import SwiftUI

struct HotelsHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var storefront: HotelStorefrontStore

    @State private var board: HotelsShowcaseBoard = .hotels
    @State private var selectedHotel: HotelSummary?
    @State private var selectedFlightPackage: StorefrontFlightPackagePreview?
    @State private var autoOpenConfiguratorHotelID: String?
    @State private var autoOpenConfiguratorDeepLink: HotelConfiguratorDeepLink?
    @State private var carePresented = false
    @State private var packageShareArtifacts: IumrahPackageShareArtifacts?
    @State private var packageShareError: String?
    @State private var flightOriginFilter: String? = nil
    @State private var flightDestinationFilter: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                IumrahRootPageTitle(title: pageTitle)

                AirportSelectorButton(airport: $journey.trip.originAirport, fallbackCode: $journey.trip.origin)

                Picker(L10n.text("hotel_storefront_section", settings.language), selection: $board) {
                    Text(L10n.text("tab_hotels", settings.language)).tag(HotelsShowcaseBoard.hotels)
                    Text(L10n.text("hotel_storefront_flights", settings.language)).tag(HotelsShowcaseBoard.flights)
                    Text(L10n.text("hotel_storefront_weekend", settings.language)).tag(HotelsShowcaseBoard.sundayClub)
                }
                .pickerStyle(.segmented)
                .onChange(of: board) { _, _ in IumrahHaptics.selection() }

                switch board {
                case .hotels:
                    hotelsBoard
                case .flights:
                    flightsBoard
                case .sundayClub:
                    sundayClubBoard
                }

            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .refreshable {
            await storefront.updateDepartureAirport(journey.trip.originCode)
            await storefront.refresh()
        }
        .task(id: journey.trip.originCode.uppercased()) {
            await storefront.prepareIfNeeded()
            await storefront.updateDepartureAirport(journey.trip.originCode)
        }
        .onAppear {
            applyRequestedBoard()
            openRequestedPackage(chrome.requestedPackageID)
        }
        .onChange(of: chrome.requestedHotelsBoard) { _, _ in
            applyRequestedBoard()
        }
        .onChange(of: chrome.requestedHotelID) { _, hotelID in
            openRequestedHotel(hotelID)
        }
        .onChange(of: chrome.requestedPackageID) { _, packageID in
            openRequestedPackage(packageID)
        }
        .onChange(of: storefront.allHotels.map(\.id)) { _, _ in
            openRequestedHotel(chrome.requestedHotelID)
        }
        .navigationDestination(item: $selectedHotel) { hotel in
            HotelDetailView(
                hotel: hotel,
                autoOpenConfigurator: autoOpenConfiguratorHotelID == hotel.id,
                configuratorDeepLink: autoOpenConfiguratorDeepLink?.hotelID == hotel.id ? autoOpenConfiguratorDeepLink : nil
            )
        }
        .navigationDestination(item: $selectedFlightPackage) { preview in
            StorefrontUmrahPackageDetailView(preview: preview)
        }
        .sheet(isPresented: $carePresented) {
            HotelCareContactSheet()
                .environmentObject(settings)
        }
        .sheet(item: $packageShareArtifacts) { artifacts in
            IumrahPackageActivitySheet(artifacts: artifacts)
        }
        .alert(packageShareErrorTitle, isPresented: Binding(
            get: { packageShareError != nil },
            set: { if !$0 { packageShareError = nil } }
        )) {
            Button(packageShareErrorDismiss, role: .cancel) { packageShareError = nil }
        } message: {
            Text(packageShareError ?? "")
        }
    }

    private func applyRequestedBoard() {
        guard let requested = chrome.requestedHotelsBoard else { return }
        board = requested
        chrome.requestedHotelsBoard = nil
    }

    private var pageTitle: String {
        switch board {
        case .hotels: return L10n.text("tab_hotels", settings.language)
        case .flights: return L10n.text("hotel_storefront_flights", settings.language)
        case .sundayClub: return "Sunday Umrah Club"
        }
    }

    // MARK: - Hotels

    private var hotelsBoard: some View {
        VStack(alignment: .leading, spacing: 24) {
            ShowcaseHero(
                asset: "IumrahHotelsShowcaseHero",
                title: "iumrah Hotels",
                description: L10n.text("hotel_storefront_hero_body", settings.language),
                note: L10n.text("hotel_storefront_hero_note", settings.language)
            )

            hotelCitySection(
                title: L10n.text("hotels_makkah", settings.language),
                hotels: storefront.makkahHotels
            )
            hotelCitySection(
                title: L10n.text("hotels_madinah", settings.language),
                hotels: storefront.madinahHotels
            )

            if storefront.isLoading && storefront.allHotels.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L10n.text("hotel_storefront_loading", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 92)
            }

            if let error = storefront.errorMessage, storefront.allHotels.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .iumrahCard()
            }

            HotelCareShowcaseCard(language: settings.language) {
                carePresented = true
            }
        }
    }

    private func hotelCitySection(title: String, hotels: [HotelSummary]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !hotels.isEmpty {
                SectionHeader(title, eyebrow: L10n.text("hotels_selected_badge", settings.language), subtitle: nil)
                ForEach(hotels) { hotel in
                    HotelStorefrontCard(
                        hotel: hotel,
                        images: storefront.previewImages(for: hotel),
                        quote: storefront.automaticQuote(for: hotel),
                        language: settings.language,
                        isFavorite: storefront.isFavorite(hotel),
                        onOpen: {
                            autoOpenConfiguratorHotelID = nil
                            autoOpenConfiguratorDeepLink = nil
                            selectedHotel = hotel
                        },
                        onFavorite: { storefront.toggleFavorite(hotel) },
                        onShare: { shareDefaultHotelPackage(hotel) }
                    )
                }
            }
        }
    }

    // MARK: - Flights

    private var flightOptions: [StorefrontFlightOption] {
        storefront.flightBoard?.options ?? []
    }

    private var flightOrigins: [String] {
        var values = Set(flightOptions.map { $0.outbound.origin.uppercased() })
        for option in flightOptions {
            if let inbound = option.inbound { values.insert(inbound.origin.uppercased()) }
        }
        return values.sorted()
    }

    private var flightDestinations: [String] {
        var values = Set(flightOptions.map { $0.outbound.destination.uppercased() })
        for option in flightOptions {
            if let inbound = option.inbound { values.insert(inbound.destination.uppercased()) }
        }
        return values.sorted()
    }

    private var filteredFlightOptions: [StorefrontFlightOption] {
        flightOptions.filter { option in
            var legs = [option.outbound]
            if let inbound = option.inbound { legs.append(inbound) }
            return legs.contains { leg in
                let originMatches = flightOriginFilter.map { leg.origin.caseInsensitiveCompare($0) == .orderedSame } ?? true
                let destinationMatches = flightDestinationFilter.map { leg.destination.caseInsensitiveCompare($0) == .orderedSame } ?? true
                return originMatches && destinationMatches
            }
        }
    }

    private var flightsBoard: some View {
        VStack(alignment: .leading, spacing: 24) {
            ShowcaseHero(
                asset: "IumrahFlightsShowcaseHero",
                title: "iumrah Flights",
                description: L10n.text("hotel_storefront_flights_hero_body", settings.language),
                note: L10n.text("hotel_storefront_flights_hero_note", settings.language)
            )

            if !flightOptions.isEmpty {
                SectionHeader(
                    L10n.text("hotel_storefront_published_flights", settings.language),
                    eyebrow: L10n.text("hotel_storefront_current", settings.language),
                    subtitle: nil
                )

                flightAirportFilters

                if filteredFlightOptions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "airplane.circle")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(noFlightsForFilterText)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(changeAirportFilterText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                    .iumrahCard()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredFlightOptions) { option in
                            let preview = storefront.packagePreview(for: option)
                            StorefrontFlightOptionCard(
                                option: option,
                                packagePreview: preview,
                                isCalculating: storefront.isLoading,
                                language: settings.language,
                                onOpen: {
                                    guard let preview else { return }
                                    IumrahHaptics.selection()
                                    selectedFlightPackage = preview
                                }
                            )
                        }
                    }
                }
            } else if storefront.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }

    private var flightAirportFilters: some View {
        HStack(spacing: 10) {
            airportFilterMenu(
                title: fromAirportText,
                selection: flightOriginFilter,
                values: flightOrigins
            ) { value in
                flightOriginFilter = value
                IumrahHaptics.selection()
            }

            airportFilterMenu(
                title: toAirportText,
                selection: flightDestinationFilter,
                values: flightDestinations
            ) { value in
                flightDestinationFilter = value
                IumrahHaptics.selection()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func airportFilterMenu(
        title: String,
        selection: String?,
        values: [String],
        onSelect: @escaping (String?) -> Void
    ) -> some View {
        Menu {
            Button(allAirportsText) { onSelect(nil) }
            Divider()
            ForEach(values, id: \.self) { value in
                Button {
                    onSelect(value)
                } label: {
                    if selection == value {
                        Label(value, systemImage: "checkmark")
                    } else {
                        Text(value)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(selection ?? allAirportsText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var fromAirportText: String {
        switch settings.language {
        case .russian: return "Откуда"
        case .english: return "From"
        case .uzbek: return "Qayerdan"
        case .uzbekCyrillic: return "Қаердан"
        }
    }

    private var toAirportText: String {
        switch settings.language {
        case .russian: return "Куда"
        case .english: return "To"
        case .uzbek: return "Qayerga"
        case .uzbekCyrillic: return "Қаерга"
        }
    }

    private var allAirportsText: String {
        switch settings.language {
        case .russian: return "Все"
        case .english: return "All"
        case .uzbek: return "Barchasi"
        case .uzbekCyrillic: return "Барчаси"
        }
    }

    private var noFlightsForFilterText: String {
        switch settings.language {
        case .russian: return "iumrah Flights Scanner не нашёл рейсов по этому маршруту"
        case .english: return "iumrah Flights Scanner found no flights for this route"
        case .uzbek: return "iumrah Flights Scanner bu yo‘nalishda reys topmadi"
        case .uzbekCyrillic: return "iumrah Flights Scanner бу йўналишда рейс топмади"
        }
    }

    private var changeAirportFilterText: String {
        switch settings.language {
        case .russian: return "Измените аэропорт отправления или прибытия."
        case .english: return "Change the departure or arrival airport."
        case .uzbek: return "Jo‘nash yoki yetib borish aeroportini o‘zgartiring."
        case .uzbekCyrillic: return "Жўнаш ёки етиб бориш аэропортини ўзгартиринг."
        }
    }

    // MARK: - Sunday Club

    private var sundayClubBoard: some View {
        VStack(alignment: .leading, spacing: 20) {
            ShowcaseHero(
                asset: "SundayUmrahClubShowcaseHero",
                title: "Sunday Umrah Club",
                description: L10n.text("hotel_storefront_weekend_body", settings.language),
                note: L10n.text("hotel_storefront_weekend_note", settings.language),
                imageBackground: .white
            )
        }
    }

    @MainActor
    private func shareDefaultHotelPackage(_ hotel: HotelSummary) {
        guard let preview = storefront.hotelConfiguratorPreview(for: hotel) else {
            packageShareError = packageShareUnavailableText
            IumrahHaptics.error()
            return
        }
        do {
            packageShareArtifacts = try IumrahPackageShareFactory.make(
                payload: .defaultHotelFirst(hotel: hotel, preview: preview, language: settings.language),
                language: settings.language,
                invitation: false
            )
            IumrahHaptics.selection()
        } catch {
            packageShareError = packageShareUnavailableText
            IumrahHaptics.error()
        }
    }

    private var packageShareUnavailableText: String {
        switch settings.language {
        case .russian: return "Не удалось подготовить пакет для отправки. Обновите цены и попробуйте ещё раз."
        case .english: return "The package could not be prepared for sharing. Refresh pricing and try again."
        case .uzbek: return "Paketni ulashish uchun tayyorlab bo‘lmadi. Narxlarni yangilang va qayta urinib ko‘ring."
        case .uzbekCyrillic: return "Пакетни улашиш учун тайёрлаб бўлмади. Нархларни янгиланг ва қайта уриниб кўринг."
        }
    }

    private var packageShareErrorTitle: String {
        switch settings.language {
        case .russian: return "Не удалось поделиться"
        case .english: return "Could not share"
        case .uzbek: return "Ulashib bo‘lmadi"
        case .uzbekCyrillic: return "Улашиб бўлмади"
        }
    }

    private var packageShareErrorDismiss: String {
        switch settings.language {
        case .russian: return "Понятно"
        case .english: return "OK"
        case .uzbek: return "Tushunarli"
        case .uzbekCyrillic: return "Тушунарли"
        }
    }

    private func openRequestedHotel(_ hotelID: String?) {
        guard let hotelID, let hotel = storefront.hotel(id: hotelID) else { return }
        autoOpenConfiguratorHotelID = chrome.requestedHotelConfiguratorID == hotelID ? hotelID : nil
        if chrome.requestedHotelConfiguratorDeepLink?.hotelID == hotelID {
            autoOpenConfiguratorDeepLink = chrome.requestedHotelConfiguratorDeepLink
        } else {
            autoOpenConfiguratorDeepLink = nil
        }
        selectedHotel = hotel
        chrome.requestedHotelID = nil
        if chrome.requestedHotelConfiguratorID == hotelID {
            chrome.requestedHotelConfiguratorID = nil
        }
        if chrome.requestedHotelConfiguratorDeepLink?.hotelID == hotelID {
            chrome.requestedHotelConfiguratorDeepLink = nil
        }
    }

    private func openRequestedPackage(_ packageID: String?) {
        guard let packageID, packageID.range(of: "^\\d{10}$", options: .regularExpression) != nil else { return }
        Task { @MainActor in
            await storefront.prepareIfNeeded()
            guard let preview = await storefront.packagePreview(id: packageID) else { return }
            board = preview.kind == .hotelFirstMakkah ? .hotels : .flights
            selectedFlightPackage = preview
            chrome.requestedPackageID = nil
        }
    }

}

// MARK: - Storefront components

private struct ShowcaseHero: View {
    let asset: String
    let title: String
    let description: String
    let note: String
    var imageBackground: Color = .black

    var bodyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(imageBackground)
                .clipped()

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 9) {
                    IumrahInlineIcon(systemName: "checkmark.seal.fill", role: .umrah, size: 15)
                    Text(note)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
    }

    var body: some View {
        bodyContent
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.055), radius: 20, y: 8)
    }
}

private struct HotelStorefrontCard: View {
    let hotel: HotelSummary
    let images: [String]
    let quote: HotelStorefrontQuote?
    let language: AppSettingsStore.Language
    let isFavorite: Bool
    let onOpen: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void

    private let cardHeight: CGFloat = 204

    var body: some View {
        GeometryReader { proxy in
            let mediaWidth = min(max(proxy.size.width * 0.31, 108), 122)

            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    HotelStorefrontCollage(images: images, fallback: hotel.coverImageURL)
                        .frame(width: mediaWidth, height: cardHeight)

                    HStack(spacing: 6) {
                        Button(action: onFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isFavorite ? Color.iumrahCareLight : Color.white)
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.34), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.text(isFavorite ? "hotel_storefront_favorite_remove" : "hotel_storefront_favorite_add", language))

                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.34), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.text("hotel_storefront_share", language))
                    }
                    .padding(9)
                }
                .frame(width: mediaWidth, height: cardHeight)
                .clipped()

                VStack(alignment: .leading, spacing: 7) {
                    Text(hotel.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .tracking(-0.2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        if let stars = hotel.stars {
                            Text(String(repeating: "★", count: max(1, min(5, stars))))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(IumrahIconRole.rating.color)
                        }
                        if let rating = hotel.rating {
                            Text(String(format: "%.1f", rating))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Label(L10n.city(hotel.city, language), systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    if let quote {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(money(quote.packageQuote.pricePerPerson))
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .tracking(-0.55)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Spacer(minLength: 2)
                            Text(L10n.text("hotel_storefront_per_pilgrim", language))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        Text(L10n.format("hotel_storefront_package_total_fmt", language, money(quote.packageQuote.totalPackagePrice)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    } else {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.small)
                            Text(L10n.text("hotel_storefront_calculating", language))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(minHeight: 38, alignment: .leading)
                    }

                    HStack(spacing: 5) {
                        Text(L10n.text("hotel_storefront_includes", language))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                        Spacer(minLength: 2)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: cardHeight)
        }
        .frame(height: cardHeight)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            IumrahHaptics.selection()
            onOpen()
        }
        .accessibilityAddTraits(.isButton)
    }

    private func money(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
    }
}

private struct HotelStorefrontCollage: View {
    let images: [String]
    let fallback: String?

    private var resolved: [String?] {
        var list = images.map(Optional.some)
        if list.isEmpty { list.append(fallback) }
        while list.count < 3 { list.append(list.first ?? fallback) }
        return Array(list.prefix(3))
    }

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 3
            let heroHeight = ((proxy.size.height - gap) * 0.63)
            let thumbnailHeight = max(0, proxy.size.height - heroHeight - gap)
            let thumbnailWidth = max(0, (proxy.size.width - gap) / 2)

            VStack(spacing: gap) {
                HotelCachedImage(rawURL: resolved[0])
                    .frame(width: proxy.size.width, height: heroHeight)
                    .clipped()

                HStack(spacing: gap) {
                    HotelCachedImage(rawURL: resolved[1])
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .clipped()
                    HotelCachedImage(rawURL: resolved[2])
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .clipped()
                }
                .frame(width: proxy.size.width, height: thumbnailHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .clipped()
    }
}

private struct StorefrontFlightOptionCard: View {
    let option: StorefrontFlightOption
    let packagePreview: StorefrontFlightPackagePreview?
    let isCalculating: Bool
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            media
                .frame(height: 118)
                .clipped()

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(routeTitle)
                            .font(.headline)
                        Text(airlineTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    packagePrice
                }

                HStack(spacing: 12) {
                    flightTime(option.outbound)
                    if let inbound = option.inbound {
                        Divider().frame(height: 34)
                        flightTime(inbound)
                    }
                }

                if let packagePreview {
                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox.fill")
                            .font(.caption2.weight(.bold))
                        Text(packageRouteText(packagePreview))
                            .lineLimit(2)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(generatedStampText, systemImage: "seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(packagePreview == nil ? Color.secondary : IumrahIconRole.umrah.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.iumrahRaisedBackground, in: Capsule())

                    Spacer(minLength: 4)
                    if packagePreview != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.035), radius: 14, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            if packagePreview != nil { onOpen() }
        }
        .accessibilityAddTraits(.isButton)
    }

    private var media: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                if let imageURL = packagePreview?.primaryHotel?.coverImageURL, !imageURL.isEmpty {
                    HotelCachedImage(rawURL: imageURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Image("IumrahFlightsShowcaseHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 10) {
                    HStack(spacing: 6) {
                        AirlineLogoView(airlineCode: option.outbound.airlineCode, size: 40)
                        if let preview = packagePreview,
                           preview.inbound.airlineCode.uppercased() != option.outbound.airlineCode.uppercased() {
                            AirlineLogoView(airlineCode: preview.inbound.airlineCode, size: 40)
                        }
                    }

                    Spacer(minLength: 8)

                    if let preview = packagePreview {
                        Text(packageTypeText(preview))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.36), in: Capsule())
                    }
                }
                .padding(13)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    @ViewBuilder
    private var packagePrice: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let packagePreview {
                Text(money(packagePreview.pricePerPerson))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(packagePerPersonText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            } else if isCalculating {
                ProgressView()
                    .controlSize(.small)
                Text(calculatingPackageText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(packageUnavailableText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 132, alignment: .trailing)
    }

    private var routeTitle: String {
        if let inbound = option.inbound {
            return "\(option.outbound.origin) → \(option.outbound.destination) · \(inbound.origin) → \(inbound.destination)"
        }
        return "\(option.outbound.origin) → \(option.outbound.destination)"
    }

    private var airlineTitle: String {
        let first = "\(option.outbound.airline) \(option.outbound.flightNumber)"
        guard let inbound = option.inbound else { return first }
        return first + " · \(inbound.airline) \(inbound.flightNumber)"
    }

    private func flightTime(_ leg: StorefrontFlightLeg) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(day(leg.departureAt))
                .font(.caption.weight(.semibold))
            Text("\(clock(leg.departureAt))  \(leg.origin) → \(leg.destination)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func money(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func packageRouteText(_ preview: StorefrontFlightPackagePreview) -> String {
        let route = "\(preview.outbound.origin) → \(preview.outbound.destination) + \(preview.inbound.origin) → \(preview.inbound.destination)"
        switch language {
        case .russian: return "\(route) · \(preview.durationDays) дн. · \(packageScopeText(preview))"
        case .english: return "\(route) · \(preview.durationDays) days · \(packageScopeText(preview))"
        case .uzbek: return "\(route) · \(preview.durationDays) kun · \(packageScopeText(preview))"
        case .uzbekCyrillic: return "\(route) · \(preview.durationDays) кун · \(packageScopeText(preview))"
        }
    }

    private func packageTypeText(_ preview: StorefrontFlightPackagePreview) -> String {
        "\(packageScopeText(preview)) · \(preview.tier.title(language))"
    }

    private func packageScopeText(_ preview: StorefrontFlightPackagePreview) -> String {
        switch (preview.kind, language) {
        case (.makkahComfortShort, .russian), (.hotelFirstMakkah, .russian): return "Только Мекка"
        case (.makkahComfortShort, .english), (.hotelFirstMakkah, .english): return "Makkah only"
        case (.makkahComfortShort, .uzbek), (.hotelFirstMakkah, .uzbek): return "Faqat Makka"
        case (.makkahComfortShort, .uzbekCyrillic), (.hotelFirstMakkah, .uzbekCyrillic): return "Фақат Макка"
        case (.makkahMadinahStandard, .russian): return "Мекка + Медина"
        case (.makkahMadinahStandard, .english): return "Makkah + Madinah"
        case (.makkahMadinahStandard, .uzbek): return "Makka + Madina"
        case (.makkahMadinahStandard, .uzbekCyrillic): return "Макка + Мадина"
        }
    }

    private var generatedStampText: String {
        switch language {
        case .russian: return packagePreview == nil ? "iumrah Flights Scanner" : "Сгенерировано iumrah Configurator"
        case .english: return packagePreview == nil ? "iumrah Flights Scanner" : "Generated by iumrah Configurator"
        case .uzbek: return packagePreview == nil ? "iumrah Flights Scanner" : "iumrah Configurator yaratdi"
        case .uzbekCyrillic: return packagePreview == nil ? "iumrah Flights Scanner" : "iumrah Configurator яратди"
        }
    }

    private var packagePerPersonText: String {
        switch language {
        case .russian: return "пакет · 1 человек"
        case .english: return "package · 1 person"
        case .uzbek: return "paket · 1 kishi"
        case .uzbekCyrillic: return "пакет · 1 киши"
        }
    }

    private var calculatingPackageText: String {
        switch language {
        case .russian: return "Считаем пакет"
        case .english: return "Calculating package"
        case .uzbek: return "Paket hisoblanmoqda"
        case .uzbekCyrillic: return "Пакет ҳисобланмоқда"
        }
    }

    private var packageUnavailableText: String {
        switch language {
        case .russian: return "нет пары 2–15 дней"
        case .english: return "no 2–15 day pair"
        case .uzbek: return "2–15 kunlik juftlik yo‘q"
        case .uzbekCyrillic: return "2–15 кунлик жуфтлик йўқ"
        }
    }
}

private enum StorefrontPackageInfoSheet: String, Identifiable {
    case visa
    case guide
    case care
    case trust

    var id: String { rawValue }
}

private struct PackageHotelSelectionTarget: Identifiable, Hashable {
    let hotel: HotelSummary
    let role: HotelSelectionRole

    var id: String { "\(role.rawValue)::\(hotel.id)" }
}

enum StorefrontConfiguratorEntry: Hashable {
    case flightFirst
    case hotelFirst(hotelID: String)
}

private struct StorefrontGroupSavings {
    let percent: Int
    let totalSavings: Decimal
    let perPersonSavings: Decimal
}

private enum StorefrontFlightPickerSheetKind: String, Identifiable {
    case outbound
    case inbound

    var id: String { rawValue }
    var direction: FlightDirection { self == .outbound ? .outbound : .inbound }
}

struct StorefrontUmrahPackageDetailView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var storefront: HotelStorefrontStore
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @ObservedObject private var push = PushNotificationManager.shared

    let preview: StorefrontFlightPackagePreview
    var entry: StorefrontConfiguratorEntry = .flightFirst
    var sharedConfiguration: HotelConfiguratorDeepLink? = nil

    @State private var heroImageIndex = 0
    @State private var isPrepared = false
    @State private var selectedHotelTarget: PackageHotelSelectionTarget?
    @State private var showTransferSelection = false
    @State private var infoSheet: StorefrontPackageInfoSheet?
    @State private var isProfileSheetPresented = false
    @State private var isSubmitting = false
    @State private var bookingError: String?
    @State private var createdBookingID: String?
    @State private var flightPickerSheet: StorefrontFlightPickerSheetKind?
    @State private var selectedOutboundChoice: StorefrontConfiguratorFlightChoice?
    @State private var selectedInboundChoice: StorefrontConfiguratorFlightChoice?
    @State private var initialOutboundFare: Decimal?
    @State private var initialInboundFare: Decimal?
    @State private var suppressQuoteRefresh = false
    @State private var showMadinahFirstCityPicker = false
    @State private var mealsExpanded = false
    @State private var shareArtifacts: IumrahPackageShareArtifacts?
    @State private var activePackageID: String?
    @State private var activePackageFingerprint: String?
    @State private var soloComparisonServerQuote: PackageQuote?
    @State private var twoPersonComparisonServerQuote: PackageQuote?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                packageHero
                overviewCard

                SectionHeader(flightsTitle, eyebrow: "iumrah Flights Scanner", subtitle: nil)
                PackageFlightLegDetailCard(
                    leg: currentOutboundLeg,
                    direction: outboundTitle,
                    language: settings.language,
                    actionTitle: changeTitle
                ) {
                    flightPickerSheet = .outbound
                }
                PackageFlightLegDetailCard(
                    leg: currentInboundLeg,
                    direction: returnTitle,
                    language: settings.language,
                    actionTitle: changeTitle
                ) {
                    flightPickerSheet = .inbound
                }

                if isHotelFirst {
                    hotelFirstRouteCard
                }

                SectionHeader(hotelsTitle, eyebrow: "iumrah Hotels", subtitle: nil)
                ForEach(displayPackageHotels) { hotel in
                    PackageHotelDetailCard(
                        hotel: hotel,
                        selectedRoomName: selectedRoomName(for: hotel),
                        chooseRoomText: chooseRoomTitle,
                        language: settings.language,
                        onOpen: { openHotel(hotel) }
                    )
                }

                SectionHeader(includedTitle, eyebrow: "iumrah", subtitle: nil)
                servicesCard

                travelersCard

                IumrahRefundPolicyCard(component: .package, compact: true)

                PackagePurchaseTrustCard(language: settings.language) {
                    infoSheet = .trust
                }

                priceCard

                if let bookingError {
                    Text(bookingError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                bookingButton

                VStack(spacing: 5) {
                    Label(generatedStamp, systemImage: "seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(IumrahIconRole.umrah.color)
                    let displayedPackageID = activePackageID ?? preview.packageID
                    if displayedPackageID.range(of: "^\\d{10}$", options: .regularExpression) != nil {
                        Text("Package ID · \(displayedPackageID)")
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 34)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(packageNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { presentPackageShare(invitation: false) } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(sharePackageTitle)
            }
        }
        .task {
            await storefront.prepareIfNeeded()
            prepareBookingJourneyIfNeeded()
        }
        .onChange(of: journey.trip) { _, _ in
            guard isPrepared, !suppressQuoteRefresh else { return }
            refreshQuote()
        }
        .onChange(of: journey.trip.travelerCount) { _, newValue in
            guard isPrepared else { return }
            ensureRoomCapacity(for: newValue)
        }
        .navigationDestination(item: $selectedHotelTarget) { target in
            HotelDetailView(
                hotel: target.hotel,
                selectionFlow: true,
                selectionRole: target.role,
                onSelectionSaved: {
                    refreshQuote()
                }
            )
        }
        .navigationDestination(isPresented: $showTransferSelection) {
            TransferSelectionView()
                .onDisappear {
                    guard isPrepared else { return }
                    refreshQuote()
                }
        }
        .navigationDestination(item: $createdBookingID) { bookingID in
            BookingDetailView(bookingID: bookingID)
        }
        .sheet(item: $infoSheet) { sheet in
            StorefrontPackageInformationSheet(
                kind: sheet,
                language: settings.language,
                preview: preview
            )
        }
        .sheet(isPresented: $isProfileSheetPresented) {
            BookingProfileCaptureSheet {
                Task { await createBooking() }
            }
            .environmentObject(settings)
        }
        .sheet(item: $shareArtifacts) { artifacts in
            IumrahPackageActivitySheet(artifacts: artifacts)
        }
        .sheet(item: $flightPickerSheet) { sheet in
            PackageFlightPickerSheet(
                direction: sheet.direction,
                currentAirport: journey.trip.originAirport,
                currentOriginCode: journey.trip.originCode,
                referenceFare: sheet.direction == .outbound ? resolvedOutboundFare : resolvedInboundFare,
                selectedOptionID: sheet.direction == .outbound ? selectedOutboundOptionID : selectedInboundOptionID
            ) { choice, airport, originCode in
                applyFlightChoice(choice, direction: sheet.direction, airport: airport, originCode: originCode)
            }
            .environmentObject(settings)
            .environmentObject(storefront)
            .environmentObject(journey)
        }
        .confirmationDialog(
            firstCityQuestionTitle,
            isPresented: $showMadinahFirstCityPicker,
            titleVisibility: .visible
        ) {
            Button(firstMadinahTitle) { addMadinahToHotelPackage(firstCity: .madinah) }
            Button(firstJeddahTitle) { addMadinahToHotelPackage(firstCity: .jeddah) }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(firstCityQuestionBody)
        }
    }

    private var packageHero: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                TabView(selection: $heroImageIndex) {
                    if heroImages.isEmpty {
                        Image("IumrahFlightsShowcaseHero")
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .tag(0)
                    } else {
                        ForEach(Array(heroImages.enumerated()), id: \.offset) { index, imageURL in
                            HotelCachedImage(rawURL: imageURL)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: proxy.size.width, height: proxy.size.height)

                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 8) {
                    Label("iumrah Configurator", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("\(currentOutboundLeg.origin) → \(currentOutboundLeg.destination) · \(currentInboundLeg.origin) → \(currentInboundLeg.destination)")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(money(currentQuote.pricePerPerson))
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(perPersonShort)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .padding(20)
                .allowsHitTesting(false)

                if heroImages.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(heroImages.indices, id: \.self) { index in
                            Capsule()
                                .fill(Color.white.opacity(index == heroImageIndex ? 0.95 : 0.42))
                                .frame(width: index == heroImageIndex ? 18 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.18), value: heroImageIndex)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .frame(height: 236)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var heroImages: [String] {
        guard let hotel = primaryHotelSummary else {
            return preview.primaryHotel?.coverImageURL.map { [$0] } ?? []
        }
        let values = storefront.previewImages(for: hotel, limit: 6)
        if !values.isEmpty { return values }
        return hotel.coverImageURL.map { [$0] } ?? []
    }

    private var isHotelFirst: Bool {
        if case .hotelFirst = entry { return true }
        return false
    }

    private var selectedOutboundOptionID: String {
        selectedOutboundChoice?.id ?? preview.outboundOptionID
    }

    private var selectedInboundOptionID: String {
        selectedInboundChoice?.id ?? preview.returnOptionID
    }

    private var resolvedOutboundFare: Decimal {
        selectedOutboundChoice?.farePerTravelerUSD ?? initialOutboundFare ?? (preview.flightFarePerPersonUSD / 2)
    }

    private var resolvedInboundFare: Decimal {
        selectedInboundChoice?.farePerTravelerUSD ?? initialInboundFare ?? (preview.flightFarePerPersonUSD / 2)
    }

    private var currentJourneyFarePerPerson: Decimal {
        let value = resolvedOutboundFare + resolvedInboundFare
        return value > 0 ? value : preview.flightFarePerPersonUSD
    }

    private var currentOutboundLeg: StorefrontFlightLeg {
        selectedOutboundChoice?.leg ?? preview.outbound
    }

    private var currentInboundLeg: StorefrontFlightLeg {
        selectedInboundChoice?.leg ?? preview.inbound
    }

    private var currentDurationDays: Int {
        guard let outbound = parseStorefrontISO(currentOutboundLeg.departureAt),
              let inbound = parseStorefrontISO(currentInboundLeg.departureAt) else { return preview.durationDays }
        let calendar = Calendar(identifier: .gregorian)
        return max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: outbound), to: calendar.startOfDay(for: inbound)).day ?? preview.durationDays)
    }

    private var displayPackageHotels: [StorefrontPackageHotel] {
        guard isPrepared, let makkah = journey.selectedHotel else { return preview.hotels }
        let stay = TripStayPlanner.breakdown(for: journey.trip)
        var result = [packageHotelSummary(makkah, nights: stay.makkahNights)]
        if journey.trip.scope == .makkahAndMadinah,
           let madinah = journey.selectedMadinahHotel,
           stay.madinahNights > 0 {
            result.append(packageHotelSummary(madinah, nights: stay.madinahNights))
        }
        return result
    }

    private func packageHotelSummary(_ hotel: HotelSummary, nights: Int) -> StorefrontPackageHotel {
        StorefrontPackageHotel(
            id: hotel.id,
            name: hotel.name,
            city: hotel.city,
            stars: hotel.stars,
            coverImageURL: storefront.previewImages(for: hotel, limit: 1).first ?? hotel.coverImageURL,
            nights: max(1, nights)
        )
    }

    private var hotelFirstRouteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "map.fill", role: .location, size: 44, symbolSize: 17, cornerRadius: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(routeConfiguratorTitle)
                        .font(.headline)
                    Text(journey.trip.scope == .makkahAndMadinah ? makkahMadinahRouteSubtitle : makkahOnlyRouteSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if journey.trip.scope == .makkahAndMadinah {
                Divider()
                Text(firstCityTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Picker(firstCityTitle, selection: Binding(
                    get: { journey.trip.arrivalAirport },
                    set: { setFirstSaudiCity($0) }
                )) {
                    Text(firstJeddahTitle).tag(SaudiArrivalAirport.jeddah)
                    Text(firstMadinahTitle).tag(SaudiArrivalAirport.madinah)
                }
                .pickerStyle(.segmented)

                Button(removeMadinahTitle) {
                    removeMadinahFromHotelPackage()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Button {
                    showMadinahFirstCityPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(addMadinahTitle)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
        }
        .iumrahCard()
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "airplane.departure", role: .travel, size: 46, symbolSize: 18, cornerRadius: 15)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(currentDurationDays) \(daysWord) · \(scopeTitle)")
                        .font(.headline)
                    Text(preview.tier.title(settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if usesTashkentReturnFallback {
                Divider()
                Label(returnFallbackText, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .iumrahCard()
    }

    private var servicesCard: some View {
        VStack(spacing: 0) {
            serviceButtonRow(
                icon: "doc.text.fill",
                title: visaTitle,
                subtitle: visaSummary,
                role: .document
            ) {
                infoSheet = .visa
            }

            Divider().padding(.leading, 54)

            serviceButtonRow(
                icon: "car.side.fill",
                title: transferTitle,
                subtitle: journey.selectedTransferVehicle?.modelName ?? "Kia Carnival",
                role: .transfer
            ) {
                journey.transferSelectionConfirmed = false
                showTransferSelection = true
            }

            Divider().padding(.leading, 54)

            if supportsOptionalMeals {
                expandableServiceButtonRow(
                    icon: "fork.knife",
                    title: mealsTitle,
                    subtitle: mealsSummary,
                    role: .hotel,
                    expanded: mealsExpanded
                ) {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        mealsExpanded.toggle()
                    }
                }
                if mealsExpanded {
                    Divider().padding(.leading, 54)
                    packageMealConfigurator
                        .padding(.leading, 54)
                        .padding(.trailing, 4)
                        .padding(.bottom, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                serviceRow(
                    icon: "fork.knife",
                    title: mealsTitle,
                    subtitle: mealsSummary,
                    role: .hotel
                )
            }

            Divider().padding(.leading, 54)

            serviceButtonRow(
                icon: "person.crop.circle.badge.checkmark",
                title: guideTitle,
                subtitle: guideSummary,
                role: .care
            ) {
                infoSheet = .guide
            }

            Divider().padding(.leading, 54)
            serviceRow(icon: "mappin.and.ellipse", title: makkahZiyaratTitle, subtitle: nil, role: .location)
            if journey.trip.scope == .makkahAndMadinah {
                Divider().padding(.leading, 54)
                serviceRow(icon: "mappin.circle.fill", title: madinahZiyaratTitle, subtitle: nil, role: .location)
            }
            Divider().padding(.leading, 54)
            serviceButtonRow(
                icon: "heart.fill",
                title: "iumrah Care",
                subtitle: careSummary,
                role: .care
            ) {
                infoSheet = .care
            }
        }
        .iumrahCard()
    }

    private func serviceRow(icon: String, title: String, subtitle: String?, role: IumrahIconRole) -> some View {
        HStack(spacing: 12) {
            IumrahIconBadge(systemName: icon, role: role, size: 40, symbolSize: 15, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(IumrahIconRole.success.color)
        }
        .padding(.vertical, 11)
    }

    private func serviceButtonRow(
        icon: String,
        title: String,
        subtitle: String,
        role: IumrahIconRole,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: icon, role: role, size: 40, symbolSize: 15, cornerRadius: 13)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func expandableServiceButtonRow(
        icon: String,
        title: String,
        subtitle: String,
        role: IumrahIconRole,
        expanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: icon, role: role, size: 40, symbolSize: 15, cornerRadius: 13)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var supportsOptionalMeals: Bool {
        let tier = isPrepared ? journey.trip.packageTier : preview.tier
        return tier == .comfort || tier == .luxury
    }

    private var packageMealConfigurator: some View {
        VStack(alignment: .leading, spacing: 14) {
            mealCitySection(city: .makkah)
            if journey.trip.scope == .makkahAndMadinah {
                Divider()
                mealCitySection(city: .madinah)
            }
        }
        .padding(14)
        .background(Color.iumrahRaisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.6)
        }
    }

    @ViewBuilder
    private func mealCitySection(city: HotelMealCity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(city == .makkah
                ? tr("Мекка", "Makkah", "Makka", "Макка")
                : tr("Медина", "Madinah", "Madina", "Мадина")
            )
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                IumrahInlineIcon(systemName: "cup.and.saucer.fill", role: .hotel, size: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(mealLabel(.breakfast))
                        .font(.subheadline.weight(.semibold))
                    Text(mealIncludedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(IumrahIconRole.success.color)
            }

            Divider()

            if city == .makkah {
                mealToggleRow(.lunch, city: city)
                Divider()
            }
            mealToggleRow(.dinner, city: city)
        }
    }

    private func mealToggleRow(_ meal: HotelMealKind, city: HotelMealCity) -> some View {
        let unit = PackagePricingPresentation.optionalMealUnitPriceUsd(for: journey.trip.packageTier) ?? 0
        let binding = Binding(
            get: { journey.isMealEnabled(meal, city: city) },
            set: { journey.setMealEnabled($0, meal: meal, city: city) }
        )

        return HStack(spacing: 10) {
            IumrahInlineIcon(systemName: meal == .lunch ? "sun.max.fill" : "moon.stars.fill", role: .hotel, size: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(mealLabel(meal))
                    .font(.subheadline.weight(.semibold))
                Text(optionalMealLabel(unit))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(Color.iumrahCareLight)
        }
    }

    private func mealLabel(_ meal: HotelMealKind) -> String {
        switch (settings.language, meal) {
        case (.russian, .breakfast): return "Завтрак"
        case (.russian, .lunch): return "Обед"
        case (.russian, .dinner): return "Ужин"
        case (.english, .breakfast): return "Breakfast"
        case (.english, .lunch): return "Lunch"
        case (.english, .dinner): return "Dinner"
        case (.uzbek, .breakfast): return "Nonushta"
        case (.uzbek, .lunch): return "Tushlik"
        case (.uzbek, .dinner): return "Kechki ovqat"
        case (.uzbekCyrillic, .breakfast): return "Нонушта"
        case (.uzbekCyrillic, .lunch): return "Тушлик"
        case (.uzbekCyrillic, .dinner): return "Кечки овқат"
        }
    }

    private var mealIncludedLabel: String {
        tr("Включено · без доплаты", "Included · no extra charge", "Kiritilgan · qo‘shimcha to‘lovsiz", "Киритилган · қўшимча тўловсиз")
    }

    private func optionalMealLabel(_ unit: Decimal) -> String {
        let amount = NSDecimalNumber(decimal: unit).intValue
        return tr(
            "$\(amount) · за человека / день",
            "$\(amount) · per person / day",
            "$\(amount) · kishi / kun",
            "$\(amount) · киши / кун"
        )
    }

    private var travelersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            groupSavingsCard

            Label(L10n.text("trip_travelers_title", settings.language), systemImage: "person.2")
                .font(.headline)
                .padding(.top, 2)

            Text(travelersBody)
                .font(.caption)
                .foregroundStyle(.secondary)

            CounterRow(
                title: L10n.text("adults", settings.language),
                subtitle: nil,
                value: $journey.trip.adults,
                minimum: 1,
                maximum: max(1, 9 - journey.trip.children - journey.trip.infants)
            )
            Divider()
            CounterRow(
                title: L10n.text("children", settings.language),
                subtitle: L10n.text("children_age", settings.language),
                value: $journey.trip.children,
                minimum: 0,
                maximum: max(0, 9 - journey.trip.adults - journey.trip.infants)
            )
            Divider()
            CounterRow(
                title: L10n.text("infants", settings.language),
                subtitle: L10n.text("infants_age", settings.language),
                value: $journey.trip.infants,
                minimum: 0,
                maximum: min(4, max(0, 9 - journey.trip.adults - journey.trip.children))
            )
            Divider()
            CounterRow(
                title: L10n.text("rooms", settings.language),
                subtitle: roomCapacitySubtitle,
                value: $journey.trip.rooms,
                minimum: minimumRecommendedRooms,
                maximum: 9
            )

            Button {
                presentPackageShare(invitation: true)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                    Text(invitePilgrimTitle)
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .padding(.top, 6)
        }
        .iumrahCard()
    }

    @ViewBuilder
    private var groupSavingsCard: some View {
        let count = max(1, journey.trip.travelerCount)
        if count == 1 {
            let comparison = twoPersonSavings
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                    Text(singleTravelerWarningTitle)
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Color(uiColor: .systemOrange))

                if let comparison, comparison.percent > 0 {
                    Text(singleTravelerWarningBody(percent: comparison.percent, savings: comparison.totalSavings))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(singleTravelerFallbackBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .systemOrange).opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else if let savings = currentPartySavings, savings.percent > 0 {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(count == 2 ? "iumrah Family Package" : "iumrah Friends Package")
                            .font(.headline)
                        Text(groupSavingsComparisonCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("−\(savings.percent)%")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(groupSavingsTotalText(savings.totalSavings))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(groupSavingsPerPersonText(savings.perPersonSavings))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (count == 2 ? Color(uiColor: .systemPurple) : Color(uiColor: .systemTeal)).opacity(0.10),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(finalPriceTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .lastTextBaseline) {
                Text(money(currentQuote.totalPackagePrice))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                Spacer()
                Text(totalForTravelersText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Label("\(money(currentQuote.pricePerPerson)) · \(perPersonLong)", systemImage: "person.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .iumrahCard()
    }

    private var bookingButton: some View {
        Button {
            isProfileSheetPresented = true
        } label: {
            HStack(spacing: 12) {
                if isSubmitting {
                    ProgressView().tint(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSubmitting ? bookingInProgressTitle : bookTripTitle)
                        .font(.headline)
                    if !isSubmitting {
                        Text("\(money(currentQuote.totalPackagePrice)) · \(totalForTravelersText)")
                            .font(.caption.weight(.semibold))
                            .opacity(0.76)
                    }
                }
                Spacer(minLength: 8)
                if !isSubmitting {
                    Image(systemName: "arrow.right")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(!canBook || isSubmitting)
        .opacity(canBook && !isSubmitting ? 1 : 0.45)
    }

    private var currentQuote: PackageQuote {
        journey.quote ?? preview.packageQuote
    }

    private func hypotheticalQuote(adults: Int, children: Int, infants: Int, rooms: Int) async -> PackageQuote? {
        guard isPrepared, let makkahHotel = journey.selectedHotel else { return nil }
        var trip = journey.trip
        trip.adults = max(1, adults)
        trip.children = max(0, children)
        trip.infants = max(0, infants)
        trip.rooms = max(1, rooms)
        return await storefront.checkoutQuote(
            for: preview,
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: journey.selectedMadinahHotel,
            makkahRoomID: journey.selectedRoom?.id ?? journey.selectedRoomCategory?.id,
            madinahRoomID: journey.selectedMadinahRoom?.id ?? journey.selectedMadinahRoomCategory?.id,
            transferVehicle: journey.selectedTransferVehicle,
            includeHaramainTrain: journey.haramainTrainSelected,
            haramainPublicAddOnUsd: journey.haramainTrainAddOnUsd,
            haramainFareClass: journey.haramainFareClass,
            haramainTicketCount: journey.haramainTicketCount,
            journeyFarePerPersonUSD: currentJourneyFarePerPerson,
            outboundOffer: journey.selectedOutbound,
            inboundOffer: journey.selectedInbound
        )
    }

    private var soloComparisonQuote: PackageQuote? { soloComparisonServerQuote }

    private var twoPersonSavings: StorefrontGroupSavings? {
        guard let solo = soloComparisonServerQuote,
              let pair = twoPersonComparisonServerQuote else { return nil }
        return savings(comparedWithSolo: solo, groupQuote: pair, people: 2)
    }

    private var currentPartySavings: StorefrontGroupSavings? {
        let people = max(1, journey.trip.travelerCount)
        guard people > 1, let solo = soloComparisonServerQuote else { return nil }
        return savings(comparedWithSolo: solo, groupQuote: currentQuote, people: people)
    }

    @MainActor
    private func refreshComparisonQuotes() async {
        async let solo = hypotheticalQuote(adults: 1, children: 0, infants: 0, rooms: 1)
        async let pair = hypotheticalQuote(adults: 2, children: 0, infants: 0, rooms: 1)
        let values = await (solo, pair)
        soloComparisonServerQuote = values.0
        twoPersonComparisonServerQuote = values.1
    }

    private func savings(comparedWithSolo solo: PackageQuote, groupQuote: PackageQuote, people: Int) -> StorefrontGroupSavings? {
        let count = max(1, people)
        let comparisonTotal = solo.totalPackagePrice * Decimal(count)
        guard comparisonTotal > 0 else { return nil }
        let saved = max(0, comparisonTotal - groupQuote.totalPackagePrice)
        let perPerson = saved / Decimal(count)
        let ratio = NSDecimalNumber(decimal: (saved / comparisonTotal) * 100).doubleValue
        return StorefrontGroupSavings(
            percent: max(0, Int(ratio.rounded())),
            totalSavings: saved,
            perPersonSavings: perPerson
        )
    }

    private var effectiveRoomCapacity: Int {
        let makkah = journey.selectedRoom?.maxGuests ?? journey.selectedRoomCategory?.maxGuests ?? 4
        guard journey.trip.scope == .makkahAndMadinah else { return max(1, makkah) }
        let madinah = journey.selectedMadinahRoom?.maxGuests ?? journey.selectedMadinahRoomCategory?.maxGuests ?? 4
        return max(1, min(makkah, madinah))
    }

    private func recommendedRooms(for travelers: Int) -> Int {
        let count = max(1, travelers)
        let capacity = max(1, effectiveRoomCapacity)
        return max(1, Int(ceil(Double(count) / Double(capacity))))
    }

    private var minimumRecommendedRooms: Int {
        recommendedRooms(for: journey.trip.travelerCount)
    }

    @MainActor
    private func ensureRoomCapacity(for travelers: Int) {
        let minimum = recommendedRooms(for: travelers)
        guard journey.trip.rooms < minimum else { return }
        journey.trip.rooms = minimum
    }

    private var roomCapacitySubtitle: String {
        tr(
            "Минимум \(minimumRecommendedRooms) · до \(effectiveRoomCapacity) гостей в выбранной комнате",
            "Minimum \(minimumRecommendedRooms) · up to \(effectiveRoomCapacity) guests in the selected room",
            "Kamida \(minimumRecommendedRooms) · tanlangan xonada \(effectiveRoomCapacity) kishigacha",
            "Камида \(minimumRecommendedRooms) · танланган хонада \(effectiveRoomCapacity) кишигача"
        )
    }

    private var sharePackageTitle: String {
        tr("Поделиться пакетом", "Share package", "Paketni ulashish", "Пакетни улашиш")
    }

    private var invitePilgrimTitle: String {
        tr("Пригласить паломника", "Invite a pilgrim", "Ziyoratchini taklif qilish", "Зиёратчини таклиф қилиш")
    }

    private var singleTravelerWarningTitle: String {
        tr("Для одного человека пакет дороже", "Solo travel costs more", "Bir kishi uchun paket qimmatroq", "Бир киши учун пакет қимматроқ")
    }

    private func singleTravelerWarningBody(percent: Int, savings: Decimal) -> String {
        tr(
            "Если ехать вдвоём, цена на человека сейчас ниже примерно на \(percent)%. Вместе двое экономят \(money(savings)) по сравнению с двумя отдельными такими поездками.",
            "For two pilgrims, the current per-person price is about \(percent)% lower. Together, two save \(money(savings)) versus two separate solo packages.",
            "Ikki kishi bo‘lib borsangiz, kishi boshiga narx hozir taxminan \(percent)% arzon. Ikki alohida yakka paketga nisbatan jami \(money(savings)) tejaysiz.",
            "Икки киши бўлиб борсангиз, киши бошига нарх ҳозир тахминан \(percent)% арзон. Икки алоҳида якка пакетга нисбатан жами \(money(savings)) тежайсиз."
        )
    }

    private var singleTravelerFallbackBody: String {
        tr(
            "Совместная поездка обычно снижает цену на человека, потому что номер, трансфер, сопровождение и часть сервисов распределяются на группу.",
            "Travelling together usually lowers the per-person price because rooms, transfers, assistance and group services are shared.",
            "Birga safar qilish odatda kishi boshiga narxni pasaytiradi: xona, transfer, hamrohlik va guruh xizmatlari bo‘linadi.",
            "Бирга сафар қилиш одатда киши бошига нархни пасайтиради: хона, трансфер, ҳамроҳлик ва гуруҳ хизматлари бўлинади."
        )
    }

    private var groupSavingsComparisonCaption: String {
        tr(
            "Сравнение с таким же пакетом для 1 паломника",
            "Compared with the same package for 1 pilgrim",
            "Xuddi shu 1 kishilik paket bilan solishtirganda",
            "Худди шу 1 кишилик пакет билан солиштирганда"
        )
    }

    private func groupSavingsTotalText(_ value: Decimal) -> String {
        tr(
            "Экономия группы \(money(value))",
            "Group saves \(money(value))",
            "Guruh tejaydi: \(money(value))",
            "Гуруҳ тежайди: \(money(value))"
        )
    }

    private func groupSavingsPerPersonText(_ value: Decimal) -> String {
        tr(
            "\(money(value)) на человека",
            "\(money(value)) per person",
            "kishi boshiga \(money(value))",
            "киши бошига \(money(value))"
        )
    }

    private func presentPackageShare(invitation: Bool) {
        Task { @MainActor in
            await preparePackageShare(invitation: invitation)
        }
    }

    @MainActor
    private func preparePackageShare(invitation: Bool) async {
        guard isPrepared, let hotel = journey.selectedHotel else {
            bookingError = packagePreparationErrorText
            return
        }
        let anchorCity = isHotelFirst ? (preview.hotelFirstAnchorCity ?? "Makkah") : "Makkah"
        let anchorHotel: HotelSummary = {
            if anchorCity == "Madinah", let madinah = journey.selectedMadinahHotel { return madinah }
            return hotel
        }()

        let config = StorefrontPackageSnapshotConfiguration(
            adults: max(1, journey.trip.adults),
            children: max(0, journey.trip.children),
            infants: max(0, journey.trip.infants),
            rooms: max(1, journey.trip.rooms),
            makkahLunch: journey.trip.effectiveMealSelection.makkahLunch,
            makkahDinner: journey.trip.effectiveMealSelection.makkahDinner,
            madinahDinner: journey.trip.effectiveMealSelection.madinahDinner,
            transferVehicle: journey.selectedTransferVehicle?.rawValue,
            haramainEnabled: journey.haramainTrainSelected,
            haramainFareClass: journey.haramainFareClass.rawValue,
            haramainTicketCount: journey.haramainTicketCount,
            makkahRoomId: journey.selectedRoom?.id ?? journey.selectedRoomCategory?.id,
            madinahRoomId: journey.selectedMadinahRoom?.id ?? journey.selectedMadinahRoomCategory?.id
        )
        let baseConfig = preview.snapshotConfiguration ?? StorefrontPackageSnapshotConfiguration(
            adults: 2,
            children: 0,
            infants: 0,
            rooms: 1,
            makkahLunch: false,
            makkahDinner: false,
            madinahDinner: false,
            transferVehicle: TransferVehicleKind.carnival.rawValue,
            haramainEnabled: false,
            haramainFareClass: HaramainFareClass.economy.rawValue,
            haramainTicketCount: 0,
            makkahRoomId: nil,
            madinahRoomId: nil
        )
        let originalMakkahID = preview.hotels.first(where: { !isMadinahCity($0.city) })?.id
        let originalMadinahID = preview.hotels.first(where: { isMadinahCity($0.city) })?.id
        let packageChanged = config != baseConfig
            || selectedOutboundOptionID != preview.outboundOptionID
            || selectedInboundOptionID != preview.returnOptionID
            || hotel.id != originalMakkahID
            || journey.selectedMadinahHotel?.id != originalMadinahID
            || currentQuote.totalPackagePrice != preview.totalPackagePrice
            || currentQuote.pricePerPerson != preview.pricePerPerson
        let packageFingerprint = [
            String(config.adults), String(config.children), String(config.infants), String(config.rooms),
            config.makkahLunch ? "1" : "0", config.makkahDinner ? "1" : "0", config.madinahDinner ? "1" : "0",
            config.transferVehicle ?? "", config.haramainEnabled ? "1" : "0", config.haramainFareClass, String(config.haramainTicketCount),
            config.makkahRoomId ?? "", config.madinahRoomId ?? "", selectedOutboundOptionID, selectedInboundOptionID,
            hotel.id, journey.selectedMadinahHotel?.id ?? "", String(describing: currentQuote.totalPackagePrice), String(describing: currentQuote.pricePerPerson)
        ].joined(separator: "|")

        var packageID = packageChanged ? (activePackageID ?? preview.packageID) : preview.packageID
        var sharedTotalPrice = currentQuote.totalPackagePrice
        var sharedPerPersonPrice = currentQuote.pricePerPerson
        let alreadyPersistedCurrentState = activePackageFingerprint == packageFingerprint
            && activePackageID?.range(of: "^\\d{10}$", options: .regularExpression) != nil
        if packageChanged && !alreadyPersistedCurrentState {
            let stay = TripStayPlanner.breakdown(for: journey.trip)
            let secondary = journey.trip.scope == .makkahAndMadinah ? journey.selectedMadinahHotel : nil
            let snapshot = StorefrontServerPackageSnapshot(
                id: "",
                entryMode: isHotelFirst ? "hotel-first" : "flight-first",
                status: "ready",
                originCode: currentOutboundLeg.origin.uppercased(),
                originCity: currentOutboundLeg.origin.uppercased(),
                destinationCode: currentOutboundLeg.destination.uppercased(),
                tier: journey.trip.packageTier,
                kind: journey.trip.scope == .makkahOnly ? "makkah-only" : "makkah-madinah",
                startDate: String(currentOutboundLeg.departureAt.prefix(10)),
                endDate: String(currentInboundLeg.departureAt.prefix(10)),
                totalDays: max(1, currentDurationDays),
                totalNights: max(1, stay.totalNights),
                makkahNights: max(1, stay.makkahNights),
                madinahNights: max(0, stay.madinahNights),
                hotelFirstVariant: isHotelFirst ? preview.hotelFirstVariant : nil,
                hotelFirstVariantIndex: isHotelFirst ? preview.hotelFirstVariantIndex : nil,
                hotelFirstVariantMinDays: isHotelFirst ? preview.hotelFirstVariantMinDays : nil,
                hotelFirstVariantMaxDays: isHotelFirst ? preview.hotelFirstVariantMaxDays : nil,
                hotelFirstAnchorCity: isHotelFirst ? anchorCity : nil,
                hotelFirstAnchorHotelId: isHotelFirst ? anchorHotel.id : nil,
                outbound: .init(
                    airline: currentOutboundLeg.airline,
                    airlineCode: currentOutboundLeg.airlineCode,
                    flightNumber: currentOutboundLeg.flightNumber,
                    origin: currentOutboundLeg.origin,
                    destination: currentOutboundLeg.destination,
                    departureAt: currentOutboundLeg.departureAt,
                    arrivalAt: currentOutboundLeg.arrivalAt,
                    durationMinutes: currentOutboundLeg.durationMinutes,
                    stops: currentOutboundLeg.stops,
                    cabinClass: currentOutboundLeg.cabinClass
                ),
                inbound: .init(
                    airline: currentInboundLeg.airline,
                    airlineCode: currentInboundLeg.airlineCode,
                    flightNumber: currentInboundLeg.flightNumber,
                    origin: currentInboundLeg.origin,
                    destination: currentInboundLeg.destination,
                    departureAt: currentInboundLeg.departureAt,
                    arrivalAt: currentInboundLeg.arrivalAt,
                    durationMinutes: currentInboundLeg.durationMinutes,
                    stops: currentInboundLeg.stops,
                    cabinClass: currentInboundLeg.cabinClass
                ),
                providerItineraryId: "curated:\(selectedOutboundOptionID)+\(selectedInboundOptionID)",
                outboundOfferId: selectedOutboundOptionID,
                inboundOfferId: selectedInboundOptionID,
                imageUrl: storefront.previewImages(for: anchorHotel, limit: 1).first ?? anchorHotel.coverImageURL ?? "/iumrah/hotels-showcase.jpeg",
                hotelImages: storefront.previewImages(for: anchorHotel, limit: 6),
                hotelName: hotel.name,
                hotelSecondaryName: secondary?.name,
                hotelCity: anchorHotel.city,
                hotelStars: anchorHotel.stars,
                makkahHotelId: hotel.id,
                madinahHotelId: secondary?.id,
                routeSummary: "\(currentOutboundLeg.origin) → \(currentOutboundLeg.destination) + \(currentInboundLeg.origin) → \(currentInboundLeg.destination)",
                pricePerPerson: currentQuote.pricePerPerson,
                totalPackagePrice: currentQuote.totalPackagePrice,
                currency: currentQuote.currency,
                isEstimated: currentQuote.isEstimated,
                configuration: config
            )
            do {
                let persisted = try await HotelStorefrontService().createPackageSnapshot(
                    snapshot,
                    parentPackageID: (activePackageID ?? preview.packageID).range(of: "^\\d{10}$", options: .regularExpression) != nil ? (activePackageID ?? preview.packageID) : nil
                )
                packageID = persisted.id
                activePackageID = persisted.id
                activePackageFingerprint = packageFingerprint
                sharedTotalPrice = persisted.totalPackagePrice ?? currentQuote.totalPackagePrice
                sharedPerPersonPrice = persisted.pricePerPerson ?? currentQuote.pricePerPerson
            } catch {
                bookingError = tr(
                    "Не удалось сохранить новый Package ID. Попробуйте ещё раз.",
                    "Could not save the new Package ID. Please try again.",
                    "Yangi Package ID saqlanmadi. Qayta urinib ko‘ring.",
                    "Янги Package ID сақланмади. Қайта уриниб кўринг."
                )
                IumrahHaptics.error()
                return
            }
        }

        let payload = IumrahPackageSharePayload(
            packageID: packageID,
            hotelID: anchorHotel.id,
            hotelName: anchorHotel.name,
            tierName: journey.trip.packageTier.title(settings.language),
            outboundRoute: "\(currentOutboundLeg.origin) → \(currentOutboundLeg.destination)",
            inboundRoute: "\(currentInboundLeg.origin) → \(currentInboundLeg.destination)",
            outboundAt: currentOutboundLeg.departureAt,
            inboundAt: currentInboundLeg.departureAt,
            durationDays: currentDurationDays,
            travelers: max(1, journey.trip.travelerCount),
            adults: max(1, journey.trip.adults),
            children: max(0, journey.trip.children),
            infants: max(0, journey.trip.infants),
            rooms: max(1, journey.trip.rooms),
            scope: journey.trip.scope,
            firstSaudiCity: journey.trip.arrivalAirport,
            mealSelection: journey.trip.effectiveMealSelection,
            totalPriceUSD: sharedTotalPrice,
            perPersonPriceUSD: sharedPerPersonPrice,
            mealsSummary: mealsSummary,
            scopeSummary: scopeTitle,
            outboundOptionID: selectedOutboundOptionID,
            inboundOptionID: selectedInboundOptionID
        )
        do {
            shareArtifacts = try IumrahPackageShareFactory.make(
                payload: payload,
                language: settings.language,
                invitation: invitation
            )
            IumrahHaptics.selection()
        } catch {
            bookingError = tr(
                "Не удалось подготовить карточку пакета для отправки. Попробуйте ещё раз.",
                "Could not prepare the package share card. Please try again.",
                "Paketni ulashish kartasini tayyorlab bo‘lmadi. Qayta urinib ko‘ring.",
                "Пакетни улашиш картасини тайёрлаб бўлмади. Қайта уриниб кўринг."
            )
            IumrahHaptics.error()
        }
    }

    private var primaryHotelSummary: HotelSummary? {
        guard let id = preview.primaryHotel?.id else { return nil }
        return storefront.hotel(id: id)
    }

    private var canBook: Bool {
        guard isPrepared,
              journey.hasFinalGeneratorQuote,
              journey.selectedHotel != nil,
              journey.selectedOutbound != nil,
              journey.selectedInbound != nil else { return false }
        if journey.trip.scope == .makkahAndMadinah, journey.selectedMadinahHotel == nil { return false }
        return true
    }

    private func openHotel(_ packageHotel: StorefrontPackageHotel) {
        guard let hotel = storefront.hotel(id: packageHotel.id) else {
            bookingError = hotelUnavailableText
            IumrahHaptics.error()
            return
        }
        let role: HotelSelectionRole = isMadinahCity(packageHotel.city) ? .madinah : .makkah
        selectedHotelTarget = PackageHotelSelectionTarget(hotel: hotel, role: role)
    }

    private func selectedRoomName(for packageHotel: StorefrontPackageHotel) -> String? {
        let role: HotelSelectionRole = isMadinahCity(packageHotel.city) ? .madinah : .makkah
        switch role {
        case .makkah:
            if let room = journey.selectedRoom { return room.name }
            if let category = journey.selectedRoomCategory { return L10n.text(category.category.titleKey, settings.language) }
        case .madinah:
            if let room = journey.selectedMadinahRoom { return room.name }
            if let category = journey.selectedMadinahRoomCategory { return L10n.text(category.category.titleKey, settings.language) }
        }
        return nil
    }

    private func isMadinahCity(_ city: String) -> Bool {
        let value = city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
        return value.contains("madin") || value.contains("medin")
    }

    @MainActor
    private func prepareBookingJourneyIfNeeded() {
        guard !isPrepared else { return }
        guard let makkahPackageHotel = preview.hotels.first(where: { !isMadinahCity($0.city) }),
              let makkahHotel = storefront.hotel(id: makkahPackageHotel.id),
              let outboundDeparture = parseStorefrontISO(preview.outbound.departureAt),
              let outboundArrival = parseStorefrontISO(preview.outbound.arrivalAt),
              let returnDeparture = parseStorefrontISO(preview.inbound.departureAt),
              let offers = storefront.bookingFlightOffers(for: preview) else {
            bookingError = packagePreparationErrorText
            return
        }

        let snapshotShared: HotelConfiguratorDeepLink? = preview.snapshotConfiguration.map { config in
            HotelConfiguratorDeepLink(
                hotelID: preview.hotelFirstAnchorHotelID ?? makkahHotel.id,
                adults: config.adults,
                children: config.children,
                infants: config.infants,
                rooms: config.rooms,
                scope: preview.kind == .makkahComfortShort || preview.kind == .hotelFirstMakkah ? .makkahOnly : .makkahAndMadinah,
                firstSaudiCity: preview.outbound.destination.uppercased() == "MED" ? .madinah : .jeddah,
                mealSelection: config.mealSelection,
                outboundOptionID: preview.outboundOptionID,
                inboundOptionID: preview.returnOptionID
            )
        }
        let expectedSharedHotelID = preview.hotelFirstAnchorHotelID ?? makkahHotel.id
        let shared = (isHotelFirst && sharedConfiguration?.hotelID == expectedSharedHotelID ? sharedConfiguration : nil) ?? snapshotShared

        let initialScope: JourneyScope
        if isHotelFirst {
            initialScope = shared?.scope ?? (preview.madinahNights > 0 ? .makkahAndMadinah : .makkahOnly)
        } else {
            initialScope = preview.kind == .makkahComfortShort ? .makkahOnly : .makkahAndMadinah
        }

        let madinahHotel: HotelSummary?
        if initialScope == .makkahAndMadinah {
            if let packageHotel = preview.hotels.first(where: { isMadinahCity($0.city) }),
               let resolved = storefront.hotel(id: packageHotel.id) {
                madinahHotel = resolved
            } else if isHotelFirst, let resolved = storefront.defaultMadinahHotel(for: preview.tier) {
                madinahHotel = resolved
            } else {
                bookingError = packagePreparationErrorText
                return
            }
        } else {
            madinahHotel = nil
        }

        let preservedAirport = journey.trip.originAirport?.iata.uppercased() == preview.outbound.origin.uppercased()
            ? journey.trip.originAirport
            : nil

        var trip = TripDraft()
        trip.origin = preview.outbound.origin.uppercased()
        trip.originAirport = preservedAirport
        trip.arrivalAirport = shared?.firstSaudiCity ?? (preview.outbound.destination.uppercased() == "MED" ? .madinah : .jeddah)
        trip.departureDate = Calendar.current.startOfDay(for: outboundDeparture)
        trip.saudiArrivalDate = Calendar.current.startOfDay(for: outboundArrival)
        trip.returnDate = Calendar.current.startOfDay(for: returnDeparture)
        trip.flexibility = .exact
        trip.adults = min(9, max(1, shared?.adults ?? 2))
        trip.children = min(8, max(0, shared?.children ?? 0))
        trip.infants = min(4, max(0, shared?.infants ?? 0))
        let restoredTravelerTotal = trip.adults + trip.children + trip.infants
        if restoredTravelerTotal > 9 {
            let overflow = restoredTravelerTotal - 9
            if trip.infants >= overflow {
                trip.infants -= overflow
            } else {
                let remaining = overflow - trip.infants
                trip.infants = 0
                trip.children = max(0, trip.children - remaining)
            }
        }
        trip.rooms = min(9, max(1, shared?.rooms ?? 1))
        trip.hotelStars = preview.tier.primaryHotelStars
        trip.packageTier = preview.tier
        trip.mealSelection = shared?.mealSelection
        trip.scope = initialScope
        trip.hotelFirstStayPolicy = isHotelFirst ? true : nil
        trip.flightTripType = .roundTrip

        initialOutboundFare = storefront.publishedFarePerTraveler(optionID: preview.outboundOptionID)
        initialInboundFare = storefront.publishedFarePerTraveler(optionID: preview.returnOptionID)
        if preview.outboundOptionID == preview.returnOptionID {
            initialOutboundFare = preview.flightFarePerPersonUSD / 2
            initialInboundFare = preview.flightFarePerPersonUSD / 2
        } else if let outbound = initialOutboundFare, initialInboundFare == nil {
            initialInboundFare = max(0, preview.flightFarePerPersonUSD - outbound)
        } else if let inbound = initialInboundFare, initialOutboundFare == nil {
            initialOutboundFare = max(0, preview.flightFarePerPersonUSD - inbound)
        }

        suppressQuoteRefresh = true
        journey.resetAfterTripChange()
        journey.trip = trip
        journey.packageFlightPath = .publishedDirect
        journey.selectedPublishedCompleteID = preview.outboundOptionID == preview.returnOptionID ? preview.outboundOptionID : nil
        journey.selectedPublishedOutboundID = preview.outboundOptionID
        journey.selectedPublishedReturnID = preview.returnOptionID
        journey.hotels = storefront.makkahHotels
        journey.madinahHotels = storefront.madinahHotels
        journey.selectedHotel = makkahHotel
        journey.selectedMadinahHotel = madinahHotel
        journey.selectedRoom = nil
        journey.selectedRoomCategory = nil
        journey.selectedMadinahRoom = nil
        journey.selectedMadinahRoomCategory = nil
        journey.selectedOutbound = offers.outbound
        journey.selectedInbound = offers.inbound
        journey.selectedTransferVehicle = preview.snapshotConfiguration?.transferVehicle
            .flatMap(TransferVehicleKind.init(rawValue:)) ?? .carnival
        journey.haramainTrainSelected = preview.snapshotConfiguration?.haramainEnabled ?? false
        journey.haramainFareClass = preview.snapshotConfiguration
            .flatMap { HaramainFareClass(rawValue: $0.haramainFareClass) } ?? .economy
        journey.haramainTicketCount = max(0, preview.snapshotConfiguration?.haramainTicketCount ?? 0)
        journey.transferSelectionConfirmed = false
        journey.quote = preview.packageQuote
        journey.errorMessage = nil
        heroImageIndex = 0

        if let shared {
            restoreSharedFlightSelections(shared)
            ensureRoomCapacity(for: journey.trip.travelerCount)
        }

        isPrepared = true
        suppressQuoteRefresh = false

        // Keep the already-rendered storefront number on screen, then obtain the
        // authoritative dated server quote (and opaque booking proof) in-place.
        // The UI does not change; only the pricing owner moves to PackageEngine.
        refreshQuote()
    }

    @MainActor
    private func refreshQuote() {
        guard isPrepared,
              let makkahHotel = journey.selectedHotel else { return }

        let expectedTrip = journey.trip
        let expectedMakkahID = makkahHotel.id
        let expectedMadinahID = journey.selectedMadinahHotel?.id
        let makkahRoomID = journey.selectedRoom?.id ?? journey.selectedRoomCategory?.id
        let madinahRoomID = journey.selectedMadinahRoom?.id ?? journey.selectedMadinahRoomCategory?.id
        let transferVehicle = journey.selectedTransferVehicle
        let includeTrain = journey.haramainTrainSelected
        let trainAddOn = journey.haramainTrainAddOnUsd
        let trainClass = journey.haramainFareClass
        let trainTickets = journey.haramainTicketCount
        let outbound = journey.selectedOutbound
        let inbound = journey.selectedInbound
        let fare = currentJourneyFarePerPerson
        let madinahHotel = journey.selectedMadinahHotel

        Task { @MainActor in
            let quote = await storefront.checkoutQuote(
                for: preview,
                trip: expectedTrip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                makkahRoomID: makkahRoomID,
                madinahRoomID: madinahRoomID,
                transferVehicle: transferVehicle,
                includeHaramainTrain: includeTrain,
                haramainPublicAddOnUsd: trainAddOn,
                haramainFareClass: trainClass,
                haramainTicketCount: trainTickets,
                journeyFarePerPersonUSD: fare,
                outboundOffer: outbound,
                inboundOffer: inbound
            )

            guard journey.trip == expectedTrip,
                  journey.selectedHotel?.id == expectedMakkahID,
                  journey.selectedMadinahHotel?.id == expectedMadinahID else { return }
            if let quote {
                journey.quote = quote
                bookingError = nil
                await refreshComparisonQuotes()
            } else {
                bookingError = priceRefreshErrorText
            }
        }
    }

    @MainActor
    private func restoreSharedFlightSelections(_ configuration: HotelConfiguratorDeepLink) {
        journey.selectedPublishedCompleteID = nil

        if let outboundID = configuration.outboundOptionID {
            let choices = storefront.configurableFlightChoices(direction: .outbound, trip: journey.trip)
            if let choice = (choices.primary + choices.other).first(where: { $0.id == outboundID }),
               let offer = storefront.bookingFlightOffer(for: choice, direction: .outbound) {
                selectedOutboundChoice = choice
                journey.selectedOutbound = offer
                journey.selectedPublishedOutboundID = choice.id
                let selectedOrigin = choice.leg.origin.uppercased()
                journey.trip.origin = selectedOrigin
                if journey.trip.originAirport?.iata.uppercased() != selectedOrigin {
                    journey.trip.originAirport = nil
                }
                if choice.leg.destination.uppercased() == "MED" {
                    journey.trip.arrivalAirport = .madinah
                } else if choice.leg.destination.uppercased() == "JED" {
                    journey.trip.arrivalAirport = .jeddah
                }
                if let departure = parseStorefrontISO(choice.leg.departureAt) {
                    journey.trip.departureDate = Calendar.current.startOfDay(for: departure)
                }
                if let arrival = parseStorefrontISO(choice.leg.arrivalAt) {
                    journey.trip.saudiArrivalDate = Calendar.current.startOfDay(for: arrival)
                }
            }
        }

        if let inboundID = configuration.inboundOptionID {
            let choices = storefront.configurableFlightChoices(direction: .inbound, trip: journey.trip)
            if let choice = (choices.primary + choices.other).first(where: { $0.id == inboundID }),
               let offer = storefront.bookingFlightOffer(for: choice, direction: .inbound) {
                selectedInboundChoice = choice
                journey.selectedInbound = offer
                journey.selectedPublishedReturnID = choice.id
                if let departure = parseStorefrontISO(choice.leg.departureAt) {
                    journey.trip.returnDate = Calendar.current.startOfDay(for: departure)
                }
            }
        }
    }

    @MainActor
    private func applyFlightChoice(
        _ choice: StorefrontConfiguratorFlightChoice,
        direction: FlightDirection,
        airport: Airport?,
        originCode: String
    ) {
        guard let offer = storefront.bookingFlightOffer(for: choice, direction: direction) else {
            bookingError = priceRefreshErrorText
            IumrahHaptics.error()
            return
        }

        suppressQuoteRefresh = true
        journey.selectedPublishedCompleteID = nil

        switch direction {
        case .outbound:
            let selectedOrigin = choice.leg.origin.uppercased()
            journey.trip.origin = selectedOrigin
            journey.trip.originAirport = airport?.iata.uppercased() == selectedOrigin ? airport : nil
            if choice.leg.destination.uppercased() == "MED" {
                journey.trip.arrivalAirport = .madinah
            } else if choice.leg.destination.uppercased() == "JED" {
                journey.trip.arrivalAirport = .jeddah
            }
            if let departure = parseStorefrontISO(choice.leg.departureAt) {
                journey.trip.departureDate = Calendar.current.startOfDay(for: departure)
            }
            if let arrival = parseStorefrontISO(choice.leg.arrivalAt) {
                journey.trip.saudiArrivalDate = Calendar.current.startOfDay(for: arrival)
            }
            journey.selectedOutbound = offer
            journey.selectedPublishedOutboundID = choice.id
            selectedOutboundChoice = choice

            // Keep the package valid after an outbound change. If the old return no
            // longer matches the selected route/window, choose the nearest published
            // compatible return automatically; the pilgrim can still change it next.
            if !currentReturnStillCompatible() {
                selectBestReturnForCurrentRoute()
            }

        case .inbound:
            if let departure = parseStorefrontISO(choice.leg.departureAt) {
                journey.trip.returnDate = Calendar.current.startOfDay(for: departure)
            }
            journey.selectedInbound = offer
            journey.selectedPublishedReturnID = choice.id
            selectedInboundChoice = choice
        }

        suppressQuoteRefresh = false
        refreshQuote()
        IumrahHaptics.selection()
    }

    private func currentReturnStillCompatible() -> Bool {
        let leg = currentInboundLeg
        let origin = journey.trip.originCode.uppercased()
        let expectedSaudi = journey.trip.returnOriginCode.uppercased()
        let destination = leg.destination.uppercased()
        let destinationMatches = destination == origin || (origin != "TAS" && destination == "TAS")
        guard leg.origin.uppercased() == expectedSaudi, destinationMatches else { return false }
        guard let arrival = journey.trip.saudiArrivalDate,
              let returnDate = parseStorefrontISO(leg.departureAt) else { return true }
        let gap = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: arrival),
            to: Calendar.current.startOfDay(for: returnDate)
        ).day ?? 0
        return (2...15).contains(gap)
    }

    @MainActor
    private func selectBestReturnForCurrentRoute() {
        let choices = storefront.configurableFlightChoices(direction: .inbound, trip: journey.trip)
        let candidates = (choices.primary + choices.other).filter(isCompatibleReturnChoice)
        guard let choice = candidates.first,
              let offer = storefront.bookingFlightOffer(for: choice, direction: .inbound) else { return }
        selectedInboundChoice = choice
        journey.selectedInbound = offer
        journey.selectedPublishedReturnID = choice.id
        if let departure = parseStorefrontISO(choice.leg.departureAt) {
            journey.trip.returnDate = Calendar.current.startOfDay(for: departure)
        }
    }

    private func isCompatibleReturnChoice(_ choice: StorefrontConfiguratorFlightChoice) -> Bool {
        guard let arrival = journey.trip.saudiArrivalDate,
              let departure = parseStorefrontISO(choice.leg.departureAt) else { return true }
        let gap = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: arrival),
            to: Calendar.current.startOfDay(for: departure)
        ).day ?? 0
        return (2...15).contains(gap)
    }

    @MainActor
    private func addMadinahToHotelPackage(firstCity: SaudiArrivalAirport) {
        guard let hotel = storefront.defaultMadinahHotel(for: journey.trip.packageTier) else {
            bookingError = madinahUnavailableText
            IumrahHaptics.error()
            return
        }
        suppressQuoteRefresh = true
        journey.trip.scope = .makkahAndMadinah
        journey.trip.arrivalAirport = firstCity
        journey.selectedMadinahHotel = hotel
        journey.selectedMadinahRoom = nil
        journey.selectedMadinahRoomCategory = nil
        selectBestFlightsForCurrentRouteOrder()
        suppressQuoteRefresh = false
        refreshQuote()
        IumrahHaptics.success()
    }

    @MainActor
    private func removeMadinahFromHotelPackage() {
        suppressQuoteRefresh = true
        journey.trip.scope = .makkahOnly
        journey.trip.arrivalAirport = .jeddah
        journey.selectedMadinahHotel = nil
        journey.selectedMadinahRoom = nil
        journey.selectedMadinahRoomCategory = nil
        selectBestFlightsForCurrentRouteOrder()
        suppressQuoteRefresh = false
        refreshQuote()
        IumrahHaptics.selection()
    }

    @MainActor
    private func setFirstSaudiCity(_ airport: SaudiArrivalAirport) {
        guard journey.trip.scope == .makkahAndMadinah else { return }
        suppressQuoteRefresh = true
        journey.trip.arrivalAirport = airport
        selectBestFlightsForCurrentRouteOrder()
        suppressQuoteRefresh = false
        refreshQuote()
        IumrahHaptics.selection()
    }

    @MainActor
    private func selectBestFlightsForCurrentRouteOrder() {
        let outboundChoices = storefront.configurableFlightChoices(direction: .outbound, trip: journey.trip)
        if let outbound = outboundChoices.primary.first,
           let offer = storefront.bookingFlightOffer(for: outbound, direction: .outbound) {
            selectedOutboundChoice = outbound
            journey.selectedOutbound = offer
            journey.selectedPublishedOutboundID = outbound.id
            journey.selectedPublishedCompleteID = nil
            if let departure = parseStorefrontISO(outbound.leg.departureAt) {
                journey.trip.departureDate = Calendar.current.startOfDay(for: departure)
            }
            if let arrival = parseStorefrontISO(outbound.leg.arrivalAt) {
                journey.trip.saudiArrivalDate = Calendar.current.startOfDay(for: arrival)
            }
        }
        selectBestReturnForCurrentRoute()
    }

    @MainActor
    private func createBooking() async {
        guard !isSubmitting,
              let hotel = journey.selectedHotel,
              let outbound = journey.selectedOutbound,
              let inbound = journey.selectedInbound,
              let quote = journey.quote else { return }

        if journey.trip.scope == .makkahAndMadinah, journey.selectedMadinahHotel == nil { return }

        isSubmitting = true
        bookingError = nil
        defer { isSubmitting = false }

        do {
            let profile = BookingPilgrimProfile(
                firstName: settings.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: settings.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                telegram: settings.telegram.trimmingCharacters(in: .whitespacesAndNewlines),
                whatsapp: settings.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            let session = try await bookings.create(
                trip: journey.trip,
                hotel: hotel,
                madinahHotel: journey.selectedMadinahHotel,
                room: journey.selectedRoom,
                roomCategory: journey.selectedRoomCategory,
                madinahRoom: journey.selectedMadinahRoom,
                madinahRoomCategory: journey.selectedMadinahRoomCategory,
                intercityTransport: journey.trip.scope == .makkahAndMadinah
                    ? (journey.haramainTrainSelected ? .haramainTrain : .road)
                    : nil,
                outbound: outbound,
                inbound: inbound,
                quote: quote,
                language: settings.language,
                pilgrimProfile: profile
            )

            if let deviceToken = push.deviceToken {
                await bookings.syncPushSubscriptions(deviceToken: deviceToken, locale: settings.language.rawValue)
            }
            IumrahHaptics.success()
            createdBookingID = session.id
        } catch {
            bookingError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    private func money(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var packageNavigationTitle: String { tr("Пакет Умры", "Umrah package", "Umra paketi", "Умра пакети") }
    private var flightsTitle: String { tr("Перелёты", "Flights", "Parvozlar", "Парвозлар") }
    private var hotelsTitle: String { tr("Отели", "Hotels", "Mehmonxonalar", "Меҳмонхоналар") }
    private var includedTitle: String { tr("Что включено", "What's included", "Nimalar kiradi", "Нималар киради") }
    private var outboundTitle: String { tr("Туда", "Outbound", "Borish", "Бориш") }
    private var returnTitle: String { tr("Обратно", "Return", "Qaytish", "Қайтиш") }
    private var scopeTitle: String {
        journey.trip.scope == .makkahOnly
            ? tr("Только Мекка", "Makkah only", "Faqat Makka", "Фақат Макка")
            : tr("Мекка + Медина", "Makkah + Madinah", "Makka + Madina", "Макка + Мадина")
    }
    private var daysWord: String { tr("дней", "days", "kun", "кун") }
    private var usesTashkentReturnFallback: Bool {
        currentOutboundLeg.origin.uppercased() != "TAS" && currentInboundLeg.destination.uppercased() == "TAS"
    }

    private var returnFallbackText: String {
        tr(
            "Для этого пакета обратный рейс приходит в Ташкент, потому что подходящего возврата в \(currentOutboundLeg.origin) в выбранном диапазоне нет.",
            "This package returns to Tashkent because no suitable flight back to \(currentOutboundLeg.origin) is available in the package window.",
            "Bu paket Toshkentga qaytadi, chunki paket oralig‘ida \(currentOutboundLeg.origin) ga mos qaytish reysi topilmadi.",
            "Бу пакет Тошкентга қайтади, чунки пакет оралиғида \(currentOutboundLeg.origin) га мос қайтиш рейси топилмади."
        )
    }
    private var visaTitle: String { tr("Туристическая виза", "Tourist visa", "Turistik viza", "Туристик виза") }
    private var visaSummary: String { tr("eVisa · 1 год · многократный въезд · до 90 дней", "eVisa · 1 year · multiple entry · up to 90 days", "eVisa · 1 yil · ko‘p martalik kirish · 90 kungacha", "eVisa · 1 йил · кўп марталик кириш · 90 кунгача") }
    private var transferTitle: String {
        journey.trip.scope == .makkahOnly
            ? tr("Аэропортовый трансфер", "Airport transfer", "Aeroport transferi", "Аэропорт трансфери")
            : tr("Трансферы и переезд между городами", "Transfers and intercity journey", "Transferlar va shaharlararo yo‘l", "Трансферлар ва шаҳарлараро йўл")
    }
    private var mealsTitle: String { tr("Питание", "Meals", "Ovqatlanish", "Овқатланиш") }
    private var mealsSummary: String {
        if supportsOptionalMeals {
            let unit = PackagePricingPresentation.optionalMealUnitPriceUsd(for: journey.trip.packageTier) ?? 0
            let amount = NSDecimalNumber(decimal: unit).intValue
            return tr(
                "Завтрак включён · обед и ужин по желанию · $\(amount) / человек / день",
                "Breakfast included · lunch and dinner optional · $\(amount) / person / day",
                "Nonushta kiritilgan · tushlik va kechki ovqat ixtiyoriy · $\(amount) / kishi / kun",
                "Нонушта киритилган · тушлик ва кечки овқат ихтиёрий · $\(amount) / киши / кун"
            )
        }
        return journey.trip.scope == .makkahOnly
            ? tr("Мекка · питание включено по категории пакета", "Makkah · meals included by package category", "Makka · ovqatlanish paket toifasiga kiritilgan", "Макка · овқатланиш пакет тоифасига киритилган")
            : tr("Мекка + Медина · питание включено по категории пакета", "Makkah + Madinah · meals included by package category", "Makka + Madina · ovqatlanish paket toifasiga kiritilgan", "Макка + Мадина · овқатланиш пакет тоифасига киритилган")
    }
    private var guideTitle: String { tr("iumrah Guide · сопровождение", "iumrah Guide · personal assistance", "iumrah Guide · shaxsiy hamrohlik", "iumrah Guide · шахсий ҳамроҳлик") }
    private var guideSummary: String { tr("Команда iumrah в Саудовской Аравии · от встречи до обратного вылета", "iumrah team in Saudi Arabia · from arrival to departure", "Saudiya Arabistonidagi iumrah jamoasi · kutib olishdan qaytishgacha", "Саудия Арабистонидаги iumrah жамоаси · кутиб олишдан қайтишгача") }
    private var careSummary: String { tr("Абдулазиз · прямой контакт с основателем iumrah", "Abdulaziz · direct contact with the iumrah founder", "Abdulaziz · iumrah asoschisi bilan to‘g‘ridan-to‘g‘ri aloqa", "Абдулазиз · iumrah асосчиси билан тўғридан-тўғри алоқа") }
    private var makkahZiyaratTitle: String { tr("Зияраты в Мекке", "Makkah ziyarat", "Makka ziyoratlari", "Макка зиёратлари") }
    private var madinahZiyaratTitle: String { tr("Зияраты в Медине", "Madinah ziyarat", "Madina ziyoratlari", "Мадина зиёратлари") }
    private var finalPriceTitle: String { tr("Итоговая цена поездки", "Final trip price", "Safarning yakuniy narxi", "Сафарнинг якуний нархи") }
    private var perPersonShort: String { tr("за 1 человека", "for 1 person", "1 kishi uchun", "1 киши учун") }
    private var perPersonLong: String { tr("на 1 человека", "per person", "1 kishi uchun", "1 киши учун") }
    private var totalForTravelersText: String {
        let count = max(1, journey.trip.travelerCount)
        return tr("за \(count) чел.", "for \(count) travelers", "\(count) kishi uchun", "\(count) киши учун")
    }
    private var travelersBody: String { tr("Добавьте тех, кто едет с вами. Итоговая цена пакета пересчитается автоматически.", "Add the people traveling with you. The package total recalculates automatically.", "Siz bilan safar qiladiganlarni qo‘shing. Paketning umumiy narxi avtomatik qayta hisoblanadi.", "Сиз билан сафар қиладиганларни қўшинг. Пакетнинг умумий нархи автоматик қайта ҳисобланади.") }
    private var changeTitle: String { tr("Изменить", "Change", "O‘zgartirish", "Ўзгартириш") }
    private var routeConfiguratorTitle: String { tr("Маршрут поездки", "Trip route", "Safar yo‘nalishi", "Сафар йўналиши") }
    private var makkahOnlyRouteSubtitle: String { tr("Сейчас пакет собран только для Мекки", "The package currently covers Makkah only", "Hozir paket faqat Makka uchun", "Ҳозир пакет фақат Макка учун") }
    private var makkahMadinahRouteSubtitle: String { tr("Мекка и Медина включены в один маршрут", "Makkah and Madinah are included in one route", "Makka va Madina bitta yo‘nalishga qo‘shilgan", "Макка ва Мадина битта йўналишга қўшилган") }
    private var firstCityTitle: String { tr("Первый город", "First city", "Birinchi shahar", "Биринчи шаҳар") }
    private var firstCityQuestionTitle: String { tr("С какого города начать?", "Which city first?", "Qaysi shahardan boshlaysiz?", "Қайси шаҳардан бошлайсиз?") }
    private var firstCityQuestionBody: String { tr("iumrah Configurator перестроит перелёты, ночи и маршрут пакета под выбранный порядок.", "iumrah Configurator will rebuild the flights, nights and package route for the selected order.", "iumrah Configurator tanlangan tartib bo‘yicha reyslar, tunlar va paket yo‘nalishini qayta hisoblaydi.", "iumrah Configurator танланган тартиб бўйича рейслар, тунлар ва пакет йўналишини қайта ҳисоблайди.") }
    private var firstJeddahTitle: String { tr("Джидда · JED", "Jeddah · JED", "Jidda · JED", "Жидда · JED") }
    private var firstMadinahTitle: String { tr("Медина · MED", "Madinah · MED", "Madina · MED", "Мадина · MED") }
    private var addMadinahTitle: String { tr("Добавить Медину", "Add Madinah", "Madinani qo‘shish", "Мадинани қўшиш") }
    private var removeMadinahTitle: String { tr("Убрать Медину из пакета", "Remove Madinah from package", "Madinani paketdan olib tashlash", "Мадинани пакетдан олиб ташлаш") }
    private var cancelTitle: String { tr("Отмена", "Cancel", "Bekor qilish", "Бекор қилиш") }
    private var madinahUnavailableText: String { tr("Сейчас нет подходящего опубликованного отеля в Медине для этой категории.", "No suitable published Madinah hotel is available for this category right now.", "Hozir bu toifa uchun Madinada mos e’lon qilingan mehmonxona yo‘q.", "Ҳозир бу тоифа учун Мадинада мос эълон қилинган меҳмонхона йўқ.") }
    private var chooseRoomTitle: String { tr("Выбрать комнату", "Choose a room", "Xona tanlash", "Хона танлаш") }
    private var bookTripTitle: String { tr("Забронировать поездку", "Book this trip", "Safarni bron qilish", "Сафарни брон қилиш") }
    private var bookingInProgressTitle: String { tr("Создаём бронирование…", "Creating booking…", "Bron yaratilmoqda…", "Брон яратилмоқда…") }
    private var generatedStamp: String { tr("Сгенерировано iumrah Configurator", "Generated by iumrah Configurator", "iumrah Configurator yaratdi", "iumrah Configurator яратди") }
    private var packagePreparationErrorText: String { tr("Не удалось подготовить этот пакет к бронированию. Обновите каталог и попробуйте снова.", "This package could not be prepared for booking. Refresh the catalog and try again.", "Bu paketni bron qilishga tayyorlab bo‘lmadi. Katalogni yangilang va qayta urinib ko‘ring.", "Бу пакетни брон қилишга тайёрлаб бўлмади. Каталогни янгиланг ва қайта уриниб кўринг.") }
    private var priceRefreshErrorText: String { tr("Не удалось пересчитать пакет после изменения выбора.", "The package could not be recalculated after your change.", "Tanlovdan keyin paket narxini qayta hisoblab bo‘lmadi.", "Танловдан кейин пакет нархини қайта ҳисоблаб бўлмади.") }
    private var hotelUnavailableText: String { tr("Карточка этого отеля временно недоступна.", "This hotel page is temporarily unavailable.", "Bu mehmonxona sahifasi vaqtincha mavjud emas.", "Бу меҳмонхона саҳифаси вақтинча мавжуд эмас.") }
}

private struct PackageFlightPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var storefront: HotelStorefrontStore
    @EnvironmentObject private var journey: JourneyStore

    let direction: FlightDirection
    let referenceFare: Decimal
    let selectedOptionID: String
    let onSelect: (StorefrontConfiguratorFlightChoice, Airport?, String) -> Void

    @State private var draftAirport: Airport?
    @State private var draftOriginCode: String

    init(
        direction: FlightDirection,
        currentAirport: Airport?,
        currentOriginCode: String,
        referenceFare: Decimal,
        selectedOptionID: String,
        onSelect: @escaping (StorefrontConfiguratorFlightChoice, Airport?, String) -> Void
    ) {
        self.direction = direction
        self.referenceFare = referenceFare
        self.selectedOptionID = selectedOptionID
        self.onSelect = onSelect
        _draftAirport = State(initialValue: currentAirport)
        _draftOriginCode = State(initialValue: currentOriginCode.uppercased())
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(airportSectionTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        AirportSelectorButton(
                            airport: $draftAirport,
                            fallbackCode: $draftOriginCode
                        )

                        Text(airportHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 6)

                    if !primaryChoices.isEmpty {
                        sectionTitle(primarySectionTitle)
                        ForEach(primaryChoices) { choice in
                            choiceCard(choice)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(noExactFlightsTitle, systemImage: "airplane.circle")
                                .font(.headline)
                            Text(noExactFlightsBody)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .iumrahCard()
                    }

                    if !otherChoices.isEmpty {
                        sectionTitle(otherFlightsTitle)
                            .padding(.top, 6)
                        ForEach(otherChoices) { choice in
                            choiceCard(choice)
                        }
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(doneTitle) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .padding(.top, 2)
    }

    private func choiceCard(_ choice: StorefrontConfiguratorFlightChoice) -> some View {
        PackageFlightChoiceCard(
            choice: choice,
            deltaText: deltaText(for: choice),
            isSelected: choice.id == selectedOptionID,
            language: settings.language
        ) {
            let code = resolvedOriginCode
            onSelect(choice, draftAirport, code)
            dismiss()
        }
    }

    private var configuredTrip: TripDraft {
        var trip = journey.trip
        let code = resolvedOriginCode
        trip.origin = code
        trip.originAirport = draftAirport?.iata.uppercased() == code ? draftAirport : nil
        return trip
    }

    private var availableChoices: (primary: [StorefrontConfiguratorFlightChoice], other: [StorefrontConfiguratorFlightChoice]) {
        let result = storefront.configurableFlightChoices(direction: direction, trip: configuredTrip)
        return (
            result.primary.filter(isDateCompatible),
            result.other.filter(isDateCompatible)
        )
    }

    private var primaryChoices: [StorefrontConfiguratorFlightChoice] { availableChoices.primary }
    private var otherChoices: [StorefrontConfiguratorFlightChoice] { availableChoices.other }

    private var resolvedOriginCode: String {
        let code = (draftAirport?.iata ?? draftOriginCode)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return code.count == 3 ? code : journey.trip.originCode.uppercased()
    }

    private func isDateCompatible(_ choice: StorefrontConfiguratorFlightChoice) -> Bool {
        guard let departure = parseStorefrontISO(choice.leg.departureAt) else { return true }
        let calendar = Calendar.current

        switch direction {
        case .outbound:
            // Published rows can contain multiple future departures. Keep the complete
            // airport-specific list, but never offer a leg that has already departed.
            return departure >= calendar.startOfDay(for: Date())

        case .inbound:
            guard let arrival = journey.trip.saudiArrivalDate else { return true }
            let gap = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: arrival),
                to: calendar.startOfDay(for: departure)
            ).day ?? 0
            return (2...15).contains(gap)
        }
    }

    private func deltaText(for choice: StorefrontConfiguratorFlightChoice) -> String {
        if choice.id == selectedOptionID { return selectedTitle }
        let delta = NSDecimalNumber(decimal: choice.farePerTravelerUSD - referenceFare).doubleValue
        if abs(delta) < 0.5 { return noChangeTitle }
        let amount = Int(abs(delta).rounded())
        return delta > 0 ? "+$\(amount)" : "−$\(amount)"
    }

    private var navigationTitle: String {
        direction == .outbound
            ? tr("Изменить перелёт туда", "Change outbound flight", "Borish reysini o‘zgartirish", "Бориш рейсини ўзгартириш")
            : tr("Изменить обратный рейс", "Change return flight", "Qaytish reysini o‘zgartirish", "Қайтиш рейсини ўзгартириш")
    }

    private var airportSectionTitle: String { tr("Аэропорт вылета", "Departure airport", "Jo‘nash aeroporti", "Жўнаш аэропорти") }
    private var airportHint: String { tr(
        "Сначала показаны опубликованные рейсы для выбранного аэропорта. Цена билета скрыта — iumrah Configurator показывает только изменение итоговой стоимости.",
        "Published flights for the selected airport are shown first. The ticket fare stays hidden — iumrah Configurator shows only the change to the package price.",
        "Avval tanlangan aeroport uchun e’lon qilingan reyslar ko‘rsatiladi. Chipta narxi yashirin — iumrah Configurator faqat paket narxidagi farqni ko‘rsatadi.",
        "Аввал танланган аэропорт учун эълон қилинган рейслар кўрсатилади. Чипта нархи яширин — iumrah Configurator фақат пакет нархидаги фарқни кўрсатади."
    ) }
    private var primarySectionTitle: String { tr("Подходящие рейсы", "Matching flights", "Mos reyslar", "Мос рейслар") }
    private var otherFlightsTitle: String { tr("Другие актуальные билеты", "Other current flights", "Boshqa dolzarb chiptalar", "Бошқа долзарб чипталар") }
    private var noExactFlightsTitle: String { tr("Подходящих рейсов пока нет", "No matching flights yet", "Mos reyslar hozircha yo‘q", "Мос рейслар ҳозирча йўқ") }
    private var noExactFlightsBody: String { tr(
        "Ниже показаны другие актуальные варианты для этого аэропорта, если они доступны.",
        "Other current options for this airport are shown below when available.",
        "Quyida ushbu aeroport uchun boshqa dolzarb variantlar mavjud bo‘lsa ko‘rsatiladi.",
        "Қуйида ушбу аэропорт учун бошқа долзарб вариантлар мавжуд бўлса кўрсатилади."
    ) }
    private var selectedTitle: String { tr("Выбран", "Selected", "Tanlangan", "Танланган") }
    private var noChangeTitle: String { tr("Без доплаты", "No extra cost", "Qo‘shimcha to‘lovsiz", "Қўшимча тўловсиз") }
    private var doneTitle: String { tr("Готово", "Done", "Tayyor", "Тайёр") }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private struct PackageFlightChoiceCard: View {
    let choice: StorefrontConfiguratorFlightChoice
    let deltaText: String
    let isSelected: Bool
    let language: AppSettingsStore.Language
    let onSelect: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onSelect()
        } label: {
            HStack(spacing: 14) {
                AirlineLogoView(airlineCode: choice.leg.airlineCode, size: 54)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("\(choice.leg.origin) → \(choice.leg.destination)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if choice.leg.stops == 0 {
                            Text(directTitle)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.iumrahRaisedBackground, in: Capsule())
                        }
                    }

                    Text("\(choice.leg.airline) · \(choice.leg.flightNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("\(localizedDay(choice.leg.departureAt)) · \(clock(choice.leg.departureAt))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 7) {
                    Text(deltaText)
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(Color.iumrahRaisedBackground, in: Capsule())

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? IumrahIconRole.success.color : Color.primary.opacity(0.30))
                }
            }
            .padding(16)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isSelected ? 0.13 : 0.055), lineWidth: isSelected ? 1.1 : 0.7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func localizedDay(_ value: String) -> String {
        guard let date = parseStorefrontISO(value) else { return String(value.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    private var directTitle: String {
        switch language {
        case .russian: return "прямой"
        case .english: return "direct"
        case .uzbek: return "to‘g‘ri"
        case .uzbekCyrillic: return "тўғри"
        }
    }
}

private struct PackageFlightLegDetailCard: View {
    let leg: StorefrontFlightLeg
    let direction: String
    let language: AppSettingsStore.Language
    let actionTitle: String?
    let onChange: (() -> Void)?
    @State private var expanded = false

    init(
        leg: StorefrontFlightLeg,
        direction: String,
        language: AppSettingsStore.Language,
        actionTitle: String? = nil,
        onChange: (() -> Void)? = nil
    ) {
        self.leg = leg
        self.direction = direction
        self.language = language
        self.actionTitle = actionTitle
        self.onChange = onChange
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                        expanded.toggle()
                    }
                    IumrahHaptics.selection()
                } label: {
                    HStack(spacing: 14) {
                        AirlineLogoView(airlineCode: leg.airlineCode, size: 50)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(direction.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text("\(leg.origin) → \(leg.destination)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(leg.airline) \(leg.flightNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text("\(day(leg.departureAt)) · \(clock(leg.departureAt))")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 6) {
                            Image(systemName: "airplane")
                                .font(.headline)
                                .foregroundStyle(IumrahIconRole.travel.color)
                            Text(directText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(expanded ? 180 : 0))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let actionTitle, let onChange {
                    Button {
                        IumrahHaptics.selection()
                        onChange()
                    } label: {
                        Text(actionTitle)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(Color.iumrahRaisedBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if expanded {
                Divider().padding(.vertical, 14)
                VStack(spacing: 11) {
                    flightFact(title: departureAirportTitle, value: airportText(leg.origin))
                    flightFact(title: arrivalAirportTitle, value: airportText(leg.destination))
                    flightFact(title: departureTimeTitle, value: fullDateTime(leg.departureAt))
                    flightFact(title: arrivalTimeTitle, value: fullDateTime(leg.arrivalAt))
                    flightFact(title: durationTitle, value: durationText(leg.durationMinutes))
                    flightFact(title: cabinTitle, value: leg.cabinClass.isEmpty ? "—" : leg.cabinClass.capitalized)
                    flightFact(title: flightNumberTitle, value: leg.flightNumber)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .iumrahCard()
    }

    private func flightFact(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

    private func airportText(_ code: String) -> String {
        if let airport = FlightReferenceCatalog.airport(code) {
            return "\(airport.city) · \(airport.name) · \(code.uppercased())"
        }
        return code.uppercased()
    }

    private func fullDateTime(_ value: String) -> String {
        guard let date = parseStorefrontISO(value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy HH:mm")
        return formatter.string(from: date)
    }

    private func durationText(_ minutes: Int) -> String {
        let h = max(0, minutes) / 60
        let m = max(0, minutes) % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var directText: String {
        switch language {
        case .russian: return leg.stops == 0 ? "прямой" : "\(leg.stops) пересад."
        case .english: return leg.stops == 0 ? "direct" : "\(leg.stops) stops"
        case .uzbek: return leg.stops == 0 ? "to‘g‘ridan-to‘g‘ri" : "\(leg.stops) ulanish"
        case .uzbekCyrillic: return leg.stops == 0 ? "тўғридан-тўғри" : "\(leg.stops) уланиш"
        }
    }

    private var departureAirportTitle: String { tr("Аэропорт вылета", "Departure airport", "Jo‘nash aeroporti", "Жўнаш аэропорти") }
    private var arrivalAirportTitle: String { tr("Аэропорт прилёта", "Arrival airport", "Yetib borish aeroporti", "Етиб бориш аэропорти") }
    private var departureTimeTitle: String { tr("Вылет", "Departure", "Jo‘nash", "Жўнаш") }
    private var arrivalTimeTitle: String { tr("Прилёт", "Arrival", "Yetib kelish", "Етиб келиш") }
    private var durationTitle: String { tr("В пути", "Duration", "Yo‘lda", "Йўлда") }
    private var cabinTitle: String { tr("Класс", "Cabin", "Klass", "Класс") }
    private var flightNumberTitle: String { tr("Рейс", "Flight", "Reys", "Рейс") }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private struct PackageHotelDetailCard: View {
    let hotel: StorefrontPackageHotel
    let selectedRoomName: String?
    let chooseRoomText: String
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onOpen()
        } label: {
            GeometryReader { proxy in
                let mediaWidth = min(max(proxy.size.width * 0.31, 108), 124)
                HStack(spacing: 0) {
                    ZStack {
                        if let imageURL = hotel.coverImageURL, !imageURL.isEmpty {
                            HotelCachedImage(rawURL: imageURL)
                                .frame(width: mediaWidth, height: 150)
                        } else {
                            Color.iumrahRaisedBackground
                                .overlay {
                                    Image(systemName: "building.2.fill")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: mediaWidth, height: 150)
                    .clipped()

                    VStack(alignment: .leading, spacing: 7) {
                        Text(hotel.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            if let stars = hotel.stars {
                                Text(String(repeating: "★", count: max(1, min(5, stars))))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(IumrahIconRole.rating.color)
                            }
                            Text(cityTitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        Label(nightsText, systemImage: "moon.stars.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        HStack(spacing: 6) {
                            Image(systemName: "bed.double.fill")
                                .font(.caption)
                            Text(selectedRoomName ?? chooseRoomText)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(selectedRoomName == nil ? .secondary : .primary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(width: proxy.size.width, height: 150)
            }
            .frame(height: 150)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
    }

    private var cityTitle: String { L10n.city(hotel.city, language) }
    private var nightsText: String {
        switch language {
        case .russian: return "\(hotel.nights) ноч."
        case .english: return "\(hotel.nights) nights"
        case .uzbek: return "\(hotel.nights) tun"
        case .uzbekCyrillic: return "\(hotel.nights) тун"
        }
    }
}

private struct PackagePurchaseTrustCard: View {
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onOpen()
        } label: {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "checkmark.shield.fill", role: .security, size: 42, symbolSize: 17, cornerRadius: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(14)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
        }
    }

    private var title: String {
        switch language {
        case .russian: return "Доверие и подтверждение бронирования"
        case .english: return "Booking trust and confirmation"
        case .uzbek: return "Bron ishonchi va tasdig‘i"
        case .uzbekCyrillic: return "Брон ишончи ва тасдиғи"
        }
    }

    private var subtitle: String {
        switch language {
        case .russian: return "Прямой контакт с основателем · инвойс и чек · ответственность iumrah за отель и iumrah Services"
        case .english: return "Direct founder contact · invoice and receipt · iumrah responsibility for the hotel and iumrah Services"
        case .uzbek: return "Asoschi bilan bevosita aloqa · invoice va chek · mehmonxona hamda iumrah Services uchun iumrah javobgarligi"
        case .uzbekCyrillic: return "Асосчи билан бевосита алоқа · invoice ва чек · меҳмонхона ҳамда iumrah Services учун iumrah жавобгарлиги"
        }
    }
}

private struct StorefrontPackageInformationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let kind: StorefrontPackageInfoSheet
    let language: AppSettingsStore.Language
    let preview: StorefrontFlightPackagePreview

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    switch kind {
                    case .visa:
                        visaContent
                    case .guide:
                        guideContent
                    case .care:
                        careContent
                    case .trust:
                        trustContent
                    }
                }
                .padding(IumrahDesign.pagePadding)
                .padding(.bottom, 28)
            }
            .background(Color.iumrahPageBackground)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneTitle) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var header: some View {
        if kind == .visa {
            visaHero
        } else {
            VStack(alignment: .leading, spacing: 8) {
                IumrahIconBadge(systemName: headerIcon, role: headerRole, size: 50, symbolSize: 20, cornerRadius: 16)
                Text(sheetTitle)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                Text(sheetSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var visaHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                Image("SaudiVisaRiyadhHero")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(sheetTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(-0.6)
                    Text(sheetSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            HStack(spacing: 12) {
                Image("SaudiEVisaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 68)
                    .padding(.horizontal, 8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.7)
                    }

                Text(tr("Официальная туристическая eVisa Саудовской Аравии", "Official Saudi tourist eVisa", "Saudiya rasmiy turistik eVisa", "Саудия расмий туристик eVisa"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var visaContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    visaChip("1 \(tr("год", "year", "yil", "йил"))")
                    visaChip(tr("Многократная", "Multiple entry", "Ko‘p kirish", "Кўп кириш"))
                    visaChip(tr("До 90 дней", "Up to 90 days", "90 kungacha", "90 кунгача"))
                }
                VStack(alignment: .leading, spacing: 8) {
                    visaChip("1 \(tr("год", "year", "yil", "йил"))")
                    visaChip(tr("Многократный въезд · до 90 дней", "Multiple entry · up to 90 days", "Ko‘p kirish · 90 kungacha", "Кўп кириш · 90 кунгача"))
                }
            }

            infoCard {
                infoPoint(
                    icon: "building.columns.fill",
                    title: tr("Для Умры", "For Umrah", "Umra uchun", "Умра учун"),
                    body: tr("Туристическая eVisa подходит для Умры. Для Хаджа она не используется.", "The tourist eVisa can be used for Umrah. It is not a Hajj visa.", "Turistik eVisa Umra uchun ishlatiladi. Haj vizasi emas.", "Туристик eVisa Умра учун ишлатилади. Ҳаж визаси эмас.")
                )
                Divider()
                infoPoint(
                    icon: "person.text.rectangle",
                    title: tr("Паспорт", "Passport", "Pasport", "Паспорт"),
                    body: tr("Для официальной eVisa паспорт должен соответствовать требованиям Saudi Visa и иметь не менее 6 месяцев действия на дату въезда.", "For the official eVisa, the passport must meet Saudi Visa requirements and have at least 6 months validity on the date of entry.", "Rasmiy eVisa uchun pasport Saudi Visa talablariga mos bo‘lishi va kirish sanasida kamida 6 oy amal qilishi kerak.", "Расмий eVisa учун паспорт Saudi Visa талабларига мос бўлиши ва кириш санасида камида 6 ой амал қилиши керак.")
                )
                Divider()
                infoPoint(
                    icon: "checkmark.seal.fill",
                    title: tr("Решение по визе", "Visa decision", "Viza qarori", "Виза қарори"),
                    body: tr("Окончательное решение о выдаче визы и въезде принимает компетентный орган Саудовской Аравии.", "The competent Saudi authority makes the final visa and admission decision.", "Viza va kirish bo‘yicha yakuniy qarorni Saudiya vakolatli organi qabul qiladi.", "Виза ва кириш бўйича якуний қарорни Саудия ваколатли органи қабул қилади.")
                )
            }

            Link(destination: URL(string: "https://visa.visitsaudi.com/")!) {
                HStack {
                    Label(officialVisaSourceTitle, systemImage: "safari.fill")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
    }

    private func visaChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private var guideContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label(tr("Команда iumrah в Саудовской Аравии", "iumrah team in Saudi Arabia", "Saudiya Arabistonidagi iumrah jamoasi", "Саудия Арабистонидаги iumrah жамоаси"), systemImage: "person.2.fill")
                    .font(.headline)
                Text(tr(
                    "К вашей семье или группе привязывается персональное сопровождение на месте. Это операционная команда поездки, а не общий чат поддержки.",
                    "Your family or group gets personal on-the-ground assistance. This is the trip operations team, not a general support chat.",
                    "Oilangiz yoki guruhingizga joydagi shaxsiy hamrohlik biriktiriladi. Bu umumiy chat emas, safar operatsion jamoasi.",
                    "Оилангиз ёки гуруҳингизга жойдаги шахсий ҳамроҳлик бириктирилади. Бу умумий чат эмас, сафар операцион жамоаси."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .iumrahCard()

            infoCard {
                guidePoint("airplane.arrival", tr("Встреча после прилёта", "Arrival welcome", "Kelganda kutib olish", "Келганда кутиб олиш"), tr("Встречают в аэропорту и помогают пройти первые организационные шаги поездки.", "They meet you at the airport and help with the first operational steps of the trip.", "Aeroportda kutib oladi va safarning dastlabki tashkiliy ishlarida yordam beradi.", "Аэропортда кутиб олади ва сафарнинг дастлабки ташкилий ишларида ёрдам беради."))
                Divider()
                guidePoint("building.2.fill", tr("Заселение и язык", "Check-in and language", "Joylashish va til", "Жойлашиш ва тил"), tr("Помогают с заселением, общением на арабском и вопросами к отелю.", "They assist with hotel check-in, Arabic communication and hotel questions.", "Mehmonxonaga joylashish, arab tilida muloqot va hotel savollarida yordam beradi.", "Меҳмонхонага жойлашиш, араб тилида мулоқот ва меҳмонхона саволларида ёрдам беради."))
                Divider()
                guidePoint("car.fill", tr("Трансферы и маршрут", "Transfers and route", "Transfer va yo‘nalish", "Трансфер ва йўналиш"), tr("Контролируют ключевые переезды, встречи транспорта и переход между городами, если Медина включена.", "They coordinate key transfers, vehicle meetings and the intercity leg when Madinah is included.", "Asosiy transferlar, transport bilan uchrashuv va Madina bo‘lsa shaharlararo yo‘lni nazorat qiladi.", "Асосий трансферлар, транспорт билан учрашув ва Мадина бўлса шаҳарлараро йўлни назорат қилади."))
                Divider()
                guidePoint("mappin.and.ellipse", tr("Умра и зияраты", "Umrah and ziyarat", "Umra va ziyoratlar", "Умра ва зиёратлар"), tr("Сопровождают включённую программу и помогают по организационным вопросам в течение поездки.", "They accompany the included program and help with operational questions throughout the trip.", "Kiritilgan dasturda hamroh bo‘ladi va safar davomida tashkiliy savollarda yordam beradi.", "Киритилган дастурда ҳамроҳ бўлади ва сафар давомида ташкилий саволларда ёрдам беради."))
                Divider()
                guidePoint("airplane.departure", tr("До обратного вылета", "Through return departure", "Qaytishgacha", "Қайтишгача"), tr("В конце поездки сопровождают организацию выезда и трансфер в аэропорт на обратный рейс.", "At the end of the trip they coordinate departure and the airport transfer for your return flight.", "Safar oxirida jo‘nash va qaytish reysi uchun aeroport transferini muvofiqlashtiradi.", "Сафар охирида жўнаш ва қайтиш рейси учун аэропорт трансферини мувофиқлаштиради."))
            }
        }
    }

    private var careContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image("CareChatAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Абдулазиз")
                        .font(.headline)
                    Text(tr("Основатель iumrah · iumrah Care", "Founder of iumrah · iumrah Care", "iumrah asoschisi · iumrah Care", "iumrah асосчиси · iumrah Care"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .iumrahCard()

            Text(tr(
                "До бронирования и во время поездки вы можете напрямую обсудить со мной пакет, отель, сезон, оплату, изменения или любой вопрос по вашей Умре. Я контролирую поддержку поездки и остаюсь доверенным контактом со стороны iumrah.",
                "Before booking and during the trip, you can contact me directly about the package, hotel, season, payment, changes or any question about your Umrah. I oversee trip support and remain your trusted iumrah contact.",
                "Bron qilishdan oldin va safar davomida paket, mehmonxona, mavsum, to‘lov, o‘zgarishlar yoki Umrangiz bo‘yicha istalgan savolni men bilan bevosita muhokama qilishingiz mumkin. Men safar yordamini nazorat qilaman va iumrah tomonidan ishonchli aloqangiz bo‘lib qolaman.",
                "Брон қилишдан олдин ва сафар давомида пакет, меҳмонхона, мавсум, тўлов, ўзгаришлар ёки Умрангиз бўйича исталган саволни мен билан бевосита муҳокама қилишингиз мумкин. Мен сафар ёрдамини назорат қиламан ва iumrah томонидан ишончли алоқангиз бўлиб қоламан."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Link(destination: URL(string: "https://t.me/saudiclub966")!) {
                HStack {
                    Label(tr("Написать Абдулазизу", "Message Abdulaziz", "Abdulazizga yozish", "Абдулазизга ёзиш"), systemImage: "paperplane.fill")
                    Spacer()
                    Text("Telegram")
                        .font(.caption.weight(.semibold))
                        .opacity(0.74)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())

            Link(destination: URL(string: "tel:+998508898845")!) {
                HStack {
                    Label(callTitle, systemImage: "phone.fill")
                    Spacer()
                    Text("+998 50 889 88 45")
                        .font(.caption.weight(.semibold))
                        .opacity(0.74)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
    }

    private var trustContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoCard {
                infoPoint(
                    icon: "person.crop.circle.fill",
                    title: tr("Живой контакт до оплаты", "A real contact before payment", "To‘lovdan oldin jonli aloqa", "Тўловдан олдин жонли алоқа"),
                    body: tr("Перед бронированием можно напрямую обсудить пакет и оплату с основателем iumrah — Абдулазизом.", "Before booking, you can discuss the package and payment directly with iumrah founder Abdulaziz.", "Bron qilishdan oldin paket va to‘lovni iumrah asoschisi Abdulaziz bilan bevosita muhokama qilishingiz mumkin.", "Брон қилишдан олдин пакет ва тўловни iumrah асосчиси Абдулазиз билан бевосита муҳокама қилишингиз мумкин.")
                )
                Divider()
                infoPoint(
                    icon: "doc.text.fill",
                    title: tr("Инвойс и чек", "Invoice and receipt", "Invoice va chek", "Invoice ва чек"),
                    body: tr("Сумма и состав заказа фиксируются в инвойсе; после подтверждения оплаты вы получаете подтверждение и чек оплаты.", "The order amount and contents are recorded in the invoice; after payment confirmation you receive payment confirmation and a receipt.", "Buyurtma summasi va tarkibi invoice’da qayd etiladi; to‘lov tasdiqlangach tasdiq va chek olasiz.", "Буюртма суммаси ва таркиби invoice’да қайд этилади; тўлов тасдиқлангач тасдиқ ва чек оласиз.")
                )
                Divider()
                infoPoint(
                    icon: "checkmark.shield.fill",
                    title: tr("Ответственность iumrah", "iumrah responsibility", "iumrah javobgarligi", "iumrah жавобгарлиги"),
                    body: tr("iumrah контролирует подтверждение отеля и выполнение iumrah Services: трансферы, сопровождение, зияраты и поддержку по поездке.", "iumrah controls hotel confirmation and delivery of iumrah Services: transfers, assistance, ziyarat and trip support.", "iumrah mehmonxona tasdig‘i va iumrah Services bajarilishini nazorat qiladi: transfer, hamrohlik, ziyoratlar va safar yordami.", "iumrah меҳмонхона тасдиғи ва iumrah Services бажарилишини назорат қилади: трансфер, ҳамроҳлик, зиёратлар ва сафар ёрдами.")
                )
                Divider()
                infoPoint(
                    icon: "airplane",
                    title: tr("Ответственность авиакомпании", "Airline responsibility", "Aviakompaniya javobgarligi", "Авиакомпания жавобгарлиги"),
                    body: tr("Выполнение рейса, задержка или отмена находятся в зоне ответственности авиакомпании. Изменение или возврат билета определяется правилами выбранного тарифа и авиакомпании.", "Flight operation, delay or cancellation are the airline’s responsibility. Ticket changes and refunds follow the selected fare and airline rules.", "Reysni bajarish, kechikish yoki bekor qilish aviakompaniya javobgarligida. Chipta o‘zgarishi va qaytarilishi tanlangan tarif va aviakompaniya qoidalariga bog‘liq.", "Рейсни бажариш, кечикиш ёки бекор қилиш авиакомпания жавобгарлигида. Чипта ўзгариши ва қайтарилиши танланган тариф ва авиакомпания қоидаларига боғлиқ.")
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Возврат — отдельная политика", "Refunds are a separate policy", "Qaytarish — alohida siyosat", "Қайтариш — алоҳида сиёсат"))
                    .font(.headline)
                Text(tr("Правила возврата показываются отдельно по авиабилету, отелю, трансферу и сервисам iumrah — без смешивания с блоком доверия.", "Refund rules are shown separately for flights, hotels, transfers and iumrah services rather than being mixed into the trust section.", "Qaytarish qoidalari aviachipta, mehmonxona, transfer va iumrah xizmatlari bo‘yicha alohida ko‘rsatiladi.", "Қайтариш қоидалари авиачипта, меҳмонхона, трансфер ва iumrah хизматлари бўйича алоҳида кўрсатилади."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    IumrahPolicyDetailView(kind: .refund)
                } label: {
                    HStack {
                        Label(tr("Открыть политику возврата", "Open refund policy", "Qaytarish siyosatini ochish", "Қайтариш сиёсатини очиш"), systemImage: "arrow.uturn.backward.circle.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
            .iumrahCard()
        }
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .iumrahCard()
    }

    private func infoPoint(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, role: .security, size: 38, symbolSize: 14, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func guidePoint(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, role: .care, size: 38, symbolSize: 14, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerIcon: String {
        switch kind {
        case .visa: return "doc.text.fill"
        case .guide: return "person.crop.circle.badge.checkmark"
        case .care: return "heart.fill"
        case .trust: return "checkmark.shield.fill"
        }
    }

    private var headerRole: IumrahIconRole {
        switch kind {
        case .visa: return .document
        case .guide, .care: return .care
        case .trust: return .security
        }
    }

    private var sheetTitle: String {
        switch kind {
        case .visa: return tr("Saudi eVisa для Умры", "Saudi eVisa for Umrah", "Umra uchun Saudi eVisa", "Умра учун Saudi eVisa")
        case .guide: return "iumrah Guide"
        case .care: return "iumrah Care"
        case .trust: return tr("Доверие перед бронированием", "Confidence before booking", "Bron oldidan ishonch", "Брон олдидан ишонч")
        }
    }

    private var sheetSubtitle: String {
        switch kind {
        case .visa:
            return tr("Коротко о визе, которая используется для этой поездки.", "A concise view of the visa used for this trip.", "Ushbu safarda ishlatiladigan viza haqida qisqacha.", "Ушбу сафарда ишлатиладиган виза ҳақида қисқача.")
        case .guide:
            return tr("Персональная команда сопровождения на месте в Саудовской Аравии — от прилёта до обратного вылета.", "Personal on-the-ground assistance in Saudi Arabia from arrival through return departure.", "Saudiya Arabistonida kelishdan qaytishgacha shaxsiy hamrohlik jamoasi.", "Саудия Арабистонида келишдан қайтишгача шахсий ҳамроҳлик жамоаси.")
        case .care:
            return tr("Прямой контакт с основателем iumrah по пакету, бронированию и вашей поездке.", "Direct contact with the iumrah founder about your package, booking and trip.", "Paket, bron va safaringiz bo‘yicha iumrah asoschisi bilan bevosita aloqa.", "Пакет, брон ва сафарингиз бўйича iumrah асосчиси билан бевосита алоқа.")
        case .trust:
            return tr("Кто отвечает за вашу поездку, какие документы вы получаете и где проходит граница ответственности авиакомпании.", "Who is responsible for your trip, which documents you receive, and where airline responsibility begins.", "Safaringiz uchun kim javob beradi, qaysi hujjatlarni olasiz va aviakompaniya javobgarligi qayerdan boshlanadi.", "Сафарингиз учун ким жавоб беради, қайси ҳужжатларни оласиз ва авиакомпания жавобгарлиги қаердан бошланади.")
        }
    }

    private var officialVisaSourceTitle: String { tr("Открыть Saudi Visa", "Open Saudi Visa", "Saudi Visa’ni ochish", "Saudi Visa’ни очиш") }
    private var callTitle: String { tr("Позвонить", "Call", "Qo‘ng‘iroq", "Қўнғироқ") }
    private var doneTitle: String { tr("Готово", "Done", "Tayyor", "Тайёр") }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}


struct HotelCareShowcaseCard: View {
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("IumrahCareShowcaseCard")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.015, green: 0.035, blue: 0.09))

            VStack(alignment: .leading, spacing: 11) {
                Text("iumrah Care")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text(L10n.text("hotel_care_card_body", language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.text("hotel_care_contact", language), action: onOpen)
                    .buttonStyle(IumrahPrimaryButtonStyle())
            }
            .padding(20)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }
}

struct HotelCareContactSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("iumrah Care")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(L10n.text("hotel_care_prebook_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Link(destination: URL(string: "https://t.me/saudiclub966")!) {
                    contactRow(icon: "paperplane.fill", title: "Telegram", value: "@saudiclub966")
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "tel:+998508898845")!) {
                    contactRow(icon: "phone.fill", title: L10n.text("hotel_care_call", settings.language), value: "+998 50 889 88 45")
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)
            }
            .padding(IumrahDesign.pagePadding)
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("settings_done", settings.language)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func contactRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            IumrahIconBadge(systemName: icon, role: .care, size: 46, symbolSize: 18, cornerRadius: 15)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(value).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .iumrahCard()
    }
}

private func parseStorefrontISO(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) { return date }
    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: value)
}

private func clock(_ value: String) -> String {
    guard let date = parseStorefrontISO(value) else { return "—" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

private func day(_ value: String) -> String {
    guard let date = parseStorefrontISO(value) else { return String(value.prefix(10)) }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "d MMM"
    return formatter.string(from: date)
}
