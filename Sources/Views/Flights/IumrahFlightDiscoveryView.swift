import SwiftUI

private enum FlightDiscoveryTripType: String, CaseIterable, Identifiable {
    case oneWay
    case roundTrip

    var id: String { rawValue }
}

private enum FlightDiscoverySearchMode: String, CaseIterable, Identifiable {
    case globalSearch
    case iumrahRecommended

    var id: String { rawValue }
}

struct IumrahFlightDiscoveryView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.openURL) private var openURL

    @StateObject private var store = IumrahFlightDiscoveryStore()
    @StateObject private var favorites = FlightFavoritesStore.shared

    @State private var destinationAirport: Airport?
    @State private var destinationCode = "JED"
    @State private var tripType: FlightDiscoveryTripType = .roundTrip
    @State private var departureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var returnDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var adults = 1
    @State private var children = 0
    @State private var infants = 0
    @State private var directOnly = false

    @State private var originPickerPresented = false
    @State private var destinationPickerPresented = false
    @State private var calendarPresented = false
    @State private var passengersPresented = false
    @State private var filtersPresented = false
    @State private var graphPresented = false
    @State private var airlinesPresented = false
    @State private var favoritesPresented = false
    @State private var selectedAirlineCodes: Set<String> = []
    @State private var selectedOffer: FlightDiscoveryOffer?
    @State private var seededFromJourney = false
    @State private var searchMode: FlightDiscoverySearchMode = .globalSearch
    @State private var hasSearched = false
    @State private var searchProgress = 0.0
    @State private var searchRunID = UUID()
    @State private var recommendedFlights: [CuratedFlightRecommendation] = []
    @State private var recommendedLoading = false
    @State private var recommendedError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            searchModePicker
            routeCard

            if searchMode == .globalSearch {
                partnerGatewayCard
                tripTypePicker
                searchControls
                searchButton
                discoveryActions
                searchResultsSection

                if hasSearched {
                    nearbyDealsSection
                    dataSourceNote
                }
            } else {
                tripTypePicker
                recommendedSearchControls
                recommendedFlightsSection
            }
        }
        .task {
            seedFromJourneyIfNeeded()
            await favorites.refreshAllFavorites(language: settings.language)
        }
        .task(id: recommendedRefreshKey) {
            guard searchMode == .iumrahRecommended else { return }
            await loadRecommendedFlights()
        }
        .onChange(of: refreshKey) { _, _ in
            resetGlobalSearch()
        }
        .sheet(isPresented: $originPickerPresented) {
            AirportPickerView(
                selection: $journey.trip.originAirport,
                fallbackCode: $journey.trip.origin
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $destinationPickerPresented) {
            AirportPickerView(
                selection: $destinationAirport,
                fallbackCode: $destinationCode
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $calendarPresented) {
            FlightDiscoveryCalendarSheet(
                language: settings.language,
                tripType: tripType,
                calendarDays: store.calendarDays,
                departureDate: $departureDate,
                returnDate: $returnDate
            )
        }
        .sheet(isPresented: $passengersPresented) {
            FlightDiscoveryPassengersSheet(
                language: settings.language,
                adults: $adults,
                children: $children,
                infants: $infants
            )
        }
        .sheet(isPresented: $filtersPresented) {
            FlightDiscoveryFiltersSheet(
                language: settings.language,
                directOnly: $directOnly
            )
        }
        .sheet(isPresented: $graphPresented) {
            FlightDiscoveryPriceGraphSheet(
                language: settings.language,
                origin: originCode,
                destination: destinationCode.uppercased(),
                initialOutboundDays: store.calendarDays,
                roundTrip: tripType == .roundTrip,
                departureDate: $departureDate,
                returnDate: $returnDate
            )
        }
        .sheet(isPresented: $airlinesPresented) {
            FlightDiscoveryAirlinesSheet(
                language: settings.language,
                offers: selectedDateUnfilteredOffers,
                selectedCodes: $selectedAirlineCodes
            )
        }
        .sheet(isPresented: $favoritesPresented) {
            FlightDiscoveryFavoritesSheet(
                language: settings.language,
                records: favorites.records,
                onSelect: { record in
                    favoritesPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        selectedOffer = record.offer
                    }
                },
                onRemove: { favorites.remove($0) }
            )
        }
        .navigationDestination(item: $selectedOffer) { offer in
            FlightDiscoveryOfferDetailView(
                language: settings.language,
                offer: offer,
                adults: adults,
                children: children,
                infants: infants,
                fallbackReturnDate: tripType == .roundTrip ? returnDate : nil,
                currency: store.currency,
                canBuildUmrah: ["JED", "MED"].contains(offer.destination.uppercased()) || ["JED", "MED"].contains(offer.origin.uppercased()),
                onCheckPrice: { currentOffer in checkCurrentPrice(for: currentOffer) },
                onBuildUmrah: { currentOffer in stageDiscoveryFlightForUmrah(currentOffer) }
            )
        }
        .onChange(of: destinationAirport) { _, airport in
            if let airport { destinationCode = airport.iata.uppercased() }
        }
        .onChange(of: store.offers) { _, offers in
            favorites.reconcile(offers: offers, currency: store.currency, language: settings.language)
        }
    }

    private var searchModePicker: some View {
        Picker("", selection: $searchMode) {
            Text(tr("Глобальный поиск", "Global search", "Global qidiruv", "Глобал қидирув"))
                .tag(FlightDiscoverySearchMode.globalSearch)
            Text(tr("Рекомендует iumrah", "iumrah recommends", "iumrah tavsiya qiladi", "iumrah тавсия қилади"))
                .tag(FlightDiscoverySearchMode.iumrahRecommended)
        }
        .pickerStyle(.segmented)
        .onChange(of: searchMode) { _, mode in
            IumrahHaptics.selection()
            if mode == .iumrahRecommended {
                Task { await loadRecommendedFlights() }
            }
        }
    }

    private var partnerGatewayCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Image("IumrahFlightsHomeCard")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(tr(
                    "Не нашли нужный маршрут?",
                    "Need a different route?",
                    "Kerakli yo‘nalishni topmadingizmi?",
                    "Керакли йўналишни топмадингизми?"
                ))
                .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(tr(
                    "Для разных маршрутов можно перейти к нашему партнёру Aviasales. В iumrah Flights мы рекомендуем прямые рейсы, чтобы поездка была проще и комфортнее.",
                    "For broader route coverage you can continue with our partner Aviasales. iumrah Flights recommends non-stop flights to keep the journey simpler and more comfortable.",
                    "Turli yo‘nalishlar uchun hamkorimiz Aviasales’ga o‘tishingiz mumkin. iumrah Flights safarni qulayroq qilish uchun to‘g‘ridan-to‘g‘ri reyslarni tavsiya qiladi.",
                    "Турли йўналишлар учун ҳамкоримиз Aviasales’га ўтишингиз мумкин. iumrah Flights сафарни қулайроқ қилиш учун тўғридан-тўғри рейсларни тавсия қилади."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    if let synthetic = syntheticSearchOffer {
                        checkCurrentPrice(for: synthetic)
                    }
                    IumrahHaptics.soft()
                } label: {
                    Text("Aviasales")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: true)
                }
                .buttonStyle(.plain)

                Button {
                    searchMode = .iumrahRecommended
                    IumrahHaptics.selection()
                } label: {
                    Label("iumrah Flights", systemImage: "airplane")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.iumrahPrimaryButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var searchButton: some View {
        VStack(spacing: 9) {
            Button {
                performGlobalSearch()
            } label: {
                HStack(spacing: 10) {
                    if searchProgress > 0 && searchProgress < 1 {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.iumrahPrimaryButtonText)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(tr("Искать билеты", "Search flights", "Chiptalarni izlash", "Чипталарни излаш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(Color.iumrahPrimaryButtonText)
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(searchProgress > 0 && searchProgress < 1)
            .opacity(searchProgress > 0 && searchProgress < 1 ? 0.92 : 1)

            if searchProgress > 0 && searchProgress < 1 {
                ProgressView(value: searchProgress)
                    .progressViewStyle(.linear)
                    .animation(.linear(duration: 0.25), value: searchProgress)
            }
        }
    }

    private var recommendedFlightsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Прямые рейсы iumrah", "iumrah non-stop flights", "iumrah to‘g‘ridan-to‘g‘ri reyslari", "iumrah тўғридан-тўғри рейслари"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(tr(
                        "\(dateChipTitle) · рейсы из собственной базы iumrah — тот же источник, который использует конфигуратор пакета.",
                        "\(dateChipTitle) · flights from the iumrah database — the same source used by the package builder.",
                        "\(dateChipTitle) · iumrah bazasidagi reyslar — paket konstruktori ishlatadigan ayni manba.",
                        "\(dateChipTitle) · iumrah базасидаги рейслар — пакет конструктори ишлатадиган айни манба."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if recommendedLoading { ProgressView().controlSize(.small) }
            }

            if recommendedLoading && filteredRecommendedFlights.isEmpty {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.iumrahCardBackground)
                    .frame(height: 176)
                    .overlay { ProgressView() }
            } else if filteredRecommendedFlights.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Label(
                        tr("Пока нет опубликованных прямых рейсов по этому маршруту", "No published non-stop flights for this route yet", "Bu yo‘nalish uchun hozircha e’lon qilingan to‘g‘ri reys yo‘q", "Бу йўналиш учун ҳозирча эълон қилинган тўғри рейс йўқ"),
                        systemImage: "airplane.circle"
                    )
                    .font(.headline)
                    if let recommendedError {
                        Text(recommendedError).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(filteredRecommendedFlights) { recommendation in
                            IumrahRecommendedFlightCard(
                                language: settings.language,
                                recommendation: recommendation,
                                selected: isRecommendationSelected(recommendation)
                            ) {
                                stageRecommendedFlight(recommendation)
                            }
                            .frame(width: 318)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .scrollClipDisabled()
            }
        }
    }

    private var routeCard: some View {
        VStack(spacing: 0) {
            Button {
                originPickerPresented = true
                IumrahHaptics.soft()
            } label: {
                routeRow(
                    eyebrow: tr("Откуда", "From", "Qayerdan", "Қаердан"),
                    title: airportDisplayName(originCode),
                    code: originCode,
                    systemImage: "airplane.departure"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 62)

            Button {
                destinationPickerPresented = true
                IumrahHaptics.soft()
            } label: {
                routeRow(
                    eyebrow: tr("Куда", "To", "Qayerga", "Қаерга"),
                    title: airportDisplayName(destinationCode),
                    code: destinationCode,
                    systemImage: "airplane.arrival"
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
        .overlay(alignment: .trailing) {
            Button {
                swapRoute()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 46, height: 46)
                    .iumrahGlass(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
    }

    private func routeRow(eyebrow: String, title: String, code: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            IumrahIconBadge(systemName: systemImage, role: .travel, size: 42, symbolSize: 17, shape: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(code.uppercased())
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 56)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 86)
        .contentShape(Rectangle())
    }

    private var tripTypePicker: some View {
        Picker("", selection: $tripType) {
            Text(tr("В одну сторону", "One way", "Bir tomonga", "Бир томонга"))
                .tag(FlightDiscoveryTripType.oneWay)
            Text(tr("Туда-обратно", "Round trip", "Borib-kelish", "Бориб-келиш"))
                .tag(FlightDiscoveryTripType.roundTrip)
        }
        .pickerStyle(.segmented)
        .onChange(of: tripType) { _, value in
            if value == .roundTrip, returnDate <= departureDate {
                returnDate = Calendar.current.date(byAdding: .day, value: 7, to: departureDate) ?? departureDate
            }
            IumrahHaptics.selection()
        }
    }

    private var searchControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chipButton(
                    icon: "calendar",
                    title: dateChipTitle,
                    active: false
                ) {
                    calendarPresented = true
                }

                chipButton(
                    icon: "person.fill",
                    title: passengerChipTitle,
                    active: false
                ) {
                    passengersPresented = true
                }

                chipButton(
                    icon: "slider.horizontal.3",
                    title: directOnly
                        ? tr("Без пересадок", "Non-stop", "To‘g‘ridan-to‘g‘ri", "Тўғридан-тўғри")
                        : tr("Фильтры", "Filters", "Filtrlar", "Фильтрлар"),
                    active: directOnly
                ) {
                    filtersPresented = true
                }
            }
        }
    }

    private var recommendedSearchControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chipButton(
                    icon: "calendar",
                    title: dateChipTitle,
                    active: false
                ) {
                    calendarPresented = true
                }

                chipButton(
                    icon: "person.fill",
                    title: passengerChipTitle,
                    active: false
                ) {
                    passengersPresented = true
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.green)
                    Text(tr(
                        "Опубликованные прямые",
                        "Published non-stop",
                        "E’lon qilingan to‘g‘ri reyslar",
                        "Эълон қилинган тўғри рейслар"
                    ))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                }
                .padding(.horizontal, 15)
                .frame(height: 46)
                .background(Color.green.opacity(0.09), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.green.opacity(0.18), lineWidth: 0.8)
                }
            }
        }
    }

    private func chipButton(icon: String, title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            IumrahHaptics.soft()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(active ? Color.iumrahPrimaryButtonText : Color.primary)
            .padding(.horizontal, 15)
            .frame(height: 46)
            .background(
                active ? Color.iumrahPrimaryButtonBackground : Color.iumrahCardBackground,
                in: Capsule()
            )
            .overlay {
                if !active {
                    Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var discoveryActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
            discoveryAction(
                icon: "chart.bar.xaxis",
                title: tr("График цен", "Price chart", "Narx grafigi", "Нарх графиги"),
                tint: .blue,
                active: false
            ) {
                graphPresented = true
            }

            discoveryAction(
                icon: "airplane",
                title: tr("Прямые", "Non-stop", "To‘g‘ri", "Тўғри"),
                tint: .green,
                active: directOnly
            ) {
                directOnly.toggle()
                IumrahHaptics.selection()
            }

            discoveryAction(
                icon: "building.2.fill",
                title: tr("Авиакомпании", "Airlines", "Aviakompaniya", "Авиакомпания"),
                tint: .purple,
                active: !selectedAirlineCodes.isEmpty
            ) {
                airlinesPresented = true
            }
        }
        .scrollClipDisabled()
        }
    }

    private func discoveryAction(icon: String, title: String, tint: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(active ? .white : tint)
                    .frame(width: 36, height: 36)
                    .background(active ? tint : tint.opacity(0.12), in: Circle())
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(width: 174)
            .frame(minHeight: 68)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(resultsSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 8)

                if store.isLoading {
                    ProgressView().controlSize(.small)
                } else if !rankedOffers.isEmpty {
                    Text("\(rankedOffers.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }

                if !favorites.records.isEmpty {
                    Button {
                        favoritesPresented = true
                        IumrahHaptics.soft()
                    } label: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.iumrahCardBackground, in: Circle())
                            .overlay { Circle().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8) }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !hasSearched {
                preSearchCard
            } else if searchProgress > 0 && searchProgress < 1 && rankedOffers.isEmpty {
                searchInProgressCard
            } else if rankedOffers.isEmpty {
                emptyOffersCard
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(rankedOffers.prefix(visibleOfferCount))) { offer in
                        FlightDiscoveryTicketCard(
                            language: settings.language,
                            offer: offer,
                            currency: store.currency,
                            badges: badges(for: offer),
                            isFavorite: favorites.isFavorite(offer),
                            onFavorite: { favorites.toggle(offer, currency: store.currency, language: settings.language) }
                        ) {
                            selectedOffer = offer
                        }
                    }
                }
            }
        }
    }

    private var nearbyDealsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Выгодные даты рядом", "Nearby cheaper dates", "Yaqin qulay sanalar", "Яқин қулай саналар"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(tr(
                        "Если дата гибкая — сравните недавно найденные цены.",
                        "If your dates are flexible, compare recently found fares.",
                        "Sana moslashuvchan bo‘lsa, yaqinda topilgan narxlarni solishtiring.",
                        "Сана мослашувчан бўлса, яқинда топилган нархларни солиштиринг."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if nearbyCalendarDeals.isEmpty {
                Text(tr("Нет данных по соседним датам", "No nearby-date data", "Yaqin sanalar bo‘yicha ma’lumot yo‘q", "Яқин саналар бўйича маълумот йўқ"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(nearbyCalendarDeals.prefix(8)) { day in
                            Button {
                                if let date = dayDate(day.date) {
                                    departureDate = date
                                    IumrahHaptics.selection()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(localizedDate(day.date))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(money(day.price))
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 5) {
                                        AirlineLogoView(airlineCode: day.airlineCode, size: 20)
                                        Text(day.airlineCode)
                                            .font(.caption2.monospaced().weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(14)
                                .frame(width: 142, alignment: .leading)
                                .frame(minHeight: 112, alignment: .leading)
                                .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var searchInProgressCard: some View {
        HStack(spacing: 14) {
            ProgressView(value: searchProgress)
                .progressViewStyle(.circular)
                .controlSize(.regular)

            VStack(alignment: .leading, spacing: 4) {
                Text(tr(
                    "Ищем подходящие авиабилеты",
                    "Searching for matching flights",
                    "Mos aviachiptalar qidirilmoqda",
                    "Мос авиачипталар қидирилмоқда"
                ))
                .font(.headline)

                Text(tr(
                    "Результаты будут появляться постепенно по мере проверки доступных предложений.",
                    "Results will appear progressively while available fares are checked.",
                    "Mavjud takliflar tekshirilishi bilan natijalar bosqichma-bosqich chiqadi.",
                    "Мавжуд таклифлар текширилиши билан натижалар босқичма-босқич чиқади."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var preSearchCard: some View {
        HStack(spacing: 12) {
            IumrahIconBadge(systemName: "magnifyingglass", role: .travel, size: 44, symbolSize: 17, shape: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Выберите маршрут и даты", "Choose route and dates", "Yo‘nalish va sanalarni tanlang", "Йўналиш ва саналарни танланг"))
                    .font(.headline)
                Text(tr(
                    "После выбора нажмите «Искать билеты». Результаты появятся постепенно во время проверки.",
                    "Then tap Search flights. Results will appear progressively while the search is checked.",
                    "So‘ng «Chiptalarni izlash» tugmasini bosing. Tekshiruv davomida natijalar bosqichma-bosqich chiqadi.",
                    "Сўнг «Чипталарни излаш» тугмасини босинг. Текширув давомида натижалар босқичма-босқич чиқади."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyOffersCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                IumrahIconBadge(
                    systemName: store.errorMessage == nil ? "airplane.circle" : "wifi.exclamationmark",
                    role: .travel,
                    size: 44,
                    symbolSize: 18,
                    shape: .circle
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        store.errorMessage == nil
                            ? tr("По выбранным параметрам билеты не найдены", "No flights found for these parameters", "Tanlangan parametrlar bo‘yicha chipta topilmadi", "Танланган параметрлар бўйича чипта топилмади")
                            : tr("Не удалось обновить авиабилеты", "Could not refresh flights", "Aviachiptalarni yangilab bo‘lmadi", "Авиачипталарни янгилаб бўлмади")
                    )
                    .font(.headline)
                    Text(tr(
                        "Попробуйте соседнюю дату, измените фильтры или продолжите поиск у партнёра Aviasales.",
                        "Try a nearby date, change filters, or continue with our partner Aviasales.",
                        "Yaqin sanani tanlang, filtrlarni o‘zgartiring yoki hamkorimiz Aviasales orqali davom eting.",
                        "Яқин санани танланг, фильтрларни ўзгартиринг ёки ҳамкоримиз Aviasales орқали давом этинг."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button {
                    performGlobalSearch()
                } label: {
                    Label(tr("Обновить", "Refresh", "Yangilash", "Янгилаш"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: true)
                }
                .buttonStyle(.plain)

                Button {
                    if let synthetic = syntheticSearchOffer {
                        checkCurrentPrice(for: synthetic)
                    }
                } label: {
                    Text(tr("Искать на Aviasales", "Search Aviasales", "Aviasales'da izlash", "Aviasales'да излаш"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.iumrahPrimaryButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var selectedDateUnfilteredOffers: [FlightDiscoveryOffer] {
        let selected = IumrahFlightDiscoveryStore.dayFormatter.string(from: departureDate)
        var rows = store.offers.filter { String($0.departureAt.prefix(10)) == selected }
        if let fallback = store.calendarDays.first(where: { $0.date == selected })?.offer {
            rows.append(fallback)
        }

        var seen = Set<String>()
        return rows.filter { offer in
            let key = [
                offer.originAirport,
                offer.destinationAirport,
                offer.airlineCode,
                offer.flightNumber,
                offer.departureAt,
                String(Int(offer.price.rounded()))
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    private var selectedDateOffers: [FlightDiscoveryOffer] {
        selectedDateUnfilteredOffers.filter { offer in
            selectedAirlineCodes.isEmpty || selectedAirlineCodes.contains(offer.airlineCode.uppercased())
        }
    }

    private var rankedOffers: [FlightDiscoveryOffer] {
        selectedDateOffers.sorted { lhs, rhs in
            if lhs.isDirect != rhs.isDirect { return lhs.isDirect && !rhs.isDirect }
            if lhs.price != rhs.price { return lhs.price < rhs.price }
            if lhs.durationMinutes != rhs.durationMinutes {
                if lhs.durationMinutes <= 0 { return false }
                if rhs.durationMinutes <= 0 { return true }
                return lhs.durationMinutes < rhs.durationMinutes
            }
            return lhs.departureAt < rhs.departureAt
        }
    }

    private func badges(for offer: FlightDiscoveryOffer) -> [FlightDiscoveryBadge] {
        guard !selectedDateOffers.isEmpty else { return [] }
        var values: [FlightDiscoveryBadge] = []

        if offer.isDirect {
            values.append(.init(
                title: tr("Рекомендует iumrah", "iumrah recommends", "iumrah tavsiya qiladi", "iumrah тавсия қилади"),
                tint: .green
            ))
        }

        if let cheapest = selectedDateOffers.map(\.price).filter({ $0 > 0 }).min(), abs(offer.price - cheapest) < 0.5 {
            values.append(.init(
                title: tr("Самый дешёвый", "Cheapest", "Eng arzon", "Энг арзон"),
                tint: .orange
            ))
        }

        let durations = selectedDateOffers.map(\.durationMinutes).filter { $0 > 0 }
        if let fastest = durations.min(), offer.durationMinutes == fastest {
            values.append(.init(
                title: tr("Самый быстрый", "Fastest", "Eng tez", "Энг тез"),
                tint: .purple
            ))
        }

        return values
    }

    private var nearbyCalendarDeals: [FlightDiscoveryCalendarDay] {
        let selected = IumrahFlightDiscoveryStore.dayFormatter.string(from: departureDate)
        return store.calendarDays
            .filter { $0.date != selected }
            .sorted { lhs, rhs in
                let leftDistance = abs(dayDistance(lhs.date))
                let rightDistance = abs(dayDistance(rhs.date))
                if leftDistance != rightDistance { return leftDistance < rightDistance }
                return lhs.price < rhs.price
            }
    }

    private var resultsSubtitle: String {
        let date = shortDate(departureDate)
        if directOnly {
            return tr("\(date) · только прямые · недавно найденные цены", "\(date) · non-stop only · recently found fares", "\(date) · faqat to‘g‘ridan-to‘g‘ri · yaqinda topilgan", "\(date) · фақат тўғридан-тўғри · яқинда топилган")
        }
        return tr("\(date) · недавно найденные предложения", "\(date) · recently found fares", "\(date) · yaqinda topilgan takliflar", "\(date) · яқинда топилган таклифлар")
    }

    private func dayDistance(_ value: String) -> Int {
        guard let date = dayDate(value) else { return 9_999 }
        let start = Calendar.current.startOfDay(for: departureDate)
        let target = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents([.day], from: start, to: target).day ?? 9_999
    }

    private var syntheticSearchOffer: FlightDiscoveryOffer? {
        let departure = IumrahFlightDiscoveryStore.dayFormatter.string(from: departureDate) + "T12:00:00Z"
        return FlightDiscoveryOffer(
            id: "search-\(originCode)-\(destinationCode)-\(departure)",
            origin: originCode,
            destination: destinationCode.uppercased(),
            originAirport: originCode,
            destinationAirport: destinationCode.uppercased(),
            price: 0,
            airlineCode: "",
            flightNumber: "",
            departureAt: departure,
            returnAt: tripType == .roundTrip ? IumrahFlightDiscoveryStore.dayFormatter.string(from: returnDate) + "T12:00:00Z" : nil,
            returnAirlineCode: nil,
            returnFlightNumber: nil,
            transfers: 0,
            returnTransfers: nil,
            durationMinutes: 0,
            returnDurationMinutes: nil,
            bookingUrl: nil
        )
    }

    private var dataSourceNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(
                tr(
                    "Цены основаны на недавно найденных предложениях Aviasales. Перед бронированием актуальная цена и наличие подтверждаются отдельно.",
                    "Prices are based on recently found Aviasales fares. The current fare and availability are confirmed separately before booking.",
                    "Narxlar Aviasales’da yaqinda topilgan takliflarga asoslanadi. Bron qilishdan oldin joriy narx va mavjudlik alohida tasdiqlanadi.",
                    "Нархлар Aviasales’да яқинда топилган таклифларга асосланади. Брон қилишдан олдин жорий нарх ва мавжудлик алоҳида тасдиқланади."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private var originCode: String {
        journey.trip.originCode.uppercased()
    }

    private var dateChipTitle: String {
        let departure = shortDate(departureDate)
        guard tripType == .roundTrip else { return departure }
        return "\(departure) – \(shortDate(returnDate))"
    }

    private var passengerChipTitle: String {
        let count = adults + children + infants
        switch settings.language {
        case .russian: return "\(count), эконом"
        case .english: return "\(count), economy"
        case .uzbek: return "\(count), ekonom"
        case .uzbekCyrillic: return "\(count), эконом"
        }
    }

    private var refreshKey: String {
        let returnValue = tripType == .roundTrip ? IumrahFlightDiscoveryStore.dayFormatter.string(from: returnDate) : "oneway"
        return [
            originCode,
            destinationCode.uppercased(),
            IumrahFlightDiscoveryStore.dayFormatter.string(from: departureDate),
            returnValue,
            directOnly ? "direct" : "all"
        ].joined(separator: "|")
    }

    private func refresh() {
        store.refresh(
            origin: originCode,
            destination: destinationCode,
            departureDate: departureDate,
            returnDate: tripType == .roundTrip ? returnDate : nil,
            directOnly: directOnly
        )
    }

    private func seedFromJourneyIfNeeded() {
        guard !seededFromJourney else { return }
        seededFromJourney = true
        let today = Calendar.current.startOfDay(for: Date())
        let departure = max(Calendar.current.startOfDay(for: journey.trip.departureDate), today)
        departureDate = departure
        returnDate = journey.trip.returnDate > departure
            ? journey.trip.returnDate
            : (Calendar.current.date(byAdding: .day, value: 7, to: departure) ?? departure)
        adults = max(1, journey.trip.adults)
        children = max(0, journey.trip.children)
        infants = max(0, journey.trip.infants)
        destinationCode = journey.trip.outboundDestinationCode
        tripType = journey.trip.isRoundTripFlight ? .roundTrip : .oneWay
    }

    private func swapRoute() {
        let oldOriginAirport = journey.trip.originAirport
        let oldOriginCode = originCode
        journey.trip.originAirport = destinationAirport
        journey.trip.origin = destinationCode.uppercased()
        destinationAirport = oldOriginAirport
        destinationCode = oldOriginCode
        IumrahHaptics.selection()
    }

    private func checkCurrentPrice(for offer: FlightDiscoveryOffer) {
        // Prefer the Aviasales result path returned by Data API. Aviasales will
        // reopen the route search and can refresh the fare on its side.
        if let raw = offer.bookingUrl, let url = URL(string: raw) {
            openURL(url)
        } else if let url = aviasalesSearchURL(for: offer) {
            openURL(url)
        }
    }

    private func aviasalesSearchURL(for offer: FlightDiscoveryOffer) -> URL? {
        guard let departure = isoDate(offer.departureAt) ?? dayDate(String(offer.departureAt.prefix(10))) else {
            return offer.bookingUrl.flatMap(URL.init(string:))
        }
        let outboundToken = compactDayMonth(departure)
        let passengerToken: String
        if children == 0 && infants == 0 {
            passengerToken = String(adults)
        } else {
            passengerToken = "\(adults)\(children)\(infants)"
        }

        var params = "\(offer.origin.uppercased())\(outboundToken)\(offer.destination.uppercased())"
        if tripType == .roundTrip {
            let actualReturn = offer.returnAt.flatMap(isoDate) ?? returnDate
            params += compactDayMonth(actualReturn)
        }
        params += passengerToken
        return URL(string: "https://www.aviasales.com/search/\(params)")
    }

    private var visibleOfferCount: Int {
        guard hasSearched else { return 0 }
        guard searchProgress < 1 else { return min(20, rankedOffers.count) }
        guard !rankedOffers.isEmpty else { return 0 }
        return min(20, max(1, Int(ceil(Double(rankedOffers.count) * searchProgress))))
    }

    private var recommendedRefreshKey: String {
        "\(searchMode.rawValue)|\(originCode)|\(destinationCode.uppercased())"
    }

    private var filteredRecommendedFlights: [CuratedFlightRecommendation] {
        recommendedFlights
            .filter { item in
                let out = item.outbound
                let role = item.effectiveJourneyRole

                let routeMatches: Bool
                if role == "return" {
                    routeMatches = out.origin.uppercased() == destinationCode.uppercased() &&
                        out.destination.uppercased() == originCode
                } else {
                    routeMatches = out.origin.uppercased() == originCode &&
                        out.destination.uppercased() == destinationCode.uppercased()
                }
                guard routeMatches else { return false }

                // A one-way search should never silently add a round-trip itinerary
                // or a Saudi -> home return leg. Round-trip mode intentionally keeps
                // complete pairs and individual published legs so the user can build
                // a package from two independently published flights when needed.
                if tripType == .oneWay {
                    return role != "return" && item.inbound == nil
                }
                return true
            }
            .sorted { lhs, rhs in
                let leftPriority = recommendationRolePriority(lhs)
                let rightPriority = recommendationRolePriority(rhs)
                if leftPriority != rightPriority { return leftPriority < rightPriority }

                let leftDistance = recommendationDateScore(lhs)
                let rightDistance = recommendationDateScore(rhs)
                if leftDistance != rightDistance { return leftDistance < rightDistance }

                if lhs.outboundDate != rhs.outboundDate { return lhs.outboundDate < rhs.outboundDate }
                return lhs.id < rhs.id
            }
    }

    private func recommendationRolePriority(_ item: CuratedFlightRecommendation) -> Int {
        let role = item.effectiveJourneyRole
        let hasRoundTrip = journey.stagedUmrahFlights.contains(where: { $0.kind == .roundTrip })
        let hasOutbound = journey.stagedUmrahFlights.contains(where: { $0.kind == .outbound })
        let hasInbound = journey.stagedUmrahFlights.contains(where: { $0.kind == .inbound })

        if tripType == .roundTrip, hasOutbound, !hasInbound, !hasRoundTrip {
            return role == "return" ? 0 : (role == "complete" ? 1 : 2)
        }
        if tripType == .roundTrip, hasInbound, !hasOutbound, !hasRoundTrip {
            return role == "outbound" ? 0 : (role == "complete" ? 1 : 2)
        }

        switch role {
        case "complete": return 0
        case "outbound": return 1
        case "return": return 2
        default: return 3
        }
    }

    private func recommendationDateScore(_ item: CuratedFlightRecommendation) -> Int {
        let role = item.effectiveJourneyRole
        if role == "return" {
            return dayDistance(item.outboundDate, from: returnDate)
        }

        var score = dayDistance(item.outboundDate, from: departureDate)
        if tripType == .roundTrip, let inboundDate = item.inboundDate {
            score += dayDistance(inboundDate, from: returnDate)
        }
        return score
    }

    private func dayDistance(_ value: String, from referenceDate: Date) -> Int {
        guard let date = dayDate(value) else { return 9_999 }
        let start = Calendar.current.startOfDay(for: referenceDate)
        let target = Calendar.current.startOfDay(for: date)
        return abs(Calendar.current.dateComponents([.day], from: start, to: target).day ?? 9_999)
    }

    private func resetGlobalSearch() {
        searchRunID = UUID()
        searchProgress = 0
        hasSearched = false
    }

    private func performGlobalSearch() {
        let runID = UUID()
        searchRunID = runID
        hasSearched = true
        searchProgress = 0
        refresh()
        IumrahHaptics.soft()

        Task { @MainActor in
            for step in 1...30 {
                try? await Task.sleep(for: .milliseconds(250))
                guard searchRunID == runID else { return }
                withAnimation(.linear(duration: 0.24)) {
                    searchProgress = Double(step) / 30.0
                }
            }
        }
    }

    @MainActor
    private func loadRecommendedFlights() async {
        recommendedLoading = true
        recommendedError = nil
        defer { recommendedLoading = false }

        var trip = journey.trip
        trip.origin = originCode
        trip.originAirport = journey.trip.originAirport
        do {
            recommendedFlights = try await CuratedFlightRecommendationService.shared.load(trip: trip)
        } catch {
            recommendedFlights = []
            recommendedError = error.localizedDescription
        }
    }

    private func isRecommendationSelected(_ recommendation: CuratedFlightRecommendation) -> Bool {
        journey.stagedUmrahFlights.contains(where: { $0.id == recommendation.id })
    }

    private func stageRecommendedFlight(_ recommendation: CuratedFlightRecommendation) {
        let role = recommendation.effectiveJourneyRole
        let kind: StagedUmrahFlightKind
        if recommendation.inbound != nil || role == "complete" {
            kind = .roundTrip
            journey.selectedPublishedCompleteID = recommendation.id
            journey.selectedPublishedOutboundID = nil
            journey.selectedPublishedReturnID = nil
        } else if role == "return" {
            kind = .inbound
            journey.selectedPublishedCompleteID = nil
            journey.selectedPublishedReturnID = recommendation.id
        } else {
            kind = .outbound
            journey.selectedPublishedCompleteID = nil
            journey.selectedPublishedOutboundID = recommendation.id
        }

        journey.packageFlightPath = .publishedDirect
        let outbound = recommendation.outbound
        let inbound = recommendation.inbound
        let selection = StagedUmrahFlight(
            id: recommendation.id,
            kind: kind,
            origin: outbound.origin,
            destination: outbound.destination,
            airline: recommendation.primaryAirlineName,
            flightNumber: [outbound.airlineCode, outbound.flightNumber].filter { !$0.isEmpty }.joined(separator: " "),
            departureAt: outbound.departureAt,
            returnAt: inbound?.departureAt,
            returnAirline: inbound?.airline,
            returnFlightNumber: inbound.map { [$0.airlineCode, $0.flightNumber].filter { !$0.isEmpty }.joined(separator: " ") },
            source: "iumrah"
        )
        journey.stageUmrahFlight(selection)

        if role != "return" {
            journey.trip.origin = outbound.origin.uppercased()
            if journey.trip.originCode.uppercased() != outbound.origin.uppercased() {
                journey.trip.originAirport = nil
            }
            if ["JED", "MED"].contains(outbound.destination.uppercased()) {
                journey.trip.arrivalAirport = outbound.destination.uppercased() == "MED" ? .madinah : .jeddah
            }
            if let date = isoDate(outbound.departureAt) {
                journey.trip.departureDate = date
            }
            journey.trip.flightTripType = inbound == nil ? .oneWay : .roundTrip
        } else if let date = isoDate(outbound.departureAt) {
            journey.trip.returnDate = date
            journey.trip.flightTripType = .roundTrip
        }
        if let inbound, let date = isoDate(inbound.departureAt) {
            journey.trip.returnDate = date
            journey.trip.flightTripType = .roundTrip
        }
        IumrahHaptics.success()
    }

    private func stageDiscoveryFlightForUmrah(_ offer: FlightDiscoveryOffer) {
        let origin = offer.origin.uppercased()
        let destination = offer.destination.uppercased()
        let originSaudi = ["JED", "MED"].contains(origin)
        let destinationSaudi = ["JED", "MED"].contains(destination)

        let kind: StagedUmrahFlightKind
        if offer.isRoundTrip || (tripType == .roundTrip && offer.returnAt != nil) {
            kind = .roundTrip
        } else if originSaudi && !destinationSaudi {
            kind = .inbound
        } else {
            kind = .outbound
        }

        let selection = StagedUmrahFlight(
            id: "global:\(offer.id)",
            kind: kind,
            origin: origin,
            destination: destination,
            airline: offer.airlineName,
            flightNumber: [offer.airlineCode, offer.flightNumber].filter { !$0.isEmpty }.joined(separator: " "),
            departureAt: offer.departureAt,
            returnAt: offer.returnAt,
            returnAirline: offer.returnAirlineCode.map { FlightReferenceCatalog.airlineName(code: $0, fallback: $0) },
            returnFlightNumber: {
                let values = [offer.returnAirlineCode, offer.returnFlightNumber].compactMap { value -> String? in
                    guard let value, !value.isEmpty else { return nil }
                    return value
                }
                return values.isEmpty ? nil : values.joined(separator: " ")
            }(),
            source: "Aviasales"
        )
        journey.stageUmrahFlight(selection)
        journey.packageFlightPath = .flexibleDates
        journey.clearPublishedFlightSelection()

        if destinationSaudi {
            let currentOriginMatches = journey.trip.originCode.uppercased() == origin
            journey.trip.origin = origin
            if !currentOriginMatches { journey.trip.originAirport = nil }
            journey.trip.arrivalAirport = destination == "MED" ? .madinah : .jeddah
            journey.trip.departureDate = isoDate(offer.departureAt) ?? departureDate
            journey.trip.saudiArrivalDate = nil
        }
        if let returnValue = offer.returnAt.flatMap(isoDate) {
            journey.trip.returnDate = returnValue
            journey.trip.flightTripType = .roundTrip
        } else if kind == .inbound, let returnValue = isoDate(offer.departureAt) {
            journey.trip.returnDate = returnValue
            journey.trip.flightTripType = .roundTrip
        } else if kind == .outbound {
            journey.trip.flightTripType = .oneWay
        }
        IumrahHaptics.success()
    }

    private func airportDisplayName(_ code: String) -> String {
        guard let reference = FlightReferenceCatalog.airport(code) else { return code.uppercased() }
        switch settings.language {
        case .russian:
            switch code.uppercased() {
            case "TAS": return "Ташкент"
            case "JED": return "Джидда"
            case "MED": return "Медина"
            case "SKD": return "Самарканд"
            case "BHK": return "Бухара"
            case "FEG": return "Фергана"
            case "NMA": return "Наманган"
            default: return reference.city
            }
        case .english: return reference.city
        case .uzbek:
            switch code.uppercased() {
            case "TAS": return "Toshkent"
            case "JED": return "Jidda"
            case "MED": return "Madina"
            case "SKD": return "Samarqand"
            case "BHK": return "Buxoro"
            case "FEG": return "Farg‘ona"
            case "NMA": return "Namangan"
            default: return reference.city
            }
        case .uzbekCyrillic:
            switch code.uppercased() {
            case "TAS": return "Тошкент"
            case "JED": return "Жидда"
            case "MED": return "Мадина"
            case "SKD": return "Самарқанд"
            case "BHK": return "Бухоро"
            case "FEG": return "Фарғона"
            case "NMA": return "Наманган"
            default: return reference.city
            }
        }
    }

    private func money(_ value: Double) -> String {
        let symbol = store.currency.lowercased() == "usd" ? "$" : store.currency.uppercased() + " "
        return "\(symbol)\(Int(value.rounded()))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private func localizedDate(_ value: String) -> String {
        guard let date = dayDate(value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter.string(from: date)
    }

    private var locale: Locale {
        switch settings.language {
        case .russian: return Locale(identifier: "ru_RU")
        case .english: return Locale(identifier: "en_US")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private func dayDate(_ value: String) -> Date? {
        IumrahFlightDiscoveryStore.dayFormatter.date(from: value)
    }

    private func isoDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func compactDayMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "ddMM"
        return formatter.string(from: date)
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private struct IumrahRecommendedFlightCard: View {
    let language: AppSettingsStore.Language
    let recommendation: CuratedFlightRecommendation
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 11) {
                AirlineLogoView(airlineCode: recommendation.outbound.airlineCode, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(recommendation.primaryAirlineName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(outboundFlightNumber)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(journeyRoleTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background(Color.primary.opacity(0.07), in: Capsule())

                    Text(tr("Прямой", "Non-stop", "To‘g‘ri", "Тўғри"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background(Color.green.opacity(0.11), in: Capsule())
                }
            }

            routeLine(
                title: primaryLegTitle,
                leg: recommendation.outbound
            )

            if let inbound = recommendation.inbound {
                Divider()
                routeLine(
                    title: tr("Обратно", "Return", "Qaytish", "Қайтиш"),
                    leg: inbound
                )
            }

            Button {
                onSelect()
            } label: {
                HStack {
                    Image(systemName: selected ? "checkmark.circle.fill" : "cart.badge.plus")
                    Text(selected
                         ? tr("Добавлено в сборку", "Added to package", "Paketga qo‘shildi", "Пакетга қўшилди")
                         : tr("Добавить в сборку", "Add to package", "Paketga qo‘shish", "Пакетга қўшиш"))
                    Spacer()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(selected ? Color.green : Color.iumrahPrimaryButtonText)
                .padding(.horizontal, 15)
                .frame(height: 48)
                .background(
                    selected ? Color.green.opacity(0.1) : Color.iumrahPrimaryButtonBackground,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(selected ? Color.green.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: selected ? 1.2 : 0.8)
        }
    }

    private func routeLine(title: String, leg: CuratedFlightRecommendation.Leg) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(dateText(leg.departureAt))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeText(leg.departureAt)).font(.title3.bold())
                    Text(leg.origin.uppercased()).font(.caption.monospaced().weight(.bold)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "airplane")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.green)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeText(leg.arrivalAt)).font(.title3.bold())
                    Text(leg.destination.uppercased()).font(.caption.monospaced().weight(.bold)).foregroundStyle(.secondary)
                }
            }
            Text([leg.airlineCode, leg.flightNumber].filter { !$0.isEmpty }.joined(separator: " "))
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var primaryLegTitle: String {
        recommendation.effectiveJourneyRole == "return"
            ? tr("Обратно", "Return", "Qaytish", "Қайтиш")
            : tr("Туда", "Outbound", "Borish", "Бориш")
    }

    private var journeyRoleTitle: String {
        if recommendation.inbound != nil || recommendation.effectiveJourneyRole == "complete" {
            return tr("Туда-обратно", "Round trip", "Borib-kelish", "Бориб-келиш")
        }
        if recommendation.effectiveJourneyRole == "return" {
            return tr("Обратно", "Return", "Qaytish", "Қайтиш")
        }
        return tr("Туда", "Outbound", "Borish", "Бориш")
    }

    private var outboundFlightNumber: String {
        [recommendation.outbound.airlineCode, recommendation.outbound.flightNumber]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func timeText(_ value: String) -> String {
        guard let date = parseISO(value) else { return String(value.dropFirst(11).prefix(5)) }
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func dateText(_ value: String) -> String {
        guard let date = parseISO(value) else { return String(value.prefix(10)) }
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("dMMM EEE")
        return f.string(from: date)
    }

    private func parseISO(_ value: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f.date(from: value) { return date }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: value)
    }

    private var locale: Locale {
        switch language {
        case .russian: return Locale(identifier: "ru_RU")
        case .english: return Locale(identifier: "en_US")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct FlightDiscoveryBadge: Identifiable {
    let id = UUID()
    let title: String
    let tint: Color
}

private struct FlightDiscoveryTicketCard: View {
    let language: AppSettingsStore.Language
    let offer: FlightDiscoveryOffer
    let currency: String
    let badges: [FlightDiscoveryBadge]
    let isFavorite: Bool
    let onFavorite: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(badges) { badge in
                            Text(badge.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(badge.tint)
                                .padding(.horizontal, 9)
                                .frame(height: 25)
                                .background(badge.tint.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                Button {
                    IumrahHaptics.selection()
                    onTap()
                } label: {
                    HStack(spacing: 11) {
                        AirlineLogoView(airlineCode: offer.airlineCode, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(money(offer.price))
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(offer.airlineName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(flightNumberText)
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        IumrahHaptics.soft()
                        onFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isFavorite ? Color.red : Color.primary)
                            .frame(width: 38, height: 38)
                            .background(Color.iumrahRaisedBackground, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Text(tripTypeText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                IumrahHaptics.selection()
                onTap()
            } label: {
                VStack(spacing: 11) {
                    legRow(
                        departureTime: localTime(offer.departureAt),
                        departureDate: compactDate(offer.departureAt),
                        arrivalTime: arrivalTime(for: offer.departureAt, duration: offer.durationMinutes),
                        origin: offer.originAirport.isEmpty ? offer.origin : offer.originAirport,
                        destination: offer.destinationAirport.isEmpty ? offer.destination : offer.destinationAirport,
                        duration: durationText(offer.durationMinutes),
                        transfers: offer.transfers
                    )

                    if let returnAt = offer.returnAt, !returnAt.isEmpty {
                        Divider()
                        legRow(
                            departureTime: localTime(returnAt),
                            departureDate: compactDate(returnAt),
                            arrivalTime: arrivalTime(for: returnAt, duration: offer.returnDurationMinutes ?? 0),
                            origin: offer.destinationAirport.isEmpty ? offer.destination : offer.destinationAirport,
                            destination: offer.originAirport.isEmpty ? offer.origin : offer.originAirport,
                            duration: durationText(offer.returnDurationMinutes ?? 0),
                            transfers: offer.returnTransfers ?? 0
                        )
                        returnFlightMetaRow
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Label(dateText, systemImage: "calendar")
                Spacer()
                Text(tr("Подробнее", "Details", "Batafsil", "Батафсил"))
                    .font(.caption.weight(.bold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(15)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.065), lineWidth: 0.8)
        }
    }

    private func legRow(
        departureTime: String,
        departureDate: String,
        arrivalTime: String,
        origin: String,
        destination: String,
        duration: String,
        transfers: Int
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(departureTime)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(origin)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(.secondary)
                Text(departureDate)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text(duration)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    Circle().fill(Color.secondary.opacity(0.45)).frame(width: 5, height: 5)
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                    Image(systemName: "airplane")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(transfers == 0 ? Color.green : Color.secondary)
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                    Circle().fill(Color.secondary.opacity(0.45)).frame(width: 5, height: 5)
                }
                Text(stopsText(transfers))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(transfers == 0 ? Color.green : Color.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 2) {
                Text(arrivalTime)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(destination)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var returnFlightMetaRow: some View {
        let code = offer.returnAirlineCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let number = offer.returnFlightNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !code.isEmpty || !number.isEmpty {
            HStack(spacing: 8) {
                if !code.isEmpty {
                    AirlineLogoView(airlineCode: code, size: 24)
                } else {
                    Image(systemName: "airplane.arrival")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                        .frame(width: 24, height: 24)
                }
                Text(
                    [
                        code.isEmpty ? nil : FlightReferenceCatalog.airlineName(code: code, fallback: code),
                        [code, number].filter { !$0.isEmpty }.joined(separator: " ")
                    ]
                    .compactMap { value in
                        guard let value, !value.isEmpty else { return nil }
                        return value
                    }
                    .joined(separator: " · ")
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private var flightNumberText: String {
        let code = offer.airlineCode.isEmpty ? tr("Авиакомпания", "Airline", "Aviakompaniya", "Авиакомпания") : offer.airlineCode
        guard !offer.flightNumber.isEmpty else { return code }
        return "\(code) \(offer.flightNumber)"
    }

    private var tripTypeText: String {
        offer.isRoundTrip
            ? tr("Туда-обратно", "Round trip", "Borib-kelish", "Бориб-келиш")
            : tr("В одну сторону", "One way", "Bir tomonga", "Бир томонга")
    }

    private func durationText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let h = minutes / 60
        let m = minutes % 60
        switch language {
        case .russian: return m == 0 ? "\(h) ч" : "\(h) ч \(m) мин"
        case .english: return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        case .uzbek: return m == 0 ? "\(h) soat" : "\(h) soat \(m) daq"
        case .uzbekCyrillic: return m == 0 ? "\(h) соат" : "\(h) соат \(m) дақ"
        }
    }

    private func stopsText(_ transfers: Int) -> String {
        switch language {
        case .russian: return transfers == 0 ? "Прямой" : "\(transfers) перес."
        case .english: return transfers == 0 ? "Non-stop" : "\(transfers) stop(s)"
        case .uzbek: return transfers == 0 ? "To‘g‘ridan-to‘g‘ri" : "\(transfers) almashish"
        case .uzbekCyrillic: return transfers == 0 ? "Тўғридан-тўғри" : "\(transfers) алмашиш"
        }
    }

    private var dateText: String {
        guard let date = isoDate(offer.departureAt) else { return String(offer.departureAt.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private func compactDate(_ value: String) -> String {
        guard let date = isoDate(value) else { return String(value.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private func localTime(_ value: String) -> String {
        guard let t = value.firstIndex(of: "T") else { return "—" }
        let after = value[value.index(after: t)...]
        return String(after.prefix(5))
    }

    private func arrivalTime(for departureAt: String, duration: Int) -> String {
        guard duration > 0, let departure = isoDate(departureAt) else { return "—" }
        let arrival = departure.addingTimeInterval(TimeInterval(duration * 60))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: arrival)
    }

    private func money(_ value: Double) -> String {
        let symbol = currency.lowercased() == "usd" ? "$" : currency.uppercased() + " "
        return "\(symbol)\(Int(value.rounded()))"
    }

    private var locale: Locale {
        switch language {
        case .russian: return Locale(identifier: "ru_RU")
        case .english: return Locale(identifier: "en_US")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private func isoDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct FlightDiscoveryPassengersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppSettingsStore.Language
    @Binding var adults: Int
    @Binding var children: Int
    @Binding var infants: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                passengerRow(
                    title: tr("Взрослые", "Adults", "Kattalar", "Катталар"),
                    subtitle: tr("12 лет и старше", "12 years and older", "12 yosh va undan katta", "12 ёш ва ундан катта"),
                    value: adults,
                    canDecrement: adults > 1,
                    increment: { if total < 9 { adults += 1 } },
                    decrement: { if adults > 1 { adults -= 1 } }
                )
                Divider()
                passengerRow(
                    title: tr("Дети", "Children", "Bolalar", "Болалар"),
                    subtitle: tr("От 2 до 11 лет", "2 to 11 years", "2 yoshdan 11 yoshgacha", "2 ёшдан 11 ёшгача"),
                    value: children,
                    canDecrement: children > 0,
                    increment: { if total < 9 { children += 1 } },
                    decrement: { if children > 0 { children -= 1 } }
                )
                Divider()
                passengerRow(
                    title: tr("Младенцы", "Infants", "Chaqaloqlar", "Чақалоқлар"),
                    subtitle: tr("Младше 2 лет", "Under 2 years", "2 yoshgacha", "2 ёшгача"),
                    value: infants,
                    canDecrement: infants > 0,
                    increment: { if total < 9 { infants += 1 } },
                    decrement: { if infants > 0 { infants -= 1 } }
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(tr("Класс", "Cabin", "Klass", "Класс"))
                            .font(.headline)
                        Spacer()
                        Text(tr("Эконом", "Economy", "Ekonom", "Эконом"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    Text(tr(
                        "Data API используется для ориентировочной цены. Другие классы и точный тариф выбираются при финальной проверке.",
                        "Data API is used for indicative pricing. Other cabins and the exact fare are selected during the final check.",
                        "Data API taxminiy narx uchun ishlatiladi. Boshqa klasslar va aniq tarif yakuniy tekshiruvda tanlanadi.",
                        "Data API тахминий нарх учун ишлатилади. Бошқа класслар ва аниқ тариф якуний текширувда танланади."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 22)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text(tr("Выбрать", "Done", "Tanlash", "Танлаш"))
                        .font(.headline)
                        .foregroundStyle(Color.iumrahPrimaryButtonText)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.iumrahPageBackground)
            .navigationTitle(tr("Пассажиры", "Passengers", "Yo‘lovchilar", "Йўловчилар"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func passengerRow(
        title: String,
        subtitle: String,
        value: Int,
        canDecrement: Bool,
        increment: @escaping () -> Void,
        decrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(Color.iumrahRaisedBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement)
            .opacity(canDecrement ? 1 : 0.35)

            Text("\(value)")
                .font(.headline.monospacedDigit())
                .frame(width: 24)

            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.blue, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(total >= 9)
            .opacity(total >= 9 ? 0.45 : 1)
        }
        .padding(.vertical, 17)
    }

    private var total: Int { adults + children + infants }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct FlightDiscoveryFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppSettingsStore.Language
    @Binding var directOnly: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Toggle(isOn: $directOnly) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("Без пересадок", "Non-stop only", "Faqat to‘g‘ridan-to‘g‘ri", "Фақат тўғридан-тўғри"))
                            .font(.headline)
                        Text(tr("Показывать только прямые варианты", "Show only direct options", "Faqat to‘g‘ridan-to‘g‘ri variantlar", "Фақат тўғридан-тўғри вариантлар"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.blue)
                .padding(18)
                .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "suitcase.rolling.fill")
                        .foregroundStyle(.secondary)
                    Text(tr(
                        "Наличие багажа не входит в надёжные поля Data API, поэтому iumrah не показывает неподтверждённый багаж. Он проверяется на финальном экране продавца.",
                        "Baggage is not a reliable Data API field, so iumrah does not display unverified baggage. It is checked on the seller's final screen.",
                        "Bagaj Data API'ning ishonchli maydoni emas, shuning uchun iumrah tasdiqlanmagan bagajni ko‘rsatmaydi. U sotuvchining yakuniy ekranida tekshiriladi.",
                        "Багаж Data API'нинг ишончли майдони эмас, шунинг учун iumrah тасдиқланмаган багажни кўрсатмайди. У сотувчининг якуний экранида текширилади."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)

                Spacer()

                Button { dismiss() } label: {
                    Text(tr("Применить", "Apply", "Qo‘llash", "Қўллаш"))
                        .font(.headline)
                        .foregroundStyle(Color.iumrahPrimaryButtonText)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.iumrahPageBackground)
            .navigationTitle(tr("Фильтры", "Filters", "Filtrlar", "Фильтрлар"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct FlightDiscoveryAirlinesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppSettingsStore.Language
    let offers: [FlightDiscoveryOffer]
    @Binding var selectedCodes: Set<String>

    private var airlines: [(code: String, name: String)] {
        var seen = Set<String>()
        return offers
            .map { ($0.airlineCode.uppercased(), $0.airlineName) }
            .filter { !$0.0.isEmpty && seen.insert($0.0).inserted }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if airlines.isEmpty {
                    ContentUnavailableView(
                        tr("Нет авиакомпаний", "No airlines", "Aviakompaniyalar yo‘q", "Авиакомпаниялар йўқ"),
                        systemImage: "airplane"
                    )
                } else {
                    ForEach(airlines, id: \.code) { airline in
                        Button {
                            if selectedCodes.contains(airline.code) {
                                selectedCodes.remove(airline.code)
                            } else {
                                selectedCodes.insert(airline.code)
                            }
                            IumrahHaptics.selection()
                        } label: {
                            HStack(spacing: 12) {
                                AirlineLogoView(airlineCode: airline.code, size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(airline.name)
                                        .foregroundStyle(.primary)
                                    Text(airline.code)
                                        .font(.caption.monospaced().weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedCodes.contains(airline.code) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedCodes.contains(airline.code) ? Color.blue : Color.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(tr("Авиакомпании", "Airlines", "Aviakompaniyalar", "Авиакомпаниялар"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !selectedCodes.isEmpty {
                        Button(tr("Сбросить", "Clear", "Tozalash", "Тозалаш")) { selectedCodes.removeAll() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Готово", "Done", "Tayyor", "Тайёр")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct FlightDiscoveryFavoritesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppSettingsStore.Language
    let records: [FlightFavoriteRecord]
    let onSelect: (FlightFavoriteRecord) -> Void
    let onRemove: (FlightFavoriteRecord) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        tr("Нет сохранённых рейсов", "No saved flights", "Saqlangan reyslar yo‘q", "Сақланган рейслар йўқ"),
                        systemImage: "heart",
                        description: Text(tr(
                            "Нажмите сердечко на авиабилете, чтобы отслеживать его цену.",
                            "Tap the heart on a flight to track its price.",
                            "Narxini kuzatish uchun reysdagi yurakchani bosing.",
                            "Нархини кузатиш учун рейсдаги юракчани босинг."
                        ))
                    )
                } else {
                    List {
                        Section {
                            ForEach(records) { record in
                                Button { onSelect(record) } label: {
                                    HStack(spacing: 12) {
                                        AirlineLogoView(airlineCode: record.offer.airlineCode, size: 40)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(record.offer.routeTitle)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text("\(record.offer.airlineName) · \(money(record.lastKnownPrice, currency: record.currency))")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Text(tr("Цена отслеживается", "Price tracking is on", "Narx kuzatilmoqda", "Нарх кузатилмоқда"))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.green)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button(role: .destructive) { onRemove(record) } label: {
                                        Label(tr("Удалить", "Remove", "O‘chirish", "Ўчириш"), systemImage: "trash")
                                    }
                                }
                            }
                        } footer: {
                            Text(tr(
                                "iumrah сравнивает сохранённую цену с новыми данными при обновлении авиабилетов и уведомляет об изменении.",
                                "iumrah compares the saved fare with fresh flight data when flights refresh and notifies you about changes.",
                                "iumrah aviachiptalar yangilanganda saqlangan narxni yangi ma’lumot bilan solishtiradi va o‘zgarish haqida xabar beradi.",
                                "iumrah авиачипталар янгиланганда сақланган нархни янги маълумот билан солиштиради ва ўзгариш ҳақида хабар беради."
                            ))
                        }
                    }
                }
            }
            .navigationTitle(tr("Избранное", "Favorites", "Sevimlilar", "Севимлилар"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Закрыть", "Close", "Yopish", "Ёпиш")) { dismiss() }
                }
            }
        }
    }

    private func money(_ value: Double, currency: String) -> String {
        currency.lowercased() == "usd" ? "$\(Int(value.rounded()))" : "\(currency.uppercased()) \(Int(value.rounded()))"
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct FlightDiscoveryCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppSettingsStore.Language
    let tripType: FlightDiscoveryTripType
    let calendarDays: [FlightDiscoveryCalendarDay]
    @Binding var departureDate: Date
    @Binding var returnDate: Date

    @State private var selectingReturn = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    selectionSummary
                    ForEach(months, id: \.self) { month in
                        FlightDiscoveryMonthGrid(
                            language: language,
                            month: month,
                            priceMap: priceMap,
                            departureDate: departureDate,
                            returnDate: tripType == .roundTrip ? returnDate : nil,
                            selectingReturn: selectingReturn,
                            onSelect: select
                        )
                    }
                    Text(tr(
                        "Цены указаны за билет в одну сторону и основаны на недавних поисках Aviasales.",
                        "Prices are per one-way ticket and based on recent Aviasales searches.",
                        "Narxlar bir tomonlama chipta uchun va Aviasales'dagi yaqindagi qidiruvlarga asoslangan.",
                        "Нархлар бир томонлама чипта учун ва Aviasales'даги яқиндаги қидирувларга асосланган."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                }
                .padding(20)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle(
                selectingReturn && tripType == .roundTrip
                    ? tr("Обратная дата", "Return date", "Qaytish sanasi", "Қайтиш санаси")
                    : tr("Когда", "When", "Qachon", "Қачон")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var selectionSummary: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("Туда", "Outbound", "Borish", "Бориш"))
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text(shortDate(departureDate)).font(.headline)
            }
            Spacer()
            if tripType == .roundTrip {
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(tr("Обратно", "Return", "Qaytish", "Қайтиш"))
                        .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(shortDate(returnDate)).font(.headline)
                }
            }
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var months: [Date] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: departureDate)) ?? departureDate
        return [0, 1].compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }

    private var priceMap: [String: Double] {
        Dictionary(uniqueKeysWithValues: calendarDays.map { ($0.date, $0.price) })
    }

    private func select(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        guard day >= today else { return }

        if tripType == .oneWay {
            departureDate = day
            IumrahHaptics.selection()
            dismiss()
            return
        }

        if !selectingReturn {
            departureDate = day
            if returnDate <= day {
                returnDate = Calendar.current.date(byAdding: .day, value: 7, to: day) ?? day
            }
            selectingReturn = true
            IumrahHaptics.selection()
        } else {
            guard day > departureDate else {
                departureDate = day
                return
            }
            returnDate = day
            IumrahHaptics.success()
            dismiss()
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter.string(from: date)
    }

    private var locale: Locale {
        switch language {
        case .russian: return Locale(identifier: "ru_RU")
        case .english: return Locale(identifier: "en_US")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct FlightDiscoveryMonthGrid: View {
    let language: AppSettingsStore.Language
    let month: Date
    let priceMap: [String: Double]
    let departureDate: Date
    let returnDate: Date?
    let selectingReturn: Bool
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(monthTitle)
                .font(.system(size: 27, weight: .bold, design: .rounded))

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { value in
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 56)
                }

                ForEach(days, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let key = IumrahFlightDiscoveryStore.dayFormatter.string(from: date)
        let price = priceMap[key]
        let isPast = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
        let isDeparture = Calendar.current.isDate(date, inSameDayAs: departureDate)
        let isReturn = returnDate.map { Calendar.current.isDate(date, inSameDayAs: $0) } ?? false
        let isSelected = isDeparture || isReturn

        return Button {
            onSelect(date)
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 17, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isPast ? Color.secondary.opacity(0.4) : Color.primary)
                if let price {
                    Text("$\(Int(price.rounded()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.blue : (isLowPrice(price) ? Color.green : Color.secondary))
                } else {
                    Text(" ")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    private var days: [Date] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: month),
              let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: month)) else { return [] }
        return range.compactMap { day in
            Calendar.current.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    private var leadingBlanks: Int {
        guard let first = days.first else { return 0 }
        return max(0, Calendar.current.component(.weekday, from: first) - 1)
    }

    private var weekdaySymbols: [String] {
        let base: [String]
        switch language {
        case .russian: base = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
        case .english: base = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        case .uzbek: base = ["Ya", "Du", "Se", "Ch", "Pa", "Ju", "Sh"]
        case .uzbekCyrillic: base = ["Як", "Ду", "Се", "Чо", "Па", "Жу", "Ша"]
        }
        return base
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLLL"
        return formatter.string(from: month).capitalized(with: locale)
    }

    private var locale: Locale {
        switch language {
        case .russian: return Locale(identifier: "ru_RU")
        case .english: return Locale(identifier: "en_US")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private func isLowPrice(_ value: Double) -> Bool {
        let values = priceMap.values.sorted()
        guard !values.isEmpty else { return false }
        let index = max(0, Int(Double(values.count - 1) * 0.28))
        return value <= values[index]
    }
}

private struct FlightDiscoveryPriceGraphSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppSettingsStore.Language
    let origin: String
    let destination: String
    let initialOutboundDays: [FlightDiscoveryCalendarDay]
    let roundTrip: Bool
    @Binding var departureDate: Date
    @Binding var returnDate: Date

    @State private var directOnly = false
    @State private var outboundDays: [FlightDiscoveryCalendarDay] = []
    @State private var inboundDays: [FlightDiscoveryCalendarDay] = []
    @State private var isLoading = false

    private let service = AviasalesFlightDiscoveryService()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(origin) → \(destination)")
                            .font(.headline.monospaced().weight(.bold))
                        Text(tr("1 пассажир · эконом", "1 passenger · economy", "1 yo‘lovchi · ekonom", "1 йўловчи · эконом"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    priceSection(
                        title: tr("Вылет в \(cityName(destination))", "Departure to \(cityName(destination))", "\(cityName(destination))ga jo‘nash", "\(cityName(destination))га жўнаш"),
                        days: outboundDays,
                        selectedDate: departureDate,
                        onSelect: { date in
                            departureDate = date
                            if roundTrip, returnDate <= date {
                                returnDate = Calendar.current.date(byAdding: .day, value: 7, to: date) ?? date
                            }
                        }
                    )

                    if roundTrip {
                        priceSection(
                            title: tr("Обратно в \(cityName(origin))", "Return to \(cityName(origin))", "\(cityName(origin))ga qaytish", "\(cityName(origin))га қайтиш"),
                            days: inboundDays,
                            selectedDate: returnDate,
                            onSelect: { date in returnDate = date }
                        )
                    }

                    Toggle(isOn: $directOnly) {
                        Text(tr("Только прямые рейсы", "Non-stop flights only", "Faqat to‘g‘ridan-to‘g‘ri", "Фақат тўғридан-тўғри"))
                            .font(.headline)
                    }
                    .padding(16)
                    .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onChange(of: directOnly) { _, _ in
                        Task { await load() }
                    }

                    if let lowest = allDays.map(\.price).filter({ $0 > 0 }).min() {
                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text(tr("Найти билеты от", "Find flights from", "Chiptalarni topish", "Чипталарни топиш"))
                                Text("$\(Int(lowest.rounded()))")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(height: 58)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .overlay {
                if isLoading && outboundDays.isEmpty {
                    ProgressView()
                }
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle(tr("График цен", "Price chart", "Narx grafigi", "Нарх графиги"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                }
            }
            .task {
                outboundDays = initialOutboundDays
                await load()
            }
        }
    }

    private var allDays: [FlightDiscoveryCalendarDay] { outboundDays + inboundDays }

    @ViewBuilder
    private func priceSection(
        title: String,
        days: [FlightDiscoveryCalendarDay],
        selectedDate: Date,
        onSelect: @escaping (Date) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            if days.isEmpty {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.iumrahCardBackground)
                    .frame(height: 148)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(tr("Нет данных по этим датам", "No fare data for these dates", "Bu sanalar uchun ma’lumot yo‘q", "Бу саналар учун маълумот йўқ"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(days.sorted(by: { $0.date < $1.date })) { day in
                            graphBar(day, days: days, selectedDate: selectedDate, onSelect: onSelect)
                        }
                    }
                    .padding(.horizontal, 2)
                    .frame(height: 166, alignment: .bottom)
                }
            }
        }
    }

    private func graphBar(
        _ day: FlightDiscoveryCalendarDay,
        days: [FlightDiscoveryCalendarDay],
        selectedDate: Date,
        onSelect: @escaping (Date) -> Void
    ) -> some View {
        let prices = days.map(\.price).filter { $0 > 0 }
        let minPrice = max(prices.min() ?? 1, 1)
        let maxPrice = max(prices.max() ?? minPrice, minPrice)
        let spread = max(maxPrice - minPrice, 1)
        let normalized = (day.price - minPrice) / spread
        let height = CGFloat(40 + max(0, min(1, normalized)) * 70)
        let selected = IumrahFlightDiscoveryStore.dayFormatter.string(from: selectedDate) == day.date
        let cheapest = abs(day.price - minPrice) < 0.5
        let tint: Color = selected ? .blue : (cheapest ? .green : Color.secondary.opacity(0.24))

        return Button {
            if let date = IumrahFlightDiscoveryStore.dayFormatter.date(from: day.date) {
                onSelect(date)
                IumrahHaptics.selection()
            }
        } label: {
            VStack(spacing: 6) {
                if selected || cheapest {
                    Text("от $\(Int(day.price.rounded()))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(selected ? Color.blue : Color.green)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.caption2)
                }

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tint)
                    .frame(width: 28, height: height)

                Text(dayNumber(day.date))
                    .font(.caption2.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? Color.blue : Color.secondary)
            }
            .frame(width: 34)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        let outboundMonth = IumrahFlightDiscoveryStore.monthFormatter.string(from: departureDate)
        if let result = try? await service.calendar(
            origin: origin,
            destination: destination,
            month: outboundMonth,
            direct: directOnly
        ) {
            outboundDays = result.days
        }

        if roundTrip {
            let inboundMonth = IumrahFlightDiscoveryStore.monthFormatter.string(from: returnDate)
            if let result = try? await service.calendar(
                origin: destination,
                destination: origin,
                month: inboundMonth,
                direct: directOnly
            ) {
                inboundDays = result.days
            }
        } else {
            inboundDays = []
        }
    }

    private func dayNumber(_ value: String) -> String {
        guard let date = IumrahFlightDiscoveryStore.dayFormatter.date(from: value) else { return value }
        return String(Calendar.current.component(.day, from: date))
    }

    private func cityName(_ code: String) -> String {
        FlightReferenceCatalog.airport(code)?.city ?? code
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct FlightDiscoveryOfferDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var favorites = FlightFavoritesStore.shared
    @State private var livePrice: Double?
    @State private var refreshedOffer: FlightDiscoveryOffer?
    @State private var isRefreshingPrice = false
    @State private var cartAnimationVisible = false
    @State private var cartAnimationDropped = false
    @State private var cartConfirmationVisible = false

    let language: AppSettingsStore.Language
    let offer: FlightDiscoveryOffer
    let adults: Int
    let children: Int
    let infants: Int
    let fallbackReturnDate: Date?
    let currency: String
    let canBuildUmrah: Bool
    let onCheckPrice: (FlightDiscoveryOffer) -> Void
    let onBuildUmrah: (FlightDiscoveryOffer) -> Void

    private var activeOffer: FlightDiscoveryOffer {
        refreshedOffer ?? offer
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                priceHero
                tripSummaryCard
                fareConditionsCard
                outboundCard

                if hasReturn {
                    returnCard
                }

                monitoringCard
                warningCard

                Button {
                    onCheckPrice(activeOffer)
                } label: {
                    HStack {
                        if isRefreshingPrice {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "airplane.circle.fill")
                        }
                        Text(tr("Проверить и купить", "Check fare & buy", "Narxni tekshirish va sotib olish", "Нархни текшириш ва сотиб олиш"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.headline)
                    .foregroundStyle(Color.iumrahPrimaryButtonText)
                    .padding(.horizontal, 18)
                    .frame(height: 60)
                    .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)

                if canBuildUmrah {
                    Button {
                        animateCartDrop()
                        onBuildUmrah(activeOffer)
                    } label: {
                        HStack {
                            Image(systemName: "cart.badge.plus")
                            Text(tr("Добавить рейс в сборку Umrah", "Add flight to Umrah package", "Reysni Umra paketiga qo‘shish", "Рейсни Умра пакетига қўшиш"))
                            Spacer()
                            Image(systemName: "arrow.down.to.line")
                        }
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(cartAnimationVisible)
                }
            }
            .padding(20)
        }
        .background(Color.iumrahPageBackground)
        .refreshable {
            await refreshCurrentFare()
        }
        .navigationTitle(tr("Авиабилет", "Flight", "Aviachipta", "Авиачипта"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(activeOffer, currency: currency, language: language)
                    IumrahHaptics.soft()
                } label: {
                    Image(systemName: favorites.isFavorite(activeOffer) ? "heart.fill" : "heart")
                        .foregroundStyle(favorites.isFavorite(activeOffer) ? Color.red : Color.primary)
                }

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            await refreshCurrentFare()
        }
        .overlay {
            GeometryReader { proxy in
                if cartAnimationVisible {
                    let targetY = max(190, proxy.size.height - 54)

                    ZStack {
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(tr("Сборка Umrah", "Umrah package", "Umra paketi", "Умра пакети"))
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(.regularMaterial, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.green.opacity(0.22), lineWidth: 0.8)
                        }
                        .position(x: proxy.size.width / 2, y: targetY)

                        Image(systemName: "ticket.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(13)
                            .background(.thinMaterial, in: Circle())
                            .position(
                                x: proxy.size.width / 2,
                                y: cartAnimationDropped ? targetY : max(90, proxy.size.height * 0.17)
                            )
                            .rotationEffect(.degrees(cartAnimationDropped ? 8 : -8))
                            .scaleEffect(cartAnimationDropped ? 0.34 : 1)
                            .opacity(cartAnimationDropped ? 0.08 : 1)
                            .animation(
                                reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.72, dampingFraction: 0.78),
                                value: cartAnimationDropped
                            )
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if cartConfirmationVisible {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(cartConfirmationText)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(15)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var priceHero: some View {
        VStack(spacing: 13) {
            Text(tripTypeTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(hasReturn ? Color.blue : Color.secondary)
                .padding(.horizontal, 11)
                .frame(height: 27)
                .background((hasReturn ? Color.blue : Color.secondary).opacity(0.11), in: Capsule())

            Text(money(livePrice ?? activeOffer.price))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .tracking(-1)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let livePrice, abs(livePrice - offer.price) >= 0.5 {
                Text(tr(
                    "Цена обновлена при открытии · было \(money(offer.price))",
                    "Price refreshed on open · was \(money(offer.price))",
                    "Sahifa ochilganda narx yangilandi · oldin \(money(offer.price))",
                    "Саҳифа очилганда нарх янгиланди · олдин \(money(offer.price))"
                ))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            } else if isRefreshingPrice {
                Text(tr("Обновляем актуальную цену…", "Refreshing current fare…", "Joriy narx yangilanmoqda…", "Жорий нарх янгиланмоқда…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(passengerPriceCaption)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                AirlineLogoView(airlineCode: activeOffer.airlineCode, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(activeOffer.airlineName)
                        .font(.headline)
                    Text(flightNumberText)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(activeOffer.routeTitle)
                    .font(.subheadline.monospaced().weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var tripSummaryCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(tr("Маршрут билета", "Ticket itinerary", "Chipta yo‘nalishi", "Чипта йўналиши"))
                .font(.headline)

            summaryLeg(
                icon: "airplane.departure",
                route: "\(outboundOrigin) → \(outboundDestination)",
                date: dateOnly(activeOffer.departureAt),
                flight: flightNumberText
            )

            if let returnAt = effectiveReturnAt {
                Divider()
                summaryLeg(
                    icon: "airplane.arrival",
                    route: "\(outboundDestination) → \(outboundOrigin)",
                    date: dateOnly(returnAt),
                    flight: returnFlightNumberText
                )
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func summaryLeg(icon: String, route: String, date: String, flight: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(route)
                    .font(.headline.monospaced())
                Text(date)
                    .font(.subheadline.weight(.semibold))
                Text(flight)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var fareConditionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Условия тарифа", "Fare conditions", "Tarif shartlari", "Тариф шартлари"))
                .font(.title3.bold())

            conditionRow(icon: "bag.fill", tint: .green, title: tr("Ручная кладь и багаж", "Cabin & checked baggage", "Qo‘l yuki va bagaj", "Қўл юки ва багаж"), value: tr("Уточняются при проверке тарифа", "Confirmed during live fare check", "Tarif tekshirilganda aniqlanadi", "Тариф текширилганда аниқланади"))
            conditionRow(icon: activeOffer.isDirect ? "checkmark.circle.fill" : "arrow.triangle.branch", tint: activeOffer.isDirect ? .green : .orange, title: tr("Маршрут", "Route", "Yo‘nalish", "Йўналиш"), value: directText(transfers: activeOffer.transfers))
            conditionRow(icon: "arrow.uturn.backward.circle", tint: .secondary, title: tr("Обмен и возврат", "Changes & refunds", "Almashtirish va qaytarish", "Алмаштириш ва қайтариш"), value: tr("По правилам тарифа продавца", "According to seller fare rules", "Sotuvchi tarifi qoidalariga ko‘ra", "Сотувчи тарифи қоидаларига кўра"))

            if hasReturn {
                conditionRow(icon: "arrow.left.arrow.right", tint: .blue, title: tr("Тип билета", "Ticket type", "Chipta turi", "Чипта тури"), value: tripTypeTitle)
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var outboundCard: some View {
        flightLegCard(
            title: "\(airportCity(outboundOrigin)) — \(airportCity(outboundDestination))",
            subtitle: tr("Перелёт туда", "Outbound flight", "Borish reysi", "Бориш рейси"),
            departureAt: activeOffer.departureAt,
            origin: outboundOrigin,
            destination: outboundDestination,
            duration: activeOffer.durationMinutes,
            transfers: activeOffer.transfers,
            flightNumber: flightNumberText,
            showAirline: true
        )
    }

    @ViewBuilder
    private var returnCard: some View {
        if let returnAt = effectiveReturnAt {
            flightLegCard(
                title: "\(airportCity(outboundDestination)) — \(airportCity(outboundOrigin))",
                subtitle: tr("Обратный перелёт", "Return flight", "Qaytish reysi", "Қайтиш рейси"),
                departureAt: returnAt,
                origin: outboundDestination,
                destination: outboundOrigin,
                duration: activeOffer.returnDurationMinutes ?? 0,
                transfers: activeOffer.returnTransfers ?? 0,
                flightNumber: returnFlightNumberText,
                showAirline: activeOffer.returnAirlineCode != nil
            )
        } else {
            EmptyView()
        }
    }

    private func flightLegCard(
        title: String,
        subtitle: String,
        departureAt: String,
        origin: String,
        destination: String,
        duration: Int,
        transfers: Int,
        flightNumber: String,
        showAirline: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.bold())
                Text("\(durationText(duration)) · \(directText(transfers: transfers))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if showAirline {
                    AirlineLogoView(airlineCode: subtitle == tr("Обратный перелёт", "Return flight", "Qaytish reysi", "Қайтиш рейси") ? (activeOffer.returnAirlineCode ?? activeOffer.airlineCode) : activeOffer.airlineCode, size: 44)
                } else {
                    Image(systemName: "airplane")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1), in: Circle())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        showAirline
                            ? (subtitle == tr("Обратный перелёт", "Return flight", "Qaytish reysi", "Қайтиш рейси")
                                ? FlightReferenceCatalog.airlineName(code: activeOffer.returnAirlineCode ?? activeOffer.airlineCode, fallback: activeOffer.returnAirlineCode ?? activeOffer.airlineCode)
                                : activeOffer.airlineName)
                            : tr("Обратный рейс", "Return flight", "Qaytish reysi", "Қайтиш рейси")
                    )
                        .font(.headline)
                    Text(flightNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            flightTimeline(
                departureAt: departureAt,
                duration: duration,
                origin: origin,
                destination: destination
            )
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func flightTimeline(departureAt: String, duration: Int, origin: String, destination: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Circle().strokeBorder(Color.secondary, lineWidth: 3).frame(width: 13, height: 13)
                Rectangle().fill(Color.secondary.opacity(0.45)).frame(width: 2, height: 62)
                Circle().strokeBorder(Color.secondary, lineWidth: 3).frame(width: 13, height: 13)
            }
            .padding(.top, 5)

            VStack(alignment: .leading, spacing: 24) {
                timelineRow(time: localTime(departureAt), date: dateOnly(departureAt), city: airportCity(origin), code: origin)
                timelineRow(time: arrivalTime(departureAt: departureAt, duration: duration), date: arrivalDate(departureAt: departureAt, duration: duration), city: airportCity(destination), code: destination)
            }
        }
    }

    private func timelineRow(time: String, date: String, city: String, code: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(time)
                    .font(.title3.bold())
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 82, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(city)
                    .font(.headline)
                Text(code)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var monitoringCard: some View {
        Button {
            favorites.toggle(activeOffer, currency: currency, language: language)
            IumrahHaptics.soft()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: favorites.isFavorite(activeOffer) ? "bell.badge.fill" : "heart")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(favorites.isFavorite(activeOffer) ? Color.green : Color.red)
                    .frame(width: 42, height: 42)
                    .background((favorites.isFavorite(activeOffer) ? Color.green : Color.red).opacity(0.11), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(favorites.isFavorite(activeOffer)
                         ? tr("Цена отслеживается", "Price tracking is on", "Narx kuzatilmoqda", "Нарх кузатилмоқда")
                         : tr("Сохранить и следить за ценой", "Save & track price", "Saqlash va narxni kuzatish", "Сақлаш ва нархни кузатиш"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(tr(
                        "iumrah уведомит, когда при обновлении найдёт другую цену на этот рейс.",
                        "iumrah will notify you when refreshed flight data shows a different fare.",
                        "Yangilangan ma’lumotda boshqa narx topilsa, iumrah xabar beradi.",
                        "Янгиланган маълумотда бошқа нарх топилса, iumrah хабар беради."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: favorites.isFavorite(activeOffer) ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(favorites.isFavorite(activeOffer) ? Color.green : Color.secondary)
            }
            .padding(16)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .foregroundStyle(.orange)
            Text(tr(
                "Это недавно найденная цена. Перед оплатой iumrah откроет актуальную проверку тарифа, багажа и наличия мест.",
                "This is a recently found fare. Before payment, iumrah opens a live check for fare, baggage and seat availability.",
                "Bu yaqinda topilgan narx. To‘lovdan oldin iumrah tarif, bagaj va joylar mavjudligini jonli tekshiradi.",
                "Бу яқинда топилган нарх. Тўловдан олдин iumrah тариф, багаж ва жойлар мавжудлигини жонли текширади."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @MainActor
    private func refreshCurrentFare() async {
        guard !isRefreshingPrice else { return }
        isRefreshingPrice = true
        defer { isRefreshingPrice = false }

        let baseOffer = activeOffer
        let departure = String(baseOffer.departureAt.prefix(10))
        let returnDay = effectiveReturnAt.map { String($0.prefix(10)) }

        do {
            let response = try await AviasalesFlightDiscoveryService().offers(
                origin: baseOffer.origin,
                destination: baseOffer.destination,
                departure: departure,
                returnAt: returnDay,
                direct: baseOffer.isDirect,
                limit: 100,
                currency: currency
            )

            let routeCandidates = response.offers.filter { candidate in
                guard candidate.origin.caseInsensitiveCompare(baseOffer.origin) == .orderedSame,
                      candidate.destination.caseInsensitiveCompare(baseOffer.destination) == .orderedSame,
                      String(candidate.departureAt.prefix(10)) == departure else {
                    return false
                }

                if let returnDay {
                    guard let candidateReturn = candidate.returnAt, !candidateReturn.isEmpty else { return false }
                    return String(candidateReturn.prefix(10)) == returnDay
                }
                return true
            }

            let sameOutbound = routeCandidates.filter { candidate in
                flightIdentityMatches(
                    candidateCode: candidate.airlineCode,
                    candidateNumber: candidate.flightNumber,
                    expectedCode: baseOffer.airlineCode,
                    expectedNumber: baseOffer.flightNumber
                )
            }

            let current = sameOutbound.max { lhs, rhs in
                returnIdentityScore(lhs, comparedTo: baseOffer) < returnIdentityScore(rhs, comparedTo: baseOffer)
            }

            guard let current, current.price > 0 else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                refreshedOffer = current
                livePrice = current.price
            }
        } catch {
            // Keep the cached fare visible if the live refresh is temporarily unavailable.
        }
    }

    private func flightIdentityMatches(
        candidateCode: String,
        candidateNumber: String,
        expectedCode: String,
        expectedNumber: String
    ) -> Bool {
        let expectedAirline = expectedCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let candidateAirline = candidateCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if !expectedAirline.isEmpty && expectedAirline != candidateAirline {
            return false
        }

        let expectedFlight = canonicalFlightNumber(expectedNumber, airlineCode: expectedAirline)
        guard !expectedFlight.isEmpty else { return true }

        let candidateFlight = canonicalFlightNumber(candidateNumber, airlineCode: candidateAirline)
        return candidateFlight == expectedFlight
    }

    private func returnIdentityScore(_ candidate: FlightDiscoveryOffer, comparedTo expected: FlightDiscoveryOffer) -> Int {
        var score = 0

        let expectedCode = expected.returnAirlineCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let candidateCode = candidate.returnAirlineCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        if !expectedCode.isEmpty, expectedCode == candidateCode { score += 2 }

        let expectedNumber = canonicalFlightNumber(expected.returnFlightNumber ?? "", airlineCode: expectedCode)
        let candidateNumber = canonicalFlightNumber(candidate.returnFlightNumber ?? "", airlineCode: candidateCode)
        if !expectedNumber.isEmpty, expectedNumber == candidateNumber { score += 4 }

        if candidate.returnAt != nil { score += 1 }
        return score
    }

    private func canonicalFlightNumber(_ value: String, airlineCode: String) -> String {
        var token = value.uppercased().filter { $0.isLetter || $0.isNumber }
        let code = airlineCode.uppercased().filter { $0.isLetter || $0.isNumber }
        if !code.isEmpty, token.hasPrefix(code) {
            token.removeFirst(code.count)
        }
        return token
    }

    private func animateCartDrop() {
        guard !cartAnimationVisible else { return }

        cartAnimationVisible = true
        cartAnimationDropped = false
        cartConfirmationVisible = false
        IumrahHaptics.success()

        let dropDelay = reduceMotion ? 0.02 : 0.04
        let landingDelay = reduceMotion ? 0.22 : 0.78

        DispatchQueue.main.asyncAfter(deadline: .now() + dropDelay) {
            cartAnimationDropped = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + landingDelay) {
            cartAnimationVisible = false
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.35, dampingFraction: 0.82)) {
                cartConfirmationVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + landingDelay + 2.7) {
            withAnimation(.easeOut(duration: 0.25)) {
                cartConfirmationVisible = false
            }
        }
    }

    private var cartConfirmationText: String {
        if activeOffer.isRoundTrip {
            return tr(
                "Билет туда‑обратно добавлен в сборку Umrah. Второй авиабилет выбирать не нужно.",
                "Round-trip flight added to your Umrah package. You do not need to choose another flight.",
                "Borib-kelish chiptasi Umra paketiga qo‘shildi. Boshqa chipta tanlash shart emas.",
                "Бориб-келиш чиптаси Умра пакетига қўшилди. Бошқа чипта танлаш шарт эмас."
            )
        }
        if ["JED", "MED"].contains(activeOffer.origin.uppercased()) {
            return tr(
                "Обратный рейс добавлен в сборку Umrah.",
                "Return flight added to your Umrah package.",
                "Qaytish reysi Umra paketiga qo‘shildi.",
                "Қайтиш рейси Умра пакетига қўшилди."
            )
        }
        return tr(
            "Рейс туда добавлен в сборку Umrah. Теперь можно выбрать обратный рейс.",
            "Outbound flight added to your Umrah package. You can now choose the return flight.",
            "Borish reysi Umra paketiga qo‘shildi. Endi qaytish reysini tanlashingiz mumkin.",
            "Бориш рейси Умра пакетига қўшилди. Энди қайтиш рейсини танлашингиз мумкин."
        )
    }

    private func conditionRow(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var hasReturn: Bool { activeOffer.isRoundTrip || fallbackReturnDate != nil }

    private var effectiveReturnAt: String? {
        if let returnAt = activeOffer.returnAt, !returnAt.isEmpty { return returnAt }
        guard let fallbackReturnDate else { return nil }
        let date = IumrahFlightDiscoveryStore.dayFormatter.string(from: fallbackReturnDate)
        return date + "T12:00:00Z"
    }

    private var outboundOrigin: String { activeOffer.originAirport.isEmpty ? activeOffer.origin : activeOffer.originAirport }
    private var outboundDestination: String { activeOffer.destinationAirport.isEmpty ? activeOffer.destination : activeOffer.destinationAirport }

    private var tripTypeTitle: String {
        hasReturn
            ? tr("Туда и обратно", "Round trip", "Borib-kelish", "Бориб-келиш")
            : tr("Только туда", "One way", "Faqat borish", "Фақат бориш")
    }

    private var passengerPriceCaption: String {
        let count = max(1, adults + children + infants)
        if count == 1 {
            return tr("за 1 пассажира", "for 1 passenger", "1 yo‘lovchi uchun", "1 йўловчи учун")
        }
        return tr(
            "за 1 пассажира · выбрано \(count)",
            "per passenger · \(count) selected",
            "1 yo‘lovchi uchun · \(count) tanlangan",
            "1 йўловчи учун · \(count) танланган"
        )
    }

    private var flightNumberText: String {
        if activeOffer.airlineCode.isEmpty && activeOffer.flightNumber.isEmpty { return tr("Рейс", "Flight", "Reys", "Рейс") }
        return [activeOffer.airlineCode, activeOffer.flightNumber].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private var returnFlightNumberText: String {
        let values = [activeOffer.returnAirlineCode, activeOffer.returnFlightNumber]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
        if !values.isEmpty { return values.joined(separator: " ") }
        return tr(
            "Точный обратный рейс уточняется",
            "Exact return flight pending",
            "Aniq qaytish reysi tekshiruvda",
            "Аниқ қайтиш рейси текширувда"
        )
    }

    private var shareText: String {
        let returnPart = hasReturn ? " · \(tripTypeTitle)" : ""
        return "iumrah · \(activeOffer.routeTitle)\(returnPart) · \(activeOffer.airlineName) · \(money(activeOffer.price))"
    }

    private func directText(transfers: Int) -> String {
        switch language {
        case .russian: return transfers == 0 ? "Прямой рейс" : "\(transfers) пересадка"
        case .english: return transfers == 0 ? "Non-stop" : "\(transfers) stop(s)"
        case .uzbek: return transfers == 0 ? "To‘g‘ridan-to‘g‘ri" : "\(transfers) almashish"
        case .uzbekCyrillic: return transfers == 0 ? "Тўғридан-тўғри" : "\(transfers) алмашиш"
        }
    }

    private func durationText(_ minutes: Int) -> String {
        guard minutes > 0 else { return tr("Время уточняется", "Duration pending", "Vaqt aniqlanmoqda", "Вақт аниқланмоқда") }
        let h = minutes / 60
        let m = minutes % 60
        switch language {
        case .russian: return m == 0 ? "\(h) ч" : "\(h) ч \(m) мин"
        case .english: return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        case .uzbek: return m == 0 ? "\(h) soat" : "\(h) soat \(m) daq"
        case .uzbekCyrillic: return m == 0 ? "\(h) соат" : "\(h) соат \(m) дақ"
        }
    }

    private func localTime(_ value: String) -> String {
        guard let date = isoDate(value) else { return String(value.suffix(5)) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dateOnly(_ value: String) -> String {
        guard let date = isoDate(value) else { return String(value.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM EEE")
        return formatter.string(from: date)
    }

    private func arrivalTime(departureAt: String, duration: Int) -> String {
        guard duration > 0, let departure = isoDate(departureAt) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: departure.addingTimeInterval(TimeInterval(duration * 60)))
    }

    private func arrivalDate(departureAt: String, duration: Int) -> String {
        guard duration > 0, let departure = isoDate(departureAt) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM EEE")
        return formatter.string(from: departure.addingTimeInterval(TimeInterval(duration * 60)))
    }

    private func airportCity(_ code: String) -> String {
        FlightReferenceCatalog.airport(code)?.city ?? code
    }

    private func money(_ value: Double) -> String {
        currency.lowercased() == "usd"
            ? "$\(Int(value.rounded()))"
            : "\(currency.uppercased()) \(Int(value.rounded()))"
    }

    private var locale: Locale {
        switch language {
        case .russian: return Locale(identifier: "ru_RU")
        case .english: return Locale(identifier: "en_US")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private func isoDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}
