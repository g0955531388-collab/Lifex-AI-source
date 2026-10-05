// اختبارات: subscription_billing_manager.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/finance/billing_exemption_policy.dart';
import 'package:lifex_ai/features/finance/payment_gateway_client.dart';
import 'package:lifex_ai/features/finance/subscription_billing_manager.dart';
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

HealthProfile _buildProfile({
  bool isPersonOfDetermination = false,
  String accountCountry = '',
  String determinationCardKind = '',
  String determinationCardCountry = '',
  String determinationCardRef = '',
}) {
  return HealthProfile(
    profileId: 'p1',
    fullName: 'مستخدم اختباري',
    dateOfBirth: DateTime(1990, 1, 1),
    isPersonOfDetermination: isPersonOfDetermination,
    accountCountry: accountCountry,
    determinationCardKind: determinationCardKind,
    determinationCardCountry: determinationCardCountry,
    determinationCardRef: determinationCardRef,
  );
}

void main() {
  test('المستخدم المُعفى لا تُستدعى له أي بوابة دفع ولا يُسجَّل عليه مبلغ', () async {
    final ledger = TransactionLedger();
    final manager = SubscriptionBillingManager(
      ledger: ledger,
      exemptionPolicy: const BillingExemptionPolicy(),
    )..registerGateway(_FakeSucceedingGateway());

    final result = await manager.chargeSubscription(
      profile: _buildProfile(
        isPersonOfDetermination: true,
        accountCountry: 'SY',
        determinationCardKind: 'nationalId',
        determinationCardCountry: 'SY',
        determinationCardRef: 'N-1',
      ),
      amountInSmallestUnit: 500,
      currencyCode: 'USD',
      gatewayName: 'FakeGateway',
    );

    expect(result.success, isTrue);
    expect(result.wasExempt, isTrue);
    expect(ledger.historyFor('p1'), isEmpty);
  });

  test('مستخدم غير مُعفى: تُستدعى البوابة ويُسجَّل الدفع في السجل', () async {
    final ledger = TransactionLedger();
    final manager = SubscriptionBillingManager(
      ledger: ledger,
      exemptionPolicy: const BillingExemptionPolicy(),
    )..registerGateway(_FakeSucceedingGateway());

    final result = await manager.chargeSubscription(
      profile: _buildProfile(),
      amountInSmallestUnit: 500,
      currencyCode: 'USD',
      gatewayName: 'FakeGateway',
    );

    expect(result.success, isTrue);
    expect(result.wasExempt, isFalse);
    expect(ledger.historyFor('p1'), hasLength(1));
    expect(
      ledger.historyFor('p1').first.type,
      TransactionType.subscriptionPayment,
    );
  });

  test('بوابة غير مسجَّلة: فشل واضح دون استثناء غير معالَج', () async {
    final ledger = TransactionLedger();
    final manager = SubscriptionBillingManager(
      ledger: ledger,
      exemptionPolicy: const BillingExemptionPolicy(),
    );

    final result = await manager.chargeSubscription(
      profile: _buildProfile(),
      amountInSmallestUnit: 500,
      currencyCode: 'USD',
      gatewayName: 'GatewayGhairMawjoud',
    );

    expect(result.success, isFalse);
  });

  test('قائمة بوابات الدفع المتاحة تُقيَّد حسب بلد المستخدم', () {
    final manager = SubscriptionBillingManager(
      ledger: TransactionLedger(),
      exemptionPolicy: const BillingExemptionPolicy(),
    )..setAvailableGatewaysForCountry(
        countryCode: 'SY',
        gatewayNames: ['PayPal'],
      );

    expect(manager.availableGatewaysForCountry('SY'), ['PayPal']);
  });
}
