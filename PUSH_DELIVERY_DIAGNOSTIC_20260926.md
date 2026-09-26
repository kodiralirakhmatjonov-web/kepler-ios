# Iumrah push delivery diagnostic · 2026-09-26

## What is present in this iOS repository

- `Resources/iUmra.entitlements` contains `aps-environment = production`.
- The TestFlight workflow explicitly verifies that the final signed IPA keeps the production APNs entitlement.
- `IumrahAppDelegate` registers with APNs and receives both foreground notifications and notification taps.
- `PushNotificationManager` persists the APNs device token.
- Booking-scoped push registration is sent to `/api/catalog/hotels/client/push/devices`.
- System/Signal registration is sent to `/api/catalog/hotels/client/notifications/devices`.

## Client-side hardening added in this patch

1. A failed APNs registration clears the cached token so an old token is not shown or re-sent as if it were valid.
2. Opening / refreshing Account rechecks APNs registration, booking push subscriptions and Signal device registration.
3. Account → Notifications no longer reports only the iOS authorization switch. It can now surface:
   - APNs registration in progress;
   - delivery connection error;
   - server push provider not ready;
   - enabled and delivery connected.

## Remaining server dependency

The bundled `Backend/PackageEngine` source does not contain handlers or an APNs sender for either client push registration endpoint above. That means this repository alone cannot guarantee remote delivery while the app is closed. The service that owns `/api/catalog/hotels/...` must:

- persist current production device tokens for bundle `com.iumrah.app`;
- return `ready: true` only when the APNs provider is actually configured;
- send through production APNs with credentials for the same App ID / Team;
- delete or quarantine tokens rejected by APNs as invalid/unregistered;
- record provider response codes so failed deliveries are diagnosable.

A web-push fallback was not added here because the web portal/backend source that would own browser push subscriptions is not part of the supplied ZIP.
