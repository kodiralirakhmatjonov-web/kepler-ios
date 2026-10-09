import Foundation
import CoreLocation

// Rebuilt 2026-10-09. Deliberately no persisted UserDefaults catalogue, image
// prefetch, map rendering, route calculations, or retained network tasks.
// Ziyarats always has a small, verified on-device catalogue while the server
// catalogue is being fetched; failed/invalid API data never blocks the screen.
actor ZiyaratService {
    static let shared = ZiyaratService()

    init() {
        // One-time cleanup of all legacy v1/v2/v3 persisted route catalogues.
        // No new persistent catalogue is written by this implementation.
        for key in UserDefaults.standard.dictionaryRepresentation().keys
        where key.hasPrefix("iumrah.ziyarats.catalog.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func route(city: String = "Madinah") async -> ZiyaratRoute {
        let requestedCity = ZiyaratFallbackCatalog.normalized(city)
        do {
            let response: ZiyaratCatalogResponse = try await APIClient.shared.get(
                "/api/catalog/ziyarats",
                query: [URLQueryItem(name: "city", value: requestedCity)],
                timeoutInterval: 10
            )
            guard !Task.isCancelled, response.ok, let returned = response.route else {
                return ZiyaratFallbackCatalog.route(city: requestedCity)
            }
            let clean = Self.validate(returned, city: requestedCity)
            // An empty or invalid remote route must not replace bundled places.
            if !clean.places.isEmpty { return clean }
        } catch {
            // Offline, slow network, or malformed payload: use bundled content.
        }
        return ZiyaratFallbackCatalog.route(city: requestedCity)
    }

    private static func validate(_ route: ZiyaratRoute, city: String) -> ZiyaratRoute {
        // Never show data for the wrong city; do not trust the server's city field.
        guard ZiyaratFallbackCatalog.normalized(route.city) == city else {
            return ZiyaratFallbackCatalog.route(city: city)
        }
        var seen = Set<String>()
        var places: [ZiyaratPlace] = []
        for place in route.places.prefix(120) {
            let key = place.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, key.count <= 120, !seen.contains(key),
                  validCoordinate(place.latitude, place.longitude),
                  ZiyaratFallbackCatalog.normalized(place.city) == city else { continue }
            seen.insert(key)
            // Keep only safe asset/HTTPS image references. No file:// or data:.
            let images = Array(place.images.prefix(8)).filter { photo in
                if photo.url.hasPrefix("asset:") { return photo.url.count < 100 }
                return URL(string: photo.url)?.scheme?.lowercased() == "https"
            }
            places.append(ZiyaratPlace(
                id: key, routeID: place.routeID, slug: place.slug,
                city: city, country: place.country,
                title: Self.trim(place.title, length: 180),
                titleArabic: Self.trim(place.titleArabic, length: 180),
                category: Self.trim(place.category, length: 64),
                shortDescription: Self.trim(place.shortDescription, length: 800),
                longDescription: Self.trim(place.longDescription, length: 8000),
                interestingFacts: Array(place.interestingFacts.prefix(12)).map { Self.trim($0, length: 1000) },
                visitNotes: Self.trim(place.visitNotes, length: 2000), visitType: place.visitType,
                durationMinutes: max(0, min(place.durationMinutes, 360)),
                latitude: place.latitude, longitude: place.longitude,
                address: Self.trim(place.address, length: 600),
                mapLabel: Self.trim(place.mapLabel, length: 180),
                routeOrder: place.routeOrder, status: place.status,
                images: images, translations: Self.trimTranslations(place.translations)
            ))
        }
        places.sort {
            if $0.routeOrder != $1.routeOrder { return $0.routeOrder < $1.routeOrder }
            return $0.id < $1.id
        }
        return ZiyaratRoute(
            id: route.id.isEmpty ? city : route.id,
            slug: route.slug, city: city, country: route.country,
            title: route.title, subtitle: route.subtitle,
            transportMode: route.transportMode, status: route.status,
            estimatedMinutes: max(0, min(route.estimatedMinutes, 1440)),
            stopCount: places.count, places: places
        )
    }

    private static func trim(_ value: String, length: Int) -> String {
        String(value.prefix(length))
    }

    private static func trimTranslations(
        _ translations: [String: ZiyaratPlaceTranslation]?
    ) -> [String: ZiyaratPlaceTranslation]? {
        guard let translations else { return nil }
        var result: [String: ZiyaratPlaceTranslation] = [:]
        for locale in ["ru", "en", "uz", "uz-cyrl"] {
            guard let t = translations[locale] else { continue }
            result[locale] = ZiyaratPlaceTranslation(
                title: trim(t.title, length: 180),
                shortDescription: trim(t.shortDescription, length: 800),
                longDescription: trim(t.longDescription, length: 8000),
                interestingFacts: Array(t.interestingFacts.prefix(12)).map { trim($0, length: 1000) },
                visitNotes: trim(t.visitNotes, length: 2000)
            )
        }
        return result
    }

    static func validCoordinate(_ latitude: Double, _ longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite &&
            (18...33).contains(latitude) && (34...56).contains(longitude) &&
            CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude))
    }
}

