import Foundation

// Widgets are intentionally disabled in the production target until the
// Widget Extension has its own App Store provisioning profile. Keeping the
// API surface as a no-op lets existing call sites compile without putting
// WidgetKit, shared-keychain access, or extension work on the app launch path.
enum IumrahWidgetSyncService {
    static func sync(
        bookings: [StoredBookingSession],
        account: IumrahAccountProfile?,
        plannedTrip: UmrahPlannedTrip?
    ) {
        // Intentionally disabled for the stable non-widget build.
    }

    static func updatePlannedTrip(_ trip: UmrahPlannedTrip?) {
        // Intentionally disabled for the stable non-widget build.
    }
}
