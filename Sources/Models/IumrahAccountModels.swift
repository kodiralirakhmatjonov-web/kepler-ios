import Foundation

struct IumrahAccountProfile: Codable, Hashable {
    let iumrahID: String
    let displayName: String
    let firstName: String
    let lastName: String
    let phone: String
    let email: String
    let telegram: String
    let whatsapp: String

    private enum CodingKeys: String, CodingKey {
        case iumrahID, displayName, firstName, lastName, phone, email, telegram, whatsapp
    }

    init(
        iumrahID: String,
        displayName: String,
        firstName: String,
        lastName: String,
        phone: String,
        email: String,
        telegram: String,
        whatsapp: String
    ) {
        self.iumrahID = iumrahID
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.email = email
        self.telegram = telegram
        self.whatsapp = whatsapp
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        iumrahID = try box.decode(String.self, forKey: .iumrahID)
        displayName = try box.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        firstName = try box.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        lastName = try box.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        phone = try box.decodeIfPresent(String.self, forKey: .phone) ?? ""
        email = try box.decodeIfPresent(String.self, forKey: .email) ?? ""
        telegram = try box.decodeIfPresent(String.self, forKey: .telegram) ?? ""
        whatsapp = try box.decodeIfPresent(String.self, forKey: .whatsapp) ?? ""
    }
}

struct IumrahAccountProfileUpdateRequest: Encodable {
    let firstName: String
    let lastName: String
    let phone: String
    let email: String
    let telegram: String
    let whatsapp: String
}

struct IumrahAccountSession: Codable, Hashable {
    let token: String
    let expiresAt: String
}

struct IumrahAccountAuthResponse: Decodable {
    let ok: Bool
    let account: IumrahAccountProfile
    let session: IumrahAccountSession
}

struct IumrahAccountSessionResponse: Decodable {
    let ok: Bool
    let account: IumrahAccountProfile
}

struct IumrahPublicIdentityLinkResponse: Decodable {
    let ok: Bool
    let iumrahID: String
    let url: String
}

struct IumrahAccountLoginRequest: Encodable {
    let identifier: String
    let password: String
    let device: IumrahClientDevice
}

struct IumrahPhoneLoginStartRequest: Encodable {
    let phone: String
    let locale: String
}

struct IumrahPhoneLoginStartResponse: Decodable {
    let ok: Bool
    let challengeID: String
    let expiresAt: String?
    let phone: String
}

struct IumrahPhoneLoginConfirmRequest: Encodable {
    let challengeID: String
    let code: String
    let device: IumrahClientDevice
}

struct IumrahAccountActivateRequest: Encodable {
    let bookingID: String
    let password: String
    let device: IumrahClientDevice
}

struct IumrahAccountActivationEmailStartRequest: Encodable {
    let bookingID: String
    let email: String
    let locale: String
}

struct IumrahAccountActivationEmailConfirmRequest: Encodable {
    let bookingID: String
    let challengeID: String
    let code: String
    let password: String
    let device: IumrahClientDevice
}

struct IumrahAccountActivationSMSStartRequest: Encodable {
    let bookingID: String
    let phone: String
    let locale: String
}

struct IumrahAccountActivationSMSConfirmRequest: Encodable {
    let bookingID: String
    let challengeID: String
    let code: String
    let password: String
    let device: IumrahClientDevice
}

struct IumrahBookingPhoneVerificationStartRequest: Encodable {
    let bookingID: String
    let phone: String
    let locale: String
}

struct IumrahBookingPhoneVerificationConfirmRequest: Encodable {
    let bookingID: String
    let challengeID: String
    let code: String
}

struct IumrahPhoneChallengeStartResponse: Decodable {
    let ok: Bool
    let challengeID: String
    let expiresAt: String?
    let phone: String
}

struct IumrahPhoneVerificationResponse: Decodable {
    let ok: Bool
    let phone: String
    let verifiedAt: String
}

struct IumrahPhoneVerificationStatusResponse: Decodable {
    let ok: Bool
    let verified: Bool
    let phone: String
    let verifiedAt: String
}

struct IumrahAccountTripsResponse: Decodable {
    let ok: Bool
    let trips: [ClientTripSnapshot]
}

struct IumrahTravelerForm: Codable, Identifiable, Hashable {
    var id: Int { position }
    let position: Int
    let travelerType: String
    var relationship: String?
    var firstName: String
    var middleName: String
    var lastName: String
    var gender: String
    var dateOfBirth: String
    var placeOfBirth: String
    var nationality: String
    var residenceCountry: String
    var passportNumber: String
    var passportIssueDate: String
    var passportExpiryDate: String
    var passportIssuingCountry: String
    var phone: String
    var email: String
    var emergencyName: String
    var emergencyPhone: String
    var emergencyRelation: String
    let hasPassport: Bool
    let completed: Bool
}

struct IumrahTravelerSaveRequest: Encodable {
    let relationship: String?
    let firstName: String
    let middleName: String
    let lastName: String
    let gender: String
    let dateOfBirth: String
    let placeOfBirth: String
    let nationality: String
    let residenceCountry: String
    let passportNumber: String
    let passportIssueDate: String
    let passportExpiryDate: String
    let passportIssuingCountry: String
    let phone: String
    let email: String
    let emergencyName: String
    let emergencyPhone: String
    let emergencyRelation: String

