import SwiftUI

struct CareHomeView: View {
    private let directCarePhone = "+998508898845"
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var careProfile: IumrahPublicProfile?
    @State private var isLoadingCareProfile = false
    @AppStorage("iumrah.care.cachedPhoneSA") private var cachedPhoneSA = ""
    @AppStorage("iumrah.care.cachedPhoneUZ") private var cachedPhoneUZ = "+998 50 889 88 45"
    @AppStorage("iumrah.care.cachedTelegram") private var cachedTelegram = "@saudiclub966"

    private var activeSession: StoredBookingSession? {
        bookings.sessions.first { session in
            !["COMPLETED", "CANCELLED"].contains(session.effectiveStatus.uppercased())
        }
    }

    var body: some View {
        GeometryReader { viewport in
            let contentWidth = max(0, viewport.size.width - (IumrahDesign.pagePadding * 2))

            ScrollView(showsIndicators: false) {
                // Match Account's root-page architecture: one regular VStack,
                // one shared horizontal inset, and one stable content width.
                VStack(alignment: .leading, spacing: 0) {
                    IumrahRootPageTitle(title: "iumrah Care")
                        .padding(.bottom, 14)

                    intro
                        .padding(.bottom, 24)

                    careHero
                        .padding(.bottom, 28)

                    helpTopics
                        .padding(.bottom, 30)

                    quickAnswers
                        .padding(.bottom, 14)
                }
                .frame(width: contentWidth, alignment: .topLeading)
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 112)
            }
            .frame(width: viewport.size.width, alignment: .topLeading)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshCare()
        }
        .task {
            await refreshCare()
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(tr(
                "We’ll help you build and arrange your Umrah",
                "Поможем собрать и оформить вашу Умру",
                "Umra safaringizni yig‘ish va rasmiylashtirishga yordam beramiz",
                "Умра сафарингизни тузиш ва расмийлаштиришга ёрдам берамиз"
            ))
            .font(.system(size: 27, weight: .bold, design: .rounded))
            .tracking(-0.5)
            .fixedSize(horizontal: false, vertical: true)

            Text(tr(
                "If you do not want to handle every detail yourself, iumrah Care can help with the route, hotel and services, review the details and guide the booking through to a ready trip.",
                "Если не хочется разбираться во всём самостоятельно, iumrah Care поможет подобрать маршрут, отель и услуги, проверить детали и довести бронирование до готовой поездки.",
                "Agar barcha tafsilotlarni o‘zingiz hal qilishni istamasangiz, iumrah Care yo‘nalish, mehmonxona va xizmatlarni tanlashga, tafsilotlarni tekshirishga va bronni tayyor safargacha olib borishga yordam beradi.",
                "Агар барча тафсилотларни ўзингиз ҳал қилишни истамасангиз, iumrah Care йўналиш, меҳмонхона ва хизматларни танлашга, тафсилотларни текширишга ва бронни тайёр сафаргача олиб боришга ёрдам беради."
            ))
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Care hero

    private var careHero: some View {
        VStack(spacing: 0) {
            Image("IumrahCareTeamHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 236)
                .clipped()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("iumrah Care")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .tracking(-0.65)

                    Text(tr(
                        "Help before, during and after your journey",
                        "Помощь до, во время и после поездки",
                        "Safardan oldin, davomida va undan keyin yordam",
                        "Сафардан олдин, давомида ва ундан кейин ёрдам"
                    ))
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                careActions

                if let activeSession {
                    activeBookingContext(activeSession)
                } else {
                    lockedChatNote
                }
            }
            .padding(20)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.065), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.07), radius: 24, y: 12)
    }

    @ViewBuilder
    private var careActions: some View {
        HStack(alignment: .top, spacing: 9) {
            if let activeSession {
                NavigationLink {
                    BookingChatView(bookingID: activeSession.id)
                } label: {
                    careActionTile(
                        icon: "message.fill",
                        title: tr("Chat", "Чат", "Chat", "Чат"),
                        subtitle: tr("Available", "Доступен", "Mavjud", "Мавжуд"),
                        enabled: true
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            } else {
                careActionTile(
                    icon: "lock.fill",
                    title: tr("Chat", "Чат", "Chat", "Чат"),
                    subtitle: tr("After booking", "После брони", "Brondan keyin", "Брондан кейин"),
                    enabled: false
                )
                .frame(maxWidth: .infinity)
            }

            Button {
                openPhone()
            } label: {
                careActionTile(
                    icon: "phone.fill",
                    title: tr("Call", "Позвонить", "Qo‘ng‘iroq", "Қўнғироқ"),
                    subtitle: contactActionSubtitle,
                    enabled: !preferredPhone.isEmpty
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .disabled(preferredPhone.isEmpty)

            Button {
                openTelegram()
            } label: {
                careActionTile(
                    icon: "paperplane.fill",
                    title: "Telegram",
                    subtitle: contactActionSubtitle,
                    enabled: telegramURL != nil
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .disabled(telegramURL == nil)
        }
        .frame(maxWidth: .infinity)
    }

    private func careActionTile(
        icon: String,
        title: String,
        subtitle: String,
        enabled: Bool
    ) -> some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(neutralIconBackground)
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.56))
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(enabled ? Color.primary : Color.secondary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 96)
        .padding(.horizontal, 7)
        .padding(.vertical, 12)
        .background(neutralTileBackground, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .opacity(enabled ? 1 : 0.72)
    }

    private func activeBookingContext(_ session: StoredBookingSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(neutralIconBackground)
                    .frame(width: 38, height: 38)
                Circle()
                    .fill(Color.primary)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(tr(
                    "Care is linked to your active trip",
                    "Care привязан к вашей активной поездке",
                    "Care faol safaringizga bog‘langan",
                    "Care фаол сафарингизга боғланган"
                ))
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))

                HStack(spacing: 5) {
                    Text(L10n.format("booking_number_short", settings.language, session.displayBookingNumber))
                    Text("·")
                    Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                    Text("·")
                    Text(L10n.status(session.effectiveStatus, settings.language))
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(neutralTileBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var lockedChatNote: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(neutralIconBackground, in: Circle())

            Text(tr(
                "One-to-one Care chat opens automatically when you have an active booking. Until then, you can call us or write in Telegram.",
                "Личный чат с iumrah Care откроется автоматически, когда появится активное бронирование. До этого можно позвонить или написать в Telegram.",
                "iumrah Care bilan shaxsiy chat faol bron paydo bo‘lganda avtomatik ochiladi. Ungacha qo‘ng‘iroq qilishingiz yoki Telegram’da yozishingiz mumkin.",
                "iumrah Care билан шахсий чат фаол брон пайдо бўлганда автоматик очилади. Унгача қўнғироқ қилишингиз ёки Telegram’da ёзишингиз мумкин."
            ))
            .font(.system(size: 12.5, weight: .regular))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    // MARK: - Topics

    private var helpTopics: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionTitle(
                tr("How we can help", "Чем мы можем помочь", "Nimada yordam bera olamiz", "Нимада ёрдам бера оламиз"),
                subtitle: tr(
                    "One place for the practical parts of your journey.",
                    "Один контакт для практических вопросов по вашей поездке.",
                    "Safaringizdagi amaliy savollar uchun bitta aloqa nuqtasi.",
                    "Сафарингиздаги амалий саволлар учун битта алоқа нуқтаси."
                )
            )

            VStack(spacing: 0) {
                helpTopicRow(icon: "airplane", title: tr("Flights and route", "Перелёт и маршрут", "Parvoz va yo‘nalish", "Парвоз ва йўналиш"))
                divider
                helpTopicRow(icon: "building.2.fill", title: tr("Hotel and accommodation", "Отель и размещение", "Mehmonxona va joylashish", "Меҳмонхона ва жойлашиш"))
                divider
                helpTopicRow(icon: "car.fill", title: tr("Transfer and services", "Трансфер и услуги", "Transfer va xizmatlar", "Трансфер ва хизматлар"))
                divider
                helpTopicRow(icon: "arrow.triangle.2.circlepath", title: tr("Booking changes", "Изменения бронирования", "Bronni o‘zgartirish", "Бронни ўзгартириш"))
            }
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
        }
    }

    private func helpTopicRow(icon: String, title: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.primary)
                .frame(width: 36, height: 36)
                .background(neutralIconBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 65)
            .opacity(0.55)
    }

    // MARK: - Quick answers

    private var quickAnswers: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionTitle(
                tr("Quick answers", "Быстрые ответы", "Tezkor javoblar", "Тезкор жавоблар"),
                subtitle: tr(
                    "The essentials before you contact Care.",
                    "Самое важное до обращения в Care.",
                    "Care’ga murojaat qilishdan oldingi asosiy ma’lumotlar.",
                    "Care’га мурожаат қилишдан олдинги асосий маълумотлар."
                )
            )

            VStack(spacing: 0) {
                answerRow(
                    icon: "message.fill",
                    title: tr("When does personal chat open?", "Когда откроется личный чат?", "Shaxsiy chat qachon ochiladi?", "Шахсий чат қачон очилади?"),
                    body: tr(
                        "It opens automatically for an active booking, so the conversation stays linked to the correct trip.",
                        "Он открывается автоматически для активного бронирования, чтобы переписка всегда была привязана к конкретной поездке.",
                        "U faol bron uchun avtomatik ochiladi, shunda yozishmalar aynan shu safarga bog‘langan bo‘ladi.",
                        "У фаол брон учун автоматик очилади, шунда ёзишмалар айнан шу сафарга боғланган бўлади."
                    )
                )
                divider
                answerRow(
                    icon: "phone.fill",
                    title: tr("Can I ask before booking?", "Можно обратиться до бронирования?", "Brondan oldin murojaat qilsa bo‘ladimi?", "Брондан олдин мурожаат қилса бўладими?"),
                    body: tr(
                        "Yes. Call us or write in Telegram and we will help you understand the options before you create a booking.",
                        "Да. Позвоните или напишите в Telegram — поможем разобраться с вариантами ещё до создания бронирования.",
                        "Ha. Qo‘ng‘iroq qiling yoki Telegram’da yozing — bron yaratishdan oldin variantlarni tushunishga yordam beramiz.",
                        "Ҳа. Қўнғироқ қилинг ёки Telegram’da ёзинг — брон яратишдан олдин вариантларни тушунишга ёрдам берамиз."
                    )
                )
                divider
                answerRow(
                    icon: "checkmark.shield.fill",
                    title: tr("What can Care handle?", "С чем поможет Care?", "Care nimalarda yordam beradi?", "Care нималарда ёрдам беради?"),
                    body: tr(
                        "Route, hotel, transfer, services, booking questions and practical changes connected to your journey.",
                        "Маршрут, отель, трансфер, услуги, вопросы по бронированию и практические изменения, связанные с поездкой.",
                        "Yo‘nalish, mehmonxona, transfer, xizmatlar, bron savollari va safarga bog‘liq amaliy o‘zgarishlar.",
                        "Йўналиш, меҳмонхона, трансфер, хизматлар, брон саволлари ва сафарга боғлиқ амалий ўзгаришлар."
                    )
                )
            }
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
        }
    }

    private func answerRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.primary)
                .frame(width: 34, height: 34)
                .background(neutralIconBackground, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(body)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(-0.35)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }


    private var neutralIconBackground: Color {
        Color(uiColor: .systemGray6)
    }

    private var neutralTileBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    // MARK: - Contact actions

    private var preferredPhone: String {
        directCarePhone
    }

    private var telegramURL: URL? {
        let live = careProfile?.telegram.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let raw = live.isEmpty ? cachedTelegram.trimmingCharacters(in: .whitespacesAndNewlines) : live
        guard !raw.isEmpty else { return nil }

        if raw.lowercased().hasPrefix("http") {
            return URL(string: raw)
        }

        let username = raw
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !username.isEmpty else { return nil }
        return URL(string: "https://t.me/\(username)")
    }

    private var contactActionSubtitle: String {
        tr("Contact", "Связаться", "Bog‘lanish", "Боғланиш")
    }

    private func openPhone() {
        let digits = preferredPhone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel:\(digits)") else { return }
        openURL(url)
    }

    private func openTelegram() {
        guard let telegramURL else { return }
        openURL(telegramURL)
    }

    @MainActor
    private func refreshCare() async {
        await bookings.refreshAll()

        guard !isLoadingCareProfile else { return }
        isLoadingCareProfile = true
        defer { isLoadingCareProfile = false }

        if let profile = try? await ChatService().loadCareProfile() {
            careProfile = profile
            if !profile.phoneSA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cachedPhoneSA = profile.phoneSA
            }
            if !profile.phoneUZ.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cachedPhoneUZ = profile.phoneUZ
            }
            if !profile.telegram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cachedTelegram = profile.telegram
            }
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
