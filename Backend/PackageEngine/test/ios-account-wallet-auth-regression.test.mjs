import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const accountView = fs.readFileSync(new URL("../../../Sources/AppShell/IumrahAccountView.swift", import.meta.url), "utf8");
const walletView = fs.readFileSync(new URL("../../../Sources/Views/Wallet/IumrahTripWalletView.swift", import.meta.url), "utf8");
const appleButton = fs.readFileSync(new URL("../../../Sources/Views/Components/IumrahLocalizedAppleAuthButton.swift", import.meta.url), "utf8");
const service = fs.readFileSync(new URL("../../../Sources/Services/IumrahAccountService.swift", import.meta.url), "utf8");

 test("KYC DevSMS service methods required by Security Confirmation remain available", () => {
  assert.match(service, /func bookingPhoneVerificationStatus\(/);
  assert.match(service, /func startBookingPhoneVerification\(/);
  assert.match(service, /func confirmBookingPhoneVerification\(/);
});

test("Account and wallet do not call fileprivate nilIfBlank helpers", () => {
  assert.doesNotMatch(accountView, /\.nilIfBlank/);
  assert.doesNotMatch(walletView, /\.nilIfBlank/);
});

test("localized Apple sign-in keeps the native authorization control tappable", () => {
  assert.match(appleButton, /SignInWithAppleButton\(/);
  assert.match(appleButton, /\.allowsHitTesting\(false\)/);
  assert.match(accountView, /onRequest: prepareAppleSignIn/);
  assert.match(accountView, /onCompletion: completeAppleSignIn/);
});

test("wallet preview keeps its nonBlank helper in IumrahTripWalletEntry scope", () => {
  const entrySource = walletView.split("private struct IumrahTripWalletScreen", 1)[0];
  assert.match(entrySource, /private func nonBlank\(_ value: String\?\) -> String\?/);
  assert.match(entrySource, /title: nonBlank\(profile\?\.displayName\) \?\? nonBlank\(session\.travelerName\)/);
});
