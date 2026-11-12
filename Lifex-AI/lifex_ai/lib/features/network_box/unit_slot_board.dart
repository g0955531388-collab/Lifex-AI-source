/// =============================================================
/// Lifex-AI — صندوق المشروع
/// حجز حصة لدى أي وحدة، بنفس قاعدة الطبيب: فراغ ثم حجز، بلا حصص مختلقة.
/// التأكيد خارج هذا الجهاز غير مثبت.
/// =============================================================
library lifex_ai.features.network_box.unit_slot_board;

import '../care_cycle/care_cycle_desk.dart';
import '../doctors/clinic_day_board.dart';
import '../doctors/public_slot_policy.dart';
import '../finance/billing_exemption_policy.dart';
import '../profile/health_profile.dart';
import 'profile_box_store.dart';
import 'unit_membership_desk.dart';

class UnitCancelResult {
  const UnitCancelResult({
    this.errorAr,
    this.refundMinor = 0,
    this.commissionMinor = 0,
    this.prepaidMinor = 0,
    this.forfeited = false,
  });

  final String? errorAr;
  final int refundMinor;
  final int commissionMinor;
  final int prepaidMinor;
  final bool forfeited;
}

class _SlotMoney {
  const _SlotMoney({
    required this.prepaid,
    required this.kept,
    required this.unitShare,
    required this.currency,
  });

  final int prepaid;
  final int kept;
  final int unitShare;
  final String currency;
}

class UnitSlotBoard {
  const UnitSlotBoard({
    this.workHours = 12,
    this.stepMinutes = 30,
    this.startHour = 9,
  });

  final int workHours;
  final int stepMinutes;
  final int startHour;

  static String slotsKey(String unitId) => 'unitSlots_$unitId';

  static String refundsKey(String unitId) => 'unitRefunds_$unitId';

  static String dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  List<String> clocks() => const PublicSlotPolicy().clocksFor(
        workHours: workHours,
        stepMinutes: stepMinutes,
        startHour: startHour,
      );

  List<Map<String, dynamic>> publicSlots(
    ProfileBoxStore store,
    String unitId,
    DateTime day,
  ) {
    final stored = _slots(store, unitId, day);
    return [
      for (final clock in clocks())
        {
          'time': clock,
          'booked': stored.any(
            (item) => item['time'] == clock && item['booked'] == true,
          ),
        },
    ];
  }

  /// يعيد null عند النجاح، ونصاً عربياً إذا كانت الحصة مأخوذة.
  String? book({
    required ProfileBoxStore store,
    required String unitId,
    required HealthProfile patient,
    required DateTime day,
    required String time,
    int prepaidMinor = 0,
    String currencyCode = 'USD',
  }) {
    if (!clocks().contains(time)) {
      return 'هذه الحصة ليست ضمن دوام الوحدة.';
    }
    if (prepaidMinor < 0) {
      return 'مبلغ الدفع المسبق يُكتب رقماً صحيحاً بالوحدة الصغرى.';
    }
    final slots = _ensureDay(store, unitId, day);
    final index = slots.indexWhere((item) => item['time'] == time);
    if (index < 0 || slots[index]['booked'] == true) {
      return 'الحصة محجوزة.';
    }
    slots[index]['booked'] = true;
    slots[index]['alias'] = patient.fullName;
    slots[index]['linkedProfileId'] = patient.profileId;
    var commission = 0;
    if (prepaidMinor > 0) {
      final exempt = const BillingExemptionPolicy().evaluate(patient).isExempt;
      commission = exempt
          ? 0
          : (prepaidMinor * CareCycleDesk.commissionPermille) ~/ 1000;
      slots[index]['prepaidMinor'] = prepaidMinor;
      slots[index]['commissionMinor'] = commission;
      slots[index]['currencyCode'] = currencyCode;
      slots[index]['prepaidStatus'] = 'pending';
      slots[index]['exempt'] = exempt;
    }
    _save(store, unitId, day, slots);
    final pay = prepaidMinor > 0
        ? ' دفع مسبق $prepaidMinor $currencyCode معلّق. '
            'الإلغاء قبل الحصة يطلب استرداد الباقي بعد عمولة النظام $commission. '
            'عدم الحضور خلال الحصة يُسقط حق المبلغ المدفوع للوحدة. '
            'لم يؤكد مزود مرخّص.'
        : '';
    store.add(UnitMembershipDesk.noticesKey(unitId), {
      'profileId': patient.profileId,
      'name': patient.fullName,
      'title': 'حجز حصة',
      'detail':
          '${patient.fullName}: حجز $time في ${dayKey(day)} على هذا الجهاز. '
              'ليست لوحة خارجية مؤكدة.$pay',
    });
    return null;
  }

  bool heldBy({
    required ProfileBoxStore store,
    required String unitId,
    required DateTime day,
    required String time,
    required String profileId,
  }) {
    return _slots(store, unitId, day).any(
      (item) =>
          item['time'] == time &&
          item['booked'] == true &&
          item['linkedProfileId'] == profileId,
    );
  }

