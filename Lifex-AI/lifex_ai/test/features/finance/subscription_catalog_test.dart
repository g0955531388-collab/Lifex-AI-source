// اختبارات: كتالوج الاشتراك ورسوم المنصة

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/finance/platform_fee_policy.dart';
import 'package:lifex_ai/features/finance/subscription_billing_manager.dart';
import 'package:lifex_ai/features/finance/subscription_catalog.dart';
import 'package:lifex_ai/features/finance/billing_exemption_policy.dart';
import 'package:lifex_ai/features/finance/payment_gateway_client.dart';
import 'package:lifex_ai/features/finance/transaction_ledger.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

class _FakeSucceedingGateway implements PaymentGatewayClient {
  @override
  String get gatewayName => 'FakeGateway';

  @override
  Future<PaymentResult> chargeAmount({
    required int amountInSmallestUnit,
    required String currencyCode,
    required String description,
    String? idempotencyKey,
  }) async {
    return const PaymentResult(
      status: PaymentStatus.succeeded,
      gatewayTransactionId: 'FAKE-TXN-1',
    );
  }

  @override
  Future<PaymentResult> refund({
    required String gatewayTransactionId,
    int? partialAmountInSmallestUnit,
  }) async {
    return const PaymentResult(status: PaymentStatus.succeeded);
  }
}

HealthProfile _person({
  String seat = 'individual',
  bool blind = false,
  bool chronic = false,
}) {
  return HealthProfile(
    profileId: 'p1',
    fullName: 'مستخدم اختباري',
    dateOfBirth: DateTime(1990, 1, 1),
    billingSeat: seat,
    isBlind: blind,
    chronicConditions: chronic
        ? [
            ChronicConditionRecord(
              conditionName: 'مرض دائم',
              diagnosedAt: DateTime(2010, 1, 1),
            ),
          ]
        : const [],
  );
}

void main() {
  test('أسعار الاشتراك السنوي: فرد 100 وحدة 300 مستشفى 600', () {
    const catalog = SubscriptionCatalog();
    expect(catalog.planFor(BillingSeat.individual).usd, 100);
    expect(catalog.planFor(BillingSeat.healthUnit).usd, 300);
    expect(catalog.planFor(BillingSeat.hospital).usd, 600);
  });

  test('تحصيل اشتراك الفرد 100 دولار عبر البوابة', () async {
    final ledger = TransactionLedger();
    final manager = SubscriptionBillingManager(
      ledger: ledger,
      exemptionPolicy: const BillingExemptionPolicy(),
    )..registerGateway(_FakeSucceedingGateway());

    final result = await manager.chargeAnnualSubscription(
      profile: _person(),
      gatewayName: 'FakeGateway',
    );

    expect(result.success, isTrue);
    expect(result.wasExempt, isFalse);
    expect(ledger.historyFor('p1').single.amountInSmallestUnit, 10000);
  });

  test('المكفوف لا يدفع اشتراكاً ولا رسوم تحويل', () async {
    final ledger = TransactionLedger();
    final manager = SubscriptionBillingManager(
      ledger: ledger,
      exemptionPolicy: const BillingExemptionPolicy(),
    )..registerGateway(_FakeSucceedingGateway());
    final profile = _person(blind: true);

    final sub = await manager.chargeAnnualSubscription(
      profile: profile,
      gatewayName: 'FakeGateway',
    );
    expect(sub.wasExempt, isTrue);

    final fee = manager.recordPlatformFeeIfDue(
      profile: profile,
      transferCents: 20000,
    );
    expect(fee, isNull);
    expect(ledger.historyFor('p1'), isEmpty);
  });

  test('تحويل أموال على غير المعفى: 5٪ لصالح المنصة', () {
    const fees = PlatformFeePolicy();
    final quote = fees.onMoneyTransfer(
      profile: _person(),
      transferCents: 20000,
    );
    expect(quote.dueCents, 1000);
    expect(quote.wasExempt, isFalse);
  });

  test('الإعلان بلا سعر متفق: تفاوض لا رقم مختلق', () {
    const fees = PlatformFeePolicy();
    final quote = fees.onExtraService(
      profile: _person(seat: 'healthUnit'),
      kind: ExtraServiceKind.advertisement,
    );
    expect(quote.needsNegotiation, isTrue);
    expect(quote.dueCents, 0);
  });

  test('المريض الدائم معفى من الدورة التدريبية', () {
    const fees = PlatformFeePolicy();
    final quote = fees.onExtraService(
      profile: _person(chronic: true),
      kind: ExtraServiceKind.trainingCourse,
      negotiatedCents: 5000,
    );
    expect(quote.wasExempt, isTrue);
    expect(quote.dueCents, 0);
  });
}
