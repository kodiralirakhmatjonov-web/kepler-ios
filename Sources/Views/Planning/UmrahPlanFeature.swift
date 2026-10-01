import SwiftUI
import UserNotifications
import UIKit

struct UmrahPlannedTrip: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var backgroundID: String
    var reminderDays: [Int]
    var reminderHour: Int
    var reminderMinute: Int
    var notificationsEnabled: Bool
    var languageRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Umrah",
        startDate: Date,
        endDate: Date,
        backgroundID: String = "gradient-sunset",
        reminderDays: [Int] = UmrahPlanReminderPreset.defaultDays,
        reminderHour: Int = 19,
        reminderMinute: Int = 0,
        notificationsEnabled: Bool = true,
        languageRaw: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.backgroundID = backgroundID
        self.reminderDays = reminderDays
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.notificationsEnabled = notificationsEnabled
        self.languageRaw = languageRaw
        self.createdAt = createdAt
    }
}

enum UmrahPlanReminderPreset {
    static let defaultDays = [60, 30, 20, 15, 10, 7, 5, 3, 2, 1]
}

final class UmrahPlanStore: ObservableObject {
    static let shared = UmrahPlanStore()

    @Published private(set) var trip: UmrahPlannedTrip?

    private let defaultsKey = "iumrah.planned-trip.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(UmrahPlannedTrip.self, from: data) {
            trip = decoded
        }
    }

    func save(_ trip: UmrahPlannedTrip) {
        self.trip = trip
        persist()
        IumrahWidgetSyncService.updatePlannedTrip(trip)
        Task {
            await UmrahPlanNotificationScheduler.reschedule(trip)
        }
    }

    func deleteTrip() {
        trip = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        IumrahWidgetSyncService.updatePlannedTrip(nil)
        Task {
            await UmrahPlanNotificationScheduler.cancelAll()
        }
    }

    private func persist() {
        guard let trip, let data = try? JSONEncoder().encode(trip) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

enum UmrahPlanNotificationScheduler {
    private static let identifierPrefix = "iumrah.planned-trip."

    static func reschedule(_ trip: UmrahPlannedTrip) async {
        await cancelAll()
        guard trip.notificationsEnabled else { return }
        guard await ensurePermission() else { return }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let uniqueDays = Array(Set(trip.reminderDays.filter { $0 > 0 })).sorted(by: >)

        for daysBefore in uniqueDays {
            guard let reminderDay = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: trip.startDate)) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: reminderDay)
            components.hour = trip.reminderHour
            components.minute = trip.reminderMinute
            components.second = 0
            components.timeZone = TimeZone.autoupdatingCurrent
            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = notificationTitle(daysBefore: daysBefore, languageRaw: trip.languageRaw)
            content.body = notificationBody(daysBefore: daysBefore, startDate: trip.startDate, languageRaw: trip.languageRaw)
            content.sound = .default
            content.userInfo = [
                "type": "system_notification",
                "destination": "home",
                "planned_trip_id": trip.id.uuidString
            ]

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(trip.id.uuidString).\(daysBefore)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    static func schedulePreview(for trip: UmrahPlannedTrip) async -> Bool {
        guard await ensurePermission() else { return false }
        let content = UNMutableNotificationContent()
        content.title = notificationTitle(daysBefore: 20, languageRaw: trip.languageRaw)
        content.body = notificationBody(daysBefore: 20, startDate: trip.startDate, languageRaw: trip.languageRaw)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)preview",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 4, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func ensurePermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func notificationTitle(daysBefore: Int, languageRaw: String) -> String {
        let language = AppSettingsStore.Language(rawValue: languageRaw) ?? .russian
        switch language {
        case .russian:
            return daysBefore == 1 ? "Umrah уже завтра" : "До Umrah осталось \(daysBefore) дней"
        case .english:
            return daysBefore == 1 ? "Your Umrah starts tomorrow" : "\(daysBefore) days until your Umrah"
        case .uzbek:
            return daysBefore == 1 ? "Umrangiz ertaga boshlanadi" : "Umragacha \(daysBefore) kun qoldi"
        case .uzbekCyrillic:
            return daysBefore == 1 ? "Умрангиз эртага бошланади" : "Умрагача \(daysBefore) кун қолди"
        }
    }

    static func notificationBody(daysBefore: Int, startDate: Date, languageRaw: String) -> String {
        let language = AppSettingsStore.Language(rawValue: languageRaw) ?? .russian
        switch language {
        case .russian:
            if daysBefore >= 60 { return "План уже создан. Начните спокойно готовить документы, даты и бюджет поездки." }
            if daysBefore >= 30 { return "До поездки месяц. Проверьте паспорт, перелёт и отель — всё важное будет в одном плане iumrah." }
            if daysBefore >= 15 { return "Поездка становится ближе. Проверьте документы, трансфер и список подготовки." }
            if daysBefore >= 7 { return "Umrah уже скоро. Проверьте финальные детали поездки и всё необходимое в дороге." }
            return "Финальная подготовка к Umrah. Откройте план и проверьте даты, документы и маршрут."
        case .english:
            if daysBefore >= 60 { return "Your plan is saved. Start preparing documents, dates and budget at your own pace." }
            if daysBefore >= 30 { return "One month to go. Check your passport, flight and hotel in your iumrah plan." }
            if daysBefore >= 15 { return "Your trip is getting close. Review documents, transfers and preparation." }
            if daysBefore >= 7 { return "Your Umrah is close. Review the final trip details and what you need to take." }
            return "Final Umrah preparation. Open your plan and check dates, documents and route."
        case .uzbek:
            if daysBefore >= 60 { return "Rejangiz saqlandi. Hujjatlar, sanalar va safar byudjetini xotirjam tayyorlashni boshlang." }
            if daysBefore >= 30 { return "Safargacha bir oy. Pasport, parvoz va mehmonxonani iumrah rejangizda tekshiring." }
            if daysBefore >= 15 { return "Safar yaqinlashmoqda. Hujjatlar, transfer va tayyorgarlik ro‘yxatini tekshiring." }
            if daysBefore >= 7 { return "Umra yaqin. Safarning yakuniy tafsilotlarini va kerakli narsalarni tekshiring." }
            return "Umraga yakuniy tayyorgarlik. Rejangizni ochib sana, hujjat va yo‘nalishni tekshiring."
        case .uzbekCyrillic:
            if daysBefore >= 60 { return "Режангиз сақланди. Ҳужжатлар, саналар ва сафар бюджетини хотиржам тайёрлашни бошланг." }
            if daysBefore >= 30 { return "Сафаргача бир ой. Паспорт, парвоз ва меҳмонхонани iumrah режангизда текширинг." }
            if daysBefore >= 15 { return "Сафар яқинлашмоқда. Ҳужжатлар, трансфер ва тайёргарлик рўйхатини текширинг." }
            if daysBefore >= 7 { return "Умра яқин. Сафарнинг якуний тафсилотларини ва керакли нарсаларни текширинг." }
            return "Умрага якуний тайёргарлик. Режангизни очиб сана, ҳужжат ва йўналишни текширинг."
        }
    }
}

