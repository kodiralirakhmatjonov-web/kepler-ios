import SwiftUI

struct SidebarDrawerHost<Content: View>: View {
    @EnvironmentObject private var chrome: AppChromeStore
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                content
                    .allowsHitTesting(!chrome.isSidebarOpen)
                    .scaleEffect(chrome.isSidebarOpen ? 0.985 : 1, anchor: .trailing)

                if chrome.isSidebarOpen {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { chrome.closeSidebar() }
                }

                SidebarDrawerView()
                    .frame(width: min(proxy.size.width * 0.74, 360))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .offset(x: chrome.isSidebarOpen ? 0 : -min(proxy.size.width * 0.78, 380))
                    .shadow(color: .black.opacity(chrome.isSidebarOpen ? 0.22 : 0), radius: 30, x: 12)
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: chrome.isSidebarOpen)
        }
    }
}

struct SidebarDrawerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(wordmarkAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 42, alignment: .leading)
                    .accessibilityLabel("iumrah")
                Spacer()
                Button { chrome.closeSidebar() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 38, height: 38)
                        .iumrahGlass(in: Circle(), interactive: true, chrome: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)

            Text(copy(.subtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            VStack(spacing: 8) {
                drawerRow(icon: "house.fill", title: copy(.home)) { go(.home) }
                drawerRow(icon: "suitcase.fill", title: copy(.bookings)) { go(.booking) }
                drawerRow(icon: "heart.fill", title: "iumrah Care") { go(.care) }
                drawerRow(icon: "person.crop.circle.fill", title: copy(.account)) { go(.account) }
            }
            .padding(.top, 22)

            Button { chrome.presentESIM() } label: {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        IumrahIconBadge(
                            systemName: "simcard.fill",
                            role: .connectivity,
                            tint: .white,
                            size: 52,
                            symbolSize: 22,
                            cornerRadius: 18
                        )

                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("iumrah eSIM")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text(copy(.esimBody))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(copy(.insidePackage))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .foregroundStyle(.white)
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Color.iumrahCareDark, Color.iumrahGraphite], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 18)

            Spacer(minLength: 18)

            Text(copy(.footer))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            Color.iumrahCardBackground.opacity(0.98)
                .ignoresSafeArea()
        }
    }

    private func drawerRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func go(_ tab: AppTab) {
        chrome.closeSidebar()
        chrome.navigate(to: tab)
    }

    private var wordmarkAsset: String {
        colorScheme == .dark ? "HeaderWordmarkDark" : "HeaderWordmarkLight"
    }

    private enum CopyKey { case subtitle, home, bookings, account, esimBody, insidePackage, footer }
    private func copy(_ key: CopyKey) -> String {
        switch (settings.language, key) {
        case (.russian, .subtitle): return "Ваша умра — в одном месте"
        case (.russian, .home): return "Главная"
        case (.russian, .bookings): return "Поездки"
        case (.russian, .account): return "Аккаунт"
        case (.russian, .esimBody): return "Активация и остаток интернета прямо в приложении."
        case (.russian, .insidePackage): return "В СОСТАВЕ ПАКЕТА"
        case (.russian, .footer): return "Independent Umrah · iumrah"
        case (.turkish, .subtitle): return TurkishLocalization.phrase("Your Umrah in one place")
        case (.indonesian, .subtitle), (.malay, .subtitle), (.english, .subtitle): return "Your Umrah in one place"
        case (.turkish, .home): return TurkishLocalization.phrase("Home")
        case (.indonesian, .home), (.malay, .home), (.english, .home): return "Home"
        case (.turkish, .bookings): return TurkishLocalization.phrase("Trips")
        case (.indonesian, .bookings), (.malay, .bookings), (.english, .bookings): return "Trips"
        case (.turkish, .account): return TurkishLocalization.phrase("Account")
        case (.indonesian, .account), (.malay, .account), (.english, .account): return "Account"
        case (.turkish, .esimBody): return TurkishLocalization.phrase("Activation and data balance directly in the app.")
        case (.indonesian, .esimBody), (.malay, .esimBody), (.english, .esimBody): return "Activation and data balance directly in the app."
        case (.turkish, .insidePackage): return TurkishLocalization.phrase("INCLUDED WITH PACKAGE")
        case (.indonesian, .insidePackage), (.malay, .insidePackage), (.english, .insidePackage): return "INCLUDED WITH PACKAGE"
        case (.turkish, .footer): return TurkishLocalization.phrase("Independent Umrah · iumrah")
        case (.indonesian, .footer), (.malay, .footer), (.english, .footer): return "Independent Umrah · iumrah"
        case (.uzbek, .subtitle): return "Umrangiz — bir joyda"
        case (.uzbek, .home): return "Bosh sahifa"
        case (.uzbek, .bookings): return "Safarlar"
        case (.uzbek, .account): return "Akkaunt"
        case (.uzbek, .esimBody): return "Faollashtirish va internet qoldig‘i ilovaning o‘zida."
        case (.uzbek, .insidePackage): return "PAKET TARKIBIDA"
        case (.uzbek, .footer): return "Independent Umrah · iumrah"
        case (.uzbekCyrillic, .subtitle): return "Умрангиз — бир жойда"
        case (.uzbekCyrillic, .home): return "Бош саҳифа"
        case (.uzbekCyrillic, .bookings): return "Сафарлар"
        case (.uzbekCyrillic, .account): return "Аккаунт"
        case (.uzbekCyrillic, .esimBody): return "Фаоллаштириш ва интернет қолдиғи илованинг ўзида."
        case (.uzbekCyrillic, .insidePackage): return "ПАКЕТ ТАРКИБИДА"
        case (.uzbekCyrillic, .footer): return "Independent Umrah · iumrah"
        }
    }
}
