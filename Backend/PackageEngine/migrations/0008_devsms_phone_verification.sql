-- DevSMS-backed phone verification for booking holders and SMS account activation.
-- Only verified phones are linked to an iumrah account identity.
CREATE TABLE IF NOT EXISTS iumrah_client_account_phones (
  pilgrim_id INTEGER PRIMARY KEY,
  phone_normalized TEXT NOT NULL UNIQUE,
  phone_display TEXT NOT NULL,
  verified_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_account_phone_lookup
ON iumrah_client_account_phones(phone_normalized);

CREATE TABLE IF NOT EXISTS iumrah_client_sms_challenges (
  id TEXT PRIMARY KEY,
  purpose TEXT NOT NULL CHECK (purpose IN ('verify_phone','activate_account')),
  pilgrim_id INTEGER NOT NULL,
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
  provider_sms_id TEXT,
  provider_request_id TEXT,
  provider_status TEXT,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_sms_challenge_lookup
ON iumrah_client_sms_challenges(purpose, phone_normalized, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_sms_challenge_account
ON iumrah_client_sms_challenges(pilgrim_id, created_at DESC);
