# iumrah Flights — fare detail & Aviasales route search repair

## What's changed
- `FlightDiscoveryOfferDetailView` presents clean per-direction cards, not repeated orange warnings / technical API jargon.
- Dates, times and carrier information are not invented when an offer has connections.
- Estimated arrival times derived from an itinerary's aggregate duration are explicitly labeled estimates.
- Verified ticket segments can now be decoded as optional `outboundSegments` / `inboundSegments`. The client validates exact airport continuity, timeline order and transfer count before showing each flight and layover time.
- **Current Aviasales Data API responses DO NOT supply complete segment arrays**. This patch does not magically reconstruct layover airports, airline names or flight numbers that the provider did not return.
- The CTA bypasses stale ticket-specific links and opens a new route/date/passenger search through official Aviasales search URL format. These are new search results, not a promise that the old fare remains bookable.
- User-visible references to “Data API” have been removed from the discovery UI.
- No other tab or business logic was changed.

## Source files
- Sources/Views/Flights/IumrahFlightDiscoveryView.swift
- Sources/Services/AviasalesFlightDiscoveryService.swift
- Sources/Services/AviasalesSearchLinkBuilder.swift (new)
- Sources/Services/FlightDiscoveryVerifiedSegment.swift (new)

## Important technical/product caveats
- To render every flight segment and intermediate airport for all itineraries in real time, the server must integrate a licensed itinerary-capable ticket search response. The cached-fare endpoint alone does not have these fields.
- New route-search links are not automatically attributed to a Travelpayouts partner. Affiliate attribution requires a supported partner link-generation workflow. Do not assume commission tracking from a raw `aviasales.ru/search/...` URL.
- Build with Xcode and test navigation, localization, and links on device before release. The Linux Swift parser is not a replacement for iOS SDK type checking.

## Local verification
- Swift 6.2 parser: all four modified/added files passed.
- Foundation executable test: date-specific one-way and return search URL construction, children/infants, invalid dates and airport codes passed.
- Foundation executable test: verified two-leg itinerary and 210-minute layover, invalid transfers and airport mismatch passed.
- Foundation executable test: existing JSON responses decode without new optional segment fields.
- Existing backend API + iOS discovery source contract test passed.
