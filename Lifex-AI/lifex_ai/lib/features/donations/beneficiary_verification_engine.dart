/// =============================================================
/// Lifex-AI — التبرعات الإنسانية
/// الملف: beneficiary_verification_engine.dart
/// المسار: lib/features/donations/beneficiary_verification_engine.dart
/// الوصف: عملية التحقق من صحة توثيق حالة المستفيد (بطاقة إعاقة، تقرير
/// طبي) قبل قبوله في سجل special_needs_beneficiary_registry.dart.
///
/// ⚠️ التحقق الفعلي عبر OCR ومطابقة مع جهات رسمية يتطلب شراكات حكومية/
/// مؤسسية حقيقية وخادماً مركزياً؛ هذا الملف يوفر بنية سير العمل (workflow)
/// فقط، والقرار النهائي يجب أن يتخذه مراجع بشري مؤهل دائماً، وليس آلة.
/// =============================================================
library;

import 'special_needs_beneficiary_registry.dart';

enum DocumentType { disabilityCard, medicalReport, socialWorkerReferral }

class VerificationSubmission {
  final String submissionId;
  final String beneficiaryId;
  final DocumentType documentType;
  final String documentStorageReference;
  bool reviewedByHuman;

  VerificationSubmission({
    required this.submissionId,
    required this.beneficiaryId,
    required this.documentType,
    required this.documentStorageReference,
    this.reviewedByHuman = false,
  });
}

/// محرك التحقق من حالة المستفيد — سير عمل تنظيمي فقط، لا يتخذ قرار
/// القبول/الرفض النهائي آلياً.
class BeneficiaryVerificationEngine {
  BeneficiaryVerificationEngine({required this.registry});

  final SpecialNeedsBeneficiaryRegistry registry;
  final List<VerificationSubmission> _submissions = [];
  int _counter = 0;

  VerificationSubmission submitDocument({
    required String beneficiaryId,
    required DocumentType documentType,
    required String documentStorageReference,
  }) {
    _counter++;
    final submission = VerificationSubmission(
      submissionId: 'VER-$_counter',
      beneficiaryId: beneficiaryId,
      documentType: documentType,
      documentStorageReference: documentStorageReference,
    );
    _submissions.add(submission);
    return submission;
  }

  /// اعتماد الحالة بعد مراجعة بشرية فعلية — لا يجوز استدعاء هذه الدالة
  /// من أي منطق آلي مباشرة دون تأكيد مراجع بشري حقيقي أولاً.
  bool approveAfterHumanReview(String submissionId) {
    final submission =
        _submissions.where((s) => s.submissionId == submissionId).toList();
    if (submission.isEmpty) return false;

    submission.first.reviewedByHuman = true;
    registry.setVerificationStatus(
      submission.first.beneficiaryId,
      BeneficiaryVerificationStatus.verified,
    );
    return true;
  }

  bool rejectAfterHumanReview(String submissionId) {
    final submission =
        _submissions.where((s) => s.submissionId == submissionId).toList();
    if (submission.isEmpty) return false;

    submission.first.reviewedByHuman = true;
    registry.setVerificationStatus(
      submission.first.beneficiaryId,
      BeneficiaryVerificationStatus.rejected,
    );
    return true;
  }

  List<VerificationSubmission> get pendingHumanReview =>
      _submissions.where((s) => !s.reviewedByHuman).toList();
}
