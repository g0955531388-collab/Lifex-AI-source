import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/clock/clock_display.dart';
import 'package:lifex_ai/widgets/device_wall_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('الوقت والتاريخ من لحظة محلية بلا نشاط مستقل', () {
    const clock = DeviceWallClock();
    final moment = DateTime(2026, 10, 12, 9, 5, 7);
    expect(clock.timeLabel(moment), '09:05:07');
    expect(clock.dateLabel(moment), 'الاثنين، 12 أكتوبر 2026');
  });

  Future<Text> pumpFace(
    WidgetTester tester,
    double width, {
    ClockDisplaySettings display =
        const ClockDisplaySettings(digits: ClockDigitStyle.western),
    RegExp? pattern,
  }) async {
    SharedPreferences.setMockInitialValues({
      ClockDisplaySettings.storageKey: jsonEncode(display.toJson()),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: const DeviceWallClockView(showAlarms: false),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final digits = pattern ?? RegExp(r'^\d\d:\d\d$');
    final face = find.byWidgetPredicate(
      (w) => w is Text && digits.hasMatch(w.data ?? ''),
    );
    expect(face, findsOneWidget);
    return tester.widget<Text>(face);
  }

  testWidgets('الرمادي: أرقام سوداء ثابتة العرض بلا ثوانٍ ومن اليسار إلى اليمين',
      (tester) async {
    final text = await pumpFace(tester, 320);
    expect(text.textDirection, TextDirection.ltr);
    expect(text.maxLines, 1);
    expect(
      text.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(text.style?.color, ClockPalette.of(ClockFaceMode.gray).digit);
    expect(text.style?.shadows, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ضعيف البصر يختار الثواني', (tester) async {
    await pumpFace(
      tester,
      320,
      display: const ClockDisplaySettings(
        mode: ClockFaceMode.lowVision,
        lowVisionSeconds: true,
        digits: ClockDigitStyle.western,
      ),
      pattern: RegExp(r'^\d\d:\d\d:\d\d$'),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('12 ساعة بأرقام مشرقية ولاحقة', (tester) async {
    await pumpFace(
      tester,
      320,
      display: const ClockDisplaySettings(
        use24h: false,
        digits: ClockDigitStyle.eastern,
      ),
      pattern: RegExp(r'^[٠-٩][٠-٩]:[٠-٩][٠-٩]$'),
    );
    expect(
      find.byWidgetPredicate((w) =>
          w is Text && const {'ص', 'م', 'AM', 'PM'}.contains(w.data)),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('الساعة لا تُقص ولا تفيض على شاشة ضيقة', (tester) async {
    await pumpFace(tester, 90);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('اللمس المطوّل يفتح الساعة بملء الشاشة، واللمستان تكبّران',
      (tester) async {
    await pumpFace(tester, 320);
    await tester.longPress(find.byType(DeviceWallClockView));
    await tester.pumpAndSettle();
    expect(find.byType(ClockFullScreen), findsOneWidget);
    final before = tester.getSize(find.byType(ClockDigits).last);
    final gesture = find.descendant(
      of: find.byType(ClockFullScreen),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(gesture.first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(gesture.first);
    await tester.pumpAndSettle();
    final after = tester.getSize(find.byType(ClockDigits).last);
    expect(after.width, greaterThan(before.width));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
