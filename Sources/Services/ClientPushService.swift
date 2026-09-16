import Foundation

struct ClientPushService {
    private let api = APIClient.shared

    func register(
        deviceToken: String,
        bookingID: String,
        headers: [String: String],
        locale: String,
        environment: String = "production"
    ) async throws -> Bool? {
        let response: ClientPushRegistrationResponse = try await api.post(
            "/api/catalog/hotels/client/push/devices",
            body: ClientPushRegistrationRequest(
                deviceToken: deviceToken,
                bookingID: bookingID,
                environment: environment,
                appBundleID: "com.iumrah.app",
                locale: locale
            ),
            headers: headers
        )
        return response.ready
    }
}

private struct ClientPushRegistrationRequest: Encodable {
    let deviceToken: String
    let bookingID: String
    let environment: String
    let appBundleID: String
    let locale: String
}

private struct ClientPushRegistrationResponse: Decodable {
    let ok: Bool
    let ready: Bool?
    let bookingID: String?
}
