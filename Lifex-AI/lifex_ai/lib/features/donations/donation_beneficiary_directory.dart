/// =============================================================
/// Lifex-AI — دليل مستفيدي التبرع العام (Consented / Public فقط)
/// الملف: donation_beneficiary_directory.dart
/// ليس استعلاماً على PatientCondition. Directory ≠ Health Record.
/// =============================================================
library lifex_ai.features.donations.donation_beneficiary_directory;

import '../../core/global_donations/donation_types.dart';
import '../trusted_person/person_match_policy.dart';
import '../trusted_person/trusted_person_models.dart';

class DonationSearchQuery {
  const DonationSearchQuery({
    this.nameContains,
    this.needCategory,
    this.locationContains,
    this.donationType,
    this.urgency,
    this.campaignId,
    this.verifiedOnly = false,
  });

  final String? nameContains;
  final DonationNeedCategory? needCategory;
  final String? locationContains;
  final String? donationType;
  final String? urgency;
  final String? campaignId;
  final bool verifiedOnly;
}

/// يحيل النص/الصوت إلى فئة احتياج — لا يفتح جدول المرضى.
class DonationIntentParser {
  const DonationIntentParser();

  DonationNeedCategory? parseNeedCategory(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.contains('سرطان') || t.contains('cancer')) {
      return DonationNeedCategory.cancer;
    }
    if (t.contains('قلب') || t.contains('heart') || t.contains('cardio')) {
      return DonationNeedCategory.cardiovascular;
    }
    if (t.contains('كرسي') || t.contains('wheelchair')) {
      return DonationNeedCategory.wheelchair;
    }
    if (t.contains('طرف') || t.contains('prosthetic')) {
      return DonationNeedCategory.prosthetics;
    }
    if (t.contains('كلى') || t.contains('dialysis') || t.contains('غسيل')) {
      return DonationNeedCategory.healthCenters;
    }
    if (t.contains('دواء') || t.contains('medicine')) {
      return DonationNeedCategory.medicine;
    }
    if (t.contains('دم') || t.contains('blood')) {
      return DonationNeedCategory.blood;
    }
    if (t.contains('طفل') || t.contains('child')) {
      return DonationNeedCategory.children;
    }
    if (t.contains('إعاقة') || t.contains('disability')) {
      return DonationNeedCategory.disability;
    }
    return null;
  }

  bool looksLikeFinancial(String raw) {
    final t = raw.toLowerCase();
    return t.contains('مال') ||
        t.contains('دولار') ||
        t.contains('financial') ||
        t.contains('money') ||
        RegExp(r'\d+').hasMatch(t);
  }

  bool looksLikeInKindDevice(String raw) {
    final t = raw.toLowerCase();
    return t.contains('كرسي') ||
        t.contains('جهاز') ||
        t.contains('wheelchair') ||
        t.contains('device') ||
        t.contains('طرف');
  }
}

class DonationBeneficiaryDirectory {
  DonationBeneficiaryDirectory({
    List<DonationBeneficiaryProfile>? seed,
    PersonMatchPolicy? matchPolicy,
  })  : _profiles = List.of(seed ?? _demoPublicSeed()),
        _match = matchPolicy ?? const PersonMatchPolicy();

  final List<DonationBeneficiaryProfile> _profiles;
  final PersonMatchPolicy _match;

