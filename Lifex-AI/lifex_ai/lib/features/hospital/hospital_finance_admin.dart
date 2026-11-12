/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_finance_admin.dart
/// المسار: lib/features/hospital/hospital_finance_admin.dart
/// الوصف: طبقة أساسية جداً لتتبّع فواتير المرضى والمصاريف التشغيلية
/// العامة داخل المستشفى.
///
/// ⚠️ حدود واقعية: محاسبة مستشفى حقيقية (رواتب، عقود موردين، ضرائب،
/// تسويات تأمين صحي) نظام مالي متكامل مستقل يحتاج فريق محاسبة ومطابقة
/// قانونية خاصة به، وليس مجرد ملف Dart داخل تطبيق موبايل. هذا الملف
/// يوفر بنية أولية جداً لتتبّع فواتير بسيطة فقط، ويُفصل لاحقاً كنظام
/// backend مستقل عند التوسع الفعلي.
/// =============================================================
library;

enum InvoiceStatus { pending, paid, overdue, cancelled }

class PatientInvoice {
  final String invoiceId;
  final String patientProfileId;
  final double amount;
  InvoiceStatus status;
  final DateTime issuedAt;
  DateTime? paidAt;

  PatientInvoice({
    required this.invoiceId,
    required this.patientProfileId,
    required this.amount,
    this.status = InvoiceStatus.pending,
    DateTime? issuedAt,
    this.paidAt,
  }) : issuedAt = issuedAt ?? DateTime.now();
}

/// مدير محاسبي أساسي جداً لفواتير المرضى (وليس نظاماً مالياً كاملاً).
class HospitalFinanceAdmin {
  HospitalFinanceAdmin({required this.hospitalId});

  final String hospitalId;
  final Map<String, PatientInvoice> _invoices = {};
  int _counter = 0;

  PatientInvoice issueInvoice({
    required String patientProfileId,
    required double amount,
  }) {
    _counter++;
    final invoice = PatientInvoice(
      invoiceId: 'INV-$_counter',
      patientProfileId: patientProfileId,
      amount: amount,
    );
    _invoices[invoice.invoiceId] = invoice;
    return invoice;
  }

  bool markPaid(String invoiceId) {
    final invoice = _invoices[invoiceId];
    if (invoice == null) return false;
    invoice.status = InvoiceStatus.paid;
    invoice.paidAt = DateTime.now();
    return true;
  }

  double totalOutstandingFor(String patientProfileId) {
    return _invoices.values
        .where((i) =>
            i.patientProfileId == patientProfileId &&
            i.status != InvoiceStatus.paid &&
            i.status != InvoiceStatus.cancelled)
        .fold(0.0, (sum, i) => sum + i.amount);
  }

  List<PatientInvoice> invoicesForPatient(String patientProfileId) {
    return _invoices.values
        .where((i) => i.patientProfileId == patientProfileId)
        .toList();
  }
}
