import SwiftUI

/// Platform-adaptive app chrome.
///
/// iPhone / narrow iPad windows keep the existing TabView + drawer unchanged.
/// Regular-width iPad and Mac switch to the system NavigationSplitView model so
/// the app behaves like a first-class large-screen application rather than a
/// stretched phone interface.
struct IumrahAdaptiveAppShell<CompactContent: View, DetailContent: View>: View {
    @Environment(\.iumrahAdaptiveLayout) private var layout
    @EnvironmentObject private var chrome: AppChromeStore

    private let compactContent: CompactContent
    private let detailContent: (AppTab) -> DetailContent

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(
        @ViewBuilder compact: () -> CompactContent,
        @ViewBuilder detail: @escaping (AppTab) -> DetailContent
    ) {
        compactContent = compact()
        detailContent = detail
    }

    @ViewBuilder
    var body: some View {
        if layout.usesSidebarNavigation {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                IumrahLargeScreenSidebar()
                    .navigationSplitViewColumnWidth(min: 228, ideal: 268, max: 310)
            } detail: {
                // Re-resolve the layout from the actual detail-column width.
                // A 1024pt iPad window may only leave ~700pt for content once
                // the sidebar is visible; feature grids must react to that
                // real width rather than the outer scene width.
                IumrahAdaptiveLayoutHost {
                    detailContent(chrome.currentTab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.iumrahPageBackground.ignoresSafeArea())
                }
            }
            .navigationSplitViewStyle(.balanced)
            .environment(\.iumrahNavigationChromeStyle, .sidebar)
            .onAppear {
                columnVisibility = chrome.isImmersiveMode ? .detailOnly : .all
            }
            .onChange(of: chrome.isImmersiveMode) { _, immersive in
                withAnimation(.easeInOut(duration: 0.20)) {
                    columnVisibility = immersive ? .detailOnly : .all
                }
            }
        } else {
            SidebarDrawerHost {
                compactContent
            }
            .environment(\.iumrahNavigationChromeStyle, .drawer)
        }
    }
}

private struct IumrahLargeScreenSidebar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared

    var body: some View {
        VStack(spacing: 0) {
            brandHeader

            List {
                Section {
                    sidebarRow(.home)
                    sidebarRow(.hotels)
                    sidebarRow(.booking)
                    sidebarRow(.care)
                    sidebarRow(.account)
                }

                Section(servicesTitle) {
                    Button {
                        chrome.presentESIM()
                    } label: {
                        Label("iumrah eSIM", systemImage: "simcard.fill")
                    }

                    Button {
                        chrome.openNotifications()
                    } label: {
                        HStack {
                            Label(notificationsTitle, systemImage: "bell")
                            Spacer()
                            if clientNotifications.unreadCount > 0 {
                                Text(clientNotifications.unreadCount > 99 ? "99+" : "\(clientNotifications.unreadCount)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .frame(minHeight: 20)
                                    .background(Color.red, in: Capsule())
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            connectionFooter
        }
        .background(Color.iumrahCardBackground)
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            Image(wordmarkAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 142, height: 40, alignment: .leading)
                .accessibilityLabel("iumrah")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func sidebarRow(_ tab: AppTab) -> some View {
        Button {
            guard chrome.currentTab != tab else { return }
            chrome.navigate(to: tab)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                Text(tab.title(for: settings.language))
                    .font(.body.weight(chrome.currentTab == tab ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(chrome.currentTab == tab ? Color.primary.opacity(0.085) : Color.clear)
                .padding(.vertical, 1)
        )
        .accessibilityAddTraits(chrome.currentTab == tab ? .isSelected : [])
    }

    private var connectionFooter: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
            Text(footerTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var wordmarkAsset: String {
        colorScheme == .dark ? "HeaderWordmarkDark" : "HeaderWordmarkLight"
    }

    private var servicesTitle: String {
        switch settings.language {
        case .russian: return "Сервисы"
        case .turkish: return TurkishLocalization.phrase("Services")
        case .indonesian, .malay, .english: return "Services"
        case .uzbek: return "Xizmatlar"
        case .uzbekCyrillic: return "Хизматлар"
        }
    }

    private var notificationsTitle: String {
        switch settings.language {
        case .russian: return "Уведомления"
        case .turkish: return TurkishLocalization.phrase("Notifications")
        case .indonesian, .malay, .english: return "Notifications"
        case .uzbek: return "Bildirishnomalar"
        case .uzbekCyrillic: return "Билдиришномалар"
        }
    }

    private var footerTitle: String {
        switch settings.language {
        case .russian: return "iumrah · онлайн"
        case .turkish: return TurkishLocalization.phrase("iumrah · online")
        case .indonesian, .malay, .english: return "iumrah · online"
        case .uzbek: return "iumrah · onlayn"
        case .uzbekCyrillic: return "iumrah · онлайн"
        }
    }
}

extension AppTab {
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .hotels: return "building.2"
        case .booking: return "suitcase"
        case .care: return "heart.fill"
        case .account: return "person.crop.circle"
        }
    }

    func title(for language: AppSettingsStore.Language) -> String {
        switch self {
        case .home:
            return L10n.text("tab_home", language)
        case .hotels:
            return L10n.text("tab_hotels", language)
        case .booking:
            return L10n.text("tab_booking", language)
        case .care:
            return L10n.text("tab_care", language)
        case .account:
            switch language {
            case .russian: return "Аккаунт"
            case .turkish: return TurkishLocalization.phrase("Account")
            case .indonesian, .malay, .english: return "Account"
            case .uzbek: return "Akkaunt"
            case .uzbekCyrillic: return "Аккаунт"
            }
        }
    }
}
