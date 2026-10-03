import SwiftUI

private enum IumrahLinkedContactKind: String, Identifiable {
    case phone
    case email

    var id: String { rawValue }
}

/// Canonical owner profile used by Account and reused by future bookings.
///
/// The screen intentionally keeps the visual language of iumrah Security while
/// separating two concepts that users understand immediately:
/// - booking details: passport-facing data used for travel services;
/// - account details: the identity and contacts linked to the iumrah account.
struct IumrahUserDataView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore

    private enum DataSection: String, CaseIterable, Identifiable {
        case booking
        case account
        var id: String { rawValue }
    }

    @State private var selectedSection: DataSection = .booking
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var telegram = ""
    @State private var whatsapp = ""
    @State private var dateOfBirth = ""
    @State private var gender = ""
    @State private var nationality = ""
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var contactChangeKind: IumrahLinkedContactKind?
    @FocusState private var focusedField: Field?
    @Namespace private var segmentNamespace

    private enum Field: Hashable {
        case firstName, lastName
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                securityHero
                sectionPicker
                introCopy
                warningCard

                Group {
                    switch selectedSection {
                    case .booking:
                        bookingContent
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    case .account:
                        accountContent
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .animation(.spring(response: 0.36, dampingFraction: 0.90), value: selectedSection)

                if let saveMessage {
                    Label(
                        saveMessage,
                        systemImage: saveMessage == savedMessage ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
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
        .sheet(item: $contactChangeKind) { kind in
            IumrahLinkedContactChangeView(
                kind: kind,
                currentValue: kind == .phone ? phone : email,
                onCompleted: { value in
                    switch kind {
                    case .phone:
                        phone = Self.formatPhoneInput(value)
                        settings.phone = Self.normalizedPhone(value)
                    case .email:
                        email = value
                        settings.email = value
                    }
                    saveMessage = nil
                }
            )
            .environmentObject(account)
            .environmentObject(settings)
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

    private var sectionPicker: some View {
        HStack(spacing: 6) {
            sectionButton(
                .booking,
                icon: "airplane",
                title: tr("Booking details", "Данные бронирования", "Bron ma’lumotlari", "Брон маълумотлари")
            )
            sectionButton(
                .account,
                icon: "person.crop.circle",
                title: tr("Account details", "Данные аккаунта", "Akkaunt ma’lumotlari", "Аккаунт маълумотлари")
            )
        }
        .padding(5)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.8)
        }
    }

    private func sectionButton(_ section: DataSection, icon: String, title: String) -> some View {
        let selected = selectedSection == section
        return Button {
            guard selectedSection != section else { return }
            IumrahHaptics.selection()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 43)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black)
                        .matchedGeometryEffect(id: "user-data-segment", in: segmentNamespace)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var introCopy: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("iumrah Security", systemImage: "lock.shield.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(selectedSection == .booking
                 ? tr(
                    "Your booking profile",
                    "Ваш профиль для бронирований",
                    "Bron profilingiz",
                    "Брон профилингиз"
                 )
                 : tr(
                    "Your iumrah account",
                    "Ваш аккаунт iumrah",
                    "iumrah akkauntingiz",
                    "iumrah аккаунтингиз"
                 ))
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .contentTransition(.opacity)

            Text(selectedSection == .booking
                 ? tr(
                    "These details are reused for flights, hotels and your Umrah trip. Fill them in once and keep them ready for future bookings.",
                    "Эти данные используются для авиабилетов, отелей и поездки Umrah. Заполните их один раз — iumrah сможет использовать их в следующих бронированиях.",
                    "Bu ma’lumotlar aviachiptalar, mehmonxonalar va Umra safari uchun qayta ishlatiladi. Ularni bir marta to‘ldiring.",
                    "Бу маълумотлар авиачипталар, меҳмонхоналар ва Умра сафари учун қайта ишлатилади. Уларни бир марта тўлдиринг."
                 )
                 : tr(
                    "This is the identity linked to your iumrah account: your name, iumrah ID, phone, email and contact channels.",
                    "Здесь хранится именно то, что привязано к Вашему аккаунту iumrah: имя, iumrah ID, номер телефона, почта и каналы связи.",
                    "Bu yerda iumrah akkauntingizga bog‘langan ma’lumotlar saqlanadi: ism, iumrah ID, telefon, email va aloqa kanallari.",
                    "Бу ерда iumrah аккаунтингизга боғланган маълумотлар сақланади: исм, iumrah ID, телефон, email ва алоқа каналлари."
                 ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
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
                Text(selectedSection == .booking
                     ? tr(
                        "Enter passport-facing details exactly as they appear in the document. They are used when iumrah prepares travel services.",
                        "Данные для бронирования указывайте точно как в паспорте. Они используются при оформлении услуг поездки.",
                        "Bron ma’lumotlarini pasportdagidek aniq kiriting. Ular safar xizmatlarini rasmiylashtirishda ishlatiladi.",
                        "Брон маълумотларини паспортдагидек аниқ киритинг. Улар сафар хизматларини расмийлаштиришда ишлатилади."
                     )
                     : tr(
                        "The phone and email here belong to the account owner. Keep them current so access and important trip communication stay with you.",
                        "Номер телефона и почта здесь относятся к владельцу аккаунта. Поддерживайте их актуальными для входа и важных сообщений о поездке.",
                        "Bu telefon va email akkaunt egasiga tegishli. Kirish va muhim safar xabarlari uchun ularni yangilab boring.",
                        "Бу телефон ва email аккаунт эгасига тегишли. Кириш ва муҳим сафар хабарлари учун уларни янгилаб боринг."
                     ))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
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

    private var bookingContent: some View {
        VStack(spacing: 16) {
            passportProfileCard
            personalDetailsCard
            bookingReuseCard
        }
    }

    private var accountContent: some View {
        VStack(spacing: 16) {
            accountIdentityCard
            accountNameCard
            linkedContactsCard
            communicationChannelsCard
            accountSecurityCard
        }
    }

    private var passportProfileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                icon: "person.text.rectangle.fill",
                title: tr("Passport name", "Имя по паспорту", "Pasportdagi ism", "Паспортдаги исм"),
                subtitle: tr("Used on travel documents", "Используется в документах поездки", "Safar hujjatlarida ishlatiladi", "Сафар ҳужжатларида ишлатилади")
            )

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
                subtitle: tr("Saved for future bookings", "Сохраняются для будущих бронирований", "Keyingi bronlar uchun saqlanadi", "Кейинги бронлар учун сақланади")
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

    private var bookingReuseCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 42, height: 42)
                .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("One profile for future trips", "Один профиль для следующих поездок", "Keyingi safarlar uchun bitta profil", "Кейинги сафарлар учун битта профил"))
                    .font(.headline)
                Text(tr(
                    "Your emergency contact is stored once in Who is traveling with you, so you do not repeat it for yourself and every companion.",
                    "Экстренный контакт сохраняется один раз в разделе «Кто едет с Вами», поэтому его не нужно повторно заполнять для себя и каждого участника.",
                    "Favqulodda kontakt «Siz bilan kim bormoqda» bo‘limida bir marta saqlanadi, shuning uchun uni o‘zingiz va har bir hamroh uchun qayta kiritmaysiz.",
                    "Фавқулодда контакт «Сиз билан ким бормоқда» бўлимида бир марта сақланади, шунинг учун уни ўзингиз ва ҳар бир ҳамроҳ учун қайта киритмайсиз."
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

    private var accountIdentityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "person.badge.key.fill",
                title: tr("Account identity", "Идентификация аккаунта", "Akkaunt identifikatsiyasi", "Аккаунт идентификацияси"),
                subtitle: tr("Permanent iumrah identity", "Постоянная идентификация iumrah", "Doimiy iumrah identifikatori", "Доимий iumrah идентификатори")
            )

            readOnlyRow(
                icon: "number",
                title: "iumrah ID",
                value: account.account?.iumrahID ?? "—"
            )
        }
        .iumrahCard()
    }

    private var accountNameCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "person.crop.circle.fill",
                title: tr("Account name", "Имя владельца аккаунта", "Akkaunt egasi nomi", "Аккаунт эгаси номи"),
                subtitle: tr("Shown across iumrah", "Используется внутри iumrah", "iumrah ichida ishlatiladi", "iumrah ичида ишлатилади")
            )

            secureField(
                title: tr("First name", "Имя", "Ism", "Исм"),
                placeholder: tr("First name", "Имя", "Ism", "Исм"),
                text: $firstName,
                field: .firstName,
                contentType: .givenName
            )
            secureField(
                title: tr("Last name", "Фамилия", "Familiya", "Фамилия"),
                placeholder: tr("Last name", "Фамилия", "Familiya", "Фамилия"),
                text: $lastName,
                field: .lastName,
                contentType: .familyName
            )
        }
        .iumrahCard()
    }

    private var linkedContactsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "checkmark.shield.fill",
                title: tr("Linked account contacts", "Привязанные данные", "Bog‘langan akkaunt ma’lumotlari", "Боғланган аккаунт маълумотлари"),
                subtitle: tr("Protected by one-time verification", "Защищены одноразовым подтверждением", "Bir martalik tasdiqlash bilan himoyalangan", "Бир марталик тасдиқлаш билан ҳимояланган")
            )

            Text(tr(
                "Your phone and email are locked to the account. To replace either one, iumrah verifies the new contact with a one-time code first.",
                "Номер телефона и почта закреплены за аккаунтом. Чтобы заменить один из них, iumrah сначала подтверждает новый контакт одноразовым кодом.",
                "Telefon va email akkauntga biriktirilgan. Ularni almashtirishdan oldin iumrah yangi kontaktni bir martalik kod bilan tasdiqlaydi.",
                "Телефон ва email аккаунтга бириктирилган. Уларни алмаштиришдан олдин iumrah янги контактни бир марталик код билан тасдиқлайди."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                linkedContactRow(
                    kind: .phone,
                    icon: "phone.fill",
                    title: tr("Linked phone", "Привязанный номер", "Bog‘langan telefon", "Боғланган телефон"),
                    value: phone
                )

                Divider().padding(.leading, 58)

                linkedContactRow(
                    kind: .email,
                    icon: "envelope.fill",
                    title: tr("Linked email", "Привязанная почта", "Bog‘langan email", "Боғланган email"),
                    value: email
                )
            }
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .iumrahCard()
    }

    private func linkedContactRow(
        kind: IumrahLinkedContactKind,
        icon: String,
        title: String,
        value: String
    ) -> some View {
        Button {
            IumrahHaptics.selection()
            contactChangeKind = kind
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.primary.opacity(0.055))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? tr("Not linked", "Не привязано", "Biriktirilmagan", "Бириктирилмаган")
                         : value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Label(
                        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? tr("Verification required", "Нужно подтвердить", "Tasdiqlash kerak", "Тасдиқлаш керак")
                            : tr("Verified", "Подтверждено", "Tasdiqlangan", "Тасдиқланган"),
                        systemImage: value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "exclamationmark.circle.fill"
                            : "checkmark.seal.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.orange : Color.green)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? tr("Add", "Добавить", "Qo‘shish", "Қўшиш")
                         : tr("Change", "Изменить", "O‘zgartirish", "Ўзгартириш"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var communicationChannelsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                icon: "bubble.left.and.bubble.right.fill",
                title: tr("Communication", "Связь", "Aloqa", "Алоқа"),
                subtitle: tr("Optional channels for trip support", "Дополнительные каналы связи по поездке", "Safar yordami uchun qo‘shimcha aloqa", "Сафар ёрдами учун қўшимча алоқа")
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
        }
        .iumrahCard()
    }

    private var accountSecurityCard: some View {
        NavigationLink {
            IumrahAccountSecurityView()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 44, height: 44)
                    .background(Color.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Account security", "Безопасность аккаунта", "Akkaunt xavfsizligi", "Аккаунт хавфсизлиги"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(tr(
                        "Password, devices and linked sign-in methods",
                        "Пароль, устройства и способы входа",
                        "Parol, qurilmalar va kirish usullari",
                        "Парол, қурилмалар ва кириш усуллари"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(17)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 10) {
                if isSaving { ProgressView().tint(.white) }
                Image(systemName: "checkmark.circle.fill")
                Text(selectedSection == .booking
                     ? tr("Save booking details", "Сохранить данные бронирования", "Bron ma’lumotlarini saqlash", "Брон маълумотларини сақлаш")
                     : tr("Save account details", "Сохранить данные аккаунта", "Akkaunt ma’lumotlarini saqlash", "Аккаунт маълумотларини сақлаш"))
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

    private func readOnlyRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.semibold))
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Image(systemName: "lock.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 58)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        whatsapp = Self.formatPhoneInput(nonEmpty(profile?.whatsapp, settings.whatsapp))
        dateOfBirth = Self.displayDate(settings.dateOfBirth)
        gender = settings.gender
        nationality = settings.nationality
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        saveMessage = nil
        defer { isSaving = false }

        let cleanFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Phone and email are security-bound account identifiers. They are never
        // changed by the ordinary profile save action; only the verified OTP
        // flows below may replace them.
        let linkedPhone = account.account?.phone.trimmingCharacters(in: .whitespacesAndNewlines) ?? Self.normalizedPhone(phone)
        let linkedEmail = account.account?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTelegram = telegram.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWhatsapp = Self.normalizedPhone(whatsapp)

        settings.firstName = cleanFirstName
        settings.lastName = cleanLastName
        settings.phone = linkedPhone
        settings.email = linkedEmail
        settings.telegram = cleanTelegram
        settings.whatsapp = cleanWhatsapp
        settings.dateOfBirth = Self.isoDate(dateOfBirth) ?? ""
        settings.gender = gender
        settings.nationality = nationality.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if account.isAuthenticated {
                _ = try await account.updateProfile(
                    firstName: cleanFirstName,
                    lastName: cleanLastName,
                    phone: linkedPhone,
                    email: linkedEmail,
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

private struct IumrahLinkedContactChangeView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    let kind: IumrahLinkedContactKind
    let currentValue: String
    let onCompleted: (String) -> Void

    @State private var newValue = ""
    @State private var challengeID = ""
    @State private var requestedValue = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    securityHeader
                    currentContactCard
                    changeCard

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    primaryButton
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Cancel", "Отмена", "Bekor qilish", "Бекор қилиш")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if newValue.isEmpty {
                newValue = kind == .phone ? formatPhone(currentValue) : currentValue
            }
        }
        .onChange(of: newValue) { _, _ in
            errorMessage = nil
        }
        .onChange(of: code) { _, _ in
            errorMessage = nil
        }
    }

    private var securityHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 74, height: 74)
                Image(systemName: kind == .phone ? "phone.badge.checkmark.fill" : "envelope.badge.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.16), radius: 16, y: 7)

            VStack(spacing: 5) {
                Text(challengeID.isEmpty ? title : codeTitle)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(challengeID.isEmpty ? introText : codeBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var currentContactCard: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
                Image(systemName: kind == .phone ? "phone.fill" : "envelope.fill")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(tr("Currently linked", "Сейчас привязано", "Hozir biriktirilgan", "Ҳозир бириктирилган"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(displayCurrentValue)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            Label(
                currentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? tr("Not linked", "Не привязано", "Biriktirilmagan", "Бириктирилмаган")
                    : tr("Verified", "Подтверждено", "Tasdiqlangan", "Тасдиқланган"),
                systemImage: currentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "exclamationmark.circle.fill"
                    : "checkmark.seal.fill"
            )
            .font(.caption2.weight(.bold))
            .foregroundStyle(currentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.orange : Color.green)
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var changeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(challengeID.isEmpty ? newContactTitle : tr("Confirmation code", "Код подтверждения", "Tasdiqlash kodi", "Тасдиқлаш коди"))
                .font(.headline)

            if challengeID.isEmpty {
                HStack(spacing: 11) {
                    Image(systemName: kind == .phone ? "phone.fill" : "envelope.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)

                    TextField(inputPlaceholder, text: $newValue)
                        .keyboardType(kind == .phone ? .phonePad : .emailAddress)
                        .textContentType(kind == .phone ? .telephoneNumber : .emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($fieldFocused)
                        .onChange(of: newValue) { _, raw in
                            guard kind == .phone else { return }
                            let formatted = formatPhone(raw)
                            if formatted != raw { newValue = formatted }
                        }
                }
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(kind == .phone
                     ? tr(
                        "The new Uzbekistan number will receive a 6-digit SMS code. The linked number changes only after the code is confirmed.",
                        "На новый номер Узбекистана придёт 6-значный SMS-код. Привязанный номер изменится только после подтверждения кода.",
                        "Yangi O‘zbekiston raqamiga 6 xonali SMS-kod keladi. Biriktirilgan raqam faqat kod tasdiqlangandan keyin o‘zgaradi.",
                        "Янги Ўзбекистон рақамига 6 хонали SMS-код келади. Бириктирилган рақам фақат код тасдиқлангандан кейин ўзгаради."
                     )
                     : tr(
                        "A 6-digit code will be sent to the new email. The linked email changes only after the code is confirmed.",
                        "На новую почту придёт 6-значный код. Привязанная почта изменится только после подтверждения кода.",
                        "Yangi emailga 6 xonali kod yuboriladi. Biriktirilgan email faqat kod tasdiqlangandan keyin o‘zgaradi.",
                        "Янги emailга 6 хонали код юборилади. Бириктирилган email фақат код тасдиқлангандан кейин ўзгаради."
                     ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 11) {
                    Image(systemName: "number.square.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    TextField("123456", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($fieldFocused)
                        .onChange(of: code) { _, raw in
                            let digits = String(raw.filter(\.isNumber).prefix(6))
                            if digits != raw { code = digits }
                        }
                }
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button {
                    challengeID = ""
                    code = ""
                    errorMessage = nil
                    fieldFocused = true
                } label: {
                    Text(tr("Use another contact", "Указать другой контакт", "Boshqa kontaktni kiritish", "Бошқа контактни киритиш"))
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
            }
        }
        .iumrahCard()
    }

    private var primaryButton: some View {
        Button {
            Task {
                if challengeID.isEmpty {
                    await requestCode()
                } else {
                    await confirmCode()
                }
            }
        } label: {
            HStack(spacing: 10) {
                if isWorking { ProgressView().tint(.white) }
                Image(systemName: challengeID.isEmpty ? "lock.shield.fill" : "checkmark.shield.fill")
                Text(challengeID.isEmpty
                     ? tr("Send verification code", "Отправить код подтверждения", "Tasdiqlash kodini yuborish", "Тасдиқлаш кодини юбориш")
                     : tr("Confirm change", "Подтвердить изменение", "O‘zgarishni tasdiqlash", "Ўзгаришни тасдиқлаш"))
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(!canContinue || isWorking)
    }

    @MainActor
    private func requestCode() async {
        guard canContinue else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            switch kind {
            case .phone:
                let normalized = normalizedPhone(newValue)
                let response = try await account.startPhoneVerification(phone: normalized, locale: localeIdentifier)
                challengeID = response.challengeID
                requestedValue = response.phone
            case .email:
                let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let response = try await account.startEmailVerification(email: normalized, locale: localeIdentifier)
                challengeID = response.challengeID
                requestedValue = normalized
            }
            code = ""
            IumrahHaptics.success()
            try? await Task.sleep(for: .milliseconds(120))
            fieldFocused = true
        } catch {
            errorMessage = message(for: error)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func confirmCode() async {
        guard code.count == 6 else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let finalValue: String
            switch kind {
            case .phone:
                let response = try await account.confirmPhoneVerification(challengeID: challengeID, code: code)
                finalValue = response.phone
            case .email:
                let response = try await account.confirmEmailVerification(challengeID: challengeID, code: code)
                finalValue = response.email
            }
            onCompleted(finalValue)
            IumrahHaptics.success()
            dismiss()
        } catch {
            errorMessage = message(for: error)
            IumrahHaptics.error()
        }
    }

    private var canContinue: Bool {
        if !challengeID.isEmpty { return code.count == 6 }
        switch kind {
        case .phone:
            let value = normalizedPhone(newValue)
            return value.hasPrefix("+998") && value.filter(\.isNumber).count == 12 && value != normalizedPhone(currentValue)
        case .email:
            let value = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return value.contains("@") && value.contains(".") && value != currentValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    private var title: String {
        kind == .phone
            ? tr("Linked phone", "Привязанный номер", "Bog‘langan telefon", "Боғланган телефон")
            : tr("Linked email", "Привязанная почта", "Bog‘langan email", "Боғланган email")
    }

    private var codeTitle: String {
        tr("Confirm the new contact", "Подтвердите новый контакт", "Yangi kontaktni tasdiqlang", "Янги контактни тасдиқланг")
    }

    private var introText: String {
        kind == .phone
            ? tr("Your linked phone cannot be edited directly.", "Привязанный номер нельзя изменить без подтверждения.", "Biriktirilgan telefonni tasdiqlashsiz o‘zgartirib bo‘lmaydi.", "Бириктирилган телефонни тасдиқлашсиз ўзгартириб бўлмайди.")
            : tr("Your linked email cannot be edited directly.", "Привязанную почту нельзя изменить без подтверждения.", "Biriktirilgan emailni tasdiqlashsiz o‘zgartirib bo‘lmaydi.", "Бириктирилган emailни тасдиқлашсиз ўзгартириб бўлмайди.")
    }

    private var codeBody: String {
        let destination = requestedValue.isEmpty ? newValue : requestedValue
        return tr(
            "Enter the 6-digit code sent to \(destination).",
            "Введите 6-значный код, отправленный на \(destination).",
            "\(destination) manziliga yuborilgan 6 xonali kodni kiriting.",
            "\(destination) манзилига юборилган 6 хонали кодни киритинг."
        )
    }

    private var newContactTitle: String {
        kind == .phone
            ? tr("New phone number", "Новый номер телефона", "Yangi telefon raqami", "Янги телефон рақами")
            : tr("New email", "Новая почта", "Yangi email", "Янги email")
    }

    private var inputPlaceholder: String {
        kind == .phone ? "+998 90 123 45 67" : "name@example.com"
    }

    private var displayCurrentValue: String {
        let value = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? tr("Not linked", "Не привязано", "Biriktirilmagan", "Бириктирилмаган") : value
    }

    private var localeIdentifier: String {
        switch settings.language {
        case .russian: return "ru-RU"
        case .english: return "en-US"
        case .uzbek: return "uz-Latn-UZ"
        case .uzbekCyrillic: return "uz-Cyrl-UZ"
        }
    }

    private func normalizedPhone(_ value: String) -> String {
        let digits = String(value.filter(\.isNumber).prefix(12))
        return digits.isEmpty ? "" : "+" + digits
    }

    private func formatPhone(_ value: String) -> String {
        normalizedPhone(value)
    }

    private func message(for error: Error) -> String {
        let raw: String
        if case APIError.server(_, let message) = error {
            raw = message
        } else if case APIError.status(let status) = error, status == 403 {
            raw = "PRIMARY_DEVICE_REQUIRED"
        } else {
            raw = error.localizedDescription
        }

        switch raw {
        case "PRIMARY_DEVICE_REQUIRED":
            return tr(
                "For account security, linked contacts can be changed only from your primary device.",
                "Для безопасности аккаунта привязанные контакты можно менять только с основного устройства.",
                "Akkaunt xavfsizligi uchun biriktirilgan kontaktlarni faqat asosiy qurilmadan o‘zgartirish mumkin.",
                "Аккаунт хавфсизлиги учун бириктирилган контактларни фақат асосий қурилмадан ўзгартириш мумкин."
            )
        case "PHONE_ALREADY_CONNECTED":
            return tr("This number is already linked to another iumrah account.", "Этот номер уже привязан к другому аккаунту iumrah.", "Bu raqam boshqa iumrah akkauntiga biriktirilgan.", "Бу рақам бошқа iumrah аккаунтига бириктирилган.")
        case "EMAIL_ALREADY_CONNECTED":
            return tr("This email is already linked to another iumrah account.", "Эта почта уже привязана к другому аккаунту iumrah.", "Bu email boshqa iumrah akkauntiga biriktirilgan.", "Бу email бошқа iumrah аккаунтига бириктирилган.")
        case "PHONE_INVALID", "SMS_COUNTRY_UNSUPPORTED":
            return tr("Enter a valid Uzbekistan phone number.", "Введите корректный номер Узбекистана.", "To‘g‘ri O‘zbekiston telefon raqamini kiriting.", "Тўғри Ўзбекистон телефон рақамини киритинг.")
        case "EMAIL_INVALID":
            return tr("Enter a valid email address.", "Введите корректный адрес электронной почты.", "To‘g‘ri email manzilini kiriting.", "Тўғри email манзилини киритинг.")
        case "VERIFICATION_CODE_INVALID":
            return tr("The code is incorrect or has expired.", "Код неверный или срок его действия истёк.", "Kod noto‘g‘ri yoki muddati tugagan.", "Код нотўғри ёки муддати тугаган.")
        case "SMS_RATE_LIMITED", "EMAIL_RATE_LIMITED":
            return tr("Too many attempts. Try again later.", "Слишком много попыток. Попробуйте позже.", "Urinishlar juda ko‘p. Keyinroq qayta urinib ko‘ring.", "Уринишлар жуда кўп. Кейинроқ қайта уриниб кўринг.")
        case "SMS_DELIVERY_NOT_CONFIGURED", "SMS_DELIVERY_UNAVAILABLE", "DEVSMS_OTP_SEND_FAILED":
            return tr("SMS could not be sent right now. Try again later.", "Сейчас не удалось отправить SMS. Попробуйте позже.", "Hozir SMS yuborib bo‘lmadi. Keyinroq urinib ko‘ring.", "Ҳозир SMS юбориб бўлмади. Кейинроқ уриниб кўринг.")
        case "EMAIL_DELIVERY_NOT_CONFIGURED", "EMAIL_DELIVERY_UNAVAILABLE":
            return tr("The verification email could not be sent right now.", "Сейчас не удалось отправить письмо с кодом.", "Hozir tasdiqlash xatini yuborib bo‘lmadi.", "Ҳозир тасдиқлаш хатини юбориб бўлмади.")
        default:
            return tr("Could not complete verification. Please try again.", "Не удалось выполнить подтверждение. Попробуйте ещё раз.", "Tasdiqlashni yakunlab bo‘lmadi. Qayta urinib ko‘ring.", "Тасдиқлашни якунлаб бўлмади. Қайта уриниб кўринг.")
        }
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
