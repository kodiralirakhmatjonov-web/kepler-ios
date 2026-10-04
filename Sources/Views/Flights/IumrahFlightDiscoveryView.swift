import SwiftUI

private enum FlightDiscoveryTripType: String, CaseIterable, Identifiable {
    case oneWay
    case roundTrip

    var id: String { rawValue }
}

struct IumrahFlightDiscoveryView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.openURL) private var openURL

    @StateObject private var store = IumrahFlightDiscoveryStore()

    @State private var destinationAirport: Airport?
    @State private var destinationCode = "JED"
    @State private var tripType: FlightDiscoveryTripType = .oneWay
    @State private var departureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var returnDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var adults = 1
    @State private var children = 0
    @State private var infants = 0
    @State private var directOnly = false

    @State private var originPickerPresented = false
    @State private var destinationPickerPresented = false
    @State private var routeMapPresented = false
    @State private var calendarPresented = false
    @State private var passengersPresented = false
    @State private var filtersPresented = false
    @State private var graphPresented = false
    @State private var directFlightsPresented = false
    @State private var selectedOffer: FlightDiscoveryOffer?
    @State private var seededFromJourney = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            routeCard
            tripTypePicker
            searchControls
            searchResultsSection
            discoveryActions
            nearbyDealsSection
            dataSourceNote
        }
        .task {
            seedFromJourneyIfNeeded()
            refresh()
        }
        .onChange(of: refreshKey) { _, _ in
            refresh()
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
        .fullScreenCover(isPresented: $routeMapPresented) {
            AirportRouteMapPickerView(
                origin: $journey.trip.originAirport,
                originCode: $journey.trip.origin,
                destination: $destinationAirport,
                destinationCode: $destinationCode
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
                days: store.calendarDays,
                selectedDate: departureDate
            )
        }
        .sheet(isPresented: $directFlightsPresented) {
            FlightDiscoveryDirectFlightsSheet(
                language: settings.language,
                origin: originCode,
                destination: destinationCode.uppercased(),
                offers: store.directOffers,
                isLoading: store.isLoadingDirect,
                onSelect: { offer in
                    directFlightsPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        selectedOffer = offer
                    }
                }
            )
        }
        .navigationDestination(item: $selectedOffer) { offer in
            FlightDiscoveryOfferDetailView(
                language: settings.language,
                offer: offer,
                currency: store.currency,
                adults: adults,
                children: children,
                infants: infants,
                fallbackReturnDate: tripType == .roundTrip ? returnDate : nil,
                canBuildUmrah: ["JED", "MED"].contains(offer.destination.uppercased()),
                onBuy: { refreshedOffer in checkCurrentPrice(for: refreshedOffer) },
                onBuildUmrah: { refreshedOffer in useDatesForUmrah(refreshedOffer) }
            )
        }
        .onChange(of: destinationAirport) { _, airport in
            if let airport { destinationCode = airport.iata.uppercased() }
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
                    icon: "globe.europe.africa.fill",
                    title: tr("На карте", "Map", "Xaritada", "Харитада"),
                    active: false
                ) {
                    routeMapPresented = true
                }

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
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Как добраться", "How to get there", "Qanday yetib borish", "Қандай етиб бориш"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.5)

            HStack(spacing: 12) {
                discoveryAction(
                    icon: "chart.bar.xaxis",
                    title: tr("График цен", "Price chart", "Narx grafigi", "Нарх графиги"),
                    tint: .blue
                ) {
                    graphPresented = true
                }

                discoveryAction(
                    icon: "calendar.badge.clock",
                    title: tr("Прямые рейсы", "Direct flights", "To‘g‘ridan-to‘g‘ri", "Тўғридан-тўғри"),
                    tint: .purple
                ) {
                    store.loadDirectFlights(origin: originCode, destination: destinationCode, monthDate: departureDate)
                    directFlightsPresented = true
                }
            }
        }
    }

    private func discoveryAction(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12), in: Circle())
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Авиабилеты", "Flights", "Aviachiptalar", "Авиачипталар"))
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .tracking(-0.55)
                    Text(resultsSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isLoading {
                    ProgressView().controlSize(.small)
                } else if !selectedDateOffers.isEmpty {
                    Text("\(selectedDateOffers.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
            }

            if selectedDateOffers.isEmpty {
                emptyOffersCard
            } else {
                flightCarouselSection(
                    title: tr("Самые дешёвые", "Cheapest", "Eng arzon", "Энг арзон"),
                    subtitle: tr("Сначала показываем минимальную цену", "Lowest fares first", "Eng past narxlar birinchi", "Энг паст нархлар биринчи"),
                    offers: cheapestOffers,
                    badge: tr("Выгодно", "Best price", "Qulay narx", "Қулай нарх"),
                    badgeIcon: "arrow.down.circle.fill"
                )

                if !directDateOffers.isEmpty {
                    flightCarouselSection(
                        title: tr("Прямые рейсы", "Non-stop flights", "To‘g‘ridan-to‘g‘ri reyslar", "Тўғридан-тўғри рейслар"),
                        subtitle: tr("Без пересадок по выбранному маршруту", "No connections on your selected route", "Tanlangan yo‘nalishda almashishsiz", "Танланган йўналишда алмашишсиз"),
                        offers: directDateOffers,
                        badge: tr("Прямой", "Non-stop", "To‘g‘ridan-to‘g‘ri", "Тўғридан-тўғри"),
                        badgeIcon: "airplane"
                    )
                }

                if selectedDateOffers.count > 1 {
                    flightCarouselSection(
                        title: tr("Рекомендует iumrah", "iumrah recommends", "iumrah tavsiya qiladi", "iumrah тавсия қилади"),
                        subtitle: tr("Баланс цены, времени в пути и пересадок", "Balanced by fare, travel time and stops", "Narx, yo‘l va almashishlar bo‘yicha muvozanat", "Нарх, йўл ва алмашишлар бўйича мувозанат"),
                        offers: recommendedOffers,
                        badge: tr("Выбор iumrah", "iumrah pick", "iumrah tanlovi", "iumrah танлови"),
                        badgeIcon: "sparkles"
                    )
                }

                if !fastestOffers.isEmpty {
                    flightCarouselSection(
                        title: tr("Самые быстрые", "Fastest", "Eng tez", "Энг тез"),
                        subtitle: tr("Минимальное время в пути", "Shortest travel time", "Eng qisqa yo‘l vaqti", "Энг қисқа йўл вақти"),
                        offers: fastestOffers,
                        badge: tr("Быстрее", "Fast", "Tez", "Тез"),
                        badgeIcon: "bolt.fill"
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("Все рейсы", "All flights", "Barcha reyslar", "Барча рейслар"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    LazyVStack(spacing: 12) {
                        ForEach(selectedDateOffers.prefix(20)) { offer in
                            FlightDiscoveryTicketCard(
                                language: settings.language,
                                offer: offer,
                                currency: store.currency
                            ) {
                                selectedOffer = offer
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func flightCarouselSection(
        title: String,
        subtitle: String,
        offers: [FlightDiscoveryOffer],
        badge: String,
        badgeIcon: String
    ) -> some View {
        if !offers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(offers.prefix(8)) { offer in
                            FlightDiscoveryCarouselTicketCard(
                                language: settings.language,
                                offer: offer,
                                currency: store.currency,
                                badge: badge,
                                badgeIcon: badgeIcon
                            ) {
                                selectedOffer = offer
                            }
                        }
                    }
                    .padding(.vertical, 1)
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
                        "Если дата гибкая — сравните цены на соседние дни.",
                        "If your dates are flexible, compare nearby dates.",
                        "Sana moslashuvchan bo‘lsa, yaqin kunlardagi narxlarni solishtiring.",
                        "Сана мослашувчан бўлса, яқин кунлардаги нархларни солиштиринг."
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
                                .frame(minWidth: 142, maxWidth: 142, minHeight: 112, alignment: .leading)
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
                            ? tr("На эту дату пока нет подходящих билетов", "No suitable flights for this date yet", "Bu sana uchun hozircha mos chiptalar yo‘q", "Бу сана учун ҳозирча мос чипталар йўқ")
                            : tr("Не удалось обновить авиабилеты", "Could not refresh flights", "Aviachiptalarni yangilab bo‘lmadi", "Авиачипталарни янгилаб бўлмади")
                    )
                    .font(.headline)
                    Text(tr(
                        "Измените дату, обновите поиск или проверьте маршрут на Aviasales.",
                        "Change the date, refresh the search, or check the route on Aviasales.",
                        "Sanani o‘zgartiring, qidiruvni yangilang yoki yo‘nalishni Aviasales’da tekshiring.",
                        "Санани ўзгартиринг, қидирувни янгиланг ёки йўналишни Aviasales’да текширинг."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button {
                    refresh()
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

    private var selectedDateOffers: [FlightDiscoveryOffer] {
        let selected = IumrahFlightDiscoveryStore.dayFormatter.string(from: departureDate)
        var rows = store.offers.filter { String($0.departureAt.prefix(10)) == selected }
        if let fallback = store.calendarDays.first(where: { $0.date == selected })?.offer {
            rows.append(fallback)
        }

        var seen = Set<String>()
        return rows
            .filter { offer in
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
            .sorted { lhs, rhs in
                if lhs.price != rhs.price { return lhs.price < rhs.price }
                return lhs.departureAt < rhs.departureAt
            }
    }

    private var cheapestOffers: [FlightDiscoveryOffer] {
        Array(selectedDateOffers.sorted { lhs, rhs in
            if lhs.price != rhs.price { return lhs.price < rhs.price }
            return lhs.departureAt < rhs.departureAt
        }.prefix(8))
    }

    private var directDateOffers: [FlightDiscoveryOffer] {
        Array(selectedDateOffers.filter { $0.transfers == 0 }.sorted { lhs, rhs in
            if lhs.price != rhs.price { return lhs.price < rhs.price }
            return lhs.departureAt < rhs.departureAt
        }.prefix(8))
    }

    private var recommendedOffers: [FlightDiscoveryOffer] {
        let rows = selectedDateOffers
        guard let minPrice = rows.map(\.price).min() else { return [] }
        return Array(rows.sorted { lhs, rhs in
            recommendationScore(lhs, minPrice: minPrice) < recommendationScore(rhs, minPrice: minPrice)
        }.prefix(8))
    }

    private var fastestOffers: [FlightDiscoveryOffer] {
        let rows = selectedDateOffers
            .filter { $0.durationMinutes > 0 }
            .sorted { lhs, rhs in
                if lhs.durationMinutes != rhs.durationMinutes { return lhs.durationMinutes < rhs.durationMinutes }
                return lhs.price < rhs.price
            }
        return Array(rows.prefix(8))
    }

    private func recommendationScore(_ offer: FlightDiscoveryOffer, minPrice: Double) -> Double {
        let pricePenalty = max(0, offer.price - minPrice)
        let transferPenalty = Double(max(0, offer.transfers)) * 65
        let durationPenalty = Double(max(0, offer.durationMinutes)) * 0.07
        return pricePenalty + transferPenalty + durationPenalty
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
            return tr("\(date) · только прямые", "\(date) · non-stop only", "\(date) · faqat to‘g‘ridan-to‘g‘ri", "\(date) · фақат тўғридан-тўғри")
        }
        return tr("\(date) · доступные варианты", "\(date) · available options", "\(date) · mavjud variantlar", "\(date) · мавжуд вариантлар")
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
                    "Цены на авиабилеты быстро меняются. Обновляйте цену перед покупкой.",
                    "Airfares change quickly. Refresh the fare before purchase.",
                    "Aviachipta narxlari tez o‘zgaradi. Xariddan oldin narxni yangilang.",
                    "Авиачипта нархлари тез ўзгаради. Хариддан олдин нархни янгиланг."
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

    private func useDatesForUmrah(_ offer: FlightDiscoveryOffer) {
        let destination = offer.destination.uppercased()
        guard destination == "JED" || destination == "MED" else { return }

        let currentOriginMatches = journey.trip.originCode.uppercased() == offer.origin.uppercased()
        journey.trip.origin = offer.origin.uppercased()
        if !currentOriginMatches { journey.trip.originAirport = nil }
        journey.trip.arrivalAirport = destination == "MED" ? .madinah : .jeddah
        journey.trip.departureDate = isoDate(offer.departureAt) ?? departureDate
        journey.trip.saudiArrivalDate = nil
        let suggestedReturn = offer.returnAt.flatMap(isoDate)
            ?? (tripType == .roundTrip ? returnDate : Calendar.current.date(byAdding: .day, value: 7, to: departureDate))
            ?? returnDate
        journey.trip.returnDate = max(
            suggestedReturn,
            Calendar.current.date(byAdding: .day, value: 1, to: journey.trip.departureDate) ?? suggestedReturn
        )
        journey.trip.flightTripType = .roundTrip
        selectedOffer = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            chrome.startNewTrip()
        }
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

private struct FlightDiscoveryCarouselTicketCard: View {
    let language: AppSettingsStore.Language
    let offer: FlightDiscoveryOffer
    let currency: String
    let badge: String
    let badgeIcon: String
    let onTap: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    AirlineLogoView(airlineCode: offer.airlineCode, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.airlineName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(flightNumberText)
                            .font(.caption2.monospaced().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(routeText)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(money(offer.price))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 7) {
                    Label(timeText, systemImage: "clock")
                    Text("·")
                    Text(durationText)
                    Text("·")
                    Text(stopsText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: badgeIcon)
                    Text(badge)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.iumrahRaisedBackground, in: Capsule())
            }
            .padding(16)
            .frame(minWidth: 286, maxWidth: 286, minHeight: 176, alignment: .leading)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private var routeText: String {
        let from = offer.originAirport.isEmpty ? offer.origin : offer.originAirport
        let to = offer.destinationAirport.isEmpty ? offer.destination : offer.destinationAirport
        return "\(from) → \(to)"
    }

    private var flightNumberText: String {
        let code = offer.airlineCode.isEmpty ? tr("Авиакомпания", "Airline", "Aviakompaniya", "Авиакомпания") : offer.airlineCode
        return offer.flightNumber.isEmpty ? code : "\(code) \(offer.flightNumber)"
    }

    private var timeText: String {
        guard let t = offer.departureAt.firstIndex(of: "T") else { return String(offer.departureAt.prefix(10)) }
        let after = offer.departureAt[offer.departureAt.index(after: t)...]
        return String(after.prefix(5))
    }

    private var durationText: String {
        guard offer.durationMinutes > 0 else { return "—" }
        let h = offer.durationMinutes / 60
        let m = offer.durationMinutes % 60
        switch language {
        case .russian: return m == 0 ? "\(h) ч" : "\(h) ч \(m) мин"
        case .english: return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        case .uzbek: return m == 0 ? "\(h) soat" : "\(h) soat \(m) daq"
        case .uzbekCyrillic: return m == 0 ? "\(h) соат" : "\(h) соат \(m) дақ"
        }
    }

    private var stopsText: String {
        switch language {
        case .russian: return offer.transfers == 0 ? "Прямой" : "\(offer.transfers) перес."
        case .english: return offer.transfers == 0 ? "Non-stop" : "\(offer.transfers) stop(s)"
        case .uzbek: return offer.transfers == 0 ? "To‘g‘ridan-to‘g‘ri" : "\(offer.transfers) almashish"
        case .uzbekCyrillic: return offer.transfers == 0 ? "Тўғридан-тўғри" : "\(offer.transfers) алмашиш"
        }
    }

    private func money(_ value: Double) -> String {
        let symbol = currency.lowercased() == "usd" ? "$" : currency.uppercased() + " "
        return "\(symbol)\(Int(value.rounded()))"
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

private struct FlightDiscoveryTicketCard: View {
    let language: AppSettingsStore.Language
    let offer: FlightDiscoveryOffer
    let currency: String
    let onTap: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AirlineLogoView(airlineCode: offer.airlineCode, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.airlineName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(flightNumberText)
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(money(offer.price))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(tr("за билет", "per ticket", "chipta uchun", "чипта учун"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(localTime(offer.departureAt))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text(offer.originAirport.isEmpty ? offer.origin : offer.originAirport)
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 5) {
                        Text(durationText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 0) {
                            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 5, height: 5)
                            Rectangle().fill(Color.secondary.opacity(0.22)).frame(height: 1)
                            Image(systemName: "airplane")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Rectangle().fill(Color.secondary.opacity(0.22)).frame(height: 1)
                            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 5, height: 5)
                        }
                        Text(stopsText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(offer.transfers == 0 ? Color.green : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(arrivalTime)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text(offer.destinationAirport.isEmpty ? offer.destination : offer.destinationAirport)
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Label(dateText, systemImage: "calendar")
                    if offer.bookingUrl != nil {
                        Label(tr("Можно проверить", "Check live", "Tekshirish mumkin", "Текшириш мумкин"), systemImage: "arrow.up.right.square")
                    }
                    Spacer()
                    Text(tr("Подробнее", "Details", "Batafsil", "Батафсил"))
                        .font(.caption.weight(.bold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(17)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private var flightNumberText: String {
        let code = offer.airlineCode.isEmpty ? tr("Авиакомпания", "Airline", "Aviakompaniya", "Авиакомпания") : offer.airlineCode
        guard !offer.flightNumber.isEmpty else { return code }
        return "\(code) \(offer.flightNumber)"
    }

    private var durationText: String {
        guard offer.durationMinutes > 0 else { return "—" }
        let h = offer.durationMinutes / 60
        let m = offer.durationMinutes % 60
        switch language {
        case .russian: return m == 0 ? "\(h) ч" : "\(h) ч \(m) мин"
        case .english: return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        case .uzbek: return m == 0 ? "\(h) soat" : "\(h) soat \(m) daq"
        case .uzbekCyrillic: return m == 0 ? "\(h) соат" : "\(h) соат \(m) дақ"
        }
    }

    private var stopsText: String {
        switch language {
        case .russian: return offer.transfers == 0 ? "Прямой" : "\(offer.transfers) перес."
        case .english: return offer.transfers == 0 ? "Non-stop" : "\(offer.transfers) stop(s)"
        case .uzbek: return offer.transfers == 0 ? "To‘g‘ridan-to‘g‘ri" : "\(offer.transfers) almashish"
        case .uzbekCyrillic: return offer.transfers == 0 ? "Тўғридан-тўғри" : "\(offer.transfers) алмашиш"
        }
    }

    private var dateText: String {
        guard let date = isoDate(offer.departureAt) else { return String(offer.departureAt.prefix(10)) }
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

    private var arrivalTime: String {
        guard offer.durationMinutes > 0,
              let departure = isoDate(offer.departureAt) else { return "—" }
        let arrival = departure.addingTimeInterval(TimeInterval(offer.durationMinutes * 60))
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
                        "Сейчас показываем эконом. Другие классы и точный тариф выбираются при финальной проверке.",
                        "Economy is shown for now. Other cabins and the exact fare are selected during the final check.",
                        "Hozir ekonom klass ko‘rsatiladi. Boshqa klasslar va aniq tarif yakuniy tekshiruvda tanlanadi.",
                        "Ҳозир эконом класс кўрсатилади. Бошқа класслар ва аниқ тариф якуний текширувда танланади."
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
                        "Багаж зависит от конкретного тарифа. Проверяйте условия багажа перед покупкой.",
                        "Baggage depends on the selected fare. Check baggage terms before purchase.",
                        "Bagaj tanlangan tarifga bog‘liq. Xariddan oldin bagaj shartlarini tekshiring.",
                        "Багаж танланган тарифга боғлиқ. Хариддан олдин багаж шартларини текширинг."
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
                        "Цены указаны за билет в одну сторону. Перед покупкой обновите выбранную цену.",
                        "Prices are per one-way ticket. Refresh the selected fare before purchase.",
                        "Narxlar bir tomonlama chipta uchun. Xariddan oldin tanlangan narxni yangilang.",
                        "Нархлар бир томонлама чипта учун. Хариддан олдин танланган нархни янгиланг."
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
    let days: [FlightDiscoveryCalendarDay]
    let selectedDate: Date

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(origin) → \(destination)")
                        .font(.title2.bold().monospaced())
                    Text(tr("Цена за билет в одну сторону", "One-way ticket price", "Bir tomonlama chipta narxi", "Бир томонлама чипта нархи"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if days.isEmpty {
                    ContentUnavailableView(
                        tr("Пока нет данных", "No data yet", "Hozircha ma’lumot yo‘q", "Ҳозирча маълумот йўқ"),
                        systemImage: "chart.bar.xaxis",
                        description: Text(tr("На этот месяц пока нет цен. Попробуйте обновить поиск позже.", "No fares for this month yet. Try refreshing later.", "Bu oy uchun hozircha narxlar yo‘q. Keyinroq yangilab ko‘ring.", "Бу ой учун ҳозирча нархлар йўқ. Кейинроқ янгилаб кўринг."))
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 11) {
                            ForEach(days.sorted(by: { $0.date < $1.date })) { day in
                                bar(day)
                            }
                        }
                        .frame(height: 250, alignment: .bottom)
                        .padding(.horizontal, 4)
                    }

                    if let lowest = days.min(by: { $0.price < $1.price }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.green)
                            Text(tr("Минимум месяца", "Monthly low", "Oyning eng past narxi", "Ойнинг энг паст нархи"))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("$\(Int(lowest.price.rounded()))")
                                .font(.headline)
                        }
                        .padding(16)
                        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color.iumrahPageBackground)
            .navigationTitle(tr("График цен", "Price chart", "Narx grafigi", "Нарх графиги"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func bar(_ day: FlightDiscoveryCalendarDay) -> some View {
        let maxPrice = max(days.map(\.price).max() ?? 1, 1)
        let height = max(34, min(168, 168 * day.price / maxPrice))
        let isSelected = IumrahFlightDiscoveryStore.dayFormatter.string(from: selectedDate) == day.date
        let isLow = day.price <= (days.map(\.price).sorted().prefix(max(1, days.count / 4)).last ?? day.price)

        return VStack(spacing: 7) {
            Text("$\(Int(day.price.rounded()))")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                .opacity(isSelected || isLow ? 1 : 0)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.blue : (isLow ? Color.green : Color.secondary.opacity(0.22)))
                .frame(width: 34, height: CGFloat(height))
            Text(dayNumber(day.date))
                .font(.caption.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.blue : Color.secondary)
        }
    }

    private func dayNumber(_ value: String) -> String {
        guard let date = IumrahFlightDiscoveryStore.dayFormatter.date(from: value) else { return value }
        return "\(Calendar.current.component(.day, from: date))"
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

private struct FlightDiscoveryDirectFlightsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppSettingsStore.Language
    let origin: String
    let destination: String
    let offers: [FlightDiscoveryOffer]
    let isLoading: Bool
    let onSelect: (FlightDiscoveryOffer) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && offers.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if offers.isEmpty {
                    ContentUnavailableView(
                        tr("Прямые рейсы не найдены", "No direct flights found", "To‘g‘ridan-to‘g‘ri reys topilmadi", "Тўғридан-тўғри рейс топилмади"),
                        systemImage: "airplane.circle",
                        description: Text(tr("Попробуйте другую дату или обновите поиск.", "Try another date or refresh the search.", "Boshqa sanani tanlang yoki qidiruvni yangilang.", "Бошқа санани танланг ёки қидирувни янгиланг."))
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(offers.sorted(by: { $0.departureAt < $1.departureAt })) { offer in
                                Button {
                                    onSelect(offer)
                                } label: {
                                    HStack(spacing: 13) {
                                        AirlineLogoView(airlineCode: offer.airlineCode, size: 44)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(dateTime(offer.departureAt))
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text("\(offer.airlineName) · \(offer.airlineCode) \(offer.flightNumber)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text("$\(Int(offer.price.rounded()))")
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .padding(16)
                                    .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle(tr("Прямые рейсы", "Direct flights", "To‘g‘ridan-to‘g‘ri", "Тўғридан-тўғри"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Text("\(origin) → \(destination)")
                    .font(.subheadline.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func dateTime(_ value: String) -> String {
        guard let date = isoDate(value) else { return String(value.prefix(16)) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM HHmm")
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

private struct FlightDiscoveryOfferDetailView: View {
    private enum PriceRefreshState: Equatable {
        case idle
        case refreshing
        case updated
        case unavailable
        case failed
    }

    let language: AppSettingsStore.Language
    let offer: FlightDiscoveryOffer
    let currency: String
    let adults: Int
    let children: Int
    let infants: Int
    let fallbackReturnDate: Date?
    let canBuildUmrah: Bool
    let onBuy: (FlightDiscoveryOffer) -> Void
    let onBuildUmrah: (FlightDiscoveryOffer) -> Void

    @State private var currentOffer: FlightDiscoveryOffer
    @State private var refreshState: PriceRefreshState = .idle
    @State private var isRefreshingPrice = false
    @State private var lastUpdatedAt: Date?

    private let service = AviasalesFlightDiscoveryService()

    init(
        language: AppSettingsStore.Language,
        offer: FlightDiscoveryOffer,
        currency: String,
        adults: Int,
        children: Int,
        infants: Int,
        fallbackReturnDate: Date?,
        canBuildUmrah: Bool,
        onBuy: @escaping (FlightDiscoveryOffer) -> Void,
        onBuildUmrah: @escaping (FlightDiscoveryOffer) -> Void
    ) {
        self.language = language
        self.offer = offer
        self.currency = currency
        self.adults = adults
        self.children = children
        self.infants = infants
        self.fallbackReturnDate = fallbackReturnDate
        self.canBuildUmrah = canBuildUmrah
        self.onBuy = onBuy
        self.onBuildUmrah = onBuildUmrah
        _currentOffer = State(initialValue: offer)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                routeHeader
                priceCard
                detailCard
                priceNotice

                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Купить билет самостоятельно", "Buy the ticket yourself", "Chiptani o‘zingiz sotib oling", "Чиптани ўзингиз сотиб олинг"))
                        .font(.headline)
                    Text(tr(
                        "Перед покупкой Aviasales ещё раз проверит актуальную цену и доступность предложения.",
                        "Before purchase, Aviasales will check the current fare and availability again.",
                        "Xariddan oldin Aviasales joriy narx va taklif mavjudligini yana tekshiradi.",
                        "Хариддан олдин Aviasales жорий нарх ва таклиф мавжудлигини яна текширади."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onBuy(currentOffer)
                } label: {
                    HStack {
                        Image(systemName: "airplane.circle.fill")
                        Text(tr("Купить самому на Aviasales", "Buy on Aviasales", "Aviasales’da sotib olish", "Aviasales’да сотиб олиш"))
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
                        onBuildUmrah(currentOffer)
                    } label: {
                        HStack {
                            Image(systemName: "moon.stars.fill")
                            Text(tr("Добавить рейс в умру", "Add flight to Umrah", "Reysni Umraga qo‘shish", "Рейсни Умрага қўшиш"))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 38)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(tr("Авиабилет", "Flight", "Aviachipta", "Авиачипта"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: offer.id) {
            await refreshPrice()
        }
    }

    private var routeHeader: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentOffer.originAirport.isEmpty ? currentOffer.origin : currentOffer.originAirport)
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospaced())
                    Text(airportCity(currentOffer.originAirport.isEmpty ? currentOffer.origin : currentOffer.originAirport))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "airplane")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.blue)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currentOffer.destinationAirport.isEmpty ? currentOffer.destination : currentOffer.destinationAirport)
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospaced())
                    Text(airportCity(currentOffer.destinationAirport.isEmpty ? currentOffer.destination : currentOffer.destinationAirport))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack(spacing: 12) {
                AirlineLogoView(airlineCode: currentOffer.airlineCode, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(currentOffer.airlineName).font(.headline)
                    Text(flightNumberText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Цена билета", "Ticket price", "Chipta narxi", "Чипта нархи"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if priceChanged {
                            Text(money(offer.price))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .strikethrough()
                        }
                        Text(money(currentOffer.price))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                }
                Spacer()
                if isRefreshingPrice {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: refreshStateIcon)
                    .font(.system(size: 13, weight: .bold))
                Text(refreshStateText)
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(refreshStateColor)

            Button {
                Task { await refreshPrice() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(tr("Обновить цену", "Refresh price", "Narxni yangilash", "Нархни янгилаш"))
                    Spacer()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous), interactive: true)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshingPrice)
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var detailCard: some View {
        VStack(spacing: 0) {
            detailRow(icon: "calendar", title: tr("Вылет", "Departure", "Jo‘nash", "Жўнаш"), value: dateTime(currentOffer.departureAt))
            Divider().padding(.leading, 48)
            detailRow(icon: "clock", title: tr("В пути", "Duration", "Yo‘lda", "Йўлда"), value: durationText)
            Divider().padding(.leading, 48)
            detailRow(icon: "point.3.connected.trianglepath.dotted", title: tr("Пересадки", "Stops", "Almashish", "Алмашиш"), value: stopsText)
            Divider().padding(.leading, 48)
            detailRow(icon: "person.2.fill", title: tr("Пассажиры", "Passengers", "Yo‘lovchilar", "Йўловчилар"), value: "\(adults + children + infants)")
        }
        .padding(.horizontal, 16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var priceNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            Text(tr(
                "Цены на авиабилеты быстро меняются. iumrah обновляет цену при открытии этой страницы, а перед покупкой её можно проверить ещё раз.",
                "Airfares change quickly. iumrah refreshes the fare when this page opens, and you can check it again before purchase.",
                "Aviachipta narxlari tez o‘zgaradi. iumrah bu sahifa ochilganda narxni yangilaydi, xariddan oldin esa yana tekshirishingiz mumkin.",
                "Авиачипта нархлари тез ўзгаради. iumrah бу саҳифа очилганда нархни янгилайди, хариддан олдин эса яна текширишингиз мумкин."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func refreshPrice() async {
        guard !isRefreshingPrice else { return }
        isRefreshingPrice = true
        refreshState = .refreshing

        let returnDate = currentOffer.returnAt.flatMap(isoDate) ?? fallbackReturnDate
        do {
            let result = try await service.refreshOffer(
                currentOffer,
                returnDate: returnDate,
                currency: currency
            )
            if let refreshed = result.offer {
                currentOffer = refreshed
                lastUpdatedAt = Date()
                refreshState = .updated
                IumrahHaptics.success()
            } else {
                refreshState = .unavailable
            }
        } catch {
            refreshState = .failed
        }
        isRefreshingPrice = false
    }

    private var refreshStateText: String {
        switch refreshState {
        case .idle:
            return tr("Цена обновится автоматически", "Price refreshes automatically", "Narx avtomatik yangilanadi", "Нарх автоматик янгиланади")
        case .refreshing:
            return tr("Обновляем цену…", "Refreshing price…", "Narx yangilanmoqda…", "Нарх янгиланмоқда…")
        case .updated:
            return tr("Обновлено только что", "Updated just now", "Hozirgina yangilandi", "Ҳозиргина янгиланди")
        case .unavailable:
            return tr("Не удалось подтвердить текущую цену", "Could not confirm the current fare", "Joriy narxni tasdiqlab bo‘lmadi", "Жорий нархни тасдиқлаб бўлмади")
        case .failed:
            return tr("Не удалось обновить цену", "Could not refresh the fare", "Narxni yangilab bo‘lmadi", "Нархни янгилаб бўлмади")
        }
    }

    private var refreshStateIcon: String {
        switch refreshState {
        case .idle: return "arrow.clockwise.circle"
        case .refreshing: return "arrow.clockwise.circle.fill"
        case .updated: return "checkmark.circle.fill"
        case .unavailable: return "exclamationmark.circle.fill"
        case .failed: return "wifi.exclamationmark"
        }
    }

    private var refreshStateColor: Color {
        switch refreshState {
        case .updated: return .green
        case .unavailable, .failed: return .orange
        default: return .secondary
        }
    }

    private var priceChanged: Bool {
        abs(currentOffer.price - offer.price) >= 0.5
    }

    private var flightNumberText: String {
        let code = currentOffer.airlineCode.isEmpty ? tr("Авиакомпания", "Airline", "Aviakompaniya", "Авиакомпания") : currentOffer.airlineCode
        return currentOffer.flightNumber.isEmpty ? code : "\(code) \(currentOffer.flightNumber)"
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
    }

    private var durationText: String {
        guard currentOffer.durationMinutes > 0 else { return "—" }
        let hours = currentOffer.durationMinutes / 60
        let minutes = currentOffer.durationMinutes % 60
        switch language {
        case .russian: return minutes == 0 ? "\(hours) ч" : "\(hours) ч \(minutes) мин"
        case .english: return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        case .uzbek: return minutes == 0 ? "\(hours) soat" : "\(hours) soat \(minutes) daq"
        case .uzbekCyrillic: return minutes == 0 ? "\(hours) соат" : "\(hours) соат \(minutes) дақ"
        }
    }

    private var stopsText: String {
        switch language {
        case .russian: return currentOffer.transfers == 0 ? "Прямой" : "\(currentOffer.transfers) перес."
        case .english: return currentOffer.transfers == 0 ? "Non-stop" : "\(currentOffer.transfers) stop(s)"
        case .uzbek: return currentOffer.transfers == 0 ? "To‘g‘ridan-to‘g‘ri" : "\(currentOffer.transfers) almashish"
        case .uzbekCyrillic: return currentOffer.transfers == 0 ? "Тўғридан-тўғри" : "\(currentOffer.transfers) алмашиш"
        }
    }

    private func money(_ value: Double) -> String {
        let symbol = currency.lowercased() == "usd" ? "$" : currency.uppercased() + " "
        return "\(symbol)\(Int(value.rounded()))"
    }

    private func airportCity(_ code: String) -> String {
        FlightReferenceCatalog.airport(code)?.city ?? code
    }

    private func dateTime(_ value: String) -> String {
        guard let date = isoDate(value) else { return String(value.prefix(16)) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM HHmm")
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
