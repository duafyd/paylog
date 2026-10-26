import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paylog/core/widgets/service_intro.dart';
import 'widget_test.dart' show mount;

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets(
        'guest homepage retains service explanation and policy actions at $scale text scale',
        (tester) async {
      await mount(tester, width: 360, scale: scale);
      expect(find.byType(ServiceIntro), findsOneWidget);
      expect(find.textContaining('Google Sheets 원장에'), findsOneWidget);
      for (final label in ['개인정보처리방침', '서비스 이용약관']) {
        final button = find.widgetWithText(TextButton, label);
        expect(button, findsOneWidget);
        expect(tester.widget<TextButton>(button).onPressed, isNotNull);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
