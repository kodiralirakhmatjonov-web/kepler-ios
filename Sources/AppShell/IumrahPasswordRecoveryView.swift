import SwiftUI

struct IumrahPasswordRecoveryView: View {
    private enum RecoveryStep {
        case email
        case code
        case newPassword
        case success
    }

    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: RecoveryStep = .email
    @State private var email = ""
    @State private var challengeID = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var restoredID = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerBadge

                    if step == .code {
                        confirmationVideoCard
                    }

                    switch step {
                    case .email:
                        emailContent
                    case .code:
                        codeContent
                    case .newPassword:
                        newPasswordContent
                    case .success:
                        successContent
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(IumrahDesign.pagePadding)
                .padding(.bottom, 30)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle(tr("Password recovery", "Восстановление пароля", "Parolni tiklash", "Паролни тиклаш"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close", "Закрыть", "Yopish", "Ёпиш")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var headerBadge: some View {
        IumrahIconBadge(
            systemName: badgeSystemName,
            role: badgeRole,
            size: 64,
            symbolSize: 28,
            cornerRadius: 20
        )
    }

    private var badgeSystemName: String {
        switch step {
        case .email: return "key.viewfinder"
        case .code: return "envelope.badge.shield.half.filled"
        case .newPassword: return "lock.rotation"
        case .success: return "checkmark.shield.fill"
        }
    }

    private var badgeRole: IumrahIconRole {
        step == .success ? .success : .security
    }

    private var confirmationVideoCard: some View {
        LoopingVideoView(resource: "password-recovery-confirmation", gravity: .resizeAspectFill)
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }

    private var emailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Reset with email", "Восстановление по почте", "Email orqali tiklash", "Email орқали тиклаш"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(tr(
                "Enter the verified email connected to your iumrah account. We will send a six-digit code.",
                "Введите подтверждённую почту, подключённую к аккаунту iumrah. Мы отправим шестизначный код.",
                "iumrah akkauntingizga ulangan tasdiqlangan emailni kiriting. Olti xonali kod yuboramiz.",
                "iumrah аккаунтингизга уланган тасдиқланган emailни киритинг. Олти хонали код юборамиз."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            field(icon: "envelope.fill") {
                TextField("name@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Button { Task { await sendCode() } } label: {
                HStack {
                    if isWorking { ProgressView().tint(.white) }
                    Text(tr("Send recovery code", "Отправить код", "Tiklash kodini yuborish", "Тиклаш кодини юбориш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(!email.contains("@") || isWorking)
        }
    }

    private var codeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Confirm your email", "Подтвердите почту", "Emailni tasdiqlang", "Emailни тасдиқланг"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(tr(
                "We sent a six-digit confirmation code to your email. Enter it below to continue to the password step.",
                "Мы отправили шестизначный код подтверждения на вашу почту. Введите его ниже, чтобы перейти к смене пароля.",
                "Emailingizga olti xonali tasdiqlash kodi yuborildi. Parol bosqichiga o‘tish uchun uni quyida kiriting.",
                "Emailингизга олти хонали тасдиқлаш коди юборилди. Парол босқичига ўтиш учун уни қуйида киритинг."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            infoPill

            field(icon: "number.square.fill") {
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.body.monospaced())
                    .onChange(of: code) { _, value in
                        code = String(value.filter(\.isNumber).prefix(6))
                    }
            }

            Button {
                errorMessage = nil
                step = .newPassword
            } label: {
                HStack {
                    Text(tr("Continue", "Продолжить", "Davom etish", "Давом этиш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(code.count != 6 || isWorking)

            Button {
                resetToEmailStep()
            } label: {
                Text(tr("Use another email", "Указать другую почту", "Boshqa emaildan foydalanish", "Бошқа emailдан фойдаланиш"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var newPasswordContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Create a new password", "Создайте новый пароль", "Yangi parol yarating", "Янги парол яратинг"))
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(tr(
                "Your email is confirmed. Choose a new password for the iumrah account linked to \(email).",
                "Почта подтверждена. Придумайте новый пароль для аккаунта iumrah, связанного с \(email).",
                "Email tasdiqlandi. \(email) bilan bog‘langan iumrah akkaunti uchun yangi parol yarating.",
                "Email тасдиқланди. \(email) билан боғланган iumrah аккаунти учун янги парол яратинг."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            field(icon: "lock.fill") {
                SecureField(tr("New password", "Новый пароль", "Yangi parol", "Янги парол"), text: $newPassword)
                    .textContentType(.newPassword)
            }

            field(icon: "lock.rotation") {
                SecureField(tr("Confirm password", "Повторите пароль", "Parolni takrorlang", "Паролни такрорланг"), text: $confirmPassword)
                    .textContentType(.newPassword)
            }

            Button { Task { await resetPassword() } } label: {
                HStack {
                    if isWorking { ProgressView().tint(.white) }
                    Text(tr("Set new password", "Установить новый пароль", "Yangi parol o‘rnatish", "Янги парол ўрнатиш"))
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(newPassword.count < 8 || newPassword != confirmPassword || isWorking)

            Button {
                errorMessage = nil
                step = .code
            } label: {
                Text(tr("Back to confirmation code", "Вернуться к коду подтверждения", "Tasdiqlash kodiga qaytish", "Тасдиқлаш кодига қайтиш"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var successContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Password updated", "Пароль изменён", "Parol yangilandi", "Парол янгиланди"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(tr(
                "All previous sessions were securely ended. Sign in again with your email or iumrah ID \(restoredID).",
                "Все предыдущие сеансы безопасно завершены. Войдите снова по почте или iumrah ID \(restoredID).",
                "Barcha oldingi seanslar xavfsiz tugatildi. Email yoki \(restoredID) iumrah ID bilan qayta kiring.",
                "Барча олдинги сеанслар хавфсиз тугатилди. Email ёки \(restoredID) iumrah ID билан қайта киринг."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(tr("Return to sign in", "Вернуться ко входу", "Kirishga qaytish", "Киришга қайтиш")) { dismiss() }
                .buttonStyle(IumrahPrimaryButtonStyle())
        }
    }

    private var infoPill: some View {
        Text(email.trimmingCharacters(in: .whitespacesAndNewlines))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private func field<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            content()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
    }

    private func resetToEmailStep() {
        step = .email
        challengeID = ""
        code = ""
        newPassword = ""
        confirmPassword = ""
        errorMessage = nil
    }

    @MainActor
    private func sendCode() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await account.startPasswordRecovery(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                locale: settings.language.rawValue
            )
            challengeID = response.challengeID
            code = ""
            newPassword = ""
            confirmPassword = ""
            step = .code
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func resetPassword() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await account.confirmPasswordRecovery(
                challengeID: challengeID,
                code: code,
                newPassword: newPassword
            )
            restoredID = response.iumrahID
            step = .success
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .turkish: return TurkishLocalization.phrase(en)
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
