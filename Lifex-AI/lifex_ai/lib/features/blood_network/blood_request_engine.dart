/// =============================================================
/// Lifex-AI — شبكة التبرع بالدم
/// الملف: blood_request_engine.dart
/// المسار: lib/features/blood_network/blood_request_engine.dart
/// الوصف: المحرك المركزي لطلبات الدم — ينسّق بين فلترة المتبرعين
/// المؤهلين، توسيع النطاق الجغرافي، والإشعارات الفورية.
/// =============================================================
library;

import '../hospital/hospital_blood_bank.dart';
import 'donor_eligibility_filter.dart';
import 'flash_alert_notifier.dart';
import 'geo_expansion_dispatcher.dart';

enum BloodRequestUrgency { routine, urgent, critical }

class BloodRequest {
  final String requestId;
  final BloodTypeSimple bloodType;
  final int unitsNeeded;
  final BloodRequestUrgency urgency;
  final double requestLatitude;
  final double requestLongitude;
  final String healthUnitName;
  final String address;
  final String contact;
  bool fulfilled;

  BloodRequest({
    required this.requestId,
    required this.bloodType,
    required this.unitsNeeded,
    required this.urgency,
    required this.requestLatitude,
    required this.requestLongitude,
    this.healthUnitName = '',
    this.address = '',
    this.contact = '',
    this.fulfilled = false,
  });
}

/// محرك طلبات الدم المركزي.
class BloodRequestEngine {
  BloodRequestEngine({
    required this.eligibilityFilter,
    required this.geoExpansionDispatcher,
    required this.alertNotifier,
  });

  final DonorEligibilityFilter eligibilityFilter;
  final GeoExpansionDispatcher geoExpansionDispatcher;
  final FlashAlertNotifier alertNotifier;

  final Map<String, BloodRequest> _requests = {};
  int _counter = 0;

  /// إنشاء طلب دم جديد وبدء دورة الإشعار الفورية بحسب مستوى الإلحاح.
  BloodRequest createRequest({
    required BloodTypeSimple bloodType,
    required int unitsNeeded,
    required BloodRequestUrgency urgency,
    required double latitude,
    required double longitude,
  }) {
    _counter++;
    final request = BloodRequest(
      requestId: 'BRQ-$_counter',
      bloodType: bloodType,
      unitsNeeded: unitsNeeded,
      urgency: urgency,
      requestLatitude: latitude,
      requestLongitude: longitude,
    );
    _requests[request.requestId] = request;

    final initialRadiusKm =
        urgency == BloodRequestUrgency.critical ? 10.0 : 5.0;

    final eligibleDonors = eligibilityFilter.findEligibleDonors(
      bloodType: bloodType,
      centerLatitude: latitude,
      centerLongitude: longitude,
      radiusKm: initialRadiusKm,
    );

    if (eligibleDonors.isEmpty) {
      geoExpansionDispatcher.scheduleExpansion(
          request.requestId, initialRadiusKm);
    } else {
      for (final donor in eligibleDonors) {
        alertNotifier.sendAlert(donor.donorLifexId, request);
      }
    }

    return request;
  }

  void markFulfilled(String requestId) {
    _requests[requestId]?.fulfilled = true;
  }

  List<BloodRequest> get activeRequests =>
      _requests.values.where((r) => !r.fulfilled).toList();
}
