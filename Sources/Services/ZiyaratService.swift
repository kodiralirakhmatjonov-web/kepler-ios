import Foundation
import MapKit

actor ZiyaratService {
    static let shared = ZiyaratService()

    // V1 stored the entire Ziyarats catalogue in UserDefaults indefinitely.
    // Old payloads must never be loaded after an app update: keep small, expiring,
    // validated snapshots in the OS Caches directory instead.
    private let legacyCachePrefix = "iumrah.ziyarats.catalog.v1."
    private let cacheDirectoryName = "iumrah.ziyarats.catalog.v2"
    private let maximumCacheBytes = 2 * 1024 * 1024
    private let maximumCacheAge: TimeInterval = 7 * 24 * 60 * 60
    private var legacyCacheWasCleared = false

    func route(city: String = "Madinah") async -> ZiyaratRoute {
        invalidateLegacyCacheIfNeeded()

        do {
            let response: ZiyaratCatalogResponse = try await APIClient.shared.get(
                "/api/catalog/ziyarats",
                query: [URLQueryItem(name: "city", value: city)]
            )
            if response.ok, let route = response.route {
                let sanitized = sanitizedRoute(route)
                if !sanitized.places.isEmpty {
                    saveCachedRoute(sanitized, city: city)
                    return sanitized
                }
            }
        } catch {
            // Network outages and invalid server payloads must not prevent access
            // to the locally bundled tour catalogue.
        }

        if let cached = readCachedRoute(city: city) {
            let sanitized = sanitizedRoute(cached)
            if !sanitized.places.isEmpty { return sanitized }
            invalidateCachedRoute(city: city)
        }
        return sanitizedRoute(ZiyaratSeedData.fallback(city: city))
    }

    private func invalidateLegacyCacheIfNeeded() {
        guard !legacyCacheWasCleared else { return }
        legacyCacheWasCleared = true
        let defaults = UserDefaults.standard
        // Only delete Ziyarats catalogue keys; never touch hotel, booking,
        // account, login or other unrelated application data.
        defaults.removeObject(forKey: legacyCachePrefix + "madinah")
        defaults.removeObject(forKey: legacyCachePrefix + "makkah")
    }

    private func cacheFileURL(city: String) -> URL? {
        let key: String
        switch city.lowercased() {
        case "madinah", "medina": key = "madinah"
        case "makkah", "mecca": key = "makkah"
        default: return nil
        }
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return directory
            .appendingPathComponent(cacheDirectoryName, isDirectory: true)
            .appendingPathComponent(key + ".json", isDirectory: false)
    }

    private func saveCachedRoute(_ route: ZiyaratRoute, city: String) {
        guard let url = cacheFileURL(city: city),
              let data = try? JSONEncoder().encode(route),
              data.count <= maximumCacheBytes else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            // Caching is opportunistic and cannot block the screen.
        }
    }

    private func readCachedRoute(city: String) -> ZiyaratRoute? {
        guard let url = cacheFileURL(city: city) else { return nil }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? NSNumber,
                  size.intValue > 0,
                  size.intValue <= maximumCacheBytes,
                  let modified = attributes[.modificationDate] as? Date,
                  Date().timeIntervalSince(modified) < maximumCacheAge,
                  Date().timeIntervalSince(modified) >= -300 else {
                invalidateCachedRoute(city: city)
                return nil
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard let decoded = try? JSONDecoder().decode(ZiyaratRoute.self, from: data) else {
                invalidateCachedRoute(city: city)
                return nil
            }
            return decoded
        } catch {
            return nil
        }
    }

    private func invalidateCachedRoute(city: String) {
        guard let url = cacheFileURL(city: city) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// MapKit requires valid, finite coordinates and unique annotation IDs.
    private func sanitizedRoute(_ route: ZiyaratRoute) -> ZiyaratRoute {
        var seen = Set<String>()
        let places = Array(route.places
            .filter { Self.hasUsableCoordinate($0) && seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.routeOrder != rhs.routeOrder { return lhs.routeOrder < rhs.routeOrder }
                return lhs.id < rhs.id
            }
            .prefix(60))

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
            guard !Task.isCancelled else { return [] }

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
