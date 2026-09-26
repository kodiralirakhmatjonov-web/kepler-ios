CREATE TABLE IF NOT EXISTS iumrah_client_phone_challenges (
  id TEXT PRIMARY KEY,
  purpose TEXT NOT NULL,
  pilgrim_id INTEGER,
  phone_normalized TEXT NOT NULL,
  phone_display TEXT NOT NULL,
  code_salt TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  code_iterations INTEGER NOT NULL DEFAULT 100000,
  attempts INTEGER NOT NULL DEFAULT 0,
  max_attempts INTEGER NOT NULL DEFAULT 5,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  consumed_at TEXT,
  request_ip_hash TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_iumrah_client_phone_challenges_purpose_phone
  ON iumrah_client_phone_challenges (purpose, phone_normalized, created_at);

CREATE INDEX IF NOT EXISTS idx_iumrah_client_phone_challenges_purpose_pilgrim
  ON iumrah_client_phone_challenges (purpose, pilgrim_id, created_at);
