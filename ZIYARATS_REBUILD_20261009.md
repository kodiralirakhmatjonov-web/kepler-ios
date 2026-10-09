# iumrah Ziyarats — clean rebuild (2026-10-09)

## Replaced completely
- `Sources/Ziyarats/ZiyaratViews.swift`: removed the old ~2,200-line map-first implementation (nested gestures, panels, automatic MKDirections, animations, speculative photo prefetch). New compact SwiftUI list screen with lazy rows, a separate on-demand Apple Map and a detail sheet.
- `Sources/Services/ZiyaratService.swift`: recreated async catalogue access and strict data validation. No UserDefaults caching. At first service creation, keys under `iumrah.ziyarats.catalog.*` are deleted; failure is handled by a bundled fallback catalogue.
- `Sources/Models/ZiyaratModels.swift`: preserved public Codable models needed by the API but removed unused legacy seed that is superseded by the new fallback.
- `Sources/Views/Booking/BookingFlightFirstComponentsView.swift`: removed automatic prefetch of Ziyarats catalogues and images from the booking screen.

## Guarantees from code design
- Main Ziyarats screen can render immediately with no internet and before the API responds.
- MapKit map rendering and Apple Maps direction handoff only start following explicit user interaction.
- Coordinates are finite and constrained to Saudi Arabia; duplicate place IDs are removed, photo URLs and arrays are limited.
- Old persistent Ziyarats catalogues are never decoded. Network photo downloads are on demand, use ephemeral URLSession, are restricted to 8 MB, and decoded as bounded ImageIO thumbnails with NSCache limits.
- All four current UI locales are supported: Russian, English, Uzbek Latin, Uzbek Cyrillic.
- Existing entry points `ZiyaratJourneyView()` and `ZiyaratIncludedCatalogSheet()` are preserved so links from Home, Bookings and Account continue to work.
- No other feature's visual layout, Hotel screen, signing, workflows, or project configuration was modified.

## Test status
- Linux Swift parser: all app Swift source files passed (`swiftc -frontend -parse`).
- Stand-alone typechecked runtime service test: offline Makkah 6 stops, Madinah 5 stops; coordinates and unique identifiers passed.
- ZIP root paths and ZIP integrity validated.
- **NOT verified:** actual Xcode 26 iOS/Catalyst compilation, runtime on an iPhone, or the historical production crash. Run the existing TestFlight workflow and check on iPhone 11 and iPhone 13 mini. A TestFlight crash report is essential if the app still terminates.

## QA checklist on TestFlight
1. Cold-open Ziyarats from Home, Bookings and Account (no delay or crash).
2. Open with airplane mode enabled; switch Makkah/Madinah and scroll.
3. Re-enable internet and pull to refresh; check server-published places and translations.
4. Open several place details, then dismiss; verify image loads while scrolling and cancellation works.
5. Tap the map icon; inspect each pin and open external Apple Maps directions.
6. Open the Ziyarats included-in-booking sheet and switch cities.
7. Check iPhone 11 (414x896), iPhone 13 mini (375x812), and landscape/iPad if deployed.

Update ZIP should be uploaded to the GitHub repository root with its exact `iumrah-beta-update-*.zip` filename; the current `Apply iumrah Beta ZIP update` workflow extracts it and removes the ZIP after applying.
