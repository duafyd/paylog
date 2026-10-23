import 'dart:convert' hide json;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:paylog/app/app.dart';
import 'package:paylog/features/export/ledger_export.dart';
import 'package:paylog/features/google_connection/google_oauth.dart';
import 'package:paylog/features/transactions/transaction.dart';
import 'package:paylog/features/transactions/transaction_repository.dart';
import 'package:paylog/features/ledger/ledger_management.dart';
import 'sheets_ledger_test.dart' as fixture;
import 'widget_test.dart' show mount, reveal;

class MutationServer extends fixture.LedgerServer {
  bool loseUpdate = false;
  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.method == 'GET' &&
        request.url.path.endsWith('/values/Members!A1:H')) {
      return json({'values': people});
    }
    if (request.method == 'GET' &&
        request.url.path.endsWith('/values/Members!A1:Z')) {
      return json({'values': people});
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/values:batchUpdate')) {
      posts++;
      if (postStatus != 200) return json({}, postStatus);
      final body = jsonDecode(request.body) as Map;
      expect(body['valueInputOption'], 'RAW');
      for (final change in body['data'] as List) {
        final range = change['range'] as String;
        final index =
            int.parse(RegExp(r'!A(\d+)').firstMatch(range)!.group(1)!) - 1;
        if (commit) {
          rows[index] = List<dynamic>.from(change['values'][0] as List);
        }
      }
      if (loseUpdate) throw http.ClientException('lost');
      return json({});
    }
    return super.handle(request);
  }
}

BudgetTransaction edit(BudgetTransaction t, {int amount = 2000}) =>
    BudgetTransaction(
        id: t.id,
        type: t.type,
        amount: amount,
        occurredAt: t.occurredAt,
        merchant: t.merchant,
        categoryId: t.categoryId,
        member: t.member,
        memberId: t.memberId,
        memo: '수정',
        paymentMethod: t.paymentMethod,
        revision: t.revision);
void main() {
  test(
      'UUID resolves shifted row; update preserves source and creation audit; delete is soft',
      () async {
    final server = MutationServer()..rows.add(fixture.row(fixture.rowA));
    server.rows[1][10] = 'android_sms';
    final repo = server.repository();
    await repo.refresh();
    final original = repo.readAll().single;
    server.rows.insert(1, fixture.row(fixture.rowB));
    await repo.update(edit(original));
    expect(server.rows[1][0], fixture.rowB);
    expect(server.rows[2][3], 2000);
    expect(server.rows[2][10], 'android_sms');
    expect(server.rows[2][14], fixture.row(fixture.rowA)[14]);
    await repo.delete(repo.readAll().firstWhere((t) => t.id == fixture.rowA));
    expect(repo.readAll().map((t) => t.id), [fixture.rowB]);
    expect(server.rows[2][17], isNotEmpty);
  });
  test('concurrent edit rejects stale revision without POST', () async {
    final server = MutationServer()..rows.add(fixture.row(fixture.rowA));
    final repo = server.repository();
    await repo.refresh();
    final old = repo.readAll().single;
    server.rows[1][6] = '다른 가족 수정';
    await expectLater(
        repo.update(edit(old)), throwsA(isA<ConnectionFailure>()));
    expect(server.posts, 0);
    await expectLater(repo.delete(old), throwsA(isA<ConnectionFailure>()));
    expect(server.posts, 0);
  });
  for (final deleting in [false, true]) {
    test(
        'lost ${deleting ? 'delete' : 'update'} response reconfirms with GET only',
        () async {
      final server = MutationServer()
        ..rows.add(fixture.row(fixture.rowA))
        ..loseUpdate = true;
      final repo = server.repository();
      await repo.refresh();
      final old = edit(repo.readAll().single);
      Future<void> change() => deleting ? repo.delete(old) : repo.update(old);
      await expectLater(
          change(),
          throwsA(isA<ConnectionFailure>()
              .having((e) => e.uncertainWrite, 'uncertain', true)));
      server.people[1][5] = 'viewer';
      await change();
      expect(server.posts, 1);
      expect(repo.readAll().length, deleting ? 0 : 1);
    });
  }
  test('uncommitted uncertain update is never repeated', () async {
    final server = MutationServer()
      ..rows.add(fixture.row(fixture.rowA))
      ..loseUpdate = true
      ..commit = false;
    final repo = server.repository();
    await repo.refresh();
    final old = edit(repo.readAll().single);
    for (var i = 0; i < 2; i++) {
      await expectLater(
          repo.update(old),
          throwsA(isA<ConnectionFailure>()
              .having((e) => e.uncertainWrite, 'uncertain', true)));
    }
    expect(server.posts, 1);
  });
  test('Google Viewer rejection preserves cache; last owner cannot be disabled',
      () async {
    final server = MutationServer()..rows.add(fixture.row(fixture.rowA));
    final repo = server.repository();
    await repo.refresh();
    server.postStatus = 403;
    await expectLater(repo.update(edit(repo.readAll().single)),
        throwsA(isA<ConnectionFailure>()));
    expect(repo.readAll().single.amount, 1000);
    final management = LedgerManagement(repo);
    final owner = (await management.list('Members')).first;
    await expectLater(
        management.save('Members', {'active': 'false'}, original: owner),
        throwsA(isA<ConnectionFailure>()));
    expect(server.posts, 1);
  });
  test('CSV escapes delimiters/newlines and neutralizes formula prefixes', () {
    for (final prefix in ['=', '+', '-', '@', '  =', '\t=']) {
      expect(csvCell('${prefix}SUM(A1)'), startsWith('"\''));
    }
    expect(csvCell('a,"b"\nc'), '"a,""b""\nc"');
    final repo = InMemoryTransactionRepository(DateTime(2026, 10, 20));
    expect(ledgerCsv(repo.readAll()), startsWith('\uFEFF'));
    expect(ledgerCsv(repo.readAll()), contains('4200000'));
  });
  testWidgets('sample transaction can be edited then deleted through UI',
      (tester) async {
    final c = await mount(tester);
    c.read(routerProvider).go('/transaction/sample-2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('amount')), '15000');
    await reveal(tester, find.byKey(const ValueKey('save')));
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(
        c
            .read(transactionsProvider)
            .firstWhere((t) => t.id == 'sample-2')
            .amount,
        15000);
    c.read(routerProvider).go('/transaction/sample-2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(c.read(transactionsProvider).any((t) => t.id == 'sample-2'), false);
    expect(tester.takeException(), isNull);
  });
}
