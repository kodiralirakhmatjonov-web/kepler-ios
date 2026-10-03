import SwiftUI

/// Canonical owner profile used by Account and reused before future bookings.
///
/// The visual language intentionally matches iumrah Security KYC so personal
/// data and identity confirmation feel like one product. The booking-bound KYC
/// flow itself remains unchanged and is opened from the Security section below
/// when a trip is available.
struct IumrahUserDataView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var telegram = ""
    @State private var whatsapp = ""
    @State private var dateOfBirth = ""
    @State private var gender = ""
    @State private var nationality = ""
    @State private var emergencyName = ""
    @State private var emergencyPhone = ""
    @State private var emergencyRelation = ""
    @State private var isSaving = false
    @State private var saveMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName, lastName
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                securityHero
                introCopy
                warningCard
                passportProfileCard
                personalDetailsCard
                contactDetailsCard
                securityStatusCard

                if let saveMessage {
                    Label(saveMessage, systemImage: saveMessage == savedMessage ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(saveMessage == savedMessage ? Color.green : Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                saveButton
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 52)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.iumrahPageBackground)
        .navigationTitle(tr("Your details", "Ваши данные", "Ma’lumotlaringiz", "Маълумотларингиз"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(tr("Your details", "Ваши данные", "Ma’lumotlaringiz", "Маълумотларингиз"))
                        .font(.headline)
                    Text("iumrah Security · Profile")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { loadProfile() }
    }

    private var securityHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)

            LoopingVideoView(resource: "iumrah-security-identity", gravity: .resizeAspect)
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .frame(height: 292)
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .accessibilityHidden(true)
    }

    private var introCopy: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("iumrah Security", systemImage: "lock.shield.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(tr(
                "Your booking profile",
                "Ваши данные для бронирования",
                "Bron uchun ma’lumotlaringiz",
                "Брон учун маълумотларингиз"
            ))
            .font(.system(size: 29, weight: .bold, design: .rounded))
            .tracking(-0.5)

            Text(tr(
                "Keep your personal and contact details in one profile. iumrah reuses them for future flights, hotels and trips, so you do not have to enter the same information again.",
                "Храните личные и контактные данные в одном профиле. iumrah использует их для будущих авиабилетов, отелей и поездок, чтобы Вам не приходилось вводить одно и то же заново.",
                "Shaxsiy va aloqa ma’lumotlaringizni bitta profilda saqlang. iumrah ularni keyingi aviachiptalar, mehmonxonalar va safarlarda qayta ishlatadi.",
                "Шахсий ва алоқа маълумотларингизни битта профилда сақланг. iumrah уларни кейинги авиачипталар, меҳмонхоналар ва сафарларда қайта ишлатади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 42, height: 42)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(tr("Important", "Важно", "Muhim", "Муҳим"))
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(tr(
                    "Enter your first name, last name and personal details exactly as they appear in your passport. These values are reused when iumrah prepares travel services.",
                    "Введите имя, фамилию и личные данные точно так, как они указаны в паспорте. Эти значения будут использоваться при оформлении услуг поездки.",
                    "Ism, familiya va shaxsiy ma’lumotlarni pasportdagidek aniq kiriting. Bu ma’lumotlar safar xizmatlarini rasmiylashtirishda ishlatiladi.",
                    "Исм, фамилия ва шахсий маълумотларни паспортдагидек аниқ киритинг. Бу маълумотлар сафар хизматларини расмийлаштиришда ишлатилади."
                ))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.075), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.red.opacity(0.20), lineWidth: 1)
        }
    }

    private var passportProfileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Passport profile", "Паспортный профиль", "Pasport profili", "Паспорт профили"))
                        .font(.headline)
                    Text(tr("Account owner", "Владелец аккаунта", "Akkaunt egasi", "Аккаунт эгаси"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            secureField(
                title: tr("First name", "Имя", "Ism", "Исм"),
                placeholder: tr("Exactly as in passport", "Как в паспорте", "Pasportdagidek", "Паспортдагидек"),
                text: $firstName,
                field: .firstName,
                contentType: .givenName
            )

            secureField(
                title: tr("Last name", "Фамилия", "Familiya", "Фамилия"),
                placeholder: tr("Exactly as in passport", "Как в паспорте", "Pasportdagidek", "Паспортдагидек"),
                text: $lastName,
                field: .lastName,
                contentType: .familyName
            )
        }
        .iumrahCard()
    }

    private var personalDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "person.crop.circle.badge.checkmark",
                title: tr("Personal details", "Личные данные", "Shaxsiy ma’lumotlar", "Шахсий маълумотлар"),
                subtitle: tr("Saved to your owner profile", "Сохраняются в Вашем профиле", "Profilingizda saqlanadi", "Профилингизда сақланади")
            )

            dateField(
                title: tr("Date of birth", "Дата рождения", "Tug‘ilgan sana", "Туғилган сана"),
                text: $dateOfBirth
            )

            Menu {
                Button { gender = "male"; IumrahHaptics.selection() } label: {
                    Label(tr("Male", "Мужской", "Erkak", "Эркак"), systemImage: gender == "male" ? "checkmark" : "person.fill")
                }
                Button { gender = "female"; IumrahHaptics.selection() } label: {
                    Label(tr("Female", "Женский", "Ayol", "Аёл"), systemImage: gender == "female" ? "checkmark" : "person.fill")
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(genderTitle)
                        .foregroundStyle(gender.isEmpty ? Color.secondary : Color.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            plainField(
                title: tr("Citizenship", "Гражданство", "Fuqarolik", "Фуқаролик"),
                placeholder: tr("Uzbekistan", "Узбекистан", "O‘zbekiston", "Ўзбекистон"),
                text: $nationality,
                keyboard: .default,
                contentType: .countryName,
                capitalization: .words
            )
        }
        .iumrahCard()
    }

    private var contactDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "phone.badge.checkmark.fill",
                title: tr("Contacts & emergency", "Контакты и экстренная связь", "Aloqa va favqulodda kontakt", "Алоқа ва фавқулодда контакт"),
                subtitle: tr("Used for bookings and support", "Используются для бронирований и поддержки", "Bron va yordam uchun ishlatiladi", "Брон ва ёрдам учун ишлатилади")
            )

            phoneField(title: tr("Phone", "Номер телефона", "Telefon", "Телефон"), text: $phone)

            plainField(
                title: "Email",
                placeholder: "name@example.com",
                text: $email,
                keyboard: .emailAddress,
                contentType: .emailAddress,
                capitalization: .never
            )

            plainField(
                title: "Telegram",
                placeholder: "@username",
                text: $telegram,
                keyboard: .default,
                contentType: .none,
                capitalization: .never
            )

            phoneField(title: "WhatsApp", text: $whatsapp)

            Divider()

            Text(tr("Emergency contact", "Экстренный контакт", "Favqulodda kontakt", "Фавқулодда контакт"))
                .font(.subheadline.weight(.semibold))

            plainField(
                title: tr("Contact name", "Имя контакта", "Kontakt ismi", "Контакт исми"),
                placeholder: tr("Name and surname", "Имя и фамилия", "Ism va familiya", "Исм ва фамилия"),
                text: $emergencyName,
                keyboard: .default,
                contentType: .name,
                capitalization: .words
            )

            phoneField(title: tr("Emergency phone", "Экстренный номер телефона", "Favqulodda telefon", "Фавқулодда телефон"), text: $emergencyPhone)

            plainField(
                title: tr("Relationship", "Кем приходится", "Qarindoshlik", "Қариндошлик"),
                placeholder: tr("For example: mother", "Например: мама", "Masalan: ona", "Масалан: она"),
                text: $emergencyRelation,
                keyboard: .default,
                contentType: .none,
                capitalization: .words
            )
        }
        .iumrahCard()
    }

    @ViewBuilder
    private var securityStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 42, height: 42)
                    .background(Color.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("iumrah Security · KYC")
                        .font(.headline)
                    Text(tr(
                        "Identity confirmation stays connected to this profile.",
                        "Подтверждение личности связано с этим профилем.",
                        "Shaxsni tasdiqlash shu profilga bog‘langan.",
                        "Шахсни тасдиқлаш шу профилга боғланган."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
            }

            if let trip = kycTrip {
                NavigationLink {
                    IumrahSecurityConfirmationView(bookingID: trip.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Open identity confirmation", "Открыть подтверждение личности", "Shaxsni tasdiqlashni ochish", "Шахсни тасдиқлашни очиш"))
                                .font(.subheadline.weight(.bold))
                            Text(tr(
                                "Passport number, passport photo and verification",
                                "Номер паспорта, фото паспорта и проверка",
                                "Pasport raqami, pasport rasmi va tekshiruv",
                                "Паспорт рақами, паспорт расми ва текширув"
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 15)
                    .frame(minHeight: 62)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text(tr(
                        "Passport photo and final KYC verification will become available when a booking reaches the pilgrim-details stage.",
                        "Фото паспорта и финальная KYC-проверка станут доступны, когда бронирование перейдёт к этапу данных паломника.",
                        "Pasport rasmi va yakuniy KYC tekshiruvi bron ziyoratchi ma’lumotlari bosqichiga o‘tganda ochiladi.",
                        "Паспорт расми ва якуний KYC текшируви брон зиёратчи маълумотлари босқичига ўтганда очилади."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .iumrahCard()
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 10) {
                if isSaving { ProgressView().tint(.white) }
                Image(systemName: "checkmark.circle.fill")
                Text(tr("Save your details", "Сохранить Ваши данные", "Ma’lumotlarni saqlash", "Маълумотларни сақлаш"))
                Spacer(minLength: 8)
            }
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(!canSave || isSaving)
    }

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func secureField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(focusedField == field ? Color.primary.opacity(0.18) : Color.primary.opacity(0.05), lineWidth: 1)
                }
        }
    }

    private func plainField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        contentType: UITextContentType?,
        capitalization: TextInputAutocapitalization
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                }
        }
    }

    private func phoneField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            TextField("+998 90 123 45 67", text: text)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                }
                .onChange(of: text.wrappedValue) { _, raw in
                    let formatted = Self.formatPhoneInput(raw)
                    if formatted != raw { text.wrappedValue = formatted }
                }
        }
    }

    private func dateField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                TextField("DD.MM.YYYY", text: text)
                    .keyboardType(.numberPad)
                    .textContentType(.none)
                    .onChange(of: text.wrappedValue) { _, raw in
                        let value = Self.formatDateInput(raw)
                        if value != raw { text.wrappedValue = value }
                    }
                Spacer(minLength: 0)
                if text.wrappedValue.count == 10 {
                    Image(systemName: Self.isoDate(text.wrappedValue) == nil ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(Self.isoDate(text.wrappedValue) == nil ? Color.red : Color.green)
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 56)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var genderTitle: String {
        switch gender {
        case "male": return tr("Male", "Мужской", "Erkak", "Эркак")
        case "female": return tr("Female", "Женский", "Ayol", "Аёл")
        default: return tr("Gender", "Пол", "Jins", "Жинс")
        }
    }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var kycTrip: StoredBookingSession? {
        bookings.sessions
            .filter { !["COMPLETED", "CANCELLED"].contains($0.effectiveStatus.uppercased()) }
            .sorted { $0.booking.input.startDate < $1.booking.input.startDate }
            .first ?? bookings.sessions.first
    }

    private var savedMessage: String {
        tr("Your details are saved.", "Ваши данные сохранены.", "Ma’lumotlaringiz saqlandi.", "Маълумотларингиз сақланди.")
    }

    @MainActor
    private func loadProfile() {
        let profile = account.account
        firstName = nonEmpty(profile?.firstName, settings.firstName)
        lastName = nonEmpty(profile?.lastName, settings.lastName)
        phone = Self.formatPhoneInput(nonEmpty(profile?.phone, settings.phone))
        email = nonEmpty(profile?.email, settings.email)
        telegram = nonEmpty(profile?.telegram, settings.telegram)
        whatsapp = nonEmpty(profile?.whatsapp, settings.whatsapp)
        dateOfBirth = Self.displayDate(settings.dateOfBirth)
        gender = settings.gender
        nationality = settings.nationality
        emergencyName = settings.emergencyName
        emergencyPhone = Self.formatPhoneInput(settings.emergencyPhone)
        emergencyRelation = settings.emergencyRelation
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        saveMessage = nil
        defer { isSaving = false }

        let cleanFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = Self.normalizedPhone(phone)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTelegram = telegram.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWhatsapp = Self.normalizedPhone(whatsapp)

        settings.firstName = cleanFirstName
        settings.lastName = cleanLastName
        settings.phone = cleanPhone
        settings.email = cleanEmail
        settings.telegram = cleanTelegram
        settings.whatsapp = cleanWhatsapp
        settings.dateOfBirth = Self.isoDate(dateOfBirth) ?? ""
        settings.gender = gender
        settings.nationality = nationality.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.emergencyName = emergencyName.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.emergencyPhone = Self.normalizedPhone(emergencyPhone)
        settings.emergencyRelation = emergencyRelation.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if account.isAuthenticated {
                _ = try await account.updateProfile(
                    firstName: cleanFirstName,
                    lastName: cleanLastName,
                    phone: cleanPhone,
                    email: cleanEmail,
                    telegram: cleanTelegram,
                    whatsapp: cleanWhatsapp
                )
            }
            saveMessage = savedMessage
            IumrahHaptics.success()
        } catch {
            saveMessage = tr(
                "The profile could not be synced. Your local details remain saved.",
                "Не удалось синхронизировать профиль. Локальные данные сохранены.",
                "Profilni sinxronlab bo‘lmadi. Mahalliy ma’lumotlar saqlandi.",
                "Профилни синхронлаб бўлмади. Маҳаллий маълумотлар сақланди."
            )
            IumrahHaptics.error()
        }
    }

    private func nonEmpty(_ primary: String?, _ fallback: String) -> String {
        let value = primary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? fallback : value
    }

    private static func normalizedPhone(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        return digits.isEmpty ? "" : "+" + digits
    }

    private static func formatPhoneInput(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(15))
        return digits.isEmpty ? "" : "+" + digits
    }

    private static func formatDateInput(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(8))
        guard digits.count > 2 else { return digits }
        let day = String(digits.prefix(2))
        let afterDay = digits.dropFirst(2)
        guard afterDay.count > 2 else { return day + "." + String(afterDay) }
        let month = String(afterDay.prefix(2))
        return day + "." + month + "." + String(afterDay.dropFirst(2))
    }

    private static func isoDate(_ input: String) -> String? {
        let parts = input.split(separator: ".")
        guard parts.count == 3,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let year = Int(parts[2]),
              year >= 1900, year <= 2100,
              let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func displayDate(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3 else { return iso }
        return "\(parts[2]).\(parts[1]).\(parts[0])"
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
