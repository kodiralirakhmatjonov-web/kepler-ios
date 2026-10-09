import SwiftUI

struct FlightCandidatePreviewCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let candidate: LiveFlightCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center, spacing: 11) {
                AirlineLogoView(airlineCode: candidate.airlineCode, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.airline)
                        .font(.headline.weight(.semibold))
                    Text(flightNumberLabel)
                        .font(.subheadline.weight(.bold))
                    Text(dateText(candidate.departureAt, zone: candidate.segments?.first?.origin.timeZoneIdentifier))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                ProgressView()
                    .controlSize(.small)
            }

            HStack(alignment: .center, spacing: 12) {
                endpoint(code: candidate.origin, date: candidate.departureAt, trailing: false)

                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        Circle().frame(width: 4, height: 4)
                        Rectangle().frame(height: 1)
                        Image(systemName: "airplane")
                            .font(.caption2)
                        Rectangle().frame(height: 1)
                        Circle().frame(width: 4, height: 4)
                    }
                    .foregroundStyle(.tertiary)

                    Text(stopText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)

                endpoint(code: candidate.destination, date: candidate.arrivalAt, trailing: true)
            }

            Divider()

            HStack(spacing: 10) {
                IumrahIconBadge(
                    systemName: "function",
                    role: .payment,
                    size: 28,
                    symbolSize: 12,
                    shape: .circle
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(pricingTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(pricingSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .iumrahCard()
        .accessibilityElement(children: .combine)
    }

    private func endpoint(code: String, date: Date, trailing: Bool) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(timeText(date, airportCode: code))
                .font(.title3.monospacedDigit().weight(.bold))
            Text(code)
                .font(.caption.weight(.semibold))
            if let airport = FlightReferenceCatalog.airport(code) {
                Text(airport.city)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 82, alignment: trailing ? .trailing : .leading)
    }

    private var flightNumberLabel: String {
        switch settings.language {
        case .russian: return "Рейс \(candidate.flightNumber)"
        case .turkish: return TurkishLocalization.phrase("Flight \(candidate.flightNumber)")
        case .indonesian, .english: return "Flight \(candidate.flightNumber)"
        case .uzbek: return "Reys \(candidate.flightNumber)"
        case .uzbekCyrillic: return "Рейс \(candidate.flightNumber)"
        }
    }

    private var stopText: String {
        if candidate.stops == 0 {
            return L10n.text("flight_direct", settings.language)
        }
        let base = L10n.format("flight_stops", settings.language, candidate.stops)
        guard let airport = candidate.connectionAirports?.first else { return base }
        let country = FlightReferenceCatalog.airportCountry(airport.code)
        return [base, airport.code, country].compactMap { $0 }.joined(separator: " · ")
    }

    private var pricingTitle: String {
        switch settings.language {
        case .russian: return "Проверяем тариф"
        case .turkish: return TurkishLocalization.phrase("Verifying fare")
        case .indonesian, .english: return "Verifying fare"
        case .uzbek: return "Tarif tekshirilmoqda"
        case .uzbekCyrillic: return "Тариф текширилмоқда"
        }
    }

    private var pricingSubtitle: String {
        switch settings.language {
        case .russian: return "Рейс найден. Подтверждаем цену и детали у источника."
        case .turkish: return TurkishLocalization.phrase("Flight found. Verifying the fare and details with the source.")
        case .indonesian, .english: return "Flight found. Verifying the fare and details with the source."
        case .uzbek: return "Reys topildi. Tarif va tafsilotlar manbada tekshirilmoqda."
        case .uzbekCyrillic: return "Рейс топилди. Тариф ва тафсилотлар манбада текширилмоқда."
        }
    }

    private func timeText(_ value: Date, airportCode: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = FlightReferenceCatalog.timeZone(for: airportCode)
        return formatter.string(from: value)
    }

    private func dateText(_ value: Date, zone: String?) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMM yyyy"
        if let zone, let timeZone = TimeZone(identifier: zone) { formatter.timeZone = timeZone }
        return formatter.string(from: value)
    }
}

