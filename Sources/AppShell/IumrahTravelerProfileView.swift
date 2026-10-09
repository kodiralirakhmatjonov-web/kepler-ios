import PhotosUI
import SwiftUI
import UIKit

/// Passport-first traveler editor.
/// A passport photo is sufficient; manual data is optional and only speeds up processing.
struct IumrahTravelerProfileView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String
    let traveler: IumrahTravelerForm
    var onSaved: (() -> Void)? = nil

    @State private var form: IumrahTravelerForm
    @State private var passportPhoto: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var previewData: Data?
    @State private var showManual = false
    @State private var dateOfBirthInput: String
    @State private var passportExpiryInput: String
    @State private var isUploading = false
    @State private var isSavingManual = false
    @State private var uploadedInSession = false
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

    private var passportReady: Bool { traveler.hasPassport || uploadedInSession }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                securityAnimationCard
                passportCard
                manualCard

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: passportPhoto) { _, item in
            guard let item else { return }
            Task { await preparePreview(item) }
        }
    }

    private var securityAnimationCard: some View {
        VStack(spacing: 10) {
            LoopingVideoView(resource: "iumrah-security-identity", gravity: .resizeAspect)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            HStack(spacing: 9) {
                Image(systemName: "lock.shield.fill")
                Text(tr("Passport data is handled securely for your booking.", "Паспортные данные защищены и используются только для оформления поездки.", "Pasport ma’lumotlari himoyalangan va faqat safarni rasmiylashtirish uchun ishlatiladi.", "Паспорт маълумотлари ҳимояланган ва фақат сафарни расмийлаштириш учун ишлатилади."))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(tr("Passport", "Паспорт", "Pasport", "Паспорт"), systemImage: "passport.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if passportReady {
                    Label(tr("Attached", "Прикреплён", "Biriktirilgan", "Бириктирилган"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
            }

            Text(tr("Attach passport", "Прикрепите паспорт", "Pasportni biriktiring", "Паспортни бириктиринг"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.55)

            Text(tr(
                "A clear photo of the information page is enough. Manual entry below is optional.",
                "Достаточно чёткой фотографии страницы с данными. Заполнять данные вручную ниже не обязательно.",
                "Ma’lumotlar sahifasining aniq rasmi yetarli. Quyidagi ma’lumotlarni qo‘lda kiritish shart emas.",
                "Маълумотлар саҳифасининг аниқ расми етарли. Қуйидаги маълумотларни қўлда киритиш шарт эмас."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var passportCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                IumrahIconBadge(
                    systemName: "person.text.rectangle.fill",
                    role: passportReady ? .success : .document,
                    size: 50,
                    symbolSize: 20,
                    cornerRadius: 17
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Passport information page", "Страница паспорта с данными", "Pasport ma’lumotlar sahifasi", "Паспорт маълумотлар саҳифаси"))
                        .font(.headline)
                    Text(tr(
                        "The holder photo, passport number, name and dates must all fit in the frame.",
                        "В кадре должны полностью быть видны фотография владельца, номер паспорта, имя и даты.",
                        "Kadrda egasining rasmi, pasport raqami, ism va sanalar to‘liq ko‘rinsin.",
                        "Кадрда эгасининг расми, паспорт рақами, исм ва саналар тўлиқ кўринсин."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 190)
                    .background(Color.black.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Label(
                            tr("If the photo is blurry, choose another", "Если фото нечёткое — выберите другое", "Rasm xira bo‘lsa, boshqasini tanlang", "Расм хира бўлса, бошқасини танланг"),
                            systemImage: "viewfinder"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 38)
                        .background(.black.opacity(0.62), in: Capsule())
                        .padding(12)
                    }
            } else if passportReady {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("Passport received", "Паспорт получен", "Pasport qabul qilindi", "Паспорт қабул қилинди"))
                            .font(.headline)
                        Text(tr("You can replace it if you want to send a clearer photo.", "При необходимости можно заменить его более чёткой фотографией.", "Kerak bo‘lsa, aniqroq rasm bilan almashtirishingiz mumkin.", "Керак бўлса, аниқроқ расм билан алмаштиришингиз мумкин."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Label {
                Text(tr(
                    "Make sure every passport field is visible and readable. These details are used to issue airline tickets, book hotels and prepare the booking documents.",
                    "Обратите внимание, чтобы все данные паспорта были видны и читались. Они используются для покупки авиабилета, бронирования отеля и оформления документов бронирования.",
                    "Pasportdagi barcha ma’lumotlar ko‘rinsin va o‘qilsin. Ular aviachipta, mehmonxona va bron hujjatlarini rasmiylashtirish uchun ishlatiladi.",
                    "Паспортдаги барча маълумотлар кўринсин ва ўқилсин. Улар авиачипта, меҳмонхона ва брон ҳужжатларини расмийлаштириш учун ишлатилади."
                ))
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            PhotosPicker(selection: $passportPhoto, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(previewImage == nil
                         ? (passportReady ? tr("Replace passport photo", "Заменить фото паспорта", "Pasport rasmini almashtirish", "Паспорт расмини алмаштириш") : tr("Choose passport photo", "Выбрать фото паспорта", "Pasport rasmini tanlash", "Паспорт расмини танлаш"))
                         : tr("Choose another photo", "Выбрать другое фото", "Boshqa rasm tanlash", "Бошқа расм танлаш"))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 15)
                .frame(height: 52)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)

            if previewData != nil {
                Button {
                    Task { await uploadPassport() }
                } label: {
                    HStack(spacing: 10) {
                        if isUploading { ProgressView().tint(.white) }
                        Image(systemName: "arrow.up.doc.fill")
                        Text(tr("Attach passport", "Прикрепить паспорт", "Pasportni biriktirish", "Паспортни бириктириш"))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isUploading)
            }
        }
        .iumrahCard()
    }

    private var manualCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                IumrahHaptics.selection()
                withAnimation(.snappy(duration: 0.24)) { showManual.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    IumrahIconBadge(systemName: "square.and.pencil", role: .profile, size: 46, symbolSize: 18, cornerRadius: 15)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(tr("Fill in manually", "Заполнить вручную", "Qo‘lda to‘ldirish", "Қўлда тўлдириш"))
                                .font(.headline)
                            Text(tr("Optional", "Не обязательно", "Ixtiyoriy", "Ихтиёрий"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .frame(height: 23)
                                .background(Color.secondary.opacity(0.10), in: Capsule())
                        }
                        Text(tr(
                            "Manual details are not required, but they help our team process the booking faster.",
                            "Заполнять вручную не обязательно, но эти данные ускорят оформление бронирования.",
                            "Qo‘lda to‘ldirish shart emas, lekin bu ma’lumotlar bronni tezroq rasmiylashtirishga yordam beradi.",
                            "Қўлда тўлдириш шарт эмас, лекин бу маълумотлар бронни тезроқ расмийлаштиришга ёрдам беради."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: showManual ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)

            if showManual {
                Divider()
                manualFields
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .iumrahCard()
    }

    private var manualFields: some View {
        VStack(spacing: 11) {
            textField(tr("First name as in passport", "Имя как в паспорте", "Pasportdagi ism", "Паспортдаги исм"), text: $form.firstName, capitalization: .words)
            textField(tr("Last name as in passport", "Фамилия как в паспорте", "Pasportdagi familiya", "Паспортдаги фамилия"), text: $form.lastName, capitalization: .words)
            textField(tr("Passport number", "Номер паспорта", "Pasport raqami", "Паспорт рақами"), text: $form.passportNumber, keyboard: .asciiCapable, capitalization: .characters)
            dateField(tr("Date of birth", "Дата рождения", "Tug‘ilgan sana", "Туғилган сана"), text: $dateOfBirthInput)
            dateField(tr("Passport expiry", "Срок действия паспорта", "Pasport muddati", "Паспорт муддати"), text: $passportExpiryInput)
            textField(tr("Citizenship", "Гражданство", "Fuqarolik", "Фуқаролик"), text: $form.nationality, capitalization: .words)

            Menu {
                Button(tr("Male", "Мужской", "Erkak", "Эркак")) { form.gender = "male" }
                Button(tr("Female", "Женский", "Ayol", "Аёл")) { form.gender = "female" }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill").foregroundStyle(.secondary).frame(width: 22)
                    Text(form.gender.isEmpty ? tr("Gender", "Пол", "Jins", "Жинс") : genderTitle)
                        .foregroundStyle(form.gender.isEmpty ? Color.secondary : Color.primary)
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 15)
                .frame(height: 54)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                Task { await saveManualDetails() }
            } label: {
                HStack(spacing: 10) {
                    if isSavingManual { ProgressView().tint(.white) }
                    Image(systemName: "checkmark")
                    Text(tr("Save manual details", "Сохранить ручные данные", "Qo‘lda kiritilganlarni saqlash", "Қўлда киритилганларни сақлаш"))
                    Spacer()
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(isSavingManual)
        }
    }

    private func textField(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .words
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(keyboard == .asciiCapable)
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func dateField(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar").foregroundStyle(.secondary).frame(width: 22)
            TextField("\(title) · DD.MM.YYYY", text: text)
                .keyboardType(.numberPad)
                .onChange(of: text.wrappedValue) { _, raw in
                    let formatted = Self.formatDateInput(raw)
                    if formatted != raw { text.wrappedValue = formatted }
                }
        }
        .padding(.horizontal, 15)
        .frame(height: 54)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    @MainActor
    private func preparePreview(_ item: PhotosPickerItem) async {
        errorMessage = nil
        do {
            guard let raw = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: raw),
                  let jpeg = image.jpegData(compressionQuality: 0.90) else {
                throw APIError.invalidResponse
            }
            previewImage = image
            previewData = jpeg
        } catch {
            previewImage = nil
            previewData = nil
            errorMessage = tr("Could not prepare this photo.", "Не удалось подготовить это фото.", "Bu rasmni tayyorlab bo‘lmadi.", "Бу расмни тайёрлаб бўлмади.")
        }
    }

    @MainActor
    private func uploadPassport() async {
        guard let token = account.bearerToken, let data = previewData else {
            errorMessage = tr("Sign in to attach the passport.", "Войдите в аккаунт, чтобы прикрепить паспорт.", "Pasportni biriktirish uchun akkauntga kiring.", "Паспортни бириктириш учун аккаунтга киринг.")
            return
        }

        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        do {
            try await service.uploadPassport(
                bookingID: bookingID,
                position: form.position,
                data: data,
                contentType: "image/jpeg",
                token: token
            )
            uploadedInSession = true
            IumrahHaptics.success()
            onSaved?()
        } catch {
            errorMessage = error.localizedDescription
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func saveManualDetails() async {
        guard let token = account.bearerToken else {
            errorMessage = tr("Sign in to save details.", "Войдите в аккаунт, чтобы сохранить данные.", "Ma’lumotlarni saqlash uchun akkauntga kiring.", "Маълумотларни сақлаш учун аккаунтга киринг.")
            return
        }

        var payload = form
        if !dateOfBirthInput.isEmpty {
            guard let value = Self.isoDate(dateOfBirthInput) else {
                errorMessage = tr("Check the date of birth.", "Проверьте дату рождения.", "Tug‘ilgan sanani tekshiring.", "Туғилган санани текширинг.")
                return
            }
            payload.dateOfBirth = value
        }
        if !passportExpiryInput.isEmpty {
            guard let value = Self.isoDate(passportExpiryInput) else {
                errorMessage = tr("Check the passport expiry date.", "Проверьте срок действия паспорта.", "Pasport muddatini tekshiring.", "Паспорт муддатини текширинг.")
                return
            }
            payload.passportExpiryDate = value
        }
        if payload.passportIssuingCountry.isEmpty { payload.passportIssuingCountry = payload.nationality }
        if payload.residenceCountry.isEmpty { payload.residenceCountry = payload.nationality }

        isSavingManual = true
        errorMessage = nil
        defer { isSavingManual = false }

        do {
            let saved = try await service.saveTraveler(
                bookingID: bookingID,
                position: payload.position,
                form: payload,
                token: token
            )
            form = saved
            IumrahHaptics.success()
            onSaved?()
        } catch {
            errorMessage = error.localizedDescription
            IumrahHaptics.error()
        }
    }

    private var pageTitle: String {
        let name = [form.firstName, form.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty
            ? tr("Traveler \(form.position)", "Участник \(form.position)", "Sayohatchi \(form.position)", "Саёҳатчи \(form.position)")
            : name
    }

    private var genderTitle: String {
        switch form.gender.lowercased() {
        case "male": return tr("Male", "Мужской", "Erkak", "Эркак")
        case "female": return tr("Female", "Женский", "Ayol", "Аёл")
        default: return tr("Gender", "Пол", "Jins", "Жинс")
        }
    }

    private static func formatDateInput(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(8))
        var result = ""
        for (index, character) in digits.enumerated() {
            if index == 2 || index == 4 { result.append(".") }
            result.append(character)
        }
        return result
    }

    private static func isoDate(_ value: String) -> String? {
        let parts = value.split(separator: ".")
        guard parts.count == 3,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]),
              (1...31).contains(day), (1...12).contains(month), (1900...2200).contains(year) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard calendar.date(from: DateComponents(year: year, month: month, day: day)) != nil else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func displayDate(_ value: String) -> String {
        let parts = value.split(separator: "-")
        guard parts.count == 3 else { return value }
        return "\(parts[2]).\(parts[1]).\(parts[0])"
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
