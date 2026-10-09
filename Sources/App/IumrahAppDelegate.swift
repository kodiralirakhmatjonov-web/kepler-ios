import GoogleSignIn
import UIKit
import UserNotifications

final class IumrahAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        Task { @MainActor in
            await PushNotificationManager.shared.refreshAndRegisterIfAllowed()
            // Restore local prayer reminders after normal launches, without
            // requesting permissions or touching flight/booking notifications.
            _ = await IumrahPrayerNotifications.synchronize(state: IumrahPrayerState())
        }

        return true
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        // Keep every existing custom URL flow available to the SwiftUI app.
        return false
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegister(error: error)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if !notification.request.identifier.hasPrefix("iumrah.prayer.") {
            await MainActor.run {
                PushNotificationManager.shared.receiveRemotePayload(notification.request.content.userInfo, opened: false)
            }
        }
        return [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Prayer alerts are local reminders, not server booking events.
        guard !response.notification.request.identifier.hasPrefix("iumrah.prayer.") else { return }
        await MainActor.run {
            PushNotificationManager.shared.receiveRemotePayload(response.notification.request.content.userInfo, opened: true)
        }
    }
}
