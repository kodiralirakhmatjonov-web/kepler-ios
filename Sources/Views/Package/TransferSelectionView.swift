import SwiftUI
import Foundation
import MapKit

private enum TransferDiscoveryPhase {
    case searching
    case matched
}

struct TransferSelectionView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var inheritedColorScheme

    @State private var discoveryPhase: TransferDiscoveryPhase = .searching
    @State private var searchSecond = 0
    @State private var selectedIndex = 1
    @State private var dragOffset: CGFloat = 0
    @State private var basePackagePriceUsd: Decimal?
    @State private var showFinalPackage = false
    @State private var isConfirming = false
    @State private var confirmationError: String?

    @State private var searchDuration = Int.random(in: 20...40)
    private let vehicles = TransferVehicleKind.allCases

    private var selectedVehicle: TransferVehicleKind {
        vehicles[min(max(selectedIndex, 0), vehicles.count - 1)]
    }

    private var includesMadinah: Bool { journey.trip.scope == .makkahAndMadinah }
    private var isVIP: Bool { selectedVehicle == .yukon }

    private var selectedVehicleAddOnUsd: Decimal {
        selectedVehicle.publicUpgradeUsd(for: journey.trip.scope)
    }

    private var selectedTrainAddOnUsd: Decimal {
        journey.haramainTrainSelected ? journey.haramainTrainAddOnUsd : 0
    }

    private var currentPackageTotalUsd: Decimal? {
        guard let basePackagePriceUsd else { return journey.quote?.totalPackagePrice }
        return basePackagePriceUsd + selectedVehicleAddOnUsd + selectedTrainAddOnUsd
    }

    var body: some View {
        Group {
            switch discoveryPhase {
            case .searching:
                searchExperience
                    .transition(.opacity)
                    .environment(\.colorScheme, inheritedColorScheme)
            case .matched:
                matchedExperience
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .environment(\.colorScheme, isVIP ? .dark : inheritedColorScheme)
            }
        }
        .background(transferPageBackground)
        .animation(.easeInOut(duration: 0.48), value: isVIP)
        .iumrahInternalNavigation(
            progress: .transfer,
            showsGeneratorAmbient: true,
            currentPriceText: currentPackagePriceTitle
        )
        .navigationDestination(isPresented: $showFinalPackage) {
            FinalPackageView()
        }
        .alert(errorTitle, isPresented: Binding(
            get: { confirmationError != nil },
            set: { if !$0 { confirmationError = nil } }
        )) {
            Button("OK", role: .cancel) { confirmationError = nil }
        } message: {
            Text(confirmationError ?? "")
        }
        .task { await startDiscoveryIfNeeded() }
    }

    private var transferPageBackground: some View {
        ZStack(alignment: .top) {
            pageBackground
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color(red: 0.97, green: 0.95, blue: 0.79), Color(red: 0.98, green: 0.98, blue: 0.94), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
            .opacity(isVIP ? 0 : 1)
            .ignoresSafeArea(edges: .top)
        }
    }

    private var pageBackground: Color {
        discoveryPhase == .matched && isVIP ? .black : .iumrahPageBackground
    }

    // MARK: - 30-second Apple Maps search

    private var searchExperience: some View {
        ZStack {
            TransferLiveSearchMap(second: searchSecond, searchDuration: searchDuration, reduceMotion: reduceMotion)
                .ignoresSafeArea(edges: .bottom)

            LinearGradient(
                colors: [
                    pageBackground,
                    pageBackground,
                    pageBackground.opacity(0.88),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 248, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                IumrahGeneratorHeader(
                    stage: .transfer,
                    currentPriceText: currentPackagePriceTitle
                )
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 10)

                Spacer()

                searchBottomSheet
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
            }
        }
    }

    private var searchBottomSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: "car.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localized(
                        "Ищем свободный трансфер",
                        "Finding an available transfer",
                        "Bo‘sh transfer qidirilmoqda",
                        "Бўш трансфер қидирилмоқда"
                    ))
                    .font(.headline)

                    Text(searchStatusTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(searchSecond)s")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .contentTransition(.numericText())
                    Text(localized("идёт поиск", "searching", "qidiruv", "қидирув"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            TransferSearchActivityBar(second: searchSecond)

            HStack(spacing: 8) {
                searchChip(icon: "location.fill", text: routeTitle)
                searchChip(icon: "person.2.fill", text: "\(journey.trip.travelerCount)")
                searchChip(
                    icon: "car.fill",
                    text: localized(
                        "\(nearbyVehicleCount) рядом",
                        "\(nearbyVehicleCount) nearby",
                        "\(nearbyVehicleCount) yaqin",
                        "\(nearbyVehicleCount) яқин"
                    )
                )
            }

            Text(localized(
                "Проверяем автомобили в Мекке, маршрут поездки, количество гостей и багаж. После проверки iumrah предложит подходящий свободный автомобиль.",
                "Checking vehicles around Makkah, your trip route, party size and luggage. iumrah will then match a suitable available vehicle.",
                "Makkadagi avtomobillar, safar yo‘nalishi, mehmonlar va bagaj tekshirilmoqda. So‘ng iumrah mos bo‘sh avtomobilni tanlaydi.",
                "Маккадаги автомобиллар, сафар йўналиши, меҳмонлар ва багаж текширилмоқда. Сўнг iumrah мос бўш автомобилни танлайди."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous), allowsStaticGlass: true)
        .shadow(color: .black.opacity(0.10), radius: 30, y: 14)
    }

    private func searchChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color.iumrahRaisedBackground.opacity(0.92), in: Capsule())
    }

    private var nearbyVehicleCount: Int {
        min(11, 2 + searchSecond / 3)
    }

    private var searchStatusTitle: String {
        switch searchSecond {
        case 0..<5:
            return localized("Сканируем дороги рядом с Харамом", "Scanning roads around the Haram", "Haram atrofidagi yo‘llar tekshirilmoqda", "Ҳарам атрофидаги йўллар текширилмоқда")
        case 5..<10:
            return localized("Проверяем доступность водителей", "Checking driver availability", "Haydovchilar mavjudligi tekshirilmoqda", "Ҳайдовчилар мавжудлиги текширилмоқда")
        case 10..<15:
            return localized("Сопоставляем ваши даты", "Matching your travel dates", "Safar sanalari moslashtirilmoqda", "Сафар саналари мослаштирилмоқда")
        case 15..<20:
            return localized("Учитываем гостей и багаж", "Matching guests and luggage", "Mehmonlar va bagaj hisoblanmoqda", "Меҳмонлар ва багаж ҳисобланмоқда")
        case 20..<25:
            return localized("Проверяем маршрут Мекка — Медина", "Checking the Makkah–Madinah route", "Makka–Madina yo‘nalishi tekshirilmoqda", "Макка–Мадина йўналиши текширилмоқда")
        default:
            return localized("Закрепляем лучший доступный вариант", "Securing the best available match", "Eng mos variant biriktirilmoqda", "Энг мос вариант бириктирилмоқда")
        }
    }

    // MARK: - Matched Uber-style transfer service

    private var matchedExperience: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                IumrahGeneratorHeader(
                    stage: .transfer,
                    currentPriceText: currentPackagePriceTitle
                )

                matchedHeader
                vehicleStage
                vehicleInformation
                IumrahRefundPolicyCard(component: .transfer, compact: false)

                if includesMadinah {
                    haramainExpandedCard
                }

                confirmationButton
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 46)
        }
        .scrollContentBackground(.hidden)
    }

    private var matchedHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isVIP ? .white : .green)
                Text(isVIP
                     ? localized("VIP TRANSFER", "VIP TRANSFER", "VIP TRANSFER", "VIP TRANSFER")
                     : localized("ТРАНСФЕР НАЙДЕН", "TRANSFER MATCHED", "TRANSFER TOPILDI", "ТРАНСФЕР ТОПИЛДИ"))
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(selectedIndex + 1) / \(vehicles.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Text(isVIP
                 ? localized("VIP трансфер", "VIP transfer", "VIP transfer", "VIP трансфер")
                 : localized("Мы нашли свободный автомобиль", "We found an available vehicle", "Bo‘sh avtomobil topildi", "Бўш автомобиль топилди"))
                .font(.system(size: isVIP ? 38 : 32, weight: .bold, design: .rounded))
                .tracking(-0.9)

            Text("\(routeTitle) · \(dateRangeTitle)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vehicleStage: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let pageWidth = max(width * 0.78, 1)

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(isVIP ? Color.black : Color.iumrahCardBackground)

                if isVIP {
                    RadialGradient(
                        colors: [
                            .white.opacity(0.78),
                            .white.opacity(0.34),
                            .white.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 240
                    )
                    .blur(radius: 10)
                    .scaleEffect(1.12)
                }

                TransferStageBackground(
                    label: vehicleClassTitle(selectedVehicle).uppercased(),
                    number: String(format: "%02d", selectedIndex + 1),
                    parallax: dragOffset * 0.16,
                    vip: isVIP
                )

                ForEach(Array(vehicles.enumerated()), id: \.element.id) { index, vehicle in
                    let relative = CGFloat(index - selectedIndex) + (dragOffset / pageWidth)
                    let distance = min(abs(relative), 1.25)
                    let scale = 1 - min(distance, 1) * 0.115
                    let opacity = 1 - min(distance, 1) * 0.46

                    TransferVehicleHero(vehicle: vehicle, active: distance < 0.16)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .offset(
                            x: relative * width * 0.82,
                            y: min(distance, 1) * 8
                        )
                        .zIndex(Double(10 - distance))
                        .accessibilityHidden(index != selectedIndex)
                }
            }
            .contentShape(Rectangle())
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .local)
                    .onChanged { value in
                        guard !isConfirming else { return }
                        dragOffset = resistedTranslation(value.translation.width)
                    }
                    .onEnded { value in
                        guard !isConfirming else { return }
                        finishDrag(value, pageWidth: pageWidth)
                    }
            )
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(isVIP ? Color.white.opacity(0.12) : Color.primary.opacity(0.055), lineWidth: 0.8)
        }
        .shadow(color: isVIP ? .white.opacity(0.06) : .black.opacity(0.06), radius: 32, y: 16)
    }

    private var vehicleInformation: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(vehicleClassTitle(selectedVehicle))
                        .font(.caption.weight(.bold))
                        .tracking(0.85)
                        .foregroundStyle(.secondary)
                    Text(selectedVehicle.modelName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .tracking(-0.45)
                        .contentTransition(.opacity)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Label(availabilityTitle, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isVIP ? .white : .green)
                    if selectedVehicle == .carnival {
                        Text(localized("Рекомендуем", "Recommended", "Tavsiya", "Тавсия"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 9)
                            .frame(height: 25)
                            .background((isVIP ? Color.white : Color.iumrahCareLight).opacity(0.14), in: Capsule())
                    }
                }
            }

            Text(vehicleRecommendationBody(selectedVehicle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 9) {
                metricChip(systemName: "person.2.fill", text: passengerMetric)
                metricChip(systemName: "suitcase.fill", text: luggageMetric)
                if requiredVehicleCount(for: selectedVehicle) > 1 {
                    metricChip(systemName: "car.2.fill", text: "\(requiredVehicleCount(for: selectedVehicle)) ×")
                }
            }

            transferCoverageCard

            Divider()

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("Изменение пакета", "Package change", "Paket o‘zgarishi", "Пакет ўзгариши"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vehicleAddOnTitle)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(localized("Итог сейчас", "Current total", "Joriy jami", "Жорий жами"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentPackagePriceTitle)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(19)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var haramainExpandedCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image("HaramainMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Haramain High Speed Railway")
                        .font(.headline)
                    Text(trainSegmentTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if journey.haramainTrainSelected {
                    Label(localized("Добавлено", "Added", "Qo‘shildi", "Қўшилди"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
            }

            HaramainPhotoGallery(compact: true)

            Text(localized(
                "Замените только междугородний участок Мекка ↔ Медина поездом. Автомобиль до станции и после прибытия остаётся частью вашего iumrah Transfer.",
                "Replace only the Makkah ↔ Madinah intercity segment by train. Your car transfer to the station and after arrival remains part of iumrah Transfer.",
                "Faqat Makka ↔ Madina shaharlararo qismini poyezdga almashtiring. Vokzalgacha va keyingi avtomobil transferi iumrah Transfer tarkibida qoladi.",
                "Фақат Макка ↔ Мадина шаҳарлараро қисмини поездга алмаштиринг. Вокзалгача ва кейинги автомобиль трансфери iumrah Transfer таркибида қолади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                trainFact(icon: "speedometer", title: "300 km/h")
                trainFact(icon: "clock.fill", title: "≈ 2h 20m")
                trainFact(icon: "wifi", title: "Wi‑Fi")
            }

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(localized("Билеты для вашей группы", "Tickets for your party", "Guruhingiz uchun chiptalar", "Гуруҳингиз учун чипталар"))
                            .font(.subheadline.weight(.semibold))
                        Text(localized("Standard", "Standard", "Standard", "Standard") + " · " + usd(Decimal(150)) + " / " + localized("паломник", "pilgrim", "ziyoratchi", "зиёратчи"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("+\(usd(standardTrainPreviewUsd))")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .contentTransition(.numericText())
                }

                Divider()

                CounterRow(
                    title: L10n.text("adults", settings.language),
                    subtitle: usd(Decimal(150)) + " / " + localized("билет", "ticket", "chipta", "чипта"),
                    value: Binding(
                        get: { journey.haramainAdultTickets },
                        set: { journey.setHaramainAdultTickets($0) }
                    ),
                    minimum: 1,
                    maximum: max(1, journey.trip.adults)
                )

                if journey.trip.children > 0 {
                    Divider()
                    CounterRow(
                        title: L10n.text("children", settings.language),
                        subtitle: usd(Decimal(150)) + " / " + localized("место", "seat", "joy", "жой"),
                        value: Binding(
                            get: { journey.haramainChildTickets },
                            set: { journey.setHaramainChildTickets($0) }
                        ),
                        minimum: 0,
                        maximum: journey.trip.children
                    )
                }
            }
            .padding(15)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button {
                journey.ensureHaramainTicketDefaults()
                journey.setHaramainFareClass(.economy)
                journey.setHaramainTrainSelected(!journey.haramainTrainSelected)
                journey.haramainTrainSelected ? IumrahHaptics.success() : IumrahHaptics.selection()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: journey.haramainTrainSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(journey.haramainTrainSelected
                             ? localized("Поезд подключён", "Train added", "Poyezd qo‘shildi", "Поезд қўшилди")
                             : localized("Подключить поезд к поездке", "Add train to this trip", "Poyezdni safarga qo‘shish", "Поездни сафарга қўшиш"))
                            .font(.headline)
                        Text(journey.haramainTrainSelected
                             ? localized("Нажмите, чтобы отключить", "Tap to remove", "Olib tashlash uchun bosing", "Олиб ташлаш учун босинг")
                             : "+" + usd(standardTrainPreviewUsd) + " · Standard")
                            .font(.caption)
                            .opacity(0.72)
                    }
                    Spacer()
                    Image(systemName: journey.haramainTrainSelected ? "checkmark" : "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(journey.haramainTrainSelected ? Color.white : Color.white)
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(journey.haramainTrainSelected ? Color.green : Color.black, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(journey.haramainTrainSelected ? Color.green.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private func trainFact(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private var confirmationButton: some View {
        Button {
            Task { await confirmTransfer() }
        } label: {
            HStack(spacing: 10) {
                if isConfirming { ProgressView().tint(.white) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isConfirming ? confirmingTitle : confirmTitle)
                    if !isConfirming {
                        Text(currentPackagePriceTitle)
                            .font(.caption.monospacedDigit())
                            .opacity(0.74)
                    }
                }
                Spacer(minLength: 10)
                if !isConfirming { Image(systemName: "arrow.right") }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(isConfirming)
    }

    // MARK: - Interaction / pricing

    @MainActor
    private func startDiscoveryIfNeeded() async {
        journey.ensureHaramainTicketDefaults()
        journey.setHaramainFareClass(.economy)

        let selected = journey.selectedTransferVehicle ?? journey.recommendedTransferVehicle()
        selectedIndex = vehicles.firstIndex(of: selected) ?? 1
        if journey.selectedTransferVehicle == nil {
            journey.chooseTransferVehicle(.carnival)
            selectedIndex = vehicles.firstIndex(of: .carnival) ?? 1
        }

        let pricingTask = Task { @MainActor in
            await refreshBasePackagePrice()
        }

        if journey.transferSelectionConfirmed {
            await pricingTask.value
            discoveryPhase = .matched
            return
        }

        searchDuration = Int.random(in: 20...40)
        searchSecond = 0
        for second in 1...searchDuration {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                searchSecond = second
            }
            if second == 6 || second == 13 || second == 21 || second == 30 {
                IumrahHaptics.soft()
            }
        }

        guard !Task.isCancelled else { return }
        journey.chooseTransferVehicle(.carnival)
        selectedIndex = vehicles.firstIndex(of: .carnival) ?? 1
        withAnimation(reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.90)) {
            discoveryPhase = .matched
        }
        IumrahHaptics.success()
    }

    @MainActor
    private func refreshBasePackagePrice() async {
        await journey.buildQuote(forceHotelRefresh: false)
        guard let quote = journey.quote else { return }
        let activeVehicleAddOn = (journey.selectedTransferVehicle ?? journey.recommendedTransferVehicle())
            .publicUpgradeUsd(for: journey.trip.scope)
        let activeTrainAddOn = journey.haramainTrainSelected ? journey.haramainTrainAddOnUsd : 0
        let resolved = quote.totalPackagePrice - activeVehicleAddOn - activeTrainAddOn
        if resolved > 0 { basePackagePriceUsd = resolved }
    }

    private func resistedTranslation(_ raw: CGFloat) -> CGFloat {
        if selectedIndex == 0, raw > 0 { return raw * 0.32 }
        if selectedIndex == vehicles.count - 1, raw < 0 { return raw * 0.32 }
        return raw
    }

    private func finishDrag(_ value: DragGesture.Value, pageWidth: CGFloat) {
        let projected = value.predictedEndTranslation.width
        let threshold = pageWidth * 0.19
        var target = selectedIndex

        if projected < -threshold {
            target = min(vehicles.count - 1, selectedIndex + 1)
        } else if projected > threshold {
            target = max(0, selectedIndex - 1)
        }

        withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
            selectedIndex = target
            dragOffset = 0
        }

        let selected = vehicles[target]
        if journey.selectedTransferVehicle != selected {
            journey.chooseTransferVehicle(selected)
            IumrahHaptics.selection()
        }
    }

    @MainActor
    private func confirmTransfer() async {
        guard !isConfirming else { return }
        isConfirming = true
        confirmationError = nil
        journey.chooseTransferVehicle(selectedVehicle)
        journey.confirmTransferSelection()

        await journey.buildQuote(forceHotelRefresh: false)

        guard journey.hasFinalGeneratorQuote else {
            journey.transferSelectionConfirmed = false
            confirmationError = journey.errorMessage ?? localized(
                "Не удалось подтвердить итоговую конфигурацию поездки. Попробуйте ещё раз.",
                "The trip configuration could not be confirmed. Please try again.",
                "Safar konfiguratsiyasini tasdiqlab bo‘lmadi. Qayta urinib ko‘ring.",
                "Сафар конфигурациясини тасдиқлаб бўлмади. Қайта уриниб кўринг."
            )
            isConfirming = false
            IumrahHaptics.error()
            return
        }

        if let quote = journey.quote {
            let addOns = selectedVehicleAddOnUsd + selectedTrainAddOnUsd
            let resolved = quote.totalPackagePrice - addOns
            if resolved > 0 { basePackagePriceUsd = resolved }
        }

        if !reduceMotion { try? await Task.sleep(for: .milliseconds(320)) }
        IumrahHaptics.success()
        isConfirming = false
        showFinalPackage = true
    }

    // MARK: - Copy / formatting

    private var transferCoverageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Что входит в трансфер", "Included in your transfer", "Transferga kiradi", "Трансферга киради"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    coverageStop(icon: "airplane.arrival", title: localized("Аэропорт", "Airport", "Aeroport", "Аэропорт"))
                    coverageLine
                    coverageStop(icon: "building.2.fill", title: "Makkah")
                    if includesMadinah {
                        coverageLine
                        coverageStop(icon: journey.haramainTrainSelected ? "train.side.front.car" : "car.fill", title: localized("Межгород", "Intercity", "Shaharlararo", "Шаҳарлараро"))
                        coverageLine
                        coverageStop(icon: "building.2.fill", title: "Madinah")
                    }
                    coverageLine
                    coverageStop(icon: "airplane.departure", title: localized("Вылет", "Departure", "Jo‘nab ketish", "Жўнаб кетиш"))
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(14)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func coverageStop(icon: String, title: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(Color.primary.opacity(0.08)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            }
            Text(title).font(.caption2.weight(.semibold)).lineLimit(1)
        }
        .frame(minWidth: 62)
    }

    private var coverageLine: some View {
        Capsule()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 32, height: 2)
            .offset(y: -10)
    }

    private func metricChip(systemName: String, text: String) -> some View {
        Label(text, systemImage: systemName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private func vehicleClassTitle(_ vehicle: TransferVehicleKind) -> String {
        switch vehicle {
        case .malibu: return localized("Sedan", "Sedan", "Sedan", "Sedan")
        case .carnival: return localized("Family", "Family", "Family", "Family")
        case .yukon: return "VIP"
        }
    }

    private func vehicleRecommendationBody(_ vehicle: TransferVehicleKind) -> String {
        switch vehicle {
        case .malibu:
            return localized(
                "Компактный частный трансфер. Доступен без доплаты к текущему пакету.",
                "A compact private transfer, available with no package surcharge.",
                "Ixcham shaxsiy transfer. Joriy paketga qo‘shimcha to‘lovsiz.",
                "Ихчам шахсий трансфер. Жорий пакетга қўшимча тўловсиз."
            )
        case .carnival:
            return localized(
                "Рекомендованный iumrah Family Transfer: больше пространства для семьи и багажа, без доплаты.",
                "The recommended iumrah Family Transfer: more room for your party and luggage with no surcharge.",
                "Tavsiya etilgan iumrah Family Transfer: oila va bagaj uchun ko‘proq joy, qo‘shimcha to‘lovsiz.",
                "Тавсия этилган iumrah Family Transfer: оила ва багаж учун кўпроқ жой, қўшимча тўловсиз."
            )
        case .yukon:
            return localized(
                "VIP-класс для поездки Мекка — Медина: больше пространства, приватности и отдельная премиальная подача.",
                "VIP class for the Makkah–Madinah journey with more space, privacy and a dedicated premium experience.",
                "Makka–Madina safari uchun VIP klass: ko‘proq joy, maxfiylik va premium tajriba.",
                "Макка–Мадина сафари учун VIP класс: кўпроқ жой, махфийлик ва премиум тажриба."
            )
        }
    }

    private func requiredVehicleCount(for vehicle: TransferVehicleKind) -> Int {
        max(1, Int(ceil(Double(max(1, journey.trip.travelerCount)) / Double(vehicle.passengerCapacity))))
    }

    private var passengerMetric: String {
        "\(min(journey.trip.travelerCount, selectedVehicle.passengerCapacity))/\(selectedVehicle.passengerCapacity)"
    }

    private var luggageMetric: String { "≤ \(selectedVehicle.luggageCapacity)" }

    private var availabilityTitle: String {
        localized("Свободен на ваши даты", "Available for your dates", "Sanalaringizda bo‘sh", "Саналарингизда бўш")
    }

    private var vehicleAddOnTitle: String {
        selectedVehicleAddOnUsd > 0 ? "+\(usd(selectedVehicleAddOnUsd))" : "+$0"
    }

    private var routeTitle: String {
        if !includesMadinah { return "JED → Makkah" }
        return journey.trip.arrivalAirport == .madinah
            ? "MED → Madinah → Makkah → JED"
            : "JED → Makkah → Madinah → MED"
    }

    private var trainSegmentTitle: String {
        journey.trip.arrivalAirport == .madinah ? "Madinah → Makkah" : "Makkah → Madinah"
    }

    private var dateRangeTitle: String {
        "\(shortDate(journey.trip.departureDate)) – \(shortDate(journey.trip.returnDate))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private var localeIdentifier: String {
        switch settings.language {
        case .russian: return "ru_RU"
        case .english: return "en_US"
        case .uzbek: return "uz_Latn_UZ"
        case .uzbekCyrillic: return "uz_Cyrl_UZ"
        }
    }

    private var currentPackagePriceTitle: String {
        guard let currentPackageTotalUsd else { return "—" }
        return usd(currentPackageTotalUsd)
    }

    private var haramainTicketSummary: String {
        let count = journey.haramainTicketCount > 0 ? journey.haramainTicketCount : max(1, journey.trip.adults + journey.trip.children)
        return "\(count) × $150 · Standard"
    }

    private var standardTrainPreviewUsd: Decimal {
        let count = journey.haramainTicketCount > 0 ? journey.haramainTicketCount : max(1, journey.trip.adults + journey.trip.children)
        return Decimal(150 * count)
    }

    private var confirmTitle: String {
        localized("Подтвердить трансфер", "Confirm transfer", "Transferni tasdiqlash", "Трансферни тасдиқлаш")
    }

    private var confirmingTitle: String {
        localized("Подтверждаем трансфер…", "Confirming transfer…", "Transfer tasdiqlanmoqda…", "Трансфер тасдиқланмоқда…")
    }

    private var errorTitle: String {
        localized("Не удалось продолжить", "Could not continue", "Davom ettirib bo‘lmadi", "Давом эттириб бўлмади")
    }

    private func usd(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value).doubleValue
        return String(format: "$%.0f", number)
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        transferLocalized(settings.language, russian: ru, english: en, uzbek: uz, uzbekCyrillic: uzCy)
    }
}

// MARK: - Apple Maps live-search scene

private struct TransferLiveSearchMap: View {
    let second: Int
    let searchDuration: Int
    let reduceMotion: Bool

    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 21.4257, longitude: 39.8264),
            distance: 7_400,
            heading: 0,
            pitch: 38
        )
    )

    private static let makkah = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
    private let candidates = TransferSearchCandidate.defaults

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            MapCircle(center: Self.makkah, radius: searchRadiusMeters)
                .foregroundStyle(Color.blue.opacity(0.075))
                .stroke(Color.blue.opacity(0.44), lineWidth: 2)

            Annotation("Makkah", coordinate: Self.makkah, anchor: .center) {
                TransferSearchCenterPulse(reduceMotion: reduceMotion)
            }

            ForEach(candidates) { candidate in
                Annotation(candidate.id, coordinate: candidate.coordinate(at: reduceMotion ? 0 : second), anchor: .center) {
                    TransferSearchCarPin(emphasis: candidate.emphasis, active: second >= candidate.appearSecond)
                }
            }
        }
        .mapStyle(
            .standard(
                elevation: .realistic,
                pointsOfInterest: .excludingAll,
                showsTraffic: true
            )
        )
        .overlay(alignment: .topTrailing) {
            Label("Makkah", systemImage: "location.fill")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 176)
                .padding(.trailing, 16)
        }
        .onChange(of: second) { _, value in
            guard !reduceMotion, value > 0, value % 5 == 0 else { return }
            withAnimation(.easeInOut(duration: 2.1)) {
                position = .camera(
                    MapCamera(
                        centerCoordinate: Self.makkah,
                        distance: min(12_000, 7_400 + Double(value) * 105),
                        heading: 0,
                        pitch: 34
                    )
                )
            }
        }
        .accessibilityLabel("Live transfer search map in Makkah")
    }

    private var searchRadiusMeters: CLLocationDistance {
        let denominator = max(1, searchDuration)
        let progress = min(1, Double(second) / Double(denominator))
        return 650 + (5_900 * progress)
    }
}

