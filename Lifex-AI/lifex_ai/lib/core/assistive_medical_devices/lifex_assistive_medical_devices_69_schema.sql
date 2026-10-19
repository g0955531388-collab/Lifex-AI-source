-- 69 Assistive medical devices network
-- Device != ownership != donation != health record.
-- Used devices stay pendingInspection until approved.

CREATE TABLE assistive_devices (
  device_id TEXT PRIMARY KEY,
  knowledge_device_id TEXT,
  category_id TEXT NOT NULL,
  name TEXT NOT NULL,
  country_code TEXT NOT NULL,
  ownership_type TEXT NOT NULL,
  availability_status TEXT NOT NULL,
  condition_status TEXT NOT NULL,
  safety_status TEXT NOT NULL,
  classified_assistive INTEGER NOT NULL DEFAULT 1,
  used_device INTEGER NOT NULL DEFAULT 0,
  serial_number TEXT
);

CREATE TABLE assistive_device_donations (
  donation_id TEXT PRIMARY KEY,
  donor_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  type TEXT NOT NULL,
  status TEXT NOT NULL,
  anonymous INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE assistive_device_requests (
  request_id TEXT PRIMARY KEY,
  beneficiary_id TEXT NOT NULL,
  country_code TEXT NOT NULL,
  functional_needs TEXT NOT NULL,
  requires_professional_assessment INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE assistive_device_loans (
  loan_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  beneficiary_id TEXT NOT NULL,
  due_at TEXT NOT NULL,
  returned INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE assistive_custody (
  event_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  action TEXT NOT NULL,
  actor_id TEXT,
  created_at TEXT NOT NULL
);
