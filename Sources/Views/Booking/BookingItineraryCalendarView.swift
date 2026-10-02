import Foundation
import SwiftUI

struct BookingItineraryCalendarView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    let bookingID: String
    let startDate: String
    let endDate: String
    let booking: RemoteBooking

    @State private var selectedDay: String?
    @State private var loading = true
    @State private var errorText: String?

    private var serverItems: [BookingItineraryItem] {
        bookings.itineraries[bookingID] ?? []
    }

    /// A legacy operational itinerary can contain every event on a single day.
    /// When that happens, use the package-aware baseline generated from the exact
    /// hotel stay dates and arrival city instead of presenting a broken schedule.
    private var items: [BookingItineraryItem] {
        if serverItems.contains(where: { $0.timeLocal != nil }) {
            return serverItems
        }
        let distinctServerDays = Set(serverItems.map(\.dateLocal)).count
        let tripDayCount = Self.dayRange(from: startDate, through: endDate).count
        let minimumUsefulDays = min(3, max(2, tripDayCount - 1))
        if distinctServerDays >= minimumUsefulDays {
            return serverItems
        }
        return BookingItineraryPlanner.make(booking: booking, language: settings.language)
    }

    private var days: [String] {
        let range = Self.dayRange(from: startDate, through: endDate)
        if !range.isEmpty { return range }
        return Array(Set(items.map(\.dateLocal))).sorted()
    }

    private var effectiveDay: String? {
        if let selectedDay, days.contains(selectedDay) { return selectedDay }
        return days.first
    }

    private var selectedItems: [BookingItineraryItem] {
        guard let day = effectiveDay else { return [] }
        return items.filter { $0.dateLocal == day }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                IumrahIconBadge(
                    systemName: "calendar.badge.clock",
                    role: .calendar,
                    size: 42,
                    symbolSize: 18,
                    shape: .circle
                )
            }

            if !days.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(days, id: \.self) { day in
                            dayChip(day)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            if loading && items.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(loadingText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
            } else if let errorText, items.isEmpty {
                Text(errorText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            } else if selectedItems.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(selectedItems) { item in
                        eventRow(item)
                    }
                }
            }
        }
        .padding(19)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
        .task(id: bookingID) {
            if selectedDay == nil { selectedDay = days.first }
            loading = true
            do {
                _ = try await bookings.loadItinerary(for: bookingID, language: settings.language)
                errorText = nil
                if selectedDay == nil { selectedDay = days.first }
            } catch {
                errorText = L10n.error(error, settings.language)
            }
            loading = false
        }
        .onChange(of: days) { _, newDays in
            if selectedDay == nil || !newDays.contains(selectedDay ?? "") {
                selectedDay = newDays.first
            }
        }
    }

    private func dayChip(_ day: String) -> some View {
        let selected = effectiveDay == day
        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                selectedDay = day
            }
            IumrahHaptics.selection()
        } label: {
            VStack(spacing: 3) {
                Text(Self.dayNumber(day))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(Self.weekday(day, locale: settings.language.localeIdentifier))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selected ? Color.white.opacity(0.78) : Color.secondary)
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(width: 58, height: 64)
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: 19, style: .continuous),
                interactive: true,
                tint: selected ? Color.primary.opacity(0.78) : nil
            )
        }
        .buttonStyle(.plain)
    }

    private func eventRow(_ item: BookingItineraryItem) -> some View {
        HStack(alignment: .top, spacing: 11) {
            if let time = item.timeLocal, !time.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(time)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    if let end = item.endTimeLocal, !end.isEmpty, end != time {
                        Text(end)
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 43, alignment: .leading)
                .padding(.top, 2)
            }

            IumrahIconBadge(
                systemName: safeIcon(item.icon),
                size: 40,
                symbolSize: 16,
                cornerRadius: 14
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                if !item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 5) {
                        IumrahInlineIcon(systemName: "mappin", role: .location, size: 10)
                        Text(item.location)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.iumrahRaisedBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func safeIcon(_ value: String) -> String {
        let icon = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return icon.isEmpty ? "calendar" : icon
    }

    private var title: String {
        switch settings.language {
        case .russian: return "Расписание поездки"
        case .english: return "Trip schedule"
        case .uzbek: return "Safar jadvali"
        case .uzbekCyrillic: return "Сафар жадвали"
        }
    }

    private var subtitle: String {
        switch settings.language {
        case .russian: return "По времени — прилёт, отели, Умра, зияраты и трансферы"
        case .english: return "Timed arrival, hotels, Umrah, visits and transfers"
        case .uzbek: return "Vaqt bo‘yicha parvoz, mehmonxona, Umra va transferlar"
        case .uzbekCyrillic: return "Вақт бўйича парвоз, меҳмонхона, Умра ва трансферлар"
        }
    }

    private var loadingText: String {
        switch settings.language {
        case .russian: return "Загружаем расписание…"
        case .english: return "Loading schedule…"
        case .uzbek: return "Jadval yuklanmoqda…"
        case .uzbekCyrillic: return "Жадвал юкланмоқда…"
        }
    }

    private var emptyText: String {
        switch settings.language {
        case .russian: return "На этот день пока нет запланированных событий."
        case .english: return "No scheduled events for this day yet."
        case .uzbek: return "Bu kun uchun hali rejalashtirilgan tadbir yo‘q."
        case .uzbekCyrillic: return "Бу кун учун ҳали режалаштирилган тадбир йўқ."
        }
    }

    private static func dayRange(from start: String, through end: String) -> [String] {
        guard let startDate = parser.date(from: start), let endDate = parser.date(from: end), startDate <= endDate else { return [] }
        var output: [String] = []
        var cursor = startDate
        let calendar = Calendar(identifier: .gregorian)
        while cursor <= endDate && output.count < 40 {
            output.append(parser.string(from: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return output
    }

    private static func dayNumber(_ day: String) -> String {
        guard let date = parser.date(from: day) else { return day }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }

    private static func weekday(_ day: String, locale: String) -> String {
        guard let date = parser.date(from: day) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.dateFormat = "EE"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
