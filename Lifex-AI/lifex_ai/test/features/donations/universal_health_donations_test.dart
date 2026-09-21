import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/global_donations/donation_types.dart';
import 'package:lifex_ai/features/donations/donation_application_service.dart';
import 'package:lifex_ai/features/donations/donation_beneficiary_directory.dart';
import 'package:lifex_ai/features/finance/payment_gateway_client.dart';
import 'package:lifex_ai/features/finance/transaction_ledger.dart';
import 'package:lifex_ai/features/finance/wallet_manager.dart';
import 'package:lifex_ai/features/trusted_person/trusted_person_models.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  group('DonationBeneficiaryDirectory privacy', () {
    test('PrivatePatientNotPublic — لا يظهر بدون موافقة', () {
      final dir = DonationBeneficiaryDirectory();
      final cancer = dir.search(
        const DonationSearchQuery(needCategory: DonationNeedCategory.cancer),
      );
      expect(cancer.any((p) => p.beneficiaryId == 'ben_private_hidden'), isFalse);
      expect(cancer.every((p) => p.isSearchablePublic), isTrue);
    });

    test('CancerDonationSearch / HeartDonationSearch', () {
      final parser = const DonationIntentParser();
      expect(parser.parseNeedCategory('أريد التبرع لمرضى السرطان'), DonationNeedCategory.cancer);
      expect(parser.parseNeedCategory('تبرع لمرضى القلب'), DonationNeedCategory.cardiovascular);

      final dir = DonationBeneficiaryDirectory();
      final svc = LifexDonationApplicationService(directory: dir);
      final cancer = svc.searchByVoiceOrText('أريد التبرع لمرضى السرطان');
      expect(cancer, isNotEmpty);
      expect(cancer.every((p) => p.needCategory == DonationNeedCategory.cancer), isTrue);

      final heart = svc.searchByVoiceOrText('أريد التبرع لمرضى القلب في حلب');
      expect(heart.any((p) => p.locationArea.contains('حلب')), isTrue);
    });

    test('ConsentVisibility — الاسم وحده لا يؤكد المطابقة', () {
      final dir = DonationBeneficiaryDirectory();
      final pub = dir.byId('ben_pub_cancer_01')!;
      final r = dir.matchPhoneCandidate(
        candidate: const PersonSelectionCandidate(
          sourceType: TrustedPersonSourceType.phoneContact,
          displayName: 'برنامج دعم السرطان',
        ),
        existing: pub,
      );
      expect(r, PersonMatchResult.matchPossible);
      expect(dir.mayAutoCreatePatientFromPhoneContact(r), isFalse);
    });
  });

  group('Financial wallet donation', () {
    test('FeeCalculation + WalletIntegration + Receipt', () async {
      final ledger = TransactionLedger();
      final wallet = WalletManager(
        gatewayClient: SandboxPaymentGatewayClient(
          feePolicy: const TopUpFeePolicy(fixedMinor: 0),
        ),
        ledger: ledger,
      );
      await wallet.topUp(
        profileId: 'donor1',
        amountInSmallestUnit: 50000,
        currencyCode: 'USD',
      );

      final svc = LifexDonationApplicationService(wallet: wallet);
      final quote = svc.quoteFinancial(donationAmountMinor: 10000);
      expect(quote.feeMinor, 200);
      expect(quote.totalChargedMinor, 10200);
      expect(quote.netToRecipientMinor, 10000);
      expect(quote.disclosed, isTrue);

      final pending = await svc.donateFinancialFromWallet(
        donorProfileId: 'donor1',
        beneficiaryId: 'ben_pub_cancer_01',
        donationAmountMinor: 10000,
        idempotencyKey: 'idem-don-1',
        userConfirmedQuote: false,
      );
      expect(pending.ok, isFalse);
      expect(pending.quote!.feeMinor, 200);

      final done = await svc.donateFinancialFromWallet(
        donorProfileId: 'donor1',
        beneficiaryId: 'ben_pub_cancer_01',
        donationAmountMinor: 10000,
        idempotencyKey: 'idem-don-2',
        userConfirmedQuote: true,
      );
      expect(done.ok, isTrue);
      expect(done.receipt, isNotNull);
      expect(wallet.balanceFor('donor1'), 50000 - 10200);
    });

    test('Insufficient balance fails honestly', () async {
      final wallet = WalletManager(
        gatewayClient: SandboxPaymentGatewayClient(),
        ledger: TransactionLedger(),
      );
      final svc = LifexDonationApplicationService(wallet: wallet);
      final r = await svc.donateFinancialFromWallet(
        donorProfileId: 'poor',
        beneficiaryId: 'ben_pub_heart_01',
        donationAmountMinor: 10000,
        idempotencyKey: 'idem-x',
        userConfirmedQuote: true,
      );
      expect(r.ok, isFalse);
    });
  });

  group('In-kind', () {
    test('WheelchairDonation — لا قرار طبي آلي', () async {
      final svc = LifexDonationApplicationService();
      final r = await svc.acceptInKindDevice(
        donorId: 'd1',
        beneficiaryId: 'ben_pub_wheelchair_01',
        category: InKindCategory.wheelchair,
        description: 'كرسي',
        condition: 'used',
      );
      expect(r.ok, isTrue);
      expect(r.messageAr.contains('AI'), isTrue);
    });
  });

  group('Voice', () {
    test('VoiceDonationFlow intents', () {
      final p = CommandParser();
      expect(p.parse('ليفكس أريد التبرع').intent, VoiceCommandIntent.openDonations);
      expect(
        p.parse('ليفكس تبرع لمرضى السرطان').intent,
        VoiceCommandIntent.donateSearchCancer,
      );
    });
  });
}
