/// =============================================================
/// Lifex-AI — مخطط
/// الملف: health_schema.dart
/// =============================================================
enum HealthTableLayer {
  knowledge,
  patient,
  terminology,
  relationship,
  provenance,
  consent,
  sync,
  audit,
}

class HealthTableSpec {
  const HealthTableSpec({
    required this.name,
    required this.layer,
    this.sensitive = false,
    this.aiDirectAccess = false,
  });

  final String name;
  final HealthTableLayer layer;
  final bool sensitive;
  final bool aiDirectAccess;
}

class HealthSchemaCatalog {
  static const tables = <HealthTableSpec>[
    HealthTableSpec(name: 'health_concepts', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'health_concept_names', layer: HealthTableLayer.terminology),
    HealthTableSpec(name: 'diseases', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'disease_symptoms', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'disease_signs', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'disease_causes', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'disease_risk_factors', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'disease_complications', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'disease_tests', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'disease_devices', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'disease_medications', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'symptoms', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medications', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'active_ingredients', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medication_ingredients', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medication_formulations', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medication_strengths', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medication_routes', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medication_products', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medication_indications', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medication_contraindications', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medication_interactions', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medication_warnings', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'medical_devices', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'device_capabilities', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'device_measurements', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'device_protocols', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'device_services', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'device_warnings', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'laboratory_tests', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'test_components', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'reference_ranges', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'test_methods', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'imaging_modalities', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'imaging_studies', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'imaging_findings', layer: HealthTableLayer.knowledge),
    HealthTableSpec(name: 'imaging_reports', layer: HealthTableLayer.knowledge),
    HealthTableSpec(
      name: 'patients',
      layer: HealthTableLayer.patient,
      sensitive: true,
    ),
    HealthTableSpec(
      name: 'health_observations',
      layer: HealthTableLayer.patient,
      sensitive: true,
    ),
    HealthTableSpec(
      name: 'patient_conditions',
      layer: HealthTableLayer.patient,
      sensitive: true,
    ),
    HealthTableSpec(
      name: 'patient_medications',
      layer: HealthTableLayer.patient,
      sensitive: true,
    ),
    HealthTableSpec(
      name: 'laboratory_results',
      layer: HealthTableLayer.patient,
      sensitive: true,
    ),
    HealthTableSpec(name: 'health_relationships', layer: HealthTableLayer.relationship),
    HealthTableSpec(name: 'data_sources', layer: HealthTableLayer.provenance),
    HealthTableSpec(name: 'provenance_records', layer: HealthTableLayer.provenance),
    HealthTableSpec(name: 'health_consents', layer: HealthTableLayer.consent, sensitive: true),
    HealthTableSpec(name: 'health_sync_records', layer: HealthTableLayer.sync),
    HealthTableSpec(name: 'health_audit_events', layer: HealthTableLayer.audit),
    HealthTableSpec(name: 'health_data_conflicts', layer: HealthTableLayer.audit, sensitive: true),
  ];

  static const compositeIndexes = <String>[
    'idx_observations_patient_time',
    'idx_observations_concept_status',
    'idx_disease_med',
    'idx_source_version',
  ];

  static Set<String> tableNames() => {for (final t in tables) t.name};

  static bool aiMayAccessDirectly(String table) {
    for (final spec in tables) {
      if (spec.name != table) continue;
      if (spec.sensitive) return false;
      return spec.layer == HealthTableLayer.knowledge ||
          spec.layer == HealthTableLayer.terminology ||
          spec.layer == HealthTableLayer.relationship;
    }
    return false;
  }

  static Set<String> parseCreateTableNames(String sql) {
    final names = <String>{};
    final re = RegExp(r'CREATE TABLE\s+(\w+)', caseSensitive: false);
    for (final m in re.allMatches(sql)) {
      names.add(m.group(1)!);
    }
    return names;
  }
}
