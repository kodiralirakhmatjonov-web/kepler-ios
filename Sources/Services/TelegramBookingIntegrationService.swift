import Foundation

struct IumrahTelegramLinkResponse: Decodable {
    struct BookingRef: Decodable {
        let bookingID: String
        let bookingDisplayNumber: String?
    }

    let ok: Bool
    let booking: BookingRef?
    let startParameter: String?
    let linkUrl: String?
    let expiresAt: String?
}

private struct IumrahTelegramLinkRequest: Encodable {
    let language: String
}

private struct IumrahTelegramStatusResponse: Decodable {
    let ok: Bool
    let linked: Bool
}

struct TelegramBookingIntegrationService {
    private let api = APIClient.shared

    func createLink(
        bookingID: String,
        authorizationHeaders: [String: String],
        language: AppSettingsStore.Language
    ) async throws -> URL {
        let response: IumrahTelegramLinkResponse = try await api.post(
            "/api/package/booking/\(bookingID)/telegram-link",
            body: IumrahTelegramLinkRequest(language: language.rawValue),
            headers: authorizationHeaders,
            timeoutInterval: 15
        )
        guard response.ok,
              let raw = response.linkUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "t.me" else {
            throw APIError.invalidResponse
        }
        return url
    }

    func isLinked(
        bookingID: String,
        authorizationHeaders: [String: String]
    ) async throws -> Bool {
        let response: IumrahTelegramStatusResponse = try await api.get(
            "/api/package/booking/\(bookingID)/telegram-status",
            headers: authorizationHeaders,
            timeoutInterval: 12
        )
        return response.ok && response.linked
    }
}
