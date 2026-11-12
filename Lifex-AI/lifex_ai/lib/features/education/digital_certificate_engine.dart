/// =============================================================
/// Lifex-AI — وحدة التأهيل والتدريب
/// الملف: digital_certificate_engine.dart
/// المسار: lib/features/education/digital_certificate_engine.dart
/// الوصف: توليد شهادات إتمام رقمية للمتدربين، مع رمز تحقق فريد يسمح
/// لأي جهة خارجية (صاحب عمل مثلاً) بالتحقق من صحة الشهادة.
/// =============================================================
library;

class DigitalCertificate {
  final String certificateId;
  final String learnerId;
  final String courseId;
  final String verificationCode;
  final DateTime issuedAt;

  const DigitalCertificate({
    required this.certificateId,
    required this.learnerId,
    required this.courseId,
    required this.verificationCode,
    required this.issuedAt,
  });
}

/// محرك الشهادات الرقمية.
class DigitalCertificateEngine {
  DigitalCertificateEngine();

  final Map<String, DigitalCertificate> _certificatesById = {};
  final Map<String, String> _certificateIdByVerificationCode = {};
  int _counter = 0;

  DigitalCertificate issueCertificate({
    required String learnerId,
    required String courseId,
  }) {
    _counter++;
    final certificateId = 'CERT-EDU-$_counter';
    final verificationCode =
        '${courseId.hashCode.abs()}-${DateTime.now().millisecondsSinceEpoch}';

    final certificate = DigitalCertificate(
      certificateId: certificateId,
      learnerId: learnerId,
      courseId: courseId,
      verificationCode: verificationCode,
      issuedAt: DateTime.now(),
    );

    _certificatesById[certificateId] = certificate;
    _certificateIdByVerificationCode[verificationCode] = certificateId;

    return certificate;
  }

  /// التحقق من صحة شهادة عبر رمز التحقق فقط (يُستخدم من طرف خارجي مثل
  /// صاحب عمل يريد التأكد من صحة شهادة مقدَّمة له).
  DigitalCertificate? verifyByCode(String verificationCode) {
    final certificateId = _certificateIdByVerificationCode[verificationCode];
    if (certificateId == null) return null;
    return _certificatesById[certificateId];
  }

  List<DigitalCertificate> certificatesForLearner(String learnerId) {
    return _certificatesById.values
        .where((c) => c.learnerId == learnerId)
        .toList();
  }
}
