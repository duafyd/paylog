import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/app/app.dart';
import 'package:paylog/features/google_connection/google_oauth.dart';
import 'package:paylog/features/transactions/transaction.dart';
import 'package:paylog/features/transactions/transaction_repository.dart';
import 'widget_test.dart' show mount, reveal;

class WidgetLedger extends TransactionRepository {
  WidgetLedger({this.canWrite = true});
  @override
  final bool canWrite;
  final calls = <BudgetTransaction>[];
  final firstWrite = Completer<void>();
  final items = <BudgetTransaction>[];
  @override
  String get sheetId => 'widgetLedgerIdentifier1234567890';
  @override
  String get title => '위젯 테스트 원장';
  @override
  int get excludedCount => 0;
  @override
  List<LedgerMember> get ledgerMembers => [
        const LedgerMember(
            id: '22222222-2222-4222-8222-222222222222', name: '테스트 가족')
      ];
  @override
  LedgerMember get actor => ledgerMembers.single;
  @override
  List<BudgetTransaction> readAll() => List.unmodifiable(items);
  @override
  Future<void> refresh() async {}
  @override
  Future<void> add(BudgetTransaction transaction) async {
    calls.add(transaction);
    if (calls.length == 1) await firstWrite.future;
    items.add(transaction);
  }
}

void main() {
  testWidgets('조회 전용 Sheets 원장에서는 저장 버튼과 입력을 비활성화한다', (tester) async {
    final repository = WidgetLedger(canWrite: false);
    final container = await mount(tester, repository: repository);
    container.read(routerProvider).go('/add');
    await tester.pumpAndSettle();
    expect(find.textContaining('조회 전용 원장이에요'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('amount')))
            .enabled,
        isFalse);
    expect(repository.calls, isEmpty);
  });
  testWidgets('저장 중 중복 탭을 막고 결과 불명 시 입력을 고정해 같은 UUID로 확인한다', (tester) async {
    final repository = WidgetLedger();
    final container = await mount(tester, repository: repository);
    container.read(routerProvider).go('/add');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('amount')), '25000');
    await tester.enterText(find.byKey(const ValueKey('merchant')), '검증 거래');
    await reveal(tester, find.byKey(const ValueKey('save')));
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(1));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save')))
            .onPressed,
        isNull);
    repository.firstWrite.completeError(
        const ConnectionFailure('결과 불명 테스트', uncertainWrite: true));
    await tester.pumpAndSettle();
    expect(find.text('저장 결과 다시 확인'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('amount')))
            .enabled,
        isFalse);
    await reveal(tester, find.byKey(const ValueKey('save')));
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(2));
    expect(repository.calls[1].id, repository.calls[0].id);
    expect(repository.calls[1].memberId, repository.actor.id);
    expect(find.textContaining('Sheets 재조회까지 확인했습니다'), findsOneWidget);
  });
}
