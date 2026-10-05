import Foundation
import MapKit

actor ZiyaratService {
    static let shared = ZiyaratService()

    private let cachePrefix = "iumrah.ziyarats.catalog.v1."

    func route(city: String = "Madinah") async -> ZiyaratRoute {
        do {
            let response: ZiyaratCatalogResponse = try await APIClient.shared.get(
                "/api/catalog/ziyarats",
                query: [URLQueryItem(name: "city", value: city)]
            )
            if let route = response.route {
                let sanitized = sanitizedRoute(route)
                if !sanitized.places.isEmpty {
                    cache(sanitized, city: city)
                    return sanitized
                }
            }
        } catch {
            // A short network interruption should not collapse a previously loaded
            // multi-stop journey back to the bundled seed route.
        }

        if let cached = cachedRoute(city: city) {
            let sanitized = sanitizedRoute(cached)
            if !sanitized.places.isEmpty { return sanitized }
        }
        return ZiyaratSeedData.fallback(city: city)
    }

    private func cache(_ route: ZiyaratRoute, city: String) {
        guard let data = try? JSONEncoder().encode(route) else { return }
        UserDefaults.standard.set(data, forKey: cachePrefix + city.lowercased())
    }

    private func cachedRoute(city: String) -> ZiyaratRoute? {
        guard let data = UserDefaults.standard.data(forKey: cachePrefix + city.lowercased()) else { return nil }
        return try? JSONDecoder().decode(ZiyaratRoute.self, from: data)
    }

    /// MapKit is not tolerant of NaN / infinite or out-of-range coordinates.
    /// Sanitize at the service boundary so every consumer (map pins, routing,
    /// camera fitting and Apple Maps handoff) sees the same safe catalogue.
    private func sanitizedRoute(_ route: ZiyaratRoute) -> ZiyaratRoute {
        let places = route.places
            .filter(Self.hasUsableCoordinate)
            .sorted { lhs, rhs in
                if lhs.routeOrder != rhs.routeOrder { return lhs.routeOrder < rhs.routeOrder }
                return lhs.id < rhs.id
            }

        return ZiyaratRoute(
            id: route.id,
            slug: route.slug,
            city: route.city,
            country: route.country,
            title: route.title,
            subtitle: route.subtitle,
            transportMode: route.transportMode,
            status: route.status,
            estimatedMinutes: route.estimatedMinutes,
            stopCount: places.count,
            places: places
        )
    }

    private static func hasUsableCoordinate(_ place: ZiyaratPlace) -> Bool {
        let coordinate = place.coordinate
        return place.latitude.isFinite &&
            place.longitude.isFinite &&
            CLLocationCoordinate2DIsValid(coordinate) &&
            (-90.0...90.0).contains(place.latitude) &&
            (-180.0...180.0).contains(place.longitude)
    }
}

actor ZiyaratRouteService {
    static let shared = ZiyaratRouteService()

    func roadPolylines(for places: [ZiyaratPlace]) async -> [MKPolyline] {
        let ordered = places
            .filter(Self.hasUsableCoordinate)
            .sorted { lhs, rhs in
                if lhs.routeOrder != rhs.routeOrder { return lhs.routeOrder < rhs.routeOrder }
                return lhs.id < rhs.id
            }
        guard ordered.count > 1 else { return [] }

        var result: [MKPolyline] = []
        for pair in zip(ordered, ordered.dropFirst()) {
            guard !Task.isCancelled else { return result }

            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: pair.0.coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: pair.1.coordinate))
            request.transportType = .automobile
            request.requestsAlternateRoutes = false

            if let response = try? await MKDirections(request: request).calculate(),
               let route = response.routes.first {
                result.append(route.polyline)
            } else {
                // Keep the journey usable when Apple routing is temporarily unavailable.
                var coordinates = [pair.0.coordinate, pair.1.coordinate]
                result.append(MKPolyline(coordinates: &coordinates, count: coordinates.count))
            }
        }
        return result
    }

    private static func hasUsableCoordinate(_ place: ZiyaratPlace) -> Bool {
        let coordinate = place.coordinate
        return place.latitude.isFinite &&
            place.longitude.isFinite &&
            CLLocationCoordinate2DIsValid(coordinate) &&
            (-90.0...90.0).contains(place.latitude) &&
            (-180.0...180.0).contains(place.longitude)
    }
}
