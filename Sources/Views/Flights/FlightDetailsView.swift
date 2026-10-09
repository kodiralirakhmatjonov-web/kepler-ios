import SwiftUI

struct FlightDetailsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var enrichedAirports: [String: Airport] = [:]
    let offer: FlightOffer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                IumrahRefundPolicyCard(component: .flight, compact: false)

                ForEach(Array(offer.displaySegments.enumerated()), id: \.element.id) { index, segment in
                    segmentSection(segment, index: index)
                    if index < offer.layovers.count {
                        layoverSection(offer.layovers[index])
                    }
                }

                if offer.layovers.isEmpty, let connections = offer.connectionAirports, !connections.isEmpty {
                    ForEach(connections, id: \.code) { airport in
                        connectionSection(airport)
                    }
                }


                ticketInfoSection
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .flight)
        .task { await enrichAirports() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L10n.text("flight_details_title", settings.language))
                .font(.largeTitle.weight(.bold))
            Text(L10n.format(
                "flight_details_route",
                settings.language,
                resolvedAirport(offer.displaySegments.first?.origin ?? FlightAirportSnapshot(code: offer.origin)).displayCity,
                resolvedAirport(offer.displaySegments.last?.destination ?? FlightAirportSnapshot(code: offer.destination)).displayCity
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Label(flightTypeTitle, systemImage: "airplane")
                Text("•")
                Label(durationText(offer.durationMinutes), systemImage: "clock")
                Text("•")
                Text(stopLabel)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 3)
        }
    }

    private var flightTypeTitle: String {
        switch settings.language {
        case .russian: return "Перелёт"
        case .turkish: return TurkishLocalization.phrase("Flight")
        case .english: return "Flight"
        case .uzbek: return "Parvoz"
        case .uzbekCyrillic: return "Парвоз"
        }
    }

    private var flightNumberPendingTitle: String {
        switch settings.language {
        case .russian: return "Номер уточняется"
        case .turkish: return TurkishLocalization.phrase("Flight number pending")
        case .english: return "Flight number pending"
        case .uzbek: return "Reys raqami aniqlanmoqda"
        case .uzbekCyrillic: return "Рейс рақами аниқланмоқда"
        }
    }

    private func segmentSection(_ segment: FlightSegment, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(offer.segments?.isEmpty == false
                 ? L10n.format("flight_segment_count", settings.language, index + 1, offer.displaySegments.count)
                 : routeSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 17) {
                HStack(spacing: 11) {
                    AirlineLogoView(airlineCode: segment.airlineCode, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(FlightReferenceCatalog.airlineName(code: segment.airlineCode, fallback: segment.airline))
                            .font(.headline.weight(.semibold))
                        if let exactNumber = FlightReferenceCatalog.normalizedVerifiedFlightNumber(segment.flightNumber) {
                            Text(flightNumberLabel(exactNumber))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                routeTimeline(segment)

                Divider()

                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 13) {
                    if segment.durationMinutes > 0 {
                        detailValue(titleKey: "flight_detail_duration", value: durationText(segment.durationMinutes))
                    }
                    detailValue(titleKey: "flight_detail_cabin", value: cabinLabel(segment.cabin))
                    if let aircraft = segment.aircraft {
                        detailValue(titleKey: "flight_detail_aircraft", value: aircraft)
                    }
                    if let carrier = segment.operatingCarrier, !carrier.localizedCaseInsensitiveContains(segment.airline) {
                        detailValue(titleKey: "flight_detail_operated_by", value: carrier)
                    }
                }
            }
            .iumrahCard()
        }
    }

    private func routeTimeline(_ segment: FlightSegment) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(Color.primary.opacity(0.16))
                    .frame(width: 2, height: 74)
                Circle()
                    .fill(Color.primary)
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 7)

            VStack(alignment: .leading, spacing: 19) {
                airportRow(segment.origin, date: segment.departureAt)
                airportRow(segment.destination, date: segment.arrivalAt)
            }
        }
    }

    private func airportRow(_ airport: FlightAirportSnapshot, date: Date) -> some View {
        let airport = resolvedAirport(airport)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(airport.displayCity)
                    .font(.title3.weight(.bold))
                Text("\(airport.displayAirport) (\(airport.code))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let terminal = airport.terminal {
                    Text(L10n.format("flight_terminal", settings.language, terminal))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 3) {
                Text(timeFormatter(airport).string(from: date))
                    .font(.title3.monospacedDigit().weight(.bold))
                Text(dateFormatter(airport).string(from: date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func layoverSection(_ layover: FlightLayover) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(
                systemName: layover.airportChange ? "arrow.triangle.swap" : "clock.arrow.circlepath",
                role: layover.airportChange ? .warning : .calendar,
                size: 28,
                symbolSize: 13,
                shape: .circle
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(layover.airportChange
                     ? L10n.format("flight_layover_airport_change", settings.language, resolvedAirport(layover.airport).displayCity)
                     : L10n.format("flight_layover_title", settings.language, resolvedAirport(layover.airport).displayCity))
                    .font(.subheadline.weight(.bold))
                if let country = FlightReferenceCatalog.airportCountry(layover.airport.code) {
                    Text("\(layover.airport.code) · \(country)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if layover.durationMinutes > 0 {
                    Text(durationText(layover.durationMinutes))
                        .font(.subheadline)
                }
                if layover.overnight {
                    Text(L10n.text("flight_layover_overnight", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func connectionSection(_ airport: FlightAirportSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(
                systemName: "arrow.triangle.branch",
                role: .travel,
                size: 28,
                symbolSize: 13,
                shape: .circle
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(connectionTitle(resolvedAirport(airport).displayCity))
                    .font(.subheadline.weight(.bold))
                if let country = FlightReferenceCatalog.airportCountry(airport.code) {
                    Text("\(airport.code) · \(country)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func flightNumberLabel(_ number: String) -> String {
        switch settings.language {
        case .russian: return "Рейс \(number)"
        case .turkish: return TurkishLocalization.phrase("Flight \(number)")
        case .english: return "Flight \(number)"
        case .uzbek: return "Reys \(number)"
        case .uzbekCyrillic: return "Рейс \(number)"
        }
    }

    private var routeSectionTitle: String {
        switch settings.language {
        case .russian: return "Маршрут"
        case .turkish: return TurkishLocalization.phrase("Itinerary")
        case .english: return "Itinerary"
        case .uzbek: return "Yo‘nalish"
        case .uzbekCyrillic: return "Йўналиш"
        }
    }

    private func connectionTitle(_ city: String) -> String {
        switch settings.language {
        case .russian: return "Пересадка · \(city)"
        case .turkish: return TurkishLocalization.phrase("Connection · \(city)")
        case .english: return "Connection · \(city)"
        case .uzbek: return "Ulanish · \(city)"
        case .uzbekCyrillic: return "Уланиш · \(city)"
        }
    }

    private var ticketInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(ticketInfoTitle)
                .font(.headline)

            if offer.baggage != nil || offer.requiresSelfTransfer != nil {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 12) {
                    if let carryOn = offer.baggage?.carryOn {
                        detailValue(title: baggageTitle(carryOn: true), value: "×\(carryOn)")
                    }
                    if let checked = offer.baggage?.checked {
                        detailValue(title: baggageTitle(carryOn: false), value: "×\(checked)")
                    }
                    if let selfTransfer = offer.requiresSelfTransfer {
                        detailValue(title: selfTransferTitle, value: selfTransfer ? selfTransferRequired : selfTransferNotRequired)
                    }
                }
            } else {
                Text(ticketInfoBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .iumrahCard()
    }

    private var ticketInfoTitle: String {
        switch settings.language {
        case .russian: return "Условия перелёта"
        case .turkish: return TurkishLocalization.phrase("Flight conditions")
        case .english: return "Flight conditions"
        case .uzbek: return "Parvoz shartlari"
        case .uzbekCyrillic: return "Парвоз шартлари"
        }
    }

    private var ticketInfoBody: String {
        switch settings.language {
        case .russian: return "Выбранный перелёт уже учтён в общей цене пакета. Здесь показаны только детали маршрута."
        case .turkish: return TurkishLocalization.phrase("Your selected flight is already included in the package total. Only itinerary details are shown here.")
        case .english: return "Your selected flight is already included in the package total. Only itinerary details are shown here."
        case .uzbek: return "Tanlangan reys paketning umumiy narxiga kiritilgan. Bu yerda faqat yo‘nalish tafsilotlari ko‘rsatiladi."
        case .uzbekCyrillic: return "Танланган рейс пакетнинг умумий нархига киритилган. Бу ерда фақат йўналиш тафсилотлари кўрсатилади."
        }
    }

    private func detailValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func baggageTitle(carryOn: Bool) -> String {
        switch settings.language {
        case .russian: return carryOn ? "Ручная кладь" : "Багаж"
        case .turkish: return carryOn ? "Kabin bagajı" : "Kayıtlı bagaj"
        case .english: return carryOn ? "Carry-on" : "Checked baggage"
        case .uzbek: return carryOn ? "Qo‘l yuki" : "Bagaj"
        case .uzbekCyrillic: return carryOn ? "Қўл юки" : "Багаж"
        }
    }

    private var selfTransferTitle: String {
        switch settings.language {
        case .russian: return "Пересадка"
        case .turkish: return TurkishLocalization.phrase("Connection")
        case .english: return "Connection"
        case .uzbek: return "Ulanish"
        case .uzbekCyrillic: return "Уланиш"
        }
    }
    private var selfTransferRequired: String {
        switch settings.language {
        case .russian: return "Самостоятельная пересадка"
        case .turkish: return TurkishLocalization.phrase("Self-transfer")
        case .english: return "Self-transfer"
        case .uzbek: return "Mustaqil transfer"
        case .uzbekCyrillic: return "Мустақил трансфер"
        }
    }
    private var selfTransferNotRequired: String {
        switch settings.language {
        case .russian: return "Не требуется"
        case .turkish: return TurkishLocalization.phrase("Not required")
        case .english: return "Not required"
        case .uzbek: return "Talab qilinmaydi"
        case .uzbekCyrillic: return "Талаб қилинмайди"
        }
    }

    private func detailValue(titleKey: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.text(titleKey, settings.language))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value ?? L10n.text("flight_detail_unknown", settings.language))
                .font(.subheadline.weight(.semibold))
        }
    }

    private var stopLabel: String {
        offer.stops == 0 ? L10n.text("flight_direct", settings.language) : L10n.format("flight_stops", settings.language, offer.stops)
    }

    private func durationText(_ minutes: Int) -> String {
        if minutes <= 0 {
            switch settings.language {
            case .russian: return "Время по данным источника"
            case .turkish: return TurkishLocalization.phrase("Duration from source")
            case .english: return "Duration from source"
            case .uzbek: return "Vaqt manba ma’lumotida"
            case .uzbekCyrillic: return "Вақт манба маълумотида"
            }
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return L10n.format("flight_minutes_short", settings.language, mins) }
        if mins == 0 { return L10n.format("flight_hours_short", settings.language, hours) }
        return L10n.format("flight_duration_short", settings.language, hours, mins)
    }

    private func cabinLabel(_ cabin: String?) -> String {
        switch cabin?.lowercased() {
        case "business": return L10n.text("flight_cabin_business", settings.language)
        case "premium_economy": return L10n.text("flight_cabin_premium", settings.language)
        case "first": return L10n.text("flight_cabin_first", settings.language)
        default: return L10n.text("flight_cabin_economy", settings.language)
        }
    }

    private func resolvedAirport(_ snapshot: FlightAirportSnapshot) -> FlightAirportSnapshot {
        guard let enriched = enrichedAirports[snapshot.code] else { return snapshot }
        return FlightAirportSnapshot(
            code: snapshot.code,
            city: enriched.city,
            name: enriched.name,
            terminal: snapshot.terminal,
            timeZoneIdentifier: snapshot.timeZoneIdentifier
        )
    }

    @MainActor
    private func enrichAirports() async {
        let codes = Set(
            offer.displaySegments.flatMap { [$0.origin.code, $0.destination.code] } +
            (offer.connectionAirports ?? []).map(\.code) +
            (offer.pairedLeg?.segments ?? []).flatMap { [$0.origin.code, $0.destination.code] }
        )
        let service = AirportSearchService()
        for code in codes where enrichedAirports[code] == nil {
            do {
                let matches = try await service.search(code, limit: 4)
                if let exact = matches.first(where: { $0.iata.uppercased() == code.uppercased() }) {
                    enrichedAirports[code] = exact
                }
            } catch {
                // Presentation enrichment is best-effort. A failed airport lookup
                // must never hide an otherwise valid live flight result.
            }
        }
    }

    private func timeFormatter(_ airport: FlightAirportSnapshot) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let identifier = airport.timeZoneIdentifier, let zone = TimeZone(identifier: identifier) { formatter.timeZone = zone }
        return formatter
    }

    private func dateFormatter(_ airport: FlightAirportSnapshot) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMM, EEE"
        if let identifier = airport.timeZoneIdentifier, let zone = TimeZone(identifier: identifier) { formatter.timeZone = zone }
        return formatter
    }
}