private struct UmrahPlanBackgroundOption: Identifiable {
    enum Kind { case photo, gradient }
    let id: String
    let kind: Kind
    let assetName: String?
    let colors: [Color]
    let title: String
    let prefersLightText: Bool
}

private enum UmrahPlanBackgroundCatalog {
    static let photos: [UmrahPlanBackgroundOption] = [
        UmrahPlanBackgroundOption(
            id: "photo-makkah-window",
            kind: .photo,
            assetName: "MakkahBackground",
            colors: [],
            title: "Makkah",
            prefersLightText: true
        ),
        UmrahPlanBackgroundOption(
            id: "photo-kaaba-arch",
            kind: .photo,
            assetName: "GiftCardKaaba",
            colors: [],
            title: "Kaaba",
            prefersLightText: true
        )
    ]

    static let gradients: [UmrahPlanBackgroundOption] = [
        UmrahPlanBackgroundOption(id: "gradient-sunset", kind: .gradient, assetName: nil, colors: [Color(red: 0.73, green: 0.37, blue: 0.22), Color(red: 0.35, green: 0.48, blue: 0.64)], title: "Sunset", prefersLightText: true),
        UmrahPlanBackgroundOption(id: "gradient-dawn", kind: .gradient, assetName: nil, colors: [Color(red: 1.00, green: 0.65, blue: 0.19), Color(red: 0.95, green: 0.31, blue: 0.23)], title: "Dawn", prefersLightText: true),
        UmrahPlanBackgroundOption(id: "gradient-sky", kind: .gradient, assetName: nil, colors: [Color(red: 0.18, green: 0.64, blue: 0.97), Color(red: 0.22, green: 0.34, blue: 0.88)], title: "Sky", prefersLightText: true),
        UmrahPlanBackgroundOption(id: "gradient-mint", kind: .gradient, assetName: nil, colors: [Color(red: 0.32, green: 0.82, blue: 0.55), Color(red: 0.10, green: 0.59, blue: 0.53)], title: "Mint", prefersLightText: true),
        UmrahPlanBackgroundOption(id: "gradient-gold", kind: .gradient, assetName: nil, colors: [Color(red: 0.98, green: 0.83, blue: 0.18), Color(red: 0.97, green: 0.48, blue: 0.15)], title: "Gold", prefersLightText: false),
        UmrahPlanBackgroundOption(id: "gradient-ocean", kind: .gradient, assetName: nil, colors: [Color(red: 0.00, green: 0.79, blue: 0.89), Color(red: 0.01, green: 0.35, blue: 0.75)], title: "Ocean", prefersLightText: true),
        UmrahPlanBackgroundOption(id: "gradient-lime", kind: .gradient, assetName: nil, colors: [Color(red: 0.80, green: 0.90, blue: 0.10), Color(red: 0.30, green: 0.73, blue: 0.22)], title: "Lime", prefersLightText: false),
        UmrahPlanBackgroundOption(id: "gradient-night", kind: .gradient, assetName: nil, colors: [Color(red: 0.26, green: 0.25, blue: 0.34), Color(red: 0.05, green: 0.08, blue: 0.13)], title: "Night", prefersLightText: true),
        UmrahPlanBackgroundOption(id: "gradient-sand", kind: .gradient, assetName: nil, colors: [Color(red: 0.88, green: 0.66, blue: 0.44), Color(red: 0.55, green: 0.38, blue: 0.28)], title: "Sand", prefersLightText: true)
    ]

