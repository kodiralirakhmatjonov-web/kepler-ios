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
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
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
        .sheet(isPresented: $showShareSheet) {
            IumrahActivityView(activityItems: shareItems)
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
            let height = width / 1.586

            identityCardSurface(width: width, height: height)
                .frame(width: width, height: height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func identityCardSurface(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)

            LinearGradient(
                colors: [Color.black.opacity(0.035), .clear, Color.black.opacity(0.018)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("iumrah ID")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Spacer()
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.42))
                }

                Spacer()

                HStack(alignment: .bottom, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(firstNameValue)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                        Text(lastNameValue)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.70))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("UMR ID")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.9)
                            .foregroundStyle(.black.opacity(0.42))
                        Text(normalizedID(identityValue))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
            }
            .padding(22)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.11), radius: 22, y: 12)
    }

    private func boardingPass(_ flight: FlightOffer, title: String) -> some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 42, 360)
            let height = min(max(width * 1.24, 420), 470)

            boardingPassSurface(flight: flight, title: title, width: width, height: height)
                .frame(width: width, height: height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func boardingPassSurface(flight: FlightOffer, title: String, width: CGFloat, height: CGFloat) -> some View {
        let tearY = height * 0.69

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.10), radius: 22, y: 12)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(flight.airline.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(.black.opacity(0.48))
                        Text(title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(flight.flightNumber)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                        Text(shortDate(flight.departureAt))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.52))
                    }
                }

                Spacer().frame(height: 28)

                HStack(alignment: .center, spacing: 14) {
                    routeAirport(code: flight.origin, date: flight.departureAt, alignment: .leading)

                    VStack(spacing: 7) {
                        Image(systemName: "airplane")
                            .font(.system(size: 20, weight: .bold))
                            .rotationEffect(.degrees(0))
                        Capsule()
                            .fill(Color.black.opacity(0.16))
                            .frame(height: 1)
                        Text(durationText(flight.durationMinutes))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)

                    routeAirport(code: flight.destination, date: flight.arrivalAt, alignment: .trailing)
                }

                Spacer().frame(height: 24)

                HStack(spacing: 18) {
                    passFact(tr("Passenger", "Пассажир", "Yo‘lovchi", "Йўловчи"), passengerName)
                    passFact(tr("Class", "Класс", "Klass", "Класс"), nonBlank(flight.cabinClass) ?? tr("Economy", "Эконом", "Ekonom", "Эконом"))
                }

                HStack(spacing: 18) {
                    passFact(tr("Terminal", "Терминал", "Terminal", "Терминал"), terminalText(flight))
                    passFact(tr("Baggage", "Багаж", "Bagaj", "Багаж"), baggageText(flight))
                }
                .padding(.top, 15)

                Spacer(minLength: 16)

                perforation
                    .frame(height: 18)

                Spacer().frame(height: 14)

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
            .padding(.vertical, 20)

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

    private func routeAirport(code: String, date: Date, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(code)
                .font(.system(size: 39, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
            Text(timeString(date))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
            Text(shortDate(date))
                .font(.caption)
                .foregroundStyle(.black.opacity(0.50))
        }
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
                    identityCardSurface(width: 1000, height: 1000 / 1.586)
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

        if let image {
            shareItems = [image, pageShareTitle]
            showShareSheet = true
            IumrahHaptics.success()
        }
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
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private struct IumrahActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
