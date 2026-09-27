import AuthenticationServices
import SwiftUI

/// Native Sign in with Apple authorization with iumrah-localized visible copy.
/// Geometry intentionally matches IumrahGoogleAuthButton exactly: 56pt height
/// and the same 19pt continuous corner radius.
struct IumrahLocalizedAppleAuthButton: View {
    let title: String
    var isDisabled = false
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.continue, onRequest: onRequest, onCompletion: onCompletion)
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous)
                    .fill(Color.black)
                    .overlay {
                        HStack(spacing: 11) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 21, weight: .semibold))
                            Text(title)
                                .font(.system(size: 19, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 20)
                    }
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.46 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
    }
}
