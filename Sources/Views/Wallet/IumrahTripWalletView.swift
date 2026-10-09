import SwiftUI
import UIKit

struct IumrahTripWalletEntry: View {
    let session: StoredBookingSession
    let profile: IumrahAccountProfile?
    let language: AppSettingsStore.Language

    @State private var presented = false

    var body: some View {
        Button {
            IumrahHaptics.selection()
            presented = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("iumrah Wallet")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(tr(
                            "Your ID, boarding passes and hotels",
                            "Ваш ID, посадочные талоны и отели",
                            "ID, boarding pass va mehmonxonalar bir joyda",
                            "ID, boarding pass ва меҳмонхоналар бир жойда"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                Image("IumrahLeatherWallet")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .scaleEffect(1.12)
                    .padding(.horizontal, -18)
                    .padding(.top, 2)
                    .padding(.bottom, -12)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $presented) {
            IumrahTripWalletScreen(session: session, profile: profile, language: language)
        }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private enum IumrahWalletPage: String, Hashable {
    case identity
    case outbound
    case inbound
    case makkahHotel
    case madinahHotel
}

private struct IumrahTripWalletScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let session: StoredBookingSession
    let profile: IumrahAccountProfile?
    let language: AppSettingsStore.Language

    @State private var page: IumrahWalletPage = .identity
    @State private var walletIdentityCopyMessage: String?
    @State private var makkahDetail: HotelDetail?
    @State private var madinahDetail: HotelDetail?

    private let hotelService = HotelCatalogService()

    var body: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.50) : Color.white.opacity(0.50))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                Spacer(minLength: 18)

                TabView(selection: $page) {
                    ForEach(availablePages, id: \.self) { item in
                        pageView(item)
                            .tag(item)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 560)

                pageIndicator
                    .padding(.top, 16)

                Spacer(minLength: 24)
            }
        }
        .task {
            await loadHotelDetails()
        }
    }

    private var availablePages: [IumrahWalletPage] {
        var items: [IumrahWalletPage] = [.identity]
        if session.outboundFlight != nil { items.append(.outbound) }
        if session.inboundFlight != nil { items.append(.inbound) }
        if hotelCardsVisible, session.hotelSelection != nil { items.append(.makkahHotel) }
        if hotelCardsVisible, session.madinahHotelSelection != nil { items.append(.madinahHotel) }
        return items
    }

    @ViewBuilder
    private func pageView(_ item: IumrahWalletPage) -> some View {
        switch item {
        case .identity:
            identityCard
        case .outbound:
            if let flight = session.outboundFlight {
                boardingPass(flight, title: tr("Outbound", "Туда", "Borish", "Бориш"))
            }
        case .inbound:
            if let flight = session.inboundFlight {
                boardingPass(flight, title: tr("Return", "Обратно", "Qaytish", "Қайтиш"))
            }
        case .makkahHotel:
            if let hotel = session.hotelSelection {
                hotelCard(hotel, detail: makkahDetail, cityTitle: tr("Makkah", "Мекка", "Makka", "Макка"))
            }
        case .madinahHotel:
            if let hotel = session.madinahHotelSelection {
                hotelCard(hotel, detail: madinahDetail, cityTitle: tr("Madinah", "Медина", "Madina", "Мадина"))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("iumrah Wallet")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(pageSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            IumrahGlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    if canShareCurrentPage {
                        IumrahGlassIconButton(
                            systemName: "square.and.arrow.up",
                            size: 48,
                            fontSize: 17,
                            accessibilityLabel: tr("Share", "Поделиться", "Ulashish", "Улашиш")
                        ) {
                            shareCurrentPage()
                        }
                    }

                    IumrahGlassIconButton(
                        systemName: "xmark",
                        size: 48,
                        fontSize: 17,
                        accessibilityLabel: tr("Close", "Закрыть", "Yopish", "Ёпиш")
                    ) {
                        dismiss()
                    }
                }
            }
        }
        .zIndex(50)
    }

    private var pageSubtitle: String {
        switch page {
        case .identity:
            return tr("Pilgrim identity", "ID паломника", "Ziyoratchi ID", "Зиёратчи ID")
        case .outbound:
            return tr("Outbound boarding pass", "Посадочный талон туда", "Borish boarding pass", "Бориш boarding pass")
        case .inbound:
            return tr("Return boarding pass", "Посадочный талон обратно", "Qaytish boarding pass", "Қайтиш boarding pass")
        case .makkahHotel:
            return tr("Makkah hotel", "Отель в Мекке", "Makka mehmonxonasi", "Макка меҳмонхонаси")
        case .madinahHotel:
            return tr("Madinah hotel", "Отель в Медине", "Madina mehmonxonasi", "Мадина меҳмонхонаси")
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(availablePages, id: \.self) { item in
                Capsule(style: .continuous)
                    .fill(item == page ? Color.primary.opacity(0.82) : Color.primary.opacity(0.18))
                    .frame(width: item == page ? 22 : 7, height: 7)
                    .animation(.snappy(duration: 0.22), value: page)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .iumrahGlass(in: Capsule(style: .continuous), allowsStaticGlass: true, chrome: true)
        .allowsHitTesting(false)
    }

    private var identityCard: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 44, 360)

            IumrahIdentityDomeCard(
                data: IumrahIdentityCardData(
                    iumrahID: identityValue,
                    displayName: passengerName,
                    phone: profile?.phone,
                    email: profile?.email
                ),
                language: language,
                copyMessage: walletIdentityCopyMessage,
                allowsFlip: true,
                onCopy: copyWalletIdentity
            )
            .frame(width: width)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func identityShareCard(width: CGFloat) -> some View {
        IumrahIdentityDomeCard(
            data: IumrahIdentityCardData(
                iumrahID: identityValue,
                displayName: passengerName,
                phone: profile?.phone,
                email: profile?.email
            ),
            language: language,
            allowsFlip: false
        )
        .frame(width: width)
    }

    private func boardingPass(_ flight: FlightOffer, title: String) -> some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 42, 360)
            let height = min(max(width * 1.48, 500), 540)

            boardingPassSurface(flight: flight, title: title, width: width, height: height)
                .frame(width: width, height: height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func boardingPassSurface(flight: FlightOffer, title: String, width: CGFloat, height: CGFloat) -> some View {
        let tearY = height * 0.72
        let departureTerminal = nonBlank(flight.segments?.first?.origin.terminal) ?? "—"
        let arrivalTerminal = nonBlank(flight.segments?.last?.destination.terminal) ?? "—"

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.10), radius: 22, y: 12)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Image("IumrahFlightsBoardingLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 122, height: 48, alignment: .leading)
                        .foregroundStyle(.black)

                    Spacer(minLength: 6)

                    AirlineLogoView(airlineCode: flight.airlineCode, size: 54)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(flight.airline)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                        Text(flight.flightNumber)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.56))
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(.black.opacity(0.40))
                    Spacer()
                    Text(shortDate(flight.departureAt))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.52))
                }
                .padding(.top, 10)

                Spacer().frame(height: 20)

                HStack(alignment: .center, spacing: 14) {
                    routeAirportDetailed(code: flight.origin, date: flight.departureAt, terminal: departureTerminal, trailing: false)

                    VStack(spacing: 6) {
                        Image(systemName: "airplane")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black)
                        Capsule()
                            .fill(Color.black.opacity(0.16))
                            .frame(height: 1)
                        Text(durationText(flight.durationMinutes))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)

                    routeAirportDetailed(code: flight.destination, date: flight.arrivalAt, terminal: arrivalTerminal, trailing: true)
                }

                Spacer().frame(height: 18)

                HStack(spacing: 12) {
                    passFact(tr("Passenger", "Пассажир", "Yo‘lovchi", "Йўловчи"), passengerName)
                    passFact(tr("Class", "Класс", "Klass", "Класс"), nonBlank(flight.cabinClass) ?? tr("Economy", "Эконом", "Ekonom", "Эконом"))
                }

                HStack(spacing: 12) {
                    passFact(tr("Departure terminal", "Терминал вылета", "Jo‘nash terminali", "Жўнаш терминали"), departureTerminal)
                    passFact(tr("Arrival terminal", "Терминал прилёта", "Kelish terminali", "Келиш терминали"), arrivalTerminal)
                }
                .padding(.top, 12)

                HStack(spacing: 12) {
                    passFact(tr("Baggage", "Багаж", "Bagaj", "Багаж"), baggageText(flight))
                    passFact(tr("Stops", "Пересадки", "To‘xtash", "Тўхташ"), stopsText(flight.stops))
                }
                .padding(.top, 12)

                Spacer(minLength: 12)

                perforation
                    .frame(height: 18)

                Spacer().frame(height: 12)

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("BOOKING", "БРОНЬ", "BRON", "БРОН"))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.black.opacity(0.40))
                        Text(session.displayBookingNumber)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                    }

                    Spacer(minLength: 8)

                    barcode
                        .frame(width: 130, height: 48)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Circle()
                .fill(walletBackdropColor)
                .frame(width: 20, height: 20)
                .position(x: 0, y: tearY)
            Circle()
                .fill(walletBackdropColor)
                .frame(width: 20, height: 20)
                .position(x: width, y: tearY)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.8)
        }
    }

    private var perforation: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
            }
            .stroke(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
    }

    private func routeAirportDetailed(code: String, date: Date, terminal: String, trailing: Bool) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
            Text(code)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
            Text(timeString(date))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
            Text(airportName(code))
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.black.opacity(0.54))
                .lineLimit(2)
                .multilineTextAlignment(trailing ? .trailing : .leading)
            Text("T \(terminal)")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.42))
        }
        .frame(maxWidth: 116, alignment: trailing ? .trailing : .leading)
    }

    private func passFact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(.black.opacity(0.40))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hotelCard(_ hotel: BookingHotelSelectionSnapshot, detail: HotelDetail?, cityTitle: String) -> some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 44, 360)
            let height = width / 1.586

            hotelCardSurface(hotel, detail: detail, cityTitle: cityTitle, width: width, height: height)
                .frame(width: width, height: height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func hotelCardSurface(
        _ hotel: BookingHotelSelectionSnapshot,
        detail: HotelDetail?,
        cityTitle: String,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black)

            if let imageURL = hotelImageURL(hotel, detail: detail) {
                HotelCachedImage(rawURL: imageURL)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color.gray.opacity(0.55), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.03),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.82),
                    Color.black.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Spacer()

                Text(cityTitle.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.70))

                Text(hotel.hotelName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(hotelLocationText(hotel, detail: detail))
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))

                if let room = nonBlank(hotel.roomName) {
                    Text(room)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 22, y: 12)
    }

    private var pageShareTitle: String {
        switch page {
        case .identity: return "iumrah ID"
        case .outbound: return tr("Outbound boarding pass", "Посадочный талон туда", "Borish boarding pass", "Бориш boarding pass")
        case .inbound: return tr("Return boarding pass", "Посадочный талон обратно", "Qaytish boarding pass", "Қайтиш boarding pass")
        case .makkahHotel, .madinahHotel: return "iumrah Wallet"
        }
    }

    private var canShareCurrentPage: Bool {
        switch page {
        case .identity, .outbound, .inbound:
            return true
        case .makkahHotel, .madinahHotel:
            return false
        }
    }

    @MainActor
    private func shareCurrentPage() {
        let image: UIImage?
        switch page {
        case .identity:
            image = renderImage(
                ZStack {
                    Color.white
                    identityShareCard(width: 1000)
                        .padding(70)
                }
                .frame(width: 1140, height: 860)
            )
        case .outbound:
            if let flight = session.outboundFlight {
                image = renderImage(
                    ZStack {
                        Color.white
                        boardingPassSurface(flight: flight, title: tr("Outbound", "Туда", "Borish", "Бориш"), width: 760, height: 960)
                            .padding(70)
                    }
                    .frame(width: 900, height: 1100)
                )
            } else {
                image = nil
            }
        case .inbound:
            if let flight = session.inboundFlight {
                image = renderImage(
                    ZStack {
                        Color.white
                        boardingPassSurface(flight: flight, title: tr("Return", "Обратно", "Qaytish", "Қайтиш"), width: 760, height: 960)
                            .padding(70)
                    }
                    .frame(width: 900, height: 1100)
                )
            } else {
                image = nil
            }
        case .makkahHotel, .madinahHotel:
            image = nil
        }

        if let image, let url = writeShareImage(image, title: pageShareTitle) {
            presentNativeShare(url)
            IumrahHaptics.success()
        }
    }

    private func copyWalletIdentity() {
        UIPasteboard.general.string = normalizedID(identityValue)
        walletIdentityCopyMessage = tr("Copied", "Скопировано", "Nusxalandi", "Нусхаланди")
        IumrahHaptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            walletIdentityCopyMessage = nil
        }
    }

    private func airportName(_ code: String) -> String {
        guard let airport = FlightReferenceCatalog.airport(code) else { return code.uppercased() }
        return "\(airport.city) · \(airport.name)"
    }

    private func stopsText(_ stops: Int) -> String {
        if stops <= 0 {
            return tr("Direct", "Прямой", "To‘g‘ridan-to‘g‘ri", "Тўғридан-тўғри")
        }
        return "\(stops)"
    }

    @MainActor
    private func writeShareImage(_ image: UIImage, title: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let safeTitle = title
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let filename = "\(safeTitle.isEmpty ? "iumrah-pass" : safeTitle)-\(UUID().uuidString.prefix(8)).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @MainActor
    private func presentNativeShare(_ url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.maxY - 44, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        presenter.present(controller, animated: true)
    }

    @MainActor
    private func renderImage<Content: View>(_ view: Content) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }

    private var walletBackdropColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.50) : Color.white.opacity(0.50)
    }

    private var passengerName: String {
        nonBlank(profile?.displayName) ?? nonBlank(session.travelerName) ?? tr("Pilgrim", "Паломник", "Ziyoratchi", "Зиёратчи")
    }

    private var identityValue: String {
        profile?.iumrahID ?? session.displayPilgrimID ?? "—"
    }

    private var firstNameValue: String {
        if let value = nonBlank(profile?.firstName) { return value }
        return firstNameFromDisplayName ?? tr("Pilgrim", "Паломник", "Ziyoratchi", "Зиёратчи")
    }

    private var lastNameValue: String {
        if let value = nonBlank(profile?.lastName) { return value }
        return lastNameFromDisplayName ?? "—"
    }

    private var firstNameFromDisplayName: String? {
        let parts = passengerName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        return parts.first.map(String.init)
    }

    private var lastNameFromDisplayName: String? {
        let parts = passengerName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        return parts.count > 1 ? String(parts[1]) : nil
    }

    private var hotelCardsVisible: Bool {
        switch session.effectiveStatus.uppercased() {
        case "PAID", "BOOKING_CONFIRMED", "DOCUMENTS_READY", "READY_TO_TRAVEL", "IN_TRIP", "COMPLETED":
            return true
        default:
            return false
        }
    }

    @MainActor
    private func loadHotelDetails() async {
        async let makkah: HotelDetail? = loadHotelDetail(session.hotelSelection)
        async let madinah: HotelDetail? = loadHotelDetail(session.madinahHotelSelection)
        let results = await (makkah, madinah)
        makkahDetail = results.0
        madinahDetail = results.1
    }

    private func loadHotelDetail(_ snapshot: BookingHotelSelectionSnapshot?) async -> HotelDetail? {
        guard hotelCardsVisible, let snapshot else { return nil }
        return try? await hotelService.hotelDetail(id: snapshot.hotelId)
    }

    private func hotelImageURL(_ hotel: BookingHotelSelectionSnapshot, detail: HotelDetail?) -> String? {
        if let value = nonBlank(hotel.coverImageURL) { return value }
        if let value = nonBlank(detail?.images.first(where: { $0.isCover })?.url) { return value }
        return nonBlank(detail?.images.first?.url)
    }

    private func hotelLocationText(_ hotel: BookingHotelSelectionSnapshot, detail: HotelDetail?) -> String {
        if let address = nonBlank(detail?.address) { return address }
        if let city = nonBlank(hotel.city) { return city }
        return tr("Saudi Arabia", "Саудовская Аравия", "Saudiya Arabistoni", "Саудия Арабистони")
    }

    private func terminalText(_ flight: FlightOffer) -> String {
        let departure = nonBlank(flight.segments?.first?.origin.terminal)
        let arrival = nonBlank(flight.segments?.last?.destination.terminal)
        switch (departure, arrival) {
        case let (d?, a?) where d != a: return "\(d) → \(a)"
        case let (d?, _): return d
        case let (_, a?): return a
        default: return "—"
        }
    }

    private func durationText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    private func baggageText(_ flight: FlightOffer) -> String {
        guard let baggage = flight.baggage else { return "—" }
        var parts: [String] = []
        if let carry = baggage.carryOn { parts.append("\(carry) kg") }
        if let checked = baggage.checked { parts.append("\(checked) kg") }
        return parts.isEmpty ? "—" : parts.joined(separator: " + ")
    }

    private var barcode: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(0..<31, id: \.self) { index in
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: index.isMultiple(of: 5) ? 3.5 : (index.isMultiple(of: 3) ? 2.5 : 1.5))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private func normalizedID(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return value }
        if digits.count >= 8 { return digits }
        return String(repeating: "0", count: 8 - digits.count) + digits
    }

    private func nonBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
