import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var storefront: HotelStorefrontStore
    @EnvironmentObject private var journey: JourneyStore
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared
    @State private var showZiyarats = false
    @State private var showCareRequestBuilder = false
    @State private var showFlightsService = false
    @State private var showTransferService = false
    @State private var selectedFlightPackage: StorefrontFlightPackagePreview?
    @State private var expandedHomeFAQID: String?
    @State private var showAboutProject = false

    private struct ReadyPackageItem: Identifiable {
        let option: StorefrontFlightOption
        let preview: StorefrontFlightPackagePreview
        var id: String { option.id }
    }

    private var activeSession: StoredBookingSession? {
        bookings.sessions.first { $0.effectiveStatus.uppercased() != "COMPLETED" }
    }

    var body: some View {
        marketingHome
            .task(id: activeSession?.id) {
                await bookings.refreshAll()
                while !Task.isCancelled {
                    if let activeSession { _ = try? await bookings.loadESIMs(for: activeSession.id) }
                    try? await Task.sleep(nanoseconds: 120_000_000_000)
                }
            }
            .task(id: journey.trip.originCode.uppercased()) {
                await storefront.prepareIfNeeded()
                await storefront.updateDepartureAirport(journey.trip.originCode)
            }
            .fullScreenCover(isPresented: $showZiyarats) {
                ZiyaratJourneyView()
                    .environmentObject(settings)
                    .environmentObject(chrome)
            }
            .navigationDestination(isPresented: $showCareRequestBuilder) {
                IumrahCareRequestView()
            }
            .navigationDestination(isPresented: $showFlightsService) {
                IumrahFlightsView()
            }
            .navigationDestination(isPresented: $showTransferService) {
                IumrahTransferServiceView()
            }
            .navigationDestination(item: $selectedFlightPackage) { preview in
                StorefrontUmrahPackageDetailView(preview: preview)
            }
            .navigationDestination(isPresented: $showAboutProject) {
                IumrahStoryView()
            }
    }

    private var marketingHome: some View {
        GeometryReader { viewport in
            let contentWidth = max(0, viewport.size.width - (IumrahDesign.pagePadding * 2))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    IumrahRootPageTitle(title: L10n.text("tab_home", settings.language), usesBrandLogo: true, brandScale: 1.25, showsConnectivityStatus: true)
                    if !clientNotifications.homeNotifications.isEmpty {
                        SystemNotificationsCarouselView(
                            notifications: Array(clientNotifications.homeNotifications.prefix(5)),
                            onOpen: { openSystemNotification($0) },
                            onDismiss: { dismissSystemNotification($0) }
                        )
                    }
                    HomeEmotionalJourneyPrompt()
                    HomeVideoCarousel()

                    IumrahHomeAudienceSection(language: settings.language)

                    IumrahHomeServicesSection(
                        language: settings.language,
                        onTransfer: { showTransferService = true },
                        onESIM: { chrome.presentESIM() },
                        onFlights: { showFlightsService = true },
                        onZiyarats: { showZiyarats = true },
                        onCare: { chrome.navigate(to: .care) }
                    )

                    readyPackagesSection
                    buildMyUmrahSection

                    VStack(alignment: .leading, spacing: 15) {
                        IumrahHomeSectionHeader(title: homeProductsTitle)
                        productsCarousel(contentWidth: contentWidth)
                    }

                    confidenceStrip
                    philosophyCard
                    connectedTripCard
                    personalUmrahFAQ
                    homeAboutFooter
                }
                // Keep the same single content-column discipline used by Account.
                // The explicit viewport width prevents any carousel/card from enlarging
                // the vertical ScrollView's horizontal content size and cancelling the
                // standard page insets for every sibling below it.
                .frame(width: contentWidth, alignment: .topLeading)
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 128)
            }
            .frame(width: viewport.size.width, alignment: .topLeading)
        }
        .background(Color.iumrahPageBackground)
    }


    private func dismissSystemNotification(_ notification: ClientSystemNotification) {
        IumrahHaptics.selection()
        clientNotifications.dismissFromHome(notification)
    }

    private func openSystemNotification(_ notification: ClientSystemNotification) {
        IumrahHaptics.selection()
        Task { await clientNotifications.markOpened(notification, accountToken: account.bearerToken) }
        switch notification.destination {
        case "hotels": chrome.navigate(to: .hotels)
        case "bookings": chrome.navigate(to: .booking)
        case "care": chrome.navigate(to: .care)
        case "account": chrome.navigate(to: .account)
        case "booking":
            if let bookingID = notification.destinationBookingID, bookings.booking(id: bookingID) != nil {
                chrome.openBooking(id: bookingID)
            } else {
                chrome.navigate(to: .booking)
            }
        default: chrome.navigate(to: .home)
        }
    }

    private func activeJourneyHome(_ session: StoredBookingSession) -> some View {
        ZStack {
            Image("MakkahBackground")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.48), Color.black.opacity(0.12), Color.black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    IumrahRootPageTitle(
                        title: L10n.text("tab_home", settings.language),
                        showsMakkahTime: true,
                        lightStyle: true,
                        usesBrandLogo: true,
                        showsConnectivityStatus: true
                    )

                    activeBookingCard(session)
                    activeCareCard(session)

                    Color.clear
                        .frame(height: 330)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
    }

    private func activeBookingCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center) {
                Label(L10n.text("home_hero_kicker", settings.language), systemImage: "moon.stars.fill")
                    .font(.caption.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Color.black.opacity(0.58))

                Spacer()

                IumrahIconBadge(
                    systemName: statusIcon(session.effectiveStatus),
                    role: IumrahBookingStatusVisual.role(for: session.effectiveStatus),
                    size: 36,
                    symbolSize: 15,
                    shape: .circle
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.status(session.effectiveStatus, settings.language))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(Color.black)

                if let travelerName = session.travelerName, !travelerName.isEmpty {
                    Text(travelerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.58))
                }
            }

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 12) {
                journeySummaryRow(
                    icon: "airplane",
                    title: L10n.text("route_label", settings.language),
                    value: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)"
                )
                journeySummaryRow(
                    icon: "calendar",
                    title: L10n.text("detail_dates", settings.language),
                    value: "\(L10n.date(session.booking.input.startDate, settings.language)) – \(L10n.date(session.booking.input.endDate, settings.language))"
                )
                if !session.booking.hotelNames.makkah.isEmpty {
                    journeySummaryRow(
                        icon: "building.2.fill",
                        title: L10n.text("detail_hotel", settings.language),
                        value: session.booking.hotelNames.makkah
                    )
                }
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("final_price", settings.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.50))
                    Text(money(session.booking.perPilgrimUsd))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)
                }
                Spacer()
                if let pilgrimID = session.displayPilgrimID {
                    Text("ID \(pilgrimID)")
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.42))
                }
            }

            NavigationLink {
                BookingDetailView(bookingID: session.id)
            } label: {
                HStack {
                    Text(L10n.text("open_booking", settings.language))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 28, y: 14)
    }

    private func journeySummaryRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, size: 34, symbolSize: 14, shape: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.black.opacity(0.48))
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private func activeCareCard(_ session: StoredBookingSession) -> some View {
        Button {
            chrome.navigate(to: .care)
        } label: {
            HStack(spacing: 14) {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .padding(5)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("iumrah Care")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.text("care_subtitle", settings.language))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(16)
            .background {
                LinearGradient(
                    colors: [Color.iumrahCareDark.opacity(0.96), Color.iumrahCareLight.opacity(0.88)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: Color.iumrahCareDark.opacity(0.22), radius: 24, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityHint(session.displayPilgrimID.map { "ID \($0)" } ?? "")
    }

    private var ziyaratsHomeCard: some View {
        Button {
            IumrahHaptics.selection()
            showZiyarats = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                Image("ZiyaratQuba3")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 255)
                    .clipped()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.16), Color.black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "map.fill")
                        Text("MAKKAH · MADINAH")
                    }
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.86))

                    Text(ziyaratsHomeTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .tracking(-0.6)
                        .foregroundStyle(.white)

                    Text(ziyaratsHomeSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(ziyaratsHomeCTA)
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 255)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.16), radius: 24, y: 11)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("iumrah Ziyarats")
    }

    private var ziyaratsHomeTitle: String {
        "iumrah Ziyarats"
    }

    private var ziyaratsHomeSubtitle: String {
        switch settings.language {
        case .russian: return "Священные и исторические места Мекки и Медины — в одном маршруте. Доступ к iumrah Ziyarats включён в iumrah Services вашего пакета."
        case .english: return "Sacred and historic places across Makkah and Madinah in one journey. Access to iumrah Ziyarats is included with your package’s iumrah Services."
        case .uzbek: return "Makka va Madinadagi muqaddas hamda tarixiy joylar — bitta yo‘nalishda. iumrah Ziyarats sizning paketingizdagi iumrah Services tarkibiga kiradi."
        case .uzbekCyrillic: return "Макка ва Мадинадаги муқаддас ҳамда тарихий жойлар — битта йўналишда. iumrah Ziyarats сизнинг пакетингиздаги iumrah Services таркибига киради."
        }
    }

    private var ziyaratsHomeCTA: String {
        switch settings.language {
        case .russian: return "Открыть Ziyarats"
        case .english: return "Open Ziyarats"
        case .uzbek: return "Ziyarats’ni ochish"
        case .uzbekCyrillic: return "Ziyarats’ни очиш"
        }
    }

    private var flightsWorldFooter: some View {
        let pageBackground = Color.iumrahPageBackground

        return VStack(spacing: 0) {
            Text("From the world to Mecca")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .padding(.bottom, 8)
                .allowsHitTesting(false)

            ZStack {
                IumrahInteractiveGlobe(presentation: .worldToMakkah)
                    .frame(height: 390)
                    // Fade the complete MapKit surface itself, including its black sky,
                    // so no rectangular map boundary survives against Home's background.
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.00),
                                .init(color: .white.opacity(0.16), location: 0.08),
                                .init(color: .white, location: 0.25),
                                .init(color: .white, location: 0.73),
                                .init(color: .white.opacity(0.20), location: 0.93),
                                .init(color: .clear, location: 1.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                // A second two-sided blend uses the exact Home page background color.
                // This keeps the transition seamless in both light and dark appearance.
                LinearGradient(
                    stops: [
                        .init(color: pageBackground, location: 0.00),
                        .init(color: pageBackground.opacity(0.82), location: 0.07),
                        .init(color: .clear, location: 0.24),
                        .init(color: .clear, location: 0.74),
                        .init(color: pageBackground.opacity(0.78), location: 0.93),
                        .init(color: pageBackground, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .frame(height: 350)
            .clipped()
            .padding(.bottom, 84)
        }
        .frame(maxWidth: .infinity)
        .background(pageBackground)
    }

    private var readyPackageEntries: [ReadyPackageItem] {
        (storefront.flightBoard?.options ?? [])
            .compactMap { option in
                guard let preview = storefront.packagePreview(for: option) else { return nil }
                return ReadyPackageItem(option: option, preview: preview)
            }
            .prefix(12)
            .map { $0 }
    }

    private var readyPackagesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            IumrahHomeSectionHeader(title: readyPackagesTitle, subtitle: readyPackagesSubtitle)

            if readyPackageEntries.isEmpty {
                HStack(spacing: 11) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(readyPackagesLoadingTitle)
                            .font(.headline)
                        Text(readyPackagesLoadingBody)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .iumrahCard()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 13) {
                        ForEach(readyPackageEntries) { entry in
                            HomeStorefrontFlightOptionCard(
                                option: entry.option,
                                packagePreview: entry.preview,
                                isCalculating: storefront.isLoading,
                                language: settings.language,
                                onOpen: { selectedFlightPackage = entry.preview }
                            )
                            .frame(width: 318)

                        }

                        allPackagesCard
                            .frame(width: 318)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollClipDisabled()
            }
        }
    }

    private var allPackagesCard: some View {
        Button {
            chrome.openHotels(board: .flights)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image("IumrahFlightsShowcaseHero")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 118)
                    .clipped()

                VStack(alignment: .leading, spacing: 13) {
                    Label("Iumrah Flights", systemImage: "airplane")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.52))

                    Text(allPackagesTitle)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .tracking(-0.45)
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(allPackagesBody)
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(allPackagesCTA)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .frame(height: 45)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.055), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.05), radius: 16, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var buildMyUmrahSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            IumrahHomeSectionHeader(title: buildUmrahSectionTitle, subtitle: buildUmrahSectionSubtitle)

            GeometryReader { proxy in
                let cardWidth = max(298, min(proxy.size.width * 0.94, 352))
                let cardHeight: CGFloat = 540

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        hero
                            .frame(width: cardWidth, height: cardHeight, alignment: .top)
                        careRequestBuilderCard
                            .frame(width: cardWidth, height: cardHeight, alignment: .top)
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 1)
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .scrollClipDisabled()
            }
            .frame(height: 554)
        }
        .padding(.bottom, 6)
    }

    private var careRequestBuilderCard: some View {
        Button {
            IumrahHaptics.soft()
            showCareRequestBuilder = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Color.black
                    Image("IumrahCareShowcaseCard")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .frame(height: 220)
                .clipped()

                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Label("Iumrah Care", systemImage: "heart.fill")
                            .font(.caption.weight(.bold))
                            .tracking(0.45)
                            .foregroundStyle(Color.black.opacity(0.58))
                        Spacer(minLength: 8)
                        Text(careRequestTimeBadge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.62))
                            .padding(.horizontal, 10)
                            .frame(height: 29)
                            .background(Color.black.opacity(0.055), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(careRequestCardTitle)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .tracking(-0.75)
                            .foregroundStyle(.black)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(careRequestCardBody)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.62))
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 16)

                    HStack(spacing: 10) {
                        Text(careRequestCardCTA)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.055), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.09), radius: 24, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var readyPackagesTitle: String {
        switch settings.language {
        case .russian: return "Готовые пакеты"
        case .english: return "Ready-made packages"
        case .uzbek: return "Tayyor paketlar"
        case .uzbekCyrillic: return "Тайёр пакетлар"
        }
    }

    private var readyPackagesSubtitle: String {
        switch settings.language {
        case .russian: return "Актуальные варианты перелёта уже собраны с отелем и сервисами в единую цену пакета."
        case .english: return "Current flight options are already combined with hotel and services into one package price."
        case .uzbek: return "Amaldagi parvoz variantlari mehmonxona va servislar bilan bitta paket narxiga yig‘ilgan."
        case .uzbekCyrillic: return "Амалдаги парвоз вариантлари меҳмонхона ва сервислар билан битта пакет нархига йиғилган."
        }
    }

    private var readyPackagesLoadingTitle: String {
        switch settings.language {
        case .russian: return "Подбираем актуальные пакеты"
        case .english: return "Loading current packages"
        case .uzbek: return "Amaldagi paketlar yuklanmoqda"
        case .uzbekCyrillic: return "Амалдаги пакетлар юкланмоқда"
        }
    }

    private var readyPackagesLoadingBody: String {
        switch settings.language {
        case .russian: return "Цены и рейсы обновляются из витрины Iumrah."
        case .english: return "Prices and flights are refreshing from the Iumrah storefront."
        case .uzbek: return "Narxlar va parvozlar Iumrah vitrinasidan yangilanmoqda."
        case .uzbekCyrillic: return "Нархлар ва парвозлар Iumrah витринасидан янгиланмоқда."
        }
    }

    private var allPackagesTitle: String {
        switch settings.language {
        case .russian: return "Больше вариантов поездки"
        case .english: return "More journey options"
        case .uzbek: return "Ko‘proq safar variantlari"
        case .uzbekCyrillic: return "Кўпроқ сафар вариантлари"
        }
    }

    private var allPackagesBody: String {
        switch settings.language {
        case .russian: return "Откройте полную витрину авиабилетов и готовых пакетов Iumrah."
        case .english: return "Open the complete Iumrah flights and ready-package storefront."
        case .uzbek: return "Iumrah parvozlari va tayyor paketlarining to‘liq vitrinasini oching."
        case .uzbekCyrillic: return "Iumrah парвозлари ва тайёр пакетларининг тўлиқ витринасини очинг."
        }
    }

    private var allPackagesCTA: String {
        switch settings.language {
        case .russian: return "Посмотреть все пакеты"
        case .english: return "View all packages"
        case .uzbek: return "Barcha paketlarni ko‘rish"
        case .uzbekCyrillic: return "Барча пакетларни кўриш"
        }
    }

    private var buildUmrahSectionTitle: String {
        switch settings.language {
        case .russian: return "Собрать свою Умру"
        case .english: return "Build your Umrah"
        case .uzbek: return "Umrangizni tuzing"
        case .uzbekCyrillic: return "Умрангизни тузинг"
        }
    }

    private var buildUmrahSectionSubtitle: String {
        switch settings.language {
        case .russian: return "Соберите пакет сами за несколько минут или передайте подбор Iumrah Care."
        case .english: return "Build the package yourself in minutes or let Iumrah Care prepare it for you."
        case .uzbek: return "Paketni bir necha daqiqada o‘zingiz tuzing yoki tanlovni Iumrah Care’ga topshiring."
        case .uzbekCyrillic: return "Пакетни бир неча дақиқада ўзингиз тузинг ёки танловни Iumrah Care’га топширинг."
        }
    }

    private var careRequestTimeBadge: String {
        switch settings.language {
        case .russian: return "ответ ≤ 2 ч"
        case .english: return "reply ≤ 2h"
        case .uzbek: return "javob ≤ 2 soat"
        case .uzbekCyrillic: return "жавоб ≤ 2 соат"
        }
    }

    private var careRequestCardTitle: String {
        switch settings.language {
        case .russian: return "Собрать Умру за меня"
        case .english: return "Build my Umrah for me"
        case .uzbek: return "Umramni men uchun tuzing"
        case .uzbekCyrillic: return "Умрамни мен учун тузинг"
        }
    }

    private var careRequestCardBody: String {
        switch settings.language {
        case .russian: return "Укажите месяц или точные даты, бюджет, уровень отеля и главный приоритет. Iumrah Care соберёт персональный вариант."
        case .english: return "Choose a month or exact dates, budget, hotel level and your main priority. Iumrah Care will prepare a personal option."
        case .uzbek: return "Oy yoki aniq sanalar, budjet, mehmonxona darajasi va asosiy ustuvorlikni belgilang. Iumrah Care shaxsiy variant tayyorlaydi."
        case .uzbekCyrillic: return "Ой ёки аниқ саналар, бюджет, меҳмонхона даражаси ва асосий устуворликни белгиланг. Iumrah Care шахсий вариант тайёрлайди."
        }
    }

    private var careRequestCardCTA: String {
        switch settings.language {
        case .russian: return "Рассказать о поездке"
        case .english: return "Tell us about the trip"
        case .uzbek: return "Safar haqida aytish"
        case .uzbekCyrillic: return "Сафар ҳақида айтиш"
        }
    }

    private var homeProductsTitle: String {
        switch settings.language {
        case .russian: return "Наши продукты"
        case .english: return "Our products"
        case .uzbek: return "Mahsulotlarimiz"
        case .uzbekCyrillic: return "Маҳсулотларимиз"
        }
    }

    private var hero: some View {
        Button {
            IumrahHaptics.soft()
            chrome.startNewTrip()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Color.black

                    Image("IumrahConfiguratorHero")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()

                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Label("Iumrah Configurator", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.bold))
                            .tracking(0.45)
                            .foregroundStyle(Color.white.opacity(0.78))
                        Spacer(minLength: 8)
                        Text(configuratorTimeBadge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .padding(.horizontal, 10)
                            .frame(height: 29)
                            .background(Color.white.opacity(0.10), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(configuratorHeroTitle)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .tracking(-0.75)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(configuratorHeroBody)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.68))
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 16)

                    HStack(spacing: 10) {
                        Text(configuratorHeroCTA)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.black)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.14), radius: 24, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuratorHeroTitle)
    }

    private var configuratorTimeBadge: String {
        switch settings.language {
        case .russian: return "≈ 5 минут"
        case .english: return "≈ 5 min"
        case .uzbek: return "≈ 5 daqiqa"
        case .uzbekCyrillic: return "≈ 5 дақиқа"
        }
    }

    private var configuratorHeroTitle: String {
        switch settings.language {
        case .russian: return "Соберите свою Умру за 5 минут"
        case .english: return "Build your Umrah in 5 minutes"
        case .uzbek: return "Umrangizni 5 daqiqada tuzing"
        case .uzbekCyrillic: return "Умрангизни 5 дақиқада тузинг"
        }
    }

    private var configuratorHeroBody: String {
        switch settings.language {
        case .russian: return "Персональный пакет для вас, вашей семьи или друзей — без обязательной туристической группы из 30–50 человек. Перелёт, отель, трансфер и Iumrah Services собираются в одну поездку."
        case .english: return "A personal package for you, your family or friends — without having to join a 30–50 person tour group. Flights, hotel, transfer and Iumrah Services come together as one journey."
        case .uzbek: return "Siz, oilangiz yoki do‘stlaringiz uchun shaxsiy paket — 30–50 kishilik majburiy tur guruhisiz. Parvoz, mehmonxona, transfer va Iumrah Services bitta safarga birlashadi."
        case .uzbekCyrillic: return "Сиз, оилангиз ёки дўстларингиз учун шахсий пакет — 30–50 кишилик мажбурий тур гуруҳисиз. Парвоз, меҳмонхона, трансфер ва Iumrah Services битта сафарга бирлашади."
        }
    }

    private var configuratorHeroCTA: String {
        switch settings.language {
        case .russian: return "Создать мою Умру"
        case .english: return "Create my Umrah"
        case .uzbek: return "Umramni yaratish"
        case .uzbekCyrillic: return "Умрамни яратиш"
        }
    }

    private var friendsHomeCard: some View {
        NavigationLink {
            IumrahGiftCardsView()
        } label: {
            HStack(spacing: 16) {
                IumrahIconBadge(systemName: "gift.fill", role: .gift, size: 82, symbolSize: 25, cornerRadius: 22)
                .overlay(alignment: .topTrailing) {
                    Text("3")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 26, height: 26)
                        .background(.white, in: Circle())
                        .offset(x: 5, y: -5)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text("iumrah Gift Card")
                            .font(.headline)
                        Text("3 × $100")
                            .font(.caption2.monospaced().weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(friendsHomeSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahCard()
        }
        .buttonStyle(.plain)
    }

    private var friendsHomeSubtitle: String {
        switch settings.language {
        case .russian: return "Подарочные карты для близких · $100 на умру и $100 в iUmrah Balance после подтверждения и оплаты."
        case .english: return "Gift cards for someone close · $100 toward Umrah and $100 in iUmrah Balance after confirmation and payment."
        case .uzbek: return "Yaqinlar uchun Gift Card · Umrah uchun $100 va tasdiqlanib to‘langach $100 iUmrah Balance."
        case .uzbekCyrillic: return "Яқинлар учун Gift Card · Умра учун $100 ва тасдиқланиб тўлангач $100 iUmrah Balance."
        }
    }

    private var confidenceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(icon: "building.2.fill", text: L10n.text("tab_hotels", settings.language))
                chip(icon: "airplane", text: L10n.text("step_flight", settings.language))
                chip(icon: "heart.fill", text: "iumrah Care")
            }
        }
    }

    private func chip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color.iumrahCardBackground)
            .clipShape(Capsule())
            .overlay { Capsule().strokeBorder(Color.primary.opacity(0.05), lineWidth: 1) }
    }

    private var philosophyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iumrah")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Capsule())
            Text(L10n.text("home_philosophy_title", settings.language))
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(L10n.text("home_philosophy_body", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private var connectedTripCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                journeyIcon("airplane")
                connector
                journeyIcon("building.2.fill")
                connector
                journeyIcon("car.fill")
                connector
                journeyIcon("moon.stars.fill")
                connector
                journeyIcon("heart.fill")
            }

            Text(L10n.text("home_connected_title", settings.language))
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text(L10n.text("home_connected_body", settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private var esimHomeCard: some View {
        Button { chrome.presentESIM() } label: {
            homeFeatureCard(
                imageName: "IumrahESIMHomeCard",
                title: "iumrah eSIM",
                body: homeESIMFeatureBody,
                ctaTitle: homeESIMCopy(.details),
                ctaIcon: "antenna.radiowaves.left.and.right",
                ctaRole: .connectivity,
                statusText: homeESIMStatusLine,
                accent: Color(uiColor: .systemTeal)
            )
        }
        .buttonStyle(.plain)
    }

    private enum HomeESIMCopyKey { case left, ready, assigned, activate, open, packageOnly, details }

    private func homeESIMCopy(_ key: HomeESIMCopyKey) -> String {
        switch (settings.language, key) {
        case (.russian, .left): return "осталось"
        case (.russian, .ready): return "Профиль готов. Активируйте eSIM на iPhone."
        case (.russian, .assigned): return "eSIM привязана к вашей поездке."
        case (.russian, .activate): return "Активировать eSIM"
        case (.russian, .open): return "Открыть eSIM"
        case (.russian, .packageOnly): return "В1 версии eSIM доступна только внутри Umra-пакета."
        case (.russian, .details): return "Тарифы и активация"
        case (.english, .left): return "left"
        case (.english, .ready): return "Profile ready. Activate the eSIM on your iPhone."
        case (.english, .assigned): return "eSIM is linked to your trip."
        case (.english, .activate): return "Activate eSIM"
        case (.english, .open): return "Open eSIM"
        case (.english, .packageOnly): return "In V1, eSIM is available only as part of the Umrah package."
        case (.english, .details): return "Plans & activation"
        case (.uzbek, .left): return "qoldi"
        case (.uzbek, .ready): return "Profil tayyor. eSIM’ni iPhone’da faollashtiring."
        case (.uzbek, .assigned): return "eSIM safaringizga biriktirilgan."
        case (.uzbek, .activate): return "eSIM’ni faollashtirish"
        case (.uzbek, .open): return "eSIM’ni ochish"
        case (.uzbek, .packageOnly): return "V1’da eSIM faqat Umra paketi tarkibida mavjud."
        case (.uzbek, .details): return "Tariflar va faollashtirish"
        case (.uzbekCyrillic, .left): return "қолди"
        case (.uzbekCyrillic, .ready): return "Профиль тайёр. eSIM’ни iPhone’да фаоллаштиринг."
        case (.uzbekCyrillic, .assigned): return "eSIM сафарингизга бириктирилган."
        case (.uzbekCyrillic, .activate): return "eSIM’ни фаоллаштириш"
        case (.uzbekCyrillic, .open): return "eSIM’ни очиш"
        case (.uzbekCyrillic, .packageOnly): return "V1’да eSIM фақат Umra пакети таркибида мавжуд."
        case (.uzbekCyrillic, .details): return "Тарифлар ва фаоллаштириш"
        }
    }

    private var homeESIMFeatureBody: String {
        if let session = activeSession, let profile = bookings.primaryESIM(for: session.id) {
            return profile.hasActivationData ? homeESIMCopy(.ready) : homeESIMCopy(.assigned)
        }
        return homeESIMCopy(.packageOnly)
    }

    private var homeESIMStatusLine: String? {
        guard let session = activeSession, let profile = bookings.primaryESIM(for: session.id) else { return nil }
        if profile.usageAvailable {
            return "\(homeDataText(profile.remainingMB)) \(homeESIMCopy(.left))"
        }
        return profile.hasActivationData ? homeESIMCopy(.activate) : homeESIMCopy(.open)
    }

    private func homeDataText(_ value: Double) -> String {
        if value >= 1024 {
            return String(format: "%.1f GB", value / 1024)
        }
        return "\(Int(max(0, value).rounded())) MB"
    }

    private func journeyIcon(_ name: String) -> some View {
        IumrahIconBadge(systemName: name, size: 34, symbolSize: 13, shape: .circle)
    }

    private var connector: some View {
        Capsule()
            .fill(Color.primary.opacity(0.10))
            .frame(maxWidth: .infinity)
            .frame(height: 2)
    }

    private var flightsHomeCard: some View {
        NavigationLink {
            IumrahFlightsView()
        } label: {
            homeFeatureCard(
                imageName: "IumrahFlightsHomeCard",
                title: "iumrah Flights",
                body: homeFlightsFeatureBody,
                ctaTitle: homeFlightsCTA,
                ctaIcon: "airplane",
                ctaRole: .travel,
                statusText: nil,
                accent: Color(uiColor: .systemBlue)
            )
        }
        .buttonStyle(.plain)
    }

    private var careShowcaseCard: some View {
        Button {
            chrome.navigate(to: .care)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image("IumrahCareShowcaseCard")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.015, green: 0.035, blue: 0.09))

                VStack(alignment: .leading, spacing: 12) {
                    Text("iumrah Care")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .tracking(-0.55)
                    Text(L10n.text("hotel_care_card_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 9) {
                        Image(systemName: "phone.fill")
                        Text(homeCareCTA)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(Color.iumrahPrimaryButtonText)
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
        .buttonStyle(.plain)
    }

    private var homeAboutFooter: some View {
        Button {
            IumrahHaptics.soft()
            showAboutProject = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    IumrahIconBadge(systemName: "sparkles.rectangle.stack.fill", role: .care, size: 46, symbolSize: 18, cornerRadius: 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(homeSinceTitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        Text(homeSinceBody)
                            .font(.system(size: 14.5, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Text(homeAboutCTA)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.iumrahPrimaryButtonText)
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Color.iumrahPrimaryButtonBackground,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private func productsCarousel(contentWidth: CGFloat) -> some View {
        let cardWidth = min(max(contentWidth * 0.88, 300), contentWidth)
        let cardHeight: CGFloat = 472
        let cardShape = RoundedRectangle(cornerRadius: 34, style: .continuous)

        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                IumrahBackendSystemHomeCard()
                    .frame(width: cardWidth, height: cardHeight, alignment: .top)
                    .clipShape(cardShape)
                    .contentShape(cardShape)
                    .id("iumrah-system")

                homeAdvisorProductCard
                    .frame(width: cardWidth, height: cardHeight, alignment: .top)
                    .clipShape(cardShape)
                    .contentShape(cardShape)
                    .id("iumrah-advisor")
            }
            .scrollTargetLayout()
            .padding(.horizontal, 1)
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .frame(height: cardHeight)
    }

    private var homeAdvisorProductCard: some View {
        NavigationLink {
            UmrahFlowRootView(
                initialStage: .start,
                guideLanguage: UmrahGuideLanguage.preferred(for: settings.language)
            )
        } label: {
            ZStack {
                // The living Advisor aura now fills the ENTIRE product card.
                // There is no static black lower half: the gradient keeps moving
                // underneath the title, body and CTA as one continuous surface.
                UmrahAdvisorHomeAura()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.04),
                        Color.black.opacity(0.10),
                        Color.black.opacity(0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.badge.mic")
                                .font(.system(size: 13, weight: .bold))
                            Text("iumrah Advisor")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .tracking(0.45)
                        }
                        .foregroundStyle(.white.opacity(0.92))

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(width: 38, height: 38)
                            .iumrahGlass(in: Circle(), tint: .white.opacity(0.09))
                    }

                    Spacer(minLength: 24)

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.075))
                            .frame(width: 106, height: 106)
                            .blur(radius: 1)

                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            .frame(width: 106, height: 106)

                        Image(systemName: "waveform")
                            .font(.system(size: 42, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 24)

                    VStack(alignment: .leading, spacing: 9) {
                        Text(homeAdvisorProductTitle)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(-0.65)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(homeAdvisorProductBody)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Text(homeAdvisorProductCTA)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 17)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .padding(.top, 5)
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded { IumrahHaptics.soft() }
        )
    }

    private func homeFeatureCard(
        imageName: String,
        title: String,
        body: String,
        ctaTitle: String,
        ctaIcon: String,
        ctaRole: IumrahIconRole,
        statusText: String?,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 214)
                .clipped()
                .background(Color(red: 0.015, green: 0.035, blue: 0.09))

            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)

                Text(body)
                    .font(.system(size: 15.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(accent.opacity(0.10), in: Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                HStack(spacing: 10) {
                    Image(systemName: ctaIcon)
                        .symbolRenderingMode(.monochrome)
                    Text(ctaTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.iumrahPrimaryButtonText)
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Color.iumrahPrimaryButtonBackground,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .padding(22)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }

    private var homeFlightsFeatureBody: String {
        switch settings.language {
        case .russian:
            return "Опубликованные рейсы Umrah, подбор направления и перелёта под ваш пакет в одном месте."
        case .english:
            return "Published Umrah flights and route selection for your package in one place."
        case .uzbek:
            return "Umra uchun e’lon qilingan reyslar va paketingizga mos parvozni bitta joyda tanlash."
        case .uzbekCyrillic:
            return "Умра учун эълон қилинган рейслар ва пакетингизга мос парвозни битта жойда танлаш."
        }
    }

    private var homeFlightsCTA: String {
        switch settings.language {
        case .russian: return "Подобрать перелёт"
        case .english: return "Choose flights"
        case .uzbek: return "Parvozni tanlash"
        case .uzbekCyrillic: return "Парвозни танлаш"
        }
    }

    private var homeCareCTA: String {
        switch settings.language {
        case .russian: return "Связаться с Care"
        case .english: return "Contact Care"
        case .uzbek: return "Care bilan bog‘lanish"
        case .uzbekCyrillic: return "Care билан боғланиш"
        }
    }

    private var homeAdvisorProductTitle: String {
        switch settings.language {
        case .russian: return "Голосовой iumrah Advisor"
        case .english: return "Voice iumrah Advisor"
        case .uzbek: return "Ovozli iumrah Advisor"
        case .uzbekCyrillic: return "Овозли iumrah Advisor"
        }
    }

    private var homeAdvisorProductBody: String {
        switch settings.language {
        case .russian: return "Пошаговый голосовой гид по Умре с поддержкой нескольких языков, чтобы паломник не оставался один во время ритуалов."
        case .english: return "A step-by-step voice guide for Umrah in multiple languages, so the pilgrim is not left alone during the rituals."
        case .uzbek: return "Umra marosimlari davomida ziyoratchi yolg‘iz qolmasligi uchun bir nechta tillarda bosqichma-bosqich ovozli gid."
        case .uzbekCyrillic: return "Умра маросимлари давомида зиёратчи ёлғиз қолмаслиги учун бир нечта тилларда босқичма-босқич овозли гид."
        }
    }

    private var homeAdvisorProductCTA: String {
        switch settings.language {
        case .russian: return "Открыть Advisor"
        case .english: return "Open Advisor"
        case .uzbek: return "Advisorni ochish"
        case .uzbekCyrillic: return "Advisorни очиш"
        }
    }

    private var homeAboutCTA: String {
        switch settings.language {
        case .russian: return "Открыть страницу проекта"
        case .english: return "Open the project page"
        case .uzbek: return "Loyiha sahifasini ochish"
        case .uzbekCyrillic: return "Лойиҳа саҳифасини очиш"
        }
    }

    private var homeSinceTitle: String {
        switch settings.language {
        case .russian: return "Since 2026"
        case .english: return "Since 2026"
        case .uzbek: return "Since 2026"
        case .uzbekCyrillic: return "Since 2026"
        }
    }

    private var homeSinceBody: String {
        switch settings.language {
        case .russian:
            return "iumrah — проект персональной и независимой Умры: собрать маршрут, отель, трансфер и сопровождение в одном спокойном приложении."
        case .english:
            return "iumrah is a personal independent Umrah project: build your route, hotel, transfer and care in one calm application."
        case .uzbek:
            return "iumrah — shaxsiy va mustaqil Umra loyihasi: yo‘nalish, mehmonxona, transfer va yordamni bitta sokin ilovada jamlash uchun yaratilgan."
        case .uzbekCyrillic:
            return "iumrah — шахсий ва мустақил Умра лойиҳаси: йўналиш, меҳмонхона, трансфер ва ёрдамни битта сокин иловада жамлаш учун яратилган."
        }
    }

    private var personalUmrahFAQ: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("iumrah")
                    .font(.caption.weight(.bold))
                    .tracking(0.9)
                    .foregroundStyle(.secondary)

                Text(personalUmrahFAQTitle)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.6)

                Text(personalUmrahFAQSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(Array(homeFAQItems.enumerated()), id: \.element.id) { index, item in
                    Button {
                        IumrahHaptics.selection()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                            expandedHomeFAQID = expandedHomeFAQID == item.id ? nil : item.id
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .center, spacing: 12) {
                                Text(item.question)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(.degrees(expandedHomeFAQID == item.id ? 180 : 0))
                            }
                            .padding(.vertical, 16)

                            if expandedHomeFAQID == item.id {
                                Text(item.answer)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.bottom, 17)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < homeFAQItems.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 18)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 0)
    }

    private var personalUmrahFAQTitle: String {
        switch settings.language {
        case .russian: return "Персональная Умра — для вас и ваших близких"
        case .english: return "A personal Umrah — for you and the people you choose"
        case .uzbek: return "Shaxsiy Umra — siz va yaqinlaringiz uchun"
        case .uzbekCyrillic: return "Шахсий Умра — сиз ва яқинларингиз учун"
        }
    }

    private var personalUmrahFAQSubtitle: String {
        switch settings.language {
        case .russian: return "iumrah не привязывает вас к стандартной группе. Соберите поездку для себя, семьи или друзей и управляйте ею как одной персональной Umrah."
        case .english: return "iumrah does not tie you to a standard tour group. Build one personal Umrah for yourself, your family or friends and manage the journey in one place."
        case .uzbek: return "iumrah sizni standart tur guruhiga bog‘lamaydi. O‘zingiz, oilangiz yoki do‘stlaringiz uchun shaxsiy Umra tuzing va safarni bitta joydan boshqaring."
        case .uzbekCyrillic: return "iumrah сизни стандарт тур гуруҳига боғламайди. Ўзингиз, оилангиз ёки дўстларингиз учун шахсий Умра тузинг ва сафарни битта жойдан бошқаринг."
        }
    }

    private var homeFAQItems: [HomeFAQItem] {
        switch settings.language {
        case .russian:
            return [
                HomeFAQItem(id: "what", question: "Что такое iumrah?", answer: "iumrah — платформа для самостоятельной и персональной Умры. Она помогает собрать перелёт, отель, трансфер и сервисы в один понятный пакет и затем вести поездку в одном приложении."),
                HomeFAQItem(id: "why", question: "Почему был создан iumrah?", answer: "Чтобы паломнику не приходилось зависеть от большой туристической группы или разбираться в десятках разрозненных бронирований. Идея iumrah — дать больше контроля, прозрачности и заботы на каждом этапе поездки."),
                HomeFAQItem(id: "personal", question: "Что значит «персональная Умра»?", answer: "Поездка собирается вокруг вас: ваших дат, бюджета, уровня отеля и выбранных услуг. Это не обязательная группа из 30–50 незнакомых людей — вы сами выбираете, с кем совершать Умру."),
                HomeFAQItem(id: "family", question: "Можно поехать только с семьёй или друзьями?", answer: "Да. Пакет можно собрать для одного человека, пары, семьи или друзей. В поездке остаются только те люди, которых вы сами добавили."),
                HomeFAQItem(id: "care", question: "А если я не хочу собирать всё самостоятельно?", answer: "Обратитесь в iumrah Care. Мы поможем подобрать вариант, проверить детали и оформить поездку, сохранив персональный формат без обязательной большой группы.")
            ]
        case .english:
            return [
                HomeFAQItem(id: "what", question: "What is iumrah?", answer: "iumrah is a platform for independent, personal Umrah. It brings flights, hotel, transfer and services into one clear package and then keeps the journey in one app."),
                HomeFAQItem(id: "why", question: "Why was iumrah created?", answer: "So a pilgrim does not have to depend on a large tour group or manage many disconnected bookings. iumrah is built around more control, transparency and care throughout the journey."),
                HomeFAQItem(id: "personal", question: "What does ‘personal Umrah’ mean?", answer: "The journey is built around your dates, budget, hotel level and chosen services. There is no required group of 30–50 strangers — you decide who travels with you."),
                HomeFAQItem(id: "family", question: "Can I travel only with family or friends?", answer: "Yes. Build a package for one person, a couple, family or friends. Your journey contains only the people you choose to add."),
                HomeFAQItem(id: "care", question: "What if I do not want to build everything myself?", answer: "Contact iumrah Care. We can help select, verify and arrange the trip while keeping the personal format without a required large group.")
            ]
        case .uzbek:
            return [
                HomeFAQItem(id: "what", question: "iumrah nima?", answer: "iumrah — mustaqil va shaxsiy Umra uchun platforma. U parvoz, mehmonxona, transfer va xizmatlarni bitta tushunarli paketga birlashtiradi va safarni bitta ilovada boshqarishga yordam beradi."),
                HomeFAQItem(id: "why", question: "iumrah nima uchun yaratildi?", answer: "Ziyoratchi katta tur guruhiga bog‘lanib qolmasligi va ko‘plab alohida bronlarni boshqarmasligi uchun. iumrah safar davomida ko‘proq nazorat, shaffoflik va g‘amxo‘rlik berish uchun yaratilgan."),
                HomeFAQItem(id: "personal", question: "«Shaxsiy Umra» nimani anglatadi?", answer: "Safar sizning sanalaringiz, budjetingiz, mehmonxona darajasi va tanlagan xizmatlaringiz asosida tuziladi. 30–50 nafar notanish kishilik majburiy guruh yo‘q — kim bilan borishni o‘zingiz tanlaysiz."),
                HomeFAQItem(id: "family", question: "Faqat oilam yoki do‘stlarim bilan bora olamanmi?", answer: "Ha. Paketni bir kishi, juftlik, oila yoki do‘stlar uchun tuzish mumkin. Safarda faqat o‘zingiz qo‘shgan insonlar bo‘ladi."),
                HomeFAQItem(id: "care", question: "Hammasini o‘zim tuzishni istamasam-chi?", answer: "iumrah Care’ga murojaat qiling. Biz variant tanlash, tafsilotlarni tekshirish va safarni rasmiylashtirishga yordam beramiz — majburiy katta guruhsiz.")
            ]
        case .uzbekCyrillic:
            return [
                HomeFAQItem(id: "what", question: "iumrah нима?", answer: "iumrah — мустақил ва шахсий Умра учун платформа. У парвоз, меҳмонхона, трансфер ва хизматларни битта тушунарли пакетга бирлаштиради ва сафарни битта иловада бошқаришга ёрдам беради."),
                HomeFAQItem(id: "why", question: "iumrah нима учун яратилди?", answer: "Зиёратчи катта тур гуруҳига боғланиб қолмаслиги ва кўплаб алоҳида бронларни бошқармаслиги учун. iumrah сафар давомида кўпроқ назорат, шаффофлик ва ғамхўрлик бериш учун яратилган."),
                HomeFAQItem(id: "personal", question: "«Шахсий Умра» нимани англатади?", answer: "Сафар сизнинг саналарингиз, бюджетингиз, меҳмонхона даражаси ва танлаган хизматларингиз асосида тузилади. 30–50 нафар нотаниш кишилик мажбурий гуруҳ йўқ — ким билан боришни ўзингиз танлайсиз."),
                HomeFAQItem(id: "family", question: "Фақат оилам ёки дўстларим билан бора оламанми?", answer: "Ҳа. Пакетни бир киши, жуфтлик, оила ёки дўстлар учун тузиш мумкин. Сафарда фақат ўзингиз қўшган инсонлар бўлади."),
                HomeFAQItem(id: "care", question: "Ҳаммасини ўзим тузишни истамасам-чи?", answer: "iumrah Care’га мурожаат қилинг. Биз вариант танлаш, тафсилотларни текшириш ва сафарни расмийлаштиришга ёрдам берамиз — мажбурий катта гуруҳсиз.")
            ]
        }
    }

    private func money(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount.rounded()))"
    }
}

private struct HomeFAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String
}
