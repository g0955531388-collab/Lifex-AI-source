/// =============================================================
/// Lifex-AI — المرجع المحلي
/// الملف: local_knowledge.dart
/// بحث في قواعد الأمراض والأدوية والأعراض والتحاليل على الجهاز.
/// =============================================================
library lifex_ai.core.local_knowledge;

import 'dart:convert';

import 'package:flutter/services.dart';

import 'medical_record_canon.dart';

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
  });

  final List<Map<String, dynamic>> diseases;
  final List<Map<String, dynamic>> medications;
  final List<Map<String, dynamic>> symptoms;
  final List<Map<String, dynamic>> tests;
  final List<Map<String, dynamic>> namedConditions;
  final List<Map<String, dynamic>> cameraSigns;
  final String disclaimerAr;

  bool get sourcesReady =>
      diseases.isNotEmpty ||
      medications.isNotEmpty ||
      symptoms.isNotEmpty ||
      tests.isNotEmpty ||
      namedConditions.isNotEmpty ||
      cameraSigns.isNotEmpty;

  static Future<List<Map<String, dynamic>>> _readList(String asset) async {
    try {
      final decoded = jsonDecode(await rootBundle.loadString(asset));
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry is Map) Map<String, dynamic>.from(entry),
      ];
    } catch (_) {
      return const [];
    }
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
    final extraConditions = MedicalRecordCanon.uniqueNamedRows([
      ...await _readList('lib/data/reference/conditions_db_1000.json'),
      ...await _readList('lib/data/reference/genital_conditions.json'),
      ...await _readList('lib/data/reference/hands_conditions.json'),
      ...await _readList('lib/data/reference/skin_hair_conditions.json'),
    ]);
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
      namedConditions: extraConditions,
      cameraSigns: MedicalRecordCanon.uniqueNamedRows(
        [
          ...await _readList('lib/data/reference/SmartCameraSigns.json'),
          ...await _readList('lib/data/reference/face_sign_extras.json'),
        ],
        nameKeys: const ['sign', 'name'],
      ),
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
    scan(namedConditions, 'حالة مرجعية', ['name', 'nameAr', 'description']);
    scan(cameraSigns, 'علامة بصرية', ['sign', 'name', 'meaning']);
    return hits;
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
      scored.add((
        score: score,
        hit: KnowledgeHit(
          kindAr: kind,
          titleAr: (row['nameAr'] ?? row['name'] ?? row['sign'] ?? row['id'])
              .toString(),
          detailAr:
              '${row['description'] ?? row['meaning'] ?? row['generalInfoAr'] ?? ''} '
              'مرجع توعية فقط. ليس تشخيصاً.',
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
