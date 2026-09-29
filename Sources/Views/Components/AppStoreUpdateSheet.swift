import SwiftUI

struct AppStoreUpdateSheet: View {
    let update: AppStoreUpdateService.Update
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 38, height: 5)
                .padding(.top, 10)

            Image("OnboardingBrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                .padding(.top, 26)

            Text(copy.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            Text(copy.message)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 28)
                .padding(.top, 10)

            HStack(spacing: 8) {
                Text("v\(update.currentVersion)")
                Image(systemName: "arrow.right")
                Text("v\(update.storeVersion)")
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.top, 16)

            Button {
                openURL(update.storeURL)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 21, weight: .semibold))
                    Text(copy.updateButton)
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.top, 24)

            Button(copy.laterButton, action: onDismiss)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 18)
        }
        .presentationDetents([.height(470)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(34)
        .presentationBackground(.regularMaterial)
    }

    private var copy: Copy {
        let language = locale.language.languageCode?.identifier ?? "en"
        switch language {
        case "ru":
            return .init(title: "Доступно обновление", message: "Новая версия iumrah уже в App Store. Обновитесь, чтобы получить последние улучшения и исправления.", updateButton: "Обновить в App Store", laterButton: "Позже")
        case "uz":
            return .init(title: "Yangi versiya mavjud", message: "iumrah’ning yangi versiyasi App Store’da. Eng so‘nggi yaxshilanishlar va tuzatishlarni olish uchun yangilang.", updateButton: "App Store’da yangilash", laterButton: "Keyinroq")
        default:
            return .init(title: "Update available", message: "A new version of iumrah is available on the App Store. Update for the latest improvements and fixes.", updateButton: "Update on App Store", laterButton: "Later")
        }
    }

    private struct Copy {
        let title: String
        let message: String
        let updateButton: String
        let laterButton: String
    }
}
