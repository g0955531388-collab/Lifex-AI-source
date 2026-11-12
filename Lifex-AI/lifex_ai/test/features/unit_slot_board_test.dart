import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/network_box/unit_membership_desk.dart';
import 'package:lifex_ai/features/network_box/unit_slot_board.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  test('حجز الوحدة يملأ الحصة الفارغة ويُعلم الوحدة بلا اسم للعامة', () {
    final profile = HealthProfile(
      profileId: 'p1',
      fullName: 'ليان',
      statedAgeYears: 30,
    );
    final store = ProfileBoxStore(profile);
    const board = UnitSlotBoard(workHours: 1, stepMinutes: 30, startHour: 9);
    final day = DateTime(2026, 10, 14);

    expect(
        board.book(
          store: store,
          unitId: 'labs',
          patient: profile,
          day: day,
          time: '09:00',
        ),
        isNull);
    expect(
        board.book(
          store: store,
          unitId: 'labs',
          patient: profile,
          day: day,
          time: '09:00',
        ),
        'الحصة محجوزة.');

    final shown = board.publicSlots(store, 'labs', day);
    expect(shown.first['booked'], isTrue);
    expect(shown.first.containsKey('alias'), isFalse);
    expect(
        board.book(
          store: store,
          unitId: 'labs',
          patient: profile,
          day: day,
          time: '09:30',
          prepaidMinor: 1500,
        ),
        isNull);
    final stored =
        store.list(UnitSlotBoard.slotsKey('labs')).single['slots'] as List;
    final paid =
        stored.cast<Map>().firstWhere((item) => item['time'] == '09:30');
    expect(paid['prepaidMinor'], 1500);
    expect(paid['prepaidStatus'], 'pending');
    expect(
      board
          .publicSlots(store, 'labs', day)
          .any((slot) => slot.containsKey('prepaidMinor')),
      isFalse,
    );
    expect(
      UnitMembershipDesk().notices(store, 'labs').last['detail'].toString(),
      contains('معلّق'),
    );
  });

  test('إلغاء الحجز يحرّر الحصة ويطلب استرداد المبلغ بعد العمولة', () {
    final profile = HealthProfile(
      profileId: 'p1',
      fullName: 'ليان',
      statedAgeYears: 30,
    );
    final other = HealthProfile(
      profileId: 'p2',
      fullName: 'سامر',
      statedAgeYears: 40,
    );
    final store = ProfileBoxStore(profile);
    const board = UnitSlotBoard(workHours: 1, stepMinutes: 30, startHour: 9);
    final day = DateTime(2026, 10, 14);

    expect(
      board.book(
        store: store,
        unitId: 'labs',
        patient: profile,
        day: day,
        time: '09:00',
      ),
      isNull,
    );
    final before = DateTime(2026, 10, 14, 8);
    expect(
      board
          .cancel(
            store: store,
            unitId: 'labs',
            patient: profile,
            day: day,
            time: '09:00',
            now: before,
          )
          .prepaidMinor,
      0,
    );
    expect(board.publicSlots(store, 'labs', day).first['booked'], isFalse);
    expect(store.list(UnitSlotBoard.refundsKey('labs')), isEmpty);

    expect(
      board.book(
        store: store,
        unitId: 'labs',
        patient: profile,
        day: day,
        time: '09:30',
        prepaidMinor: 1500,
      ),
      isNull,
    );
    expect(
      board
          .cancel(
            store: store,
            unitId: 'labs',
            patient: other,
            day: day,
            time: '09:30',
            now: before,
          )
          .errorAr,
      'إلغاء الحجز لصاحب الحصة فقط.',
    );
    final result = board.cancel(
      store: store,
      unitId: 'labs',
      patient: profile,
      day: day,
      time: '09:30',
      now: before,
    );
    expect(result.errorAr, isNull);
    expect(result.commissionMinor, 75);
    expect(result.refundMinor, 1425);
    expect(board.publicSlots(store, 'labs', day).last['booked'], isFalse);
    final refund = store.list(UnitSlotBoard.refundsKey('labs')).single;
    expect(refund['status'], 'refundRequested');
    expect(refund['commissionMinor'], 75);
    expect(refund['refundMinor'], 1425);
    expect(refund.containsKey('card'), isFalse);
    expect(
      board.book(
        store: store,
        unitId: 'labs',
        patient: profile,
        day: day,
        time: '09:30',
      ),
      isNull,
    );
  });

  test('غياب الحصة يُسقط حق المبلغ المدفوع للوحدة', () {
    final profile = HealthProfile(
      profileId: 'p1',
      fullName: 'ليان',
      statedAgeYears: 30,
    );
    final other = HealthProfile(
      profileId: 'p2',
      fullName: 'سامر',
      statedAgeYears: 40,
    );
    final store = ProfileBoxStore(profile);
    const board = UnitSlotBoard(workHours: 1, stepMinutes: 30, startHour: 9);
    final day = DateTime(2026, 10, 14);
    expect(
      board.book(
        store: store,
        unitId: 'labs',
        patient: profile,
        day: day,
        time: '09:30',
        prepaidMinor: 1500,
      ),
      isNull,
    );
    expect(
      board.markAttended(
        store: store,
        unitId: 'labs',
        patient: other,
        day: day,
        time: '09:30',
        now: DateTime(2026, 10, 14, 9, 40),
      ),
      'تسجيل الحضور لصاحب الحصة فقط.',
    );
    expect(
      board.settleNoShows(
        store: store,
        unitId: 'labs',
        day: day,
        now: DateTime(2026, 10, 14, 10),
      ),
      1,
    );
    expect(
      board.settleNoShows(
        store: store,
        unitId: 'labs',
        day: day,
        now: DateTime(2026, 10, 14, 10),
      ),
      0,
    );
    final missed = store.list(UnitSlotBoard.refundsKey('labs')).single;
    expect(missed['status'], 'forfeited');
    expect(missed['refundMinor'], 0);
    expect(missed['unitMinor'], 1425);
    expect(missed['commissionMinor'], 75);
    expect(
      board
          .publicSlots(store, 'labs', day)
          .any((slot) => slot.containsKey('unitMinor')),
      isFalse,
    );

    expect(
      board.book(
        store: store,
        unitId: 'labs',
        patient: profile,
        day: day,
        time: '09:00',
        prepaidMinor: 1500,
      ),
      isNull,
    );
    expect(
      board.markAttended(
        store: store,
        unitId: 'labs',
        patient: profile,
        day: day,
        time: '09:00',
        now: DateTime(2026, 10, 14, 9, 10),
      ),
      isNull,
    );
    expect(
      board.settleNoShows(
        store: store,
        unitId: 'labs',
        day: day,
        now: DateTime(2026, 10, 14, 10),
      ),
      0,
    );
    expect(
      board
          .cancel(
            store: store,
            unitId: 'labs',
            patient: profile,
            day: day,
            time: '09:00',
            now: DateTime(2026, 10, 14, 9, 20),
          )
          .errorAr,
      'الحضور سُجّل خلال الحصة. مبلغ الوحدة يبقى لها.',
    );
  });
}
