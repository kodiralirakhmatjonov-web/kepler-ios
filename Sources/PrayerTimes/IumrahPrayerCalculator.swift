import Foundation

// Deterministic, network-independent prayer calculations. The results are
// astronomical estimates: local mosque schedules may differ by a few minutes.
struct IumrahPrayerPlace: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    var isValid: Bool { (-90...90).contains(latitude) && (-180...180).contains(longitude) }

    static let presets: [Self] = [
        .init(id: "makkah", name: "Makkah", latitude: 21.4225, longitude: 39.8262, timeZoneID: "Asia/Riyadh"),
        .init(id: "madinah", name: "Madinah", latitude: 24.4672, longitude: 39.6111, timeZoneID: "Asia/Riyadh"),
        .init(id: "tashkent", name: "Tashkent", latitude: 41.3111, longitude: 69.2797, timeZoneID: "Asia/Tashkent"),
        .init(id: "samarkand", name: "Samarkand", latitude: 39.6542, longitude: 66.9597, timeZoneID: "Asia/Tashkent"),
        .init(id: "istanbul", name: "Istanbul", latitude: 41.0082, longitude: 28.9784, timeZoneID: "Europe/Istanbul"),
        .init(id: "dubai", name: "Dubai", latitude: 25.2048, longitude: 55.2708, timeZoneID: "Asia/Dubai"),
        .init(id: "jakarta", name: "Jakarta", latitude: -6.2088, longitude: 106.8456, timeZoneID: "Asia/Jakarta"),
        .init(id: "london", name: "London", latitude: 51.5074, longitude: -0.1278, timeZoneID: "Europe/London")
    ]
}

enum IumrahPrayerMethod: String, CaseIterable, Identifiable, Codable {
    case ummAlQura, muslimWorldLeague, egypt, karachi, northAmerica
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ummAlQura: return "Umm al-Qura"
        case .muslimWorldLeague: return "Muslim World League"
        case .egypt: return "Egyptian Authority"
        case .karachi: return "University of Karachi"
        case .northAmerica: return "ISNA"
        }
    }
    var fajrAngle: Double {
        switch self {
        case .ummAlQura: return 18.5
        case .muslimWorldLeague: return 18
        case .egypt: return 19.5
        case .karachi: return 18
        case .northAmerica: return 15
        }
    }
    var ishaAngle: Double? {
        switch self {
        case .ummAlQura: return nil
        case .muslimWorldLeague: return 17
        case .egypt: return 17.5
        case .karachi: return 18
        case .northAmerica: return 15
        }
    }
}

enum IumrahPrayerKind: String, CaseIterable, Identifiable, Codable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha, duha, tahajjud
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        case .duha: return "Duha"
        case .tahajjud: return "Tahajjud"
        }
    }
    var symbol: String {
        switch self {
        case .fajr: return "moon.stars.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.haze.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.fill"
        case .duha: return "sun.max.circle.fill"
        case .tahajjud: return "moon.stars.circle.fill"
        }
    }
}

struct IumrahPrayerEntry: Identifiable, Hashable {
    let kind: IumrahPrayerKind
    let date: Date
    var id: String { kind.rawValue }
}

struct IumrahPrayerSchedule: Hashable {
    let place: IumrahPrayerPlace
    let day: Date
    let entries: [IumrahPrayerEntry]
    let duhaEnd: Date?

