import PhotosUI
import SwiftUI

/// Dedicated editor for one companion from Account → Who is traveling with you.
/// Emergency contact is intentionally not edited here: it is account-level and
/// lives in IumrahEmergencyContactView.
struct IumrahTravelerProfileView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String
    let traveler: IumrahTravelerForm
    var onSaved: (() -> Void)? = nil

    @State private var form: IumrahTravelerForm
    @State private var dateOfBirthInput: String
    @State private var passportExpiryInput: String
    @State private var passportPhoto: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = IumrahAccountService()

    init(bookingID: String, traveler: IumrahTravelerForm, onSaved: (() -> Void)? = nil) {
        self.bookingID = bookingID
        self.traveler = traveler
        self.onSaved = onSaved
        _form = State(initialValue: traveler)
        _dateOfBirthInput = State(initialValue: Self.displayDate(traveler.dateOfBirth))
        _passportExpiryInput = State(initialValue: Self.displayDate(traveler.passportExpiryDate))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                hero
                personalCard
                passportCard
                contactCard
                emergencyReuseCard

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                saveButton
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 14)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .scrollDismissesKeyboard(.interactively)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                IumrahIconBadge(
                    systemName: relationshipIcon,
                    role: form.completed ? .success : .profile,
                    size: 58,
                    symbolSize: 23,
                    cornerRadius: 18
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(relationshipTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(pageTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(tr(
                        "Separate traveler profile for tickets and hotels",
                        "Отдельный профиль участника для билетов и отелей",
                        "Chipta va mehmonxona uchun alohida sayohatchi profili",
                        "Чипта ва меҳмонхона учун алоҳида саёҳатчи профили"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                statusChip(
                    icon: nameReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    text: nameReady ? tr("Personal data ready", "Личные данные готовы", "Shaxsiy ma’lumotlar tayyor", "Шахсий маълумотлар тайёр") : tr("Personal data", "Личные данные", "Shaxsiy ma’lumotlar", "Шахсий маълумотлар"),
                    ready: nameReady
                )
                statusChip(
                    icon: passportReady ? "checkmark.circle.fill" : "passport.fill",
                    text: passportReady ? maskedPassport : tr("Passport", "Паспорт", "Pasport", "Паспорт"),
                    ready: passportReady
                )
            }
        }
        .iumrahCard()
    }

    private var personalCard: some View {
        section(
            title: tr("Personal details", "Личные данные", "Shaxsiy ma’lumotlar", "Шахсий маълумотлар"),
            icon: "person.text.rectangle.fill"
        ) {
            field(tr("First name", "Имя", "Ism", "Исм"), $form.firstName, contentType: .givenName)
            field(tr("Middle name", "Отчество / второе имя", "Otasining ismi", "Отасининг исми"), $form.middleName, contentType: .middleName)
            field(tr("Last name", "Фамилия", "Familiya", "Фамилия"), $form.lastName, contentType: .familyName)

            Menu {
                Button { form.gender = "male"; IumrahHaptics.selection() } label: {
                    Label(tr("Male", "Мужской", "Erkak", "Эркак"), systemImage: form.gender == "male" ? "checkmark" : "person.fill")
                }
                Button { form.gender = "female"; IumrahHaptics.selection() } label: {
                    Label(tr("Female", "Женский", "Ayol", "Аёл"), systemImage: form.gender == "female" ? "checkmark" : "person.fill")
                }
            } label: {
                menuRow(
                    icon: "person.2.fill",
                    title: tr("Gender", "Пол", "Jins", "Жинс"),
                    value: genderTitle
                )
            }

            smartDateField(
                tr("Date of birth", "Дата рождения", "Tug‘ilgan sana", "Туғилган сана"),
                text: $dateOfBirthInput
            )

            field(
                tr("Citizenship", "Гражданство", "Fuqarolik", "Фуқаролик"),
                $form.nationality,
                contentType: .countryName
            )
        }
    }

    private var passportCard: some View {
        section(
            title: tr("Passport", "Загранпаспорт", "Pasport", "Паспорт"),
            icon: "passport.fill"
        ) {
            field(
                tr("Passport number", "Номер паспорта", "Pasport raqami", "Паспорт рақами"),
                $form.passportNumber,
                keyboard: .asciiCapable,
                contentType: .none,
                capitalization: .characters
            )

            smartDateField(
                tr("Expiry date", "Срок действия", "Amal qilish muddati", "Амал қилиш муддати"),
                text: $passportExpiryInput
            )

            PhotosPicker(selection: $passportPhoto, matching: .images) {
                HStack(spacing: 12) {
                    IumrahIconBadge(
                        systemName: passportPhoto != nil || form.hasPassport ? "checkmark.circle.fill" : "camera.fill",
                        role: passportPhoto != nil || form.hasPassport ? .success : .document,
                        size: 42,
                        symbolSize: 17,
                        cornerRadius: 14
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(passportPhoto != nil || form.hasPassport
                             ? tr("Passport photo attached", "Фото паспорта прикреплено", "Pasport rasmi biriktirilgan", "Паспорт расми бириктирилган")
                             : tr("Attach passport photo", "Добавить фото паспорта", "Pasport rasmini qo‘shish", "Паспорт расмини қўшиш"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(tr(
                            "Clear photo of the information page",
                            "Чёткое фото страницы с данными",
                            "Ma’lumotlar sahifasining aniq rasmi",
                            "Маълумотлар саҳифасининг аниқ расми"
                        ))
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
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var contactCard: some View {
        section(
            title: tr("Traveler contacts", "Контакты участника", "Sayohatchi kontaktlari", "Саёҳатчи контактлари"),
            icon: "phone.fill"
        ) {
            field(
                tr("Phone", "Номер телефона", "Telefon", "Телефон"),
                $form.phone,
                keyboard: .phonePad,
                contentType: .telephoneNumber,
                capitalization: .never
            )
            field(
                "Email",
                $form.email,
                keyboard: .emailAddress,
                contentType: .emailAddress,
                capitalization: .never
            )
        }
    }

    private var emergencyReuseCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sos.circle.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 42, height: 42)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Emergency contact is shared", "Экстренный контакт общий", "Favqulodda kontakt umumiy", "Фавқулодда контакт умумий"))
                    .font(.headline)
                Text(tr(
                    "It is managed once in Who is traveling with you and is not repeated on every traveler profile.",
                    "Он настраивается один раз в разделе «Кто едет с Вами» и не заполняется заново в каждой карточке участника.",
                    "U «Siz bilan kim bormoqda» bo‘limida bir marta sozlanadi va har bir sayohatchi profilida qayta kiritilmaydi.",
                    "У «Сиз билан ким бормоқда» бўлимида бир марта созланади ва ҳар бир саёҳатчи профилида қайта киритилмайди."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 10) {
                if isSaving { ProgressView().tint(.white) }
                Image(systemName: "checkmark.circle.fill")
                Text(tr("Save traveler details", "Сохранить данные участника", "Sayohatchi ma’lumotlarini saqlash", "Саёҳатчи маълумотларини сақлаш"))
                Spacer(minLength: 8)
            }
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(!canSave || isSaving)
    }

    private func section<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                IumrahIconBadge(systemName: icon, size: 40, symbolSize: 16, cornerRadius: 13)
                Text(title)
                    .font(.headline)
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
        capitalization: TextInputAutocapitalization = .words
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .asciiCapable)
            .padding(.horizontal, 15)
            .frame(height: 56)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func smartDateField(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            TextField("\(title) · DD.MM.YYYY", text: text)
                .keyboardType(.numberPad)
                .onChange(of: text.wrappedValue) { _, raw in
                    let formatted = Self.formatDateInput(raw)
                    if formatted != raw { text.wrappedValue = formatted }
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

    private func menuRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .foregroundStyle(value.isEmpty ? Color.secondary : Color.primary)
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 15)
        .frame(height: 58)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statusChip(icon: String, text: String, ready: Bool) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ready ? Color.green : Color.secondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background((ready ? Color.green : Color.secondary).opacity(0.09), in: Capsule())
            .lineLimit(1)
    }

    private var pageTitle: String {
        let values = [form.firstName, form.middleName, form.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return values.isEmpty
            ? tr("Traveler \(form.position)", "Участник \(form.position)", "Sayohatchi \(form.position)", "Саёҳатчи \(form.position)")
            : values
    }

    private var relationshipTitle: String {
        switch form.relationship?.lowercased() {
        case "spouse": return tr("Spouse", "Муж или жена", "Turmush o‘rtog‘i", "Турмуш ўртоғи")
        case "mother": return tr("Mother", "Мама", "Ona", "Она")
        case "father": return tr("Father", "Папа", "Ota", "Ота")
        case "brother": return tr("Brother", "Брат", "Aka yoki uka", "Ака ёки ука")
        case "sister": return tr("Sister", "Сестра", "Opa yoki singil", "Опа ёки сингил")
        case "child": return tr("Child", "Ребёнок", "Farzand", "Фарзанд")
        case "relative": return tr("Relative", "Родственник", "Qarindosh", "Қариндош")
        case "friend": return tr("Friend", "Друг или подруга", "Do‘st", "Дўст")
        default: return tr("Traveler", "Участник поездки", "Sayohatchi", "Саёҳатчи")
        }
    }

    private var relationshipIcon: String {
        switch form.relationship?.lowercased() {
        case "spouse": return "heart.fill"
        case "child": return "figure.child"
        case "mother", "father", "brother", "sister", "relative", "friend": return "person.2.fill"
        default: return "person.crop.circle.fill"
        }
    }

    private var genderTitle: String {
        switch form.gender.lowercased() {
        case "male": return tr("Male", "Мужской", "Erkak", "Эркак")
        case "female": return tr("Female", "Женский", "Ayol", "Аёл")
        default: return tr("Select", "Выберите", "Tanlang", "Танланг")
        }
    }

    private var nameReady: Bool {
        !form.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !form.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var passportReady: Bool {
        !form.passportNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Self.isoDate(passportExpiryInput) != nil &&
        (form.hasPassport || passportPhoto != nil)
    }

    private var maskedPassport: String {
        let clean = form.passportNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > 4 else { return clean }
        return "•••• \(clean.suffix(4))"
    }

    private var canSave: Bool {
        nameReady &&
        Self.isoDate(dateOfBirthInput) != nil &&
        !form.gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !form.nationality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !form.passportNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Self.isoDate(passportExpiryInput) != nil
    }

    @MainActor
    private func save() async {
        guard let token = account.bearerToken,
              let dob = Self.isoDate(dateOfBirthInput),
              let expiry = Self.isoDate(passportExpiryInput) else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var payload = form
            payload.dateOfBirth = dob
            payload.passportExpiryDate = expiry
            payload.passportIssuingCountry = payload.nationality

            // Emergency contact is intentionally centralized in Account. Keep the
            // current server values unless empty, then fill from the shared profile.
            if payload.emergencyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                payload.emergencyName = settings.emergencyName
            }
            if payload.emergencyPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                payload.emergencyPhone = settings.emergencyPhone
            }
            if payload.emergencyRelation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                payload.emergencyRelation = settings.emergencyRelation
            }

            _ = try await service.saveTraveler(
                bookingID: bookingID,
                position: payload.position,
                form: payload,
                token: token
            )

            if let passportPhoto,
               let data = try await passportPhoto.loadTransferable(type: Data.self) {
                let type = passportPhoto.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                try await service.uploadPassport(
                    bookingID: bookingID,
                    position: payload.position,
                    data: data,
                    contentType: type,
                    token: token
                )
            }

            IumrahHaptics.success()
            onSaved?()
            dismiss()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
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

    private static func displayDate(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "-")
        guard parts.count == 3 else { return value }
        return "\(parts[2]).\(parts[1]).\(parts[0])"
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

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
