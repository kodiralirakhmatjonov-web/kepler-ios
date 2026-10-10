import SwiftUI
import MapKit
import CoreLocation

struct AirportRouteMapPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore

    @Binding private var origin: Airport?
    @Binding private var originCode: String
    @Binding private var destination: Airport?
    @Binding private var destinationCode: String

    @StateObject private var discovery = AirportMapDiscoveryStore()
    @State private var draftOrigin: Airport?
    @State private var draftDestination: Airport?
    @State private var mode: AirportRouteSelectionMode
    @State private var selectedPoint: AirportMapPoint?
    @State private var resolvedAirport: Airport?
    @State private var isResolving = false
    @State private var resolveFailed = false
    @State private var sameAirportError = false
    @State private var cameraDistance: CLLocationDistance = 32_000_000
    @State private var resetGeneration = 0
    @State private var resolutionTask: Task<Void, Never>?

    private let resolver = AirportMapResolver()

    init(
        origin: Binding<Airport?>,
        originCode: Binding<String>,
        destination: Binding<Airport?>,
        destinationCode: Binding<String>
    ) {
        _origin = origin
        _originCode = originCode
        _destination = destination
        _destinationCode = destinationCode

        let seededOrigin = origin.wrappedValue ?? AirportMapBootstrapCatalog.airport(code: originCode.wrappedValue)
        let seededDestination = destination.wrappedValue ?? AirportMapBootstrapCatalog.airport(code: destinationCode.wrappedValue)
        _draftOrigin = State(initialValue: seededOrigin)
        _draftDestination = State(initialValue: seededDestination)
        _mode = State(initialValue: seededOrigin == nil ? .departure : .arrival)
    }

    var body: some View {
        ZStack {
            AirportMapKitCanvas(
                points: mapPoints,
                origin: draftOrigin,
                destination: draftDestination,
                selectedPointID: selectedPoint?.id,
                initialFocus: draftOrigin ?? draftDestination,
                resetGeneration: resetGeneration,
                onSelect: select,
                onRegionSettled: regionDidSettle
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                Spacer(minLength: 12)
                bottomPanel
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .onDisappear {
            resolutionTask?.cancel()
        }
    }

    private var mapPoints: [AirportMapPoint] {
        let bundled = AirportMapBootstrapCatalog.points
        let dynamic = discovery.points.filter { candidate in
            !bundled.contains { bundledPoint in
                CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
                    .distance(from: CLLocation(latitude: bundledPoint.latitude, longitude: bundledPoint.longitude)) < 2_500
            }
        }
        return bundled + dynamic
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    discovery.resetRequestThrottle()
                    resetGeneration += 1
                    IumrahHaptics.soft()
                } label: {
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("airport_map_reset", settings.language))

                Text(tr("Карта аэропортов", "Airports map", "Aeroportlar xaritasi", "Аэропортлар харитаси"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Button {
                    dismiss()
                } label: {
                    Text(L10n.text("close", settings.language))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
            }

            Picker("", selection: $mode) {
                Text(tr("Откуда", "From", "Qayerdan", "Қаердан"))
                    .tag(AirportRouteSelectionMode.departure)
                Text(tr("Куда", "To", "Qayerga", "Қаерга"))
                    .tag(AirportRouteSelectionMode.arrival)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                clearCandidate()
                IumrahHaptics.selection()
            }
        }
        .padding(6)
        .foregroundStyle(.primary)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 27, style: .continuous), interactive: true, chrome: true)
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if let selectedPoint {
            candidatePanel(selectedPoint)
        } else {
            routePanel
        }
    }

    private var routePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                routeEndpoint(
                    title: tr("Откуда", "From", "Qayerdan", "Қаердан"),
                    airport: draftOrigin,
                    fallback: originCode,
                    selected: mode == .departure
                ) {
                    mode = .departure
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)

                routeEndpoint(
                    title: tr("Куда", "To", "Qayerga", "Қаерга"),
                    airport: draftDestination,
                    fallback: destinationCode,
                    selected: mode == .arrival
                ) {
                    mode = .arrival
                }
            }

            if sameAirportError {
                Label(
                    tr(
                        "Аэропорты вылета и прилёта должны отличаться.",
                        "Departure and arrival airports must be different.",
                        "Jo‘nash va kelish aeroportlari boshqa bo‘lishi kerak.",
                        "Жўнаш ва келиш аэропортлари бошқа бўлиши керак."
                    ),
                    systemImage: "exclamationmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: cameraDistance > 5_500_000 ? "plus.magnifyingglass" : "hand.tap.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)

                    Text(routeHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    if discovery.isDiscovering {
                        ProgressView().controlSize(.small)
                    }
                }
            }

            if draftOrigin != nil, draftDestination != nil {
                Button {
                    commitRoute()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane")
                        Text(tr("Использовать маршрут", "Use this route", "Yo‘nalishni tanlash", "Йўналишни танлаш"))
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 29, style: .continuous))
    }

    private func routeEndpoint(
        title: String,
        airport: Airport?,
        fallback: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            clearCandidate()
            action()
            IumrahHaptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.35)
                    .foregroundStyle(.secondary)
                Text((airport?.iata ?? fallback).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospaced()
                    .foregroundStyle(.primary)
                Text(airport?.city ?? tr("Выберите", "Choose", "Tanlang", "Танланг"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 62)
            .background(
                selected ? Color.iumrahRaisedBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func candidatePanel(_ point: AirportMapPoint) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    if let code = resolvedAirport?.iata ?? point.displayCode {
                        Text(code.uppercased())
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospaced()
                    } else {
                        Image(systemName: "airplane")
                            .font(.system(size: 20, weight: .semibold))
                            .rotationEffect(.degrees(-35))
                    }
                }
                .frame(width: 50, height: 50)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedAirport?.city ?? point.displayTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(resolvedAirport?.subtitle ?? point.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button {
                    clearCandidate()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .iumrahGlass(in: Circle(), interactive: true, chrome: true)
                }
                .buttonStyle(.plain)
            }

            if isResolving {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text(L10n.text("airport_map_resolving", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if resolveFailed {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                    Text(L10n.text("airport_map_resolve_failed", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let resolvedAirport {
                Button {
                    apply(resolvedAirport)
                } label: {
                    Text(selectionButtonTitle(resolvedAirport))
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 29, style: .continuous))
    }

    private var routeHint: String {
        if cameraDistance > 5_500_000 {
            return tr(
                "Приблизьте карту: точки превратятся в аэропорты. Нажмите на нужный аэропорт.",
                "Zoom in: dots become airport markers. Tap the airport you need.",
                "Xaritani yaqinlashtiring: nuqtalar aeroport belgilariga aylanadi. Kerakli aeroportni bosing.",
                "Харитани яқинлаштиринг: нуқталар аэропорт белгиларига айланади. Керакли аэропортни босинг."
            )
        }
        switch mode {
        case .departure:
            return tr("Выберите аэропорт вылета.", "Choose the departure airport.", "Jo‘nash aeroportini tanlang.", "Жўнаш аэропортини танланг.")
        case .arrival:
            return tr("Выберите аэропорт прилёта.", "Choose the arrival airport.", "Kelish aeroportini tanlang.", "Келиш аэропортини танланг.")
        }
    }

    private func selectionButtonTitle(_ airport: Airport) -> String {
        switch mode {
        case .departure:
            return tr(
                "Выбрать \(airport.iata) как вылет",
                "Use \(airport.iata) as departure",
                "\(airport.iata) jo‘nash aeroporti",
                "\(airport.iata) жўнаш аэропорти"
            )
        case .arrival:
            return tr(
                "Выбрать \(airport.iata) как прилёт",
                "Use \(airport.iata) as arrival",
                "\(airport.iata) kelish aeroporti",
                "\(airport.iata) келиш аэропорти"
            )
        }
    }

    private func select(_ point: AirportMapPoint) {
        resolutionTask?.cancel()
        selectedPoint = point
        resolvedAirport = point.airport
        resolveFailed = false
        isResolving = point.airport == nil
        sameAirportError = false
        IumrahHaptics.selection()

        guard point.airport == nil else { return }
        resolutionTask = Task {
            let airport = await resolver.resolve(point)
            guard !Task.isCancelled, selectedPoint?.id == point.id else { return }
            resolvedAirport = airport
            resolveFailed = airport == nil
            isResolving = false
            if let airport {
                discovery.rememberResolved(point, airport: airport)
            } else {
                IumrahHaptics.error()
            }
        }
    }

    private func apply(_ airport: Airport) {
        let normalized = airport.iata.uppercased()
        switch mode {
        case .departure:
            if draftDestination?.iata.uppercased() == normalized {
                sameAirportError = true
                IumrahHaptics.error()
                return
            }
            draftOrigin = airport
            mode = .arrival
        case .arrival:
            if draftOrigin?.iata.uppercased() == normalized {
                sameAirportError = true
                IumrahHaptics.error()
                return
            }
            draftDestination = airport
        }
        clearCandidate(keepError: false)
        resetGeneration += 1
        IumrahHaptics.success()
    }

    private func clearCandidate(keepError: Bool = false) {
        resolutionTask?.cancel()
        selectedPoint = nil
        resolvedAirport = nil
        isResolving = false
        resolveFailed = false
        if !keepError { sameAirportError = false }
    }

    private func regionDidSettle(_ region: MKCoordinateRegion, _ distance: CLLocationDistance) {
        cameraDistance = distance
        discovery.update(region: region, cameraDistance: distance)
    }

    private func commitRoute() {
        guard let draftOrigin, let draftDestination,
              draftOrigin.iata.uppercased() != draftDestination.iata.uppercased() else {
            sameAirportError = true
            IumrahHaptics.error()
            return
        }
        origin = draftOrigin
        originCode = draftOrigin.iata.uppercased()
        destination = draftDestination
        destinationCode = draftDestination.iata.uppercased()
        IumrahHaptics.success()
        dismiss()
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .malay, .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}
