/// =============================================================
/// Lifex-AI — المرجع المحلي
/// الملف: local_knowledge.dart
/// بحث في قواعد الأمراض والأدوية والأعراض والتحاليل على الجهاز.
/// =============================================================
library lifex_ai.core.local_knowledge;

import 'dart:convert';

import 'package:flutter/services.dart';

import 'medical_record_canon.dart';
import 'reference_ledger.dart';

class KnowledgeHit {
  const KnowledgeHit({
    required this.kindAr,
    required this.titleAr,
    required this.detailAr,
  });

  final String kindAr;
  final String titleAr;
  final String detailAr;
}

class LocalKnowledge {
  LocalKnowledge({
    required this.diseases,
    required this.medications,
    required this.symptoms,
    required this.tests,
    required this.namedConditions,
    required this.cameraSigns,
    required this.disclaimerAr,
    this.references = ReferenceLedger.empty,
  });

  final List<Map<String, dynamic>> diseases;
  final List<Map<String, dynamic>> medications;
  final List<Map<String, dynamic>> symptoms;
  final List<Map<String, dynamic>> tests;
  final List<Map<String, dynamic>> namedConditions;
  final List<Map<String, dynamic>> cameraSigns;
  final String disclaimerAr;
  final ReferenceLedger references;

  bool get sourcesReady =>
      diseases.isNotEmpty ||
      medications.isNotEmpty ||
      symptoms.isNotEmpty ||
      tests.isNotEmpty ||
      namedConditions.isNotEmpty ||
      cameraSigns.isNotEmpty;

  static const referenceAssets = [
    'lib/data/reference/SmartCameraSigns.json',
    'lib/data/reference/face_sign_extras.json',
    'lib/data/reference/conditions_db_1000.json',
    'lib/data/reference/genital_conditions.json',
    'lib/data/reference/hands_conditions.json',
    'lib/data/reference/skin_hair_conditions.json',
    'lib/data/reference/Height_Weight.json',
    'lib/data/reference/incoming_reference.json',
    'lib/data/reference/drugs/Analgesics.json',
    'lib/data/reference/drugs/Antibiotics.json',
    'lib/data/reference/drugs/Antidiabetic.json',
    'lib/data/reference/drugs/Antifungal.json',
    'lib/data/reference/drugs/Antihypertensive.json',
    'lib/data/reference/drugs/AntiInflammatory.json',
    'lib/data/reference/drugs/Antipyretics.json',
    'lib/data/reference/drugs/Antiviral.json',
    'lib/data/reference/drugs/Cardiac.json',
    'lib/data/reference/drugs/Gastrointestinal.json',
    'lib/data/reference/drugs/MiscellaneousDrugs.json',
    'lib/data/reference/drugs/NeuroPsych.json',
    'lib/data/reference/drugs/Oncology.json',
    'lib/data/reference/drugs/PregnancySupplements.json',
    'lib/data/reference/drugs/Respiratory.json',
    'lib/data/reference/drugs/SexualHealth.json',
    'lib/data/reference/drugs/Vitamins.json',
  ];

  static Future<ReferenceLedger> _loadReferences() async {
    final documents = <String, Object?>{};
    for (final asset in referenceAssets) {
      try {
        final decoded = jsonDecode(await rootBundle.loadString(asset));
        documents[asset] = decoded;
      } catch (_) {}
    }
    return ReferenceLedger.fromDocuments(documents);
  }

  static Future<LocalKnowledge> load() async {
    Future<Map<String, dynamic>> read(String name) async {
      try {
        final raw = await rootBundle.loadString('lib/data/medical/$name');
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return const {};
      }
    }

    final diseasesJson = await read('diseases_database.json');
    final medsJson = await read('medications_database.json');
    final symptomsJson = await read('symptoms_database.json');
    final testsJson = await read('tests_database.json');
    final references = await _loadReferences();
    return LocalKnowledge(
      diseases: MedicalRecordCanon.uniqueDiseases(
        List<Map<String, dynamic>>.from(
            diseasesJson['diseases'] as List? ?? const []),
      ),
      medications: List<Map<String, dynamic>>.from(
          medsJson['medications'] as List? ?? const []),
      symptoms: List<Map<String, dynamic>>.from(
          symptomsJson['symptoms'] as List? ?? const []),
      tests: List<Map<String, dynamic>>.from(
          testsJson['tests'] as List? ?? const []),
      namedConditions: references.merged(kind: 'حالة مرجعية'),
      cameraSigns: references.merged(kind: 'علامة بصرية'),
      references: references,
      disclaimerAr: (diseasesJson['_meta'] as Map?)?['disclaimer_ar']
              as String? ??
          MedicalRecordCanon.disclaimerAr,
    );
  }

