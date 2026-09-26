import AuthenticationServices
import SwiftUI

/// Keeps Apple's authorization flow native while the visible label follows the
/// language selected inside iumrah instead of the device language.
struct IumrahLocalizedAppleAuthButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var isDisabled = false
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.continue, onRequest: onRequest, onCompletion: onCompletion)
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: IumrahDesign.controlHeight)
            .overlay {
                ZStack {
                    RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white : Color.black)

                    HStack(spacing: 11) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20, weight: .semibold))
                        Text(title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                    .padding(.horizontal, 18)
                }
                .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.48 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
    }
}
