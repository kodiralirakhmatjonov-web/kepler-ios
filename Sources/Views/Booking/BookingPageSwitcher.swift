import SwiftUI

enum BookingPrimaryPage: Hashable {
    case booking
    case status
    case schedule
}

struct BookingPageSwitcher: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let selection: BookingPrimaryPage
    let onBooking: () -> Void
    let onStatus: () -> Void
    var onSchedule: () -> Void = {}

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
                    case .schedule: onSchedule()
                    }
                }
            )
        ) {
            Text(localized("Бронирование", "Booking", "Bron", "Брон"))
                .tag(BookingPrimaryPage.booking)
            Text(localized("Статус", "Status", "Holat", "Ҳолат"))
                .tag(BookingPrimaryPage.status)
            Text(localized("Расписание", "Schedule", "Jadval", "Жадвал"))
                .tag(BookingPrimaryPage.schedule)
        }
        .pickerStyle(.segmented)
        .accessibilityElement(children: .contain)
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .turkish: return TurkishLocalization.phrase(en)
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
