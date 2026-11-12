import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/energy/battery_monitor.dart';
import 'package:lifex_ai/features/energy/phone_battery_brief.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  test('بلا قياس لا تُخترع نسبة', () {
    final speech = PhoneBatterySpeech.unread();
    expect(speech.measured, isFalse);
    expect(speech.arabic, contains('لن أخترع'));
    expect(speech.arabic, isNot(contains('100')));
  });

  test('العتبات لا تتكرر حتى ترتفع النسبة', () {
    final gate = BatteryAlertGate();
    final first = gate.onReading(level: 15, charging: false, english: false);
    expect(first.single, contains('20'));

    final again = gate.onReading(level: 14, charging: false, english: false);
    expect(again, isEmpty);

    final lower = gate.onReading(level: 9, charging: false, english: false);
    expect(lower.single, contains('10'));

    final still = gate.onReading(level: 8, charging: false, english: false);
    expect(still, isEmpty);

    gate.onReading(level: 25, charging: false, english: false);
    final afterRise = gate.onReading(level: 18, charging: false, english: false);
    expect(afterRise.single, contains('20'));
  });

  test('بدء الشحن وفصله يُقالان مرة عند التغيّر', () {
    final gate = BatteryAlertGate();
    expect(
      gate.onReading(level: 40, charging: false, english: false),
      isEmpty,
    );
    expect(
      gate.onReading(level: 40, charging: true, english: false).single,
      'بدأ الشحن.',
    );
    expect(
      gate.onReading(level: 41, charging: true, english: false),
      isEmpty,
    );
    expect(
      gate.onReading(level: 41, charging: false, english: false).single,
      'انفصل الشاحن.',
    );
  });

  test('أمر الشحن يُفهم والمراقب الفارغ لا يقرأ 100', () {
    expect(
      CommandParser().parse('كم شحن الجوال؟').intent,
      VoiceCommandIntent.phoneBattery,
    );
    expect(
      CommandParser().parse('بطارية الكرسي').intent,
      VoiceCommandIntent.wheelchairReadBattery,
    );
    final speech = PhoneBatterySpeech.fromMonitor(BatteryMonitor());
    expect(speech.measured, isFalse);
    expect(speech.arabic, isNot(contains('100')));
  });

  test('قراءة موجودة تُنطق النسبة وحالة الشحن', () {
    final speech = PhoneBatterySpeech.fromReading(level: 47, charging: true);
    expect(speech.measured, isTrue);
    expect(speech.arabic, contains('47'));
    expect(speech.arabic, contains('يُشحن'));
  });
}
