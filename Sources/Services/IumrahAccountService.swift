import Foundation

struct IumrahAccountService {
    private let api = APIClient.shared

    func activate(bookingID: String, bookingToken: String, password: String, locale: String) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/activate",
            body: IumrahAccountActivateRequest(
                bookingID: bookingID,
                password: password,
                device: IumrahAccountDeviceIdentity.current(locale: locale)
            ),
            headers: ["x-booking-token": bookingToken]
        )
    }

    func startActivationEmail(bookingID: String, bookingToken: String, email: String, locale: String) async throws -> IumrahEmailChallengeStartResponse {
        try await api.post(
            "/api/package/client/account/activate/email/start",
            body: IumrahAccountActivationEmailStartRequest(
                bookingID: bookingID,
                email: email,
                locale: locale
            ),
            headers: ["x-booking-token": bookingToken]
        )
    }

    func confirmActivationEmail(
        bookingID: String,
        bookingToken: String,
        challengeID: String,
        code: String,
        password: String,
        locale: String
    ) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/activate/email/confirm",
            body: IumrahAccountActivationEmailConfirmRequest(
                bookingID: bookingID,
                challengeID: challengeID,
                code: code,
                password: password,
                device: IumrahAccountDeviceIdentity.current(locale: locale)
            ),
            headers: ["x-booking-token": bookingToken]
        )
    }

    func login(identifier: String, password: String, locale: String) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/login",
            body: IumrahAccountLoginRequest(
                identifier: identifier,
                password: password,
                device: IumrahAccountDeviceIdentity.current(locale: locale)
            )
        )
    }

    func session(token: String) async throws -> IumrahAccountProfile {
        let value: IumrahAccountSessionResponse = try await api.get(
            "/api/catalog/hotels/client/account/session",
            headers: ["Authorization": "Bearer \(token)"]
        )
        return value.account
    }

    func logout(token: String) async {
        let _: IumrahSimpleResponse? = try? await api.post(
            "/api/catalog/hotels/client/account/logout",
            body: EmptyBody(),
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    func updateProfile(_ request: IumrahAccountProfileUpdateRequest, token: String) async throws -> IumrahAccountProfile {
        let value: IumrahAccountSessionResponse = try await api.put(
            "/api/catalog/hotels/client/account/profile",
            body: request,
            headers: ["Authorization": "Bearer \(token)"]
        )
        return value.account
    }

    func trips(token: String) async throws -> [ClientTripSnapshot] {
        let value: IumrahAccountTripsResponse = try await api.get(
            "/api/catalog/hotels/client/trips",
            headers: ["Authorization": "Bearer \(token)"]
        )
        return value.trips
    }

    func tripDetail(bookingID: String, token: String) async throws -> IumrahAccountTripDetailResponse {
        try await api.get(
            "/api/catalog/hotels/client/trips/\(bookingID)",
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    func linkBooking(bookingID: String, bookingToken: String, token: String) async throws -> IumrahAccountLinkBookingResponse {
        let response: IumrahAccountLinkBookingResponse = try await api.post(
            "/api/catalog/hotels/client/account/link-booking",
            body: IumrahAccountLinkBookingRequest(bookingID: bookingID),
            headers: ["Authorization": "Bearer \(token)", "x-booking-token": bookingToken]
        )
        return response
    }

    func checkout(bookingID: String, authorizationHeaders: [String: String]) async throws -> IumrahCheckoutResponse {
        try await api.get(
            "/api/catalog/hotels/client/trips/\(bookingID)/checkout",
            headers: authorizationHeaders
        )
    }

    func saveTraveler(bookingID: String, position: Int, form: IumrahTravelerForm, token: String) async throws -> IumrahTravelerForm {
        let value: IumrahTravelerSaveResponse = try await api.put(
            "/api/catalog/hotels/client/trips/\(bookingID)/travelers/\(position)",
            body: IumrahTravelerSaveRequest(form),
            headers: ["Authorization": "Bearer \(token)"]
        )
        return value.traveler
    }

    func uploadPassport(bookingID: String, position: Int, data: Data, contentType: String, token: String) async throws {
        let _: IumrahSimpleResponse = try await api.upload(
            "/api/catalog/hotels/client/trips/\(bookingID)/travelers/\(position)/passport",
            data: data,
            contentType: contentType,
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    func uploadReceipt(bookingID: String, method: String, data: Data, contentType: String, token: String) async throws -> String {
        let value: IumrahReceiptResponse = try await api.upload(
            "/api/catalog/hotels/client/trips/\(bookingID)/receipt",
            data: data,
            contentType: contentType,
            headers: ["Authorization": "Bearer \(token)", "x-payment-method": method]
        )
        return value.id
    }

    func media(path: String, token: String) async throws -> Data {
        try await api.fetchData(path, headers: ["Authorization": "Bearer \(token)"])
    }

    func registerCurrentSession(token: String, locale: String) async throws -> IumrahSecurityOverview {
        try await api.post(
            "/api/package/client/account/security/register",
            body: IumrahDeviceRegistrationRequest(device: IumrahAccountDeviceIdentity.current(locale: locale)),
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    func walletPass(token: String) async throws -> Data {
        try await api.fetchData(
            "/api/package/client/account/wallet-pass",
            headers: ["Authorization": "Bearer \(token)"],
            timeoutInterval: 45
        )
    }

    func publicIdentityLink(token: String) async throws -> IumrahPublicIdentityLinkResponse {
        try await api.get(
            "/api/package/client/account/public-card",
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    func securityOverview(token: String) async throws -> IumrahSecurityOverview {
        try await api.get(
            "/api/package/client/account/security",
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func friendsDashboard(token: String) async throws -> IumrahFriendsDashboard {
        try await api.get(
            "/api/package/client/account/friends",
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func claimPrimaryDevice(password: String, token: String) async throws -> IumrahSecurityOverview {
        try await api.post(
            "/api/package/client/account/security/claim-primary",
            body: IumrahClaimPrimaryRequest(password: password),
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func terminateSession(id: String, token: String) async throws -> IumrahTerminateSessionResponse {
        try await api.delete(
            "/api/package/client/account/security/sessions/\(id)",
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func signInWithApple(_ credential: IumrahAppleCredential, locale: String) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/apple/sign-in",
            body: IumrahAppleSignInRequest(
                identityToken: credential.identityToken,
                nonce: credential.nonce,
                device: IumrahAccountDeviceIdentity.current(locale: locale)
            )
        )
    }

    func linkApple(_ credential: IumrahAppleCredential, token: String) async throws -> IumrahAppleLinkResponse {
        try await api.post(
            "/api/package/client/account/apple/link",
            body: IumrahAppleRequest(identityToken: credential.identityToken, nonce: credential.nonce),
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func signInWithGoogle(_ credential: IumrahGoogleCredential, locale: String) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/google/sign-in",
            body: IumrahGoogleSignInRequest(
                identityToken: credential.identityToken,
                nonce: credential.nonce,
                device: IumrahAccountDeviceIdentity.current(locale: locale)
            )
        )
    }

    func linkGoogle(_ credential: IumrahGoogleCredential, token: String) async throws -> IumrahGoogleLinkResponse {
        try await api.post(
            "/api/package/client/account/google/link",
            body: IumrahGoogleRequest(identityToken: credential.identityToken, nonce: credential.nonce),
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func startEmailVerification(email: String, locale: String, token: String) async throws -> IumrahEmailChallengeStartResponse {
        try await api.post(
            "/api/package/client/account/email/start",
            body: IumrahEmailChallengeStartRequest(email: email, locale: locale),
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func confirmEmailVerification(challengeID: String, code: String, token: String) async throws -> IumrahEmailChallengeConfirmResponse {
        try await api.post(
            "/api/package/client/account/email/confirm",
            body: IumrahEmailChallengeConfirmRequest(challengeID: challengeID, code: code),
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func startPasswordRecovery(email: String, locale: String) async throws -> IumrahEmailChallengeStartResponse {
        try await api.post(
            "/api/package/client/account/password/recovery/start",
            body: IumrahEmailChallengeStartRequest(email: email, locale: locale)
        )
    }

    func confirmPasswordRecovery(challengeID: String, code: String, newPassword: String) async throws -> IumrahPasswordRecoveryResponse {
        try await api.post(
            "/api/package/client/account/password/recovery/confirm",
            body: IumrahPasswordRecoveryConfirmRequest(
                challengeID: challengeID,
                code: code,
                newPassword: newPassword
            )
        )
    }
}

private struct EmptyBody: Encodable {}
