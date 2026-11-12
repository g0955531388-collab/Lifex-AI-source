/// =============================================================
/// Lifex-AI — التبرعات الإنسانية
/// الملف: donation_gratitude_certificates.dart
/// المسار: lib/features/donations/donation_gratitude_certificates.dart
/// الوصف: توليد شهادة شكر رقمية بسيطة للمتبرع بعد إتمام التبرع فعلياً،
/// كتقدير رمزي دون كشف أي بيانات حساسة عن المستفيد.
/// =============================================================
library;

import '../../core/app_constants.dart';

class GratitudeCertificate {
  final String certificateId;
  final String donorLifexId;
  final String donationId;
  final DateTime issuedAt;
  final String messageAr;

  /// نص الإسناد والملكية الرسمي الكامل — تُعرَض هذه الشهادة كوثيقة
  /// رسمية باسم النظام، لذا يظهر فيها النص الكامل (وليس المختصر).
  final String officialFooterAr;

  GratitudeCertificate({
    required this.certificateId,
    required this.donorLifexId,
    required this.donationId,
    required this.messageAr,
    this.officialFooterAr = AppConstants.ownershipStatement,
    DateTime? issuedAt,
  }) : issuedAt = issuedAt ?? DateTime.now();
}

/// مولّد شهادات الشكر.
class DonationGratitudeCertificates {
  DonationGratitudeCertificates();

  final Map<String, GratitudeCertificate> _certificates = {};
  int _counter = 0;

  GratitudeCertificate issueCertificate({
    required String donorLifexId,
    required String donationId,
  }) {
    _counter++;
    final certificate = GratitudeCertificate(
      certificateId: 'CERT-$_counter',
      donorLifexId: donorLifexId,
      donationId: donationId,
      messageAr:
          'شكراً لك على تبرعك الكريم. أثرك الطيب وصل ولمس حياة إنسان '
          'يحتاج للمساعدة، جعله الله في ميزان حسناتك.',
    );
    _certificates[certificate.certificateId] = certificate;
    return certificate;
  }

  List<GratitudeCertificate> certificatesForDonor(String donorLifexId) {
    return _certificates.values
        .where((c) => c.donorLifexId == donorLifexId)
        .toList();
  }
}
