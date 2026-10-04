import Foundation
import Combine
import UserNotifications

struct FlightFavoriteRecord: Codable, Hashable, Identifiable {
    let id: String
    var offer: FlightDiscoveryOffer
    var currency: String
    var lastKnownPrice: Double
    var addedAt: Date

    var monitorKey: String { offer.monitorKey }
}

final class FlightFavoritesStore: ObservableObject {
    static let shared = FlightFavoritesStore()

    @Published private(set) var records: [FlightFavoriteRecord] = []

    private let defaultsKey = "iumrah.flight-favorites.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        load()
    }

    func isFavorite(_ offer: FlightDiscoveryOffer) -> Bool {
        records.contains { $0.monitorKey == offer.monitorKey }
    }

    func toggle(_ offer: FlightDiscoveryOffer, currency: String, language: AppSettingsStore.Language) {
        if let index = records.firstIndex(where: { $0.monitorKey == offer.monitorKey }) {
            records.remove(at: index)
            save()
            return
        }

        records.insert(
            FlightFavoriteRecord(
                id: UUID().uuidString,
                offer: offer,
                currency: currency,
                lastKnownPrice: offer.price,
                addedAt: Date()
            ),
            at: 0
        )
        save()
        requestNotificationsIfNeeded()
    }

    func remove(_ record: FlightFavoriteRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func refreshAllFavorites(language: AppSettingsStore.Language) async {
        guard !records.isEmpty else { return }
        let service = AviasalesFlightDiscoveryService()

        for record in records.prefix(16) {
            let offer = record.offer
            let departure = String(offer.departureAt.prefix(10))
            let returnAt = offer.returnAt.map { String($0.prefix(10)) }

            guard let result = try? await service.offers(
                origin: offer.origin,
                destination: offer.destination,
                departure: departure,
                returnAt: returnAt,
                direct: offer.isDirect,
                limit: 100,
                currency: record.currency
            ) else { continue }

            reconcile(offers: result.offers, currency: result.currency, language: language)
        }
    }

    func reconcile(offers: [FlightDiscoveryOffer], currency: String, language: AppSettingsStore.Language) {
        guard !records.isEmpty, !offers.isEmpty else { return }
        var changed = false

        for index in records.indices {
            guard let fresh = offers.first(where: { $0.monitorKey == records[index].monitorKey }) else { continue }
            let oldPrice = records[index].lastKnownPrice
            let newPrice = fresh.price
            records[index].offer = fresh
            records[index].currency = currency

            if oldPrice > 0, newPrice > 0, abs(newPrice - oldPrice) >= 1 {
                records[index].lastKnownPrice = newPrice
                schedulePriceNotification(
                    offer: fresh,
                    currency: currency,
                    oldPrice: oldPrice,
                    newPrice: newPrice,
                    language: language
                )
                changed = true
            } else if records[index].lastKnownPrice != newPrice {
                records[index].lastKnownPrice = newPrice
                changed = true
            }
        }

        if changed { save() }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? decoder.decode([FlightFavoriteRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded
    }

    private func save() {
        guard let data = try? encoder.encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func requestNotificationsIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func schedulePriceNotification(
        offer: FlightDiscoveryOffer,
        currency: String,
        oldPrice: Double,
        newPrice: Double,
        language: AppSettingsStore.Language
    ) {
        let content = UNMutableNotificationContent()
        content.sound = .default

        let route = "\(offer.originAirport.isEmpty ? offer.origin : offer.originAirport) → \(offer.destinationAirport.isEmpty ? offer.destination : offer.destinationAirport)"
        let old = money(oldPrice, currency: currency)
        let new = money(newPrice, currency: currency)

        switch language {
        case .russian:
            content.title = newPrice < oldPrice ? "Авиабилет подешевел" : "Цена авиабилета изменилась"
            content.body = "\(route): \(old) → \(new). Откройте iumrah, чтобы проверить актуальный тариф."
        case .english:
            content.title = newPrice < oldPrice ? "Flight price dropped" : "Flight price changed"
            content.body = "\(route): \(old) → \(new). Open iumrah to check the current fare."
        case .uzbek:
            content.title = newPrice < oldPrice ? "Aviachipta arzonlashdi" : "Aviachipta narxi o‘zgardi"
            content.body = "\(route): \(old) → \(new). Joriy tarifni tekshirish uchun iumrah’ni oching."
        case .uzbekCyrillic:
            content.title = newPrice < oldPrice ? "Авиачипта арзонлашди" : "Авиачипта нархи ўзгарди"
            content.body = "\(route): \(old) → \(new). Жорий тарифни текшириш учун iumrah’ни очинг."
        }

        content.userInfo = [
            "type": "flight_price_change",
            "flight_monitor_key": offer.monitorKey
        ]

        let request = UNNotificationRequest(
            identifier: "flight-price-\(offer.monitorKey)-\(Int(newPrice.rounded()))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func money(_ value: Double, currency: String) -> String {
        currency.lowercased() == "usd"
            ? "$\(Int(value.rounded()))"
            : "\(currency.uppercased()) \(Int(value.rounded()))"
    }
}
