# iumrah — Global Turkish localization patch v2 (9 October 2026)

**Standalone cumulative patch**, built against `kepler-ios-main 4.zip`. The earlier Turkish v1 patch does **not** need to be installed. The archive uses repository-root paths and can be applied with the existing `.github/workflows/apply-beta-update.yml` workflow.

## What changed

- Added Turkish (`tr`) to `AppSettingsStore.Language` as the fifth selectable language, with a `tr_TR` Foundation and SwiftUI locale; preserved Russian, English, Uzbek (Latin) and Uzbek (Cyrillic).
- Turkish is available immediately in the native language selection interface and is retained via the existing `iumrah.language` preference.
- `L10n` contains Turkish output for all 552 original English keys plus the new language label (553 keys in total).
- Shared translation catalogue has 2,546 English-to-Turkish phrases. It covers 838 formerly missing literal four-language `tr(...)` strings, 257 additional untranslated strings from `localized(...)`, `localizedFinal(...)` and Ziyarat screen helpers, 36 untranslated indirect `FlowCopy.en(...)` entries, and 121 standalone language-switch phrases, alongside v1 translations.
- Extended Turkish translations through authentication, booking, flights, airport maps, hotels and package configurator, invoice/receipts, Turkish eVisa explanations, care/help, transfer, Umrah Flow, social/Gift Cards, Telegram, trip wallet and Ziyarat.
- Localized all 37 eSIM UI copy keys. Corrected hard-coded Account tab/header, some checkout/flight footer labels, accessiblity text, and Mac/iPad navigation command titles for Turkish.
- Localized `tr.lproj/InfoPlist.strings` for the location-usage permission. Existing resources, price logic, networking, UI layout, and existing four-language localization data are otherwise retained.

## Two independent static QA passes

**Pass 1 — string call-site coverage:** independently visited each recognized four-language inline helper call; verified all 1,775 literal call sites (`tr`, `localized`, `localizedFinal`, `localizedDetail`, `copy.text` and `text`) match a Turkish phrase; separately checked all 431 literal `TurkishLocalization.phrase(...)` references (one is intentionally empty), all 57 indirect English `FlowCopy` keys, the 37 eSIM dictionary entries, and all 553 central keys. No uncovered call-site text in these recognized patterns.

**Pass 2 — structure, placeholders and compiler:** verified the interpolated Swift placeholders in all 2,546 translations are preserved (zero mismatches); checked all central printf format placeholders (zero mismatches), 414 language-switch candidates all support `.turkish`; parsed all 253 Swift files with Swift 6.2 `swiftc -frontend -parse` (success). Compiled and executed the standalone Turkish translation runtime QA program on Linux (success).

## Verification boundaries

This is a comprehensive **static source-level localization patch** rather than a tested iOS release. It has **not** been compiled and linked in Xcode (Xcode is unavailable on Linux), run on an iPhone, proofread by a native Turkish editor, or checked for truncation in every device size. Third-party/backend-provided messages, airline/airport/hotel names and content delivered from the server can remain in their original language. Accordingly, these static passes cannot support an absolute 100%-error-free production guarantee.

For a brand-safe launch, apply this cumulative ZIP in the repository root, run your existing GitHub Actions iOS build, and inspect a TestFlight build using Türkçe on iPhone 11 and iPhone 13 mini with the critical flows: select language, onboarding, flight search and filters, hotel selection, package checkout, Security Confirmation, eSIM, wallet, Care and booking status. Verify other four languages still work before publishing.
