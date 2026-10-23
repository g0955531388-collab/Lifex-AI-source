/// =============================================================
/// Lifex-AI — شبكة التبرع بالدم
/// الملف: standby_donor_manager.dart
/// المسار: lib/features/blood_network/standby_donor_manager.dart
/// الوصف: إدارة "وضع المتبرع الاحتياطي" — أشخاص يوافقون مسبقاً على
/// تفعيل استباقي لتلقي إشعارات استغاثة أولوية أعلى من غيرهم.
/// =============================================================
library;

import '../hospital/hospital_blood_bank.dart';

class StandbyDonorEnrollment {
  final String donorLifexId;
  final BloodTypeSimple bloodType;
  bool isActive;
  final DateTime enrolledAt;

  StandbyDonorEnrollment({
    required this.donorLifexId,
    required this.bloodType,
    this.isActive = true,
    DateTime? enrolledAt,
  }) : enrolledAt = enrolledAt ?? DateTime.now();
}

/// مدير المتبرعين الاحتياطيين.
class StandbyDonorManager {
  StandbyDonorManager();

  final Map<String, StandbyDonorEnrollment> _enrollments = {};

  StandbyDonorEnrollment enroll({
    required String donorLifexId,
    required BloodTypeSimple bloodType,
  }) {
    final enrollment = StandbyDonorEnrollment(
      donorLifexId: donorLifexId,
      bloodType: bloodType,
    );
    _enrollments[donorLifexId] = enrollment;
    return enrollment;
  }

  void pause(String donorLifexId) {
    _enrollments[donorLifexId]?.isActive = false;
  }

  void resume(String donorLifexId) {
    _enrollments[donorLifexId]?.isActive = true;
  }

  void withdraw(String donorLifexId) {
    _enrollments.remove(donorLifexId);
  }

  List<StandbyDonorEnrollment> activeStandbyForType(BloodTypeSimple bloodType) {
    return _enrollments.values
        .where((e) => e.isActive && e.bloodType == bloodType)
        .toList();
  }
}
