import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const accountSecurity = fs.readFileSync(new URL("../src/client-account-security.ts", import.meta.url), "utf8");
const walletPass = fs.readFileSync(new URL("../src/wallet-pass.ts", import.meta.url), "utf8");
const accountView = fs.readFileSync(new URL("../../../Sources/AppShell/IumrahAccountView.swift", import.meta.url), "utf8");

test("Wallet pass route requires the canonical authenticated iumrah account", () => {
  assert.match(accountSecurity, /\/api\/package\/client\/account\/wallet-pass/);
  assert.match(accountSecurity, /const auth = await requireAccount\(request, db\)/);
  assert.match(accountSecurity, /accountProfile\(auth\.pilgrim\)/);
});

test("Wallet pass is signed and carries the permanent iumrah ID as a QR pass", () => {
  assert.match(walletPass, /PKBarcodeFormatQR/);
  assert.match(walletPass, /crypto\.subtle\.sign\("RSASSA-PKCS1-v1_5"/);
  assert.match(walletPass, /function zipStore/);
  assert.match(walletPass, /WALLET_PASS_TYPE_ID/);
  assert.match(walletPass, /const verificationURL = "https:\/\/iumrah\.app"/);
  assert.match(walletPass, /application\/vnd\.apple\.pkpass/);
});

test("Account ID card uses the current iumrah.app domain and native Apple Wallet UI", () => {
  assert.match(accountView, /Text\("iumrah\.app"\)/);
  assert.match(accountView, /makeQRCode\("https:\/\/iumrah\.app"\)/);
  assert.doesNotMatch(accountView, /aiumra\.app/);
  assert.match(accountView, /IumrahAddToWalletButton/);
});