struct FlightSearchProgressCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let isSearching: Bool
    let hasResults: Bool
    var liveStatus: GeneratorSearchStage? = nil
    let onContinue: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 13) {
                IumrahIconBadge(
                    systemName: isSearching ? "magnifyingglass" : "arrow.clockwise",
                    role: isSearching ? .search : .travel,
                    size: 44,
                    symbolSize: 18,
                    cornerRadius: 15
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(liveStatus?.text(settings.language) ?? subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if isSearching {
                HStack(spacing: 7) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(Color.primary.opacity(pulse ? 0.14 + Double(index) * 0.055 : 0.40 - Double(index) * 0.045))
                            .frame(maxWidth: .infinity)
                            .frame(height: 5)
                    }
                }
                .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: pulse)
            } else {
                Button(action: onContinue) {
                    HStack {
                        Text(continueTitle)
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
        .onAppear { pulse = true }
    }

    private var title: String {
        switch settings.language {
        case .russian: return isSearching ? "Продолжаем поиск" : "Ищем ещё варианты"
        case .turkish: return isSearching ? "Daha fazla seçenek aranıyor" : "Daha fazla seçenek bul"
        case .indonesian, .english: return isSearching ? "Searching for more" : "Find more options"
        case .uzbek: return isSearching ? "Qidiruv davom etmoqda" : "Yana variant izlash"
        case .uzbekCyrillic: return isSearching ? "Қидирув давом этмоқда" : "Яна вариант излаш"
        }
    }

    private var subtitle: String {
        switch settings.language {
        case .russian:
            return hasResults
                ? "Найденные рейсы уже можно сравнивать. Новые варианты появятся здесь автоматически."
                : "Получаем актуальные рейсы. Первый подтверждённый вариант появится сразу."
        case .turkish:
            return hasResults
                ? "Doğrulanmış uçuşları şimdiden karşılaştırabilirsiniz. Yeni seçenekler otomatik olarak görünür."
                : "Güncel uçuşlar getiriliyor. Doğrulanan ilk seçenek hemen görünecek."
        case .indonesian, .english:
            return hasResults
                ? "You can already compare verified flights. New options will appear automatically."
                : "Fetching current flights. The first verified option will appear immediately."
        case .uzbek:
            return hasResults
                ? "Topilgan reyslarni hozirdanoq solishtiring. Yangi variantlar avtomatik qo‘shiladi."
                : "Dolzarb reyslarni olyapmiz. Birinchi tasdiqlangan variant darhol chiqadi."
        case .uzbekCyrillic:
            return hasResults
                ? "Топилган рейсларни ҳозирданоқ солиштиринг. Янги вариантлар автоматик қўшилади."
                : "Долзарб рейсларни оляпмиз. Биринчи тасдиқланган вариант дарҳол чиқади."
        }
    }

    private var continueTitle: String {
        switch settings.language {
        case .russian: return "Продолжить поиск"
        case .turkish: return TurkishLocalization.phrase("Continue search")
        case .indonesian, .english: return "Continue search"
        case .uzbek: return "Qidiruvni davom ettirish"
        case .uzbekCyrillic: return "Қидирувни давом эттириш"
        }
    }
}

struct FlightResultRowModel: Identifiable {
    let id: String
    let candidate: LiveFlightCandidate?
    let offer: FlightOffer?

    var departureAt: Date { offer?.departureAt ?? candidate?.departureAt ?? .distantFuture }

    static func merge(candidates: [LiveFlightCandidate], offers: [FlightOffer]) -> [FlightResultRowModel] {
        // UI boundary repeats the model/service validation intentionally. Even if
        // an old in-memory offer survived an app upgrade, an aggregator/reference
        // row can never be rendered on the production flight screen.
        let verifiedCandidates = candidates.filter(\.isDisplayableCandidate)
        let verifiedOffers = offers.filter(\.isVerifiedForBooking)

        let candidateByLeg = Dictionary(
            verifiedCandidates.map { ($0.deduplicationKey, $0) },
            uniquingKeysWith: { existing, replacement in
                replacement.observedAt > existing.observedAt ? replacement : existing
            }
        )
        var output = verifiedOffers.map { offer in
            FlightResultRowModel(
                id: offer.resultIdentityKey,
                candidate: candidateByLeg[offer.deduplicationKey],
                offer: offer
            )
        }
        let pricedLegKeys = Set(verifiedOffers.map(\.deduplicationKey))
        output.append(contentsOf: verifiedCandidates.compactMap { candidate in
            guard !pricedLegKeys.contains(candidate.deduplicationKey) else { return nil }
            return FlightResultRowModel(id: candidate.id, candidate: candidate, offer: nil)
        })
        return output.sorted { lhs, rhs in
            let calendar = Calendar.current
            let leftDay = calendar.startOfDay(for: lhs.departureAt)
            let rightDay = calendar.startOfDay(for: rhs.departureAt)
            if leftDay != rightDay { return leftDay < rightDay }
            if let lp = lhs.offer?.totalPackagePrice, let rp = rhs.offer?.totalPackagePrice, lp != rp { return lp < rp }
            if lhs.offer != nil, rhs.offer == nil { return true }
            if rhs.offer != nil, lhs.offer == nil { return false }
            return lhs.departureAt < rhs.departureAt
        }
    }
}
