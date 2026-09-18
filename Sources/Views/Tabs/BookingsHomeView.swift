import Foundation
import SwiftUI

struct BookingsHomeView: View {
    private enum BookingPanel: String, CaseIterable, Identifiable {
        case booking
        case status
        var id: String { rawValue }
    }

    private enum BookingScope: String, CaseIterable, Identifiable {
        case active
        case past

        var id: String { rawValue }
    }
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var account: IumrahAccountStore

    @State private var pendingDeleteID: String?
    @State private var deleteError: String?
    @State private var showZiyarats = false
    @State private var showCareRequestBuilder = false
    @State private var bookingScope: BookingScope = .active
    @State private var bookingPanel: BookingPanel = .booking
    @State private var activeCheckout: IumrahCheckoutResponse?

    private let accountService = IumrahAccountService()

    private var activeSessions: [StoredBookingSession] {
        bookings.sessions.filter { session in
            !["COMPLETED", "CANCELLED"].contains(session.effectiveStatus.uppercased())
        }
    }

    private var pastSessions: [StoredBookingSession] {
        bookings.sessions.filter { session in
            ["COMPLETED", "CANCELLED"].contains(session.effectiveStatus.uppercased())
        }
    }

    private var activeSession: StoredBookingSession? {
        activeSessions.first
    }

