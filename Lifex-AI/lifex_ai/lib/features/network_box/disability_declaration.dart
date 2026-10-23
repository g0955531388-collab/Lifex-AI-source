/// تصريح صاحب الملف عن نوع الإعاقة ونسبة يذكرها.
/// النسبة ليست شهادة عجز ولا ترتّب أولوية تبرع.
library lifex_ai.features.network_box.disability_declaration;

class DisabilityDeclaration {
  const DisabilityDeclaration({
    required this.type,
    this.declaredPercent,
  });

  static const types = [
    'حركية',
    'سمعية',
    'بصرية',
    'عقلية',
    'متعددة',
    'أخرى',
  ];

  static const percentIsCertificate = false;
  static const donationRankAllowed = false;

  final String type;
  final int? declaredPercent;

  static DisabilityDeclaration? tryParse(String type, String percentText) {
    final folded = type.trim();
    if (!types.contains(folded)) return null;
    final raw = percentText.trim();
    if (raw.isEmpty) {
      return DisabilityDeclaration(type: folded);
    }
    final percent = int.tryParse(raw);
    if (percent == null || percent < 0 || percent > 100) return null;
    return DisabilityDeclaration(type: folded, declaredPercent: percent);
  }

  int? donationRank() => null;
}
