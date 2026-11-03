import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_config.dart';
import 'package:lifex_ai/features/clock/clock_announcer.dart';
import 'package:lifex_ai/features/clock/clock_chime.dart';
import 'package:lifex_ai/features/clock/clock_display.dart';
import 'package:lifex_ai/features/clock/speaking_alarm_book.dart';
import 'package:lifex_ai/features/location/device_location_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime at(int h, int m) => DateTime(2026, 10, 28, h, m);

SpeakingAlarm alarm(String name, int h, int m, {bool enabled = true}) =>
    SpeakingAlarm(
      id: name,
      name: name,
      hour: h,
      minute: m,
      enabled: enabled,
      latitude: 1,
      longitude: 1,
      radiusMeters: 200,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('النطق الطبيعي بالعربية', () {
    final cases = {
      at(13, 15): 'الساعة الواحدة والربع مساءً',
      at(6, 0): 'الساعة السادسة تماماً صباحاً',
      at(12, 0): 'الساعة الثانية عشرة تماماً ظهراً',
      at(0, 0): 'الساعة الثانية عشرة تماماً ليلاً',
      at(9, 30): 'الساعة التاسعة والنصف صباحاً',
      at(16, 20): 'الساعة الرابعة والثلث مساءً',
      at(16, 40): 'الساعة الخامسة إلا ثلثاً مساءً',
      at(11, 45): 'الساعة الثانية عشرة إلا ربعاً ظهراً',
      at(23, 45): 'الساعة الثانية عشرة إلا ربعاً ليلاً',
      at(7, 1): 'الساعة السابعة ودقيقة واحدة صباحاً',
      at(7, 2): 'الساعة السابعة ودقيقتان صباحاً',
      at(7, 5): 'الساعة السابعة و 5 دقائق صباحاً',
      at(22, 11): 'الساعة العاشرة و 11 دقيقة مساءً',
      at(10, 55): 'الساعة العاشرة و 55 دقيقة صباحاً',
    };
    cases.forEach((time, phrase) {
      test('${time.hour}:${time.minute}', () {
        expect(naturalTimeArabic(time), phrase);
        expect(naturalTimeArabic(time), isNot(contains(':')));
      });
    });
    test('بلا كلمة الساعة لعبارة المنبه', () {
      expect(naturalTimeArabic(at(6, 0), prefix: false), 'السادسة تماماً صباحاً');
    });
  });

  group('النطق الطبيعي بالإنجليزية', () {
    final cases = {
      at(13, 15): 'quarter past one in the afternoon',
      at(6, 0): "six o'clock in the morning",
      at(12, 0): 'noon',
      at(0, 0): 'midnight',
      at(9, 30): 'half past nine in the morning',
      at(19, 45): 'quarter to eight in the evening',
      at(11, 45): 'quarter to noon',
      at(23, 50): '10 minutes to midnight',
      at(22, 1): '1 minute past ten at night',
      at(14, 59): '1 minute to three in the afternoon',
    };
    cases.forEach((time, phrase) {
      test('${time.hour}:${time.minute}', () {
        expect(naturalTimeEnglish(time), phrase);
      });
    });
  });

  group('العرض: 12/24 ونمط الأرقام والثواني', () {
    test('24 ساعة بأرقام غربية', () {
      final label = clockFaceLabel(at(13, 5),
          use24h: true, seconds: false, eastern: false, arabicUi: true);
      expect(label.digits, '13:05');
      expect(label.suffix, isEmpty);
    });
    test('12 ساعة بلاحقة عربية وإنجليزية', () {
      final ar = clockFaceLabel(at(13, 5),
          use24h: false, seconds: false, eastern: false, arabicUi: true);
      expect(ar.digits, '01:05');
      expect(ar.suffix, 'م');
      final en = clockFaceLabel(at(0, 7),
          use24h: false, seconds: false, eastern: false, arabicUi: false);
      expect(en.digits, '12:07');
      expect(en.suffix, 'AM');
    });
    test('أرقام عربية مشرقية', () {
      final label = clockFaceLabel(at(9, 41),
          use24h: true, seconds: false, eastern: true, arabicUi: true);
      expect(label.digits, '٠٩:٤١');
    });
    test('نمط الأرقام يتبع لغة الواجهة ما لم يختر المستخدم', () {
      const follow = ClockDisplaySettings();
      expect(follow.easternDigits(arabicUi: true), isTrue);
      expect(follow.easternDigits(arabicUi: false), isFalse);
      const western = ClockDisplaySettings(digits: ClockDigitStyle.western);
      expect(western.easternDigits(arabicUi: true), isFalse);
    });
    test('الرمادي بلا ثوانٍ متحركة، وضعيف البصر يختار', () {
      expect(const ClockDisplaySettings().showSeconds, isFalse);
      expect(
        const ClockDisplaySettings(lowVisionSeconds: true).showSeconds,
        isFalse,
      );
      expect(
        const ClockDisplaySettings(
          mode: ClockFaceMode.lowVision,
          lowVisionSeconds: true,
        ).showSeconds,
        isTrue,
      );
    });
  });

  group('التباين', () {
    test('الرمادي يتجاوز WCAG AA وضعيف البصر يتجاوز AAA', () {
      final gray = ClockPalette.of(ClockFaceMode.gray);
      expect(contrastRatio(gray.face, gray.digit), greaterThanOrEqualTo(4.5));
      final low = ClockPalette.of(ClockFaceMode.lowVision);
      expect(contrastRatio(low.face, low.digit), greaterThanOrEqualTo(7));
    });
    test('وضع المكفوف شاشة شبه سوداء', () {
      final blind = ClockPalette.of(ClockFaceMode.blind);
      expect(blind.face.computeLuminance(), lessThan(0.01));
      expect(blind.digit.computeLuminance(), lessThan(0.05));
    });
  });

  group('حفظ إعداد الشكل', () {
    test('الافتراضي رمادي و24 ساعة وبلا إعلان', () async {
      SharedPreferences.setMockInitialValues({});
      final display = await ClockDisplaySettings.load();
      expect(display.mode, ClockFaceMode.gray);
      expect(display.use24h, isTrue);
      expect(display.autoAnnounce, ClockAutoAnnounce.off);
    });
    test('يبقى بعد إعادة الفتح', () async {
      SharedPreferences.setMockInitialValues({});
      await const ClockDisplaySettings(
        mode: ClockFaceMode.lowVision,
        use24h: false,
        digits: ClockDigitStyle.eastern,
        lowVisionSeconds: true,
        autoAnnounce: ClockAutoAnnounce.quarterly,
      ).save();
      final back = await ClockDisplaySettings.load();
      expect(back.mode, ClockFaceMode.lowVision);
      expect(back.use24h, isFalse);
      expect(back.digits, ClockDigitStyle.eastern);
      expect(back.showSeconds, isTrue);
      expect(back.autoAnnounce, ClockAutoAnnounce.quarterly);
    });
  });

  group('المنبه التالي', () {
    test('الأقرب بعد الآن، ويلتف إلى الغد', () {
      final reply = nextAlarmReply(
        [alarm('العمل', 6, 0), alarm('الدواء', 21, 30), alarm('مطفأ', 20, 0, enabled: false)],
        at(20, 15),
      );
      expect(reply.ar, 'المنبه التالي الدواء، الساعة التاسعة والنصف مساءً.');
      final tomorrow = nextAlarmReply([alarm('العمل', 6, 0)], at(20, 15));
      expect(tomorrow.en, "Next alarm: العمل, six o'clock in the morning.");
    });
    test('بلا منبه مفعّل لا يخترع موعداً', () {
      expect(nextAlarmReply(const [], at(8, 0)).ar, 'لا منبه مفعّل.');
    });
  });

  group('الإعلان الدوري', () {
    setUp(() => AppConfig.instance.explicitLanguage = AppLanguage.arabic);
    tearDown(() => AppConfig.instance.explicitLanguage = null);

    Future<List<String>> tickAt(DateTime time) async {
      final spoken = <String>[];
      await SpeakingAlarmWatch.instance.tick(
        time,
        fix: const DeviceLocationRead(messageAr: ''),
        speak: (text) async => spoken.add(text),
        tone: (ref, volume) async => true,
      );
      return spoken;
    }

    test('مطفأ افتراضياً', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await tickAt(DateTime(2026, 11, 1, 9, 0)), isEmpty);
    });

    test('كل ربع ساعة مرة واحدة، وبلا إعلان خارج الربع', () async {
      SharedPreferences.setMockInitialValues({});
      await const ClockDisplaySettings(
        autoAnnounce: ClockAutoAnnounce.quarterly,
      ).save();
      final first = await tickAt(DateTime(2026, 11, 2, 9, 15));
      expect(first.length, 1);
      expect(first.single, contains('التاسعة والربع'));
      expect(await tickAt(DateTime(2026, 11, 2, 9, 15)), isEmpty);
      expect(await tickAt(DateTime(2026, 11, 2, 9, 16)), isEmpty);
    });

    test('إيقاف الاثنين يُسكت الإعلان الدوري', () async {
      SharedPreferences.setMockInitialValues({});
      await const ClockDisplaySettings(
        autoAnnounce: ClockAutoAnnounce.hourly,
      ).save();
      await const ClockChimeSettings(order: ChimeOrder.off).save();
      expect(await tickAt(DateTime(2026, 11, 3, 10, 0)), isEmpty);
    });

    test('المنبه يرن بالنطق الطبيعي لا بالأرقام', () async {
      SharedPreferences.setMockInitialValues({});
      await const SpeakingAlarmBook().save([alarm('العمل', 6, 0)]);
      final spoken = await tickAt(DateTime(2026, 11, 4, 6, 0));
      expect(spoken.single, contains('منبه العمل'));
      expect(spoken.single, contains('السادسة تماماً صباحاً'));
      expect(spoken.single, isNot(contains('06:00')));
    });

    test('بالإنجليزية حين تكون الواجهة إنجليزية', () async {
      AppConfig.instance.explicitLanguage = AppLanguage.english;
      SharedPreferences.setMockInitialValues({});
      await const SpeakingAlarmBook().save([alarm('work', 7, 30)]);
      final spoken = await tickAt(DateTime(2026, 11, 5, 7, 30));
      expect(spoken.single,
          'Alarm work. The time is half past seven in the morning. The place could not be confirmed.');
      await const ClockDisplaySettings(
        autoAnnounce: ClockAutoAnnounce.hourly,
      ).save();
      expect(await tickAt(DateTime(2026, 11, 5, 8, 0)),
          ["It's eight o'clock in the morning."]);
    });
  });
}
