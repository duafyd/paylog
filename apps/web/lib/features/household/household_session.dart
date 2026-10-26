import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_port.dart';
import '../auth/auth_session.dart';
import '../auth/firebase_options.dart';
import '../transactions/transaction_repository.dart';
import 'firestore_transaction_repository.dart';
import 'firestore_household.dart';
import 'household.dart';

final firestoreDatabaseProvider = Provider<FirebaseFirestore>((ref) {
  final db = FirebaseFirestore.instance;
  db.settings = const Settings(persistenceEnabled: false);
  if (useFirebaseEmulators) {
    db.useFirestoreEmulator('127.0.0.1', 8085, automaticHostMapping: false);
  }
  return db;
});
final householdPortProvider = Provider<HouseholdPort>(
    (ref) => FirestoreHousehold(ref.watch(firestoreDatabaseProvider)));
final householdSessionProvider =
    ChangeNotifierProvider<HouseholdSession>((ref) {
  final uid = ref.watch(firebaseSessionProvider.select((s) => s.user?.uid));
  final user = ref.read(firebaseSessionProvider).user;
  final session = HouseholdSession(
      uid == null ? null : ref.read(householdPortProvider), user);
  FirestoreTransactionRepository? repository;
  session.addListener(() {
    if (session.household != null && uid != null) {
      if (repository == null) {
        repository = FirestoreTransactionRepository(
            ref.read(firestoreDatabaseProvider),
            session.household!,
            user!,
            ref.read(visibleMonthProvider));
        ref.read(activeRepositoryProvider.notifier).state = repository;
      }
      repository!.setMembers(session.people);
    } else if (session.loaded && repository != null) {
      repository!.dispose();
      if (identical(ref.read(activeRepositoryProvider), repository)) {
        ref.read(activeRepositoryProvider.notifier).state = null;
      }
      repository = null;
    }
  });
  ref.listen(visibleMonthProvider, (_, month) => repository?.setMonth(month));
  ref.onDispose(() => repository?.dispose());
  if (uid != null) scheduleMicrotask(session.load);
  return session;
});

class HouseholdSession extends ChangeNotifier {
  HouseholdSession(this.port, this.user);
  final HouseholdPort? port;
  final AuthIdentity? user;
  Household? household;
  HouseholdInvite? invitation;
  List<HouseholdMember> people = [];
  bool hasMore = false, busy = false, loaded = false;
  String? error;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_disposed || busy || user == null || port == null) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } on HouseholdFailure catch (e) {
      if (!_disposed) error = e.message;
    } on FirebaseException catch (e) {
      if (!_disposed) {
        error = switch (e.code) {
          'permission-denied' =>
            '접근 권한이 없거나 초대 코드가 만료됐어요. 가입 결과가 불확실하면 새로고침해 주세요.',
          'unavailable' => '서버에 연결하지 못했어요. 네트워크와 데이터베이스 설정을 확인해 주세요.',
          _ => '요청 결과를 확인하지 못했어요. 새로고침해서 확인해 주세요.',
        };
      }
    } catch (_) {
      if (!_disposed) error = '요청 결과를 확인하지 못했어요. 새로고침해서 확인해 주세요.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _people({bool more = false}) async {
    if (household == null) return;
    final result = await port!.members(household!,
        afterUid: more && people.isNotEmpty ? people.last.uid : null);
    if (_disposed) return;
    people = more
        ? [
            ...people,
            ...result.members
                .where((p) => !people.any((old) => old.uid == p.uid))
          ]
        : result.members;
    hasMore = result.hasMore;
  }

  Future<void> load() => _run(() async {
        final found = await port!.load(user!);
        if (_disposed) return;
        household = found;
        invitation = null;
        people = [];
        loaded = true;
        await _people();
      });
  Future<void> create(String name) => _run(() async {
        if (!loaded || household != null) {
          throw const HouseholdFailure('먼저 현재 가계부를 확인해 주세요.');
        }
        final found = await port!.create(user!, name);
        if (_disposed) return;
        household = found;
        await _people();
      });
  Future<void> join(String code) => _run(() async {
        if (!loaded || household != null) {
          throw const HouseholdFailure('먼저 현재 가계부를 확인해 주세요.');
        }
        final found = await port!.join(user!, code);
        if (_disposed) return;
        household = found;
        await _people();
      });
  Future<void> makeInvite() => _run(() async {
        if (household == null) return;
        // Reissue invalidates the previous code from this page before generating a
        // replacement; failure never displays the old code as still valid.
        final previous = invitation;
        invitation = null;
        if (previous != null) await port!.revokeInvite(user!, previous.code);
        final result = await port!.invite(user!, household!);
        if (!_disposed) invitation = result;
      });
  Future<void> revoke() => _run(() async {
        final previous = invitation;
        invitation = null;
        if (previous != null) await port!.revokeInvite(user!, previous.code);
      });
  Future<void> more() => _run(() => _people(more: true));
  @override
  void dispose() {
    _disposed = true;
    invitation = null;
    people = [];
    super.dispose();
  }
}