private struct TransferSearchCenterPulse: View {
    let reduceMotion: Bool
    @State private var animate = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.blue.opacity(0.46 - Double(index) * 0.09), lineWidth: 2)
                        .frame(width: 34, height: 34)
                        .scaleEffect(animate ? CGFloat(3.0 + Double(index) * 0.72) : 0.78)
                        .opacity(animate ? 0.02 : 0.72)
                        .animation(
                            .easeOut(duration: 2.6)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.55),
                            value: animate
                        )
                }
            }

            Circle()
                .fill(Color.blue.opacity(0.14))
                .frame(width: 48, height: 48)
            Circle()
                .fill(.white)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.blue, lineWidth: 5))
                .shadow(color: .black.opacity(0.16), radius: 7, y: 2)
        }
        .onAppear { animate = true }
    }
}

private struct TransferSearchActivityBar: View {
    let second: Int
    @State private var travel = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.09))
                Capsule()
                    .fill(Color.blue)
                    .frame(width: max(68, width * 0.34))
                    .offset(x: travel ? max(0, width * 0.66) : 0)
            }
        }
        .frame(height: 5)
        .clipShape(Capsule())
        .onAppear { travel = true }
        .animation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true), value: travel)
        .accessibilityHidden(true)
    }
}

private struct TransferSearchCarPin: View {
    let emphasis: Bool
    let active: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(active ? Color.black : Color.black.opacity(0.36))
                .frame(width: emphasis ? 46 : 40, height: emphasis ? 46 : 40)
                .overlay {
                    Circle().stroke(Color.white.opacity(active ? 0.92 : 0.45), lineWidth: 2)
                }
                .shadow(color: .black.opacity(active ? 0.30 : 0.12), radius: 10, y: 4)

