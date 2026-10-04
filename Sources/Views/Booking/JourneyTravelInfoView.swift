import CoreLocation
import Foundation
import SwiftUI

// MARK: - Booking travel context

enum IumrahHolyCity: String, CaseIterable, Identifiable, Codable {
    case makkah
    case madinah

    var id: String { rawValue }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .makkah: return CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        case .madinah: return CLLocationCoordinate2D(latitude: 24.4672, longitude: 39.6111)
        }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: "Asia/Riyadh") ?? .current
    }

    func title(_ language: AppSettingsStore.Language) -> String {
        switch self {
        case .makkah:
            switch language {
            case .russian: return "Мекка"
            case .english: return "Makkah"
            case .uzbek: return "Makka"
            case .uzbekCyrillic: return "Макка"
            }
        case .madinah:
            switch language {
            case .russian: return "Медина"
            case .english: return "Madinah"
            case .uzbek: return "Madina"
            case .uzbekCyrillic: return "Мадина"
            }
        }
    }
}

private enum JourneyInfoPage: Int, CaseIterable, Identifiable {
    case prayer
    case weather
    case clocks
    var id: Int { rawValue }
}

@MainActor
final class JourneyTravelInfoModel: ObservableObject {
    @Published private(set) var prayers: IumrahPrayerDay?
    @Published private(set) var weather: IumrahWeatherSnapshot?
    @Published private(set) var localCityName: String
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?

    private let prayerService = IumrahPrayerTimesService()
    private let weatherService = IumrahWeatherService()
    private var lastCity: IumrahHolyCity?

    init() {
        localCityName = Self.timeZoneCityName()
        resolveAuthorizedLocationName()
    }

    func refresh(city: IumrahHolyCity, force: Bool = false) async {
        if !force, lastCity == city, prayers != nil, weather != nil { return }
        if lastCity != nil, lastCity != city {
            prayers = nil
            weather = nil
        }
        lastCity = city
        isRefreshing = true
        defer { isRefreshing = false }

        async let prayerResult: IumrahPrayerDay? = try? prayerService.prayers(for: city, date: Date(), forceRefresh: force)
        async let weatherResult: IumrahWeatherSnapshot? = try? weatherService.forecast(for: city, forceRefresh: force)
        let (newPrayers, newWeather) = await (prayerResult, weatherResult)

        if let newPrayers { prayers = newPrayers }
        if let newWeather { weather = newWeather }
        lastError = (newPrayers == nil && newWeather == nil) ? "unavailable" : nil
    }

    private func resolveAuthorizedLocationName() {
        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways,
              let location = CLLocationManager().location else { return }

        Task { @MainActor in
            if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first,
               let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines),
               !city.isEmpty {
                localCityName = city
            }
        }
    }

    private static func timeZoneCityName() -> String {
        let identifier = TimeZone.autoupdatingCurrent.identifier
        let last = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }
}

