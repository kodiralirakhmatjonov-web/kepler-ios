import SwiftUI

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
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("iumrah Wallet")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text(tr(
                            "Your trip, ID, tickets and hotels in one place",
                            "Ваша поездка, ID, билеты и отели в одном месте",
                            "Safar, ID, chiptalar va mehmonxonalar bir joyda",
                            "Сафар, ID, чипталар ва меҳмонхоналар бир жойда"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                walletPreview
                    .frame(height: 205)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $presented) {
            IumrahTripWalletScreen(session: session, profile: profile, language: language)
        }
    }

    private var walletPreview: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .bottom) {
                compactPass(
                    title: nonBlank(profile?.displayName) ?? nonBlank(session.travelerName) ?? "iumrah ID",
                    detail: profile.map { "ID \($0.iumrahID)" } ?? session.displayBookingNumber,
                    symbol: "person.text.rectangle.fill",
                    fill: Color.black
                )
                .frame(width: width * 0.82, height: 106)
                .offset(y: -82)

                if let outbound = session.outboundFlight {
                    compactPass(
                        title: "\(outbound.origin)  →  \(outbound.destination)",
                        detail: "\(outbound.airline) · \(outbound.flightNumber)",
                        symbol: "airplane.departure",
                        fill: Color(red: 0.12, green: 0.16, blue: 0.17)
                    )
                    .frame(width: width * 0.88, height: 106)
                    .offset(y: -56)
                } else {
                    compactPass(
                        title: session.displayBookingNumber,
                        detail: statusLabel,
                        symbol: "checkmark.seal.fill",
                        fill: Color(red: 0.23, green: 0.17, blue: 0.14)
                    )
                    .frame(width: width * 0.88, height: 106)
                    .offset(y: -56)
                }

                if hotelCardsVisible, let hotel = session.hotelSelection {
                    compactPass(
                        title: hotel.hotelName,
                        detail: tr("Makkah hotel", "Отель в Мекке", "Makka mehmonxonasi", "Макка меҳмонхонаси"),
                        symbol: "building.2.fill",
                        fill: Color(red: 0.17, green: 0.14, blue: 0.12)
                    )
                    .frame(width: width * 0.93, height: 106)
                    .offset(y: -28)
                }

                Image("IumrahLeatherWallet")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
                    .shadow(color: .black.opacity(0.16), radius: 16, y: 9)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func compactPass(title: String, detail: String, symbol: String, fill: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.bold)).lineLimit(1)
                Text(detail).font(.caption2).foregroundStyle(.white.opacity(0.64)).lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.7)
        }
    }

    private var statusLabel: String {
        let status = session.effectiveStatus.uppercased()
        switch status {
        case "NEW", "AVAILABILITY_CHECK":
            return tr("Availability is being confirmed", "Наличие подтверждается", "Mavjudlik tasdiqlanmoqda", "Мавжудлик тасдиқланмоқда")
        case "PAYMENT_PENDING":
            return tr("Availability confirmed", "Наличие подтверждено", "Mavjudlik tasdiqlandi", "Мавжудлик тасдиқланди")
        case "PAID", "BOOKING_CONFIRMED", "DOCUMENTS_READY", "READY_TO_TRAVEL", "IN_TRIP", "COMPLETED":
            return tr("Booking confirmed", "Бронирование подтверждено", "Bron tasdiqlandi", "Брон тасдиқланди")
        default:
            return L10n.status(session.effectiveStatus, language)
        }
    }

    private var hotelCardsVisible: Bool {
        switch session.effectiveStatus.uppercased() {
        case "PAID", "BOOKING_CONFIRMED", "DOCUMENTS_READY", "READY_TO_TRAVEL", "IN_TRIP", "COMPLETED":
            return true
        default:
            return false
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

private struct IumrahTripWalletScreen: View {
    @Environment(\.dismiss) private var dismiss

    let session: StoredBookingSession
    let profile: IumrahAccountProfile?
    let language: AppSettingsStore.Language

    @State private var page = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.07, blue: 0.065), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 6)

                TabView(selection: $page) {
                    identityCard.tag(0)
                    if let outbound = session.outboundFlight {
                        boardingPass(outbound, title: tr("Outbound", "Туда", "Borish", "Бориш")).tag(1)
                    }
                    if let inbound = session.inboundFlight {
                        boardingPass(inbound, title: tr("Return", "Обратно", "Qaytish", "Қайтиш")).tag(2)
                    }
                    bookingCard.tag(3)
                    if hotelCardsVisible, let makkah = session.hotelSelection {
                        hotelCard(makkah, cityTitle: tr("Makkah", "Мекка", "Makka", "Макка")).tag(4)
                    }
                    if hotelCardsVisible, let madinah = session.madinahHotelSelection {
                        hotelCard(madinah, cityTitle: tr("Madinah", "Медина", "Madina", "Мадина")).tag(5)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                .frame(maxHeight: 540)

                VStack(spacing: 5) {
                    Text(session.displayBookingNumber)
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(.white.opacity(0.70))
                    Text(tr(
                        "This booking is linked to your trip and is available to the guide assigned to it.",
                        "Эта бронь привязана к поездке и доступна гиду, назначенному на Вашу поездку.",
                        "Bu bron safaringizga bog‘langan va safarga biriktirilgan gid uchun mavjud.",
                        "Бу брон сафарингизга боғланган ва сафарга бириктирилган гид учун мавжуд."
                    ))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 14)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("iumrah Wallet")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(tr("Swipe through your trip", "Листайте документы поездки", "Safar hujjatlarini suring", "Сафар ҳужжатларини суринг"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .iumrahGlass(in: Circle(), interactive: true, tint: Color.white.opacity(0.05), chrome: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var identityCard: some View {
        walletCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("iumrah ID")
                            .font(.caption.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(.white.opacity(0.60))
                        Text(profile?.iumrahID ?? session.displayPilgrimID ?? "—")
                            .font(.system(size: 31, weight: .bold, design: .monospaced))
                            .tracking(2)
                    }
                    Spacer()
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 5) {
                    Text(nonBlank(profile?.displayName) ?? nonBlank(session.travelerName) ?? tr("Booking holder", "Владелец бронирования", "Bron egasi", "Брон эгаси"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination) · \(session.displayBookingNumber)")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.white.opacity(0.68))
                }

                HStack {
                    Label(tr("Trip identity", "ID поездки", "Safar ID", "Сафар ID"), systemImage: "checkmark.shield.fill")
                    Spacer()
                    Text(statusLabel)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
            }
        }
    }

    private func boardingPass(_ flight: FlightOffer, title: String) -> some View {
        walletCard(background: Color(red: 0.93, green: 0.94, blue: 0.92), foreground: .black) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(title, systemImage: flight.direction == .outbound ? "airplane.departure" : "airplane.arrival")
                        .font(.caption.weight(.bold))
                    Spacer()
                    Text(flight.airline)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.black.opacity(0.70))

                HStack(alignment: .center, spacing: 16) {
                    airportBlock(flight.origin, date: flight.departureAt, alignment: .leading)
                    VStack(spacing: 6) {
                        Image(systemName: "airplane")
                            .font(.system(size: 22, weight: .semibold))
                        Capsule().fill(Color.black.opacity(0.18)).frame(height: 1)
                    }
                    .frame(maxWidth: .infinity)
                    airportBlock(flight.destination, date: flight.arrivalAt, alignment: .trailing)
                }

                Divider().overlay(Color.black.opacity(0.16))

                HStack(spacing: 18) {
                    ticketFact(tr("Flight", "Рейс", "Reys", "Рейс"), flight.flightNumber)
                    ticketFact(tr("Date", "Дата", "Sana", "Сана"), shortDate(flight.departureAt))
                    ticketFact(tr("Class", "Класс", "Klass", "Класс"), nonBlank(flight.cabinClass) ?? tr("Economy", "Эконом", "Ekonom", "Эконом"))
                }

                HStack(spacing: 18) {
                    ticketFact(tr("Terminal", "Терминал", "Terminal", "Терминал"), terminalText(flight))
                    ticketFact(tr("Duration", "В пути", "Davomiyligi", "Давомийлиги"), durationText(flight.durationMinutes))
                    ticketFact(tr("Baggage", "Багаж", "Bagaj", "Багаж"), baggageText(flight))
                }

                Spacer(minLength: 2)

                HStack(alignment: .bottom, spacing: 14) {
                    barcode
                        .frame(height: 58)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(nonBlank(profile?.displayName) ?? nonBlank(session.travelerName) ?? "iumrah")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                        Text(session.displayBookingNumber)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.black.opacity(0.55))
                    }
                }
            }
        }
    }

    private var bookingCard: some View {
        walletCard(background: Color(red: 0.17, green: 0.12, blue: 0.10)) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text(tr("Umrah booking", "Бронирование Umrah", "Umrah broni", "Umrah брони"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.58))
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                }
                Text(session.displayBookingNumber)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                Text(statusLabel)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                            .font(.headline)
                        Text("\(dateString(session.booking.input.startDate)) – \(dateString(session.booking.input.endDate))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    Text("\(session.booking.input.travelers.totalPeople)")
                        .font(.title2.bold())
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                }
            }
        }
    }

    private func hotelCard(_ hotel: BookingHotelSelectionSnapshot, cityTitle: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(red: 0.055, green: 0.055, blue: 0.060))

            if nonBlank(hotel.coverImageURL) != nil {
                HotelCachedImage(rawURL: hotel.coverImageURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [Color.black.opacity(0.34), Color.black.opacity(0.72), Color.black.opacity(0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }

            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cityTitle.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.66))
                        Text(tr("Hotel", "Отель", "Mehmonxona", "Меҳмонхона"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.56))
                    }
                    Spacer()
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .frame(width: 52, height: 52)
                        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                Spacer()
                Text(hotel.hotelName)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                if let room = nonBlank(hotel.roomName) {
                    Text(room)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                HStack {
                    Label(session.displayBookingNumber, systemImage: "number")
                    Spacer()
                    Text(statusLabel)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
            }
            .foregroundStyle(.white)
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.28), radius: 22, y: 14)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private func walletCard<Content: View>(
        background: Color = .black,
        foreground: Color = .white,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .foregroundStyle(foreground)
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(background, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(foreground.opacity(0.10), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.28), radius: 22, y: 14)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
    }

    private func airportBlock(_ code: String, date: Date, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(code)
                .font(.system(size: 38, weight: .bold, design: .rounded))
            Text(timeString(date))
                .font(.headline.monospacedDigit())
            Text(shortDate(date))
                .font(.caption)
                .foregroundStyle(.black.opacity(0.55))
        }
    }

    private func ticketFact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.black.opacity(0.48))
            Text(value)
                .font(.caption.weight(.bold))
                .lineLimit(1)
        }
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

    private var statusLabel: String {
        let status = session.effectiveStatus.uppercased()
        switch status {
        case "NEW", "AVAILABILITY_CHECK":
            return tr("Availability is being confirmed", "Наличие подтверждается", "Mavjudlik tasdiqlanmoqda", "Мавжудлик тасдиқланмоқда")
        case "PAYMENT_PENDING":
            return tr("Availability confirmed", "Наличие подтверждено", "Mavjudlik tasdiqlandi", "Мавжудлик тасдиқланди")
        case "PAID", "BOOKING_CONFIRMED", "DOCUMENTS_READY", "READY_TO_TRAVEL", "IN_TRIP", "COMPLETED":
            return tr("Booking confirmed", "Бронирование подтверждено", "Bron tasdiqlandi", "Брон тасдиқланди")
        default:
            return L10n.status(session.effectiveStatus, language)
        }
    }

    private var hotelCardsVisible: Bool {
        switch session.effectiveStatus.uppercased() {
        case "PAID", "BOOKING_CONFIRMED", "DOCUMENTS_READY", "READY_TO_TRAVEL", "IN_TRIP", "COMPLETED":
            return true
        default:
            return false
        }
    }

    private func terminalText(_ flight: FlightOffer) -> String {
        let departure = nonBlank(flight.segments?.first?.origin.terminal)
        let arrival = nonBlank(flight.segments?.last?.destination.terminal)
        switch (departure, arrival) {
        case let (d?, a?) where d != a:
            return "\(d) → \(a)"
        case let (d?, _):
            return d
        case let (_, a?):
            return a
        default:
            return "—"
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

    private func dateString(_ raw: String) -> String {
        L10n.date(raw, language)
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


private func nonBlank(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