    func date(for kind: IumrahPrayerKind) -> Date? {
        entries.first(where: { $0.kind == kind })?.date
    }
    func displayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = place.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

enum IumrahPrayerCalculator {
    private static func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func deg(_ radians: Double) -> Double { radians * 180 / .pi }
    private static func normalize(_ angle: Double) -> Double { (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }

    // NOAA fractional-year approximation gives solar declination and equation of time.
    // Iterating at the estimated solar transit stabilizes the result around DST changes.
    private static func sun(at moment: Date) -> (declination: Double, equationMinutes: Double) {
        let julian = moment.timeIntervalSince1970 / 86400 + 2440587.5
        let t = (julian - 2451545.0) / 36525
        let l0 = normalize(280.46646 + t * (36000.76983 + 0.0003032 * t))
        let m = normalize(357.52911 + t * (35999.05029 - 0.0001537 * t))
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let c = sin(rad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(rad(2 * m)) * (0.019993 - 0.000101 * t) + sin(rad(3 * m)) * 0.000289
        let trueLongitude = l0 + c
        let omega = 125.04 - 1934.136 * t
        let lambda = trueLongitude - 0.00569 - 0.00478 * sin(rad(omega))
        let obliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
            + 0.00256 * cos(rad(omega))
        let epsilon = rad(obliquity)
        let declination = asin(sin(epsilon) * sin(rad(lambda)))
        let y = pow(tan(epsilon / 2), 2)
        let equation = 4 * deg(y * sin(2 * rad(l0)) - 2 * e * sin(rad(m))
            + 4 * e * y * sin(rad(m)) * cos(2 * rad(l0))
            - 0.5 * y * y * sin(4 * rad(l0)) - 1.25 * e * e * sin(2 * rad(m)))
        return (declination, equation)
    }

    private static func hourAngle(latitude: Double, declination: Double, altitude: Double) -> Double? {
        let lat = rad(latitude)
        let denominator = cos(lat) * cos(declination)
        guard abs(denominator) > 0.0000001 else { return nil }
        let cosine = (sin(rad(altitude)) - sin(lat) * sin(declination)) / denominator
        guard cosine.isFinite, (-1...1).contains(cosine) else { return nil }
        return deg(acos(cosine)) * 4 // minutes from solar noon
    }

    private static func baseDay(_ date: Date, place: IumrahPrayerPlace, method: IumrahPrayerMethod, hanafi: Bool) -> [IumrahPrayerKind: Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        let dayStart = calendar.startOfDay(for: date)
        let approximateNoon = dayStart.addingTimeInterval(12 * 3600)
        var solar = sun(at: approximateNoon)
        var noonMinutes = 720 - 4 * place.longitude - solar.equationMinutes
            + Double(place.timeZone.secondsFromGMT(for: approximateNoon)) / 60
        for _ in 0..<2 {
            let transit = dayStart.addingTimeInterval(noonMinutes * 60)
            solar = sun(at: transit)
            noonMinutes = 720 - 4 * place.longitude - solar.equationMinutes
                + Double(place.timeZone.secondsFromGMT(for: transit)) / 60
        }
        // Express transit as a wall-clock time. Adding seconds directly to local
        // midnight would introduce a one-hour error on a DST transition day.
        let wholeMinute = Int(floor(noonMinutes))
        let hour = (wholeMinute / 60) % 24
        let minute = ((wholeMinute % 60) + 60) % 60
        let localNoon = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)
        let noon = (localNoon ?? dayStart.addingTimeInterval(noonMinutes * 60))
            .addingTimeInterval((noonMinutes - Double(wholeMinute)) * 60)
        func before(_ angle: Double) -> Date? {
            hourAngle(latitude: place.latitude, declination: solar.declination, altitude: -angle)
                .map { noon.addingTimeInterval(-$0 * 60) }
        }
        func afterAltitude(_ altitude: Double) -> Date? {
            hourAngle(latitude: place.latitude, declination: solar.declination, altitude: altitude)
                .map { noon.addingTimeInterval($0 * 60) }
        }
        var result: [IumrahPrayerKind: Date] = [.dhuhr: noon]
        let sunRise = before(0.833)
        let sunSet = afterAltitude(-0.833)
        result[.sunrise] = sunRise
        result[.maghrib] = sunSet
        let fajr = before(method.fajrAngle)
        result[.fajr] = fajr
        let shadow = hanafi ? 2.0 : 1.0
        let asrAltitude = deg(atan(1 / (shadow + tan(abs(rad(place.latitude) - solar.declination)))))
        result[.asr] = afterAltitude(asrAltitude)
        if let angle = method.ishaAngle {
            result[.isha] = afterAltitude(-angle)
        } else if let sunSet {
            var islamic = Calendar(identifier: .islamicUmmAlQura)
            islamic.timeZone = place.timeZone
            let isRamadan = islamic.component(.month, from: noon) == 9
            result[.isha] = sunSet.addingTimeInterval(Double(isRamadan ? 120 : 90) * 60)
        }
        // High-latitude fallback using the angle-based portion of the night.
        // This applies only when astronomical twilight is absent, not globally.
        if result[.fajr] == nil, let sunRise, let sunSet {
            let prevSet = sunSet.addingTimeInterval(-24 * 3600)
            let night = sunRise.timeIntervalSince(prevSet)
            if night > 0 { result[.fajr] = sunRise.addingTimeInterval(-night * method.fajrAngle / 60) }
        }
        if result[.isha] == nil, let sunSet, let sunRise {
            let followingRise = sunRise.addingTimeInterval(24 * 3600)
            let night = followingRise.timeIntervalSince(sunSet)
            if night > 0 { result[.isha] = sunSet.addingTimeInterval(night * (method.ishaAngle ?? 17) / 60) }
        }
        if let sunRise { result[.duha] = sunRise.addingTimeInterval(20 * 60) }
        return result
    }

    static func calculate(on date: Date, place: IumrahPrayerPlace, method: IumrahPrayerMethod, hanafi: Bool) -> IumrahPrayerSchedule {
        guard place.isValid else { return .init(place: place, day: date, entries: [], duhaEnd: nil) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        let today = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86400)
        let entries = baseDay(today, place: place, method: method, hanafi: hanafi)
        let next = baseDay(tomorrow, place: place, method: method, hanafi: hanafi)
        var enriched = entries
        if let sunset = entries[.maghrib], let nextFajr = next[.fajr], nextFajr > sunset {
            enriched[.tahajjud] = sunset.addingTimeInterval(nextFajr.timeIntervalSince(sunset) * 2 / 3)
        }
        let order: [IumrahPrayerKind] = [.fajr, .sunrise, .duha, .dhuhr, .asr, .maghrib, .isha, .tahajjud]
        let mapped = order.compactMap { kind -> IumrahPrayerEntry? in
            enriched[kind].map { .init(kind: kind, date: $0) }
        }
        return .init(place: place, day: today, entries: mapped, duhaEnd: entries[.dhuhr].map { $0.addingTimeInterval(-15 * 60) })
    }

    static func upcoming(now: Date, place: IumrahPrayerPlace, method: IumrahPrayerMethod, hanafi: Bool) -> IumrahPrayerEntry? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        for shift in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: shift, to: now) else { continue }
            let schedule = calculate(on: day, place: place, method: method, hanafi: hanafi)
            if let next = schedule.entries
                .filter({ [.fajr, .dhuhr, .asr, .maghrib, .isha].contains($0.kind) && $0.date > now })
                .min(by: { $0.date < $1.date }) { return next }
        }
        return nil
    }
}
