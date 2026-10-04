import Foundation
import Combine

struct FlightDiscoveryOffer: Codable, Hashable, Identifiable {
    let id: String
    let origin: String
    let destination: String
    let originAirport: String
    let destinationAirport: String
    let price: Double
    let airlineCode: String
    let flightNumber: String
    let departureAt: String
    let returnAt: String?
    let transfers: Int
    let returnTransfers: Int?
    let durationMinutes: Int
    let returnDurationMinutes: Int?
    let bookingUrl: String?

    var airlineName: String {
        FlightReferenceCatalog.airlineName(code: airlineCode, fallback: airlineCode.isEmpty ? "Airline" : airlineCode)
    }

    var routeTitle: String {
        "\(originAirport.isEmpty ? origin : originAirport) → \(destinationAirport.isEmpty ? destination : destinationAirport)"
    }
}

struct FlightDiscoveryCalendarDay: Codable, Hashable, Identifiable {
    let date: String
    let id: String
    let origin: String
    let destination: String
    let originAirport: String
    let destinationAirport: String
    let price: Double
    let airlineCode: String
    let flightNumber: String
    let departureAt: String
    let returnAt: String?
    let transfers: Int
    let returnTransfers: Int?
    let durationMinutes: Int
    let returnDurationMinutes: Int?
    let bookingUrl: String?

    var offer: FlightDiscoveryOffer {
        FlightDiscoveryOffer(
            id: id,
            origin: origin,
            destination: destination,
            originAirport: originAirport,
            destinationAirport: destinationAirport,
            price: price,
            airlineCode: airlineCode,
            flightNumber: flightNumber,
            departureAt: departureAt,
            returnAt: returnAt,
            transfers: transfers,
            returnTransfers: returnTransfers,
            durationMinutes: durationMinutes,
            returnDurationMinutes: returnDurationMinutes,
            bookingUrl: bookingUrl
        )
    }
}

private struct FlightDiscoveryOffersEnvelope: Decodable {
    let ok: Bool
    let source: String?
    let sourceFreshness: String?
    let generatedAt: String?
    let currency: String?
    let offers: [FlightDiscoveryOffer]
}

private struct FlightDiscoveryCalendarEnvelope: Decodable {
    let ok: Bool
    let source: String?
    let sourceFreshness: String?
    let generatedAt: String?
    let currency: String?
    let days: [FlightDiscoveryCalendarDay]
}

struct FlightDiscoverySnapshot: Hashable {
    let offers: [FlightDiscoveryOffer]
    let calendar: [FlightDiscoveryCalendarDay]
    let directOffers: [FlightDiscoveryOffer]
    let currency: String
    let generatedAt: String?
}

struct AviasalesFlightDiscoveryService {
    private let api = APIClient.shared

    func offers(
        origin: String,
        destination: String,
        departure: String,
        returnAt: String? = nil,
        direct: Bool = false,
        limit: Int = 50,
        currency: String = "usd",
        cacheBuster: String? = nil
    ) async throws -> (offers: [FlightDiscoveryOffer], currency: String, generatedAt: String?) {
        var query = [
            URLQueryItem(name: "view", value: direct ? "direct" : "offers"),
            URLQueryItem(name: "origin", value: origin.uppercased()),
            URLQueryItem(name: "destination", value: destination.uppercased()),
            URLQueryItem(name: "departure", value: departure),
            URLQueryItem(name: "currency", value: currency.lowercased()),
            URLQueryItem(name: "limit", value: String(max(1, min(limit, 100))))
        ]
        if let returnAt, !returnAt.isEmpty {
            query.append(URLQueryItem(name: "return", value: returnAt))
        }
        if let cacheBuster, !cacheBuster.isEmpty {
            query.append(URLQueryItem(name: "refresh", value: cacheBuster))
        }

        let response: FlightDiscoveryOffersEnvelope = try await api.get(
            "/api/package/flights/data",
            query: query,
            timeoutInterval: 15
        )
        guard response.ok else { throw APIError.invalidResponse }
        return (response.offers, response.currency ?? currency, response.generatedAt)
    }

    func refreshOffer(
        _ offer: FlightDiscoveryOffer,
        returnDate: Date?,
        currency: String = "usd"
    ) async throws -> (offer: FlightDiscoveryOffer?, currency: String, generatedAt: String?) {
        let departure = String(offer.departureAt.prefix(10))
        guard departure.count == 10 else {
            return (nil, currency, nil)
        }
        let returnAt = returnDate.map { IumrahFlightDiscoveryStore.dayFormatter.string(from: $0) }
        let result = try await offers(
            origin: offer.origin,
            destination: offer.destination,
            departure: departure,
            returnAt: returnAt,
            direct: offer.transfers == 0,
            limit: 100,
            currency: currency,
            cacheBuster: UUID().uuidString
        )

        let sameDay = result.offers.filter { String($0.departureAt.prefix(10)) == departure }
        let exactFlight = sameDay.first { candidate in
            !offer.airlineCode.isEmpty &&
            !offer.flightNumber.isEmpty &&
            candidate.airlineCode.caseInsensitiveCompare(offer.airlineCode) == .orderedSame &&
            candidate.flightNumber.caseInsensitiveCompare(offer.flightNumber) == .orderedSame
        }
        if let exactFlight {
            return (exactFlight, result.currency, result.generatedAt)
        }

        let sameAirlineAndTime = sameDay.first { candidate in
            !offer.airlineCode.isEmpty &&
            candidate.airlineCode.caseInsensitiveCompare(offer.airlineCode) == .orderedSame &&
            String(candidate.departureAt.prefix(16)) == String(offer.departureAt.prefix(16))
        }
        return (sameAirlineAndTime, result.currency, result.generatedAt)
    }

