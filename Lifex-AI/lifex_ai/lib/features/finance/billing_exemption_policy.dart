/// =============================================================
/// Lifex-AI — المعاملات المالية
/// الملف: billing_exemption_policy.dart
/// المسار: lib/features/finance/billing_exemption_policy.dart
/// إعفاء بلا أجور ولا رسوم بعد التثبيت في وحدة المعاقين:
/// بطاقة إعاقة أو بطاقة مريض دائم من البلد المسجّل فيه صاحب الحساب.
/// التصريح، وعلم المكفوف، وحالة مزمنة مكتوبة في الملف لا تثبّت وحدها.
/// =============================================================
library lifex_ai.features.finance.billing_exemption_policy;

import '../profile/determination_credential_policy.dart';
import '../profile/health_profile.dart';

class BillingExemptionResult {
  final bool isExempt;
  final String? reasonAr;

  const BillingExemptionResult._(this.isExempt, this.reasonAr);

  const BillingExemptionResult.exempt(String reasonAr)
      : this._(true, reasonAr);

  const BillingExemptionResult.notExempt() : this._(false, null);
}

/// سياسة الإعفاء من الرسوم — دالة واحدة، صريحة، وغير قابلة للتجاوز من
/// أي طبقة أعلى (الواجهة لا تملك خياراً لتعطيل هذا الفحص).
class BillingExemptionPolicy {
  const BillingExemptionPolicy();

  BillingExemptionResult evaluate(HealthProfile profile) {
    final determination =
        const DeterminationCredentialPolicy().evaluate(profile);
    if (determination.recognized) {
      return BillingExemptionResult.exempt(determination.messageAr);
    }
    return const BillingExemptionResult.notExempt();
  }
}
