import SwiftUI

/// Compatibility entry point retained for call sites that still open the old
/// email-security sheet. The production contact-security flow now owns all
/// re-authentication, verification and replacement semantics for linked email.
struct IumrahEmailVerificationView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore

    let existingEmail: String?

    var body: some View {
        IumrahAccountContactSecurityView(
            kind: .email,
            currentValue: existingEmail ?? ""
        )
        .environmentObject(account)
        .environmentObject(settings)
    }
}
