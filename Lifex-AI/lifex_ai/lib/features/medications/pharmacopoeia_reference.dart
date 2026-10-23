/// =============================================================
/// Lifex-AI — مرجع دستوري للأدوية
/// يطابق اسماً في الملف الصحي مع دستور مرجعي.
/// التنبيه يوجّه للطبيب. لا يوقف دواء ولا يقترح بديلاً ولا يأمر بجرعة.
/// فئة الحمل ليست إذناً. المجهول ليس آمناً.
/// =============================================================
library lifex_ai.features.medications.pharmacopoeia_reference;

import '../profile/health_profile.dart';

class PharmacopoeiaEntry {
  const PharmacopoeiaEntry({
    required this.genericName,
    required this.genericNameAr,
    required this.tradeNames,
    required this.pregnancyCategory,
    required this.contraindications,
  });

  final String genericName;
  final String genericNameAr;
  final List<String> tradeNames;
  final String pregnancyCategory;
  final List<String> contraindications;

  bool matches(String raw) {
    final needle = raw.trim().toLowerCase();
    if (needle.isEmpty) return false;
    final names = [
      genericName,
      genericNameAr,
      ...tradeNames,
    ];
    for (final name in names) {
      final folded = name.trim().toLowerCase();
      if (folded.isEmpty) continue;
      if (needle == folded || needle.contains(folded)) return true;
    }
    return false;
  }
}

class PharmacopoeiaReference {
  const PharmacopoeiaReference(this.entries);

  static const bool automaticStopAllowed = false;
  static const bool automaticAlternativeAllowed = false;
  static const bool dosingAdviceAllowed = false;

  static const assetPath = 'lib/data/reference/global_drugs_database.json';

  final List<PharmacopoeiaEntry> entries;

  factory PharmacopoeiaReference.fromJson(Map<String, dynamic> json) {
    final categories = json['drug_categories'];
    final entries = <PharmacopoeiaEntry>[];
    if (categories is List) {
      for (final category in categories) {
        if (category is! Map) continue;
        final drugs = category['drugs'];
        if (drugs is! List) continue;
        for (final drug in drugs) {
          if (drug is! Map) continue;
          final generic = '${drug['generic_name'] ?? ''}'.trim();
          if (generic.isEmpty) continue;
          entries.add(
            PharmacopoeiaEntry(
              genericName: generic,
              genericNameAr: '${drug['generic_name_ar'] ?? ''}'.trim(),
              tradeNames: [
                for (final name in (drug['trade_names'] as List? ?? const []))
                  '$name'.trim(),
              ].where((name) => name.isNotEmpty).toList(),
              pregnancyCategory:
                  '${drug['pregnancy_safety_category'] ?? ''}'.trim(),
              contraindications: [
                for (final item in (drug['contraindications'] as List? ?? const []))
                  '$item'.trim(),
              ].where((item) => item.isNotEmpty).toList(),
            ),
          );
        }
      }
    }
    return PharmacopoeiaReference(entries);
  }

  PharmacopoeiaEntry? find(String name) {
    PharmacopoeiaEntry? best;
    var bestLength = -1;
    for (final entry in entries) {
      if (!entry.matches(name)) continue;
      final length = entry.genericName.length;
      if (length > bestLength) {
        best = entry;
        bestLength = length;
      }
    }
    return best;
  }

  List<String> pregnancyCautions(
    HealthProfile profile, {
    int? gestationalWeek,
  }) {
    final lines = <String>[];
    var unknown = 0;
    for (final name in profile.currentMedicationNames) {
      final entry = find(name);
      if (entry == null) {
        unknown++;
        continue;
      }
      lines.add(_pregnancyLine(name, entry, gestationalWeek));
    }
    if (unknown > 0) {
      lines.add(
        'بعض أدوية الملف غير موجودة في دستور الأدوية المرجعي. '
        'غيابها ليس أماناً. أخبري الطبيبة بكل دواء.',
      );
    }
    return lines;
  }

  List<String> cvCautions(HealthProfile profile) {
    final lines = <String>[];
    final pregnant = _profileMentionsPregnancy(profile);
    for (final name in profile.currentMedicationNames) {
      final entry = find(name);
      if (entry == null) continue;
      for (final contra in entry.contraindications) {
        if (_isPregnancyPhrase(contra) && !pregnant) continue;
        if (_profileHits(profile, contra)) {
          lines.add(
            'تنبيه مرجع: $name مذكور مع «$contra» ويوجد بند قريب في الملف. '
            'هذا ليس إيقافاً للدواء ولا بديلاً. راجع الطبيب قبل أي تغيير.',
          );
        }
      }
    }
    return lines.toSet().toList();
  }

  String _pregnancyLine(
    String recordedName,
    PharmacopoeiaEntry entry,
    int? gestationalWeek,
  ) {
    final category = entry.pregnancyCategory;
    final third = gestationalWeek != null &&
        gestationalWeek >= 28 &&
        category.toLowerCase().contains('3rd');
    final categoryText = category.isEmpty
        ? 'لا فئة حمل مكتوبة في المرجع.'
        : third
            ? 'نص الفئة في المرجع يذكر الثلث الثالث: $category.'
            : 'فئة الحمل في المرجع: $category.';
    return 'دواء الملف ($recordedName / ${entry.genericName}). $categoryText '
        'الفئة ليست إذناً بالاستمرار. Lifex لا يوقف الدواء ولا يقترح بديلاً. '
        'راجعي الطبيبة قبل أي تغيير.';
  }

  bool _profileMentionsPregnancy(HealthProfile profile) {
    if (profile.questionnaireData['isPregnant'] == true) return true;
    return profile.chronicConditions.where((item) => item.isActive).any(
          (item) => item.conditionName.contains('حمل'),
        );
  }

  bool _isPregnancyPhrase(String contra) =>
      contra.toLowerCase().contains('pregnancy');

  bool _profileHits(HealthProfile profile, String contra) {
    final hints = _hintsFor(contra);
    if (hints.isEmpty) return false;
    final blob = [
      for (final allergy in profile.allergies) allergy.substance,
      for (final condition in profile.chronicConditions.where((c) => c.isActive))
        condition.conditionName,
      if (_profileMentionsPregnancy(profile)) 'حمل pregnancy',
    ].join(' ').toLowerCase();
    return hints.any(blob.contains);
  }

  List<String> _hintsFor(String contra) {
    final folded = contra.toLowerCase();
    const table = <String, List<String>>{
      'hepatic': ['كبد', 'hepatic', 'liver'],
      'liver': ['كبد', 'liver', 'hepatic'],
      'peptic ulcer': ['قرحة', 'ulcer'],
      'renal': ['كلى', 'كلو', 'renal', 'kidney'],
      'hypotension': ['انخفاض الضغط', 'هبوط الضغط', 'hypotension'],
      'angioedema': ['وذمة', 'angioedema'],
      'pregnancy': ['حمل', 'pregnancy'],
      'cholestatic': ['يرقان', 'صفرا', 'jaundice', 'cholest'],
      'macrolide': ['ماكروليد', 'macrolide'],
      'penicillin': ['بنسلين', 'penicillin'],
      'proton pump': ['مضخة', 'proton pump'],
      'tachyarrhythm': ['تسرع', 'tachy'],
    };
    final hints = <String>[];
    for (final entry in table.entries) {
      if (folded.contains(entry.key)) hints.addAll(entry.value);
    }
    return hints;
  }
}
