import SwiftUI

struct IumrahRootPageTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    let title: String
    var showsMakkahTime = false
    var lightStyle = false
    var usesBrandLogo = false
    var brandScale: CGFloat = 1.0
    var showsConnectivityStatus = false
    var showsSignalButton = false

    @ObservedObject private var notifications = ClientNotificationCenter.shared

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
                HStack(spacing: 8) {
                    if showsSignalButton {
                        NavigationLink {
                            AccountNotificationsView()
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: notifications.unreadCount > 0 ? "bell.fill" : "bell")
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

                                if notifications.unreadCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 9, height: 9)
                                        .overlay(Circle().stroke(lightStyle ? Color.black.opacity(0.24) : Color.iumrahPageBackground, lineWidth: 1.5))
                                        .offset(x: -2, y: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("iumrah Signal")
                    }

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
                    .accessibilityLabel("Menu")
                }

                if showsMakkahTime {
                    MakkahClockView(lightStyle: lightStyle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var brandFrameWidth: CGFloat {
        // The supplied wordmark asset is height-limited, so this narrower frame
        // preserves its visible size while freeing genuine layout space for the
        // compact connectivity control on Home.
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
