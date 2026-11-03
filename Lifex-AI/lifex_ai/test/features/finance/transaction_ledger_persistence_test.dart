import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifex_ai/features/finance/transaction_ledger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ledger persists transactions and restores the calculated balance', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = TransactionLedger(preferences: preferences);

    first.record(
      profileId: 'patient-1',
      type: TransactionType.topUp,
      amountInSmallestUnit: 12500,
      currencyCode: 'USD',
      relatedGatewayTransactionId: 'gateway-confirmed-1',
    );
    first.record(
      profileId: 'patient-1',
      type: TransactionType.hospitalPayment,
      amountInSmallestUnit: 2500,
      currencyCode: 'USD',
      relatedEntityId: 'invoice-1',
    );
    await first.flush();

    final restored = TransactionLedger(preferences: preferences);
    await restored.load();

    expect(restored.historyFor('patient-1'), hasLength(2));
    expect(restored.currentBalanceFor('patient-1', currencyCode: 'USD'), 10000);
    expect(restored.historyFor('patient-1').last.relatedEntityId, 'invoice-1');
  });

  test('balances are not mixed across different currencies', () {
    final ledger = TransactionLedger();
    ledger.record(
      profileId: 'patient-1',
      type: TransactionType.topUp,
      amountInSmallestUnit: 5000,
      currencyCode: 'USD',
    );
    ledger.record(
      profileId: 'patient-1',
      type: TransactionType.topUp,
      amountInSmallestUnit: 7000,
      currencyCode: 'EUR',
    );

    expect(ledger.currentBalanceFor('patient-1', currencyCode: 'USD'), 5000);
    expect(ledger.currentBalanceFor('patient-1', currencyCode: 'EUR'), 7000);
  });

  test('invalid or tampered transactions are rejected', () {
    final ledger = TransactionLedger();
    expect(
      () => ledger.record(
        profileId: 'patient-1',
        type: TransactionType.topUp,
        amountInSmallestUnit: -100,
        currencyCode: 'USD',
      ),
      throwsArgumentError,
    );
  });
}
