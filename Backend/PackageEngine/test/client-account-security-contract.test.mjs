import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const source = fs.readFileSync(new URL("../src/client-account-security.ts", import.meta.url), "utf8");
const migration = fs.readFileSync(new URL("../migrations/0006_package_primary_hotels.sql", import.meta.url), "utf8");

test("Apple is a unique external key for the canonical pilgrim id", () => {
  assert.match(migration, /apple_subject TEXT PRIMARY KEY/);
  assert.match(migration, /pilgrim_id INTEGER NOT NULL UNIQUE/);
  assert.match(source, /iumrahID: formatIumrahID\(pilgrim\.id\)/);
  assert.doesNotMatch(migration, /CREATE TABLE[^;]*apple[^;]*password/si);
});

test("Apple identity tokens are verified server-side and cannot be replayed", () => {
  assert.match(source, /RSASSA-PKCS1-v1_5/);
  assert.match(source, /claims\.iss !== "https:\/\/appleid\.apple\.com"/);
  assert.match(source, /configuredAudiences\.some\(\(audience\) => audiences\.includes\(audience\)\)/);
  assert.match(source, /claims\.nonce !== nonce && claims\.nonce !== nonceDigest/);
  assert.match(source, /APPLE_TOKEN_REPLAYED/);
});


test("re-authentication on the same installation rotates the token instead of duplicating the device session", () => {
  assert.match(source, /A security session represents one physical app installation, not one login/);
  assert.match(source, /WHERE pilgrim_id=\?1 AND device_id=\?2/);
  assert.match(source, /SET token_hash=\?1,last_seen_at=\?2/);
  assert.match(source, /b\.device_id=\?2 AND b\.token_hash<>\?3/);
  assert.match(source, /UPDATE iumrah_account_sessions SET revoked_at=\?1 WHERE token_hash=\?2 AND revoked_at IS NULL/);
  assert.match(source, /collapseDuplicateDeviceSessions/);
  assert.match(source, /const keptDevices = new Set<string>\(\)/);
});

test("secondary sessions can terminate only themselves", () => {
  assert.match(source, /if \(!self && !auth\.isPrimary\) throw new RouteError\("PRIMARY_DEVICE_REQUIRED", 403\)/);
  assert.match(source, /canTerminate: isCurrent \|\| auth\.isPrimary/);
  assert.match(source, /if \(!auth\.isPrimary\) throw new RouteError\("PRIMARY_DEVICE_REQUIRED", 403\)/);
});

test("verified email is a unique alternate key to the canonical pilgrim", () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS iumrah_client_account_emails/);
  assert.match(migration, /pilgrim_id INTEGER PRIMARY KEY/);
  assert.match(migration, /email_normalized TEXT NOT NULL UNIQUE/);
  assert.match(source, /SELECT pilgrim_id FROM iumrah_client_account_emails WHERE email_normalized=\?1/);
  assert.match(source, /UPDATE pilgrims SET email=\?1,updated_at=\?2 WHERE id=\?3/);
});

test("email verification and recovery are bounded and do not store raw codes", () => {
  assert.match(source, /randomVerificationCode/);
  assert.match(source, /codeHash = await passwordDigest\(code, salt, CODE_ITERATIONS\)/);
  assert.match(source, /CODE_TTL_MINUTES = 10/);
  assert.match(source, /MAX_CODE_ATTEMPTS = 5/);
  assert.match(source, /https:\/\/api\.resend\.com\/emails/);
  assert.match(source, /SET revoked_at=\?1 WHERE pilgrim_id=\?2 AND revoked_at IS NULL/);
  assert.match(source, /UPDATE iumrah_client_devices SET is_primary=0 WHERE pilgrim_id=\?1/);
  assert.doesNotMatch(migration, /code TEXT NOT NULL/);
  assert.doesNotMatch(
    source,
    /PASSWORD_RECOVERY_DELIVERY_FAILED[\s\S]{0,300}challengeID:\s*publicChallengeID/,
    "A Resend failure for a verified account must not be returned as a fake success",
  );
});

