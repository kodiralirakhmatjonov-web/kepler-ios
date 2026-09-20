import Foundation

private struct StorefrontFareCalendarEnvelope: Decodable {
    let ok: Bool
    let observations: [FlightFareCalendarEntry]
    let suggestions: [FlightFareCalendarEntry]
}

private struct ServerStorefrontQuoteRequest: Encodable {
    struct Flight: Encodable {
        let outboundOfferId: String
        let inboundOfferId: String
        let outboundOrigin: String
        let outboundDestination: String
        let outboundDate: String
        let inboundOrigin: String
        let inboundDestination: String
        let inboundDate: String
    }
    let tier: String
    let travelers: Int
    let rooms: Int
    let hotelId: String
    let hotelNights: Int
    let flight: Flight
}

private struct ServerStorefrontQuoteEnvelope: Decodable {
    struct Quote: Decodable {
        let totalPackagePrice: Decimal
        let pricePerPerson: Decimal
        let currency: String
        let isEstimated: Bool
        let quoteId: String
    }
    let ok: Bool
    let quote: Quote
}


struct StorefrontServerPackageSnapshot: Codable, Hashable, Identifiable {
    struct Leg: Codable, Hashable {
        let airline: String
        let airlineCode: String
        let flightNumber: String
        let origin: String
        let destination: String
        let departureAt: String
        let arrivalAt: String
        let durationMinutes: Int
        let stops: Int
        let cabinClass: String

        var clientLeg: StorefrontFlightLeg {
            StorefrontFlightLeg(
                airline: airline,
                flightNumber: flightNumber,
                airlineCode: airlineCode,
                origin: origin,
                destination: destination,
                departureAt: departureAt,
                arrivalAt: arrivalAt,
                durationMinutes: durationMinutes,
                stops: stops,
                cabinClass: cabinClass
            )
        }
    }

    let id: String
    let entryMode: String
    let status: String
    let originCode: String
    let originCity: String
    let destinationCode: String
    let tier: PackageTier
    let kind: String
    let startDate: String
    let endDate: String
    let totalDays: Int
    let totalNights: Int
    let makkahNights: Int?
    let madinahNights: Int?
    let hotelFirstVariant: String?
    let hotelFirstVariantIndex: Int?
    let hotelFirstVariantMinDays: Int?
    let hotelFirstVariantMaxDays: Int?
    let hotelFirstAnchorCity: String?
    let hotelFirstAnchorHotelId: String?
    let outbound: Leg
    let inbound: Leg
    let providerItineraryId: String
    let outboundOfferId: String
    let inboundOfferId: String
    let imageUrl: String
    let hotelImages: [String]
    let hotelName: String
    let hotelSecondaryName: String?
    let hotelCity: String?
    let hotelStars: Int?
    let makkahHotelId: String?
    let madinahHotelId: String?
    let routeSummary: String
    let pricePerPerson: Decimal?
    let totalPackagePrice: Decimal?
    let currency: String
    let isEstimated: Bool
    let configuration: StorefrontPackageSnapshotConfiguration?
}

private struct StorefrontServerPackagesEnvelope: Decodable {
    let ok: Bool
    let cacheState: String?
    let generatedAt: String?
    let expiresAt: String?
    let items: [StorefrontServerPackageSnapshot]
}

private struct StorefrontServerPackageEnvelope: Decodable {
    let ok: Bool
    let package: StorefrontServerPackageSnapshot
    let generatedAt: String?
    let expiresAt: String?
    let expired: Bool?
}

private struct StorefrontCreateSnapshotRequest: Encodable {
    let package: StorefrontServerPackageSnapshot
    let parentPackageId: String?
}

struct HotelStorefrontService {
    private let api = APIClient.shared

    func serverPackages(mode: String, origin: String) async throws -> [StorefrontServerPackageSnapshot] {
        let response: StorefrontServerPackagesEnvelope = try await api.get(
            "/api/storefront/packages",
            query: [
                URLQueryItem(name: "mode", value: mode),
                URLQueryItem(name: "origins", value: origin.uppercased()),
                URLQueryItem(name: "limit", value: mode == "hotel-first" ? "300" : "500")
            ],
            timeoutInterval: 25
        )
        guard response.ok else { throw APIError.invalidResponse }
        return response.items
    }

    func packageSnapshot(id: String) async throws -> StorefrontServerPackageSnapshot {
        let response: StorefrontServerPackageEnvelope = try await api.get(
            "/api/storefront/packages/\(id)",
            timeoutInterval: 15
        )
        guard response.ok else { throw APIError.invalidResponse }
        return response.package
    }

    func createPackageSnapshot(
        _ package: StorefrontServerPackageSnapshot,
        parentPackageID: String?
    ) async throws -> StorefrontServerPackageSnapshot {
        let response: StorefrontServerPackageEnvelope = try await api.post(
            "/api/storefront/packages/snapshot",
            body: StorefrontCreateSnapshotRequest(package: package, parentPackageId: parentPackageID),
            timeoutInterval: 15
        )
        guard response.ok else { throw APIError.invalidResponse }
        return response.package
    }

