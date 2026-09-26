import Foundation
import Security
import Combine

@MainActor
final class IumrahAccountStore: ObservableObject {
    @Published private(set) var account: IumrahAccountProfile?
    @Published private(set) var isRestoring = false
    @Published private(set) var lastError: String?

    private let service = IumrahAccountService()
    private var token: String?

    init() {
        LegacyClientIdentityCleanup.purge()
        if let saved = IumrahAccountVault.load() {
            token = saved.token
            account = saved.account
        }
    }

    var isAuthenticated: Bool { token != nil && account != nil }
    var iumrahID: String? { account?.iumrahID }
    var bearerToken: String? { token }

    func authorizationHeaders(bookingToken: String? = nil) -> [String: String] {
        var headers: [String: String] = [:]
        if let token, !token.isEmpty { headers["Authorization"] = "Bearer \(token)" }
        if let bookingToken, !bookingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            headers["x-booking-token"] = bookingToken
        }
        return headers
    }

    func restore() async {
        guard let token else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            let profile = try await service.session(token: token)
            account = profile
            IumrahAccountVault.save(.init(token: token, account: profile))
            _ = try? await service.registerCurrentSession(token: token, locale: Locale.current.identifier)
            lastError = nil
        } catch {
            self.token = nil
            account = nil
            IumrahAccountVault.clear()
            lastError = nil
        }
    }

    @discardableResult
    func activate(bookingID: String, bookingToken: String, password: String, locale: String = Locale.current.identifier) async throws -> IumrahAccountProfile {
        let response = try await service.activate(
            bookingID: bookingID,
            bookingToken: bookingToken,
            password: password,
            locale: locale
        )
        setSession(response)
        return response.account
    }

    func startActivationEmail(bookingID: String, bookingToken: String, email: String, locale: String) async throws -> IumrahEmailChallengeStartResponse {
        try await service.startActivationEmail(
            bookingID: bookingID,
            bookingToken: bookingToken,
            email: email,
            locale: locale
        )
    }

    @discardableResult
    func confirmActivationEmail(
        bookingID: String,
        bookingToken: String,
        challengeID: String,
        code: String,
        password: String,
        locale: String
    ) async throws -> IumrahAccountProfile {
        let response = try await service.confirmActivationEmail(
            bookingID: bookingID,
            bookingToken: bookingToken,
            challengeID: challengeID,
            code: code,
            password: password,
            locale: locale
        )
        setSession(response)
        return response.account
    }

    func startActivationSMS(bookingID: String, bookingToken: String, phone: String, locale: String) async throws -> IumrahPhoneChallengeStartResponse {
        try await service.startActivationSMS(
            bookingID: bookingID,
            bookingToken: bookingToken,
            phone: phone,
            locale: locale
        )
    }

    @discardableResult
    func confirmActivationSMS(
        bookingID: String,
        bookingToken: String,
        challengeID: String,
        code: String,
        password: String,
        locale: String
    ) async throws -> IumrahAccountProfile {
        let response = try await service.confirmActivationSMS(
            bookingID: bookingID,
            bookingToken: bookingToken,
            challengeID: challengeID,
            code: code,
            password: password,
            locale: locale
        )
        setSession(response)
        return response.account
    }

    @discardableResult
    func login(identifier: String, password: String, locale: String = Locale.current.identifier) async throws -> IumrahAccountProfile {
        let response = try await service.login(identifier: identifier, password: password, locale: locale)
        setSession(response)
        _ = try? await service.registerCurrentSession(token: response.session.token, locale: locale)
        return response.account
    }

    @discardableResult
    func signInWithApple(_ credential: IumrahAppleCredential, locale: String) async throws -> IumrahAccountProfile {
        let response = try await service.signInWithApple(credential, locale: locale)
        setSession(response)
        _ = try? await service.registerCurrentSession(token: response.session.token, locale: locale)
        return response.account
    }

    @discardableResult
    func signInWithGoogle(_ credential: IumrahGoogleCredential, locale: String) async throws -> IumrahAccountProfile {
        let response = try await service.signInWithGoogle(credential, locale: locale)
        setSession(response)
        _ = try? await service.registerCurrentSession(token: response.session.token, locale: locale)
        return response.account
    }

    @discardableResult
    func updateProfile(firstName: String, lastName: String, phone: String, email: String, telegram: String, whatsapp: String) async throws -> IumrahAccountProfile {
        guard let token else { throw APIError.status(401) }
        let profile = try await service.updateProfile(
            .init(firstName: firstName, lastName: lastName, phone: phone, email: email, telegram: telegram, whatsapp: whatsapp),
            token: token
        )
        account = profile
        lastError = nil
        IumrahAccountVault.save(.init(token: token, account: profile))
        return profile
    }

    func logout() async {
        if let token { await service.logout(token: token) }
        IumrahGoogleSignInSupport.signOutProviderSession()
        token = nil
        account = nil
        lastError = nil
        IumrahAccountVault.clear()
    }

    func walletPassData() async throws -> Data {
        guard let token else { throw APIError.status(401) }
        return try await service.walletPass(token: token)
    }

    func publicIdentityLink() async throws -> IumrahPublicIdentityLinkResponse {
        guard let token else { throw APIError.status(401) }
        return try await service.publicIdentityLink(token: token)
    }

    func securityOverview(locale: String) async throws -> IumrahSecurityOverview {
        guard let token else { throw APIError.status(401) }
        _ = try await service.registerCurrentSession(token: token, locale: locale)
        return try await service.securityOverview(token: token)
    }

    func friendsDashboard() async throws -> IumrahFriendsDashboard {
        guard let token else { throw APIError.status(401) }
        _ = try? await service.registerCurrentSession(token: token, locale: Locale.current.identifier)
        return try await service.friendsDashboard(token: token)
    }

    func claimPrimaryDevice(password: String) async throws -> IumrahSecurityOverview {
        guard let token else { throw APIError.status(401) }
        return try await service.claimPrimaryDevice(password: password, token: token)
    }

    func terminateSecuritySession(id: String) async throws -> Bool {
        guard let token else { throw APIError.status(401) }
        let response = try await service.terminateSession(id: id, token: token)
        if response.signedOut { clearLocalSession() }
        return response.signedOut
    }

    func linkApple(_ credential: IumrahAppleCredential) async throws -> IumrahAppleLinkResponse {
        guard let token else { throw APIError.status(401) }
        return try await service.linkApple(credential, token: token)
    }

    func linkGoogle(_ credential: IumrahGoogleCredential) async throws -> IumrahGoogleLinkResponse {
        guard let token else { throw APIError.status(401) }
        return try await service.linkGoogle(credential, token: token)
    }

    func startEmailVerification(email: String, locale: String) async throws -> IumrahEmailChallengeStartResponse {
        guard let token else { throw APIError.status(401) }
        return try await service.startEmailVerification(email: email, locale: locale, token: token)
    }

    func confirmEmailVerification(challengeID: String, code: String) async throws -> IumrahEmailChallengeConfirmResponse {
        guard let token else { throw APIError.status(401) }
        let response = try await service.confirmEmailVerification(challengeID: challengeID, code: code, token: token)
        if let profile = account {
            let updated = IumrahAccountProfile(
                iumrahID: profile.iumrahID,
                displayName: profile.displayName,
                firstName: profile.firstName,
                lastName: profile.lastName,
                phone: profile.phone,
                email: response.email,
                telegram: profile.telegram,
                whatsapp: profile.whatsapp
            )
            account = updated
            IumrahAccountVault.save(.init(token: token, account: updated))
        }
        return response
    }

    func startPasswordRecovery(email: String, locale: String) async throws -> IumrahEmailChallengeStartResponse {
        try await service.startPasswordRecovery(email: email, locale: locale)
    }

    func confirmPasswordRecovery(challengeID: String, code: String, newPassword: String) async throws -> IumrahPasswordRecoveryResponse {
        try await service.confirmPasswordRecovery(challengeID: challengeID, code: code, newPassword: newPassword)
    }

    func linkBooking(bookingID: String, bookingToken: String) async throws -> IumrahAccountLinkBookingResponse {
        guard let token else { throw APIError.status(401) }
        return try await service.linkBooking(bookingID: bookingID, bookingToken: bookingToken, token: token)
    }

    func accountTrips() async throws -> [ClientTripSnapshot] {
        guard let token else { throw APIError.status(401) }
        return try await service.trips(token: token)
    }

    func tripDetail(bookingID: String) async throws -> IumrahAccountTripDetailResponse {
        guard let token else { throw APIError.status(401) }
        return try await service.tripDetail(bookingID: bookingID, token: token)
    }

    private func setSession(_ response: IumrahAccountAuthResponse) {
        token = response.session.token
        account = response.account
        lastError = nil
        IumrahAccountVault.save(.init(token: response.session.token, account: response.account))
    }

    private func clearLocalSession() {
        IumrahGoogleSignInSupport.signOutProviderSession()
        token = nil
        account = nil
        lastError = nil
        IumrahAccountVault.clear()
    }
}

private struct StoredIumrahAccountSession: Codable {
    let token: String
    let account: IumrahAccountProfile
}

private enum IumrahAccountVault {
    private static let service = "com.iumrah.app.iumrah-account"
    private static let account = "session"

    static func load() -> StoredIumrahAccountSession? {
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
        return try? JSONDecoder().decode(StoredIumrahAccountSession.self, from: data)
    }

    static func save(_ value: StoredIumrahAccountSession) {
        guard let data = try? JSONEncoder().encode(value) else { return }
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

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
