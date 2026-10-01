import SwiftUI

struct AccountNotificationsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared

    private enum SignalPage: String, CaseIterable, Identifiable {
        case signal
        case reminders
        case telegram
        var id: String { rawValue }
    }

    @State private var selectedPage: SignalPage = .signal

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private var unreadNotifications: [ClientSystemNotification] {
        clientNotifications.inboxNotifications.filter { !$0.isRead }
    }

    private var readNotifications: [ClientSystemNotification] {
        clientNotifications.inboxNotifications.filter(\.isRead)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                pageSwitcher

                switch selectedPage {
                case .signal:
                    signalPage
                case .reminders:
                    remindersPage
                case .telegram:
                    telegramPage
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(signalTitle)
        .navigationBarTitleDisplayMode(.inline)
        .iumrahInternalNavigation()
        .refreshable {
            await clientNotifications.refresh(accountToken: account.bearerToken)
        }
        .task {
            await clientNotifications.refresh(accountToken: account.bearerToken)
        }
    }

    private var pageSwitcher: some View {
        IumrahGlassGroup(spacing: 5) {
            HStack(spacing: 5) {
                pageSegment(
                    title: tr("Signal", "Сигнал", "Signal", "Сигнал"),
                    symbol: "bell.badge.fill",
                    page: .signal
                )
                pageSegment(
                    title: tr("Reminders", "Напоминания", "Eslatmalar", "Эслатмалар"),
                    symbol: "calendar.badge.clock",
                    page: .reminders
                )
                pageSegment(
                    title: "Telegram",
                    symbol: "paperplane.fill",
                    page: .telegram
                )
            }
        }
        .padding(5)
        .iumrahGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            interactive: false,
            allowsStaticGlass: true,
            chrome: true
        )
    }

    private func pageSegment(title: String, symbol: String, page: SignalPage) -> some View {
        let selected = selectedPage == page
        return Button {
            guard !selected else { return }
            IumrahHaptics.selection()
            withAnimation(.snappy(duration: 0.28)) { selectedPage = page }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 45)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: 17, style: .continuous),
                interactive: true,
                tint: selected ? Color.white.opacity(0.26) : nil,
                allowsStaticGlass: true,
                chrome: true
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var signalPage: some View {
        VStack(spacing: 22) {
            hero

            if clientNotifications.inboxNotifications.isEmpty {
                emptyState
            } else {
                if !unreadNotifications.isEmpty {
                    notificationSection(
                        title: tr("New", "Новые", "Yangi", "Янги"),
                        subtitle: tr("Needs your attention", "То, что стоит посмотреть", "E’tibor berish kerak", "Эътибор бериш керак"),
                        notifications: unreadNotifications,
                        unreadSection: true
                    )
                }

                if !readNotifications.isEmpty {
                    notificationSection(
                        title: tr("Earlier", "Ранее", "Avvalgi", "Аввалги"),
                        subtitle: tr("Already opened", "Уже просмотрено", "Ko‘rib chiqilgan", "Кўриб чиқилган"),
                        notifications: readNotifications,
                        unreadSection: false
                    )
                }
            }
        }
    }

    private var remindersPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            pageHeading(
                title: tr("Next-trip reminders", "Напоминания о следующей поездке", "Keyingi safar eslatmalari", "Кейинги сафар эслатмалари"),
                body: tr(
                    "Plan your Umrah and choose exactly when iumrah should remind you as the journey gets closer.",
                    "Запланируйте Umrah и выберите, когда именно iumrah должен напоминать Вам по мере приближения поездки.",
                    "Umrani rejalashtiring va safar yaqinlashgani sari iumrah qachon eslatishini o‘zingiz belgilang.",
                    "Умрани режалаштиринг ва сафар яқинлашгани сари iumrah қачон эслатишини ўзингиз белгиланг."
                )
            )
            UmrahPlanReminderCenterView()
        }
    }

    @ViewBuilder
    private var telegramPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            pageHeading(title: telegramSignalTitle, body: telegramSignalBody)

            if let session = telegramSession {
                IumrahTelegramConnectCard(
                    session: session,
                    accountToken: account.bearerToken,
                    style: .standard
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "paperplane.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Color(red: 0.15, green: 0.64, blue: 0.91))
                    Text(tr("No booking to connect yet", "Пока нет бронирования для подключения", "Ulash uchun bron hali yo‘q", "Улаш учун брон ҳали йўқ"))
                        .font(.headline)
                    Text(tr(
                        "Create a booking first. Telegram linking will appear here automatically.",
                        "Сначала создайте бронирование. Подключение Telegram появится здесь автоматически.",
                        "Avval bron yarating. Telegram ulanishi bu yerda avtomatik paydo bo‘ladi.",
                        "Аввал брон яратинг. Telegram уланиши бу ерда автоматик пайдо бўлади."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .iumrahCard()
            }
        }
    }

    private func pageHeading(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.45)
                .fixedSize(horizontal: false, vertical: true)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var telegramSession: StoredBookingSession? {
        bookings.sessions.first { !["COMPLETED", "CANCELLED"].contains($0.effectiveStatus.uppercased()) }
            ?? bookings.sessions.first
    }

    private var signalTitle: String {
        tr("Iumrah Status Signal", "Iumrah Status Signal", "Iumrah Status Signal", "Iumrah Status Signal")
    }

    private var telegramSignalTitle: String {
        tr(
            "Booking status in Telegram",
            "Получайте статус бронирования в Telegram",
            "Bron holatini Telegram’da oling",
            "Брон ҳолатини Telegram’да олинг"
        )
    }

    private var telegramSignalBody: String {
        tr(
            "Connect once and receive booking status, payment, confirmation and document updates directly in Telegram.",
            "Подключите один раз и получайте изменения статуса, оплаты, подтверждения и документов прямо в Telegram.",
            "Bir marta ulang va status, to‘lov, tasdiq hamda hujjat yangilanishlarini to‘g‘ridan-to‘g‘ri Telegram’da oling.",
            "Бир марта уланг ва статус, тўлов, тасдиқ ҳамда ҳужжат янгиланишларини тўғридан-тўғри Telegram’да олинг."
        )
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(signalTitle)
                        .font(.caption.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.72))

                    Text(tr(
                        "Everything important about your journey",
                        "Всё важное по вашей поездке",
                        "Safaringiz bo‘yicha barcha muhim xabarlar",
                        "Сафарингиз бўйича барча муҳим хабарлар"
                    ))
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.55)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(tr(
                        "Booking changes, trip updates and reminders stay here even after a push notification disappears.",
                        "Изменения бронирования, новости поездки и напоминания остаются здесь, даже когда push уже исчез.",
                        "Bron o‘zgarishlari, safar yangiliklari va eslatmalar push yo‘qolgandan keyin ham shu yerda qoladi.",
                        "Брон ўзгаришлари, сафар янгиликлари ва эслатмалар push йўқолгандан кейин ҳам шу ерда қолади."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .iumrahGlass(
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous),
                        tint: .white.opacity(0.08),
                        allowsStaticGlass: true,
                        chrome: true
                    )
            }

            HStack(spacing: 10) {
                heroCountChip(
                    value: "\(clientNotifications.unreadCount)",
                    title: tr("new", "новых", "yangi", "янги"),
                    emphasized: clientNotifications.unreadCount > 0
                )
                heroCountChip(
                    value: "\(clientNotifications.inboxNotifications.count)",
                    title: tr("total", "всего", "jami", "жами"),
                    emphasized: false
                )
            }
        }
        .padding(22)
        .background(signalGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
        }
        .shadow(color: signalBlue.opacity(0.18), radius: 22, y: 11)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            IumrahIconBadge(systemName: "bell.slash.fill", role: .notification, size: 48, symbolSize: 19, cornerRadius: 16)
            Text(tr("No notifications yet", "Пока нет уведомлений", "Hali bildirishnomalar yo‘q", "Ҳали билдиришномалар йўқ"))
                .font(.headline)
            Text(tr(
                "When iumrah sends a Signal, it will appear here and on the Home screen.",
                "Когда iumrah отправит Signal, он появится здесь и на главной странице.",
                "iumrah Signal yuborganda, u shu yerda va Asosiy sahifada ko‘rinadi.",
                "iumrah Signal юборганда, у шу ерда ва Асосий саҳифада кўринади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func notificationSection(
        title: String,
        subtitle: String,
        notifications: [ClientSystemNotification],
        unreadSection: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .tracking(-0.35)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(notifications.count)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(unreadSection ? signalBlue : .secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background((unreadSection ? signalBlue.opacity(0.10) : Color.secondary.opacity(0.10)), in: Capsule())
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(notifications) { notification in
                    notificationRow(notification)
                }
            }
        }
    }

    private func notificationRow(_ notification: ClientSystemNotification) -> some View {
        let hiddenOnHome = clientNotifications.isDismissedFromHome(notification)
        let unread = !notification.isRead

        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(unread ? signalBlue.opacity(0.12) : Color.iumrahRaisedBackground)
                    Image(systemName: destinationIcon(notification))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(unread ? signalBlue : .secondary)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(notification.title)
                            .font(.system(size: 17, weight: unread ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        if unread {
                            Circle()
                                .fill(signalBlue)
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                                .accessibilityHidden(true)
                        }
                    }

                    Text(formattedDate(notification.sentAt ?? notification.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(notification.body)
                .font(.subheadline)
                .foregroundStyle(unread ? Color.primary.opacity(0.78) : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Label(destinationTitle(notification), systemImage: "arrow.turn.down.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if hiddenOnHome {
                    Text(tr("Hidden on Home", "Скрыто на главной", "Asosiyda yashirilgan", "Асосийда яширилган"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                Button {
                    IumrahHaptics.selection()
                    if hiddenOnHome { clientNotifications.restoreToHome(notification) }
                    else { clientNotifications.dismissFromHome(notification) }
                } label: {
                    Image(systemName: hiddenOnHome ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .iumrahGlass(in: Circle(), interactive: true, chrome: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hiddenOnHome
                    ? tr("Show on Home", "Показать на главной", "Asosiyda ko‘rsatish", "Асосийда кўрсатиш")
                    : tr("Hide on Home", "Скрыть с главной", "Asosiydan yashirish", "Асосийдан яшириш"))
            }

            Button {
                open(notification)
            } label: {
                HStack(spacing: 8) {
                    Text(tr("Open", "Открыть", "Ochish", "Очиш"))
                    Spacer(minLength: 6)
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(unread ? Color.white : Color.primary)
                .padding(.horizontal, 15)
                .frame(height: 46)
                .background(
                    unread ? signalBlue : Color.iumrahRaisedBackground,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            unread ? signalBlue.opacity(0.065) : Color.iumrahCardBackground,
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(alignment: .leading) {
            if unread {
                Capsule()
                    .fill(signalBlue)
                    .frame(width: 4)
                    .padding(.vertical, 22)
                    .padding(.leading, 1)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(unread ? signalBlue.opacity(0.18) : Color.primary.opacity(0.055), lineWidth: 1)
        }
        .shadow(color: unread ? signalBlue.opacity(0.08) : Color.black.opacity(0.03), radius: 16, y: 8)
    }

    private func heroCountChip(value: String, title: String, emphasized: Bool) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(emphasized ? 1 : 0.78))
        .padding(.horizontal, 13)
        .frame(height: 36)
        .background(Color.white.opacity(emphasized ? 0.16 : 0.09), in: Capsule())
    }

    private var signalBlue: Color {
        Color(red: 0.18, green: 0.40, blue: 0.90)
    }

    private var signalGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.21, blue: 0.56),
                Color(red: 0.17, green: 0.39, blue: 0.88),
                Color(red: 0.37, green: 0.31, blue: 0.80)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func open(_ notification: ClientSystemNotification) {
        IumrahHaptics.selection()
        Task { await clientNotifications.markOpened(notification, accountToken: account.bearerToken) }
        switch notification.destination {
        case "hotels": chrome.navigate(to: .hotels)
        case "bookings": chrome.navigate(to: .booking)
        case "care": chrome.navigate(to: .care)
        case "account": chrome.navigate(to: .account)
        case "booking":
            if let bookingID = notification.destinationBookingID,
               bookings.booking(id: bookingID) != nil {
                chrome.openBooking(id: bookingID)
            } else {
                chrome.navigate(to: .booking)
            }
        default:
            chrome.navigate(to: .home)
        }
    }

    private func destinationIcon(_ notification: ClientSystemNotification) -> String {
        switch notification.destination {
        case "hotels": return "building.2.fill"
        case "bookings", "booking": return "suitcase.fill"
        case "care": return "heart.fill"
        case "account": return "person.crop.circle.fill"
        default: return "house.fill"
        }
    }

    private func destinationTitle(_ notification: ClientSystemNotification) -> String {
        switch notification.destination {
        case "hotels": return tr("Hotels", "Отели", "Mehmonxonalar", "Меҳмонхоналар")
        case "bookings": return tr("Trips", "Поездки", "Safarlar", "Сафарлар")
        case "booking": return tr("Trip details", "Детали поездки", "Safar tafsilotlari", "Сафар тафсилотлари")
        case "care": return "iumrah Care"
        case "account": return "Account"
        default: return tr("Home", "Главная", "Asosiy", "Асосий")
        }
    }

    private func formattedDate(_ value: String) -> String {
        guard let date = Self.isoFractionalFormatter.date(from: value) ?? Self.isoFormatter.date(from: value) else {
            return value
        }

        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        if calendar.isDateInToday(date) {
            return "\(tr("Today", "Сегодня", "Bugun", "Бугун")), \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "\(tr("Yesterday", "Вчера", "Kecha", "Кеча")), \(timeFormatter.string(from: date))"
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d MMM · HH:mm"
        return formatter.string(from: date)
    }

    private var locale: Locale {
        switch settings.language {
        case .english: return Locale(identifier: "en_US")
        case .russian: return Locale(identifier: "ru_RU")
        case .uzbek: return Locale(identifier: "uz_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
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
