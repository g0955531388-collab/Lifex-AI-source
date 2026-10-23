/// =============================================================
/// Lifex-AI — موديول ربط ملفات JSON الطبية
/// يقرأ الحزمة الخماسية وقاموس القياسات ويبني فهرس معرّفات.
/// الرابط معلومة مرجعية: ليس تشخيصاً وليس وصفة ولا جرعة.
/// =============================================================
library lifex_ai.data.medical_json_link_module;

import 'medical_database_manager.dart';

class MedicalJsonLink {
  const MedicalJsonLink({
    required this.relation,
    required this.fromFile,
    required this.fromId,
    required this.toFile,
    required this.toId,
    required this.toNameAr,
    required this.resolved,
    required this.noteAr,
  });

  final String relation;
  final String fromFile;
  final String fromId;
  final String toFile;
  final String toId;
  final String toNameAr;
  final bool resolved;
  final String noteAr;
}

class MedicalJsonLinkIndex {
  const MedicalJsonLinkIndex({
    required this.links,
    required this.measurementsByKey,
    this.skinHairDiseaseIds = const {},
  });

  static const bool automaticPrescribingAllowed = false;
  static const bool automaticDiagnosisAllowed = false;

  final List<MedicalJsonLink> links;

  /// مفتاح القياس → measurement_id. لا يحوي مجالاً مرجعياً رقمياً.
  final Map<String, String> measurementsByKey;

  /// معرّف المرجع الجلدي → معرّف مرض قائم عند تطابق الاسم فقط.
  final Map<String, String> skinHairDiseaseIds;

  List<MedicalJsonLink> from(String file, String id) {
    return links
        .where((link) => link.fromFile == file && link.fromId == id)
        .toList(growable: false);
  }

  List<MedicalJsonLink> unresolved() {
    return links.where((link) => !link.resolved).toList(growable: false);
  }

  String? measurementIdForKey(String key) => measurementsByKey[key];

  String? diseaseIdForSkinHairReference(String referenceId) =>
      skinHairDiseaseIds[referenceId];
}

/// يربط ملفات JSON الموجودة بالمعرّف. لا ينشئ سجلات طبية جديدة.
class MedicalJsonLinkModule {
  const MedicalJsonLinkModule();

  static const symptomNoteAr = 'إشارة مرجعية بين الملفات. ليست تشخيصاً.';
  static const testNoteAr =
      'الفحص مذكور في طبقة الربط. ليس أمراً بإجرائه لكل شخص.';
  static const medicationNoteAr =
      'رابط معلوماتي إلى سجل دواء. ليس وصفة ولا جرعة.';
  static const interactionNoteAr =
      'معرّف تفاعل مذكور داخل سجل الدواء. ليس قراراً سريرياً.';
  static const emergencyNoteAr =
      'قاعدة تصعيد مذكورة في طبقة الربط. الأولوية للسلامة لا لقائمة أمراض.';
  static const skinHairNoteAr =
      'مطابقة اسم مع سجل المرض القائم. ليست تشخيصاً.';

  MedicalJsonLinkIndex build({
    required Map<String, Map<String, dynamic>> bundle,
    Map<String, dynamic>? biometricCatalog,
    Map<String, dynamic>? skinHairCatalog,
  }) {
    final diseases = _byId(
      bundle[MedicalBundleFiles.diseases],
      'diseases',
    );
    final symptoms = _byId(
      bundle[MedicalBundleFiles.symptoms],
      'symptoms',
    );
    final tests = _byId(bundle[MedicalBundleFiles.tests], 'tests');
    final medications = _byId(
      bundle[MedicalBundleFiles.medications],
      'medications',
    );
    final knowledge = bundle[MedicalBundleFiles.knowledge] ?? const {};
    final links = <MedicalJsonLink>[];

    for (final disease in diseases.values) {
      final diseaseId = disease['id'] as String? ?? '';
      if (diseaseId.isEmpty) continue;
      for (final symptomId in _ids(disease['commonSymptomsIds'])) {
        links.add(
          _link(
            relation: 'listed_symptom',
            fromFile: MedicalBundleFiles.diseases,
            fromId: diseaseId,
            toFile: MedicalBundleFiles.symptoms,
            toId: symptomId,
            target: symptoms[symptomId],
            noteAr: symptomNoteAr,
          ),
        );
      }
    }

    for (final raw in _rows(knowledge['diseaseSymptomLinks'])) {
      final diseaseId = raw['diseaseId'] as String? ?? '';
      if (diseaseId.isEmpty) continue;
      for (final symptomId in _ids(raw['symptomIds'])) {
        links.add(
          _link(
            relation: 'knowledge_symptom',
            fromFile: MedicalBundleFiles.knowledge,
            fromId: diseaseId,
            toFile: MedicalBundleFiles.symptoms,
            toId: symptomId,
            target: symptoms[symptomId],
            noteAr: symptomNoteAr,
          ),
        );
      }
    }

    for (final raw in _rows(knowledge['diseaseTestLinks'])) {
      final diseaseId = raw['diseaseId'] as String? ?? '';
      if (diseaseId.isEmpty) continue;
      for (final testId in _ids(raw['recommendedTestIds'])) {
        links.add(
          _link(
            relation: 'knowledge_test',
            fromFile: MedicalBundleFiles.knowledge,
            fromId: diseaseId,
            toFile: MedicalBundleFiles.tests,
            toId: testId,
            target: tests[testId],
            noteAr: testNoteAr,
          ),
        );
      }
    }

    for (final raw in _rows(knowledge['diseaseMedicationLinks'])) {
      final diseaseId = raw['diseaseId'] as String? ?? '';
      if (diseaseId.isEmpty) continue;
      for (final medicationId in _ids(raw['commonMedicationIds'])) {
        links.add(
          _link(
            relation: 'knowledge_medication_reference',
            fromFile: MedicalBundleFiles.knowledge,
            fromId: diseaseId,
            toFile: MedicalBundleFiles.medications,
            toId: medicationId,
            target: medications[medicationId],
            noteAr: medicationNoteAr,
          ),
        );
      }
    }

    for (final medication in medications.values) {
      final medicationId = medication['id'] as String? ?? '';
      if (medicationId.isEmpty) continue;
      for (final otherId in _ids(medication['knownInteractionsWithIds'])) {
        links.add(
          _link(
            relation: 'medication_interaction_reference',
            fromFile: MedicalBundleFiles.medications,
            fromId: medicationId,
            toFile: MedicalBundleFiles.medications,
            toId: otherId,
            target: medications[otherId],
            noteAr: interactionNoteAr,
          ),
        );
      }
    }

    for (final raw in _rows(knowledge['emergencyEscalationRules'])) {
      for (final symptomId in _ids(raw['triggerSymptomIds'])) {
        links.add(
          _link(
            relation: 'emergency_symptom',
            fromFile: MedicalBundleFiles.knowledge,
            fromId: 'emergencyEscalationRules',
            toFile: MedicalBundleFiles.symptoms,
            toId: symptomId,
            target: symptoms[symptomId],
            noteAr: emergencyNoteAr,
          ),
        );
      }
    }

    final measurementsByKey = <String, String>{};
    for (final raw in _rows(biometricCatalog?['measurements'])) {
      final measurementId = raw['measurement_id'] as String? ?? '';
      final key = raw['key'] as String? ?? '';
      if (measurementId.isEmpty || key.isEmpty) continue;
      measurementsByKey[key] = measurementId;
    }

    final skinHairDiseaseIds = _skinHairNameLinks(
      diseases: diseases,
      catalog: skinHairCatalog,
      links: links,
    );

    return MedicalJsonLinkIndex(
      links: List.unmodifiable(links),
      measurementsByKey: Map.unmodifiable(measurementsByKey),
      skinHairDiseaseIds: Map.unmodifiable(skinHairDiseaseIds),
    );
  }

