import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/doctors/clinic_day_board.dart';
import 'package:lifex_ai/features/doctors/daily_clinic_clock.dart';
import 'package:lifex_ai/features/education/empowerment_chapters.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  test('جدول 12 حصة من التاسعة بربع ساعة ينتهي عند 11:45', () {
    final slots = const DailyClinicClock().buildDay(
      day: DateTime(2026, 9, 16),
      maxPatients: 12,
      examMinutes: 15,
      startHour: 9,
      startMinute: 0,
    );
    expect(slots, hasLength(12));
    expect(slots.first.clockLabel(), '09:00');
    expect(slots.last.clockLabel(), '11:45');
  });

  test('الموسوعة ليست فارغة وليست وعداً مالياً', () {
    final chapters = const EmpowermentLibrary().chapters();
    expect(chapters, hasLength(3));
    expect(chapters.first.bodyAr, isNot(contains('اربح بسرعة')));
    expect(chapters.last.bodyAr, contains('ليس وصفة استثمار'));
  });

  test('الأوامر تفتح اليوميات والموسوعة', () {
    final parser = CommandParser();
    expect(
      parser.parse('ليفكس يوميات الطبيب').intent,
      VoiceCommandIntent.openDoctorDiary,
    );
    expect(
      parser.parse('موسوعة التمكين').intent,
      VoiceCommandIntent.openEmpowermentLab,
    );
  });

  test('التوليد الفارغ لا يخترع مرضى والإحصاء يُعدّ الحجوزات الحقيقية فقط', () {
    final empty = const ClinicEmptyBoard().emptySlot(index: 1, time: '09:00');
    expect(empty['booked'], isFalse);
    expect(empty['alias'], isEmpty);
    final stats = ClinicDayStats.fromSlots([
      empty,
      {'booked': true, 'specialNeeds': true},
      {'booked': true, 'specialNeeds': false},
    ]);
    expect(stats.booked, 2);
    expect(stats.special, 1);
    expect(stats.free, 1);
    expect(
      const ClinicSlotMark(booked: false, specialNeeds: false).badgeAr(),
      'متاح',
    );
    expect(
      const PharmacyReviewGate(enabled: true, namedPharmaciesAr: 'صيدلية النور')
          .spokenAr(),
      contains('مقيّدة'),
    );
  });
}
