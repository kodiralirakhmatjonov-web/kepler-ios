import Foundation

/// Standalone regression checks; run with bash scripts/check-app-store-update.sh.
@main
struct AppStoreUpdateChecks {
    struct Failure: Error { let message: String }
    static var count = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Failure(message: message) }
        count += 1
    }

    static func version(_ value: String) throws -> AppStoreVersion {
        guard let result = AppStoreVersion(value) else { throw Failure(message: "Invalid test version: \(value)") }
        return result
    }

    static func fixture(
        version: String = "2.0.6",
        bundleID: String = AppIdentity.productionBundleID,
        appID: String = AppIdentity.appStoreID,
        minimumOS: String = "17.0",
        wrapper: String = "software"
    ) throws -> Data {
        let id = Int64(appID) ?? 0
        return try JSONSerialization.data(withJSONObject: ["resultCount": 1, "results": [[
            "trackId": id, "bundleId": bundleID, "wrapperType": wrapper,
            "version": version, "minimumOsVersion": minimumOS,
            "trackViewUrl": "https://unrelated.invalid/download"
        ]]])
    }

    static func main() throws {
        for (older, newer) in [("2.0.9", "2.0.10"), ("2.9.99", "2.10.0"), ("2.99.99", "3"), ("1", "1.0.1")] {
            let a = try version(older), b = try version(newer)
            try expect(a < b && b > a && !(b < a), "Numeric ordering \(older), \(newer)")
        }
        let short = try version("2.0"), padded = try version("2.0.0")
        try expect(short == padded, "Trailing zero equality")
        for invalid in ["", "2..1", "2.", ".2", "2.0-beta", " 2.0", "-2", "二", "2.0.0.0.0", "999999999999999999999999999"] {
            try expect(AppStoreVersion(invalid) == nil, "Reject malformed version: \(invalid)")
        }

        let os = OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0)
        let update = try AppStoreUpdateChecker.availableUpdate(from: fixture(), currentVersion: "2.0.5", operatingSystemVersion: os)
        try expect(update?.storeVersion == "2.0.6", "Newer compatible release is offered")
        try expect(update?.currentVersion == "2.0.5", "Installed version is retained")
        try expect(update?.storeURL.absoluteString == "https://apps.apple.com/app/id\(AppIdentity.appStoreID)", "Store URL is our known product, not remote metadata")

        for published in ["2.0.5", "2.0.4", "1.9.9", "broken"] {
            let result = try AppStoreUpdateChecker.availableUpdate(from: fixture(version: published), currentVersion: "2.0.5", operatingSystemVersion: os)
            try expect(result == nil, "Same, older or invalid version must not prompt: \(published)")
        }
        let beta = try AppStoreUpdateChecker.availableUpdate(from: fixture(version: "2.0.5"), currentVersion: "2.1.0", operatingSystemVersion: os)
        try expect(beta == nil, "No downgrade of a newer TestFlight version")
        for data in [
            try fixture(bundleID: "com.example.other"),
            try fixture(appID: "1234"),
            try fixture(minimumOS: "18.0"),
            try fixture(minimumOS: "invalid"),
            try fixture(wrapper: "track"),
            Data("{\"resultCount\":0,\"results\":[]}".utf8)
        ] {
            let result = try AppStoreUpdateChecker.availableUpdate(from: data, currentVersion: "2.0.5", operatingSystemVersion: os)
            try expect(result == nil, "Wrong product, unsupported iOS or no release must not prompt")
        }
        do {
            _ = try AppStoreUpdateChecker.availableUpdate(from: Data("<html>unavailable</html>".utf8), currentVersion: "2.0.5", operatingSystemVersion: os)
            throw Failure(message: "Malformed response was accepted")
        } catch is DecodingError { count += 1 }

        let lookup = AppStoreUpdateChecker.lookupURL(countryCode: "UZ")
        let query = lookup.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        try expect(lookup?.host == "itunes.apple.com", "Official lookup host")
        try expect(query.contains(URLQueryItem(name: "country", value: "uz")), "Explicit Uzbekistan storefront")
        try expect(query.contains(URLQueryItem(name: "id", value: AppIdentity.appStoreID)), "Existing production App Store ID")
        for invalid in ["USA", "001", "", "u1", "uz&x=1"] {
            try expect(AppStoreUpdateChecker.lookupURL(countryCode: invalid) == nil, "Reject invalid lookup country")
        }
        for (code, expected) in [("UZB", "uz"), ("USA", "us"), ("RUS", "ru"), ("KAZ", "kz"), ("TUR", "tr"), ("SAU", "sa"), ("GBR", "gb"), ("IDN", "id"), ("MYS", "my"), ("BGD", "bd"), ("FRA", "fr")] {
            try expect(AppStoreCountryCodes.lookupCountry(storefrontCountry: code, deviceCountry: "US") == expected, "Storefront takes precedence: \(code)")
        }
        try expect(AppStoreCountryCodes.lookupCountry(storefrontCountry: nil, deviceCountry: "RU") == "ru", "Device fallback")
        try expect(AppStoreCountryCodes.lookupCountry(storefrontCountry: nil, deviceCountry: "001") == "uz", "Missing region fallback")

        let now = Date(timeIntervalSince1970: 100_000)
        try expect(AppStoreUpdateReminder.shouldPresent(version: "2.0.6", lastVersion: "", lastShownAt: 0, now: now), "First prompt")
        try expect(!AppStoreUpdateReminder.shouldPresent(version: "2.0.6", lastVersion: "2.0.6", lastShownAt: 99_000, now: now), "Do not repeat on each foreground")
        try expect(AppStoreUpdateReminder.shouldPresent(version: "2.0.7", lastVersion: "2.0.6", lastShownAt: 99_000, now: now), "A different release can prompt immediately")
        try expect(AppStoreUpdateReminder.shouldPresent(version: "2.0.6", lastVersion: "2.0.6", lastShownAt: 13_600, now: now), "Reminder after 24 hours")
        try expect(AppStoreUpdateReminder.shouldPresent(version: "2.0.6", lastVersion: "2.0.6", lastShownAt: 200_000, now: now), "Clock rollback does not suppress forever")
        print("PASS: \(count) App Store update regression checks")
    }
}