    func calendar(
        origin: String,
        destination: String,
        month: String,
        direct: Bool = false,
        currency: String = "usd"
    ) async throws -> (days: [FlightDiscoveryCalendarDay], currency: String, generatedAt: String?) {
        let response: FlightDiscoveryCalendarEnvelope = try await api.get(
            "/api/package/flights/data",
            query: [
                URLQueryItem(name: "view", value: "calendar"),
                URLQueryItem(name: "origin", value: origin.uppercased()),
                URLQueryItem(name: "destination", value: destination.uppercased()),
                URLQueryItem(name: "departure", value: month),
                URLQueryItem(name: "currency", value: currency.lowercased()),
                URLQueryItem(name: "direct", value: direct ? "true" : "false")
            ],
            timeoutInterval: 15
        )
        guard response.ok else { throw APIError.invalidResponse }
        return (response.days, response.currency ?? currency, response.generatedAt)
    }
}

@MainActor
final class IumrahFlightDiscoveryStore: ObservableObject {
    @Published private(set) var offers: [FlightDiscoveryOffer] = []
    @Published private(set) var calendarDays: [FlightDiscoveryCalendarDay] = []
    @Published private(set) var directOffers: [FlightDiscoveryOffer] = []
    @Published private(set) var currency: String = "usd"
    @Published private(set) var generatedAt: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingDirect = false
    @Published private(set) var errorMessage: String?

    private let service = AviasalesFlightDiscoveryService()
    private var refreshTask: Task<Void, Never>?
    private var directTask: Task<Void, Never>?

    deinit {
        refreshTask?.cancel()
        directTask?.cancel()
    }

    func refresh(
        origin: String,
        destination: String,
        departureDate: Date,
        returnDate: Date?,
        directOnly: Bool
    ) {
        refreshTask?.cancel()
        let origin = origin.uppercased()
        let destination = destination.uppercased()
        guard origin.count == 3, destination.count == 3, origin != destination else {
            offers = []
            calendarDays = []
            errorMessage = nil
            return
        }

        let month = Self.monthFormatter.string(from: departureDate)
        let departure = Self.dayFormatter.string(from: departureDate)
        let returnAt = returnDate.map { Self.dayFormatter.string(from: $0) }

        isLoading = true
        errorMessage = nil

        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let calendar = try await service.calendar(
                    origin: origin,
                    destination: destination,
                    month: month,
                    direct: directOnly
                )
                guard !Task.isCancelled else { return }
                self.calendarDays = calendar.days
                self.currency = calendar.currency
                self.generatedAt = calendar.generatedAt

                var collected: [FlightDiscoveryOffer] = []

                // 1) Ask for the exact travel day. This is the most relevant cache slice.
                if let exact = try? await service.offers(
                    origin: origin,
                    destination: destination,
                    departure: departure,
                    returnAt: returnAt,
                    direct: directOnly,
                    limit: 100
                ) {
                    collected.append(contentsOf: exact.offers)
                    self.currency = exact.currency
                    self.generatedAt = exact.generatedAt ?? calendar.generatedAt
                }

                guard !Task.isCancelled else { return }

                // 2) prices_for_dates can contain several cached fares for the month even
                // when the exact-day request returns only one row. Merge matching rows so
                // the client receives a real ticket list rather than only a price insight.
                if collected.count < 6,
                   let monthly = try? await service.offers(
                    origin: origin,
                    destination: destination,
                    departure: month,
                    returnAt: returnAt,
                    direct: directOnly,
                    limit: 100
                   ) {
                    let matching = monthly.offers.filter {
                        String($0.departureAt.prefix(10)) == departure
                    }
                    collected.append(contentsOf: matching)
                    self.currency = monthly.currency
                    self.generatedAt = monthly.generatedAt ?? self.generatedAt
                }

                guard !Task.isCancelled else { return }

                // 3) grouped_prices always gives us the cheapest cached row for a day when
                // one exists. Use it as a final selected-day fallback so the UI never hides
                // a fare that is already visible in the calendar/price graph.
                if let fallback = calendar.days.first(where: { $0.date == departure })?.offer {
                    collected.append(fallback)
                }

                var seen = Set<String>()
                self.offers = collected
                    .filter { $0.price > 0 && !$0.departureAt.isEmpty }
                    .filter { offer in
                        let signature = [
                            offer.originAirport,
                            offer.destinationAirport,
                            offer.airlineCode,
                            offer.flightNumber,
                            offer.departureAt,
                            String(Int(offer.price.rounded()))
                        ].joined(separator: "|")
                        return seen.insert(signature).inserted
                    }
                    .sorted { lhs, rhs in
                        if lhs.price != rhs.price { return lhs.price < rhs.price }
                        return lhs.departureAt < rhs.departureAt
                    }

                self.errorMessage = nil
                self.isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                self.calendarDays = []
                self.offers = []
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func loadDirectFlights(origin: String, destination: String, monthDate: Date) {
        directTask?.cancel()
        let origin = origin.uppercased()
        let destination = destination.uppercased()
        guard origin.count == 3, destination.count == 3, origin != destination else {
            directOffers = []
            return
        }

        isLoadingDirect = true
        let month = Self.monthFormatter.string(from: monthDate)
        directTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.offers(
                    origin: origin,
                    destination: destination,
                    departure: month,
                    direct: true,
                    limit: 100
                )
                guard !Task.isCancelled else { return }
                self.directOffers = result.offers
                self.isLoadingDirect = false
            } catch {
                guard !Task.isCancelled else { return }
                self.directOffers = []
                self.isLoadingDirect = false
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}
