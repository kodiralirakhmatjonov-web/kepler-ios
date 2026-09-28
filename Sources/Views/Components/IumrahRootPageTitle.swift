import SwiftUI

struct IumrahRootPageTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared

    let title: String
    var showsMakkahTime = false
    var lightStyle = false
    var usesBrandLogo = false
    var brandScale: CGFloat = 1.0
    var showsConnectivityStatus = false

    var body: some View {
        HStack(alignment: .top, spacing: showsConnectivityStatus ? 10 : 14) {
            Group {
                if usesBrandLogo {
                    Image(wordmarkAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: brandFrameWidth, height: 46 * brandScale, alignment: .leading)
                        .accessibilityLabel("Iumrah")
                } else {
                    Text(title)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1.0)
                        .foregroundStyle(lightStyle ? Color.white : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Spacer(minLength: showsConnectivityStatus ? 4 : 8)

            if showsConnectivityStatus {
                IumrahAnimatedConnectivityIndicator(lightStyle: lightStyle)
                    .padding(.top, 6)
            }

            VStack(alignment: .trailing, spacing: showsMakkahTime ? 8 : 0) {
                HStack(spacing: 10) {
                    notificationButton
                    menuButton
                }

                if showsMakkahTime {
                    MakkahClockView(lightStyle: lightStyle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notificationButton: some View {
        Button {
            chrome.openNotifications()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: clientNotifications.unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(lightStyle ? Color.white : Color.primary)
                    .frame(width: 46, height: 46)
                    .contentShape(Circle())
                    .iumrahGlass(
                        in: Circle(),
                        interactive: true,
                        tint: lightStyle ? Color.black.opacity(0.18) : nil,
                        chrome: true
                    )

                if clientNotifications.unreadCount > 0 {
                    unreadDot
                        .offset(x: -3, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(notificationAccessibilityLabel)
    }

    private var menuButton: some View {
        Button {
            chrome.openSidebar()
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(lightStyle ? Color.white : Color.primary)
                .frame(width: 46, height: 46)
                .contentShape(Circle())
                .iumrahGlass(
                    in: Circle(),
                    interactive: true,
                    tint: lightStyle ? Color.black.opacity(0.18) : nil,
                    chrome: true
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(menuAccessibilityLabel)
    }

    private var unreadDot: some View {
        Text(clientNotifications.unreadCount > 9 ? "9+" : "\(clientNotifications.unreadCount)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, clientNotifications.unreadCount > 9 ? 5 : 0)
            .frame(minWidth: 16, minHeight: 16)
            .background(Color.red, in: Capsule())
            .overlay {
                Capsule().stroke(Color.white.opacity(0.95), lineWidth: 1)
            }
    }

    private var notificationAccessibilityLabel: String {
        switch settings.language {
        case .russian: return "Уведомления"
        case .english: return "Notifications"
        case .uzbek: return "Bildirishnomalar"
        case .uzbekCyrillic: return "Билдиришномалар"
        }
    }

    private var menuAccessibilityLabel: String {
        switch settings.language {
        case .russian: return "Меню"
        case .english: return "Menu"
        case .uzbek: return "Menyu"
        case .uzbekCyrillic: return "Меню"
        }
    }

    private var brandFrameWidth: CGFloat {
        showsConnectivityStatus ? 140 : 180 * brandScale
    }

    private var wordmarkAsset: String {
        if lightStyle { return "HeaderWordmarkDark" }
        return colorScheme == .dark ? "HeaderWordmarkDark" : "HeaderWordmarkLight"
    }
}

struct MakkahClockView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    var lightStyle = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .trailing, spacing: 1) {
                Text(L10n.text("makkah_time", settings.language))
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(timeString(context.date))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(lightStyle ? Color.white.opacity(0.96) : Color.secondary)
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Riyadh")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
