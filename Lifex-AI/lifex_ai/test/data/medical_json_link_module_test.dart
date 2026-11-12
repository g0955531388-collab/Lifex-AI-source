import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/data/medical_database_manager.dart';
import 'package:lifex_ai/data/medical_json_link_module.dart';

void main() {
  const module = MedicalJsonLinkModule();

  test('يربط المعرّفات الموجودة ويُبقي المعرّف المفقود غير محلول', () {
    final index = module.build(
      bundle: {
        MedicalBundleFiles.diseases: {
          'diseases': [
            {
              'id': 'd001',
              'nameAr': 'ضغط',
              'commonSymptomsIds': ['s001', 's404'],
            },
          ],
        },
        MedicalBundleFiles.symptoms: {
          'symptoms': [
            {'id': 's001', 'nameAr': 'صداع'},
          ],
        },
        MedicalBundleFiles.tests: {
          'tests': [
            {'id': 't001', 'nameAr': 'تحليل'},
          ],
        },
        MedicalBundleFiles.medications: {
          'medications': [
            {
              'id': 'm001',
              'nameAr': 'دواء',
              'knownInteractionsWithIds': ['m002'],
            },
          ],
        },
        MedicalBundleFiles.knowledge: {
          'diseaseSymptomLinks': [
            {
              'diseaseId': 'd001',
              'symptomIds': ['s001'],
            },
          ],
          'diseaseTestLinks': [
            {
              'diseaseId': 'd001',
              'recommendedTestIds': ['t001'],
            },
          ],
          'diseaseMedicationLinks': [
            {
              'diseaseId': 'd001',
              'commonMedicationIds': ['m001'],
              'note': 'يجب ألا تُنسخ هذه الملاحظة كوصفة',
            },
          ],
          'emergencyEscalationRules': [
            {
              'triggerSymptomIds': ['s001'],
            },
          ],
        },
      },
      biometricCatalog: {
        'measurements': [
          {'measurement_id': 'LX-BIO-001', 'key': 'height'},
        ],
      },
    );

    expect(MedicalJsonLinkIndex.automaticPrescribingAllowed, isFalse);
    expect(MedicalJsonLinkIndex.automaticDiagnosisAllowed, isFalse);
    final listed = index.from(MedicalBundleFiles.diseases, 'd001');
    expect(listed.map((link) => link.toId), containsAll(['s001', 's404']));
    expect(
      listed.firstWhere((link) => link.toId == 's001').resolved,
      isTrue,
    );
    expect(
      listed.firstWhere((link) => link.toId == 's404').resolved,
      isFalse,
    );
    final medication = index
        .from(MedicalBundleFiles.knowledge, 'd001')
        .firstWhere((link) => link.relation == 'knowledge_medication_reference');
    expect(medication.toNameAr, 'دواء');
    expect(medication.noteAr, MedicalJsonLinkModule.medicationNoteAr);
    expect(medication.noteAr.contains('يجب ألا تُنسخ'), isFalse);
    expect(index.unresolved(), isNotEmpty);
    expect(index.measurementIdForKey('height'), 'LX-BIO-001');
    expect(
      index
          .from(MedicalBundleFiles.medications, 'm001')
          .single
          .resolved,
      isFalse,
    );
  });

  test('ملفات JSON الفعلية تُربط بالمعرّف دون اختراع علاقة قياس بمرض', () {
    Map<String, dynamic> read(String name) {
      final file = File('lib/data/medical/$name');
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }

    final index = module.build(
      bundle: {
        for (final name in MedicalBundleFiles.all) name: read(name),
      },
      biometricCatalog: read(MedicalBundleFiles.biometrics),
      skinHairCatalog: read(MedicalBundleFiles.skinHair),
    );
    final skin = read(MedicalBundleFiles.skinHair);
    expect(skin['_meta']['automatic_diagnosis_allowed'], isFalse);
    final skinLinks = index.links
        .where((link) => link.relation == 'skin_hair_name_reference');
    expect(skinLinks, isNotEmpty);
    expect(
      skinLinks.every(
        (link) =>
            link.resolved &&
            link.noteAr == MedicalJsonLinkModule.skinHairNoteAr &&
            link.toFile == MedicalBundleFiles.diseases,
      ),
      isTrue,
    );
    final hinted = (skin['records'] as List).cast<Map>().where(
          (row) => row['kind'] == 'hair_sign_note',
        );
    expect(hinted, isNotEmpty);
    expect(
      hinted.every((row) => row['hint_is_diagnosis'] == false),
      isTrue,
    );
    for (final row in hinted) {
      final referenceId = row['reference_id'] as String;
      final linked = index.diseaseIdForSkinHairReference(referenceId);
      if (linked != null) {
        expect(
          index
              .from(MedicalBundleFiles.skinHair, referenceId)
              .single
              .noteAr,
          MedicalJsonLinkModule.skinHairNoteAr,
        );
      }
    }

    final symptoms = index
        .from(MedicalBundleFiles.knowledge, 'd001')
        .where((link) => link.relation == 'knowledge_symptom');
    expect(symptoms.any((link) => link.toId == 's001' && link.resolved), isTrue);
    expect(index.measurementIdForKey('bmi'), 'LX-BIO-003');
    expect(
      index.links.every((link) => link.toFile != MedicalBundleFiles.biometrics),
      isTrue,
    );
    expect(
      index.links
          .where((link) => link.relation == 'knowledge_medication_reference')
          .every((link) => link.noteAr == MedicalJsonLinkModule.medicationNoteAr),
      isTrue,
    );
  });
}
