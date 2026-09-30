import Foundation

enum AppStoreUpdateReminder {
    static func shouldPresent(
        version: String,
        lastVersion: String,
        lastShownAt: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        // A different release is immediately eligible. The same release is
        // suggested at most once a day, including after relaunching the app.
        version != lastVersion || lastShownAt <= 0
            || now.timeIntervalSince1970 - lastShownAt >= 24 * 60 * 60
            || lastShownAt > now.timeIntervalSince1970
    }
}
