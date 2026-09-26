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

    func startActivationSMS(bookingID: String, bookingToken: String, phone: String, locale: String) async throws -> IumrahPhoneChallengeStartResponse {
        try await api.post(
            "/api/package/client/account/activate/sms/start",
            body: IumrahAccountActivationSMSStartRequest(
                bookingID: bookingID,
                phone: phone,
                locale: locale
            ),
            headers: ["x-booking-token": bookingToken]
        )
    }

    func confirmActivationSMS(
        bookingID: String,
        bookingToken: String,
        challengeID: String,
        code: String,
        password: String,
        locale: String
    ) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/activate/sms/confirm",
            body: IumrahAccountActivationSMSConfirmRequest(
                bookingID: bookingID,
                challengeID: challengeID,
                code: code,
                password: password,
                device: IumrahAccountDeviceIdentity.current(locale: locale)
            ),
            headers: ["x-booking-token": bookingToken]
        )
    }

    func bookingPhoneVerificationStatus(bookingID: String, bookingToken: String) async throws -> IumrahPhoneVerificationStatusResponse {
        let encodedID = bookingID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bookingID
        return try await api.get(
            "/api/package/client/account/phone/status?bookingID=\(encodedID)",
            headers: ["x-booking-token": bookingToken]
        )
    }

    func startBookingPhoneVerification(bookingID: String, bookingToken: String, phone: String, locale: String) async throws -> IumrahPhoneChallengeStartResponse {
        try await api.post(
            "/api/package/client/account/phone/start",
            body: IumrahBookingPhoneVerificationStartRequest(
                bookingID: bookingID,
                phone: phone,
                locale: locale
            ),
            headers: ["x-booking-token": bookingToken]
        )
    }

    func confirmBookingPhoneVerification(bookingID: String, bookingToken: String, challengeID: String, code: String) async throws -> IumrahPhoneVerificationResponse {
        try await api.post(
            "/api/package/client/account/phone/confirm",
            body: IumrahBookingPhoneVerificationConfirmRequest(
                bookingID: bookingID,
                challengeID: challengeID,
                code: code
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

    func startPhoneLogin(phone: String, locale: String) async throws -> IumrahPhoneLoginStartResponse {
        try await api.post(
            "/api/package/client/account/login/sms/start",
            body: IumrahPhoneLoginStartRequest(phone: phone, locale: locale)
        )
    }

    func confirmPhoneLogin(challengeID: String, code: String, locale: String) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/login/sms/confirm",
            body: IumrahPhoneLoginConfirmRequest(
                challengeID: challengeID,
                code: code,
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

    /// Checkout accepts either the short-lived booking proof or the permanent account
    /// session. Do not send both in the same request: some gateway versions prioritize
    /// the bearer session and reject a still-valid booking proof when the two identities
    /// are temporarily out of sync. Prefer the booking proof, then fall back to the
    /// permanent account session only for authorization/not-found responses.
    func checkout(
        bookingID: String,
        bookingToken: String?,
        accountToken: String?
    ) async throws -> IumrahCheckoutResponse {
        let bookingToken = bookingToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let accountToken = accountToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !bookingToken.isEmpty {
            do {
                return try await checkout(
                    bookingID: bookingID,
                    authorizationHeaders: ["x-booking-token": bookingToken]
                )
            } catch {
                guard !accountToken.isEmpty, checkoutMayRetryWithAccount(error) else { throw error }
            }
        }

        if !accountToken.isEmpty {
            return try await checkout(
                bookingID: bookingID,
                authorizationHeaders: ["Authorization": "Bearer \(accountToken)"]
            )
        }

        throw APIError.missingBookingToken
    }

    private func checkoutMayRetryWithAccount(_ error: Error) -> Bool {
        switch error {
        case APIError.status(let code):
            return code == 401 || code == 403 || code == 404
        case APIError.server(let code, let message):
            let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return code == 401 || code == 403 || code == 404
                || normalized.contains("UNAUTHORIZED")
                || normalized.contains("BOOKING_NOT_FOUND")
                || normalized.contains("BOOKING_PROOF_INVALID")
        default:
            return false
        }
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
