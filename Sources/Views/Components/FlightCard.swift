import SwiftUI

/// Consumer flight card for the Umrah package flow.
///
/// The customer sees only how this flight changes the package price.
/// Internal pricing/source details are intentionally kept out of the client UI.
struct FlightCard: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let offer: FlightOffer
    let isSelected: Bool
    var isRecommended: Bool = false
    var travelerCount: Int = 1
    var packagePricePerPerson: Decimal? = nil
    var referencePackagePricePerPerson: Decimal? = nil
    var usesProvisionalOppositeLeg: Bool = false
    var isPackagePriceLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            timingRow
            details
            Divider().opacity(0.55)
            bottomMeta
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(isSelected ? Color.primary : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.7 : 0.8)
        }
        .shadow(color: Color.primary.opacity(0.045), radius: 14, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            AirlineLogoView(airlineCode: offer.primaryAirlineCode, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(offer.airlinesSummary)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !offer.flightNumbersSummary.isEmpty {
                    Text(offer.flightNumbersSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if isPackagePriceLoading && packagePricePerPerson == nil {
                    ProgressView().controlSize(.small)
                } else {
                    Text(deltaDisplay)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Text(deltaLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 108, alignment: .trailing)
            }
        }
    }

    private var timingRow: some View {
        HStack(alignment: .center, spacing: 10) {
            timeBlock(date: offer.departureAt, code: offer.origin, alignment: .leading, isArrival: false)
                .frame(width: 82, alignment: .leading)

            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Rectangle().frame(height: 1.5)
                    IumrahInlineIcon(systemName: "airplane", role: .travel, size: 12)
                        .rotationEffect(.degrees(0))
                    Rectangle().frame(height: 1.5)
                }
                .foregroundStyle(.secondary.opacity(0.72))

                Text(durationText(offer.durationMinutes))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)

            timeBlock(date: offer.arrivalAt, code: offer.destination, alignment: .trailing, isArrival: true)
                .frame(width: 82, alignment: .trailing)
        }
    }

    private func timeBlock(date: Date, code: String, alignment: HorizontalAlignment, isArrival: Bool) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 2) {
                if isArrival { Spacer(minLength: 0) }
                Text(time(date))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if isArrival && arrivesNextDay {
                    Text("+1")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                        .baselineOffset(7)
                }
                if !isArrival { Spacer(minLength: 0) }
            }
            Text(code)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
            Text(airportCity(code))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(stopAndRouteLabel)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if isRecommended {
                    Text(recommendedLabel)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary)
                        .foregroundStyle(Color.iumrahCardBackground)
                        .clipShape(Capsule())
                }

                if isSelected {
                    IumrahInlineIcon(systemName: "checkmark.circle.fill", role: .success, size: 15)
                }
            }

            if let layover = offer.layovers.first {
                Label(layoverText(layover), systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if let connection = offer.connectionAirports?.first {
                Label(connectionText(connection), systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var bottomMeta: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                IumrahInlineIcon(systemName: "seatbelt", role: .travel, size: 11)
                Text(cabinLabel)
            }
            if let carry = offer.baggage?.carryOn, carry > 0 {
                HStack(spacing: 4) {
                    IumrahInlineIcon(systemName: "bag", role: .booking, size: 11)
                    Text("×\(carry)")
                }
            }
            if let checked = offer.baggage?.checked, checked > 0 {
                HStack(spacing: 4) {
                    IumrahInlineIcon(systemName: "suitcase", role: .booking, size: 11)
                    Text("×\(checked)")
                }
            }
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var packageDelta: Decimal? {
        guard let current = packagePricePerPerson,
              let baseline = referencePackagePricePerPerson else { return nil }
        return current - baseline
    }

    private var deltaDisplay: String {
        guard let delta = packageDelta else { return "—" }
        let rounded = abs(NSDecimalNumber(decimal: delta).doubleValue).rounded()
        let number = NumberFormatter()
        number.numberStyle = .decimal
        number.maximumFractionDigits = 0
        number.minimumFractionDigits = 0
        let body = number.string(from: NSNumber(value: rounded)) ?? String(Int(rounded))
        if delta > 0 { return "+$\(body)" }
        if delta < 0 { return "−$\(body)" }
        return "$0"
    }

    private var deltaLabel: String {
        switch settings.language {
        case .russian: return "к пакету / 1 человек"
        case .turkish: return TurkishLocalization.phrase("package difference / traveler")
        case .indonesian, .malay, .english: return "package difference / traveler"
        case .uzbek: return "paket farqi / 1 kishi"
        case .uzbekCyrillic: return "пакет фарқи / 1 киши"
        }
    }

    private var stopAndRouteLabel: String {
        switch settings.language {
        case .russian:
            return "\(stopLabel) · \(offer.origin) → \(offer.destination)"
        case .turkish:
            return "\(stopLabel) · \(offer.origin) → \(offer.destination)"
        case .indonesian, .malay, .english:
            return "\(stopLabel) · \(offer.origin) → \(offer.destination)"
        case .uzbek, .uzbekCyrillic:
            return "\(stopLabel) · \(offer.origin) → \(offer.destination)"
        }
    }

    private var stopLabel: String {
        switch settings.language {
        case .russian:
            return offer.stops == 0 ? "прямой" : offer.stops == 1 ? "1 пересадка" : "\(offer.stops) пересадки"
        case .turkish:
            return offer.stops == 0 ? "nonstop" : offer.stops == 1 ? "1 aktarma" : "\(offer.stops) aktarma"
        case .indonesian, .malay, .english:
            return offer.stops == 0 ? "nonstop" : offer.stops == 1 ? "1 stop" : "\(offer.stops) stops"
        case .uzbek:
            return offer.stops == 0 ? "to‘g‘ridan-to‘g‘ri" : "\(offer.stops) ta to‘xtash"
        case .uzbekCyrillic:
            return offer.stops == 0 ? "тўғридан-тўғри" : "\(offer.stops) та тўхташ"
        }
    }

    private var recommendedLabel: String {
        switch settings.language {
        case .russian: return "Рекомендуем"
        case .turkish: return TurkishLocalization.phrase("Recommended")
        case .indonesian, .malay, .english: return "Recommended"
        case .uzbek: return "Tavsiya"
        case .uzbekCyrillic: return "Тавсия"
        }
    }

    private var cabinLabel: String {
        let value = offer.cabinClass?.lowercased() ?? "economy"
        switch (value, settings.language) {
        case ("business", .russian): return "Бизнес"
        case ("first", .russian): return "Первый"
        case ("premium_economy", .russian): return "Премиум эконом"
        case (_, .russian): return "Эконом"
        case ("business", .turkish): return TurkishLocalization.phrase("Business")
        case ("business", .indonesian), ("business", .english): return "Business"
        case ("first", .turkish): return TurkishLocalization.phrase("First")
        case ("first", .indonesian), ("first", .english): return "First"
        case ("premium_economy", .turkish): return TurkishLocalization.phrase("Premium economy")
        case ("premium_economy", .indonesian), ("premium_economy", .english): return "Premium economy"
        case (_, .turkish): return TurkishLocalization.phrase("Economy")
        case (_, .indonesian), (_, .english): return "Economy"
        case ("business", .uzbek), ("business", .uzbekCyrillic): return "Business"
        case ("first", .uzbek), ("first", .uzbekCyrillic): return "First"
        case ("premium_economy", .uzbek), ("premium_economy", .uzbekCyrillic): return "Premium economy"
        default: return "Economy"
        }
    }

    private var arrivesNextDay: Bool {
        let calendar = Calendar(identifier: .gregorian)
        return !calendar.isDate(offer.departureAt, inSameDayAs: offer.arrivalAt)
    }

    private func layoverText(_ layover: FlightLayover) -> String {
        let city = layover.airport.displayCity
        switch settings.language {
        case .russian: return "Пересадка · \(city) (\(layover.airport.code))"
        case .turkish: return TurkishLocalization.phrase("Layover · \(city) (\(layover.airport.code))")
        case .indonesian, .malay, .english: return "Layover · \(city) (\(layover.airport.code))"
        case .uzbek: return "To‘xtash · \(city) (\(layover.airport.code))"
        case .uzbekCyrillic: return "Тўхташ · \(city) (\(layover.airport.code))"
        }
    }

    private func connectionText(_ airport: FlightAirportSnapshot) -> String {
        switch settings.language {
        case .russian: return "Пересадка · \(airport.displayCity) (\(airport.code))"
        case .turkish: return TurkishLocalization.phrase("Connection · \(airport.displayCity) (\(airport.code))")
        case .indonesian, .malay, .english: return "Connection · \(airport.displayCity) (\(airport.code))"
        case .uzbek: return "Ulanish · \(airport.displayCity) (\(airport.code))"
        case .uzbekCyrillic: return "Уланиш · \(airport.displayCity) (\(airport.code))"
        }
    }

    private func airportCity(_ code: String) -> String {
        FlightReferenceCatalog.airport(code)?.city ?? code
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func durationText(_ minutes: Int) -> String {
        let hours = max(0, minutes) / 60
        let rest = max(0, minutes) % 60
        switch settings.language {
        case .russian: return rest == 0 ? "\(hours)ч" : "\(hours)ч \(rest)м"
        case .turkish: return rest == 0 ? "\(hours)h" : "\(hours) sa. \(rest) dk."
        case .indonesian, .malay, .english: return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
        case .uzbek: return rest == 0 ? "\(hours)soat" : "\(hours)soat \(rest)d"
        case .uzbekCyrillic: return rest == 0 ? "\(hours)соат" : "\(hours)соат \(rest)д"
        }
    }
}
