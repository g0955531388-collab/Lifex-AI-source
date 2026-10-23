/// شاشة الطبيب على الملف العام الموجود. ليست صفحة ويب ولا نشاط أندرويد.
library;

import '../../core/attribution/project_attribution.dart';
import '../location/gps_priority_monitor.dart';

abstract final class DoctorDesk {
  DoctorDesk._();

  static const String bannerAr = 'منظومة Lifex-AI للخدمات الصحية العالمية';

  /// مثال طبيب أو ترخيص أو إحداثيات ليس ملفاً.
  static const bool sampleProfileAllowed = false;

  /// الواجهة لا تُستضاف في WebView ولا تُفتح لها جسر جافاسكربت.
  static const bool webDashboardAllowed = false;

  /// رسالة على الشاشة ليست إرسال وصفة ولا موافقة صيدلي على السجل.
  static const bool toastIsPrescriptionDelivery = false;

  static const bool placeFollowsLocationSystem =
      GpsPriorityMonitor.userPlaceFieldsStartEmpty &&
          !GpsPriorityMonitor.inventedCoordinatesAllowed;

  static String shareFooter() =>
      '$bannerAr\n${ProjectAttribution.officialStatementShortAr}';
}
