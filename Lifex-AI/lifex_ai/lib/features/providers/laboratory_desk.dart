/// شاشة المختبر على الملف العام الموجود. ليست نشاط أندرويد مستقلاً.
library;

import '../../core/attribution/project_attribution.dart';
import '../location/gps_priority_monitor.dart';

abstract final class LaboratoryDesk {
  LaboratoryDesk._();

  static const String bannerAr = 'منظومة Lifex-AI للخدمات الصحية العالمية';

  /// مثال مختبر أو ترخيص أو مريض أو إحداثيات ليس ملفاً.
  static const bool sampleProfileAllowed = false;

  /// النتيجة ملاحظة يكتبها صاحب الحساب. ليست تشخيصاً ولا حكماً جاهزاً.
  static const bool resultIsDiagnosis = false;
  static const bool normalResultPresetAllowed = false;

  /// المكان مدينة أو مسافة يكتبها صاحب الحساب.
  static const bool placeFollowsLocationSystem =
      GpsPriorityMonitor.userPlaceFieldsStartEmpty &&
          !GpsPriorityMonitor.inventedCoordinatesAllowed;

  static String shareFooter() =>
      '$bannerAr\n${ProjectAttribution.officialStatementShortAr}';
}
