import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/widgets/device_wall_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('الوقت والتاريخ من لحظة محلية بلا نشاط مستقل', () {
    const clock = DeviceWallClock();
    final moment = DateTime(2026, 10, 12, 9, 5, 7);
    expect(clock.timeLabel(moment), '09:05:07');
    expect(clock.dateLabel(moment), 'الاثنين، 12 أكتوبر 2026');
  });

  Future<Text> pumpFace(WidgetTester tester, double width) async {
    SharedPreferences.setMockInitialValues({});
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
    final face = find.byWidgetPredicate(
      (w) => w is Text && RegExp(r'^\d\d:\d\d:\d\d$').hasMatch(w.data ?? ''),
    );
    expect(face, findsOneWidget);
    return tester.widget<Text>(face);
  }

  testWidgets('أرقام الساعة ثابتة العرض ومن اليسار إلى اليمين في الواجهة العربية',
      (tester) async {
    final text = await pumpFace(tester, 320);
    expect(text.textDirection, TextDirection.ltr);
    expect(text.maxLines, 1);
    expect(
      text.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('الساعة لا تُقص ولا تفيض على شاشة ضيقة', (tester) async {
    await pumpFace(tester, 90);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
