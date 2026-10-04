import Foundation

struct BookingService {
    private let api = APIClient.shared

    func createBooking(_ request: BookingCreateEnvelope) async throws -> BookingCreateResponse {
        try await api.post(AppConfig.packageBookingPath, body: request)
    }

    func fetchBooking(id: String, accessToken: String) async throws -> RemoteBooking {
        let response: BookingCreateResponse = try await api.get(
            "/api/bookings/\(id)",
            headers: ["x-booking-token": accessToken]
        )
        return response.booking
    }



    func syncBookingProfile(
        id: String,
        accessToken: String,
        profile: BookingPilgrimProfile,
        generatorTrace: BookingGeneratorTrace? = nil
    ) async throws -> ClientTripResponse {
        let response: ClientTripResponse = try await api.post(
            "/api/catalog/hotels/client/trips/\(id)/sync",
            body: BookingProfileSyncRequest(
                firstName: profile.firstName,
                lastName: profile.lastName,
                displayName: profile.displayName,
                telegram: profile.telegram,
                whatsapp: profile.whatsapp,
                generatorTrace: generatorTrace
            ),
            headers: ["x-booking-token": accessToken]
        )
        return response
    }

    /// Persists the exact immutable generator audit report into the operational
    /// iumrah Business trip immediately after booking creation. This does not depend
    /// on the pilgrim having already completed profile fields.
    func syncGeneratorReport(
        id: String,
        accessToken: String,
        generatorTrace: BookingGeneratorTrace?
    ) async throws -> ClientTripResponse {
        let response: ClientTripResponse = try await api.post(
            "/api/catalog/hotels/client/trips/\(id)/sync",
            body: BookingGeneratorReportSyncRequest(
                generatorTrace: generatorTrace
            ),
            headers: ["x-booking-token": accessToken]
        )
        return response
    }

    func fetchOperationalTrip(id: String, headers: [String: String]) async throws -> ClientTripResponse {
        let response: ClientTripResponse = try await api.get(
            "/api/catalog/hotels/client/trips/\(id)",
            headers: headers
        )
        return response
    }