            Image(systemName: "car.fill")
                .font(.system(size: emphasis ? 18 : 16, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .scaleEffect(active ? 1 : 0.74)
        .opacity(active ? 1 : 0.42)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: active)
    }
}

private struct TransferSearchCandidate: Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let phase: Double
    let appearSecond: Int
    let emphasis: Bool

    func coordinate(at second: Int) -> CLLocationCoordinate2D {
        let t = Double(second) * 0.22 + phase
        let lat = latitude + sin(t) * 0.00115 + cos(t * 0.55) * 0.00038
        let lon = longitude + cos(t * 0.88) * 0.00135 + sin(t * 0.46) * 0.00042
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static let defaults: [TransferSearchCandidate] = [
        .init(id: "A", latitude: 21.4314, longitude: 39.8347, phase: 0.2, appearSecond: 1, emphasis: false),
        .init(id: "B", latitude: 21.4159, longitude: 39.8382, phase: 1.0, appearSecond: 3, emphasis: true),
        .init(id: "C", latitude: 21.4378, longitude: 39.8171, phase: 1.8, appearSecond: 5, emphasis: false),
        .init(id: "D", latitude: 21.4108, longitude: 39.8164, phase: 2.5, appearSecond: 8, emphasis: false),
        .init(id: "E", latitude: 21.4475, longitude: 39.8292, phase: 3.2, appearSecond: 11, emphasis: true),
        .init(id: "F", latitude: 21.4234, longitude: 39.8505, phase: 4.1, appearSecond: 14, emphasis: false),
        .init(id: "G", latitude: 21.4019, longitude: 39.8298, phase: 5.0, appearSecond: 18, emphasis: false),
        .init(id: "H", latitude: 21.4391, longitude: 39.8460, phase: 5.9, appearSecond: 21, emphasis: true),
        .init(id: "I", latitude: 21.4201, longitude: 39.8058, phase: 6.6, appearSecond: 24, emphasis: false)
    ]
}

