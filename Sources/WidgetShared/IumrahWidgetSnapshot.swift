import Foundation
import Security

struct IumrahWidgetSnapshot: Codable, Equatable {
    var schemaVersion: Int = 1
    var updatedAt: Date = Date()
    var activeBooking: IumrahWidgetBookingSnapshot?
    var plannedTrip: IumrahWidgetPlannedTripSnapshot?
    var identity: IumrahWidgetIdentitySnapshot?

    static let empty = IumrahWidgetSnapshot()
}

struct IumrahWidgetBookingSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let displayNumber: String
    let status: String
    let originCode: String
    let destinationCode: String
    let startDate: Date?
    let endDate: Date?
    let travelerCount: Int
    let perPilgrimUSD: Double
}

struct IumrahWidgetPlannedTripSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let backgroundID: String
    let notificationsEnabled: Bool
    let reminderHour: Int
    let reminderMinute: Int
}

struct IumrahWidgetIdentitySnapshot: Codable, Equatable {
    let displayName: String
    let iumrahID: String
    let publicURL: String
}

enum IumrahWidgetDeepLink {
    static let scheme = "iumrah"

    static func booking(_ id: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "widget"
        components.path = "/booking/\(id)"
        return components.url
    }

    static var plannedTrip: URL? {
        URL(string: "iumrah://widget/planned")
    }

    static var account: URL? {
        URL(string: "iumrah://widget/account")
    }
}

enum IumrahWidgetSharedStore {
    // The production provisioning profile already permits the team wildcard
    // keychain group. Using a shared keychain keeps widget data private and
    // avoids storing account/booking snapshots in a public container.
    static let keychainAccessGroup = "2DQ678JTNG.com.iumrah.shared"

    private static let service = "com.iumrah.widget.snapshot"
    private static let account = "current"

    static func load() -> IumrahWidgetSnapshot {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: keychainAccessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let decoded = try? decoder.decode(IumrahWidgetSnapshot.self, from: data) else {
            // A simulator/debug environment may not expose the shared access group.
            // Falling back to a process-local copy keeps previews and development safe.
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            item = nil
            let fallbackStatus = SecItemCopyMatching(query as CFDictionary, &item)
            guard fallbackStatus == errSecSuccess,
                  let fallbackData = item as? Data,
                  let fallback = try? decoder.decode(IumrahWidgetSnapshot.self, from: fallbackData) else {
                return .empty
            }
            return fallback
        }
        return decoded
    }

    @discardableResult
    static func save(_ snapshot: IumrahWidgetSnapshot) -> Bool {
        var normalized = snapshot
        normalized.updatedAt = Date()
        guard let data = try? encoder.encode(normalized) else { return false }
        if write(data: data, accessGroup: keychainAccessGroup) { return true }
        return write(data: data, accessGroup: nil)
    }

    static func mutate(_ body: (inout IumrahWidgetSnapshot) -> Void) {
        var snapshot = load()
        body(&snapshot)
        _ = save(snapshot)
    }

    static func clear() {
        delete(accessGroup: keychainAccessGroup)
        delete(accessGroup: nil)
    }

    private static func write(data: Data, accessGroup: String?) -> Bool {
        var base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup { base[kSecAttrAccessGroup as String] = accessGroup }

        let updateStatus = SecItemUpdate(
            base as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var insert = base
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    private static func delete(accessGroup: String?) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        SecItemDelete(query as CFDictionary)
    }

    private static let encoder: JSONEncoder = {
        let value = JSONEncoder()
        value.dateEncodingStrategy = .iso8601
        return value
    }()

    private static let decoder: JSONDecoder = {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .iso8601
        return value
    }()
}
