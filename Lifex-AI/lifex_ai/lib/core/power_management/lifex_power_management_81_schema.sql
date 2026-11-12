-- 81 Power management
-- Events and policies. Not a physical battery partition.

CREATE TABLE power_events (
  event_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  type TEXT NOT NULL,
  battery_level INTEGER,
  mode TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE power_policies (
  policy_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  balanced_below INTEGER NOT NULL,
  power_saving_below INTEGER NOT NULL,
  low_power_below INTEGER NOT NULL,
  critical_below INTEGER NOT NULL
);

CREATE TABLE power_consumers (
  consumer_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  service_id TEXT NOT NULL,
  priority TEXT NOT NULL
);

CREATE TABLE charging_sessions (
  session_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  started_at TEXT NOT NULL,
  source TEXT
);