    func fetchItinerary(id: String, headers: [String: String], language: AppSettingsStore.Language) async throws -> [BookingItineraryItem] {
        do {
            let response: BookingItineraryResponse = try await api.get(
                "/api/package/booking/\(id)/itinerary",
                query: [URLQueryItem(name: "lang", value: language.rawValue)],
                headers: headers
            )
            if response.ok, !response.items.isEmpty {
                return response.items.sorted { lhs, rhs in
                    if lhs.dateLocal != rhs.dateLocal { return lhs.dateLocal < rhs.dateLocal }
                    return lhs.sortOrder < rhs.sortOrder
                }
            }
        } catch {
            // Backward-compatible fallback while the PackageEngine deployment rolls out.
        }

        let response: BookingItineraryResponse = try await api.get(
            "/api/catalog/hotels/client/trips/\(id)/itinerary",
            query: [URLQueryItem(name: "lang", value: language.rawValue)],
            headers: headers
        )
        return response.items.sorted { lhs, rhs in
            if lhs.dateLocal != rhs.dateLocal { return lhs.dateLocal < rhs.dateLocal }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    func updateHotelSelection(
        id: String,
        accessToken: String,
        role: HotelSelectionRole,
        hotel: HotelSummary,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption? = nil
    ) async throws -> BookingMutationResponse {
        try await updateHotelSelection(
            id: id,
            headers: ["x-booking-token": accessToken],
            role: role,
            hotel: hotel,
            room: room,
            roomCategory: roomCategory
        )
    }

    func updateHotelSelection(
        id: String,
        headers: [String: String],
        role: HotelSelectionRole,
        hotel: HotelSummary,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption? = nil
    ) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)",
            body: BookingHotelUpdateRequest(role: role, hotel: hotel, room: room, roomCategory: roomCategory),
            headers: headers
        )
    }

    func updateHotelSelection(id: String, accessToken: String, role: HotelSelectionRole, snapshot: BookingHotelSelectionSnapshot) async throws -> BookingMutationResponse {
        try await updateHotelSelection(id: id, headers: ["x-booking-token": accessToken], role: role, snapshot: snapshot)
    }

    func updateHotelSelection(id: String, headers: [String: String], role: HotelSelectionRole, snapshot: BookingHotelSelectionSnapshot) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)",
            body: BookingHotelUpdateRequest(role: role, snapshot: snapshot),
            headers: headers
        )
    }

    func updateContacts(id: String, accessToken: String, telegram: String, whatsapp: String) async throws -> BookingMutationResponse {
        try await updateContacts(id: id, headers: ["x-booking-token": accessToken], telegram: telegram, whatsapp: whatsapp)
    }

    func updateContacts(id: String, headers: [String: String], telegram: String, whatsapp: String) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)/contact",
            body: BookingContactUpdateRequest(telegram: telegram, whatsapp: whatsapp),
            headers: headers
        )
    }

    func updateZiyarat(id: String, accessToken: String, makkah: Bool, madinah: Bool) async throws -> BookingMutationResponse {
        try await updateZiyarat(id: id, headers: ["x-booking-token": accessToken], makkah: makkah, madinah: madinah)
    }

    func updateZiyarat(id: String, headers: [String: String], makkah: Bool, madinah: Bool) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)/customization",
            body: BookingCustomizationUpdateRequest(ziyaratMakkah: makkah, ziyaratMadinah: madinah, esim: nil),
            headers: headers
        )
    }


    func updateESIM(id: String, headers: [String: String], enabled: Bool) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)/customization",
            body: BookingCustomizationUpdateRequest(ziyaratMakkah: nil, ziyaratMadinah: nil, esim: enabled),
            headers: headers
        )
    }

    func securityConfirmation(id: String, accessToken: String) async throws -> IumrahSecurityConfirmationResponse {
        try await api.get(
            "/api/catalog/hotels/client/trips/\(id)/security",
            headers: ["x-booking-token": accessToken]
        )
    }

    func uploadSecurityPassport(
        id: String,
        accessToken: String,
        data: Data,
        contentType: String
    ) async throws -> IumrahSecurityConfirmationResponse {
        try await api.upload(
            "/api/catalog/hotels/client/trips/\(id)/security/passport",
            data: data,
            contentType: contentType,
            headers: ["x-booking-token": accessToken],
            timeoutInterval: 60
        )
    }

    func submitSecurityConfirmation(
        id: String,
        accessToken: String,
        firstName: String,
        lastName: String,
        passportNumber: String
    ) async throws -> IumrahSecurityConfirmationResponse {
        try await api.put(
            "/api/catalog/hotels/client/trips/\(id)/security",
            body: IumrahSecurityConfirmationRequest(
                firstName: firstName,
                lastName: lastName,
                passportNumber: passportNumber,
                holderConfirmed: true
            ),
            headers: ["x-booking-token": accessToken]
        )
    }

    func friendsSummary(id: String, headers: [String: String]) async throws -> IumrahFriendsBookingSummary {
        try await api.get(
            "/api/package/booking/\(id)/friends",
            headers: headers
        )
    }

    func redeemFriendGift(id: String, headers: [String: String], code: String) async throws -> IumrahFriendsBookingSummary {
        try await api.post(
            "/api/package/booking/\(id)/friends/redeem",
            body: IumrahFriendGiftRedeemRequest(code: code),
            headers: headers
        )
    }

    func applyFriendCredit(id: String, headers: [String: String], amountUsd: Int) async throws -> IumrahFriendsBookingSummary {
        try await api.post(
            "/api/package/booking/\(id)/friends/credit",
            body: IumrahFriendCreditApplyRequest(amountUsd: amountUsd),
            headers: headers
        )
    }

    func deleteBooking(id: String, accessToken: String) async throws -> BookingMutationResponse {
        try await deleteBooking(id: id, headers: ["x-booking-token": accessToken])
    }

    func deleteBooking(id: String, headers: [String: String]) async throws -> BookingMutationResponse {
        try await api.delete(
            "/api/catalog/hotels/client/bookings/\(id)",
            headers: headers
        )
    }
}


private struct BookingProfileSyncRequest: Encodable {
    let firstName: String
    let lastName: String
    let displayName: String
    let telegram: String
    let whatsapp: String
    let generatorTrace: BookingGeneratorTrace?
}

private struct BookingGeneratorReportSyncRequest: Encodable {
    let generatorTrace: BookingGeneratorTrace?
}
