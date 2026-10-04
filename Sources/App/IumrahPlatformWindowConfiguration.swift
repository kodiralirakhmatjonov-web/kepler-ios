import SwiftUI
import UIKit

/// Catalyst-only window policy. iPhone and iPad receive an EmptyView so their
/// scene behavior remains exactly system-managed.
struct IumrahPlatformWindowConfiguration: View {
    var body: some View {
        #if targetEnvironment(macCatalyst)
        IumrahMacCatalystWindowConfigurator()
            .frame(width: 0, height: 0)
        #else
        EmptyView()
        #endif
    }
}

#if targetEnvironment(macCatalyst)
private struct IumrahMacCatalystWindowConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        WindowPolicyViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class WindowPolicyViewController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyWindowPolicy()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyWindowPolicy()
        }

        private func applyWindowPolicy() {
            guard let restrictions = view.window?.windowScene?.sizeRestrictions else { return }
            restrictions.minimumSize = CGSize(width: 900, height: 640)
        }
    }
}
#endif

/// Top-level navigation shortcuts. On Mac they appear in the menu bar; on
/// iPadOS SwiftUI exposes the keyboard shortcuts as system key commands.
struct IumrahNavigationCommands: Commands {
    @ObservedObject var chrome: AppChromeStore

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Home") { chrome.navigate(to: .home) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Hotels") { chrome.navigate(to: .hotels) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Trips") { chrome.navigate(to: .booking) }
                .keyboardShortcut("3", modifiers: .command)
            Button("Care") { chrome.navigate(to: .care) }
                .keyboardShortcut("4", modifiers: .command)
            Button("Account") { chrome.navigate(to: .account) }
                .keyboardShortcut("5", modifiers: .command)

            Divider()

            Button("Notifications") { chrome.openNotifications() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
