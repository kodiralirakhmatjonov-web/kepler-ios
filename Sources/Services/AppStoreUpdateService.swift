import Foundation

@MainActor
final class AppStoreUpdateService: ObservableObject {
    struct Update: Identifiable, Equatable {
        let id = UUID()
        let currentVersion: String
        let storeVersion: String
        let storeURL: URL
    }

    @Published private(set) var availableUpdate: Update?
    private var hasChecked = false

    func checkIfNeeded() async {
        guard !hasChecked else { return }
        hasChecked = true

        guard let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=\(AppIdentity.appStoreID)&country=us") else { return }

        do {
            var request = URLRequest(url: lookupURL)
            request.timeoutInterval = 8
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }

            let payload = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let item = payload.results.first,
                  isNewer(item.version, than: AppIdentity.marketingVersion),
                  let storeURL = URL(string: item.trackViewUrl ?? "https://apps.apple.com/app/id\(AppIdentity.appStoreID)")
            else { return }

            availableUpdate = Update(
                currentVersion: AppIdentity.marketingVersion,
                storeVersion: item.version,
                storeURL: storeURL
            )
        } catch {
            // Update discovery is deliberately best-effort. Offline/error states
            // must never delay or block normal app startup.
        }
    }

    func dismiss() {
        availableUpdate = nil
    }

    private func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let l = index < lhs.count ? lhs[index] : 0
            let r = index < rhs.count ? rhs[index] : 0
            if l != r { return l > r }
        }
        return false
    }

    private struct LookupResponse: Decodable {
        let results: [LookupItem]
    }

    private struct LookupItem: Decodable {
        let version: String
        let trackViewUrl: String?
    }
}
