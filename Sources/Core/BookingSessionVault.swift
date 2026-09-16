import Foundation
import Security

enum BookingSessionVault {
    private static let service = "com.iumrah.app.booking-sessions"
    private static let account = "sessions"

    static func load() -> [StoredBookingSession] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return [] }
        return (try? JSONDecoder().decode([StoredBookingSession].self, from: data)) ?? []
    }

    @discardableResult
    static func save(_ sessions: [StoredBookingSession]) -> Bool {
        guard let data = try? JSONEncoder().encode(sessions) else { return false }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return false
    }
}

/// One-time cleanup for the pre-account device identities. These values are no longer
/// accepted as user identity: the permanent eight-digit iumrah ID is the only account identity.
enum LegacyClientIdentityCleanup {
    static func purge() {
        for account in ["client-user-id", "stable-client-id"] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.iumrah.app.client-identity",
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
