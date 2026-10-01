import SwiftUI

enum IumrahTelegramConnectCardStyle {
    case standard
    case dark
    case compact
}

struct IumrahTelegramConnectCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    let session: StoredBookingSession
    var accountToken: String? = nil
    var style: IumrahTelegramConnectCardStyle = .standard

    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var openedTelegram = false
    @State private var isLinked = false
    @State private var isCheckingLink = false

    private let service = TelegramBookingIntegrationService()

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact ? 12 : 15) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(telegramBlue.opacity(style == .dark ? 0.22 : 0.12))
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: style == .compact ? 17 : 20, weight: .semibold))
                        .foregroundStyle(style == .dark ? Color.white : telegramBlue)
                        .offset(x: -1, y: 1)
                }
                .frame(width: style == .compact ? 42 : 48, height: style == .compact ? 42 : 48)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: style == .compact ? 16 : 18, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText)
                    Text(bodyText)
                        .font(.system(size: style == .compact ? 13 : 14, weight: .regular, design: .rounded))
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if openedTelegram {
                Label(openedHint, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style == .dark ? Color.white.opacity(0.78) : Color.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(style == .dark ? Color.orange : Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                guard !isLinked else { return }
                Task { await connect() }
            } label: {
                HStack(spacing: 9) {
                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(isLinked ? connectedTitle : (isConnecting ? connectingTitle : connectTitle))
                    Spacer(minLength: 8)
                    if isLinked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                    } else if !isConnecting {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: style == .compact ? 48 : 52)
                .background(isLinked ? linkedGreen : telegramBlue, in: RoundedRectangle(cornerRadius: style == .compact ? 16 : 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isConnecting || isLinked)
        }
        .padding(style == .compact ? 15 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: style == .compact ? 22 : 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: style == .compact ? 22 : 26, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 0.8)
        }
        .task(id: session.id) { await refreshLinkedState() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, openedTelegram else { return }
            Task { await refreshLinkedState() }
        }
    }

    @MainActor
    private func connect() async {
        guard !isConnecting else { return }
        errorMessage = nil
        openedTelegram = false

        let headers = authorizationHeaders
        guard !headers.isEmpty else {
            errorMessage = authorizationMissingText
            IumrahHaptics.error()
            return
        }

        isConnecting = true
        defer { isConnecting = false }
        do {
            let url = try await service.createLink(
                bookingID: session.id,
                authorizationHeaders: headers,
                language: settings.language
            )
            openedTelegram = true
            IumrahHaptics.success()
            openURL(url)
        } catch {
            errorMessage = connectErrorText
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func refreshLinkedState() async {
        guard !isCheckingLink else { return }
        let headers = authorizationHeaders
        guard !headers.isEmpty else { return }
        isCheckingLink = true
        defer { isCheckingLink = false }
        if let linked = try? await service.isLinked(bookingID: session.id, authorizationHeaders: headers) {
            isLinked = linked
            if linked { openedTelegram = false }
        }
    }

    private var authorizationHeaders: [String: String] {
        let trimmedBookingToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccountToken = accountToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var headers: [String: String] = [:]
        if !trimmedBookingToken.isEmpty { headers["x-booking-token"] = trimmedBookingToken }
        if !trimmedAccountToken.isEmpty { headers["Authorization"] = "Bearer \(trimmedAccountToken)" }
        return headers
    }

    private var telegramBlue: Color { Color(red: 0.15, green: 0.64, blue: 0.91) }
    private var linkedGreen: Color { Color(red: 0.18, green: 0.68, blue: 0.36) }
    private var primaryText: Color { style == .dark ? .white : .primary }
    private var secondaryText: Color { style == .dark ? Color.white.opacity(0.62) : .secondary }
    private var cardBackground: Color { style == .dark ? Color.white.opacity(0.065) : Color.iumrahCardBackground }
    private var cardBorder: Color { style == .dark ? Color.white.opacity(0.10) : Color.primary.opacity(0.06) }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var title: String {
        tr("Booking status in Telegram", "Статус бронирования в Telegram", "Bron holati Telegram’da", "Брон ҳолати Telegram’да")
    }

    private var bodyText: String {
        tr(
            "Connect this booking once. The iumrah bot will send status, payment, confirmation and document updates automatically.",
            "Подключите эту бронь один раз. Бот iumrah будет автоматически присылать изменения статуса, оплаты, подтверждения и документов.",
            "Bu bronni bir marta ulang. iumrah boti status, to‘lov, tasdiq va hujjatlardagi o‘zgarishlarni avtomatik yuboradi.",
            "Бу бронни бир марта уланг. iumrah боти статус, тўлов, тасдиқ ва ҳужжатлардаги ўзгаришларни автоматик юборади."
        )
    }

    private var connectTitle: String {
        tr("Connect Telegram", "Подключить Telegram", "Telegram’ni ulash", "Telegram’ни улаш")
    }

    private var connectedTitle: String {
        tr("Telegram connected", "Telegram подключен", "Telegram ulangan", "Telegram уланган")
    }

    private var connectingTitle: String {
        tr("Creating secure link…", "Создаём безопасную ссылку…", "Xavfsiz havola yaratilmoqda…", "Хавфсиз ҳавола яратилмоқда…")
    }

    private var openedHint: String {
        tr(
            "Telegram opened. Tap Start in the bot to finish linking this booking.",
            "Telegram открыт. Нажмите «Запустить» в боте, чтобы завершить привязку этой брони.",
            "Telegram ochildi. Bronni ulashni yakunlash uchun botda Start tugmasini bosing.",
            "Telegram очилди. Бронни улашни якунлаш учун ботда Start тугмасини босинг."
        )
    }

    private var authorizationMissingText: String {
        tr(
            "This restored booking has no local booking key. Sign in to your iumrah account and try again.",
            "У восстановленной брони нет локального ключа. Войдите в аккаунт iumrah и попробуйте снова.",
            "Tiklangan bronda lokal kalit yo‘q. iumrah akkauntiga kiring va qayta urinib ko‘ring.",
            "Тикланган бронда локал калит йўқ. iumrah аккаунтига киринг ва қайта уриниб кўринг."
        )
    }

    private var connectErrorText: String {
        tr(
            "Could not create the Telegram link. Try again in a moment.",
            "Не удалось создать ссылку Telegram. Попробуйте ещё раз через несколько секунд.",
            "Telegram havolasini yaratib bo‘lmadi. Bir necha soniyadan keyin qayta urinib ko‘ring.",
            "Telegram ҳаволасини яратиб бўлмади. Бир неча сониядан кейин қайта уриниб кўринг."
        )
    }
}

struct IumrahTelegramEntryCard: View {
    let language: AppSettingsStore.Language
    var large: Bool = false

    var body: some View {
        Group {
            if large {
                VStack(alignment: .leading, spacing: 0) {
                    Image("TelegramIntegrationHero")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 172)
                        .clipped()

                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .tracking(-0.45)
                            .foregroundStyle(.black)
                        Text(bodyText)
                            .font(.subheadline)
                            .foregroundStyle(Color.black.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                            Text(cta)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .padding(18)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.black.opacity(0.055), lineWidth: 0.8) }
            } else {
                HStack(spacing: 14) {
                    Image("TelegramIntegrationHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 84, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(shortBody)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7) }
            }
        }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var title: String { tr("iumrah in Telegram", "iumrah в Telegram", "iumrah Telegram’da", "iumrah Telegram’да") }
    private var bodyText: String {
        tr(
            "Receive booking status changes in Telegram — even when the iumrah app is closed.",
            "Получайте изменения статуса бронирования в Telegram — даже когда приложение iumrah закрыто.",
            "Bron holatidagi o‘zgarishlarni Telegram’da oling — iumrah ilovasi yopiq bo‘lsa ham.",
            "Брон ҳолатидаги ўзгаришларни Telegram’да олинг — iumrah иловаси ёпиқ бўлса ҳам."
        )
    }
    private var shortBody: String { tr("Status and booking notifications", "Статус и уведомления по брони", "Bron statusi va bildirishnomalar", "Брон статуси ва билдиришномалар") }
    private var cta: String { tr("Set up Telegram", "Настроить Telegram", "Telegram’ni sozlash", "Telegram’ни созлаш") }
}

struct IumrahTelegramIntegrationView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore

    let preferredBookingID: String?
    @State private var selectedBookingID: String?

    init(preferredBookingID: String? = nil) {
        self.preferredBookingID = preferredBookingID
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Image("TelegramIntegrationHero")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.8) }

                VStack(alignment: .leading, spacing: 9) {
                    Text(pageTitle)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .tracking(-0.7)
                    Text(pageBody)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    benefit(icon: "clock.arrow.circlepath", title: benefitStatusTitle, body: benefitStatusBody)
                    benefit(icon: "creditcard.fill", title: benefitPaymentTitle, body: benefitPaymentBody)
                    benefit(icon: "doc.text.fill", title: benefitDocsTitle, body: benefitDocsBody)
                }

                if bookings.sessions.isEmpty {
                    noBookingCard
                } else {
                    if bookings.sessions.count > 1 {
                        bookingPicker
                    }
                    if let session = selectedSession {
                        IumrahTelegramConnectCard(
                            session: session,
                            accountToken: account.bearerToken,
                            style: .standard
                        )
                    }
                }

                Text(securityNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("Telegram")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { chooseInitialBooking() }
        .onChange(of: bookings.sessions.map(\.id)) { _, _ in chooseInitialBooking() }
    }

    private var selectedSession: StoredBookingSession? {
        guard let selectedBookingID else { return bookings.sessions.first }
        return bookings.sessions.first(where: { $0.id == selectedBookingID }) ?? bookings.sessions.first
    }

    private var bookingPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(bookingLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Picker(bookingLabel, selection: Binding(
                get: { selectedSession?.id ?? bookings.sessions.first?.id ?? "" },
                set: { selectedBookingID = $0 }
            )) {
                ForEach(bookings.sessions) { session in
                    Text("\(session.displayBookingNumber) · \(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                        .tag(session.id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var noBookingCard: some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: "suitcase.fill", role: .booking, size: 44, symbolSize: 17, cornerRadius: 15)
            VStack(alignment: .leading, spacing: 5) {
                Text(noBookingTitle)
                    .font(.headline)
                Text(noBookingBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func benefit(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, role: .connectivity, size: 42, symbolSize: 16, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private func chooseInitialBooking() {
        if let preferredBookingID, bookings.sessions.contains(where: { $0.id == preferredBookingID }) {
            selectedBookingID = preferredBookingID
        } else if selectedBookingID == nil || !bookings.sessions.contains(where: { $0.id == selectedBookingID }) {
            selectedBookingID = bookings.sessions.first(where: { !["COMPLETED", "CANCELLED"].contains($0.effectiveStatus.uppercased()) })?.id
                ?? bookings.sessions.first?.id
        }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var pageTitle: String { tr("Your booking, now in Telegram", "Ваша бронь теперь и в Telegram", "Broningiz endi Telegram’da ham", "Бронингиз энди Telegram’да ҳам") }
    private var pageBody: String {
        tr(
            "Link a booking once and the iumrah bot will keep its live status close at hand. The bot uses the same booking state as the app.",
            "Привяжите бронь один раз — бот iumrah будет держать актуальный статус под рукой. Бот использует то же состояние бронирования, что и приложение.",
            "Bronni bir marta ulang — iumrah boti uning joriy holatini doim qo‘l ostida saqlaydi. Bot ilovadagi ayni bron holatidan foydalanadi.",
            "Бронни бир марта уланг — iumrah боти унинг жорий ҳолатини доим қўл остида сақлайди. Бот иловадаги айни брон ҳолатидан фойдаланади."
        )
    }
    private var benefitStatusTitle: String { tr("Live booking status", "Живой статус бронирования", "Jonli bron holati", "Жонли брон ҳолати") }
    private var benefitStatusBody: String { tr("Availability, confirmation, travel-ready and trip stages.", "Проверка наличия, подтверждение, готовность к поездке и этапы путешествия.", "Mavjudlik, tasdiq, safarga tayyorlik va safar bosqichlari.", "Мавжудлик, тасдиқ, сафарга тайёрлик ва сафар босқичлари.") }
    private var benefitPaymentTitle: String { tr("Payment updates", "Изменения по оплате", "To‘lov yangilanishlari", "Тўлов янгиланишлари") }
    private var benefitPaymentBody: String { tr("See when payment is expected, received or confirmed.", "Узнавайте, когда ожидается, получена или подтверждена оплата.", "To‘lov qachon kutilayotgani, qabul qilingani yoki tasdiqlanganini ko‘ring.", "Тўлов қачон кутилаётгани, қабул қилингани ёки тасдиқланганини кўринг.") }
    private var benefitDocsTitle: String { tr("Documents and readiness", "Документы и готовность", "Hujjatlar va tayyorgarlik", "Ҳужжатлар ва тайёргарлик") }
    private var benefitDocsBody: String { tr("Get notified when confirmations and travel documents are ready.", "Получайте уведомление, когда подтверждения и документы к поездке готовы.", "Tasdiqlar va safar hujjatlari tayyor bo‘lganda xabar oling.", "Тасдиқлар ва сафар ҳужжатлари тайёр бўлганда хабар олинг.") }
    private var bookingLabel: String { tr("Booking to connect", "Бронь для подключения", "Ulanadigan bron", "Уланадиган брон") }
    private var noBookingTitle: String { tr("Create a booking first", "Сначала создайте бронирование", "Avval bron yarating", "Аввал брон яратинг") }
    private var noBookingBody: String { tr("Telegram linking becomes available as soon as Hotel First, Flight First or Configurator creates a booking.", "Подключение Telegram появится сразу после создания брони через Hotel First, Flight First или Configurator.", "Telegram ulanishi Hotel First, Flight First yoki Configurator bron yaratishi bilan paydo bo‘ladi.", "Telegram уланиши Hotel First, Flight First ёки Configurator брон яратиши билан пайдо бўлади.") }
    private var securityNote: String { tr("The connection link is one-time and expires after 10 minutes. The bot receives access only to the booking you link.", "Ссылка подключения одноразовая и действует 10 минут. Бот получает доступ только к той брони, которую Вы привязываете.", "Ulash havolasi bir martalik va 10 daqiqa amal qiladi. Bot faqat siz ulagan bronga kirish oladi.", "Улаш ҳаволаси бир марталик ва 10 дақиқа амал қилади. Бот фақат сиз улаган бронга кириш олади.") }
}
