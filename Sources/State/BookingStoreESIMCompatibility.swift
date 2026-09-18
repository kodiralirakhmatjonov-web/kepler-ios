import Foundation

// Compatibility bridge for repositories where the eSIM client model was added
// after BookingStore.swift. Keeping this in a separate file avoids replacing
// the newer eSIM-aware BookingModels/HomeDashboard implementation.
@MainActor
private enum BookingESIMCompatibilityCache {
    static var profilesByStore: [ObjectIdentifier: [String: [ClientESIMProfile]]] = [:]

    static func setProfiles(_ profiles: [ClientESIMProfile], bookingID: String, store: BookingStore) {
        let storeID = ObjectIdentifier(store)
        var values = profilesByStore[storeID] ?? [:]
        if profiles.isEmpty {
            values.removeValue(forKey: bookingID)
        } else {
            values[bookingID] = profiles
        }
        profilesByStore[storeID] = values
    }

    static func profiles(bookingID: String, store: BookingStore) -> [ClientESIMProfile] {
        profilesByStore[ObjectIdentifier(store)]?[bookingID] ?? []
    }
}

extension ClientTripResponse {
    /// Source-compatible initializer for call sites created before `esims`
    /// became part of ClientTripResponse.
    init(ok: Bool?, trip: ClientTripSnapshot, assignment: ClientBookingAssignment?) {
        self.init(
            ok: ok,
            trip: trip,
            assignment: assignment,
            esims: nil,
            statusHistory: nil
        )
    }
}

extension BookingStore {
    /// Refreshes the complete eSIM list from the existing authenticated
    /// operational-trip endpoint. No separate paid API or additional backend
    /// is introduced here.
    func loadESIMs(for bookingID: String) async throws {
        guard let session = booking(id: bookingID) else {
            BookingESIMCompatibilityCache.setProfiles([], bookingID: bookingID, store: self)
            return
        }

        let token = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            // Account-restored sessions may not have a local booking token.
            // Do not manufacture eSIM data in that case.
            BookingESIMCompatibilityCache.setProfiles([], bookingID: bookingID, store: self)
            return
        }

        let response = try await BookingService().fetchOperationalTrip(
            id: bookingID,
            headers: ["x-booking-token": token]
        )
        BookingESIMCompatibilityCache.setProfiles(
            response.esims ?? [],
            bookingID: bookingID,
            store: self
        )
    }

    /// Returns every eSIM profile associated with the booking.
    func esimProfiles(for bookingID: String) -> [ClientESIMProfile] {
        BookingESIMCompatibilityCache.profiles(bookingID: bookingID, store: self)
    }

    /// Convenience accessor used by compact cards and status surfaces.
    func primaryESIM(for bookingID: String) -> ClientESIMProfile? {
        esimProfiles(for: bookingID).first
    }
}
