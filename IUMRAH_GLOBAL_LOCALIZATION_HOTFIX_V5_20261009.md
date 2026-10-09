# iumrah Global Localization Quality Hotfix v5

This ZIP is incremental: apply **after** the previously uploaded Turkish + Indonesian v4.

- Widget strings and dates follow the selected in-app language `tr`, `id` or any of the four existing locales; optional `languageCode` in shared snapshot maintains decoding compatibility with earlier widgets.
- Four Russian hard-coded booking labels use central `booking_number_short` localization.
- Package Engine itineraries emit localized event titles for Turkish and Indonesian, including regional locale variants.
- Transactional security emails (verification, password recovery) use six languages.
- Hotel deep-link fallback page shows Turkish/Indonesian messaging when browser locale matches.
- Ziyarats preserves remote `tr` / `id` translations; 11 offline place names and blurbs have explicit TR/ID copy.
- Targeted VoiceOver translations: connectivity, globe, onboarding audio, video stories and transfer search.
- One stale Ziyarats contract test updated to match the current deliberately opt-in map implementation. Ziyarats source UI has not been changed.
- New regression tests verify six-locale contracts and runtime server itinerary text.

Important: The server changes need a separate **Deploy iumrah Package Engine** workflow_dispatch after the ZIP is applied. The ZIP extraction workflow only commits files; it does not publish the Cloudflare worker. Do not rerun deployment if secrets / existing production prerequisites are not configured.

Checks: Swift frontend parsing and TypeScript `tsc --noEmit`, backend contract tests and locale-specific tests. Xcode compile, WidgetKit runtime, TestFlight UI, push backend and native language review still need external validation. No claim of 100% production readiness without these steps.
