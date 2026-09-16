import SwiftUI

private enum FinalPackageServiceSection: Hashable {
    case outboundFlight
    case makkahHotel
    case madinahHotel
    case returnFlight
    case transfer
    case haramain
    case visa
    case meals
}


private enum FinalPackageSupportSheet: String, Identifiable {
    case visa
    case guide

    var id: String { rawValue }
}

struct FinalPackageView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @ObservedObject private var push = PushNotificationManager.shared

    @State private var isProfileSheetPresented = false
    @State private var isSubmitting = false
    @State private var createdSession: StoredBookingSession?
    @State private var errorMessage: String?
    @State private var showCreatedBooking = false
    @State private var isCalculatingPrice = false
    @State private var showCareExplanation = false
    @State private var presentedSupportSheet: FinalPackageSupportSheet?
    @State private var expandedService: FinalPackageServiceSection?
    @State private var comparisonOptions: [PackageTierComparisonOption] = []
    @State private var focusedComparisonTier: PackageTier?
    @State private var isLoadingComparisons = false
    @State private var isApplyingComparison = false

    private var needsMadinah: Bool { journey.trip.scope == .makkahAndMadinah }
    private var canBook: Bool {
        journey.hasFinalGeneratorQuote &&
        journey.selectedHotel != nil &&
        journey.selectedOutbound?.isVerifiedForBooking == true &&
        (!journey.trip.isRoundTripFlight || journey.selectedInbound?.isVerifiedForBooking == true) &&
        (!needsMadinah || journey.selectedMadinahHotel != nil)
    }

    var body: some View {
        Group {
            if let createdSession {
                IumrahBookingCelebrationView(
                    session: createdSession,
                    onOpenBooking: { showCreatedBooking = true },
                    onHome: {
                        chrome.shouldStartTripBuilder = false
                        journey.resetAfterTripChange()
                        chrome.navigate(to: .home)
                    }
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        IumrahGeneratorHeader(stage: .ready)
                        packageHeader
                        if journey.quote != nil, journey.hasFinalGeneratorQuote {
                            packageTierCarousel
                                .padding(.horizontal, -IumrahDesign.pagePadding)
                            packageRecommendationCard
                            packageDifferenceCard
                            packageSupportShortcutsCard
                        } else {
                            pricingStatusCard
                        }
                        includedServicesCard
                        IumrahRefundPolicyCard(component: .package, compact: false)
                        IumrahManualPaymentNotice()
                        careReassuranceCard
                        notificationCard

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        packagePrimaryActionButton
                    }
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .background(Color.iumrahPageBackground.ignoresSafeArea())
            }
        }
        .iumrahInternalNavigation(progress: .ready, showsGeneratorAmbient: true)
        .task {
            if !journey.hasFinalGeneratorQuote {
                await recalculatePrice(forceHotelRefresh: false)
            } else {
                await loadPackageTierComparisons(resetFocus: true)
            }
            await push.refreshAndRegisterIfAllowed()
        }
        .sheet(isPresented: $isProfileSheetPresented) {
            BookingProfileCaptureSheet {
                Task { await createBooking() }
            }
            .environmentObject(settings)
        }
        .sheet(isPresented: $showCareExplanation) {
            UmrahCarePackageExplanationView()
                .environmentObject(settings)
        }
        .sheet(item: $presentedSupportSheet) { kind in
            FinalPackageInformationSheet(kind: kind, language: settings.language)
        }
        .navigationDestination(isPresented: $showCreatedBooking) {
            if let createdSession {
                BookingDetailView(bookingID: createdSession.id)
            }
        }
    }

    private var pricingStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if isCalculatingPrice {
                    ProgressView()
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(isCalculatingPrice ? calculatingPriceTitle : pricingUnavailableTitle)
                        .font(.headline)
                    Text(isCalculatingPrice ? calculatingPriceBody : (journey.errorMessage ?? pricingUnavailableBody))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if !isCalculatingPrice {
                VStack(spacing: 10) {
                    Button(retryPricingTitle) {
                        Task { await recalculatePrice(forceHotelRefresh: true) }
                    }
                    .buttonStyle(IumrahSecondaryButtonStyle())

                    if isHotelVerificationFailure {
                        NavigationLink {
                            PrimaryHotelView()
                        } label: {
                            Text(changeHotelTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IumrahSecondaryButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    @MainActor
    private func recalculatePrice(forceHotelRefresh: Bool) async {
        guard !isCalculatingPrice else { return }
        isCalculatingPrice = true
        await journey.buildQuote(forceHotelRefresh: forceHotelRefresh)
        isCalculatingPrice = false
        if journey.hasFinalGeneratorQuote {
            IumrahHaptics.success()
            await loadPackageTierComparisons(resetFocus: true)
        }
    }

    @MainActor
    private func loadPackageTierComparisons(resetFocus: Bool) async {
        guard journey.hasFinalGeneratorQuote else { return }

        // Capture the package the pilgrim actually finished configuring before
        // the asynchronous comparison request starts. The comparison list itself
        // is ordered Economy → Luxury, so without restoring this anchor SwiftUI
        // can briefly adopt the first item (Economy) when the full list arrives.
        let selectedTier = journey.trip.packageTier

        if resetFocus || focusedComparisonTier == nil {
            focusedComparisonTier = selectedTier
        }

        isLoadingComparisons = true
        let options = await journey.buildPackageTierComparisons()
        comparisonOptions = options
        isLoadingComparisons = false

        if resetFocus {
            // Re-apply the selected package after the carousel has its final data.
            // No animation: entering the page should open directly on the user's
            // package, not visibly slide there from Economy.
            await Task.yield()
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                focusedComparisonTier = selectedTier
            }
        }
    }

    @MainActor
    private func applyPackageTierComparison(_ option: PackageTierComparisonOption) async {
        guard option.isAvailable, option.tier != journey.trip.packageTier, !isApplyingComparison else { return }
        isApplyingComparison = true
        journey.applyPackageTierComparison(option)
        focusedComparisonTier = option.tier
        comparisonOptions = await journey.buildPackageTierComparisons()
        isApplyingComparison = false
        IumrahHaptics.success()
    }

    private var calculatingPriceTitle: String {
        switch settings.language {
        case .russian: return "Рассчитываем цену пакета"
        case .english: return "Calculating your package price"
        case .uzbek: return "Paket narxi hisoblanmoqda"
        case .uzbekCyrillic: return "Пакет нархи ҳисобланмоқда"
        }
    }

    private var calculatingPriceBody: String {
        switch settings.language {
        case .russian: return "Собираем выбранные перелёты, отели и услуги в одну итоговую цену поездки."
        case .english: return "Combining your selected flights, hotels and services into one trip price."
        case .uzbek: return "Tanlangan reyslar, mehmonxonalar va xizmatlarni safarning yagona narxiga birlashtiramiz."
        case .uzbekCyrillic: return "Танланган рейслар, меҳмонхоналар ва хизматларни сафарнинг ягона нархига бирлаштирамиз."
        }
    }

    private var pricingUnavailableTitle: String {
        switch settings.language {
        case .russian: return "Не удалось обновить пакет"
        case .english: return "The package could not be refreshed"
        case .uzbek: return "Paketni yangilab bo‘lmadi"
        case .uzbekCyrillic: return "Пакетни янгилаб бўлмади"
        }
    }

    private var pricingUnavailableBody: String {
        switch settings.language {
        case .russian: return "Ваш выбор сохранён. Повторная проверка обновит доступность выбранных отелей и пересчитает поездку без потери маршрута."
        case .english: return "Your selections are preserved. Retry will refresh hotel availability and recalculate the trip without losing your route."
        case .uzbek: return "Tanlovlaringiz saqlanadi. Qayta tekshirish mehmonxona mavjudligini yangilaydi va yo‘nalishni yo‘qotmasdan safarni qayta hisoblaydi."
        case .uzbekCyrillic: return "Танловларингиз сақланади. Қайта текшириш меҳмонхона мавжудлигини янгилайди ва йўналишни йўқотмасдан сафарни қайта ҳисоблайди."
        }
    }

    private var isHotelVerificationFailure: Bool {
        journey.errorMessage?.localizedCaseInsensitiveContains("Primary Hotel") == true
    }

    private var changeHotelTitle: String {
        switch settings.language {
        case .russian: return "Изменить отель"
        case .english: return "Change hotel"
        case .uzbek: return "Mehmonxonani o‘zgartirish"
        case .uzbekCyrillic: return "Меҳмонхонани ўзгартириш"
        }
    }

    private var retryPricingTitle: String {
        switch settings.language {
        case .russian: return "Повторно проверить пакет"
        case .english: return "Recheck package"
        case .uzbek: return "Narxni qayta olish"
        case .uzbekCyrillic: return "Нархни қайта олиш"
        }
    }

    private var focusedComparisonOption: PackageTierComparisonOption? {
        let tier = focusedComparisonTier ?? journey.trip.packageTier
        return displayComparisonOptions.first { $0.tier == tier } ?? displayComparisonOptions.first
    }

    @ViewBuilder
    private var packagePrimaryActionButton: some View {
        if journey.quote != nil, journey.hasFinalGeneratorQuote, let option = focusedComparisonOption {
            if option.tier == journey.trip.packageTier {
                Button {
                    isProfileSheetPresented = true
                    IumrahHaptics.soft()
                } label: {
                    HStack(spacing: 10) {
                        if isSubmitting { ProgressView().tint(.white).controlSize(.small) }
                        Text(continueBookingTitle)
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 6)
                        if !isSubmitting {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canBook || isSubmitting || isApplyingComparison)
                .opacity(canBook && !isSubmitting && !isApplyingComparison ? 1 : 0.45)
            } else if option.isAvailable {
                Button {
                    Task { await applyPackageTierComparison(option) }
                } label: {
                    HStack(spacing: 10) {
                        if isApplyingComparison {
                            ProgressView().tint(.white).controlSize(.small)
                        }
                        Text(selectComparisonTitle(option))
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Spacer(minLength: 6)
                        if !isApplyingComparison {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isApplyingComparison)
            }
        }
    }

    private var packageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(FlowCopy.text(.finalEyebrow, settings.language))
                .font(.caption.weight(.bold))
                .tracking(1.25)
                .foregroundStyle(.secondary)
            Text(FlowCopy.text(.finalTitle, settings.language))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.9)
            Text(FlowCopy.text(.finalBody, settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var packageTierCarousel: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(comparisonSectionTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer(minLength: 8)
                Text(comparisonSectionHint)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let cardWidth = max(286, proxy.size.width * 0.80)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(displayComparisonOptions) { option in
                            packageTierCard(option)
                                .frame(width: cardWidth, height: 492)
                                .scaleEffect(focusedComparisonTier == option.tier ? 1 : 0.965)
                                .opacity(focusedComparisonTier == option.tier ? 1 : 0.86)
                                .animation(.spring(response: 0.34, dampingFraction: 0.9), value: focusedComparisonTier)
                                .id(option.tier)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 12)
                    .padding(.horizontal, max(0, (proxy.size.width - cardWidth) / 2))
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focusedComparisonTier, anchor: .center)
            }
            .frame(height: 516)

            packageTierIndicator

            HStack(spacing: 8) {
                Image(systemName: "airplane")
                    .font(.caption.weight(.bold))
                Text(fixedFlightComparisonNote)
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(.secondary)

            if isLoadingComparisons {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(comparisonLoadingTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
    }

    private var displayComparisonOptions: [PackageTierComparisonOption] {
        if !comparisonOptions.isEmpty { return comparisonOptions }
        return [PackageTierComparisonOption(
            tier: journey.trip.packageTier,
            quote: journey.quote,
            makkahHotel: journey.selectedHotel,
            madinahHotel: journey.selectedMadinahHotel,
            unavailableReason: nil
        )]
    }

    @ViewBuilder
    private func packageTierCard(_ option: PackageTierComparisonOption) -> some View {
        let isCurrent = option.tier == journey.trip.packageTier
        let theme = packageTheme(option.tier)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(option.tier.title(settings.language).uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.15)
                    .foregroundStyle(.white.opacity(0.78))

                if isCurrent {
                    Text(currentPackageBadge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(Color.white.opacity(0.16), in: Capsule())
                }
                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Image(systemName: "person.fill")
                    Text("\(journey.trip.travelerCount)")
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.white.opacity(0.12), in: Capsule())
            }

            Spacer().frame(height: 20)

            if let quote = option.quote {
                Text(money(quote.totalPackagePrice, quote.currency))
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .tracking(-1.9)
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("\(money(quote.pricePerPerson, quote.currency)) / \(perPersonShortTitle)")
                    Text("·")
                    Text(packageForTravelersTitle)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                if !isCurrent, let delta = comparisonDeltaText(option) {
                    Text(delta)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.94))
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .padding(.top, 10)
                }
            } else {
                Text(priceTemporarilyUnavailableTitle)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                Text(priceTemporarilyUnavailableBody)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.top, 7)
            }

            Spacer().frame(height: 13)

            Text(packagePositionTitle(option.tier))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            Text(packagePositionBody(option.tier))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            Spacer().frame(height: 13)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(packageBenefits(option), id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 1)
                        Text(benefit)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.84))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 12)

            if isCurrent {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(continueBelowTitle)
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if option.isAvailable {
                HStack(spacing: 10) {
                    Text(selectComparisonTitle(option))
                        .font(.footnote.weight(.bold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .foregroundStyle(.white)
        .padding(21)
        .background {
            LinearGradient(
                stops: [
                    .init(color: theme.top, location: 0.00),
                    .init(color: theme.midTop, location: 0.34),
                    .init(color: theme.midBottom, location: 0.70),
                    .init(color: theme.bottom, location: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(isCurrent ? 0.16 : 0.075), lineWidth: 0.7)
        }
    }


    private struct PackageCardTheme {
        let top: Color
        let midTop: Color
        let midBottom: Color
        let bottom: Color
    }

    private func packageTheme(_ tier: PackageTier) -> PackageCardTheme {
        switch tier {
        case .economy:
            return PackageCardTheme(
                top: Color(red: 0.22, green: 0.34, blue: 0.27),
                midTop: Color(red: 0.15, green: 0.25, blue: 0.20),
                midBottom: Color(red: 0.09, green: 0.15, blue: 0.12),
                bottom: Color(red: 0.045, green: 0.065, blue: 0.055)
            )
        case .standard:
            return PackageCardTheme(
                top: Color(red: 0.17, green: 0.22, blue: 0.50),
                midTop: Color(red: 0.12, green: 0.17, blue: 0.38),
                midBottom: Color(red: 0.075, green: 0.10, blue: 0.25),
                bottom: Color(red: 0.035, green: 0.045, blue: 0.12)
            )
        case .comfort:
            return PackageCardTheme(
                top: Color(red: 0.06, green: 0.38, blue: 0.40),
                midTop: Color(red: 0.045, green: 0.29, blue: 0.32),
                midBottom: Color(red: 0.03, green: 0.18, blue: 0.21),
                bottom: Color(red: 0.018, green: 0.075, blue: 0.095)
            )
        case .luxury:
            return PackageCardTheme(
                top: Color(red: 0.64, green: 0.49, blue: 0.18),
                midTop: Color(red: 0.48, green: 0.34, blue: 0.105),
                midBottom: Color(red: 0.30, green: 0.19, blue: 0.065),
                bottom: Color(red: 0.13, green: 0.075, blue: 0.028)
            )
        }
    }

    private var packageTierIndicator: some View {

        HStack(spacing: 7) {
            ForEach(PackageTier.allCases) { tier in
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        focusedComparisonTier = tier
                    }
                    IumrahHaptics.selection()
                } label: {
                    Text(tier.title(settings.language))
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(focusedComparisonTier == tier ? Color.primary : Color.secondary)
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .background(
                            focusedComparisonTier == tier ? Color.primary.opacity(0.08) : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var continueBelowTitle: String {
        switch settings.language {
        case .russian: return "Продолжение — внизу страницы"
        case .english: return "Continue below on this page"
        case .uzbek: return "Davomi sahifa pastida"
        case .uzbekCyrillic: return "Давоми саҳифа пастида"
        }
    }

    private var changePackageBelowTitle: String {
        switch settings.language {
        case .russian: return "Выбор пакета — кнопкой внизу"
        case .english: return "Choose this package with the button below"
        case .uzbek: return "Paketni pastdagi tugma bilan tanlang"
        case .uzbekCyrillic: return "Пакетни пастдаги тугма билан танланг"
        }
    }

    private var packageRecommendationCard: some View {
        let tier = focusedComparisonTier ?? journey.trip.packageTier
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                Text(iumrahRecommendationTitle)
                    .font(.caption.weight(.bold))
                    .tracking(0.6)
                Spacer(minLength: 0)
                if tier == journey.trip.packageTier {
                    Text(currentPackageBadge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.23, blue: 0.60))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(Color.white.opacity(0.75), in: Capsule())
                }
            }
            .foregroundStyle(Color(red: 0.35, green: 0.23, blue: 0.60))

            Text(packageRecommendationHeadline(tier))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.28, green: 0.18, blue: 0.48))
                .fixedSize(horizontal: false, vertical: true)

            Text(packageRecommendationText(tier))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(red: 0.33, green: 0.24, blue: 0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.90, green: 0.87, blue: 1.0), Color(red: 0.97, green: 0.94, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.56), lineWidth: 0.9)
        }
    }

    private var packageSupportShortcutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(packageSupportTitle)
                .font(.system(size: 21, weight: .bold, design: .rounded))
            Text(packageSupportBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                packageSupportButton(
                    icon: "doc.text.fill",
                    title: visaSupportTitle,
                    subtitle: visaSupportSubtitle
                ) {
                    presentedSupportSheet = .visa
                    IumrahHaptics.selection()
                }

                packageSupportButton(
                    icon: "heart.fill",
                    title: careSupportTitle,
                    subtitle: careSupportSubtitle
                ) {
                    showCareExplanation = true
                    IumrahHaptics.selection()
                }

                packageSupportButton(
                    icon: "person.2.fill",
                    title: guideSupportTitle,
                    subtitle: guideSupportSubtitle
                ) {
                    presentedSupportSheet = .guide
                    IumrahHaptics.selection()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    private func packageSupportButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: icon, role: icon == "doc.text.fill" ? .document : .care, size: 40, symbolSize: 14, cornerRadius: 13)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(14)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var packageDifferenceCard: some View {
        if let target = differenceTargetOption,
           let currentHotel = journey.selectedHotel,
           let targetHotel = target.makkahHotel {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(differenceCardTitle(target.tier))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        if let delta = comparisonDeltaText(target) {
                            Text(delta)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: target.tier.primaryHotelStars > journey.trip.packageTier.primaryHotelStars ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)

                comparisonFactRow(
                    title: makkahHotelComparisonTitle,
                    current: currentHotel.name,
                    target: targetHotel.name
                )

                if needsMadinah,
                   let currentMadinah = journey.selectedMadinahHotel,
                   let targetMadinah = target.madinahHotel {
                    comparisonFactRow(
                        title: madinahHotelComparisonTitle,
                        current: currentMadinah.name,
                        target: targetMadinah.name
                    )
                }

                comparisonFactRow(
                    title: hotelLevelComparisonTitle,
                    current: hotelLevelText(journey.trip.packageTier),
                    target: hotelLevelText(target.tier)
                )

                comparisonFactRow(
                    title: mealsComparisonTitle,
                    current: mealsLevelText(journey.trip.packageTier),
                    target: mealsLevelText(target.tier),
                    showsDivider: false
                )
            }
            .padding(18)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
        }
    }

    private func comparisonFactRow(
        title: String,
        current: String,
        target: String,
        showsDivider: Bool = true
    ) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(current)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                    Text(target)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 11)

            if showsDivider { Divider().opacity(0.45) }
        }
    }

    private var differenceTargetOption: PackageTierComparisonOption? {
        let currentTier = journey.trip.packageTier
        let focusedTier = focusedComparisonTier ?? currentTier
        if focusedTier != currentTier {
            return comparisonOptions.first(where: { $0.tier == focusedTier && $0.isAvailable })
        }

        guard let currentIndex = PackageTier.allCases.firstIndex(of: currentTier) else { return nil }
        let higher = PackageTier.allCases.dropFirst(currentIndex + 1)
        for tier in higher {
            if let option = comparisonOptions.first(where: { $0.tier == tier && $0.isAvailable }) { return option }
        }
        for tier in PackageTier.allCases.prefix(currentIndex).reversed() {
            if let option = comparisonOptions.first(where: { $0.tier == tier && $0.isAvailable }) { return option }
        }
        return nil
    }

    private func packageBenefits(_ option: PackageTierComparisonOption) -> [String] {
        let makkah = option.makkahHotel?.name ?? fallbackPrimaryHotelTitle(option.tier, city: .makkah)
        let madinah = option.madinahHotel?.name ?? fallbackPrimaryHotelTitle(option.tier, city: .madinah)

        switch option.tier {
        case .economy:
            return [
                localizedFinal("Практичное размещение 1–2★ / Primary Hotel", "Practical 1–2★ / Primary Hotel stay", "Amaliy 1–2★ / Primary Hotel", "Амалий 1–2★ / Primary Hotel"),
                makkah,
                localizedFinal("Более доступная Umrah без ухода в удалённые от Харама районы", "A more accessible Umrah without sending you far from the Haram area", "Haramdan juda uzoq bo‘lmagan, ko‘proq hamyonbop Umra", "Ҳарамдан жуда узоқ бўлмаган, кўпроқ ҳамёнбоп Умра")
            ]
        case .standard:
            return [
                "\(makkah) · 3★",
                needsMadinah ? madinah : localizedFinal("Оптимальная логистика поездки", "Balanced trip logistics", "Muvozanatli safar logistikasi", "Мувозанатли сафар логистикаси"),
                localizedFinal("Хороший комфорт и честная цена без лишней переплаты", "Good comfort with a fair price and no unnecessary overpayment", "Yaxshi qulaylik va ortiqcha to‘lovsiz halol narx", "Яхши қулайлик ва ортиқча тўловсиз ҳалол нарх")
            ]
        case .comfort:
            return [
                "\(makkah) · 4★",
                localizedFinal("Завтрак включён без доплаты", "Breakfast included at no extra charge", "Nonushta qo‘shimcha to‘lovsiz", "Нонушта қўшимча тўловсиз"),
                localizedFinal("Ближе к Хараму и комфортнее по качеству проживания", "Closer to the Haram with stronger day-to-day comfort", "Haramga yaqinroq va yashash sifati qulayroq", "Ҳарамга яқинроқ ва яшаш сифати қулайроқ")
            ]
        case .luxury:
            return [
                "\(makkah) · 5★",
                needsMadinah ? "\(madinah) · 5★" : localizedFinal("Премиальный уровень проживания", "Premium stay level", "Premium yashash darajasi", "Премиум яшаш даражаси"),
                localizedFinal("Расположение у Харама и высокий класс каждой части поездки", "Haram-front positioning with a higher class across the journey", "Haram yonidagi joylashuv va safarning har bir qismida yuqori daraja", "Ҳарам ёнидаги жойлашув ва сафарнинг ҳар бир қисмида юқори даража")
            ]
        }
    }

    private enum ComparisonCity: Equatable { case makkah, madinah }

    private func fallbackPrimaryHotelTitle(_ tier: PackageTier, city: ComparisonCity) -> String {
        let cityName = city == .makkah ? "Makkah" : "Madinah"
        return "\(cityName) · Primary Hotel · \(tier.primaryHotelStars)★"
    }

    private func packagePositionTitle(_ tier: PackageTier) -> String {
        switch tier {
        case .economy: return localizedFinal("Максимальная экономия", "Maximum savings", "Maksimal tejamkorlik", "Максимал тежамкорлик")
        case .standard: return localizedFinal("Оптимальный баланс", "Balanced choice", "Muvozanatli tanlov", "Мувозанатли танлов")
        case .comfort: return localizedFinal("Больше комфорта каждый день", "More comfort every day", "Har kuni ko‘proq qulaylik", "Ҳар куни кўпроқ қулайлик")
        case .luxury: return localizedFinal("Премиальная Umrah без компромиссов", "Premium Umrah with fewer compromises", "Kamroq murosali premium Umra", "Камроқ муросали премиум Умра")
        }
    }

    private func packagePositionBody(_ tier: PackageTier) -> String {
        switch tier {
        case .economy:
            return localizedFinal("Для тех, кому важнее итоговая стоимость, чем категория проживания.", "For travelers who prioritize the final price over hotel category.", "Yakuniy narx mehmonxona toifasidan muhimroq bo‘lganlar uchun.", "Якуний нарх меҳмонхона тоифасидан муҳимроқ бўлганлар учун.")
        case .standard:
            return localizedFinal("Основные удобства сохранены, а стоимость остаётся под контролем.", "Core conveniences stay intact while the total remains controlled.", "Asosiy qulayliklar saqlanadi, umumiy narx nazoratda qoladi.", "Асосий қулайликлар сақланади, умумий нарх назоратда қолади.")
        case .comfort:
            return localizedFinal("Доплата направлена прежде всего на уровень и расположение отеля.", "The upgrade is focused primarily on hotel level and location.", "Qo‘shimcha qiymat asosan mehmonxona darajasi va joylashuviga ketadi.", "Қўшимча қиймат асосан меҳмонхона даражаси ва жойлашувига кетади.")
        case .luxury:
            return localizedFinal("Вы платите не за больше услуг, а за более высокий уровень ключевых частей поездки.", "You are not paying for more items, but for a higher level of the journey's key parts.", "Ko‘proq xizmat uchun emas, safarning asosiy qismlarining yuqori darajasi uchun to‘laysiz.", "Кўпроқ хизмат учун эмас, сафарнинг асосий қисмларининг юқори даражаси учун тўлайсиз.")
        }
    }

    private func packageRecommendationHeadline(_ tier: PackageTier) -> String {
        switch tier {
        case .economy:
            return localizedFinal("Доступная Umrah без тяжёлой логистики", "Accessible Umrah without difficult logistics", "Qiyin logistikasiz hamyonbop Umra", "Қийин логистикасиз ҳамёнбоп Умра")
        case .standard:
            return localizedFinal("Проверенный баланс цены и качества", "A proven balance of price and quality", "Narx va sifatning sinalgan muvozanati", "Нарх ва сифатнинг синалган мувозанати")
        case .comfort:
            return localizedFinal("Ближе к Хараму и легче каждый день", "Closer to the Haram and easier every day", "Haramga yaqinroq va har kuni yengilroq", "Ҳарамга яқинроқ ва ҳар куни енгилроқ")
        case .luxury:
            return localizedFinal("Премиальный уровень рядом с Харамом", "A premium level right by the Haram", "Haram yonidagi premium daraja", "Ҳарам ёнидаги премиум даража")
        }
    }

    private func packageRecommendationText(_ tier: PackageTier) -> String {
        switch tier {
        case .economy:
            return localizedFinal(
                "Мы старались сделать этот уровень действительно доступным: эконом‑отели не уводят Вас на 5 километров от Харама. Обычно это размещение примерно в 1–2 км, в районе Ajyad и по прямой дороге к Хараму, с понятной логистикой, хорошими комнатами и очень приемлемой ценой.",
                "We intentionally keep this level genuinely accessible: Economy hotels do not push you 5 km away from the Haram. They are typically around 1–2 km away, often in the Ajyad area and on a direct route toward the Haram, with clear logistics, decent rooms and a very approachable price.",
                "Bu darajani haqiqatan hamyonbop qilishga harakat qildik: Economy mehmonxonalari Sizni Haramdan 5 km uzoqqa olib ketmaydi. Odatda ular 1–2 km atrofida, ko‘pincha Ajyad hududida va Haramga to‘g‘ri yo‘nalishda bo‘ladi — logistika tushunarli, xonalar yaxshi va narx juda maqbul.",
                "Бу даражани ҳақиқатан ҳамёнбоп қилишга ҳаракат қилдик: Economy меҳмонхоналари Сизни Ҳарамдан 5 км узоққа олиб кетмайди. Одатда улар 1–2 км атрофида, кўпинча Ajyad ҳудудида ва Ҳарамга тўғри йўналишда бўлади — логистика тушунарли, хоналар яхши ва нарх жуда мақбул."
            )
        case .standard:
            return localizedFinal(
                "Для Standard мы подбираем качественный и аккуратный отель с хорошим уровнем комфорта и честной стоимостью. Это вариант для тех, кто хочет сохранить бюджет, но всё равно получить удачное расположение, надёжный уровень комнат и понятную структуру поездки.",
                "For Standard we choose a solid, comfortable hotel with an honest price. It fits travelers who want to protect the budget while still getting a good location, reliable room quality and a clear trip structure.",
                "Standard uchun biz qulay va ishonchli mehmonxonani halol narx bilan tanlaymiz. Bu byudjetni saqlamoqchi, lekin baribir yaxshi joylashuv, xonalar sifati va tushunarli safar tuzilishini xohlaydiganlar uchun mos variant.",
                "Standard учун биз қулай ва ишончли меҳмонхонани ҳалол нарх билан танлаймиз. Бу бюджетни сақламоқчи, лекин барибир яхши жойлашув, хоналар сифати ва тушунарли сафар тузилишини хоҳлайдиганлар учун мос вариант."
            )
        case .comfort:
            return localizedFinal(
                "Comfort мы рекомендуем тем, кому важна близость к Хараму каждый день: ориентир — около 150 метров, то есть буквально несколько минут пешком. Здесь лучше чувствуется баланс цены, близости к Хараму и качества комнат, поэтому этот уровень особенно хорошо подходит семьям и тем, кто хочет больше удобства без перехода в Luxury.",
                "We recommend Comfort to travelers who value being closer to the Haram every day: the reference point is around 150 meters, just a few minutes on foot. This tier gives a stronger balance of price, Haram proximity and room quality, making it especially suitable for families and travelers who want more ease without moving all the way to Luxury.",
                "Comfort'ni Haramga har kuni yaqin bo‘lish muhim bo‘lganlar uchun tavsiya qilamiz: mo‘ljal taxminan 150 metr, ya’ni piyoda bir necha daqiqa. Bu yerda narx, Haramga yaqinlik va xona sifati balansi yaxshiroq seziladi, shuning uchun bu daraja oilalar va Luxury'ga o‘tmasdan ko‘proq qulaylik xohlaydiganlar uchun ayniqsa mos.",
                "Comfort'ни Ҳарамга ҳар куни яқин бўлиш муҳим бўлганлар учун тавсия қиламиз: мўлжал тахминан 150 метр, яъни пиёда бир неча дақиқа. Бу ерда нарх, Ҳарамга яқинлик ва хона сифати баланси яхшироқ сезилади, шунинг учун бу даража оилалар ва Luxury'га ўтмасдан кўпроқ қулайлик хоҳлайдиганлар учун айниқса мос."
            )
        case .luxury:
            return localizedFinal(
                "Luxury подойдёт тем, кто хочет максимально убрать бытовую нагрузку из поездки. Главное преимущество здесь — расположение непосредственно у Харама: Вы почти не теряете время на дорогу между отелем и мечетью, а каждая ключевая часть поездки ощущается на более высоком уровне.",
                "Luxury suits travelers who want to remove as much everyday friction from the trip as possible. The main advantage is being positioned directly by the Haram, so you lose almost no time moving between the hotel and the mosque, while every key part of the journey feels upgraded.",
                "Luxury safardan kundalik tashvishlarni imkon qadar kamaytirmoqchi bo‘lganlar uchun mos. Asosiy ustunlik — mehmonxona Haramning o‘ziga juda yaqin: mehmonxona va masjid o‘rtasidagi yo‘lga deyarli vaqt ketmaydi va safarning har bir asosiy qismi yuqoriroq darajada seziladi.",
                "Luxury сафардан кундалик ташвишларни имкон қадар камайтирмоқчи бўлганлар учун мос. Асосий устунлик — меҳмонхона Ҳарамнинг ўзига жуда яқин: меҳмонхона ва масжид ўртасидаги йўлга деярли вақт кетмайди ва сафарнинг ҳар бир асосий қисми юқорироқ даражада сезилади."
            )
        }
    }

    private func comparisonDeltaText(_ option: PackageTierComparisonOption) -> String? {
        guard let current = journey.quote?.totalPackagePrice,
              let target = option.quote?.totalPackagePrice else { return nil }
        let delta = target - current
        if delta == 0 { return localizedFinal("Та же итоговая цена", "Same total price", "Umumiy narx bir xil", "Умумий нарх бир хил") }
        if delta > 0 {
            return localizedFinal("+\(money(delta, option.quote?.currency ?? "USD")) к вашему пакету", "+\(money(delta, option.quote?.currency ?? "USD")) vs your package", "+\(money(delta, option.quote?.currency ?? "USD")) joriy paketingizga", "+\(money(delta, option.quote?.currency ?? "USD")) жорий пакетингизга")
        }
        let saved = -delta
        return localizedFinal("Экономия \(money(saved, option.quote?.currency ?? "USD"))", "Save \(money(saved, option.quote?.currency ?? "USD"))", "\(money(saved, option.quote?.currency ?? "USD")) tejaysiz", "\(money(saved, option.quote?.currency ?? "USD")) тежайсиз")
    }

    private func selectComparisonTitle(_ option: PackageTierComparisonOption) -> String {
        let tier = option.tier.title(settings.language)
        guard let current = journey.quote?.totalPackagePrice,
              let target = option.quote?.totalPackagePrice else {
            return localizedFinal("Выбрать \(tier)", "Choose \(tier)", "\(tier) ni tanlash", "\(tier) ни танлаш")
        }
        let delta = target - current
        if delta > 0 {
            return localizedFinal("Выбрать \(tier) · +\(money(delta, option.quote?.currency ?? "USD"))", "Choose \(tier) · +\(money(delta, option.quote?.currency ?? "USD"))", "\(tier) · +\(money(delta, option.quote?.currency ?? "USD"))", "\(tier) · +\(money(delta, option.quote?.currency ?? "USD"))")
        } else if delta < 0 {
            return localizedFinal("Выбрать \(tier) · −\(money(-delta, option.quote?.currency ?? "USD"))", "Choose \(tier) · −\(money(-delta, option.quote?.currency ?? "USD"))", "\(tier) · −\(money(-delta, option.quote?.currency ?? "USD"))", "\(tier) · −\(money(-delta, option.quote?.currency ?? "USD"))")
        }
        return localizedFinal("Выбрать \(tier)", "Choose \(tier)", "\(tier) ni tanlash", "\(tier) ни танлаш")
    }

    private func hotelLevelText(_ tier: PackageTier) -> String {
        tier == .economy ? "2★ / 1★" : "\(tier.primaryHotelStars)★"
    }

    private func mealsLevelText(_ tier: PackageTier) -> String {
        switch tier {
        case .economy, .standard:
            return localizedFinal("Питание в пакете", "Meals in package", "Ovqat paketda", "Овқат пакетда")
        case .comfort, .luxury:
            return localizedFinal("Завтрак включён", "Breakfast included", "Nonushta kiritilgan", "Нонушта киритилган")
        }
    }

    private var currentPackageBadge: String { localizedFinal("Ваш пакет", "Your package", "Sizning paketingiz", "Сизнинг пакетингиз") }
    private var currentSelectionTitle: String { localizedFinal("Текущий выбор", "Current selection", "Joriy tanlov", "Жорий танлов") }
    private var comparisonSectionTitle: String { localizedFinal("Уровень поездки", "Trip level", "Safar darajasi", "Сафар даражаси") }
    private var comparisonSectionHint: String { localizedFinal("Свайпните для сравнения", "Swipe to compare", "Taqqoslash uchun suring", "Таққослаш учун суринг") }
    private var iumrahRecommendationTitle: String { localizedFinal("РЕКОМЕНДАЦИЯ IUMRAH", "IUMRAH RECOMMENDATION", "IUMRAH TAVSIYASI", "IUMRAH ТАВСИЯСИ") }
    private var comparisonLoadingTitle: String { localizedFinal("Сравниваем уровни по вашим датам…", "Comparing levels for your dates…", "Sanalar bo‘yicha darajalar solishtirilmoqda…", "Саналар бўйича даражалар солиштирилмоқда…") }
    private var fixedFlightComparisonNote: String { localizedFinal("Выбранный авиабилет и даты не меняются при сравнении", "Your selected flight and dates stay fixed while comparing", "Taqqoslashda tanlangan reys va sanalar o‘zgarmaydi", "Таққослашда танланган рейс ва саналар ўзгармайди") }
    private var priceTemporarilyUnavailableTitle: String { localizedFinal("Цена обновляется", "Price is updating", "Narx yangilanmoqda", "Нарх янгиланмоқда") }
    private var priceTemporarilyUnavailableBody: String { localizedFinal("Для этого уровня сейчас нет подтверждённой цены Primary Hotel.", "A confirmed Primary Hotel price is not available for this level right now.", "Bu daraja uchun Primary Hotel tasdiqlangan narxi hozir mavjud emas.", "Бу даража учун Primary Hotel тасдиқланган нархи ҳозир мавжуд эмас.") }
    private var perPersonShortTitle: String { localizedFinal("чел.", "person", "kishi", "киши") }
    private var packageForTravelersTitle: String {
        let count = journey.trip.travelerCount
        return localizedFinal("пакет для \(count)", "package for \(count)", "\(count) kishi uchun paket", "\(count) киши учун пакет")
    }
    private var makkahHotelComparisonTitle: String { localizedFinal("Отель в Мекке", "Makkah hotel", "Makkadagi mehmonxona", "Маккадаги меҳмонхона") }
    private var madinahHotelComparisonTitle: String { localizedFinal("Отель в Медине", "Madinah hotel", "Madinadagi mehmonxona", "Мадинадаги меҳмонхона") }
    private var hotelLevelComparisonTitle: String { localizedFinal("Уровень проживания", "Stay level", "Yashash darajasi", "Яшаш даражаси") }
    private var mealsComparisonTitle: String { localizedFinal("Питание", "Meals", "Ovqatlanish", "Овқатланиш") }
    private var packageSupportTitle: String { localizedFinal("Важные пояснения по поездке", "Important trip details", "Safar bo‘yicha muhim izohlar", "Сафар бўйича муҳим изоҳлар") }
    private var packageSupportBody: String { localizedFinal("Если хотите заранее понять детали, откройте пояснения по визе, iumrah Care и iumrah Guide.", "If you want to understand the details before booking, open the explainers for the visa, iumrah Care and iumrah Guide.", "Bron qilishdan oldin tafsilotlarni tushunmoqchi bo‘lsangiz, viza, iumrah Care va iumrah Guide izohlarini oching.", "Брон қилишдан олдин тафсилотларни тушунмоқчи бўлсангиз, виза, iumrah Care ва iumrah Guide изоҳларини очинг.") }
    private var visaSupportTitle: String { localizedFinal("Виза для поездки", "Trip visa", "Safar vizasi", "Сафар визаси") }
    private var visaSupportSubtitle: String { localizedFinal("Срок действия, въезд и что именно входит в ваш пакет.", "Validity, entries and what is included in your package.", "Amal qilish muddati, kirish va paketingizga nimalar kirishi.", "Амал қилиш муддати, кириш ва пакетингизга нималар кириши.") }
    private var careSupportTitle: String { localizedFinal("iumrah Care", "iumrah Care", "iumrah Care", "iumrah Care") }
    private var careSupportSubtitle: String { localizedFinal("Как работает дополнительная поддержка по вашей поездке.", "How the additional support layer works for your trip.", "Safaringiz bo‘yicha qo‘shimcha yordam qanday ishlashi.", "Сафарингиз бўйича қўшимча ёрдам қандай ишлаши.") }
    private var guideSupportTitle: String { localizedFinal("iumrah Guide", "iumrah Guide", "iumrah Guide", "iumrah Guide") }
    private var guideSupportSubtitle: String { localizedFinal("Что включает персональное сопровождение по маршруту.", "What personal assistance includes along the journey.", "Yo‘nalish bo‘yicha shaxsiy hamrohlik nimalarni o‘z ichiga olishi.", "Йўналиш бўйича шахсий ҳамроҳлик нималарни ўз ичига олиши.") }
    private var continueBookingTitle: String { localizedFinal("Продолжить бронирование", "Continue booking", "Bron qilishni davom ettirish", "Брон қилишни давом эттириш") }

    private func differenceCardTitle(_ tier: PackageTier) -> String {
        localizedFinal(
            "Что изменится с \(tier.title(settings.language))",
            "What changes with \(tier.title(settings.language))",
            "\(tier.title(settings.language)) bilan nima o‘zgaradi",
            "\(tier.title(settings.language)) билан нима ўзгаради"
        )
    }

    private var includedServicesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(FlowCopy.text(.includedTitle, settings.language))
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .padding(.bottom, 12)

            if let outbound = journey.selectedOutbound {
                expandableServiceRow(
                    .outboundFlight,
                    title: FlowCopy.text(.outboundFlight, settings.language),
                    subtitle: "\(outbound.airlinesSummary) · \(outbound.flightNumbersSummary)",
                    icon: "airplane.departure"
                ) {
                    flightExpandedContent(outbound)
                }
            }

            if let makkah = journey.selectedHotel {
                expandableServiceRow(
                    .makkahHotel,
                    title: FlowCopy.text(.makkahHotel, settings.language),
                    subtitle: makkah.name,
                    icon: "building.2.fill"
                ) {
                    hotelExpandedContent(makkah, cityLabel: "Makkah", roomName: journey.selectedRoom?.name ?? journey.selectedRoomCategory?.displayName)
                }
            }

            if needsMadinah, let madinah = journey.selectedMadinahHotel {
                expandableServiceRow(
                    .madinahHotel,
                    title: FlowCopy.text(.madinahHotel, settings.language),
                    subtitle: madinah.name,
                    icon: "building.2.fill"
                ) {
                    hotelExpandedContent(madinah, cityLabel: "Madinah", roomName: journey.selectedMadinahRoom?.name ?? journey.selectedMadinahRoomCategory?.displayName)
                }
            }

            if let inbound = journey.selectedInbound {
                expandableServiceRow(
                    .returnFlight,
                    title: FlowCopy.text(.returnFlight, settings.language),
                    subtitle: "\(inbound.airlinesSummary) · \(inbound.flightNumbersSummary)",
                    icon: "airplane.arrival"
                ) {
                    flightExpandedContent(inbound)
                }
            }

            expandableServiceRow(
                .transfer,
                title: FlowCopy.text(.fullTransfer, settings.language),
                subtitle: journey.selectedTransferVehicle?.modelName ?? "Kia Carnival",
                icon: "car.fill"
            ) {
                transferExpandedContent
            }

            if journey.haramainTrainSelected {
                expandableServiceRow(
                    .haramain,
                    title: "Haramain High Speed Railway",
                    subtitle: haramainIncludedSubtitle,
                    customImage: "HaramainMark"
                ) {
                    haramainExpandedContent
                }
            }

            staticIncludedRow(.ziyaratMakkah, icon: "mappin.and.ellipse")
            if needsMadinah { staticIncludedRow(.ziyaratMadinah, icon: "mappin.and.ellipse") }
            staticIncludedRow(.careSupport, icon: "heart.fill")
            staticIncludedRow(.guide, icon: "person.2.fill")

            expandableServiceRow(
                .visa,
                title: FlowCopy.text(.visa, settings.language),
                subtitle: FlowCopy.text(.included, settings.language),
                icon: "doc.text.fill"
            ) {
                visaExpandedContent
            }

            expandableServiceRow(
                .meals,
                title: FlowCopy.text(.meals, settings.language),
                subtitle: mealsSummary,
                icon: "fork.knife"
            ) {
                mealsExpandedContent
            }

            esimIncludedRow
        }
        .padding(20)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5) }
    }

    @ViewBuilder
    private func expandableServiceRow<Content: View>(
        _ section: FinalPackageServiceSection,
        title: String,
        subtitle: String,
        icon: String? = nil,
        customImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let expanded = expandedService == section

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.90)) {
                    expandedService = expanded ? nil : section
                }
                IumrahHaptics.selection()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    IumrahIconBadge(
                        systemName: "checkmark",
                        role: .success,
                        size: 30,
                        symbolSize: 12,
                        shape: .circle
                    )

                    if let customImage {
                        Image(customImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    } else if let icon {
                        IumrahInlineIcon(systemName: icon, size: 15)
                            .frame(width: 22)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(expanded ? 3 : 2)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.iumrahRaisedBackground, in: Circle())
                }
                .contentShape(Rectangle())
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.leading, 42)
                content()
                    .padding(.leading, 42)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func staticIncludedRow(_ key: FlowCopy.Key, value: String? = nil, icon: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            IumrahIconBadge(systemName: "checkmark", role: .success, size: 30, symbolSize: 12, shape: .circle)
            IumrahInlineIcon(systemName: icon, size: 15)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(FlowCopy.text(key, settings.language))
                    .font(.subheadline.weight(.semibold))
                Text(value ?? FlowCopy.text(.included, settings.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    private func flightExpandedContent(_ offer: FlightOffer) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.origin)
                        .font(.title3.weight(.bold))
                    Text(shortFlightDate(offer.departureAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(shortFlightTime(offer.departureAt))
                        .font(.headline.monospacedDigit())
                }

                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.system(size: 17, weight: .semibold))
                    Text(durationText(offer.durationMinutes))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 3)

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(offer.destination)
                        .font(.title3.weight(.bold))
                    Text(shortFlightDate(offer.arrivalAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(shortFlightTime(offer.arrivalAt))
                        .font(.headline.monospacedDigit())
                }
            }

            HStack(spacing: 8) {
                bookingDetailChip(icon: "airplane.circle", text: offer.stops == 0 ? directFlightTitle : "\(offer.stops) stop")
                if let rawCabin = offer.cabinClass {
                    let cabin = rawCabin.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cabin.isEmpty {
                        bookingDetailChip(icon: "seat.recline.normal", text: cabin)
                    }
                }
                if let checked = offer.baggage?.checked {
                    bookingDetailChip(icon: "suitcase.fill", text: "\(checked) kg")
                }
            }

            if let segments = offer.segments, segments.count > 1 {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(segments) { segment in
                        HStack {
                            Text("\(segment.origin.code) → \(segment.destination.code)")
                                .font(.caption.weight(.bold))
                            Spacer()
                            Text("\(segment.airline) · \(segment.flightNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func hotelExpandedContent(_ hotel: HotelSummary, cityLabel: String, roomName: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                HotelCachedImage(rawURL: hotel.coverImageURL, placeholderSystemName: "building.2.fill")
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(hotel.name).font(.headline)
                    Text(cityLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let stars = hotel.stars {
                    Label("\(stars)", systemImage: "star.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
            }

            if let roomName, !roomName.isEmpty {
                bookingDetailChip(icon: "bed.double.fill", text: roomName)
            }
        }
    }

    private var transferExpandedContent: some View {
        let vehicle = journey.selectedTransferVehicle ?? .carnival
        return VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(vehicle == .yukon ? Color.black : Color.iumrahRaisedBackground)
                if vehicle == .yukon {
                    RadialGradient(colors: [.white.opacity(0.55), .white.opacity(0.12), .clear], center: .center, startRadius: 8, endRadius: 150)
                }
                Image(vehicle.assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            }
            .frame(height: 180)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle.modelName).font(.headline)
                    Text(vehicle == .yukon ? "VIP Transfer" : "iumrah Transfer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                bookingDetailChip(icon: "person.2.fill", text: "\(journey.trip.travelerCount)/\(vehicle.passengerCapacity)")
            }

            transferRouteSummary
        }
    }

    private var transferRouteSummary: some View {
        HStack(spacing: 0) {
            bookingRouteStop("airplane.arrival", label: journey.trip.arrivalAirport.rawValue)
            bookingRouteLine
            bookingRouteStop("building.2.fill", label: "Makkah")
            if needsMadinah {
                bookingRouteLine
                bookingRouteStop(journey.haramainTrainSelected ? "train.side.front.car" : "car.fill", label: journey.haramainTrainSelected ? "Train" : "Intercity")
                bookingRouteLine
                bookingRouteStop("building.2.fill", label: "Madinah")
            }
            bookingRouteLine
            bookingRouteStop("airplane.departure", label: journey.trip.returnOriginCode)
        }
        .padding(12)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var haramainExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(["HaramainHero", "HaramainGalleryStation", "HaramainGalleryInterior", "HaramainGalleryTrain"], id: \.self) { name in
                        Image(name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 210, height: 125)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }

            HStack(spacing: 8) {
                bookingDetailChip(icon: "speedometer", text: "300 km/h")
                bookingDetailChip(icon: "clock.fill", text: "≈ 2h 20m")
                bookingDetailChip(icon: "wifi", text: "Wi‑Fi")
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Standard").font(.subheadline.weight(.bold))
                    Text("\(max(1, journey.haramainTicketCount)) × $150")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("+$\(haramainAmountNumber)")
                    .font(.headline.monospacedDigit())
            }
        }
    }

    private var visaExpandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(visaMultipleEntryTitle, systemImage: "checkmark.seal.fill")
                .font(.headline)
            Text(visaExplanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                bookingDetailChip(icon: "calendar", text: visaOneYearTitle)
                bookingDetailChip(icon: "arrow.triangle.2.circlepath", text: visaMultipleTitle)
                bookingDetailChip(icon: "clock", text: visaNinetyDaysTitle)
            }
        }
        .padding(14)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var mealsExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(mealGalleryURLs, id: \.absoluteString) { url in
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            default:
                                ZStack {
                                    LinearGradient(colors: [Color.orange.opacity(0.18), Color.iumrahRaisedBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    Image(systemName: "fork.knife.circle.fill")
                                        .font(.system(size: 34))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(width: 205, height: 132)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }

            HStack(spacing: 8) {
                mealCountPill(city: localizedMealCity(.makkah), count: makkahMealCount)
                if needsMadinah { mealCountPill(city: localizedMealCity(.madinah), count: madinahMealCount) }
            }

            Text(mealsExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func bookingDetailChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private func bookingRouteStop(_ icon: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(label).font(.caption2.weight(.semibold)).lineLimit(1)
        }
        .frame(minWidth: 46)
    }

    private var bookingRouteLine: some View {
        Capsule().fill(Color.primary.opacity(0.18)).frame(width: 18, height: 2).offset(y: -8)
    }

    private func mealCountPill(city: String, count: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "fork.knife")
            Text("\(city) · \(count)×")
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private var mealGalleryURLs: [URL] {
        [
            "https://images.unsplash.com/photo-1679312061521-d7d619a8cfb7?auto=format&fit=crop&w=900&q=78",
            "https://images.unsplash.com/photo-1679312182375-28464cfc00d7?auto=format&fit=crop&w=900&q=78",
            "https://images.unsplash.com/photo-1760594308930-06b631dd916b?auto=format&fit=crop&w=900&q=78"
        ].compactMap { URL(string: $0) }
    }

    private var mealsSummary: String {
        if needsMadinah {
            return localizedFinal(
                "Мекка · \(russianMealsPerDay(makkahMealCount)) · Медина · \(russianMealsPerDay(madinahMealCount))",
                "Makkah · \(makkahMealCount) meals/day · Madinah · \(madinahMealCount) meals/day",
                "Makka · kuniga \(makkahMealCount) mahal · Madina · kuniga \(madinahMealCount) mahal",
                "Макка · кунига \(makkahMealCount) маҳал · Мадина · кунига \(madinahMealCount) маҳал"
            )
        }
        return localizedFinal(
            "Мекка · \(russianMealsPerDay(makkahMealCount))",
            "Makkah · \(makkahMealCount) meals/day",
            "Makka · kuniga \(makkahMealCount) mahal",
            "Макка · кунига \(makkahMealCount) маҳал"
        )
    }

    private var mealsExplanation: String {
        if journey.hasSelectableHotelMeals {
            return localizedFinal(
                "Завтрак включён без доплаты. В цену пакета входят только выбранные Вами обеды и ужины; отключённые позиции сразу исключаются из расчёта.",
                "Breakfast is included at no extra charge. Only the lunches and dinners you selected are included in the package price; disabled items are removed from pricing immediately.",
                "Nonushta qo‘shimcha to‘lovsiz kiritilgan. Paket narxiga faqat Siz tanlagan tushlik va kechki ovqatlar kiradi; o‘chirilgan variantlar hisobdan darhol chiqariladi.",
                "Нонушта қўшимча тўловсиз киритилган. Пакет нархига фақат Сиз танлаган тушлик ва кечки овқатлар киради; ўчирилган вариантлар ҳисобдан дарҳол чиқарилади."
            )
        }
        return localizedFinal(
            "Питание включено в программу пакета. Конкретные рестораны и время приёмов пищи подтверждаются в деталях поездки.",
            "Meals are included in the package program. Specific restaurants and meal times are confirmed in your trip details.",
            "Ovqatlanish paket dasturiga kiritilgan. Aniq restoranlar va vaqtlar safar tafsilotlarida tasdiqlanadi.",
            "Овқатланиш пакет дастурига киритилган. Аниқ ресторанлар ва вақтлар сафар тафсилотларида тасдиқланади."
        )
    }

    private func russianMealsPerDay(_ count: Int) -> String {
        count == 1 ? "1 раз в день" : "\(count) раза в день"
    }

    private var makkahMealCount: Int {
        guard journey.hasSelectableHotelMeals else { return 3 }
        var count = 1 // Breakfast is always included.
        if journey.isMealEnabled(.lunch, city: .makkah) { count += 1 }
        if journey.isMealEnabled(.dinner, city: .makkah) { count += 1 }
        return count
    }

    private var madinahMealCount: Int {
        guard journey.hasSelectableHotelMeals else { return 2 }
        var count = 1 // Breakfast is always included; Madinah has no lunch option.
        if journey.isMealEnabled(.dinner, city: .madinah) { count += 1 }
        return count
    }

    private func localizedMealCity(_ city: HotelMealCity) -> String {
        switch (settings.language, city) {
        case (.russian, .makkah): return "Мекка"
        case (.russian, .madinah): return "Медина"
        case (.english, .makkah): return "Makkah"
        case (.english, .madinah): return "Madinah"
        case (.uzbek, .makkah): return "Makka"
        case (.uzbek, .madinah): return "Madina"
        case (.uzbekCyrillic, .makkah): return "Макка"
        case (.uzbekCyrillic, .madinah): return "Мадина"
        }
    }

    private var directFlightTitle: String { localizedFinal("Прямой", "Direct", "To‘g‘ridan-to‘g‘ri", "Тўғридан-тўғри") }

    private var haramainIncludedSubtitle: String {
        let tickets = max(1, journey.haramainTicketCount)
        return localizedFinal("Мекка ↔ Медина · Standard · \(tickets) бил.", "Makkah ↔ Madinah · Standard · \(tickets) tickets", "Makka ↔ Madina · Standard · \(tickets) chipta", "Макка ↔ Мадина · Standard · \(tickets) чипта")
    }

    private var haramainAmountNumber: String {
        let value = NSDecimalNumber(decimal: journey.haramainTrainAddOnUsd).doubleValue
        return String(format: "%.0f", value)
    }

    private func shortFlightDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    private func shortFlightTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func durationText(_ minutes: Int) -> String {
        let h = max(0, minutes) / 60
        let m = max(0, minutes) % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private var visaMultipleEntryTitle: String { localizedFinal("Туристическая eVisa", "Tourist eVisa", "Turistik eVisa", "Туристик eVisa") }
    private var visaOneYearTitle: String { localizedFinal("1 год", "1 year", "1 yil", "1 йил") }
    private var visaMultipleTitle: String { localizedFinal("Многократный въезд", "Multiple entry", "Ko‘p martalik kirish", "Кўп марталик кириш") }
    private var visaNinetyDaysTitle: String { localizedFinal("до 90 дней", "up to 90 days", "90 kungacha", "90 кунгача") }
    private var visaExplanation: String {
        localizedFinal(
            "Электронная туристическая виза Саудовской Аравии действует один год с даты выдачи и предусматривает многократный въезд, если в самой визе не указано иное. Максимальный разрешённый срок пребывания по eVisa — до 90 дней.",
            "Saudi Arabia's tourist eVisa is valid for one year from issuance and permits multiple entries unless the issued visa states otherwise. The maximum permitted stay under the eVisa is up to 90 days.",
            "Saudiya Arabistonining turistik eVisa-si berilgan kundan boshlab bir yil amal qiladi va vizada boshqacha ko‘rsatilmagan bo‘lsa, ko‘p martalik kirishga ruxsat beradi. eVisa bo‘yicha maksimal qolish muddati 90 kungacha.",
            "Саудия Арабистонининг туристик eVisa-си берилган кундан бошлаб бир йил амал қилади ва визада бошқача кўрсатилмаган бўлса, кўп марталик киришга рухсат беради. eVisa бўйича максимал қолиш муддати 90 кунгача."
        )
    }

    private func localizedFinal(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var esimIncludedRow: some View {
        HStack(alignment: .center, spacing: 12) {
            IumrahIconBadge(
                systemName: "checkmark",
                role: .success,
                size: 30,
                symbolSize: 12,
                shape: .circle
            )

            Image("UmrahMobileLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("iumrah Mobile eSIM")
                    .font(.subheadline.weight(.semibold))
                Text(FlowCopy.text(.included, settings.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    private var careReassuranceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("CarePriceSupport")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color.black)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 5) {
                    IumrahInlineIcon(systemName: "heart.fill", role: .care, size: 11)
                    Text("iumrah Care")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(IumrahIconRole.care.color)

                Text(careCardTitle)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                Text(careCardBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showCareExplanation = true
                    IumrahHaptics.soft()
                } label: {
                    HStack {
                        Text(careHowItWorks)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var careCardTitle: String {
        switch settings.language {
        case .russian: return "Мы проверим баланс цены и маршрута"
        case .english: return "We review the balance between price and itinerary"
        case .uzbek: return "Narx va yo‘nalish muvozanatini tekshiramiz"
        case .uzbekCyrillic: return "Нарх ва йўналиш мувозанатини текширамиз"
        }
    }

    private var careCardBody: String {
        switch settings.language {
        case .russian: return "Если текущая цена выше ожидаемой или даты гибкие, специалисты iumrah Care дополнительно проверят более удобные прямые рейсы, логичное распределение ночей и отели ближе к ключевым местам — без потери качества поездки."
        case .english: return "If the current price is higher than expected or your dates are flexible, iumrah Care will review more convenient direct flights, sensible night allocation and closer hotels without compromising the journey."
        case .uzbek: return "Agar joriy narx kutilganidan yuqori bo‘lsa yoki sanalaringiz moslashuvchan bo‘lsa, iumrah Care qulayroq to‘g‘ridan-to‘g‘ri reyslar, tunlarning mantiqiy taqsimoti va yaqinroq mehmonxonalarni qo‘shimcha tekshiradi."
        case .uzbekCyrillic: return "Агар жорий нарх кутилганидан юқори бўлса ёки саналарингиз мослашувчан бўлса, iumrah Care қулайроқ тўғридан-тўғри рейслар, тунларнинг мантиқий тақсимоти ва яқинроқ меҳмонхоналарни қўшимча текширади."
        }
    }

    private var careHowItWorks: String {
        switch settings.language {
        case .russian: return "Как это работает"
        case .english: return "How it works"
        case .uzbek: return "Qanday ishlaydi"
        case .uzbekCyrillic: return "Қандай ишлайди"
        }
    }

    private var notificationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(
                systemName: push.isAuthorized ? "bell.badge.fill" : "bell.badge",
                role: .notification,
                size: 42,
                symbolSize: 18,
                shape: .circle
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("notifications_title", settings.language)).font(.headline)
                Text(push.statusText(language: settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if !push.isAuthorized {
                Button { Task { await push.requestAuthorization() } } label: {
                    Image(systemName: "arrow.up.right")
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                        .iumrahGlass(in: Circle(), interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func successContent(_ session: StoredBookingSession) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.iumrahCareLight)
                Text(FlowCopy.text(.bookingSuccessTitle, settings.language))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(FlowCopy.text(.bookingSuccessBody, settings.language))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let pilgrimID = session.displayPilgrimID {
                    Text("ID \(pilgrimID)")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 18)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            Button {
                showCreatedBooking = true
            } label: {
                Text(FlowCopy.text(.openBooking, settings.language)).frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahSecondaryButtonStyle())

            Button {
                // Close the whole builder destination before switching tabs so the
                // next visit starts from a clean booking root instead of reopening
                // the completed flow deep in the navigation stack.
                chrome.shouldStartTripBuilder = false
                journey.resetAfterTripChange()
                chrome.navigate(to: .home)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                    Text(FlowCopy.text(.home, settings.language))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
    }

    @MainActor
    private func createBooking() async {
        guard !isSubmitting,
              let hotel = journey.selectedHotel,
              let outbound = journey.selectedOutbound,
              let quote = journey.quote else { return }
        let inbound = journey.selectedInbound
        guard outbound.isVerifiedForBooking,
              (!journey.trip.isRoundTripFlight || inbound?.isVerifiedForBooking == true) else {
            errorMessage = invalidFlightSelectionMessage
            IumrahHaptics.error()
            return
        }
        if needsMadinah && journey.selectedMadinahHotel == nil { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let profile = BookingPilgrimProfile(
                firstName: settings.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: settings.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                telegram: settings.telegram.trimmingCharacters(in: .whitespacesAndNewlines),
                whatsapp: settings.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let session = try await bookings.create(
                trip: journey.trip,
                hotel: hotel,
                madinahHotel: journey.selectedMadinahHotel,
                room: journey.selectedRoom,
                roomCategory: journey.selectedRoomCategory,
                madinahRoom: journey.selectedMadinahRoom,
                madinahRoomCategory: journey.selectedMadinahRoomCategory,
                intercityTransport: needsMadinah ? (journey.haramainTrainSelected ? .haramainTrain : .road) : nil,
                outbound: outbound,
                inbound: inbound,
                quote: quote,
                language: settings.language,
                pilgrimProfile: profile
            )
            createdSession = session
            if let deviceToken = push.deviceToken {
                await bookings.syncPushSubscriptions(deviceToken: deviceToken, locale: settings.language.rawValue)
            }
            IumrahHaptics.success()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }


    private var invalidFlightSelectionMessage: String {
        switch settings.language {
        case .russian: return "Выберите актуальный маршрут. Система автоматически свяжет его с вашим Umrah-пакетом."
        case .english: return "Select a current itinerary. The system will automatically connect it to your Umrah package."
        case .uzbek: return "Joriy yo‘nalishni tanlang. Tizim uni Umra paketingiz bilan avtomatik bog‘laydi."
        case .uzbekCyrillic: return "Жорий йўналишни танланг. Тизим уни Умра пакетингиз билан автоматик боғлайди."
        }
    }

    private var indicativePriceTitle: String {
        switch settings.language {
        case .russian: return "Цена вашего Umrah-пакета"
        case .english: return "Your Umrah package price"
        case .uzbek: return "Umra paketingiz narxi"
        case .uzbekCyrillic: return "Умра пакетингиз нархи"
        }
    }

    private func money(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency) \(amount)"
    }
}

private struct FinalPackageInformationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let kind: FinalPackageSupportSheet
    let language: AppSettingsStore.Language

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    content
                }
                .padding(IumrahDesign.pagePadding)
                .padding(.bottom, 24)
            }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeTitle) { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            IumrahIconBadge(systemName: headerIcon, role: kind == .visa ? .document : .care, size: 52, symbolSize: 20, cornerRadius: 17)
            Text(sheetTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(sheetSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .visa:
            VStack(alignment: .leading, spacing: 14) {
                infoCard {
                    infoPoint(icon: "calendar", title: tr("Срок действия", "Validity", "Amal qilish muddati", "Амал қилиш муддати"), body: tr("Туристическая eVisa обычно действует 1 год с даты выдачи.", "The tourist eVisa is typically valid for 1 year from issuance.", "Turistik eVisa odatda berilgan kundan boshlab 1 yil amal qiladi.", "Туристик eVisa одатда берилган кундан бошлаб 1 йил амал қилади."))
                    Divider()
                    infoPoint(icon: "arrow.triangle.2.circlepath", title: tr("Въезд", "Entries", "Kirish", "Кириш"), body: tr("Как правило, виза предусматривает многократный въезд, если в самой визе не указано иное.", "It generally allows multiple entries unless the issued visa states otherwise.", "Odatda viza ko‘p martalik kirishga ruxsat beradi, agar vizaning o‘zida boshqacha ko‘rsatilmagan bo‘lsa.", "Одатда виза кўп марталик киришга рухсат беради, агар визанинг ўзида бошқача кўрсатилмаган бўлса."))
                    Divider()
                    infoPoint(icon: "clock", title: tr("Пребывание", "Stay", "Qolish", "Қолиш"), body: tr("Разрешённый срок пребывания — до 90 дней.", "The permitted stay is up to 90 days.", "Ruxsat etilgan qolish muddati 90 kungacha.", "Рухсат этилган қолиш муддати 90 кунгача."))
                }

                Text(tr("В вашем пакете виза идёт как часть общей поездки. Итоговое решение о выдаче визы и разрешении на въезд всегда остаётся за компетентными органами Саудовской Аравии.", "In your package, the visa is treated as part of the overall journey. Final visa issuance and entry decisions always remain with the competent Saudi authorities.", "Paketingizda viza umumiy safarning bir qismi sifatida ko‘riladi. Vizani berish va kirishga ruxsat bo‘yicha yakuniy qaror Saudiya vakolatli organlariga tegishli.", "Пакетингизда виза умумий сафарнинг бир қисми сифатида кўрилади. Визани бериш ва киришга рухсат бўйича якуний қарор Саудия ваколатли органларига тегишли."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .guide:
            VStack(alignment: .leading, spacing: 14) {
                infoCard {
                    infoPoint(icon: "airplane.arrival", title: tr("Встреча по маршруту", "Arrival support", "Kelishdagi yordam", "Келишдаги ёрдам"), body: tr("iumrah Guide помогает начать поездку спокойнее: встреча, первые ориентиры и логика перемещений по вашему маршруту.", "iumrah Guide helps you start the trip more calmly with arrival support, first orientation and movement logic for your route.", "iumrah Guide safarni xotirjamroq boshlashingizga yordam beradi: kutib olish, dastlabki yo‘naltirish va yo‘nalish bo‘yicha harakatlar logikasi.", "iumrah Guide сафарни хотиржамроқ бошлашингизга ёрдам беради: кутиб олиш, дастлабки йўналтириш ва йўналиш бўйича ҳаракатлар логикаси."))
                    Divider()
                    infoPoint(icon: "building.2.fill", title: tr("Поддержка по отелю", "Hotel support", "Mehmonxona bo‘yicha yordam", "Меҳмонхона бўйича ёрдам"), body: tr("Это сопровождение вокруг вашей программы: заселение, ключевые точки поездки и координация по маршруту.", "This is support around your program: check-in, key journey points and route coordination.", "Bu dasturingiz atrofidagi yordam: joylashish, safarning asosiy nuqtalari va yo‘nalish bo‘yicha muvofiqlashtirish.", "Бу дастурингиз атрофидаги ёрдам: жойлашиш, сафарнинг асосий нуқталари ва йўналиш бўйича мувофиқлаштириш."))
                    Divider()
                    infoPoint(icon: "person.2.fill", title: tr("Индивидуальный формат", "Personal format", "Individual format", "Индивидуал формат"), body: tr("Guide привязан к вашему бронированию как персональное сопровождение, а не как массовая группа.", "The Guide is tied to your booking as personal assistance rather than a mass group experience.", "Guide broningizga ommaviy guruh emas, balki shaxsiy hamrohlik sifatida biriktiriladi.", "Guide бронингизга оммавий гуруҳ эмас, балки шахсий ҳамроҳлик сифатида бириктирилади."))
                }
            }
        }
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .padding(18)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
    }

    private func infoPoint(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, role: kind == .visa ? .document : .care, size: 40, symbolSize: 15, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerIcon: String { kind == .visa ? "doc.text.fill" : "person.2.fill" }
    private var sheetTitle: String {
        switch kind {
        case .visa: return tr("Виза Umrah-поездки", "Visa for your Umrah trip", "Umra safaringiz vizasi", "Умра сафарингиз визаси")
        case .guide: return "iumrah Guide"
        }
    }
    private var sheetSubtitle: String {
        switch kind {
        case .visa: return tr("Кратко о визе, которая входит в пакет поездки.", "A short explainer about the visa included in your trip package.", "Safar paketingizga kiradigan viza haqida qisqacha izoh.", "Сафар пакетингизга кирадиган виза ҳақида қисқача изоҳ.")
        case .guide: return tr("Что включает персональное сопровождение по вашему маршруту.", "What the personal assistance layer includes for your route.", "Yo‘nalishingiz bo‘yicha shaxsiy hamrohlik nimalarni o‘z ichiga oladi.", "Йўналишингиз бўйича шахсий ҳамроҳлик нималарни ўз ичига олади.")
        }
    }
    private var closeTitle: String { tr("Готово", "Done", "Tayyor", "Тайёр") }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}
