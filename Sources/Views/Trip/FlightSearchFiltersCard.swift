import SwiftUI

struct FlightSearchFiltersCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Binding var filters: FlightSearchFilters
    let infantCount: Int
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    IumrahIconBadge(
                        systemName: "slider.horizontal.3",
                        role: .settings,
                        size: 38,
                        symbolSize: 16,
                        cornerRadius: 13
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy(.title))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 20) {
                    filterSection(copy(.cabin)) {
                        horizontalChips(FlightCabinClass.allCases, selection: filters.cabinClass) { value in
                            update { $0.cabinClass = value }
                        } label: { cabinTitle($0) }
                    }

                    filterSection(copy(.stops)) {
                        horizontalChips(FlightStopsPreference.allCases, selection: filters.stops) { value in
                            update { $0.stops = value }
                        } label: { stopsTitle($0) }
                    }

                    filterSection(copy(.time)) {
                        HStack(spacing: 10) {
                            menuTile(title: copy(.departure), value: timeTitle(filters.departureWindow)) {
                                ForEach(FlightTimeWindow.allCases) { value in
                                    Button(timeTitle(value)) { update { $0.departureWindow = value } }
                                }
                            }
                            menuTile(title: copy(.arrival), value: timeTitle(filters.arrivalWindow)) {
                                ForEach(FlightTimeWindow.allCases) { value in
                                    Button(timeTitle(value)) { update { $0.arrivalWindow = value } }
                                }
                            }
                        }
                    }

                    filterSection(copy(.baggage)) {
                        HStack(spacing: 10) {
                            countMenu(title: copy(.carryOn), value: filters.minCarryOnBags) { value in
                                update { $0.minCarryOnBags = value }
                            }
                            countMenu(title: copy(.checked), value: filters.minCheckedBags) { value in
                                update { $0.minCheckedBags = value }
                            }
                        }
                    }

                    filterSection(copy(.price)) {
                        HStack {
                            Text("$")
                                .font(.title3.weight(.bold))
                            TextField(copy(.noLimit), text: maxPriceBinding)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .font(.title3.monospacedDigit().weight(.semibold))
                            Spacer()
                            if filters.maxPriceUSD != nil {
                                Button {
                                    update { $0.maxPriceUSD = nil }
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: true)
                    }

                    filterSection(copy(.airlines)) {
                        airlineModePicker
                        if airlineMode != .all {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(FlightReferenceCatalog.filterAirlines, id: \.iata) { airline in
                                        let selected = selectedAirlineCodes.contains(airline.iata)
                                        Button {
                                            toggleAirline(airline.iata)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(airline.iata).font(.caption.weight(.bold))
                                                Text(airline.name).font(.caption.weight(.semibold)).lineLimit(1)
                                                if selected { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                                            }
                                            .padding(.horizontal, 11)
                                            .frame(height: 36)
                                            .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                                            .iumrahGlass(in: Capsule(), interactive: true, tint: selected ? Color.primary : nil)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { !filters.allowSelfTransfer },
                        set: { protected in update { $0.allowSelfTransfer = !protected } }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(copy(.protectedConnections)).font(.subheadline.weight(.semibold))
                            Text(copy(.protectedConnectionsBody)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)

                    if infantCount > 0 {
                        filterSection(copy(.infant)) {
                            horizontalChips(FlightInfantSeating.allCases, selection: filters.infantSeating) { value in
                                update { $0.infantSeating = value }
                            } label: { $0 == .lap ? copy(.lap) : copy(.seat) }
                        }
                    }

                    Button(copy(.reset)) {
                        filters = .default
                        IumrahHaptics.selection()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .iumrahCard()
    }

    @ViewBuilder
    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func horizontalChips<T: Hashable & Identifiable>(
        _ values: [T],
        selection: T,
        action: @escaping (T) -> Void,
        label: @escaping (T) -> String
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values) { value in
                    Button { action(value) } label: {
                        Text(label(value))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 13)
                            .frame(height: 38)
                            .foregroundStyle(selection == value ? Color(uiColor: .systemBackground) : Color.primary)
                            .iumrahGlass(in: Capsule(), interactive: true, tint: selection == value ? Color.primary : nil)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func menuTile<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                HStack {
                    Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 54)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: true)
        }
    }

    private func countMenu(title: String, value: Int, action: @escaping (Int) -> Void) -> some View {
        Menu {
            ForEach(0...2, id: \.self) { count in
                Button(count == 0 ? copy(.any) : "\(count)+") { action(count) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                HStack {
                    Text(value == 0 ? copy(.any) : "\(value)+").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Spacer()
                    IumrahInlineIcon(systemName: "suitcase.fill", role: .travel, size: 12)
                }
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 54)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: true)
        }
    }

    private var airlineModePicker: some View {
        HStack(spacing: 7) {
            ForEach(AirlineMode.allCases) { mode in
                Button {
                    setAirlineMode(mode)
                } label: {
                    Text(airlineModeTitle(mode))
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .foregroundStyle(airlineMode == mode ? Color(uiColor: .systemBackground) : Color.primary)
                        .iumrahGlass(in: Capsule(), interactive: true, tint: airlineMode == mode ? Color.primary : nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private enum AirlineMode: String, CaseIterable, Identifiable { case all, include, exclude; var id: String { rawValue } }
    private var airlineMode: AirlineMode {
        if !filters.normalizedAirlinesInclude.isEmpty { return .include }
        if !filters.normalizedAirlinesExclude.isEmpty { return .exclude }
        return .all
    }
    private var selectedAirlineCodes: [String] {
        airlineMode == .exclude ? filters.normalizedAirlinesExclude : filters.normalizedAirlinesInclude
    }

    private func setAirlineMode(_ mode: AirlineMode) {
        let existing = selectedAirlineCodes
        update { value in
            switch mode {
            case .all:
                value.airlinesInclude = []
                value.airlinesExclude = []
            case .include:
                value.airlinesInclude = existing
                value.airlinesExclude = []
            case .exclude:
                value.airlinesExclude = existing
                value.airlinesInclude = []
            }
        }
    }

    private func toggleAirline(_ code: String) {
        var values = Set(selectedAirlineCodes)
        if values.contains(code) { values.remove(code) } else { values.insert(code) }
        let sorted = values.sorted()
        update { value in
            if airlineMode == .exclude { value.airlinesExclude = sorted; value.airlinesInclude = [] }
            else { value.airlinesInclude = sorted; value.airlinesExclude = [] }
        }
    }

    private func update(_ change: (inout FlightSearchFilters) -> Void) {
        var value = filters
        change(&value)
        filters = value
        IumrahHaptics.selection()
    }

    private var maxPriceBinding: Binding<String> {
        Binding(
            get: { filters.maxPriceUSD.map(String.init) ?? "" },
            set: { raw in
                let digits = raw.filter(\.isNumber)
                var value = filters
                value.maxPriceUSD = digits.isEmpty ? nil : Int(digits)
                filters = value
            }
        )
    }

    private var summary: String {
        var values = [cabinTitle(filters.cabinClass), stopsTitle(filters.stops)]
        if filters.minCheckedBags > 0 { values.append("\(filters.minCheckedBags)+ \(copy(.checkedShort))") }
        if let max = filters.maxPriceUSD { values.append("≤ $\(max)") }
        return values.joined(separator: " · ")
    }

    private func cabinTitle(_ value: FlightCabinClass) -> String {
        switch value {
        case .economy: return copy(.economy)
        case .premiumEconomy: return copy(.premium)
        case .business: return copy(.business)
        case .first: return copy(.first)
        }
    }
    private func stopsTitle(_ value: FlightStopsPreference) -> String {
        switch value {
        case .any: return copy(.anyStops)
        case .nonstop: return copy(.direct)
        case .upToOne: return copy(.oneStop)
        case .upToTwo: return copy(.twoStops)
        }
    }
    private func timeTitle(_ value: FlightTimeWindow) -> String {
        switch value {
        case .any: return copy(.any)
        case .night: return copy(.night)
        case .morning: return copy(.morning)
        case .afternoon: return copy(.afternoon)
        case .evening: return copy(.evening)
        }
    }
    private func airlineModeTitle(_ mode: AirlineMode) -> String {
        switch mode { case .all: return copy(.allAirlines); case .include: return copy(.only); case .exclude: return copy(.exclude) }
    }

    private enum CopyKey { case title, cabin, stops, time, departure, arrival, baggage, carryOn, checked, price, noLimit, airlines, protectedConnections, protectedConnectionsBody, infant, lap, seat, reset, any, economy, premium, business, first, anyStops, direct, oneStop, twoStops, night, morning, afternoon, evening, allAirlines, only, exclude, checkedShort }
    private func copy(_ key: CopyKey) -> String {
        switch settings.language {
        case .russian:
            switch key {
            case .title: return "Параметры перелёта"; case .cabin: return "Класс"; case .stops: return "Пересадки"; case .time: return "Время"; case .departure: return "Вылет"; case .arrival: return "Прилёт"; case .baggage: return "Багаж включён"; case .carryOn: return "Ручная кладь"; case .checked: return "Багаж"; case .price: return "Максимальная цена перелёта"; case .noLimit: return "Без лимита"; case .airlines: return "Авиакомпании"; case .protectedConnections: return "Без отдельных билетов"; case .protectedConnectionsBody: return "Исключать self-transfer, когда источник может его определить"; case .infant: return "Младенцы"; case .lap: return "На руках"; case .seat: return "Отдельное место"; case .reset: return "Сбросить фильтры"; case .any: return "Любое"; case .economy: return "Эконом"; case .premium: return "Премиум"; case .business: return "Бизнес"; case .first: return "Первый"; case .anyStops: return "Любые"; case .direct: return "Прямой"; case .oneStop: return "До 1"; case .twoStops: return "До 2"; case .night: return "Ночь"; case .morning: return "Утро"; case .afternoon: return "День"; case .evening: return "Вечер"; case .allAirlines: return "Все"; case .only: return "Только"; case .exclude: return "Исключить"; case .checkedShort: return "багаж" }
        case .turkish:
            switch key {
            case .title: return "Uçuş tercihleri"; case .cabin: return "Kabin sınıfı"; case .stops: return "Aktarma"; case .time: return "Saat"; case .departure: return "Kalkış"; case .arrival: return "Varış"; case .baggage: return "Dahil bagajlar"; case .carryOn: return "Kabin bagajı"; case .checked: return "Checked"; case .price: return "En yüksek uçuş fiyatı"; case .noLimit: return "Sınır yok"; case .airlines: return "Havayolları"; case .protectedConnections: return "Ayrı bilet istemiyorum"; case .protectedConnectionsBody: return "Kendi imkânlarıyla aktarma gerektirdiği belirlenen rotaları hariç tut"; case .infant: return "Bebekler"; case .lap: return "Kucakta"; case .seat: return "Ayrı koltuk"; case .reset: return "Filtreleri sıfırla"; case .any: return "Any"; case .economy: return "Ekonomi"; case .premium: return "Premium"; case .business: return "Business"; case .first: return "Birinci sınıf"; case .anyStops: return "Any"; case .direct: return "Aktarmasız"; case .oneStop: return "En fazla 1"; case .twoStops: return "En fazla 2"; case .night: return "Gece"; case .morning: return "Morning"; case .afternoon: return "Afternoon"; case .evening: return "Evening"; case .allAirlines: return "Tümü"; case .only: return "Only"; case .exclude: return "Exclude"; case .checkedShort: return "bag" }
        case .indonesian, .english:
            switch key {
            case .title: return "Flight preferences"; case .cabin: return "Cabin"; case .stops: return "Stops"; case .time: return "Time"; case .departure: return "Departure"; case .arrival: return "Arrival"; case .baggage: return "Included bags"; case .carryOn: return "Carry-on"; case .checked: return "Checked"; case .price: return "Maximum flight price"; case .noLimit: return "No limit"; case .airlines: return "Airlines"; case .protectedConnections: return "No separate tickets"; case .protectedConnectionsBody: return "Exclude identifiable self-transfer itineraries"; case .infant: return "Infants"; case .lap: return "On lap"; case .seat: return "Own seat"; case .reset: return "Reset filters"; case .any: return "Any"; case .economy: return "Economy"; case .premium: return "Premium"; case .business: return "Business"; case .first: return "First"; case .anyStops: return "Any"; case .direct: return "Nonstop"; case .oneStop: return "Up to 1"; case .twoStops: return "Up to 2"; case .night: return "Night"; case .morning: return "Morning"; case .afternoon: return "Afternoon"; case .evening: return "Evening"; case .allAirlines: return "All"; case .only: return "Only"; case .exclude: return "Exclude"; case .checkedShort: return "bag" }
        case .uzbek, .uzbekCyrillic:
            switch key {
            case .title: return "Parvoz parametrlari"; case .cabin: return "Klass"; case .stops: return "To‘xtashlar"; case .time: return "Vaqt"; case .departure: return "Uchish"; case .arrival: return "Yetib kelish"; case .baggage: return "Bagaj"; case .carryOn: return "Qo‘l yuki"; case .checked: return "Bagaj"; case .price: return "Maksimal narx"; case .noLimit: return "Cheklovsiz"; case .airlines: return "Aviakompaniyalar"; case .protectedConnections: return "Alohida chiptalarsiz"; case .protectedConnectionsBody: return "Aniqlangan self-transfer variantlarini chiqarib tashlash"; case .infant: return "Chaqaloqlar"; case .lap: return "Qo‘lda"; case .seat: return "Alohida joy"; case .reset: return "Filtrlarni tozalash"; case .any: return "Istalgan"; case .economy: return "Ekonom"; case .premium: return "Premium"; case .business: return "Biznes"; case .first: return "Birinchi"; case .anyStops: return "Istalgan"; case .direct: return "To‘g‘ridan"; case .oneStop: return "1 gacha"; case .twoStops: return "2 gacha"; case .night: return "Tun"; case .morning: return "Ertalab"; case .afternoon: return "Kunduzi"; case .evening: return "Kechqurun"; case .allAirlines: return "Barchasi"; case .only: return "Faqat"; case .exclude: return "Chiqarish"; case .checkedShort: return "bagaj" }
        }
    }
}
