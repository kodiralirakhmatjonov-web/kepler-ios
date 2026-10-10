import SwiftUI

/// One account-level emergency contact reused across the owner's and companions'
/// booking flows. Keeping it separate prevents users from entering the same
/// emergency contact repeatedly on every traveler card.
struct IumrahEmergencyContactView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var name = ""
    @State private var phone = ""
    @State private var relation = ""
    @State private var saved = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                hero
                explanation
                formCard
                saveButton
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 14)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(tr("Emergency contact", "Экстренный контакт", "Favqulodda kontakt", "Фавқулодда контакт"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { load() }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.84)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.red.opacity(0.24))
                .frame(width: 170, height: 170)
                .blur(radius: 26)
                .offset(x: 210, y: -76)

            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "sos.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)

                Text(tr("One contact for every trip", "Один контакт для всех поездок", "Har bir safar uchun bitta kontakt", "Ҳар бир сафар учун битта контакт"))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(tr(
                    "iumrah will reuse this contact for you and your companions when emergency information is required.",
                    "iumrah будет использовать этот контакт для Вас и Ваших участников, когда для поездки требуется экстренная связь.",
                    "iumrah favqulodda aloqa kerak bo‘lganda bu kontaktni Siz va hamrohlaringiz uchun ishlatadi.",
                    "iumrah фавқулодда алоқа керак бўлганда бу контактни Сиз ва ҳамроҳларингиз учун ишлатади."
                ))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 22, y: 10)
    }

    private var explanation: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sos.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 42, height: 42)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("No duplicate forms", "Без повторного заполнения", "Takroriy to‘ldirish yo‘q", "Такрорий тўлдириш йўқ"))
                    .font(.headline)
                Text(tr(
                    "This contact is stored once in Account. Traveler pages no longer ask for a separate emergency contact.",
                    "Контакт сохраняется один раз в Account. В карточках путешественников его больше не нужно заполнять отдельно.",
                    "Kontakt Account’da bir marta saqlanadi. Sayohatchi kartalarida uni alohida kiritish shart emas.",
                    "Контакт Account’да бир марта сақланади. Саёҳатчи карталарида уни алоҳида киритиш шарт эмас."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "person.crop.circle.badge.exclamationmark", role: .profile, size: 46, symbolSize: 19, cornerRadius: 15)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Contact details", "Данные контакта", "Kontakt ma’lumotlari", "Контакт маълумотлари"))
                        .font(.headline)
                    Text(tr("A trusted person outside the trip", "Надёжный человек вне поездки", "Safardan tashqaridagi ishonchli inson", "Сафардан ташқаридаги ишончли инсон"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            field(
                title: tr("Name and surname", "Имя и фамилия", "Ism va familiya", "Исм ва фамилия"),
                placeholder: tr("Contact person", "Контактное лицо", "Kontakt shaxs", "Контакт шахс"),
                text: $name,
                keyboard: .default,
                contentType: .name,
                capitalization: .words
            )

            phoneField

            field(
                title: tr("Relationship", "Кем приходится", "Qarindoshlik", "Қариндошлик"),
                placeholder: tr("For example: mother", "Например: мама", "Masalan: ona", "Масалан: она"),
                text: $relation,
                keyboard: .default,
                contentType: .none,
                capitalization: .words
            )

            if saved {
                Label(tr("Saved", "Сохранено", "Saqlandi", "Сақланди"), systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .transition(.opacity)
            }
        }
        .iumrahCard()
    }

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(tr("Phone", "Номер телефона", "Telefon", "Телефон"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            TextField("+998 90 123 45 67", text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onChange(of: phone) { _, value in
                    let formatted = formatPhone(value)
                    if formatted != value { phone = formatted }
                    saved = false
                }
        }
    }

    private func field(
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
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onChange(of: text.wrappedValue) { _, _ in saved = false }
        }
    }

    private var saveButton: some View {
        Button {
            settings.emergencyName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.emergencyPhone = normalizedPhone(phone)
            settings.emergencyRelation = relation.trimmingCharacters(in: .whitespacesAndNewlines)
            withAnimation(.easeInOut(duration: 0.2)) { saved = true }
            IumrahHaptics.success()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                Text(tr("Save emergency contact", "Сохранить экстренный контакт", "Favqulodda kontaktni saqlash", "Фавқулодда контактни сақлаш"))
                Spacer()
            }
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || normalizedPhone(phone).isEmpty)
    }

    private func load() {
        name = settings.emergencyName
        phone = formatPhone(settings.emergencyPhone)
        relation = settings.emergencyRelation
    }

    private func normalizedPhone(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        return digits.isEmpty ? "" : "+" + digits
    }

    private func formatPhone(_ value: String) -> String {
        let digits = String(value.filter(\.isNumber).prefix(15))
        return digits.isEmpty ? "" : "+" + digits
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .malay, .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
