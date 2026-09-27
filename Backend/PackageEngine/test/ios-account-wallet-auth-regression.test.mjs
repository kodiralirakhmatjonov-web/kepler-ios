import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const accountView = fs.readFileSync(new URL("../../../Sources/AppShell/IumrahAccountView.swift", import.meta.url), "utf8");
const walletView = fs.readFileSync(new URL("../../../Sources/Views/Wallet/IumrahTripWalletView.swift", import.meta.url), "utf8");
const appleButton = fs.readFileSync(new URL("../../../Sources/Views/Components/IumrahLocalizedAppleAuthButton.swift", import.meta.url), "utf8");
const service = fs.readFileSync(new URL("../../../Sources/Services/IumrahAccountService.swift", import.meta.url), "utf8");
const backend = fs.readFileSync(new URL("../src/client-account-security.ts", import.meta.url), "utf8");
const smsMigration = fs.readFileSync(new URL("../migrations/0008_devsms_phone_verification.sql", import.meta.url), "utf8");

const emotionalView = fs.readFileSync(new URL("../../../Sources/Views/Home/HomeEmotionalJourneyView.swift", import.meta.url), "utf8");
const carouselView = fs.readFileSync(new URL("../../../Sources/Views/Home/HomeVideoCarousel.swift", import.meta.url), "utf8");
const walletAsset = fs.readFileSync(new URL("../../../Resources/Assets.xcassets/IumrahLeatherWallet.imageset/IumrahLeatherWallet.png", import.meta.url));

test("KYC DevSMS service methods required by Security Confirmation remain available", () => {
  assert.match(service, /func bookingPhoneVerificationStatus\(/);
  assert.match(service, /func startBookingPhoneVerification\(/);
  assert.match(service, /func confirmBookingPhoneVerification\(/);
});

test("Account and wallet do not call fileprivate nilIfBlank helpers", () => {
  assert.doesNotMatch(accountView, /\.nilIfBlank/);
  assert.doesNotMatch(walletView, /\.nilIfBlank/);
});

test("localized Apple sign-in keeps native authorization tappable and matches Google geometry", () => {
  assert.match(appleButton, /SignInWithAppleButton\(/);
  assert.match(appleButton, /frame\(maxWidth: \.infinity\)/);
  assert.match(appleButton, /IumrahDesign\.controlHeight/);
  assert.match(appleButton, /IumrahDesign\.compactRadius/);
  assert.match(appleButton, /\.allowsHitTesting\(false\)/);
  assert.match(accountView, /onRequest: prepareAppleSignIn/);
  assert.match(accountView, /onCompletion: completeAppleSignIn/);
});

test("wallet preview uses the transparent wallet asset directly with no inner white image surface", () => {
  const entrySource = walletView.split("private enum IumrahWalletPage", 1)[0];
  assert.match(entrySource, /Image\("IumrahLeatherWallet"\)/);
  assert.match(entrySource, /\.scaleEffect\(1\.12\)/);
  assert.doesNotMatch(entrySource, /walletPreview/);
  assert.doesNotMatch(entrySource, /compactPass/);
});

test("wallet uses card proportions, boarding-pass presentation and removes status-only booking card", () => {
  assert.match(walletView, /let height = width \/ 1\.586/);
  assert.match(walletView, /boardingPassSurface/);
  assert.match(walletView, /perforation/);
  assert.match(walletView, /hotelCardSurface/);
  assert.doesNotMatch(walletView, /private var bookingCard/);
});

test("phone is a first-class sign-in and registration method", () => {
  assert.match(accountView, /startGuestSMSRegistration\(\)/);
  assert.match(accountView, /confirmGuestSMSRegistration\(\)/);
  assert.match(service, /func startPhoneRegistration\(/);
  assert.match(service, /func confirmPhoneRegistration\(/);
  assert.match(backend, /\/api\/package\/client\/account\/register\/sms\/start/);
  assert.match(backend, /\/api\/package\/client\/account\/register\/sms\/confirm/);
  assert.match(backend, /PHONE_ACCOUNT_NOT_FOUND/);
  assert.match(backend, /Legacy accounts can already have the phone/);
  assert.match(smsMigration, /login_phone/);
  assert.match(smsMigration, /register_phone/);
  assert.match(smsMigration, /iumrah_client_sms_challenges_v2/);
});


test("wallet artwork remains a real transparent PNG", () => {
  assert.equal(walletAsset.subarray(1, 4).toString("ascii"), "PNG");
  const pngColorType = walletAsset[25];
  assert.ok(pngColorType === 4 || pngColorType === 6, `expected PNG alpha channel, color type=${pngColorType}`);
});

test("promo video close and mute controls use native Liquid Glass controls above non-interactive video content", () => {
  assert.match(emotionalView, /IumrahGlassIconButton\(/);
  assert.match(emotionalView, /systemName: "xmark"/);
  assert.match(emotionalView, /speaker\.slash\.fill/);
  assert.match(emotionalView, /\.allowsHitTesting\(false\)/);
  assert.match(carouselView, /IumrahGlassIconButton\(/);
});
