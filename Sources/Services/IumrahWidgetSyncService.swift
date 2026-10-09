import Foundation
import WidgetKit

enum IumrahWidgetSyncService {
    static func sync(
        bookings: [StoredBookingSession],
        account: IumrahAccountProfile?,
        plannedTrip: UmrahPlannedTrip?,
        languageCode: String
    ) {
        let snapshot = IumrahWidgetSnapshot(
            activeBooking: makeActiveBooking(from: bookings),
            plannedTrip: plannedTrip.map(makePlannedTrip),
            identity: account.map(makeIdentity),
            languageCode: languageCode
        )

        _ = IumrahWidgetSharedStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func updatePlannedTrip(_ trip: UmrahPlannedTrip?) {
        IumrahWidgetSharedStore.mutate { snapshot in
            snapshot.plannedTrip = trip.map(makePlannedTrip)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func makeActiveBooking(from bookings: [StoredBookingSession]) -> IumrahWidgetBookingSnapshot? {
        let active = bookings
            .filter { session in
                let status = session.effectiveStatus.uppercased()
                return status != "COMPLETED" && status != "CANCELLED"
            }
            .sorted { lhs, rhs in
                let left = parseDate(lhs.booking.input.startDate) ?? .distantFuture
                let right = parseDate(rhs.booking.input.startDate) ?? .distantFuture
                return left < right
            }
            .first

        guard let session = active else { return nil }
        let booking = session.booking

        return IumrahWidgetBookingSnapshot(
            id: session.id,
            displayNumber: session.displayBookingNumber,
            status: session.effectiveStatus,
            originCode: booking.input.originCode,
            destinationCode: booking.route.outboundDestination.isEmpty
                ? booking.input.arrivalAirportCode
                : booking.route.outboundDestination,
            startDate: parseDate(booking.input.startDate),
            endDate: parseDate(booking.input.endDate),
            travelerCount: max(1, booking.input.travelers.totalPeople),
            perPilgrimUSD: booking.perPilgrimUsd
        )
    }

    private static func makePlannedTrip(_ trip: UmrahPlannedTrip) -> IumrahWidgetPlannedTripSnapshot {
        IumrahWidgetPlannedTripSnapshot(
            id: trip.id,
            title: trip.title,
            startDate: trip.startDate,
            endDate: trip.endDate,
            backgroundID: trip.backgroundID,
            notificationsEnabled: trip.notificationsEnabled,
            reminderHour: trip.reminderHour,
            reminderMinute: trip.reminderMinute
        )
    }

    private static func makeIdentity(_ account: IumrahAccountProfile) -> IumrahWidgetIdentitySnapshot {
        let rawName = account.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = [account.firstName, account.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let displayName = rawName.isEmpty ? fallbackName : rawName
        let normalizedID = account.iumrahID.trimmingCharacters(in: .whitespacesAndNewlines)

        return IumrahWidgetIdentitySnapshot(
            displayName: displayName,
            iumrahID: normalizedID,
            publicURL: "https://iumrah.app/id/\(normalizedID)"
        )
    }

    private static func parseDate(_ value: String) -> Date? {
        if let iso = ISO8601DateFormatter().date(from: value) {
            return iso
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
