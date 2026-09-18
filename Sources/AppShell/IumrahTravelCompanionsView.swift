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
            LazyVStack(alignment: .leading, spacing: 22) {
                pageIntro

                if isLoading && checkouts.isEmpty {
                    loadingRow
                } else if travelers.isEmpty {
                    emptyCard
                } else {
                    travelersSection
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(tr("Travel companions", "Кто едет с Вами", "Siz bilan kim bormoqda", "Сиз билан ким бормоқда"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await loadTravelers() }
        .task { await loadTravelers() }
    }

    private var pageIntro: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IumrahIconBadge(
                    systemName: "person.2.fill",
                    role: .profile,
                    size: 56,
                    symbolSize: 22,
                    cornerRadius: 18
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Your family and loved ones", "Ваша семья и близкие", "Oilangiz va yaqinlaringiz", "Оилангиз ва яқинларингиз"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(companionCountText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(tr(
                "Each person has one clear profile. The same saved details are used for the flight, hotel and booking documents.",
                "У каждого человека — один понятный профиль. Сохранённые данные используются для авиабилета, отеля и документов бронирования.",
                "Har bir inson uchun bitta tushunarli profil bor. Saqlangan ma’lumotlar aviachipta, mehmonxona va bron hujjatlarida ishlatiladi.",
                "Ҳар бир инсон учун битта тушунарли профил бор. Сақланган маълумотлар авиачипта, меҳмонхона ва брон ҳужжатларида ишлатилади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Label(
                tr(
                    "You can complete passport details before availability is confirmed.",
                    "Паспортные данные можно заполнить заранее, ещё до подтверждения наличия.",
                    "Pasport ma’lumotlarini mavjudlik tasdiqlanishidan oldin to‘ldirish mumkin.",
                    "Паспорт маълумотларини мавжудлик тасдиқланишидан олдин тўлдириш мумкин."
                ),
                systemImage: "checkmark.shield.fill"
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var travelersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Travelers", "Участники поездки", "Sayohatchilar", "Саёҳатчилар"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Spacer()
                Text("\(travelers.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(travelers) { item in
                travelerCard(item)
            }
        }
    }

    private var loadingRow: some View {
        HStack(spacing: 13) {
            ProgressView()
                .controlSize(.regular)
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("Loading travelers", "Загружаем участников", "Sayohatchilar yuklanmoqda", "Саёҳатчилар юкланмоқда"))
                    .font(.subheadline.weight(.semibold))
                Text(tr("This usually takes only a few seconds.", "Обычно это занимает несколько секунд.", "Bu odatda bir necha soniya davom etadi.", "Бу одатда бир неча сония давом этади."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(17)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            IumrahIconBadge(
                systemName: "person.crop.circle.badge.plus",
                role: .profile,
                size: 52,
                symbolSize: 21,
                cornerRadius: 17
            )
            Text(tr("No travelers yet", "Участники пока не добавлены", "Hozircha sayohatchilar yo‘q", "Ҳозирча саёҳатчилар йўқ"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(tr(
                "Create or link a booking. Everyone included in it will appear here automatically.",
                "Создайте или привяжите бронирование — все участники появятся здесь автоматически.",
                "Bron yarating yoki ulang — undagi barcha sayohatchilar bu yerda avtomatik ko‘rinadi.",
                "Брон яратинг ёки уланг — ундаги барча саёҳатчилар бу ерда автоматик кўринади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private func travelerCard(_ item: TravelerItem) -> some View {
        let traveler = item.traveler
        let complete = traveler.completed && traveler.hasPassport

        return NavigationLink {
            PilgrimCheckoutView(bookingID: item.bookingID)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 13) {
                    IumrahIconBadge(
                        systemName: relationshipIcon(traveler.relationship),
                        role: complete ? .success : .profile,
                        size: 50,
                        symbolSize: 20,
                        cornerRadius: 17
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(relationshipTitle(traveler.relationship, position: traveler.position))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(travelerName(traveler))
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 7) {
                        statusPill(complete: complete)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()
                    .overlay(Color.primary.opacity(0.05))

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.route)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(item.dates)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    if traveler.hasPassport {
                        Label(maskedPassport(traveler.passportNumber), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Label(tr("Passport needed", "Нужен паспорт", "Pasport kerak", "Паспорт керак"), systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.065), lineWidth: 0.7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statusPill(complete: Bool) -> some View {
        Text(complete
             ? tr("Ready", "Готово", "Tayyor", "Тайёр")
             : tr("Complete", "Заполнить", "To‘ldirish", "Тўлдириш"))
            .font(.caption2.weight(.bold))
            .foregroundStyle(complete ? Color.green : Color.orange)
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background((complete ? Color.green : Color.orange).opacity(0.10), in: Capsule())
    }

    private var companionCountText: String {
        let count = travelers.count
        switch settings.language {
        case .russian: return count == 0 ? "Все участники Ваших поездок" : "Участников: \(count)"
        case .english: return count == 0 ? "Everyone traveling with you" : "Travelers: \(count)"
        case .uzbek: return count == 0 ? "Siz bilan safar qiluvchilar" : "Sayohatchilar: \(count)"
        case .uzbekCyrillic: return count == 0 ? "Сиз билан сафар қилувчилар" : "Саёҳатчилар: \(count)"
        }
    }

    private var travelers: [TravelerItem] {
        bookings.sessions.flatMap { session in
            let checkout = checkouts[session.id]
            let route = "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)"
            let dates = "\(L10n.date(session.booking.input.startDate, settings.language)) – \(L10n.date(session.booking.input.endDate, settings.language))"
            return (checkout?.travelers ?? []).map {
                TravelerItem(
                    bookingID: session.id,
                    route: route,
                    dates: dates,
                    traveler: $0
                )
            }
        }
        .sorted {
            if $0.bookingID == $1.bookingID { return $0.traveler.position < $1.traveler.position }
            if $0.route == $1.route { return $0.traveler.position < $1.traveler.position }
            return $0.route < $1.route
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
        default: return position == 1
            ? tr("You", "Вы", "Siz", "Сиз")
            : tr("Traveler", "Участник поездки", "Sayohatchi", "Саёҳатчи")
        }
    }

    private func relationshipIcon(_ value: String?) -> String {
        switch value?.lowercased() {
        case "self": return "person.fill"
        case "spouse": return "heart.fill"
        case "child": return "figure.child"
        case "mother", "father", "brother", "sister", "relative", "friend": return "person.2.fill"
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
    let route: String
    let dates: String
    let traveler: IumrahTravelerForm

    var id: String { "\(bookingID)-\(traveler.position)" }
}
