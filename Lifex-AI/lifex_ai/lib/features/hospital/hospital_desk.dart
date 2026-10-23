/// شاشة المستشفى على الملف العام الموجود. ليست وحدة أندرويد مستقلة.
library;

import '../../core/attribution/project_attribution.dart';
import '../location/gps_priority_monitor.dart';

abstract final class HospitalDesk {
  HospitalDesk._();

  static const String bannerAr = 'منظومة Lifex-AI للخدمات الصحية العالمية';

  /// قائمة جاهزة أو إحداثيات أو مرضى مزمنون ليست سجلاً.
  static const bool sampleCatalogAllowed = false;

  /// لا يُختار مستشفى من مسافة مختلقة. المكان يكتبه صاحب الحساب.
  static const bool autoSuggestFromCoordinatesAllowed = false;

  static const bool placeFollowsLocationSystem =
      GpsPriorityMonitor.userPlaceFieldsStartEmpty &&
          !GpsPriorityMonitor.inventedCoordinatesAllowed;

  /// مبلغ التبرع وحدات صغرى صحيحة، وليس عدداً عشرياً.
  static const bool donationAmountIsDouble = false;

  /// الطوارئ تبقى على مدير الطوارئ. لا بث باسم مريض.
  static const bool emergencyBroadcastAllowed = false;

  /// خطة لقاح هنا ليست جدولاً وطنياً ولا أمر جرعة.
  static const bool vaccinePlanIsSchedule = false;

  static String shareFooter() =>
      '$bannerAr\n${ProjectAttribution.officialStatementShortAr}';
}