  /// عيّنة عامة موافقة للعرض — ليست مرضى من قاعدة 55.
  static List<DonationBeneficiaryProfile> _demoPublicSeed() => const [
        DonationBeneficiaryProfile(
          beneficiaryId: 'ben_pub_cancer_01',
          displayName: 'برنامج دعم السرطان',
          alias: 'حملة أمل',
          needCategory: DonationNeedCategory.cancer,
          needDescription: 'دعم علاج وتكاليف مرتبطة ببرنامج عام',
          locationArea: 'دمشق',
          urgency: 'high',
          requestedAmountMinor: 50000,
          supportedDonationTypes: ['FINANCIAL', 'MEDICINE'],
          verificationStatus: 'verified',
          visibility: DonationVisibility.consentedPublic,
          consentGranted: true,
          campaignId: 'cmp_cancer_pool',
        ),
        DonationBeneficiaryProfile(
          beneficiaryId: 'ben_pub_heart_01',
          displayName: 'صندوق جراحة القلب',
          alias: 'قلب آمن',
          needCategory: DonationNeedCategory.cardiovascular,
          needDescription: 'دعم عمليات قلب ضمن برنامج مؤسسي',
          locationArea: 'حلب',
          urgency: 'high',
          requestedAmountMinor: 120000,
          supportedDonationTypes: ['FINANCIAL'],
          verificationStatus: 'verified',
          visibility: DonationVisibility.authorizedProgram,
          consentGranted: true,
          campaignId: 'cmp_heart_pool',
        ),
        DonationBeneficiaryProfile(
          beneficiaryId: 'ben_pub_wheelchair_01',
          displayName: 'مركز الأجهزة المساعدة',
          needCategory: DonationNeedCategory.wheelchair,
          needDescription: 'مطابقة كراسي متحركة حسب الاحتياج',
          locationArea: 'اللاذقية',
          urgency: 'normal',
          supportedDonationTypes: ['MEDICAL_DEVICE', 'IN_KIND'],
          verificationStatus: 'verified',
          visibility: DonationVisibility.public,
          consentGranted: true,
        ),
        DonationBeneficiaryProfile(
          beneficiaryId: 'ben_private_hidden',
          displayName: 'مريض سري',
          needCategory: DonationNeedCategory.cancer,
          visibility: DonationVisibility.private,
          consentGranted: false,
          supportedDonationTypes: ['FINANCIAL'],
        ),
      ];

  void register(DonationBeneficiaryProfile profile) {
    _profiles.removeWhere((p) => p.beneficiaryId == profile.beneficiaryId);
    _profiles.add(profile);
  }

  DonationBeneficiaryProfile? byId(String id) {
    for (final p in _profiles) {
      if (p.beneficiaryId == id) return p;
    }
    return null;
  }

  /// البحث لا يمر على PatientCondition.
  List<DonationBeneficiaryProfile> search(DonationSearchQuery q) {
    return _profiles.where((p) {
      if (!p.isSearchablePublic) return false;
      if (q.verifiedOnly && p.verificationStatus != 'verified') return false;
      if (q.needCategory != null && p.needCategory != q.needCategory) {
        return false;
      }
      if (q.campaignId != null && p.campaignId != q.campaignId) return false;
      if (q.urgency != null && p.urgency != q.urgency) return false;
      if (q.donationType != null &&
          !p.supportedDonationTypes.contains(q.donationType)) {
        return false;
      }
      if (q.locationContains != null && q.locationContains!.trim().isNotEmpty) {
        if (!p.locationArea
            .toLowerCase()
            .contains(q.locationContains!.trim().toLowerCase())) {
          return false;
        }
      }
      if (q.nameContains != null && q.nameContains!.trim().isNotEmpty) {
        final n = q.nameContains!.trim().toLowerCase();
        final hit = p.displayName.toLowerCase().contains(n) ||
            (p.alias?.toLowerCase().contains(n) ?? false) ||
            p.beneficiaryId.toLowerCase().contains(n);
        if (!hit) return false;
      }
      return true;
    }).toList();
  }

  PersonMatchResult matchPhoneCandidate({
    required PersonSelectionCandidate candidate,
    required DonationBeneficiaryProfile existing,
  }) {
    return _match.match(
      candidate: candidate,
      existingIdentityId: existing.identityId,
      existingDisplayName: existing.displayName,
    );
  }

  /// ممنوع إنشاء Person/Patient من اسم هاتف فقط.
  bool mayAutoCreatePatientFromPhoneContact(PersonMatchResult r) => false;
}