    static let all = photos + gradients

    static func option(id: String) -> UmrahPlanBackgroundOption {
        all.first(where: { $0.id == id }) ?? gradients[0]
    }
}

private struct UmrahPlanBackgroundView: View {
    let id: String

    var body: some View {
        let option = UmrahPlanBackgroundCatalog.option(id: id)
        Group {
            switch option.kind {
            case .photo:
                if let assetName = option.assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .overlay(Color.black.opacity(0.22))
                }
            case .gradient:
                LinearGradient(colors: option.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

struct UmrahPlanHomeEntryCard: View {
    @ObservedObject private var store = UmrahPlanStore.shared
    let language: AppSettingsStore.Language

    var body: some View {
        if let trip = store.trip {
            plannedCard(trip)
        } else {
            emptyCard
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 44, height: 54)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -18, y: 2)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.92, green: 0.74, blue: 0.58))
                    .frame(width: 44, height: 54)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.55, green: 0.73, blue: 0.92))
                    .frame(width: 44, height: 54)
                    .rotationEffect(.degrees(12))
                    .offset(x: 18, y: 2)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.72))
            }
            .frame(height: 62)

            VStack(spacing: 8) {
                Text(PlanCopy.text(language, "Запланировать Umrah", "Plan your Umrah", "Umrani rejalashtiring", "Умрани режалаштиринг"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(PlanCopy.text(language,
                    "Выберите будущие даты и iumrah будет спокойно напоминать о подготовке к поездке.",
                    "Choose your future dates and iumrah will calmly remind you as your trip gets closer.",
                    "Kelajakdagi sanalarni tanlang — iumrah safar yaqinlashgani sari tayyorgarlikni eslatib turadi.",
                    "Келажакдаги саналарни танланг — iumrah сафар яқинлашгани сари тайёргарликни эслатиб туради."
                ))
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Text(PlanCopy.text(language, "Создать план поездки", "Create trip plan", "Safar rejasini yaratish", "Сафар режасини яратиш"))
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Color(red: 1.0, green: 0.32, blue: 0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.98, blue: 0.96), Color(red: 1.0, green: 0.91, blue: 0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
        }
    }

    private func plannedCard(_ trip: UmrahPlannedTrip) -> some View {
        let option = UmrahPlanBackgroundCatalog.option(id: trip.backgroundID)
        let textColor = option.prefersLightText ? Color.white : Color.black
        return ZStack {
            UmrahPlanBackgroundView(id: trip.backgroundID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(colors: [Color.black.opacity(0.05), Color.black.opacity(0.16)], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 0) {
                HStack {
                    Text(PlanCopy.text(language, "ПРЕДСТОЯЩАЯ", "UPCOMING", "KELGUSI", "КЕЛГУСИ"))
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                    Spacer()
                    Image(systemName: trip.notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(textColor.opacity(0.86))

                Spacer()

                Text(trip.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                    .foregroundStyle(textColor)

                Text(countdownText(trip))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor.opacity(0.78))
                    .padding(.top, 4)

                Text(PlanDate.formatRange(trip.startDate, trip.endDate, language: language))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(textColor.opacity(0.72))
                    .padding(.top, 3)

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                    Text(PlanCopy.text(language, "Напоминания настроены", "Reminders ready", "Eslatmalar tayyor", "Эслатмалар тайёр"))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 286)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8)
        }
    }

    private func countdownText(_ trip: UmrahPlannedTrip) -> String {
        let days = PlanDate.daysUntil(trip.startDate)
        let duration = PlanDate.durationDays(trip.startDate, trip.endDate)
        switch language {
        case .russian: return days > 0 ? "Через \(days) дн. · \(duration) дн. поездки" : "Поездка начинается сегодня · \(duration) дн."
        case .english: return days > 0 ? "In \(days) days · \(duration)-day trip" : "Starts today · \(duration)-day trip"
        case .uzbek: return days > 0 ? "\(days) kundan keyin · \(duration) kunlik safar" : "Bugun boshlanadi · \(duration) kun"
        case .uzbekCyrillic: return days > 0 ? "\(days) кундан кейин · \(duration) кунлик сафар" : "Бугун бошланади · \(duration) кун"
        }
    }
}


struct UmrahPlanReminderCenterView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @ObservedObject private var store = UmrahPlanStore.shared
    @State private var showReminderSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let trip = store.trip {
                NavigationLink {
                    UmrahPlanHubView()
                } label: {
                    UmrahPlanHomeEntryCard(language: settings.language)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        IumrahIconBadge(systemName: "bell.badge.fill", role: .notification, size: 48, symbolSize: 19, cornerRadius: 16)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(PlanCopy.text(settings.language, "Напоминания о следующей поездке", "Next-trip reminders", "Keyingi safar eslatmalari", "Кейинги сафар эслатмалари"))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text(PlanCopy.text(settings.language,
                                "iumrah напомнит о подготовке заранее и будет делать это чаще по мере приближения поездки.",
                                "iumrah reminds you early, then increases the cadence as your journey gets closer.",
                                "iumrah safar yaqinlashgani sari eslatmalarni oldindan va tez-tez yuboradi.",
                                "iumrah сафар яқинлашгани сари эслатмаларни олдиндан ва тез-тез юборади."
                            ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach(Array(trip.reminderDays.sorted(by: >).prefix(4)), id: \.self) { day in
                            Text(reminderDayLabel(day))
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(Color.iumrahRaisedBackground, in: Capsule())
                        }
                        Spacer(minLength: 0)
                        Text(String(format: "%02d:%02d", trip.reminderHour, trip.reminderMinute))
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        IumrahHaptics.selection()
                        showReminderSettings = true
                    } label: {
                        HStack {
                            Text(PlanCopy.text(settings.language, "Настроить напоминания", "Edit reminders", "Eslatmalarni sozlash", "Эслатмаларни созлаш"))
                            Spacer()
                            Image(systemName: "slider.horizontal.3")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .iumrahCard()
            } else {
                NavigationLink {
                    UmrahPlanHubView()
                } label: {
                    UmrahPlanHomeEntryCard(language: settings.language)
                }
                .buttonStyle(.plain)

                Text(PlanCopy.text(settings.language,
                    "Сначала запланируйте следующую Umrah — после этого здесь появится расписание напоминаний.",
                    "Plan your next Umrah first; your reminder schedule will then appear here.",
                    "Avval keyingi Umrani rejalashtiring — so‘ng bu yerda eslatmalar jadvali paydo bo‘ladi.",
                    "Аввал кейинги Умрани режалаштиринг — сўнг бу ерда эслатмалар жадвали пайдо бўлади."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $showReminderSettings) {
            if let trip = store.trip {
                UmrahPlanReminderSettingsView(trip: trip)
            }
        }
    }

    private func reminderDayLabel(_ day: Int) -> String {
        switch settings.language {
        case .russian: return day >= 30 ? "\(day / 30) мес." : "\(day) дн."
        case .english: return day >= 30 ? "\(day / 30) mo" : "\(day)d"
        case .uzbek: return day >= 30 ? "\(day / 30) oy" : "\(day) kun"
        case .uzbekCyrillic: return day >= 30 ? "\(day / 30) ой" : "\(day) кун"
        }
    }
}

struct UmrahPlanHubView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @ObservedObject private var store = UmrahPlanStore.shared
    @State private var showEditor = false
    @State private var showReminderSettings = false
    @State private var showDeleteConfirmation = false
    @State private var previewStatus: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let trip = store.trip {
                    plannedHero(trip)
                    routeCard(trip)
                    reminderSection(trip)
                    packageFutureCard
                    deleteButton
                } else {
                    upcomingLabel
                    creationCard
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 46)
        }
        .background(Color.iumrahPageBackground)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showEditor) {
            UmrahPlanEditorView(existingTrip: store.trip)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showReminderSettings) {
            if let trip = store.trip {
                UmrahPlanReminderSettingsView(trip: trip)
                    .environmentObject(settings)
            }
        }
        .confirmationDialog(
            PlanCopy.text(settings.language, "Удалить план Umrah?", "Delete Umrah plan?", "Umra rejasini o‘chirasizmi?", "Умра режасини ўчирасизми?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(PlanCopy.text(settings.language, "Удалить", "Delete", "O‘chirish", "Ўчириш"), role: .destructive) {
                store.deleteTrip()
                IumrahHaptics.soft()
            }
            Button(PlanCopy.text(settings.language, "Отмена", "Cancel", "Bekor qilish", "Бекор қилиш"), role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(PlanCopy.text(settings.language, "Мои поездки", "My trips", "Safarlarim", "Сафарларим"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                Text(String(Calendar.current.component(.year, from: store.trip?.startDate ?? Date())))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.06))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 1.0, green: 0.32, blue: 0.06).opacity(0.10), in: Capsule())
            }
            Spacer()
            if store.trip != nil {
                Button {
                    showEditor = true
                    IumrahHaptics.selection()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Color.iumrahRaisedBackground, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var upcomingLabel: some View {
        HStack(spacing: 12) {
            Text(PlanCopy.text(settings.language, "Предстоящий", "Upcoming", "Kelgusi", "Келгуси"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Rectangle().fill(Color.primary.opacity(0.18)).frame(height: 1)
        }
    }

    private var creationCard: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white).frame(width: 42, height: 54).rotationEffect(.degrees(-11)).offset(x: -18)
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(red: 0.93, green: 0.76, blue: 0.61)).frame(width: 42, height: 54)
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(red: 0.52, green: 0.73, blue: 0.91)).frame(width: 42, height: 54).rotationEffect(.degrees(11)).offset(x: 18)
                Image(systemName: "moon.stars.fill").foregroundStyle(.black.opacity(0.70))
            }
            .frame(height: 64)

            VStack(spacing: 9) {
                Text(PlanCopy.text(settings.language, "Организовать\nновую Umrah", "Plan a new\nUmrah", "Yangi Umrani\nrejalashtirish", "Янги Умрани\nрежалаштириш"))
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .tracking(-0.5)
                Text(PlanCopy.text(settings.language,
                    "Создайте будущую поездку, выберите даты и настройте напоминания о подготовке.",
                    "Create your future trip, choose dates and set preparation reminders.",
                    "Kelajakdagi safarni yarating, sanalarni tanlang va tayyorgarlik eslatmalarini sozlang.",
                    "Келажакдаги сафарни яратинг, саналарни танланг ва тайёргарлик эслатмаларини созланг."
                ))
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                showEditor = true
                IumrahHaptics.soft()
            } label: {
                Text(PlanCopy.text(settings.language, "Создать новую поездку", "Create a new trip", "Yangi safar yaratish", "Янги сафар яратиш"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color(red: 1.0, green: 0.32, blue: 0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                chrome.navigate(to: .booking)
            } label: {
                Text(PlanCopy.text(settings.language, "Открыть мои бронирования", "Open my bookings", "Bronlarimni ochish", "Бронларимни очиш"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.985, blue: 0.97), Color(red: 1.0, green: 0.90, blue: 0.84)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
        }
    }

    private func plannedHero(_ trip: UmrahPlannedTrip) -> some View {
        let option = UmrahPlanBackgroundCatalog.option(id: trip.backgroundID)
        let textColor = option.prefersLightText ? Color.white : Color.black
        return ZStack {
            UmrahPlanBackgroundView(id: trip.backgroundID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(colors: [Color.black.opacity(0.03), Color.black.opacity(0.21)], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 0) {
                HStack {
                    Menu {
                        Button(PlanCopy.text(settings.language, "Изменить поездку", "Edit trip", "Safarni tahrirlash", "Сафарни таҳрирлаш")) { showEditor = true }
                        Button(PlanCopy.text(settings.language, "Напоминания", "Reminders", "Eslatmalar", "Эслатмалар")) { showReminderSettings = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.18), in: Circle())
                    }
                    Spacer()
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.18), in: Circle())
                }

                Spacer()

                Text(trip.title)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                Text(heroCountdown(trip))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .opacity(0.82)
                    .padding(.top, 5)
                Text(PlanDate.formatRange(trip.startDate, trip.endDate, language: settings.language))
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .opacity(0.76)
                    .padding(.top, 4)

                Spacer()

                Button {
                    showReminderSettings = true
                    IumrahHaptics.selection()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                        Text(PlanCopy.text(settings.language, "Настроить напоминания", "Manage reminders", "Eslatmalarni sozlash", "Эслатмаларни созлаш"))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color.white.opacity(0.93), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(textColor)
            .padding(18)
        }
        .frame(height: 410)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func routeCard(_ trip: UmrahPlannedTrip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(PlanCopy.text(settings.language, "Маршрут", "Route", "Yo‘nalish", "Йўналиш"), systemImage: "map.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Text(PlanDate.shortDate(trip.startDate, language: settings.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(Color.primary.opacity(0.06), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(PlanCopy.text(settings.language, "Добавить маршрут позже", "Add route later", "Yo‘nalishni keyinroq qo‘shish", "Йўналишни кейинроқ қўшиш"))
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                    Text(PlanCopy.text(settings.language, "Сюда позже подключим выбранный пакет iumrah.", "Your selected iumrah package will appear here later.", "Keyinroq tanlangan iumrah paketi shu yerda ko‘rinadi.", "Кейинроқ танланган iumrah пакети шу ерда кўринади."))
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8) }
    }

    private func reminderSection(_ trip: UmrahPlannedTrip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(PlanCopy.text(settings.language, "Какие уведомления вы получите", "What notifications you'll get", "Qanday bildirishnomalar olasiz", "Қандай билдиришномалар оласиз"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(-0.3)
                Spacer()
            }

            let previewDays = trip.reminderDays.sorted(by: >).prefix(4)
            ForEach(Array(previewDays), id: \.self) { day in
                notificationPreviewRow(day: day, trip: trip)
            }

            Button {
                showReminderSettings = true
            } label: {
                HStack {
                    Text(PlanCopy.text(settings.language, "Настроить расписание", "Edit schedule", "Jadvalni sozlash", "Жадвални созлаш"))
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                }
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func notificationPreviewRow(day: Int, trip: UmrahPlannedTrip) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.06))
                .frame(width: 42, height: 42)
                .background(Color(red: 1.0, green: 0.32, blue: 0.06).opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(UmrahPlanNotificationScheduler.notificationTitle(daysBefore: day, languageRaw: trip.languageRaw))
                    .font(.system(size: 15.5, weight: .bold, design: .rounded))
                Text(UmrahPlanNotificationScheduler.notificationBody(daysBefore: day, startDate: trip.startDate, languageRaw: trip.languageRaw))
                    .font(.system(size: 13.5, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var packageFutureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.06))
                Text(PlanCopy.text(settings.language, "Пакеты для вашей даты", "Packages for your dates", "Sanangiz uchun paketlar", "Санангиз учун пакетлар"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text(PlanCopy.text(settings.language, "Скоро", "Soon", "Tez orada", "Тез орада"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text(PlanCopy.text(settings.language,
                "Следующим этапом сюда можно подключить Hotel First и Flight First, чтобы iumrah присылал подходящий пакет прямо к вашему плану.",
                "Next we can connect Hotel First and Flight First so iumrah can surface a matching package directly in this plan.",
                "Keyingi bosqichda Hotel First va Flight First ulanadi va iumrah mos paketni shu rejaning o‘zida ko‘rsatadi.",
                "Кейинги босқичда Hotel First ва Flight First уланади ва iumrah мос пакетни шу режанинг ўзида кўрсатади."
            ))
            .font(.system(size: 14.5, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8) }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text(PlanCopy.text(settings.language, "Удалить план поездки", "Delete trip plan", "Safar rejasini o‘chirish", "Сафар режасини ўчириш"))
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .buttonStyle(.plain)
    }

    private func heroCountdown(_ trip: UmrahPlannedTrip) -> String {
        let days = PlanDate.daysUntil(trip.startDate)
        let duration = PlanDate.durationDays(trip.startDate, trip.endDate)
        switch settings.language {
        case .russian: return days > 0 ? "Начнётся через \(days) дней · \(duration) дней поездки" : "Начинается сегодня · \(duration) дней поездки"
        case .english: return days > 0 ? "Starts in \(days) days · \(duration)-day trip" : "Starts today · \(duration)-day trip"
        case .uzbek: return days > 0 ? "\(days) kundan keyin boshlanadi · \(duration) kun" : "Bugun boshlanadi · \(duration) kun"
        case .uzbekCyrillic: return days > 0 ? "\(days) кундан кейин бошланади · \(duration) кун" : "Бугун бошланади · \(duration) кун"
        }
    }
}

private struct UmrahPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @ObservedObject private var store = UmrahPlanStore.shared

    let existingTrip: UmrahPlannedTrip?

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var backgroundID: String
    @State private var reminderDays: [Int]
    @State private var reminderHour: Int
    @State private var reminderMinute: Int
    @State private var notificationsEnabled: Bool
    @State private var showBackgroundPicker = false
    @State private var showDatePicker = false
    @State private var showReminderSettings = false

    init(existingTrip: UmrahPlannedTrip?) {
        self.existingTrip = existingTrip
        let calendar = Calendar.autoupdatingCurrent
        let defaultStart = calendar.date(byAdding: .month, value: 2, to: Date()) ?? Date().addingTimeInterval(60 * 60 * 24 * 60)
        let defaultEnd = calendar.date(byAdding: .day, value: 7, to: defaultStart) ?? defaultStart
        _title = State(initialValue: existingTrip?.title ?? "Umrah")
        _startDate = State(initialValue: existingTrip?.startDate ?? defaultStart)
        _endDate = State(initialValue: existingTrip?.endDate ?? defaultEnd)
        _backgroundID = State(initialValue: existingTrip?.backgroundID ?? "gradient-sunset")
        _reminderDays = State(initialValue: existingTrip?.reminderDays ?? UmrahPlanReminderPreset.defaultDays)
        _reminderHour = State(initialValue: existingTrip?.reminderHour ?? 19)
        _reminderMinute = State(initialValue: existingTrip?.reminderMinute ?? 0)
        _notificationsEnabled = State(initialValue: existingTrip?.notificationsEnabled ?? true)
    }

    var body: some View {
        ZStack {
            UmrahPlanBackgroundView(id: backgroundID)
                .ignoresSafeArea()

            LinearGradient(colors: [Color.black.opacity(0.22), Color.black.opacity(0.04), Color.black.opacity(0.34)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(PlanCopy.text(settings.language, "Отмена", "Cancel", "Bekor qilish", "Бекор қилиш")) {
                        dismiss()
                    }
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Color.black.opacity(0.28), in: Capsule())

                    Spacer()

                    Button(existingTrip == nil ? PlanCopy.text(settings.language, "Создать поездку", "Create trip", "Safar yaratish", "Сафар яратиш") : PlanCopy.text(settings.language, "Сохранить", "Save", "Saqlash", "Сақлаш")) {
                        save()
                    }
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(Color(red: 1.0, green: 0.32, blue: 0.06), in: Capsule())
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                Spacer()

                VStack(spacing: 9) {
                    TextField("Umrah", text: $title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)

                    Text(PlanDate.formatRange(startDate, endDate, language: settings.language))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(.horizontal, 28)

                Spacer()

                HStack(spacing: 12) {
                    editorAction(icon: "calendar", title: PlanCopy.text(settings.language, "Даты", "Dates", "Sanalar", "Саналар")) {
                        showDatePicker = true
                    }
                    editorAction(icon: "photo.on.rectangle.angled", title: PlanCopy.text(settings.language, "Фон", "Background", "Fon", "Фон")) {
                        showBackgroundPicker = true
                    }
                    editorAction(icon: "bell.badge", title: PlanCopy.text(settings.language, "Напоминания", "Reminders", "Eslatmalar", "Эслатмалар")) {
                        showReminderSettings = true
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showBackgroundPicker) {
            UmrahPlanBackgroundPicker(selectedID: $backgroundID)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showDatePicker) {
            UmrahPlanDateRangePicker(startDate: $startDate, endDate: $endDate)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showReminderSettings) {
            UmrahPlanReminderDraftView(
                reminderDays: $reminderDays,
                reminderHour: $reminderHour,
                reminderMinute: $reminderMinute,
                notificationsEnabled: $notificationsEnabled
            )
            .environmentObject(settings)
        }
    }

    private func editorAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip = UmrahPlannedTrip(
            id: existingTrip?.id ?? UUID(),
            title: cleanTitle.isEmpty ? "Umrah" : cleanTitle,
            startDate: startDate,
            endDate: max(endDate, startDate),
            backgroundID: backgroundID,
            reminderDays: Array(Set(reminderDays.filter { $0 > 0 })).sorted(by: >),
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            notificationsEnabled: notificationsEnabled,
            languageRaw: settings.language.rawValue,
            createdAt: existingTrip?.createdAt ?? Date()
        )
        store.save(trip)
        IumrahHaptics.success()
        dismiss()
    }
}

private struct UmrahPlanBackgroundPicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @Binding var selectedID: String
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("", selection: $tab) {
                    Text(PlanCopy.text(settings.language, "Фото", "Photos", "Rasmlar", "Расмлар")).tag(0)
                    Text(PlanCopy.text(settings.language, "Цвета", "Colors", "Ranglar", "Ранглар")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(tab == 0 ? UmrahPlanBackgroundCatalog.photos : UmrahPlanBackgroundCatalog.gradients) { option in
                            Button {
                                selectedID = option.id
                                IumrahHaptics.selection()
                                dismiss()
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    UmrahPlanBackgroundView(id: option.id)
                                        .frame(height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                    if selectedID == option.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(8)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 12)
            .navigationTitle(PlanCopy.text(settings.language, "Выберите фон", "Choose background", "Fon tanlang", "Фон танланг"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(PlanCopy.text(settings.language, "Отмена", "Cancel", "Bekor qilish", "Бекор қилиш")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct UmrahPlanDateRangePicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(PlanCopy.text(settings.language, "Начало поездки", "Trip starts", "Safar boshlanishi", "Сафар бошланиши"))
                            .font(.headline)
                        DatePicker("", selection: $startDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                    .padding(16)
                    .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(PlanCopy.text(settings.language, "Возвращение", "Return", "Qaytish", "Қайтиш"))
                            .font(.headline)
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                    .padding(16)
                    .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .padding(18)
            }
            .navigationTitle(PlanCopy.text(settings.language, "Даты поездки", "Trip dates", "Safar sanalari", "Сафар саналари"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PlanCopy.text(settings.language, "Готово", "Done", "Tayyor", "Тайёр")) {
                        if endDate < startDate { endDate = startDate }
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = Calendar.current.date(byAdding: .day, value: 7, to: newValue) ?? newValue
            }
        }
    }
}

private struct UmrahPlanReminderDraftView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @Binding var reminderDays: [Int]
    @Binding var reminderHour: Int
    @Binding var reminderMinute: Int
    @Binding var notificationsEnabled: Bool
    @State private var customDays = 12

    var body: some View {
        NavigationStack {
            ScrollView {
                reminderContent
                    .padding(18)
            }
            .navigationTitle(PlanCopy.text(settings.language, "Напоминания", "Reminders", "Eslatmalar", "Эслатмалар"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PlanCopy.text(settings.language, "Готово", "Done", "Tayyor", "Тайёр")) { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var reminderContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(PlanCopy.text(settings.language, "Напоминать о поездке", "Trip reminders", "Safar eslatmalari", "Сафар эслатмалари"), isOn: $notificationsEnabled)
                .font(.system(size: 17, weight: .bold, design: .rounded))

            if notificationsEnabled {
                reminderTimePicker
                reminderDaysPicker
            }
        }
    }

    private var reminderTimePicker: some View {
        let timeBinding = Binding<Date>(
            get: {
                var comps = DateComponents()
                comps.hour = reminderHour
                comps.minute = reminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                reminderHour = Calendar.current.component(.hour, from: date)
                reminderMinute = Calendar.current.component(.minute, from: date)
            }
        )
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(PlanCopy.text(settings.language, "Время уведомлений", "Reminder time", "Eslatma vaqti", "Эслатма вақти"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(PlanCopy.text(settings.language, "Все напоминания придут в это время.", "All reminders will arrive at this time.", "Barcha eslatmalar shu vaqtda keladi.", "Барча эслатмалар шу вақтда келади."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var reminderDaysPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PlanCopy.text(settings.language, "Когда напомнить", "When to remind", "Qachon eslatish", "Қачон эслатиш"))
                .font(.system(size: 18, weight: .bold, design: .rounded))

            ForEach(Array(Set(UmrahPlanReminderPreset.defaultDays + reminderDays)).sorted(by: >), id: \.self) { day in
                Toggle(isOn: Binding(
                    get: { reminderDays.contains(day) },
                    set: { enabled in
                        if enabled {
                            if !reminderDays.contains(day) { reminderDays.append(day) }
                        } else {
                            reminderDays.removeAll { $0 == day }
                        }
                    }
                )) {
                    Text(PlanCopy.daysBefore(day, language: settings.language))
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 12) {
                Stepper(value: $customDays, in: 1...180) {
                    Text(PlanCopy.daysBefore(customDays, language: settings.language))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                Button {
                    if !reminderDays.contains(customDays) { reminderDays.append(customDays) }
                    IumrahHaptics.selection()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 42, height: 42)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct UmrahPlanReminderSettingsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = UmrahPlanStore.shared

    @State private var trip: UmrahPlannedTrip
    @State private var previewMessage: String?

    init(trip: UmrahPlannedTrip) {
        _trip = State(initialValue: trip)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    UmrahPlanReminderDraftViewContent(trip: $trip)
                        .environmentObject(settings)

                    Button {
                        Task {
                            let ok = await UmrahPlanNotificationScheduler.schedulePreview(for: trip)
                            await MainActor.run {
                                previewMessage = ok
                                    ? PlanCopy.text(settings.language, "Тестовое уведомление придёт через несколько секунд.", "A test notification will arrive in a few seconds.", "Sinov bildirishnomasi bir necha soniyada keladi.", "Синов билдиришномаси бир неча сонияда келади.")
                                    : PlanCopy.text(settings.language, "Разрешите уведомления для iumrah в настройках iPhone.", "Allow iumrah notifications in iPhone Settings.", "iPhone sozlamalarida iumrah bildirishnomalariga ruxsat bering.", "iPhone созламаларида iumrah билдиришномаларига рухсат беринг.")
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                            Text(PlanCopy.text(settings.language, "Отправить тестовое уведомление", "Send test notification", "Sinov bildirishnomasini yuborish", "Синов билдиришномасини юбориш"))
                            Spacer()
                        }
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 17)
                        .frame(height: 56)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if let previewMessage {
                        Text(previewMessage)
                            .font(.system(size: 13.5, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(18)
            }
            .navigationTitle(PlanCopy.text(settings.language, "Напоминания", "Reminders", "Eslatmalar", "Эслатмалар"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(PlanCopy.text(settings.language, "Закрыть", "Close", "Yopish", "Ёпиш")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PlanCopy.text(settings.language, "Сохранить", "Save", "Saqlash", "Сақлаш")) {
                        trip.languageRaw = settings.language.rawValue
                        store.save(trip)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct UmrahPlanReminderDraftViewContent: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Binding var trip: UmrahPlannedTrip
    @State private var customDays = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(PlanCopy.text(settings.language, "Напоминать о поездке", "Trip reminders", "Safar eslatmalari", "Сафар эслатмалари"), isOn: $trip.notificationsEnabled)
                .font(.system(size: 17, weight: .bold, design: .rounded))

            if trip.notificationsEnabled {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PlanCopy.text(settings.language, "Время уведомлений", "Reminder time", "Eslatma vaqti", "Эслатма вақти"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(PlanCopy.text(settings.language, "Все выбранные напоминания приходят в это время.", "All selected reminders arrive at this time.", "Tanlangan eslatmalar shu vaqtda keladi.", "Танланган эслатмалар шу вақтда келади."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(16)
                .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(PlanCopy.text(settings.language, "Расписание", "Schedule", "Jadval", "Жадвал"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    ForEach(Array(Set(UmrahPlanReminderPreset.defaultDays + trip.reminderDays)).sorted(by: >), id: \.self) { day in
                        Toggle(isOn: Binding(
                            get: { trip.reminderDays.contains(day) },
                            set: { enabled in
                                if enabled {
                                    if !trip.reminderDays.contains(day) { trip.reminderDays.append(day) }
                                } else {
                                    trip.reminderDays.removeAll { $0 == day }
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(PlanCopy.daysBefore(day, language: settings.language))
                                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                                if day == 20 || day == 15 {
                                    Text(PlanCopy.text(settings.language, "С этого этапа напоминания становятся чаще", "Reminders become more frequent from here", "Shu bosqichdan eslatmalar tezlashadi", "Шу босқичдан эслатмалар тезлашади"))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    HStack(spacing: 12) {
                        Stepper(value: $customDays, in: 1...180) {
                            Text(PlanCopy.daysBefore(customDays, language: settings.language))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        Button {
                            if !trip.reminderDays.contains(customDays) { trip.reminderDays.append(customDays) }
                            IumrahHaptics.selection()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 42, height: 42)
                                .background(Color.primary.opacity(0.07), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var timeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = trip.reminderHour
                components.minute = trip.reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                trip.reminderHour = Calendar.current.component(.hour, from: date)
                trip.reminderMinute = Calendar.current.component(.minute, from: date)
            }
        )
    }
}

private enum PlanDate {
    static func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.autoupdatingCurrent
        let now = calendar.startOfDay(for: Date())
        let future = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: now, to: future).day ?? 0)
    }

    static func durationDays(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.autoupdatingCurrent
        let a = calendar.startOfDay(for: start)
        let b = calendar.startOfDay(for: max(start, end))
        return max(1, (calendar.dateComponents([.day], from: a, to: b).day ?? 0) + 1)
    }

    static func formatRange(_ start: Date, _ end: Date, language: AppSettingsStore.Language) -> String {
        "\(shortDate(start, language: language)) – \(shortDate(end, language: language))"
    }

    static func shortDate(_ date: Date, language: AppSettingsStore.Language) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

private enum PlanCopy {
    static func text(_ language: AppSettingsStore.Language, _ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    static func daysBefore(_ days: Int, language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian:
            if days == 60 { return "За 2 месяца" }
            if days == 30 { return "За 1 месяц" }
            return "За \(days) дней"
        case .english:
            if days == 60 { return "2 months before" }
            if days == 30 { return "1 month before" }
            return "\(days) days before"
        case .uzbek:
            if days == 60 { return "2 oy oldin" }
            if days == 30 { return "1 oy oldin" }
            return "\(days) kun oldin"
        case .uzbekCyrillic:
            if days == 60 { return "2 ой олдин" }
            if days == 30 { return "1 ой олдин" }
            return "\(days) кун олдин"
        }
    }
}
