import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/app/app.dart';
import 'package:paylog/features/transactions/transaction.dart';
import 'package:paylog/features/transactions/transaction_repository.dart';

Future<ProviderContainer> mount(WidgetTester tester,
    {double width = 390, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    clockProvider.overrideWithValue(() => DateTime(2026, 10, 20, 12))
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const PaylogApp()));
  await tester.pumpAndSettle();
  return container;
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 390.0, 393.0, 402.0, 430.0, 1024.0]) {
    testWidgets('달력과 모든 탭이 $width px에서 overflow 없이 렌더링된다', (tester) async {
      final container = await mount(tester, width: width);
      expect(find.text('paylog'), findsOneWidget);
      expect(find.text('₩180,600'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final path in [
        '/statistics',
        '/add',
        '/settings',
        '/google-connection'
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('360px와 큰 글씨에서도 주요 화면을 사용할 수 있다', (tester) async {
    final container = await mount(tester, width: 360, scale: 1.6);
    for (final path in [
      '/',
      '/statistics',
      '/add',
      '/settings',
      '/google-connection'
    ]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
    }
  });
  testWidgets('OAuth 미설정 상태를 안내하고 샘플 원장을 유지한다', (tester) async {
    final container = await mount(tester);
    container.read(routerProvider).go('/google-connection');
    await tester.pumpAndSettle();
    expect(find.text('웹 OAuth 설정이 필요해요'), findsOneWidget);
    expect(find.text('Google 로그인'), findsNothing);
    expect(container.read(transactionsProvider), hasLength(6));
  });
  testWidgets('날짜 선택과 연말 월 이동, 빈 상태를 지원한다', (tester) async {
    final container = await mount(tester);
    await reveal(tester, find.byKey(const ValueKey('day-2026-10-8')));
    await tester.tap(find.byKey(const ValueKey('day-2026-10-8')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider).day, 8);
    expect(find.text('주말의 식탁'), findsOneWidget);
    container.read(visibleMonthProvider.notifier).state = DateTime(2026, 12);
    await tester.pumpAndSettle();
    await reveal(tester, find.byTooltip('다음 달'));
    await tester.tap(find.byTooltip('다음 달'));
    await tester.pumpAndSettle();
    expect(find.text('2027년 1월'), findsOneWidget);
    expect(find.text('₩0'), findsNWidgets(5));
    expect(find.textContaining('아직 기록이 없는 날'), findsOneWidget);
  });
  for (final income in [false, true]) {
    testWidgets('${income ? '수입' : '지출'} 입력 검증 후 한 번만 저장되고 달력에 반영된다',
        (tester) async {
      final container = await mount(tester);
      await tester.tap(find.text('등록'));
      await tester.pumpAndSettle();
      if (income) {
        await tester.tap(find.text('수입'));
        await tester.pumpAndSettle();
      }
      await reveal(tester, find.byKey(const ValueKey('save')));
      await tester.tap(find.byKey(const ValueKey('save')));
      await tester.pumpAndSettle();
      expect(container.read(transactionsProvider), hasLength(6));
      await reveal(tester, find.byKey(const ValueKey('amount')));
      await tester.enterText(find.byKey(const ValueKey('amount')), '0');
      await tester.enterText(find.byKey(const ValueKey('merchant')), '테스트 기록');
      await reveal(tester, find.byKey(const ValueKey('save')));
      await tester.tap(find.byKey(const ValueKey('save')));
      await tester.pumpAndSettle();
      expect(container.read(transactionsProvider), hasLength(6));
      await reveal(tester, find.byKey(const ValueKey('amount')));
      await tester.enterText(find.byKey(const ValueKey('amount')), '25000');
      await reveal(tester, find.byKey(const ValueKey('save')));
      await tester.tap(find.byKey(const ValueKey('save')));
      await tester.pumpAndSettle();
      final items = container.read(transactionsProvider);
      expect(items, hasLength(7));
      expect(items.last.amount, 25000);
      expect(items.last.type,
          income ? TransactionType.income : TransactionType.expense);
      expect(find.text('테스트 기록'), findsOneWidget);
      expect(find.textContaining('거래를 저장했어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