    func flightBoard(origin: String = "TAS") async throws -> StorefrontFlightBoardResponse {
        try await api.get(
            "/api/package/storefront/flights",
            query: [URLQueryItem(name: "origin", value: origin)],
            timeoutInterval: 10
        )
    }

    /// Hotel storefront pricing must not depend on a newly deployed endpoint being
    /// perfect. Prefer the staff-published storefront board, then fall back to the
    /// already-existing fare calendar for the two exact one-way legs used by this
    /// undated preview: TAS → MED and JED → TAS. No Ignav search is started here.
    func resilientFlightBoard(origin: String = "TAS") async throws -> StorefrontFlightBoardResponse {
        var primaryBoard: StorefrontFlightBoardResponse?
        do {
            let board = try await flightBoard(origin: origin)
            primaryBoard = board
            if board.baseline != nil { return board }
        } catch {
            // The calendar fallback below keeps package cards usable even when an
            // older Package Engine deployment does not yet expose /storefront/flights.
        }

        if let fallback = try await calendarBaseline(origin: origin) {
            return StorefrontFlightBoardResponse(
                ok: true,
                origin: origin,
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                baseline: fallback,
                options: primaryBoard?.options ?? []
            )
        }

        if let primaryBoard { return primaryBoard }
        throw URLError(.resourceUnavailable)
    }

    func quote(
        hotel: HotelSummary,
        tier: PackageTier,
        baseline: StorefrontFlightBaseline,
        price overridePrice: HotelCatalogPrice? = nil
    ) async throws -> HotelStorefrontQuote {
        guard baseline.currency.uppercased() == "USD" else {
            throw LocalPricingError.invalidFlightFare
        }
        // Night count is public itinerary geometry only. Hotel and flight supplier
        // prices are resolved again by PackageEngine from D1; the client never
        // participates in package arithmetic.
        let nights = max(1, packageNights(from: baseline) ?? overridePrice?.nights ?? hotel.price?.nights ?? fallbackNights(for: hotel.city))
        let rooms = max(1, overridePrice?.rooms ?? hotel.price?.rooms ?? 1)
        let travelers = 2
        let request = ServerStorefrontQuoteRequest(
            tier: tier.rawValue,
            travelers: travelers,
            rooms: rooms,
            hotelId: hotel.id,
            hotelNights: nights,
            flight: .init(
                outboundOfferId: baseline.outboundOfferID,
                inboundOfferId: baseline.inboundOfferID,
                outboundOrigin: baseline.outbound.origin,
                outboundDestination: baseline.outbound.destination,
                outboundDate: String(baseline.outbound.departureAt.prefix(10)),
                inboundOrigin: baseline.inbound.origin,
                inboundDestination: baseline.inbound.destination,
                inboundDate: String(baseline.inbound.departureAt.prefix(10))
            )
        )
        let response: ServerStorefrontQuoteEnvelope = try await api.post(
            "/api/package/storefront/quote",
            body: request,
            timeoutInterval: 12
        )
        guard response.ok else { throw APIError.invalidResponse }
        let packageQuote = PackageQuote(
            totalPackagePrice: response.quote.totalPackagePrice,
            pricePerPerson: response.quote.pricePerPerson,
            currency: response.quote.currency,
            isEstimated: response.quote.isEstimated,
            quoteId: response.quote.quoteId,
            quoteProof: nil
        )
        return HotelStorefrontQuote(
            tier: tier,
            packageQuote: packageQuote,
            hotelNightlyUsd: 0,
            hotelNights: nights,
            rooms: rooms,
            travelers: travelers,
            flightFarePerTravelerUsd: 0
        )
    }

