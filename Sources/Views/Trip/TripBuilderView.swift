import SwiftUI

struct TripBuilderView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    private enum CuratedDisplayMode: String, CaseIterable, Identifiable {
        case separate
        case roundTrip
        var id: String { rawValue }
    }

    private enum CuratedLegSelection {
        case outbound
        case inbound
    }

    @State private var showsDateCalendar = false
    @State private var curatedFlights: [CuratedFlightRecommendation] = []
    @State private var isLoadingCuratedFlights = false
    @State private var curatedDisplayMode: CuratedDisplayMode = .separate

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(0, proxy.size.width - (IumrahDesign.pagePadding * 2))

            ScrollView {
                VStack(spacing: 22) {
                    IumrahGeneratorHeader(stage: .trip)

                    intro
                    routeCard
                    datesCard
                    if journey.packageFlightPath == .publishedDirect && !journey.trip.isWeekendUmrah {
                        curatedFlightsSection
                    }
                    travelersCard
                    if journey.packageFlightPath != .publishedDirect {
                        FlightSearchFiltersCard(filters: flightFiltersBinding, infantCount: journey.trip.infants)
                    }
                    packageCard

                    NavigationLink {
                        PrimaryHotelView()
                    } label: {
                        Text(L10n.text("trip_continue_hotel", settings.language))
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                    .disabled(!canContinueFromBuilder)
                    .opacity(canContinueFromBuilder ? 1 : 0.45)
                }
                .frame(width: contentWidth, alignment: .top)
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 42)
                .frame(width: proxy.size.width)
            }
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .iumrahInternalNavigation(progress: .trip, showsGeneratorAmbient: true)
        .task(id: curatedFlightsQueryKey) {
            curatedDisplayMode = .separate
            await loadCuratedFlights()
        }
        .onChange(of: routeSelectionKey) { _, _ in
            guard !journey.trip.isWeekendUmrah else { return }
            journey.resetAfterTripChange()
            journey.packageFlightPath = .publishedDirect
        }
        .onAppear {
            // Package category is now the single hotel-level choice. This also
            // normalizes drafts created by builds where Standard defaulted to 4★.
            journey.selectPackageTier(journey.trip.packageTier)
            curatedDisplayMode = .separate

            // Production flow is always a complete Umrah journey: the pilgrim
            // chooses the outbound first and the compatible return afterwards.
            // Do not expose an internal ticket-type switch in the customer flow.
            if journey.trip.resolvedFlightTripType != .roundTrip {
                journey.resetAfterTripChange()
                journey.trip.flightTripType = .roundTrip
            } else if journey.trip.flightTripType == nil {
                journey.trip.flightTripType = .roundTrip
            }
            // The former week-wide discovery mode is retired from the customer flow.
            // Date discovery now happens in the cached OTA calendar without buying
            // seven provider searches at once.
            if journey.trip.flexibility.isFlexibleDayRange {
                journey.trip.flexibility = .exact
            }
            if journey.trip.isWeekendUmrah {
                journey.packageFlightPath = .weekend
                journey.trip.applyWeekendWindow(around: journey.trip.departureDate)
            }
        }
    }

    private var canContinueFromBuilder: Bool {
        guard journey.trip.canContinue else { return false }
        switch journey.packageFlightPath {
        case .publishedDirect:
            return journey.hasCompletePublishedFlightSelection
        case .flexibleDates:
            return !journey.trip.isWeekendUmrah
        case .weekend:
            return journey.trip.isWeekendUmrah
        }
    }

    private var routeSelectionKey: String {
        [
            journey.trip.originCode.uppercased(),
            journey.trip.scope.rawValue,
            journey.trip.arrivalAirport.rawValue
        ].joined(separator: "|")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("trip_intro_kicker", settings.language))
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(L10n.text("trip_intro_title", settings.language))
                .font(.system(size: 33, weight: .bold, design: .rounded))
                .tracking(-0.7)
            Text(L10n.text("trip_intro_body", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.text("trip_origin_title", settings.language), systemImage: "airplane.departure")
                .font(.headline)

            AirportSelectorButton(airport: $journey.trip.originAirport, fallbackCode: $journey.trip.origin)

            if journey.trip.isWeekendUmrah {
                weekendRouteSummary
            } else {
                Text(L10n.text("trip_destination_title", settings.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker(L10n.text("trip_route_picker", settings.language), selection: $journey.trip.scope) {
                    ForEach(JourneyScope.allCases) { scope in
                        Text(scope.title(settings.language)).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                if journey.trip.scope == .makkahAndMadinah {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("trip_arrival_title", settings.language))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker(L10n.text("trip_arrival_picker", settings.language), selection: $journey.trip.arrivalAirport) {
                            ForEach(SaudiArrivalAirport.allCases) { airport in
                                Text(airport.shortTitle(settings.language)).tag(airport)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(L10n.text(
                            journey.trip.arrivalAirport == .madinah ? "trip_arrival_madinah_hint" : "trip_arrival_jeddah_hint",
                            settings.language
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .iumrahCard()
    }

    private var weekendRouteSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                routeCode(journey.trip.originCode)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                routeCode("JED")
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                routeCode(journey.trip.originCode)
            }

            Text(L10n.format(
                "weekend_route_note",
                settings.language,
                journey.trip.originCode,
                journey.trip.originCode
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahRaisedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
    }

    private func routeCode(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .monospaced()
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(flightChoiceTitle, systemImage: "airplane")
                .font(.headline)

            Text(flightChoiceBody)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            dateModePicker

            if journey.packageFlightPath == .weekend || journey.trip.isWeekendUmrah {
                weekendDatesContent
            } else if journey.packageFlightPath == .flexibleDates {
                Button {
                    showsDateCalendar = true
                    IumrahHaptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        dateSummaryColumn(title: L10n.text("departure", settings.language), date: journey.trip.departureDate)
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        dateSummaryColumn(title: L10n.text("return", settings.language), date: journey.trip.returnDate)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 76)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
                }
                .buttonStyle(.plain)

                HStack(alignment: .top, spacing: 10) {
                    IumrahInlineIcon(
                        systemName: "calendar.badge.clock",
                        role: .payment,
                        size: 12
                    )
                    Text(flexibleDatesHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.green)
                    Text(publishedDirectHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .iumrahCard()
        .sheet(isPresented: $showsDateCalendar) {
            FlightDateCalendarView(
                trip: journey.trip,
                initialDeparture: journey.trip.departureDate,
                initialReturn: journey.trip.returnDate
            ) { result in
                journey.resetAfterTripChange()
                journey.trip.flexibility = .exact
                journey.trip.flightTripType = .roundTrip
                journey.trip.departureDate = result.departure
                journey.trip.returnDate = result.returnDate

                if let published = result.publishedSelection, published.isComplete {
                    journey.packageFlightPath = .publishedDirect
                    journey.selectedPublishedCompleteID = published.completeID
                    journey.selectedPublishedOutboundID = published.outboundID
                    journey.selectedPublishedReturnID = published.returnID
                    curatedDisplayMode = .separate
                } else {
                    journey.packageFlightPath = .flexibleDates
                    journey.clearPublishedFlightSelection()
                }
            }
            .environmentObject(settings)
        }
    }

    private var dateModePicker: some View {
        HStack(spacing: 8) {
            Button {
                guard journey.packageFlightPath != .publishedDirect || journey.trip.isWeekendUmrah else { return }
                journey.resetAfterTripChange()
                journey.packageFlightPath = .publishedDirect
                journey.trip.flexibility = .exact
                journey.trip.flightTripType = .roundTrip
                IumrahHaptics.selection()
            } label: {
                dateModeChip(directFlightsModeTitle, selected: journey.packageFlightPath == .publishedDirect && !journey.trip.isWeekendUmrah, systemImage: "airplane")
            }
            .buttonStyle(.plain)

            Button {
                if journey.packageFlightPath != .flexibleDates || journey.trip.isWeekendUmrah {
                    journey.resetAfterTripChange()
                    journey.packageFlightPath = .flexibleDates
                    journey.trip.flexibility = .exact
                    journey.trip.flightTripType = .roundTrip
                }
                showsDateCalendar = true
                IumrahHaptics.selection()
            } label: {
                dateModeChip(flexibleDatesModeTitle, selected: journey.packageFlightPath == .flexibleDates, systemImage: "calendar.badge.clock")
            }
            .buttonStyle(.plain)

            Button {
                guard journey.packageFlightPath != .weekend || !journey.trip.isWeekendUmrah else { return }
                journey.resetAfterTripChange()
                journey.packageFlightPath = .weekend
                journey.trip.selectFlexibility(.weekend)
                journey.trip.flightTripType = .roundTrip
                IumrahHaptics.selection()
            } label: {
                dateModeChip(dateWeekendTitle, selected: journey.packageFlightPath == .weekend || journey.trip.isWeekendUmrah)
            }
            .buttonStyle(.plain)
        }
    }

    private func dateModeChip(_ title: String, selected: Bool, systemImage: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.caption.weight(.bold)) }
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .foregroundStyle(selected ? Color.iumrahCardBackground : Color.primary)
        .iumrahGlass(in: Capsule(), interactive: true, tint: selected ? Color.primary : nil)
    }

    private func dateSummaryColumn(title: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(dateSummary(date))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(minWidth: 88, alignment: .leading)
    }

    private func dateSummary(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return formatter.string(from: date)
    }

    private var dateExactTitle: String {
        switch settings.language {
        case .russian: return "Точно"
        case .english: return "Exact"
        case .uzbek: return "Aniq"
        case .uzbekCyrillic: return "Аниқ"
        }
    }

    private var dateCalendarTitle: String {
        switch settings.language {
        case .russian: return "Даты"
        case .english: return "Dates"
        case .uzbek: return "Sanalar"
        case .uzbekCyrillic: return "Саналар"
        }
    }

    private var flightChoiceTitle: String {
        switch settings.language {
        case .russian: return "Сначала выберите перелёт"
        case .english: return "Choose your flight first"
        case .uzbek: return "Avval parvozni tanlang"
        case .uzbekCyrillic: return "Аввал парвозни танланг"
        }
    }

    private var flightChoiceBody: String {
        switch settings.language {
        case .russian: return "Выберите прямой рейс с подходящими датами. Если даты важнее рейса, используйте гибкий календарь."
        case .english: return "Choose a direct flight with suitable dates. If your dates matter more than the flight, use the flexible calendar."
        case .uzbek: return "Mos sanali to‘g‘ridan-to‘g‘ri reysni tanlang. Agar sana muhimroq bo‘lsa, moslashuvchan kalendardan foydalaning."
        case .uzbekCyrillic: return "Мос санали тўғридан-тўғри рейсни танланг. Агар сана муҳимроқ бўлса, мослашувчан календардан фойдаланинг."
        }
    }

    private var directFlightsModeTitle: String {
        switch settings.language {
        case .russian: return "Прямые"
        case .english: return "Direct"
        case .uzbek: return "To‘g‘ri"
        case .uzbekCyrillic: return "Тўғри"
        }
    }

    private var flexibleDatesModeTitle: String {
        switch settings.language {
        case .russian: return "Гибкие даты"
        case .english: return "Flexible"
        case .uzbek: return "Moslashuvchan"
        case .uzbekCyrillic: return "Мослашувчан"
        }
    }

    private var publishedDirectHint: String {
        switch settings.language {
        case .russian: return "Рейсы ниже найдены iumrah Scanner. Выберите билет туда и обратно — цену авиабилета отдельно не показываем; она войдёт в итоговую цену вашего личного пакета."
        case .english: return "The flights below were found by iumrah Scanner. Choose your outbound and return; the airfare is not shown separately and will be included in your personal package total."
        case .uzbek: return "Quyidagi reyslar iumrah Scanner yordamida topilgan. Borish va qaytish reysini tanlang — aviachipta narxi alohida ko‘rsatilmaydi, u shaxsiy paketingiz yakuniy narxiga kiradi."
        case .uzbekCyrillic: return "Қуйидаги рейслар iumrah Scanner ёрдамида топилган. Бориш ва қайтиш рейсини танланг — авиачипта нархи алоҳида кўрсатилмайди, у шахсий пакетингиз якуний нархига киради."
        }
    }

    private var flexibleDatesHint: String {
        switch settings.language {
        case .russian: return "Зелёные дни в календаре — даты прямых рейсов, найденных iumrah AI. Выбор других дат запустит гибкий поиск после выбора отеля."
        case .english: return "Green calendar days are direct-flight dates found by iumrah AI. Choosing other dates starts flexible flight search after your hotel is selected."
        case .uzbek: return "Kalendardagi yashil kunlar — iumrah AI topgan to‘g‘ridan-to‘g‘ri reys sanalari. Boshqa sanalar mehmonxona tanlangach moslashuvchan qidiruvni ishga tushiradi."
        case .uzbekCyrillic: return "Календардаги яшил кунлар — iumrah AI топган тўғридан-тўғри рейс саналари. Бошқа саналар меҳмонхона танлангач мослашувчан қидирувни ишга туширади."
        }
    }

    private var dateWeekendTitle: String {
        switch settings.language {
        case .russian: return "Выходные"
        case .english: return "Weekend"
        case .uzbek: return "Dam olish"
        case .uzbekCyrillic: return "Дам олиш"
        }
    }

    private var dateCalendarHint: String {
        switch settings.language {
        case .russian: return "Откройте календарь актуальных дат: он заполняется реальными поисками и помогает выбрать подходящее окно поездки до запуска нового поиска."
        case .english: return "Open the current-date calendar: it grows from real searches and helps choose a suitable travel window before a new flight search starts."
        case .uzbek: return "Dolzarb sanalar kalendarini oching: u haqiqiy qidiruvlar bilan to‘lib boradi va yangi qidiruvdan oldin mos safar oynasini tanlashga yordam beradi."
        case .uzbekCyrillic: return "Долзарб саналар календарини очинг: у ҳақиқий қидирувлар билан тўлиб боради ва янги қидирувдан олдин мос сафар оралиғини танлашга ёрдам беради."
        }
    }

    private var weekendDatesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            DatePicker(
                L10n.text("weekend_picker_title", settings.language),
                selection: weekendAnchorBinding,
                in: Date()...,
                displayedComponents: .date
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("weekend_window_title", settings.language))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(weekendDates, id: \.self) { date in
                        VStack(spacing: 4) {
                            Text(shortWeekday(date))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(dayNumber(date))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text(shortMonth(date))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 78)
                        .background(Color.iumrahRaisedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }

            HStack(alignment: .top, spacing: 13) {
                IumrahIconBadge(
                    systemName: "moon.stars.fill",
                    role: .umrah,
                    size: 42,
                    symbolSize: 18,
                    shape: .circle
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("weekend_umrah_title", settings.language))
                        .font(.headline)
                    Text(L10n.text("weekend_umrah_body", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(15)
            .background(
                LinearGradient(
                    colors: [Color.iumrahCareLight.opacity(0.18), Color.iumrahCardBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.iumrahCareLight.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private var weekendDates: [Date] {
        (0...3).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: journey.trip.departureDate) }
    }

    private var departureBinding: Binding<Date> {
        Binding(
            get: { journey.trip.departureDate },
            set: { newValue in
                if Calendar.current.startOfDay(for: newValue) != Calendar.current.startOfDay(for: journey.trip.departureDate) {
                    journey.resetAfterTripChange()
                    journey.trip.departureDate = newValue
                    if journey.trip.returnDate <= newValue {
                        journey.trip.returnDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue.addingTimeInterval(86_400)
                    }
                }
            }
        )
    }

    private var returnBinding: Binding<Date> {
        Binding(
            get: { journey.trip.returnDate },
            set: { newValue in
                if Calendar.current.startOfDay(for: newValue) != Calendar.current.startOfDay(for: journey.trip.returnDate) {
                    journey.resetAfterTripChange()
                    journey.trip.returnDate = newValue
                }
            }
        )
    }

    private var weekendAnchorBinding: Binding<Date> {
        Binding(
            get: { journey.trip.departureDate },
            set: { newValue in
                journey.resetAfterTripChange()
                journey.trip.applyWeekendWindow(around: newValue)
            }
        )
    }

    private func shortWeekday(_ date: Date) -> String {
        dateString(date, format: "EEE").uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        dateString(date, format: "d")
    }

    private func shortMonth(_ date: Date) -> String {
        dateString(date, format: "MMM")
    }

    private func dateString(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private var locale: Locale {
        switch settings.language {
        case .english: return Locale(identifier: "en_US")
        case .russian: return Locale(identifier: "ru_RU")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private var flightFiltersBinding: Binding<FlightSearchFilters> {
        Binding(
            get: { journey.trip.effectiveFlightFilters },
            set: { journey.updateFlightFilters($0) }
        )
    }

    private var tripEndDateTitle: String {
        switch settings.language {
        case .russian: return "Завершение поездки"
        case .english: return "Trip end date"
        case .uzbek: return "Safar tugash sanasi"
        case .uzbekCyrillic: return "Сафар тугаш санаси"
        }
    }

    private var curatedFlightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 46, height: 46)
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(curatedFlightsTitle)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(curatedFlightsSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Text("iumrah")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }

            if isLoadingCuratedFlights && curatedFlights.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(curatedLoadingLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                .padding(.horizontal, 4)
            } else {
                VStack(alignment: .leading, spacing: 17) {
                    curatedOneWayRow(
                        title: curatedOutboundRowTitle,
                        subtitle: "\(journey.trip.originCode) → \(journey.trip.outboundDestinationCode)",
                        recommendations: curatedOutboundFlights,
                        selection: .outbound
                    )

                    Divider()
                        .opacity(0.45)

                    curatedOneWayRow(
                        title: curatedReturnRowTitle,
                        subtitle: "\(journey.trip.returnOriginCode) → \(journey.trip.originCode)",
                        recommendations: curatedReturnFlights,
                        selection: .inbound
                    )
                }
            }
        }
        .padding(17)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.orange.opacity(0.085))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.18), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func curatedOneWayRow(
        title: String,
        subtitle: String,
        recommendations: [CuratedFlightRecommendation],
        selection: CuratedLegSelection
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(recommendations.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if recommendations.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color.orange)
                    Text(curatedEmptyRowLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.iumrahRaisedBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 11) {
                        ForEach(recommendations) { recommendation in
                            if let leg = curatedLeg(for: recommendation, selection: selection),
                               let date = curatedLegDate(for: recommendation, selection: selection) {
                                curatedOneWayCard(
                                    recommendation,
                                    leg: leg,
                                    date: date,
                                    selection: selection
                                )
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 1, for: .scrollContent)
            }
        }
    }

    private var curatedRoundTripRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(curatedRoundTripRowTitle)
                        .font(.subheadline.weight(.bold))
                    Text("\(journey.trip.originCode) → \(journey.trip.outboundDestinationCode) · \(journey.trip.returnOriginCode) → \(journey.trip.originCode)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(curatedRoundTripFlights.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if curatedRoundTripFlights.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.left.arrow.right.circle")
                        .foregroundStyle(Color.orange)
                    Text(curatedRoundTripEmptyLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.iumrahRaisedBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(curatedRoundTripFlights) { recommendation in
                            curatedRoundTripCard(recommendation)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 1, for: .scrollContent)
            }
        }
    }

    private func curatedOneWayCard(
        _ recommendation: CuratedFlightRecommendation,
        leg: CuratedFlightRecommendation.Leg,
        date: String,
        selection: CuratedLegSelection
    ) -> some View {
        let isSelected = selectedCuratedID(for: selection) == recommendation.id

        return Button {
            selectCuratedOneWay(recommendation, date: date, selection: selection)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    AirlineLogoView(airlineCode: leg.airlineCode.isEmpty ? nil : leg.airlineCode, size: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(leg.airline.isEmpty ? curatedAirlineFallback : leg.airline)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(leg.flightNumber)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 5)

                    Text(curatedDirectLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(Color.orange.opacity(0.10), in: Capsule())
                }

                curatedLegRow(
                    origin: leg.origin,
                    destination: leg.destination,
                    date: date,
                    systemImage: selection == .outbound ? "airplane.departure" : "airplane.arrival"
                )

                HStack {
                    Text(curatedChooseFlightLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? Color.orange : Color.primary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .foregroundStyle(isSelected ? Color.orange : Color.primary)
                }
            }
            .padding(14)
            .frame(minWidth: 274, maxWidth: 274, minHeight: 154, alignment: .leading)
            .background(
                isSelected ? Color.orange.opacity(0.075) : Color.iumrahRaisedBackground,
                in: RoundedRectangle(cornerRadius: 21, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(isSelected ? Color.orange.opacity(0.35) : Color.primary.opacity(0.055), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func curatedRoundTripCard(_ recommendation: CuratedFlightRecommendation) -> some View {
        let isSelected = journey.selectedPublishedCompleteID == recommendation.id

        return Button {
            selectCuratedRoundTrip(recommendation)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    AirlineLogoView(airlineCode: recommendation.primaryAirlineCode, size: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.primaryAirlineName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(recommendation.flightNumbers.joined(separator: " · "))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Text(curatedRoundTripBadgeLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 8)
                        .frame(height: 25)
                        .background(Color.orange.opacity(0.10), in: Capsule())
                }

                VStack(spacing: 9) {
                    curatedLegRow(
                        origin: recommendation.outbound.origin,
                        destination: recommendation.outbound.destination,
                        date: recommendation.outboundDate,
                        systemImage: "airplane.departure"
                    )

                    if let inbound = recommendation.inbound,
                       let inboundDate = recommendation.inboundDate {
                        curatedLegRow(
                            origin: inbound.origin,
                            destination: inbound.destination,
                            date: inboundDate,
                            systemImage: "airplane.arrival"
                        )
                    }
                }

                Divider()
                    .opacity(0.55)

                HStack {
                    Text(curatedSelectDatesLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? Color.orange : Color.primary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.orange : Color.primary)
                }
            }
            .padding(15)
            .frame(minWidth: 292, maxWidth: 292, minHeight: 204, alignment: .leading)
            .background(
                isSelected ? Color.orange.opacity(0.075) : Color.iumrahRaisedBackground,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? Color.orange.opacity(0.35) : Color.primary.opacity(0.055), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func curatedLegRow(origin: String, destination: String, date: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.orange)
                .frame(width: 18)

            Text(origin)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospaced()
            Image(systemName: "arrow.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(destination)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospaced()

            Spacer(minLength: 8)

            Text(curatedShortDate(date))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func curatedShortDate(_ value: String) -> String {
        guard let date = CuratedFlightRecommendationService.date(value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private var curatedOutboundFlights: [CuratedFlightRecommendation] {
        let origin = journey.trip.originCode.uppercased()
        let destination = journey.trip.outboundDestinationCode.uppercased()

        // The route selected by the pilgrim is authoritative. Makkah-only means
        // origin → JED; Makkah + Madinah uses the explicitly selected first Saudi
        // airport. Do not mix JED and MED publications in the same generator row.
        return curatedFlights.filter { recommendation in
            recommendation.inbound == nil &&
            recommendation.outbound.origin.uppercased() == origin &&
            recommendation.outbound.destination.uppercased() == destination
        }
    }

    private var curatedReturnFlights: [CuratedFlightRecommendation] {
        let returnOrigin = journey.trip.returnOriginCode.uppercased()
        let destination = journey.trip.originCode.uppercased()

        return curatedFlights.filter { recommendation in
            recommendation.inbound == nil &&
            recommendation.outbound.origin.uppercased() == returnOrigin &&
            recommendation.outbound.destination.uppercased() == destination
        }
        .filter { recommendation in
            // Before an outbound publication is selected, TripDraft still contains
            // its synthetic +21-day default departure date. Using that placeholder
            // to filter the return catalogue hides perfectly valid Business rows.
            // Apply chronological filtering only after the user has picked outbound.
            guard journey.selectedPublishedOutboundID != nil else { return true }
            guard let date = CuratedFlightRecommendationService.date(recommendation.outboundDate) else { return false }
            return Calendar.current.startOfDay(for: date) >= Calendar.current.startOfDay(for: journey.trip.departureDate)
        }
    }

    private var curatedRoundTripFlights: [CuratedFlightRecommendation] {
        let origin = journey.trip.originCode.uppercased()
        let outboundDestination = journey.trip.outboundDestinationCode.uppercased()
        let returnOrigin = journey.trip.returnOriginCode.uppercased()

        return curatedFlights.filter { recommendation in
            guard let inbound = recommendation.inbound else { return false }
            return recommendation.outbound.origin.uppercased() == origin
                && recommendation.outbound.destination.uppercased() == outboundDestination
                && inbound.origin.uppercased() == returnOrigin
                && inbound.destination.uppercased() == origin
        }
    }

    private func curatedLeg(
        for recommendation: CuratedFlightRecommendation,
        selection: CuratedLegSelection
    ) -> CuratedFlightRecommendation.Leg? {
        switch selection {
        case .outbound:
            return recommendation.outbound
        case .inbound:
            if recommendation.effectiveOfferType == "one_way" { return recommendation.outbound }
            return recommendation.inbound
        }
    }

    private func curatedLegDate(
        for recommendation: CuratedFlightRecommendation,
        selection: CuratedLegSelection
    ) -> String? {
        switch selection {
        case .outbound:
            return recommendation.outboundDate
        case .inbound:
            if recommendation.effectiveOfferType == "one_way" { return recommendation.outboundDate }
            return recommendation.inboundDate
        }
    }

    private func selectedCuratedID(for selection: CuratedLegSelection) -> String? {
        switch selection {
        case .outbound: return journey.selectedPublishedOutboundID
        case .inbound: return journey.selectedPublishedReturnID
        }
    }

    private func selectCuratedOneWay(
        _ recommendation: CuratedFlightRecommendation,
        date value: String,
        selection: CuratedLegSelection
    ) {
        guard let date = CuratedFlightRecommendationService.date(value),
              let leg = curatedLeg(for: recommendation, selection: selection) else { return }

        let expectedOrigin: String
        let expectedDestination: String
        switch selection {
        case .outbound:
            expectedOrigin = journey.trip.originCode.uppercased()
            expectedDestination = journey.trip.outboundDestinationCode.uppercased()
        case .inbound:
            expectedOrigin = journey.trip.returnOriginCode.uppercased()
            expectedDestination = journey.trip.originCode.uppercased()
        }
        guard leg.origin.uppercased() == expectedOrigin,
              leg.destination.uppercased() == expectedDestination else { return }
        if selection == .inbound, date < journey.trip.departureDate { return }

        let calendar = Calendar.current
        let oldDuration = max(1, calendar.dateComponents([.day], from: journey.trip.departureDate, to: journey.trip.returnDate).day ?? 7)

        journey.resetAfterTripChange(keepingPublishedFlightSelection: true)
        journey.packageFlightPath = .publishedDirect
        journey.trip.flexibility = .exact
        journey.trip.flightTripType = .roundTrip

        switch selection {
        case .outbound:
            journey.trip.departureDate = date
            if journey.trip.returnDate < date {
                journey.trip.returnDate = calendar.date(byAdding: .day, value: oldDuration, to: date) ?? date
                journey.selectedPublishedReturnID = nil
            }
            journey.selectedPublishedOutboundID = recommendation.id
        case .inbound:
            journey.trip.returnDate = date
            journey.selectedPublishedReturnID = recommendation.id
        }

        journey.selectedPublishedCompleteID = nil
        IumrahHaptics.selection()
    }

    private func selectCuratedRoundTrip(_ recommendation: CuratedFlightRecommendation) {
        guard let outbound = CuratedFlightRecommendationService.date(recommendation.outboundDate),
              let inbound = CuratedFlightRecommendationService.date(recommendation.inboundDate),
              inbound >= outbound else { return }
        journey.resetAfterTripChange()
        journey.packageFlightPath = .publishedDirect
        journey.trip.flexibility = .exact
        journey.trip.flightTripType = .roundTrip
        journey.trip.departureDate = outbound
        journey.trip.returnDate = inbound
        journey.selectedPublishedCompleteID = recommendation.id
        journey.selectedPublishedOutboundID = nil
        journey.selectedPublishedReturnID = nil
        IumrahHaptics.selection()
    }

    @MainActor
    private func loadCuratedFlights() async {
        isLoadingCuratedFlights = true
        defer { isLoadingCuratedFlights = false }
        do {
            curatedFlights = try await CuratedFlightRecommendationService.shared.load(trip: journey.trip)

            // Keep the currently chosen presentation whenever it has inventory. If a
            // route has only one published product shape, fall back automatically so
            // the pilgrim sees real flights instead of an empty first tab.
            if curatedDisplayMode == .roundTrip,
               curatedRoundTripFlights.isEmpty,
               !curatedOutboundFlights.isEmpty || !curatedReturnFlights.isEmpty {
                curatedDisplayMode = .separate
            } else if curatedDisplayMode == .separate,
                      curatedOutboundFlights.isEmpty,
                      curatedReturnFlights.isEmpty,
                      !curatedRoundTripFlights.isEmpty {
                curatedDisplayMode = .roundTrip
            }
        } catch {
            curatedFlights = []
        }
    }

    private var curatedFlightsQueryKey: String {
        routeSelectionKey
    }

    private var curatedFlightsTitle: String {
        switch settings.language {
        case .russian: return "Найденные прямые рейсы"
        case .english: return "Found direct flights"
        case .uzbek: return "Topilgan to‘g‘ridan-to‘g‘ri reyslar"
        case .uzbekCyrillic: return "Топилган тўғридан-тўғри рейслар"
        }
    }

    private var curatedFlightsSubtitle: String {
        switch settings.language {
        case .russian: return "Найдено с помощью iumrah Scanner"
        case .english: return "Found with iumrah Scanner"
        case .uzbek: return "iumrah Scanner yordamida topildi"
        case .uzbekCyrillic: return "iumrah Scanner ёрдамида топилди"
        }
    }

    private var curatedModePickerLabel: String {
        switch settings.language {
        case .russian: return "Тип билета"
        case .english: return "Ticket type"
        case .uzbek: return "Chipta turi"
        case .uzbekCyrillic: return "Чипта тури"
        }
    }

    private var curatedSeparateModeLabel: String {
        switch settings.language {
        case .russian: return "В одну сторону"
        case .english: return "One way"
        case .uzbek: return "Bir tomonlama"
        case .uzbekCyrillic: return "Бир томонлама"
        }
    }

    private var curatedRoundTripModeLabel: String {
        switch settings.language {
        case .russian: return "Туда-обратно"
        case .english: return "Round trip"
        case .uzbek: return "Borib-kelish"
        case .uzbekCyrillic: return "Бориб-келиш"
        }
    }

    private var curatedOutboundRowTitle: String {
        switch settings.language {
        case .russian: return "Туда"
        case .english: return "Outbound"
        case .uzbek: return "Borish"
        case .uzbekCyrillic: return "Бориш"
        }
    }

    private var curatedReturnRowTitle: String {
        switch settings.language {
        case .russian: return "Обратно"
        case .english: return "Return"
        case .uzbek: return "Qaytish"
        case .uzbekCyrillic: return "Қайтиш"
        }
    }

    private var curatedRoundTripRowTitle: String {
        switch settings.language {
        case .russian: return "Билеты туда-обратно"
        case .english: return "Round-trip tickets"
        case .uzbek: return "Borib-kelish chiptalari"
        case .uzbekCyrillic: return "Бориб-келиш чипталари"
        }
    }

    private var curatedDirectLabel: String {
        switch settings.language {
        case .russian: return "ПРЯМОЙ"
        case .english: return "DIRECT"
        case .uzbek: return "TO‘G‘RI"
        case .uzbekCyrillic: return "ТЎҒРИ"
        }
    }

    private var curatedRoundTripBadgeLabel: String {
        switch settings.language {
        case .russian: return "ТУДА-ОБРАТНО"
        case .english: return "ROUND TRIP"
        case .uzbek: return "BORIB-KELISH"
        case .uzbekCyrillic: return "БОРИБ-КЕЛИШ"
        }
    }

    private var curatedChooseFlightLabel: String {
        switch settings.language {
        case .russian: return "Выбрать рейс"
        case .english: return "Choose flight"
        case .uzbek: return "Reysni tanlash"
        case .uzbekCyrillic: return "Рейсни танлаш"
        }
    }

    private var curatedSelectDatesLabel: String {
        switch settings.language {
        case .russian: return "Выбрать эти даты"
        case .english: return "Choose these dates"
        case .uzbek: return "Shu sanalarni tanlash"
        case .uzbekCyrillic: return "Шу саналарни танлаш"
        }
    }

    private var curatedLoadingLabel: String {
        switch settings.language {
        case .russian: return "Ищем рейсы через iumrah Scanner…"
        case .english: return "Searching flights with iumrah Scanner…"
        case .uzbek: return "iumrah Scanner orqali reyslar qidirilmoqda…"
        case .uzbekCyrillic: return "iumrah Scanner орқали рейслар қидирилмоқда…"
        }
    }

    private var curatedEmptyRowLabel: String {
        switch settings.language {
        case .russian: return "Для этого направления пока не найдено подходящих прямых рейсов."
        case .english: return "No suitable direct flights found for this route yet."
        case .uzbek: return "Bu yo‘nalish uchun hozircha mos to‘g‘ridan-to‘g‘ri reys topilmadi."
        case .uzbekCyrillic: return "Бу йўналиш учун ҳозирча мос тўғридан-тўғри рейс топилмади."
        }
    }

    private var curatedRoundTripEmptyLabel: String {
        switch settings.language {
        case .russian:
            if journey.trip.returnOriginCode != journey.trip.outboundDestinationCode {
                return "Для текущего open-jaw маршрута аэропорт прилёта и аэропорт обратного вылета разные. Используйте вкладку «В одну сторону» — там можно выбрать рейс туда и обратно отдельно."
            }
            return "Пока нет подходящей пары рейсов туда и обратно для этого маршрута."
        case .english:
            return journey.trip.returnOriginCode != journey.trip.outboundDestinationCode
                ? "This is an open-jaw route. Use One way to choose outbound and return flights separately."
                : "No suitable outbound and return pair found for this route yet."
        case .uzbek:
            return journey.trip.returnOriginCode != journey.trip.outboundDestinationCode
                ? "Bu open-jaw yo‘nalish. Borish va qaytish reyslarini alohida tanlash uchun Bir tomonlama bo‘limidan foydalaning."
                : "Bu yo‘nalish uchun hozircha mos borish-qaytish jufti topilmadi."
        case .uzbekCyrillic:
            return journey.trip.returnOriginCode != journey.trip.outboundDestinationCode
                ? "Бу open-jaw йўналиш. Бориш ва қайтиш рейсларини алоҳида танлаш учун Бир томонлама бўлимидан фойдаланинг."
                : "Бу йўналиш учун ҳозирча мос бориш-қайтиш жуфти топилмади."
        }
    }

    private var curatedAirlineFallback: String {
        switch settings.language {
        case .russian: return "Авиакомпания"
        case .english: return "Airline"
        case .uzbek: return "Aviakompaniya"
        case .uzbekCyrillic: return "Авиакомпания"
        }
    }

    private var travelersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text("trip_travelers_title", settings.language), systemImage: "person.2")
                .font(.headline)
                .padding(.bottom, 4)

            Text(L10n.text("trip_travelers_body", settings.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            groupSavingsSummaryCard
                .padding(.bottom, 4)

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
            CounterRow(title: L10n.text("rooms", settings.language), subtitle: nil, value: $journey.trip.rooms, minimum: 1, maximum: 6)
        }
        .iumrahCard()
    }

    private var packageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.text("trip_format_title", settings.language), systemImage: "square.grid.2x2")
                .font(.headline)

            ForEach(PackageTier.allCases) { tier in
                packageTierSelectionCard(tier)
            }
        }
        .iumrahCard()
    }

    private func packageTierSelectionCard(_ tier: PackageTier) -> some View {
        let selected = journey.trip.packageTier == tier
        let gradient = packageTierGradient(tier)
        let badgeTint = packageTierAccentColor(tier)

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                journey.selectPackageTier(tier)
            }
            IumrahHaptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(selected ? 0.20 : 0.10))
                            .frame(width: 48, height: 48)
                        Image(systemName: selected ? "checkmark.circle.fill" : packageTierSymbol(tier))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(tier.title(settings.language))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            if tier == .standard {
                                Text(L10n.text("popular", settings.language))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(badgeTint)
                                    .padding(.horizontal, 9)
                                    .frame(height: 24)
                                    .background(Color.white.opacity(0.92), in: Capsule())
                            }
                        }

                        Text(packageTierHeadline(tier))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.86))
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(hotelLevelTitle(tier))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Color.white.opacity(0.16), in: Capsule())

                        if selected {
                            Text(packageCurrentBadge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                Text(packageTierBody(tier))
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(packageTierBullets(tier), id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.top, 1)
                            Text(benefit)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color.white.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Text(selected ? packageSelectedFooter : packageSelectFooter)
                        .font(.footnote.weight(.semibold))
                    Spacer(minLength: 8)
                    Image(systemName: selected ? "checkmark" : "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Color.white.opacity(selected ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(gradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(selected ? 0.22 : 0.10), lineWidth: 1)
            }
            .shadow(color: badgeTint.opacity(selected ? 0.26 : 0.16), radius: selected ? 18 : 12, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func packageTierGradient(_ tier: PackageTier) -> LinearGradient {
        switch tier {
        case .economy:
            return LinearGradient(colors: [Color(red: 0.32, green: 0.56, blue: 0.34), Color(red: 0.13, green: 0.25, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .standard:
            return LinearGradient(colors: [Color(red: 0.31, green: 0.37, blue: 0.83), Color(red: 0.13, green: 0.18, blue: 0.43)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .comfort:
            return LinearGradient(colors: [Color(red: 0.11, green: 0.60, blue: 0.62), Color(red: 0.03, green: 0.18, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .luxury:
            return LinearGradient(colors: [Color(red: 0.81, green: 0.63, blue: 0.24), Color(red: 0.29, green: 0.18, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func packageTierAccentColor(_ tier: PackageTier) -> Color {
        switch tier {
        case .economy: return Color(red: 0.62, green: 0.91, blue: 0.69)
        case .standard: return Color(red: 0.76, green: 0.80, blue: 1.0)
        case .comfort: return Color(red: 0.69, green: 0.95, blue: 0.94)
        case .luxury: return Color(red: 1.0, green: 0.91, blue: 0.68)
        }
    }

    private func packageTierSymbol(_ tier: PackageTier) -> String {
        switch tier {
        case .economy: return "leaf.fill"
        case .standard: return "checklist"
        case .comfort: return "sparkles"
        case .luxury: return "crown.fill"
        }
    }

    private func packageTierHeadline(_ tier: PackageTier) -> String {
        switch tier {
        case .economy:
            return groupSavingsText(ru: "Практичный пакет", en: "Practical package", uz: "Amaliy paket", uzCyr: "Амалий пакет")
        case .standard:
            return groupSavingsText(ru: "Сбалансированная база", en: "Balanced essentials", uz: "Muvozanatli asos", uzCyr: "Мувозанатли асос")
        case .comfort:
            return groupSavingsText(ru: "Больше ежедневного удобства", en: "More daily comfort", uz: "Har kuni ko‘proq qulaylik", uzCyr: "Ҳар куни кўпроқ қулайлик")
        case .luxury:
            return groupSavingsText(ru: "Максимально близко к Хараму", en: "Closest to the Haram", uz: "Haromga maksimal yaqin", uzCyr: "Ҳаромга максимал яқин")
        }
    }

    private func packageTierBody(_ tier: PackageTier) -> String {
        switch tier {
        case .economy:
            return groupSavingsText(ru: "Для тех, кто хочет сохранить бюджет и собрать полноценную поездку без лишнего. Основная цель — выгодная личная умра с базовым комфортом.", en: "For pilgrims who want to keep the budget under control and still assemble a full trip. The goal is a smart personal Umrah with essential comfort.", uz: "Budjetni nazoratda ushlab, to‘liq safar yig‘moqchi bo‘lganlar uchun. Asosiy maqsad — zarur qulayliklar bilan foydali shaxsiy umra.", uzCyr: "Бюджетни назоратда ушлаб, тўлиқ сафар йиғмоқчи бўлганлар учун. Асосий мақсад — зарур қулайликлар билан фойдали шахсий умра.")
        case .standard:
            return groupSavingsText(ru: "Оптимальный старт для большинства поездок: аккуратный баланс цены, расположения и привычных удобств.", en: "The best starting point for most trips: a clean balance of price, location and familiar convenience.", uz: "Ko‘pchilik safarlar uchun eng maqbul boshlanish: narx, joylashuv va odatiy qulayliklarning muvozanati.", uzCyr: "Кўпчилик сафарлар учун энг мақбул бошланиш: нарх, жойлашув ва одатий қулайликларнинг мувозанати.")
        case .comfort:
            return groupSavingsText(ru: "Комфортный вариант для тех, кто хочет меньше бытовой нагрузки и более приятный ежедневный ритм поездки.", en: "A comfortable option for pilgrims who want less daily friction and a smoother travel rhythm.", uz: "Kundalik tashvishlarni kamaytirib, safarni yengilroq qilishni istaganlar uchun qulay variant.", uzCyr: "Кундалик ташвишларни камайтириб, сафарни енгилроқ қилишни истаганлар учун қулай вариант.")
        case .luxury:
            return groupSavingsText(ru: "Премиальный формат для тех, кто хочет самый высокий уровень сервиса и максимально сократить дорогу до Харама.", en: "A premium format for pilgrims who want the highest level of service and the shortest possible walk to the Haram.", uz: "Eng yuqori xizmat va Haromgacha yo‘lni maksimal qisqartirishni istaganlar uchun premium format.", uzCyr: "Энг юқори хизмат ва Ҳаромгача йўлни максимал қисқартиришни истаганлар учун премиум формат.")
        }
    }

    private func packageTierBullets(_ tier: PackageTier) -> [String] {
        switch tier {
        case .economy:
            return [
                groupSavingsText(ru: "Базовый уровень отеля 2★ / 1★", en: "2★ / 1★ hotel level", uz: "2★ / 1★ mehmonxona darajasi", uzCyr: "2★ / 1★ меҳмонхона даражаси"),
                groupSavingsText(ru: "Лучше всего, если приоритет — цена", en: "Best when price is the main priority", uz: "Asosiy ustuvorlik narx bo‘lsa mos", uzCyr: "Асосий устуворлик нарх бўлса мос"),
                groupSavingsText(ru: "Все основные этапы уже внутри одного пакета", en: "All core trip parts stay inside one package", uz: "Safarning barcha asosiy qismlari bir paketda", uzCyr: "Сафарнинг барча асосий қисмлари бир пакетда")
            ]
        case .standard:
            return [
                groupSavingsText(ru: "3★ отель как основной уровень", en: "3★ hotel as the main level", uz: "Asosiy daraja — 3★ mehmonxona", uzCyr: "Асосий даража — 3★ меҳмонхона"),
                groupSavingsText(ru: "Хороший баланс цены и повседневного удобства", en: "A strong balance of price and comfort", uz: "Narx va qulaylikning yaxshi muvozanati", uzCyr: "Нарх ва қулайликнинг яхши мувозанати"),
                groupSavingsText(ru: "Подходит для большинства индивидуальных поездок", en: "Suitable for most private trips", uz: "Ko‘pchilik individual safarlar uchun mos", uzCyr: "Кўпчилик индивидуал сафарлар учун мос")
            ]
        case .comfort:
            return [
                groupSavingsText(ru: "4★ уровень с более удобным проживанием", en: "4★ level with more comfortable stays", uz: "4★ daraja va qulayroq yashash", uzCyr: "4★ даража ва қулайроқ яшаш"),
                groupSavingsText(ru: "Лучше ежедневный ритм и меньше бытовых компромиссов", en: "A smoother daily rhythm with fewer compromises", uz: "Har kuni qulayroq ritm va kamroq murosa", uzCyr: "Ҳар куни қулайроқ ритм ва камроқ муроса"),
                groupSavingsText(ru: "Хороший выбор для семей и спокойной поездки", en: "A strong choice for families and calmer trips", uz: "Oilalar va sokin safar uchun yaxshi tanlov", uzCyr: "Оилалар ва сокин сафар учун яхши танлов")
            ]
        case .luxury:
            return [
                groupSavingsText(ru: "5★ уровень и премиальная подача", en: "5★ level and a premium feel", uz: "5★ daraja va premium tajriba", uzCyr: "5★ даража ва премиум тажриба"),
                groupSavingsText(ru: "Максимальная близость к Хараму", en: "Maximum closeness to the Haram", uz: "Haromga maksimal yaqinlik", uzCyr: "Ҳаромга максимал яқинлик"),
                groupSavingsText(ru: "Для тех, кто хочет сократить нагрузку в поездке", en: "For pilgrims who want the lightest trip burden", uz: "Safardagi yuklamani kamaytirishni istaganlar uchun", uzCyr: "Сафардаги юкламани камайтиришни истаганлар учун")
            ]
        }
    }

    private func hotelLevelTitle(_ tier: PackageTier) -> String {
        tier == .economy ? "2★ · 1★" : "\(tier.primaryHotelStars)★"
    }

    private var packageCurrentBadge: String {
        groupSavingsText(ru: "Текущий", en: "Current", uz: "Joriy", uzCyr: "Жорий")
    }

    private var packageSelectedFooter: String {
        groupSavingsText(ru: "Этот уровень уже выбран", en: "This level is already selected", uz: "Bu daraja allaqachon tanlangan", uzCyr: "Бу даража аллақачон танланган")
    }

    private var packageSelectFooter: String {
        groupSavingsText(ru: "Выбрать этот уровень", en: "Choose this level", uz: "Shu darajani tanlash", uzCyr: "Шу даражани танлаш")
    }

    @ViewBuilder
    private var groupSavingsSummaryCard: some View {
        let count = max(1, journey.trip.travelerCount)
        if count == 1 {
            let comparison = estimatedSavings(for: 2)
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
        } else if let savings = estimatedSavings(for: count), savings.percent > 0 {
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

    private struct TripBuilderEstimatedSavings {
        let percent: Int
        let totalSavings: Double
        let perPersonSavings: Double
    }

    private func estimatedSavings(for people: Int) -> TripBuilderEstimatedSavings? {
        let count = max(1, people)
        guard count > 1 else { return nil }

        let sharedWeight: Double = 0.24
        let occupancyFactor = Double(count - 1) / Double(count)
        let rawPercent = sharedWeight * occupancyFactor * 100
        let percent = max(6, Int(rawPercent.rounded()))

        let nights = max(3, Calendar.current.dateComponents([.day], from: journey.trip.hotelStayStartDate, to: journey.trip.returnDate).day ?? 6)
        var soloPerPilgrim = estimatedSoloBasePrice
        soloPerPilgrim += Double(max(0, nights - 5)) * 42
        let soloTotal = soloPerPilgrim * Double(count)
        let totalSavings = max(0, soloTotal * Double(percent) / 100)
        let perPersonSavings = totalSavings / Double(count)
        return TripBuilderEstimatedSavings(percent: percent, totalSavings: totalSavings, perPersonSavings: perPersonSavings)
    }

    private var estimatedSoloBasePrice: Double {
        switch journey.trip.packageTier {
        case .economy: return journey.trip.scope == .makkahAndMadinah ? 980 : 860
        case .standard: return journey.trip.scope == .makkahAndMadinah ? 1210 : 1080
        case .comfort: return journey.trip.scope == .makkahAndMadinah ? 1480 : 1320
        case .luxury: return journey.trip.scope == .makkahAndMadinah ? 1880 : 1690
        }
    }

    private var singleTravelerWarningTitle: String {
        groupSavingsText(
            ru: "Для одного человека пакет дороже",
            en: "Solo travel costs more",
            uz: "Bir kishi uchun paket qimmatroq",
            uzCy: "Бир киши учун пакет қимматроқ"
        )
    }

    private func singleTravelerWarningBody(percent: Int, savings: Double) -> String {
        groupSavingsText(
            ru: "Если ехать вдвоём, цена на человека сейчас ниже примерно на \(percent)%. Вместе двое экономят \(moneyText(savings)) по сравнению с двумя отдельными такими поездками.",
            en: "For two pilgrims, the current per-person price is about \(percent)% lower. Together, two save \(moneyText(savings)) versus two separate solo packages.",
            uz: "Ikki kishi bo‘lib borsangiz, kishi boshiga narx hozir taxminan \(percent)% arzon. Ikki alohida yakka paketga nisbatan jami \(moneyText(savings)) tejaysiz.",
            uzCy: "Икки киши бўлиб борсангиз, киши бошига нарх ҳозир тахминан \(percent)% арзон. Икки алоҳида якка пакетга нисбатан жами \(moneyText(savings)) тежайсиз."
        )
    }

    private var singleTravelerFallbackBody: String {
        groupSavingsText(
            ru: "Совместная поездка обычно снижает цену на человека, потому что номер, трансфер, сопровождение и часть сервисов распределяются на группу.",
            en: "Travelling together usually lowers the per-person price because rooms, transfers, assistance and group services are shared.",
            uz: "Birga safar qilish odatda kishi boshiga narxni pasaytiradi: xona, transfer, hamrohlik va guruh xizmatlari bo‘linadi.",
            uzCy: "Бирга сафар қилиш одатда киши бошига нархни пасайтиради: хона, трансфер, ҳамроҳлик ва гуруҳ хизматлари бўлинади."
        )
    }

    private var groupSavingsComparisonCaption: String {
        groupSavingsText(
            ru: "Сравнение с таким же пакетом для 1 паломника",
            en: "Compared with the same package for 1 pilgrim",
            uz: "Xuddi shu 1 kishilik paket bilan solishtirganda",
            uzCy: "Худди шу 1 кишилик пакет билан солиштирганда"
        )
    }

    private func groupSavingsTotalText(_ value: Double) -> String {
        groupSavingsText(
            ru: "Экономия группы \(moneyText(value))",
            en: "Group saves \(moneyText(value))",
            uz: "Guruh tejaydi: \(moneyText(value))",
            uzCy: "Гуруҳ тежайди: \(moneyText(value))"
        )
    }

    private func groupSavingsPerPersonText(_ value: Double) -> String {
        groupSavingsText(
            ru: "\(moneyText(value)) на человека",
            en: "\(moneyText(value)) per person",
            uz: "kishi boshiga \(moneyText(value))",
            uzCy: "киши бошига \(moneyText(value))"
        )
    }

    private func groupSavingsText(ru: String, en: String, uz: String, uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private func moneyText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: settings.language == .russian || settings.language == .uzbekCyrillic ? "ru_RU" : "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }

}
