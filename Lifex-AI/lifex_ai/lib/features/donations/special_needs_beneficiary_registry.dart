/// =============================================================
/// Lifex-AI — التبرعات الإنسانية
/// الملف: special_needs_beneficiary_registry.dart
/// المسار: lib/features/donations/special_needs_beneficiary_registry.dart
/// الوصف: سجل الحالات الخاصة الموثّقة (ذوي احتياجات، أمراض مزمنة تحتاج
/// دعماً) المؤهلة لتلقي تبرعات، بعد التحقق من صحة توثيقها.
///
/// ⚠️ بيانات حساسة للغاية (حالة صحية + احتياج مادي). يجب عرض الحد
/// الأدنى الضروري فقط للمتبرعين (عبر alias)، مع إخفاء الهوية الكاملة
/// إلا بموافقة المستفيد الصريحة.
/// =============================================================
library;

enum BeneficiaryVerificationStatus { pendingReview, verified, rejected }

class SpecialNeedsBeneficiary {
  final String beneficiaryId;
  final String profileId;
  final String displayAliasAr;
  final String needCategoryAr;
  BeneficiaryVerificationStatus verificationStatus;

  SpecialNeedsBeneficiary({
    required this.beneficiaryId,
    required this.profileId,
    required this.displayAliasAr,
    required this.needCategoryAr,
    this.verificationStatus = BeneficiaryVerificationStatus.pendingReview,
  });
}

/// سجل المستفيدين ذوي الحالات الخاصة.
class SpecialNeedsBeneficiaryRegistry {
  SpecialNeedsBeneficiaryRegistry();

  final Map<String, SpecialNeedsBeneficiary> _beneficiaries = {};
  int _counter = 0;

  SpecialNeedsBeneficiary registerCase({
    required String profileId,
    required String displayAliasAr,
    required String needCategoryAr,
  }) {
    _counter++;
    final beneficiary = SpecialNeedsBeneficiary(
      beneficiaryId: 'BEN-$_counter',
      profileId: profileId,
      displayAliasAr: displayAliasAr,
      needCategoryAr: needCategoryAr,
    );
    _beneficiaries[beneficiary.beneficiaryId] = beneficiary;
    return beneficiary;
  }

  void setVerificationStatus(
    String beneficiaryId,
    BeneficiaryVerificationStatus status,
  ) {
    _beneficiaries[beneficiaryId]?.verificationStatus = status;
  }

  /// المستفيدون المؤهلون لتلقي تبرعات (تم التحقق منهم فقط).
  List<SpecialNeedsBeneficiary> verifiedBeneficiaries() {
    return _beneficiaries.values
        .where((b) => b.verificationStatus == BeneficiaryVerificationStatus.verified)
        .toList();
  }

  SpecialNeedsBeneficiary? getById(String beneficiaryId) =>
      _beneficiaries[beneficiaryId];
}