    var body: some View {
        Group {
            switch bookingScope {
            case .active:
                if let activeSession {
                    activeBookingHub(activeSession)
                } else {
                    emptyBookingHome
                }
            case .past:
                pastBookingsHome
            }
        }
        .refreshable {
            await bookings.refreshAll()
            await loadActiveCheckout()
        }
        .task {
            await bookings.refreshAll()
            await loadActiveCheckout()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await bookings.refreshAll()
                await loadActiveCheckout()
            }
        }
        .confirmationDialog(
            L10n.text("booking_delete_confirm_title", settings.language),
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.text("booking_delete_confirm_action", settings.language), role: .destructive) {
                guard let id = pendingDeleteID else { return }
                pendingDeleteID = nil
                Task { await deleteBooking(id) }
            }
            Button(L10n.text("cancel", settings.language), role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text(L10n.text("booking_delete_confirm_body", settings.language))
        }
        .navigationDestination(isPresented: $chrome.shouldStartTripBuilder) {
            TripBuilderView()
        }
        .navigationDestination(isPresented: Binding(
            get: { chrome.requestedBookingID != nil },
            set: { if !$0 { chrome.requestedBookingID = nil } }
        )) {
            if let bookingID = chrome.requestedBookingID, bookings.booking(id: bookingID) != nil {
                BookingDetailView(bookingID: bookingID)
            } else {
                EmptyView()
            }
        }
        .fullScreenCover(isPresented: $showZiyarats) {
            ZiyaratJourneyView()
                .environmentObject(settings)
                .environmentObject(chrome)
        }
        .navigationDestination(isPresented: $showCareRequestBuilder) {
            IumrahCareRequestView()
        }
    }

    // MARK: - Active booking

    private func activeBookingHub(_ session: StoredBookingSession) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                IumrahRootPageTitle(
                    title: L10n.text("tab_booking", settings.language),
                    showsMakkahTime: true,
                    usesBrandLogo: true
                )
                .padding(.bottom, 18)

                bookingPanelPicker
                    .padding(.bottom, 12)

                bookingScopePicker
                    .padding(.bottom, 24)

                bookingIdentity(session)
                    .padding(.bottom, 28)

                if bookingPanel == .booking {
                    bookingTimerOverview(session)
                        .padding(.bottom, 28)

                    bookingActionCenter(session, checkout: activeCheckout)
                        .padding(.bottom, 34)

                    tripPlanPreview(session)
                        .padding(.bottom, 34)

                    tripManagement(session)
                        .padding(.bottom, activeSessions.count > 1 ? 36 : 12)
                } else {
                    bookingProgress(session)
                        .padding(.bottom, 30)

                    bookingStatusWorkspace(session)
                        .padding(.bottom, 38)
                }

                if activeSessions.count > 1 {
                    otherTrips(excluding: session.id)
                        .padding(.bottom, 12)
                }

                if let deleteError {
                    Text(deleteError)
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .systemRed))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(uiColor: .systemRed).opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .animation(.snappy(duration: 0.34), value: session.effectiveStatus)
    }

    /// The top deliberately avoids another large card. Like the reference flow,
    /// hierarchy comes from whitespace and typography before the process begins.
    private func bookingIdentity(_ session: StoredBookingSession) -> some View {
        VStack(spacing: 17) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.iumrahRaisedBackground)
                    .frame(width: 94, height: 94)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.065), lineWidth: 0.7)
                    }

                Image(systemName: "suitcase.fill")
                    .font(.system(size: 34, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(activeEyebrow)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-0.9)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.76)
                    .lineLimit(1)

                Text("\(L10n.date(session.booking.input.startDate, settings.language)) – \(L10n.date(session.booking.input.endDate, settings.language))")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                identityPill(L10n.format("booking_number_short", settings.language, session.displayBookingNumber))
                identityPill(pilgrimCountText(session.booking.input.travelers.totalPeople), systemName: "person.2.fill")
            }

            if let name = session.travelerName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func identityPill(_ text: String, systemName: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11)
        .frame(height: 31)
        .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private var bookingPanelPicker: some View {
        Picker(localized("Раздел бронирования", "Booking section", "Bron bo‘limi", "Брон бўлими"), selection: $bookingPanel) {
            Text(localized("Бронирование", "Booking", "Bron", "Брон")).tag(BookingPanel.booking)
            Text(localized("Статус бронирования", "Booking status", "Bron holati", "Брон ҳолати")).tag(BookingPanel.status)
        }
        .pickerStyle(.segmented)
        .onChange(of: bookingPanel) { _, _ in IumrahHaptics.selection() }
    }

    @ViewBuilder
    private func bookingTimerOverview(_ session: StoredBookingSession) -> some View {
        if lifecyclePhase(for: session) != nil {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(IumrahBookingStatusVisual.color(for: session.effectiveStatus).opacity(0.12))
                            .frame(width: 48, height: 48)
                        if ["AVAILABILITY_CHECK", "PAYMENT_PENDING", "BOOKING_CONFIRMED"].contains(session.effectiveStatus.uppercased()) {
                            ProgressView()
                                .tint(IumrahBookingStatusVisual.color(for: session.effectiveStatus))
                        } else {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(IumrahBookingStatusVisual.color(for: session.effectiveStatus))
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(localized("Работа идёт", "Work is in progress", "Jarayon davom etmoqda", "Жараён давом этмоқда"))
                            .font(.headline)
                        Text(localized("Вы можете закрыть приложение — статус обновится автоматически.", "You can close the app — the status will update automatically.", "Ilovani yopishingiz mumkin — holat avtomatik yangilanadi.", "Иловани ёпишингиз мумкин — ҳолат автоматик янгиланади."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                lifecycleTimerPanel(session, tint: IumrahBookingStatusVisual.color(for: session.effectiveStatus))
            }
            .padding(18)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7) }
        }
    }

    private func bookingActionCenter(_ session: StoredBookingSession, checkout: IumrahCheckoutResponse?) -> some View {
        let completed = checkout?.travelers.filter(\.completed).count ?? 0
        let total = checkout?.travelers.count ?? session.booking.input.travelers.totalPeople
        let receiptReady = !(checkout?.receipts.isEmpty ?? true)
        let documentCount = checkout?.documents.count ?? 0

        return VStack(alignment: .leading, spacing: 15) {
            sectionHeader(title: localized("Что нужно сделать", "What to do next", "Keyingi qadamlar", "Кейинги қадамлар"), trailing: nil)
            Text(localized("Открывайте карточки по порядку. Все введённые данные сохраняются в бронировании.", "Open the cards in order. Everything you enter is saved with the booking.", "Kartalarni ketma-ket oching. Kiritilgan ma’lumotlar bronda saqlanadi.", "Карталарни кетма-кет очинг. Киритилган маълумотлар бронда сақланади."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink { IumrahSecurityConfirmationView(bookingID: session.id) } label: {
                bookingActionCard(
                    icon: "person.text.rectangle.fill",
                    role: .security,
                    title: "KYC · iumrah Security",
                    body: localized("Подтвердите личность владельца бронирования.", "Confirm the booking holder’s identity.", "Bron egasining shaxsini tasdiqlang.", "Брон эгасининг шахсини тасдиқланг."),
                    action: localized("Проверить личность", "Confirm identity", "Shaxsni tasdiqlash", "Шахсни тасдиқлаш"),
                    ready: false
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappy(duration: 0.28)) { bookingPanel = .status }
                IumrahHaptics.selection()
            } label: {
                bookingActionCard(
                    icon: "person.2.fill",
                    role: .profile,
                    title: localized("Кто едет с Вами", "Who is traveling with you", "Siz bilan kim bormoqda", "Сиз билан ким бормоқда"),
                    body: localized("Заполнено анкет: \(completed) из \(total). Можно заполнить заранее во время проверки наличия.", "Forms completed: \(completed) of \(total). You can fill them in while availability is checked.", "To‘ldirilgan anketalar: \(completed)/\(total). Mavjudlik tekshirilayotganda oldindan to‘ldirish mumkin.", "Тўлдирилган анкеталар: \(completed)/\(total). Мавжудлик текширилаётганда олдиндан тўлдириш мумкин."),
                    action: completed == total && total > 0 ? localized("Проверить анкеты", "Review forms", "Anketalarni tekshirish", "Анкеталарни текшириш") : localized("Заполнить анкеты", "Complete forms", "Anketalarni to‘ldirish", "Анкеталарни тўлдириш"),
                    ready: completed == total && total > 0
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappy(duration: 0.28)) { bookingPanel = .status }
                IumrahHaptics.selection()
            } label: {
                bookingActionCard(
                    icon: "creditcard.fill",
                    role: .payment,
                    title: localized("Оплата", "Payment", "To‘lov", "Тўлов"),
                    body: session.effectiveStatus.uppercased() == "AVAILABILITY_CHECK"
                        ? localized("Пока ничего оплачивать не нужно. Оплата откроется после подтверждения наличия.", "No payment is needed yet. It will open after availability is confirmed.", "Hozircha to‘lov kerak emas. Mavjudlik tasdiqlangach ochiladi.", "Ҳозирча тўлов керак эмас. Мавжудлик тасдиқлангач очилади.")
                        : (receiptReady ? localized("Чек получен и сохранён в бронировании.", "The receipt is received and saved with the booking.", "Chek qabul qilindi va bronda saqlandi.", "Чек қабул қилинди ва бронда сақланди.") : localized("Оплатите по реквизитам и прикрепите чек.", "Pay using the provided details and attach the receipt.", "Rekvizitlar bo‘yicha to‘lang va chekni biriktiring.", "Реквизитлар бўйича тўланг ва чекни бириктиринг.")),
                    action: receiptReady ? localized("Открыть чек", "Open receipt", "Chekni ochish", "Чекни очиш") : localized("Перейти к оплате", "Go to payment", "To‘lovga o‘tish", "Тўловга ўтиш"),
                    ready: receiptReady
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappy(duration: 0.28)) { bookingPanel = .status }
                IumrahHaptics.selection()
            } label: {
                bookingActionCard(
                    icon: "doc.on.doc.fill",
                    role: .document,
                    title: localized("Документы поездки", "Travel documents", "Safar hujjatlari", "Сафар ҳужжатлари"),
                    body: documentCount > 0 ? localized("Готово документов: \(documentCount). Каждый файл доступен отдельно.", "Documents ready: \(documentCount). Each file is available separately.", "Tayyor hujjatlar: \(documentCount). Har biri alohida ochiladi.", "Тайёр ҳужжатлар: \(documentCount). Ҳар бири алоҳида очилади.") : localized("После оплаты здесь появятся авиабилет, отель и остальные готовые документы.", "After payment, your ticket, hotel confirmation and other documents will appear here.", "To‘lovdan keyin aviachipta, mehmonxona tasdig‘i va boshqa hujjatlar shu yerda chiqadi.", "Тўловдан кейин авиачипта, меҳмонхона тасдиғи ва бошқа ҳужжатлар шу ерда чиқади."),
                    action: localized("Посмотреть документы", "View documents", "Hujjatlarni ko‘rish", "Ҳужжатларни кўриш"),
                    ready: documentCount > 0
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func bookingActionCard(icon: String, role: IumrahIconRole, title: String, body: String, action: String, ready: Bool) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 13) {
                IumrahIconBadge(systemName: ready ? "checkmark.circle.fill" : icon, role: ready ? .success : role, size: 54, symbolSize: 21, cornerRadius: 18)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.primary)
                    Text(body).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Text(action)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.iumrahPrimaryButtonText)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .padding(17)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7) }
    }

    // MARK: - Booking progress

    private func bookingProgress(_ session: StoredBookingSession) -> some View {
        let stages = progressStages
        let current = progressIndex(for: session.effectiveStatus)
        let isCancelled = session.effectiveStatus.uppercased() == "CANCELLED"

        return VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: statusTitle,
                trailing: isCancelled ? cancelledText : progressCounter(current: current, total: stages.count)
            )

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    processStep(
                        stage,
                        index: index,
                        current: current,
                        isLast: index == stages.count - 1,
                        session: session,
                        isCancelled: isCancelled
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func bookingStatusWorkspace(_ session: StoredBookingSession) -> some View {
        if session.effectiveStatus.uppercased() != "CANCELLED" {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader(
                    title: localized("Данные бронирования", "Booking details", "Bron ma’lumotlari", "Брон маълумотлари"),
                    trailing: nil
                )

                PilgrimCheckoutView(bookingID: session.id, presentation: .bookingStatus)

                if shouldShowTravelReadyFlights(session) {
                    bookingStatusFlights(session)
                }
            }
        }
    }

    private func shouldShowTravelReadyFlights(_ session: StoredBookingSession) -> Bool {
        ["READY_TO_TRAVEL", "IN_TRIP"].contains(session.effectiveStatus.uppercased())
    }

    private func bookingStatusFlights(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                IumrahIconBadge(systemName: "airplane", role: .travel, size: 46, symbolSize: 19, cornerRadius: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("Ваши авиабилеты", "Your flights", "Aviachiptalaringiz", "Авиачипталарингиз"))
                        .font(.headline)
                    Text(localized("Полные данные рейсов закреплены в статусе поездки.", "Full flight details stay attached to your trip status.", "Parvozning to‘liq ma’lumotlari safar holatida saqlanadi.", "Парвознинг тўлиқ маълумотлари сафар ҳолатида сақланади."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let outbound = session.outboundFlight {
                bookingStatusFlightCard(outbound, label: localized("Туда", "Outbound", "Borish", "Бориш"))
            } else {
                bookingStatusLegacyFlightCard(
                    title: localized("Туда", "Outbound", "Borish", "Бориш"),
                    route: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)",
                    date: session.booking.input.startDate,
                    value: session.booking.flight
                )
            }

            if let inbound = session.inboundFlight {
                bookingStatusFlightCard(inbound, label: localized("Обратно", "Return", "Qaytish", "Қайтиш"))
            } else {
                bookingStatusLegacyFlightCard(
                    title: localized("Обратно", "Return", "Qaytish", "Қайтиш"),
                    route: "\(session.booking.route.returnOrigin) → \(session.booking.route.originCode)",
                    date: session.booking.input.endDate,
                    value: session.booking.flight
                )
            }

            NavigationLink {
                IumrahFlightsView(preferredBookingID: session.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "location.wave.radiowaves.left.and.right")
                    Text(localized("Отслеживать рейс", "Track flight", "Reysni kuzatish", "Рейсни кузатиш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.iumrahPrimaryButtonText)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(17)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private func bookingStatusFlightCard(_ offer: FlightOffer, label: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                AirlineLogoView(airlineCode: offer.primaryAirlineCode, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(label.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text(offer.flightNumbersSummary.isEmpty ? offer.flightNumber : offer.flightNumbersSummary)
                        .font(.headline.monospaced())
                    Text(offer.airlinesSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(offer.stops == 0 ? localized("Прямой", "Direct", "To‘g‘ridan", "Тўғридан") : localized("С пересадкой", "Connection", "Ulanish", "Уланиш"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(offer.displaySegments.enumerated()), id: \.element.id) { index, segment in
                if index > 0 { Divider() }
                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(segment.flightNumber)
                            .font(.caption.monospaced().weight(.bold))
                        if let operatingCarrier = nonBlankFlightValue(segment.operatingCarrier), operatingCarrier != segment.airline {
                            Text(operatingCarrier)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if let aircraft = nonBlankFlightValue(segment.aircraft) {
                            Text(aircraft)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(segment.origin.code)
                                .font(.title3.weight(.bold))
                            Text(segment.origin.displayCity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(segment.origin.displayAirport)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "airplane")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(segment.destination.code)
                                .font(.title3.weight(.bold))
                            Text(segment.destination.displayCity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(segment.destination.displayAirport)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(statusFlightTime(segment.departureAt, zone: segment.origin.timeZoneIdentifier))
                            Text(statusFlightDate(segment.departureAt, zone: segment.origin.timeZoneIdentifier))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(statusFlightDuration(segment.durationMinutes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(statusFlightTime(segment.arrivalAt, zone: segment.destination.timeZoneIdentifier))
                            Text(statusFlightDate(segment.arrivalAt, zone: segment.destination.timeZoneIdentifier))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline.monospacedDigit().weight(.semibold))

                    HStack(spacing: 8) {
                        if let terminal = nonBlankFlightValue(segment.origin.terminal) {
                            flightMetaPill(localized("Вылет", "Dep", "Uchish", "Учиш") + " T\(terminal)")
                        }
                        if let terminal = nonBlankFlightValue(segment.destination.terminal) {
                            flightMetaPill(localized("Прилёт", "Arr", "Qo‘nish", "Қўниш") + " T\(terminal)")
                        }
                        if let cabin = nonBlankFlightValue(segment.cabin) {
                            flightMetaPill(cabin)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if let carry = offer.baggage?.carryOn { flightMetaPill(localized("Ручная", "Carry-on", "Qo‘l yuki", "Қўл юки") + " \(carry) kg") }
                if let checked = offer.baggage?.checked { flightMetaPill(localized("Багаж", "Checked", "Bagaj", "Багаж") + " \(checked) kg") }
            }
        }
        .padding(14)
        .background(Color.iumrahRaisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private func bookingStatusLegacyFlightCard(title: String, route: String, date: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(route)
                .font(.headline)
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(L10n.date(date, settings.language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.iumrahRaisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private func flightMetaPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color.primary.opacity(0.045), in: Capsule())
    }

    private func statusFlightDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }

    private func nonBlankFlightValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func statusFlightTime(_ date: Date, zone: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let zone, let timeZone = TimeZone(identifier: zone) { formatter.timeZone = timeZone }
        return formatter.string(from: date)
    }

    private func statusFlightDate(_ date: Date, zone: String?) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        if let zone, let timeZone = TimeZone(identifier: zone) { formatter.timeZone = timeZone }
        return formatter.string(from: date)
    }

    private func processStep(
        _ stage: BookingProgressStage,
        index: Int,
        current: Int,
        isLast: Bool,
        session: StoredBookingSession,
        isCancelled: Bool
    ) -> some View {
        let completed = isCancelled ? index == 0 : index < current
        let active = index == current
        let future = index > current
        let effectiveStage = isCancelled && active ? cancelledStage : stage
        let nodeColor = active
            ? IumrahBookingStatusVisual.color(for: session.effectiveStatus)
            : (completed ? Color(uiColor: .systemGreen) : Color(uiColor: .secondaryLabel).opacity(0.62))
        let lineColor = completed
            ? Color(uiColor: .systemGreen).opacity(0.36)
            : Color.primary.opacity(0.12)

        return HStack(alignment: .top, spacing: 17) {
            ZStack {
                Circle()
                    .fill(completed || active ? nodeColor : Color.iumrahPageBackground)
                    .frame(width: 25, height: 25)
                    .overlay {
                        if future {
                            Circle()
                                .strokeBorder(Color(uiColor: .secondaryLabel).opacity(0.52), lineWidth: 1.6)
                        }
                    }

                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else if active {
                    Circle()
                        .fill(activeNodeForeground(for: session.effectiveStatus))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 26, height: 25, alignment: .top)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(effectiveStage.title)
                        .font(.system(size: active ? 18 : 17, weight: active ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(future ? Color(uiColor: .secondaryLabel) : Color.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let date = statusDateText(for: index, current: current, session: session, isCancelled: isCancelled) {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if active {
                        Text(activeStageSubtitle(session, fallback: effectiveStage.activeSubtitle))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if active {
                    activeStageCard(session, stage: effectiveStage)
                        .padding(.top, 4)
                        .padding(.bottom, 18)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isLast ? 0 : 13)
        }
        .overlay(alignment: .topLeading) {
            if !isLast {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 1)
                    .padding(.top, 25)
                    .offset(x: 12.5)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func activeStageCard(_ session: StoredBookingSession, stage: BookingProgressStage) -> some View {
        let tint = IumrahBookingStatusVisual.color(for: session.effectiveStatus)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint)
                        .frame(width: 34, height: 34)
                    if session.effectiveStatus.uppercased() == "AVAILABILITY_CHECK" {
                        Image(systemName: "hourglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(activeNodeForeground(for: session.effectiveStatus))
                            .symbolEffect(.pulse, options: .repeating)
                    } else {
                        Image(systemName: IumrahBookingStatusVisual.symbol(for: session.effectiveStatus))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(activeNodeForeground(for: session.effectiveStatus))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(activeCardTitle(session, fallback: stage.cardTitle))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .tracking(-0.25)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(activeCardBody(session, fallback: stage.cardBody))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            lifecycleTimerPanel(session, tint: tint)

            Divider()
                .overlay(Color.primary.opacity(0.05))

            VStack(spacing: 13) {
                progressFact(title: routeTitle, value: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                progressFact(title: dateTitle, value: "\(L10n.date(session.booking.input.startDate, settings.language)) – \(L10n.date(session.booking.input.endDate, settings.language))")
                if !session.booking.hotelNames.makkah.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    progressFact(title: hotelTitle, value: session.booking.hotelNames.makkah)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(priceTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PackagePriceView(amount: Decimal(session.booking.perPilgrimUsd), currency: "USD", showsPerPerson: false)
                }

                Spacer(minLength: 12)

                Text(pilgrimCountText(session.booking.input.travelers.totalPeople))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.iumrahCardBackground)
                .overlay {
                    LinearGradient(
                        colors: [tint.opacity(0.13), tint.opacity(0.025), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 0.8)
        }
    }

    @ViewBuilder
    private func lifecycleTimerPanel(_ session: StoredBookingSession, tint: Color) -> some View {
        if let phase = lifecyclePhase(for: session), let deadline = phase.deadline {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, deadline.timeIntervalSince(context.date))
                let expired = remaining <= 0

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(lifecycleTimerTitle(phase, expired: expired))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(lifecycleCountdown(remaining))
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .tracking(-0.7)
                                .contentTransition(.numericText())
                        }
                        Spacer(minLength: 12)
                        Image(systemName: phase.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(tint)
                            .frame(width: 38, height: 38)
                            .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }

                    Text(lifecycleTimerFootnote(phase, expired: expired))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func lifecyclePhase(for session: StoredBookingSession) -> BookingLifecyclePhase? {
        switch session.effectiveStatus.uppercased() {
        case "NEW", "AVAILABILITY_CHECK":
            let deadline = lifecycleDeadline(
                explicit: session.availabilityDeadlineAt,
                start: session.availabilityStartedAt ?? session.booking.createdAt,
                duration: 6 * 60 * 60
            )
            return .availability(deadline)
        case "PAYMENT_PENDING":
            if session.paymentReceivedAt != nil {
                let deadline = lifecycleDeadline(
                    explicit: session.paymentConfirmationDeadlineAt,
                    start: session.paymentReceivedAt,
                    duration: 10 * 60
                )
                return .paymentConfirmation(deadline)
            }
            let deadline = lifecycleDeadline(
                explicit: session.priceLockExpiresAt,
                start: session.priceLockStartedAt ?? transitionDate("payment_pending", session: session) ?? session.booking.updatedAt,
                duration: 30 * 60
            )
            return .priceLock(deadline)
        case "PAID", "BOOKING_CONFIRMED":
            let deadline = lifecycleDeadline(
                explicit: session.documentsDeadlineAt,
                start: session.documentsStartedAt ?? transitionDate("booking_confirmed", session: session) ?? session.booking.updatedAt,
                duration: 24 * 60 * 60
            )
            return .documents(deadline)
        default:
            return nil
        }
    }

    private func lifecycleDeadline(explicit: String?, start: String?, duration: TimeInterval) -> Date? {
        if let explicit, let value = Self.isoDate(explicit) { return value }
        guard let start, let value = Self.isoDate(start) else { return nil }
        return value.addingTimeInterval(duration)
    }

    private func lifecycleCountdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func lifecycleTimerTitle(_ phase: BookingLifecyclePhase, expired: Bool) -> String {
        switch phase {
        case .availability:
            return expired
                ? localized("Проверка занимает дольше обычного", "The check is taking longer than usual", "Tekshiruv odatdagidan uzoqroq davom etmoqda", "Текширув одатдагидан узоқроқ давом этмоқда")
                : localized("До максимального срока проверки", "Until the maximum check time", "Tekshiruvning maksimal muddatigacha", "Текширувнинг максимал муддатигача")
        case .priceLock:
            return expired
                ? localized("Срок фиксации цены завершён", "Price hold has ended", "Narxni saqlash muddati tugadi", "Нархни сақлаш муддати тугади")
                : localized("Цена зафиксирована ещё", "Price held for", "Narx yana shuncha vaqtga saqlanadi", "Нарх яна шунча вақтга сақланади")
        case .paymentConfirmation:
            return expired
                ? localized("Подтверждение занимает дольше обычного", "Confirmation is taking longer than usual", "Tasdiqlash odatdagidan uzoqroq davom etmoqda", "Тасдиқлаш одатдагидан узоқроқ давом этмоқда")
                : localized("Подтверждаем оплату", "Confirming payment", "To‘lov tasdiqlanmoqda", "Тўлов тасдиқланмоқда")
        case .documents:
            return expired
                ? localized("Подготовка занимает дольше обычного", "Preparation is taking longer than usual", "Tayyorlash odatdagidan uzoqroq davom etmoqda", "Тайёрлаш одатдагидан узоқроқ давом этмоқда")
                : localized("Плановый срок подготовки", "Planned preparation time", "Rejalashtirilgan tayyorlash muddati", "Режалаштирилган тайёрлаш муддати")
        }
    }

    private func lifecycleTimerFootnote(_ phase: BookingLifecyclePhase, expired: Bool) -> String {
        switch phase {
        case .availability:
            return expired
                ? localized("Мы продолжаем проверку. Статус обновится автоматически, как только все компоненты будут подтверждены.", "We are continuing the check. The status will update automatically once all components are confirmed.", "Tekshiruv davom etmoqda. Barcha qismlar tasdiqlangach holat avtomatik yangilanadi.", "Текширув давом этмоқда. Барча қисмлар тасдиқлангач ҳолат автоматик янгиланади.")
                : localized("Обычно подтверждение занимает 1–2 часа. Можно закрыть приложение — статус обновится автоматически.", "Confirmation usually takes 1–2 hours. You can close the app — the status will update automatically.", "Tasdiqlash odatda 1–2 soat davom etadi. Ilovani yopishingiz mumkin — holat avtomatik yangilanadi.", "Тасдиқлаш одатда 1–2 соат давом этади. Иловани ёпишингиз мумкин — ҳолат автоматик янгиланади.")
        case .priceLock:
            return expired
                ? localized("Перед подтверждением оплаты iumrah повторно проверит актуальную итоговую стоимость.", "Before confirming payment, iumrah will recheck the current total price.", "To‘lovni tasdiqlashdan oldin iumrah yakuniy narxning dolzarbligini qayta tekshiradi.", "Тўловни тасдиқлашдан олдин iumrah якуний нархнинг долзарблигини қайта текширади.")
                : localized("Авиабилеты и некоторые другие компоненты имеют динамическую стоимость и после окончания периода могут потребовать повторной проверки.", "Flights and some other components have dynamic pricing and may require a fresh check after this period.", "Aviachiptalar va ayrim boshqa qismlar dinamik narxga ega, muddat tugagach qayta tekshiruv talab qilinishi mumkin.", "Авиачипталар ва айрим бошқа қисмлар динамик нархга эга, муддат тугагач қайта текширув талаб қилиниши мумкин.")
        case .paymentConfirmation:
            return localized("Оплата получена. Обычно проверка и окончательная фиксация бронирования занимают до 10 минут.", "Payment received. Verification and final booking confirmation usually take up to 10 minutes.", "To‘lov qabul qilindi. Tekshiruv va bronni yakuniy tasdiqlash odatda 10 daqiqagacha davom etadi.", "Тўлов қабул қилинди. Текширув ва бронни якуний тасдиқлаш одатда 10 дақиқагача давом этади.")
        case .documents:
            return localized("Обычно доступные документы готовятся в течение 24 часов. Срок визы может зависеть от доступности официальных визовых систем Саудовской Аравии и внешних ограничений.", "Available travel documents are usually prepared within 24 hours. Visa timing can depend on the availability of Saudi Arabia’s official visa systems and external restrictions.", "Mavjud safar hujjatlari odatda 24 soat ichida tayyorlanadi. Viza muddati Saudiya Arabistonining rasmiy viza tizimlari mavjudligi va tashqi cheklovlarga bog‘liq bo‘lishi mumkin.", "Мавжуд сафар ҳужжатлари одатда 24 соат ичида тайёрланади. Виза муддати Саудия Арабистонининг расмий виза тизимлари мавжудлиги ва ташқи чекловларга боғлиқ бўлиши мумкин.")
        }
    }

    private func activeStageSubtitle(_ session: StoredBookingSession, fallback: String) -> String {
        switch lifecyclePhase(for: session) {
        case .paymentConfirmation:
            return localized("Оплата получена · подтверждаем бронирование", "Payment received · confirming booking", "To‘lov qabul qilindi · bron tasdiqlanmoqda", "Тўлов қабул қилинди · брон тасдиқланмоқда")
        case .documents:
            return localized("Бронирование подтверждено · готовим документы", "Booking confirmed · preparing documents", "Bron tasdiqlandi · hujjatlar tayyorlanmoqda", "Брон тасдиқланди · ҳужжатлар тайёрланмоқда")
        default:
            return fallback
        }
    }

    private func activeCardTitle(_ session: StoredBookingSession, fallback: String) -> String {
        switch lifecyclePhase(for: session) {
        case .priceLock: return localized("Цена зафиксирована", "Price held", "Narx saqlandi", "Нарх сақланди")
        case .paymentConfirmation: return localized("Оплата получена", "Payment received", "To‘lov qabul qilindi", "Тўлов қабул қилинди")
        case .documents: return localized("Подготавливаем документы", "Preparing documents", "Hujjatlar tayyorlanmoqda", "Ҳужжатлар тайёрланмоқда")
        default: return fallback
        }
    }

    private func activeCardBody(_ session: StoredBookingSession, fallback: String) -> String {
        switch lifecyclePhase(for: session) {
        case .availability:
            return localized("iumrah подтверждает перелёт, отель и выбранные услуги. Обычно это занимает 1–2 часа, максимальный срок — до 6 часов.", "iumrah is confirming your flight, hotel and selected services. This usually takes 1–2 hours, with a maximum target of 6 hours.", "iumrah parvoz, mehmonxona va tanlangan xizmatlarni tasdiqlamoqda. Odatda 1–2 soat, maksimal muddat 6 soatgacha.", "iumrah парвоз, меҳмонхона ва танланган хизматларни тасдиқламоқда. Одатда 1–2 соат, максимал муддат 6 соатгача.")
        case .priceLock:
            return localized("Итоговая цена пакета зафиксирована на время оплаты.", "Your package total is held during the payment window.", "Paketning yakuniy narxi to‘lov oynasi davomida saqlanadi.", "Пакетнинг якуний нархи тўлов ойнаси давомида сақланади.")
        case .paymentConfirmation:
            return localized("Проверяем полученную оплату и окончательно фиксируем бронирование.", "We are verifying the payment and finalizing your booking.", "Qabul qilingan to‘lov tekshirilmoqda va bron yakuniy tasdiqlanmoqda.", "Қабул қилинган тўлов текширилмоқда ва брон якуний тасдиқланмоқда.")
        case .documents:
            return localized("Бронирование подтверждено. Теперь готовим доступные документы поездки.", "Your booking is confirmed. We are now preparing the available travel documents.", "Bron tasdiqlandi. Endi mavjud safar hujjatlari tayyorlanmoqda.", "Брон тасдиқланди. Энди мавжуд сафар ҳужжатлари тайёрланмоқда.")
        case nil:
            return fallback
        }
    }

    private func progressFact(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cancelledStage: BookingProgressStage {
        BookingProgressStage(
            title: localized("Бронирование отменено", "Booking cancelled", "Bron bekor qilindi", "Брон бекор қилинди"),
            activeSubtitle: localized("Поездка остановлена", "The trip has been stopped", "Safar to‘xtatildi", "Сафар тўхтатилди"),
            cardTitle: localized("Бронирование отменено", "Booking cancelled", "Bron bekor qilindi", "Брон бекор қилинди"),
            cardBody: localized("Откройте бронирование, чтобы посмотреть сохранённые детали поездки и доступные действия.", "Open the booking to review the saved trip details and available actions.", "Saqlangan safar tafsilotlari va mavjud amallarni ko‘rish uchun bronni oching.", "Сақланган сафар тафсилотлари ва мавжуд амалларни кўриш учун бронни очинг.")
        )
    }

    private var progressStages: [BookingProgressStage] {
        [
            BookingProgressStage(
                title: createdTitle,
                activeSubtitle: createdSubtitle,
                cardTitle: createdTitle,
                cardBody: createdSubtitle
            ),
            BookingProgressStage(
                title: availabilityTitle,
                activeSubtitle: availabilitySubtitle,
                cardTitle: availabilityCardTitle,
                cardBody: availabilityCardBody
            ),
            BookingProgressStage(
                title: paymentStageTitle,
                activeSubtitle: paymentStageSubtitle,
                cardTitle: paymentCardTitle,
                cardBody: paymentCardBody
            ),
            BookingProgressStage(
                title: confirmedStageTitle,
                activeSubtitle: confirmedStageSubtitle,
                cardTitle: confirmedCardTitle,
                cardBody: confirmedCardBody
            ),
            BookingProgressStage(
                title: documentsStageTitle,
                activeSubtitle: documentsStageSubtitle,
                cardTitle: documentsCardTitle,
                cardBody: documentsCardBody
            ),
            BookingProgressStage(
                title: inTripStageTitle,
                activeSubtitle: inTripStageSubtitle,
                cardTitle: inTripCardTitle,
                cardBody: inTripCardBody
            ),
            BookingProgressStage(
                title: completedStageTitle,
                activeSubtitle: completedStageSubtitle,
                cardTitle: completedCardTitle,
                cardBody: completedCardBody
            )
        ]
    }

    private func progressIndex(for status: String) -> Int {
        switch status.uppercased() {
        case "NEW", "AVAILABILITY_CHECK": return 1
        case "PAYMENT_PENDING": return 2
        case "PAID", "BOOKING_CONFIRMED": return 3
        case "DOCUMENTS_READY", "READY_TO_TRAVEL": return 4
        case "IN_TRIP": return 5
        case "COMPLETED": return 6
        case "CANCELLED": return 1
        default: return 1
        }
    }

    private func progressCounter(current: Int, total: Int) -> String {
        localized("\(current + 1) из \(total)", "\(current + 1) of \(total)", "\(current + 1) / \(total)", "\(current + 1) / \(total)")
    }

    private func activeNodeForeground(for status: String) -> Color {
        switch IumrahBookingStatusVisual.role(for: status) {
        case .waiting, .warning, .rating:
            return Color.black.opacity(0.78)
        default:
            return .white
        }
    }

    // MARK: - Trip plan preview

    private func tripPlanPreview(_ session: StoredBookingSession) -> some View {
        let items = previewItineraryItems(session)

        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: tripPlanTitle, trailing: nil)

            VStack(spacing: 0) {
                if items.isEmpty {
                    Text(tripPlanEmptyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                        .padding(.horizontal, 17)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        tripPlanRow(item)
                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }

                Divider()
                    .padding(.leading, 17)

                NavigationLink {
                    BookingDetailView(bookingID: session.id)
                } label: {
                    HStack {
                        Text(openFullPlanTitle)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 17)
                    .frame(height: 54)
                }
                .buttonStyle(.plain)
            }
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
        }
    }

    private func tripPlanRow(_ item: BookingItineraryItem) -> some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.iumrahRaisedBackground)
                    .frame(width: 39, height: 39)
                Image(systemName: safeIcon(item.icon))
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(compactDate(item.dateLocal))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)
                }

                if !item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.location)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
    }

    private func previewItineraryItems(_ session: StoredBookingSession) -> [BookingItineraryItem] {
        let remote = bookings.itineraries[session.id] ?? []
        let source: [BookingItineraryItem]
        let distinctRemoteDays = Set(remote.map(\.dateLocal)).count
        if distinctRemoteDays >= 2 {
            source = remote.sorted { lhs, rhs in
                if lhs.dateLocal == rhs.dateLocal { return lhs.sortOrder < rhs.sortOrder }
                return lhs.dateLocal < rhs.dateLocal
            }
        } else {
            source = BookingItineraryPlanner.make(booking: session.booking, language: settings.language)
        }

        guard !source.isEmpty else { return [] }
        let today = Self.riyadhDayFormatter.string(from: Date())
        let upcoming = source.filter { $0.dateLocal >= today }
        if !upcoming.isEmpty { return Array(upcoming.prefix(3)) }
        return Array(source.suffix(3))
    }

    // MARK: - Management

    private func tripManagement(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: manageSectionTitle, trailing: nil)

            VStack(spacing: 0) {
                NavigationLink {
                    BookingDetailView(bookingID: session.id)
                } label: {
                    managementRow(icon: "slider.horizontal.3", title: manageTitle, subtitle: manageSubtitle)
                }
                .buttonStyle(.plain)

                managementDivider

                NavigationLink {
                    BookingChatView(bookingID: session.id)
                } label: {
                    managementRow(icon: "person.badge.plus", title: addPilgrimTitle, subtitle: addPilgrimSubtitle)
                }
                .buttonStyle(.plain)

                managementDivider

                Button {
                    showZiyarats = true
                } label: {
                    managementRow(icon: "map", title: ziyaratsBookingTitle, subtitle: ziyaratsBookingSubtitle)
                }
                .buttonStyle(.plain)

                managementDivider

                Button {
                    startNewTrip()
                } label: {
                    managementRow(icon: "plus", title: newUmrahTitle, subtitle: newUmrahSubtitle)
                }
                .buttonStyle(.plain)
            }
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
        }
    }

    private var managementDivider: some View {
        Divider().padding(.leading, 65)
    }

    private func managementRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.iumrahRaisedBackground)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    // MARK: - Other trips

    private func otherTrips(excluding bookingID: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: otherTripsTitle, trailing: nil)

            VStack(spacing: 10) {
                ForEach(activeSessions.filter { $0.id != bookingID }) { session in
                    NavigationLink {
                        BookingDetailView(bookingID: session.id)
                    } label: {
                        compactBookingCard(session)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeleteID = session.id
                        } label: {
                            Label(L10n.text("booking_delete", settings.language), systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func compactBookingCard(_ session: StoredBookingSession) -> some View {
        HStack(alignment: .center, spacing: 13) {
            Circle()
                .fill(IumrahBookingStatusVisual.color(for: session.effectiveStatus))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                        .font(.subheadline.weight(.bold))
                    Text(session.displayBookingNumber)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                Text(L10n.status(session.effectiveStatus, settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let name = session.travelerName, !name.isEmpty {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatPrice(session.booking.perPilgrimUsd))
                    .font(.subheadline.weight(.bold))
                Text(L10n.date(session.booking.input.startDate, settings.language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var bookingScopePicker: some View {
        Picker(bookingScopePickerTitle, selection: $bookingScope) {
            Text(activeScopeTitle).tag(BookingScope.active)
            Text(pastScopeTitle).tag(BookingScope.past)
        }
        .pickerStyle(.segmented)
        .onChange(of: bookingScope) { _, _ in
            IumrahHaptics.selection()
        }
    }

    private var pastBookingsHome: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                IumrahRootPageTitle(
                    title: L10n.text("tab_booking", settings.language),
                    showsMakkahTime: true
                )

                bookingScopePicker

                if pastSessions.isEmpty {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .fill(Color.primary.opacity(0.055))
                                .frame(width: 58, height: 58)
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 22, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.primary)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(noPastBookingsTitle)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Text(noPastBookingsBody)
                                .font(.system(size: 14.5, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(pastSessions) { session in
                            NavigationLink {
                                BookingDetailView(bookingID: session.id)
                            } label: {
                                compactBookingCard(session)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeleteID = session.id
                                } label: {
                                    Label(L10n.text("booking_delete", settings.language), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
    }

    private var explorePackagesButton: some View {
        Button {
            chrome.openHotels(board: .flights)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "suitcase.rolling.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(explorePackagesTitle)
                    .font(.headline.weight(.semibold))
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyBookingHome: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                IumrahRootPageTitle(
                    title: L10n.text("tab_booking", settings.language),
                    showsMakkahTime: true
                )

                bookingScopePicker

                bookingEmptyStatusCard

                explorePackagesButton

                emptyConfiguratorCard
                emptyCareCard
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
    }

    private var bookingEmptyStatusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
                    .frame(width: 58, height: 58)

                Image(systemName: "tray.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.primary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(emptyBookingTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(emptyBookingNote)
                    .font(.system(size: 14.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }


    private var emptyConfiguratorCard: some View {
        emptyShowcaseCard(
            imageName: "IumrahConfiguratorHero",
            imageBackground: .black,
            eyebrow: "Iumrah Configurator",
            badge: localized("5 минут", "5 minutes", "5 daqiqa", "5 дақиқа"),
            title: L10n.text("booking_hero_title", settings.language),
            body: L10n.text("booking_hero_body", settings.language),
            cta: L10n.text("booking_hero_cta", settings.language),
            dark: true,
            imageTopPadding: 0,
            imageHorizontalPadding: 0,
            action: startNewTrip
        )
    }

    private var emptyCareCard: some View {
        emptyShowcaseCard(
            imageName: "IumrahCareShowcaseCard",
            imageBackground: .white,
            eyebrow: "Iumrah Care",
            badge: localized("За вас", "For you", "Siz uchun", "Сиз учун"),
            title: careBookingCardTitle,
            body: careBookingCardBody,
            cta: careBookingCardCTA,
            dark: false,
            imageTopPadding: 0,
            imageHorizontalPadding: 0,
            action: { showCareRequestBuilder = true }
        )
    }

    private func emptyShowcaseCard(
        imageName: String,
        imageBackground: Color,
        eyebrow: String,
        badge: String,
        title: String,
        body: String,
        cta: String,
        dark: Bool,
        imageTopPadding: CGFloat,
        imageHorizontalPadding: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            IumrahHaptics.soft()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    imageBackground

                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(1.08)
                        .padding(.horizontal, imageHorizontalPadding)
                        .padding(.top, imageTopPadding)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 236)
                .clipped()

                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Label(eyebrow, systemImage: dark ? "slider.horizontal.3" : "heart.fill")
                            .font(.caption.weight(.bold))
                            .tracking(0.45)
                            .foregroundStyle(dark ? Color.white.opacity(0.78) : Color.black.opacity(0.58))
                        Spacer(minLength: 8)
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(dark ? Color.white.opacity(0.82) : Color.black.opacity(0.62))
                            .padding(.horizontal, 10)
                            .frame(height: 29)
                            .background((dark ? Color.white.opacity(0.10) : Color.black.opacity(0.055)), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .tracking(-0.75)
                            .foregroundStyle(dark ? .white : .black)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(body)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(dark ? Color.white.opacity(0.68) : Color.black.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 16)

                    HStack(spacing: 10) {
                        Text(cta)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(dark ? .black : .white)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(dark ? Color.white : Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(dark ? Color.black : Color.white)
            }
            .frame(maxWidth: .infinity, minHeight: 458, alignment: .topLeading)
            .background(dark ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder((dark ? Color.white : Color.black).opacity(dark ? 0.06 : 0.055), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared helpers

    private func sectionHeader(title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(-0.35)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startNewTrip() {
        journey.resetAfterTripChange()
        chrome.startNewTrip()
    }

    @MainActor
    private func loadActiveCheckout() async {
        guard let session = activeSession else {
            activeCheckout = nil
            return
        }
        let headers = account.authorizationHeaders(bookingToken: session.accessToken)
        activeCheckout = try? await accountService.checkout(bookingID: session.id, authorizationHeaders: headers)
    }

    @MainActor
    private func deleteBooking(_ id: String) async {
        do {
            try await bookings.deleteBooking(id: id)
            deleteError = nil
            IumrahHaptics.success()
        } catch {
            deleteError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    private func safeIcon(_ value: String) -> String {
        let icon = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return icon.isEmpty ? "calendar" : icon
    }

    private func compactDate(_ raw: String) -> String {
        guard let date = Self.dayParser.date(from: raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func createdDateText(_ raw: String) -> String? {
        guard let date = Self.isoDate(raw) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMM · HH:mm"
        return formatter.string(from: date)
    }

    private func transitionDate(_ status: String, session: StoredBookingSession) -> String? {
        session.orderedStatusHistory.last(where: { $0.newStatus.lowercased() == status.lowercased() })?.createdAt
    }

    private func statusDateText(for index: Int, current: Int, session: StoredBookingSession, isCancelled: Bool) -> String? {
        guard index <= current else { return nil }
        let raw: String?
        switch index {
        case 0:
            raw = session.booking.createdAt
        case 1:
            raw = isCancelled
                ? transitionDate("cancelled", session: session)
                : (session.availabilityStartedAt ?? transitionDate("availability_check", session: session) ?? session.booking.createdAt)
        case 2:
            raw = session.priceLockStartedAt ?? transitionDate("payment_pending", session: session)
        case 3:
            raw = session.documentsStartedAt ?? transitionDate("booking_confirmed", session: session)
        case 4:
            raw = transitionDate("ready_to_travel", session: session)
        case 5:
            raw = transitionDate("in_trip", session: session)
        case 6:
            raw = transitionDate("completed", session: session)
        default:
            raw = nil
        }
        return raw.flatMap(createdDateText)
    }

    private func formatPrice(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        let value = formatter.string(from: NSNumber(value: amount)) ?? String(Int(amount.rounded()))
        return "\(value) $"
    }

    private func pilgrimCountText(_ count: Int) -> String {
        switch settings.language {
        case .russian:
            let mod10 = count % 10
            let mod100 = count % 100
            if mod10 == 1 && mod100 != 11 { return "\(count) паломник" }
            if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "\(count) паломника" }
            return "\(count) паломников"
        case .english:
            return count == 1 ? "1 pilgrim" : "\(count) pilgrims"
        case .uzbek:
            return "\(count) ziyoratchi"
        case .uzbekCyrillic:
            return "\(count) зиёратчи"
        }
    }


    private static func isoDate(_ raw: String) -> Date? {
        if let date = isoFormatterFractional.date(from: raw) { return date }
        return isoFormatter.date(from: raw)
    }

    private static let isoFormatterFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let riyadhDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Riyadh")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Copy

    private var activeEyebrow: String { localized("Ваша Umrah", "Your Umrah", "Sizning Umrangiz", "Сизнинг Умрангиз") }
    private var routeTitle: String { localized("Маршрут", "Route", "Yo‘nalish", "Йўналиш") }
    private var dateTitle: String { localized("Даты", "Dates", "Sanalar", "Саналар") }
    private var hotelTitle: String { localized("Отель", "Hotel", "Mehmonxona", "Меҳмонхона") }
    private var priceTitle: String { localized("На паломника", "Per pilgrim", "Bir ziyoratchiga", "Бир зиёратчига") }
    private var openBookingTitle: String { localized("Открыть бронирование", "Open booking", "Bronni ochish", "Бронни очиш") }
    private var statusTitle: String { localized("Статус бронирования", "Booking status", "Bron holati", "Брон ҳолати") }
    private var cancelledText: String { localized("Отменено", "Cancelled", "Bekor qilingan", "Бекор қилинган") }

    private var createdTitle: String { localized("Пакет создан", "Package created", "Paket yaratildi", "Пакет яратилди") }
    private var createdSubtitle: String { localized("Поездка добавлена в iumrah", "Trip added to iumrah", "Safar iumrah'ga qo‘shildi", "Сафар iumrah'га қўшилди") }

    private var availabilityTitle: String { localized("Проверка наличия", "Availability check", "Mavjudlik tekshiruvi", "Мавжудлик текшируви") }
    private var availabilitySubtitle: String { localized("Подтверждаем перелёт, отель и услуги", "Confirming flight, hotel and services", "Parvoz, mehmonxona va xizmatlar tasdiqlanmoqda", "Парвоз, меҳмонхона ва хизматлар тасдиқланмоқда") }
    private var availabilityCardTitle: String { localized("Проверяем ваш пакет", "Checking your package", "Paketingiz tekshirilmoqda", "Пакетингиз текширилмоқда") }
    private var availabilityCardBody: String { localized("iumrah подтверждает выбранные позиции. Пока от вас ничего не требуется.", "iumrah is confirming the selected items. No action is required from you yet.", "iumrah tanlangan xizmatlarni tasdiqlamoqda. Hozircha sizdan hech narsa talab qilinmaydi.", "iumrah танланган хизматларни тасдиқламоқда. Ҳозирча сиздан ҳеч нарса талаб қилинмайди.") }

    private var paymentStageTitle: String { localized("Оплата и данные паломников", "Payment and pilgrim details", "To‘lov va ziyoratchi ma’lumotlari", "Тўлов ва зиёратчи маълумотлари") }
    private var paymentStageSubtitle: String { localized("Наличие подтверждено · требуется действие", "Availability confirmed · action required", "Mavjudlik tasdiqlandi · amal kerak", "Мавжудлик тасдиқланди · амал керак") }
    private var paymentCardTitle: String { localized("Наличие подтверждено", "Availability confirmed", "Mavjudlik tasdiqlandi", "Мавжудлик тасдиқланди") }
    private var paymentCardBody: String { localized("Проверьте данные паломников и перейдите к оплате, чтобы закрепить бронирование.", "Review pilgrim details and continue to payment to secure the booking.", "Bronni mustahkamlash uchun ziyoratchilar ma’lumotlarini tekshiring va to‘lovga o‘ting.", "Бронни мустаҳкамлаш учун зиёратчилар маълумотларини текширинг ва тўловга ўтинг.") }

    private var confirmedStageTitle: String { localized("Бронирование подтверждено", "Booking confirmed", "Bron tasdiqlandi", "Брон тасдиқланди") }
    private var confirmedStageSubtitle: String { localized("Позиции закреплены за вами", "Your trip components are secured", "Safar xizmatlari siz uchun band qilindi", "Сафар хизматлари сиз учун банд қилинди") }
    private var confirmedCardTitle: String { confirmedStageTitle }
    private var confirmedCardBody: String { localized("Перелёт, проживание и выбранные услуги закреплены. Все детали доступны внутри бронирования.", "Flight, stay and selected services are secured. Full details are available inside the booking.", "Parvoz, yashash va tanlangan xizmatlar band qilindi. Barcha tafsilotlar bron ichida mavjud.", "Парвоз, яшаш ва танланган хизматлар банд қилинди. Барча тафсилотлар брон ичида мавжуд.") }

    private var documentsStageTitle: String { localized("Документы готовы", "Documents ready", "Hujjatlar tayyor", "Ҳужжатлар тайёр") }
    private var documentsStageSubtitle: String { localized("Всё готово к поездке", "Everything is ready for travel", "Safar uchun hammasi tayyor", "Сафар учун ҳаммаси тайёр") }
    private var documentsCardTitle: String { localized("Готово к поездке", "Ready to travel", "Safarga tayyor", "Сафарга тайёр") }
    private var documentsCardBody: String { localized("Проверьте билеты, бронирования и документы перед выездом.", "Review tickets, reservations and travel documents before departure.", "Jo‘nashdan oldin chiptalar, bronlar va hujjatlarni tekshiring.", "Жўнашдан олдин чипталар, бронлар ва ҳужжатларни текширинг.") }

    private var inTripStageTitle: String { localized("Паломник в поездке", "Pilgrim in trip", "Ziyoratchi safarda", "Зиёратчи сафарда") }
    private var inTripStageSubtitle: String { localized("iumrah сопровождает вашу поездку", "iumrah is accompanying your trip", "iumrah safaringizga hamroh", "iumrah сафарингизга ҳамроҳ") }
    private var inTripCardTitle: String { localized("Ваша Umrah идёт", "Your Umrah is underway", "Umrangiz davom etmoqda", "Умрангиз давом этмоқда") }
    private var inTripCardBody: String { localized("Маршрут, отель, расписание и помощь iumrah остаются под рукой на протяжении поездки.", "Your route, hotel, schedule and iumrah support stay close throughout the trip.", "Yo‘nalish, mehmonxona, jadval va iumrah yordami safar davomida doimo yoningizda.", "Йўналиш, меҳмонхона, жадвал ва iumrah ёрдами сафар давомида доимо ёнингизда.") }

    private var completedStageTitle: String { localized("Поездка завершена", "Trip completed", "Safar yakunlandi", "Сафар якунланди") }
    private var completedStageSubtitle: String { localized("История поездки сохранена", "Your trip history is saved", "Safar tarixi saqlandi", "Сафар тарихи сақланди") }
    private var completedCardTitle: String { completedStageTitle }
    private var completedCardBody: String { localized("Бронирование и история поездки останутся доступны в iumrah.", "The booking and trip history remain available in iumrah.", "Bron va safar tarixi iumrah'da saqlanadi.", "Брон ва сафар тарихи iumrah'да сақланади.") }

    private var tripPlanTitle: String { localized("План поездки", "Trip plan", "Safar rejasi", "Сафар режаси") }
    private var tripPlanEmptyText: String { localized("События поездки появятся после подтверждения деталей.", "Trip events will appear after the details are confirmed.", "Tafsilotlar tasdiqlangach safar voqealari paydo bo‘ladi.", "Тафсилотлар тасдиқлангач сафар воқеалари пайдо бўлади.") }
    private var openFullPlanTitle: String { localized("Открыть полное расписание", "Open full schedule", "To‘liq jadvalni ochish", "Тўлиқ жадвални очиш") }

    private var manageSectionTitle: String { localized("Управление поездкой", "Trip management", "Safarni boshqarish", "Сафарни бошқариш") }
    private var bookingScopePickerTitle: String { localized("Поездки", "Trips", "Safarlar", "Сафарлар") }
    private var activeScopeTitle: String { localized("Активные", "Upcoming", "Faol", "Фаол") }
    private var pastScopeTitle: String { localized("Прошлые", "Past", "O‘tgan", "Ўтган") }
    private var explorePackagesTitle: String { localized("Смотреть готовые пакеты", "Explore Packages", "Tayyor paketlarni ko‘rish", "Тайёр пакетларни кўриш") }
    private var noPastBookingsTitle: String { localized("Прошлых поездок пока нет", "No past trips yet", "O‘tgan safarlar hozircha yo‘q", "Ўтган сафарлар ҳозирча йўқ") }
    private var noPastBookingsBody: String { localized("Завершённые и отменённые поездки будут храниться здесь.", "Completed and cancelled trips will appear here.", "Yakunlangan va bekor qilingan safarlar shu yerda ko‘rinadi.", "Якунланган ва бекор қилинган сафарлар шу ерда кўринади.") }
    private var emptyBookingTitle: String { localized("Пока бронирований нет", "No bookings yet", "Hozircha bron yo‘q", "Ҳозирча брон йўқ") }
    private var emptyBookingNote: String { localized("Пока здесь нет активных бронирований. Начните с Конфигуратора или передайте сборку iumrah Care.", "There are no active bookings here yet. Start with the Configurator or let iumrah Care prepare the trip for you.", "Hozircha bu yerda faol bronlar yo‘q. Konfiguratorni oching yoki safarni iumrah Care’ga topshiring.", "Ҳозирча бу ерда фаол бронлар йўқ. Конфигураторни очинг ёки сафарни iumrah Care’га топширинг.") }
    private var careBookingCardTitle: String { localized("Соберите Umrah за меня", "Build my Umrah for me", "Umramni men uchun yig‘ing", "Умрамни мен учун йиғинг") }
    private var careBookingCardBody: String { localized("Расскажите даты, бюджет и пожелания. Iumrah Care соберёт для вас персональный вариант поездки.", "Tell us your dates, budget and preferences. Iumrah Care will prepare a personal Umrah option for you.", "Sanalar, budjet va istaklaringizni ayting. Iumrah Care siz uchun shaxsiy Umra variantini tayyorlaydi.", "Саналар, бюджет ва истакларингизни айтинг. Iumrah Care сиз учун шахсий Умра вариантини тайёрлайди.") }
    private var careBookingCardCTA: String { localized("Собрать мою Umrah", "Build my Umrah", "Mening Umramni yig‘ish", "Менинг Умрамни йиғиш") }
    private var newUmrahTitle: String { localized("Новая Umrah", "New Umrah", "Yangi Umra", "Янги Умра") }
    private var newUmrahSubtitle: String { localized("Собрать новый пакет", "Build a new package", "Yangi paket tuzish", "Янги пакет тузиш") }
    private var addPilgrimTitle: String { localized("Добавить паломника", "Add pilgrim", "Ziyoratchi qo‘shish", "Зиёратчи қўшиш") }
    private var addPilgrimSubtitle: String { localized("Запрос через iumrah Care", "Request via iumrah Care", "iumrah Care orqali so‘rov", "iumrah Care орқали сўров") }
    private var manageTitle: String { localized("Управлять бронированием", "Manage booking", "Bronni boshqarish", "Бронни бошқариш") }
    private var manageSubtitle: String { localized("Отели, данные, услуги и документы", "Hotels, details, services and documents", "Mehmonxona, ma’lumotlar, xizmatlar va hujjatlar", "Меҳмонхона, маълумотлар, хизматлар ва ҳужжатлар") }
    private var otherTripsTitle: String { localized("Другие поездки", "Other trips", "Boshqa safarlar", "Бошқа сафарлар") }
    private var ziyaratsBookingTitle: String { localized("Зияраты", "Ziyarat", "Ziyorat", "Зиёрат") }
    private var ziyaratsBookingSubtitle: String { localized("Маршрут и места посещения", "Route and places to visit", "Yo‘nalish va tashrif joylari", "Йўналиш ва ташриф жойлари") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private enum BookingLifecyclePhase {
    case availability(Date?)
    case priceLock(Date?)
    case paymentConfirmation(Date?)
    case documents(Date?)

    var deadline: Date? {
        switch self {
        case .availability(let value), .priceLock(let value), .paymentConfirmation(let value), .documents(let value):
            return value
        }
    }

    var symbol: String {
        switch self {
        case .availability: return "clock.badge.checkmark"
        case .priceLock: return "lock.clock"
        case .paymentConfirmation: return "creditcard.and.123"
        case .documents: return "doc.badge.clock"
        }
    }
}

private struct BookingProgressStage {
    let title: String
    let activeSubtitle: String
    let cardTitle: String
    let cardBody: String
}