    static func publicHotelToken(_ hotelID: String) -> String {
        Data(hotelID.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decodePublicHotelToken(_ token: String) -> String? {
        var value = token
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = value.count % 4
        if remainder != 0 { value += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: value),
              let decoded = String(data: data, encoding: .utf8),
              !decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return decoded
    }

    private func calendarBaseline(origin: String) async throws -> StorefrontFlightBaseline? {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 30, to: start) ?? start

        async let outboundRequest = calendarLeg(origin: origin, destination: "MED", from: start, to: end)
        async let inboundRequest = calendarLeg(origin: "JED", destination: origin, from: start, to: end)
        let (outboundRows, directInboundRows) = try await (outboundRequest, inboundRequest)

        guard let outbound = bestUSD(outboundRows) else { return nil }

        var returnDestination = origin
        var inbound = bestCompatibleReturn(directInboundRows, after: outbound.outboundDate)
        if inbound == nil, origin.uppercased() != "TAS" {
            let fallbackRows = try await calendarLeg(origin: "JED", destination: "TAS", from: start, to: end)
            inbound = bestCompatibleReturn(fallbackRows, after: outbound.outboundDate)
            returnDestination = "TAS"
        }

        guard let inbound else { return nil }
        let fare = outbound.minPerTravelerFare + inbound.minPerTravelerFare
        guard fare.isFinite, fare > 0 else { return nil }

        let outboundLeg = syntheticLeg(
            origin: origin,
            destination: "MED",
            date: outbound.outboundDate,
            label: "Published flight"
        )
        let inboundLeg = syntheticLeg(
            origin: "JED",
            destination: returnDestination,
            date: inbound.outboundDate,
            label: "Published flight"
        )
        return StorefrontFlightBaseline(
            mode: "calendar_published_pair_fallback",
            travelers: 2,
            currency: "USD",
            perTravelerFareUsd: fare,
            totalFareUsd: fare * 2,
            outboundOfferID: outbound.id,
            inboundOfferID: inbound.id,
            outbound: outboundLeg,
            inbound: inboundLeg,
            observedAt: max(outbound.observedAt, inbound.observedAt)
        )
    }

    private func calendarLeg(origin: String, destination: String, from: Date, to: Date) async throws -> [FlightFareCalendarEntry] {
        let response: StorefrontFareCalendarEnvelope = try await api.get(
            "/api/package/flights/calendar",
            query: [
                URLQueryItem(name: "outbound_origin", value: origin),
                URLQueryItem(name: "outbound_destination", value: destination),
                URLQueryItem(name: "adults", value: "2"),
                URLQueryItem(name: "children", value: "0"),
                URLQueryItem(name: "infants_in_seat", value: "0"),
                URLQueryItem(name: "infants_on_lap", value: "0"),
                URLQueryItem(name: "cabin_class", value: "economy"),
                URLQueryItem(name: "from", value: Self.day.string(from: from)),
                URLQueryItem(name: "to", value: Self.day.string(from: to)),
            ],
            timeoutInterval: 10
        )
        guard response.ok else { return [] }
        return response.observations.isEmpty ? response.suggestions : response.observations
    }

    private func bestCompatibleReturn(_ rows: [FlightFareCalendarEntry], after outboundDay: String) -> FlightFareCalendarEntry? {
        guard let departure = Self.day.date(from: outboundDay) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        return rows
            .filter { row in
                guard row.currency.uppercased() == "USD",
                      row.minPerTravelerFare.isFinite,
                      row.minPerTravelerFare > 0,
                      let date = Self.day.date(from: row.outboundDate),
                      let gap = calendar.dateComponents([.day], from: departure, to: date).day else { return false }
                return (4...15).contains(gap)
            }
            .min { lhs, rhs in
                let lhsDate = Self.day.date(from: lhs.outboundDate) ?? .distantFuture
                let rhsDate = Self.day.date(from: rhs.outboundDate) ?? .distantFuture
                let lhsGap = calendar.dateComponents([.day], from: departure, to: lhsDate).day ?? 99
                let rhsGap = calendar.dateComponents([.day], from: departure, to: rhsDate).day ?? 99
                let lhsDistance = abs(lhsGap - 7)
                let rhsDistance = abs(rhsGap - 7)
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                if lhsDate != rhsDate { return lhsDate < rhsDate }
                return lhs.minPerTravelerFare < rhs.minPerTravelerFare
            }
    }

    private func bestUSD(_ rows: [FlightFareCalendarEntry]) -> FlightFareCalendarEntry? {
        rows
            .filter { $0.currency.uppercased() == "USD" && $0.minPerTravelerFare.isFinite && $0.minPerTravelerFare > 0 }
            .min { lhs, rhs in
                if lhs.minPerTravelerFare != rhs.minPerTravelerFare {
                    return lhs.minPerTravelerFare < rhs.minPerTravelerFare
                }
                return lhs.outboundDate < rhs.outboundDate
            }
    }

    private func syntheticLeg(origin: String, destination: String, date: String, label: String) -> StorefrontFlightLeg {
        StorefrontFlightLeg(
            airline: label,
            flightNumber: "",
            airlineCode: "",
            origin: origin,
            destination: destination,
            departureAt: "\(date)T00:00:00Z",
            arrivalAt: "\(date)T00:00:00Z",
            durationMinutes: 0,
            stops: 0,
            cabinClass: "economy"
        )
    }

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func packageNights(from baseline: StorefrontFlightBaseline) -> Int? {
        guard let arrivalDay = travelDay(baseline.outbound.arrivalAt),
              let returnDay = travelDay(baseline.inbound.departureAt),
              returnDay > arrivalDay else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let days = calendar.dateComponents([.day], from: arrivalDay, to: returnDay).day, days > 0 else { return nil }
        return min(15, max(1, days))
    }

    private func travelDay(_ value: String) -> Date? {
        let day = String(value.prefix(10))
        guard day.count == 10 else { return nil }
        return Self.day.date(from: day)
    }

    private func fallbackNights(for city: String) -> Int {
        city.lowercased().contains("mad") ? 2 : 5
    }
}
