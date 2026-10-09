import AuthenticationServices
import SwiftUI


enum IumrahSecurityContactKind: String, Identifiable {
    case phone
    case email

    var id: String { rawValue }
}

/// Production-grade sensitive-contact flow.
///
/// A linked contact is never replaced just because a user can type a new value.
/// The flow first re-verifies the owner using an existing account factor, then
/// verifies the new destination, and only then commits the replacement.
struct IumrahAccountContactSecurityView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let kind: IumrahSecurityContactKind
    let currentValue: String
    var onCompleted: ((String) -> Void)? = nil

    private enum Phase {
        case loading
        case ownership
        case edit
        case confirmNew
        case success
    }

    private enum ProofMethod: String, Identifiable {
        case password
        case phone
        case email
        case apple
        case google
        var id: String { rawValue }
    }

    @State private var phase: Phase = .loading
    @State private var overview: IumrahSecurityOverview?
    @State private var selectedProof: ProofMethod = .password
    @State private var currentPassword = ""
    @State private var proofChallengeID = ""
    @State private var proofDestination = ""
    @State private var proofCode = ""
    @State private var securityProof = ""
    @State private var appleNonce = ""
    @State private var isAuthorizingSocial = false
    @State private var showRecoveryHelp = false
    @State private var newValue = ""
    @State private var requestedValue = ""
    @State private var changeChallengeID = ""
    @State private var changeCode = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showPasswordRecovery = false
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case password
        case proofCode
        case newValue
        case changeCode
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    currentContactCard

                    switch phase {
                    case .loading:
                        ProgressView()
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 42)
                    case .ownership:
                        ownershipCard
                    case .edit:
                        newContactCard
                    case .confirmNew:
                        newContactCodeCard
                    case .success:
                        successCard
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.red.opacity(0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(phase == .success ? tr("Close", "Закрыть", "Yopish", "Ёпиш") : tr("Cancel", "Отмена", "Bekor qilish", "Бекор қилиш")) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $showPasswordRecovery) {
                IumrahPasswordRecoveryView()
                    .environmentObject(account)
                    .environmentObject(settings)
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .sheet(isPresented: $showRecoveryHelp) {
            IumrahAccountRecoveryHelpView {
                showRecoveryHelp = false
                dismiss()
                DispatchQueue.main.async { chrome.navigate(to: .care) }
            }
            .environmentObject(settings)
        }
        .task { await bootstrap() }
        .onChange(of: newValue) { _, _ in errorMessage = nil }
        .onChange(of: proofCode) { _, value in
            proofCode = String(value.filter(\.isNumber).prefix(6))
            errorMessage = nil
        }
        .onChange(of: changeCode) { _, value in
            changeCode = String(value.filter(\.isNumber).prefix(6))
            errorMessage = nil
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 72, height: 72)
                Image(systemName: kind == .phone ? "phone.badge.checkmark.fill" : "envelope.badge.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.14), radius: 16, y: 7)

            VStack(spacing: 5) {
                Text(headerTitle)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(headerBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var currentContactCard: some View {
        HStack(spacing: 13) {
            IumrahIconBadge(
                systemName: kind == .phone ? "phone.fill" : "envelope.fill",
                role: kind == .phone ? .phone : .mail,
                size: 46,
                symbolSize: 17,
                cornerRadius: 14
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(tr("Currently linked", "Сейчас привязано", "Hozir bog‘langan", "Ҳозир боғланган"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(currentDisplayValue)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            Label(
                currentIsVerified
                    ? tr("Verified", "Подтверждено", "Tasdiqlangan", "Тасдиқланган")
                    : (hasCurrentValue
                        ? tr("Needs verification", "Нужно подтвердить", "Tasdiqlash kerak", "Тасдиқлаш керак")
                        : tr("Not linked", "Не привязано", "Bog‘lanmagan", "Боғланмаган")),
                systemImage: currentIsVerified ? "checkmark.seal.fill" : (hasCurrentValue ? "exclamationmark.circle.fill" : "minus.circle.fill")
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(currentIsVerified ? Color.iumrahCareLight : (hasCurrentValue ? Color.orange : Color.secondary))
        }
        .iumrahCard()
    }

    private var ownershipCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                icon: "lock.shield.fill",
                title: tr("Confirm it’s you", "Подтвердите, что это Вы", "Bu siz ekaningizni tasdiqlang", "Бу сиз эканингизни тасдиқланг"),
                subtitle: tr(
                    "We verify the account owner before changing a linked contact.",
                    "Перед изменением привязанного контакта мы подтверждаем владельца аккаунта.",
                    "Bog‘langan kontaktni o‘zgartirishdan oldin akkaunt egasi tasdiqlanadi.",
                    "Боғланган контактни ўзгартиришдан олдин аккаунт эгаси тасдиқланади."
                )
            )

            proofMethodPicker

            Group {
                switch selectedProof {
                case .password:
                    passwordProofContent
                case .phone, .email:
                    otpProofContent
                case .apple:
                    appleProofContent
                case .google:
                    googleProofContent
                }
            }

            if hasRecoveryEmail {
                Button {
                    showPasswordRecovery = true
                } label: {
                    Text(tr("Forgot password?", "Забыли пароль?", "Parolni unutdingizmi?", "Паролни унутдингизми?"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            Button {
                showRecoveryHelp = true
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text(tr(
                        "No access to any verification method?",
                        "Нет доступа ни к одному способу?",
                        "Hech bir tasdiqlash usuliga kirish yo‘qmi?",
                        "Ҳеч бир тасдиқлаш усулига кириш йўқми?"
                    ))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            securityFootnote
        }
        .iumrahCard()
    }

    private var proofMethodPicker: some View {
        VStack(spacing: 8) {
            proofOption(.password, icon: "key.fill", title: tr("Password", "Пароль", "Parol", "Парол"), subtitle: tr("Use your current iumrah password", "Введите текущий пароль iumrah", "Joriy iumrah parolini kiriting", "Жорий iumrah паролини киритинг"), enabled: true)

            if let phone = overview?.loginPhone?.phone, !phone.isEmpty {
                proofOption(.phone, icon: "message.fill", title: tr("SMS code", "SMS-код", "SMS kod", "SMS-код"), subtitle: maskedPhone(phone), enabled: true)
            }

            if let email = overview?.loginEmail?.email, !email.isEmpty {
                proofOption(.email, icon: "envelope.fill", title: tr("Email code", "Код на почту", "Email kodi", "Email коди"), subtitle: maskedEmail(email), enabled: true)
            }

            if overview?.apple.linked == true {
                proofOption(.apple, icon: "apple.logo", title: "Sign in with Apple", subtitle: tr("Confirm with your connected Apple ID", "Подтвердить подключённым Apple ID", "Ulangan Apple ID bilan tasdiqlash", "Уланган Apple ID билан тасдиқлаш"), enabled: true)
            }

            if overview?.google?.linked == true {
                proofOption(.google, icon: "person.crop.circle.badge.checkmark", title: "Google", subtitle: tr("Confirm with your connected Google account", "Подтвердить подключённым Google-аккаунтом", "Ulangan Google akkaunti bilan tasdiqlash", "Уланган Google аккаунти билан тасдиқлаш"), enabled: true)
            }
        }
    }

    private func proofOption(_ method: ProofMethod, icon: String, title: String, subtitle: String, enabled: Bool) -> some View {
        Button {
            guard enabled else { return }
            selectedProof = method
            proofChallengeID = ""
            proofDestination = ""
            proofCode = ""
            currentPassword = ""
            errorMessage = nil
            focusedField = method == .password ? .password : nil
            IumrahHaptics.selection()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selectedProof == method ? Color.primary.opacity(0.10) : Color.primary.opacity(0.045))
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: selectedProof == method ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(selectedProof == method ? Color.iumrahCareLight : Color.secondary.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var passwordProofContent: some View {
        VStack(spacing: 12) {
            SecureField(tr("Current password", "Текущий пароль", "Joriy parol", "Жорий парол"), text: $currentPassword)
                .focused($focusedField, equals: .password)
                .textContentType(.password)
                .padding(.horizontal, 15)
                .frame(height: 54)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            Button {
                Task { await verifyPasswordOwner() }
            } label: {
                actionLabel(
                    title: tr("Continue", "Продолжить", "Davom etish", "Давом этиш"),
                    icon: "arrow.right"
                )
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(currentPassword.count < 8 || isWorking)
        }
    }

    private var otpProofContent: some View {
        VStack(spacing: 12) {
            if proofChallengeID.isEmpty {
                Button {
                    Task { await sendOwnershipCode() }
                } label: {
                    actionLabel(
                        title: selectedProof == .phone
                            ? tr("Send SMS code", "Отправить SMS-код", "SMS kod yuborish", "SMS код юбориш")
                            : tr("Send email code", "Отправить код на почту", "Email kod yuborish", "Email код юбориш"),
                        icon: "paperplane.fill"
                    )
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isWorking)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr(
                        "Code sent to %@",
                        "Код отправлен на %@",
                        "Kod %@ manziliga yuborildi",
                        "Код %@ манзилига юборилди"
                    ).replacingOccurrences(of: "%@", with: proofDestination))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    codeField(text: $proofCode, focus: .proofCode)
                }

                Button {
                    Task { await confirmOwnershipCode() }
                } label: {
                    actionLabel(title: tr("Confirm", "Подтвердить", "Tasdiqlash", "Тасдиқлаш"), icon: "checkmark.shield.fill")
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(proofCode.count != 6 || isWorking)

                Button {
                    proofChallengeID = ""
                    proofCode = ""
                    proofDestination = ""
                    errorMessage = nil
                } label: {
                    Text(tr("Use another method", "Выбрать другой способ", "Boshqa usulni tanlash", "Бошқа усулни танлаш"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appleProofContent: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.continue) { request in
                do {
                    appleNonce = try IumrahAppleSignInSupport.prepare(request)
                    errorMessage = nil
                    isAuthorizingSocial = true
                } catch {
                    errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
                }
            } onCompletion: { result in
                Task { @MainActor in
                    defer { isAuthorizingSocial = false }
                    do {
                        let authorization = try result.get()
                        let credential = try IumrahAppleSignInSupport.credential(from: authorization, nonce: appleNonce)
                        let response = try await account.authorizeSensitiveActionWithApple(credential)
                        acceptSensitiveAuthorization(response)
                    } catch let error as ASAuthorizationError where error.code == .canceled {
                        errorMessage = nil
                    } catch {
                        errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
                        IumrahHaptics.error()
                    }
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .disabled(isAuthorizingSocial || isWorking)

            Text(tr(
                "Apple confirms the same linked account. It does not create a new iumrah profile.",
                "Apple подтверждает тот же подключённый аккаунт и не создаёт новый профиль iumrah.",
                "Apple aynan ulangan akkauntni tasdiqlaydi va yangi iumrah profili yaratmaydi.",
                "Apple айнан уланган аккаунтни тасдиқлайди ва янги iumrah профили яратмайди."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var googleProofContent: some View {
        VStack(spacing: 10) {
            Button {
                Task { await authorizeWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    if isAuthorizingSocial { ProgressView().controlSize(.small) }
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text(tr("Continue with Google", "Продолжить через Google", "Google orqali davom etish", "Google орқали давом этиш"))
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
            .disabled(isAuthorizingSocial || isWorking)

            Text(tr(
                "Google confirms the same linked account. It does not create a new iumrah profile.",
                "Google подтверждает тот же подключённый аккаунт и не создаёт новый профиль iumrah.",
                "Google aynan ulangan akkauntni tasdiqlaydi va yangi iumrah profili yaratmaydi.",
                "Google айнан уланган аккаунтни тасдиқлайди ва янги iumrah профили яратмайди."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var newContactCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                icon: kind == .phone ? "phone.arrow.up.right" : "envelope.arrow.triangle.branch",
                title: newContactTitle,
                subtitle: newContactSubtitle
            )

            HStack(spacing: 12) {
                Image(systemName: kind == .phone ? "phone.fill" : "envelope.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                TextField(kind == .phone ? "+998 00 000 00 00" : "name@example.com", text: $newValue)
                    .focused($focusedField, equals: .newValue)
                    .keyboardType(kind == .phone ? .phonePad : .emailAddress)
                    .textContentType(kind == .phone ? .telephoneNumber : .emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: newValue) { _, value in
                        if kind == .phone { newValue = Self.formatPhone(value) }
                    }
            }
            .padding(.horizontal, 15)
            .frame(height: 56)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            Text(newContactSecurityText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await sendNewContactCode() }
            } label: {
                actionLabel(
                    title: tr("Send verification code", "Отправить код подтверждения", "Tasdiqlash kodini yuborish", "Тасдиқлаш кодини юбориш"),
                    icon: "paperplane.fill"
                )
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(!newValueIsValid || isSameAsCurrent || isWorking)
        }
        .iumrahCard()
        .onAppear {
            if newValue.isEmpty {
                newValue = kind == .phone ? "+998" : ""
            }
            focusedField = .newValue
        }
    }

    private var newContactCodeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                icon: "number.square.fill",
                title: tr("Verification code", "Код подтверждения", "Tasdiqlash kodi", "Тасдиқлаш коди"),
                subtitle: tr(
                    "Confirm the new contact before it replaces the old one.",
                    "Подтвердите новый контакт, прежде чем он заменит старый.",
                    "Yangi kontakt eskisini almashtirishidan oldin uni tasdiqlang.",
                    "Янги контакт эскисини алмаштиришидан олдин уни тасдиқланг."
                )
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(requestedValue)
                    .font(.subheadline.weight(.bold))
                Text(tr(
                    "The code is valid for a limited time. Until it is confirmed, your current contact remains active.",
                    "Код действует ограниченное время. Пока он не подтверждён, текущий контакт остаётся активным.",
                    "Kod cheklangan vaqt amal qiladi. Tasdiqlanmaguncha joriy kontakt faol bo‘lib qoladi.",
                    "Код чекланган вақт амал қилади. Тасдиқланмагунча жорий контакт фаол бўлиб қолади."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            codeField(text: $changeCode, focus: .changeCode)

            Button {
                Task { await confirmNewContact() }
            } label: {
                actionLabel(title: tr("Confirm change", "Подтвердить изменение", "O‘zgarishni tasdiqlash", "Ўзгаришни тасдиқлаш"), icon: "checkmark.shield.fill")
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(changeCode.count != 6 || isWorking)

            Button {
                phase = .edit
                changeChallengeID = ""
                changeCode = ""
                errorMessage = nil
            } label: {
                Text(tr("Change the new contact", "Изменить новый контакт", "Yangi kontaktni o‘zgartirish", "Янги контактни ўзгартириш"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .iumrahCard()
    }

    private var successCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.iumrahCareLight)

            VStack(spacing: 5) {
                Text(tr("Updated securely", "Изменено безопасно", "Xavfsiz yangilandi", "Хавфсиз янгиланди"))
                    .font(.title2.bold())
                Text(successBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

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

    private var securityFootnote: some View {
        Label(
            tr(
                "A code sent only to a new phone or email is not enough to take over an account. Ownership is confirmed first using an existing trusted factor.",
                "Кода, отправленного только на новый номер или почту, недостаточно для смены владельца аккаунта. Сначала подтверждается существующий доверенный способ.",
                "Faqat yangi telefon yoki emailga yuborilgan kod akkauntni egallash uchun yetarli emas. Avval mavjud ishonchli usul tasdiqlanadi.",
                "Фақат янги телефон ёки emailга юборилган код аккаунтни эгаллаш учун етарли эмас. Аввал мавжуд ишончли усул тасдиқланади."
            ),
            systemImage: "hand.raised.fill"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, role: .security, size: 42, symbolSize: 16, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func codeField(text: Binding<String>, focus: FocusField) -> some View {
        TextField("000000", text: text)
            .focused($focusedField, equals: focus)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .font(.system(size: 25, weight: .bold, design: .monospaced))
            .multilineTextAlignment(.center)
            .tracking(8)
            .padding(.horizontal, 15)
            .frame(height: 58)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func actionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            if isWorking { ProgressView().tint(.white) }
            Text(title)
            Spacer(minLength: 8)
            if !isWorking { Image(systemName: icon) }
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    private func bootstrap() async {
        do {
            overview = try await account.securityOverview(locale: settings.language.rawValue)
            selectedProof = preferredProofMethod
            phase = .ownership
            errorMessage = nil
        } catch {
            phase = .ownership
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
        }
    }

    @MainActor
    private func verifyPasswordOwner() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let authorization = try await account.authorizeSensitiveAction(password: currentPassword)
            acceptSensitiveAuthorization(authorization)
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func sendOwnershipCode() async {
        guard selectedProof == .phone || selectedProof == .email, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await account.startPrimaryRecovery(method: selectedProof.rawValue, locale: settings.language.rawValue)
            proofChallengeID = response.challengeID
            proofDestination = response.maskedDestination
            proofCode = ""
            focusedField = .proofCode
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func confirmOwnershipCode() async {
        guard !proofChallengeID.isEmpty, proofCode.count == 6, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let authorization = try await account.confirmPrimaryRecovery(method: selectedProof.rawValue, challengeID: proofChallengeID, code: proofCode)
            acceptSensitiveAuthorization(authorization)
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func authorizeWithGoogle() async {
        guard !isAuthorizingSocial else { return }
        isAuthorizingSocial = true
        errorMessage = nil
        defer { isAuthorizingSocial = false }
        do {
            let credential = try await IumrahGoogleSignInSupport.signIn()
            let response = try await account.authorizeSensitiveActionWithGoogle(credential)
            acceptSensitiveAuthorization(response)
        } catch where IumrahGoogleSignInSupport.isCancellation(error) {
            errorMessage = nil
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func acceptSensitiveAuthorization(_ authorization: IumrahSensitiveAuthorizationResponse) {
        overview = authorization.overview
        securityProof = authorization.securityProof
        proofCode = ""
        currentPassword = ""
        phase = .edit
        IumrahHaptics.success()
    }

    @MainActor
    private func sendNewContactCode() async {
        guard newValueIsValid, !isSameAsCurrent, !isWorking else { return }
        guard !securityProof.isEmpty else {
            phase = .ownership
            errorMessage = tr(
                "For security, confirm the account owner again.",
                "Для безопасности снова подтвердите владельца аккаунта.",
                "Xavfsizlik uchun akkaunt egasini yana tasdiqlang.",
                "Хавфсизлик учун аккаунт эгасини яна тасдиқланг."
            )
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            switch kind {
            case .phone:
                let response = try await account.startPhoneVerification(
                    phone: Self.normalizedPhone(newValue),
                    locale: settings.language.rawValue,
                    securityProof: securityProof
                )
                changeChallengeID = response.challengeID
                requestedValue = response.phone
            case .email:
                let email = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let response = try await account.startEmailVerification(
                    email: email,
                    locale: settings.language.rawValue,
                    securityProof: securityProof
                )
                changeChallengeID = response.challengeID
                requestedValue = email
            }
            changeCode = ""
            phase = .confirmNew
            focusedField = .changeCode
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func confirmNewContact() async {
        guard !changeChallengeID.isEmpty, changeCode.count == 6, !isWorking else { return }
        guard !securityProof.isEmpty else {
            phase = .ownership
            errorMessage = tr(
                "For security, confirm the account owner again.",
                "Для безопасности снова подтвердите владельца аккаунта.",
                "Xavfsizlik uchun akkaunt egasini yana tasdiqlang.",
                "Хавфсизлик учун аккаунт эгасини яна тасдиқланг."
            )
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let finalValue: String
            switch kind {
            case .phone:
                let response = try await account.confirmPhoneVerification(
                    challengeID: changeChallengeID,
                    code: changeCode,
                    securityProof: securityProof
                )
                finalValue = response.phone
            case .email:
                let response = try await account.confirmEmailVerification(
                    challengeID: changeChallengeID,
                    code: changeCode,
                    securityProof: securityProof
                )
                finalValue = response.email
            }
            onCompleted?(finalValue)
            requestedValue = finalValue
            securityProof = ""
            phase = .success
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    private var preferredProofMethod: ProofMethod {
        if kind == .phone, overview?.loginEmail != nil { return .email }
        if kind == .email, overview?.loginPhone != nil { return .phone }
        if overview?.loginPhone != nil { return .phone }
        if overview?.loginEmail != nil { return .email }
        return .password
    }

    private var hasRecoveryEmail: Bool { overview?.loginEmail != nil }

    private var verifiedCurrentValue: String? {
        switch kind {
        case .phone: return overview?.loginPhone?.phone
        case .email: return overview?.loginEmail?.email
        }
    }

    private var currentIsVerified: Bool {
        guard let value = verifiedCurrentValue else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasCurrentValue: Bool {
        !currentDisplayRawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentDisplayRawValue: String {
        let verified = verifiedCurrentValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return verified.isEmpty ? currentValue : verified
    }

    private var currentDisplayValue: String {
        hasCurrentValue ? currentDisplayRawValue : tr("Not linked", "Не привязано", "Bog‘lanmagan", "Боғланмаган")
    }

    private var title: String {
        kind == .phone
            ? tr("Linked phone", "Привязанный номер", "Bog‘langan telefon", "Боғланган телефон")
            : tr("Linked email", "Привязанная почта", "Bog‘langan email", "Боғланган email")
    }

    private var headerTitle: String {
        switch phase {
        case .loading, .ownership:
            return tr("Protected account contact", "Защищённый контакт аккаунта", "Himoyalangan akkaunt kontakti", "Ҳимояланган аккаунт контакти")
        case .edit:
            return newContactTitle
        case .confirmNew:
            return tr("Confirm the new contact", "Подтвердите новый контакт", "Yangi kontaktni tasdiqlang", "Янги контактни тасдиқланг")
        case .success:
            return tr("Security updated", "Безопасность обновлена", "Xavfsizlik yangilandi", "Хавфсизлик янгиланди")
        }
    }

    private var headerBody: String {
        switch phase {
        case .loading:
            return tr("Checking account security…", "Проверяем безопасность аккаунта…", "Akkaunt xavfsizligi tekshirilmoqda…", "Аккаунт хавфсизлиги текширилмоқда…")
        case .ownership:
            return tr(
                "First verify the current owner. Then we will verify the new contact.",
                "Сначала подтвердите текущего владельца. После этого мы подтвердим новый контакт.",
                "Avval joriy egani tasdiqlang. Keyin yangi kontakt tasdiqlanadi.",
                "Аввал жорий эгани тасдиқланг. Кейин янги контакт тасдиқланади."
            )
        case .edit:
            return newContactSubtitle
        case .confirmNew:
            return tr("Nothing changes until the six-digit code is accepted.", "Ничего не изменится, пока шестизначный код не будет подтверждён.", "Olti xonali kod tasdiqlanmaguncha hech narsa o‘zgarmaydi.", "Олти хонали код тасдиқланмагунча ҳеч нарса ўзгармайди.")
        case .success:
            return successBody
        }
    }

    private var newContactTitle: String {
        kind == .phone
            ? tr("New phone number", "Новый номер телефона", "Yangi telefon raqami", "Янги телефон рақами")
            : tr("New email", "Новая почта", "Yangi email", "Янги email")
    }

    private var newContactSubtitle: String {
        kind == .phone
            ? tr("Enter the number you want to use for sign-in and recovery.", "Введите номер, который будет использоваться для входа и восстановления.", "Kirish va tiklash uchun ishlatiladigan raqamni kiriting.", "Кириш ва тиклаш учун ишлатиладиган рақамни киритинг.")
            : tr("Enter the address you want to use for sign-in and recovery.", "Введите почту, которая будет использоваться для входа и восстановления.", "Kirish va tiklash uchun ishlatiladigan emailni kiriting.", "Кириш ва тиклаш учун ишлатиладиган emailни киритинг.")
    }

    private var newContactSecurityText: String {
        kind == .phone
            ? tr("A six-digit SMS code will be sent to the new number. The old number stays linked until the code is confirmed.", "На новый номер придёт 6-значный SMS-код. Старый номер останется привязанным до подтверждения кода.", "Yangi raqamga 6 xonali SMS kod yuboriladi. Kod tasdiqlanmaguncha eski raqam bog‘langan holda qoladi.", "Янги рақамга 6 хонали SMS код юборилади. Код тасдиқланмагунча эски рақам боғланган ҳолда қолади.")
            : tr("A six-digit code will be sent to the new email. The old email stays linked until the code is confirmed.", "На новую почту придёт 6-значный код. Старая почта останется привязанной до подтверждения кода.", "Yangi emailga 6 xonali kod yuboriladi. Kod tasdiqlanmaguncha eski email bog‘langan holda qoladi.", "Янги emailга 6 хонали код юборилади. Код тасдиқланмагунча эски email боғланган ҳолда қолади.")
    }

    private var successBody: String {
        let value = requestedValue.isEmpty ? newValue : requestedValue
        return kind == .phone
            ? tr("%@ is now your verified phone for this iumrah account.", "%@ теперь подтверждённый номер этого аккаунта iumrah.", "%@ endi ushbu iumrah akkaunti uchun tasdiqlangan raqam.", "%@ энди ушбу iumrah аккаунти учун тасдиқланган рақам.").replacingOccurrences(of: "%@", with: value)
            : tr("%@ is now your verified email for this iumrah account.", "%@ теперь подтверждённая почта этого аккаунта iumrah.", "%@ endi ushbu iumrah akkaunti uchun tasdiqlangan email.", "%@ энди ушбу iumrah аккаунти учун тасдиқланган email.").replacingOccurrences(of: "%@", with: value)
    }

    private var newValueIsValid: Bool {
        switch kind {
        case .phone:
            return Self.normalizedPhone(newValue).filter(\.isNumber).count == 12 && Self.normalizedPhone(newValue).hasPrefix("+998")
        case .email:
            let value = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.contains("@") && value.contains(".") && !value.contains(" ")
        }
    }

    private var isSameAsCurrent: Bool {
        guard currentIsVerified else { return false }
        let existing = verifiedCurrentValue ?? currentDisplayRawValue
        switch kind {
        case .phone:
            return Self.normalizedPhone(newValue) == Self.normalizedPhone(existing)
        case .email:
            return newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                == existing.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    private func maskedPhone(_ raw: String) -> String {
        let value = Self.normalizedPhone(raw)
        guard value.count > 8 else { return value }
        return String(value.prefix(4)) + " •••• " + String(value.suffix(4))
    }

    private func maskedEmail(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = value.firstIndex(of: "@") else { return value }
        let local = String(value[..<at])
        let domain = String(value[value.index(after: at)...])
        let prefix = String(local.prefix(min(2, max(1, local.count))))
        return prefix + "•••@" + domain
    }

    private static func normalizedPhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        if digits.hasPrefix("998") { return "+" + String(digits.prefix(12)) }
        return "+998" + String(digits.suffix(9))
    }

    private static func formatPhone(_ raw: String) -> String {
        normalizedPhone(raw)
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

private struct IumrahAccountRecoveryHelpView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    let openCare: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 76, height: 76)
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 29, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)

                        Text(tr("Recover account access", "Восстановление доступа", "Akkauntga kirishni tiklash", "Аккаунтга киришни тиклаш"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text(tr(
                            "If you cannot use the current phone, verified email, password, Apple or Google, iumrah will not instantly replace your account contacts.",
                            "Если у Вас нет доступа к текущему номеру, подтверждённой почте, паролю, Apple или Google, iumrah не будет мгновенно заменять контакты аккаунта.",
                            "Agar joriy telefon, tasdiqlangan email, parol, Apple yoki Google mavjud bo‘lmasa, iumrah akkaunt kontaktlarini darhol almashtirmaydi.",
                            "Агар жорий телефон, тасдиқланган email, парол, Apple ёки Google мавжуд бўлмаса, iumrah аккаунт контактларини дарҳол алмаштирмайди."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        recoveryStep("1", icon: "person.text.rectangle.fill", title: tr("Confirm the account owner", "Подтвердить владельца", "Akkaunt egasini tasdiqlash", "Аккаунт эгасини тасдиқлаш"), body: tr("Support checks the account and linked trip information before any contact is changed.", "Поддержка проверяет аккаунт и связанные данные поездки до изменения контактов.", "Kontakt o‘zgartirilishidan oldin yordam xizmati akkaunt va bog‘langan safar ma’lumotlarini tekshiradi.", "Контакт ўзгартирилишидан олдин ёрдам хизмати аккаунт ва боғланган сафар маълумотларини текширади."))
                        recoveryStep("2", icon: "lock.shield.fill", title: tr("Protect existing access", "Сохранить существующий доступ", "Mavjud kirishni himoyalash", "Мавжуд киришни ҳимоялаш"), body: tr("Active sessions and linked contacts are not silently replaced while recovery is being reviewed.", "Во время проверки активные сеансы и привязанные контакты не заменяются скрытно.", "Tiklash tekshirilayotgan paytda faol seanslar va bog‘langan kontaktlar yashirincha almashtirilmaydi.", "Тиклаш текширилаётган пайтда фаол сеанслар ва боғланган контактлар яширинча алмаштирилмайди."))
                        recoveryStep("3", icon: "checkmark.shield.fill", title: tr("Restore a trusted method", "Восстановить доверенный способ", "Ishonchli usulni tiklash", "Ишончли усулни тиклаш"), body: tr("After ownership is verified, support can guide you through restoring a verified sign-in method.", "После проверки владельца поддержка поможет восстановить подтверждённый способ входа.", "Ega tasdiqlangach, yordam xizmati tasdiqlangan kirish usulini tiklashga yordam beradi.", "Эга тасдиқлангач, ёрдам хизмати тасдиқланган кириш усулини тиклашга ёрдам беради."))
                    }
                    .iumrahCard()

                    Button {
                        dismiss()
                        DispatchQueue.main.async { openCare() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.fill")
                            Text(tr("Open iumrah Care", "Открыть iumrah Care", "iumrah Care’ni ochish", "iumrah Care’ни очиш"))
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())

                    Label(
                        tr(
                            "Never share SMS codes, email codes or your password with support staff.",
                            "Никогда не сообщайте сотрудникам поддержки SMS-коды, коды из почты или пароль.",
                            "Yordam xodimlariga SMS kod, email kod yoki parolni hech qachon bermang.",
                            "Ёрдам ходимларига SMS код, email код ёки паролни ҳеч қачон берманг."
                        ),
                        systemImage: "exclamationmark.shield.fill"
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(IumrahDesign.pagePadding)
                .padding(.bottom, 28)
            }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .navigationTitle(tr("Account recovery", "Восстановление аккаунта", "Akkauntni tiklash", "Аккаунтни тиклаш"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close", "Закрыть", "Yopish", "Ёпиш")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func recoveryStep(_ number: String, icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(number)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.subheadline.weight(.bold))
                }
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

/// Reusable owner-verification sheet for operations such as trusting the current
/// device before managing other sessions or connecting/disconnecting providers.
struct IumrahTrustedDeviceVerificationView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    let overview: IumrahSecurityOverview
    let onVerified: (IumrahSecurityOverview) -> Void

    private enum Method: String, Identifiable {
        case password
        case phone
        case email
        var id: String { rawValue }
    }

    @State private var method: Method = .password
    @State private var password = ""
    @State private var challengeID = ""
    @State private var destination = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.black).frame(width: 72, height: 72)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text(tr("Confirm this device", "Подтвердите это устройство", "Bu qurilmani tasdiqlang", "Бу қурилмани тасдиқланг"))
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                        Text(tr(
                            "Re-verify the account owner. This device will become the protected device for sensitive account actions.",
                            "Повторно подтвердите владельца аккаунта. Это устройство станет защищённым для важных действий с аккаунтом.",
                            "Akkaunt egasini qayta tasdiqlang. Bu qurilma muhim akkaunt amallari uchun himoyalangan qurilmaga aylanadi.",
                            "Аккаунт эгасини қайта тасдиқланг. Бу қурилма муҳим аккаунт амаллари учун ҳимояланган қурилмага айланади."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 8) {
                        methodRow(.password, icon: "key.fill", title: tr("Password", "Пароль", "Parol", "Парол"), subtitle: tr("Current iumrah password", "Текущий пароль iumrah", "Joriy iumrah paroli", "Жорий iumrah пароли"))
                        if let phone = overview.loginPhone?.phone {
                            methodRow(.phone, icon: "message.fill", title: tr("SMS code", "SMS-код", "SMS kod", "SMS-код"), subtitle: maskPhone(phone))
                        }
                        if let email = overview.loginEmail?.email {
                            methodRow(.email, icon: "envelope.fill", title: tr("Email code", "Код на почту", "Email kodi", "Email коди"), subtitle: maskEmail(email))
                        }
                    }
                    .iumrahCard()

                    verificationContent

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(IumrahDesign.pagePadding)
                .padding(.bottom, 30)
            }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .navigationTitle(tr("Account verification", "Подтверждение аккаунта", "Akkaunt tasdig‘i", "Аккаунт тасдиғи"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Cancel", "Отмена", "Bekor qilish", "Бекор қилиш")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var verificationContent: some View {
        VStack(spacing: 12) {
            if method == .password {
                SecureField(tr("Current password", "Текущий пароль", "Joriy parol", "Жорий парол"), text: $password)
                    .textContentType(.password)
                    .padding(.horizontal, 15)
                    .frame(height: 54)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                Button { Task { await verifyPassword() } } label: {
                    actionLabel(tr("Confirm device", "Подтвердить устройство", "Qurilmani tasdiqlash", "Қурилмани тасдиқлаш"))
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(password.count < 8 || isWorking)
            } else if challengeID.isEmpty {
                Button { Task { await sendCode() } } label: {
                    actionLabel(method == .phone
                                ? tr("Send SMS code", "Отправить SMS-код", "SMS kod yuborish", "SMS код юбориш")
                                : tr("Send email code", "Отправить код на почту", "Email kod yuborish", "Email код юбориш"))
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isWorking)
            } else {
                Text(tr("Code sent to %@", "Код отправлен на %@", "Kod %@ manziliga yuborildi", "Код %@ манзилига юборилди").replacingOccurrences(of: "%@", with: destination))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 25, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .tracking(8)
                    .padding(.horizontal, 15)
                    .frame(height: 58)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .onChange(of: code) { _, value in code = String(value.filter(\.isNumber).prefix(6)) }

                Button { Task { await confirmCode() } } label: {
                    actionLabel(tr("Confirm device", "Подтвердить устройство", "Qurilmani tasdiqlash", "Қурилмани тасдиқлаш"))
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(code.count != 6 || isWorking)
            }
        }
        .iumrahCard()
    }

    private func methodRow(_ value: Method, icon: String, title: String, subtitle: String) -> some View {
        Button {
            method = value
            password = ""
            challengeID = ""
            destination = ""
            code = ""
            errorMessage = nil
        } label: {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: icon, role: .security, size: 38, symbolSize: 14, cornerRadius: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: method == value ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(method == value ? Color.iumrahCareLight : Color.secondary.opacity(0.45))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ title: String) -> some View {
        HStack {
            if isWorking { ProgressView().tint(.white) }
            Text(title)
            Spacer()
            if !isWorking { Image(systemName: "checkmark.shield.fill") }
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    private func verifyPassword() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let refreshed = try await account.claimPrimaryDevice(password: password)
            onVerified(refreshed)
            IumrahHaptics.success()
            dismiss()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func sendCode() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await account.startPrimaryRecovery(method: method.rawValue, locale: settings.language.rawValue)
            challengeID = response.challengeID
            destination = response.maskedDestination
            code = ""
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func confirmCode() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let refreshed = try await account.confirmPrimaryRecovery(method: method.rawValue, challengeID: challengeID, code: code)
            onVerified(refreshed.overview)
            IumrahHaptics.success()
            dismiss()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    private func maskPhone(_ value: String) -> String {
        let digits = value.filter { $0.isNumber || $0 == "+" }
        guard digits.count > 8 else { return digits }
        return String(digits.prefix(4)) + " •••• " + String(digits.suffix(4))
    }

    private func maskEmail(_ value: String) -> String {
        guard let at = value.firstIndex(of: "@") else { return value }
        let local = String(value[..<at])
        let domain = String(value[value.index(after: at)...])
        return String(local.prefix(min(2, max(1, local.count)))) + "•••@" + domain
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
