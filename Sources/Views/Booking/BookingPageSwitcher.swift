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
        IumrahGlassGroup(spacing: 6) {
            HStack(spacing: 4) {
                segment(
                    title: localized("Бронирование", "Booking", "Bron", "Брон"),
                    symbol: "rectangle.stack.fill",
                    selected: selection == .booking,
                    action: onBooking
                )
                segment(
                    title: localized("Статус", "Status", "Holat", "Ҳолат"),
                    symbol: "checkmark.circle.fill",
                    selected: selection == .status,
                    action: onStatus
                )
                segment(
                    title: localized("Расписание", "Schedule", "Jadval", "Жадвал"),
                    symbol: "calendar.badge.clock",
                    selected: selection == .schedule,
                    action: onSchedule
                )
            }
        }
        .padding(5)
        .iumrahGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            interactive: false,
            allowsStaticGlass: true,
            chrome: true
        )
        .accessibilityElement(children: .contain)
    }

    private func segment(
        title: String,
        symbol: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !selected else { return }
            IumrahHaptics.selection()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: 17, style: .continuous),
                interactive: true,
                tint: selected ? Color.white.opacity(0.26) : nil,
                allowsStaticGlass: true,
                chrome: true
            )
        }
        .buttonStyle(.plain)
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
