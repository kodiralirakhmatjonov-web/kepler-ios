import SwiftUI
import MapKit
import UIKit
import ImageIO

// MARK: - iumrah Ziyarats
//
// Map-first experience tuned to the interaction model of Apple's Find My:
// a single floating Liquid Glass surface above MapKit, three snap positions,
// one persistent tab row, and no nested sheets or duplicated glass layers.
// Liquid Glass itself is always rendered by the iOS 26 API; only the panel's
// geometry/gesture is custom so the compact state can match Find My precisely.

private enum ZiyaratJourneyCity: String, CaseIterable, Identifiable {
    case madinah = "Madinah"
    case makkah = "Makkah"

    var id: String { rawValue }
}

struct ZiyaratJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore

    @State private var route = ZiyaratSeedData.medina
    @State private var selectedCity: ZiyaratJourneyCity = .madinah
    @State private var routeRequestID = UUID()
    @State private var selectedPlace: ZiyaratPlace?
    @State private var activeTab: ZiyaratPanelTab = .journey

    @State private var camera: MapCameraPosition = .region(Self.region(for: ZiyaratSeedData.medina.places))
    @State private var polylines: [MKPolyline] = []
    @State private var loadingCatalog = true
    @State private var loadingRoute = false

    @State private var mapMode: ZiyaratMapMode = .standard
    @State private var showRouteLine = true
    @State private var showPlacePins = true

    @State private var welcomeVisible = true
    @State private var welcomeCopyVisible = false
    @State private var revealedStopCount = 0

    @State private var panelLevel: ZiyaratPanelLevel = .compact
    @State private var panelDragY: CGFloat = 0
    @State private var closing = false

    private var orderedPlaces: [ZiyaratPlace] {
        route.places
            .filter(Self.hasUsableCoordinate)
            .sorted { $0.routeOrder < $1.routeOrder }
    }

    private var isCompactPanel: Bool { panelLevel == .compact }
    private var isExpandedPanel: Bool { panelLevel == .full }

    var body: some View {
        GeometryReader { proxy in
            let metrics = ZiyaratPanelMetrics(containerHeight: proxy.size.height)

            ZStack(alignment: .bottom) {
                mapScene
                    .ignoresSafeArea()

                mapChrome

                if orderedPlaces.isEmpty && !loadingCatalog {
                    emptyOverlay
                        .padding(.horizontal, 24)
                        .zIndex(5)
                }

                findMyPanel(metrics: metrics)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .opacity(welcomeVisible ? 0 : 1)
                    .allowsHitTesting(!welcomeVisible)
                    .zIndex(12)

                if welcomeVisible {
                    ZiyaratWelcomeOverlay(
                        pretitle: welcomePretitle,
                        title: "iumrah Ziyarats",
                        city: cityTitle,
                        copyVisible: welcomeCopyVisible
                    )
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .zIndex(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("iumrah Ziyarats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            chrome.setImmersive(true)
        }
        .onDisappear {
            if !closing { chrome.setImmersive(false) }
        }
        .task {
            await loadJourney()
            await playWelcomeSequence()
        }
        .onChange(of: panelLevel) { _, _ in
            guard let selectedPlace else { return }
            focus(on: selectedPlace, animated: true)
        }
    }

    // MARK: Map

    @ViewBuilder
    private var mapScene: some View {
        switch mapMode {
        case .standard:
            mapContent
                .mapStyle(.standard(
                    elevation: .realistic,
                    emphasis: .muted,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                ))
        case .satellite:
            mapContent
                .mapStyle(.imagery(elevation: .realistic))
        }
    }

    private var mapContent: some View {
        Map(position: $camera) {
            if showRouteLine {
                ForEach(Array(polylines.enumerated()), id: \.offset) { _, polyline in
                    MapPolyline(polyline)
                        .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    MapPolyline(polyline)
                        .stroke(Color(uiColor: .systemBlue), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                }
            }

            if showPlacePins {
                ForEach(Array(orderedPlaces.enumerated()), id: \.offset) { index, place in
                    Annotation(
                        place.localizedContent(locale: settings.language.rawValue).title,
                        coordinate: place.coordinate,
                        anchor: .bottom
                    ) {
                        Button {
                            select(place)
                        } label: {
                            ZiyaratMapPin(
                                number: place.routeOrder,
                                title: place.localizedContent(locale: settings.language.rawValue).title,
                                isSelected: selectedPlace?.id == place.id
                            )
                            .opacity(!welcomeVisible || index < revealedStopCount ? 1 : 0)
                            .scaleEffect(!welcomeVisible || index < revealedStopCount ? 1 : 0.76)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(place.localizedContent(locale: settings.language.rawValue).title)
                    }
                }
            }
        }
    }

    private var mapChrome: some View {
        VStack(spacing: 0) {
            Group {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 12) {
                        mapChromeTopRow
                    }
                } else {
                    mapChromeTopRow
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(isExpandedPanel ? 0 : 1)
        .allowsHitTesting(!isExpandedPanel && !welcomeVisible)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isExpandedPanel)
        .zIndex(10)
    }

    private var mapChromeTopRow: some View {
        HStack(alignment: .top) {
            ZiyaratNativeCitySwitcher(
                selectedCity: selectedCity,
                madinahTitle: medinaSwitchTitle,
                makkahTitle: makkahSwitchTitle,
                onSelect: changeCity
            )

            Spacer(minLength: 8)

            ZiyaratNativeMapControlGroup(
                primarySystemName: mapMode == .standard ? "map.fill" : "globe.americas.fill",
                primaryForeground: activeTab == .map ? Color(uiColor: .systemBlue) : nil,
                primaryAccessibilityLabel: mapModeLabel,
                primaryAction: {
                    selectedPlace = nil
                    activeTab = .map
                    setPanel(.card)
                },
                secondarySystemName: "location.viewfinder",
                secondaryAccessibilityLabel: fitRouteLabel,
                secondaryAction: {
                    fitEntireRoute(animated: true)
                }
            )
        }
    }

    @ViewBuilder
    private var nativePanelSheet: some View {
        if #available(iOS 26.0, *) {
            nativePanelContent
                .glassEffect(
                    .regular.interactive(true),
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
        } else {
            nativePanelContent
                .background(
                    Color(uiColor: .systemBackground),
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
        }
    }

    private var nativePanelContent: some View {
        VStack(spacing: 0) {
            currentPanelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            Divider()

            ZiyaratSheetNavigationBar(
                activeTab: activeTab,
                title: tabTitle,
                onSelect: activateTab
            )
            .frame(height: 70)
        }
    }

    // MARK: Find My-style Ziyarats surface

    /// One native Liquid Glass surface, exactly one tab row, and no SwiftUI sheet.
    /// STRICT: iOS 26 chrome uses only Apple Liquid Glass APIs. Never add Material, blur,
    /// translucent background overlays, manual glass strokes, or fake glass shadows here.
    /// The custom geometry is deliberate: SwiftUI's minimum sheet detent is much
    /// taller than Find My's compact surface on iPhone. The glass itself remains
    /// iOS 26's native compositor effect.
    private func findMyPanel(metrics: ZiyaratPanelMetrics) -> some View {
        let height = interactivePanelHeight(metrics: metrics)
        let contentProgress = metrics.contentProgress(for: height)

        return Group {
            if #available(iOS 26.0, *) {
                panelSurfaceContent(
                    metrics: metrics,
                    contentProgress: contentProgress
                )
                .frame(height: height)
                .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            } else {
                panelSurfaceContent(
                    metrics: metrics,
                    contentProgress: contentProgress
                )
                .frame(height: height)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
        }
        .animation(nil, value: panelDragY)
    }

    private func panelSurfaceContent(
        metrics: ZiyaratPanelMetrics,
        contentProgress: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            ZiyaratPanelGrabber()
                .gesture(panelDragGesture(metrics: metrics))

            currentPanelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(contentProgress)
                .clipped()
                .allowsHitTesting(contentProgress > 0.98 && !isCompactPanel)

            Divider()
                .opacity(contentProgress > 0.2 ? 0.26 : 0)

            ZiyaratSheetNavigationBar(
                activeTab: activeTab,
                title: tabTitle,
                onSelect: activateTab
            )
            .frame(height: metrics.navigationHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func interactivePanelHeight(metrics: ZiyaratPanelMetrics) -> CGFloat {
        let base = metrics.height(for: panelLevel)
        return metrics.rubberBanded(base - panelDragY)
    }

    private func panelDragGesture(metrics: ZiyaratPanelMetrics) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    panelDragY = value.translation.height
                }
            }
            .onEnded { value in
                let source = panelLevel
                let projected = metrics.height(for: source) - value.predictedEndTranslation.height
                let target = metrics.nearestLevel(to: projected)

                withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.08)) {
                    panelDragY = 0
                    panelLevel = target
                }
                if target != source {
                    IumrahHaptics.selection()
                }
            }
    }

    @ViewBuilder
    private var currentPanelContent: some View {
        switch activeTab {
        case .journey:
            journeyPanel
        case .places:
            placesTabContent
        case .route:
            routePanel
        case .map:
            mapPanel
        }
    }

    @ViewBuilder
    private var placesTabContent: some View {
        if let selectedPlace {
            ZiyaratPlacePanelContent(
                place: selectedPlace,
                counterTitle: stopCounterTitle(selectedPlace),
                expanded: isExpandedPanel,
                language: settings.language,
                onBack: closeSelectedPlace,
                onExpand: { setPanel(.full) },
                onOpenMaps: { openInMaps(selectedPlace) }
            )
        } else {
            placesPanel
        }
    }

    private func activateTab(_ tab: ZiyaratPanelTab) {
        IumrahHaptics.selection()

        if tab != .places {
            selectedPlace = nil
        }

        activeTab = tab

        switch tab {
        case .map:
            setPanel(.compact)
        case .route:
            fitEntireRoute(animated: true)
            if isCompactPanel { setPanel(.card) }
        case .journey, .places:
            if isCompactPanel { setPanel(.card) }
        }
    }

    private func closeSelectedPlace() {
        guard selectedPlace != nil else { return }
        IumrahHaptics.selection()
        selectedPlace = nil
        activeTab = .places
        if isExpandedPanel { setPanel(.card) }
        fitEntireRoute(animated: true)
    }

    private func stopCounterTitle(_ place: ZiyaratPlace) -> String {
        localized(
            "Остановка \(place.routeOrder) из \(max(orderedPlaces.count, 1))",
            "Stop \(place.routeOrder) of \(max(orderedPlaces.count, 1))",
            "\(place.routeOrder) / \(max(orderedPlaces.count, 1)) bekat",
            "\(place.routeOrder) / \(max(orderedPlaces.count, 1)) бекат"
        )
    }

    // MARK: Panel pages

    private var journeyPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("iumrah Ziyarats")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(routeTitle)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.5)
                        Text(routeSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                }

                HStack(spacing: 0) {
                    journeyMetric(icon: "mappin.and.ellipse", value: "\(orderedPlaces.count)", label: stopsLabel)
                    Divider().frame(height: 38)
                    journeyMetric(icon: "clock", value: timeText(route.estimatedMinutes), label: totalTimeLabel)
                    Divider().frame(height: 38)
                    journeyMetric(icon: "car.fill", value: transportLabel, label: routeLabel)
                }

                if let first = orderedPlaces.first {
                    Button { select(first) } label: {
                        ZiyaratJourneyNextStopRow(
                            place: first,
                            title: first.localizedContent(locale: settings.language.rawValue).title,
                            eyebrow: firstStopLabel,
                            durationText: durationText(first.durationMinutes)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    selectedPlace = nil
                    activeTab = .route
                    fitEntireRoute(animated: true)
                    setPanel(.card)
                } label: {
                    Label(showRouteLabel, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: true))
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
    }

    private var placesPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                panelSectionHeader(title: placesTitle, subtitle: "\(orderedPlaces.count) \(stopsLabel)")
                    .padding(.bottom, 8)

                ForEach(Array(orderedPlaces.enumerated()), id: \.offset) { index, place in
                    Button { select(place) } label: {
                        ZiyaratPlaceListRow(
                            place: place,
                            content: place.localizedContent(locale: settings.language.rawValue),
                            visitText: visitType(place.visitType),
                            durationText: durationText(place.durationMinutes)
                        )
                    }
                    .buttonStyle(.plain)

                    if index < orderedPlaces.count - 1 {
                        Divider().padding(.leading, 90)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
    }

    private var routePanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    panelSectionHeader(title: itineraryTitle, subtitle: routeSubtitle)
                    Spacer(minLength: 8)
                    if loadingRoute { ProgressView().controlSize(.small) }
                }

                VStack(spacing: 0) {
                    ForEach(Array(orderedPlaces.enumerated()), id: \.offset) { index, place in
                        Button { select(place) } label: {
                            ZiyaratRouteStepRow(
                                place: place,
                                title: place.localizedContent(locale: settings.language.rawValue).title,
                                subtitle: place.localizedContent(locale: settings.language.rawValue).shortDescription,
                                duration: durationText(place.durationMinutes),
                                isLast: index == orderedPlaces.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    fitEntireRoute(animated: true)
                    setPanel(.compact)
                } label: {
                    Label(showOnMapLabel, systemImage: "map.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: true))
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
    }

    private var mapPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                panelSectionHeader(title: mapModesTitle, subtitle: mapModesSubtitle)

                HStack(spacing: 12) {
                    mapModeChoice(.standard, title: standardMapTitle, icon: "map.fill")
                    mapModeChoice(.satellite, title: satelliteMapTitle, icon: "globe.americas.fill")
                }

                VStack(spacing: 0) {
                    Toggle(isOn: $showRouteLine) {
                        Label(routeLineTitle, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    .tint(Color(uiColor: .systemBlue))
                    .padding(.vertical, 12)

                    Divider()

                    Toggle(isOn: $showPlacePins) {
                        Label(placePinsTitle, systemImage: "mappin.circle.fill")
                    }
                    .tint(Color(uiColor: .systemBlue))
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 14)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    fitEntireRoute(animated: true)
                    setPanel(.compact)
                } label: {
                    Label(fitRouteLabel, systemImage: "scope")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: false))
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
    }

    private func mapModeChoice(_ mode: ZiyaratMapMode, title: String, icon: String) -> some View {
        Button {
            IumrahHaptics.selection()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { mapMode = mode }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                HStack {
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer()
                    if mapMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(uiColor: .systemBlue))
                    }
                }
            }
            .foregroundStyle(.primary)
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(mapMode == mode ? Color(uiColor: .systemBlue) : Color.primary.opacity(0.07), lineWidth: mapMode == mode ? 1.7 : 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private func panelSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title2.bold()).tracking(-0.25)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func journeyMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(value).lineLimit(1).minimumScaleFactor(0.72)
            }
            .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Interaction

    private func select(_ place: ZiyaratPlace) {
        IumrahHaptics.selection()
        selectedPlace = place
        activeTab = .places
        setPanel(.card)
        focus(on: place, animated: true)
    }

    private func setPanel(_ level: ZiyaratPanelLevel) {
        panelDragY = 0
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            panelLevel = level
        }
    }

    private func focus(on place: ZiyaratPlace, animated: Bool) {
        guard Self.hasUsableCoordinate(place) else { return }

        let shift: Double
        let span: Double
        if isExpandedPanel {
            shift = 0.0068
            span = 0.021
        } else if isCompactPanel {
            shift = 0.0008
            span = 0.0135
        } else {
            shift = 0.0038
            span = 0.0155
        }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: place.latitude - shift, longitude: place.longitude),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )

        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.56)) { camera = .region(region) }
        } else {
            camera = .region(region)
        }
    }

    private func fitEntireRoute(animated: Bool) {
        guard !orderedPlaces.isEmpty else { return }
        let target = Self.region(for: orderedPlaces)
        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.56)) { camera = .region(target) }
        } else {
            camera = .region(target)
        }
    }

    private func openInMaps(_ place: ZiyaratPlace) {
        guard Self.hasUsableCoordinate(place) else { return }
        IumrahHaptics.selection()
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        item.name = place.localizedContent(locale: settings.language.rawValue).title
        item.openInMaps()
    }

    private func closeZiyarats() {
        guard !closing else { return }
        closing = true
        IumrahHaptics.selection()
        chrome.setImmersive(false)
        dismiss()
    }

    // MARK: Loading / intro

    @MainActor
    private func loadJourney() async {
        await loadJourney(for: selectedCity, animateCamera: false)
    }

    @MainActor
    private func loadJourney(for city: ZiyaratJourneyCity, animateCamera: Bool) async {
        let requestID = UUID()
        routeRequestID = requestID
        loadingCatalog = true

        let live = await ZiyaratService.shared.route(city: city.rawValue)
        guard routeRequestID == requestID, selectedCity == city else { return }

        route = live
        // Do not prefetch the whole Ziyarats photo catalogue when the screen opens.
        // A route can contain dozens of high-resolution images; eagerly downloading
        // and decoding them was able to spike memory and terminate the app before
        // the first frame became interactive. Images now load on demand.
        let validPlaces = live.places.filter(Self.hasUsableCoordinate)
        let targetRegion = validPlaces.isEmpty ? Self.defaultRegion(for: city) : Self.region(for: validPlaces)
        if animateCamera && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.52)) { camera = .region(targetRegion) }
        } else {
            camera = .region(targetRegion)
        }
        loadingCatalog = false
        revealedStopCount = validPlaces.count

        loadingRoute = true
        let routeCity = city
        Task { @MainActor in
            let lines = await ZiyaratRouteService.shared.roadPolylines(for: validPlaces)
            guard !Task.isCancelled, selectedCity == routeCity, routeRequestID == requestID else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { polylines = lines }
            loadingRoute = false
        }
    }

    private func changeCity(_ city: ZiyaratJourneyCity) {
        guard city != selectedCity else { return }
        IumrahHaptics.selection()
        selectedCity = city
        selectedPlace = nil
        activeTab = .journey
        polylines = []
        revealedStopCount = 0
        if isCompactPanel { setPanel(.card) }
        Task { @MainActor in
            await loadJourney(for: city, animateCamera: true)
        }
    }

    @MainActor
    private func playWelcomeSequence() async {
        if reduceMotion {
            welcomeCopyVisible = true
            revealedStopCount = orderedPlaces.count
            try? await Task.sleep(for: .milliseconds(250))
            welcomeVisible = false
            panelLevel = .card
            return
        }

        withAnimation(.easeOut(duration: 0.34)) { welcomeCopyVisible = true }
        try? await Task.sleep(for: .milliseconds(260))

        let count = max(orderedPlaces.count, 1)
        for index in 1...count {
            try? await Task.sleep(for: .milliseconds(92))
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                revealedStopCount = index
            }
        }

        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(.easeInOut(duration: 0.38)) { welcomeVisible = false }
        try? await Task.sleep(for: .milliseconds(90))
        panelLevel = .compact
        try? await Task.sleep(for: .milliseconds(180))
        setPanel(.card)
    }

    private static func defaultRegion(for city: ZiyaratJourneyCity) -> MKCoordinateRegion {
        switch city {
        case .madinah:
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 24.4672, longitude: 39.6111),
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
        case .makkah:
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 21.4038, longitude: 39.8926),
                span: MKCoordinateSpan(latitudeDelta: 0.16, longitudeDelta: 0.18)
            )
        }
    }

    private static func hasUsableCoordinate(_ place: ZiyaratPlace) -> Bool {
        let coordinate = place.coordinate
        return place.latitude.isFinite &&
            place.longitude.isFinite &&
            CLLocationCoordinate2DIsValid(coordinate) &&
            (-90.0...90.0).contains(place.latitude) &&
            (-180.0...180.0).contains(place.longitude)
    }

    private static func region(for places: [ZiyaratPlace]) -> MKCoordinateRegion {
        let valid = places.filter(hasUsableCoordinate)
        guard !valid.isEmpty else {
            return defaultRegion(for: .madinah)
        }

        let lats = valid.map(\.latitude)
        let lons = valid.map(\.longitude)
        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max() else {
            return defaultRegion(for: .madinah)
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2 - 0.002,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.033, (maxLat - minLat) * 1.7),
                longitudeDelta: max(0.033, (maxLon - minLon) * 1.7)
            )
        )
    }

    @ViewBuilder
    private var emptyOverlay: some View {
        let content = VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.title2)
            Text(noPlacesTitle).font(.headline)
            Text(noPlacesSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)

        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    // MARK: Localized UI copy

    private var routeTitle: String {
        switch selectedCity {
        case .madinah: return localized("Зиярат Медины", "Medina Ziyarat", "Madina ziyorati", "Мадина зиёрати")
        case .makkah: return localized("Зиярат Мекки", "Makkah Ziyarat", "Makka ziyorati", "Макка зиёрати")
        }
    }
    private var cityTitle: String {
        switch selectedCity {
        case .madinah: return localized("Медина", "Madinah", "Madina", "Мадина")
        case .makkah: return localized("Мекка", "Makkah", "Makka", "Макка")
        }
    }
    private var medinaSwitchTitle: String { localized("Медина", "Madinah", "Madina", "Мадина") }
    private var makkahSwitchTitle: String { localized("Мекка", "Makkah", "Makka", "Макка") }
    private var routeSubtitle: String { localized("Священные и исторические места в одной поездке", "Sacred and historic places in one journey", "Muqaddas va tarixiy joylar bitta yo‘nalishda", "Муқаддас ва тарихий жойлар битта йўналишда") }
    private var welcomePretitle: String { localized("Добро пожаловать в", "Welcome to", "Xush kelibsiz", "Хуш келибсиз") }
    private var stopsLabel: String { localized("мест", "stops", "joy", "жой") }
    private var totalTimeLabel: String { localized("всего", "total", "jami", "жами") }
    private var transportLabel: String { localized("Авто", "Car", "Avto", "Авто") }
    private var routeLabel: String { localized("поездка", "journey", "sayohat", "саёҳат") }
    private var firstStopLabel: String { localized("Первая остановка", "First stop", "Birinchi bekat", "Биринчи бекат") }
    private var showRouteLabel: String { localized("Показать маршрут", "Show route", "Yo‘nalishni ko‘rsatish", "Йўналишни кўрсатиш") }
    private var showOnMapLabel: String { localized("Показать на карте", "Show on map", "Xaritada ko‘rsatish", "Харитада кўрсатиш") }
    private var placesTitle: String { localized("Все места", "All places", "Barcha joylar", "Барча жойлар") }
    private var itineraryTitle: String { localized("Маршрут зиярата", "Ziyarat route", "Ziyorat yo‘nalishi", "Зиёрат йўналиши") }
    private var mapModesTitle: String { localized("Режим карты", "Map mode", "Xarita rejimi", "Харита режими") }
    private var mapModesSubtitle: String { localized("Выберите вид карты и то, что показывать", "Choose the map view and what to display", "Xarita ko‘rinishi va ko‘rsatiladigan ma’lumotlarni tanlang", "Харита кўриниши ва кўрсатиладиган маълумотларни танланг") }
    private var standardMapTitle: String { localized("Стандарт", "Standard", "Standart", "Стандарт") }
    private var satelliteMapTitle: String { localized("Спутник", "Satellite", "Sun’iy yo‘ldosh", "Сунъий йўлдош") }
    private var routeLineTitle: String { localized("Линия маршрута", "Route line", "Yo‘nalish chizig‘i", "Йўналиш чизиғи") }
    private var placePinsTitle: String { localized("Метки мест", "Place markers", "Joy belgilari", "Жой белгилари") }
    private var fitRouteLabel: String { localized("Показать весь маршрут", "Fit entire route", "Butun yo‘nalishni ko‘rsatish", "Бутун йўналишни кўрсатиш") }
    private var mapModeLabel: String { localized("Режим карты", "Map mode", "Xarita rejimi", "Харита режими") }
    private var closeLabel: String { localized("Закрыть", "Close", "Yopish", "Ёпиш") }
    private var closePlaceLabel: String { localized("Закрыть место", "Close place", "Joy ma’lumotini yopish", "Жой маълумотини ёпиш") }
    private var noPlacesTitle: String { localized("Пока нет мест", "No places yet", "Hozircha joylar yo‘q", "Ҳозирча жойлар йўқ") }
    private var noPlacesSubtitle: String { localized("Опубликованные в iumrah Business точки появятся здесь автоматически.", "Places published in iumrah Business will appear here automatically.", "iumrah Business’da chop etilgan joylar bu yerda avtomatik paydo bo‘ladi.", "iumrah Business’да чоп этилган жойлар бу ерда автоматик пайдо бўлади.") }

    private func tabTitle(_ tab: ZiyaratPanelTab) -> String {
        switch tab {
        case .journey: return localized("Поездка", "Journey", "Sayohat", "Саёҳат")
        case .places: return localized("Места", "Places", "Joylar", "Жойлар")
        case .route: return localized("Маршрут", "Route", "Yo‘nalish", "Йўналиш")
        case .map: return localized("Карта", "Map", "Xarita", "Харита")
        }
    }

    private func timeText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        if minutes >= 60 {
            let hours = max(1, minutes / 60)
            let remainder = minutes % 60
            if remainder >= 15 {
                return localized("~\(hours) ч \(remainder) мин", "~\(hours)h \(remainder)m", "~\(hours) soat \(remainder) daq", "~\(hours) соат \(remainder) дақ")
            }
            return localized("~\(hours) ч", "~\(hours)h", "~\(hours) soat", "~\(hours) соат")
        }
        return durationText(minutes)
    }

    private func durationText(_ minutes: Int) -> String {
        localized("\(minutes) мин", "\(minutes) min", "\(minutes) daq", "\(minutes) дақ")
    }

    private func visitType(_ raw: String) -> String {
        switch raw {
        case "enter": return localized("Заходим", "Enter", "Kiramiz", "Кирамиз")
        case "view": return localized("Осмотр", "View", "Ko‘ramiz", "Кўрамиз")
        case "pass": return localized("Проездом", "Pass by", "Yo‘lda", "Йўлда")
        default: return localized("Остановка", "Stop", "To‘xtash", "Тўхташ")
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private enum ZiyaratPanelLevel: CaseIterable {
    case compact
    case card
    case full
}

private struct ZiyaratPanelMetrics {
    let containerHeight: CGFloat

    let navigationHeight: CGFloat = 70
    let compactHeight: CGFloat = 108

    var cardHeight: CGFloat {
        min(max(containerHeight * 0.48, 360), 470)
    }

    var fullHeight: CGFloat {
        min(containerHeight - 12, max(cardHeight + 150, containerHeight - 48))
    }

    func height(for level: ZiyaratPanelLevel) -> CGFloat {
        switch level {
        case .compact: return compactHeight
        case .card: return cardHeight
        case .full: return fullHeight
        }
    }

    func rubberBanded(_ raw: CGFloat) -> CGFloat {
        let minimum = compactHeight
        let maximum = fullHeight

        if raw < minimum {
            return minimum - (minimum - raw) * 0.18
        }
        if raw > maximum {
            return maximum + (raw - maximum) * 0.12
        }
        return raw
    }

    func nearestLevel(to projectedHeight: CGFloat) -> ZiyaratPanelLevel {
        ZiyaratPanelLevel.allCases.min {
            abs(height(for: $0) - projectedHeight) < abs(height(for: $1) - projectedHeight)
        } ?? .card
    }

    func contentProgress(for height: CGFloat) -> CGFloat {
        let start = compactHeight + 10
        let end = compactHeight + 74
        guard end > start else { return 1 }
        return min(max((height - start) / (end - start), 0), 1)
    }
}

private struct ZiyaratPanelGrabber: View {
    var body: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.32))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }
}

