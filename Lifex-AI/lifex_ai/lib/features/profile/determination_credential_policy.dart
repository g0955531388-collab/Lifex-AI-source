/// =============================================================
/// Lifex-AI — الهوية الصحية
/// الملف: determination_credential_policy.dart
/// التصريح بذوي الهمم لا يثبّت الوضع. التثبيت في وحدة المعاقين
/// ببطاقة إعاقة أو بطاقة مريض دائم من البلد المسجّل فيه صاحب الحساب.
/// ليست مطابقة حكومية عبر شبكة.
/// =============================================================
library lifex_ai.features.profile.determination_credential_policy;

import 'health_profile.dart';

enum DeterminationCardKind {
  nationalId,
  disabilityCard,
  chronicIllnessCard,
}

extension DeterminationCardKindLabel on DeterminationCardKind {
  bool get fixesInDisabilityUnit {
    return this == DeterminationCardKind.disabilityCard ||
        this == DeterminationCardKind.chronicIllnessCard;
  }

  String get labelAr {
    switch (this) {
      case DeterminationCardKind.nationalId:
        return 'بطاقة وطنية';
      case DeterminationCardKind.disabilityCard:
        return 'بطاقة إعاقة';
      case DeterminationCardKind.chronicIllnessCard:
        return 'بطاقة مرض دائم';
    }
  }
}

class DeterminationCheck {
  const DeterminationCheck({
    required this.recognized,
    required this.messageAr,
  });

  final bool recognized;
  final String messageAr;

  const DeterminationCheck.notClaimed()
      : recognized = false,
        messageAr = 'لم يُدَّعَ وضع ذوي الهمم.';

  const DeterminationCheck.recognized()
      : recognized = true,
        messageAr =
            'ثُبّت في وحدة المعاقين ببطاقة من البلد المسجّل فيه صاحب الحساب. ليست مطابقة حكومية عبر شبكة.';
}

class DeterminationCredentialPolicy {
  const DeterminationCredentialPolicy();

  String foldCountry(String raw) {
    final trimmed = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return trimmed
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }

  bool sameCountry(String accountCountry, String cardCountry) {
    final account = foldCountry(accountCountry);
    final card = foldCountry(cardCountry);
    return account.isNotEmpty && account == card;
  }

  DeterminationCardKind? parseKind(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    for (final kind in DeterminationCardKind.values) {
      if (kind.name == raw.trim()) return kind;
    }
    return null;
  }

  DeterminationCheck evaluate(HealthProfile profile) {
    if (!profile.isPersonOfDetermination) {
      return const DeterminationCheck.notClaimed();
    }
    if (foldCountry(profile.accountCountry).isEmpty) {
      return const DeterminationCheck(
        recognized: false,
        messageAr:
            'سجّل بلد صاحب الحساب. بطاقة من بلد آخر لا تُعتمد.',
      );
    }
    final kind = parseKind(profile.determinationCardKind);
    if (kind == null || !kind.fixesInDisabilityUnit) {
      return const DeterminationCheck(
        recognized: false,
        messageAr:
            'التثبيت في وحدة المعاقين: بطاقة إعاقة أو بطاقة مريض دائم من البلد المسجّل فيه صاحب الحساب.',
      );
    }
    if (!sameCountry(
      profile.accountCountry,
      profile.determinationCardCountry,
    )) {
      return const DeterminationCheck(
        recognized: false,
        messageAr:
            'البطاقة من البلد المسجّل فيه صاحب الحساب. بلد آخر لا يثبّت الوضع.',
      );
    }
    if (profile.determinationCardRef.trim().isEmpty) {
      return const DeterminationCheck(
        recognized: false,
        messageAr:
            'أدخل رقم أو مرجع البطاقة. التصريح وحده لا يمنح الميزة.',
      );
    }
    return const DeterminationCheck.recognized();
  }

  bool isRecognized(HealthProfile profile) => evaluate(profile).recognized;
}
