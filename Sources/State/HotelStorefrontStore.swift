import Foundation
import SwiftUI

@MainActor
final class HotelStorefrontStore: ObservableObject {
    @Published private(set) var makkahHotels: [HotelSummary] = []
    @Published private(set) var madinahHotels: [HotelSummary] = []
    @Published private(set) var details: [String: HotelDetail] = [:]
    @Published private(set) var flightBoard: StorefrontFlightBoardResponse?
    @Published private(set) var standardQuotes: [String: HotelStorefrontQuote] = [:]
    @Published private(set) var comfortQuotes: [String: HotelStorefrontQuote] = [:]
    @Published private(set) var luxuryQuotes: [String: HotelStorefrontQuote] = [:]
    @Published private(set) var departureOriginCode = "TAS"
    @Published private(set) var flightPackagePreviews: [String: StorefrontFlightPackagePreview] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var hasPrepared = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var favoriteHotelIDs: Set<String> = []

    private let catalog = HotelCatalogService()
    private let storefront = HotelStorefrontService()
    private let packageEngine = RemotePackageEngineClient()
    private let favoritesKey = "iumrah.hotelStorefront.favorites.v1"
    private let snapshotURL: URL
    private var preparationTask: Task<Void, Never>?
    private var hotelServerPackages: [String: [StorefrontServerPackageSnapshot]] = [:]
    private var flightServerPackages: [String: StorefrontServerPackageSnapshot] = [:]

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        snapshotURL = caches.appendingPathComponent("iumrah-hotel-storefront-v3.json")
        favoriteHotelIDs = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
        restoreDiskSnapshot()
    }

    var allHotels: [HotelSummary] { makkahHotels + madinahHotels }
    var baseline: StorefrontFlightBaseline? {
        guard let board = flightBoard else { return nil }
        if let pair = preferredHotelPackagePair(in: board.options) {
            return storefrontBaseline(from: pair)
        }
        return board.baseline
    }

    func automaticTier(for hotel: HotelSummary) -> PackageTier {
        switch hotel.stars ?? 3 {
        case 5...: return .luxury
        case 4: return .comfort
        default: return .standard
        }
    }

    func automaticQuote(for hotel: HotelSummary) -> HotelStorefrontQuote? {
        quote(for: hotel, tier: automaticTier(for: hotel))
    }

    func prepareIfNeeded() async {
        if hasPrepared { return }
        if let preparationTask {
            await preparationTask.value
            return
        }
        let task = Task { @MainActor in await prepare(force: false) }
        preparationTask = task
        await task.value
        preparationTask = nil
    }

    func refresh() async {
        if let preparationTask { await preparationTask.value }
        let task = Task { @MainActor in await prepare(force: true) }
        preparationTask = task
        await task.value
        preparationTask = nil
    }

    func hotel(id: String) -> HotelSummary? {
        allHotels.first(where: { $0.id == id })
    }

    func detail(for hotel: HotelSummary) -> HotelDetail? { details[hotel.id] }

    func ingest(detail: HotelDetail) {
        details[detail.id] = detail
        persistDiskSnapshot()
        startImageWarmup()
    }

    func quote(for hotel: HotelSummary, tier: PackageTier = .standard) -> HotelStorefrontQuote? {
        switch tier {
        case .luxury: return luxuryQuotes[hotel.id]
        case .comfort: return comfortQuotes[hotel.id]
        case .economy, .standard: return standardQuotes[hotel.id]
        }
    }

    func updateDepartureAirport(_ code: String) async {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 3 else { return }
        guard normalized != departureOriginCode || flightBoard?.origin.uppercased() != normalized || baseline == nil else { return }

        departureOriginCode = normalized
        do {
            async let boardRequest = storefront.resilientFlightBoard(origin: normalized)
            async let hotelPackagesRequest = storefront.serverPackages(mode: "hotel-first", origin: normalized)
            async let flightPackagesRequest = storefront.serverPackages(mode: "flight-first", origin: normalized)
            let (board, hotelPackages, flightPackages) = try await (boardRequest, hotelPackagesRequest, flightPackagesRequest)
            flightBoard = board
            applyServerPackages(hotelPackages: hotelPackages, flightPackages: flightPackages)
            hasPrepared = !allHotels.isEmpty && (!standardQuotes.isEmpty || !comfortQuotes.isEmpty || !luxuryQuotes.isEmpty || !flightPackagePreviews.isEmpty)
            errorMessage = nil
            persistDiskSnapshot()
        } catch {
            errorMessage = L10n.error(error, .russian)
        }
    }

    func packagePreview(for option: StorefrontFlightOption) -> StorefrontFlightPackagePreview? {
        flightPackagePreviews[option.id]
    }

    func packagePreview(id packageID: String) async -> StorefrontFlightPackagePreview? {
        if let cached = flightPackagePreviews.values.first(where: { $0.packageID == packageID }) {
            return cached
        }
        if let cached = hotelServerPackages.values.flatMap({ $0 }).first(where: { $0.id == packageID }) {
            return serverPreview(cached, forceHotelFirst: true)
        }
        guard let snapshot = try? await storefront.packageSnapshot(id: packageID) else { return nil }
        return ingestPackageSnapshot(snapshot)
    }

    @discardableResult
    func ingestPackageSnapshot(_ snapshot: StorefrontServerPackageSnapshot) -> StorefrontFlightPackagePreview? {
        if snapshot.entryMode == "hotel-first" {
            let hotelID = snapshot.hotelFirstAnchorHotelId ?? snapshot.makkahHotelId ?? snapshot.madinahHotelId
            if let hotelID {
                var values = hotelServerPackages[hotelID] ?? []
                values.removeAll(where: { existing in
                    if existing.id == snapshot.id { return true }
                    if let variantIndex = snapshot.hotelFirstVariantIndex,
                       existing.hotelFirstVariantIndex == variantIndex { return true }
                    if let variant = snapshot.hotelFirstVariant,
                       !variant.isEmpty,
                       existing.hotelFirstVariant == variant { return true }
                    return false
                })
                values.append(snapshot)
                objectWillChange.send()
                hotelServerPackages[hotelID] = sortedHotelFirstSnapshots(values)
            }
            return serverPreview(snapshot, forceHotelFirst: true)
        }
        objectWillChange.send()
        flightServerPackages[snapshot.id] = snapshot
        return serverPreview(snapshot)
    }

    /// All server-owned Hotel First choices for one concrete hotel. The same
    /// outbound is reused where inventory allows and each return date has its own
    /// immutable 10-digit Package ID.
    func hotelConfiguratorPreviews(for hotel: HotelSummary) -> [StorefrontFlightPackagePreview] {
        sortedHotelFirstSnapshots(hotelServerPackages[hotel.id] ?? []).compactMap {
            serverPreview($0, forceHotelFirst: true)
        }
    }

    func hotelConfiguratorPreview(for hotel: HotelSummary) -> StorefrontFlightPackagePreview? {
        hotelConfiguratorPreviews(for: hotel).first
    }

    func defaultMadinahHotel(for tier: PackageTier) -> HotelSummary? {
        let stars = tier.primaryHotelStars
        let exact = madinahHotels.filter { ($0.stars ?? 0) == stars && nightlyUSD(for: $0) != nil }
        if let hotel = exact.first { return hotel }
        return madinahHotels.first(where: { nightlyUSD(for: $0) != nil })
    }

    /// Published one-way inventory used by the package flight changer. Matching
    /// route rows are shown first; the remainder is exposed under "Other current
    /// flights" without ever revealing the supplier fare itself.
    func configurableFlightChoices(
        direction: FlightDirection,
        trip: TripDraft
    ) -> (primary: [StorefrontConfiguratorFlightChoice], other: [StorefrontConfiguratorFlightChoice]) {
        let options = flightBoard?.options ?? []
        let all = options.compactMap { option -> StorefrontConfiguratorFlightChoice? in
            guard option.inbound == nil,
                  option.currency.caseInsensitiveCompare("USD") == .orderedSame,
                  option.perTravelerFare.isFinite,
                  option.perTravelerFare > 0 else { return nil }

            let leg = option.outbound
            switch direction {
            case .outbound:
                guard !isSaudi(leg.origin), isSaudi(leg.destination) else { return nil }
            case .inbound:
                guard isSaudi(leg.origin), !isSaudi(leg.destination) else { return nil }
            }
            return StorefrontConfiguratorFlightChoice(
                id: option.id,
                leg: leg,
                farePerTravelerUSD: Decimal(option.perTravelerFare),
                observedAt: option.observedAt
            )
        }

        let origin = trip.originCode.uppercased()
        let expectedSaudi = direction == .outbound ? trip.outboundDestinationCode.uppercased() : trip.returnOriginCode.uppercased()

        let hasExactInbound = direction == .inbound && all.contains { choice in
            choice.leg.origin.uppercased() == expectedSaudi && choice.leg.destination.uppercased() == origin
        }

        func isPrimary(_ choice: StorefrontConfiguratorFlightChoice) -> Bool {
            switch direction {
            case .outbound:
                return choice.leg.origin.uppercased() == origin && choice.leg.destination.uppercased() == expectedSaudi
            case .inbound:
                let destination = choice.leg.destination.uppercased()
                let preferredDestination = hasExactInbound ? origin : (origin == "TAS" ? origin : "TAS")
                return choice.leg.origin.uppercased() == expectedSaudi && destination == preferredDestination
            }
        }

        func sorted(_ values: [StorefrontConfiguratorFlightChoice]) -> [StorefrontConfiguratorFlightChoice] {
            values.sorted { lhs, rhs in
                if lhs.leg.departureAt != rhs.leg.departureAt { return lhs.leg.departureAt < rhs.leg.departureAt }
                if lhs.farePerTravelerUSD != rhs.farePerTravelerUSD { return lhs.farePerTravelerUSD < rhs.farePerTravelerUSD }
                return lhs.id < rhs.id
            }
        }

        let primary = sorted(all.filter(isPrimary))
        let ids = Set(primary.map(\.id))
        let relatedOther = all.filter { choice in
            guard !ids.contains(choice.id) else { return false }
            switch direction {
            case .outbound:
                return choice.leg.origin.uppercased() == origin
            case .inbound:
                let destination = choice.leg.destination.uppercased()
                return destination == origin || (origin != "TAS" && destination == "TAS")
            }
        }
        return (primary, sorted(relatedOther))
    }

    func publishedFarePerTraveler(optionID: String) -> Decimal? {
        guard let option = flightBoard?.options.first(where: { $0.id == optionID }),
              option.currency.caseInsensitiveCompare("USD") == .orderedSame,
              option.perTravelerFare.isFinite,
              option.perTravelerFare > 0 else { return nil }
        let fare = Decimal(option.perTravelerFare)
        // Complete rows do not expose per-leg component fares. Splitting is only a
        // neutral display baseline until the pilgrim chooses independent one-way legs.
        return option.inbound == nil ? fare : fare / 2
    }

    func bookingFlightOffer(
        for choice: StorefrontConfiguratorFlightChoice,
        direction: FlightDirection
    ) -> FlightOffer? {
        guard let departure = isoDate(choice.leg.departureAt),
              let arrival = isoDate(choice.leg.arrivalAt) else { return nil }
        return syntheticOffer(
            id: choice.id,
            leg: choice.leg,
            direction: direction,
            departure: departure,
            arrival: arrival,
            fare: choice.farePerTravelerUSD,
            observedAt: choice.observedAt
        )
    }

    /// Rebuilds the exact package quote used by the Flights Scanner checkout after
    /// the pilgrim changes traveler count, room selection or transfer class.
    /// Supplier/component values stay internal; the caller only receives PackageQuote.
    func checkoutQuote(
        for preview: StorefrontFlightPackagePreview,
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomID: String?,
        madinahRoomID: String?,
        transferVehicle: TransferVehicleKind?,
        includeHaramainTrain: Bool = false,
        haramainPublicAddOnUsd: Decimal = 0,
        haramainFareClass: HaramainFareClass = .economy,
        haramainTicketCount: Int? = nil,
        journeyFarePerPersonUSD: Decimal? = nil,
        outboundOffer selectedOutboundOffer: FlightOffer? = nil,
        inboundOffer selectedInboundOffer: FlightOffer? = nil
    ) async -> PackageQuote? {
        // `journeyFarePerPersonUSD` and `haramainPublicAddOnUsd` remain in the
        // signature for source compatibility only. PackageEngine re-resolves all
        // supplier values and public add-ons from identifiers + selections.
        _ = journeyFarePerPersonUSD
        _ = haramainPublicAddOnUsd
        guard let previewOffers = bookingFlightOffers(for: preview) else { return nil }
        let outboundOffer = selectedOutboundOffer ?? previewOffers.outbound
        let inboundOffer = selectedInboundOffer ?? previewOffers.inbound
        guard trip.scope != .makkahAndMadinah || madinahHotel != nil else { return nil }

        let outboundUsesSnapshot = outboundOffer.sourceCandidateID == preview.outboundOptionID
        let inboundUsesSnapshot = inboundOffer.sourceCandidateID == preview.returnOptionID
        let preservesHotelFirstStay = preview.hotelFirstVariant != nil
            && outboundUsesSnapshot
            && inboundUsesSnapshot
            && (trip.scope == .makkahAndMadinah) == (preview.madinahNights > 0)

        return try? await packageEngine.packageQuote(
            trip: trip,
            pricingOffer: inboundOffer,
            outboundOffer: outboundOffer,
            inboundOffer: trip.isRoundTripFlight ? inboundOffer : nil,
            makkahHotelID: makkahHotel.id,
            makkahRoomID: makkahRoomID,
            madinahHotelID: trip.scope == .makkahAndMadinah ? madinahHotel?.id : nil,
            madinahRoomID: trip.scope == .makkahAndMadinah ? madinahRoomID : nil,
            includeHaramainTrain: includeHaramainTrain,
            transferVehicle: transferVehicle,
            haramainFareClass: haramainFareClass,
            haramainTicketCount: haramainTicketCount ?? max(0, trip.adults + trip.children),
            makkahNightsOverride: preservesHotelFirstStay ? preview.makkahNights : nil,
            madinahNightsOverride: preservesHotelFirstStay ? preview.madinahNights : nil
        )
    }

    /// Booking-safe snapshots for the published flight pair. The package fare is
    /// carried once by the pair; the booking payload still preserves both physical
    /// legs and their staff-published identifiers for operations/audit.
    func bookingFlightOffers(for preview: StorefrontFlightPackagePreview) -> (outbound: FlightOffer, inbound: FlightOffer)? {
        guard let outboundDeparture = isoDate(preview.outbound.departureAt),
              let outboundArrival = isoDate(preview.outbound.arrivalAt),
              let inboundDeparture = isoDate(preview.inbound.departureAt),
              let inboundArrival = isoDate(preview.inbound.arrivalAt) else { return nil }

        return (
            syntheticOffer(
                id: preview.outboundOptionID,
                leg: preview.outbound,
                direction: .outbound,
                departure: outboundDeparture,
                arrival: outboundArrival,
                fare: preview.flightFarePerPersonUSD,
                observedAt: preview.fareObservedAt
            ),
            syntheticOffer(
                id: preview.returnOptionID,
                leg: preview.inbound,
                direction: .inbound,
                departure: inboundDeparture,
                arrival: inboundArrival,
                fare: preview.flightFarePerPersonUSD,
                observedAt: preview.fareObservedAt
            )
        )
    }

    func previewImages(for hotel: HotelSummary, limit: Int = 3) -> [String] {
        var values: [String] = []
        if let detail = details[hotel.id] {
            values.append(contentsOf: detail.images.sorted(by: imageSort).map(\.url))
        }
        if let cover = hotel.coverImageURL { values.insert(cover, at: 0) }
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }.prefix(limit).map { $0 }
    }

    func isFavorite(_ hotel: HotelSummary) -> Bool { favoriteHotelIDs.contains(hotel.id) }

    func toggleFavorite(_ hotel: HotelSummary) {
        if favoriteHotelIDs.contains(hotel.id) { favoriteHotelIDs.remove(hotel.id) }
        else { favoriteHotelIDs.insert(hotel.id) }
        UserDefaults.standard.set(Array(favoriteHotelIDs).sorted(), forKey: favoritesKey)
        IumrahHaptics.selection()
    }

    func shareURL(for hotel: HotelSummary) -> URL {
        AppConfig.apiBaseURL.appendingPathComponent("h").appendingPathComponent(HotelStorefrontService.publicHotelToken(hotel.id))
    }

    /// The catalogue and the package baseline are intentionally loaded independently.
    /// A Package Engine problem must never make the hotel catalogue disappear.
    /// As soon as both a fresh hotel price and a published flight baseline are present,
    /// the package quote is pure local arithmetic and is rebuilt immediately.
    private func prepare(force: Bool) async {
        guard force || !hasPrepared else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let makkahRequest = hotelListResult(cities: ["Makkah", "Mecca", "Makka"])
        async let madinahRequest = hotelListResult(cities: [
            "Madinah", "Medina", "Madina", "Medinah",
            "Al Madinah", "Al Medina",
            "Madinah Al Munawwarah", "Al Madinah Al Munawwarah"
        ])
        async let flightRequest = flightBoardResult()
        async let hotelPackagesRequest = serverPackagesResult(mode: "hotel-first")
        async let flightPackagesRequest = serverPackagesResult(mode: "flight-first")

        let (makkahResult, madinahResult, flightResult, hotelPackagesResult, flightPackagesResult) = await (
            makkahRequest, madinahRequest, flightRequest, hotelPackagesRequest, flightPackagesRequest
        )

        var hotelErrors: [Error] = []
        switch makkahResult {
        case .success(let hotels): makkahHotels = hotels
        case .failure(let error): hotelErrors.append(error)
        }
        switch madinahResult {
        case .success(let hotels): madinahHotels = hotels
        case .failure(let error): hotelErrors.append(error)
        }
        if case .success(let board) = flightResult { flightBoard = board }

        let hotelPackages = (try? hotelPackagesResult.get()) ?? []
        let flightPackages = (try? flightPackagesResult.get()) ?? []
        applyServerPackages(hotelPackages: hotelPackages, flightPackages: flightPackages)

        // Details/photos are now lazy. The old implementation fetched every hotel
        // detail and generated 3 server quotes per hotel on tab entry, which created
        // the visible iPhone hitch. Package prices now arrive as one server snapshot.
        persistDiskSnapshot()
        startImageWarmup()

        hasPrepared = !allHotels.isEmpty && (!standardQuotes.isEmpty || !comfortQuotes.isEmpty || !luxuryQuotes.isEmpty || !flightPackagePreviews.isEmpty)

        if allHotels.isEmpty {
            if let error = hotelErrors.first {
                errorMessage = L10n.error(error, .russian)
            } else {
                errorMessage = "Каталог отелей временно недоступен."
            }
        } else if hotelPackages.isEmpty && flightPackages.isEmpty {
            errorMessage = "iumrah обновляет единые серверные пакеты."
        }
    }

    private func serverPackagesResult(mode: String) async -> Result<[StorefrontServerPackageSnapshot], Error> {
        do { return .success(try await storefront.serverPackages(mode: mode, origin: departureOriginCode)) }
        catch { return .failure(error) }
    }

    private func applyServerPackages(
        hotelPackages: [StorefrontServerPackageSnapshot],
        flightPackages: [StorefrontServerPackageSnapshot]
    ) {
        hotelServerPackages = [:]
        for item in hotelPackages {
            let hotelID = item.hotelFirstAnchorHotelId ?? item.makkahHotelId ?? item.madinahHotelId
            guard let hotelID else { continue }
            hotelServerPackages[hotelID, default: []].append(item)
        }
        for (hotelID, values) in hotelServerPackages {
            hotelServerPackages[hotelID] = sortedHotelFirstSnapshots(values)
        }
        flightServerPackages = Dictionary(uniqueKeysWithValues: flightPackages.map { ($0.id, $0) })

        var standard: [String: HotelStorefrontQuote] = [:]
        var comfort: [String: HotelStorefrontQuote] = [:]
        var luxury: [String: HotelStorefrontQuote] = [:]
        for item in hotelPackages.sorted(by: { ($0.hotelFirstVariantIndex ?? 99) < ($1.hotelFirstVariantIndex ?? 99) }) {
            guard let hotelID = item.hotelFirstAnchorHotelId ?? item.makkahHotelId ?? item.madinahHotelId,
                  let total = item.totalPackagePrice,
                  let perPerson = item.pricePerPerson else { continue }
            let quote = HotelStorefrontQuote(
                tier: item.tier,
                packageQuote: PackageQuote(
                    totalPackagePrice: total,
                    pricePerPerson: perPerson,
                    currency: item.currency,
                    isEstimated: item.isEstimated,
                    quoteId: item.id,
                    quoteProof: nil
                ),
                hotelNightlyUsd: 0,
                hotelNights: max(1, item.totalNights),
                rooms: 1,
                travelers: 2,
                flightFarePerTravelerUsd: 0
            )
            switch item.tier {
            case .luxury: if luxury[hotelID] == nil { luxury[hotelID] = quote }
            case .comfort: if comfort[hotelID] == nil { comfort[hotelID] = quote }
            case .economy, .standard: if standard[hotelID] == nil { standard[hotelID] = quote }
            }
        }
        standardQuotes = standard
        comfortQuotes = comfort
        luxuryQuotes = luxury

        var previews: [String: StorefrontFlightPackagePreview] = [:]
        for item in flightPackages {
            guard let preview = serverPreview(item) else { continue }
            previews[item.outboundOfferId] = preview
            if previews[item.inboundOfferId] == nil { previews[item.inboundOfferId] = preview }
        }
        flightPackagePreviews = previews
    }

    private func sortedHotelFirstSnapshots(_ values: [StorefrontServerPackageSnapshot]) -> [StorefrontServerPackageSnapshot] {
        values.sorted { lhs, rhs in
            let left = lhs.hotelFirstVariantIndex ?? 99
            let right = rhs.hotelFirstVariantIndex ?? 99
            if left != right { return left < right }
            if lhs.totalDays != rhs.totalDays { return lhs.totalDays < rhs.totalDays }
            return lhs.id < rhs.id
        }
    }

    private func serverPreview(
        _ item: StorefrontServerPackageSnapshot,
        forceHotelFirst: Bool = false
    ) -> StorefrontFlightPackagePreview? {
        guard let total = item.totalPackagePrice, let perPerson = item.pricePerPerson else { return nil }
        let kind: StorefrontUmrahPackageKind
        if forceHotelFirst {
            kind = item.kind == "makkah-only" ? .hotelFirstMakkah : .makkahMadinahStandard
        } else {
            kind = item.kind == "makkah-only" ? .makkahComfortShort : .makkahMadinahStandard
        }

        let madinahNights = item.madinahNights ?? (item.kind == "makkah-madinah" && item.totalNights > 1
            ? max(1, min(item.totalNights - 1, Int(floor(Double(item.totalNights) * 0.42))))
            : 0)
        let makkahNights = item.makkahNights ?? max(1, item.totalNights - madinahNights)
        var packageHotels: [StorefrontPackageHotel] = []
        if let hotelID = item.makkahHotelId {
            let hotel = hotel(id: hotelID)
            packageHotels.append(StorefrontPackageHotel(
                id: hotelID,
                name: hotel?.name ?? item.hotelName,
                city: hotel?.city ?? item.hotelCity ?? "Makkah",
                stars: hotel?.stars ?? item.hotelStars,
                coverImageURL: hotel?.coverImageURL ?? item.imageUrl,
                nights: makkahNights
            ))
        }
        if let hotelID = item.madinahHotelId {
            let hotel = hotel(id: hotelID)
            packageHotels.append(StorefrontPackageHotel(
                id: hotelID,
                name: hotel?.name ?? item.hotelSecondaryName ?? "Madinah hotel",
                city: hotel?.city ?? "Madinah",
                stars: hotel?.stars,
                coverImageURL: hotel?.coverImageURL,
                nights: max(1, madinahNights)
            ))
        }

        let pairFare = publishedFarePerTraveler(optionID: item.outboundOfferId)
            .map { $0 + (publishedFarePerTraveler(optionID: item.inboundOfferId) ?? 0) } ?? 0
        let quote = PackageQuote(
            totalPackagePrice: total,
            pricePerPerson: perPerson,
            currency: item.currency,
            isEstimated: item.isEstimated,
            quoteId: item.id,
            quoteProof: nil
        )
        return StorefrontFlightPackagePreview(
            packageID: item.id,
            snapshotConfiguration: item.configuration,
            pricePerPerson: perPerson,
            totalPackagePrice: total,
            flightFarePerPersonUSD: pairFare,
            fareObservedAt: flightBoard?.generatedAt ?? item.startDate,
            outboundOptionID: item.outboundOfferId,
            returnOptionID: item.inboundOfferId,
            outbound: item.outbound.clientLeg,
            inbound: item.inbound.clientLeg,
            durationDays: max(1, item.totalDays),
            totalNights: max(1, item.totalNights),
            makkahNights: makkahNights,
            madinahNights: madinahNights,
            hotelFirstVariant: item.hotelFirstVariant,
            hotelFirstVariantIndex: item.hotelFirstVariantIndex,
            hotelFirstVariantMinDays: item.hotelFirstVariantMinDays,
            hotelFirstVariantMaxDays: item.hotelFirstVariantMaxDays,
            hotelFirstAnchorCity: item.hotelFirstAnchorCity,
            hotelFirstAnchorHotelID: item.hotelFirstAnchorHotelId,
            kind: kind,
            tier: item.tier,
            hotels: packageHotels,
            packageQuote: quote
        )
    }

    private func hotelListResult(city: String) async -> Result<[HotelSummary], Error> {
        do { return .success(try await catalog.listHotels(city: city)) }
        catch { return .failure(error) }
    }

    private func hotelListResult(cities: [String]) async -> Result<[HotelSummary], Error> {
        var merged: [String: HotelSummary] = [:]
        var lastError: Error?
        for city in cities {
            do {
                for hotel in try await catalog.listHotels(city: city) { merged[hotel.id] = hotel }
            } catch {
                lastError = error
            }
        }
        let hotels = Array(merged.values).sorted { lhs, rhs in
            if lhs.stars != rhs.stars { return (lhs.stars ?? 0) > (rhs.stars ?? 0) }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        if !hotels.isEmpty { return .success(hotels) }
        if let lastError { return .failure(lastError) }
        return .success([])
    }

    private func flightBoardResult() async -> Result<StorefrontFlightBoardResponse, Error> {
        do { return .success(try await storefront.resilientFlightBoard(origin: departureOriginCode)) }
        catch { return .failure(error) }
    }

    private func fetchDetails(for hotels: [HotelSummary]) async -> [HotelDetail] {
        await withTaskGroup(of: HotelDetail?.self, returning: [HotelDetail].self) { group in
            for hotel in hotels {
                group.addTask {
                    try? await self.catalog.hotelDetail(id: hotel.id)
                }
            }
            var loaded: [HotelDetail] = []
            for await detail in group {
                if let detail { loaded.append(detail) }
            }
            return loaded
        }
    }

    private func rebuildQuotes() async {
        guard let baseline else {
            // Keep the last valid public server quotes while the baseline refreshes.
            return
        }

        let hotels = allHotels
        let storefrontService = storefront
        let results = await withTaskGroup(of: (String, PackageTier, HotelStorefrontQuote?).self, returning: [(String, PackageTier, HotelStorefrontQuote?)].self) { group in
            for hotel in hotels {
                let price = bestFreshPrice(for: hotel)
                for tier in [PackageTier.standard, .comfort, .luxury] {
                    group.addTask {
                        let quote = try? await storefrontService.quote(hotel: hotel, tier: tier, baseline: baseline, price: price)
                        return (hotel.id, tier, quote)
                    }
                }
            }
            var values: [(String, PackageTier, HotelStorefrontQuote?)] = []
            for await value in group { values.append(value) }
            return values
        }

        var standard: [String: HotelStorefrontQuote] = [:]
        var comfort: [String: HotelStorefrontQuote] = [:]
        var luxury: [String: HotelStorefrontQuote] = [:]
        for (hotelID, tier, quote) in results {
            guard let quote else { continue }
            switch tier {
            case .luxury: luxury[hotelID] = quote
            case .comfort: comfort[hotelID] = quote
            case .economy, .standard: standard[hotelID] = quote
            }
        }
        if !standard.isEmpty { standardQuotes = standard }
        if !comfort.isEmpty { comfortQuotes = comfort }
        if !luxury.isEmpty { luxuryQuotes = luxury }
    }

    private func bestFreshPrice(for hotel: HotelSummary) -> HotelCatalogPrice? {
        if let detailPrice = details[hotel.id]?.price, detailPrice.isFresh { return detailPrice }
        if let summaryPrice = hotel.price, summaryPrice.isFresh { return summaryPrice }
        return details[hotel.id]?.price ?? hotel.price
    }

    // MARK: - iumrah Flights Scanner package composition

    /// The flight storefront is a package surface, not a raw fare board.
    /// Uzbekistan → Saudi Arabia rows are package anchors. The scanner pairs each
    /// anchor with a Saudi Arabia → Uzbekistan return and mirrors the same composed
    /// package price onto that return row. Raw ticket prices stay internal.
    private func rebuildFlightPackagePreviews() async {
        guard let board = flightBoard else {
            flightPackagePreviews = [:]
            return
        }

        let standardMakkahHotel = fixedStorefrontHotel(
            in: makkahHotels,
            preferredNames: ["Nawazi Hotel", "Nawazi Watheer Hotel"],
            requiredTokenGroups: [["nawazi"]]
        )
        let standardMadinahHotel = fixedStorefrontHotel(
            in: madinahHotels,
            preferredNames: ["Mihrab Tayyiba", "Mihrab Tayba", "Mihrab Taiba"],
            requiredTokenGroups: [["mihrab"], ["tayyiba", "tayba", "taiba"]]
        )
        let comfortMakkahHotel = fixedStorefrontHotel(
            in: makkahHotels,
            preferredNames: ["Shohada Hotel", "Al Shohada Hotel", "Shuhada Hotel", "Al Shuhada Hotel"],
            requiredTokenGroups: [["shohada", "shuhada"]]
        )

        var output: [String: StorefrontFlightPackagePreview] = [:]

        // Only outbound Uzbekistan → Saudi rows create packages. Saudi → Uzbekistan
        // rows receive the price of the first package that actually uses that leg.
        // This prevents the same return flight from independently inventing a second price.
        for option in board.options where isPackageAnchor(option) {
            guard let pair = packagePair(forOutbound: option, among: board.options),
                  let preview = await makePackagePreview(
                    pair: pair,
                    standardMakkahHotel: standardMakkahHotel,
                    standardMadinahHotel: standardMadinahHotel,
                    comfortMakkahHotel: comfortMakkahHotel
                  ) else { continue }

            output[option.id] = preview
            if pair.returnOptionID != option.id, output[pair.returnOptionID] == nil {
                output[pair.returnOptionID] = preview
            }
        }

        flightPackagePreviews = output
    }

    private struct FlightPackagePair {
        let outboundOptionID: String
        let returnOptionID: String
        let outbound: StorefrontFlightLeg
        let inbound: StorefrontFlightLeg
        let farePerPersonUSD: Decimal
        let observedAt: String
        let durationDays: Int
        let travelerCount: Int
        let kind: StorefrontUmrahPackageKind
    }

    private func preferredHotelPackagePair(in options: [StorefrontFlightOption]) -> FlightPackagePair? {
        let origin = departureOriginCode.uppercased()
        let anchors = options
            .filter { option in
                isPackageAnchor(option) && option.outbound.origin.uppercased() == origin
            }
            .sorted { lhs, rhs in
                let lhsDay = stableTravelDay(lhs.outbound.departureAt) ?? .distantFuture
                let rhsDay = stableTravelDay(rhs.outbound.departureAt) ?? .distantFuture
                if lhsDay != rhsDay { return lhsDay < rhsDay }
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.perTravelerFare < rhs.perTravelerFare
            }

        for option in anchors {
            if let pair = packagePair(forOutbound: option, among: options) { return pair }
        }
        return nil
    }

    private func storefrontBaseline(from pair: FlightPackagePair) -> StorefrontFlightBaseline {
        StorefrontFlightBaseline(
            mode: "iumrah_configurator_published_pair",
            travelers: pair.travelerCount,
            currency: "USD",
            perTravelerFareUsd: NSDecimalNumber(decimal: pair.farePerPersonUSD).doubleValue,
            totalFareUsd: NSDecimalNumber(decimal: pair.farePerPersonUSD * Decimal(pair.travelerCount)).doubleValue,
            outboundOfferID: pair.outboundOptionID,
            inboundOfferID: pair.returnOptionID,
            outbound: pair.outbound,
            inbound: pair.inbound,
            observedAt: pair.observedAt
        )
    }

    private func isPackageAnchor(_ option: StorefrontFlightOption) -> Bool {
        let origin = option.outbound.origin.uppercased()
        let destination = option.outbound.destination.uppercased()
        return !isSaudi(origin) && isSaudi(destination)
    }

    private func packagePair(
        forOutbound option: StorefrontFlightOption,
        among all: [StorefrontFlightOption]
    ) -> FlightPackagePair? {
        guard option.currency.caseInsensitiveCompare("USD") == .orderedSame,
              option.perTravelerFare.isFinite,
              option.perTravelerFare > 0,
              isPackageAnchor(option) else { return nil }

        // A staff row may already contain both directions. Keep it authoritative when
        // it satisfies the same scanner rules as two one-way publications.
        if let inbound = option.inbound,
           let gap = tripGapDays(outbound: option.outbound, inbound: inbound),
           isSaudi(inbound.origin),
           isAllowedReturnDestination(inbound.destination, for: option.outbound.origin),
           let kind = packageKind(outbound: option.outbound, inbound: inbound, gapDays: gap) {
            return FlightPackagePair(
                outboundOptionID: option.id,
                returnOptionID: option.id,
                outbound: option.outbound,
                inbound: inbound,
                farePerPersonUSD: Decimal(option.perTravelerFare),
                observedAt: option.observedAt,
                durationDays: gap,
                travelerCount: max(1, option.travelerCount),
                kind: kind
            )
        }

        guard option.inbound == nil else { return nil }

        let preferredDestination = option.outbound.origin.uppercased()
        if let candidate = bestReturnOneWay(
            for: option.outbound,
            among: all,
            returnDestination: preferredDestination
        ) {
            return oneWayPair(outboundOption: option, returnOption: candidate)
        }

        // Regional departures may legitimately return to Tashkent when no matching
        // flight to the original city exists inside the valid package window.
        if preferredDestination != "TAS",
           let fallback = bestReturnOneWay(
            for: option.outbound,
            among: all,
            returnDestination: "TAS"
           ) {
            return oneWayPair(outboundOption: option, returnOption: fallback)
        }

        return nil
    }

    private func oneWayPair(
        outboundOption: StorefrontFlightOption,
        returnOption: StorefrontFlightOption
    ) -> FlightPackagePair? {
        guard let gap = tripGapDays(outbound: outboundOption.outbound, inbound: returnOption.outbound),
              let kind = packageKind(outbound: outboundOption.outbound, inbound: returnOption.outbound, gapDays: gap) else {
            return nil
        }
        return FlightPackagePair(
            outboundOptionID: outboundOption.id,
            returnOptionID: returnOption.id,
            outbound: outboundOption.outbound,
            inbound: returnOption.outbound,
            farePerPersonUSD: Decimal(outboundOption.perTravelerFare) + Decimal(returnOption.perTravelerFare),
            observedAt: max(outboundOption.observedAt, returnOption.observedAt),
            durationDays: gap,
            travelerCount: max(1, outboundOption.travelerCount),
            kind: kind
        )
    }

    private func bestReturnOneWay(
        for outbound: StorefrontFlightLeg,
        among all: [StorefrontFlightOption],
        returnDestination: String
    ) -> StorefrontFlightOption? {
        let candidates = all.filter { candidate in
            guard candidate.inbound == nil,
                  candidate.currency.caseInsensitiveCompare("USD") == .orderedSame,
                  candidate.perTravelerFare.isFinite,
                  candidate.perTravelerFare > 0,
                  isSaudi(candidate.outbound.origin),
                  candidate.outbound.destination.caseInsensitiveCompare(returnDestination) == .orderedSame,
                  let gap = tripGapDays(outbound: outbound, inbound: candidate.outbound),
                  packageKind(outbound: outbound, inbound: candidate.outbound, gapDays: gap) != nil else {
                return false
            }
            return true
        }

        guard !candidates.isEmpty else { return nil }

        // JED arrivals get a real 2–3 day Makkah-only Comfort product whenever that
        // window exists. Otherwise the scanner composes a 4–15 day two-city Standard trip.
        if outbound.destination.uppercased() == "JED" {
            let short = candidates.filter { candidate in
                guard candidate.outbound.origin.uppercased() == "JED",
                      let gap = tripGapDays(outbound: outbound, inbound: candidate.outbound) else { return false }
                return (2...3).contains(gap)
            }
            if !short.isEmpty {
                return short.min { lhs, rhs in
                    let lhsGap = tripGapDays(outbound: outbound, inbound: lhs.outbound) ?? 99
                    let rhsGap = tripGapDays(outbound: outbound, inbound: rhs.outbound) ?? 99
                    let lhsDistance = abs(lhsGap - 3)
                    let rhsDistance = abs(rhsGap - 3)
                    if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                    if lhs.perTravelerFare != rhs.perTravelerFare { return lhs.perTravelerFare < rhs.perTravelerFare }
                    if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                    return lhs.outbound.departureAt < rhs.outbound.departureAt
                }
            }
        }

        let long = candidates.filter { candidate in
            guard let gap = tripGapDays(outbound: outbound, inbound: candidate.outbound) else { return false }
            return (4...15).contains(gap)
        }
        return long.min { lhs, rhs in
            let complementary = complementarySaudiAirport(for: outbound.destination)
            let lhsOpenJaw = lhs.outbound.origin.uppercased() == complementary
            let rhsOpenJaw = rhs.outbound.origin.uppercased() == complementary
            if lhsOpenJaw != rhsOpenJaw { return lhsOpenJaw && !rhsOpenJaw }

            let lhsGap = tripGapDays(outbound: outbound, inbound: lhs.outbound) ?? 99
            let rhsGap = tripGapDays(outbound: outbound, inbound: rhs.outbound) ?? 99
            let lhsDistance = abs(lhsGap - 7)
            let rhsDistance = abs(rhsGap - 7)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            if lhs.perTravelerFare != rhs.perTravelerFare { return lhs.perTravelerFare < rhs.perTravelerFare }
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.outbound.departureAt < rhs.outbound.departureAt
        }
    }

    private func packageKind(
        outbound: StorefrontFlightLeg,
        inbound: StorefrontFlightLeg,
        gapDays: Int
    ) -> StorefrontUmrahPackageKind? {
        guard isSaudi(outbound.destination), isSaudi(inbound.origin) else { return nil }

        if outbound.destination.uppercased() == "JED",
           inbound.origin.uppercased() == "JED",
           (2...3).contains(gapDays) {
            return .makkahComfortShort
        }

        if (4...15).contains(gapDays) {
            return .makkahMadinahStandard
        }

        return nil
    }

    private func isAllowedReturnDestination(_ airport: String, for outboundOrigin: String) -> Bool {
        let destination = airport.uppercased()
        let preferred = outboundOrigin.uppercased()
        return destination == preferred || (preferred != "TAS" && destination == "TAS")
    }

    private func makePackagePreview(
        pair: FlightPackagePair,
        standardMakkahHotel: HotelSummary?,
        standardMadinahHotel: HotelSummary?,
        comfortMakkahHotel: HotelSummary?
    ) async -> StorefrontFlightPackagePreview? {
        guard pair.farePerPersonUSD > 0,
              let outboundDeparture = isoDate(pair.outbound.departureAt),
              let outboundArrival = isoDate(pair.outbound.arrivalAt),
              let inboundDeparture = isoDate(pair.inbound.departureAt),
              let inboundArrival = isoDate(pair.inbound.arrivalAt),
              let tripDepartureDay = stableTravelDay(pair.outbound.departureAt),
              let saudiArrivalDay = stableTravelDay(pair.outbound.arrivalAt),
              let returnDay = stableTravelDay(pair.inbound.departureAt),
              returnDay > saudiArrivalDay else { return nil }

        var trip = TripDraft()
        trip.origin = pair.outbound.origin.uppercased()
        trip.originAirport = nil
        trip.arrivalAirport = pair.outbound.destination.uppercased() == "MED" ? .madinah : .jeddah
        trip.departureDate = tripDepartureDay
        trip.saudiArrivalDate = saudiArrivalDay
        trip.returnDate = returnDay
        trip.flexibility = .exact
        trip.adults = 1
        trip.children = 0
        trip.infants = 0
        trip.rooms = 1
        trip.flightTripType = .roundTrip

        let makkahHotel: HotelSummary
        let madinahHotel: HotelSummary?
        switch pair.kind {
        case .makkahComfortShort:
            guard let hotel = comfortMakkahHotel, nightlyUSD(for: hotel) != nil else { return nil }
            makkahHotel = hotel
            madinahHotel = nil
            trip.scope = .makkahOnly
            trip.packageTier = .comfort
            trip.hotelStars = PackageTier.comfort.primaryHotelStars

        case .makkahMadinahStandard:
            guard let makkah = standardMakkahHotel,
                  let madinah = standardMadinahHotel,
                  nightlyUSD(for: makkah) != nil,
                  nightlyUSD(for: madinah) != nil else { return nil }
            makkahHotel = makkah
            madinahHotel = madinah
            trip.scope = .makkahAndMadinah
            trip.packageTier = .standard
            trip.hotelStars = PackageTier.standard.primaryHotelStars

        case .hotelFirstMakkah:
            // This kind is created only by hotelConfiguratorPreview(for:), never by
            // the flight-first pair builder. Keep the shared enum exhaustive here.
            return nil
        }

        let outboundOffer = syntheticOffer(
            id: pair.outboundOptionID,
            leg: pair.outbound,
            direction: .outbound,
            departure: outboundDeparture,
            arrival: outboundArrival,
            fare: pair.farePerPersonUSD,
            observedAt: pair.observedAt
        )
        let pricingOffer = syntheticOffer(
            id: pair.returnOptionID,
            leg: pair.inbound,
            direction: .inbound,
            departure: inboundDeparture,
            arrival: inboundArrival,
            fare: pair.farePerPersonUSD,
            observedAt: pair.observedAt
        )

        guard let quote = try? await packageEngine.packageQuote(
            trip: trip,
            pricingOffer: pricingOffer,
            outboundOffer: outboundOffer,
            inboundOffer: pricingOffer,
            makkahHotelID: makkahHotel.id,
            makkahRoomID: nil,
            madinahHotelID: madinahHotel?.id,
            madinahRoomID: nil,
            includeHaramainTrain: false,
            transferVehicle: nil,
            haramainFareClass: .economy,
            haramainTicketCount: 0
        ) else { return nil }

        let stay = TripStayPlanner.breakdown(for: trip, calendar: storefrontCalendar)
        var packageHotels = [storefrontPackageHotel(makkahHotel, nights: stay.makkahNights)]
        if let madinahHotel, stay.madinahNights > 0 {
            packageHotels.append(storefrontPackageHotel(madinahHotel, nights: stay.madinahNights))
        }

        guard let quoteID = quote.quoteId, !quoteID.isEmpty else { return nil }

        return StorefrontFlightPackagePreview(
            packageID: quoteID,
            snapshotConfiguration: nil,
            pricePerPerson: quote.pricePerPerson,
            totalPackagePrice: quote.totalPackagePrice,
            flightFarePerPersonUSD: pair.farePerPersonUSD,
            fareObservedAt: pair.observedAt,
            outboundOptionID: pair.outboundOptionID,
            returnOptionID: pair.returnOptionID,
            outbound: pair.outbound,
            inbound: pair.inbound,
            durationDays: pair.durationDays,
            totalNights: stay.totalNights,
            makkahNights: stay.makkahNights,
            madinahNights: stay.madinahNights,
            hotelFirstVariant: nil,
            hotelFirstVariantIndex: nil,
            hotelFirstVariantMinDays: nil,
            hotelFirstVariantMaxDays: nil,
            hotelFirstAnchorCity: nil,
            hotelFirstAnchorHotelID: nil,
            kind: pair.kind,
            tier: trip.packageTier,
            hotels: packageHotels,
            packageQuote: quote
        )
    }

    private func storefrontPackageHotel(_ hotel: HotelSummary, nights: Int) -> StorefrontPackageHotel {
        StorefrontPackageHotel(
            id: hotel.id,
            name: hotel.name,
            city: hotel.city,
            stars: hotel.stars,
            coverImageURL: previewImages(for: hotel, limit: 1).first ?? hotel.coverImageURL,
            nights: max(1, nights)
        )
    }

    private func syntheticOffer(
        id: String,
        leg: StorefrontFlightLeg,
        direction: FlightDirection,
        departure: Date,
        arrival: Date,
        fare: Decimal,
        observedAt: String
    ) -> FlightOffer {
        let directSegments: [FlightSegment]?
        if leg.stops == 0 {
            directSegments = [
                FlightSegment(
                    id: "storefront-segment:\(id):\(direction.rawValue)",
                    airline: leg.airline,
                    airlineCode: leg.airlineCode,
                    flightNumber: leg.flightNumber,
                    origin: FlightAirportSnapshot(code: leg.origin),
                    destination: FlightAirportSnapshot(code: leg.destination),
                    departureAt: departure,
                    arrivalAt: arrival,
                    durationMinutes: max(1, leg.durationMinutes),
                    cabin: leg.cabinClass
                )
            ]
        } else {
            directSegments = nil
        }

        return FlightOffer(
            id: "storefront-package:\(id):\(direction.rawValue)",
            direction: direction,
            airline: leg.airline,
            flightNumber: leg.flightNumber,
            origin: leg.origin,
            destination: leg.destination,
            departureAt: departure,
            arrivalAt: arrival,
            stops: leg.stops,
            durationMinutes: leg.durationMinutes,
            totalPackagePrice: fare,
            currency: "USD",
            sourceLabel: "iumrah Flights Scanner",
            sourceCandidateID: id,
            airlineCode: leg.airlineCode,
            segments: directSegments,
            fareAmount: fare,
            fareScope: .perPassenger,
            fareObservedAt: isoDate(observedAt),
            providerItineraryID: id,
            cabinClass: leg.cabinClass,
            requiresSelfTransfer: false
        )
    }

    private func fixedStorefrontHotel(
        in hotels: [HotelSummary],
        preferredNames: [String],
        requiredTokenGroups: [[String]]
    ) -> HotelSummary? {
        let exactNames = Set(preferredNames.map(normalizedHotelName))
        if let hotel = hotels.first(where: { exactNames.contains(normalizedHotelName($0.name)) && nightlyUSD(for: $0) != nil }) {
            return hotel
        }

        return hotels.first { hotel in
            let normalized = normalizedHotelName(hotel.name)
            let matches = requiredTokenGroups.allSatisfy { alternatives in
                alternatives.contains { normalized.contains($0) }
            }
            return matches && nightlyUSD(for: hotel) != nil
        }
    }

    private func normalizedHotelName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func nightlyUSD(for hotel: HotelSummary) -> Decimal? {
        let candidates = [details[hotel.id]?.price, hotel.price].compactMap { $0 }
        for price in candidates {
            guard let value = price.nightlyUSD, value.isFinite, value > 0 else { continue }
            return Decimal(value)
        }
        return nil
    }

    private func isSaudi(_ airport: String) -> Bool {
        let code = airport.uppercased()
        return code == "JED" || code == "MED"
    }

    private func complementarySaudiAirport(for airport: String) -> String? {
        switch airport.uppercased() {
        case "MED": return "JED"
        case "JED": return "MED"
        default: return nil
        }
    }

    private func tripGapDays(outbound: StorefrontFlightLeg, inbound: StorefrontFlightLeg) -> Int? {
        guard let first = stableTravelDay(outbound.departureAt),
              let second = stableTravelDay(inbound.departureAt) else { return nil }
        return storefrontCalendar.dateComponents([.day], from: first, to: second).day
    }

    private func stableTravelDay(_ value: String) -> Date? {
        let day = String(value.prefix(10))
        guard day.count == 10 else { return nil }
        return storefrontDayFormatter.date(from: day)
    }

    private func isoDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = fractional.date(from: value) { return value }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }

    private var storefrontCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var storefrontDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = storefrontCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = storefrontCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.defaultDate = Date(timeIntervalSince1970: 43_200)
        return formatter
    }

    private func restoreDiskSnapshot() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(HotelStorefrontDiskSnapshot.self, from: data) else { return }
        makkahHotels = snapshot.makkahHotels
        madinahHotels = snapshot.madinahHotels
        details = Dictionary(uniqueKeysWithValues: snapshot.hotelDetails.map { ($0.id, $0) })
        flightBoard = snapshot.flightBoard
        departureOriginCode = snapshot.flightBoard?.origin.uppercased() ?? "TAS"
        // Package prices are intentionally not rebuilt from disk. The app renders
        // cached hotel media immediately and then obtains the current 24h server snapshot.
        // Disk data renders immediately, then the app refreshes prices/flight baseline
        // once per launch. Photo bytes themselves live in the persistent image cache.
        hasPrepared = false
        startImageWarmup()
    }

    private func persistDiskSnapshot() {
        let snapshot = HotelStorefrontDiskSnapshot(
            makkahHotels: makkahHotels,
            madinahHotels: madinahHotels,
            hotelDetails: Array(details.values),
            flightBoard: flightBoard,
            savedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    private func startImageWarmup() {
        let critical = allHotels
            .flatMap { previewImages(for: $0, limit: 3) }
            .compactMap { AppConfig.absoluteURL($0) }
        let detailWarmup = details.values
            .flatMap { detail in detail.images.sorted(by: imageSort).prefix(8).map(\.url) }
            .compactMap { AppConfig.absoluteURL($0) }
        Task(priority: .userInitiated) { await HotelImageCache.shared.prefetch(urls: critical) }
        Task(priority: .utility) { await HotelImageCache.shared.prefetch(urls: detailWarmup) }
    }

    private func imageSort(_ lhs: HotelImage, _ rhs: HotelImage) -> Bool {
        if lhs.isCover != rhs.isCover { return lhs.isCover && !rhs.isCover }
        return lhs.position < rhs.position
    }
}