private enum ZiyaratPanelTab: String, CaseIterable, Identifiable {
    case journey
    case places
    case route
    case map

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .journey: return "figure.walk"
        case .places: return "square.grid.2x2.fill"
        case .route: return "point.topleft.down.to.point.bottomright.curvepath"
        case .map: return "map.fill"
        }
    }
}


private struct ZiyaratNativeCitySwitcher: View {
    let selectedCity: ZiyaratJourneyCity
    let madinahTitle: String
    let makkahTitle: String
    let onSelect: (ZiyaratJourneyCity) -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                controls
                    .padding(4)
                    .glassEffect(.regular.interactive(true), in: Capsule())
            } else {
                controls
                    .padding(4)
                    .background(Color(uiColor: .systemBackground), in: Capsule())
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .contain)
    }

    private var controls: some View {
        HStack(spacing: 2) {
            cityButton(.madinah, title: madinahTitle)
            cityButton(.makkah, title: makkahTitle)
        }
    }

    private func cityButton(_ city: ZiyaratJourneyCity, title: String) -> some View {
        let selected = selectedCity == city
        return Button {
            guard !selected else { return }
            onSelect(city)
        } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color(uiColor: .systemBlue) : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: 64)
                .padding(.horizontal, 10)
                .frame(height: 38)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}


