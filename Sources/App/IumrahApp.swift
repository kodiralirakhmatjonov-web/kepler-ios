import SwiftUI

@main
struct IumrahApp: App {
    @UIApplicationDelegateAdaptor(IumrahAppDelegate.self) private var appDelegate
    @StateObject private var appStoreUpdateService = AppStoreUpdateService()

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
                await appStoreUpdateService.checkIfNeeded()
            }
            .sheet(item: Binding(
                get: { appStoreUpdateService.availableUpdate },
                set: { if $0 == nil { appStoreUpdateService.dismiss() } }
            )) { update in
                AppStoreUpdateSheet(update: update) {
                    appStoreUpdateService.dismiss()
                }
            }
        }
    }
}
