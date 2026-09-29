import SwiftUI

enum BookingPrimaryPage: Hashable {
    case booking
    case status
}

struct BookingPageSwitcher: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let selection: BookingPrimaryPage
    let onBooking: () -> Void
    let onStatus: () -> Void

    var body: some View {
        Picker(
            localized("Раздел бронирования", "Booking section", "Bron bo‘limi", "Брон бўлими"),
            selection: Binding(
                get: { selection },
                set: { newValue in
                    guard newValue != selection else { return }
                    IumrahHaptics.selection()
                    switch newValue {
                    case .booking: onBooking()
                    case .status: onStatus()
                    }
                }
            )
        ) {
            Text(localized("Бронирование", "Booking", "Bron", "Брон"))
                .tag(BookingPrimaryPage.booking)
            Text(localized("Статус", "Status", "Holat", "Ҳолат"))
                .tag(BookingPrimaryPage.status)
        }
        .pickerStyle(.segmented)
        .accessibilityElement(children: .contain)
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
