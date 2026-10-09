import Foundation
import CoreLocation

struct ZiyaratImage: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let position: Int
    let byteSize: Int?
    let width: Int?
    let height: Int?

    var bundledAssetName: String? {
        guard url.hasPrefix("asset:") else { return nil }
        return String(url.dropFirst("asset:".count))
    }
}

struct ZiyaratPlaceTranslation: Codable, Hashable {
    let title: String
    let shortDescription: String
    let longDescription: String
    let interestingFacts: [String]
    let visitNotes: String
}

struct ZiyaratPlace: Codable, Identifiable, Hashable {
    let id: String
    let routeID: String
    let slug: String
    let city: String
    let country: String
    let title: String
    let titleArabic: String
    let category: String
    let shortDescription: String
    let longDescription: String
    let interestingFacts: [String]
    let visitNotes: String
    let visitType: String
    let durationMinutes: Int
    let latitude: Double
    let longitude: Double
    let address: String
    let mapLabel: String
    let routeOrder: Int
    let status: String
    let images: [ZiyaratImage]
    let translations: [String: ZiyaratPlaceTranslation]?

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    func localizedContent(locale: String) -> ZiyaratPlaceTranslation {
        if let exact = translations?[locale], !exact.title.isEmpty { return exact }
        if let english = translations?["en"], !english.title.isEmpty { return english }
        if let russian = translations?["ru"], !russian.title.isEmpty { return russian }
        if let uzbek = translations?["uz"], !uzbek.title.isEmpty { return uzbek }
        if let cyrillic = translations?["uz-cyrl"], !cyrillic.title.isEmpty { return cyrillic }
        return ZiyaratPlaceTranslation(
            title: title,
            shortDescription: shortDescription,
            longDescription: longDescription,
            interestingFacts: interestingFacts,
            visitNotes: visitNotes
        )
    }
}

struct ZiyaratRoute: Codable, Identifiable, Hashable {
    let id: String
    let slug: String
    let city: String
    let country: String
    let title: String
    let subtitle: String
    let transportMode: String
    let status: String
    let estimatedMinutes: Int
    let stopCount: Int
    let places: [ZiyaratPlace]
}

struct ZiyaratCatalogResponse: Codable {
    let ok: Bool
    let route: ZiyaratRoute?
}
