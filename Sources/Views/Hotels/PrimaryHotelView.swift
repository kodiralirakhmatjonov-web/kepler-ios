import Foundation
import SwiftUI

enum PrimaryHotelEntryMode {
    case standard
    case flightFirst
}

struct PrimaryHotelView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.iumrahAdaptiveLayout) private var adaptiveLayout
    @State private var showTransfer = false
    @State private var isPreparingPublishedPackage = false
    @State private var publishedPackageError: String?

    var entryMode: PrimaryHotelEntryMode = .standard

    private var requiresMadinah: Bool { journey.trip.scope == .makkahAndMadinah }
    private var canContinue: Bool {
        // Selection should not be blocked by a stale list-row cache. The existing
        // pricing pipeline re-reads hotel detail and still requires a fresh 48h
        // price before any final package quote can be produced.
        journey.selectedHotel != nil &&
        (!requiresMadinah || journey.selectedMadinahHotel != nil)
    }

    var body: some View {
        GeometryReader { viewport in
            let contentWidth = max(0, viewport.size.width - (IumrahDesign.pagePadding * 2))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    IumrahGeneratorHeader(stage: .hotel)

                    heading
                    if entryMode == .flightFirst {
                        flightFirstContextCard
                        flightFirstTierSelector
                    }
                    hotelContent

                    if journey.packageFlightPath == .publishedDirect || journey.packageFlightPath == .aviasalesSelected {
                        Button {
                            Task { await continuePublishedDirectPackage() }
                        } label: {
                            HStack(spacing: 9) {
                                if isPreparingPublishedPackage { ProgressView().tint(.white) }
                                Text(publishedContinueTitle)
                                if !isPreparingPublishedPackage { Image(systemName: "arrow.right") }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IumrahPrimaryButtonStyle())
                        .disabled(!canContinue || isPreparingPublishedPackage)
                        .opacity(canContinue && !isPreparingPublishedPackage ? 1 : 0.42)
                    } else {
                        NavigationLink {
                            OutboundFlightView()
                        } label: {
                            HStack(spacing: 9) {
                                Text(FlowCopy.text(.continueToFlights, settings.language))
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IumrahPrimaryButtonStyle())
                        .disabled(!canContinue)
                        .opacity(canContinue ? 1 : 0.42)
                    }
                }
                // A vertical ScrollView does not hard-clamp child intrinsic width.
                // Own the exact viewport width here so a panoramic hotel photo can
                // never widen the card or shift the whole hotel step horizontally.
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 140) // leave enough scroll reach above the persistent tab bar
            }
            .frame(width: viewport.size.width)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .hotel, showsGeneratorAmbient: true)
        .task {
            if journey.hotels.isEmpty { await journey.loadMakkahHotels() }
            if requiresMadinah, journey.madinahHotels.isEmpty { await journey.loadMadinahHotels() }
        }
        .navigationDestination(isPresented: $showTransfer) {
            TransferSelectionView()
        }
        .alert(publishedErrorTitle, isPresented: Binding(
            get: { publishedPackageError != nil },
            set: { if !$0 { publishedPackageError = nil } }
        )) {
            Button("OK", role: .cancel) { publishedPackageError = nil }
        } message: {
            Text(publishedPackageError ?? "")
        }
    }

    @MainActor
    private func continuePublishedDirectPackage() async {
        guard !isPreparingPublishedPackage else { return }
        isPreparingPublishedPackage = true
        publishedPackageError = nil
        defer { isPreparingPublishedPackage = false }

        let ready: Bool
        if journey.packageFlightPath == .aviasalesSelected {
            ready = await journey.prepareAviasalesSelectedQuote()
        } else {
            ready = await journey.preparePublishedDirectQuote()
        }
        if ready {
            IumrahHaptics.success()
            showTransfer = true
        } else {
            IumrahHaptics.error()
            publishedPackageError = journey.errorMessage ?? publishedFallbackError
        }
    }


    private var flightFirstContextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(flightFirstTitle)
                        .font(.headline)
                    Text(flightFirstSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }

            if !journey.stagedUmrahFlights.isEmpty {
                Divider()
                ForEach(journey.stagedUmrahFlights) { flight in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: flight.kind == .roundTrip ? "arrow.left.arrow.right" : "airplane")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(flight.routeTitle)
                                .font(.subheadline.monospaced().weight(.bold))
                            Text([flight.airline, flight.flightNumber].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let returnAt = flight.returnAt {
                                Text("↩︎ \(String(returnAt.prefix(10)))" + ((flight.returnAirline ?? flight.returnFlightNumber) == nil ? "" : " · " + [flight.returnAirline, flight.returnFlightNumber].compactMap { $0 }.joined(separator: " · ")))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }

            if journey.packageFlightPath == .aviasalesSelected,
               let roundTrip = journey.stagedAviasalesOffers[.roundTrip],
               (roundTrip.returnAirlineCode?.isEmpty != false || roundTrip.returnFlightNumber?.isEmpty != false) {
                Label(unverifiedReturnFlightNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack(spacing: 14) {
                Label("\(max(1, journey.trip.travelerCount))", systemImage: "person.2.fill")
                Label(journey.trip.scope.title(settings.language), systemImage: "mappin.and.ellipse")
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8)
        }
    }


    private var flightFirstTierSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(flightFirstHotelLevelTitle)
                    .font(.headline)
                Text(flightFirstHotelLevelSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: adaptiveLayout.isWide ? 4 : 2),
                spacing: 10
            ) {
                    ForEach(PackageTier.allCases) { tier in
                        let selected = journey.trip.packageTier == tier
                        Button {
                            guard !selected else { return }
                            IumrahHaptics.selection()
                            journey.selectPackageTier(tier)
                            Task {
                                await journey.loadMakkahHotels()
                                if requiresMadinah { await journey.loadMadinahHotels() }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(tier.primaryHotelStars)★")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                Text(tier.title(settings.language))
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(selected ? Color.iumrahPrimaryButtonText : Color.primary)
                            .padding(.horizontal, 15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 66, alignment: .leading)
                            .background(
                                selected ? Color.iumrahPrimaryButtonBackground : Color.iumrahRaisedBackground,
                                in: RoundedRectangle(cornerRadius: 19, style: .continuous)
                            )
                            .overlay {
                                if !selected {
                                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
            }
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var unverifiedReturnFlightNote: String {
        switch settings.language {
        case .russian: return "Data API не указал авиакомпанию или номер обратного рейса. Проверьте эти данные у продавца до покупки билета."
        case .turkish: return TurkishLocalization.phrase("Data API did not provide the return carrier or flight number. Confirm these with the seller before buying.")
        case .english: return "Data API did not provide the return carrier or flight number. Confirm these with the seller before buying."
        case .uzbek: return "Data API qaytish aviakompaniyasi yoki reys raqamini bermagan. Xarid qilishdan oldin sotuvchidan tekshiring."
        case .uzbekCyrillic: return "Data API қайтиш авиакомпанияси ёки рейс рақамини бермаган. Харид қилишдан олдин сотувчидан текширинг."
        }
    }

    private var flightFirstHotelLevelTitle: String {
        switch settings.language {
        case .russian: return "Уровень отеля"
        case .turkish: return TurkishLocalization.phrase("Hotel level")
        case .english: return "Hotel level"
        case .uzbek: return "Mehmonxona darajasi"
        case .uzbekCyrillic: return "Меҳмонхона даражаси"
        }
    }

    private var flightFirstHotelLevelSubtitle: String {
        switch settings.language {
        case .russian: return "Выберите звёздность — iumrah автоматически подберёт Primary Hotel для нужных городов."
        case .turkish: return TurkishLocalization.phrase("Choose the hotel level and iumrah will automatically resolve the Primary Hotel for each required city.")
        case .english: return "Choose the hotel level and iumrah will automatically resolve the Primary Hotel for each required city."
        case .uzbek: return "Yulduz darajasini tanlang — iumrah kerakli shaharlardagi Primary Hotel’ni avtomatik tavsiya qiladi."
        case .uzbekCyrillic: return "Юлдуз даражасини танланг — iumrah керакли шаҳарлардаги Primary Hotel’ни автоматик тавсия қилади."
        }
    }

    private var flightFirstTitle: String {
        switch settings.language {
        case .russian: return "Flight First · авиабилет выбран"
        case .turkish: return TurkishLocalization.phrase("Flight First · flight selected")
        case .english: return "Flight First · flight selected"
        case .uzbek: return "Flight First · aviachipta tanlangan"
        case .uzbekCyrillic: return "Flight First · авиачипта танланган"
        }
    }

    private var flightFirstSubtitle: String {
        switch settings.language {
        case .russian: return "Теперь выберите Primary Hotels. После этого flow продолжится к трансферу и итоговому сравнению пакета."
        case .turkish: return TurkishLocalization.phrase("Choose Primary Hotels next. The flow then continues to transfer and final package comparison.")
        case .english: return "Choose Primary Hotels next. The flow then continues to transfer and final package comparison."
        case .uzbek: return "Endi Primary Hotels’ni tanlang. Keyin flow transfer va yakuniy paket taqqoslashiga o‘tadi."
        case .uzbekCyrillic: return "Энди Primary Hotels’ни танланг. Кейин flow трансфер ва якуний пакет таққослашига ўтади."
        }
    }

    private var publishedContinueTitle: String {
        switch settings.language {
        case .russian: return "Продолжить к трансферу"
        case .turkish: return TurkishLocalization.phrase("Continue to transfer")
        case .english: return "Continue to transfer"
        case .uzbek: return "Transferga davom etish"
        case .uzbekCyrillic: return "Трансферга давом этиш"
        }
    }

    private var publishedErrorTitle: String {
        switch settings.language {
        case .russian: return "Не удалось собрать пакет"
        case .turkish: return TurkishLocalization.phrase("Could not build package")
        case .english: return "Could not build package"
        case .uzbek: return "Paketni yig‘ib bo‘lmadi"
        case .uzbekCyrillic: return "Пакетни йиғиб бўлмади"
        }
    }

    private var publishedFallbackError: String {
        switch settings.language {
        case .russian: return "Не удалось получить опубликованный рейс или актуальную цену отеля. Попробуйте ещё раз."
        case .turkish: return TurkishLocalization.phrase("The published flight or current hotel price could not be resolved. Please try again.")
        case .english: return "The published flight or current hotel price could not be resolved. Please try again."
        case .uzbek: return "E’lon qilingan reys yoki mehmonxonaning dolzarb narxini olib bo‘lmadi. Qayta urinib ko‘ring."
        case .uzbekCyrillic: return "Эълон қилинган рейс ёки меҳмонхонанинг долзарб нархини олиб бўлмади. Қайта уриниб кўринг."
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(FlowCopy.text(.hotelStageEyebrow, settings.language))
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(FlowCopy.text(.hotelStageTitle, settings.language))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.8)
            Text(FlowCopy.text(.hotelStageBody, settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var hotelContent: some View {
        if adaptiveLayout.isWide && requiresMadinah {
            HStack(alignment: .top, spacing: 20) {
                cityHotelContent(role: .makkah)
                    .frame(maxWidth: .infinity, alignment: .top)
                cityHotelContent(role: .madinah)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            cityHotelContent(role: .makkah)
            if requiresMadinah {
                cityHotelContent(role: .madinah)
            }
        }
    }

    @ViewBuilder
    private func cityHotelContent(role: HotelSelectionRole) -> some View {
        let isMakkah = role == .makkah
        let isLoading = isMakkah ? journey.isLoadingHotels : journey.isLoadingMadinahHotels
        let selectedHotel = isMakkah ? journey.selectedHotel : journey.selectedMadinahHotel
        let roomName = isMakkah
            ? (journey.selectedRoom?.name ?? journey.selectedRoomCategory?.displayName)
            : (journey.selectedMadinahRoom?.name ?? journey.selectedMadinahRoomCategory?.displayName)

        if isLoading && selectedHotel == nil {
            loadingCard
        } else if let hotel = selectedHotel {
            stayCard(
                hotel: hotel,
                role: role,
                title: recommendedTitle(role: role),
                roomName: roomName
            )
        } else {
            missingHotelCard(role: role)
        }
    }

    private func recommendedTitle(role: HotelSelectionRole) -> String {
        switch settings.language {
        case .turkish:
            return "iumrah Öneriyor"
        case .english:
            return "iumrah Recommended"
        case .russian:
            return "Рекомендуем iumrah"
        case .uzbek:
            return "iumrah tavsiyasi"
        case .uzbekCyrillic:
            return "iumrah тавсияси"
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 13) {
            ProgressView()
            Text(L10n.text("primary_hotel_loading", settings.language))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func stayCard(hotel: HotelSummary, role: HotelSelectionRole, title: String, roomName: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            hotelImage(hotel)
                .frame(height: 214)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(12)
                .padding(.bottom, 0)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Label(title, systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color.iumrahCareLight.opacity(0.16), in: Capsule())

                    Spacer(minLength: 8)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.iumrahCareLight)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Text(FlowCopy.text(.primaryHotel, settings.language))
                        if let stars = hotel.stars { Text("· \(stars)★") }
                        Text("·")
                        Text(role == .makkah ? localizedMakkah : localizedMadinah)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    Text(hotel.name)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                }

                HStack(spacing: 8) {
                    Label(L10n.city(hotel.city, settings.language), systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background(Color.iumrahRaisedBackground, in: Capsule())

                    if let roomName, !roomName.isEmpty {
                        Label(roomName, systemImage: "bed.double.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 11)
                            .frame(height: 32)
                            .background(Color.iumrahRaisedBackground, in: Capsule())
                    }
                    Spacer(minLength: 0)
                }

                if journey.hasSelectableHotelMeals {
                    mealPlanCard(role: role)
                }

                HStack(spacing: 10) {
                    NavigationLink {
                        HotelDetailView(hotel: hotel, selectionFlow: true, selectionRole: role)
                    } label: {
                        Label(FlowCopy.text(.viewHotel, settings.language), systemImage: "info.circle")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftHotelActionButtonStyle())

                    NavigationLink {
                        HotelSelectionView(role: role)
                    } label: {
                        Label(FlowCopy.text(.changeHotel, settings.language), systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftHotelActionButtonStyle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }

    private func mealPlanCard(role: HotelSelectionRole) -> some View {
        let city: HotelMealCity = role == .makkah ? .makkah : .madinah

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Color.primary.opacity(0.06), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(mealPlanTitle)
                        .font(.subheadline.weight(.bold))
                    Text(mealScheduleText(role: role))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            Divider().padding(.leading, 54)
            includedBreakfastRow

            if role == .makkah {
                Divider().padding(.leading, 54)
                selectableMealRow(.lunch, city: city)
            }

            Divider().padding(.leading, 54)
            selectableMealRow(.dinner, city: city)
        }
        .background(Color.iumrahRaisedBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 0.6)
        }
    }

    private var includedBreakfastRow: some View {
        HStack(spacing: 12) {
            mealIcon("cup.and.saucer.fill")

            VStack(alignment: .leading, spacing: 2) {
                Text(mealName(.breakfast))
                    .font(.subheadline.weight(.semibold))
                Text(mealIncludedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.iumrahCareLight)
                .accessibilityLabel(mealIncludedText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func selectableMealRow(_ meal: HotelMealKind, city: HotelMealCity) -> some View {
        let price = PackagePricingPresentation.optionalMealUnitPriceUsd(for: journey.trip.packageTier) ?? 0
        let isOn = Binding(
            get: { journey.isMealEnabled(meal, city: city) },
            set: { journey.setMealEnabled($0, meal: meal, city: city) }
        )

        return HStack(spacing: 12) {
            mealIcon(meal == .lunch ? "sun.max.fill" : "moon.stars.fill")

            VStack(alignment: .leading, spacing: 2) {
                Text(mealName(meal))
                    .font(.subheadline.weight(.semibold))
                Text(optionalMealPriceText(price))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.iumrahCareLight)
                .accessibilityLabel(mealName(meal))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func mealIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
    }

    private var mealPlanTitle: String {
        switch settings.language {
        case .russian: return "Питание в отеле"
        case .turkish: return TurkishLocalization.phrase("Hotel meals")
        case .english: return "Hotel meals"
        case .uzbek: return "Mehmonxonada ovqatlanish"
        case .uzbekCyrillic: return "Меҳмонхонада овқатланиш"
        }
    }

    private func mealScheduleText(role: HotelSelectionRole) -> String {
        switch (settings.language, role) {
        case (.russian, .makkah): return "Мекка · завтрак, обед и ужин"
        case (.russian, .madinah): return "Медина · завтрак и ужин"
        case (.turkish, .makkah): return TurkishLocalization.phrase("Makkah · breakfast, lunch and dinner")
        case (.english, .makkah): return "Makkah · breakfast, lunch and dinner"
        case (.turkish, .madinah): return TurkishLocalization.phrase("Madinah · breakfast and dinner")
        case (.english, .madinah): return "Madinah · breakfast and dinner"
        case (.uzbek, .makkah): return "Makka · nonushta, tushlik va kechki ovqat"
        case (.uzbek, .madinah): return "Madina · nonushta va kechki ovqat"
        case (.uzbekCyrillic, .makkah): return "Макка · нонушта, тушлик ва кечки овқат"
        case (.uzbekCyrillic, .madinah): return "Мадина · нонушта ва кечки овқат"
        }
    }

    private func mealName(_ meal: HotelMealKind) -> String {
        switch (settings.language, meal) {
        case (.russian, .breakfast): return "Завтрак"
        case (.russian, .lunch): return "Обед"
        case (.russian, .dinner): return "Ужин"
        case (.turkish, .breakfast): return TurkishLocalization.phrase("Breakfast")
        case (.english, .breakfast): return "Breakfast"
        case (.turkish, .lunch): return TurkishLocalization.phrase("Lunch")
        case (.english, .lunch): return "Lunch"
        case (.turkish, .dinner): return TurkishLocalization.phrase("Dinner")
        case (.english, .dinner): return "Dinner"
        case (.uzbek, .breakfast): return "Nonushta"
        case (.uzbek, .lunch): return "Tushlik"
        case (.uzbek, .dinner): return "Kechki ovqat"
        case (.uzbekCyrillic, .breakfast): return "Нонушта"
        case (.uzbekCyrillic, .lunch): return "Тушлик"
        case (.uzbekCyrillic, .dinner): return "Кечки овқат"
        }
    }

    private var mealIncludedText: String {
        switch settings.language {
        case .russian: return "Включено · без доплаты"
        case .turkish: return TurkishLocalization.phrase("Included · no extra charge")
        case .english: return "Included · no extra charge"
        case .uzbek: return "Kiritilgan · qo‘shimcha to‘lovsiz"
        case .uzbekCyrillic: return "Киритилган · қўшимча тўловсиз"
        }
    }

    private func optionalMealPriceText(_ price: Decimal) -> String {
        let amount = NSDecimalNumber(decimal: price).intValue
        switch settings.language {
        case .russian: return "$\(amount) · за человека / день"
        case .turkish: return TurkishLocalization.phrase("$\(amount) · per person / day")
        case .english: return "$\(amount) · per person / day"
        case .uzbek: return "$\(amount) · kishi / kun"
        case .uzbekCyrillic: return "$\(amount) · киши / кун"
        }
    }

    private var localizedMakkah: String {
        switch settings.language {
        case .russian: return "Мекка"
        case .turkish: return TurkishLocalization.phrase("Makkah")
        case .english: return "Makkah"
        case .uzbek: return "Makka"
        case .uzbekCyrillic: return "Макка"
        }
    }

    private var localizedMadinah: String {
        switch settings.language {
        case .russian: return "Медина"
        case .turkish: return TurkishLocalization.phrase("Madinah")
        case .english: return "Madinah"
        case .uzbek: return "Madina"
        case .uzbekCyrillic: return "Мадина"
        }
    }

    private func missingHotelCard(role: HotelSelectionRole) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 36, weight: .light))
            Text(role == .makkah ? FlowCopy.text(.makkahStay, settings.language) : FlowCopy.text(.madinahStay, settings.language))
                .font(.headline)
            NavigationLink {
                HotelSelectionView(role: role)
            } label: {
                Text(FlowCopy.text(.chooseHotel, settings.language))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func hotelImage(_ hotel: HotelSummary) -> some View {
        GeometryReader { proxy in
            HotelCachedImage(rawURL: hotel.coverImageURL)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

private struct SoftHotelActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 52)
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                interactive: true
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
    }
}
