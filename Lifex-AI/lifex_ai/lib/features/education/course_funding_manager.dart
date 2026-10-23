/// =============================================================
/// Lifex-AI — وحدة التأهيل والتدريب
/// الملف: course_funding_manager.dart
/// المسار: lib/features/education/course_funding_manager.dart
/// الوصف: تصنيف الدورات حسب نموذج التمويل (مجاني/مدعوم/مدفوع) وإدارة
/// طلبات الدعم المالي للمتدربين ذوي الاحتياج.
/// =============================================================
library;

enum CourseFundingModel { free, subsidized, paid }

class CourseFundingInfo {
  final String courseId;
  final CourseFundingModel model;
  final double? fullPrice;
  final double? subsidizedPrice;

  const CourseFundingInfo({
    required this.courseId,
    required this.model,
    this.fullPrice,
    this.subsidizedPrice,
  });
}

enum SubsidyRequestStatus { pending, approved, rejected }

class SubsidyRequest {
  final String requestId;
  final String learnerId;
  final String courseId;
  SubsidyRequestStatus status;

  SubsidyRequest({
    required this.requestId,
    required this.learnerId,
    required this.courseId,
    this.status = SubsidyRequestStatus.pending,
  });
}

/// مدير تمويل الدورات.
class CourseFundingManager {
  CourseFundingManager();

  final Map<String, CourseFundingInfo> _fundingInfo = {};
  final List<SubsidyRequest> _subsidyRequests = [];
  int _counter = 0;

  void setFundingInfo(CourseFundingInfo info) {
    _fundingInfo[info.courseId] = info;
  }

  CourseFundingInfo? fundingInfoFor(String courseId) => _fundingInfo[courseId];

  /// السعر الفعلي الذي يجب على المتدرب دفعه، بناءً على نموذج التمويل
  /// وحالة طلب الدعم إن وُجد.
  double effectivePriceFor(String learnerId, String courseId) {
    final info = _fundingInfo[courseId];
    if (info == null) return 0.0;

    if (info.model == CourseFundingModel.free) return 0.0;

    if (info.model == CourseFundingModel.subsidized) {
      final hasApprovedSubsidy = _subsidyRequests.any((r) =>
          r.learnerId == learnerId &&
          r.courseId == courseId &&
          r.status == SubsidyRequestStatus.approved);
      if (hasApprovedSubsidy) return info.subsidizedPrice ?? 0.0;
    }

    return info.fullPrice ?? 0.0;
  }

  SubsidyRequest requestSubsidy({
    required String learnerId,
    required String courseId,
  }) {
    _counter++;
    final request = SubsidyRequest(
      requestId: 'SUB-$_counter',
      learnerId: learnerId,
      courseId: courseId,
    );
    _subsidyRequests.add(request);
    return request;
  }

  bool approveSubsidy(String requestId) {
    final matches =
        _subsidyRequests.where((r) => r.requestId == requestId).toList();
    if (matches.isEmpty) return false;
    matches.first.status = SubsidyRequestStatus.approved;
    return true;
  }

  bool rejectSubsidy(String requestId) {
    final matches =
        _subsidyRequests.where((r) => r.requestId == requestId).toList();
    if (matches.isEmpty) return false;
    matches.first.status = SubsidyRequestStatus.rejected;
    return true;
  }
}
