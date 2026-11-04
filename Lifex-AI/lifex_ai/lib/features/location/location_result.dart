/// =============================================================
/// Lifex-AI — الموقع الجغرافي والطوارئ
/// الملف: location_result.dart
/// المسار: lib/features/location/location_result.dart
/// الوصف: نموذج نتيجة الموقع الجغرافي، يميز بوضوح بين
/// الحالات الناجحة والفاشلة بدون اختلاق إحداثيات.
/// =============================================================

/// سبب فشل الحصول على الموقع.
enum LocationFailureReason {
  /// المستخدم رفض منح صلاحية الموقع.
  permissionDenied,

  /// المستخدم رفض نهائياً (لا يمكن طلب مرة أخرى).
  permissionPermanentlyDenied,

  /// خدمات الموقع معطلة على الجهاز.
  locationServicesDisabled,

  /// انتهت مهلة زمنية الانتظار للحصول على الموقع.
  timeout,

  /// الموقع غير متاح حالياً (خدمة GPS غير مستجيبة).
  unavailable,

  /// النتيجة المُرجعة غير صحيحة أو فارغة.
  invalidResult,

  /// خطأ غير متوقع.
  unknown,
}

/// نتيجة محاولة الحصول على الموقع الجغرافي الحالي.
/// إما ناجحة (مع إحداثيات صحيحة وطازجة) أو فاشلة (مع سبب محدد).
abstract class LocationResult {
  const LocationResult();

  /// ما إذا كانت العملية نجحت.
  bool get isSuccess;

  /// ما إذا كانت العملية فشلت.
  bool get isFailure => !isSuccess;
}

/// نتيجة ناجحة — الموقع تم الحصول عليه بنجاح وهو طازج.
class SuccessLocationResult extends LocationResult {
  const SuccessLocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  /// خط العرض (بين -90 و +90).
  final double latitude;

  /// خط الطول (بين -180 و +180).
  final double longitude;

  /// دقة الموقع بالمتر (أكبر = أقل دقة).
  /// قد يكون null إذا لم تتمكن النظام من تحديد الدقة.
  final double? accuracy;

  /// الوقت الذي تم الحصول على الموقع فيه.
  final DateTime timestamp;

  @override
  bool get isSuccess => true;

  /// ما إذا كان الموقع "طازجاً" (أقل من دقيقة).
  bool get isFresh {
    final age = DateTime.now().difference(timestamp);
    return age.inSeconds < 60;
  }
}

/// نتيجة فاشلة — لم يتم الحصول على الموقع.
class FailureLocationResult extends LocationResult {
  const FailureLocationResult({
    required this.reason,
    this.message,
  });

  /// سبب الفشل.
  final LocationFailureReason reason;

  /// رسالة خطأ اختيارية توضح التفاصيل.
  final String? message;

  @override
  bool get isSuccess => false;

  @override
  String toString() =>
      'FailureLocationResult(reason: $reason, message: $message)';
}