  DateTime slotStart(DateTime day, String time) =>
      const PublicSlotPolicy().slotAt(day, time);

  DateTime slotEnd(DateTime day, String time) => slotStart(day, time)
      .add(Duration(minutes: stepMinutes < 5 ? 5 : stepMinutes));

  bool attendedBy({
    required ProfileBoxStore store,
    required String unitId,
    required DateTime day,
    required String time,
    required String profileId,
  }) {
    return _slots(store, unitId, day).any(
      (item) =>
          item['time'] == time &&
          item['booked'] == true &&
          item['linkedProfileId'] == profileId &&
          item['attended'] == true,
    );
  }

  /// الحضور يُسجَّل خلال الحصة فقط، وعلى هذا الجهاز.
  String? markAttended({
    required ProfileBoxStore store,
    required String unitId,
    required HealthProfile patient,
    required DateTime day,
    required String time,
    DateTime? now,
  }) {
    if (!clocks().contains(time)) {
      return 'هذه الحصة ليست ضمن دوام الوحدة.';
    }
    final slots = _slots(store, unitId, day);
    final index = slots.indexWhere((item) => item['time'] == time);
    if (index < 0 || slots[index]['booked'] != true) {
      return 'لا حجز لتسجيل حضوره.';
    }
    if (slots[index]['linkedProfileId'] != patient.profileId) {
      return 'تسجيل الحضور لصاحب الحصة فقط.';
    }
    final clock = now ?? DateTime.now();
    final open = !clock.isBefore(slotStart(day, time)) &&
        clock.isBefore(slotEnd(day, time));
    if (!open) return 'الحضور يُسجَّل خلال الحصة فقط.';
    if (slots[index]['attended'] == true) return null;
    slots[index]['attended'] = true;
    _save(store, unitId, day, slots);
    store.add(UnitMembershipDesk.noticesKey(unitId), {
      'profileId': patient.profileId,
      'name': patient.fullName,
      'title': 'حضور حصة',
      'detail':
          '${patient.fullName}: سُجّل حضوره في $time بتاريخ ${dayKey(day)} على هذا الجهاز.',
    });
    return null;
  }

  /// بعد نهاية الحصة بلا حضور: يسقط حق المبلغ المدفوع للوحدة. بلا حركة أموال.
  int settleNoShows({
    required ProfileBoxStore store,
    required String unitId,
    required DateTime day,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final slots = _slots(store, unitId, day);
    if (slots.isEmpty) return 0;
    var count = 0;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (slot['booked'] != true || slot['attended'] == true) continue;
      if (slot['noShow'] == true) continue;
      final time = slot['time']?.toString() ?? '';
      if (!clocks().contains(time)) continue;
      if (clock.isBefore(slotEnd(day, time))) continue;
      _forfeit(
        store: store,
        unitId: unitId,
        day: day,
        time: time,
        slot: slot,
      );
      count++;
    }
    if (count > 0) _save(store, unitId, day, slots);
    return count;
  }

  /// يعيد خطأ إن لم يُلغَ الحجز. الاسترداد طلب معلّق، بلا حركة أموال.
  UnitCancelResult cancel({
    required ProfileBoxStore store,
    required String unitId,
    required HealthProfile patient,
    required DateTime day,
    required String time,
    DateTime? now,
  }) {
    if (!clocks().contains(time)) {
      return const UnitCancelResult(
        errorAr: 'هذه الحصة ليست ضمن دوام الوحدة.',
      );
    }
    final slots = _slots(store, unitId, day);
    final index = slots.indexWhere((item) => item['time'] == time);
    if (index < 0 || slots[index]['booked'] != true) {
      return const UnitCancelResult(errorAr: 'لا حجز لإلغائه.');
    }
    if (slots[index]['linkedProfileId'] != patient.profileId) {
      return const UnitCancelResult(errorAr: 'إلغاء الحجز لصاحب الحصة فقط.');
    }
    if (slots[index]['attended'] == true) {
      return const UnitCancelResult(
        errorAr: 'الحضور سُجّل خلال الحصة. مبلغ الوحدة يبقى لها.',
      );
    }
    if (slots[index]['noShow'] == true) {
      return const UnitCancelResult(
        errorAr: 'سُجّل الغياب. سقط حق المبلغ المدفوع للوحدة.',
        forfeited: true,
      );
    }
    final clock = now ?? DateTime.now();
    final amounts = _amounts(slots[index]);
    if (!clock.isBefore(slotStart(day, time))) {
      _forfeit(
        store: store,
        unitId: unitId,
        day: day,
        time: time,
        slot: slots[index],
      );
      final release = clock.isBefore(slotEnd(day, time));
      if (release) {
        slots[index] =
            const ClinicEmptyBoard().emptySlot(index: index + 1, time: time);
      }
      _save(store, unitId, day, slots);
      return UnitCancelResult(
        refundMinor: 0,
        commissionMinor: amounts.kept,
        prepaidMinor: amounts.prepaid,
        forfeited: amounts.prepaid > 0,
      );
    }
    final prepaidMinor = amounts.prepaid;
    final kept = amounts.kept;
    final refundMinor = amounts.unitShare;
    final currency = amounts.currency;
    slots[index] =
        const ClinicEmptyBoard().emptySlot(index: index + 1, time: time);
    _save(store, unitId, day, slots);
    if (prepaidMinor > 0) {
      store.add(refundsKey(unitId), {
        'profileId': patient.profileId,
        'day': dayKey(day),
        'time': time,
        'prepaidMinor': prepaidMinor,
        'commissionMinor': kept,
        'refundMinor': refundMinor,
        'currencyCode': currency,
        'status': 'refundRequested',
      });
    }
    final pay = prepaidMinor > 0
        ? ' طُلب استرداد $refundMinor $currency. عمولة النظام $kept تبقى. '
            'المزود المرخّص غير مربوط فلم يُرجع مبلغ.'
        : '';
    store.add(UnitMembershipDesk.noticesKey(unitId), {
      'profileId': patient.profileId,
      'name': patient.fullName,
      'title': 'إلغاء حصة',
      'detail':
          '${patient.fullName}: ألغى $time في ${dayKey(day)} على هذا الجهاز.$pay',
    });
    return UnitCancelResult(
      refundMinor: refundMinor,
      commissionMinor: kept,
      prepaidMinor: prepaidMinor,
    );
  }