private struct ZiyaratNativeGlassIconButton: View {
    let systemName: String
    var foreground: Color? = nil
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button {
                    IumrahHaptics.selection()
                    action()
                } label: {
                    Image(systemName: systemName)
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(foreground ?? Color.primary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.regular)
            } else {
                Button {
                    IumrahHaptics.selection()
                    action()
                } label: {
                    Image(systemName: systemName)
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(foreground ?? Color.primary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.regular)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ZiyaratNativeMapControlGroup: View {
    let primarySystemName: String
    var primaryForeground: Color? = nil
    let primaryAccessibilityLabel: String
    let primaryAction: () -> Void

    let secondarySystemName: String
    let secondaryAccessibilityLabel: String
    let secondaryAction: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                controls
                    .frame(width: 54)
                    .fixedSize(horizontal: true, vertical: true)
                    .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 27, style: .continuous))
            } else {
                controls
                    .frame(width: 54)
                    .fixedSize(horizontal: true, vertical: true)
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 27, style: .continuous))
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            Button {
                IumrahHaptics.selection()
                primaryAction()
            } label: {
                Image(systemName: primarySystemName)
                    .font(.system(size: 19, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(primaryForeground ?? Color.primary)
                    .frame(width: 52, height: 50)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(primaryAccessibilityLabel)

            Divider()
                .padding(.horizontal, 13)

            Button {
                IumrahHaptics.selection()
                secondaryAction()
            } label: {
                Image(systemName: secondarySystemName)
                    .font(.system(size: 19, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.primary)
                    .frame(width: 52, height: 50)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(secondaryAccessibilityLabel)
        }
    }
}

private struct ZiyaratSheetNavigationBar: View {
    let activeTab: ZiyaratPanelTab
    let title: (ZiyaratPanelTab) -> String
    let onSelect: (ZiyaratPanelTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ZiyaratPanelTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 21, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)

                        Text(title(tab))
                            .font(.caption2.weight(activeTab == tab ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(activeTab == tab ? Color(uiColor: .systemBlue) : Color.primary.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

private enum ZiyaratMapMode: Equatable {
    case standard
    case satellite
}

private struct ZiyaratWelcomeOverlay: View {
    let pretitle: String
    let title: String
    let city: String
    let copyVisible: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text(pretitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                Text(title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-1.1)
                    .foregroundStyle(.white)
                Text(city)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.top, 2)
            }
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.32), radius: 18, y: 8)
            .opacity(copyVisible ? 1 : 0)
            .scaleEffect(copyVisible ? 1 : 0.97)
        }
    }
}

// MARK: - Map pin

private struct ZiyaratMapPin: View {
    let number: Int
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            if isSelected {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 31)
                    .background(Color(uiColor: .systemBackground), in: Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.7))
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            VStack(spacing: -2) {
                Text("\(number)")
                    .font(.system(size: isSelected ? 15 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: isSelected ? 40 : 33, height: isSelected ? 40 : 33)
                    .background(isSelected ? Color(uiColor: .systemBlue) : Color.black.opacity(0.84), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.96), lineWidth: isSelected ? 3 : 2.5))
                    .shadow(color: .black.opacity(0.27), radius: 8, y: 4)

                Image(systemName: "triangle.fill")
                    .font(.system(size: isSelected ? 8 : 7))
                    .rotationEffect(.degrees(180))
                    .foregroundStyle(isSelected ? Color(uiColor: .systemBlue) : Color.black.opacity(0.84))
            }
        }
        .animation(.spring(response: 0.33, dampingFraction: 0.78), value: isSelected)
    }
}

