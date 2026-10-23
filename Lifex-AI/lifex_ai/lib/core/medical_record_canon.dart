/// =============================================================
/// Lifex-AI — المرجع المحلي
/// الملف: medical_record_canon.dart
/// يطوي أسماء المرض المكررة (عربي/إنجليزي لنفس الحالة) دون دمج أمراض مختلفة.
/// المرجع توعوي فقط وليس تشخيصاً.
/// =============================================================
library lifex_ai.core.medical_record_canon;

class MedicalRecordCanon {
  MedicalRecordCanon._();

  static const disclaimerAr =
      'مرجع توعية فقط. ليس تشخيصاً ولا بديلاً عن الطبيب.';

  /// مفاتيح إنجليزية مطويّة: نسختان لنفس المرض، ليستا مرضين.
  static const Map<String, String> englishSynonyms = {
    'hypertension': 'hypertension',
    'type 2 diabetes': 'diabetes_t2',
    'diabetes mellitus type 2': 'diabetes_t2',
    'diabetes mellitus type 1': 'diabetes_t1',
    'gastroesophageal reflux disease': 'gerd',
    'gastroesophageal reflux disease (gerd)': 'gerd',
    'chronic obstructive pulmonary disease': 'copd',
    'chronic obstructive pulmonary disease (copd)': 'copd',
    'tuberculosis': 'tb',
    'tuberculosis - tb': 'tb',
    'urinary tract infection': 'uti',
    'urinary tract infection (uti)': 'uti',
    'irritable bowel syndrome': 'ibs',
    'irritable bowel syndrome (ibs)': 'ibs',
    'eczema': 'eczema',
    'eczema (atopic dermatitis)': 'eczema',
    'cirrhosis': 'cirrhosis',
    'liver cirrhosis': 'cirrhosis',
    'osa': 'osa',
    'obstructive sleep apnea syndrome (osas)': 'osa',
    'shingles': 'shingles',
    'herpes zoster (shingles)': 'shingles',
    'conjunctivitis': 'conjunctivitis',
    'acute conjunctivitis and eye burning': 'conjunctivitis',
    'onychomycosis': 'onychomycosis',
    'fungal nail infection - hands': 'onychomycosis',
    'contact dermatitis': 'contact_dermatitis',
    'allergic contact dermatitis': 'contact_dermatitis_allergic',
    'kidney stones': 'kidney_stones',
    'nephrolithiasis': 'kidney_stones',
    'systemic lupus erythematosus': 'sle',
    'systemic lupus erythematosus sle': 'sle',
    'sle': 'sle',
  };

  static const Map<String, String> arabicSynonyms = {
    'ارتفاع ضغط الدم': 'hypertension',
    'داء السكري': 'diabetes_generic',
  };

  static String normalize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[()\[\].,/_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// مطابقة البحث فقط. لا تُستخدم لمفتاح السجل حتى لا تُدمج الأسماء.
  static String searchFold(String raw) {
    return normalize(raw)
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ـ', '')
        .replaceAll(RegExp('[ً-ْٰ]'), '');
  }

  static bool queryMatches(String blob, String query) {
    final hay = searchFold(blob);
    final needle = searchFold(query);
    if (needle.isEmpty || hay.isEmpty) return false;
    if (hay.contains(needle)) return true;
    final tokens = needle.split(' ').where((token) => token.length >= 2);
    if (tokens.isEmpty) return false;
    return tokens.every(hay.contains);
  }

  static String foldKey({
    required String nameEn,
    required String nameAr,
  }) {
    final en = normalize(nameEn);
    final ar = nameAr.trim();
    if (en.contains('hypertension') || ar.contains('ارتفاع ضغط')) {
      return 'hypertension';
    }
    if (en.contains('diabetes mellitus type 1') ||
        en.contains('type 1 diabetes')) {
      return 'diabetes_t1';
    }
    if (en.contains('diabetes mellitus type 2') ||
        en.contains('type 2 diabetes')) {
      return 'diabetes_t2';
    }
    if (en.isNotEmpty) {
      for (final entry in englishSynonyms.entries) {
        if (normalize(entry.key) == en) return entry.value;
      }
      return 'en:$en';
    }
    if (arabicSynonyms.containsKey(ar)) return arabicSynonyms[ar]!;
    return 'ar:${normalize(ar)}';
  }

  static int _richness(Map<String, dynamic> row) {
    final symptoms = row['commonSymptomsIds'];
    final n = symptoms is List ? symptoms.length : 0;
    final info = '${row['generalInfoAr'] ?? ''}';
    return n * 100 + info.length;
  }

  /// يُبقي السجل الأغنى لكل مفتاح مطوي.
  static List<Map<String, dynamic>> uniqueDiseases(
    List<Map<String, dynamic>> rows,
  ) {
    final buckets = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final key = foldKey(
        nameEn: '${row['nameEn'] ?? ''}',
        nameAr: '${row['nameAr'] ?? ''}',
      );
      final prev = buckets[key];
      if (prev == null || _richness(row) > _richness(prev)) {
        buckets[key] = row;
      }
    }
    return buckets.values.toList();
  }

  /// يُبقي السجل الأغنى لكل اسم ظاهر (للحالات/العلامات المكررة بأسماء مختلفة).
  static List<Map<String, dynamic>> uniqueNamedRows(
    List<Map<String, dynamic>> rows, {
    List<String> nameKeys = const ['name', 'nameAr', 'sign'],
  }) {
    final buckets = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      var name = '';
      for (final key in nameKeys) {
        final value = '${row[key] ?? ''}'.trim();
        if (value.isEmpty) continue;
        name = value;
        break;
      }
      if (name.isEmpty) continue;
      final folded = normalize(name);
      final prev = buckets[folded];
      if (prev == null || _namedRichness(row) > _namedRichness(prev)) {
        buckets[folded] = row;
      }
    }
    return buckets.values.toList();
  }

  static int _namedRichness(Map<String, dynamic> row) {
    final symptoms = row['symptoms'];
    final n = symptoms is List ? symptoms.length : 0;
    final text =
        '${row['description'] ?? row['meaning'] ?? row['generalInfoAr'] ?? ''}';
    return n * 100 + text.length;
  }

  static List<String> uniqueIds(List<Map<String, dynamic>> rows) {
    return rows.map((row) => '${row['id']}').toSet().toList();
  }
}
