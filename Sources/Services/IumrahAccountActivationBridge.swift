import Foundation

/// Narrow compatibility bridge for account-entry flows that deliberately does
/// not replace IumrahAccountService. This keeps the live DevSMS account-security
/// implementation free to evolve independently.
struct IumrahAccountActivationBridge {
    private let api = APIClient.shared

    struct SMSChallenge: Decodable {
        let ok: Bool
        let challengeID: String
        let expiresAt: String?
    }

    private struct BookingSMSStartRequest: Encodable {
        let bookingID: String
        let phone: String
        let locale: String
    }

    private struct BookingSMSConfirmRequest: Encodable {
        let bookingID: String
        let challengeID: String
        let code: String
        let password: String
        let device: IumrahClientDevice
    }

    private struct RegistrationEmailConfirmRequest: Encodable {
        let challengeID: String
        let code: String
        let password: String
        let firstName: String
        let lastName: String
        let device: IumrahClientDevice
    }

    func startBookingSMS(
        bookingID: String,
        bookingToken: String,
        phone: String,
        locale: String
    ) async throws -> SMSChallenge {
        try await api.post(
            "/api/package/client/account/activate/sms/start",
            body: BookingSMSStartRequest(bookingID: bookingID, phone: phone, locale: locale),
            headers: ["x-booking-token": bookingToken]
        )
    }

    func confirmBookingSMS(
        bookingID: String,
        bookingToken: String,
        challengeID: String,
        code: String,
        password: String,
        locale: String
    ) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/activate/sms/confirm",
            body: BookingSMSConfirmRequest(
                bookingID: bookingID,
                challengeID: challengeID,
                code: code,
                password: password,
                device: IumrahAccountDeviceIdentity.current(locale: locale)
            ),
            headers: ["x-booking-token": bookingToken]
        )
    }

    func startEmailRegistration(email: String, locale: String) async throws -> IumrahEmailChallengeStartResponse {
        try await api.post(
            "/api/package/client/account/register/email/start",
            body: IumrahEmailChallengeStartRequest(email: email, locale: locale)
        )
    }

    func confirmEmailRegistration(
        challengeID: String,
        code: String,
        password: String,
        firstName: String,
        lastName: String,
        locale: String
    ) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/register/email/confirm",
            body: RegistrationEmailConfirmRequest(
                challengeID: challengeID,
                code: code,
                password: password,
                firstName: firstName,
                lastName: lastName,
                device: IumrahAccountDeviceIdentity.current(locale: locale)
            )
        )
    }
}
