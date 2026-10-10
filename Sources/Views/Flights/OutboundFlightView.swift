import SwiftUI

private enum FlightResultSortMode: String, CaseIterable, Identifiable {
    case recommended
    case cheapest
    case fastest
    var id: String { rawValue }
}

private enum FlightResultStopsFilter: String, CaseIterable, Identifiable {
    case all
    case nonstop
    case oneStop
    case multipleStops
    var id: String { rawValue }
}

struct OutboundFlightView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.iumrahAdaptiveLayout) private var adaptiveLayout

    @State private var candidates: [LiveFlightCandidate] = []
    @State private var offers: [FlightOffer] = []
    @State private var isInitialLoading = true
    @State private var isSearching = false
    @State private var fatalErrorText: String?
    @State private var searchStatus: GeneratorSearchStage? = .starting
    @State private var searchGeneration = UUID()
    @State private var sortMode: FlightResultSortMode = .recommended
    @State private var stopsFilter: FlightResultStopsFilter = .all
    @State private var airlineFilter: String? = nil
    @State private var packagePrices: [String: Decimal] = [:]

    var body: some View {
        Group {
            if hasVerifiedResults {
                resultsView
                    .iumrahInternalNavigation(progress: .flight, showsGeneratorAmbient: true)
            } else if !isSearching && !isInitialLoading {
                searchGate
                    .iumrahInternalNavigation(progress: .flight, showsGeneratorAmbient: true)
            } else {
                FlightSearchImmersiveView(state: .searching, liveStatus: searchStatus)
            }
        }
        .background(shouldShowImmersive ? Color.black : Color.iumrahPageBackground)
        .task { await search(continueExisting: false) }
        .task(id: packagePreviewSignature) { await refreshPackagePrices() }
        .onAppear { updateImmersive() }
        .onChange(of: isInitialLoading) { _, _ in updateImmersive() }
        .onDisappear { chrome.setImmersive(false) }
    }

    private var searchGate: some View {
        FlightSearchGateView(
            direction: .outbound,
            anchorDate: journey.trip.departureDate,
            flexibility: journey.trip.flexibility,
            message: fatalErrorText ?? searchGateFallbackMessage,
            onRetry: { Task { await search(continueExisting: true) } }
        )
    }

    private var searchGateFallbackMessage: String {
        switch settings.language {
        case .russian: return "Поиск завершён без рейса, который прошёл все проверки iumrah."
        case .turkish: return TurkishLocalization.phrase("Search completed without a flight that passed all iumrah checks.")
        case .indonesian, .malay, .english: return "Search completed without a flight that passed all iumrah checks."
        case .uzbek: return "Qidiruv iumrah tekshiruvlaridan o‘tgan reyssiz yakunlandi."
        case .uzbekCyrillic: return "Қидирув iumrah текширувларидан ўтган рейссиз якунланди."
        }
    }

    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                IumrahGeneratorHeader(stage: .flight)

                SectionHeader(
                    L10n.text("flight_out_title", settings.language),
                    eyebrow: L10n.text("flight_out_eyebrow", settings.language),
                    subtitle: L10n.text("flight_out_body", settings.language)
                )

                if adaptiveLayout.isWide {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 14) {
                            resultCountLabel
                            IumrahRefundPolicyCard(component: .flight, compact: true)
                            resultFilters
                            FlightSearchProgressCard(
                                isSearching: isSearching,
                                hasResults: !offers.isEmpty,
                                liveStatus: searchStatus,
                                onContinue: { Task { await search(continueExisting: true) } }
                            )
                        }
                        .frame(width: 320, alignment: .top)

                        flightGroups
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                } else {
                    resultCountLabel
                    IumrahRefundPolicyCard(component: .flight, compact: true)
                    resultFilters
                    flightGroups

                    FlightSearchProgressCard(
                        isSearching: isSearching,
                        hasResults: !offers.isEmpty,
                        liveStatus: searchStatus,
                        onContinue: { Task { await search(continueExisting: true) } }
                    )
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 112)
        }
        .background(Color.iumrahPageBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasCompleteSelection {
                floatingContinueBar
            }
        }
    }

    @ViewBuilder
    private var flightGroups: some View {
        let rows = visibleOffers.map {
            FlightResultRowModel(id: $0.resultIdentityKey, candidate: nil, offer: $0)
        }
        let groups = grouped(rows: rows, anchor: journey.trip.departureDate)

        if rows.isEmpty {
            Text(noFilteredResultsText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .iumrahCard()
        } else {
            ForEach(groups, id: \.offset) { group in
                VStack(alignment: .leading, spacing: 12) {
                    if journey.trip.flexibility.isFlexibleDayRange || group.offset != 0 {
                        flexibleDateHeader(offset: group.offset, date: group.rows.first?.departureAt)
                    }

                    ForEach(group.rows) { row in
                        resultRow(row)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ row: FlightResultRowModel) -> some View {
        if let offer = row.offer {
            VStack(spacing: 10) {
                Button {
                    journey.chooseOutboundFlight(offer)
                    IumrahHaptics.selection()
                } label: {
                    FlightCard(
                        offer: offer,
                        isSelected: journey.selectedOutbound?.id == offer.id,
                        isRecommended: recommendedOfferID == offer.id,
                        travelerCount: journey.trip.travelerCount,
                        packagePricePerPerson: packagePrices[offer.id],
                        referencePackagePricePerPerson: referenceOffer.flatMap { packagePrices[$0.id] },
                        usesProvisionalOppositeLeg: false,
                        isPackagePriceLoading: journey.isSearchingHotelPrices
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FlightDetailsView(offer: offer)
                } label: {
                    HStack(spacing: 6) {
                        Text(L10n.text("flight_details_cta", settings.language))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
            }
        } else if let candidate = row.candidate {
            FlightCandidatePreviewCard(candidate: candidate)
        }
    }

    private var recommendedOffer: FlightOffer? {
        let selectedDay = offers.filter { dayOffset($0.departureAt, from: journey.trip.departureDate) == 0 }
        let pool = selectedDay.isEmpty ? offers : selectedDay
        return pool.min { lhs, rhs in
            // Recommendation follows the complete package price shown on the card.
            // Every round-trip outbound row already represents the cheapest verified
            // complete itinerary compatible with that physical outbound leg.
            if let lp = packagePrices[lhs.id], let rp = packagePrices[rhs.id], lp != rp {
                return lp < rp
            }
            if lhs.currency == rhs.currency, lhs.totalPackagePrice != rhs.totalPackagePrice {
                return lhs.totalPackagePrice < rhs.totalPackagePrice
            }
            if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
            if lhs.durationMinutes != rhs.durationMinutes { return lhs.durationMinutes < rhs.durationMinutes }
            return lhs.departureAt < rhs.departureAt
        }
    }

    private var recommendedOfferID: String? { recommendedOffer?.id }

    /// Deltas are relative to the traveler's current selection. Before a selection
    /// exists, the recommended package is the zero reference. This allows both +$ and −$ changes.
    private var referenceOffer: FlightOffer? { journey.selectedOutbound ?? recommendedOffer }

    private var resultCountLabel: some View {
        Label(resultCountText, systemImage: "list.number")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultFilters: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(ticketTypeLabel, systemImage: "airplane.departure")
                .font(.subheadline.weight(.bold))

            filterSection(title: sortTitle) {
                ForEach(FlightResultSortMode.allCases) { value in
                    filterChip(sortLabel(value), selected: sortMode == value) {
                        sortMode = value
                    }
                }
            }

            filterSection(title: stopsTitle) {
                ForEach(FlightResultStopsFilter.allCases) { value in
                    filterChip(stopsLabel(value), selected: stopsFilter == value) {
                        stopsFilter = value
                    }
                }
            }

            if !allAirlineCodes.isEmpty {
                filterSection(title: airlinesTitle) {
                    filterChip(allAirlinesTitle, selected: airlineFilter == nil) { airlineFilter = nil }
                    ForEach(allAirlineCodes, id: \.self) { code in
                        filterChip(FlightReferenceCatalog.airlineName(code: code, fallback: code), selected: airlineFilter == code) {
                            airlineFilter = code
                        }
                    }
                }
            }
        }
        .iumrahCard()
    }

    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }
            }
        }
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .foregroundStyle(selected ? Color.iumrahCardBackground : Color.primary)
                .iumrahGlass(in: Capsule(), interactive: true, tint: selected ? Color.primary : nil)
        }
        .buttonStyle(.plain)
    }

    private var resultCountText: String {
        switch settings.language {
        case .russian: return "Показано \(visibleOffers.count) из \(offers.count) найденных билетов"
        case .turkish: return TurkishLocalization.phrase("Showing \(visibleOffers.count) of \(offers.count) tickets found")
        case .indonesian, .malay, .english: return "Showing \(visibleOffers.count) of \(offers.count) tickets found"
        case .uzbek: return "Topilgan \(offers.count) chiptadan \(visibleOffers.count) tasi ko‘rsatilmoqda"
        case .uzbekCyrillic: return "Топилган \(offers.count) чиптадан \(visibleOffers.count) таси кўрсатилмоқда"
        }
    }

    private func selectRecommendedIfNeeded() {
        guard let recommendedOffer else { return }
        if journey.selectedOutbound == nil {
            journey.chooseOutboundFlight(recommendedOffer)
        }
    }

    private var floatingContinueBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)

            if adaptiveLayout.layoutClass == .compact {
                continuePackageLink
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    continuePackageLink
                        .frame(maxWidth: 560)
                }
                .padding(.horizontal, adaptiveLayout.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Color.iumrahCardBackground)
    }

    private var continuePackageLink: some View {
        NavigationLink {
            if journey.trip.isRoundTripFlight {
                ReturnFlightView()
            } else {
                TransferSelectionView()
            }
        } label: {
            HStack(spacing: 10) {
                Text(continuePackageTitle)
                Spacer(minLength: 12)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal, 20)
            .frame(height: 58)
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
    }

    private func search(continueExisting: Bool) async {
        guard !isSearching else { return }
        guard let makkahHotel = journey.selectedHotel else {
            fatalErrorText = L10n.text("flight_select_hotel_first", settings.language)
            isInitialLoading = false
            return
        }
        let madinahHotel = journey.selectedMadinahHotel
        if journey.trip.scope == .makkahAndMadinah, madinahHotel == nil {
            fatalErrorText = FlowCopy.text(.madinahHotelRequired, settings.language)
            isInitialLoading = false
            return
        }

        if !continueExisting {
            candidates = []
            offers = []
            journey.selectedOutbound = nil
            journey.selectedInbound = nil
            journey.quote = nil
        }

        let generation = UUID()
        searchGeneration = generation
        isSearching = true
        fatalErrorText = nil
        journey.errorMessage = nil
        if candidates.isEmpty && offers.isEmpty { isInitialLoading = true }

        // Hotel catalog availability is prepared beside flight discovery instead of starting only after
        // the user reaches FinalPackageView. The JourneyStore-owned task survives
        // navigation and is reused by the final quote calculation.
        journey.scheduleHotelPricePrefetch()
        do {
            let final = try await journey.flightService.searchOutboundProgressive(
                trip: journey.trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                onUpdate: { progress in
                    guard searchGeneration == generation else { return }
                    candidates = mergeCandidates(candidates, progress.discoveredCandidates)
                    offers = mergeOffers(offers, progress.pricedOffers)
                    searchStatus = progress.status
                    isSearching = progress.isSearching
                    if !offers.isEmpty || !progress.isSearching {
                        withAnimation(.easeInOut(duration: 0.22)) { isInitialLoading = false }
                    }
                }
            )
            guard searchGeneration == generation else { return }
            offers = mergeOffers(offers, final)
        } catch {
            guard searchGeneration == generation else { return }
            // Provider exhaustion is handled inside the progressive service. Only
            // backend/configuration failures reach this branch.
            fatalErrorText = L10n.error(error, settings.language)
            journey.errorMessage = error.localizedDescription
        }

        guard searchGeneration == generation else { return }
        isSearching = false
        isInitialLoading = false
        selectRecommendedIfNeeded()
        if !offers.isEmpty { IumrahHaptics.success() }
    }

    private var hasVerifiedResults: Bool { !offers.isEmpty }

    private var hasCompleteSelection: Bool {
        journey.selectedOutbound != nil
    }

    private var visibleOffers: [FlightOffer] {
        let filtered = offers.filter { offer in
            let stops = offer.stops
            let matchesStops: Bool
            switch stopsFilter {
            case .all: matchesStops = true
            case .nonstop: matchesStops = stops == 0
            case .oneStop: matchesStops = stops == 1
            case .multipleStops: matchesStops = stops >= 2
            }
            let matchesAirline = airlineFilter.map { airlineCodes(for: offer).contains($0) } ?? true
            return matchesStops && matchesAirline
        }

        return filtered.sorted { lhs, rhs in
            let lhsDay = abs(dayOffset(lhs.departureAt, from: journey.trip.departureDate))
            let rhsDay = abs(dayOffset(rhs.departureAt, from: journey.trip.departureDate))
            if lhsDay != rhsDay { return lhsDay < rhsDay }
            switch sortMode {
            case .recommended:
                if lhs.id == recommendedOfferID { return true }
                if rhs.id == recommendedOfferID { return false }
                if let lp = packagePrices[lhs.id], let rp = packagePrices[rhs.id], lp != rp { return lp < rp }
                if lhs.totalPackagePrice != rhs.totalPackagePrice { return lhs.totalPackagePrice < rhs.totalPackagePrice }
                let leftStops = lhs.stops
                let rightStops = rhs.stops
                if leftStops != rightStops { return leftStops < rightStops }
            case .cheapest:
                if let lp = packagePrices[lhs.id], let rp = packagePrices[rhs.id], lp != rp { return lp < rp }
                if lhs.totalPackagePrice != rhs.totalPackagePrice { return lhs.totalPackagePrice < rhs.totalPackagePrice }
            case .fastest:
                let leftDuration = lhs.durationMinutes
                let rightDuration = rhs.durationMinutes
                if leftDuration != rightDuration { return leftDuration < rightDuration }
            }
            return lhs.departureAt < rhs.departureAt
        }
    }

    private var packagePreviewSignature: String {
        let hotelKey = journey.hotelPriceSnapshot.map { String($0.hashValue) } ?? "-"
        return [offers.map(\.id).joined(separator: ","), hotelKey].joined(separator: "|")
    }

    private func refreshPackagePrices() async {
        guard !offers.isEmpty else { packagePrices = [:]; return }
        packagePrices = await journey.packagePricePreviews(
            offers: offers,
            direction: .outbound,
            oppositeLeg: nil
        )
    }

    private var allAirlineCodes: [String] {
        Array(Set(offers.flatMap { airlineCodes(for: $0) })).sorted()
    }

    private func airlineCodes(for offer: FlightOffer) -> [String] {
        let leg = [offer.airlineCode, offer.primaryAirlineCode] + offer.displaySegments.map(\.airlineCode)
        return Array(Set(leg.compactMap { code in
            guard let code = code?.uppercased(), code.range(of: "^[A-Z0-9]{2}$", options: .regularExpression) != nil else { return nil }
            return code
        }))
    }

    private var ticketTypeLabel: String {
        switch settings.language {
        case .russian: return journey.trip.isRoundTripFlight ? "Выберите перелёт туда" : "Выберите перелёт"
        case .turkish: return journey.trip.isRoundTripFlight ? "Gidiş uçuşunuzu seçin" : "Uçuşunuzu seçin"
        case .indonesian, .malay, .english: return journey.trip.isRoundTripFlight ? "Choose your outbound flight" : "Choose your flight"
        case .uzbek: return journey.trip.isRoundTripFlight ? "Borish reysini tanlang" : "Reysni tanlang"
        case .uzbekCyrillic: return journey.trip.isRoundTripFlight ? "Бориш рейсини танланг" : "Рейсни танланг"
        }
    }

    private var continuePackageTitle: String {
        if journey.trip.isRoundTripFlight {
            switch settings.language {
            case .russian: return "Выбрать билет туда"
            case .turkish: return TurkishLocalization.phrase("Select outbound ticket")
            case .indonesian, .malay, .english: return "Select outbound ticket"
            case .uzbek: return "Borish chiptasini tanlash"
            case .uzbekCyrillic: return "Бориш чиптасини танлаш"
            }
        }
        switch settings.language {
        case .russian: return "Выбрать билет и продолжить к трансферу"
        case .turkish: return TurkishLocalization.phrase("Select ticket and continue to transfer")
        case .indonesian, .malay, .english: return "Select ticket and continue to transfer"
        case .uzbek: return "Chiptani tanlash va transferga o‘tish"
        case .uzbekCyrillic: return "Чиптани танлаш ва трансферга ўтиш"
        }
    }

    private var sortTitle: String {
        switch settings.language {
        case .russian: return "Сортировка"
        case .turkish: return TurkishLocalization.phrase("Sort")
        case .indonesian, .malay, .english: return "Sort"
        case .uzbek: return "Saralash"
        case .uzbekCyrillic: return "Саралаш"
        }
    }

    private func sortLabel(_ value: FlightResultSortMode) -> String {
        switch (value, settings.language) {
        case (.recommended, .russian): return "Рекомендуемые"
        case (.recommended, .turkish): return TurkishLocalization.phrase("Recommended")
        case (.recommended, .indonesian), (.recommended, .malay), (.recommended, .english): return "Recommended"
        case (.recommended, .uzbek), (.recommended, .uzbekCyrillic): return "Tavsiya"
        case (.cheapest, .russian): return "Самые дешёвые"
        case (.cheapest, .turkish): return TurkishLocalization.phrase("Cheapest")
        case (.cheapest, .indonesian), (.cheapest, .malay), (.cheapest, .english): return "Cheapest"
        case (.cheapest, .uzbek), (.cheapest, .uzbekCyrillic): return "Eng arzon"
        case (.fastest, .russian): return "Самые быстрые"
        case (.fastest, .turkish): return TurkishLocalization.phrase("Fastest")
        case (.fastest, .indonesian), (.fastest, .malay), (.fastest, .english): return "Fastest"
        case (.fastest, .uzbek), (.fastest, .uzbekCyrillic): return "Eng tez"
        }
    }

    private var stopsTitle: String {
        switch settings.language {
        case .russian: return "Пересадки"
        case .turkish: return TurkishLocalization.phrase("Stops")
        case .indonesian, .malay, .english: return "Stops"
        case .uzbek: return "To‘xtashlar"
        case .uzbekCyrillic: return "Тўхташлар"
        }
    }

    private func stopsLabel(_ value: FlightResultStopsFilter) -> String {
        switch (value, settings.language) {
        case (.all, .russian): return "Все билеты"
        case (.all, .turkish): return TurkishLocalization.phrase("All tickets")
        case (.all, .indonesian), (.all, .malay), (.all, .english): return "All tickets"
        case (.all, .uzbek): return "Barcha chiptalar"
        case (.all, .uzbekCyrillic): return "Барча чипталар"
        case (.nonstop, .russian): return "Прямые"
        case (.nonstop, .turkish): return TurkishLocalization.phrase("Nonstop")
        case (.nonstop, .indonesian), (.nonstop, .malay), (.nonstop, .english): return "Nonstop"
        case (.nonstop, .uzbek): return "To‘g‘ridan-to‘g‘ri"
        case (.nonstop, .uzbekCyrillic): return "Тўғридан-тўғри"
        case (.oneStop, .russian): return "1 пересадка"
        case (.oneStop, .turkish): return TurkishLocalization.phrase("1 stop")
        case (.oneStop, .indonesian), (.oneStop, .malay), (.oneStop, .english): return "1 stop"
        case (.oneStop, .uzbek): return "1 ta ulanish"
        case (.oneStop, .uzbekCyrillic): return "1 та уланиш"
        case (.multipleStops, .russian): return "2+ пересадки"
        case (.multipleStops, .turkish): return TurkishLocalization.phrase("2+ stops")
        case (.multipleStops, .indonesian), (.multipleStops, .malay), (.multipleStops, .english): return "2+ stops"
        case (.multipleStops, .uzbek): return "2+ ulanish"
        case (.multipleStops, .uzbekCyrillic): return "2+ уланиш"
        }
    }

    private var airlinesTitle: String {
        switch settings.language {
        case .russian: return "Авиакомпании"
        case .turkish: return TurkishLocalization.phrase("Airlines")
        case .indonesian, .malay, .english: return "Airlines"
        case .uzbek: return "Aviakompaniyalar"
        case .uzbekCyrillic: return "Авиакомпаниялар"
        }
    }

    private var allAirlinesTitle: String {
        switch settings.language {
        case .russian: return "Все"
        case .turkish: return TurkishLocalization.phrase("All")
        case .indonesian, .malay, .english: return "All"
        case .uzbek, .uzbekCyrillic: return "Barchasi"
        }
    }

    private var noFilteredResultsText: String {
        switch settings.language {
        case .russian: return "По выбранным фильтрам вариантов нет. Сбросьте фильтр — все найденные варианты останутся в списке."
        case .turkish: return TurkishLocalization.phrase("No matches for these filters. Clear a filter; every discovered option remains available.")
        case .indonesian, .malay, .english: return "No matches for these filters. Clear a filter; every discovered option remains available."
        case .uzbek: return "Tanlangan filtrlarda variant yo‘q. Filtrni olib tashlang — barcha topilgan variantlar saqlanadi."
        case .uzbekCyrillic: return "Танланган фильтрларда вариант йўқ. Фильтрни олиб ташланг — барча топилган вариантлар сақланади."
        }
    }

    private var shouldShowImmersive: Bool {
        !hasVerifiedResults && (isSearching || isInitialLoading)
    }

    private func updateImmersive() {
        chrome.setImmersive(shouldShowImmersive)
    }

    private func grouped(rows: [FlightResultRowModel], anchor: Date) -> [(offset: Int, rows: [FlightResultRowModel])] {
        let byOffset = Dictionary(grouping: rows) { dayOffset($0.departureAt, from: anchor) }
        let keys: [Int]
        if journey.trip.flexibility.isWeeklyDiscovery {
            keys = byOffset.keys.sorted()
        } else {
            keys = byOffset.keys.sorted { abs($0) == abs($1) ? $0 < $1 : abs($0) < abs($1) }
        }
        return keys.map { ($0, byOffset[$0, default: []]) }
    }

    private func dayOffset(_ date: Date, from anchor: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: anchor)
        let value = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: value).day ?? 0
    }

    private func mergeCandidates(_ lhs: [LiveFlightCandidate], _ rhs: [LiveFlightCandidate]) -> [LiveFlightCandidate] {
        var result = lhs.filter(\.isDisplayableCandidate)
        var indexByKey = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($0.element.deduplicationKey, $0.offset) })
        for candidate in rhs where candidate.isDisplayableCandidate {
            if let index = indexByKey[candidate.deduplicationKey] {
                if candidate.observedAt > result[index].observedAt { result[index] = candidate }
            } else {
                indexByKey[candidate.deduplicationKey] = result.count
                result.append(candidate)
            }
        }
        return result
    }

    private func mergeOffers(_ lhs: [FlightOffer], _ rhs: [FlightOffer]) -> [FlightOffer] {
        var result = lhs.filter { $0.isVerifiedForBooking && isValidOutboundDate($0.departureAt, airportCode: $0.origin) }
        var indexByKey = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($0.element.resultIdentityKey, $0.offset) })
        for offer in rhs where offer.isVerifiedForBooking && isValidOutboundDate(offer.departureAt, airportCode: offer.origin) {
            if let index = indexByKey[offer.resultIdentityKey] {
                result[index] = offer
            } else {
                indexByKey[offer.resultIdentityKey] = result.count
                result.append(offer)
            }
        }
        return result
    }

    private func isValidOutboundDate(_ date: Date, airportCode: String) -> Bool {
        guard journey.trip.isRoundTripFlight else { return true }
        return travelDay(date, airportCode: airportCode) < Calendar.current.startOfDay(for: journey.trip.returnDate)
    }

    private func travelDay(_ date: Date, airportCode: String) -> Date {
        var source = Calendar(identifier: .gregorian)
        source.timeZone = FlightReferenceCatalog.timeZone(for: airportCode) ?? TimeZone(secondsFromGMT: 0)!
        let parts = source.dateComponents([.year, .month, .day], from: date)
        return Calendar.current.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day)) ?? Calendar.current.startOfDay(for: date)
    }

    private func flexibleDateHeader(offset: Int, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if journey.trip.flexibility.isWeeklyDiscovery, let date {
                Text(weeklyDateTitle(date))
                    .font(.title3.weight(.bold))
                Text(weeklyDateSubtitle(offset))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(flexibleDateTitle(offset))
                    .font(.title3.weight(.bold))
                if let date {
                    Text("\(localizedDate(date)) · \(flexibleDateSubtitle(offset))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, offset == 0 ? 0 : 8)
    }

    private func weeklyDateTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: date).localizedCapitalized
    }

    private func weeklyDateSubtitle(_ offset: Int) -> String {
        let selected = offset == 0
        switch settings.language {
        case .russian: return selected ? "Ваша дата · есть подтверждённый рейс" : "На эту дату найден подтверждённый рейс"
        case .turkish: return selected ? "Seçtiğiniz tarih · doğrulanmış uçuş mevcut" : "Bu tarihte doğrulanmış uçuş mevcut"
        case .indonesian, .malay, .english: return selected ? "Your date · verified flight available" : "A verified flight is available on this date"
        case .uzbek: return selected ? "Siz tanlagan sana · tasdiqlangan reys bor" : "Bu sanada tasdiqlangan reys topildi"
        case .uzbekCyrillic: return selected ? "Сиз танлаган сана · тасдиқланган рейс бор" : "Бу санада тасдиқланган рейс топилди"
        }
    }

    private func flexibleDateTitle(_ offset: Int) -> String {
        switch settings.language {
        case .russian:
            if offset == 0 { return "Ваша выбранная дата" }
            return offset < 0 ? "На \(abs(offset)) дн. раньше" : "На \(offset) дн. позже"
        case .turkish:
            if offset == 0 { return "Seçtiğiniz tarih" }
            return offset < 0 ? "\(abs(offset)) gün önce" : "\(offset) gün sonra"
        case .indonesian, .malay, .english:
            if offset == 0 { return "Your selected date" }
            return offset < 0 ? "\(abs(offset)) day(s) earlier" : "\(offset) day(s) later"
        case .uzbek:
            if offset == 0 { return "Siz tanlagan sana" }
            return offset < 0 ? "\(abs(offset)) kun oldin" : "\(offset) kun keyin"
        case .uzbekCyrillic:
            if offset == 0 { return "Сиз танлаган сана" }
            return offset < 0 ? "\(abs(offset)) кун олдин" : "\(offset) кун кейин"
        }
    }

    private func flexibleDateSubtitle(_ offset: Int) -> String {
        switch settings.language {
        case .russian:
            return offset == 0 ? "Сначала показываем варианты на выбранный день" : "Нашли дополнительные варианты и хорошие цены рядом с вашей датой"
        case .turkish:
            return offset == 0 ? "Seçtiğiniz tarihteki seçenekler" : "Tarihinize yakın daha avantajlı seçenekler ve fiyatlar"
        case .indonesian, .malay, .english:
            return offset == 0 ? "Options on the date you selected" : "More useful options and prices close to your date"
        case .uzbek:
            return offset == 0 ? "Avval tanlangan kundagi variantlar" : "Tanlangan sanaga yaqin qo‘shimcha qulay variantlar"
        case .uzbekCyrillic:
            return offset == 0 ? "Аввал танланган кундаги вариантлар" : "Танланган санага яқин қўшимча қулай вариантлар"
        }
    }

    private func localizedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}
