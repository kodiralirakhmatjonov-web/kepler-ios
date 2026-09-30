import SwiftUI

@main
struct IumrahApp: App {
    @UIApplicationDelegateAdaptor(IumrahAppDelegate.self) private var appDelegate
    @State private var availableUpdate: AppStoreUpdateInfo?
    @State private var didScheduleUpdateCheck = false

    init() {
        // Keychain may survive an uninstall. Establish the installation boundary
        // before RootView creates BookingStore / IumrahAccountStore so stale
        // sessions can never be loaded into memory after a reinstall.
        AppInstallationLifecycle.prepare()
    }

    var body: some Scene {
        WindowGroup {
            IumrahLaunchExperience {
                RootView()
            }
            .task {
                await IumrahPlusStore.shared.start()
            }
            .task {
                guard !didScheduleUpdateCheck else { return }
                didScheduleUpdateCheck = true

                // Update discovery is deliberately outside the critical launch path.
                // Give the root UI time to become fully interactive first.
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                availableUpdate = await AppStoreUpdateChecker.fetchAvailableUpdate()
            }
            .sheet(item: $availableUpdate) { update in
                AppStoreUpdateSheet(update: update) {
                    availableUpdate = nil
                }
            }
        }
    }
}
