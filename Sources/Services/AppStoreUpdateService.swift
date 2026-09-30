import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct AppStoreUpdateInfo: Identifiable, Equatable, Sendable {
    var id: String { storeVersion }
    let currentVersion: String
    let storeVersion: String
    let storeURL: URL
}

/// No work runs during initialization. The caller starts this only after launch.
enum AppStoreUpdateChecker {
    static func fetchAvailableUpdate(countryCode: String) async throws -> AppStoreUpdateInfo? {
        let currentVersion = AppIdentity.marketingVersion
        guard currentVersion != "0.0.0", AppStoreVersion(currentVersion) != nil,
              let url = lookupURL(countryCode: countryCode) else { return nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 10
        #if !os(Linux)
        configuration.waitsForConnectivity = false
        #endif
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        try Task.checkCancellation()
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try availableUpdate(from: data, currentVersion: currentVersion)
    }

    static func lookupURL(countryCode: String) -> URL? {
        // Apple expects alpha-2, not StoreKit's alpha-3 country code.
        let country = countryCode.lowercased()
        guard country.utf8.count == 2,
              country.utf8.allSatisfy({ (97...122).contains($0) }) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/lookup"
        components.queryItems = [
            URLQueryItem(name: "id", value: AppIdentity.appStoreID),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "entity", value: "software")
        ]
        return components.url
    }

    static func availableUpdate(
        from data: Data,
        currentVersion: String,
        operatingSystemVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) throws -> AppStoreUpdateInfo? {
        let payload = try JSONDecoder().decode(LookupResponse.self, from: data)
        guard let installed = AppStoreVersion(currentVersion),
              let item = payload.results.first(where: {
                  String($0.trackId) == AppIdentity.appStoreID
                      && $0.bundleId == AppIdentity.productionBundleID
                      && $0.wrapperType == "software"
              }),
              let published = AppStoreVersion(item.version), published > installed
        else { return nil }

        if let minimum = item.minimumOsVersion {
            let system = "\(operatingSystemVersion.majorVersion).\(operatingSystemVersion.minorVersion).\(operatingSystemVersion.patchVersion)"
            guard let requiredOS = AppStoreVersion(minimum),
                  let currentOS = AppStoreVersion(system), currentOS >= requiredOS
            else { return nil }
        }

        // Use our known product ID; ignore arbitrary URLs in remote metadata.
        guard let url = URL(string: "https://apps.apple.com/app/id\(AppIdentity.appStoreID)") else { return nil }
        return AppStoreUpdateInfo(currentVersion: currentVersion, storeVersion: item.version, storeURL: url)
    }

    private struct LookupResponse: Decodable {
        let results: [LookupItem]
    }

    private struct LookupItem: Decodable {
        let trackId: Int64
        let bundleId: String
        let wrapperType: String
        let version: String
        let minimumOsVersion: String?
    }
}

/// Numeric comparison: 2.0.10 > 2.0.9, and 2.0 == 2.0.0. Invalid versions
/// cannot accidentally become zero or trigger a downgrade from a TestFlight build.
struct AppStoreVersion: Comparable {
    private let parts: [Int]

    init?(_ value: String) {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !components.isEmpty, components.count <= 4 else { return nil }
        var numbers: [Int] = []
        for component in components {
            guard !component.isEmpty,
                  component.utf8.allSatisfy({ (48...57).contains($0) }),
                  let number = Int(component) else { return nil }
            numbers.append(number)
        }
        while numbers.count > 1, numbers.last == 0 { numbers.removeLast() }
        parts = numbers
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        for index in 0..<max(lhs.parts.count, rhs.parts.count) {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}
