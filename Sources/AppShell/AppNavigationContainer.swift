import SwiftUI

struct AppNavigationContainer<Content: View>: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore

    let tab: AppTab?
    let content: Content

    init(tab: AppTab? = nil, @ViewBuilder content: () -> Content) {
        self.tab = tab
        self.content = content()
    }

    private var isESIMDestinationActive: Binding<Bool> {
        Binding(
            get: { chrome.isESIMPresented && (tab == nil || chrome.currentTab == tab) },
            set: { newValue in
                if !newValue { chrome.isESIMPresented = false }
            }
        )
    }

    private var isNotificationsDestinationActive: Binding<Bool> {
        Binding(
            get: { chrome.isNotificationsPresented && (tab == nil || chrome.currentTab == tab) },
            set: { newValue in
                if !newValue { chrome.isNotificationsPresented = false }
            }
        )
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .background(Color.iumrahPageBackground.ignoresSafeArea())
                .navigationDestination(isPresented: isESIMDestinationActive) {
                    ESIMView()
                        .environmentObject(settings)
                        .environmentObject(chrome)
                        .environmentObject(bookings)
                }
                .navigationDestination(isPresented: isNotificationsDestinationActive) {
                    AccountNotificationsView()
                }
        }
    }
}
