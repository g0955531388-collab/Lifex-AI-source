-- 66 Lifex Global Donations Network
-- Campaign != donation != payment != ledger != disbursement != expenditure.
-- Real money movement stays in 51. No PAN/CVV.

CREATE TABLE donation_campaigns (
  campaign_id TEXT PRIMARY KEY,
  organizer_id TEXT NOT NULL,
  beneficiary_id TEXT NOT NULL,
  title TEXT NOT NULL,
  target_minor INTEGER NOT NULL,
  raised_minor INTEGER NOT NULL DEFAULT 0,
  disbursed_minor INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL,
  status TEXT NOT NULL,
  verified INTEGER NOT NULL DEFAULT 0,
  exposes_full_health_record INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE donation_intents (
  intent_id TEXT PRIMARY KEY,
  donor_id TEXT NOT NULL,
  campaign_id TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  visibility TEXT NOT NULL,
  designation TEXT NOT NULL,
  status TEXT NOT NULL
);

CREATE TABLE campaign_donations (
  donation_id TEXT PRIMARY KEY,
  intent_id TEXT NOT NULL,
  donor_id TEXT NOT NULL,
  campaign_id TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  visibility TEXT NOT NULL,
  status TEXT NOT NULL,
  payment_intent_id TEXT,
  financial_donation_id TEXT
);

CREATE TABLE donation_allocations (
  allocation_id TEXT PRIMARY KEY,
  donation_id TEXT NOT NULL,
  purpose TEXT NOT NULL,
  amount_minor INTEGER NOT NULL
);

CREATE TABLE donation_disbursements (
  disbursement_id TEXT PRIMARY KEY,
  campaign_id TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  requester_id TEXT NOT NULL,
  approver_id TEXT,
  status TEXT NOT NULL,
  payment_confirmed INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE donation_receipts (
  receipt_id TEXT PRIMARY KEY,
  donation_id TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  issued_at TEXT NOT NULL,
  tax_deductible_assumed INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE donation_audit (
  event_id TEXT PRIMARY KEY,
  action TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  actor_id TEXT,
  created_at TEXT NOT NULL,
  integrity_hash TEXT
);
