import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum IumrahWidgetSyncService {
    static func sync(
        bookings: [StoredBookingSession],
        account: IumrahAccountProfile?,
        plannedTrip: UmrahPlannedTrip?
    ) {
        let active = bookings.first { session in
            !["COMPLETED", "CANCELLED"].contains(session.effectiveStatus.uppercased())
        }

        let bookingSnapshot = active.map { session in
            IumrahWidgetBookingSnapshot(
                id: session.id,
                displayNumber: session.displayBookingNumber,
                status: session.effectiveStatus.uppercased(),
                originCode: session.booking.input.originCode.uppercased(),
                destinationCode: session.booking.route.outboundDestination.uppercased(),
                startDate: parseTripDate(session.booking.input.startDate),
                endDate: parseTripDate(session.booking.input.endDate),
                travelerCount: session.booking.input.travelers.totalPeople,
                perPilgrimUSD: session.booking.perPilgrimUsd
            )
        }

        let plannedSnapshot = plannedTrip.map {
            IumrahWidgetPlannedTripSnapshot(
                id: $0.id,
                title: $0.title,
                startDate: $0.startDate,
                endDate: $0.endDate,
                backgroundID: $0.backgroundID,
                notificationsEnabled: $0.notificationsEnabled,
                reminderHour: $0.reminderHour,
                reminderMinute: $0.reminderMinute
            )
        }

        let identitySnapshot = account.map { profile in
            let digits = profile.iumrahID.filter(\.isNumber)
            let normalizedID = digits.isEmpty ? profile.iumrahID : String(repeating: "0", count: max(0, 8 - digits.count)) + digits
            let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? [profile.firstName, profile.lastName].filter { !$0.isEmpty }.joined(separator: " ")
                : profile.displayName
            return IumrahWidgetIdentitySnapshot(
                displayName: displayName.isEmpty ? "iumrah" : displayName,
                iumrahID: normalizedID,
                publicURL: "https://iumrah.app/id/\(normalizedID)"
            )
        }

        let snapshot = IumrahWidgetSnapshot(
            updatedAt: Date(),
            activeBooking: bookingSnapshot,
            plannedTrip: plannedSnapshot,
            identity: identitySnapshot
        )
        _ = IumrahWidgetSharedStore.save(snapshot)
        reloadWidgets()
    }

    static func updatePlannedTrip(_ trip: UmrahPlannedTrip?) {
        IumrahWidgetSharedStore.mutate { snapshot in
            snapshot.plannedTrip = trip.map {
                IumrahWidgetPlannedTripSnapshot(
                    id: $0.id,
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    backgroundID: $0.backgroundID,
                    notificationsEnabled: $0.notificationsEnabled,
                    reminderHour: $0.reminderHour,
                    reminderMinute: $0.reminderMinute
                )
            }
        }
        reloadWidgets()
    }

    private static func parseTripDate(_ value: String) -> Date? {
        if let iso = ISO8601DateFormatter().date(from: value) { return iso }
        for format in ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
