import Foundation
import SwiftUI

enum BookingStoreError: LocalizedError {
    case permanentDeleteUnavailable
    case authoritativeQuoteRequired

    var errorDescription: String? {
        switch self {
        case .permanentDeleteUnavailable:
            return "Permanent booking deletion is not available on the server."
        case .authoritativeQuoteRequired:
            return "The package price must be confirmed by the secure iumrah PackageEngine before booking."
        }
    }
}

@MainActor
final class BookingStore: ObservableObject {
    @Published private(set) var sessions: [StoredBookingSession] = []
    @Published private(set) var chats: [String: [ChatMessage]] = [:]
    @Published private(set) var itineraries: [String: [BookingItineraryItem]] = [:]
    @Published private(set) var pushRegistrationReady: Bool?
    @Published private(set) var pushRegistrationError: String?

    private let bookingService = BookingService()
    private let packageEngine = RemotePackageEngineClient()
    private let hotelCatalogService = HotelCatalogService()
    private let chatService = ChatService()
    private let clientPushService = ClientPushService()
    private let accountService = IumrahAccountService()
    private let legacyStorageKey = "iumrah.booking.sessions.v1"
    private var accountToken: String?

    init() {
        loadFromStorage()
    }

    func create(
        trip: TripDraft,
        hotel: HotelSummary,
        madinahHotel: HotelSummary? = nil,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption? = nil,
        madinahRoom: HotelRoom? = nil,
        madinahRoomCategory: IumrahRoomCategoryOption? = nil,
        authoritativeMakkahRoomId: String? = nil,
        authoritativeMadinahRoomId: String? = nil,
        intercityTransport: ServerIntercityTransport? = nil,
        outbound: FlightOffer,
        inbound: FlightOffer?,
        quote: PackageQuote,
        language: AppSettingsStore.Language,
        pilgrimProfile: BookingPilgrimProfile?
    ) async throws -> StoredBookingSession {
        guard let quoteID = quote.quoteId,
              quoteID.hasPrefix("server-"),
              let quoteProof = quote.quoteProof,
              !quoteProof.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BookingStoreError.authoritativeQuoteRequired
        }

