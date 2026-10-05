// =============================================================
// Lifex-AI — اختبارات الوحدة
// الملف: persistence_trial_test.dart
// المسار: test/features/persistence_trial_test.dart
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_constants.dart';
import 'package:lifex_ai/core/local_knowledge.dart';
import 'package:lifex_ai/core/trial_manager.dart';
import 'package:lifex_ai/features/doctors/pharmacy_locator.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';
import 'package:lifex_ai/features/profile/multi_profile_engine.dart';
import 'package:lifex_ai/features/profile/profile_vault.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';
import 'package:lifex_ai/features/women_health/female_cycle_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileVault', () {
    test('يحفظ ويستعيد الملف النشط والاستبيان', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final vault = ProfileVault(prefs);
      final engine = MultiProfileEngine(maxProfiles: 4);
      final profile = HealthProfile(
        profileId: 'p-persist',
        fullName: 'غازي',
        dateOfBirth: DateTime(1990, 1, 1),
      );
      profile.questionnaireData['pharmacyStock'] = [
        {'title': 'باراسيتامول', 'quantity': '2'},
      ];
      engine.addProfile(profile, role: ProfileRole.primaryOwner);
      await vault.save(engine);

      final restored = MultiProfileEngine(maxProfiles: 4);
      await vault.loadInto(restored);
      expect(restored.activeProfileId, 'p-persist');
      expect(restored.activeProfile!.fullName, 'غازي');
      expect(
        restored.activeProfile!.questionnaireData['pharmacyStock'],
        isNotEmpty,
      );
    });
  });

  group('TrialManager و SessionAccessPolicy', () {
    test('النسخة المستقلة تفتح شهراً مخفّفاً لا كاملاً', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final trial = TrialManager(prefs);
      expect(trial.phase(), TrialPhase.reducedMonth);
      expect(trial.emergencyAndBloodOnly, isFalse);
      const policy = SessionAccessPolicy();
      expect(
        policy.canOpenUnit(
          'profile',
          phase: TrialPhase.reducedMonth,
          feeExempt: false,
        ),
        isTrue,
      );
      // Module Access ≠ Entitlement: فتح الوحدة متاح؛ القيد على الميزة المدفوعة.
      expect(
        policy.canOpenUnit(
          'box',
          phase: TrialPhase.reducedMonth,
          feeExempt: false,
        ),
        isTrue,
      );
      expect(
        policy.canUsePaidFeature(
          'premium_booking',
          phase: TrialPhase.reducedMonth,
          feeExempt: false,
        ),
        isFalse,
      );
    });

    test('بعد الشهر المجاني تبقى الوحدات مفتوحة والقيود على المدفوع فقط', () async {
      SharedPreferences.setMockInitialValues({
        'lifex_installed_at': DateTime.now()
            .subtract(const Duration(days: AppConstants.trialPeriodDays + 1))
            .toIso8601String(),
        'lifex_copy_origin': 'independent',
      });
      final prefs = await SharedPreferences.getInstance();
      final trial = TrialManager(prefs);
      expect(trial.phase(), TrialPhase.residual);
      expect(trial.emergencyAndBloodOnly, isTrue);
      const policy = SessionAccessPolicy();
      expect(
        policy.canOpenUnit(
          'emergency',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isTrue,
      );
      expect(
        policy.canOpenUnit(
          'blood',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isTrue,
      );
      expect(
        policy.canOpenUnit(
          'donations',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isTrue,
      );
      expect(
        policy.canOpenUnit(
          'notifications',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isTrue,
      );
      expect(
        policy.canOpenUnit(
          'wallet',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isTrue,
      );
      expect(
        policy.canOpenUnit(
          'settings',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isTrue,
      );
      expect(
        policy.canOpenUnit(
          'box',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isTrue,
      );
      expect(
        policy.canUsePaidFeature(
          'premium_booking',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isFalse,
      );
      expect(
        policy.canUsePaidFeature(
          'premium_booking',
          phase: TrialPhase.residual,
          feeExempt: true,
        ),
        isTrue,
      );
    });

    test('الإهداء مرة واحدة من مشترك ثم خمسة عشر يوماً ثم تخصيص', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final donor = TrialManager(prefs);
      donor.activatePaidYear();
      final denied = donor.issueGiftToken(legallySubscribed: false);
      expect(denied.ok, isFalse);
      final first = donor.issueGiftToken(legallySubscribed: true);
      expect(first.ok, isTrue);
      expect(first.token, startsWith('LIFEX-GIFT-'));
      final second = donor.issueGiftToken(legallySubscribed: true);
      expect(second.ok, isFalse);

      SharedPreferences.setMockInitialValues({});
      final guestPrefs = await SharedPreferences.getInstance();
      final guest = TrialManager(guestPrefs);
      expect(guest.redeemGiftToken('bad').ok, isFalse);
      expect(guest.redeemGiftToken(first.token!).ok, isTrue);
      expect(guest.phase(), TrialPhase.giftWorking);
      expect(
        const SessionAccessPolicy().canOpenUnit(
          'ai',
          phase: TrialPhase.giftWorking,
          feeExempt: false,
        ),
        isTrue,
      );

      await guestPrefs.setString(
        'lifex_gift_started_at',
        DateTime.now()
            .subtract(const Duration(days: AppConstants.giftCopyDays + 1))
            .toIso8601String(),
      );
      expect(guest.phase(), TrialPhase.giftFrozen);
      expect(
        const SessionAccessPolicy().canOpenUnit(
          'emergency',
          phase: TrialPhase.giftFrozen,
          feeExempt: false,
        ),
        isFalse,
      );
      expect(guest.claimAsNewSubscriber().ok, isTrue);
      expect(guest.phase(), TrialPhase.reducedMonth);
    });
  });

  group('LocalKnowledge', () {
    test('يبحث في الأمراض والأدوية', () {
      final knowledge = LocalKnowledge(
        diseases: [
          {
            'nameAr': 'ارتفاع ضغط الدم الشرياني',
            'nameEn': 'hypertension',
            'generalInfoAr': 'مرجع توعية',
          },
        ],
        medications: [
          {'nameAr': 'باراسيتامول', 'nameEn': 'paracetamol'},
        ],
        symptoms: const [],
        tests: const [],
        namedConditions: [
          {
            'name': 'الهربس التناسلي',
            'description': 'مرجع توعية وليس تشخيصاً',
          },
        ],
        cameraSigns: [
          {'sign': 'Cyanotic Lips', 'meaning': 'إشارة أكسجة'},
        ],
        disclaimerAr: 'مرجع توعية فقط. ليس تشخيصاً.',
      );
      final hits = knowledge.search('ضغط');
      expect(hits, isNotEmpty);
      expect(hits.first.titleAr, contains('ضغط'));
      expect(knowledge.search('باراسيتامول').first.kindAr, 'دواء');
      expect(knowledge.search('الهربس').first.kindAr, 'حالة مرجعية');
      expect(knowledge.search('cyanotic').first.kindAr, 'علامة بصرية');
    });
  });

  group('PharmacyLocator', () {
    test('يرجع الأقرب في نفس المدينة مع كمية موجبة', () {
      final hits = PharmacyLocator().nearestWithDrug(
        stock: [
          {
            'title': 'بعيد',
            'city': 'دمشق',
            'km': '9',
            'quantity': '4',
            'barcode': '1',
          },
          {
            'title': 'قريب',
            'city': 'دمشق',
            'km': '1',
            'quantity': '3',
            'barcode': '2',
          },
          {
            'title': 'نفد',
            'city': 'دمشق',
            'km': '0.5',
            'quantity': '0',
            'barcode': '3',
          },
        ],
        query: '',
        city: 'دمشق',
      );
      expect(hits.first['title'], 'قريب');
      expect(hits, hasLength(2));
    });
  });

  group('موعد الولادة من آخر دورة', () {
    test('يضيف 280 يوماً', () {
      final due = FemaleCycleTracker.estimatedDueFromLmp(DateTime(2026, 1, 1));
      expect(due, DateTime(2026, 10, 8));
    });
  });

  group('CommandParser', () {
    test('يفتح البحث والصيدلية', () {
      final parser = CommandParser();
      expect(parser.parse('ابحث عن دواء').intent, VoiceCommandIntent.openSearch);
      expect(parser.parse('افتح الصيدلية').intent, VoiceCommandIntent.openPharmacy);
    });

    test('يزيل كلمة ليفكس ويفهم مرادفات الدواء والطوارئ', () {
      final parser = CommandParser();
      expect(
        parser.parse('ليفكس، ذكرني بالدواء').intent,
        VoiceCommandIntent.openMedications,
      );
      expect(
        parser.parse("Lifex, I cannot breathe").intent,
        VoiceCommandIntent.callEmergency,
      );
      expect(
        parser.parse('كيف وضعي').intent,
        VoiceCommandIntent.clarifyHealthAspect,
      );
      expect(
        parser.parse('ما الموجود أمامي').intent,
        VoiceCommandIntent.openLiveSight,
      );
    });
  });
}
