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
            discoveryActions
            cheapestSection
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
        .sheet(item: $selectedOffer) { offer in
            FlightDiscoveryOfferSheet(
                language: settings.language,
                offer: offer,
                adults: adults,
                children: children,
                infants: infants,
                fallbackReturnDate: tripType == .roundTrip ? returnDate : nil,
                canBuildUmrah: ["JED", "MED"].contains(offer.destination.uppercased()),
                onCheckPrice: { checkCurrentPrice(for: offer) },
                onBuildUmrah: { useDatesForUmrah(offer) }
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

    private var cheapestSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Самые дешёвые билеты", "Cheapest tickets", "Eng arzon chiptalar", "Энг арзон чипталар"))
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.55)
                Spacer()
                if store.isLoading {
                    ProgressView().controlSize(.small)
                }
            }

            if let insight = priceInsight {
                insightCard(insight)
            }

            if displayOffers.isEmpty {
                emptyOffersCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(displayOffers.prefix(12)) { offer in
                            FlightDiscoveryOfferCard(
                                language: settings.language,
                                offer: offer,
                                currency: store.currency
                            ) {
                                selectedOffer = offer
                            }
                            .frame(width: 286)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .contentMargins(.horizontal, 0, for: .scrollContent)
            }
        }
    }

    private func insightCard(_ insight: (price: Double, date: String)) -> some View {
        HStack(spacing: 12) {
            IumrahIconBadge(systemName: "sparkles", role: .success, size: 42, symbolSize: 17, shape: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("Выгодная дата", "Best value date", "Qulay sana", "Қулай сана"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(localizedDate(insight.date)) · \(money(insight.price))")
                    .font(.headline)
            }
            Spacer()
            Button {
                if let date = dayDate(insight.date) {
                    departureDate = date
                }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 38, height: 38)
                    .iumrahGlass(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    private var emptyOffersCard: some View {
        VStack(spacing: 12) {
            Image(systemName: store.errorMessage == nil ? "airplane.circle" : "wifi.exclamationmark")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.secondary)
            Text(
                store.errorMessage == nil
                    ? tr("На выбранную дату в кэше пока нет цены", "No cached price for this date yet", "Tanlangan sana uchun keshda narx hali yo‘q", "Танланган сана учун кешда нарх ҳали йўқ")
                    : tr("Не удалось обновить цены", "Could not refresh prices", "Narxlarni yangilab bo‘lmadi", "Нархларни янгилаб бўлмади")
            )
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            Text(
                tr(
                    "Откройте календарь цен или выберите соседнюю дату. Data API показывает недавно найденные предложения, а не гарантированное наличие.",
                    "Open the price calendar or choose a nearby date. Data API shows recently found fares, not guaranteed availability.",
                    "Narxlar taqvimini oching yoki yaqin sanani tanlang. Data API yaqinda topilgan tariflarni ko‘rsatadi, mavjudlikni kafolatlamaydi.",
                    "Нархлар тақвимини очинг ёки яқин санани танланг. Data API яқинда топилган тарифларни кўрсатади, мавжудликни кафолатламайди."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                refresh()
            } label: {
                Label(tr("Обновить", "Refresh", "Yangilash", "Янгилаш"), systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .iumrahGlass(in: Capsule(), interactive: true)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 188)
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
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

    private var displayOffers: [FlightDiscoveryOffer] {
        if !store.offers.isEmpty { return store.offers }
        let selected = IumrahFlightDiscoveryStore.dayFormatter.string(from: departureDate)
        let future = store.calendarDays
            .filter { $0.date >= selected }
            .sorted { lhs, rhs in
                if lhs.price != rhs.price { return lhs.price < rhs.price }
                return lhs.date < rhs.date
            }
            .map(\.offer)
        if !future.isEmpty { return Array(future.prefix(12)) }
        return Array(store.calendarDays.sorted { $0.price < $1.price }.prefix(12).map(\.offer))
    }

    private var priceInsight: (price: Double, date: String)? {
        guard let value = store.calendarDays.min(by: { $0.price < $1.price }) else { return nil }
        return (value.price, value.date)
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

private struct FlightDiscoveryOfferCard: View {
    let language: AppSettingsStore.Language
    let offer: FlightDiscoveryOffer
    let currency: String
    let onTap: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top) {
                    Text(money(offer.price))
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .tracking(-0.6)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 34, height: 34)
                        .background(Color.iumrahRaisedBackground, in: Circle())
                }

                HStack(spacing: 11) {
                    AirlineLogoView(airlineCode: offer.airlineCode, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.airlineName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(flightNumberText)
                            .font(.caption.monospaced().weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    Label(dateText, systemImage: "calendar")
                    Label(durationText, systemImage: offer.transfers == 0 ? "airplane" : "point.3.connected.trianglepath.dotted")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                HStack {
                    Text(offer.routeTitle)
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(stopsText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(offer.transfers == 0 ? Color.green : Color.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 206, alignment: .topLeading)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private var flightNumberText: String {
        guard !offer.flightNumber.isEmpty else { return offer.airlineCode }
        return "\(offer.airlineCode) \(offer.flightNumber)"
    }

    private var dateText: String {
        guard let date = isoDate(offer.departureAt) else { return String(offer.departureAt.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private var durationText: String {
        guard offer.durationMinutes > 0 else { return stopsText }
        let h = offer.durationMinutes / 60
        let m = offer.durationMinutes % 60
        let duration = m == 0 ? "\(h)h" : "\(h)h \(m)m"
        return "\(duration) · \(stopsText)"
    }

    private var stopsText: String {
        switch language {
        case .russian: return offer.transfers == 0 ? "Прямой" : "Пересадок: \(offer.transfers)"
        case .english: return offer.transfers == 0 ? "Direct" : "Stops: \(offer.transfers)"
        case .uzbek: return offer.transfers == 0 ? "To‘g‘ridan-to‘g‘ri" : "Almashish: \(offer.transfers)"
        case .uzbekCyrillic: return offer.transfers == 0 ? "Тўғридан-тўғри" : "Алмашиш: \(offer.transfers)"
        }
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
                        description: Text(tr("Data API ещё не видел цену на этот месяц.", "Data API has not seen a fare for this month yet.", "Data API bu oy uchun hali narx ko‘rmagan.", "Data API бу ой учун ҳали нарх кўрмаган."))
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
                        description: Text(tr("Data API показывает только недавно найденные предложения.", "Data API only shows recently found offers.", "Data API faqat yaqinda topilgan takliflarni ko‘rsatadi.", "Data API фақат яқинда топилган таклифларни кўрсатади."))
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

private struct FlightDiscoveryOfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppSettingsStore.Language
    let offer: FlightDiscoveryOffer
    let adults: Int
    let children: Int
    let infants: Int
    let fallbackReturnDate: Date?
    let canBuildUmrah: Bool
    let onCheckPrice: () -> Void
    let onBuildUmrah: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    routeHeader
                    detailCard
                    warningCard

                    Button {
                        onCheckPrice()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.right.square.fill")
                            Text(tr("Проверить актуальную цену", "Check current price", "Joriy narxni tekshirish", "Жорий нархни текшириш"))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.headline)
                        .foregroundStyle(Color.iumrahPrimaryButtonText)
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if canBuildUmrah {
                        Button {
                            onBuildUmrah()
                        } label: {
                            HStack {
                                Image(systemName: "moon.stars.fill")
                                Text(tr("Собрать умру на эти даты", "Build Umrah for these dates", "Shu sanalarga Umra tuzish", "Шу саналарга Умра тузиш"))
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
                .padding(20)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle("iumrah Flights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var routeHeader: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.originAirport.isEmpty ? offer.origin : offer.originAirport)
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospaced())
                    Text(airportCity(offer.originAirport.isEmpty ? offer.origin : offer.originAirport))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "airplane")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.blue)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(offer.destinationAirport.isEmpty ? offer.destination : offer.destinationAirport)
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospaced())
                    Text(airportCity(offer.destinationAirport.isEmpty ? offer.destination : offer.destinationAirport))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack(spacing: 12) {
                AirlineLogoView(airlineCode: offer.airlineCode, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.airlineName).font(.headline)
                    Text("\(offer.airlineCode) \(offer.flightNumber)")
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                Text("$\(Int(offer.price.rounded()))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
    }

    private var detailCard: some View {
        VStack(spacing: 0) {
            detailRow(icon: "calendar", title: tr("Вылет", "Departure", "Jo‘nash", "Жўнаш"), value: dateTime(offer.departureAt))
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

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .foregroundStyle(.orange)
            Text(tr(
                "Это недавно найденная цена из Data API. Она может измениться, а наличие места не гарантировано. Кнопка выше выполняет актуальную проверку на Aviasales.",
                "This is a recently found Data API price. It may change and seat availability is not guaranteed. The button above performs a current check on Aviasales.",
                "Bu Data API'dan yaqinda topilgan narx. U o‘zgarishi mumkin va joy mavjudligi kafolatlanmaydi. Yuqoridagi tugma Aviasales'da joriy tekshiruvni ochadi.",
                "Бу Data API'дан яқинда топилган нарх. У ўзгариши мумкин ва жой мавжудлиги кафолатланмайди. Юқоридаги тугма Aviasales'да жорий текширувни очади."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        guard offer.durationMinutes > 0 else { return "—" }
        let hours = offer.durationMinutes / 60
        let minutes = offer.durationMinutes % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    private var stopsText: String {
        switch language {
        case .russian: return offer.transfers == 0 ? "Прямой" : "\(offer.transfers)"
        case .english: return offer.transfers == 0 ? "Direct" : "\(offer.transfers)"
        case .uzbek: return offer.transfers == 0 ? "To‘g‘ridan-to‘g‘ri" : "\(offer.transfers)"
        case .uzbekCyrillic: return offer.transfers == 0 ? "Тўғридан-тўғри" : "\(offer.transfers)"
        }
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
