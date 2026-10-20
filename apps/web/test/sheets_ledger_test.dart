import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paylog/features/google_connection/google_connection.dart';
import 'package:paylog/features/google_connection/google_oauth.dart';
import 'package:paylog/features/ledger/ledger_session.dart';
import 'package:paylog/features/ledger/sheets_ledger_repository.dart';
import 'package:paylog/features/google_connection/sheets_probe.dart';
import 'package:paylog/features/transactions/transaction.dart';
import 'package:paylog/features/transactions/transaction_repository.dart';

const liveId = 'liveSpreadsheetIdentifier1234567890';
const household = '11111111-1111-4111-8111-111111111111';
const memberA = '22222222-2222-4222-8222-222222222222';
const memberB = '33333333-3333-4333-8333-333333333333';
const rowA = '44444444-4444-4444-8444-444444444444';
const rowB = '55555555-5555-4555-8555-555555555555';
const rowC = '66666666-6666-4666-8666-666666666666';

class LedgerServer {
  List<List<dynamic>> people = [
    memberHeaders,
    [
      memberA,
      household,
      'subject-a',
      'a@example.com',
      '가족',
      'owner',
      '2026-10-20T00:00:00+09:00',
      true
    ],
    [
      memberB,
      household,
      'subject-b',
      'b@example.com',
      '가족',
      'editor',
      '2026-10-20T00:00:00+09:00',
      true
    ]
  ];
  List<List<dynamic>> rows = [ledgerHeaders];
  int posts = 0;
  int postStatus = 200;
  bool dropResponse = false;
  bool commit = true;
  GoogleApi get api => GoogleApi(MockClient(handle));
  http.Response json(Object data, [int status = 200]) =>
      http.Response(jsonEncode(data), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
  Future<http.Response> handle(http.Request request) async {
    expect(request.headers['Authorization'], 'Bearer unit-test-token');
    if (request.url.host == 'openidconnect.googleapis.com') {
      return json({
        'sub': 'subject-a',
        'email': 'a@example.com',
        'email_verified': true,
        'name': '가족'
      });
    }
    if (request.method == 'POST') {
      posts++;
      if (postStatus != 200) {
        return json({'error': 'PRIVATE_RESPONSE'}, postStatus);
      }
      if (request.url.path.endsWith(':append')) {
        expect(request.url.queryParameters['valueInputOption'], 'RAW');
        if (commit) {
          rows.add(List<dynamic>.from(
              (jsonDecode(request.body) as Map)['values'][0] as List));
        }
        if (dropResponse) throw http.ClientException('response lost');
      }
      return json({'spreadsheetId': liveId});
    }
    if (request.url.path.endsWith('/values:batchGet')) {
      return json({
        'valueRanges': [
          {'values': people}
        ]
      });
    }
    if (request.url.path.contains('/values/')) return json({'values': rows});
    return json({
      'properties': {'title': '실제 원장'}
    });
  }

  SheetsLedgerRepository repository({String subject = 'subject-a'}) =>
      SheetsLedgerRepository(
          api: api,
          token: () => 'unit-test-token',
          subject: subject,
          id: liveId);
}

List<dynamic> row(String id,
        {int amount = 1000,
        String member = memberA,
        String status = 'approved',
        String deleted = ''}) =>
    [
      id,
      household,
      'expense',
      amount,
      '2026-10-19T15:05:00Z',
      '거래',
      '메모',
      'food',
      member,
      '',
      'manual',
      status,
      '',
      '',
      '2026-10-20T00:05:00+09:00',
      '2026-10-20T00:05:00+09:00',
      memberA,
      deleted,
      '현금'
    ];
BudgetTransaction draft({String id = rowA, String merchant = '=SUM(A1:A2)'}) =>
    BudgetTransaction(
        id: id,
        type: TransactionType.expense,
        amount: 25000,
        occurredAt: DateTime(2026, 10, 20, 14, 30),
        merchant: merchant,
        memo: '메모',
        categoryId: 'food',
        memberId: memberB,
        member: '가족',
        paymentMethod: '현금');

class UnitOAuth implements GoogleOAuthPort {
  @override
  Future<void> initialize() async {}
  @override
  Future<OAuthGrant> authorize(String scope) async => OAuthGrant(
      'unit-test-token', DateTime.now().add(const Duration(hours: 1)));
  @override
  Future<void> revoke(String accessToken) async {}
}

void main() {
  test('UUID로 동명이인을 구분하고 서울 날짜로 읽으며 취소·검토·삭제를 합계에서 제외한다', () async {
    final server = LedgerServer()
      ..rows.addAll([
        row(rowA),
        row(rowB, member: memberB, status: 'cancelled'),
        row(rowC, status: 'review_required')
      ]);
    final repo = server.repository();
    await repo.refresh();
    expect(repo.readAll(), hasLength(1));
    expect(repo.excludedCount, 2);
    expect(repo.readAll().single.occurredAt, DateTime(2026, 10, 20, 0, 5));
    expect(repo.actor!.id, memberA);
    expect(repo.ledgerMembers.map((m) => m.id), [memberA, memberB]);
    expect(repo.ledgerMembers.map((m) => m.name), ['가족', '가족']);
    expect(memberLabel(repo.ledgerMembers[0], repo.ledgerMembers),
        contains('a@example.com'));
    expect(memberLabel(repo.ledgerMembers[1], repo.ledgerMembers),
        contains('b@example.com'));
    server.rows[3][11] = 'approved';
    server.rows[3][17] = '2026-10-20T01:00:00+09:00';
    await repo.refresh();
    expect(repo.excludedCount, 2);
  });
  test('RAW 저장은 선택한 멤버 UUID와 현재 계정의 감사 ID를 구분한다', () async {
    final server = LedgerServer(), repo = LedgerServer().repository();
    final active = server.repository();
    await active.refresh();
    await active.add(draft());
    final saved = server.rows.last;
    expect(saved[5], '=SUM(A1:A2)');
    expect(saved[8], memberB);
    expect(saved[16], memberA);
    expect(saved[4], '2026-10-20T14:30:00.000+09:00');
    expect(saved[18], '현금');
    expect(active.readAll().single.memberId, memberB);
    expect(server.posts, 1);
    expect(repo.readAll(), isEmpty);
  });
  test('서버에는 저장됐지만 응답이 끊기면 같은 UUID 재확인은 POST 없이 성공한다', () async {
    final server = LedgerServer()..dropResponse = true;
    final repo = server.repository();
    await repo.refresh();
    await expectLater(
        repo.add(draft()),
        throwsA(isA<ConnectionFailure>()
            .having((e) => e.uncertainWrite, 'uncertain', true)));
    expect(repo.readAll(), isEmpty);
    expect(server.rows, hasLength(2));
    server.people[1][5] = 'viewer';
    await repo.add(draft());
    expect(repo.canWrite, isFalse);
    expect(server.posts, 1);
    expect(repo.readAll(), hasLength(1));
  });
  test('응답 단절 후 행이 안 보여도 같은 UUID를 자동으로 다시 쓰지 않는다', () async {
    final server = LedgerServer()
      ..dropResponse = true
      ..commit = false;
    final repo = server.repository();
    await repo.refresh();
    for (var i = 0; i < 2; i++) {
      await expectLater(
          repo.add(draft()),
          throwsA(isA<ConnectionFailure>()
              .having((e) => e.uncertainWrite, 'uncertain', true)));
    }
    expect(server.posts, 1);
    expect(server.rows, hasLength(1));
  });
  test('Google 403 거부 시 로컬에는 성공한 거래를 추가하지 않는다', () async {
    final server = LedgerServer()..postStatus = 403;
    final repo = server.repository();
    await repo.refresh();
    await expectLater(
        repo.add(draft()),
        throwsA(isA<ConnectionFailure>()
            .having((e) => e.uncertainWrite, 'uncertain', false)));
    expect(repo.readAll(), isEmpty);
    expect(server.rows, hasLength(1));
  });
  test('같은 UUID의 다른 거래는 덮어쓰거나 추가하지 않는다', () async {
    final server = LedgerServer()..rows.add(row(rowA));
    final repo = server.repository();
    await repo.refresh();
    await expectLater(repo.add(draft()), throwsA(isA<ConnectionFailure>()));
    expect(server.posts, 0);
  });
  for (final mode in ['viewer', 'unmapped', 'legacy']) {
    test('$mode 원장은 조회는 허용하고 수동 쓰기를 차단한다', () async {
      final server = LedgerServer();
      if (mode == 'viewer') server.people[1][5] = 'viewer';
      if (mode == 'legacy') server.rows[0] = transactionHeaders;
      final repo = server.repository(
          subject: mode == 'unmapped' ? 'other-subject' : 'subject-a');
      await repo.refresh();
      expect(repo.canWrite, isFalse);
      await expectLater(repo.add(draft()), throwsA(isA<ConnectionFailure>()));
      expect(server.posts, 0);
    });
  }
  for (final defect in [
    'duplicate',
    'fraction',
    'unknown-category',
    'unmapped-member',
    'timezone',
    'invalid-day',
    'mixed-household'
  ]) {
    test('$defect 시트 오류는 이전 정상 스냅샷을 덮어쓰지 않는다', () async {
      final server = LedgerServer()..rows.add(row(rowA));
      final repo = server.repository();
      await repo.refresh();
      if (defect == 'duplicate') server.rows.add(row(rowA));
      if (defect == 'fraction') server.rows[1][3] = 1000.5;
      if (defect == 'unknown-category') server.rows[1][7] = 'custom-category';
      if (defect == 'unmapped-member') server.rows[1][8] = 'not-a-member';
      if (defect == 'timezone') server.rows[1][4] = '2026-10-20T00:00:00';
      if (defect == 'invalid-day') {
        server.rows[1][4] = '2026-02-31T00:00:00+09:00';
      }
      if (defect == 'mixed-household') server.rows[1][1] = memberB;
      await expectLater(repo.refresh(), throwsA(isA<ConnectionFailure>()));
      expect(repo.readAll().single.amount, 1000);
    });
  }
  test('템플릿은 샘플 거래 없이 헤더·UUID Members를 RAW로 초기화한다', () async {
    final writes = <Map>[];
    final api = GoogleApi(MockClient((request) async {
      writes.add(jsonDecode(request.body) as Map);
      return http.Response(jsonEncode({'spreadsheetId': liveId}), 200);
    }));
    String? created;
    await createLedgerTemplate(api, () => 'unit-test-token',
        subject: 'subject-a',
        email: 'a@example.com',
        name: '=NAME()',
        onCreated: (id) => created = id);
    expect(created, liveId);
    expect(writes[0]['sheets'], hasLength(2));
    expect(writes[1]['valueInputOption'], 'RAW');
    final data = writes[1]['data'] as List;
    expect(data[0]['values'], [ledgerHeaders]);
    final member = data[1]['values'][1] as List;
    expect(member[0], matches(RegExp(r'^[a-f0-9-]{36}$')));
    expect(member[2], 'subject-a');
    expect(member[4], '=NAME()');
  });
  test('원장 연결 시 샘플은 섞지 않고 Google 연결 해제 시 캐시를 화면에서 제거한다', () async {
    final server = LedgerServer()..rows.add(row(rowA));
    final google = GoogleConnection(UnitOAuth(), server.api, configured: true);
    final container = ProviderContainer(
        overrides: [googleConnectionProvider.overrideWith((ref) => google)]);
    addTearDown(container.dispose);
    await google.initialize();
    await google.signIn();
    await google.authorizeSheets();
    await container.read(ledgerSessionProvider.notifier).connect(liveId);
    expect(container.read(transactionsProvider), hasLength(1));
    expect(container.read(activeRepositoryProvider)!.sheetId, liveId);
    await google.disconnect();
    expect(container.read(activeRepositoryProvider), isNull);
    expect(container.read(transactionsProvider), hasLength(6));
  });
}