  List<KnowledgeHit> search(String query) {
    final q = MedicalRecordCanon.normalize(query);
    if (q.isEmpty) return const [];
    final hits = <KnowledgeHit>[];
    void scan(
      List<Map<String, dynamic>> rows,
      String kind,
      List<String> keys, {
      int limit = 4,
    }) {
      var taken = 0;
      for (final row in rows) {
        final blob = MedicalRecordCanon.normalize(
          keys.map((k) => '${row[k] ?? ''}').join(' '),
        );
        if (!MedicalRecordCanon.queryMatches(blob, q)) continue;
        hits.add(
          KnowledgeHit(
            kindAr: kind,
            titleAr: (row['nameAr'] ??
                    row['name'] ??
                    row['sign'] ??
                    row['id'])
                .toString(),
            detailAr: (row['generalInfoAr'] ??
                    row['description'] ??
                    row['meaning'] ??
                    row['nameEn'] ??
                    '')
                .toString(),
          ),
        );
        taken++;
        if (taken >= limit) return;
      }
    }

    scan(diseases, 'مرض', ['nameAr', 'nameEn', 'generalInfoAr']);
    scan(medications, 'دواء', ['nameAr', 'nameEn']);
    scan(symptoms, 'عرض', ['nameAr', 'nameEn']);
    scan(tests, 'تحليل', ['nameAr', 'nameEn']);
    scan(namedConditions, 'حالة مرجعية', ['name', 'nameAr', 'description', 'symptoms']);
    scan(cameraSigns, 'علامة بصرية', ['sign', 'name', 'meaning']);
    scan(
      references.merged(kind: 'دواء مرجعي'),
      'دواء مرجعي',
      ['name', 'form', 'strength', 'description'],
    );
    scan(
      references.merged(kind: 'معيار نمو'),
      'معيار نمو',
      ['age_group', 'name'],
    );
    hits.addAll(_referenceHits(q));
    final seen = <String>{};
    return [
      for (final hit in hits)
        if (seen.add('${hit.kindAr}|${hit.titleAr}|${hit.detailAr}')) hit,
    ];
  }

  List<Map<String, dynamic>> compareReferences(String query) =>
      references.compare(query);

  List<ReferenceConflict> referenceConflicts(String query) =>
      references.conflictsFor(query);

  List<KnowledgeHit> _referenceHits(String q) {
    return [
      for (final item in references.conflictsFor(q).take(4))
        KnowledgeHit(
          kindAr: 'تعارض مراجع',
          titleAr: item.title,
          detailAr: '${item.noteAr} ${item.bodies.join(' | ')}',
        ),
    ];
  }

  /// تطابق أعراض أو علامة كاميرا أدخلها المستخدم مع المرجع. ليس تشخيصاً.
  List<KnowledgeHit> rankByEnteredClues({
    required List<String> symptoms,
    String? cameraHint,
  }) {
    final clues = [
      for (final item in symptoms) MedicalRecordCanon.normalize(item),
      if (cameraHint != null) MedicalRecordCanon.normalize(cameraHint),
    ].where((item) => item.isNotEmpty).toList();
    if (clues.isEmpty) return const [];

    final scored = <({int score, KnowledgeHit hit})>[];
    void consider(Map<String, dynamic> row, String kind, List<String> keys) {
      final blob = MedicalRecordCanon.normalize(
        keys.map((k) {
          final value = row[k];
          if (value is List) return value.join(' ');
          return '$value';
        }).join(' '),
      );
      if (blob.isEmpty) return;
      var score = 0;
      for (final clue in clues) {
        if (blob.contains(clue)) score += 2;
      }
      if (cameraHint != null &&
          MedicalRecordCanon.normalize('${row['sign'] ?? row['patterns'] ?? ''}')
              .contains(MedicalRecordCanon.normalize(cameraHint))) {
        score += 5;
      }
      if (score <= 0) return;
      final title =
          (row['nameAr'] ?? row['name'] ?? row['sign'] ?? row['id']).toString();
      final conflict = references.conflictsFor(title);
      final note = conflict.isEmpty ? '' : ' ${conflict.first.noteAr}';
      scored.add((
        score: score,
        hit: KnowledgeHit(
          kindAr: kind,
          titleAr: title,
          detailAr:
              '${row['description'] ?? row['meaning'] ?? row['generalInfoAr'] ?? ''} '
              'مرجع توعية فقط. ليس تشخيصاً.$note',
        ),
      ));
    }

    for (final row in namedConditions) {
      consider(row, 'حالة مرجعية', ['name', 'description', 'symptoms']);
    }
    for (final row in cameraSigns) {
      consider(row, 'علامة بصرية', ['sign', 'name', 'meaning']);
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return [for (final item in scored.take(8)) item.hit];
  }
}
