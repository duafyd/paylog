import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_port.dart';
import '../auth/firebase_options.dart';
import '../household/household.dart';
import 'hana_parser.dart';

class SmsFailure implements Exception {
  const SmsFailure(this.message);
  final String message;
}

/// Separate capture-only Auth accounts never replace the user's login session.
class SmsEnrollment {
  SmsEnrollment(this.client);
  final http.Client client;
  Future<Map<String, String>> create() async {
    final random = Random.secure();
    String hex(int count) => List.generate(
            count, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    final email = 'device_${hex(16)}@devices.paylog.invalid';
    final password = hex(32);
    final host = useFirebaseEmulators
        ? 'http://127.0.0.1:9099/identitytoolkit.googleapis.com'
        : 'https://identitytoolkit.googleapis.com';
    final response = await client
        .post(
            Uri.parse(
                '$host/v1/accounts:signUp?key=${activeFirebaseOptions.apiKey}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'returnSecureToken': true
            }))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const SmsFailure('기기 계정을 만들지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'email': email,
      'password': password,
      'deviceId': result['localId'] as String
    };
  }
}

class SmsService {
  SmsService(this.db, this.home, this.user);
  final FirebaseFirestore db;
  final Household home;
  final AuthIdentity user;
  CollectionReference<Map<String, dynamic>> get devices =>
      db.collection('smsDevices');
  CollectionReference<Map<String, dynamic>> get inbox =>
      db.collection('households').doc(home.id).collection('smsInbox');
  late final Stream<QuerySnapshot<Map<String, dynamic>>> pending = inbox
      .where('status', isEqualTo: 'pending')
      .limit(50)
      .snapshots(includeMetadataChanges: true);
  late final Stream<QuerySnapshot<Map<String, dynamic>>> registrations = devices
      .where('householdId', isEqualTo: home.id)
      .limit(50)
      .snapshots(includeMetadataChanges: true);

