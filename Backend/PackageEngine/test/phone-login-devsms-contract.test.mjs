import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const source = fs.readFileSync(new URL("../src/client-account-security.ts", import.meta.url), "utf8");
const models = fs.readFileSync(new URL("../../../Sources/Models/IumrahAccountModels.swift", import.meta.url), "utf8");
const service = fs.readFileSync(new URL("../../../Sources/Services/IumrahAccountService.swift", import.meta.url), "utf8");
const store = fs.readFileSync(new URL("../../../Sources/State/IumrahAccountStore.swift", import.meta.url), "utf8");

 test("phone sign-in reuses live DevSMS OTP and never exposes a debug code", () => {
  assert.match(source, /type SMSChallengePurpose = "verify_phone" \| "activate_account" \| "login_phone"/);
  assert.match(source, /startPhoneLogin\(request: Request, env: Env, db: D1Like\)/);
  assert.match(source, /createSMSChallenge\([\s\S]*?"login_phone"/);
  assert.match(source, /https:\/\/devsms\.uz\/api\/send_sms\.php/);
  assert.match(source, /\/api\/package\/client\/account\/login\/sms\/start/);
  assert.match(source, /\/api\/package\/client\/account\/login\/sms\/confirm/);
  assert.doesNotMatch(source, /debugCode/);
});

test("iOS phone sign-in models and service match the live backend contract", () => {
  assert.match(models, /struct IumrahPhoneLoginStartResponse: Decodable[\s\S]*?let phone: String/);
  assert.doesNotMatch(models, /IumrahPhoneLoginStartResponse[\s\S]{0,250}debugCode/);
  assert.match(service, /func startPhoneLogin\(phone: String, locale: String\) async throws -> IumrahPhoneLoginStartResponse/);
  assert.match(service, /func confirmPhoneLogin\(challengeID: String, code: String, locale: String\) async throws -> IumrahAccountAuthResponse/);
  assert.match(store, /func startPhoneLogin\(phone: String, locale: String = Locale\.current\.identifier\)/);
  assert.match(store, /func confirmPhoneLogin\(challengeID: String, code: String, locale: String = Locale\.current\.identifier\)/);
});
