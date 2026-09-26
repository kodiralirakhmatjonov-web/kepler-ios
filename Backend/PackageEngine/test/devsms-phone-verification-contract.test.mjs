import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const source = fs.readFileSync(new URL("../src/client-account-security.ts", import.meta.url), "utf8");
const migration = fs.readFileSync(new URL("../migrations/0008_devsms_phone_verification.sql", import.meta.url), "utf8");
const workflow = fs.readFileSync(new URL("../../../.github/workflows/deploy-package-engine.yml", import.meta.url), "utf8");

test("DevSMS OTP stays server-side and only Uzbekistan +998 numbers are accepted", () => {
  assert.match(source, /https:\/\/devsms\.uz\/api\/send_sms\.php/);
  assert.match(source, /authorization: `Bearer \$\{token\}`/);
  assert.match(source, /type: "universal_otp"/);
  assert.match(source, /template_type: purpose === "activate_account" \? 3 : 1/);
  assert.match(source, /service_name: "iumrah"/);
  assert.match(source, /otp_code: otpCode/);
  assert.match(source, /\^\\\+998\\d\{9\}\$/);
  assert.match(source, /SMS_COUNTRY_UNSUPPORTED/);
  assert.match(source, /SMS_RATE_LIMITED/);
  assert.doesNotMatch(source, /return json\([^)]*otpCode/s);
});

test("SMS verification stores only a salted OTP hash and verified phone linkage", () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS iumrah_client_sms_challenges/);
  assert.match(migration, /code_salt TEXT NOT NULL/);
  assert.match(migration, /code_hash TEXT NOT NULL/);
  assert.doesNotMatch(migration, /otp_code TEXT|code TEXT NOT NULL/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS iumrah_client_account_phones/);
  assert.match(migration, /phone_normalized TEXT NOT NULL UNIQUE/);
  assert.match(source, /codeHash = await passwordDigest\(code, salt, CODE_ITERATIONS\)/);
  assert.match(source, /MAX_CODE_ATTEMPTS = 5/);
  assert.match(source, /CODE_TTL_MINUTES = 10/);
});

test("booking phone and SMS activation routes share booking proof and persist verification", () => {
  assert.match(source, /\/api\/package\/client\/account\/activate\/sms\/start/);
  assert.match(source, /\/api\/package\/client\/account\/activate\/sms\/confirm/);
  assert.match(source, /\/api\/package\/client\/account\/phone\/status/);
  assert.match(source, /\/api\/package\/client\/account\/phone\/start/);
  assert.match(source, /\/api\/package\/client\/account\/phone\/confirm/);
  assert.match(source, /bookingActivationContext\(request, env, db/);
  assert.match(source, /linkVerifiedPhone\(db, context\.pilgrimID/);
});

test("deployment requires and installs the DevSMS secret before health passes", () => {
  assert.match(workflow, /DEVSMS_API_TOKEN: \$\{\{ secrets\.DEVSMS_API_TOKEN \}\}/);
  assert.match(workflow, /https:\/\/devsms\.uz\/api\/get_balance\.php/);
  assert.match(workflow, /wrangler secret put DEVSMS_API_TOKEN/);
  assert.match(workflow, /migrations\/0008_devsms_phone_verification\.sql/);
  assert.match(workflow, /\.smsProviderConfigured == true/);
});
