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
        GeometryReader { viewport in
            let horizontalInset = IumrahDesign.pagePadding
            let contentWidth = max(0, viewport.size.width - (horizontalInset * 2))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    pageHeader
                    introCard

                    if isLoading && checkouts.isEmpty {
                        loadingCard
                    } else if companions.isEmpty {
                        emptyCard
                    } else {
                        ForEach(companions) { item in
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
                .frame(width: contentWidth, alignment: .topLeading)
                .padding(.horizontal, horizontalInset)
                .padding(.top, 12)
                .padding(.bottom, 46)
            }
            .frame(width: viewport.size.width)
            .clipped()
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await loadTravelers() }
        .task { await loadTravelers() }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(tr("Who is traveling with you", "Кто едет с Вами", "Siz bilan kim bormoqda", "Сиз билан ким бормоқда"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)

            Text(tr(
                "Family, loved ones and other pilgrims are stored separately from your own account profile.",
                "Семья, близкие и другие паломники хранятся отдельно от Вашего собственного профиля.",
                "Oila, yaqinlar va boshqa ziyoratchilar Sizning akkaunt profilingizdan alohida saqlanadi.",
                "Оила, яқинлар ва бошқа зиёратчилар Сизнинг аккаунт профилингиздан алоҳида сақланади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                IumrahIconBadge(systemName: "person.2.fill", role: .profile, size: 52, symbolSize: 21, cornerRadius: 17)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Your family and loved ones", "Ваша семья и близкие", "Oilangiz va yaqinlaringiz", "Оилангиз ва яқинларингиз"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(tr(
                        "Every companion has a separate card and a separate page with only the details needed for tickets and hotels.",
                        "У каждого участника — отдельная карточка и отдельная страница только с данными для авиабилета и отеля.",
                        "Har bir hamroh uchun chipta va mehmonxonaga kerakli ma’lumotlar bilan alohida karta va sahifa mavjud.",
                        "Ҳар бир ҳамроҳ учун чипта ва меҳмонхонага керакли маълумотлар билан алоҳида карта ва саҳифа мавжуд."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18, height: 20, alignment: .top)

                Text(tr(
                    "Passport details can be prepared in advance. The emergency contact is shared from Account and is not repeated here.",
                    "Паспортные данные можно заполнить заранее. Экстренный контакт берётся из Account и здесь повторно не заполняется.",
                    "Pasport ma’lumotlarini oldindan to‘ldirish mumkin. Favqulodda kontakt Account’dan olinadi va bu yerda qayta kiritilmaydi.",
                    "Паспорт маълумотларини олдиндан тўлдириш мумкин. Фавқулодда контакт Account’дан олинади ва бу ерда қайта киритилмайди."
                ))
                .font(.footnote.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            }
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
            Text(tr("No companions yet", "Попутчики пока не добавлены", "Hozircha hamrohlar yo‘q", "Ҳозирча ҳамроҳлар йўқ"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(tr(
                "When a booking includes family or friends, each of them will appear here as a separate traveler profile.",
                "Когда в бронировании появятся родственники или друзья, каждый из них появится здесь отдельной карточкой.",
                "Broningizga oila yoki do‘stlar qo‘shilganda, ularning har biri bu yerda alohida profil sifatida ko‘rinadi.",
                "Бронингизга оила ёки дўстлар қўшилганда, уларнинг ҳар бири бу ерда алоҳида профил сифатида кўринади."
            ))
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

        return NavigationLink {
            IumrahTravelerProfileView(
                bookingID: item.bookingID,
                traveler: traveler,
                onSaved: {
                    Task { await loadTravelers() }
                }
            )
        } label: {
            VStack(alignment: .leading, spacing: 0) {
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
                            Text(relationshipTitle(traveler.relationship))
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
                            value: traveler.firstName.isEmpty || traveler.lastName.isEmpty
                                ? tr("Fill in", "Нужно заполнить", "To‘ldirish kerak", "Тўлдириш керак")
                                : tr("Ready", "Заполнены", "Tayyor", "Тайёр")
                        )
                        factRow(
                            icon: "passport.fill",
                            title: tr("Passport", "Загранпаспорт", "Pasport", "Паспорт"),
                            value: traveler.hasPassport
                                ? maskedPassport(traveler.passportNumber)
                                : tr("Add a photo", "Добавьте фото", "Rasm qo‘shing", "Расм қўшинг")
                        )
                    }
                }
                .padding(20)

                HStack(spacing: 9) {
                    Text(complete
                         ? tr("Open traveler profile", "Открыть профиль участника", "Sayohatchi profilini ochish", "Саёҳатчи профилини очиш")
                         : tr("Fill in traveler details", "Заполнить данные участника", "Sayohatchi ma’lumotlarini to‘ldirish", "Саёҳатчи маълумотларини тўлдириш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 54)
                .background(Color.black)
            }
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func factRow(icon: String, title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24)
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer(minLength: 10)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24)
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline)
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var companions: [TravelerItem] {
        bookings.sessions.flatMap { session in
            let checkout = checkouts[session.id]
            return (checkout?.travelers ?? []).compactMap { traveler in
                let relationship = traveler.relationship?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let isOwner = relationship == "self" || (relationship.isEmpty && traveler.position == 1)
                guard !isOwner else { return nil }
                return TravelerItem(
                    bookingID: session.id,
                    tripTitle: companionTripTitle(session),
                    traveler: traveler
                )
            }
        }
        .sorted {
            if $0.bookingID == $1.bookingID { return $0.traveler.position < $1.traveler.position }
            return $0.tripTitle < $1.tripTitle
        }
    }

    private func companionTripTitle(_ session: StoredBookingSession) -> String {
        let hotelName = session.booking.hotelNames.makkah.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hotelName.isEmpty { return hotelName }

        let origin = session.booking.route.originCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = session.booking.route.outboundDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        if !origin.isEmpty && !destination.isEmpty { return "\(origin) → \(destination)" }
        if !origin.isEmpty { return origin }
        if !destination.isEmpty { return destination }
        return tr("Umrah trip", "Поездка Umrah", "Umra safari", "Умра сафари")
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
                    bookingToken: session.accessToken,
                    accountToken: account.bearerToken
                )
            } catch {
                continue
            }
        }
        checkouts = loaded
        if loaded.isEmpty && !bookings.sessions.isEmpty {
            errorMessage = tr(
                "Travelers could not be loaded. Pull down to try again.",
                "Не удалось загрузить участников. Потяните экран вниз, чтобы повторить.",
                "Sayohatchilarni yuklab bo‘lmadi. Qayta urinish uchun pastga torting.",
                "Саёҳатчиларни юклаб бўлмади. Қайта уриниш учун пастга тортинг."
            )
        }
    }

    private func travelerName(_ traveler: IumrahTravelerForm) -> String {
        let value = [traveler.firstName, traveler.middleName, traveler.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return value.isEmpty
            ? tr("Traveler \(traveler.position)", "Участник \(traveler.position)", "Sayohatchi \(traveler.position)", "Саёҳатчи \(traveler.position)")
            : value
    }

    private func relationshipTitle(_ value: String?) -> String {
        switch value?.lowercased() {
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

    private func relationshipIcon(_ value: String?) -> String {
        switch value?.lowercased() {
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
        guard cleaned.count > 4 else {
            return cleaned.isEmpty ? tr("Added", "Добавлен", "Qo‘shilgan", "Қўшилган") : cleaned
        }
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
