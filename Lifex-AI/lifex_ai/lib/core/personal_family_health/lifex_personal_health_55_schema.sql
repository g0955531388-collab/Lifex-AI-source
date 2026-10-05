-- Lifex-AI 55 personal & family health (SQLite).
-- Knowledge tables remain in 54-B. These store person-specific records only.

CREATE TABLE persons (
  person_id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE person_identities (
  identity_id TEXT PRIMARY KEY,
  person_id TEXT NOT NULL REFERENCES persons(person_id),
  account_id TEXT NOT NULL,
  type TEXT NOT NULL
);

CREATE TABLE patients (
  patient_id TEXT PRIMARY KEY,
  person_id TEXT NOT NULL REFERENCES persons(person_id),
  identity_id TEXT NOT NULL REFERENCES person_identities(identity_id),
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE patient_aliases (
  alias_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  display_name TEXT NOT NULL,
  public_visible INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE families (
  family_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  primary_patient_id TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE family_memberships (
  membership_id TEXT PRIMARY KEY,
  family_id TEXT NOT NULL REFERENCES families(family_id),
  person_id TEXT NOT NULL REFERENCES persons(person_id),
  role TEXT NOT NULL,
  joined_at TEXT NOT NULL,
  ended_at TEXT
);

CREATE TABLE family_relationships (
  relationship_id TEXT PRIMARY KEY,
  person_a_id TEXT NOT NULL REFERENCES persons(person_id),
  person_b_id TEXT NOT NULL REFERENCES persons(person_id),
  type TEXT NOT NULL,
  confidence REAL
);

CREATE TABLE family_health_history (
  history_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  related_person_id TEXT,
  relationship TEXT NOT NULL,
  disease_id TEXT NOT NULL,
  status TEXT NOT NULL,
  provenance_source_id TEXT
);

CREATE TABLE patient_profiles (
  patient_id TEXT PRIMARY KEY REFERENCES patients(patient_id),
  birth_date TEXT,
  biological_sex TEXT,
  blood_group TEXT,
  rhesus_factor TEXT,
  updated_at TEXT NOT NULL
);

CREATE TABLE patient_conditions (
  condition_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  disease_concept_id TEXT NOT NULL,
  status TEXT NOT NULL,
  onset_date TEXT,
  resolved_date TEXT,
  provenance_source_id TEXT
);

CREATE TABLE patient_symptoms (
  symptom_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  symptom_concept_id TEXT NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  source TEXT
);

CREATE TABLE patient_medications (
  patient_medication_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  medication_id TEXT NOT NULL,
  status TEXT NOT NULL,
  started_at TEXT,
  ended_at TEXT,
  instructions TEXT,
  provenance_source_id TEXT
);

CREATE TABLE patient_allergies (
  allergy_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  allergen_concept_id TEXT NOT NULL,
  verification TEXT,
  provenance_source_id TEXT
);

CREATE TABLE patient_immunizations (
  immunization_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  vaccine_concept_id TEXT NOT NULL,
  administration_date TEXT NOT NULL,
  provenance_source_id TEXT
);

CREATE TABLE patient_observations (
  observation_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  concept_id TEXT NOT NULL,
  value_text TEXT,
  unit TEXT,
  observed_at TEXT NOT NULL,
  source TEXT,
  provenance_source_id TEXT
);

CREATE TABLE patient_vitals (
  vital_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  concept_id TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  device_id TEXT,
  provenance_source_id TEXT
);

CREATE TABLE patient_lab_results (
  result_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  laboratory_test_id TEXT NOT NULL,
  value_text TEXT,
  unit TEXT,
  collected_at TEXT,
  reported_at TEXT,
  laboratory_id TEXT,
  provenance_source_id TEXT
);

CREATE TABLE patient_imaging_studies (
  study_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  imaging_concept_id TEXT,
  performed_at TEXT,
  organization_id TEXT,
  provenance_source_id TEXT
);

CREATE TABLE health_encounters (
  encounter_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  type TEXT NOT NULL,
  started_at TEXT NOT NULL,
  organization_id TEXT
);

CREATE TABLE patient_devices (
  patient_device_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  device_id TEXT NOT NULL,
  relationship TEXT NOT NULL,
  linked_at TEXT NOT NULL
);

CREATE TABLE health_timeline_events (
  event_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  type TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  record_id TEXT NOT NULL
);

CREATE TABLE health_consents (
  consent_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  grantor_id TEXT NOT NULL,
  grantee_id TEXT NOT NULL,
  decision TEXT NOT NULL,
  scopes TEXT NOT NULL,
  purposes TEXT NOT NULL,
  valid_from TEXT NOT NULL,
  valid_until TEXT
);

CREATE TABLE health_delegations (
  delegation_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id),
  delegator_id TEXT NOT NULL,
  delegate_id TEXT NOT NULL,
  scopes TEXT NOT NULL,
  valid_from TEXT NOT NULL,
  valid_until TEXT,
  status TEXT NOT NULL
);

CREATE TABLE health_sync_records (
  sync_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL,
  device_id TEXT,
  record_id TEXT NOT NULL,
  local_version INTEGER,
  remote_version INTEGER,
  status TEXT NOT NULL
);

CREATE TABLE health_conflicts (
  conflict_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL,
  left_id TEXT,
  right_id TEXT,
  value_a TEXT,
  value_b TEXT,
  detected_at TEXT NOT NULL
);

CREATE TABLE health_access_audit (
  audit_id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  action TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  result TEXT NOT NULL,
  consent_id TEXT
);

CREATE INDEX idx_pfh_conditions_patient ON patient_conditions(patient_id, status);
CREATE INDEX idx_pfh_meds_patient ON patient_medications(patient_id, status);
CREATE INDEX idx_pfh_obs_patient_time ON patient_observations(patient_id, observed_at);
CREATE INDEX idx_pfh_vitals_patient_time ON patient_vitals(patient_id, observed_at);
CREATE INDEX idx_pfh_consent_grantee ON health_consents(patient_id, grantee_id);