// MARK: - Cinematic vehicle stage

private struct TransferVehicleHero: View {
    let vehicle: TransferVehicleKind
    let active: Bool

    var body: some View {
        ZStack {
            if active {
                Ellipse()
                    .fill(Color.black.opacity(vehicle == .yukon ? 0.18 : 0.12))
                    .frame(width: vehicle == .malibu ? 260 : 300, height: 38)
                    .blur(radius: 17)
                    .offset(y: 76)
            }

            Image(vehicle.assetName)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, vehicle == .malibu ? 18 : 6)
                .accessibilityLabel(vehicle.modelName)
        }
        .padding(.horizontal, 4)
    }
}

private struct TransferStageBackground: View {
    let label: String
    let number: String
    let parallax: CGFloat
    let vip: Bool

    var body: some View {
        ZStack {
            Text(number)
                .font(.system(size: 156, weight: .black, design: .rounded))
                .foregroundStyle((vip ? Color.white : Color.primary).opacity(vip ? 0.055 : 0.035))
                .offset(x: parallax * 0.42, y: -58)

            Text(label)
                .font(.system(size: label == "VIP" ? 104 : 72, weight: .black, design: .rounded))
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle((vip ? Color.white : Color.primary).opacity(vip ? 0.12 : 0.06))
                .offset(x: parallax, y: 84)
                .padding(.horizontal, 18)
        }
    }
}

// MARK: - Haramain gallery / ticket booking

private struct HaramainPhotoGallery: View {
    let compact: Bool
    private let images = ["HaramainHero", "HaramainGalleryStation", "HaramainGalleryInterior", "HaramainGalleryTrain"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(images, id: \.self) { name in
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: compact ? 238 : 292, height: compact ? 145 : 184)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 20 : 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: compact ? 20 : 24, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.7)
                        }
                }
            }
        }
    }
}

private func transferLocalized(
    _ language: AppSettingsStore.Language,
    russian: String,
    english: String,
    uzbek: String,
    uzbekCyrillic: String
) -> String {
    switch language {
    case .russian: return russian
    case .english: return english
    case .uzbek: return uzbek
    case .uzbekCyrillic: return uzbekCyrillic
    }
}
