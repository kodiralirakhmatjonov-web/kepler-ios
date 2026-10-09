import CoreLocation
import Combine
import Foundation
import UserNotifications

struct IumrahPrayerNotificationPreference: Codable, Equatable {
    var enabled = false
    var offsetMinutes = 0
    var sound = true
}

@MainActor
final class IumrahPrayerState: ObservableObject {
    @Published var place: IumrahPrayerPlace { didSet { persist() } }
    @Published var method: IumrahPrayerMethod { didSet { persist() } }
    @Published var hanafi: Bool { didSet { persist() } }
    @Published var wallpaper: IumrahPrayerWallpaper { didSet { persist() } }
    @Published var notifications: [String: IumrahPrayerNotificationPreference] { didSet { persist() } }

    private struct Persisted: Codable {
        var place: IumrahPrayerPlace
        var method: IumrahPrayerMethod
        var hanafi: Bool
        var wallpaper: IumrahPrayerWallpaper
        var notifications: [String: IumrahPrayerNotificationPreference]
    }
    private static let storageKey = "iumrah.prayerTimes.preferences.v2"

    init() {
        let previous = UserDefaults.standard.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(Persisted.self, from: $0) }
        let restored = previous?.place
        place = (restored?.isValid == true) ? restored! : IumrahPrayerPlace.presets[0]
        method = previous?.method ?? .ummAlQura
        hanafi = previous?.hanafi ?? false
        wallpaper = previous?.wallpaper ?? .kaabaCorner
        notifications = previous?.notifications ?? [:]
    }

    func preference(for kind: IumrahPrayerKind) -> IumrahPrayerNotificationPreference {
        notifications[kind.rawValue] ?? .init()
    }

    func setPreference(_ preference: IumrahPrayerNotificationPreference, for kind: IumrahPrayerKind) {
        var next = notifications
        var value = preference
        value.offsetMinutes = min(30, max(-30, value.offsetMinutes))
        next[kind.rawValue] = value
        notifications = next
    }

    private func persist() {
        let value = Persisted(place: place, method: method, hanafi: hanafi, wallpaper: wallpaper, notifications: notifications)
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

@MainActor
final class IumrahPrayerLocation: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var working = false
    @Published var message: String?
    @Published var resolved: IumrahPrayerPlace?
    private let manager = CLLocationManager()
    private var awaitingAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        guard !working else { return }
        message = nil
        guard CLLocationManager.locationServicesEnabled() else {
            message = "Location Services are disabled. Choose a city manually."
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            working = true
            awaitingAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            working = true
            manager.requestLocation()
        case .denied, .restricted:
            message = "Location access is unavailable. Choose a city manually or enable access in Settings."
        @unknown default:
            message = "Location unavailable. Choose a city manually."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard awaitingAuthorization else { return }
        if manager.authorizationStatus == .notDetermined { return }
        awaitingAuthorization = false
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        } else {
            working = false
            message = "Location permission was not granted. You can select a city manually."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, CLLocationCoordinate2DIsValid(location.coordinate) else {
            working = false
            message = "Could not obtain a valid location."
            return
        }
        Task { @MainActor in
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            let title = placemark?.locality ?? placemark?.administrativeArea ?? "Current location"
            let zone = placemark?.timeZone?.identifier ?? TimeZone.autoupdatingCurrent.identifier
            resolved = IumrahPrayerPlace(
                id: "current", name: title,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timeZoneID: zone
            )
            working = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        working = false
        message = "Unable to locate: \(error.localizedDescription)"
    }
}

@MainActor
enum IumrahPrayerNotifications {
    private static let prefix = "iumrah.prayer."

    static func synchronize(state: IumrahPrayerState, allowPermissionPrompt: Bool = false) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let existingIDs = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !existingIDs.isEmpty { center.removePendingNotificationRequests(withIdentifiers: existingIDs) }
        guard state.notifications.values.contains(where: { $0.enabled }) else { return true }
        let permission = await center.notificationSettings()
        var authorized = permission.authorizationStatus == .authorized || permission.authorizationStatus == .provisional
        if permission.authorizationStatus == .notDetermined && allowPermissionPrompt {
            authorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        guard authorized else { return false }

        let place = state.place
        let method = state.method
        let hanafi = state.hanafi
        let preferences = state.notifications
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        var requestsAdded = 0
        for dayOffset in 0..<8 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let schedule = IumrahPrayerCalculator.calculate(on: date, place: place, method: method, hanafi: hanafi)
            for entry in schedule.entries {
                guard let preference = preferences[entry.kind.rawValue], preference.enabled else { continue }
                let fireDate = entry.date.addingTimeInterval(TimeInterval(preference.offsetMinutes * 60))
                guard fireDate > now.addingTimeInterval(10) else { continue }
                guard requestsAdded < 56 else { break }
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                components.timeZone = place.timeZone
                let content = UNMutableNotificationContent()
                content.title = entry.kind.title
                content.body = "Prayer time in \(place.name)"
                content.sound = preference.sound ? .default : nil
                content.userInfo = ["iumrahCategory": "prayerTimes", "kind": entry.kind.rawValue]
                let id = prefix + String(Int(fireDate.timeIntervalSince1970)) + "." + entry.kind.rawValue
                let request = UNNotificationRequest(identifier: id, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                if (try? await center.add(request)) != nil { requestsAdded += 1 }
            }
        }
        return true
    }

    static func preview(kind: IumrahPrayerKind, sound: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let permission = await center.notificationSettings()
        var authorized = permission.authorizationStatus == .authorized || permission.authorizationStatus == .provisional
        if permission.authorizationStatus == .notDetermined {
            authorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        guard authorized else { return false }
        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = "iumrah Prayer Times · test notification"
        content.sound = sound ? .default : nil
        return (try? await center.add(UNNotificationRequest(
            identifier: prefix + "preview", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        ))) != nil
    }
}
