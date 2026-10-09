import SwiftUI
import Foundation

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("iumrah.hasCompletedOnboarding.cinematic.v4") private var hasCompletedOnboarding = false
    @StateObject private var settings = AppSettingsStore()
    @ObservedObject var chrome: AppChromeStore
    @StateObject private var journey = JourneyStore()
    @StateObject private var bookings = BookingStore()
    @StateObject private var account = IumrahAccountStore()
    @StateObject private var hotelStorefront = HotelStorefrontStore()
    @ObservedObject private var push = PushNotificationManager.shared
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared
    @State private var hasBootstrappedAfterOnboarding = false

    var body: some View {
        IumrahAdaptiveLayoutHost {
            rootContent
        }
            .preferredColorScheme(settings.appearance.colorScheme)
            .environment(\.locale, Locale(identifier: settings.language.localeIdentifier))
            .environmentObject(settings)
            .environmentObject(chrome)
            .environmentObject(journey)
            .environmentObject(bookings)
            .environmentObject(account)
            .environmentObject(hotelStorefront)
            .onChange(of: chrome.requestedTab) { _, newValue in
                guard let newValue else { return }
                chrome.currentTab = newValue
                chrome.requestedTab = nil
            }
            .task {
                // Keep the first rendered app frame cheap and deterministic. Heavy
                // catalogue/network work is owned by the destination that needs it
                // (Home/Hotels) instead of starting underneath the splash.
                guard hasCompletedOnboarding else { return }
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }

                await bootstrapAfterOnboardingIfNeeded()
                syncWidgets()
                await push.ensureAuthorizationForClientNotifications()
                await syncPushSubscriptions()
                await syncClientNotifications()
                handleOpenedPushIfNeeded()
            }
            .onChange(of: push.deviceToken) { _, _ in
                guard hasCompletedOnboarding else { return }
                Task {
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                }
            }
            .onChange(of: bookings.sessions) { _, _ in
                syncWidgets()
                Task {
                    await linkLocalBookingsToAccount()
                    guard hasCompletedOnboarding else { return }
                    await push.ensureAuthorizationForClientNotifications()
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                }
            }
            .onChange(of: account.account) { _, newAccount in
                bookings.setAccountToken(account.bearerToken)
                syncLocalProfileFromAccount()
                syncWidgets()
                Task { await syncClientNotifications() }
                guard newAccount != nil, let token = account.bearerToken else { return }
                Task {
                    await bookings.restoreAccountTrips(token: token)
                    await linkLocalBookingsToAccount()
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                }
            }
            .onChange(of: settings.language.rawValue) { _, _ in
                // Update widget strings and dates on every in-app language change.
                syncWidgets()
                guard hasCompletedOnboarding else { return }
                Task {
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                }
            }
            .onChange(of: hasCompletedOnboarding) { _, completed in
                guard completed else { return }
                Task {
                    await bootstrapAfterOnboardingIfNeeded()
                    syncWidgets()
                    await push.ensureAuthorizationForClientNotifications()
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                    handleOpenedPushIfNeeded()
                }
            }
            .onChange(of: push.eventRevision) { _, _ in
                guard hasCompletedOnboarding else { return }
                Task {
                    await bookings.refreshAll()
                    await clientNotifications.refresh(accountToken: account.bearerToken)
                    if let bookingID = push.lastEvent?.bookingID,
                       push.lastEvent?.type.hasPrefix("chat_") == true {
                        _ = try? await bookings.loadChat(for: bookingID)
                    }
                }
            }
            .onChange(of: push.openRevision) { _, _ in
                guard hasCompletedOnboarding else { return }
                handleOpenedPushIfNeeded()
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                handleDeepLink(url)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, hasCompletedOnboarding else { return }
                syncWidgets()
                Task {
                    await push.refreshAndRegisterIfAllowed()
                    // Retry booking-scoped chat push registration whenever the app
                    // returns to foreground. Previously a transient registration
                    // failure could remain silent until another unrelated state change.
                    await syncPushSubscriptions()
                    await syncClientNotifications()
                }
            }
    }

    @MainActor
    private func handleDeepLink(_ url: URL) {
        if url.scheme?.lowercased() == "iumrah",
           url.host?.lowercased() == "widget" {
            let components = url.pathComponents.filter { $0 != "/" }
            guard let destination = components.first?.lowercased() else { return }

            switch destination {
            case "booking":
                guard components.count >= 2 else { return }
                let bookingID = components[1].removingPercentEncoding ?? components[1]
                guard !bookingID.isEmpty else { return }
                chrome.openBooking(id: bookingID)
            case "planned":
                chrome.openUmrahPlan()
            case "account":
                chrome.navigate(to: .account)
            default:
                break
            }
            return
        }

        let hotelID: String?

        if url.scheme?.lowercased() == "https",
           url.host?.lowercased() == "iumrah.app" {
            let components = url.pathComponents.filter { $0 != "/" }
            if components.count == 3,
               components[0] == "flights",
               components[1] == "package",
               components[2].range(of: "^\\d{10}$", options: .regularExpression) != nil {
                chrome.openPackage(id: components[2])
                return
            }
            guard components.count == 2 else { return }
            let rawValue = components[1].removingPercentEncoding ?? components[1]
            switch components[0] {
            case "h":
                hotelID = HotelStorefrontService.decodePublicHotelToken(rawValue)
            case "hotel":
                hotelID = rawValue
            default:
                hotelID = nil
            }
        } else if url.scheme?.lowercased() == "iumrahapp",
                  url.host?.lowercased() == "hotel" {
            let token = url.pathComponents.filter { $0 != "/" }.first ?? ""
            let rawValue = token.removingPercentEncoding ?? token
            hotelID = HotelStorefrontService.decodePublicHotelToken(rawValue)
        } else {
            hotelID = nil
        }

        guard let hotelID,
              !hotelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var queryValues: [String: String] = [:]
        for item in query {
            guard let value = item.value else { continue }
            queryValues[item.name.lowercased()] = value
        }
        let truthy = { (value: String?) -> Bool in
            ["1", "true", "yes", "on"].contains(value?.lowercased() ?? "")
        }
        let openConfigurator = truthy(queryValues["configurator"])

        let configuratorDeepLink: HotelConfiguratorDeepLink?
        if openConfigurator {
            let hasMealSnapshot = queryValues["makkah_lunch"] != nil
                || queryValues["makkah_dinner"] != nil
                || queryValues["madinah_dinner"] != nil
            let meals = hasMealSnapshot
                ? PackageMealSelection(
                    makkahLunch: truthy(queryValues["makkah_lunch"]),
                    makkahDinner: truthy(queryValues["makkah_dinner"]),
                    madinahDinner: truthy(queryValues["madinah_dinner"])
                )
                : nil
            configuratorDeepLink = HotelConfiguratorDeepLink(
                hotelID: hotelID,
                adults: queryValues["adults"].flatMap { Int($0) },
                children: queryValues["children"].flatMap { Int($0) },
                infants: queryValues["infants"].flatMap { Int($0) },
                rooms: queryValues["rooms"].flatMap { Int($0) },
                scope: queryValues["scope"].flatMap { JourneyScope(rawValue: $0) },
                firstSaudiCity: queryValues["first_city"].map { $0.uppercased() }.flatMap { SaudiArrivalAirport(rawValue: $0) },
                mealSelection: meals,
                outboundOptionID: queryValues["outbound"],
                inboundOptionID: queryValues["inbound"]
            )
        } else {
            configuratorDeepLink = nil
        }

        chrome.openHotel(
            id: hotelID,
            openConfigurator: openConfigurator,
            configuratorDeepLink: configuratorDeepLink
        )
    }

    @MainActor
    private func syncWidgets() {
        IumrahWidgetSyncService.sync(
            bookings: bookings.sessions,
            account: account.account,
            plannedTrip: UmrahPlanStore.shared.trip,
            languageCode: settings.language.rawValue
        )
    }

    @MainActor
    private func bootstrapAfterOnboardingIfNeeded() async {
        guard !hasBootstrappedAfterOnboarding else { return }
        hasBootstrappedAfterOnboarding = true

        // Keep the cinematic first launch independent from account/network restoration.
        // This prevents stale sessions or slow network calls from competing with the intro.
        await account.restore()
        syncLocalProfileFromAccount()
        bookings.setAccountToken(account.bearerToken)

        if let token = account.bearerToken {
            await bookings.restoreAccountTrips(token: token)
            await linkLocalBookingsToAccount()
        }

        await bookings.refreshAll()
    }

    @MainActor
    private func syncPushSubscriptions() async {
        guard let token = push.deviceToken, !token.isEmpty else { return }
        await bookings.syncPushSubscriptions(deviceToken: token, locale: settings.language.rawValue)
    }

    @MainActor
    private func syncClientNotifications() async {
        await clientNotifications.sync(
            deviceToken: push.deviceToken,
            accountToken: account.bearerToken,
            hasTrip: !bookings.sessions.isEmpty,
            locale: settings.language.rawValue
        )
    }

    @MainActor
    private func handleOpenedPushIfNeeded() {
        guard let event = push.lastOpenedEvent else { return }
        if event.type == "system_notification" {
            routeNotification(destination: event.destination, bookingID: event.destinationBookingID)
            if let id = event.notificationID, let notification = clientNotifications.notification(id: id) {
                Task { await clientNotifications.markOpened(notification, accountToken: account.bearerToken) }
            }
            return
        }
        if let bookingID = event.bookingID {
            if event.type.hasPrefix("chat_") {
                chrome.navigate(to: .care)
            } else {
                chrome.openBooking(id: bookingID)
            }
        }
    }

    @MainActor
    private func routeNotification(destination: String?, bookingID: String?) {
        switch destination {
        case "hotels": chrome.navigate(to: .hotels)
        case "bookings": chrome.navigate(to: .booking)
        case "care": chrome.navigate(to: .care)
        case "account": chrome.navigate(to: .account)
        case "booking":
            if let bookingID, bookings.booking(id: bookingID) != nil { chrome.openBooking(id: bookingID) }
            else { chrome.navigate(to: .booking) }
        default: chrome.navigate(to: .home)
        }
    }

    @MainActor
    private func linkLocalBookingsToAccount() async {
        guard account.isAuthenticated else { return }
        for session in bookings.sessions {
            let bookingToken = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bookingToken.isEmpty else { continue }
            if let linked = try? await account.linkBooking(bookingID: session.id, bookingToken: bookingToken) {
                bookings.applyCanonicalLink(linked, to: session.id)
            }
        }
    }

    @MainActor
    private func syncLocalProfileFromAccount() {
        guard let profile = account.account else { return }
        if settings.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.firstName = profile.firstName
        }
        if settings.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.lastName = profile.lastName
        }
        if settings.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.phone = profile.phone
        }
        if settings.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.email = profile.email
        }
        if settings.telegram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.telegram = profile.telegram
        }
        if settings.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.whatsapp = profile.whatsapp.isEmpty ? profile.phone : profile.whatsapp
        }
    }


    private var rootContent: some View {
        Group {
            if hasCompletedOnboarding {
                IumrahAdaptiveAppShell {
                    tabs
                } detail: { tab in
                    selectedTabScreen(for: tab)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                OnboardingFlowView {
                    withAnimation(.easeInOut(duration: 0.34)) {
                        hasCompletedOnboarding = true
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.015)))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: hasCompletedOnboarding)
    }

    private var tabs: some View {
        TabView(selection: $chrome.currentTab) {
            tabScreen(for: .home) { HomeDashboardView() }
                .tabItem { Label(L10n.text("tab_home", settings.language), systemImage: "house") }
                .tag(AppTab.home)

            tabScreen(for: .hotels) { HotelsHomeView() }
                .tabItem { Label(L10n.text("tab_hotels", settings.language), systemImage: "building.2") }
                .tag(AppTab.hotels)

            tabScreen(for: .booking) { BookingsHomeView() }
                .tabItem { Label(L10n.text("tab_booking", settings.language), systemImage: "suitcase") }
                .tag(AppTab.booking)

            tabScreen(for: .care) { CareHomeView() }
                .tabItem { Label(L10n.text("tab_care", settings.language), systemImage: "heart.fill") }
                .tag(AppTab.care)

            tabScreen(for: .account) { IumrahAccountView() }
                .tabItem { Label(settings.language == .indonesian ? "Akun saya" : (settings.language == .turkish ? "Hesabım" : "Account"), systemImage: "person.crop.circle") }
                .tag(AppTab.account)
        }
        // Navigation chrome uses one restrained app accent; content icons carry
        // the richer semantic palette. This keeps the native tab bar adult and legible.
        .tint(IumrahIconRole.umrah.color)
        .toolbar((chrome.isImmersiveMode || chrome.isInternalNavigationActive) ? .hidden : .visible, for: .tabBar)
    }

    @ViewBuilder
    private func selectedTabScreen(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            tabScreen(for: .home) { HomeDashboardView() }
        case .hotels:
            tabScreen(for: .hotels) { HotelsHomeView() }
        case .booking:
            tabScreen(for: .booking) { BookingsHomeView() }
        case .care:
            tabScreen(for: .care) { CareHomeView() }
        case .account:
            tabScreen(for: .account) { IumrahAccountView() }
        }
    }

    private func tabScreen<Content: View>(for tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        AppNavigationContainer(tab: tab) { content() }
    }
}