        let payload = BookingDraftBuilder.make(
            trip: trip,
            hotel: hotel,
            madinahHotel: madinahHotel,
            room: room,
            roomCategory: roomCategory,
            madinahRoom: madinahRoom,
            madinahRoomCategory: madinahRoomCategory,
            authoritativeMakkahRoomId: authoritativeMakkahRoomId,
            authoritativeMadinahRoomId: authoritativeMadinahRoomId,
            intercityTransport: intercityTransport,
            outbound: outbound,
            inbound: inbound,
            quote: quote,
            language: language,
            pilgrimProfile: pilgrimProfile
        )
        let response = try await bookingService.createBooking(payload)
        guard let token = response.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw APIError.missingBookingToken
        }
        let serverProfile = response.booking.pilgrimProfile ?? pilgrimProfile
        var session = StoredBookingSession(
            id: response.booking.id,
            accessToken: token,
            booking: response.booking,
            travelerName: serverProfile?.displayName,
            telegram: serverProfile?.telegram,
            whatsapp: serverProfile?.whatsapp,
            outboundFlight: outbound,
            inboundFlight: inbound,
            hotelSelection: BookingHotelSelectionSnapshot(hotel: hotel, room: room, roomCategory: roomCategory, authoritativeRoomId: authoritativeMakkahRoomId),
            madinahHotelSelection: madinahHotel.map { BookingHotelSelectionSnapshot(hotel: $0, room: madinahRoom, roomCategory: madinahRoomCategory, authoritativeRoomId: authoritativeMadinahRoomId) }
        )
        // Keep only the opaque proof until PackageEngine accepts responsibility for
        // the server-owned cost report. Persist immediately after the canonical booking
        // response so an app termination during Business/profile synchronization cannot
        // lose the reconciliation job. No supplier pricing is readable here.
        session.pendingGeneratorQuoteProof = quote.quoteProof
        upsert(session)

        // Hand the confidential report to PackageEngine immediately after the
        // canonical booking exists. PackageEngine either commits it to an existing
        // Business trip or durably queues it server-side until that trip is created.
        // This closes the crash window before account/profile synchronization.
        var pricingReportCommitted = false
        if let proof = session.pendingGeneratorQuoteProof, !proof.isEmpty {
            pricingReportCommitted = await commitPricingReportWithRetry(
                id: session.id,
                accessToken: session.accessToken,
                quoteProof: proof
            )
            if pricingReportCommitted {
                session.pendingGeneratorQuoteProof = nil
                upsert(session)
            }
        }

        if let accountToken, !accountToken.isEmpty,
           let linked = try? await accountService.linkBooking(bookingID: session.id, bookingToken: session.accessToken, token: accountToken) {
            session.pilgrimID = linked.pilgrimID
            session.bookingNumber = linked.bookingNumber
            session.bookingDisplayNumber = linked.bookingDisplayNumber
        }
        // First synchronize only the public generator trace. The confidential
        // supplier-cost report is never accepted from the client anymore.
        let generatorReportResult = await syncGeneratorReportWithRetry(
            id: session.id,
            accessToken: session.accessToken,
            generatorTrace: payload.booking.generatorTrace
        )
        if let operational = generatorReportResult {
            session.mergeOperationalTrip(operational.trip)
            session.mergeOperationalStatusHistory(operational.statusHistory)
            session.guide = operational.assignment?.guide
        }

        if let profile = serverProfile, !profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let response = try? await bookingService.syncBookingProfile(
                id: session.id,
                accessToken: session.accessToken,
                profile: profile,
                generatorTrace: generatorReportResult == nil ? payload.booking.generatorTrace : nil
            ) {
                session.mergeOperationalTrip(response.trip)
                session.mergeOperationalStatusHistory(response.statusHistory)
                session.guide = response.assignment?.guide
            }
        }

        // Profile sync may have created the Business trip after the first commit
        // attempt. Give the server-owned report one final immediate chance here; a
        // pending proof is also retried by refreshAll if a transient race remains.
        if !pricingReportCommitted,
           let proof = session.pendingGeneratorQuoteProof, !proof.isEmpty {
            pricingReportCommitted = await commitPricingReportWithRetry(
                id: session.id,
                accessToken: session.accessToken,
                quoteProof: proof
            )
        }
        if pricingReportCommitted {
            session.pendingGeneratorQuoteProof = nil
        }
        upsert(session)
        if let makkahSelection = session.hotelSelection {
            _ = try? await bookingService.updateHotelSelection(
                id: session.id,
                accessToken: session.accessToken,
                role: .makkah,
                snapshot: makkahSelection
            )
        }
        if let madinahSelection = session.madinahHotelSelection {
            _ = try? await bookingService.updateHotelSelection(
                id: session.id,
                accessToken: session.accessToken,
                role: .madinah,
                snapshot: madinahSelection
            )
        }
        return session
    }

    private func syncGeneratorReportWithRetry(
        id: String,
        accessToken: String,
        generatorTrace: BookingGeneratorTrace?
    ) async -> ClientTripResponse? {
        guard generatorTrace != nil else { return nil }
        let retryDelaysMilliseconds = [0, 350, 900, 1_800]
        for (index, delayMilliseconds) in retryDelaysMilliseconds.enumerated() {
            if delayMilliseconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000)
            }
            do {
                return try await bookingService.syncGeneratorReport(
                    id: id,
                    accessToken: accessToken,
                    generatorTrace: generatorTrace
                )
            } catch {
                if index == retryDelaysMilliseconds.count - 1 {
                    #if DEBUG
                    print("[BookingStore] generator trace sync failed after retries: \(error)")
                    #endif
                }
            }
        }
        return nil
    }

    private func commitPricingReportWithRetry(
        id: String,
        accessToken: String,
        quoteProof: String
    ) async -> Bool {
        let retryDelaysMilliseconds = [0, 350, 900, 1_800]
        for (index, delayMilliseconds) in retryDelaysMilliseconds.enumerated() {
            if delayMilliseconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000)
            }
            do {
                try await packageEngine.commitPricingReport(
                    bookingID: id,
                    bookingToken: accessToken,
                    quoteProof: quoteProof
                )
                return true
            } catch {
                if index == retryDelaysMilliseconds.count - 1 {
                    #if DEBUG
                    print("[BookingStore] server pricing report commit failed after retries: \(error)")
                    #endif
                }
            }
        }
        return false
    }

    func refreshAll() async {
        var staleBookingIDs = Set<String>()

        for session in sessions {
            let bookingToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                if !bookingToken.isEmpty {
                    let booking = try await bookingService.fetchBooking(id: session.id, accessToken: bookingToken)
                    var operational: ClientTripResponse?
                    if let profile = identityProfile(remote: booking.pilgrimProfile, session: session) {
                        operational = try? await bookingService.syncBookingProfile(
                            id: session.id,
                            accessToken: bookingToken,
                            profile: profile
                        )
                    }
                    if operational == nil {
                        operational = try? await bookingService.fetchOperationalTrip(
                            id: session.id,
                            headers: ["x-booking-token": bookingToken]
                        )
                    }
                    mergeRemoteBooking(booking, operational: operational, bookingID: session.id)
                } else if let accountToken, !accountToken.isEmpty {
                    let detail = try await accountService.tripDetail(bookingID: session.id, token: accountToken)
                    mergeRemoteBooking(
                        detail.booking,
                        operational: ClientTripResponse(ok: true, trip: detail.trip, assignment: detail.assignment, esims: detail.esims, statusHistory: detail.statusHistory),
                        bookingID: session.id
                    )
                }

                if !bookingToken.isEmpty,
                   let pendingProof = session.pendingGeneratorQuoteProof,
                   !pendingProof.isEmpty,
                   await commitPricingReportWithRetry(id: session.id, accessToken: bookingToken, quoteProof: pendingProof),
                   let index = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[index].pendingGeneratorQuoteProof = nil
                }

                if let current = booking(id: session.id) {
                    await hydrateHotelSelectionIfNeeded(bookingID: session.id, role: .makkah)
                    if current.booking.input.includeMadinah {
                        await hydrateHotelSelectionIfNeeded(bookingID: session.id, role: .madinah)
                    }
                }
            } catch APIError.status(let code) where code == 404 || code == 410 {
                staleBookingIDs.insert(session.id)
            } catch APIError.server(let code, let message) where isRemoteMissing(code: code, message: message) {
                staleBookingIDs.insert(session.id)
            } catch {
                continue
            }
        }

        for id in staleBookingIDs { purgeLocalBooking(id: id) }
        persist()
    }

    func setAccountToken(_ token: String?) {
        accountToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func restoreAccountTrips(token: String) async {
        setAccountToken(token)
        guard let trips = try? await accountService.trips(token: token) else { return }
        for trip in trips {
            guard let detail = try? await accountService.tripDetail(bookingID: trip.bookingID, token: token) else { continue }
            if let index = sessions.firstIndex(where: { $0.id == trip.bookingID }) {
                sessions[index].booking = detail.booking
                sessions[index].mergeOperationalTrip(detail.trip)
                sessions[index].mergeOperationalStatusHistory(detail.statusHistory)
                sessions[index].guide = detail.assignment?.guide ?? sessions[index].guide
                mergeRemoteHotelSelection(detail.booking.hotelSelection, into: &sessions[index].hotelSelection)
                mergeRemoteHotelSelection(detail.booking.madinahHotelSelection, into: &sessions[index].madinahHotelSelection)
            } else {
                let profile = detail.booking.pilgrimProfile
                var restored = StoredBookingSession(
                    id: trip.bookingID,
                    accessToken: "",
                    booking: detail.booking,
                    travelerName: profile?.displayName,
                    telegram: profile?.telegram,
                    whatsapp: profile?.whatsapp,
                    outboundFlight: nil,
                    inboundFlight: nil,
                    hotelSelection: detail.booking.hotelSelection,
                    madinahHotelSelection: detail.booking.madinahHotelSelection,
                    guide: detail.assignment?.guide
                )
                restored.mergeOperationalTrip(detail.trip)
                restored.mergeOperationalStatusHistory(detail.statusHistory)
                sessions.append(restored)
            }
        }
        sessions.sort { $0.booking.createdAt > $1.booking.createdAt }
        persist()
    }

    func applyCanonicalLink(_ value: IumrahAccountLinkBookingResponse, to bookingID: String) {
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].pilgrimID = value.pilgrimID
        sessions[index].bookingNumber = value.bookingNumber ?? sessions[index].bookingNumber
        sessions[index].bookingDisplayNumber = value.bookingDisplayNumber ?? sessions[index].bookingDisplayNumber
        persist()
    }

    private func mergeRemoteBooking(_ booking: RemoteBooking, operational: ClientTripResponse?, bookingID: String) {
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].booking = booking
        if let trip = operational?.trip { sessions[index].mergeOperationalTrip(trip) }
        sessions[index].mergeOperationalStatusHistory(operational?.statusHistory)
        sessions[index].guide = operational?.assignment?.guide ?? sessions[index].guide
        if let profile = booking.pilgrimProfile {
            sessions[index].travelerName = profile.displayName
            sessions[index].telegram = profile.telegram
            sessions[index].whatsapp = profile.whatsapp
        }
        mergeRemoteHotelSelection(booking.hotelSelection, into: &sessions[index].hotelSelection)
        mergeRemoteHotelSelection(booking.madinahHotelSelection, into: &sessions[index].madinahHotelSelection)
        if let customization = booking.customization {
            sessions[index].ziyaratMakkahOverride = customization.ziyaratMakkah
            sessions[index].ziyaratMadinahOverride = customization.ziyaratMadinah
            sessions[index].esimOverride = customization.esim
        }
    }

    func booking(id: String) -> StoredBookingSession? {
        sessions.first(where: { $0.id == id })
    }

    private func hydrateHotelSelectionIfNeeded(bookingID: String, role: HotelSelectionRole) async {
        guard let current = booking(id: bookingID) else { return }
        let existing = role == .madinah ? current.madinahHotelSelection : current.hotelSelection
        guard existing == nil else { return }

        let rawName = role == .madinah ? current.booking.hotelNames.madinah : current.booking.hotelNames.makkah
        let targetName = normalizedHotelName(rawName)
        guard !targetName.isEmpty else { return }

        let city = role == .madinah ? "Madinah" : "Makkah"
        guard let hotels = try? await hotelCatalogService.listHotels(city: city),
              let hotel = hotels.first(where: { normalizedHotelName($0.name) == targetName }),
              let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }

        let snapshot = BookingHotelSelectionSnapshot(hotel: hotel, room: nil, roomCategory: nil)
        if role == .madinah {
            sessions[index].madinahHotelSelection = snapshot
        } else {
            sessions[index].hotelSelection = snapshot
        }
    }

    private func normalizedHotelName(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func loadItinerary(for bookingID: String) async throws -> [BookingItineraryItem] {
        guard let session = booking(id: bookingID) else { throw APIError.missingBookingToken }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { throw APIError.missingBookingToken }
        let items = try await bookingService.fetchItinerary(id: bookingID, headers: headers)
        itineraries[bookingID] = items
        return items
    }

    func loadChat(for bookingID: String) async throws -> [ChatMessage] {
        guard let session = booking(id: bookingID) else { throw APIError.missingBookingToken }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { throw APIError.missingBookingToken }
        let response = try await chatService.loadChat(bookingID: bookingID, headers: headers)
        let messages = response.messages.sorted(by: { $0.createdAt < $1.createdAt })
        chats[bookingID] = messages
        _ = try? await chatService.markRead(bookingID: bookingID, headers: headers)
        return messages
    }

    func send(message: String, for bookingID: String) async throws -> ChatMessage {
        guard let session = booking(id: bookingID) else { throw APIError.missingBookingToken }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { throw APIError.missingBookingToken }
        let created = try await chatService.send(message: message, bookingID: bookingID, headers: headers)
        var current = chats[bookingID] ?? []
        current.append(created)
        chats[bookingID] = current.sorted(by: { $0.createdAt < $1.createdAt })
        return created
    }

    func sendPhoto(data: Data, for bookingID: String) async throws -> ChatMessage {
        guard let session = booking(id: bookingID) else { throw APIError.missingBookingToken }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { throw APIError.missingBookingToken }
        let created = try await chatService.sendPhoto(data: data, bookingID: bookingID, headers: headers)
        var current = chats[bookingID] ?? []
        current.append(created)
        chats[bookingID] = current.sorted(by: { $0.createdAt < $1.createdAt })
        return created
    }

    func chatAttachmentData(path: String, bookingID: String) async throws -> Data {
        guard let session = booking(id: bookingID) else { throw APIError.missingBookingToken }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { throw APIError.missingBookingToken }
        return try await chatService.loadAttachment(path: path, headers: headers)
    }

    func syncPushSubscriptions(deviceToken: String, locale: String) async {
        let token = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }

        var registeredAny = false
        var observedReady: Bool?
        var firstError: String?

        for session in sessions {
            let headers = clientHeaders(for: session)
            guard !headers.isEmpty else { continue }
            do {
                let ready = try await clientPushService.register(
                    deviceToken: token,
                    bookingID: session.id,
                    headers: headers,
                    locale: locale
                )
                registeredAny = true
                if let ready {
                    observedReady = (observedReady ?? true) && ready
                }
            } catch {
                // A stale/deleted booking must not block other trips, but registration
                // failures may explain missing chat pushes and must no longer disappear silently.
                if firstError == nil { firstError = error.localizedDescription }
            }
        }

        if registeredAny {
            pushRegistrationReady = observedReady
        }
        pushRegistrationError = firstError
    }

    func syncHotelSelectionIfNeeded(bookingID: String) async {
        guard let session = booking(id: bookingID) else { return }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { return }

        await syncHotelSelectionIfNeeded(
            bookingID: bookingID,
            role: .makkah,
            local: session.hotelSelection,
            remote: session.booking.hotelSelection,
            headers: headers
        )
        await syncHotelSelectionIfNeeded(
            bookingID: bookingID,
            role: .madinah,
            local: session.madinahHotelSelection,
            remote: session.booking.madinahHotelSelection,
            headers: headers
        )
    }

    func updateHotelSelection(
        bookingID: String,
        role: HotelSelectionRole = .makkah,
        hotel: HotelSummary,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption? = nil
    ) async throws {
        guard let session = booking(id: bookingID) else { throw APIError.missingBookingToken }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { throw APIError.missingBookingToken }
        _ = try await bookingService.updateHotelSelection(
            id: bookingID,
            headers: headers,
            role: role,
            hotel: hotel,
            room: room,
            roomCategory: roomCategory
        )
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        let snapshot = BookingHotelSelectionSnapshot(hotel: hotel, room: room, roomCategory: roomCategory)
        if role == .madinah {
            sessions[index].madinahHotelSelection = snapshot
        } else {
            sessions[index].hotelSelection = snapshot
        }
        sessions[index].pendingChangeConfirmation = true
        persist()
    }

    func updateContacts(bookingID: String, telegram: String, whatsapp: String) async throws {
        guard let session = booking(id: bookingID) else { throw APIError.missingBookingToken }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { throw APIError.missingBookingToken }
        let cleanTelegram = telegram.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWhatsApp = whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await bookingService.updateContacts(
            id: bookingID,
            headers: headers,
            telegram: cleanTelegram,
            whatsapp: cleanWhatsApp
        )

        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].telegram = cleanTelegram
        sessions[index].whatsapp = cleanWhatsApp
        sessions[index].pendingChangeConfirmation = true
        if let profile = identityProfile(remote: sessions[index].booking.pilgrimProfile, session: sessions[index]) {
            let updatedProfile = BookingPilgrimProfile(
                firstName: profile.firstName,
                lastName: profile.lastName,
                telegram: cleanTelegram,
                whatsapp: cleanWhatsApp
            )
            if !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let response = try? await bookingService.syncBookingProfile(
                id: bookingID,
                accessToken: session.accessToken,
                profile: updatedProfile
            ) {
                sessions[index].mergeOperationalTrip(response.trip)
                sessions[index].mergeOperationalStatusHistory(response.statusHistory)
                sessions[index].guide = response.assignment?.guide ?? sessions[index].guide
            }
        }
        persist()
    }

    func updateZiyarat(bookingID: String, makkah: Bool, madinah: Bool) async throws {
        guard let session = booking(id: bookingID) else { throw APIError.missingBookingToken }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { throw APIError.missingBookingToken }
        _ = try await bookingService.updateZiyarat(
            id: bookingID,
            headers: headers,
            makkah: makkah,
            madinah: madinah
        )
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].ziyaratMakkahOverride = makkah
        sessions[index].ziyaratMadinahOverride = madinah
        sessions[index].pendingChangeConfirmation = true
        persist()
    }


    func updateESIM(bookingID: String, enabled: Bool) async throws {
        guard let session = booking(id: bookingID) else { throw APIError.missingBookingToken }
        let headers = clientHeaders(for: session)
        guard !headers.isEmpty else { throw APIError.missingBookingToken }
        _ = try await bookingService.updateESIM(id: bookingID, headers: headers, enabled: enabled)
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].esimOverride = enabled
        sessions[index].pendingChangeConfirmation = true
        persist()
    }

    func requestChangeConfirmation(bookingID: String, message: String) async throws {
        _ = try await send(message: message, for: bookingID)
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].pendingChangeConfirmation = false
        persist()
    }

    private func syncHotelSelectionIfNeeded(
        bookingID: String,
        role: HotelSelectionRole,
        local: BookingHotelSelectionSnapshot?,
        remote: BookingHotelSelectionSnapshot?,
        headers: [String: String]
    ) async {
        guard let local else { return }
        let differs = remote?.hotelId != local.hotelId ||
            remote?.roomId != local.roomId ||
            remote?.roomCategory != local.roomCategory
        guard differs else { return }
        do {
            _ = try await bookingService.updateHotelSelection(
                id: bookingID,
                headers: headers,
                role: role,
                snapshot: local
            )
        } catch {
            // Keep the local selection and retry on a later booking-detail refresh.
        }
    }

    func deleteBooking(id: String) async throws {
        guard let session = booking(id: id) else {
            purgeLocalBooking(id: id)
            return
        }

        let token = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let headers = clientHeaders(for: session)
        if !headers.isEmpty {
            do {
                _ = try await bookingService.deleteBooking(id: id, headers: headers)
            } catch APIError.status(let code) where code == 404 || code == 410 {
                // Idempotent delete: if the server no longer has the booking, the local copy is stale.
            } catch APIError.server(let code, let message) where isRemoteMissing(code: code, message: message) {
                // Same as a successful delete from the client's point of view.
            } catch APIError.status(let code) where code == 405 {
                throw BookingStoreError.permanentDeleteUnavailable
            } catch APIError.server(let code, let message) where code == 405 || message.uppercased().contains("METHOD_NOT_ALLOWED") {
                throw BookingStoreError.permanentDeleteUnavailable
            } catch {
                // Some legacy delete paths completed the database mutation and then returned 500.
                // Reconcile once: if the booking is now absent remotely, finish the local delete.
                guard !token.isEmpty, await remoteBookingIsMissing(id: id, accessToken: token) else { throw error }
            }
        }

        purgeLocalBooking(id: id)
        persist()
    }


    private func clientHeaders(for session: StoredBookingSession) -> [String: String] {
        let bookingToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !bookingToken.isEmpty { return ["x-booking-token": bookingToken] }
        if let accountToken, !accountToken.isEmpty { return ["Authorization": "Bearer \(accountToken)"] }
        return [:]
    }

    private func remoteBookingIsMissing(id: String, accessToken: String) async -> Bool {
        do {
            _ = try await bookingService.fetchBooking(id: id, accessToken: accessToken)
            return false
        } catch APIError.status(let code) where code == 404 || code == 410 {
            return true
        } catch APIError.server(let code, let message) where isRemoteMissing(code: code, message: message) {
            return true
        } catch {
            return false
        }
    }
    private func purgeLocalBooking(id: String) {
        sessions.removeAll(where: { $0.id == id })
        chats[id] = nil
        itineraries[id] = nil
    }

    private func isRemoteMissing(code: Int, message: String) -> Bool {
        let normalized = message.uppercased()
        return code == 404 || code == 410 || normalized.contains("NOT_FOUND") || normalized.contains("NOT FOUND")
    }

    private func mergeRemoteHotelSelection(_ remote: BookingHotelSelectionSnapshot?, into local: inout BookingHotelSelectionSnapshot?) {
        guard let remote else { return }
        if remote.roomCategory == nil,
           remote.roomId == nil,
           let current = local,
           current.hotelId == remote.hotelId,
           current.roomCategory != nil {
            return
        }
        local = remote
    }

    private func identityProfile(remote: BookingPilgrimProfile?, session: StoredBookingSession) -> BookingPilgrimProfile? {
        if let remote,
           !remote.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !remote.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return remote
        }
        let parts = (session.travelerName ?? "")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard parts.count >= 2 else { return nil }
        return BookingPilgrimProfile(
            firstName: parts[0],
            lastName: parts.dropFirst().joined(separator: " "),
            telegram: session.telegram ?? "",
            whatsapp: session.whatsapp ?? ""
        )
    }

    private func upsert(_ session: StoredBookingSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        persist()
    }

    private func persist() {
        _ = BookingSessionVault.save(sessions)
    }

    private func loadFromStorage() {
        let secureSessions = BookingSessionVault.load()
        if !secureSessions.isEmpty {
            sessions = migrateLegacyPrimaryRooms(in: secureSessions)
            _ = BookingSessionVault.save(sessions)
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            return
        }

        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey),
              let decoded = try? JSONDecoder().decode([StoredBookingSession].self, from: data) else {
            return
        }

        sessions = migrateLegacyPrimaryRooms(in: decoded)
        if BookingSessionVault.save(sessions) {
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }
    }

    private func migrateLegacyPrimaryRooms(in values: [StoredBookingSession]) -> [StoredBookingSession] {
        values.map { value in
            var migrated = value
            if let selection = migrated.hotelSelection {
                migrated.hotelSelection = selection.migratedLegacyPrimaryRoom
            }
            return migrated
        }
    }
}
