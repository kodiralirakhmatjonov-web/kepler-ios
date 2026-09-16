import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

struct IumrahClientDevice: Codable, Hashable {
    let installationID: String
    let secret: String
    let name: String
    let model: String
    let hardwareIdentifier: String
    let platform: String
    let osVersion: String
    let appVersion: String
    let locale: String
}

enum IumrahAccountDeviceIdentity {
    private struct Credentials: Codable {
        let installationID: String
        let secret: String
    }

    private static let service = "com.iumrah.app.account-device"
    private static let account = "installation"

    static func current(locale: String = Locale.current.identifier) -> IumrahClientDevice {
        let credentials = load() ?? create()
        let hardware = hardwareIdentifier
        let modelName = friendlyModelName(for: hardware)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

        return IumrahClientDevice(
            installationID: credentials.installationID,
            secret: credentials.secret,
            name: modelName,
            // Keep the raw Apple hardware identifier as the technical model. The
            // backend already persists this field, so no schema change is needed.
            // It also gives us an exact fallback for future devices that have not
            // yet been added to the marketing-name map.
            model: hardware,
            hardwareIdentifier: hardware,
            platform: "ios",
            osVersion: UIDevice.current.systemVersion,
            appVersion: version,
            locale: locale
        )
    }

    static func friendlyModelName(for identifier: String) -> String {
        let models: [String: String] = [
            "iPhone7,2": "iPhone 6",
            "iPhone7,1": "iPhone 6 Plus",
            "iPhone8,1": "iPhone 6s",
            "iPhone8,2": "iPhone 6s Plus",
            "iPhone8,4": "iPhone SE (1st generation)",
            "iPhone9,1": "iPhone 7", "iPhone9,3": "iPhone 7",
            "iPhone9,2": "iPhone 7 Plus", "iPhone9,4": "iPhone 7 Plus",
            "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8",
            "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
            "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS",
            "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone12,8": "iPhone SE (2nd generation)",
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,6": "iPhone SE (3rd generation)",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,5": "iPhone 16e",
            "iPhone18,3": "iPhone 17",
            "iPhone18,1": "iPhone 17 Pro",
            "iPhone18,2": "iPhone 17 Pro Max",
            "iPhone18,4": "iPhone Air",
            "iPhone18,5": "iPhone 17e",
        ]

        if let name = models[identifier] { return name }
        if identifier == "i386" || identifier == "x86_64" || identifier == "arm64" {
            return "iPhone Simulator"
        }
        if identifier.hasPrefix("iPhone") { return "iPhone" }
        if identifier.hasPrefix("iPad") { return "iPad" }
        return UIDevice.current.localizedModel
    }

    static func securityHeaders(token: String) -> [String: String] {
        let device = current()
        return [
            "Authorization": "Bearer \(token)",
            "x-iumrah-device-id": device.installationID,
            "x-iumrah-device-secret": device.secret,
        ]
    }

    private static var hardwareIdentifier: String {
#if targetEnvironment(simulator)
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !simulated.isEmpty {
            return simulated
        }
#endif
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { buffer in
            let bytes = buffer.prefix { $0 != 0 }
            return String(bytes: bytes, encoding: .utf8) ?? UIDevice.current.localizedModel
        }
    }

    private static func create() -> Credentials {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Secure random generation failed")
        let secret = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let credentials = Credentials(
            installationID: UUID().uuidString.lowercased(),
            secret: secret
        )
        save(credentials)
        return credentials
    }

    private static func load() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    private static func save(_ credentials: Credentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(base as CFDictionary, update as CFDictionary) == errSecSuccess { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(add as CFDictionary, nil)
    }
}

struct IumrahAppleCredential {
    let identityToken: String
    let nonce: String
}

enum IumrahAppleSignInError: LocalizedError {
    case secureRandomFailed
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .secureRandomFailed:
            return "Не удалось безопасно подготовить вход через Apple."
        case .invalidCredential:
            return "Apple не вернул подтверждение личности. Попробуйте ещё раз."
        }
    }
}

enum IumrahAppleSignInSupport {
    static func prepare(_ request: ASAuthorizationAppleIDRequest) throws -> String {
        let nonce = try randomNonce()
        // Apple email is requested only to resolve or create the same canonical
        // iumrah account. The permanent eight-digit iumrah ID remains the profile ID.
        request.requestedScopes = [.email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return nonce
    }

    static func credential(from authorization: ASAuthorization, nonce: String) throws -> IumrahAppleCredential {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleCredential.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              !token.isEmpty,
              !nonce.isEmpty else {
            throw IumrahAppleSignInError.invalidCredential
        }
        return IumrahAppleCredential(identityToken: token, nonce: nonce)
    }

    private static func randomNonce(length: Int = 32) throws -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw IumrahAppleSignInError.secureRandomFailed
            }
            for byte in bytes where Int(byte) < characters.count {
                result.append(characters[Int(byte)])
                remaining -= 1
                if remaining == 0 { break }
            }
        }
        return result
    }
}
