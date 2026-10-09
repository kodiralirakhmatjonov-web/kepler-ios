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
    @AppStorage("iumrah.language") private var languageRaw = "uz"

    private func localized(_ english: String) -> String {
        languageRaw == "tr" ? TurkishLocalization.phrase(english) : english
    }

    var body: some Commands {
        CommandMenu(localized("Navigate")) {
            Button(localized("Home")) { chrome.navigate(to: .home) }
                .keyboardShortcut("1", modifiers: .command)
            Button(localized("Hotels")) { chrome.navigate(to: .hotels) }
                .keyboardShortcut("2", modifiers: .command)
            Button(localized("Trips")) { chrome.navigate(to: .booking) }
                .keyboardShortcut("3", modifiers: .command)
            Button(localized("Care")) { chrome.navigate(to: .care) }
                .keyboardShortcut("4", modifiers: .command)
            Button(localized("Account")) { chrome.navigate(to: .account) }
                .keyboardShortcut("5", modifiers: .command)

            Divider()

            Button(localized("Notifications")) { chrome.openNotifications() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