// MARK: - Journey content

private struct ZiyaratJourneyNextStopRow: View {
    let place: ZiyaratPlace
    let title: String
    let eyebrow: String
    let durationText: String

    var body: some View {
        HStack(spacing: 13) {
            ZiyaratImageView(image: place.images.first)
                .frame(width: 78, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("\(place.routeOrder)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 23, height: 23)
                        .background(Color.black.opacity(0.78), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                        .padding(6)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Label(durationText, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ZiyaratPlaceListRow: View {
    let place: ZiyaratPlace
    let content: ZiyaratPlaceTranslation
    let visitText: String
    let durationText: String

    var body: some View {
        HStack(spacing: 13) {
            ZiyaratImageView(image: place.images.first)
                .frame(width: 70, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("\(place.routeOrder)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.black.opacity(0.80), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.4))
                        .padding(5)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(content.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !place.titleArabic.isEmpty {
                    Text(place.titleArabic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(content.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    Label(visitText, systemImage: visitIcon(place.visitType))
                    Label(durationText, systemImage: "clock")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func visitIcon(_ raw: String) -> String {
        raw == "pass" ? "car.fill" : raw == "view" ? "eye.fill" : "figure.walk"
    }
}

private struct ZiyaratRouteStepRow: View {
    let place: ZiyaratPlace
    let title: String
    let subtitle: String
    let duration: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Text("\(place.routeOrder)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.86), in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.30))
                        .frame(width: 2, height: 54)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(duration)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !place.titleArabic.isEmpty {
                    Text(place.titleArabic)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 3)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Place details inside the persistent panel

private struct ZiyaratPlacePanelContent: View {
    let place: ZiyaratPlace
    let counterTitle: String
    let expanded: Bool
    let language: AppSettingsStore.Language
    let onBack: () -> Void
    let onExpand: () -> Void
    let onOpenMaps: () -> Void

    @State private var selectedImage = 0

    private var content: ZiyaratPlaceTranslation {
        place.localizedContent(locale: language.rawValue)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                placeNavigationHeader
                gallery
                placeHeader
                metadata

                Text(content.shortDescription)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                if expanded {
                    Divider().padding(.vertical, 2)
                    infoSection(title: localized("Подробнее", "Details", "Batafsil", "Батафсил"), body: content.longDescription)

                    if !content.interestingFacts.isEmpty {
                        factsSection
                    }

                    if !content.visitNotes.isEmpty {
                        infoSection(title: localized("Посещение", "Visit", "Tashrif", "Ташриф"), body: content.visitNotes)
                    }

                    exactPointSection
                } else {
                    Button(action: onExpand) {
                        Label(localized("Подробнее", "More details", "Batafsil", "Батафсил"), systemImage: "chevron.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: false))
                }

                Button(action: onOpenMaps) {
                    Label(localized("Открыть точную точку", "Open exact point", "Aniq nuqtani ochish", "Аниқ нуқтани очиш"), systemImage: "location.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: true))
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
    }

    private var placeNavigationHeader: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label(localized("Места", "Places", "Joylar", "Жойлар"), systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(uiColor: .systemBlue))

            Spacer(minLength: 8)

            Text(counterTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(height: 28)
    }

    private var gallery: some View {
        VStack(spacing: 9) {
            ZStack(alignment: .topTrailing) {
                if place.images.isEmpty {
                    ZiyaratImageView(image: nil)
                        .frame(height: expanded ? 260 : 190)
                } else {
                    TabView(selection: $selectedImage) {
                        ForEach(Array(place.images.enumerated()), id: \.offset) { index, image in
                            ZiyaratImageView(image: image)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: expanded ? 260 : 190)
                }

                if !place.images.isEmpty {
                    Text("\(min(selectedImage + 1, place.images.count)) / \(place.images.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 27)
                        .background(Color.black.opacity(0.52), in: Capsule())
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            if place.images.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(Array(place.images.enumerated()), id: \.offset) { index, image in
                            Button {
                                withAnimation(.easeInOut(duration: 0.24)) { selectedImage = index }
                            } label: {
                                ZiyaratImageView(image: image)
                                    .frame(width: 62, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selectedImage == index ? Color(uiColor: .systemBlue) : Color.clear, lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: expanded)
    }

    private var placeHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(content.title)
                .font(.system(size: 29, weight: .bold))
                .tracking(-0.55)
            if !place.titleArabic.isEmpty {
                Text(place.titleArabic)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metadata: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                metaCapsule(icon: visitIcon(place.visitType), text: visitType(place.visitType))
                metaCapsule(icon: "clock", text: localized("\(place.durationMinutes) мин", "\(place.durationMinutes) min", "\(place.durationMinutes) daq", "\(place.durationMinutes) дақ"))
                metaCapsule(icon: categoryIcon(place.category), text: categoryTitle(place.category))
            }
        }
    }

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Что интересно здесь", "What’s interesting here", "Bu yerda nimalar qiziq", "Бу ерда нималар қизиқ"))
                .font(.title3.bold())

            VStack(spacing: 0) {
                ForEach(Array(content.interestingFacts.enumerated()), id: \.offset) { index, fact in
                    HStack(alignment: .top, spacing: 11) {
                        Text("\(index + 1)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.iumrahRaisedBackground, in: Circle())
                        Text(fact)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)

                    if index < content.interestingFacts.count - 1 {
                        Divider().padding(.leading, 35)
                    }
                }
            }
        }
    }

    private var exactPointSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("Точная точка", "Exact point", "Aniq nuqta", "Аниқ нуқта"))
                        .font(.title3.bold())
                    Text(place.mapLabel.isEmpty ? place.address : place.mapLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Image(systemName: "scope")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(String(format: "%.5f, %.5f", place.latitude, place.longitude))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color(uiColor: .systemBlue))
                Text(localized("Координаты", "Coordinates", "Koordinatalar", "Координаталар"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(13)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func infoSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.title3.bold())
            Text(body)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaCapsule(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Color.iumrahRaisedBackground, in: Capsule())
            .lineLimit(1)
    }

    private func visitType(_ raw: String) -> String {
        switch raw {
        case "enter": return localized("Заходим", "Enter", "Kiramiz", "Кирамиз")
        case "view": return localized("Осмотр", "View", "Ko‘ramiz", "Кўрамиз")
        case "pass": return localized("Проездом", "Pass by", "Yo‘lda", "Йўлда")
        default: return localized("Остановка", "Stop", "To‘xtash", "Тўхташ")
        }
    }

    private func visitIcon(_ raw: String) -> String {
        raw == "pass" ? "car.fill" : raw == "view" ? "eye.fill" : "figure.walk"
    }

    private func categoryTitle(_ raw: String) -> String {
        switch raw {
        case "mosque": return localized("Мечеть", "Mosque", "Masjid", "Масжид")
        case "mountain": return localized("Гора", "Mountain", "Tog‘", "Тоғ")
        case "garden": return localized("Сад", "Garden", "Bog‘", "Боғ")
        case "cemetery": return localized("Кладбище", "Cemetery", "Qabriston", "Қабристон")
        case "restaurant": return localized("Ресторан", "Restaurant", "Restoran", "Ресторан")
        case "beach": return localized("Море", "Sea", "Dengiz", "Денгиз")
        case "picnic": return localized("Пикник", "Picnic", "Piknik", "Пикник")
        case "museum": return localized("Музей", "Museum", "Muzey", "Музей")
        default: return localized("Место", "Place", "Joy", "Жой")
        }
    }

    private func categoryIcon(_ raw: String) -> String {
        switch raw {
        case "mosque": return "building.columns.fill"
        case "mountain": return "mountain.2.fill"
        case "garden": return "tree.fill"
        case "cemetery": return "leaf.fill"
        case "restaurant": return "fork.knife"
        case "beach": return "water.waves"
        case "picnic": return "basket.fill"
        case "museum": return "building.2.fill"
        default: return "mappin.and.ellipse"
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

// MARK: - Native capsule buttons

private struct ZiyaratNativeCapsuleButtonModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Color(uiColor: .systemBlue))
            } else {
                content
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .tint(Color(uiColor: .systemBlue))
            }
        } else {
            if prominent {
                content
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Color(uiColor: .systemBlue))
            } else {
                content
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Color(uiColor: .systemBlue))
            }
        }
    }
}

// MARK: - Shared image renderer

struct ZiyaratImageView: View {
    let image: ZiyaratImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.iumrahRaisedBackground)

            if let image, let asset = image.bundledAssetName {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else if let image, let url = AppConfig.absoluteURL(image.url) {
                ZiyaratRemoteImageView(url: url, fallbackAsset: fallbackAsset(for: image.id))
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
    }

    private func fallbackAsset(for id: String) -> String? {
        guard id.hasPrefix("quba-") else { return nil }
        let number = id.replacingOccurrences(of: "quba-", with: "")
        return "ZiyaratQuba\(number)"
    }
}

private struct ZiyaratRemoteImageView: View {
    let url: URL
    let fallbackAsset: String?
    @StateObject private var loader = ZiyaratRemoteImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else if loader.failed, let fallbackAsset {
                Image(fallbackAsset)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .task(id: url) {
            loader.load(url: url)
        }
        .onDisappear { loader.cancel() }
        .animation(.easeOut(duration: 0.16), value: loader.image != nil)
    }
}

@MainActor
fileprivate final class ZiyaratRemoteImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var failed = false

    fileprivate static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 12
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    private var task: Task<Void, Never>?
    private var currentURL: URL?

    func load(url: URL) {
        guard currentURL != url || (image == nil && !failed) else { return }
        currentURL = url
        failed = false
        task?.cancel()

        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        image = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
                request.setValue("image/avif,image/webp,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    failed = true
                    return
                }
                guard data.count <= 20 * 1024 * 1024,
                      let decoded = Self.downsampledImage(from: data, maxPixelSize: 1600) else {
                    failed = true
                    return
                }
                let decodedCost = max(1, Int(decoded.size.width * decoded.scale) * Int(decoded.size.height * decoded.scale) * 4)
                Self.cache.setObject(decoded, forKey: url as NSURL, cost: decodedCost)
                image = decoded
            } catch {
                guard !Task.isCancelled else { return }
                failed = true
            }
        }
    }

    private static func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}


// MARK: - Booking Ziyarats carousel

/// Booking-facing Ziyarats presentation. This intentionally stays separate from
/// the full map-first `ZiyaratJourneyView`: the booking sheet is a focused,
/// horizontally swipeable catalog, while the full product keeps its immersive map.
struct ZiyaratIncludedCatalogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var city: ZiyaratJourneyCity = .makkah
    @State private var route = ZiyaratSeedData.fallback(city: "Makkah")
    @State private var selectedPlaceID: String?
    @State private var isLoading = false

    private var places: [ZiyaratPlace] {
        route.places.sorted { $0.routeOrder < $1.routeOrder }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker(localized("Город", "City", "Shahar", "Шаҳар"), selection: $city) {
                    Text(localized("Мекка", "Makkah", "Makka", "Макка")).tag(ZiyaratJourneyCity.makkah)
                    Text(localized("Медина", "Madinah", "Madina", "Мадина")).tag(ZiyaratJourneyCity.madinah)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, IumrahDesign.pagePadding)

                VStack(alignment: .leading, spacing: 5) {
                    Text(localized(
                        "Места Вашей программы",
                        "Places in your program",
                        "Dasturingizdagi joylar",
                        "Дастурингиздаги жойлар"
                    ))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(-0.5)

                    Text(localized(
                        "Листайте карточки — фото и подробности каждого места уже собраны здесь.",
                        "Swipe through the cards — photos and details for every stop are already here.",
                        "Kartalarni suring — har bir joyning fotosi va tafsilotlari shu yerda.",
                        "Карталарни суринг — ҳар бир жойнинг фотоси ва тафсилотлари шу ерда."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, IumrahDesign.pagePadding)

                if isLoading && places.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if places.isEmpty {
                    ContentUnavailableView(
                        localized("Места пока не опубликованы", "No places published yet", "Joylar hali e’lon qilinmagan", "Жойлар ҳали эълон қилинмаган"),
                        systemImage: "map"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TabView(selection: $selectedPlaceID) {
                        ForEach(places) { place in
                            ZiyaratBookingCarouselCard(place: place)
                                .environmentObject(settings)
                                .padding(.horizontal, IumrahDesign.pagePadding)
                                .tag(Optional(place.id))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
            }
            .padding(.top, 10)
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .navigationTitle("iumrah Ziyarats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .task {
                async let makkah: Void = ZiyaratImagePrefetcher.shared.prefetch(city: ZiyaratJourneyCity.makkah.rawValue)
                async let madinah: Void = ZiyaratImagePrefetcher.shared.prefetch(city: ZiyaratJourneyCity.madinah.rawValue)
                _ = await (makkah, madinah)
            }
            .task(id: city.rawValue) {
                await load(city)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func load(_ city: ZiyaratJourneyCity) async {
        isLoading = true
        let newRoute = await ZiyaratService.shared.route(city: city.rawValue)
        guard self.city == city else { return }
        route = newRoute
        selectedPlaceID = newRoute.places.sorted { $0.routeOrder < $1.routeOrder }.first?.id
        isLoading = false
        await ZiyaratImagePrefetcher.shared.prefetch(route: newRoute)
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct ZiyaratBookingCarouselCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let place: ZiyaratPlace

    private var content: ZiyaratPlaceTranslation {
        place.localizedContent(locale: settings.language.rawValue)
    }

    private var primaryImage: ZiyaratImage? {
        place.images.sorted { $0.position < $1.position }.first
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ZiyaratImageView(image: primaryImage)
                        .frame(height: 270)
                        .clipped()

                    if place.images.count > 1 {
                        Label("\(place.images.count)", systemImage: "photo.on.rectangle.angled")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(Color.black.opacity(0.52), in: Capsule())
                            .padding(12)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(place.routeOrder)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.black, in: Circle())

                        Text(content.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .tracking(-0.35)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !place.titleArabic.isEmpty {
                        Text(place.titleArabic)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        meta("clock.fill", localized("\(place.durationMinutes) мин", "\(place.durationMinutes) min", "\(place.durationMinutes) daq", "\(place.durationMinutes) дақ"))
                        meta("mappin.and.ellipse", categoryTitle(place.category))
                    }

                    Text(content.shortDescription)
                        .font(.headline)
                        .foregroundStyle(.primary.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(content.longDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !content.interestingFacts.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            Text(localized("Что важно знать", "What to know", "Muhim ma’lumot", "Муҳим маълумот"))
                                .font(.headline)

                            ForEach(Array(content.interestingFacts.prefix(3).enumerated()), id: \.offset) { _, fact in
                                Label(fact, systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !content.visitNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(localized("Как проходит остановка", "How the stop works", "Tashrif qanday o‘tadi", "Ташриф қандай ўтади"))
                                .font(.headline)
                            Text(content.visitNotes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.04), radius: 16, y: 7)
            .padding(.bottom, 34)
        }
    }

    private func meta(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private func categoryTitle(_ raw: String) -> String {
        switch raw.lowercased() {
        case "mountain": return localized("Гора", "Mountain", "Tog‘", "Тоғ")
        case "mosque": return localized("Мечеть", "Mosque", "Masjid", "Масжид")
        case "cemetery": return localized("Кладбище", "Cemetery", "Qabriston", "Қабристон")
        case "garden": return localized("Сад", "Garden", "Bog‘", "Боғ")
        default: return raw.capitalized
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

/// Warms the system URL cache before a Ziyarats surface is opened. The regular
/// image loader continues to own rendering/cancellation, but most remote image
/// bytes are already local by the time the user starts swiping.
actor ZiyaratImagePrefetcher {
    static let shared = ZiyaratImagePrefetcher()

    /// Prefetch is deliberately bounded. The full catalogue can contain many
    /// high-resolution photos, so warming every image in parallel can cause an
    /// out-of-memory termination. Rendering owns image decoding; prefetch only
    /// stores a small number of compressed responses in URLCache.
    func prefetch(city: String) async {
        let route = await ZiyaratService.shared.route(city: city)
        await prefetch(route: route)
    }

    func prefetch(route: ZiyaratRoute) async {
        let urls = route.places
            .sorted { $0.routeOrder < $1.routeOrder }
            .flatMap { place in
                place.images
                    .sorted { $0.position < $1.position }
                    .prefix(1)
            }
            .compactMap { image -> URL? in
                guard image.bundledAssetName == nil else { return nil }
                return AppConfig.absoluteURL(image.url)
            }

        // A few cover images are enough to make the catalogue feel instant.
        // Sequential warming keeps peak networking and memory deterministic.
        for url in urls.prefix(6) {
            guard !Task.isCancelled else { return }
            await Self.warm(url)
        }
    }

    private static func warm(_ url: URL) async {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        request.setValue("image/avif,image/webp,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        if URLCache.shared.cachedResponse(for: request) != nil { return }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  data.count <= 12 * 1024 * 1024,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return }
            URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
        } catch {
            // Best effort only. Ziyarats must remain usable without image prefetch.
        }
    }
}