struct JourneyTravelInfoView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @AppStorage("iumrah.booking.travelInfo.city") private var selectedCityRaw = IumrahHolyCity.makkah.rawValue
    @StateObject private var model = JourneyTravelInfoModel()
    @State private var page: JourneyInfoPage = .prayer

    private var city: IumrahHolyCity {
        IumrahHolyCity(rawValue: selectedCityRaw) ?? .makkah
    }

    var body: some View {
        VStack(spacing: 12) {
            holyCityPicker

            TabView(selection: $page) {
                PrayerTimesCard(city: city, day: model.prayers, isRefreshing: model.isRefreshing)
                    .tag(JourneyInfoPage.prayer)
                WeatherForecastCard(city: city, forecast: model.weather, isRefreshing: model.isRefreshing)
                    .tag(JourneyInfoPage.weather)
                DualWorldClockCard(city: city, localCityName: model.localCityName)
                    .tag(JourneyInfoPage.clocks)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 326)

            HStack(spacing: 7) {
                ForEach(JourneyInfoPage.allCases) { item in
                    Capsule()
                        .fill(item == page ? Color.primary : Color.secondary.opacity(0.20))
                        .frame(width: item == page ? 22 : 7, height: 7)
                        .animation(.snappy(duration: 0.24), value: page)
                }
            }
            .accessibilityHidden(true)
        }
        .task(id: city.rawValue) {
            await model.refresh(city: city)
        }
        .onChange(of: page) { _, _ in
            IumrahHaptics.selection()
        }
        .refreshable {
            await model.refresh(city: city, force: true)
        }
    }

    private var holyCityPicker: some View {
        Picker(
            tr("Holy city", "Священный город", "Muqaddas shahar", "Муқаддас шаҳар"),
            selection: Binding(
                get: { city },
                set: { newValue in
                    guard newValue != city else { return }
                    IumrahHaptics.selection()
                    withAnimation(.snappy(duration: 0.24)) {
                        selectedCityRaw = newValue.rawValue
                    }
                }
            )
        ) {
            Text(IumrahHolyCity.makkah.title(settings.language)).tag(IumrahHolyCity.makkah)
            Text(IumrahHolyCity.madinah.title(settings.language)).tag(IumrahHolyCity.madinah)
        }
        .pickerStyle(.segmented)
        .accessibilityElement(children: .contain)
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

// MARK: - Prayer card

private struct PrayerTimesCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let city: IumrahHolyCity
    let day: IumrahPrayerDay?
    let isRefreshing: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(eyebrow, systemImage: "moon.stars.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(city.title(settings.language))
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .tracking(-0.45)
                    }
                    Spacer(minLength: 8)
                    if isRefreshing && day == nil { ProgressView().controlSize(.small) }
                    if let next = day?.nextPrayer(after: context.date) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(next.title(settings.language))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.iumrahCareLight)
                            Text(next.time)
                                .font(.title3.monospacedDigit().weight(.bold))
                        }
                    }
                }

                if let day {
                    HStack(spacing: 6) {
                        ForEach(day.prayers) { prayer in
                            prayerCell(prayer, nextID: day.nextPrayer(after: context.date)?.id)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.primary.opacity(0.045))
                                .frame(height: 86)
                        }
                    }
                    .redacted(reason: .placeholder)

                    if !isRefreshing {
                        Label(prayerUnavailableText, systemImage: "wifi.slash")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text(methodLabel)
                    Spacer()
                    if let sunrise = day?.sunrise {
                        Label(sunrise, systemImage: "sunrise.fill")
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

                if let next = day?.nextPrayer(after: context.date) {
                    countdownPanel(next: next, now: context.date)
                }
            }
            .padding(19)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(prayerBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.085), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.035), radius: 14, y: 6)
        }
    }

    private func prayerCell(_ prayer: IumrahPrayerMoment, nextID: String?) -> some View {
        let active = prayer.id == nextID
        return VStack(spacing: 9) {
            Image(systemName: prayer.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.secondary)
            Text(prayer.shortTitle(settings.language))
                .font(.caption2.weight(.bold))
                .foregroundStyle(active ? Color.white.opacity(0.88) : Color.secondary)
            Text(prayer.time)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(active ? Color.white : Color.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(active ? Color.black : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: active)
    }

    private func countdownPanel(next: IumrahPrayerMoment, now: Date) -> some View {
        let parts = countdownParts(to: next.date, now: now)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("UNTIL NEXT PRAYER", "ДО СЛЕДУЮЩЕЙ МОЛИТВЫ", "KEYINGI NAMOZGACHA", "КЕЙИНГИ НАМОЗГАЧА"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(next.title(settings.language))
                    .font(.subheadline.weight(.bold))
            }

            Spacer(minLength: 8)

            HStack(spacing: 7) {
                timerUnit(parts.hours, tr("h", "ч", "soat", "с"))
                Text(":").font(.headline.monospacedDigit()).foregroundStyle(.secondary)
                timerUnit(parts.minutes, tr("m", "м", "daq", "д"))
                Text(":").font(.headline.monospacedDigit()).foregroundStyle(.secondary)
                timerUnit(parts.seconds, tr("s", "с", "son", "с"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func timerUnit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%02d", value))
                .font(.subheadline.monospacedDigit().weight(.bold))
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 27)
    }

    private func countdownParts(to date: Date, now: Date) -> (hours: Int, minutes: Int, seconds: Int) {
        let interval = max(0, Int(date.timeIntervalSince(now)))
        return (interval / 3600, (interval % 3600) / 60, interval % 60)
    }

    private var prayerBackground: LinearGradient {
        LinearGradient(
            colors: [Color.iumrahCardBackground, Color.iumrahCareLight.opacity(0.055)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var prayerUnavailableText: String {
        switch settings.language {
        case .russian: return "Времена появятся после подключения к сети"
        case .english: return "Prayer times appear when online"
        case .uzbek: return "Namoz vaqtlari internet bo‘lganda chiqadi"
        case .uzbekCyrillic: return "Намоз вақтлари интернет бўлганда чиқади"
        }
    }

    private var eyebrow: String {
        switch settings.language {
        case .russian: return "ВРЕМЕНА МОЛИТВ"
        case .english: return "PRAYER TIMES"
        case .uzbek: return "NAMOZ VAQTLARI"
        case .uzbekCyrillic: return "НАМОЗ ВАҚТЛАРИ"
        }
    }

    private var methodLabel: String {
        switch settings.language {
        case .russian: return "Umm al-Qura · время Саудии"
        case .english: return "Umm al-Qura · Saudi time"
        case .uzbek: return "Umm al-Qura · Saudiya vaqti"
        case .uzbekCyrillic: return "Umm al-Qura · Саудия вақти"
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

// MARK: - Weather card

private struct WeatherForecastCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let city: IumrahHolyCity
    let forecast: IumrahWeatherSnapshot?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(weatherEyebrow, systemImage: "cloud.sun.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(city.title(settings.language))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                }
                Spacer(minLength: 8)
                if let forecast {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(Int(forecast.currentTemperature.rounded()))°")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .tracking(-1.2)
                        Text(forecast.currentCondition.localized(settings.language))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                } else if isRefreshing {
                    ProgressView().controlSize(.small)
                }
            }

            if let forecast {
                HStack(spacing: 8) {
                    ForEach(forecast.days.prefix(7)) { day in
                        VStack(spacing: 7) {
                            Text(day.dayLabel(language: settings.language, timeZone: city.timeZone))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                            Image(systemName: day.condition.symbol)
                                .symbolRenderingMode(.hierarchical)
                                .font(.system(size: 19, weight: .semibold))
                            Text("\(Int(day.high.rounded()))°")
                                .font(.caption.monospacedDigit().weight(.bold))
                            Text("\(Int(day.low.rounded()))°")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
                    .frame(height: 105)
                    .redacted(reason: .placeholder)
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                Text(forecast == nil ? unavailableText : providerText)
                Spacer()
                if let forecast {
                    Text(forecast.updatedLabel(language: settings.language, timeZone: city.timeZone))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(19)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(weatherBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.085), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.035), radius: 14, y: 6)
    }

    private var weatherBackground: some ShapeStyle {
        LinearGradient(
            colors: [Color.iumrahCardBackground, Color.blue.opacity(0.055)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var weatherEyebrow: String {
        switch settings.language {
        case .russian: return "ПОГОДА · 7 ДНЕЙ"
        case .english: return "WEATHER · 7 DAYS"
        case .uzbek: return "OB-HAVO · 7 KUN"
        case .uzbekCyrillic: return "ОБ-ҲАВО · 7 КУН"
        }
    }

    private var providerText: String { "Weather data · MET Norway" }

    private var unavailableText: String {
        switch settings.language {
        case .russian: return "Прогноз появится при подключении к сети"
        case .english: return "Forecast appears when online"
        case .uzbek: return "Prognoz internet bo‘lganda chiqadi"
        case .uzbekCyrillic: return "Прогноз интернет бўлганда чиқади"
        }
    }
}

// MARK: - Clock card

private struct DualWorldClockCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let city: IumrahHolyCity
    let localCityName: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 12) {
                Label(clockEyebrow, systemImage: "clock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 18) {
                    clockColumn(
                        title: city.title(settings.language),
                        date: context.date,
                        timeZone: city.timeZone,
                        accent: Color.iumrahCareLight
                    )
                    clockColumn(
                        title: localCityName,
                        date: context.date,
                        timeZone: .autoupdatingCurrent,
                        accent: .blue
                    )
                }

                VStack(spacing: 5) {
                    HStack {
                        Text("\(city.title(settings.language)) · \(gmtLabel(city.timeZone))")
                        Spacer()
                        Text("\(localCityName) · \(gmtLabel(.autoupdatingCurrent))")
                    }
                    Text(offsetText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .padding(19)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(clockBackground)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.085), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.035), radius: 14, y: 6)
        }
    }

    private func clockColumn(title: String, date: Date, timeZone: TimeZone, accent: Color) -> some View {
        VStack(spacing: 8) {
            AnalogTravelClock(date: date, timeZone: timeZone, accent: accent)
                .frame(width: 112, height: 112)
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(timeString(date, timeZone: timeZone))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var clockBackground: some ShapeStyle {
        LinearGradient(
            colors: [Color.iumrahCardBackground, Color.primary.opacity(0.018)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var clockEyebrow: String {
        switch settings.language {
        case .russian: return "МИРОВОЕ ВРЕМЯ"
        case .english: return "WORLD CLOCK"
        case .uzbek: return "DUNYO VAQTI"
        case .uzbekCyrillic: return "ДУНЁ ВАҚТИ"
        }
    }

    private var offsetText: String {
        let holySeconds = city.timeZone.secondsFromGMT(for: Date())
        let localSeconds = TimeZone.autoupdatingCurrent.secondsFromGMT(for: Date())
        let deltaMinutes = (localSeconds - holySeconds) / 60
        guard deltaMinutes != 0 else {
            switch settings.language {
            case .russian: return "Одинаковое время"
            case .english: return "Same time"
            case .uzbek: return "Vaqt bir xil"
            case .uzbekCyrillic: return "Вақт бир хил"
            }
        }
        let sign = deltaMinutes > 0 ? "+" : "−"
        let absolute = abs(deltaMinutes)
        let hours = absolute / 60
        let minutes = absolute % 60
        let delta = minutes == 0 ? "\(sign)\(hours) ч" : "\(sign)\(hours):\(String(format: "%02d", minutes))"
        switch settings.language {
        case .russian: return "Ваш город \(delta) относительно Саудии"
        case .english: return "Your city \(delta) vs Saudi Arabia"
        case .uzbek: return "Shahringiz Saudiya vaqtiga nisbatan \(delta)"
        case .uzbekCyrillic: return "Шаҳрингиз Саудия вақтига нисбатан \(delta)"
        }
    }

    private func gmtLabel(_ timeZone: TimeZone) -> String {
        let minutes = timeZone.secondsFromGMT(for: Date()) / 60
        let sign = minutes >= 0 ? "+" : "−"
        let absolute = abs(minutes)
        let hours = absolute / 60
        let remainder = absolute % 60
        return remainder == 0 ? "UTC\(sign)\(hours)" : "UTC\(sign)\(hours):\(String(format: "%02d", remainder))"
    }

    private func timeString(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

private struct AnalogTravelClock: View {
    let date: Date
    let timeZone: TimeZone
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            var face = Path()
            face.addEllipse(in: CGRect(x: center.x - radius + 1, y: center.y - radius + 1, width: (radius - 1) * 2, height: (radius - 1) * 2))
            context.fill(face, with: .color(Color.primary.opacity(0.035)))
            context.stroke(face, with: .color(Color.primary.opacity(0.10)), lineWidth: 0.8)

            for index in 0..<60 {
                let angle = Double(index) / 60 * 2 * Double.pi - Double.pi / 2
                let major = index % 5 == 0
                let outer = radius - 7
                let inner = outer - (major ? 8 : 3)
                var mark = Path()
                mark.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                mark.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                context.stroke(mark, with: .color(Color.primary.opacity(major ? 0.58 : 0.18)), lineWidth: major ? 1.5 : 0.7)
            }

            let calendar = Calendar(identifier: .gregorian)
            var zoned = calendar
            zoned.timeZone = timeZone
            let comps = zoned.dateComponents([.hour, .minute, .second], from: date)
            let hour = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
            let minute = Double(comps.minute ?? 0) + Double(comps.second ?? 0) / 60
            let second = Double(comps.second ?? 0)

            hand(context: context, center: center, radius: radius * 0.48, angle: hour / 12 * 2 * .pi - .pi / 2, width: 4.2, color: .primary)
            hand(context: context, center: center, radius: radius * 0.68, angle: minute / 60 * 2 * .pi - .pi / 2, width: 2.7, color: .primary)
            hand(context: context, center: center, radius: radius * 0.72, angle: second / 60 * 2 * .pi - .pi / 2, width: 1.2, color: accent)

            var dot = Path()
            dot.addEllipse(in: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7))
            context.fill(dot, with: .color(accent))
        }
        .accessibilityHidden(true)
    }

    private func hand(context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double, width: CGFloat, color: Color) {
        var path = Path()
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

// MARK: - Prayer service

struct IumrahPrayerMoment: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let time: String
    let date: Date

    var symbol: String {
        switch id {
        case "fajr": return "sunrise.fill"
        case "dhuhr": return "sun.max.fill"
        case "asr": return "sun.haze.fill"
        case "maghrib": return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    func title(_ language: AppSettingsStore.Language) -> String {
        switch (id, language) {
        case ("fajr", .russian): return "Фаджр"
        case ("dhuhr", .russian): return "Зухр"
        case ("asr", .russian): return "Аср"
        case ("maghrib", .russian): return "Магриб"
        case ("isha", .russian): return "Иша"
        case ("fajr", .uzbek), ("fajr", .uzbekCyrillic): return "Fajr"
        case ("dhuhr", .uzbek), ("dhuhr", .uzbekCyrillic): return "Dhuhr"
        case ("asr", .uzbek), ("asr", .uzbekCyrillic): return "Asr"
        case ("maghrib", .uzbek), ("maghrib", .uzbekCyrillic): return "Maghrib"
        case ("isha", .uzbek), ("isha", .uzbekCyrillic): return "Isha"
        default: return name
        }
    }

    func shortTitle(_ language: AppSettingsStore.Language) -> String {
        switch id {
        case "fajr": return language == .russian ? "Фаджр" : "Fajr"
        case "dhuhr": return language == .russian ? "Зухр" : "Dhuhr"
        case "asr": return language == .russian ? "Аср" : "Asr"
        case "maghrib": return language == .russian ? "Магр." : "Magh."
        default: return language == .russian ? "Иша" : "Isha"
        }
    }
}

struct IumrahPrayerDay: Codable, Hashable {
    let city: IumrahHolyCity
    let dateKey: String
    let prayers: [IumrahPrayerMoment]
    let sunrise: String?
    let tomorrowFajr: IumrahPrayerMoment?
    let cachedAt: Date

    func nextPrayer(after now: Date) -> IumrahPrayerMoment? {
        if let next = prayers.first(where: { $0.date > now }) { return next }
        if let tomorrowFajr, tomorrowFajr.date > now { return tomorrowFajr }
        return nil
    }
}

private actor IumrahPrayerTimesService {
    private let session: URLSession = .shared

    func prayers(for city: IumrahHolyCity, date: Date, forceRefresh: Bool) async throws -> IumrahPrayerDay {
        let key = cacheKey(city: city, date: date)
        var cityCalendar = Calendar(identifier: .gregorian)
        cityCalendar.timeZone = city.timeZone
        if !forceRefresh, let cached = loadCache(key), cityCalendar.isDate(cached.cachedAt, inSameDayAs: date) {
            return cached
        }

        do {
            let value = try await fetch(city: city, date: date)
            saveCache(value, key: key)
            return value
        } catch {
            if let cached = loadCache(key) { return cached }
            throw error
        }
    }

    private func fetch(city: IumrahHolyCity, date: Date) async throws -> IumrahPrayerDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)

        async let todayTimings = fetchTimings(city: city, date: date)
        async let tomorrowTimings = fetchTimings(city: city, date: tomorrow)
        let (today, nextDay) = try await (todayTimings, tomorrowTimings)
        return makeDay(city: city, date: date, timings: today, tomorrowDate: tomorrow, tomorrowTimings: nextDay)
    }

    private func fetchTimings(city: IumrahHolyCity, date: Date) async throws -> AlAdhanTimings {
        let formatter = DateFormatter()
        formatter.timeZone = city.timeZone
        formatter.dateFormat = "dd-MM-yyyy"
        let dateString = formatter.string(from: date)
        let coordinate = city.coordinate
        var components = URLComponents(string: "https://api.aladhan.com/v1/timings/\(dateString)")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.5f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.5f", coordinate.longitude)),
            URLQueryItem(name: "method", value: "4"),
            URLQueryItem(name: "school", value: "0")
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 10
        request.setValue("iumrah-iOS/2.0 (https://iumrah.app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(AlAdhanResponse.self, from: data).data.timings
    }

    private func makeDay(city: IumrahHolyCity, date: Date, timings: AlAdhanTimings, tomorrowDate: Date, tomorrowTimings: AlAdhanTimings) -> IumrahPrayerDay {
        let clean: (String) -> String = { raw in
            raw.split(separator: " ").first.map(String.init) ?? raw
        }
        let values: [(String, String, String)] = [
            ("fajr", "Fajr", clean(timings.Fajr)),
            ("dhuhr", "Dhuhr", clean(timings.Dhuhr)),
            ("asr", "Asr", clean(timings.Asr)),
            ("maghrib", "Maghrib", clean(timings.Maghrib)),
            ("isha", "Isha", clean(timings.Isha))
        ]
        let moments = values.compactMap { id, name, time -> IumrahPrayerMoment? in
            guard let parsed = combine(day: date, time: time, timeZone: city.timeZone) else { return nil }
            return IumrahPrayerMoment(id: id, name: name, time: time, date: parsed)
        }
        let keyFormatter = DateFormatter()
        keyFormatter.timeZone = city.timeZone
        keyFormatter.dateFormat = "yyyy-MM-dd"
        let tomorrowFajrTime = clean(tomorrowTimings.Fajr)
        let tomorrowFajr = combine(day: tomorrowDate, time: tomorrowFajrTime, timeZone: city.timeZone).map {
            IumrahPrayerMoment(id: "fajr", name: "Fajr", time: tomorrowFajrTime, date: $0)
        }
        return IumrahPrayerDay(
            city: city,
            dateKey: keyFormatter.string(from: date),
            prayers: moments,
            sunrise: clean(timings.Sunrise),
            tomorrowFajr: tomorrowFajr,
            cachedAt: Date()
        )
    }

    private func combine(day: Date, time: String, timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        components.hour = parts[0]
        components.minute = parts[1]
        components.second = 0
        components.timeZone = timeZone
        return calendar.date(from: components)
    }

    private func cacheKey(city: IumrahHolyCity, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = city.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "iumrah.prayers.\(city.rawValue).\(formatter.string(from: date))"
    }

    private func loadCache(_ key: String) -> IumrahPrayerDay? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(IumrahPrayerDay.self, from: data)
    }

    private func saveCache(_ value: IumrahPrayerDay, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct AlAdhanResponse: Decodable {
    let data: AlAdhanData
}
private struct AlAdhanData: Decodable { let timings: AlAdhanTimings }
private struct AlAdhanTimings: Decodable {
    let Fajr: String
    let Sunrise: String
    let Dhuhr: String
    let Asr: String
    let Maghrib: String
    let Isha: String
}

// MARK: - Weather service

struct IumrahWeatherSnapshot: Codable, Hashable {
    let city: IumrahHolyCity
    let currentTemperature: Double
    let currentCondition: IumrahWeatherCondition
    let days: [IumrahWeatherDay]
    let fetchedAt: Date

    func updatedLabel(language: AppSettingsStore.Language, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        switch language {
        case .russian: return "обновлено \(formatter.string(from: fetchedAt))"
        case .english: return "updated \(formatter.string(from: fetchedAt))"
        case .uzbek: return "yangilandi \(formatter.string(from: fetchedAt))"
        case .uzbekCyrillic: return "янгиланди \(formatter.string(from: fetchedAt))"
        }
    }
}

struct IumrahWeatherDay: Identifiable, Codable, Hashable {
    let date: Date
    let high: Double
    let low: Double
    let condition: IumrahWeatherCondition
    var id: Date { date }

    func dayLabel(language: AppSettingsStore.Language, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(date, inSameDayAs: Date()) {
            switch language {
            case .russian: return "Сег."
            case .english: return "Today"
            case .uzbek: return "Bugun"
            case .uzbekCyrillic: return "Бугун"
            }
        }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        switch language {
        case .russian: formatter.locale = Locale(identifier: "ru_RU")
        case .english: formatter.locale = Locale(identifier: "en_US")
        case .uzbek: formatter.locale = Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: formatter.locale = Locale(identifier: "uz_Cyrl_UZ")
        }
        formatter.dateFormat = "EE"
        return formatter.string(from: date).capitalized
    }
}

enum IumrahWeatherCondition: String, Codable, Hashable {
    case clear
    case partlyCloudy
    case cloudy
    case fog
    case rain
    case showers
    case thunder
    case snow
    case unknown

    var symbol: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .rain: return "cloud.rain.fill"
        case .showers: return "cloud.heavyrain.fill"
        case .thunder: return "cloud.bolt.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .unknown: return "cloud.fill"
        }
    }

    func localized(_ language: AppSettingsStore.Language) -> String {
        switch (self, language) {
        case (.clear, .russian): return "Ясно"
        case (.partlyCloudy, .russian): return "Переменная облачность"
        case (.cloudy, .russian): return "Облачно"
        case (.fog, .russian): return "Туман"
        case (.rain, .russian), (.showers, .russian): return "Дождь"
        case (.thunder, .russian): return "Гроза"
        case (.snow, .russian): return "Снег"
        case (.clear, .english): return "Clear"
        case (.partlyCloudy, .english): return "Partly cloudy"
        case (.cloudy, .english): return "Cloudy"
        case (.fog, .english): return "Fog"
        case (.rain, .english), (.showers, .english): return "Rain"
        case (.thunder, .english): return "Thunderstorm"
        case (.snow, .english): return "Snow"
        case (.clear, .uzbek), (.clear, .uzbekCyrillic): return "Ochiq"
        case (.partlyCloudy, .uzbek), (.partlyCloudy, .uzbekCyrillic): return "Qisman bulutli"
        case (.cloudy, .uzbek), (.cloudy, .uzbekCyrillic): return "Bulutli"
        case (.fog, .uzbek), (.fog, .uzbekCyrillic): return "Tuman"
        case (.rain, .uzbek), (.showers, .uzbek), (.rain, .uzbekCyrillic), (.showers, .uzbekCyrillic): return "Yomg‘ir"
        case (.thunder, .uzbek), (.thunder, .uzbekCyrillic): return "Momaqaldiroq"
        case (.snow, .uzbek), (.snow, .uzbekCyrillic): return "Qor"
        default: return "Weather"
        }
    }

    static func fromMET(_ raw: String?) -> IumrahWeatherCondition {
        guard let raw = raw?.lowercased() else { return .unknown }
        if raw.contains("thunder") { return .thunder }
        if raw.contains("snow") || raw.contains("sleet") { return .snow }
        if raw.contains("rainshowers") || raw.contains("showers") { return .showers }
        if raw.contains("rain") { return .rain }
        if raw.contains("fog") { return .fog }
        if raw.contains("partlycloudy") || raw.contains("fair") { return .partlyCloudy }
        if raw.contains("cloudy") { return .cloudy }
        if raw.contains("clearsky") { return .clear }
        return .unknown
    }
}

private actor IumrahWeatherService {
    private let session: URLSession = .shared
    private let maxAge: TimeInterval = 30 * 60

    func forecast(for city: IumrahHolyCity, forceRefresh: Bool) async throws -> IumrahWeatherSnapshot {
        let key = "iumrah.weather.\(city.rawValue)"
        if !forceRefresh, let cached = loadCache(key), Date().timeIntervalSince(cached.fetchedAt) < maxAge {
            return cached
        }

        do {
            let snapshot = try await fetch(city: city)
            saveCache(snapshot, key: key)
            return snapshot
        } catch {
            if let cached = loadCache(key) { return cached }
            throw error
        }
    }

    private func fetch(city: IumrahHolyCity) async throws -> IumrahWeatherSnapshot {
        let c = city.coordinate
        var components = URLComponents(string: "https://api.met.no/weatherapi/locationforecast/2.0/compact")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.4f", c.latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.4f", c.longitude))
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        request.setValue("iumrah-iOS/2.0 (https://iumrah.app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let decoded = try JSONDecoder.metWeather.decode(METLocationForecast.self, from: data)
        guard let current = decoded.properties.timeseries.first else { throw URLError(.cannotParseResponse) }

        let currentTemp = current.data.instant.details.airTemperature
        let currentCondition = IumrahWeatherCondition.fromMET(current.data.next1Hours?.summary.symbolCode ?? current.data.next6Hours?.summary.symbolCode)
        let days = aggregateDays(decoded.properties.timeseries, city: city)
        return IumrahWeatherSnapshot(city: city, currentTemperature: currentTemp, currentCondition: currentCondition, days: days, fetchedAt: Date())
    }

    private func aggregateDays(_ series: [METTimeSeries], city: IumrahHolyCity) -> [IumrahWeatherDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let grouped = Dictionary(grouping: series) { calendar.startOfDay(for: $0.time) }
        return grouped.keys.sorted().prefix(7).compactMap { day in
            guard let items = grouped[day], !items.isEmpty else { return nil }
            let temperatures = items.map { $0.data.instant.details.airTemperature }
            guard let low = temperatures.min(), let high = temperatures.max() else { return nil }
            let midday = items.min { lhs, rhs in
                abs(calendar.component(.hour, from: lhs.time) - 12) < abs(calendar.component(.hour, from: rhs.time) - 12)
            }
            let code = midday?.data.next6Hours?.summary.symbolCode ?? midday?.data.next1Hours?.summary.symbolCode
            return IumrahWeatherDay(date: day, high: high, low: low, condition: .fromMET(code))
        }
    }

    private func loadCache(_ key: String) -> IumrahWeatherSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(IumrahWeatherSnapshot.self, from: data)
    }

    private func saveCache(_ value: IumrahWeatherSnapshot, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct METLocationForecast: Decodable {
    let properties: METProperties
}
private struct METProperties: Decodable { let timeseries: [METTimeSeries] }
private struct METTimeSeries: Decodable {
    let time: Date
    let data: METData
}
private struct METData: Decodable {
    let instant: METInstant
    let next1Hours: METPeriod?
    let next6Hours: METPeriod?

    enum CodingKeys: String, CodingKey {
        case instant
        case next1Hours = "next_1_hours"
        case next6Hours = "next_6_hours"
    }
}
private struct METInstant: Decodable { let details: METInstantDetails }
private struct METInstantDetails: Decodable {
    let airTemperature: Double
    enum CodingKeys: String, CodingKey { case airTemperature = "air_temperature" }
}
private struct METPeriod: Decodable { let summary: METSummary }
private struct METSummary: Decodable {
    let symbolCode: String?
    enum CodingKeys: String, CodingKey { case symbolCode = "symbol_code" }
}

private extension JSONDecoder {
    static var metWeather: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
