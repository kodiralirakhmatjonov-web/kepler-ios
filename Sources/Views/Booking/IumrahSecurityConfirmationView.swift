import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import UIKit

struct IumrahSecurityConfirmationView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var account: IumrahAccountStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var passportNumber = ""
    @State private var dateOfBirthInput = ""
    @State private var passportExpiryDateInput = ""
    @State private var gender = ""
    @State private var nationality = ""
    @State private var phone = "+998"
    @State private var email = ""
    @State private var telegram = ""
    @State private var emergencyName = ""
    @State private var emergencyPhone = "+998"
    @State private var emergencyRelation = ""
    @State private var holderConfirmed = false
    @State private var passportPhotoItem: PhotosPickerItem?
    @State private var passportPhotoData: Data?
    @State private var passportPreview: UIImage?
    @State private var passportContentType = "image/jpeg"
    @State private var existing: IumrahSecurityConfirmation?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var isPreparingPhoto = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private let service = BookingService()
    private let accountService = IumrahAccountService()

    private enum Field: Hashable {
        case firstName, lastName, passport
    }

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    private var normalizedPassport: String {
        passportNumber
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private var hasPassportPhoto: Bool {
        passportPhotoData != nil || existing?.hasPassportPhoto == true
    }

    private var canSubmit: Bool {
        validName(firstName)
            && validName(lastName)
            && normalizedPassport.count >= 5
            && normalizedPassport.count <= 20
            && Self.isoDate(dateOfBirthInput) != nil
            && Self.isoDate(passportExpiryDateInput) != nil
            && !gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !nationality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isUsablePhone(phone)
            && validName(emergencyName)
            && isUsablePhone(emergencyPhone)
            && holderConfirmed
            && hasPassportPhoto
            && !isSubmitting
            && !isPreparingPhoto
    }

    private var smsCovered: Bool {
        normalizedPhone(phone).hasPrefix("+998")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                securityHero
                introCopy

                if isLoading {
                    loadingCard
                } else if let existing, existing.isConfirmed {
                    confirmedCard(existing)
                } else if let existing, existing.isPendingReview {
                    pendingReviewCard(existing)
                } else {
                    if let existing, existing.needsResubmission {
                        correctionCard(existing)
                    }
                    warningCard
                    passportForm
                    personalDetailsCard
                    contactDetailsCard
                    passportPhotoCard
                    holderConfirmation
                    privacyCard
                    submitButton
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 52)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.iumrahPageBackground)
        .navigationTitle("Iumrah Security")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Iumrah Security")
                        .font(.headline)
                    Text("Security Confirmation · KYC")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { await load() }
        .task(id: existing?.status) {
            guard existing?.isPendingReview == true else { return }
            await pollSecurityStatus()
        }
        .onChange(of: passportPhotoItem) { _, item in
            guard let item else { return }
            Task { await preparePassportPhoto(item) }
        }
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
            Label("Iumrah Security", systemImage: "lock.shield.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(tr(
                "Confirm the booking holder",
                "Подтверждение владельца бронирования",
                "Bron egasini tasdiqlash",
                "Брон эгасини тасдиқлаш"
            ))
            .font(.system(size: 29, weight: .bold, design: .rounded))
            .tracking(-0.5)

            Text(tr(
                "Iumrah Security links the passport profile to this trip and confirms the booking holder. Your information is used only to process and protect this booking.",
                "Iumrah Security привязывает паспортный профиль к этой поездке и подтверждает владельца бронирования. Данные используются только для оформления и защиты этого бронирования.",
                "Iumrah Security pasport profilini ushbu safarga bog‘laydi va bron egasini tasdiqlaydi. Ma’lumotlar faqat ushbu bronni rasmiylashtirish va himoya qilish uchun ishlatiladi.",
                "Iumrah Security паспорт профилини ушбу сафарга боғлайди ва брон эгасини тасдиқлайди. Маълумотлар фақат ушбу бронни расмийлаштириш ва ҳимоя қилиш учун ишлатилади."
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
                    "These passport details are used for your booking. Enter your first name, last name and passport number exactly as they appear in the passport. Incorrect details can prevent travel services from being issued correctly.",
                    "Эти паспортные данные используются именно в Вашем бронировании. Введите имя, фамилию и номер паспорта точно так, как они указаны в паспорте. Ошибка может помешать корректному оформлению услуг поездки.",
                    "Bu pasport ma’lumotlari aynan broningizda ishlatiladi. Ism, familiya va pasport raqamini pasportdagidek aniq kiriting. Xato ma’lumot safar xizmatlarini to‘g‘ri rasmiylashtirishga xalaqit berishi mumkin.",
                    "Бу паспорт маълумотлари айнан бронда ишлатилади. Исм, фамилия ва паспорт рақамини паспортдагидек аниқ киритинг. Хато маълумот сафар хизматларини тўғри расмийлаштиришга халақит бериши мумкин."
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

    private var passportForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Passport profile", "Паспортный профиль", "Pasport profili", "Паспорт профили"))
                        .font(.headline)
                    Text(tr("Booking holder", "Владелец бронирования", "Bron egasi", "Брон эгаси"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            securityField(
                title: tr("First name", "Имя", "Ism", "Исм"),
                placeholder: tr("Exactly as in passport", "Как в паспорте", "Pasportdagidek", "Паспортдагидек"),
                text: $firstName,
                field: .firstName,
                contentType: .givenName
            )

            securityField(
                title: tr("Last name", "Фамилия", "Familiya", "Фамилия"),
                placeholder: tr("Exactly as in passport", "Как в паспорте", "Pasportdagidek", "Паспортдагидек"),
                text: $lastName,
                field: .lastName,
                contentType: .familyName
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(tr("Passport number", "Номер паспорта", "Pasport raqami", "Паспорт рақами"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                TextField(tr("Passport number", "Номер паспорта", "Pasport raqami", "Паспорт рақами"), text: $passportNumber)
                    .textContentType(.none)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .passport)
                    .padding(.horizontal, 15)
                    .frame(height: 56)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(focusedField == .passport ? Color.primary.opacity(0.18) : Color.primary.opacity(0.05), lineWidth: 1)
                    }
                    .onChange(of: passportNumber) { _, value in
                        let normalized = value.uppercased().filter { $0.isLetter || $0.isNumber }
                        if normalized != value { passportNumber = normalized }
                    }
            }
        }
        .iumrahCard()
    }

    private var personalDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Personal details", "Личные данные", "Shaxsiy ma’lumotlar", "Шахсий маълумотлар"))
                        .font(.headline)
                    Text(tr("Saved to your owner profile", "Сохраняются в профиле владельца", "Ega profilida saqlanadi", "Эга профилида сақланади"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            securityDateField(
                title: tr("Date of birth", "Дата рождения", "Tug‘ilgan sana", "Туғилган сана"),
                text: $dateOfBirthInput
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
                    Text(gender == "male"
                         ? tr("Male", "Мужской", "Erkak", "Эркак")
                         : gender == "female"
                            ? tr("Female", "Женский", "Ayol", "Аёл")
                            : tr("Gender", "Пол", "Jins", "Жинс"))
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

            securityPlainField(
                title: tr("Citizenship", "Гражданство", "Fuqarolik", "Фуқаролик"),
                placeholder: tr("Uzbekistan", "Узбекистан", "O‘zbekiston", "Ўзбекистон"),
                text: $nationality,
                keyboard: .default,
                contentType: .countryName,
                capitalization: .words
            )

            securityDateField(
                title: tr("Passport expiry date", "Срок действия паспорта", "Pasport amal qilish muddati", "Паспорт амал қилиш муддати"),
                text: $passportExpiryDateInput
            )
        }
        .iumrahCard()
    }

    private var contactDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "phone.badge.checkmark.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Contacts & emergency", "Контакты и экстренная связь", "Aloqa va favqulodda kontakt", "Алоқа ва фавқулодда контакт"))
                        .font(.headline)
                    Text(tr("Used for this trip and your owner profile", "Используются для этой поездки и профиля владельца", "Safar va ega profili uchun ishlatiladi", "Сафар ва эга профили учун ишлатилади"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            securityPhoneField(
                title: tr("Phone", "Номер телефона", "Telefon", "Телефон"),
                text: $phone
            )

            if !smsCovered && !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .foregroundStyle(.orange)
                    Text(tr(
                        "SMS is temporarily unavailable for this country. Please continue with email or use your Google or Apple account. SMS verification in iumrah currently supports Uzbekistan numbers beginning with +998.",
                        "SMS для этой страны временно недоступны. Продолжите по электронной почте или воспользуйтесь аккаунтом Google или Apple. Сейчас SMS-подтверждение iumrah поддерживает номера Узбекистана, начинающиеся с +998.",
                        "Bu davlat uchun SMS vaqtincha mavjud emas. Email orqali davom eting yoki Google/Apple akkauntingizdan foydalaning. Hozir iumrah SMS tasdiqlashi +998 bilan boshlanuvchi O‘zbekiston raqamlarini qo‘llaydi.",
                        "Бу давлат учун SMS вақтинча мавжуд эмас. Email орқали давом этинг ёки Google/Apple аккаунтингиздан фойдаланинг. Ҳозир iumrah SMS тасдиқлаши +998 билан бошланувчи Ўзбекистон рақамларини қўллайди."
                    ))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.20), lineWidth: 0.8)
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "message.badge.fill")
                        .foregroundStyle(.blue)
                    Text(tr(
                        "SMS confirmation for +998 will be connected through DevSMS. Your number is saved now; the verification action is temporarily disabled.",
                        "SMS-подтверждение для +998 будет подключено через DevSMS. Номер уже сохраняется, а само подтверждение пока временно недоступно.",
                        "+998 uchun SMS tasdiqlash DevSMS orqali ulanadi. Raqamingiz hozir saqlanadi, tasdiqlash amali esa vaqtincha o‘chirilgan.",
                        "+998 учун SMS тасдиқлаш DevSMS орқали уланади. Рақамингиз ҳозир сақланади, тасдиқлаш амали эса вақтинча ўчирилган."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }

            securityPlainField(
                title: "Email",
                placeholder: "name@example.com",
                text: $email,
                keyboard: .emailAddress,
                contentType: .emailAddress,
                capitalization: .never
            )

            securityPlainField(
                title: "Telegram",
                placeholder: "@username",
                text: $telegram,
                keyboard: .default,
                contentType: nil,
                capitalization: .never
            )

            Divider()

            Text(tr("Emergency contact", "Экстренный контакт", "Favqulodda kontakt", "Фавқулодда контакт"))
                .font(.subheadline.weight(.semibold))

            securityPlainField(
                title: tr("Contact name", "Имя контакта", "Kontakt ismi", "Контакт исми"),
                placeholder: tr("Name and surname", "Имя и фамилия", "Ism va familiya", "Исм ва фамилия"),
                text: $emergencyName,
                keyboard: .default,
                contentType: .name,
                capitalization: .words
            )

            securityPhoneField(
                title: tr("Emergency phone", "Экстренный номер телефона", "Favqulodda telefon", "Фавқулодда телефон"),
                text: $emergencyPhone
            )

            securityPlainField(
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

    private func securityPlainField(
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

    private func securityPhoneField(title: String, text: Binding<String>) -> some View {
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
                    let value = Self.formatPhoneInput(raw)
                    if value != raw { text.wrappedValue = value }
                }
        }
    }

    private func securityDateField(title: String, text: Binding<String>) -> some View {
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

    private func securityField(
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

    private var passportPhotoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Passport photo", "Фото паспорта", "Pasport rasmi", "Паспорт расми"))
                        .font(.headline)
                    Text(tr(
                        "Attach the passport page with the holder photo and data.",
                        "Прикрепите страницу паспорта с фотографией и данными владельца.",
                        "Egasi rasmi va ma’lumotlari ko‘rsatilgan pasport sahifasini biriktiring.",
                        "Эгаси расми ва маълумотлари кўрсатилган паспорт саҳифасини бириктиринг."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: hasPassportPhoto ? "checkmark.circle.fill" : "photo.badge.plus")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(hasPassportPhoto ? .green : .secondary)
            }

            if let passportPreview {
                Image(uiImage: passportPreview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    }
            } else if existing?.hasPassportPhoto == true {
                Label(
                    tr("Passport photo attached", "Фото паспорта прикреплено", "Pasport rasmi biriktirilgan", "Паспорт расми бириктирилган"),
                    systemImage: "checkmark.shield.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            PhotosPicker(selection: $passportPhotoItem, matching: .images) {
                HStack {
                    if isPreparingPhoto { ProgressView().controlSize(.small) }
                    else { Image(systemName: "photo.on.rectangle.angled") }
                    Text(hasPassportPhoto
                         ? tr("Replace passport photo", "Заменить фото паспорта", "Pasport rasmini almashtirish", "Паспорт расмини алмаштириш")
                         : tr("Attach passport photo", "Прикрепить фото паспорта", "Pasport rasmini biriktirish", "Паспорт расмини бириктириш"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(height: 52)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
            }
            .buttonStyle(.plain)
            .disabled(isPreparingPhoto || isSubmitting)
        }
        .iumrahCard()
    }

    private var holderConfirmation: some View {
        Toggle(isOn: $holderConfirmed) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("I confirm these are my booking-holder details", "Подтверждаю данные владельца бронирования", "Bron egasi ma’lumotlarini tasdiqlayman", "Брон эгаси маълумотларини тасдиқлайман"))
                    .font(.subheadline.weight(.semibold))
                Text(tr(
                    "The entered details will be checked against the attached passport page before the security confirmation is completed.",
                    "Перед завершением подтверждения безопасности введённые данные будут сверены с прикреплённой страницей паспорта.",
                    "Xavfsizlik tasdiqlanishi yakunlanishidan oldin kiritilgan ma’lumotlar biriktirilgan pasport sahifasi bilan tekshiriladi.",
                    "Хавфсизлик тасдиқланиши якунланишидан олдин киритилган маълумотлар бириктирилган паспорт саҳифаси билан текширилади."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 17, weight: .semibold))
            Text(tr(
                "Your passport information is transmitted securely and is available only within the protected booking process. Iumrah Security never displays the full passport number on this status screen.",
                "Паспортные данные передаются по защищённому соединению и доступны только в защищённом процессе этого бронирования. На экране статуса Iumrah Security полный номер паспорта не отображается.",
                "Pasport ma’lumotlari himoyalangan aloqa orqali uzatiladi va faqat ushbu bronning xavfsiz jarayonida ishlatiladi. Iumrah Security holat ekranida pasportning to‘liq raqami ko‘rsatilmaydi.",
                "Паспорт маълумотлари ҳимояланган алоқа орқали узатилади ва фақат ушбу броннинг хавфсиз жараёнида ишлатилади. Iumrah Security ҳолат экранида паспортнинг тўлиқ рақами кўрсатилмайди."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var submitButton: some View {
        Button {
            focusedField = nil
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting { ProgressView().controlSize(.small) }
                else { Image(systemName: "paperplane.fill") }
                Text(tr(
                    "Start security check",
                    "Начать проверку безопасности",
                    "Xavfsizlik tekshiruvini boshlash",
                    "Хавфсизлик текширувини бошлаш"
                ))
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.45)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(tr("Checking security status…", "Проверяем статус безопасности…", "Xavfsizlik holati tekshirilmoqda…", "Хавфсизлик ҳолати текширилмоқда…"))
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func pendingReviewCard(_ value: IumrahSecurityConfirmation) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = securityRemainingSeconds(value, now: context.date)
            let timedOut = remaining <= 0

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: timedOut ? "hourglass.circle.fill" : "lock.shield.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(timedOut ? Color.orange : Color.blue)
                        .frame(width: 50, height: 50)
                        .background((timedOut ? Color.orange : Color.blue).opacity(0.10), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(timedOut
                             ? tr("Additional verification", "Дополнительная проверка", "Qo‘shimcha tekshiruv", "Қўшимча текширув")
                             : tr("Security check in progress", "Проверка безопасности", "Xavfsizlik tekshiruvi", "Хавфсизлик текшируви"))
                            .font(.title3.weight(.bold))

                        Text(timedOut
                             ? tr(
                                "The system could not complete confirmation automatically within 20 minutes. Your data remains protected and is now waiting for manual verification. We will notify you as soon as the booking holder is confirmed.",
                                "Система не смогла завершить подтверждение автоматически в течение 20 минут. Ваши данные остаются защищёнными и теперь ожидают ручной проверки. Мы уведомим Вас сразу после подтверждения владельца бронирования.",
                                "Tizim 20 daqiqa ichida tasdiqlashni avtomatik yakunlay olmadi. Ma’lumotlaringiz himoyalangan va endi qo‘lda tekshirishni kutmoqda. Bron egasi tasdiqlangach, Sizga xabar beramiz.",
                                "Тизим 20 дақиқа ичида тасдиқлашни автоматик якунлай олмади. Маълумотларингиз ҳимояланган ва энди қўлда текширишни кутмоқда. Брон эгаси тасдиқлангач, Сизга хабар берамиз."
                             )
                             : tr(
                                "Your passport data has been received. The automatic security check is running now; we will confirm the booking holder shortly. This usually takes up to 20 minutes.",
                                "Паспортные данные получены. Автоматическая проверка уже идёт — скоро подтвердим владельца бронирования. Обычно это занимает до 20 минут.",
                                "Pasport ma’lumotlaringiz qabul qilindi. Avtomatik xavfsizlik tekshiruvi boshlandi — bron egasini tez orada tasdiqlaymiz. Odatda bu 20 daqiqagacha davom etadi.",
                                "Паспорт маълумотларингиз қабул қилинди. Автоматик хавфсизлик текшируви бошланди — брон эгасини тез орада тасдиқлаймиз. Одатда бу 20 дақиқагача давом этади."
                             ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !timedOut {
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Automatic verification", "Автоматическое подтверждение", "Avtomatik tasdiqlash", "Автоматик тасдиқлаш"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(securityCountdown(remaining))
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Divider()
                summaryRow(title: tr("Name", "Имя", "Ism", "Исм"), value: [value.firstName, value.lastName].joined(separator: " "))
                summaryRow(title: tr("Passport", "Паспорт", "Pasport", "Паспорт"), value: value.passportLast4.isEmpty ? "—" : "•••• \(value.passportLast4)")
                summaryRow(
                    title: tr("Status", "Статус", "Holat", "Ҳолат"),
                    value: timedOut
                        ? tr("Manual verification", "Ручная проверка", "Qo‘lda tekshirish", "Қўлда текшириш")
                        : tr("Protected verification", "Защищённая проверка", "Himoyalangan tekshiruv", "Ҳимояланган текширув")
                )
            }
            .iumrahCard()
        }
    }

    private func confirmedCard(_ value: IumrahSecurityConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 50, height: 50)
                    .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Identity confirmed", "Личность подтверждена", "Shaxs tasdiqlandi", "Шахс тасдиқланди"))
                        .font(.title3.weight(.bold))
                    Text(tr(
                        "The booking holder has been confirmed. Your passport profile is securely linked to this trip and the booking is protected by Iumrah Security.",
                        "Владелец бронирования подтверждён. Паспортный профиль безопасно привязан к этой поездке, а бронирование защищено Iumrah Security.",
                        "Bron egasi tasdiqlandi. Pasport profilingiz ushbu safarga xavfsiz bog‘landi va bron Iumrah Security bilan himoyalangan.",
                        "Брон эгаси тасдиқланди. Паспорт профилингиз ушбу сафарга хавфсиз боғланди ва брон Iumrah Security билан ҳимояланган."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
            summaryRow(title: tr("Name", "Имя", "Ism", "Исм"), value: [value.firstName, value.lastName].joined(separator: " "))
            summaryRow(title: tr("Passport", "Паспорт", "Pasport", "Паспорт"), value: value.passportLast4.isEmpty ? "—" : "•••• \(value.passportLast4)")
            summaryRow(title: tr("Status", "Статус", "Holat", "Ҳолат"), value: tr("Confirmed", "Подтверждено", "Tasdiqlandi", "Тасдиқланди"))
        }
        .iumrahCard()
    }

    private func correctionCard(_ value: IumrahSecurityConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                value.normalizedStatus == "rejected"
                    ? tr("Verification rejected", "Подтверждение отклонено", "Tasdiqlash rad etildi", "Тасдиқлаш рад этилди")
                    : tr("Please correct the profile", "Исправьте данные профиля", "Profilni tuzating", "Профилни тузатинг"),
                systemImage: "arrow.triangle.2.circlepath"
            )
            .font(.headline)
            .foregroundStyle(.orange)

            if !value.reviewNote.isEmpty {
                Text(value.reviewNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func securitySubmittedDate(_ value: IumrahSecurityConfirmation) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value.submittedAt) { return date }
        return ISO8601DateFormatter().date(from: value.submittedAt)
    }

    private func securityRemainingSeconds(_ value: IumrahSecurityConfirmation, now: Date = .now) -> Int {
        guard let submitted = securitySubmittedDate(value) else { return 0 }
        let deadline = submitted.addingTimeInterval(20 * 60)
        return max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
    }

    private func securityCountdown(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    @MainActor
    private func pollSecurityStatus() async {
        guard let session else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                let response = try await service.securityConfirmation(id: bookingID, accessToken: session.accessToken)
                if let confirmation = response.confirmation {
                    existing = confirmation
                    if !confirmation.isPendingReview { return }
                }
            } catch is CancellationError {
                return
            } catch {
                // Background status polling must never replace the protected UI with an error.
            }
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let session else {
            errorMessage = tr("Booking not found.", "Бронирование не найдено.", "Bron topilmadi.", "Брон топилмади.")
            return
        }

        if firstName.isEmpty { firstName = session.booking.pilgrimProfile?.firstName ?? account.account?.firstName ?? settings.firstName }
        if lastName.isEmpty { lastName = session.booking.pilgrimProfile?.lastName ?? account.account?.lastName ?? settings.lastName }
        if dateOfBirthInput.isEmpty { dateOfBirthInput = Self.displayDate(settings.dateOfBirth) }
        if gender.isEmpty { gender = settings.gender }
        if nationality.isEmpty { nationality = settings.nationality.isEmpty ? "Uzbekistan" : settings.nationality }
        if phone == "+998" {
            let accountPhone = account.account?.phone ?? ""
            let saved = accountPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? settings.phone : accountPhone
            if !saved.isEmpty { phone = Self.formatPhoneInput(saved) }
        }
        if email.isEmpty {
            let accountEmail = account.account?.email ?? ""
            email = accountEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? settings.email : accountEmail
        }
        if telegram.isEmpty {
            let accountTelegram = account.account?.telegram ?? ""
            telegram = accountTelegram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? settings.telegram : accountTelegram
        }
        if emergencyName.isEmpty { emergencyName = settings.emergencyName }
        if emergencyPhone == "+998", !settings.emergencyPhone.isEmpty { emergencyPhone = Self.formatPhoneInput(settings.emergencyPhone) }
        if emergencyRelation.isEmpty { emergencyRelation = settings.emergencyRelation }

        do {
            let response = try await service.securityConfirmation(id: bookingID, accessToken: session.accessToken)
            existing = response.confirmation
            if let value = response.confirmation, value.canEdit {
                if firstName.isEmpty { firstName = value.firstName }
                if lastName.isEmpty { lastName = value.lastName }
            }
        } catch APIError.status(let code) where code == 404 {
            existing = nil
        } catch {
            errorMessage = L10n.error(error, settings.language)
        }
    }

    @MainActor
    private func preparePassportPhoto(_ item: PhotosPickerItem) async {
        isPreparingPhoto = true
        errorMessage = nil
        defer { isPreparingPhoto = false }
        do {
            guard let raw = try await item.loadTransferable(type: Data.self), !raw.isEmpty else {
                throw APIError.invalidResponse
            }
            let optimized = optimizedPassportImage(raw)
            passportPhotoData = optimized.data
            passportContentType = optimized.contentType
            passportPreview = UIImage(data: optimized.data)
        } catch {
            passportPhotoData = nil
            passportPreview = nil
            errorMessage = tr(
                "Could not prepare the passport photo.",
                "Не удалось подготовить фото паспорта.",
                "Pasport rasmini tayyorlab bo‘lmadi.",
                "Паспорт расмини тайёрлаб бўлмади."
            )
        }
    }

    @MainActor
    private func submit() async {
        guard canSubmit, let session else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            if let passportPhotoData {
                let upload = try await service.uploadSecurityPassport(
                    id: bookingID,
                    accessToken: session.accessToken,
                    data: passportPhotoData,
                    contentType: passportContentType
                )
                existing = upload.confirmation
            }

            let response = try await service.submitSecurityConfirmation(
                id: bookingID,
                accessToken: session.accessToken,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                passportNumber: normalizedPassport
            )
            guard let confirmation = response.confirmation else { throw APIError.invalidResponse }
            existing = confirmation

            persistOwnerProfileLocally()
            await persistOwnerAccountProfile()
            await syncOwnerTravelerFromKYC(
                session: session,
                passportNumber: normalizedPassport,
                passportPhotoData: passportPhotoData,
                passportContentType: passportContentType
            )

            passportNumber = ""
            holderConfirmed = false
            passportPhotoData = nil
            passportPreview = nil
            passportPhotoItem = nil
            IumrahHaptics.success()
        } catch APIError.server(_, let message) where message == "IDENTITY_CONFIRMATION_NOT_AVAILABLE" {
            errorMessage = tr(
                "Security Confirmation becomes available only after availability is confirmed and the booking moves to payment and pilgrim details.",
                "Security Confirmation доступен только после подтверждения наличия, когда бронирование перейдёт к оплате и данным паломников.",
                "Security Confirmation faqat mavjudlik tasdiqlanib, bron to‘lov va ziyoratchi ma’lumotlari bosqichiga o‘tgandan keyin ochiladi.",
                "Security Confirmation фақат мавжудлик тасдиқланиб, брон тўлов ва зиёратчи маълумотлари босқичига ўтгандан кейин очилади."
            )
            IumrahHaptics.error()
        } catch APIError.server(_, let message) where message == "IDENTITY_PASSPORT_PHOTO_REQUIRED" {
            errorMessage = tr(
                "Attach a passport photo before sending the profile.",
                "Прикрепите фото паспорта перед отправкой профиля.",
                "Profilni yuborishdan oldin pasport rasmini biriktiring.",
                "Профилни юборишдан олдин паспорт расмини бириктиринг."
            )
            IumrahHaptics.error()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func persistOwnerAccountProfile() async {
        guard account.isAuthenticated, let current = account.account else { return }
        let resolvedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? current.email : email.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTelegram = telegram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? current.telegram : telegram.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try? await account.updateProfile(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: normalizedPhone(phone),
            email: resolvedEmail,
            telegram: resolvedTelegram,
            whatsapp: current.whatsapp
        )
    }

    @MainActor
    private func persistOwnerProfileLocally() {
        settings.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.phone = normalizedPhone(phone)
        settings.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.dateOfBirth = Self.isoDate(dateOfBirthInput) ?? ""
        settings.gender = gender
        settings.nationality = nationality.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.emergencyName = emergencyName.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.emergencyPhone = normalizedPhone(emergencyPhone)
        settings.emergencyRelation = emergencyRelation.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.telegram = telegram.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func syncOwnerTravelerFromKYC(
        session: StoredBookingSession,
        passportNumber: String,
        passportPhotoData: Data?,
        passportContentType: String
    ) async {
        guard let token = account.bearerToken,
              let dob = Self.isoDate(dateOfBirthInput),
              let expiry = Self.isoDate(passportExpiryDateInput) else { return }
        do {
            let checkout = try await accountService.checkout(
                bookingID: bookingID,
                bookingToken: session.accessToken,
                accountToken: token
            )
            guard var owner = checkout.travelers.first(where: { ($0.relationship ?? "").lowercased() == "self" }) ?? checkout.travelers.first(where: { $0.position == 1 }) else { return }
            owner.relationship = "self"
            owner.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            owner.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            owner.gender = gender
            owner.dateOfBirth = dob
            owner.nationality = nationality.trimmingCharacters(in: .whitespacesAndNewlines)
            if owner.residenceCountry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                owner.residenceCountry = owner.nationality
            }
            owner.passportNumber = passportNumber
            owner.passportExpiryDate = expiry
            // Client asks only for citizenship. The backend compatibility field is derived from it.
            owner.passportIssuingCountry = owner.nationality
            owner.phone = normalizedPhone(phone)
            owner.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
            owner.emergencyName = emergencyName.trimmingCharacters(in: .whitespacesAndNewlines)
            owner.emergencyPhone = normalizedPhone(emergencyPhone)
            owner.emergencyRelation = emergencyRelation.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await accountService.saveTraveler(bookingID: bookingID, position: owner.position, form: owner, token: token)
            if let passportPhotoData, !passportPhotoData.isEmpty {
                try await accountService.uploadPassport(
                    bookingID: bookingID,
                    position: owner.position,
                    data: passportPhotoData,
                    contentType: passportContentType,
                    token: token
                )
            }
        } catch {
            // KYC remains successful even if the account traveler mirror is temporarily unavailable.
            // The traveler editor will still prefill the non-sensitive owner profile locally.
        }
    }

    private func normalizedPhone(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return "+" + digits
    }

    private func isUsablePhone(_ value: String) -> Bool {
        let digits = value.filter(\.isNumber)
        return digits.count >= 9 && digits.count <= 15
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
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = Calendar(identifier: .gregorian)
        parser.dateFormat = "dd.MM.yyyy"
        parser.isLenient = false
        guard let date = parser.date(from: display) else { return nil }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.calendar = Calendar(identifier: .gregorian)
        output.dateFormat = "yyyy-MM-dd"
        return output.string(from: date)
    }

    private func optimizedPassportImage(_ data: Data) -> (data: Data, contentType: String) {
        guard let image = UIImage(data: data) else { return (data, "image/jpeg") }
        let maxDimension: CGFloat = 2200
        let largest = max(image.size.width, image.size.height)
        let scale = largest > maxDimension ? maxDimension / largest : 1
        let target = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))

        let renderer = UIGraphicsImageRenderer(size: target)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return (rendered.jpegData(compressionQuality: 0.86) ?? data, "image/jpeg")
    }

    private func validName(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 80 else { return false }
        return trimmed.unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar)
                || CharacterSet.whitespaces.contains(scalar)
                || scalar == "-" || scalar == "'" || scalar == "’"
        }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ uzCyrl: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCyrl
        }
    }
}
