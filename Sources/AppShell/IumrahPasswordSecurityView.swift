import SwiftUI

struct IumrahPasswordSecurityView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showRecovery = false
    @State private var completed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                header

                if completed {
                    successCard
                } else {
                    passwordCard
                    sessionNotice

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.red.opacity(0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Button {
                        Task { await changePassword() }
                    } label: {
                        HStack {
                            if isWorking { ProgressView().tint(.white) }
                            Text(tr("Change password", "Изменить пароль", "Parolni o‘zgartirish", "Паролни ўзгартириш"))
                            Spacer()
                            if !isWorking { Image(systemName: "checkmark.shield.fill") }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                    .disabled(!canSubmit || isWorking)

                    Button {
                        showRecovery = true
                    } label: {
                        Text(tr("Forgot password?", "Забыли пароль?", "Parolni unutdingizmi?", "Паролни унутдингизми?"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(tr("Password", "Пароль", "Parol", "Парол"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showRecovery) {
            IumrahPasswordRecoveryView()
                .environmentObject(account)
                .environmentObject(settings)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.black).frame(width: 72, height: 72)
                Image(systemName: "key.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.14), radius: 16, y: 7)

            Text(tr("Password security", "Безопасность пароля", "Parol xavfsizligi", "Парол хавфсизлиги"))
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text(tr(
                "Use a password that you do not reuse on other services.",
                "Используйте пароль, который не повторяется в других сервисах.",
                "Boshqa xizmatlarda ishlatilmaydigan paroldan foydalaning.",
                "Бошқа хизматларда ишлатилмайдиган паролдан фойдаланинг."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var passwordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            secureField(tr("Current password", "Текущий пароль", "Joriy parol", "Жорий парол"), text: $currentPassword)
            secureField(tr("New password", "Новый пароль", "Yangi parol", "Янги парол"), text: $newPassword)
            secureField(tr("Repeat new password", "Повторите новый пароль", "Yangi parolni takrorlang", "Янги паролни такрорланг"), text: $confirmPassword)

            VStack(alignment: .leading, spacing: 6) {
                requirementRow(
                    met: newPassword.count >= 8,
                    text: tr("At least 8 characters", "Не менее 8 символов", "Kamida 8 ta belgi", "Камида 8 та белги")
                )
                requirementRow(
                    met: !newPassword.isEmpty && newPassword == confirmPassword,
                    text: tr("Passwords match", "Пароли совпадают", "Parollar mos", "Пароллар мос")
                )
                requirementRow(
                    met: !newPassword.isEmpty && newPassword != currentPassword,
                    text: tr("Different from the current password", "Отличается от текущего пароля", "Joriy paroldan farq qiladi", "Жорий паролдан фарқ қилади")
                )
            }
            .padding(.top, 2)
        }
        .iumrahCard()
    }

    private var sessionNotice: some View {
        Label(
            tr(
                "After the password changes, other active sessions are signed out. This device stays signed in.",
                "После смены пароля остальные активные сеансы будут завершены. Это устройство останется в аккаунте.",
                "Parol o‘zgargach, boshqa faol seanslar tugatiladi. Bu qurilma akkauntda qoladi.",
                "Парол ўзгаргач, бошқа фаол сеанслар тугатилади. Бу қурилма аккаунтда қолади."
            ),
            systemImage: "rectangle.stack.badge.person.crop.fill"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 4)
    }

    private var successCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.iumrahCareLight)
            Text(tr("Password changed", "Пароль изменён", "Parol o‘zgartirildi", "Парол ўзгартирилди"))
                .font(.title2.bold())
            Text(tr(
                "Other sessions were signed out for security.",
                "Другие сеансы завершены для безопасности.",
                "Xavfsizlik uchun boshqa seanslar tugatildi.",
                "Хавфсизлик учун бошқа сеанслар тугатилди."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button {
                dismiss()
            } label: {
                Text(tr("Done", "Готово", "Tayyor", "Тайёр"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .iumrahCard()
    }

    private func secureField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .textContentType(.password)
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func requirementRow(met: Bool, text: String) -> some View {
        Label(text, systemImage: met ? "checkmark.circle.fill" : "circle")
            .font(.caption.weight(.medium))
            .foregroundStyle(met ? Color.iumrahCareLight : .secondary)
    }

    private var canSubmit: Bool {
        currentPassword.count >= 8 &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword &&
        newPassword != currentPassword
    }

    @MainActor
    private func changePassword() async {
        guard canSubmit, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await account.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            completed = true
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
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
