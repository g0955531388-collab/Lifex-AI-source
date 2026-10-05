/// =============================================================
/// Lifex-AI — اختبار
/// الملف: health_data_engine_test.dart
/// =============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/health_data/health_data_engine.dart';
import 'package:lifex_ai/core/health_data/health_data_types.dart';

void main() {
  test('hybrid store keeps knowledge separate from patient data; observation is not diagnosis', () {
    final e = LifexHealthDataEngine();
    e.putProvenance(
      ProvenanceRecord(
        sourceId: 'src1',
        sourceName: 'label',
        sourceType: 'official',
        version: '1',
        retrievedAt: DateTime.utc(2026, 9, 18),
      ),
    );
    e.putDisease(
      const Disease(
        diseaseId: 'd1',
        concept: HealthConcept(
          conceptId: 'mi',
          category: 'disease',
          canonicalName: 'Myocardial Infarction',
          synonyms: ['احتشاء عضلة القلب', 'الجلطة القلبية', 'MI'],
        ),
        symptomIds: ['chest_pain'],
      ),
    );
    expect(e.layerOf(e.getDisease('d1')!), DataLayer.globalKnowledge);
    expect(e.search('الجلطة').single.conceptId, 'mi');
    expect(e.observationIsDiagnosis(
      HealthObservation(
        observationId: 'o0',
        patientId: 'p1',
        conceptId: 'temp',
        value: 38.2,
        unit: 'C',
        observedAt: DateTime.utc(2026, 9, 18),
        sourceType: 'device',
        sourceId: 'dev',
        provenanceId: 'src1',
      ),
    ), isFalse);
    expect(e.atcIsIndication('C01'), isFalse);
    expect(e.symptomOverlapIsDiagnosis(['chest_pain']), isFalse);
    expect(e.wouldAutoPrescribe(), isFalse);
  });

  test('consent gates records; correction supersedes; conflicts stay', () {
    final e = LifexHealthDataEngine();
    final t = DateTime.utc(2026, 9, 18, 2);
    e.putProvenance(
      ProvenanceRecord(
        sourceId: 'src1',
        sourceName: 'oximeter',
        sourceType: 'device',
        version: '1',
        retrievedAt: t,
      ),
    );
    e.putPatient(
      PatientProfile(
        patientId: 'p1',
        aliasId: 'Lifex-User-27',
        createdAt: t,
        updatedAt: t,
      ),
    );
    expect(
      e.addObservation(
        HealthObservation(
          observationId: 'o1',
          patientId: 'p1',
          conceptId: 'spo2',
          value: 97,
          unit: '%',
          observedAt: t,
          sourceType: 'device',
          sourceId: 'ox1',
          provenanceId: 'src1',
        ),
      ),
      isNull,
    );
    e.putConsent(
      HealthConsent(
        consentId: 'c1',
        subjectId: 'p1',
        purpose: 'care',
        scopes: ['observation.write', 'observation.read', 'lab.write'],
        grantedAt: t,
      ),
    );
    expect(
      e.addObservation(
        HealthObservation(
          observationId: 'o1',
          patientId: 'p1',
          conceptId: 'spo2',
          value: 97,
          unit: '%',
          observedAt: t,
          sourceType: 'device',
          sourceId: 'ox1',
          provenanceId: 'src1',
        ),
      ),
      'o1',
    );
    e.addObservation(
      HealthObservation(
        observationId: 'o2',
        patientId: 'p1',
        conceptId: 'spo2',
        value: 91,
        unit: '%',
        observedAt: t.add(const Duration(minutes: 1)),
        sourceType: 'device',
        sourceId: 'ox2',
        provenanceId: 'src1',
      ),
    );
    expect(e.detectConflicts('p1', 'spo2'), isNotEmpty);
    e.addObservation(
      HealthObservation(
        observationId: 'o3',
        patientId: 'p1',
        conceptId: 'spo2',
        value: 96,
        unit: '%',
        observedAt: t.add(const Duration(minutes: 2)),
        sourceType: 'device',
        sourceId: 'ox1',
        provenanceId: 'src1',
        supersedesId: 'o1',
      ),
    );
    expect(
      e.getObservations('p1', at: t).firstWhere((o) => o.observationId == 'o1').status,
      HealthRecordStatus.superseded,
    );
    expect(e.convertUnit(value: 37, from: 'C', to: 'F'), contains('F'));
    expect(e.validateRecord('o3').hasProvenance, isTrue);
  });
}
