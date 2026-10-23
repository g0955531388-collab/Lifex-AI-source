/// شاشة الأسنان على الملف العام الموجود. ليست وحدة أندرويد مستقلة.
library;

import '../../core/attribution/project_attribution.dart';
import '../location/gps_priority_monitor.dart';

abstract final class DentalDesk {
  DentalDesk._();

  static const String bannerAr = 'منظومة Lifex-AI للخدمات الصحية العالمية';

  static const bool sampleCatalogAllowed = false;
  static const bool autoSuggestFromCoordinatesAllowed = false;
  static const bool publicFollowOfPatientAllowed = false;
  static const bool donationAmountIsDouble = false;
  static const bool emergencyBroadcastAllowed = false;

  static const bool placeFollowsLocationSystem =
      GpsPriorityMonitor.userPlaceFieldsStartEmpty &&
          !GpsPriorityMonitor.inventedCoordinatesAllowed;

  static String shareFooter() =>
      '$bannerAr\n${ProjectAttribution.officialStatementShortAr}';
}