  Future<String> enroll(SmsEnrollment enrollment,
      {required String name,
      required String senders,
      required String cards,
      required String platform}) async {
    final numbers = senders
        .split(',')
        .map((s) => s.replaceAll(RegExp(r'[\s()-]'), ''))
        .toSet()
        .toList();
    final identifiers = cards.split(',').map((c) => c.trim()).toSet().toList();
    if (name.trim().isEmpty ||
        name.trim().length > 40 ||
        numbers.isEmpty ||
        numbers.length > 10 ||
        numbers.any((s) => !RegExp(r'^\+?[0-9]{3,20}$').hasMatch(s)) ||
        identifiers.isEmpty ||
        identifiers.length > 10 ||
        identifiers.any((c) => !RegExp(r'^하나[0-9*]{4,12}$').hasMatch(c)) ||
        !['android', 'ios'].contains(platform)) {
      throw const SmsFailure(
          '기기 이름, 실제 카드 문자 발신번호, 문자에 표시된 카드 식별자(예: 하나1234)를 확인해 주세요.');
    }
    final credentials = await enrollment.create();
    // An unbound capture account has no Firestore access. Never export until
    // the human-authorized binding has been acknowledged by the server.
    await devices.doc(credentials['deviceId']).set({
      'householdId': home.id,
      'ownerUid': user.uid,
      'name': name.trim(),
      'enabled': true,
      'senders': numbers,
      'cards': identifiers,
      'platform': platform,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return jsonEncode({
      'format': 'paylog-android-connection',
      'version': 2,
      'backend': 'firestore',
      'projectId': activeFirebaseOptions.projectId,
      'apiKey': activeFirebaseOptions.apiKey,
      'householdId': home.id,
      ...credentials,
      'senders': numbers.join(','),
      'platform': platform
    });
  }

  Future<void> disable(String id) => devices.doc(id).update({'enabled': false});

  /// A deterministic transaction ID and one atomic inbox/ledger commit make
  /// simultaneous processing by multiple open browsers idempotent.
  Future<bool> importApproval(String id, {bool confirmed = false}) =>
      db.runTransaction((tx) async {
        final source = inbox.doc(id);
        final snapshot = await tx.get(source);
        final d = snapshot.data();
        if (d == null || d['status'] != 'pending') return false;
        final device =
            (await tx.get(devices.doc(d['deviceId'] as String))).data();
        if (device == null ||
            device['householdId'] != home.id ||
            device['enabled'] != true) {
          return false;
        }
        if (d['bodyHash'] !=
            sha256.convert(utf8.encode(d['body'] as String)).toString()) {
          return false;
        }
        final parsed = parseHana(
            d['body'] as String, (d['receivedAt'] as Timestamp).toDate());
        if (parsed == null ||
            parsed.cancelled ||
            !(device['cards'] as List).contains(parsed.card) ||
            !(device['senders'] as List).contains(d['sender']) ||
            (!confirmed && device['platform'] != 'android')) {
          return false;
        }
        final owner = (await tx.get(db
                .collection('households')
                .doc(home.id)
                .collection('members')
                .doc(device['ownerUid'] as String)))
            .data();
        if (owner == null) return false;
        final target = db
            .collection('households')
            .doc(home.id)
            .collection('transactions')
            .doc('sms_${d['messageId']}');
        final receiptRef = db
            .collection('households')
            .doc(home.id)
            .collection('smsReceipts')
            .doc(d['messageId'] as String);
        final receipt = (await tx.get(receiptRef)).data();
        final existing = await tx.get(target);
        if (receipt != null) {
          if (receipt['bodyHash'] == d['bodyHash'] &&
              receipt['sender'] == d['sender'] &&
              receipt['transactionId'] == '') {
            tx.update(source, {
              'status': 'dismissed',
              'body': '',
              'handledAt': FieldValue.serverTimestamp()
            });
            return true;
          }
          if (receipt['bodyHash'] != d['bodyHash'] ||
              receipt['sender'] != d['sender'] ||
              receipt['transactionId'] != target.id ||
              !existing.exists) {
            return false;
          }
          tx.update(source, {
            'status': 'imported',
            'transactionId': target.id,
            'body': '',
            'handledAt': FieldValue.serverTimestamp()
          });
          return true;
        }
        if (existing.exists) {
          throw const SmsFailure('같은 문자 ID의 거래가 이미 있어요. 기록을 확인한 뒤 검토를 마쳐 주세요.');
        }
        tx.set(receiptRef, {
          'bodyHash': d['bodyHash'],
          'sender': d['sender'],
          'transactionId': target.id,
          'createdAt': FieldValue.serverTimestamp()
        });
        tx.set(target, {
          'type': 'expense',
          'amount': parsed.amount,
          'occurredAt': Timestamp.fromDate(parsed.occurredAt),
          'merchant': parsed.merchant,
          'memo': '카드 문자에서 기록',
          'categoryId': 'other',
          'memberId': device['ownerUid'],
          'memberName': owner['username'],
          'paymentMethod': '카드',
          'version': 1,
          'createdBy': user.uid,
          'updatedBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'deletedAt': null
        });
        tx.update(source, {
          'status': 'imported',
          'transactionId': target.id,
          'body': '',
          'handledAt': FieldValue.serverTimestamp()
        });
        return true;
      });
  Future<void> dismiss(String id) => db.runTransaction((tx) async {
        final source = inbox.doc(id);
        final d = (await tx.get(source)).data();
        if (d == null || d['status'] != 'pending') return;
        final receipt = db
            .collection('households')
            .doc(home.id)
            .collection('smsReceipts')
            .doc(d['messageId'] as String);
        if (!(await tx.get(receipt)).exists) {
          tx.set(receipt, {
            'bodyHash': d['bodyHash'],
            'sender': d['sender'],
            'transactionId': '',
            'createdAt': FieldValue.serverTimestamp()
          });
        }
        tx.update(source, {
          'status': 'dismissed',
          'body': '',
          'handledAt': FieldValue.serverTimestamp()
        });
      });
}
