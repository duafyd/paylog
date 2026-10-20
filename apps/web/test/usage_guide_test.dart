import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/app/app.dart';
import 'widget_test.dart' show mount, reveal;

void main() {
  for (final config in [(360.0, 1.6), (393.0, 1.0), (402.0, 1.0)]) {
    testWidgets('휴대폰 가이드 탐색과 긴 안내 스크롤 ${config.$1}/${config.$2}',
        (tester) async {
      final container = await mount(tester, width: config.$1, scale: config.$2);
      container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      final entry = find.text('Android · iPhone 사용 가이드');
      await reveal(tester, entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('휴대폰 사용 가이드'), findsOneWidget);
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          3);
      for (final title in [
        'Android · 홈 화면에 설치',
        'Android · 문자 자동 수집',
        'APK 다운로드 주소 복사',
        'iPhone · 홈 화면에 설치',
        'iPhone · 문자 전송 단축어',
        '연결·수집이 안 될 때',
        '설정으로 돌아가기',
      ]) {
        await reveal(tester, find.text(title));
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('설정으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(find.text('우리 집 가계부'), findsOneWidget);
    });
  }
}