  _SlotMoney _amounts(Map<String, dynamic> slot) {
    final prepaidRaw = slot['prepaidMinor'];
    final prepaid = prepaidRaw is int && prepaidRaw > 0 ? prepaidRaw : 0;
    final stored = slot['commissionMinor'];
    final commission = prepaid == 0
        ? 0
        : (stored is int
            ? stored
            : (prepaid * CareCycleDesk.commissionPermille) ~/ 1000);
    final kept =
        commission < 0 ? 0 : (commission > prepaid ? prepaid : commission);
    final currency = slot['currencyCode']?.toString() ?? '';
    return _SlotMoney(
      prepaid: prepaid,
      kept: kept,
      unitShare: prepaid - kept,
      currency: currency.isEmpty ? 'USD' : currency,
    );
  }

  void _forfeit({
    required ProfileBoxStore store,
    required String unitId,
    required DateTime day,
    required String time,
    required Map<String, dynamic> slot,
  }) {
    if (slot['noShow'] == true) return;
    final amounts = _amounts(slot);
    final name = slot['alias']?.toString() ?? '';
    final profileId = slot['linkedProfileId']?.toString() ?? '';
    slot['noShow'] = true;
    if (amounts.prepaid > 0) {
      slot['prepaidStatus'] = 'forfeited';
      store.add(refundsKey(unitId), {
        'profileId': profileId,
        'day': dayKey(day),
        'time': time,
        'prepaidMinor': amounts.prepaid,
        'commissionMinor': amounts.kept,
        'unitMinor': amounts.unitShare,
        'refundMinor': 0,
        'currencyCode': amounts.currency,
        'status': 'forfeited',
        'reason': 'noShow',
      });
    }
    final pay = amounts.prepaid > 0
        ? ' سقط حقه في المبلغ المدفوع للوحدة (${amounts.unitShare} ${amounts.currency}). '
            'عمولة النظام ${amounts.kept} تبقى. المزود المرخّص غير مربوط فلم تُنقل أموال.'
        : ' لا مبلغ مدفوع.';
    store.add(UnitMembershipDesk.noticesKey(unitId), {
      'profileId': profileId,
      'name': name,
      'title': 'غياب عن الحصة',
      'detail':
          '$name: لم يُسجَّل حضوره في $time بتاريخ ${dayKey(day)} على هذا الجهاز.$pay',
    });
  }

  List<Map<String, dynamic>> _slots(
    ProfileBoxStore store,
    String unitId,
    DateTime day,
  ) {
    final key = dayKey(day);
    final rows =
        store.list(slotsKey(unitId)).where((item) => item['day'] == key);
    if (rows.isEmpty) return const [];
    final raw = rows.first['slots'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  List<Map<String, dynamic>> _ensureDay(
    ProfileBoxStore store,
    String unitId,
    DateTime day,
  ) {
    final existing = _slots(store, unitId, day);
    if (existing.isNotEmpty) return existing;
    final clocks = this.clocks();
    return [
      for (var i = 0; i < clocks.length; i++)
        const ClinicEmptyBoard().emptySlot(index: i + 1, time: clocks[i]),
    ];
  }

  void _save(
    ProfileBoxStore store,
    String unitId,
    DateTime day,
    List<Map<String, dynamic>> slots,
  ) {
    final key = dayKey(day);
    final days = store.list(slotsKey(unitId));
    days.removeWhere((item) => item['day'] == key);
    days.add({'day': key, 'slots': slots});
    store.setList(slotsKey(unitId), days);
  }
}
