import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/app/app.dart';
import 'package:paylog/features/auth/auth_port.dart';
import 'package:paylog/features/household/firestore_household.dart';
import 'package:paylog/features/household/firestore_transaction_repository.dart';
import 'package:paylog/features/household/household.dart';
import 'package:paylog/features/transactions/transaction_repository.dart';
import 'package:paylog/features/transactions/transaction.dart';
import 'package:paylog/features/google_connection/google_oauth.dart';
import 'firebase_auth_test.dart' show FakeAuth;
import 'widget_test.dart' show mount;

const owner = AuthIdentity(uid: 'owner', username: 'owner');
const guest = AuthIdentity(uid: 'guest', username: 'guest');
void main() {
  test('household creation and multi-user invite have no two-member limit',
      () async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreHousehold(db);
    expect(await service.load(owner), isNull);
    final home = await service.create(owner, '우리 가계부');
    final code = await service.invite(owner, home);
    expect(code.code.length, 32);
    for (var i = 0; i < 5; i++) {
      final member = AuthIdentity(uid: 'member$i', username: 'member$i');
      expect((await service.join(member, code.code)).id, home.id);
      expect((await service.load(member))!.id, home.id);
    }
    final people = await service.members(home);
    expect(people.members.length, 6);
    expect(people.hasMore, false);
    await expectLater(
        service.create(owner, '중복'), throwsA(isA<HouseholdFailure>()));
    await service.revokeInvite(owner, code.code);
    await expectLater(
        service.join(guest, code.code), throwsA(isA<HouseholdFailure>()));
  });
  test(
      'member pagination continues past the first page and code format is checked',
      () async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreHousehold(db);
    final home = await service.create(owner, '여럿');
    final code = await service.invite(owner, home);
    for (var i = 0; i < 52; i++) {
      await service.join(
          AuthIdentity(
              uid: 'member${i.toString().padLeft(2, '0')}',
              username: 'member$i'),
          code.code);
    }
    final first = await service.members(home);
    expect(first.members.length, 50);
    expect(first.hasMore, true);
    final second =
        await service.members(home, afterUid: first.members.last.uid);
    expect(second.members.length, 3);
    expect(
        {
          ...first.members.map((m) => m.uid),
          ...second.members.map((m) => m.uid)
        }.length,
        53);
    expect(() => inviteHash('123456'), throwsA(isA<HouseholdFailure>()));
  });
  test(
      'financial writes are idempotent, conflicting revisions are rejected, and month is bounded',
      () async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreHousehold(db);
    final home = await service.create(owner, '기록');
    await service.join(guest, (await service.invite(owner, home)).code);
    final repo =
        FirestoreTransactionRepository(db, home, owner, DateTime(2026, 10));
    addTearDown(repo.dispose);
    BudgetTransaction value({int amount = 12000, String revision = ''}) =>
        BudgetTransaction(
            id: 'purchase',
            type: TransactionType.expense,
            amount: amount,
            occurredAt: DateTime(2026, 10, 26, 12),
            merchant: '가게',
            categoryId: 'food',
            member: guest.username,
            memberId: guest.uid,
            revision: revision);
    await repo.add(value());
    await repo.add(value());
    expect(repo.readAll().single.amount, 12000);
    expect(repo.ledgerMembers.any((person) => person.id == guest.uid), true);
    expect(repo.readAll().single.revision, '1');
    await repo.update(value(amount: 13000, revision: '1'));
    await repo.update(value(amount: 13000, revision: '1'));
    expect(repo.readAll().single.revision, '2');
    await expectLater(repo.update(value(amount: 14000, revision: '1')),
        throwsA(isA<ConnectionFailure>()));
    repo.setMonth(DateTime(2026, 11));
    await repo.refresh();
    expect(repo.readAll(), isEmpty);
    repo.setMonth(DateTime(2026, 10));
    await repo.refresh();
    await repo.delete(repo.readAll().single);
    expect(repo.readAll(), isEmpty);
    expect(repo.excludedCount, 1);
  });
  testWidgets(
      'signed-in user creates a household and sees invite and real empty ledger',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final auth = FakeAuth()..restored = owner;
    addTearDown(auth.events.close);
    final container =
        await mount(tester, auth: auth, firestore: db, width: 393);
    container.read(routerProvider).go('/household');
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextField, '가계부 이름');
    await tester.ensureVisible(name);
    await tester.enterText(name, '우리 집');
    final create = find.widgetWithText(FilledButton, '가계부 만들기');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('우리 집'), findsOneWidget);
    expect(find.text('가계부 열기'), findsOneWidget);
    final issue = find.widgetWithText(FilledButton, '초대 코드 만들기');
    await tester.ensureVisible(issue);
    await tester.tap(issue);
    await tester.pumpAndSettle();
    expect(find.text('초대 코드 복사'), findsOneWidget);
    container.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    expect(find.text('공동 가계부'), findsOneWidget);
    expect(find.text('₩180,600'), findsNothing);
    // Consecutive remote snapshots must each rebuild the provider, even when
    // nobody presses refresh (a void/null stream signal loses these updates).
    final repository = container.read(transactionRepositoryProvider);
    final doc = db
        .collection('households')
        .doc(repository.householdId)
        .collection('transactions')
        .doc('remote');
    await doc.set({
      'type': 'expense',
      'amount': 1000,
      'occurredAt': Timestamp.fromDate(DateTime.utc(2026, 10, 15, 3)),
      'merchant': '원격 거래',
      'memo': '',
      'categoryId': 'food',
      'memberId': owner.uid,
      'memberName': owner.username,
      'paymentMethod': '카드',
      'version': 1,
      'deletedAt': null,
    });
    await tester.pumpAndSettle();
    expect(container.read(transactionsProvider).single.amount, 1000);
    await doc.update({'amount': 2000, 'version': 2});
    await tester.pumpAndSettle();
    expect(container.read(transactionsProvider).single.amount, 2000);
    await doc.update({'deletedAt': Timestamp.now(), 'version': 3});
    await tester.pumpAndSettle();
    expect(container.read(transactionsProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
