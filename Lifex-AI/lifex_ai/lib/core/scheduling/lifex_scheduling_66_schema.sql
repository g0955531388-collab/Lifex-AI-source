-- Platform 66 catalog. Not clinical encounters.

CREATE TABLE scheduling_slots (
  slot_id TEXT PRIMARY KEY,
  resource_ref TEXT NOT NULL,
  status TEXT NOT NULL
);
