import Foundation
import SwiftUI

enum BookingItineraryPresentation {
    case preview
    case fullScreen
}

struct BookingItineraryCalendarView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    let bookingID: String
    let startDate: String
    let endDate: String
    let booking: RemoteBooking
    let presentation: BookingItineraryPresentation
    let onOpenFullSchedule: (() -> Void)?

    @State private var selectedDay: String?
    @State private var loading = true
    @State private var errorText: String?

    init(
        bookingID: String,
        startDate: String,
        endDate: String,
        booking: RemoteBooking,
        presentation: BookingItineraryPresentation = .preview,
        onOpenFullSchedule: (() -> Void)? = nil
    ) {
        self.bookingID = bookingID
        self.startDate = startDate
        self.endDate = endDate
        self.booking = booking
        self.presentation = presentation
        self.onOpenFullSchedule = onOpenFullSchedule
    }

    private enum TemporalState {
        case neutral
        case completed
        case active
        case upcoming
    }

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
        return preferredInitialDay(in: days)
    }

    private var selectedItems: [BookingItineraryItem] {
        guard let day = effectiveDay else { return [] }
        return items.filter { $0.dateLocal == day }.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.title < rhs.title
        }
    }

    private var visibleSelectedItems: [BookingItineraryItem] {
        switch presentation {
        case .preview:
            return Array(selectedItems.prefix(4))
        case .fullScreen:
            return selectedItems
        }
    }

    private var selectedDayIsToday: Bool {
        guard let day = effectiveDay else { return false }
        return day == Self.todaySaudiString()
    }

    private var shouldUseDetailedTimeView: Bool {
        selectedDayIsToday && visibleSelectedItems.contains(where: { $0.timeLocal?.isEmpty == false })
    }

    private var bodySpacing: CGFloat {
        presentation == .fullScreen ? 18 : 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: bodySpacing) {
            header

            if presentation == .fullScreen {
                selectedDaySummary
            }

            if !days.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(days, id: \.self) { day in
                            dayChip(day)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            content
        }
        .padding(presentation == .fullScreen ? 20 : 19)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
        .task(id: bookingID) {
            if selectedDay == nil { selectedDay = preferredInitialDay(in: days) }
            loading = true
            do {
                _ = try await bookings.loadItinerary(for: bookingID, language: settings.language)
                errorText = nil
                if selectedDay == nil || !(days.contains(selectedDay ?? "")) {
                    selectedDay = preferredInitialDay(in: days)
                }
            } catch {
                errorText = L10n.error(error, settings.language)
            }
            loading = false
        }
        .onChange(of: days) { _, newDays in
            if selectedDay == nil || !newDays.contains(selectedDay ?? "") {
                selectedDay = preferredInitialDay(in: newDays)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: presentation == .fullScreen ? 27 : 25, weight: .bold, design: .rounded))
                    .tracking(-0.4)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if presentation == .preview, let onOpenFullSchedule {
                Button {
                    IumrahHaptics.selection()
                    onOpenFullSchedule()
                } label: {
                    HStack(spacing: 8) {
                        Text(openButtonTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .iumrahGlass(in: Circle(), interactive: true, allowsStaticGlass: true, chrome: true)
                    }
                }
                .buttonStyle(.plain)
            } else {
                IumrahIconBadge(
                    systemName: "calendar.badge.clock",
                    role: .calendar,
                    size: 44,
                    symbolSize: 18,
                    shape: .circle
                )
            }
        }
    }

    @ViewBuilder
    private var selectedDaySummary: some View {
        if let effectiveDay {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(fullDateTitle(effectiveDay))
                        .font(.subheadline.weight(.bold))
                    Text(selectedDayIsToday ? currentDaySubtitle : ordinaryDaySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if selectedDayIsToday {
                    Text(nowLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Color.primary.opacity(0.78), in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.iumrahRaisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
    }

    @ViewBuilder
    private var content: some View {
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
            VStack(spacing: shouldUseDetailedTimeView ? 14 : 10) {
                ForEach(Array(visibleSelectedItems.enumerated()), id: \.element.id) { index, item in
                    if shouldUseDetailedTimeView {
                        timedTimelineRow(item, index: index, isLast: index == visibleSelectedItems.count - 1)
                    } else {
                        compactEventRow(item)
                    }
                }
            }
        }
    }

    private func dayChip(_ day: String) -> some View {
        let selected = effectiveDay == day
        let today = day == Self.todaySaudiString()
        let width: CGFloat = today && selected ? 68 : 58
        let height: CGFloat = today && selected ? 70 : 64

        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                selectedDay = day
            }
            IumrahHaptics.selection()
        } label: {
            VStack(spacing: 4) {
                Text(Self.dayNumber(day))
                    .font(.system(size: today && selected ? 20 : 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(Self.weekday(day, locale: settings.language.localeIdentifier))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selected ? Color.white.opacity(0.78) : Color.secondary)
                if today {
                    Circle()
                        .fill(selected ? Color.white.opacity(0.88) : Color.blue)
                        .frame(width: 5, height: 5)
                }
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(width: width, height: height)
            .scaleEffect(today && selected ? 1.03 : 1.0)
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: 19, style: .continuous),
                interactive: true,
                tint: selected ? Color.primary.opacity(0.78) : nil
            )
        }
        .buttonStyle(.plain)
    }

    private func compactEventRow(_ item: BookingItineraryItem) -> some View {
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

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                if !item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 5) {
                            IumrahInlineIcon(systemName: "mappin", role: .location, size: 10)
                            Text(item.location)
                        }
                    }
                    if let duration = durationText(for: item) {
                        HStack(spacing: 5) {
                            IumrahInlineIcon(systemName: "clock", role: .calendar, size: 10)
                            Text(duration)
                        }
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.iumrahRaisedBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func timedTimelineRow(_ item: BookingItineraryItem, index: Int, isLast: Bool) -> some View {
        let state = temporalState(for: item)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.timeLocal ?? "—")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                if let end = item.endTimeLocal, !end.isEmpty, end != item.timeLocal {
                    Text(end)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if let duration = durationText(for: item) {
                    Text(duration)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 66, alignment: .leading)
            .padding(.top, 2)

            VStack(spacing: 0) {
                Circle()
                    .fill(stateTint(state))
                    .frame(width: state == .active ? 14 : 11, height: state == .active ? 14 : 11)
                    .overlay {
                        if state == .active {
                            Circle()
                                .strokeBorder(stateTint(state).opacity(0.25), lineWidth: 8)
                                .frame(width: 26, height: 26)
                        }
                    }
                    .padding(.top, 7)

                if !isLast {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 6)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    IumrahIconBadge(
                        systemName: safeIcon(item.icon),
                        tint: stateTint(state),
                        size: 42,
                        symbolSize: 16,
                        cornerRadius: 14
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
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

                    Spacer(minLength: 8)

                    if state != .neutral {
                        Text(stateTitle(state))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(state == .completed ? .secondary : .primary)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(statePillBackground(state), in: Capsule())
                    }
                }

                if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(stateCardBackground(state), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(state == .active ? stateTint(state).opacity(0.22) : Color.primary.opacity(0.04), lineWidth: state == .active ? 1.0 : 0.7)
            }
        }
    }

    private func temporalState(for item: BookingItineraryItem) -> TemporalState {
        guard selectedDayIsToday, let start = localDateTime(day: item.dateLocal, time: item.timeLocal) else {
            return .neutral
        }
        let now = Date()
        let end = localDateTime(day: item.dateLocal, time: item.endTimeLocal) ?? Calendar.current.date(byAdding: .minute, value: 50, to: start)
        if now < start { return .upcoming }
        if now >= start && now <= end { return .active }
        return .completed
    }

    private func localDateTime(day: String, time: String?) -> Date? {
        guard let time, !time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return Self.dateTimeParser.date(from: "\(day)T\(time)")
    }

    private func durationText(for item: BookingItineraryItem) -> String? {
        guard let start = localDateTime(day: item.dateLocal, time: item.timeLocal),
              let end = localDateTime(day: item.dateLocal, time: item.endTimeLocal) else { return nil }
        let minutes = max(1, Int(end.timeIntervalSince(start) / 60))
        return durationLabel(minutes)
    }

    private func durationLabel(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        switch settings.language {
        case .russian:
            if hours > 0 && mins > 0 { return "≈ \(hours) ч \(mins) мин" }
            if hours > 0 { return "≈ \(hours) ч" }
            return "≈ \(mins) мин"
        case .english:
            if hours > 0 && mins > 0 { return "~ \(hours)h \(mins)m" }
            if hours > 0 { return "~ \(hours)h" }
            return "~ \(mins)m"
        case .uzbek:
            if hours > 0 && mins > 0 { return "≈ \(hours) soat \(mins) daq" }
            if hours > 0 { return "≈ \(hours) soat" }
            return "≈ \(mins) daq"
        case .uzbekCyrillic:
            if hours > 0 && mins > 0 { return "≈ \(hours) соат \(mins) дақ" }
            if hours > 0 { return "≈ \(hours) соат" }
            return "≈ \(mins) дақ"
        }
    }

    private func stateTint(_ state: TemporalState) -> Color {
        switch state {
        case .active: return Color.blue
        case .upcoming: return Color.orange
        case .completed: return Color.secondary
        case .neutral: return Color.blue
        }
    }

    private func statePillBackground(_ state: TemporalState) -> Color {
        switch state {
        case .active: return Color.blue.opacity(0.14)
        case .upcoming: return Color.orange.opacity(0.16)
        case .completed: return Color.primary.opacity(0.08)
        case .neutral: return Color.clear
        }
    }

    private func stateCardBackground(_ state: TemporalState) -> Color {
        switch state {
        case .active: return Color.blue.opacity(0.08)
        case .upcoming: return Color.iumrahRaisedBackground.opacity(0.86)
        case .completed, .neutral: return Color.iumrahRaisedBackground.opacity(0.72)
        }
    }

    private func stateTitle(_ state: TemporalState) -> String {
        switch (state, settings.language) {
        case (.active, .russian): return "Сейчас"
        case (.upcoming, .russian): return "Далее"
        case (.completed, .russian): return "Завершено"
        case (.neutral, .russian): return ""

        case (.active, .english): return "Now"
        case (.upcoming, .english): return "Next"
        case (.completed, .english): return "Done"
        case (.neutral, .english): return ""

        case (.active, .uzbek): return "Hozir"
        case (.upcoming, .uzbek): return "Keyin"
        case (.completed, .uzbek): return "Bajarildi"
        case (.neutral, .uzbek): return ""

        case (.active, .uzbekCyrillic): return "Ҳозир"
        case (.upcoming, .uzbekCyrillic): return "Кейин"
        case (.completed, .uzbekCyrillic): return "Бажарилди"
        case (.neutral, .uzbekCyrillic): return ""
        }
    }

    private func safeIcon(_ value: String) -> String {
        let icon = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return icon.isEmpty ? "calendar" : icon
    }

    private func preferredInitialDay(in values: [String]) -> String? {
        guard !values.isEmpty else { return nil }
        let today = Self.todaySaudiString()
        if values.contains(today) { return today }
        return values.first
    }

    private func fullDateTitle(_ day: String) -> String {
        guard let date = Self.parser.date(from: day) else { return day }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.timeZone = Self.saudiTimeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMMM EEEE")
        return formatter.string(from: date)
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
        case .russian: return "По времени — прилёт, контроль, трансферы, отели, Умра и вылет"
        case .english: return "Timed arrival, controls, transfers, hotels, Umrah and departure"
        case .uzbek: return "Vaqt bo‘yicha parvoz, nazorat, transfer, mehmonxona, Umra va jo‘nab ketish"
        case .uzbekCyrillic: return "Вақт бўйича парвоз, назорат, трансфер, меҳмонхона, Умра ва жўнаб кетиш"
        }
    }

    private var openButtonTitle: String {
        switch settings.language {
        case .russian: return "Полностью"
        case .english: return "Full"
        case .uzbek: return "To‘liq"
        case .uzbekCyrillic: return "Тўлиқ"
        }
    }

    private var currentDaySubtitle: String {
        switch settings.language {
        case .russian: return "Текущий день раскрыт по времени и подсвечивает активный этап поездки."
        case .english: return "Today is expanded by time and highlights the current journey stage."
        case .uzbek: return "Bugungi kun vaqt bo‘yicha ochilgan va joriy bosqichni ko‘rsatadi."
        case .uzbekCyrillic: return "Бугунги кун вақт бўйича очилган ва жорий босқични кўрсатади."
        }
    }

    private var ordinaryDaySubtitle: String {
        switch settings.language {
        case .russian: return "Для прошлых и предстоящих дней события показаны как запланированная цепочка."
        case .english: return "Past and upcoming days are shown as a planned chain of events."
        case .uzbek: return "O‘tgan va kelgusi kunlar rejalashtirilgan zanjir sifatida ko‘rsatiladi."
        case .uzbekCyrillic: return "Ўтган ва келгуси кунлар режалаштирилган занжир сифатида кўрсатилади."
        }
    }

    private var nowLabel: String {
        switch settings.language {
        case .russian: return "Сейчас"
        case .english: return "Now"
        case .uzbek: return "Hozir"
        case .uzbekCyrillic: return "Ҳозир"
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
        formatter.timeZone = saudiTimeZone
        return formatter.string(from: date)
    }

    private static func weekday(_ day: String, locale: String) -> String {
        guard let date = parser.date(from: day) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.timeZone = saudiTimeZone
        formatter.dateFormat = "EE"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private static func todaySaudiString() -> String {
        parser.string(from: Date())
    }

    private static let saudiTimeZone = TimeZone(secondsFromGMT: 3 * 3600) ?? .current

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = saudiTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateTimeParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = saudiTimeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()
}
