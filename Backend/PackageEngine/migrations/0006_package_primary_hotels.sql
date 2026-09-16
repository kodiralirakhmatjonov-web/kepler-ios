PRAGMA foreign_keys = ON;

-- Cleanup compatibility migration.
-- The protected GitHub deploy workflow still runs this historical filename and
-- performs COUNT(*) against package_primary_hotels. Keep an EMPTY compatibility
-- shell until that protected workflow is changed manually; no runtime code reads it.
CREATE TABLE IF NOT EXISTS package_primary_hotels (
  id TEXT PRIMARY KEY,
  package_tier TEXT NOT NULL,
  stars INTEGER NOT NULL,
  city TEXT NOT NULL,
  hotel_id TEXT NOT NULL,
  room_id TEXT,
  base_price_usd REAL NOT NULL DEFAULT 0,
  price_unit TEXT NOT NULL DEFAULT 'perRoomNight',
  active INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
DELETE FROM package_primary_hotels;

-- Purge tables created only for the retired server flight/search/quote experiment.
DROP TABLE IF EXISTS package_flight_cache_v1;
DROP TABLE IF EXISTS package_quote_audits_v2;

-- `primary_hotels` is the real recommendation layer used by the generator.
CREATE TABLE IF NOT EXISTS primary_hotels (
  city TEXT NOT NULL,
  star_category INTEGER NOT NULL CHECK (star_category BETWEEN 1 AND 5),
  position INTEGER NOT NULL CHECK (position BETWEEN 1 AND 3),
  hotel_id TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (city, star_category, position),
  UNIQUE (city, star_category, hotel_id),
  FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_primary_hotels_lookup ON primary_hotels(city, star_category, position);

-- Every login method resolves to the canonical integer pilgrims.id. The public
-- eight-digit iumrah ID is only its zero-padded presentation (for example 16 -> 00000016).
CREATE TABLE IF NOT EXISTS iumrah_client_devices (
  id TEXT PRIMARY KEY,
  pilgrim_id INTEGER NOT NULL,
  installation_id TEXT NOT NULL,
  secret_hash TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT 'iPhone',
  model TEXT NOT NULL DEFAULT 'iPhone',
  platform TEXT NOT NULL DEFAULT 'iOS',
  os_version TEXT NOT NULL DEFAULT '',
  app_version TEXT NOT NULL DEFAULT '',
  locale TEXT NOT NULL DEFAULT '',
  is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0,1)),
  created_at TEXT NOT NULL,
  first_seen_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  last_city TEXT NOT NULL DEFAULT '',
  last_region TEXT NOT NULL DEFAULT '',
  last_country TEXT NOT NULL DEFAULT '',
  revoked_at TEXT,
  UNIQUE (pilgrim_id, installation_id),
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_devices_account
ON iumrah_client_devices(pilgrim_id, last_seen_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_iumrah_client_devices_primary
ON iumrah_client_devices(pilgrim_id)
WHERE is_primary=1 AND revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS iumrah_client_session_bindings (
  session_id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL UNIQUE,
  pilgrim_id INTEGER NOT NULL,
  device_id TEXT,
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  last_city TEXT NOT NULL DEFAULT '',
  last_region TEXT NOT NULL DEFAULT '',
  last_country TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (token_hash) REFERENCES iumrah_account_sessions(token_hash) ON DELETE CASCADE,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES iumrah_client_devices(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_sessions_account
ON iumrah_client_session_bindings(pilgrim_id, last_seen_at DESC);

-- Apple `sub` is a unique external credential. It never replaces or duplicates
-- pilgrims.id; it only points to the same canonical iumrah account.
CREATE TABLE IF NOT EXISTS iumrah_client_apple_links (
  apple_subject TEXT PRIMARY KEY,
  pilgrim_id INTEGER NOT NULL UNIQUE,
  linked_at TEXT NOT NULL,
  last_used_at TEXT NOT NULL,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS iumrah_client_apple_assertions (
  token_hash TEXT PRIMARY KEY,
  used_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_apple_assertions_used
ON iumrah_client_apple_assertions(used_at);

-- Google `sub` follows the exact same canonical-account invariant as Apple:
-- one verified external subject can point to one pilgrim, and one pilgrim can
-- have at most one Google subject linked.
CREATE TABLE IF NOT EXISTS iumrah_client_google_links (
  google_subject TEXT PRIMARY KEY,
  pilgrim_id INTEGER NOT NULL UNIQUE,
  linked_at TEXT NOT NULL,
  last_used_at TEXT NOT NULL,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS iumrah_client_google_assertions (
  token_hash TEXT PRIMARY KEY,
  used_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_google_assertions_used
ON iumrah_client_google_assertions(used_at);

-- A verified email is an alternate credential for the same canonical pilgrim.
-- Profile email text is not trusted for login until this table contains the
-- verified, normalized address. One address and one pilgrim can each appear once.
CREATE TABLE IF NOT EXISTS iumrah_client_account_emails (
  pilgrim_id INTEGER PRIMARY KEY,
  email_normalized TEXT NOT NULL UNIQUE,
  email_display TEXT NOT NULL,
  verified_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_account_email_lookup
ON iumrah_client_account_emails(email_normalized);

CREATE TABLE IF NOT EXISTS iumrah_client_email_challenges (
  id TEXT PRIMARY KEY,
  purpose TEXT NOT NULL CHECK (purpose IN ('verify_email','reset_password')),
  pilgrim_id INTEGER,
  email_normalized TEXT NOT NULL,
  email_display TEXT NOT NULL,
  code_salt TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  code_iterations INTEGER NOT NULL DEFAULT 100000,
  attempts INTEGER NOT NULL DEFAULT 0,
  max_attempts INTEGER NOT NULL DEFAULT 5,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  consumed_at TEXT,
  request_ip_hash TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_email_challenge_lookup
ON iumrah_client_email_challenges(purpose,email_normalized,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_email_challenge_account
ON iumrah_client_email_challenges(pilgrim_id,created_at DESC);

CREATE TABLE IF NOT EXISTS iumrah_client_security_audit (
  id TEXT PRIMARY KEY,
  pilgrim_id INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  actor_session_id TEXT,
  target_session_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_client_security_audit_account
ON iumrah_client_security_audit(pilgrim_id, created_at DESC);

-- iumrah Security final identity registry. PackageEngine never accepts KYC
-- self-confirmation: only iumrah Business manual approval writes a confirmed row.
-- Only masked passport metadata and the deterministic anti-fraud fingerprint live here.
CREATE TABLE IF NOT EXISTS iumrah_identity_confirmations (
  id TEXT PRIMARY KEY,
  booking_id TEXT NOT NULL UNIQUE,
  identity_fingerprint TEXT NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  passport_last4 TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted','manual_review','confirmed','rejected')),
  verification_method TEXT NOT NULL DEFAULT 'business_manual_passport_review',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_iumrah_identity_fingerprint
ON iumrah_identity_confirmations(identity_fingerprint, updated_at DESC);

-- iumrah Friends: every canonical iumrah account receives three $100 gifts.
-- Gift redemptions are bound to the booking holder's Security Confirmation
-- fingerprint so one identity cannot repeatedly claim first-booking benefits.
CREATE TABLE IF NOT EXISTS iumrah_friends_gifts (
  id TEXT PRIMARY KEY,
  gift_token TEXT NOT NULL UNIQUE,
  referrer_pilgrim_id INTEGER NOT NULL,
  position INTEGER NOT NULL CHECK (position BETWEEN 1 AND 3),
  status TEXT NOT NULL DEFAULT 'available'
    CHECK (status IN ('available','redeemed')),
  redeemed_booking_id TEXT,
  created_at TEXT NOT NULL,
  redeemed_at TEXT,
  UNIQUE (referrer_pilgrim_id, position),
  FOREIGN KEY (referrer_pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_friends_gifts_owner
ON iumrah_friends_gifts(referrer_pilgrim_id, position);

CREATE TABLE IF NOT EXISTS iumrah_friends_redemptions (
  id TEXT PRIMARY KEY,
  gift_id TEXT NOT NULL UNIQUE,
  gift_token TEXT NOT NULL,
  referrer_pilgrim_id INTEGER NOT NULL,
  redeemer_pilgrim_id INTEGER NOT NULL,
  booking_id TEXT NOT NULL,
  identity_fingerprint TEXT NOT NULL,
  discount_usd REAL NOT NULL DEFAULT 100,
  reward_usd REAL NOT NULL DEFAULT 100,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','earned','cancelled')),
  reward_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (reward_status IN ('pending','earned','cancelled')),
  created_at TEXT NOT NULL,
  settled_at TEXT,
  FOREIGN KEY (gift_id) REFERENCES iumrah_friends_gifts(id) ON DELETE CASCADE,
  FOREIGN KEY (referrer_pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE,
  FOREIGN KEY (redeemer_pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_friends_redemption_referrer
ON iumrah_friends_redemptions(referrer_pilgrim_id, reward_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_iumrah_friends_redemption_booking
ON iumrah_friends_redemptions(booking_id, status);
CREATE INDEX IF NOT EXISTS idx_iumrah_friends_redemption_identity
ON iumrah_friends_redemptions(identity_fingerprint, status);

-- Positive rows are earned iumrah Credit; negative rows are credit used on a
-- future booking. The ledger is append-only so referral value remains auditable.
CREATE TABLE IF NOT EXISTS iumrah_friends_credit_ledger (
  id TEXT PRIMARY KEY,
  pilgrim_id INTEGER NOT NULL,
  amount_usd REAL NOT NULL,
  source_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  booking_id TEXT,
  created_at TEXT NOT NULL,
  UNIQUE (source_type, source_id),
  FOREIGN KEY (pilgrim_id) REFERENCES pilgrims(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_iumrah_friends_credit_owner
ON iumrah_friends_credit_ledger(pilgrim_id, created_at DESC);
