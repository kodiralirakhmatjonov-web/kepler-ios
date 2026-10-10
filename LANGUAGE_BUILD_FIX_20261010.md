# Iumrah iOS — triple-language build audit, 10 October 2026

## Confirmed current CI failure

`logs_103047561975.zip`: `Sources/Services/FlightSearchService.swift:12` — non-exhaustive `switch (self, language)`. The exact missing pair is `(.checkingProvider(_), .malay)`. The archive fills this pair without modifying flight inventory or search logic.

## Other detected issues

- `L10n.text` lacked the Malay app-wide dispatcher: Malay was silently falling back to English. `AppLocalization.swift` now routes to `MalayLocalization.key`.
- `MalayLocalization` from the previous v2 patch handled selector phrases only. This patch adds app keyed translations with a predictable fallback.
- Turkish `hotel_detail_package_total_for_fmt` reordered `%@` and `%d` without positional placeholders. Updated to `%2$d kişi için toplam %1$@`, retaining caller argument order and types.
- Indonesian core account/settings labels get explicit existing-safe translations (unchanged Swift surface API).
- CI preflight now invokes `scripts/ci_language_audit.py`: it checks **each** tuple case per language instead of merely searching for `.malay` anywhere in the switch. Includes negative self-test.

## Safety and limitations

This is a file replacement patch, based on `kepler-ios-main 5.zip` + earlier fix archives, not a live pull of GitHub's latest `main`. It does not replace the more recent `HotelsHomeView.swift`, which CI already showed has Malay cases. Before merging, check source diffs if those six file paths have been edited meanwhile. A successful Xcode Simulator and Release build is essential; Linux `swiftc -parse` cannot guarantee an iOS build will succeed.

## Files

- `Sources/Services/FlightSearchService.swift`
- `Sources/Core/AppLocalization.swift`
- `Sources/Core/TurkishLocalization.swift`
- `Sources/Core/IndonesianLocalization.swift`
- `Sources/Core/MalayLocalization.swift`
- `scripts/ci_language_audit.py`
- `scripts/ci_preflight.py`

No SwiftUI layouts or screens replaced.
