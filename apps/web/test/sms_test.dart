import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:paylog/app/app.dart';
import 'firebase_auth_test.dart' show FakeAuth;
import 'widget_test.dart' show mount;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paylog/features/auth/auth_port.dart';
import 'package:paylog/features/household/firestore_household.dart';
import 'package:paylog/features/household/firestore_transaction_repository.dart';
import 'package:paylog/features/transactions/transaction.dart';
import 'package:paylog/features/sms/hana_parser.dart';
import 'package:paylog/features/sms/sms_service.dart';

const user = AuthIdentity(uid: 'owner', username: 'owner');
String body({String event = '승인', String date = '10/26', int amount = 12000}) =>
    '하나1234$event\n$amount원\n$date 12:00 테스트 가게\n누적 99,999원';
void main() {
  testWidgets(
      'capture setup fits a narrow screen with large text and keeps private config off screen',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await FirestoreHousehold(db).create(user, '가계부');
    final auth = FakeAuth()..restored = user;
    addTearDown(auth.events.close);
    final container =
        await mount(tester, auth: auth, firestore: db, width: 360, scale: 1.6);
    container.read(routerProvider).go('/sms-devices');
    await tester.pumpAndSettle();
    expect(find.text('문자 자동 기록'), findsOneWidget);
    expect(find.widgetWithText(TextField, '카드 문자 발신번호'), findsOneWidget);
    expect(find.textContaining('로그인 토큰'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
      'Hana parser handles masked cards, cancellation, year boundaries and invalid dates',
      () {
    final now = DateTime.utc(2026, 10, 26, 3);
    final parsed = parseHana(body(), now)!;
    expect(parsed.amount, 12000);
    expect(parsed.merchant, '테스트 가게');
    expect(parsed.card, '하나1234');
    expect(parsed.occurredAt, now);
    expect(parseHana(body(event: '승인취소'), now)!.cancelled, true);
    expect(
        parseHana(body(date: '12/31'), DateTime.utc(2027, 1, 1))!
            .occurredAt
            .year,
        2026);
    expect(parseHana(body(date: '02/30'), DateTime.utc(2026, 3, 1)), isNull);
    expect(parseHana(body(amount: 0), now), isNull);
    expect(parseHana(body(date: '10/01'), now), isNull);
    expect(parseHana('로그인 인증번호 123456', now), isNull);
  });
  test(
      'enrollment exports only a fresh capture account and validates sender/card configuration before signup',
      () async {
    final db = FakeFirebaseFirestore();
    final home = await FirestoreHousehold(db).create(user, '가계부');
    final service = SmsService(db, home, user);
    var calls = 0;
    final enrollment = SmsEnrollment(MockClient((request) async {
      calls++;
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      expect(data['email'],
          matches(r'^device_[a-f0-9]{32}@devices\.paylog\.invalid$'));
      expect((data['password'] as String).length, 64);
      return http.Response(jsonEncode({'localId': 'capture'}), 200);
    }));
    await expectLater(
        service.enroll(enrollment,
            name: '내 폰', senders: '*', cards: '하나1234', platform: 'android'),
        throwsA(isA<SmsFailure>()));
    expect(calls, 0);
    final config = jsonDecode(await service.enroll(enrollment,
        name: '내 폰',
        senders: '1800-1111',
        cards: '하나1234',
        platform: 'android')) as Map<String, dynamic>;
    expect(calls, 1);
    expect(config['senders'], '18001111');
    expect(config['version'], 2);
    expect(config.containsKey('idToken'), false);
    final stored =
        (await db.collection('smsDevices').doc('capture').get()).data()!;
    expect(stored['ownerUid'], user.uid);
    expect(stored.containsKey('password'), false);
    expect(stored.containsKey('email'), false);
  });
  test(
      'inbox import is atomic/idempotent across devices; cancellations, disabled devices and iPhone require review',
      () async {
    final db = FakeFirebaseFirestore();
    final home = await FirestoreHousehold(db).create(user, '가계부');
    final service = SmsService(db, home, user);
    Future<void> device(String id, {String platform = 'android'}) =>
        service.devices.doc(id).set({
          'householdId': home.id,
          'ownerUid': user.uid,
          'enabled': true,
          'cards': ['하나1234'],
          'senders': ['18001111'],
          'platform': platform
        });
    Future<void> capture(String id, String phone,
            {String? text, String message = 'original'}) =>
        service.inbox.doc(id).set({
          'deviceId': phone,
          'messageId': message,
          'sender': '18001111',
          'body': text ?? body(),
          'bodyHash': sha256.convert(utf8.encode(text ?? body())).toString(),
          'receivedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 26, 3)),
          'status': 'pending',
          'transactionId': ''
        });
    await device('phone');
    await device('second');
    await device('iphone', platform: 'ios');
    await capture('one', 'phone');
    expect(await service.importApproval('one'), true);
    expect(await service.importApproval('one'), false);
    await capture('duplicate', 'second');
    expect(await service.importApproval('duplicate'), true);
    expect(
        (await db
                .collection('households')
                .doc(home.id)
                .collection('transactions')
                .get())
            .docs
            .length,
        1);
    expect((await service.inbox.doc('one').get()).data()!['body'], '');
    final ledger =
        FirestoreTransactionRepository(db, home, user, DateTime(2026, 10));
    addTearDown(ledger.dispose);
    await ledger.refresh();
    final original = ledger.readAll().single;
    await ledger.update(BudgetTransaction(
        id: original.id,
        type: original.type,
        amount: 15000,
        occurredAt: original.occurredAt,
        merchant: original.merchant,
        categoryId: 'food',
        member: original.member,
        memberId: original.memberId,
        revision: original.revision));
    expect(ledger.readAll().single.amount, 15000);
    await ledger.delete(ledger.readAll().single);
    expect(ledger.readAll(), isEmpty);
    await capture('after-delete', 'second');
    expect(await service.importApproval('after-delete'), true);
    await ledger.refresh();
    expect(ledger.readAll(), isEmpty);

    await capture('cancel', 'phone',
        text: body(event: '취소'), message: 'cancel');
    expect(await service.importApproval('cancel'), false);
    await capture('ios', 'iphone', message: 'ios');
    expect(await service.importApproval('ios'), false);
    expect(await service.importApproval('ios', confirmed: true), true);
    await capture('dismiss-one', 'second', message: 'suppressed');
    await service.dismiss('dismiss-one');
    await capture('dismiss-again', 'phone', message: 'suppressed');
    expect(await service.importApproval('dismiss-again'), true);
    expect((await service.inbox.doc('dismiss-again').get()).data()!['status'],
        'dismissed');
    await service.disable('phone');
    await capture('blocked', 'phone', message: 'blocked');
    expect(await service.importApproval('blocked'), false);
    await service.dismiss('cancel');
    expect((await service.inbox.doc('cancel').get()).data()!['body'], '');
  });
}
