import SwiftUI

struct BookingFlightFirstComponentsView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let session: StoredBookingSession
    let onChangeMakkahHotel: () -> Void
    let onChangeMadinahHotel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let outbound = session.outboundFlight {
                SectionHeader(flightsTitle, eyebrow: "iumrah Flights", subtitle: nil)
                BookingFlightFirstLegCard(
                    flight: outbound,
                    direction: outboundTitle,
                    language: settings.language
                )
            }

            if let inbound = session.inboundFlight {
                BookingFlightFirstLegCard(
                    flight: inbound,
                    direction: returnTitle,
                    language: settings.language
                )
            }

            if session.hotelSelection != nil || session.madinahHotelSelection != nil {
                SectionHeader(hotelsTitle, eyebrow: "iumrah Hotels", subtitle: nil)

                if let makkah = session.hotelSelection {
                    BookingFlightFirstHotelCard(
                        hotel: makkah,
                        nights: session.booking.stay.makkahNights,
                        language: settings.language,
                        onOpen: onChangeMakkahHotel
                    )
                }

                if let madinah = session.madinahHotelSelection {
                    BookingFlightFirstHotelCard(
                        hotel: madinah,
                        nights: session.booking.stay.madinahNights ?? 0,
                        language: settings.language,
                        onOpen: onChangeMadinahHotel
                    )
                }
            }

            SectionHeader(includedTitle, eyebrow: "iumrah", subtitle: nil)
            includedServicesCard
        }
    }

    private var includedServicesCard: some View {
        VStack(spacing: 0) {
            includedRow(
                icon: "car.fill",
                title: localized("Трансфер по маршруту", "Route transfer", "Yo‘nalish transferi", "Йўналиш трансфери"),
                subtitle: localized("Аэропорт, отели и ключевые точки поездки", "Airport, hotels and key trip points", "Aeroport, mehmonxonalar va asosiy nuqtalar", "Аэропорт, меҳмонхоналар ва асосий нуқталар")
            )

            Divider().padding(.leading, 58)

            includedRow(
                icon: "person.badge.shield.checkmark.fill",
                title: localized("iumrah Guide", "iumrah Guide", "iumrah Guide", "iumrah Guide"),
                subtitle: guideSubtitle
            )

            Divider().padding(.leading, 58)

            if session.ziyaratMakkahEnabled || session.ziyaratMadinahEnabled {
                includedRow(
                    icon: "map.fill",
                    title: localized("Зияраты", "Ziyarats", "Ziyoratlar", "Зиёратлар"),
                    subtitle: ziyaratSubtitle
                )
                Divider().padding(.leading, 58)
            }

            if session.esimEnabled {
                includedRow(
                    icon: "simcard.fill",
                    title: "iumrah eSIM",
                    subtitle: localized("Связь в Саудовской Аравии внутри поездки", "Connectivity in Saudi Arabia inside your trip", "Saudiya Arabistonida safar ichidagi aloqa", "Саудия Арабистонида сафар ичидаги алоқа")
                )
                Divider().padding(.leading, 58)
            }

            includedRow(
                icon: "heart.fill",
                title: "iumrah Care",
                subtitle: localized("Поддержка по поездке и бронированию", "Trip and booking support", "Safar va bron bo‘yicha yordam", "Сафар ва брон бўйича ёрдам")
            )

            if session.booking.customization?.meals == true {
                Divider().padding(.leading, 58)
                includedRow(
                    icon: "fork.knife",
                    title: localized("Питание", "Meals", "Ovqatlanish", "Овқатланиш"),
                    subtitle: localized("Включено по выбранной категории пакета", "Included according to your package category", "Tanlangan paket toifasi bo‘yicha kiritilgan", "Танланган пакет тоифаси бўйича киритилган")
                )
            }
        }
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    private func includedRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            IumrahIconBadge(
                systemName: icon,
                role: role(for: icon),
                size: 44,
                symbolSize: 17,
                cornerRadius: 15
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func role(for icon: String) -> IumrahIconRole {
        if icon.contains("car") { return .transfer }
        if icon.contains("simcard") { return .connectivity }
        if icon.contains("heart") { return .care }
        if icon.contains("map") { return .location }
        if icon.contains("person") { return .profile }
        return .umrah
    }

    private var flightsTitle: String { localized("Авиабилеты", "Flights", "Aviachiptalar", "Авиачипталар") }
    private var hotelsTitle: String { localized("Отели", "Hotels", "Mehmonxonalar", "Меҳмонхоналар") }
    private var includedTitle: String { localized("Что включено", "What's included", "Nimalar kiradi", "Нималар киради") }
    private var outboundTitle: String { localized("Туда", "Outbound", "Borish", "Бориш") }
    private var returnTitle: String { localized("Обратно", "Return", "Qaytish", "Қайтиш") }

    private var guideSubtitle: String {
        if let guide = session.guide?.displayName, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localized("Гид: \(guide)", "Guide: \(guide)", "Gid: \(guide)", "Гид: \(guide)")
        }
        return localized("Сопровождение и координация поездки", "Journey guidance and coordination", "Safarni kuzatish va muvofiqlashtirish", "Сафарни кузатиш ва мувофиқлаштириш")
    }

    private var ziyaratSubtitle: String {
        var cities: [String] = []
        if session.ziyaratMakkahEnabled { cities.append(L10n.city("Makkah", settings.language)) }
        if session.ziyaratMadinahEnabled { cities.append(L10n.city("Madinah", settings.language)) }
        return cities.joined(separator: " · ")
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

private struct BookingFlightFirstLegCard: View {
    let flight: FlightOffer
    let direction: String
    let language: AppSettingsStore.Language
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                    expanded.toggle()
                }
                IumrahHaptics.selection()
            } label: {
                HStack(spacing: 14) {
                    AirlineLogoView(airlineCode: flight.airlineCode, size: 50)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(direction.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("\(flight.origin) → \(flight.destination)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(flight.airline) · \(flight.flightNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("\(day(flight.departureAt)) · \(clock(flight.departureAt))")
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

            if expanded {
                Divider().padding(.vertical, 14)
                VStack(spacing: 11) {
                    fact(localized("Аэропорт вылета", "Departure airport", "Jo‘nash aeroporti", "Жўнаш аэропорти"), airportText(flight.origin))
                    fact(localized("Аэропорт прилёта", "Arrival airport", "Yetib borish aeroporti", "Етиб бориш аэропорти"), airportText(flight.destination))
                    fact(localized("Вылет", "Departure", "Jo‘nash", "Жўнаш"), fullDateTime(flight.departureAt))
                    fact(localized("Прилёт", "Arrival", "Yetib kelish", "Етиб келиш"), fullDateTime(flight.arrivalAt))
                    fact(localized("В пути", "Duration", "Yo‘lda", "Йўлда"), durationText(flight.durationMinutes))
                    fact(localized("Класс", "Cabin", "Klass", "Класс"), nonBlank(flight.cabinClass)?.capitalized ?? "—")
                    fact(localized("Багаж", "Baggage", "Bagaj", "Багаж"), baggageText)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .iumrahCard()
    }

    private func nonBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func fact(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
        }
    }

    private var directText: String {
        switch language {
        case .russian: return flight.stops == 0 ? "прямой" : "\(flight.stops) пересад."
        case .english: return flight.stops == 0 ? "direct" : "\(flight.stops) stops"
        case .uzbek: return flight.stops == 0 ? "to‘g‘ridan-to‘g‘ri" : "\(flight.stops) ulanish"
        case .uzbekCyrillic: return flight.stops == 0 ? "тўғридан-тўғри" : "\(flight.stops) уланиш"
        }
    }

    private var baggageText: String {
        guard let baggage = flight.baggage else { return "—" }
        var parts: [String] = []
        if let carry = baggage.carryOn { parts.append("\(carry) kg") }
        if let checked = baggage.checked { parts.append("\(checked) kg") }
        return parts.isEmpty ? "—" : parts.joined(separator: " + ")
    }

    private func airportText(_ code: String) -> String {
        if let airport = FlightReferenceCatalog.airport(code) {
            return "\(airport.city) · \(airport.name) · \(code.uppercased())"
        }
        return code.uppercased()
    }

    private func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func fullDateTime(_ date: Date) -> String {
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

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct BookingFlightFirstHotelCard: View {
    let hotel: BookingHotelSelectionSnapshot
    let nights: Int
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
                        if let imageURL = nonBlank(hotel.coverImageURL) {
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
                        Text(hotel.hotelName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(L10n.city(hotel.city, language))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Label(nightsText, systemImage: "moon.stars.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        HStack(spacing: 6) {
                            Image(systemName: "bed.double.fill")
                                .font(.caption)
                            Text(nonBlank(hotel.roomName) ?? chooseRoomText)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(nonBlank(hotel.roomName) == nil ? Color.secondary : Color.primary)
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

    private var nightsText: String {
        switch language {
        case .russian: return "\(nights) ноч."
        case .english: return "\(nights) nights"
        case .uzbek: return "\(nights) tun"
        case .uzbekCyrillic: return "\(nights) тун"
        }
    }

    private var chooseRoomText: String {
        switch language {
        case .russian: return "Открыть отель"
        case .english: return "Open hotel"
        case .uzbek: return "Mehmonxonani ochish"
        case .uzbekCyrillic: return "Меҳмонхонани очиш"
        }
    }

    private func nonBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension StoredBookingSession {
    var ziyaratMakkahEnabled: Bool {
        ziyaratMakkahOverride ?? booking.customization?.ziyaratMakkah ?? false
    }

    var ziyaratMadinahEnabled: Bool {
        ziyaratMadinahOverride ?? booking.customization?.ziyaratMadinah ?? false
    }

    var esimEnabled: Bool {
        esimOverride ?? booking.customization?.esim ?? false
    }
}
