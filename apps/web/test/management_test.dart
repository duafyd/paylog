import 'dart:convert' hide json;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:paylog/features/google_connection/google_oauth.dart';
import 'package:paylog/features/ledger/ledger_management.dart';
import 'package:paylog/features/transactions/transaction.dart';
import 'sheets_ledger_test.dart' as f;
import 'ledger_mutation_test.dart' show MutationServer;

const categoryId = '77777777-7777-4777-8777-777777777777';

class ManagementServer extends MutationServer {
  final tables = <String, List<List<dynamic>>>{
    for (final name in ['Categories', 'Cards', 'Devices', 'Review'])
      name: [managementHeaders[name]!]
  };
  @override
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path.endsWith('/${f.liveId}')) {
      return json({
        'properties': {'title': '관리 테스트'},
        'sheets': [
          {
            'properties': {'title': 'Categories'}
          }
        ]
      });
    }
    final match = RegExp(r'/values/(\w+)!').firstMatch(path);
    if (match != null) {
      final name = match.group(1)!;
      final target = name == 'Members' ? people : tables[name];
      if (target != null) {
        if (request.method == 'GET') return json({'values': target});
        if (path.endsWith(':append')) {
          posts++;
          expect(request.url.queryParameters['valueInputOption'], 'RAW');
          target.add(List<dynamic>.from(jsonDecode(request.body)['values'][0]));
          return json({});
        }
      }
    }
    if (request.method == 'POST' && path.endsWith('/values:batchUpdate')) {
      final body = jsonDecode(request.body);
      final changes = body['data'] as List;
      if (changes
          .any((d) => !d['range'].toString().startsWith('Transactions'))) {
        posts++;
        expect(body['valueInputOption'], 'RAW');
        for (final change in changes) {
          final match = RegExp(r'^(\w+)!A(\d+)').firstMatch(change['range'])!;
          final name = match.group(1)!;
          final target = name == 'Members' ? people : tables[name]!;
          target[int.parse(match.group(2)!) - 1] =
              List<dynamic>.from(change['values'][0]);
        }
        return json({});
      }
    }
    return super.handle(request);
  }
}

void main() {
  test(
      'join binds only the current subject, and duplicate/inactive accounts cannot append again',
      () async {
    final server = ManagementServer();
    final repo = server.repository(subject: 'new-subject');
    await repo.refresh();
    expect(repo.canWrite, false);
    await repo.join(email: 'new@example.com', name: '새 가족');
    expect(repo.canWrite, true);
    expect(repo.actor!.subject, 'new-subject');
    expect(server.posts, 1);
    await expectLater(repo.join(email: 'new@example.com', name: '다른 이름'),
        throwsA(isA<ConnectionFailure>()));
    expect(server.posts, 1);
    server.people.last[7] = false;
    await expectLater(repo.join(email: 'new@example.com', name: '복귀'),
        throwsA(isA<ConnectionFailure>()));
    expect(server.posts, 1);
  });
  test(
      'custom categories are read by UUID including disabled historical records',
      () async {
    final server = ManagementServer();
    server.tables['Categories']!
        .add([categoryId, f.household, '교육', 'other', 'expense', 2, false]);
    final raw = f.row(f.rowA);
    raw[7] = categoryId;
    server.rows.add(raw);
    final repo = server.repository();
    await repo.refresh();
    expect(repo.readAll().single.category.label, '교육');
    expect(repo.categoryCatalog.last.enabled, false);
    final draft = BudgetTransaction(
        id: f.rowB,
        type: TransactionType.expense,
        amount: 1000,
        occurredAt: DateTime(2026, 10, 20),
        merchant: '학교',
        categoryId: categoryId,
        member: '가족',
        memberId: f.memberA);
    await expectLater(repo.add(draft), throwsA(isA<ConnectionFailure>()));
    expect(server.posts, 0);
  });
  test('category/card management round trip uses RAW and rejects stale changes',
      () async {
    final server = ManagementServer(), repo = ManagementServer().repository();
    final active = server.repository();
    await active.refresh();
    final service = LedgerManagement(active);
    await service.save('Categories', {
      'name': '교육',
      'icon': 'other',
      'type': 'expense',
      'sortOrder': '1',
      'enabled': 'true'
    });
    final category = (await service.list('Categories')).single;
    expect(category.values['id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    server.tables['Categories']![1][2] = '다른 곳 수정';
    await expectLater(
        service.save('Categories', {'name': '덮어쓰기'}, original: category),
        throwsA(isA<ConnectionFailure>()));
    expect(server.posts, 1);
    await service.save('Cards', {
      'issuer': '하나카드',
      'senderAllowlist': '실제번호등록필요',
      'maskedIdentifier': '하나3*8*',
      'memberId': f.memberA,
      'enabled': 'true'
    });
    expect((await service.list('Cards')).single.values['memberId'], f.memberA);
    expect(repo.readAll(), isEmpty);
  });
  test(
      'device disable preserves hash; review resolution requires a real transaction UUID',
      () async {
    final server = ManagementServer();
    server.tables['Devices']!.add([
      f.rowB,
      f.household,
      f.memberA,
      'android',
      'TEST_HASH_ONLY',
      true,
      '',
      '2026-10-20T00:00:00+09:00'
    ]);
    server.tables['Review']!.add([
      f.rowC,
      'key',
      f.household,
      f.rowB,
      'UNPARSEABLE',
      'null',
      '2026-10-20T00:00:00+09:00',
      '',
      ''
    ]);
    final repo = server.repository();
    await repo.refresh();
    final service = LedgerManagement(repo);
    final device = (await service.list('Devices')).single;
    await service.save(
        'Devices', {'enabled': 'false', 'tokenHash': 'must-not-change'},
        original: device);
    expect(server.tables['Devices']![1][4], 'TEST_HASH_ONLY');
    expect(server.tables['Devices']![1][5], 'false');
    final review = (await service.list('Review')).single;
    await expectLater(
        service.save('Review', {'resolution': 'unknown-id'}, original: review),
        throwsA(isA<ConnectionFailure>()));
    await service.save('Review', {'resolution': 'ignored'}, original: review);
    expect(server.tables['Review']![1][7], isNotEmpty);
  });
  test('foreign household categories and duplicate UUID fail closed', () async {
    final server = ManagementServer();
    server.tables['Categories']!
        .add([categoryId, f.memberB, '교육', 'other', 'expense', 0, true]);
    await expectLater(
        server.repository().refresh(), throwsA(isA<ConnectionFailure>()));
    server.tables['Categories']![1][1] = f.household;
    server.tables['Categories']!
        .add(List.from(server.tables['Categories']![1]));
    await expectLater(
        server.repository().refresh(), throwsA(isA<ConnectionFailure>()));
  });
}
