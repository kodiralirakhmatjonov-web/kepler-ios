import Foundation

struct AppStoreUpdateInfo: Identifiable, Equatable {
    let id: String
    let currentVersion: String
    let storeVersion: String
    let storeURL: URL

    init(currentVersion: String, storeVersion: String, storeURL: URL) {
        self.id = storeVersion
        self.currentVersion = currentVersion
        self.storeVersion = storeVersion
        self.storeURL = storeURL
    }
}

enum AppStoreUpdateChecker {
    static func fetchAvailableUpdate() async -> AppStoreUpdateInfo? {
        let currentVersion = AppIdentity.marketingVersion
        guard currentVersion != "0.0.0",
              let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=\(AppIdentity.appStoreID)")
        else { return nil }

        do {
            var request = URLRequest(url: lookupURL)
            request.timeoutInterval = 6
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode)
            else { return nil }

            let payload = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let item = payload.results.first,
                  isNewer(item.version, than: currentVersion)
            else { return nil }

            let fallback = "https://apps.apple.com/app/id\(AppIdentity.appStoreID)"
            guard let storeURL = URL(string: item.trackViewUrl ?? fallback) else { return nil }

            return AppStoreUpdateInfo(
                currentVersion: currentVersion,
                storeVersion: item.version,
                storeURL: storeURL
            )
        } catch {
            // Best effort only: network/App Store failures must never affect app launch.
            return nil
        }
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = numericVersion(candidate)
        let rhs = numericVersion(current)
        let count = max(lhs.count, rhs.count)

        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private static func numericVersion(_ value: String) -> [Int] {
        value.split(separator: ".").map { component in
            let digits = component.prefix { $0.isNumber }
            return Int(digits) ?? 0
        }
    }

    private struct LookupResponse: Decodable {
        let results: [LookupItem]
    }

    private struct LookupItem: Decodable {
        let version: String
        let trackViewUrl: String?
    }
}
