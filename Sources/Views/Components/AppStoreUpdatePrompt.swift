import SwiftUI
import StoreKit
import UIKit

private struct IumrahLaunchCompletedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var iumrahLaunchCompleted: Bool {
        get { self[IumrahLaunchCompletedKey.self] }
        set { self[IumrahLaunchCompletedKey.self] = newValue }
    }
}

/// Lives inside RootView so it follows launch readiness, onboarding and the
/// selected language. It never participates in App.init or account restoration.
@MainActor
struct AppStoreUpdatePrompt: ViewModifier {
    let isReady: Bool
    let language: AppSettingsStore.Language
    let colorScheme: ColorScheme?

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("iumrah.update.lastPromptedVersion") private var lastPromptedVersion = ""
    @AppStorage("iumrah.update.lastPromptedAt") private var lastPromptedAt = 0.0
    @State private var nextCheckAt = Date.distantPast
    @State private var pendingUpdate: AppStoreUpdateInfo?
    @State private var presentedUpdate: AppStoreUpdateInfo?

    private var canCheck: Bool { isReady && scenePhase == .active }

    func body(content: Content) -> some View {
        content
            .task(id: canCheck) {
                guard canCheck else { return }
                await checkAndPresentIfNeeded()
            }
            .sheet(item: $presentedUpdate) { update in
                AppStoreUpdateSheet(update: update, language: language) {
                    presentedUpdate = nil
                }
                .preferredColorScheme(colorScheme)
                .onAppear {
                    // Record an actual presentation, not a fetched/pending update.
                    lastPromptedVersion = update.storeVersion
                    lastPromptedAt = Date().timeIntervalSince1970
                }
            }
    }

    private func checkAndPresentIfNeeded() async {
        do {
            // Readiness is an explicit signal from the finished splash; this
            // extra second lets onboarding/navigation animations settle.
            try await Task.sleep(for: .seconds(1))
            try Task.checkCancellation()
            guard presentedUpdate == nil else { return }

            if Date() >= nextCheckAt {
                let country = AppStoreCountryCodes.lookupCountry(
                    storefrontCountry: SKPaymentQueue.default().storefront?.countryCode,
                    deviceCountry: Locale.autoupdatingCurrent.region?.identifier
                )
                let update = try await AppStoreUpdateChecker.fetchAvailableUpdate(countryCode: country)
                try Task.checkCancellation()
                pendingUpdate = update
                // Every cold launch checks; subsequent foregrounds use a 6h cache.
                nextCheckAt = Date().addingTimeInterval(6 * 60 * 60)
            }

            guard let update = pendingUpdate,
                  AppStoreUpdateReminder.shouldPresent(
                    version: update.storeVersion,
                    lastVersion: lastPromptedVersion,
                    lastShownAt: lastPromptedAt
                  ) else { return }

            // An update must not compete with login, payment, permissions or an
            // existing sheet. The task is cancelled when backgrounded/not ready.
            while !hasUnobstructedWindow {
                try await Task.sleep(for: .milliseconds(500))
                try Task.checkCancellation()
            }
            try Task.checkCancellation()
            guard canCheck, presentedUpdate == nil else { return }
            presentedUpdate = update
        } catch {
            guard !Task.isCancelled else { return }
            // Offline, timeout and malformed responses are silent, retryable
            // failures. They never block launch or mark a version as shown.
            pendingUpdate = nil
            nextCheckAt = Date().addingTimeInterval(60)
        }
    }

    private var hasUnobstructedWindow: Bool {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
        guard let root = windows.first(where: { $0.isKeyWindow })?.rootViewController,
              root.viewIfLoaded?.window != nil else { return false }
        return !isPresentingModal(root)
    }

    private func isPresentingModal(_ controller: UIViewController) -> Bool {
        if controller.presentedViewController != nil
            || controller.isBeingPresented || controller.isBeingDismissed { return true }
        return controller.children.contains { isPresentingModal($0) }
    }
}
