/// شاشة الصيدلاني على الملف العام الموجود. ليست نشاط أندرويد مستقلاً.
library;

import '../../core/attribution/project_attribution.dart';
import '../location/gps_priority_monitor.dart';

abstract final class PharmacistDesk {
  PharmacistDesk._();

  static const String bannerAr =
      'اتحاد الصيادلة العالمي الإلكتروني عبر منظومة Lifex-AI';

  /// مثال شخص أو ترخيص أو إحداثيات أو نسبة شحن ليس ملفاً.
  static const bool sampleProfileAllowed = false;

  /// المكان يتبع نظام الموقع الحالي: مدينة أو مسافة يكتبها صاحب الحساب.
  static const bool placeFollowsLocationSystem =
      GpsPriorityMonitor.userPlaceFieldsStartEmpty &&
          !GpsPriorityMonitor.inventedCoordinatesAllowed;

  /// نسبة الشحن ليست رسماً عاماً محفوظاً.
  static const bool publicShippingPercentIsFee = false;

  /// نداء الدم يبقى على شبكة الدم، بلا تكرار كل دقيقة من شاشة الصيدلية.
  static const int bloodFlashRepeats = 0;

  static String shareFooter() =>
      '$bannerAr\n${ProjectAttribution.officialStatementShortAr}';
}
