import SwiftUI

struct IumrahTravelCompanionsView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var checkouts: [String: IumrahCheckoutResponse] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = IumrahAccountService()
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                introCard

                if isLoading && checkouts.isEmpty {
                    loadingCard
                } else if travelers.isEmpty {
                    emptyCard
                } else {
                    ForEach(travelers) { item in
                        travelerCard(item)
                    }
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 14)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(tr("Travelers", "Кто едет с Вами", "Sayohatchilar", "Саёҳатчилар"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await loadTravelers() }
        .task { await loadTravelers() }
    }
    private var introCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                IumrahIconBadge(systemName: "person.2.fill", role: .profile, size: 52, symbolSize: 21, cornerRadius: 17)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Your family and loved ones", "Ваша семья и близкие", "Oilangiz va yaqinlaringiz", "Оилангиз ва яқинларингиз"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(tr("Each traveler has a separate card with only the details needed for the flight and hotel.", "У каждого участника — отдельная карточка только с данными, необходимыми для авиабилета и отеля.", "Har bir sayohatchi uchun aviachipta va mehmonxonaga kerakli ma’lumotlar alohida kartada saqlanadi.", "Ҳар бир саёҳатчи учун авиачипта ва меҳмонхонага керакли маълумотлар алоҳида картада сақланади."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Label(
                tr("You can fill in passport details while availability is being checked.", "Паспортные данные можно заполнить заранее, пока мы проверяем наличие.", "Mavjudlik tekshirilayotganda pasport ma’lumotlarini oldindan to‘ldirishingiz mumkin.", "Мавжудлик текширилаётганда паспорт маълумотларини олдиндан тўлдиришингиз мумкин."),
                systemImage: "lightbulb.fill"
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .iumrahCard()
    }
    private var loadingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("Loading travelers", "Загружаем участников поездки", "Sayohatchilar yuklanmoqda", "Саёҳатчилар юкланмоқда"))
                    .font(.headline)
                Text(tr("This usually takes only a few seconds.", "Обычно это занимает несколько секунд.", "Bu odatda bir necha soniya davom etadi.", "Бу одатда бир неча сония давом этади."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }
    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            IumrahIconBadge(systemName: "person.crop.circle.badge.plus", role: .profile, size: 52, symbolSize: 22, cornerRadius: 17)
            Text(tr("No travelers yet", "Участники пока не добавлены", "Hozircha sayohatchilar yo‘q", "Ҳозирча саёҳатчилар йўқ"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(tr("Create or link a booking. Everyone included in it will appear here automatically.", "Создайте или привяжите бронирование — все указанные в нём участники появятся здесь автоматически.", "Bron yarating yoki ulang — undagi barcha sayohatchilar bu yerda avtomatik ko‘rinadi.", "Брон яратинг ёки уланг — ундаги барча саёҳатчилар бу ерда автоматик кўринади."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }
    private func travelerCard(_ item: TravelerItem) -> some View {
        let traveler = item.traveler
        let title = travelerName(traveler)
        let complete = traveler.completed && traveler.hasPassport
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 13) {
                    IumrahIconBadge(
                        systemName: relationshipIcon(traveler.relationship),
                        role: complete ? .success : .profile,
                        size: 52,
                        symbolSize: 21,
                        cornerRadius: 17
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(relationshipTitle(traveler.relationship, position: traveler.position))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(title)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(item.tripTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: complete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(complete ? .green : .orange)
                }
                VStack(spacing: 10) {
                    factRow(
                        icon: "person.text.rectangle.fill",
                        title: tr("Personal details", "Личные данные", "Shaxsiy ma’lumotlar", "Шахсий маълумотлар"),
                        value: traveler.firstName.isEmpty || traveler.lastName.isEmpty ? tr("Fill in", "Нужно заполнить", "To‘ldirish kerak", "Тўлдириш керак") : tr("Ready", "Заполнены", "Tayyor", "Тайёр")
                    )
                    factRow(
                        icon: "passport.fill",
                        title: tr("Passport", "Загранпаспорт", "Pasport", "Паспорт"),
                        value: traveler.hasPassport ? maskedPassport(traveler.passportNumber) : tr("Add a photo", "Добавьте фото", "Rasm qo‘shing", "Расм қўшинг")
                    )
                }
            }
            .padding(20)
            NavigationLink {
                PilgrimCheckoutView(bookingID: item.bookingID)
            } label: {
                HStack(spacing: 9) {
                    Text(complete ? tr("View traveler details", "Посмотреть данные", "Ma’lumotlarni ko‘rish", "Маълумотларни кўриш") : tr("Fill in traveler details", "Заполнить данные участника", "Sayohatchi ma’lumotlarini to‘ldirish", "Саёҳатчи маълумотларини тўлдириш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 54)
                .background(Color.black)
            }
            .buttonStyle(.plain)
        }
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
    }
    private func factRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 24)
                .foregroundStyle(.primary)
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 10)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
    private var travelers: [TravelerItem] {
        bookings.sessions.flatMap { session in
            let checkout = checkouts[session.id]
            return (checkout?.travelers ?? []).map {
                // BookingInput has no `hotelName`; the normalized booking model stores
                // the selected Makkah hotel in `hotelNames`.
                TravelerItem(bookingID: session.id, tripTitle: session.booking.hotelNames.makkah, traveler: $0)
            }
        }
        .sorted {
            if $0.bookingID == $1.bookingID { return $0.traveler.position < $1.traveler.position }
            return $0.tripTitle < $1.tripTitle
        }
    }
    @MainActor
    private func loadTravelers() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        var loaded: [String: IumrahCheckoutResponse] = [:]
        for session in bookings.sessions {
            do {
                loaded[session.id] = try await service.checkout(
                    bookingID: session.id,
                    authorizationHeaders: account.authorizationHeaders(bookingToken: session.accessToken)
                )
            } catch {
                continue
            }
        }
        checkouts = loaded
        if loaded.isEmpty && !bookings.sessions.isEmpty {
            errorMessage = tr("Travelers could not be loaded. Pull down to try again.", "Не удалось загрузить участников. Потяните экран вниз, чтобы повторить.", "Sayohatchilarni yuklab bo‘lmadi. Qayta urinish uchun pastga torting.", "Саёҳатчиларни юклаб бўлмади. Қайта уриниш учун пастга тортинг.")
        }
    }
    private func travelerName(_ traveler: IumrahTravelerForm) -> String {
        let value = [traveler.firstName, traveler.middleName, traveler.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return value.isEmpty ? tr("Traveler \(traveler.position)", "Участник \(traveler.position)", "Sayohatchi \(traveler.position)", "Саёҳатчи \(traveler.position)") : value
    }
    private func relationshipTitle(_ value: String?, position: Int) -> String {
        switch value?.lowercased() {
        case "self": return tr("You", "Вы", "Siz", "Сиз")
        case "spouse": return tr("Spouse", "Муж или жена", "Turmush o‘rtog‘i", "Турмуш ўртоғи")
        case "mother": return tr("Mother", "Мама", "Ona", "Она")
        case "father": return tr("Father", "Папа", "Ota", "Ота")
        case "brother": return tr("Brother", "Брат", "Aka yoki uka", "Ака ёки ука")
        case "sister": return tr("Sister", "Сестра", "Opa yoki singil", "Опа ёки сингил")
        case "child": return tr("Child", "Ребёнок", "Farzand", "Фарзанд")
        case "relative": return tr("Relative", "Родственник", "Qarindosh", "Қариндош")
        case "friend": return tr("Friend", "Друг или подруга", "Do‘st", "Дўст")
        default: return position == 1 ? tr("You", "Вы", "Siz", "Сиз") : tr("Traveler", "Участник поездки", "Sayohatchi", "Саёҳатчи")
        }
    }
    private func relationshipIcon(_ value: String?) -> String {
        switch value?.lowercased() {
        case "self": return "person.fill"
        case "spouse": return "heart.fill"
        case "mother", "father": return "person.2.fill"
        case "child": return "figure.child"
        case "brother", "sister", "relative": return "person.2.fill"
        case "friend": return "person.2.fill"
        default: return "person.crop.circle.fill"
        }
    }
    private func maskedPassport(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 4 else { return cleaned.isEmpty ? tr("Added", "Добавлен", "Qo‘shilgan", "Қўшилган") : cleaned }
        return "•••• \(cleaned.suffix(4))"
    }
    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private struct TravelerItem: Identifiable {
    let bookingID: String
    let tripTitle: String
    let traveler: IumrahTravelerForm

    var id: String { "\(bookingID)-\(traveler.position)" }
}
