/// =============================================================
/// Lifex-AI — شبكة التبرع بالدم
/// الملف: flash_alert_notifier.dart
/// المسار: lib/features/blood_network/flash_alert_notifier.dart
/// الوصف: إرسال إشعار فوري "استغاثة دم" لمتبرع مؤهل، بأولوية عالية في
/// نظام الإشعارات (لا تندرج ضمن الإشعارات العادية القابلة للتأجيل).
/// =============================================================
library;

import 'blood_request_engine.dart';
import 'blood_type_match.dart';
import 'donor_eligibility_filter.dart';

typedef FlashAlertSendFunction = Future<bool> Function(
  String recipientLifexId,
  String messageAr,
);

class FlashAlertRecord {
  final String recipientLifexId;
  final String requestId;
  final DateTime sentAt;

  FlashAlertRecord({
    required this.recipientLifexId,
    required this.requestId,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();
}

/// موزّع إشعارات استغاثة الدم الفورية.
class FlashAlertNotifier {
  FlashAlertNotifier({this.sendFunction});

  final FlashAlertSendFunction? sendFunction;
  final List<FlashAlertRecord> _log = [];

  Future<void> sendAlert(String recipientLifexId, BloodRequest request) async {
    _log.add(FlashAlertRecord(
      recipientLifexId: recipientLifexId,
      requestId: request.requestId,
    ));

    final unit = request.healthUnitName.trim().isEmpty
        ? 'الوحدة الصحية'
        : request.healthUnitName.trim();
    final place = request.address.trim().isEmpty
        ? 'العنوان لدى الوحدة'
        : request.address.trim();
    final type = BloodTypeMatch.label(request.bloodType);
    final spot = DonorEligibilityFilter.coordinatesUsable(
      request.requestLatitude,
      request.requestLongitude,
    )
        ? ' الموقع: ${request.requestLatitude}, ${request.requestLongitude}.'
        : '';
    final message = 'نداء للتبرع بالدم: $unit، العنوان: $place. '
        'الزمرة المطلوبة: $type.$spot '
        'اضغط للاطلاع على التفاصيل والتواصل مع الوحدة الصحية. '
        'هذه دعوة أولية، وبنك الدم يتحقق من الأهلية.';

    await sendFunction?.call(recipientLifexId, message);
  }

  List<FlashAlertRecord> get log => List.unmodifiable(_log);
}
