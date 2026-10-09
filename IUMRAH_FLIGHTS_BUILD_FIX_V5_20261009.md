# iumrah Flights Xcode Build Fix V5 · 2026-10-09

Source failure: `logs_102829391548.zip` / `build/9_Validate simulator build.txt`.

## Corrected compiler diagnostics

- All **23 non-exhaustive Swift language switches** in `IumrahFlightDiscoveryView.swift` now handle `.turkish`, as required by the five-case `AppSettingsStore.Language` enum.
- For Turkish, airport names, weekdays, duration, number of stops and date formatting are localized; longer copy falls back to English until full Turkish translations are introduced. Other languages are unchanged.
- The `connectionRow` `Text(...)` expression that caused a SwiftUI type-check timeout is now split into explicitly typed `String` values before the ViewBuilder, so Swift need not infer nested overloaded concatenations.

## Scope

Only `Sources/Views/Flights/IumrahFlightDiscoveryView.swift` is modified. No backend contracts, search/filter, flight prices, fare amounts, routing, other views, account settings or widget implementation changed.

## Checks performed

- Parsed with Linux Swift 6.2.1 `swiftc -frontend -parse` (syntax-only check).
- Verified all 23 language switches have a `.turkish` branch.
- Compared against the previous flight patch: 37 added lines, 1 replaced line; no other original lines removed.
- ZIP integrity test.

**Not verified**: full Xcode simulator build on macOS; the user's GitHub Actions build must confirm it. If build passes, check flight search, filters, calendar, itinerary and Aviasales link in TestFlight.

## Applying

Upload the ZIP to repository root in `main` under its existing `iumrah-beta-update-*` name. Wait for **Apply iumrah Beta ZIP update** to complete and commit changes *before* running **TestFlight**. The ZIP is a delta for a repository that already contains the flight details production repair update.
