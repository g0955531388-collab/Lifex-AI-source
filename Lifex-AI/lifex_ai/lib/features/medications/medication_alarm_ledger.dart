/// =============================================================
/// Lifex-AI — الأدوية
/// الملف: medication_alarm_ledger.dart
/// منبّهات لكل ملف في الحساب. ليست منبّهاً خفياً خارج التطبيق.
/// =============================================================
library lifex_ai.features.medications.medication_alarm_ledger;

import '../network_box/profile_box_store.dart';
import '../profile/health_profile.dart';
import 'medication_alarm_engine.dart';

class MedicationAlarmLedger {
  List<MedicationAlarm> forProfile(HealthProfile profile) =>
      ProfileBoxStore(profile)
          .activeRecords(BoxKeys.medicationAlarms)
          .map(MedicationAlarm.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList();

  List<MedicationAlarm> household(Iterable<HealthProfile> profiles) => [
        for (final profile in profiles) ...forProfile(profile),
      ];

  MedicationAlarm add({
    required HealthProfile profile,
    required String medicine,
    required int hour,
    required int minute,
  }) {
    final alarm = MedicationAlarm(
      id: 'MA-${DateTime.now().millisecondsSinceEpoch}',
      profileId: profile.profileId,
      personName: profile.fullName,
      medicine: medicine.trim(),
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
    ProfileBoxStore(profile).add(BoxKeys.medicationAlarms, alarm.toJson());
    return alarm;
  }

  void replace(HealthProfile profile, MedicationAlarm alarm) {
    final store = ProfileBoxStore(profile);
    final items = store.list(BoxKeys.medicationAlarms);
    final next = [
      for (final item in items)
        if (item['id'] == alarm.id) alarm.toJson() else item,
    ];
    store.setList(BoxKeys.medicationAlarms, next);
  }

  void remove(HealthProfile profile, String id) {
    ProfileBoxStore(profile).archiveById(BoxKeys.medicationAlarms, id);
  }
}
