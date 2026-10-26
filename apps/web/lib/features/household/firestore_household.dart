import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../auth/auth_port.dart';
import 'household.dart';

/// Code material stays in memory; only its hash is used as the invitation key.
String inviteHash(String code) {
  final normalized = code.trim();
  if (!RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(normalized)) {
    throw const HouseholdFailure('초대 코드를 다시 확인해 주세요.');
  }
  return sha256.convert(utf8.encode(normalized)).toString();
}

class FirestoreHousehold implements HouseholdPort {
  FirestoreHousehold(this.db);
  final FirebaseFirestore db;
  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      db.collection('profiles').doc(uid);
  DocumentReference<Map<String, dynamic>> _home(String id) =>
      db.collection('households').doc(id);
  Household _model(DocumentSnapshot<Map<String, dynamic>> doc) {
    final value = doc.data();
    if (value == null) throw const HouseholdFailure('가계부를 찾을 수 없어요.');
    return Household(
        id: doc.id,
        name: value['name'] as String,
        ownerId: value['ownerId'] as String);
  }

  Map<String, dynamic> _member(AuthIdentity user, String role, String hash) => {
        'uid': user.uid,
        'username': user.username,
        'role': role,
        'inviteHash': hash,
        'createdAt': FieldValue.serverTimestamp(),
      };
  Map<String, dynamic> _membership(AuthIdentity user, String home) => {
        'householdId': home,
        'username': user.username,
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  Future<Household?> load(AuthIdentity user) async {
    final profile =
        await _profile(user.uid).get(const GetOptions(source: Source.server));
    if (!profile.exists) return null;
    return _model(await _home(profile.data()!['householdId'] as String)
        .get(const GetOptions(source: Source.server)));
  }

  @override
  Future<Household> create(AuthIdentity user, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw const HouseholdFailure('가계부 이름을 1~40자로 입력해 주세요.');
    }
    // Allocate once outside the retryable transaction callback.
    final home = db.collection('households').doc();
    final member = home.collection('members').doc(user.uid);
    await db.runTransaction((tx) async {
      if ((await tx.get(_profile(user.uid))).exists) {
        throw const HouseholdFailure('이미 참여한 가계부가 있어요. 새로고침해 주세요.');
      }
      tx.set(home, {
        'name': trimmed,
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp()
      });
      tx.set(member, _member(user, 'owner', ''));
      tx.set(_profile(user.uid), _membership(user, home.id));
    });
    return Household(id: home.id, name: trimmed, ownerId: user.uid);
  }

  @override
  Future<HouseholdInvite> invite(AuthIdentity user, Household household) async {
    final random = Random.secure();
    final code = base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
    final expires = DateTime.now().toUtc().add(const Duration(hours: 24));
    await db.collection('invites').doc(inviteHash(code)).set({
      'householdId': household.id,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expires),
    });
    return HouseholdInvite(code, expires);
  }

  @override
  Future<void> revokeInvite(AuthIdentity user, String code) =>
      db.collection('invites').doc(inviteHash(code)).delete();

  @override
  Future<Household> join(AuthIdentity user, String code) async {
    final hash = inviteHash(code);
    final invitation = db.collection('invites').doc(hash);
    late String id;
    await db.runTransaction((tx) async {
      final profile = await tx.get(_profile(user.uid));
      if (profile.exists) {
        throw const HouseholdFailure('이미 참여한 가계부가 있어요. 새로고침해 주세요.');
      }
      final invite = await tx.get(invitation);
      final value = invite.data();
      if (value == null ||
          !(value['expiresAt'] as Timestamp)
              .toDate()
              .isAfter(DateTime.now().toUtc())) {
        throw const HouseholdFailure('만료되었거나 사용할 수 없는 초대 코드예요.');
      }
      id = value['householdId'] as String;
      // No member count or global membership array: independent joins do not
      // contend on a shared two-person slot or household document.
      tx.set(_home(id).collection('members').doc(user.uid),
          _member(user, 'member', hash));
      tx.set(_profile(user.uid), _membership(user, id));
    });
    return _model(await _home(id).get(const GetOptions(source: Source.server)));
  }

  @override
  Future<MemberPage> members(Household household, {String? afterUid}) async {
    Query<Map<String, dynamic>> query =
        _home(household.id).collection('members').orderBy('uid');
    if (afterUid != null) query = query.startAfter([afterUid]);
    final page =
        await query.limit(50).get(const GetOptions(source: Source.server));
    return MemberPage(
        page.docs
            .map((d) => HouseholdMember(
                uid: d.id,
                username: d.data()['username'] as String,
                role: d.data()['role'] as String))
            .toList(),
        page.docs.length == 50);
  }
}
