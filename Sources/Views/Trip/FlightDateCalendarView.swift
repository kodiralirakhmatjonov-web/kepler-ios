import SwiftUI

struct FlightDateCalendarResult {
    let departure: Date
    let returnDate: Date
    let publishedSelection: CuratedPublishedFlightSelection?
}

struct FlightDateCalendarView: View {
    let trip: TripDraft
    let initialDeparture: Date
    let initialReturn: Date
    let onApply: (FlightDateCalendarResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var departure: Date?
    @State private var returnDate: Date?
    @State private var publishedFlights: [CuratedFlightRecommendation] = []
    @State private var isLoading = false
    @State private var loadError = false
    @State private var showFlexibleWarning = false

    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.firstWeekday = 2
        return value
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                calendarBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        routeSummary
                        directLegend
                        if selectionNeedsFlexibleSearch { flexibleInlineWarning }
                        ForEach(monthStarts, id: \.self) { month in
                            monthSection(month)
                        }
                        directInventoryNote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 136)
                }
                .scrollIndicators(.hidden)

                if showFlexibleWarning { flexibleWarningOverlay }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        IumrahHaptics.selection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(closeLabel)
                }

                ToolbarItem(placement: .principal) {
                    Image("IumrahFlightsCalendarLogo")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(.primary)
                        .frame(width: 138, height: 30)
                        .accessibilityLabel("iumrah Flights")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .task { await loadPublishedFlights() }
        }
        .onAppear {
            departure = calendar.startOfDay(for: initialDeparture)
            returnDate = calendar.startOfDay(for: initialReturn)
        }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(36)
    }

    private var calendarBackground: some View {
        ZStack {
            Color.iumrahPageBackground
            LinearGradient(
                colors: [
                    Color.primary.opacity(colorScheme == .dark ? 0.025 : 0.018),
                    Color.clear,
                    Color.green.opacity(colorScheme == .dark ? 0.035 : 0.055)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(copy(.title))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(-0.5)
            Text(copy(.subtitle))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var routeSummary: some View {
        HStack(spacing: 10) {
            routeCode(trip.originCode)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            routeCode(trip.outboundDestinationCode)
            Image(systemName: "arrow.left.arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            routeCode(trip.returnOriginCode)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            routeCode(trip.originCode)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func routeCode(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .monospaced()
            .frame(maxWidth: .infinity)
    }

    private var directLegend: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.green)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(copy(.recommendedDirect))
                    .font(.subheadline.weight(.bold))
                Text(isLoading ? copy(.loading) : copy(.directHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if loadError {
                Button(copy(.retry)) { Task { await loadPublishedFlights() } }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .iumrahGlass(in: Capsule(), interactive: true)
                    .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.green.opacity(0.075), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.green.opacity(0.16), lineWidth: 1)
        }
    }

    private var flexibleInlineWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.orange)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(copy(.noDirectTitle))
                    .font(.subheadline.weight(.bold))
                Text(copy(.noDirectInlineBody))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.24), lineWidth: 1)
        }
    }

    private func monthSection(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(monthTitle(month))
                .font(.system(size: 25, weight: .bold, design: .rounded))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthCells(month), id: \.id) { cell in
                    if let date = cell.date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 58)
                    }
                }
            }
        }
        .padding(16)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func dayCell(_ date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let disabled = day < calendar.startOfDay(for: Date())
        let isDeparture = departure.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isReturn = returnDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let inRange = isInsideSelectedRange(day)
        let directDay = isRecommendedDay(day)
        let directPair = selectedPublishedSelection != nil

        return Button {
            guard !disabled else { return }
            select(day)
        } label: {
            Text(String(calendar.component(.day, from: day)))
                .font(.system(size: 17, weight: isDeparture || isReturn || directDay ? .bold : .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background {
                    if isDeparture || isReturn {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(directPair ? Color.green : Color.primary)
                    } else if inRange {
                        Rectangle()
                            .fill(directPair ? Color.green.opacity(0.15) : Color.primary.opacity(0.055))
                    } else if directDay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.green.opacity(0.14))
                    }
                }
                .foregroundStyle(
                    disabled
                        ? Color.secondary.opacity(0.36)
                        : ((isDeparture || isReturn) ? Color.iumrahCardBackground : (directDay ? Color.green : Color.primary))
                )
                .overlay {
                    if directDay && !isDeparture && !isReturn {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.green.opacity(0.24), lineWidth: 0.8)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityHint(directDay ? copy(.directAccessibility) : "")
    }

    private var directInventoryNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(copy(.inventoryNote))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                departure = nil
                returnDate = nil
                IumrahHaptics.selection()
            } label: {
                Text(copy(.reset))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(width: 116, height: 60)
            }
            .buttonStyle(.plain)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true)

            Button {
                guard let departure, let returnDate, returnDate > departure else { return }
                if let published = selectedPublishedSelection {
                    IumrahHaptics.success()
                    onApply(FlightDateCalendarResult(
                        departure: departure,
                        returnDate: returnDate,
                        publishedSelection: published
                    ))
                    dismiss()
                } else {
                    IumrahHaptics.soft()
                    showFlexibleWarning = true
                }
            } label: {
                Text(copy(.chooseDates))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.iumrahCardBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.primary.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!hasValidRange)
            .opacity(hasValidRange ? 1 : 0.42)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.iumrahCardBackground)
        .overlay(alignment: .top) { Divider().opacity(0.14) }
    }

    private var flexibleWarningOverlay: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .onTapGesture { showFlexibleWarning = false }

            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.13))
                        .frame(width: 54, height: 54)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.orange)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy(.noDirectTitle))
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    Text(copy(.noDirectPopupBody))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    showFlexibleWarning = false
                    departure = nil
                    returnDate = nil
                    IumrahHaptics.selection()
                } label: {
                    Text(copy(.chooseDirectDates))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.iumrahCardBackground)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 19, style: .continuous))

                Button {
                    guard let departure, let returnDate else { return }
                    IumrahHaptics.success()
                    onApply(FlightDateCalendarResult(
                        departure: departure,
                        returnDate: returnDate,
                        publishedSelection: nil
                    ))
                    dismiss()
                } label: {
                    Text(copy(.continueFlexible))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .padding(22)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.14), radius: 34, y: 16)
            .padding(.horizontal, 22)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(20)
    }

    private var hasValidRange: Bool {
        guard let departure, let returnDate else { return false }
        return returnDate > departure
    }

    private var selectionNeedsFlexibleSearch: Bool {
        guard let departure else { return false }
        if let returnDate { return publishedSelection(departure: departure, returnDate: returnDate) == nil }
        return !recommendedOutboundDateKeys.contains(dayKey(departure))
    }

    private var selectedPublishedSelection: CuratedPublishedFlightSelection? {
        guard let departure, let returnDate else { return nil }
        return publishedSelection(departure: departure, returnDate: returnDate)
    }

    private func publishedSelection(departure: Date, returnDate: Date) -> CuratedPublishedFlightSelection? {
        let outKey = dayKey(departure)
        let returnKey = dayKey(returnDate)

        if let complete = completeRecommendations.first(where: {
            $0.outboundDate == outKey && $0.inboundDate == returnKey
        }) {
            return CuratedPublishedFlightSelection(completeID: complete.id)
        }

        guard let outbound = oneWayOutboundRecommendations.first(where: { $0.outboundDate == outKey }),
              let inbound = oneWayReturnRecommendations.first(where: { $0.outboundDate == returnKey }) else {
            return nil
        }
        return CuratedPublishedFlightSelection(outboundID: outbound.id, returnID: inbound.id)
    }

    private var completeRecommendations: [CuratedFlightRecommendation] {
        publishedFlights.filter { recommendation in
            guard let inbound = recommendation.inbound else { return false }
            return recommendation.outbound.origin == trip.originCode &&
                recommendation.outbound.destination == trip.outboundDestinationCode &&
                inbound.origin == trip.returnOriginCode &&
                inbound.destination == trip.originCode &&
                recommendation.inboundDate != nil
        }
    }

    private var oneWayOutboundRecommendations: [CuratedFlightRecommendation] {
        publishedFlights.filter { recommendation in
            recommendation.inbound == nil &&
            recommendation.outbound.origin == trip.originCode &&
            recommendation.outbound.destination == trip.outboundDestinationCode
        }
    }

    private var oneWayReturnRecommendations: [CuratedFlightRecommendation] {
        publishedFlights.filter { recommendation in
            recommendation.inbound == nil &&
            recommendation.outbound.origin == trip.returnOriginCode &&
            recommendation.outbound.destination == trip.originCode
        }
    }

    private var recommendedOutboundDateKeys: Set<String> {
        Set(completeRecommendations.map(\.outboundDate) + oneWayOutboundRecommendations.map(\.outboundDate))
    }

    private func recommendedReturnDateKeys(for outbound: Date) -> Set<String> {
        let outKey = dayKey(outbound)
        var keys = Set(completeRecommendations.compactMap { recommendation -> String? in
            guard recommendation.outboundDate == outKey else { return nil }
            return recommendation.inboundDate
        })
        if oneWayOutboundRecommendations.contains(where: { $0.outboundDate == outKey }) {
            for recommendation in oneWayReturnRecommendations {
                if let date = CuratedFlightRecommendationService.date(recommendation.outboundDate), date > outbound {
                    keys.insert(recommendation.outboundDate)
                }
            }
        }
        return keys
    }

    private func isRecommendedDay(_ day: Date) -> Bool {
        let key = dayKey(day)
        if let departure, returnDate == nil {
            return recommendedReturnDateKeys(for: departure).contains(key)
        }
        return recommendedOutboundDateKeys.contains(key)
    }

    private func select(_ date: Date) {
        if departure == nil || (departure != nil && returnDate != nil) {
            departure = date
            returnDate = nil
        } else if let departure, date <= departure {
            self.departure = date
            returnDate = nil
        } else {
            returnDate = date
        }
        IumrahHaptics.selection()
    }

    private func isInsideSelectedRange(_ date: Date) -> Bool {
        guard let departure, let returnDate else { return false }
        return date > departure && date < returnDate
    }

    private func dayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return "" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter.string(from: date).capitalized(with: locale)
    }

    private var weekdayTitles: [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        var symbols = formatter.veryShortStandaloneWeekdaySymbols
            ?? formatter.veryShortWeekdaySymbols
            ?? ["S", "M", "T", "W", "T", "F", "S"]
        if calendar.firstWeekday == 2, !symbols.isEmpty {
            let first = symbols.removeFirst()
            symbols.append(first)
        }
        return symbols
    }

    private var monthStarts: [Date] {
        let today = calendar.startOfDay(for: Date())
        let current = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        return (0..<6).compactMap { calendar.date(byAdding: .month, value: $0, to: current) }
    }

    private struct MonthCell: Identifiable {
        let id: String
        let date: Date?
    }

    private func monthCells(_ month: Date) -> [MonthCell] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [MonthCell] = (0..<leading).map { MonthCell(id: "blank-\(month.timeIntervalSince1970)-\($0)", date: nil) }
        cells += range.compactMap { day -> MonthCell? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: first) else { return nil }
            return MonthCell(id: dayKey(date), date: date)
        }
        return cells
    }

    private func loadPublishedFlights() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = false
        defer { isLoading = false }
        do {
            let start = calendar.startOfDay(for: Date())
            let last = monthStarts.last ?? start
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: last) ?? last
            let days = max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 180)
            publishedFlights = try await CuratedFlightRecommendationService.shared.load(trip: trip, from: Date(), days: min(365, days + 2))
        } catch {
            publishedFlights = []
            loadError = true
        }
    }

    private var locale: Locale {
        switch settings.language {
        case .turkish: return Locale(identifier: "tr_TR")
        case .indonesian, .english: return Locale(identifier: "en_US")
        case .russian: return Locale(identifier: "ru_RU")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private var closeLabel: String {
        switch settings.language {
        case .russian: return "Закрыть"
        case .turkish: return TurkishLocalization.phrase("Close")
        case .indonesian, .english: return "Close"
        case .uzbek: return "Yopish"
        case .uzbekCyrillic: return "Ёпиш"
        }
    }

    private enum CopyKey {
        case title, subtitle, recommendedDirect, loading, directHint, retry
        case noDirectTitle, noDirectInlineBody, noDirectPopupBody
        case inventoryNote, reset, chooseDates, chooseDirectDates, continueFlexible, directAccessibility
    }

    private func copy(_ key: CopyKey) -> String {
        switch (settings.language, key) {
        case (.russian, .title): return "Выберите даты"
        case (.russian, .subtitle): return "Зелёные дни — опубликованные прямые рейсы iumrah"
        case (.russian, .recommendedDirect): return "Рекомендует iumrah AI"
        case (.russian, .loading): return "Проверяем опубликованные прямые рейсы…"
        case (.russian, .directHint): return "Зелёные дни доступны в базе iumrah: это прямые рейсы, которые обычно удобнее и выгоднее вариантов с пересадками."
        case (.russian, .retry): return "Обновить"
        case (.russian, .noDirectTitle): return "На эти даты нет прямых рейсов"
        case (.russian, .noDirectInlineBody): return "Можно продолжить с гибкими датами, но система может предложить рейсы с одной или двумя пересадками и более высокой стоимостью. Это повлияет на итоговую цену пакета."
        case (.russian, .noDirectPopupBody): return "В iumrah сейчас нет опубликованной пары прямых рейсов на выбранные даты. При гибком поиске могут появиться варианты с 1–2 пересадками и более высокой ценой, которая увеличит итоговую стоимость вашего пакета."
        case (.russian, .inventoryNote): return "Зелёные дни берутся только из опубликованных рейсов в базе iumrah. Другие дни не помечаются как прямые автоматически."
        case (.russian, .reset): return "Сбросить"
        case (.russian, .chooseDates): return "Продолжить"
        case (.russian, .chooseDirectDates): return "Выбрать даты с прямым рейсом"
        case (.russian, .continueFlexible): return "Продолжить с гибкими датами"
        case (.russian, .directAccessibility): return "Опубликованный прямой рейс"

        case (.turkish, .title): return TurkishLocalization.phrase("Choose your dates")

        case (.indonesian, .title), (.english, .title): return "Choose your dates"
        case (.turkish, .subtitle): return TurkishLocalization.phrase("Green days are iumrah-published direct flights")
        case (.indonesian, .subtitle), (.english, .subtitle): return "Green days are iumrah-published direct flights"
        case (.turkish, .recommendedDirect): return TurkishLocalization.phrase("Recommended by iumrah AI")
        case (.indonesian, .recommendedDirect), (.english, .recommendedDirect): return "Recommended by iumrah AI"
        case (.turkish, .loading): return TurkishLocalization.phrase("Checking published direct flights…")
        case (.indonesian, .loading), (.english, .loading): return "Checking published direct flights…"
        case (.turkish, .directHint): return TurkishLocalization.phrase("Green days are available in iumrah inventory: direct flights that are usually more convenient and better value than connecting options.")
        case (.indonesian, .directHint), (.english, .directHint): return "Green days are available in iumrah inventory: direct flights that are usually more convenient and better value than connecting options."
        case (.turkish, .retry): return TurkishLocalization.phrase("Refresh")
        case (.indonesian, .retry), (.english, .retry): return "Refresh"
        case (.turkish, .noDirectTitle): return TurkishLocalization.phrase("No direct flights on these dates")
        case (.indonesian, .noDirectTitle), (.english, .noDirectTitle): return "No direct flights on these dates"
        case (.turkish, .noDirectInlineBody): return TurkishLocalization.phrase("You can continue with flexible dates, but the system may offer one- or two-stop flights at a higher fare. This affects your final package total.")
        case (.indonesian, .noDirectInlineBody), (.english, .noDirectInlineBody): return "You can continue with flexible dates, but the system may offer one- or two-stop flights at a higher fare. This affects your final package total."
        case (.turkish, .noDirectPopupBody): return TurkishLocalization.phrase("iumrah currently has no published direct-flight pair for these dates. Flexible search may return one- or two-stop options at a higher fare, increasing your final package total.")
        case (.indonesian, .noDirectPopupBody), (.english, .noDirectPopupBody): return "iumrah currently has no published direct-flight pair for these dates. Flexible search may return one- or two-stop options at a higher fare, increasing your final package total."
        case (.turkish, .inventoryNote): return TurkishLocalization.phrase("Green days come only from flights published in the iumrah database. Other dates are never marked direct automatically.")
        case (.indonesian, .inventoryNote), (.english, .inventoryNote): return "Green days come only from flights published in the iumrah database. Other dates are never marked direct automatically."
        case (.turkish, .reset): return TurkishLocalization.phrase("Reset")
        case (.indonesian, .reset), (.english, .reset): return "Reset"
        case (.turkish, .chooseDates): return TurkishLocalization.phrase("Continue")
        case (.indonesian, .chooseDates), (.english, .chooseDates): return "Continue"
        case (.turkish, .chooseDirectDates): return TurkishLocalization.phrase("Choose direct-flight dates")
        case (.indonesian, .chooseDirectDates), (.english, .chooseDirectDates): return "Choose direct-flight dates"
        case (.turkish, .continueFlexible): return TurkishLocalization.phrase("Continue with flexible dates")
        case (.indonesian, .continueFlexible), (.english, .continueFlexible): return "Continue with flexible dates"
        case (.turkish, .directAccessibility): return TurkishLocalization.phrase("Published direct flight")
        case (.indonesian, .directAccessibility), (.english, .directAccessibility): return "Published direct flight"

        case (.uzbek, .title): return "Sanalarni tanlang"
        case (.uzbek, .subtitle): return "Yashil kunlar — iumrah e’lon qilgan to‘g‘ridan-to‘g‘ri reyslar"
        case (.uzbek, .recommendedDirect): return "iumrah AI tavsiya qiladi"
        case (.uzbek, .loading): return "E’lon qilingan to‘g‘ri reyslar tekshirilmoqda…"
        case (.uzbek, .directHint): return "Yashil kunlar iumrah bazasida mavjud: ular odatda transferli variantlardan qulayroq va foydaliroq bo‘lgan to‘g‘ridan-to‘g‘ri reyslardir."
        case (.uzbek, .retry): return "Yangilash"
        case (.uzbek, .noDirectTitle): return "Bu sanalarda to‘g‘ridan-to‘g‘ri reys yo‘q"
        case (.uzbek, .noDirectInlineBody): return "Moslashuvchan sanalar bilan davom etishingiz mumkin, ammo tizim 1–2 ta transferli va qimmatroq reyslarni taklif qilishi mumkin. Bu paketning yakuniy narxiga ta’sir qiladi."
        case (.uzbek, .noDirectPopupBody): return "Hozir iumrah bazasida tanlangan sanalar uchun e’lon qilingan to‘g‘ridan-to‘g‘ri reys juftligi yo‘q. Moslashuvchan qidiruv 1–2 ta transferli va qimmatroq variantlarni topishi mumkin; bu yakuniy paket narxini oshiradi."
        case (.uzbek, .inventoryNote): return "Yashil kunlar faqat iumrah bazasida e’lon qilingan reyslardan olinadi. Boshqa kunlar avtomatik ravishda to‘g‘ri reys deb belgilanmaydi."
        case (.uzbek, .reset): return "Tozalash"
        case (.uzbek, .chooseDates): return "Davom etish"
        case (.uzbek, .chooseDirectDates): return "To‘g‘ri reysli sanalarni tanlash"
        case (.uzbek, .continueFlexible): return "Moslashuvchan sanalar bilan davom etish"
        case (.uzbek, .directAccessibility): return "E’lon qilingan to‘g‘ridan-to‘g‘ri reys"

        case (.uzbekCyrillic, .title): return "Саналарни танланг"
        case (.uzbekCyrillic, .subtitle): return "Яшил кунлар — iumrah эълон қилган тўғридан-тўғри рейслар"
        case (.uzbekCyrillic, .recommendedDirect): return "iumrah AI тавсия қилади"
        case (.uzbekCyrillic, .loading): return "Эълон қилинган тўғри рейслар текширилмоқда…"
        case (.uzbekCyrillic, .directHint): return "Яшил кунлар iumrah базасида мавжуд: улар одатда трансферли вариантлардан қулайроқ ва фойдалироқ бўлган тўғридан-тўғри рейслардир."
        case (.uzbekCyrillic, .retry): return "Янгилаш"
        case (.uzbekCyrillic, .noDirectTitle): return "Бу саналарда тўғридан-тўғри рейс йўқ"
        case (.uzbekCyrillic, .noDirectInlineBody): return "Мослашувчан саналар билан давом этишингиз мумкин, аммо тизим 1–2 та трансферли ва қимматроқ рейсларни таклиф қилиши мумкин. Бу пакетнинг якуний нархига таъсир қилади."
        case (.uzbekCyrillic, .noDirectPopupBody): return "Ҳозир iumrah базасида танланган саналар учун эълон қилинган тўғридан-тўғри рейс жуфтлиги йўқ. Мослашувчан қидирув 1–2 та трансферли ва қимматроқ вариантларни топиши мумкин; бу якуний пакет нархини оширади."
        case (.uzbekCyrillic, .inventoryNote): return "Яшил кунлар фақат iumrah базасида эълон қилинган рейслардан олинади. Бошқа кунлар автоматик равишда тўғри рейс деб белгиланмайди."
        case (.uzbekCyrillic, .reset): return "Тозалаш"
        case (.uzbekCyrillic, .chooseDates): return "Давом этиш"
        case (.uzbekCyrillic, .chooseDirectDates): return "Тўғри рейсли саналарни танлаш"
        case (.uzbekCyrillic, .continueFlexible): return "Мослашувчан саналар билан давом этиш"
        case (.uzbekCyrillic, .directAccessibility): return "Эълон қилинган тўғридан-тўғри рейс"
        }
    }
}