    init(_ form: IumrahTravelerForm) {
        relationship = form.relationship
        firstName = form.firstName
        middleName = form.middleName
        lastName = form.lastName
        gender = form.gender
        dateOfBirth = form.dateOfBirth
        placeOfBirth = form.placeOfBirth
        nationality = form.nationality
        residenceCountry = form.residenceCountry
        passportNumber = form.passportNumber
        passportIssueDate = form.passportIssueDate
        passportExpiryDate = form.passportExpiryDate
        passportIssuingCountry = form.passportIssuingCountry
        phone = form.phone
        email = form.email
        emergencyName = form.emergencyName
        emergencyPhone = form.emergencyPhone
        emergencyRelation = form.emergencyRelation
    }
}

struct IumrahTravelerSaveResponse: Decodable {
    let ok: Bool
    let traveler: IumrahTravelerForm
}

struct IumrahCheckoutPayment: Codable, Hashable {
    let visaCardNumber: String
    let visaHolder: String
    let hasPaymeQR: Bool
    let paymeQRURL: String?
    let humoCardNumber: String
    let humoHolder: String
    let instructions: String
}

struct IumrahPaymentReceipt: Codable, Identifiable, Hashable {
    let id: String
    let paymentMethod: String
    let note: String?
    let reviewStatus: String
    let createdAt: String
    let url: String?
    let contentType: String?
    let filename: String?
}

struct IumrahTravelDocument: Codable, Identifiable, Hashable {
    let id: String
    let documentKind: String
    let title: String
    let contentType: String
    let createdAt: String
    let url: String
    let bookingReference: String?
}

struct IumrahCheckoutResponse: Decodable {
    let ok: Bool
    let iumrahID: String
    let accountActive: Bool
    let status: String
    let travelers: [IumrahTravelerForm]
    let payment: IumrahCheckoutPayment
    let receipts: [IumrahPaymentReceipt]
    let documents: [IumrahTravelDocument]
}

struct IumrahSimpleResponse: Decodable { let ok: Bool }
struct IumrahReceiptResponse: Decodable { let ok: Bool; let id: String }

struct IumrahDeviceRegistrationRequest: Encodable {
    let device: IumrahClientDevice
}

struct IumrahSecuritySession: Decodable, Identifiable, Hashable {
    let id: String
    let deviceName: String
    let model: String
    let platform: String
    let osVersion: String
    let appVersion: String
    let city: String
    let region: String
    let country: String
    let createdAt: String
    let lastActiveAt: String
    let expiresAt: String
    let isCurrent: Bool
    let isPrimary: Bool
    let canTerminate: Bool
}

struct IumrahAppleConnectionStatus: Decodable, Hashable {
    let linked: Bool
    let linkedAt: String?
}

struct IumrahGoogleConnectionStatus: Decodable, Hashable {
    let linked: Bool
    let linkedAt: String?
}

struct IumrahVerifiedLoginEmail: Decodable, Hashable {
    let email: String
    let verifiedAt: String
}

struct IumrahSecurityOverview: Decodable, Hashable {
    let ok: Bool
    let iumrahID: String
    let currentSessionID: String
    let currentDeviceIsPrimary: Bool
    let primaryDeviceProtected: Bool
    let loginEmail: IumrahVerifiedLoginEmail?
    let apple: IumrahAppleConnectionStatus
    let google: IumrahGoogleConnectionStatus?
    let sessions: [IumrahSecuritySession]
}

struct IumrahClaimPrimaryRequest: Encodable {
    let password: String
}

struct IumrahAppleRequest: Encodable {
    let identityToken: String
    let nonce: String
}

struct IumrahAppleSignInRequest: Encodable {
    let identityToken: String
    let nonce: String
    let device: IumrahClientDevice
}

struct IumrahAppleLinkResponse: Decodable {
    let ok: Bool
    let appleLinked: Bool
    let iumrahID: String
}

struct IumrahGoogleRequest: Encodable {
    let identityToken: String
    let nonce: String
}

struct IumrahGoogleSignInRequest: Encodable {
    let identityToken: String
    let nonce: String
    let device: IumrahClientDevice
}

struct IumrahGoogleLinkResponse: Decodable {
    let ok: Bool
    let googleLinked: Bool
    let iumrahID: String
}

struct IumrahEmailChallengeStartRequest: Encodable {
    let email: String
    let locale: String
}

struct IumrahEmailChallengeStartResponse: Decodable {
    let ok: Bool
    let challengeID: String
    let expiresAt: String?
}

struct IumrahEmailChallengeConfirmRequest: Encodable {
    let challengeID: String
    let code: String
}

struct IumrahEmailChallengeConfirmResponse: Decodable {
    let ok: Bool
    let email: String
    let verifiedAt: String
}

struct IumrahPasswordRecoveryConfirmRequest: Encodable {
    let challengeID: String
    let code: String
    let newPassword: String
}

struct IumrahPasswordRecoveryResponse: Decodable {
    let ok: Bool
    let iumrahID: String
    let sessionsRevoked: Bool
}

struct IumrahTerminateSessionResponse: Decodable {
    let ok: Bool
    let signedOut: Bool
}

struct IumrahAccountTripDetailResponse: Decodable {
    let ok: Bool
    let trip: ClientTripSnapshot
    let booking: RemoteBooking
    let assignment: ClientBookingAssignment?
    let esims: [ClientESIMProfile]?
    let statusHistory: [BookingStatusHistoryEntry]?
}

struct IumrahAccountLinkBookingRequest: Encodable {
    let bookingID: String
}

struct IumrahAccountLinkBookingResponse: Decodable {
    let ok: Bool
    let pilgrimID: String
    let bookingNumber: Int?
    let bookingDisplayNumber: String?
}
