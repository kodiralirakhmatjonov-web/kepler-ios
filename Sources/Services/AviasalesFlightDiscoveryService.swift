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
        currency: String = "usd"
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

        let response: FlightDiscoveryOffersEnvelope = try await api.get(
            "/api/package/flights/data",
            query: query,
            timeoutInterval: 15
        )
        guard response.ok else { throw APIError.invalidResponse }
        return (response.offers, response.currency ?? currency, response.generatedAt)
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

                do {
                    let offers = try await service.offers(
                        origin: origin,
                        destination: destination,
                        departure: departure,
                        returnAt: returnAt,
                        direct: directOnly,
                        limit: 50
                    )
                    guard !Task.isCancelled else { return }
                    self.offers = offers.offers
                    self.currency = offers.currency
                    self.generatedAt = offers.generatedAt ?? calendar.generatedAt
                } catch {
                    guard !Task.isCancelled else { return }
                    // The Data API is a recent-search cache. An exact travel day can
                    // legitimately have no row even while the monthly calendar has data.
                    self.offers = []
                    self.errorMessage = nil
                }
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