test("Apple can resolve or create one canonical account without duplicating identity", () => {
  assert.match(source, /APPLE_ACCOUNT_EMAIL_REQUIRED/);
  assert.match(source, /FROM iumrah_client_account_emails e/);
  assert.match(source, /INSERT INTO pilgrims\(email,created_at,updated_at\)/);
  assert.match(source, /INSERT INTO iumrah_client_apple_links\(apple_subject,pilgrim_id,linked_at,last_used_at\)/);
  assert.match(source, /UPDATE iumrah_client_devices SET is_primary=1/);
});

test("Google is a unique external key for the same canonical pilgrim id", () => {
  assert.match(migration, /google_subject TEXT PRIMARY KEY/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS iumrah_client_google_links/);
  assert.match(source, /iumrah_client_google_links/);
  assert.doesNotMatch(migration, /CREATE TABLE[^;]*google[^;]*password/si);
});

test("Google identity tokens are verified server-side, nonce-bound and cannot be replayed", () => {
  assert.match(source, /https:\/\/www\.googleapis\.com\/oauth2\/v3\/certs/);
  assert.match(source, /claims\.iss !== "https:\/\/accounts\.google\.com"/);
  assert.match(source, /claims\.iss !== "accounts\.google\.com"/);
  assert.match(source, /!audiences\.includes\(configuredAudience\)/);
  assert.match(source, /claims\.nonce !== nonce/);
  assert.match(source, /GOOGLE_TOKEN_REPLAYED/);
});

test("Google sign-in resolves verified email to one canonical account and returns the normal session", () => {
  assert.match(source, /GOOGLE_ACCOUNT_EMAIL_REQUIRED/);
  assert.match(source, /FROM iumrah_client_account_emails e/);
  assert.match(source, /INSERT INTO iumrah_client_google_links\(google_subject,pilgrim_id,linked_at,last_used_at\)/);
  assert.match(source, /google_account_created/);
  assert.match(source, /google_sign_in/);
});

test("security overview reports Google and Apple as independent keys to the same account", () => {
  assert.match(source, /google: \{ linked: Boolean\(google\), linkedAt: google\?\.linked_at \?\? null \}/);
  assert.match(source, /apple: \{ linked: Boolean\(apple\), linkedAt: apple\?\.linked_at \?\? null \}/);
});



test("booking activation proves possession, repairs provisional accounts and supports verified email activation", () => {
  assert.match(source, /\/api\/package\/client\/account\/activate/);
  assert.match(source, /SELECT id FROM bookings WHERE id=\?1 AND access_token_hash=\?2 LIMIT 1/);
  assert.match(source, /SELECT pilgrim_id FROM pilgrim_trips WHERE booking_id=\?1 LIMIT 1/);
  assert.match(source, /ACCOUNT_ALREADY_ACTIVE/);
  assert.match(source, /ON CONFLICT\(pilgrim_id\) DO UPDATE SET/);
  assert.match(source, /\/api\/package\/client\/account\/activate\/email\/start/);
  assert.match(source, /\/api\/package\/client\/account\/activate\/email\/confirm/);
  assert.match(source, /createEmailChallenge\([\s\S]*"verify_email"/);
  assert.match(source, /verifyEmailChallenge\([\s\S]*"verify_email"/);
  assert.match(source, /linkVerifiedEmail\(db, context\.pilgrimID/);
});

test("standalone email registration joins the canonical pilgrim model instead of creating a web-only user", () => {
  assert.match(source, /\/api\/package\/client\/account\/register\/email\/start/);
  assert.match(source, /\/api\/package\/client\/account\/register\/email\/confirm/);
  assert.match(source, /reusableProvisionalPilgrim/);
  assert.match(source, /LOWER\(TRIM\(COALESCE\(p\.email,''\)\)\)=\?1/);
  assert.match(source, /email_account_created/);
  assert.match(source, /linkVerifiedEmail\(db, pilgrimID/);
  assert.match(source, /establishPasswordCredentials/);
});

test("social sign-in reuses one unclaimed provisional pilgrim when verified email proves ownership", () => {
  const matches = source.match(/reusableProvisionalPilgrim\(db, (?:apple|google)\.email\)/g) ?? [];
  assert.equal(matches.length, 2);
});
