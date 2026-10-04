import SwiftUI

/// Account → Who is traveling with you.
/// The production flow is intentionally passport-first: a clear passport photo is
/// sufficient for operations, while manual details stay optional and only speed up processing.
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
            LazyVStack(alignment: .leading, spacing: 18) {
                pageHeader
                passportIntroCard

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
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 48)
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
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(-0.65)
                .fixedSize(horizontal: false, vertical: true)

            Text(tr(
                "Attach the passport information page for each traveler. A clear passport photo is enough for booking operations.",
                "Прикрепите страницу загранпаспорта с данными для каждого паломника. Чёткой фотографии паспорта достаточно для оформления бронирования.",
                "Har bir ziyoratchining ma’lumotlar sahifasi tushirilgan pasport rasmini biriktiring. Aniq pasport rasmi bronni rasmiylashtirish uchun yetarli.",
                "Ҳар бир зиёратчининг маълумотлар саҳифаси туширилган паспорт расмини бириктиринг. Аниқ паспорт расми бронни расмийлаштириш учун етарли."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var passportIntroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("TravelCompanionsCover")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 154)
                .clipped()

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 13) {
                    IumrahIconBadge(systemName: "passport.fill", role: .document, size: 52, symbolSize: 21, cornerRadius: 17)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Passport first", "Сначала паспорт", "Avval pasport", "Аввал паспорт"))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                        Text(tr(
                            "Use a photo of the passport page with the holder photo and all personal data visible.",
                            "Нужна передняя страница паспорта: фотография владельца и все данные должны полностью попадать в кадр.",
                            "Pasportning egasi rasmi va barcha ma’lumotlar ko‘rinadigan old sahifasini suratga oling.",
                            "Паспортнинг эгаси расми ва барча маълумотлар кўринадиган олд саҳифасини суратга олинг."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Label {
                    Text(tr(
                        "Make sure every passport field is sharp and readable. We use these details to issue airline tickets, hotel bookings and the rest of the trip documents.",
                        "Обратите внимание: все данные паспорта должны быть чёткими и видимыми. Они используются для оформления авиабилетов, бронирования отеля и остальных документов поездки.",
                        "E’tibor bering: pasportdagi barcha ma’lumotlar aniq va to‘liq ko‘rinsin. Ular aviachipta, mehmonxona va safar hujjatlarini rasmiylashtirish uchun ishlatiladi.",
                        "Эътибор беринг: паспортдаги барча маълумотлар аниқ ва тўлиқ кўринсин. Улар авиачипта, меҳмонхона ва сафар ҳужжатларини расмийлаштириш учун ишлатилади."
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
            }
            .padding(18)
        }
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var loadingCard: some View {
        HStack(spacing: 13) {
            ProgressView()
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("Loading travelers", "Загружаем участников", "Sayohatchilar yuklanmoqda", "Саёҳатчилар юкланмоқда"))
                    .font(.headline)
                Text(tr("This usually takes a few seconds.", "Обычно это занимает несколько секунд.", "Bu odatda bir necha soniya davom etadi.", "Бу одатда бир неча сония давом этади."))
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
                "When your booking includes another traveler, their passport card will appear here automatically.",
                "Когда в бронировании появится ещё один паломник, его карточка паспорта автоматически появится здесь.",
                "Bronga yana bir ziyoratchi qo‘shilganda, uning pasport kartasi shu yerda avtomatik paydo bo‘ladi.",
                "Бронга яна бир зиёратчи қўшилганда, унинг паспорт картаси шу ерда автоматик пайдо бўлади."
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
        let passportReady = traveler.hasPassport

        return NavigationLink {
            IumrahTravelerProfileView(
                bookingID: item.bookingID,
                traveler: traveler,
                onSaved: { Task { await loadTravelers() } }
            )
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 13) {
                    IumrahIconBadge(
                        systemName: passportReady ? "checkmark.circle.fill" : relationshipIcon(traveler.relationship),
                        role: passportReady ? .success : .profile,
                        size: 54,
                        symbolSize: 22,
                        cornerRadius: 18
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(relationshipTitle(traveler.relationship))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(travelerName(traveler))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(item.tripTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: passportReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(passportReady ? .green : .orange)
                }

                HStack(spacing: 11) {
                    Image(systemName: "passport.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Passport photo", "Фото паспорта", "Pasport rasmi", "Паспорт расми"))
                            .font(.subheadline.weight(.semibold))
                        Text(passportReady
                             ? tr("Attached · ready for processing", "Прикреплено · готово к обработке", "Biriktirilgan · qayta ishlashga tayyor", "Бириктирилган · қайта ишлашга тайёр")
                             : tr("Attach the information page", "Прикрепите страницу с данными", "Ma’lumotlar sahifasini biriktiring", "Маълумотлар саҳифасини бириктиринг"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 9) {
                    Text(passportReady
                         ? tr("Review passport", "Проверить паспорт", "Pasportni tekshirish", "Паспортни текшириш")
                         : tr("Attach passport", "Прикрепить паспорт", "Pasportni biriktirish", "Паспортни бириктириш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .padding(18)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var companions: [TravelerItem] {
        bookings.sessions.flatMap { session -> [TravelerItem] in
            let travelers: [IumrahTravelerForm] = checkouts[session.id]?.travelers ?? []
            return travelers.compactMap { traveler -> TravelerItem? in
                let relationship = traveler.relationship?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let isOwner = relationship == "self" || (relationship.isEmpty && traveler.position == 1)
                guard !isOwner else { return nil }
                return TravelerItem(bookingID: session.id, tripTitle: companionTripTitle(session), traveler: traveler)
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
            if let checkout = try? await service.checkout(
                bookingID: session.id,
                bookingToken: session.accessToken,
                accountToken: account.bearerToken
            ) {
                loaded[session.id] = checkout
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
        case "child": return "figure.child"
        default: return "person.crop.circle.fill"
        }
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
