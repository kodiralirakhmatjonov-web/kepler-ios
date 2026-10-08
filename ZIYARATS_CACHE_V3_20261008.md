# iumrah Beta: Hotel Swipe + Ziyarats Cache Fix (cumulative v3)

This single patch includes all six previously supplied Swift file changes and the hotel swipe gesture fix. Upload only this ZIP to your repository update workflow.

## Additional finding: persistent Ziyarats catalogue cache
Previously `ZiyaratService` saved entire server routes indefinitely as `UserDefaults` data using the key prefix `iumrah.ziyarats.catalog.v1.`. The prior stability archives sanitized stored data but did not invalidate legacy on-device catalogues. The Ziyarats photo loader also uses an independent `NSCache` (memory only) and the system `URLCache` (persistent); MapKit has its own internal tile cache. This archive specifically fixes the persisted route catalogue layer, not every kind of image/map caching.

## Changes
- On first Ziyarats catalogue request after installation, delete only `iumrah.ziyarats.catalog.v1.madinah` and `iumrah.ziyarats.catalog.v1.makkah`, preserving user accounts, logins, bookings, and all other settings.
- Do not read the legacy cache. Replace it with versioned `.json` snapshots in the OS Caches directory, max 2 MiB per city, expiring after 7 days.
- Discard missing/corrupt/oversized/expired snapshots safely. The UI receives only sanitized routes with finite in-range coordinates and unique IDs.
- When offline or if the backend responds with invalid data, fall back to the bundled city route instead of crashing. Do not clear system-wide URLCache or photos used by other features.

## Boundaries
Cannot establish the root cause of an existing TestFlight crash without a symbolicated crash report; crashes due to MapKit, memory pressure or navigation may persist. This patch addresses one confirmed stale-cache design weakness, not a proven specific crash stack trace.

## Validation
`swiftc -frontend -parse` completed for the service and all seven bundled Swift sources (syntax only). Full Xcode compile, simulator and iPhone runtime checks are not available here.

## Test plan
1. Upload just this ZIP using the normal GitHub automation and build a new TestFlight version.
2. Open Ziyarats on Wi-Fi; change Madinah/Makkah; reopen it after killing the app; test airplane mode.
3. Confirm hotels carousel swipes do not trigger a configurator and explicit CTA taps still do.
4. If any crash persists, export TestFlight App Store Connect crash report (.ips, preferably symbolicated) and record device/iOS version and exact action before termination.
