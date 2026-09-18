import SwiftUI
import PhotosUI
import QuickLook
import UniformTypeIdentifiers
import UIKit

private enum IumrahActivationMethod: String, CaseIterable, Identifiable {
    case iumrahID
    case email

    var id: String { rawValue }
}

private enum IumrahCheckoutLoginMethod: String, CaseIterable, Identifiable {
    case iumrahID
    case email

    var id: String { rawValue }
}

struct PilgrimCheckoutView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var account: IumrahAccountStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String

    @State private var checkout: IumrahCheckoutResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var activationMethod: IumrahActivationMethod = .iumrahID
    @State private var activationEmail = ""
    @State private var activationEmailChallengeID = ""
    @State private var activationEmailCode = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var isPasswordVisible = false
    @State private var isPasswordConfirmVisible = false
    @State private var existingLoginMethod: IumrahCheckoutLoginMethod = .iumrahID
    @State private var existingLoginID = ""
    @State private var existingLoginEmail = ""
    @State private var loginPassword = ""
    @State private var isLoginPasswordVisible = false
    @State private var showExistingAccountLogin = false
    @State private var showPasswordRecovery = false
    @State private var isSubmittingAccount = false
    @State private var travelerEditor: IumrahTravelerForm?
    @State private var paymentMethod = "visa"
    @State private var receiptPhoto: PhotosPickerItem?
    @State private var isUploadingReceipt = false
    @State private var paymeQRImage: UIImage?
    @State private var previewFile: IumrahPreviewFile?
    @State private var isLoadingDocument = false
    @State private var friendsSummary: IumrahFriendsBookingSummary?
    @State private var giftCode = ""
    @State private var isApplyingFriendBenefit = false
    @State private var friendsMessage: String?

    private let service = IumrahAccountService()
    private let bookingService = BookingService()
    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }
    private var isPaymentPending: Bool { checkout?.status == "payment_pending" }
    private var isAvailabilityChecking: Bool { checkout?.status == "availability_check" }
    private var isTravelerEditingAllowed: Bool { isAvailabilityChecking || isPaymentPending }
    private var shouldShowDocuments: Bool {
        guard let checkout else { return false }
        return !checkout.documents.isEmpty || !checkout.receipts.isEmpty || ["booking_confirmed", "ready_to_travel", "in_trip", "completed"].contains(checkout.status)
    }
    private var accountMatchesTrip: Bool {
        guard let checkout, let id = account.iumrahID else { return false }
        return normalizedID(id) == normalizedID(checkout.iumrahID)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                hero

                if isLoading {
                    loadingCard
                } else if let checkout {
                    if accountMatchesTrip {
                        progressCard(checkout)
                        travelersCard(checkout)
                        paymentCard(checkout)
                        if shouldShowDocuments { documentsCard(checkout) }
                    } else if showExistingAccountLogin {
                        loginCard(checkout)
                    } else {
                        activationCard(checkout)
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(tr("Pilgrim details & payment", "Данные и оплата", "Ma’lumotlar va to‘lov", "Маълумотлар ва тўлов"))
                        .font(.headline)
                        .lineLimit(1)
                    if let id = checkout?.iumrahID ?? session?.displayPilgrimID {
                        Text("iumrah ID \(normalizedID(id))")
                            .font(.caption2.monospaced().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .iumrahInternalNavigation()
        .task { await loadCheckout() }
        .onAppear {
            if account.isAuthenticated { Task { await loadFriendsSummary() } }
        }
        .sheet(item: $travelerEditor) { traveler in
            TravelerFormEditorSheet(
                bookingID: bookingID,
                traveler: traveler,
                language: settings.language,
                onSaved: { Task { await loadCheckout(showLoader: false) } }
            )
            .environmentObject(account)
        }
        .sheet(item: $previewFile) { file in
            NavigationStack {
                QuickLookFilePreview(url: file.url)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle(file.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(tr("Done", "Готово", "Tayyor", "Тайёр")) { previewFile = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPasswordRecovery) {
            IumrahPasswordRecoveryView()
        }
        .onChange(of: receiptPhoto) { _, item in
            guard let item else { return }
            Task { await uploadReceipt(item) }
        }
    }


    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(isAvailabilityChecking
                         ? tr("We are checking availability", "Проверяем наличие", "Mavjudlik tekshirilmoqda", "Мавжудлик текширилмоқда")
                         : tr("Continue your booking", "Продолжите оформление", "Bronni davom ettiring", "Бронни давом эттиринг"))
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                    Text(isAvailabilityChecking
                         ? tr(
                            "You can safely close the app — we will update the status automatically. Fill in pilgrim and passport details now to move straight to payment after confirmation.",
                            "Вы можете спокойно закрыть приложение — статус обновится автоматически. Заранее заполните данные паломников и паспортов, чтобы после подтверждения сразу перейти к оплате.",
                            "Ilovani bemalol yopishingiz mumkin — holat avtomatik yangilanadi. Tasdiqdan keyin darhol to‘lovga o‘tish uchun ziyoratchilar va pasport ma’lumotlarini oldindan kiriting.",
                            "Иловани бемалол ёпишингиз мумкин — ҳолат автоматик янгиланади. Тасдиқдан кейин дарҳол тўловга ўтиш учун зиёратчилар ва паспорт маълумотларини олдиндан киритинг."
                         )
                         : tr(
                            "Create your iumrah ID password, complete every pilgrim form and attach the payment receipt.",
                            "Создайте пароль для iumrah ID, заполните анкеты всех паломников и прикрепите чек оплаты.",
                            "iumrah ID uchun parol yarating, barcha ziyoratchilar anketasini to‘ldiring va to‘lov chekini biriktiring.",
                            "iumrah ID учун парол яратинг, барча зиёратчилар анкетасини тўлдиринг ва тўлов чекини бириктиринг."
                         ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                IumrahIconBadge(
                    systemName: "person.text.rectangle.fill",
                    role: .profile,
                    size: 50,
                    symbolSize: 21,
                    cornerRadius: 17
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var loadingCard: some View {
        HStack(spacing: 13) {
            ProgressView()
            Text(tr("Loading secure checkout…", "Загружаем защищённое оформление…", "Himoyalangan sahifa yuklanmoqda…", "Ҳимояланган саҳифа юкланмоқда…"))
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func activationCard(_ value: IumrahCheckoutResponse) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            stageHeader(
                number: "01",
                icon: "person.badge.key.fill",
                title: tr("Activate your iumrah account", "Активируйте аккаунт iumrah", "iumrah akkauntingizni faollashtiring", "iumrah аккаунтингизни фаоллаштиринг")
            )

            Label("iumrah Security", systemImage: "checkmark.shield.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(tr(
                "Create a password and keep it safe. You will use it to sign in to your iumrah account from another device or on the iumrah website.",
                "Придумайте пароль и сохраните его надёжно. Он будет использоваться для входа в Ваш аккаунт iumrah с другого устройства или на сайте iumrah.",
                "Parol yarating va uni xavfsiz saqlang. U boshqa qurilmadan yoki iumrah saytida akkauntingizga kirish uchun ishlatiladi.",
                "Парол яратинг ва уни хавфсиз сақланг. У бошқа қурилмадан ёки iumrah сайтида аккаунтингизга кириш учун ишлатилади."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("", selection: $activationMethod) {
                Text("iumrah ID").tag(IumrahActivationMethod.iumrahID)
                Text("Email").tag(IumrahActivationMethod.email)
            }
            .pickerStyle(.segmented)
            .onChange(of: activationMethod) { _, _ in
                errorMessage = nil
                activationEmailChallengeID = ""
                activationEmailCode = ""
            }

            if activationMethod == .iumrahID {
                VStack(alignment: .leading, spacing: 7) {
                    Text("iumrah ID")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(normalizedID(value.iumrahID))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .textSelection(.enabled)
                    Text(tr(
                        "Your eight-digit iumrah ID is permanent and stays with you for future trips.",
                        "Ваш восьмизначный iumrah ID постоянный и сохраняется для будущих поездок.",
                        "Sakkiz xonali iumrah ID doimiy va keyingi safarlarda ham saqlanadi.",
                        "Саккиз хонали iumrah ID доимий ва кейинги сафарларда ҳам сақланади."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 11) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        TextField("name@example.com", text: $activationEmail)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(!activationEmailChallengeID.isEmpty)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 54)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)

                    if !activationEmailChallengeID.isEmpty {
                        HStack(spacing: 11) {
                            Image(systemName: "number.square.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            TextField(tr("6-digit code", "Код из 6 цифр", "6 xonali kod", "6 хонали код"), text: $activationEmailCode)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .font(.body.monospaced())
                                .onChange(of: activationEmailCode) { _, raw in
                                    let digits = String(raw.filter(\.isNumber).prefix(6))
                                    if digits != raw { activationEmailCode = digits }
                                }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 54)
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)

                        Text(tr(
                            "We sent a verification code with Resend. It expires in 10 minutes.",
                            "Мы отправили код подтверждения на почту. Он действует 10 минут.",
                            "Tasdiqlash kodi emailingizga yuborildi. U 10 daqiqa amal qiladi.",
                            "Тасдиқлаш коди emailingizга юборилди. У 10 дақиқа амал қилади."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            passwordField(
                tr("Create password", "Создайте пароль", "Parol yarating", "Парол яратинг"),
                text: $password,
                isVisible: $isPasswordVisible,
                newPassword: true
            )
            passwordField(
                tr("Confirm password", "Подтвердите пароль", "Parolni tasdiqlang", "Паролни тасдиқланг"),
                text: $passwordConfirm,
                isVisible: $isPasswordConfirmVisible,
                newPassword: true
            )

            VStack(alignment: .leading, spacing: 7) {
                activationRequirement(
                    tr("At least 8 characters", "Минимум 8 символов", "Kamida 8 belgi", "Камида 8 белги"),
                    ready: password.count >= 8
                )
                activationRequirement(
                    tr("Passwords match", "Пароли совпадают", "Parollar mos", "Пароллар мос"),
                    ready: !passwordConfirm.isEmpty && password == passwordConfirm
                )
            }

            Button {
                Task {
                    if activationMethod == .iumrahID {
                        await activateAccount(value)
                    } else if activationEmailChallengeID.isEmpty {
                        await startEmailActivation(value)
                    } else {
                        await confirmEmailActivation(value)
                    }
                }
            } label: {
                HStack {
                    if isSubmittingAccount { ProgressView().tint(.white) }
                    Text(activationPrimaryTitle)
                    Spacer()
                    Image(systemName: activationMethod == .email && activationEmailChallengeID.isEmpty ? "envelope.badge.fill" : "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(!activationPrimaryReady || isSubmittingAccount || !isTravelerEditingAllowed)

            if activationMethod == .email && !activationEmailChallengeID.isEmpty {
                HStack {
                    Button {
                        activationEmailChallengeID = ""
                        activationEmailCode = ""
                        errorMessage = nil
                    } label: {
                        Text(tr("Change email", "Изменить почту", "Emailni o‘zgartirish", "Emailни ўзгартириш"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        Task { await startEmailActivation(value) }
                    } label: {
                        Text(tr("Send again", "Отправить ещё раз", "Qayta yuborish", "Қайта юбориш"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmittingAccount)
                }
            }

            Button {
                errorMessage = nil
                if existingLoginID.isEmpty { existingLoginID = normalizedID(value.iumrahID) }
                showExistingAccountLogin = true
            } label: {
                Text(value.accountActive
                    ? tr("Already created a password? Sign in", "Уже создавали пароль? Войти", "Avval parol yaratganmisiz? Kiring", "Аввал парол яратганмисиз? Киринг")
                    : tr("I already have an iumrah account", "У меня уже есть аккаунт iumrah", "Menda iumrah akkaunti bor", "Менда iumrah аккаунти бор"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .iumrahCard()
    }

    private func loginCard(_ value: IumrahCheckoutResponse) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            stageHeader(number: "01", icon: "person.crop.circle.badge.checkmark", title: tr("Use an existing iumrah account", "Войдите в существующий аккаунт", "Mavjud iumrah akkauntiga kiring", "Мавжуд iumrah аккаунтига киринг"))
            Text(tr(
                "Sign in with your existing account. This booking will then be securely linked to that same permanent iumrah ID.",
                "Войдите в свой существующий аккаунт. После входа эта бронь будет безопасно привязана к тому же постоянному iumrah ID.",
                "Mavjud akkauntingizga kiring. Shundan keyin bu bron aynan shu doimiy iumrah ID ga xavfsiz ulanadi.",
                "Мавжуд аккаунтингизга киринг. Шундан кейин бу брон айнан шу доимий iumrah ID га хавфсиз уланади."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("", selection: $existingLoginMethod) {
                Text("iumrah ID").tag(IumrahCheckoutLoginMethod.iumrahID)
                Text("Email").tag(IumrahCheckoutLoginMethod.email)
            }
            .pickerStyle(.segmented)
            .onChange(of: existingLoginMethod) { _, _ in errorMessage = nil }

            if existingLoginMethod == .iumrahID {
                HStack(spacing: 11) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    TextField("00000016", text: $existingLoginID)
                        .keyboardType(.numberPad)
                        .textContentType(.username)
                        .font(.body.monospaced())
                        .onChange(of: existingLoginID) { _, raw in
                            let digits = String(raw.filter(\.isNumber).prefix(8))
                            if digits != raw { existingLoginID = digits }
                        }
                }
                .padding(.horizontal, 14)
                .frame(height: 54)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
            } else {
                HStack(spacing: 11) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    TextField("name@example.com", text: $existingLoginEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 54)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
            }

            passwordField(
                tr("Password", "Пароль", "Parol", "Парол"),
                text: $loginPassword,
                isVisible: $isLoginPasswordVisible,
                newPassword: false
            )

            HStack {
                Button {
                    errorMessage = nil
                    showExistingAccountLogin = false
                } label: {
                    Text(tr("Create an account for this booking", "Создать аккаунт для этой брони", "Bu bron uchun akkaunt yaratish", "Бу брон учун аккаунт яратиш"))
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    showPasswordRecovery = true
                } label: {
                    Text(tr("Forgot password?", "Забыли пароль?", "Parolni unutdingizmi?", "Паролни унутдингизми?"))
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await login(value) }
            } label: {
                HStack {
                    if isSubmittingAccount { ProgressView().tint(.white) }
                    Text(tr("Sign in and link booking", "Войти и привязать бронь", "Kirish va bronni ulash", "Кириш ва бронни улаш"))
                    Spacer(); Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(!existingLoginReady || isSubmittingAccount)
        }
        .iumrahCard()
    }

    private var existingLoginReady: Bool {
        guard loginPassword.count >= 8 else { return false }
        switch existingLoginMethod {
        case .iumrahID:
            return [6, 8].contains(existingLoginID.filter(\.isNumber).count)
        case .email:
            let email = existingLoginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            return email.contains("@") && email.contains(".")
        }
    }

    private var activationPrimaryTitle: String {
        if activationMethod == .iumrahID {
            return tr("Activate ID and continue", "Активировать ID и продолжить", "ID ni faollashtirish va davom etish", "ID ни фаоллаштириш ва давом этиш")
        }
        if activationEmailChallengeID.isEmpty {
            return tr("Send verification code", "Отправить код", "Tasdiqlash kodini yuborish", "Тасдиқлаш кодини юбориш")
        }
        return tr("Confirm email and continue", "Подтвердить почту и продолжить", "Emailni tasdiqlash va davom etish", "Emailни тасдиқлаш ва давом этиш")
    }

    private var activationPrimaryReady: Bool {
        guard password.count >= 8, password == passwordConfirm else { return false }
        if activationMethod == .iumrahID { return true }
        let email = activationEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), email.contains(".") else { return false }
        if activationEmailChallengeID.isEmpty { return true }
        return activationEmailCode.count == 6
    }

    private func activationRequirement(_ title: String, ready: Bool) -> some View {
        Label(title, systemImage: ready ? "checkmark.circle.fill" : "circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(ready ? Color.iumrahCareDark : Color.secondary)
    }

    private func progressCard(_ value: IumrahCheckoutResponse) -> some View {
        let complete = value.travelers.filter(\.completed).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Booking readiness", "Готовность оформления", "Rasmiylashtirish holati", "Расмийлаштириш ҳолати"))
                        .font(.headline)
                    Text(L10n.status(value.status, settings.language))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(complete)/\(value.travelers.count)")
                    .font(.headline.monospacedDigit())
            }
            ProgressView(value: Double(complete + (value.receipts.isEmpty ? 0 : 1)), total: Double(max(1, value.travelers.count + 1)))
                .tint(Color.iumrahCareDark)
            HStack(spacing: 8) {
                readinessChip(tr("Account", "Аккаунт", "Akkaunt", "Аккаунт"), ready: accountMatchesTrip)
                readinessChip(tr("Pilgrims", "Анкеты", "Anketalar", "Анкеталар"), ready: complete == value.travelers.count)
                readinessChip(tr("Receipt", "Чек", "Chek", "Чек"), ready: !value.receipts.isEmpty)
            }
        }
        .iumrahCard()
    }

    private func travelersCard(_ value: IumrahCheckoutResponse) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            stageHeader(number: "02", icon: "person.2.fill", title: tr("Pilgrim details", "Данные паломников", "Ziyoratchilar ma’lumotlari", "Зиёратчилар маълумотлари"))
            Text(tr("One secure form for every traveler in this booking.", "Для каждого участника поездки — отдельная защищённая анкета.", "Har bir sayohatchi uchun alohida himoyalangan anketa.", "Ҳар бир саёҳатчи учун алоҳида ҳимояланган анкета."))
                .font(.subheadline).foregroundStyle(.secondary)

            ForEach(value.travelers) { traveler in
                Button {
                    if isTravelerEditingAllowed { travelerEditor = traveler }
                } label: {
                    HStack(spacing: 13) {
                        IumrahIconBadge(
                            systemName: traveler.completed ? "checkmark" : travelerIcon(traveler.travelerType),
                            role: traveler.completed ? .success : .profile,
                            size: 46,
                            symbolSize: 17,
                            cornerRadius: 15
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(travelerName(traveler))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(relationshipTitle(traveler.relationship, position: traveler.position))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(traveler.completed ? tr("Completed", "Анкета готова", "Anketa tayyor", "Анкета тайёр") : tr("Passport and travel details required", "Нужны данные и паспорт", "Ma’lumot va pasport kerak", "Маълумот ва паспорт керак"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: isTravelerEditingAllowed ? "chevron.right" : "lock.fill")
                            .font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    .padding(13)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
        .iumrahCard()
    }

    private func paymentCard(_ value: IumrahCheckoutResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            stageHeader(number: "03", icon: "creditcard.fill", title: tr("Payment", "Оплата", "To‘lov", "Тўлов"))

            if isAvailabilityChecking {
                VStack(alignment: .leading, spacing: 12) {
                    Label(tr("Payment will open after availability is confirmed", "Оплата откроется после подтверждения наличия", "To‘lov mavjudlik tasdiqlangach ochiladi", "Тўлов мавжудлик тасдиқлангач очилади"), systemImage: "lock.clock.fill")
                        .font(.headline)
                    Text(tr(
                        "Nothing needs to be paid now. Complete the pilgrim forms above — the entered details will remain saved.",
                        "Сейчас ничего оплачивать не нужно. Заполните анкеты паломников выше — введённые данные сохранятся.",
                        "Hozir to‘lov qilish shart emas. Yuqoridagi ziyoratchi anketalarini to‘ldiring — ma’lumotlar saqlanadi.",
                        "Ҳозир тўлов қилиш шарт эмас. Юқоридаги зиёратчи анкеталарини тўлдиринг — маълумотлар сақланади."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                IumrahManualPaymentNotice()
                IumrahRefundPolicyCard(component: .package, compact: true)
                if let session {
                    IumrahInvoiceShareCard(session: session, compact: true)
                }

                friendsBenefitCard

                if paymentOptions(value).isEmpty {
                    Label(tr("Payment details will appear after iumrah Business adds them.", "Реквизиты появятся после того, как iumrah Business их добавит.", "To‘lov rekvizitlari iumrah Business qo‘shgandan keyin paydo bo‘ladi.", "Тўлов реквизитлари iumrah Business қўшгандан кейин пайдо бўлади."), systemImage: "clock")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        ForEach(paymentOptions(value), id: \.self) { method in
                            Button {
                                paymentMethod = method
                                if method == "payme" { Task { await loadPaymeQR(value) } }
                            } label: {
                                Text(paymentTitle(method))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(paymentMethod == method ? Color.iumrahPrimaryButtonText : Color.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(paymentMethod == method ? Color.iumrahPrimaryButtonBackground : Color.iumrahRaisedBackground, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    paymentDetails(value)

                    if !value.payment.instructions.isEmpty {
                        Text(value.payment.instructions)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Divider()

                    if let receipt = value.receipts.first {
                        paymentReceiptSummary(receipt, checkout: value)
                    } else if isPaymentPending {
                        PhotosPicker(selection: $receiptPhoto, matching: .images) {
                            HStack {
                                if isUploadingReceipt { ProgressView().tint(.white) }
                                Image(systemName: "paperclip")
                                Text(tr("Attach payment receipt", "Прикрепить чек оплаты", "To‘lov chekini biriktirish", "Тўлов чекини бириктириш"))
                                Spacer()
                                Image(systemName: "arrow.up")
                            }
                        }
                        .buttonStyle(IumrahPrimaryButtonStyle())
                        .disabled(isUploadingReceipt || paymentOptions(value).isEmpty)
                    }
                }
            }
        }
        .iumrahCard()
    }

    private func paymentReceiptSummary(_ receipt: IumrahPaymentReceipt, checkout: IumrahCheckoutResponse) -> some View {
        let number = receipt.paymentMethod == "humo" ? checkout.payment.humoCardNumber : checkout.payment.visaCardNumber
        let holder = receipt.paymentMethod == "humo" ? checkout.payment.humoHolder : checkout.payment.visaHolder
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: receipt.reviewStatus == "approved" ? "checkmark.seal.fill" : "clock.badge.checkmark.fill", role: receipt.reviewStatus == "approved" ? .success : .payment, size: 48, symbolSize: 19, cornerRadius: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Payment receipt", "Чек об оплате", "To‘lov cheki", "Тўлов чеки"))
                        .font(.headline)
                    Text(receiptStatus(receipt.reviewStatus))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(receipt.reviewStatus == "approved" ? Color.green : Color.secondary)
                }
                Spacer()
            }

            VStack(spacing: 9) {
                receiptFact(tr("Booking", "Бронирование", "Bron", "Брон"), session?.displayBookingNumber ?? "—")
                if let traveler = receiptTravelerName(checkout) {
                    receiptFact(tr("Pilgrim", "Паломник", "Ziyoratchi", "Зиёратчи"), traveler)
                }
                if let total = session?.booking.totalUsd {
                    receiptFact(tr("Booking total", "Сумма бронирования", "Bron summasi", "Брон суммаси"), receiptMoney(total))
                }
                receiptFact(tr("Payment method", "Способ оплаты", "To‘lov usuli", "Тўлов усули"), paymentTitle(receipt.paymentMethod))
                if !number.isEmpty { receiptFact(tr("Card number", "Номер карты", "Karta raqami", "Карта рақами"), groupedCard(number)) }
                if !holder.isEmpty { receiptFact(tr("Recipient", "Получатель", "Qabul qiluvchi", "Қабул қилувчи"), holder) }
                receiptFact(tr("Platform", "Платформа", "Platforma", "Платформа"), "Iumrah")
                receiptFact(tr("Responsible team", "Ответственное лицо", "Mas’ul jamoa", "Масъул жамоа"), "Iumrah Booking Operations")
                receiptFact(tr("Sent", "Отправлен", "Yuborildi", "Юборилди"), checkoutDate(receipt.createdAt))
            }

            Label(tr(
                "Iumrah is responsible for issuing and delivering the airline ticket after payment confirmation. Refund and change conditions follow the airline fare rules.",
                "Iumrah несёт ответственность за оформление и передачу авиабилета после подтверждения оплаты. Условия возврата и изменений зависят от тарифа авиакомпании.",
                "To‘lov tasdiqlangach, aviachiptani rasmiylashtirish va yetkazish uchun Iumrah javob beradi. Qaytarish va o‘zgartirish shartlari aviakompaniya tarifiga bog‘liq.",
                "Тўлов тасдиқлангач, авиачиптани расмийлаштириш ва етказиш учун Iumrah жавоб беради. Қайтариш ва ўзгартириш шартлари авиакомпания тарифига боғлиқ."
            ), systemImage: "shield.checkered")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if let url = receipt.url, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button { Task { await openReceipt(receipt) } } label: {
                    HStack {
                        if isLoadingDocument { ProgressView().tint(.white) } else { Image(systemName: "doc.text.image.fill") }
                        Text(tr("Open payment receipt", "Открыть чек оплаты", "To‘lov chekini ochish", "Тўлов чекини очиш"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isLoadingDocument)
            }

            NavigationLink {
                IumrahPolicyDetailView(kind: .refund)
            } label: {
                Label(tr("Refund policy", "Политика возврата", "Qaytarish siyosati", "Қайтариш сиёсати"), systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.iumrahRaisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func receiptTravelerName(_ checkout: IumrahCheckoutResponse) -> String? {
        let fallback = session?.travelerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let primary = checkout.travelers.sorted(by: { $0.position < $1.position }).first else {
            return fallback.isEmpty ? nil : fallback
        }
        let value = [primary.firstName, primary.middleName, primary.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !value.isEmpty { return value }
        return fallback.isEmpty ? nil : fallback
    }

    private func receiptMoney(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = amount.rounded() == amount ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    private func receiptFact(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 10)
            Text(value).font(.caption.weight(.semibold)).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var friendsBenefitCard: some View {
        if account.isAuthenticated {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    IumrahIconBadge(
                        systemName: "gift.fill",
                        role: .gift,
                        size: 42,
                        symbolSize: 17,
                        cornerRadius: 15
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("iUmrah Gift Cards")
                            .font(.headline)
                        Text(tr("Gift Card & iUmrah Balance", "Gift Card и iUmrah Balance", "Gift Card va iUmrah Balance", "Gift Card ва iUmrah Balance"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isApplyingFriendBenefit { ProgressView() }
                }

                if let summary = friendsSummary {
                    if !summary.identityConfirmed {
                        VStack(alignment: .leading, spacing: 11) {
                            Label(
                                tr(
                                    "Confirm the passport holder and wait for manual review before using a Gift Card benefit.",
                                    "Подтвердите владельца паспорта и дождитесь ручной проверки перед применением Gift Card.",
                                    "Gift Card ishlatishdan oldin pasport egasini tasdiqlang va qo‘lda tekshirishni kuting.",
                                    "Gift Card ишлатишдан олдин паспорт эгасини тасдиқланг ва қўлда текширишни кутинг."
                                ),
                                systemImage: "lock.shield.fill"
                            )
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)

                            NavigationLink {
                                IumrahSecurityConfirmationView(bookingID: bookingID)
                            } label: {
                                HStack {
                                    Text("iUmrah Security Confirmation")
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 15)
                                .frame(height: 50)
                                .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        friendsPricingSummary(summary)

                        if summary.remainingAllowanceUsd >= 100 {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(tr("Use a Gift Card", "Применить Gift Card", "Gift Card ishlatish", "Gift Card ишлатиш"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 9) {
                                    TextField("IUMG-XXXXXXXXX", text: $giftCode)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 13)
                                        .frame(height: 50)
                                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous), interactive: true)

                                    Button {
                                        Task { await redeemFriendGift() }
                                    } label: {
                                        Text(tr("Apply", "Применить", "Qo‘llash", "Қўллаш"))
                                            .font(.subheadline.weight(.bold))
                                            .padding(.horizontal, 15)
                                            .frame(height: 50)
                                            .iumrahGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous), interactive: true)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(normalizedGiftCode.count < 8 || isApplyingFriendBenefit)
                                }
                            }
                        }

                        if summary.availableCreditUsd >= 100 && summary.remainingAllowanceUsd >= 100 {
                            let amount = Int(min(200.0, min(summary.availableCreditUsd, summary.remainingAllowanceUsd)) / 100) * 100
                            Button {
                                Task { await applyFriendCredit(amountUsd: max(100, amount)) }
                            } label: {
                                HStack {
                                    Image(systemName: "creditcard.and.123")
                                    Text(tr(
                                        "Use $\(max(100, amount)) iUmrah Balance",
                                        "Использовать $\(max(100, amount)) iUmrah Balance",
                                        "$\(max(100, amount)) iUmrah Balance ishlatish",
                                        "$\(max(100, amount)) iUmrah Balance ишлатиш"
                                    ))
                                    Spacer()
                                    Image(systemName: "minus.circle.fill")
                                }
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 15)
                                .frame(height: 50)
                                .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
                            }
                            .buttonStyle(.plain)
                            .disabled(isApplyingFriendBenefit)
                        }

                        if !summary.appliedGifts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(summary.appliedGifts) { gift in
                                    HStack {
                                        Label(gift.code, systemImage: "checkmark.circle.fill")
                                            .font(.caption.monospaced().weight(.semibold))
                                            .foregroundStyle(.green)
                                        Spacer()
                                        Text("−\(friendMoney(gift.discountUsd))")
                                            .font(.caption.weight(.bold))
                                    }
                                }
                            }
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(tr("Checking Gift Card benefits…", "Проверяем Gift Card…", "Gift Card imtiyozlari tekshirilmoqda…", "Gift Card имтиёзлари текширилмоқда…"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let friendsMessage {
                    Label(friendsMessage, systemImage: "info.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(friendsMessageIsError ? Color.red : Color.green)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(Color.iumrahRaisedBackground.opacity(0.45), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func friendsPricingSummary(_ summary: IumrahFriendsBookingSummary) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(tr("Gift Card limit", "Лимит Gift Card", "Gift Card limiti", "Gift Card лимити"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(friendMoney(summary.maxDiscountUsd)).fontWeight(.semibold)
            }
            if summary.totalUsd > 0 {
                HStack {
                    Text(tr("Package", "Пакет", "Paket", "Пакет"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(friendMoney(summary.totalUsd))
                }
            }
            if summary.totalDiscountUsd > 0 {
                HStack {
                    Text("iUmrah Gift Cards")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("−\(friendMoney(summary.totalDiscountUsd))")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
            if summary.totalUsd > 0 {
                Divider()
                HStack {
                    Text(tr("Amount to pay", "К оплате", "To‘lov summasi", "Тўлов суммаси"))
                        .fontWeight(.semibold)
                    Spacer()
                    Text(friendMoney(summary.payableUsd))
                        .font(.headline.monospacedDigit())
                }
            }
            HStack {
                Text(tr("Available iUmrah Balance", "Доступный iUmrah Balance", "Mavjud iUmrah Balance", "Мавжуд iUmrah Balance"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(friendMoney(summary.availableCreditUsd))
                    .font(.caption.weight(.bold))
            }
        }
        .font(.subheadline)
    }

    private var normalizedGiftCode: String {
        giftCode.uppercased().filter { !$0.isWhitespace }
    }

    private var friendsMessageIsError: Bool {
        guard let value = friendsMessage?.lowercased() else { return false }
        return value.contains("не ") || value.contains("cannot") || value.contains("required") || value.contains("нельзя") || value.contains("xato") || value.contains("kerak") || value.contains("керак")
    }

    private func friendMoney(_ amount: Double) -> String {
        "$\(Int(amount.rounded()))"
    }

    @MainActor
    private func loadFriendsSummary() async {
        guard let session, account.isAuthenticated else {
            friendsSummary = nil
            return
        }
        do {
            let headers = account.authorizationHeaders(bookingToken: session.accessToken)
            friendsSummary = try await bookingService.friendsSummary(id: bookingID, headers: headers)
        } catch APIError.status(let code) where code == 404 {
            friendsSummary = nil
        } catch APIError.server(_, let message) where message == "FRIENDS_UNAVAILABLE" {
            friendsSummary = nil
        } catch {
            // Friends is supplemental to checkout. Do not block payment if the service is temporarily unavailable.
        }
    }

    @MainActor
    private func redeemFriendGift() async {
        guard let session else { return }
        isApplyingFriendBenefit = true
        friendsMessage = nil
        defer { isApplyingFriendBenefit = false }
        do {
            let headers = account.authorizationHeaders(bookingToken: session.accessToken)
            friendsSummary = try await bookingService.redeemFriendGift(
                id: bookingID,
                headers: headers,
                code: normalizedGiftCode
            )
            giftCode = ""
            friendsMessage = tr("$100 Gift Card applied.", "Gift Card на $100 применён.", "$100 Gift Card qo‘llandi.", "$100 Gift Card қўлланди.")
            IumrahHaptics.success()
        } catch APIError.server(_, let code) {
            friendsMessage = friendError(code)
            IumrahHaptics.error()
        } catch {
            friendsMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func applyFriendCredit(amountUsd: Int) async {
        guard let session else { return }
        isApplyingFriendBenefit = true
        friendsMessage = nil
        defer { isApplyingFriendBenefit = false }
        do {
            let headers = account.authorizationHeaders(bookingToken: session.accessToken)
            friendsSummary = try await bookingService.applyFriendCredit(
                id: bookingID,
                headers: headers,
                amountUsd: amountUsd
            )
            friendsMessage = tr("iUmrah Balance applied.", "iUmrah Balance применён.", "iUmrah Balance qo‘llandi.", "iUmrah Balance қўлланди.")
            IumrahHaptics.success()
        } catch APIError.server(_, let code) {
            friendsMessage = friendError(code)
            IumrahHaptics.error()
        } catch {
            friendsMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    private func friendError(_ code: String) -> String {
        switch code.uppercased() {
        case "IDENTITY_CONFIRMATION_REQUIRED":
            return tr("iUmrah Security Confirmation is required.", "Сначала пройдите iUmrah Security Confirmation.", "Avval iUmrah Security Confirmation dan o‘ting.", "Аввал iUmrah Security Confirmation дан ўтинг.")
        case "FRIENDS_GIFT_INVALID":
            return tr("Check the Gift code.", "Проверьте код Gift-карты.", "Gift kodini tekshiring.", "Gift кодини текширинг.")
        case "FRIENDS_GIFT_NOT_AVAILABLE":
            return tr("This Gift is unavailable or already used.", "Эта Gift-карта недоступна или уже использована.", "Bu Gift mavjud emas yoki allaqachon ishlatilgan.", "Бу Gift мавжуд эмас ёки аллақачон ишлатилган.")
        case "FRIENDS_NEW_CUSTOMER_ONLY":
            return tr("This identity already has a previously paid iumrah trip or has used a first-booking Gift Card.", "У этой личности уже есть ранее оплаченная поездка iumrah или использованная Gift Card первого бронирования.", "Bu shaxsning avval to‘langan iumrah safari bor yoki birinchi bron Gift Card idan foydalangan.", "Бу шахснинг аввал тўланган iumrah сафари бор ёки биринчи брон Gift Card идан фойдаланган.")
        case "FRIENDS_DISCOUNT_LIMIT_REACHED":
            return tr("The Gift Card limit for this trip is already reached.", "Лимит Gift Card для этой поездки уже исчерпан.", "Bu safar uchun Gift Card limiti tugagan.", "Бу сафар учун Gift Card лимити тугаган.")
        case "FRIENDS_SELF_REFERRAL":
            return tr("You cannot use your own Gift.", "Нельзя применить собственную Gift-карту.", "O‘z Gift kartangizni ishlata olmaysiz.", "Ўз Gift картангизни ишлата олмайсиз.")
        case "FRIENDS_CREDIT_UNAVAILABLE":
            return tr("There is not enough available iUmrah Balance for this booking.", "Недостаточно доступного iUmrah Balance для этого бронирования.", "Bu bron uchun iUmrah Balance yetarli emas.", "Бу брон учун iUmrah Balance етарли эмас.")
        default:
            return L10n.error(APIError.server(409, code), settings.language)
        }
    }

    private func documentsCard(_ value: IumrahCheckoutResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            stageHeader(number: "04", icon: "doc.fill", title: tr("Travel documents", "Документы поездки", "Safar hujjatlari", "Сафар ҳужжатлари"))
            Text(tr("Each document appears here as soon as it is ready.", "Каждый документ появится здесь отдельно сразу после готовности.", "Har bir hujjat tayyor bo‘lishi bilan shu yerda alohida paydo bo‘ladi.", "Ҳар бир ҳужжат тайёр бўлиши билан шу ерда алоҳида пайдо бўлади."))
                .font(.subheadline).foregroundStyle(.secondary)

            documentStatusRow(kind: "ticket", title: tr("Airline ticket", "Авиабилет", "Aviachipta", "Авиачипта"), icon: "airplane", documents: value.documents)
            documentStatusRow(kind: "voucher", title: tr("Hotel confirmation", "Подтверждение отеля", "Mehmonxona tasdig‘i", "Меҳмонхона тасдиғи"), icon: "building.2.fill", documents: value.documents)
            documentStatusRow(kind: "visa", title: tr("Visa", "Виза", "Viza", "Виза"), icon: "checkmark.seal.fill", documents: value.documents)
            documentStatusRow(kind: "insurance", title: tr("Insurance", "Страховка", "Sug‘urta", "Суғурта"), icon: "cross.case.fill", documents: value.documents)

            ForEach(value.documents.filter { !["ticket", "voucher", "visa", "insurance"].contains($0.documentKind) }) { document in
                readyDocumentButton(document, title: document.title, icon: "doc.fill")
            }
        }
        .iumrahCard()
    }

    @ViewBuilder
    private func documentStatusRow(kind: String, title: String, icon: String, documents: [IumrahTravelDocument]) -> some View {
        if let document = documents.first(where: { $0.documentKind == kind }) {
            readyDocumentButton(document, title: title, icon: icon)
        } else {
            HStack(spacing: 13) {
                IumrahIconBadge(systemName: icon, role: .document, size: 48, symbolSize: 18, cornerRadius: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(tr("Being prepared", "Готовится", "Tayyorlanmoqda", "Тайёрланмоқда"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ProgressView().controlSize(.small)
            }
            .padding(14)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func readyDocumentButton(_ document: IumrahTravelDocument, title: String, icon: String) -> some View {
        Button { Task { await openDocument(document) } } label: {
            HStack(spacing: 13) {
                IumrahIconBadge(systemName: icon, role: .success, size: 48, symbolSize: 18, cornerRadius: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(tr("Ready to open", "Готов · можно открыть", "Tayyor · ochish mumkin", "Тайёр · очиш мумкин"))
                        .font(.caption).foregroundStyle(.secondary)
                    if let reference = document.bookingReference, !reference.isEmpty {
                        Text(tr("Booking code: ", "Код бронирования: ", "Bron kodi: ", "Брон коди: ") + reference)
                            .font(.caption2.monospaced().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Spacer()
                if isLoadingDocument { ProgressView() } else { Image(systemName: "arrow.up.right").foregroundStyle(.tertiary) }
            }
            .padding(14)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func paymentDetails(_ value: IumrahCheckoutResponse) -> some View {
        switch paymentMethod {
        case "payme":
            VStack(spacing: 12) {
                if let image = paymeQRImage {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                        .padding(14)
                        .frame(maxWidth: 260, maxHeight: 260)
                        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .task { await loadPaymeQR(value) }
                }
                Text(tr("Scan the QR in PayMe, then attach the receipt below.", "Отсканируйте QR в PayMe, затем прикрепите чек ниже.", "PayMe orqali QR ni skanerlang, so‘ng chekni biriktiring.", "PayMe орқали QR ни сканерланг, сўнг чекни бириктиринг."))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        case "humo":
            paymentNumberBlock(title: "Humo", number: value.payment.humoCardNumber, holder: value.payment.humoHolder)
        default:
            paymentNumberBlock(title: "Visa", number: value.payment.visaCardNumber, holder: value.payment.visaHolder)
        }
    }

    private func paymentNumberBlock(title: String, number: String, holder: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(groupedCard(number))
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.78)
                        .lineLimit(1)
                    if !holder.isEmpty { Text(holder).font(.caption.weight(.medium)).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                Button {
                    UIPasteboard.general.string = number
                    IumrahHaptics.success()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 42, height: 42)
                        .contentShape(Circle())
                        .iumrahGlass(in: Circle(), interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .background(Color.iumrahRaisedBackground.opacity(0.70), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func stageHeader(number: String, icon: String, title: String) -> some View {
        HStack(spacing: 11) {
            IumrahIconBadge(
                systemName: icon,
                size: 38,
                symbolSize: 15,
                cornerRadius: 12
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(number).font(.caption2.monospaced().weight(.bold)).foregroundStyle(.secondary)
                Text(title).font(.headline)
            }
        }
    }

    private func passwordField(_ title: String, text: Binding<String>, isVisible: Binding<Bool>, newPassword: Bool) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "lock.fill").foregroundStyle(.secondary).frame(width: 22)
            Group {
                if isVisible.wrappedValue {
                    TextField(title, text: text)
                        .textContentType(newPassword ? .newPassword : .password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(title, text: text)
                        .textContentType(newPassword ? .newPassword : .password)
                }
            }
            Button { isVisible.wrappedValue.toggle() } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible.wrappedValue ? tr("Hide password", "Скрыть пароль", "Parolni yashirish", "Паролни яшириш") : tr("Show password", "Показать пароль", "Parolni ko‘rsatish", "Паролни кўрсатиш"))
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
    }

    private func readinessChip(_ title: String, ready: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: ready ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ready ? .green : .secondary)
            Text(title).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(.caption2.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    @MainActor
    private func loadCheckout(showLoader: Bool = true) async {
        guard let session else { return }
        if showLoader { isLoading = true }
        defer { isLoading = false }
        do {
            let headers = account.authorizationHeaders(bookingToken: session.accessToken)
            let loaded = try await service.checkout(bookingID: bookingID, authorizationHeaders: headers)
            checkout = loaded
            errorMessage = nil
            let options = paymentOptions(loaded)
            if let first = options.first, !options.contains(paymentMethod) {
                paymentMethod = first
            }
            if account.isAuthenticated { await loadFriendsSummary() }
        } catch {
            errorMessage = L10n.error(error, settings.language)
        }
    }

    @MainActor
    private func activateAccount(_ value: IumrahCheckoutResponse) async {
        guard let session, !session.accessToken.isEmpty else { return }
        isSubmittingAccount = true
        errorMessage = nil
        defer { isSubmittingAccount = false }
        do {
            let profile = try await account.activate(
                bookingID: bookingID,
                bookingToken: session.accessToken,
                password: password,
                locale: settings.language.rawValue
            )
            await finishAccountActivation(profile, session: session)
        } catch APIError.server(_, let message) where message.uppercased().contains("ACCOUNT_ALREADY_ACTIVE") {
            errorMessage = IumrahAccountSecurityCopy.message(for: APIError.server(409, "ACCOUNT_ALREADY_ACTIVE"), language: settings.language)
            showExistingAccountLogin = true
            IumrahHaptics.error()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func startEmailActivation(_ value: IumrahCheckoutResponse) async {
        guard let session, !session.accessToken.isEmpty else { return }
        isSubmittingAccount = true
        errorMessage = nil
        defer { isSubmittingAccount = false }
        do {
            let response = try await account.startActivationEmail(
                bookingID: bookingID,
                bookingToken: session.accessToken,
                email: activationEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                locale: settings.language.rawValue
            )
            activationEmailChallengeID = response.challengeID
            activationEmailCode = ""
            IumrahHaptics.success()
        } catch APIError.server(_, let message) where message.uppercased().contains("ACCOUNT_ALREADY_ACTIVE") {
            errorMessage = IumrahAccountSecurityCopy.message(for: APIError.server(409, "ACCOUNT_ALREADY_ACTIVE"), language: settings.language)
            showExistingAccountLogin = true
            IumrahHaptics.error()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func confirmEmailActivation(_ value: IumrahCheckoutResponse) async {
        guard let session, !session.accessToken.isEmpty, !activationEmailChallengeID.isEmpty else { return }
        isSubmittingAccount = true
        errorMessage = nil
        defer { isSubmittingAccount = false }
        do {
            let profile = try await account.confirmActivationEmail(
                bookingID: bookingID,
                bookingToken: session.accessToken,
                challengeID: activationEmailChallengeID,
                code: activationEmailCode,
                password: password,
                locale: settings.language.rawValue
            )
            await finishAccountActivation(profile, session: session)
        } catch APIError.server(_, let message) where message.uppercased().contains("ACCOUNT_ALREADY_ACTIVE") {
            errorMessage = IumrahAccountSecurityCopy.message(for: APIError.server(409, "ACCOUNT_ALREADY_ACTIVE"), language: settings.language)
            showExistingAccountLogin = true
            IumrahHaptics.error()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func finishAccountActivation(_ profile: IumrahAccountProfile, session: StoredBookingSession) async {
        _ = profile
        bookings.setAccountToken(account.bearerToken)
        if let linked = try? await account.linkBooking(bookingID: bookingID, bookingToken: session.accessToken) {
            bookings.applyCanonicalLink(linked, to: bookingID)
        }
        if let token = account.bearerToken {
            await bookings.restoreAccountTrips(token: token)
        }
        password = ""
        passwordConfirm = ""
        activationEmailCode = ""
        await loadCheckout(showLoader: false)
        IumrahHaptics.success()
    }

    @MainActor
    private func login(_ value: IumrahCheckoutResponse) async {
        isSubmittingAccount = true; errorMessage = nil
        defer { isSubmittingAccount = false }
        do {
            let identifier = existingLoginMethod == .iumrahID
                ? normalizedID(existingLoginID)
                : existingLoginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await account.login(identifier: identifier, password: loginPassword, locale: settings.language.rawValue)
            bookings.setAccountToken(account.bearerToken)
            guard let session else { throw APIError.missingBookingToken }
            let linked = try await account.linkBooking(bookingID: bookingID, bookingToken: session.accessToken)
            bookings.applyCanonicalLink(linked, to: bookingID)
            if let token = account.bearerToken { await bookings.restoreAccountTrips(token: token) }
            loginPassword = ""
            await loadCheckout(showLoader: false)
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func uploadReceipt(_ item: PhotosPickerItem) async {
        guard let token = account.bearerToken else { return }
        isUploadingReceipt = true; errorMessage = nil
        defer { isUploadingReceipt = false; receiptPhoto = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw URLError(.cannotDecodeContentData) }
            let contentType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            _ = try await service.uploadReceipt(bookingID: bookingID, method: paymentMethod, data: data, contentType: contentType, token: token)
            await loadCheckout(showLoader: false)
            IumrahHaptics.success()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func loadPaymeQR(_ value: IumrahCheckoutResponse) async {
        guard value.payment.hasPaymeQR, let path = value.payment.paymeQRURL, let token = account.bearerToken else { return }
        do {
            let data = try await service.media(path: path, token: token)
            paymeQRImage = UIImage(data: data)
        } catch { errorMessage = L10n.error(error, settings.language) }
    }

    @MainActor
    private func openReceipt(_ receipt: IumrahPaymentReceipt) async {
        guard let token = account.bearerToken,
              let path = receipt.url?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return }
        isLoadingDocument = true
        defer { isLoadingDocument = false }
        do {
            let data = try await service.media(path: path, token: token)
            let ext: String
            if let filename = receipt.filename, !URL(fileURLWithPath: filename).pathExtension.isEmpty {
                ext = URL(fileURLWithPath: filename).pathExtension
            } else if receipt.contentType == "application/pdf" {
                ext = "pdf"
            } else if let direct = URL(string: path), !direct.pathExtension.isEmpty {
                ext = direct.pathExtension
            } else {
                ext = "jpg"
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("iumrah-payment-receipt-\(receipt.id).\(ext)")
            try data.write(to: url, options: .atomic)
            previewFile = IumrahPreviewFile(
                id: "receipt-\(receipt.id)",
                title: tr("Payment receipt", "Чек оплаты", "To‘lov cheki", "Тўлов чеки"),
                url: url
            )
        } catch {
            errorMessage = L10n.error(error, settings.language)
        }
    }

    @MainActor
    private func openDocument(_ document: IumrahTravelDocument) async {
        guard let token = account.bearerToken else { return }
        isLoadingDocument = true; errorMessage = nil
        defer { isLoadingDocument = false }
        do {
            let data = try await service.media(path: document.url, token: token)
            let ext = document.contentType == "application/pdf" ? "pdf" : document.contentType.contains("png") ? "png" : "jpg"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("iumrah-\(document.id).\(ext)")
            try data.write(to: url, options: .atomic)
            previewFile = IumrahPreviewFile(id: document.id, title: document.title, url: url)
        } catch { errorMessage = L10n.error(error, settings.language) }
    }

    private func paymentOptions(_ value: IumrahCheckoutResponse) -> [String] {
        var result: [String] = []
        if !value.payment.visaCardNumber.isEmpty { result.append("visa") }
        if value.payment.hasPaymeQR { result.append("payme") }
        if !value.payment.humoCardNumber.isEmpty { result.append("humo") }
        return result
    }

    private func paymentTitle(_ value: String) -> String { value == "payme" ? "PayMe" : value == "humo" ? "Humo" : "Visa" }
    private func receiptStatus(_ value: String) -> String {
        switch value { case "approved": return tr("Verified", "Проверен", "Tekshirildi", "Текширилди"); case "rejected": return tr("Needs attention", "Нужно исправить", "Qayta yuklang", "Қайта юкланг"); default: return tr("Sent for verification", "Отправлен на проверку", "Tekshiruvga yuborildi", "Текширувга юборилди") }
    }
    private func checkoutDate(_ value: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: value) ?? ISO8601DateFormatter().date(from: value) else { return value }
        return date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }
    private func relationshipTitle(_ value: String?, position: Int) -> String {
        switch value ?? (position == 1 ? "self" : "other") {
        case "self": return tr("You", "Вы", "Siz", "Сиз")
        case "spouse": return tr("Spouse", "Муж / жена", "Turmush o‘rtog‘i", "Турмуш ўртоғи")
        case "mother": return tr("Mother", "Мама", "Ona", "Она")
        case "father": return tr("Father", "Папа", "Ota", "Ота")
        case "brother": return tr("Brother", "Брат", "Aka / uka", "Ака / ука")
        case "sister": return tr("Sister", "Сестра", "Opa / singil", "Опа / сингил")
        case "child": return tr("Child", "Ребёнок", "Farzand", "Фарзанд")
        case "relative": return tr("Relative", "Родственник", "Qarindosh", "Қариндош")
        case "friend": return tr("Friend", "Друг / подруга", "Do‘st", "Дўст")
        default: return tr("Travel companion", "Попутчик", "Hamroh", "Ҳамроҳ")
        }
    }
    private func travelerName(_ traveler: IumrahTravelerForm) -> String {
        let name = [traveler.firstName, traveler.lastName].filter { !$0.isEmpty }.joined(separator: " ")
        if !name.isEmpty { return name }
        return "\(travelerType(traveler.travelerType)) · \(traveler.position)"
    }
    private func travelerType(_ value: String) -> String {
        switch value { case "child": return tr("Child", "Ребёнок", "Bola", "Бола"); case "infant": return tr("Infant", "Младенец", "Chaqaloq", "Чақалоқ"); default: return tr("Adult", "Взрослый", "Katta", "Катта") }
    }
    private func travelerIcon(_ value: String) -> String { value == "infant" ? "figure.and.child.holdinghands" : value == "child" ? "figure.child" : "person.fill" }
    private func documentKind(_ value: String) -> String { value == "visa" ? tr("Visa", "Виза", "Viza", "Виза") : value == "voucher" ? tr("Voucher", "Ваучер", "Vaucher", "Ваучер") : value == "ticket" ? tr("Ticket", "Билет", "Chipta", "Чипта") : value == "insurance" ? tr("Insurance", "Страховка", "Sug‘urta", "Суғурта") : tr("Document", "Документ", "Hujjat", "Ҳужжат") }
    private func groupedCard(_ value: String) -> String {
        let compact = value.replacingOccurrences(of: " ", with: "")
        return stride(from: 0, to: compact.count, by: 4).map { offset in
            let start = compact.index(compact.startIndex, offsetBy: offset)
            let end = compact.index(start, offsetBy: min(4, compact.distance(from: start, to: compact.endIndex)))
            return String(compact[start..<end])
        }.joined(separator: " ")
    }
    private func normalizedID(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return value }
        if digits.count >= 8 { return digits }
        return String(repeating: "0", count: 8 - digits.count) + digits
    }
    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language { case .russian: return ru; case .english: return en; case .uzbek: return uz; case .uzbekCyrillic: return cyrl }
    }
}

private struct TravelerFormEditorSheet: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @Environment(\.dismiss) private var dismiss
    let bookingID: String
    let language: AppSettingsStore.Language
    let onSaved: () -> Void

    @State private var form: IumrahTravelerForm
    @State private var dateOfBirthInput: String
    @State private var passportExpiryDateInput: String
    @State private var countryTarget: CountryTarget?
    @State private var passportPhoto: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?
    private let service = IumrahAccountService()

    init(bookingID: String, traveler: IumrahTravelerForm, language: AppSettingsStore.Language, onSaved: @escaping () -> Void) {
        self.bookingID = bookingID
        self.language = language
        self.onSaved = onSaved
        var initial = traveler
        if initial.relationship?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            initial.relationship = traveler.position == 1 ? "self" : "other"
        }
        _form = State(initialValue: initial)
        _dateOfBirthInput = State(initialValue: Self.displayDate(traveler.dateOfBirth))
        _passportExpiryDateInput = State(initialValue: Self.displayDate(traveler.passportExpiryDate))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    introCard

                    section(tr("Personal details", "Личные данные", "Shaxsiy ma’lumotlar", "Шахсий маълумотлар"), icon: "person.fill") {
                        relationshipRow
                        field(tr("First name", "Имя", "Ism", "Исм"), $form.firstName, contentType: .givenName)
                        field(tr("Middle name", "Отчество / второе имя", "Otasining ismi", "Отасининг исми"), $form.middleName, contentType: .middleName)
                        field(tr("Last name", "Фамилия", "Familiya", "Фамилия"), $form.lastName, contentType: .familyName)
                        genderRow
                        smartDateField(tr("Date of birth", "Дата рождения", "Tug‘ilgan sana", "Туғилган сана"), text: $dateOfBirthInput)
                        countryRow(target: .nationality, title: tr("Citizenship", "Гражданство", "Fuqarolik", "Фуқаролик"), value: form.nationality)
                    }

                    section(tr("Passport", "Паспорт", "Pasport", "Паспорт"), icon: "passport.fill") {
                        field(
                            tr("Passport number", "Номер паспорта", "Pasport raqami", "Паспорт рақами"),
                            $form.passportNumber,
                            keyboard: .asciiCapable,
                            autocapitalization: .characters
                        )
                        smartDateField(tr("Expiry date", "Срок действия", "Amal qilish muddati", "Амал қилиш муддати"), text: $passportExpiryDateInput)
                        countryRow(target: .issuing, title: tr("Issuing country", "Страна выдачи", "Bergan davlat", "Берган давлат"), value: form.passportIssuingCountry)

                        PhotosPicker(selection: $passportPhoto, matching: .images) {
                            HStack(spacing: 12) {
                                IumrahIconBadge(
                                    systemName: (passportPhoto != nil || form.hasPassport) ? "checkmark.circle.fill" : "camera.fill",
                                    role: (passportPhoto != nil || form.hasPassport) ? .success : .document,
                                    size: 40,
                                    symbolSize: 17,
                                    cornerRadius: 13
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text((passportPhoto != nil || form.hasPassport) ? tr("Passport photo attached", "Фото паспорта прикреплено", "Pasport rasmi biriktirildi", "Паспорт расми бириктирилди") : tr("Attach passport photo", "Прикрепить фото паспорта", "Pasport rasmini biriktirish", "Паспорт расмини бириктириш"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(tr("Clear photo of the information page", "Чёткое фото страницы с данными", "Ma’lumotlar sahifasining aniq rasmi", "Маълумотлар саҳифасининг аниқ расми"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 66)
                            .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
                        }
                        .buttonStyle(.plain)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    Button { Task { await save() } } label: {
                        HStack(spacing: 10) {
                            if isSaving { ProgressView().tint(.white) }
                            Image(systemName: "checkmark.circle.fill")
                            Text(tr("Save pilgrim", "Сохранить анкету", "Anketani saqlash", "Анкетани сақлаш"))
                            Spacer(minLength: 10)
                        }
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                    .disabled(!canSave || isSaving)
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle(tr("Pilgrim \(form.position)", "Паломник \(form.position)", "Ziyoratchi \(form.position)", "Зиёратчи \(form.position)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Close", "Закрыть", "Yopish", "Ёпиш")) { dismiss() }
                }
            }
            .sheet(item: $countryTarget) { target in
                CountryPickerSheet(
                    language: language,
                    selectedCanonicalName: selectedCountry(for: target),
                    title: countryTitle(target),
                    onSelect: { option in
                        setCountry(option.canonicalName, for: target)
                        countryTarget = nil
                    }
                )
            }
        }
    }

    private var introCard: some View {
        HStack(spacing: 12) {
            IumrahIconBadge(
                systemName: "wand.and.stars",
                role: .umrah,
                size: 42,
                symbolSize: 17,
                cornerRadius: 14
            )
            Text(tr(
                "Dates format automatically while you type. Countries can be selected from the searchable list.",
                "Даты форматируются автоматически. Страны можно выбрать из списка с поиском.",
                "Sanalar avtomatik formatlanadi. Davlatlarni qidiruv orqali ro‘yxatdan tanlang.",
                "Саналар автоматик форматланади. Давлатларни қидирув орқали рўйхатдан танланг."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color.iumrahCareLight.opacity(0.085), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private var relationshipRow: some View {
        Menu {
            ForEach(["self", "spouse", "mother", "father", "brother", "sister", "child", "relative", "friend", "other"], id: \.self) { value in
                Button {
                    form.relationship = value
                    IumrahHaptics.selection()
                } label: {
                    Label(relationshipOptionTitle(value), systemImage: form.relationship == value ? "checkmark" : relationshipOptionIcon(value))
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: relationshipOptionIcon(form.relationship ?? "other"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Who is traveling?", "Кто едет?", "Kim bormoqda?", "Ким бормоқда?"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(relationshipOptionTitle(form.relationship ?? "other"))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
    }

    private func relationshipOptionTitle(_ value: String) -> String {
        switch value {
        case "self": return tr("Me", "Я", "Men", "Мен")
        case "spouse": return tr("Husband / wife", "Муж / жена", "Turmush o‘rtog‘i", "Турмуш ўртоғи")
        case "mother": return tr("Mother", "Мама", "Ona", "Она")
        case "father": return tr("Father", "Папа", "Ota", "Ота")
        case "brother": return tr("Brother", "Брат", "Aka / uka", "Ака / ука")
        case "sister": return tr("Sister", "Сестра", "Opa / singil", "Опа / сингил")
        case "child": return tr("Child", "Ребёнок", "Farzand", "Фарзанд")
        case "relative": return tr("Relative", "Родственник", "Qarindosh", "Қариндош")
        case "friend": return tr("Friend", "Друг / подруга", "Do‘st", "Дўст")
        default: return tr("Travel companion", "Попутчик", "Hamroh", "Ҳамроҳ")
        }
    }

    private func relationshipOptionIcon(_ value: String) -> String {
        switch value {
        case "self": return "person.fill"
        case "spouse": return "heart.fill"
        case "mother", "father": return "person.crop.circle.fill"
        case "brother", "sister": return "person.2.fill"
        case "child": return "figure.and.child.holdinghands"
        case "friend": return "person.2.fill"
        default: return "person.2.fill"
        }
    }

    private var genderRow: some View {
        Menu {
            Button {
                form.gender = "male"
                IumrahHaptics.selection()
            } label: {
                Label(tr("Male", "Мужской", "Erkak", "Эркак"), systemImage: form.gender == "male" ? "checkmark" : "person.fill")
            }
            Button {
                form.gender = "female"
                IumrahHaptics.selection()
            } label: {
                Label(tr("Female", "Женский", "Ayol", "Аёл"), systemImage: form.gender == "female" ? "checkmark" : "person.fill")
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(form.gender == "male" ? tr("Male", "Мужской", "Erkak", "Эркак") : form.gender == "female" ? tr("Female", "Женский", "Ayol", "Аёл") : tr("Gender", "Пол", "Jins", "Жинс"))
                    .foregroundStyle(form.gender.isEmpty ? Color.secondary : Color.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
        }
    }

    private var canSave: Bool {
        let required = [
            form.relationship ?? "", form.firstName, form.lastName, form.gender,
            form.nationality, form.passportNumber, form.passportIssuingCountry
        ]
        return required.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && Self.isoDate(dateOfBirthInput) != nil
            && Self.isoDate(passportExpiryDateInput) != nil
            && (form.hasPassport || passportPhoto != nil)
    }

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                IumrahIconBadge(
                    systemName: icon,
                    size: 38,
                    symbolSize: 16,
                    cornerRadius: 13
                )
                Text(title).font(.headline)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func field(
        _ title: String,
        _ text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .words
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .asciiCapable)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
    }

    private func smartDateField(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            TextField("\(title) · DD.MM.YYYY", text: text)
                .keyboardType(.numberPad)
                .textContentType(.none)
                .onChange(of: text.wrappedValue) { _, value in
                    let formatted = Self.formatDateInput(value)
                    if formatted != value { text.wrappedValue = formatted }
                }
            Spacer(minLength: 0)
            if text.wrappedValue.count == 10 {
                Image(systemName: Self.isoDate(text.wrappedValue) == nil ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(Self.isoDate(text.wrappedValue) == nil ? Color.red : Color.green)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
    }

    private func countryRow(target: CountryTarget, title: String, value: String) -> some View {
        Button {
            countryTarget = target
            IumrahHaptics.selection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: target == .nationality ? "flag.fill" : "globe.europe.africa.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CountryCatalog.displayName(for: value, language: language) ?? tr("Select country", "Выберите страну", "Davlatni tanlang", "Давлатни танланг"))
                        .font(.body)
                        .foregroundStyle(value.isEmpty ? Color.secondary : Color.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func save() async {
        guard let token = account.bearerToken,
              let dob = Self.isoDate(dateOfBirthInput),
              let expiry = Self.isoDate(passportExpiryDateInput) else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            var payload = form
            payload.dateOfBirth = dob
            payload.passportExpiryDate = expiry
            _ = try await service.saveTraveler(bookingID: bookingID, position: form.position, form: payload, token: token)
            if let passportPhoto, let data = try await passportPhoto.loadTransferable(type: Data.self) {
                let type = passportPhoto.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                try await service.uploadPassport(bookingID: bookingID, position: form.position, data: data, contentType: type, token: token)
            }
            IumrahHaptics.success()
            onSaved()
            dismiss()
        } catch {
            errorMessage = L10n.error(error, language)
            IumrahHaptics.error()
        }
    }

    private func selectedCountry(for target: CountryTarget) -> String {
        switch target {
        case .nationality: return form.nationality
        case .issuing: return form.passportIssuingCountry
        }
    }

    private func setCountry(_ value: String, for target: CountryTarget) {
        switch target {
        case .nationality: form.nationality = value
        case .issuing: form.passportIssuingCountry = value
        }
    }

    private func countryTitle(_ target: CountryTarget) -> String {
        switch target {
        case .nationality: return tr("Citizenship", "Гражданство", "Fuqarolik", "Фуқаролик")
        case .issuing: return tr("Issuing country", "Страна выдачи", "Bergan davlat", "Берган давлат")
        }
    }

    private static func formatDateInput(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(8))
        guard digits.count > 2 else { return digits }
        let day = String(digits.prefix(2))
        let afterDay = digits.dropFirst(2)
        guard afterDay.count > 2 else { return day + "." + afterDay }
        let month = String(afterDay.prefix(2))
        let year = afterDay.dropFirst(2)
        return day + "." + month + "." + year
    }

    private static func displayDate(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            let pieces = value.split(separator: "-")
            if pieces.count == 3 { return "\(pieces[2]).\(pieces[1]).\(pieces[0])" }
        }
        return formatDateInput(value)
    }

    private static func isoDate(_ display: String) -> String? {
        guard display.range(of: #"^\d{2}\.\d{2}\.\d{4}$"#, options: .regularExpression) != nil else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.isLenient = false
        guard let date = formatter.date(from: display) else { return nil }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.calendar = Calendar(identifier: .gregorian)
        output.dateFormat = "yyyy-MM-dd"
        return output.string(from: date)
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private enum CountryTarget: String, Identifiable {
    case nationality
    case issuing
    var id: String { rawValue }
}

private struct CountryOption: Identifiable, Hashable {
    let code: String
    let canonicalName: String
    let localizedName: String
    var id: String { code }
    var flag: String {
        code.uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(127397 + scalar.value).map(String.init)
        }.joined()
    }
}

private enum CountryCatalog {
    static func options(language: AppSettingsStore.Language) -> [CountryOption] {
        let localized = Locale(identifier: language.localeIdentifier)
        let canonical = Locale(identifier: "en_US_POSIX")
        return Locale.isoRegionCodes.compactMap { code in
            guard let englishName = canonical.localizedString(forRegionCode: code),
                  let localizedName = localized.localizedString(forRegionCode: code) else { return nil }
            return CountryOption(code: code, canonicalName: englishName, localizedName: localizedName)
        }
        .sorted { $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending }
    }

    static func displayName(for stored: String, language: AppSettingsStore.Language) -> String? {
        let value = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let option = options(language: language).first(where: {
            $0.canonicalName.caseInsensitiveCompare(value) == .orderedSame ||
            $0.localizedName.caseInsensitiveCompare(value) == .orderedSame ||
            $0.code.caseInsensitiveCompare(value) == .orderedSame
        }) {
            return option.localizedName
        }
        return value
    }
}

private struct CountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppSettingsStore.Language
    let selectedCanonicalName: String
    let title: String
    let onSelect: (CountryOption) -> Void
    @State private var search = ""

    private var filtered: [CountryOption] {
        let all = CountryCatalog.options(language: language)
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.localizedName.localizedCaseInsensitiveContains(q) ||
            $0.canonicalName.localizedCaseInsensitiveContains(q) ||
            $0.code.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { option in
                Button {
                    onSelect(option)
                    IumrahHaptics.selection()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(option.flag)
                            .font(.system(size: 24))
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.localizedName)
                                .foregroundStyle(.primary)
                            Text(option.code)
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if option.canonicalName.caseInsensitiveCompare(selectedCanonicalName) == .orderedSame {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.iumrahCareLight)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: searchPrompt)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeTitle) { dismiss() }
                }
            }
        }
    }

    private var searchPrompt: String {
        switch language {
        case .russian: return "Поиск страны"
        case .english: return "Search country"
        case .uzbek: return "Davlatni qidirish"
        case .uzbekCyrillic: return "Давлатни қидириш"
        }
    }

    private var closeTitle: String {
        switch language {
        case .russian: return "Закрыть"
        case .english: return "Close"
        case .uzbek: return "Yopish"
        case .uzbekCyrillic: return "Ёпиш"
        }
    }
}

private struct IumrahPreviewFile: Identifiable {
    let id: String
    let title: String
    let url: URL
}

private struct QuickLookFilePreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller
    }
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
