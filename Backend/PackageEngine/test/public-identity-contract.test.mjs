import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const identity = fs.readFileSync(new URL("../src/public-identity.ts", import.meta.url), "utf8");
const security = fs.readFileSync(new URL("../src/client-account-security.ts", import.meta.url), "utf8");

test("Iumrah ID presentation is eight digits without changing the canonical pilgrim primary key", () => {
  assert.match(identity, /padStart\(8, "0"\)/);
  assert.match(security, /\^\\d\{6,8\}\$/);
  assert.doesNotMatch(identity, /UPDATE pilgrims SET id/);
});

test("public identity links are signed and cannot be enumerated by numeric id alone", () => {
  assert.match(identity, /HMAC/);
  assert.match(identity, /iumrah-id:v1:/);
  assert.match(identity, /IDENTITY_LINK_INVALID/);
  assert.match(identity, /constantTimeEqual/);
  assert.match(identity, /IUMRAH_PUBLIC_ID_ORIGIN/);
  assert.match(identity, /\$\{origin\}\/id\/\$\{id\}/);
});

test("public identity response excludes sensitive pilgrim fields", () => {
  assert.match(identity, /first_name,last_name,display_name/);
  assert.doesNotMatch(identity, /passport/);
  assert.doesNotMatch(identity, /phone/);
  assert.doesNotMatch(identity, /whatsapp/);
  assert.doesNotMatch(identity, /telegram/);
});
