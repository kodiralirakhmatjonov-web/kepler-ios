import SwiftUI

struct AppStoreUpdateSheet: View {
    let update: AppStoreUpdateInfo
    let language: AppSettingsStore.Language
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var openingStore = false
    @State private var showOpenError = false

    var body: some View {
        ScrollView {
            updateDetails
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionButtons
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(520), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Color(uiColor: .systemBackground))
        .alert(copy.openErrorTitle, isPresented: $showOpenError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(copy.openErrorMessage)
        }
    }

    private var updateDetails: some View {
        VStack(spacing: 18) {
            Image("AppUpdateIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                .accessibilityLabel("Iumrah")

            VStack(spacing: 10) {
                Text(copy.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                Text(copy.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { versionLabels }
                VStack(spacing: 8) { versionLabels }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.045), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(copy.versions(current: update.currentVersion, available: update.storeVersion))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.top, 30)
        .padding(.bottom, 20)
    }

    private var actionButtons: some View {
        VStack(spacing: 4) {
            Button(action: openAppStore) {
                HStack(spacing: 12) {
                    AppStoreMark()
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 30, height: 30)
                        .accessibilityHidden(true)

                    VStack(spacing: 2) {
                        Text(copy.updateButton)
                            .font(.system(.headline, design: .rounded))
                        Text("App Store")
                            .font(.caption)
                            .opacity(0.9)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color(uiColor: .systemBlue), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(openingStore)
            .accessibilityIdentifier("appStoreUpdate.openStore")
            .accessibilityLabel(copy.updateButton + ", App Store")

            Button(copy.laterButton, action: onDismiss)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("appStoreUpdate.later")
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var versionLabels: some View {
        Text(update.currentVersion).foregroundStyle(.secondary)
        Image(systemName: "arrow.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        Text(update.storeVersion).foregroundStyle(Color(uiColor: .systemBlue))
    }

    private func openAppStore() {
        guard !openingStore else { return }
        openingStore = true
        // HTTPS is handled by iOS and opens this product in the user's App Store.
        // A failed open keeps the sheet available, with a retryable explanation.
        openURL(update.storeURL) { accepted in
            openingStore = false
            if accepted { onDismiss() } else { showOpenError = true }
        }
    }

    private var copy: Copy {
        switch language {
        case .russian:
            return Copy(
                title: "Обновление Iumrah",
                message: "В App Store доступна новая версия. Обновите приложение, чтобы пользоваться последними улучшениями.",
                updateButton: "Обновить", laterButton: "Позже",
                openErrorTitle: "Не удалось открыть App Store",
                openErrorMessage: "Попробуйте ещё раз или найдите Iumrah в App Store.",
                currentLabel: "Установлена версия", availableLabel: "Доступна версия"
            )
        case .uzbek:
            return Copy(
                title: "Iumrah yangilanishi",
                message: "App Store’da yangi versiya mavjud. Eng so‘nggi yaxshilanishlardan foydalanish uchun ilovani yangilang.",
                updateButton: "Yangilash", laterButton: "Keyinroq",
                openErrorTitle: "App Store ochilmadi",
                openErrorMessage: "Qayta urinib ko‘ring yoki App Store’dan Iumrah’ni toping.",
                currentLabel: "O‘rnatilgan versiya", availableLabel: "Yangi versiya"
            )
        case .uzbekCyrillic:
            return Copy(
                title: "Iumrah янгиланиши",
                message: "App Store’да янги версия мавжуд. Энг сўнгги яхшиланишлардан фойдаланиш учун иловани янгиланг.",
                updateButton: "Янгилаш", laterButton: "Кейинроқ",
                openErrorTitle: "App Store очилмади",
                openErrorMessage: "Қайта уриниб кўринг ёки App Store’дан Iumrah’ни топинг.",
                currentLabel: "Ўрнатилган версия", availableLabel: "Янги версия"
            )
        case .english:
            return Copy(
                title: "Iumrah update",
                message: "A new version is available on the App Store. Update the app to enjoy the latest improvements.",
                updateButton: "Update", laterButton: "Later",
                openErrorTitle: "Couldn’t open the App Store",
                openErrorMessage: "Try again or search for Iumrah in the App Store.",
                currentLabel: "Installed version", availableLabel: "Available version"
            )
        }
    }

    private struct Copy {
        let title: String
        let message: String
        let updateButton: String
        let laterButton: String
        let openErrorTitle: String
        let openErrorMessage: String
        let currentLabel: String
        let availableLabel: String

        func versions(current: String, available: String) -> String {
            "\(currentLabel) \(current). \(availableLabel) \(available)."
        }
    }
}

/// Scalable App Store A mark. This is separate from the Apple corporate logo.
private struct AppStoreMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        path.move(to: point(0.59, 0.18))
        path.addLine(to: point(0.29, 0.70))
        path.move(to: point(0.41, 0.18))
        path.addLine(to: point(0.77, 0.81))
        path.move(to: point(0.17, 0.64))
        path.addLine(to: point(0.61, 0.64))
        path.move(to: point(0.73, 0.64))
        path.addLine(to: point(0.84, 0.64))
        path.move(to: point(0.23, 0.81))
        path.addLine(to: point(0.25, 0.77))
        return path
    }
}
