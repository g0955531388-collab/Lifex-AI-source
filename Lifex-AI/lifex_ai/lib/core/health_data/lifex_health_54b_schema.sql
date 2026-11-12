-- Lifex-AI 54-B.1 relational source of truth (SQLite).
-- Graph and search are projections of health_relationships / names.
-- Language models must not query patient tables directly.

PRAGMA foreign_keys = ON;

-- 01 Knowledge
CREATE TABLE health_concepts (
  concept_id TEXT PRIMARY KEY,
  concept_type TEXT NOT NULL,
  canonical_name TEXT NOT NULL,
  definition TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  version TEXT NOT NULL DEFAULT '1',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE health_concept_names (
  name_id TEXT PRIMARY KEY,
  concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  language TEXT NOT NULL,
  name TEXT NOT NULL,
  name_type TEXT NOT NULL,
  preferred INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE diseases (
  disease_id TEXT PRIMARY KEY,
  concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  classification TEXT,
  definition TEXT,
  epidemiology TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  version TEXT NOT NULL DEFAULT '1',
  provenance_id TEXT
);

CREATE TABLE disease_symptoms (
  disease_id TEXT NOT NULL REFERENCES diseases(disease_id),
  symptom_id TEXT NOT NULL,
  PRIMARY KEY (disease_id, symptom_id)
);

CREATE TABLE disease_signs (
  disease_id TEXT NOT NULL REFERENCES diseases(disease_id),
  sign_id TEXT NOT NULL,
  PRIMARY KEY (disease_id, sign_id)
);

CREATE TABLE disease_causes (
  disease_id TEXT NOT NULL REFERENCES diseases(disease_id),
  cause_id TEXT NOT NULL,
  PRIMARY KEY (disease_id, cause_id)
);

CREATE TABLE disease_risk_factors (
  disease_id TEXT NOT NULL REFERENCES diseases(disease_id),
  risk_factor_id TEXT NOT NULL,
  PRIMARY KEY (disease_id, risk_factor_id)
);

CREATE TABLE disease_complications (
  disease_id TEXT NOT NULL REFERENCES diseases(disease_id),
  complication_id TEXT NOT NULL,
  PRIMARY KEY (disease_id, complication_id)
);

CREATE TABLE disease_tests (
  disease_id TEXT NOT NULL REFERENCES diseases(disease_id),
  test_id TEXT NOT NULL,
  PRIMARY KEY (disease_id, test_id)
);

CREATE TABLE disease_devices (
  disease_id TEXT NOT NULL REFERENCES diseases(disease_id),
  device_id TEXT NOT NULL,
  PRIMARY KEY (disease_id, device_id)
);

CREATE TABLE disease_medications (
  disease_id TEXT NOT NULL REFERENCES diseases(disease_id),
  medication_id TEXT NOT NULL,
  PRIMARY KEY (disease_id, medication_id)
);

CREATE TABLE symptoms (
  symptom_id TEXT PRIMARY KEY,
  concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  description TEXT,
  category TEXT,
  provenance_id TEXT
);

CREATE TABLE medications (
  medication_id TEXT PRIMARY KEY,
  concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  generic_name TEXT NOT NULL,
  drug_category TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  provenance_id TEXT
);

CREATE TABLE active_ingredients (
  ingredient_id TEXT PRIMARY KEY,
  concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  canonical_name TEXT NOT NULL,
  chemical_reference TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  provenance_id TEXT
);

CREATE TABLE medication_ingredients (
  medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  ingredient_id TEXT NOT NULL REFERENCES active_ingredients(ingredient_id),
  PRIMARY KEY (medication_id, ingredient_id)
);

CREATE TABLE medication_formulations (
  formulation_id TEXT PRIMARY KEY,
  medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  dosage_form TEXT,
  provenance_id TEXT
);

CREATE TABLE medication_strengths (
  strength_id TEXT PRIMARY KEY,
  formulation_id TEXT NOT NULL REFERENCES medication_formulations(formulation_id),
  amount TEXT,
  unit TEXT
);

CREATE TABLE medication_routes (
  route_id TEXT PRIMARY KEY,
  medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  route TEXT NOT NULL
);

CREATE TABLE medication_products (
  product_id TEXT PRIMARY KEY,
  medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  manufacturer_id TEXT,
  brand_name TEXT,
  country TEXT,
  formulation_id TEXT,
  strength_id TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  provenance_id TEXT
);

CREATE TABLE medication_indications (
  indication_id TEXT PRIMARY KEY,
  medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  disease_id TEXT,
  provenance_id TEXT
);

CREATE TABLE medication_contraindications (
  contraindication_id TEXT PRIMARY KEY,
  medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  condition_id TEXT,
  provenance_id TEXT
);

CREATE TABLE medication_interactions (
  interaction_id TEXT PRIMARY KEY,
  source_medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  target_medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  severity TEXT,
  mechanism TEXT,
  description TEXT,
  evidence_level TEXT,
  provenance_id TEXT
);

CREATE TABLE medication_warnings (
  warning_id TEXT PRIMARY KEY,
  medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  text TEXT,
  provenance_id TEXT
);

CREATE TABLE medical_devices (
  device_id TEXT PRIMARY KEY,
  concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  manufacturer_id TEXT,
  model TEXT,
  device_class TEXT,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  provenance_id TEXT
);

CREATE TABLE device_capabilities (
  device_id TEXT NOT NULL REFERENCES medical_devices(device_id),
  capability_id TEXT NOT NULL,
  PRIMARY KEY (device_id, capability_id)
);

CREATE TABLE device_measurements (
  device_id TEXT NOT NULL REFERENCES medical_devices(device_id),
  measurement_concept_id TEXT NOT NULL,
  PRIMARY KEY (device_id, measurement_concept_id)
);

CREATE TABLE device_protocols (
  device_id TEXT NOT NULL REFERENCES medical_devices(device_id),
  protocol_id TEXT NOT NULL,
  PRIMARY KEY (device_id, protocol_id)
);

CREATE TABLE device_services (
  device_id TEXT NOT NULL REFERENCES medical_devices(device_id),
  service_id TEXT NOT NULL,
  PRIMARY KEY (device_id, service_id)
);

CREATE TABLE device_warnings (
  warning_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES medical_devices(device_id),
  text TEXT,
  provenance_id TEXT
);

CREATE TABLE laboratory_tests (
  test_id TEXT PRIMARY KEY,
  concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  name TEXT NOT NULL,
  category TEXT,
  specimen_type TEXT,
  method TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  provenance_id TEXT
);

CREATE TABLE test_components (
  component_id TEXT PRIMARY KEY,
  test_id TEXT NOT NULL REFERENCES laboratory_tests(test_id),
  concept_id TEXT,
  name TEXT
);

CREATE TABLE reference_ranges (
  reference_range_id TEXT PRIMARY KEY,
  test_id TEXT REFERENCES laboratory_tests(test_id),
  component_id TEXT,
  low_value REAL,
  high_value REAL,
  unit TEXT,
  population TEXT
);

CREATE TABLE test_methods (
  method_id TEXT PRIMARY KEY,
  test_id TEXT NOT NULL REFERENCES laboratory_tests(test_id),
  method TEXT
);

CREATE TABLE imaging_modalities (
  modality_id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE imaging_studies (
  study_id TEXT PRIMARY KEY,
  modality_id TEXT REFERENCES imaging_modalities(modality_id),
  body_region TEXT,
  study_date TEXT,
  source TEXT,
  provenance_id TEXT
);

CREATE TABLE imaging_findings (
  finding_id TEXT PRIMARY KEY,
  study_id TEXT NOT NULL REFERENCES imaging_studies(study_id),
  description TEXT
);

CREATE TABLE imaging_reports (
  report_id TEXT PRIMARY KEY,
  study_id TEXT NOT NULL REFERENCES imaging_studies(study_id),
  report TEXT,
  provenance_id TEXT
);

-- 02 Patient (sensitive)
CREATE TABLE patients (
  patient_id TEXT PRIMARY KEY,
  identity_id TEXT,
  alias_id TEXT,
  date_of_birth TEXT,
  sex TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE health_observations (
  observation_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  value_numeric REAL,
  value_text TEXT,
  unit TEXT,
  observed_at TEXT NOT NULL,
  source_type TEXT,
  source_id TEXT,
  method TEXT,
  quality TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  provenance_id TEXT,
  supersedes_id TEXT
);

CREATE TABLE patient_conditions (
  patient_condition_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  disease_id TEXT NOT NULL REFERENCES diseases(disease_id),
  status TEXT NOT NULL DEFAULT 'active',
  recorded_at TEXT NOT NULL,
  onset_date TEXT,
  resolved_date TEXT,
  source_type TEXT,
  source_id TEXT,
  provenance_id TEXT
);

CREATE TABLE patient_medications (
  patient_medication_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  medication_id TEXT NOT NULL REFERENCES medications(medication_id),
  status TEXT NOT NULL DEFAULT 'active',
  start_date TEXT,
  end_date TEXT,
  source_type TEXT,
  source_id TEXT,
  provenance_id TEXT
);

CREATE TABLE laboratory_results (
  result_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  test_id TEXT NOT NULL REFERENCES laboratory_tests(test_id),
  value_numeric REAL,
  value_text TEXT,
  unit TEXT,
  reference_range_id TEXT,
  specimen_id TEXT,
  collected_at TEXT,
  resulted_at TEXT,
  laboratory_id TEXT,
  provenance_id TEXT,
  status TEXT NOT NULL DEFAULT 'active'
);

-- 03 Terminology uses health_concepts + health_concept_names

-- 04 Relationships (source of graph projection)
CREATE TABLE health_relationships (
  relationship_id TEXT PRIMARY KEY,
  source_concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  relationship_type TEXT NOT NULL,
  target_concept_id TEXT NOT NULL REFERENCES health_concepts(concept_id),
  provenance_id TEXT,
  confidence REAL,
  status TEXT NOT NULL DEFAULT 'active'
);

-- 05 Provenance
CREATE TABLE data_sources (
  source_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT,
  publisher TEXT,
  version TEXT,
  url_reference TEXT,
  status TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE provenance_records (
  provenance_id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL REFERENCES data_sources(source_id),
  source_version TEXT,
  retrieved_at TEXT NOT NULL,
  effective_at TEXT,
  verification_status TEXT NOT NULL DEFAULT 'unverified'
);

-- 06 Consent
CREATE TABLE health_consents (
  consent_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL,
  granted_to TEXT NOT NULL,
  purpose TEXT,
  scope TEXT NOT NULL,
  granted_at TEXT NOT NULL,
  expires_at TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  revoked_at TEXT
);

-- 07 Synchronization
CREATE TABLE health_sync_records (
  sync_id TEXT PRIMARY KEY,
  device_id TEXT,
  record_id TEXT NOT NULL,
  record_version TEXT,
  operation TEXT NOT NULL,
  created_at TEXT NOT NULL,
  synced_at TEXT,
  status TEXT NOT NULL,
  conflict_id TEXT
);

-- 08 Audit + conflicts
CREATE TABLE health_audit_events (
  event_id TEXT PRIMARY KEY,
  actor_id TEXT,
  action TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT,
  timestamp TEXT NOT NULL,
  result TEXT,
  authorization_id TEXT,
  previous_hash TEXT,
  integrity_hash TEXT
);

CREATE TABLE health_data_conflicts (
  conflict_id TEXT PRIMARY KEY,
  record_id TEXT,
  source_a TEXT,
  source_b TEXT,
  value_a TEXT,
  value_b TEXT,
  detected_at TEXT NOT NULL,
  resolution_status TEXT NOT NULL DEFAULT 'open',
  resolution_source TEXT
);

CREATE INDEX idx_observations_patient_time ON health_observations(patient_id, observed_at);
CREATE INDEX idx_observations_concept_status ON health_observations(concept_id, status);
CREATE INDEX idx_concepts_status ON health_concepts(concept_id, status);
CREATE INDEX idx_disease_med ON disease_medications(disease_id, medication_id);
CREATE INDEX idx_source_version ON provenance_records(source_id, source_version);
CREATE INDEX idx_patient_conditions ON patient_conditions(patient_id, disease_id);
CREATE INDEX idx_patient_meds ON patient_medications(patient_id, medication_id);
CREATE INDEX idx_lab_results_patient ON laboratory_results(patient_id, resulted_at);
CREATE INDEX idx_relationships_source ON health_relationships(source_concept_id, status);
CREATE INDEX idx_names_concept ON health_concept_names(concept_id, language);