// Small offline starter catalogue, independent of network and old cache schema.
// Live published places, descriptions and photo galleries still come from API.
enum ZiyaratFallbackCatalog {
    static func normalized(_ city: String) -> String {
        switch city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "makkah", "mecca", "makka": return "Makkah"
        default: return "Madinah"
        }
    }

    static func route(city: String) -> ZiyaratRoute {
        let isMakkah = normalized(city) == "Makkah"
        let cityName = isMakkah ? "Makkah" : "Madinah"
        let sites: [Seed] = isMakkah ? [
            Seed("haram", "Masjid al-Haram", "Масджид аль-Харам", "Masjidul Harom", "Масжидул Ҳаром", 21.42252, 39.82618, "mosque", "The Grand Mosque and the sacred Kaaba.", "Заповедная мечеть и священная Кааба."),
            Seed("thawr", "Jabal Thawr", "Гора Саур", "Savr tog‘i", "Савр тоғи", 21.3771, 39.8356, "history", "Mountain associated with the Hijrah.", "Гора, связанная с историей хиджры."),
            Seed("arafat", "Arafat", "Арафат", "Arafot", "Арафот", 21.3554, 39.9841, "history", "A principal site of the Hajj pilgrimage.", "Одно из главных мест паломничества во время хаджа."),
            Seed("muzdalifah", "Muzdalifah", "Муздалифа", "Muzdalifa", "Муздалифа", 21.3842, 39.9291, "history", "The sacred area between Arafat and Mina.", "Священная местность между Арафатом и Миной."),
            Seed("mina", "Mina", "Мина", "Mino", "Мино", 21.4134, 39.8943, "history", "The valley connected with the rites of Hajj.", "Долина, связанная с обрядами хаджа."),
            Seed("jamarat", "Jamarat", "Джамарат", "Jamarot", "Жамарот", 21.4219, 39.8714, "history", "The stoning site visited during Hajj.", "Место обряда бросания камней во время хаджа.")
        ] : [
            Seed("quba", "Quba Mosque", "Мечеть Куба", "Qubo masjidi", "Қубо масжиди", 24.43917, 39.61722, "mosque", "The first mosque established in Islam.", "Первая мечеть, основанная в исламе."),
            Seed("qiblatain", "Masjid al-Qiblatayn", "Мечеть двух кибл", "Qiblatayn masjidi", "Қиблатайн масжиди", 24.4831, 39.5786, "mosque", "The mosque associated with the change of qibla.", "Мечеть, связанная с изменением направления киблы."),
            Seed("uhud", "Mount Uhud", "Гора Ухуд", "Uhud tog‘i", "Уҳуд тоғи", 24.5091, 39.6138, "history", "Historic mountain near Madinah.", "Историческая гора неподалёку от Медины."),
            Seed("baqi", "Al-Baqi Cemetery", "Кладбище аль-Баки", "Baqi qabristoni", "Бақи қабристони", 24.4679, 39.6161, "history", "Historic cemetery near the Prophet’s Mosque.", "Историческое кладбище рядом с мечетью Пророка ﷺ."),
            Seed("shajara", "Masjid Dhul Hulaifah", "Мечеть Шаджара", "Shajara masjidi", "Шажара масжиди", 24.4124, 39.5428, "mosque", "A miqat point for pilgrims departing Madinah.", "Микат для паломников, отправляющихся из Медины.")
        ]
        let places = sites.enumerated().map { index, seed in
            make(seed, city: cityName, index: index)
        }
        return ZiyaratRoute(
            id: isMakkah ? "makkah-offline" : "madinah-offline",
            slug: isMakkah ? "makkah-ziyarat" : "madinah-ziyarat",
            city: cityName, country: "Saudi Arabia",
            title: isMakkah ? "Makkah Ziyarats" : "Madinah Ziyarats",
            subtitle: "Places and history", transportMode: "car",
            status: "offline", estimatedMinutes: 0, stopCount: places.count,
            places: places
        )
    }

    private struct Seed {
        let id: String
        let english: String
        let russian: String
        let uzbek: String
        let cyrillic: String
        let latitude: Double
        let longitude: Double
        let category: String
        let englishSummary: String
        let russianSummary: String

        init(_ id: String, _ english: String, _ russian: String, _ uzbek: String,
             _ cyrillic: String, _ latitude: Double, _ longitude: Double,
             _ category: String, _ englishSummary: String, _ russianSummary: String) {
            self.id = id; self.english = english; self.russian = russian
            self.uzbek = uzbek; self.cyrillic = cyrillic
            self.latitude = latitude; self.longitude = longitude
            self.category = category; self.englishSummary = englishSummary
            self.russianSummary = russianSummary
        }
    }

    private static func make(_ site: Seed, city: String, index: Int) -> ZiyaratPlace {
        let texts: [(String, String, String)] = [
            ("en", site.english, site.englishSummary),
            ("ru", site.russian, site.russianSummary),
            ("uz", site.uzbek, site.englishSummary),
            ("uz-cyrl", site.cyrillic, site.englishSummary)
        ]
        let translations = Dictionary(uniqueKeysWithValues: texts.map { locale, title, body in
            (locale, ZiyaratPlaceTranslation(
                title: title, shortDescription: body, longDescription: body,
                interestingFacts: [], visitNotes: ""
            ))
        })
        let images: [ZiyaratImage] = site.id == "quba" ? [
            ZiyaratImage(id: "quba-offline", url: "asset:ZiyaratQuba1", position: 0,
                         byteSize: nil, width: 1254, height: 1254)
        ] : []
        return ZiyaratPlace(
            id: "offline-\(city.lowercased())-\(site.id)",
            routeID: "\(city.lowercased())-offline",
            slug: site.id, city: city, country: "Saudi Arabia",
            title: site.english, titleArabic: "", category: site.category,
            shortDescription: site.englishSummary, longDescription: site.englishSummary,
            interestingFacts: [], visitNotes: "", visitType: "outside",
            durationMinutes: 0, latitude: site.latitude, longitude: site.longitude,
            address: "", mapLabel: site.english, routeOrder: index + 1,
            status: "offline", images: images, translations: translations
        )
    }
}