  Map<String, String> _skinHairNameLinks({
    required Map<String, Map<String, dynamic>> diseases,
    required Map<String, dynamic>? catalog,
    required List<MedicalJsonLink> links,
  }) {
    final byTitle = <String, String>{};
    final ambiguous = <String>{};
    for (final disease in diseases.values) {
      final id = disease['id'] as String? ?? '';
      final title = _title(_nameAr(disease));
      if (id.isEmpty || title.isEmpty) continue;
      final previous = byTitle[title];
      if (previous != null && previous != id) {
        ambiguous.add(title);
      } else {
        byTitle[title] = id;
      }
    }
    for (final title in ambiguous) {
      byTitle.remove(title);
    }

    final matched = <String, String>{};
    for (final raw in _rows(catalog?['records'])) {
      final referenceId = raw['reference_id'] as String? ?? '';
      final title = _title(raw['name_ar'] as String? ?? '');
      if (referenceId.isEmpty || title.isEmpty) continue;
      final diseaseId = byTitle[title];
      if (diseaseId == null) continue;
      matched[referenceId] = diseaseId;
      links.add(
        _link(
          relation: 'skin_hair_name_reference',
          fromFile: MedicalBundleFiles.skinHair,
          fromId: referenceId,
          toFile: MedicalBundleFiles.diseases,
          toId: diseaseId,
          target: diseases[diseaseId],
          noteAr: skinHairNoteAr,
        ),
      );
    }
    return matched;
  }

  MedicalJsonLink _link({
    required String relation,
    required String fromFile,
    required String fromId,
    required String toFile,
    required String toId,
    required Map<String, dynamic>? target,
    required String noteAr,
  }) {
    final name = target == null ? '' : _nameAr(target);
    return MedicalJsonLink(
      relation: relation,
      fromFile: fromFile,
      fromId: fromId,
      toFile: toFile,
      toId: toId,
      toNameAr: name,
      resolved: target != null,
      noteAr: noteAr,
    );
  }

  Map<String, Map<String, dynamic>> _byId(
    Map<String, dynamic>? json,
    String listKey,
  ) {
    final index = <String, Map<String, dynamic>>{};
    for (final row in _rows(json?[listKey])) {
      final id = row['id'] as String? ?? '';
      if (id.isEmpty) continue;
      index[id] = row;
    }
    return index;
  }

  List<Map<String, dynamic>> _rows(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  List<String> _ids(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((item) => item.toString()).where((id) => id.isNotEmpty).toList();
  }

  String _nameAr(Map<String, dynamic> row) {
    final nameAr = row['nameAr'] ?? row['name_ar'];
    if (nameAr is String && nameAr.isNotEmpty) return nameAr;
    final nameEn = row['nameEn'] ?? row['name_en'];
    return nameEn is String ? nameEn : '';
  }

  String _title(String raw) {
    final trimmed =
        raw.replaceAll('\u0640', '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = RegExp(r'^(.*?)\s*\(([^)]+)\)\s*$').firstMatch(trimmed);
    if (match == null) return trimmed;
    final left = match.group(1)!.trim();
    final right = match.group(2)!.trim();
    final leftLatin = RegExp(r'[A-Za-z]').allMatches(left).length >
        left.runes.length ~/ 2;
    final rightLatin = RegExp(r'[A-Za-z]').allMatches(right).length >
        right.runes.length ~/ 2;
    if (leftLatin && !rightLatin) return right;
    return left;
  }
}
