import SwiftUI

struct BookingDetailView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String

    @State private var outboundExpanded = false
    @State private var inboundExpanded = false
    @State private var makkahHotelExpanded = false
    @State private var madinahHotelExpanded = false
    @State private var showMakkahHotelChange = false
    @State private var showMadinahHotelChange = false
    @State private var showContactEdit = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var ziyaratMakkah = true
    @State private var ziyaratMadinah = false
    @State private var isSavingZiyarat = false
    @State private var esimIncluded = true
    @State private var isSavingESIM = false
    @State private var mutationError: String?
    @State private var isRequestingConfirmation = false
    @State private var confirmationSent = false
    @State private var showPackageCareExplanation = false
    @State private var bookingCardFlipped = false
    @State private var bookingScrollMinY: CGFloat? = nil
    @State private var bookingPullTranslation: CGFloat = 0
    @State private var bookingPullArmed = false
    @State private var bookingPullGestureActive = false
    @State private var bookingPullGestureDecisionMade = false
    @State private var bookingPullGestureEligible = false
    @State private var bookingViewportHeight: CGFloat = 0
    @State private var showFullscreenBookingCard = false
    @State private var fullscreenBookingCardFlipped = false
    @State private var fullscreenCardLandscape = false
    @State private var securityConfirmation: IumrahSecurityConfirmation?

    private let bookingService = BookingService()
    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        Group {
            if let session {
                GeometryReader { viewport in
                    ScrollView(showsIndicators: false) {
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: BookingPullDistancePreferenceKey.self,
                                    value: Optional(proxy.frame(in: .named("booking-detail-scroll")).minY)
                                )
                        }
                        .frame(height: 0)

                        VStack(spacing: 16) {
                            IumrahBookingDomeCard(
                                bookingNumber: session.displayBookingNumber,
                                travelerName: bookingTravelerName(session),
                                language: settings.language,
                                isFlipped: $bookingCardFlipped
                            )
                            statusHero(session)
                            if shouldShowCheckoutEntry(for: session) {
                                IumrahManualPaymentNotice()
                                IumrahRefundPolicyCard(component: .package, compact: true)
                                IumrahInvoiceShareCard(session: session, compact: true)
                            }
                            bookingMetaCard(session.booking)
                            if session.booking.perPilgrimUsd >= 1800 {
                                bookingCareBalanceCard
                            }
                            BookingItineraryCalendarView(
                                bookingID: session.id,
                                startDate: session.booking.input.startDate,
                                endDate: session.booking.input.endDate,
                                booking: session.booking
                            )

                            BookingFlightDisclosureCard(
                                title: L10n.text("booking_outbound_flight", settings.language),
                                route: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)",
                                date: session.booking.input.startDate,
                                fallbackFlight: outboundFallback(session),
                                offer: session.outboundFlight,
                                isExpanded: $outboundExpanded
                            )

                            BookingFlightDisclosureCard(
                                title: L10n.text("booking_return_flight", settings.language),
                                route: "\(session.booking.route.returnOrigin) → \(session.booking.route.originCode)",
                                date: session.booking.input.endDate,
                                fallbackFlight: inboundFallback(session),
                                offer: session.inboundFlight,
                                isExpanded: $inboundExpanded
                            )

                            hotelCard(session, role: .makkah, isExpanded: $makkahHotelExpanded)

                            if session.booking.input.includeMadinah {
                                hotelCard(session, role: .madinah, isExpanded: $madinahHotelExpanded)
                            }

                            transferCard(session)
                            guideCard(session)
                            ziyaratCard(session)
                            esimCard(session)
                            contactCard(session)

                            if session.pendingChangeConfirmation == true || confirmationSent {
                                confirmationCard(session)
                            }

                            careAction
                            destructiveActions
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, IumrahDesign.pagePadding)
                        .padding(.top, 12)
                        .padding(.bottom, 56)
                        .offset(y: bookingPullVisualOffset)
                    }
                    .coordinateSpace(name: "booking-detail-scroll")
                    .background(Color.iumrahPageBackground)
                    .onAppear {
                        bookingViewportHeight = viewport.size.height
                    }
                    .onChange(of: viewport.size.height) { _, newValue in
                        bookingViewportHeight = newValue
                    }
                    .onPreferenceChange(BookingPullDistancePreferenceKey.self) { value in
                        bookingScrollMinY = value
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 4, coordinateSpace: .local)
                            .onChanged { value in
                                updateBookingPull(translation: value.translation.height)
                            }
                            .onEnded { value in
                                finishBookingPull(translation: value.translation.height)
                            }
                    )
                    .overlay(alignment: .top) {
                        if bookingPullTranslation > 10, !showFullscreenBookingCard {
                            bookingPullHint
                                .padding(.top, bookingPullHintOffset)
                                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                                .allowsHitTesting(false)
                        }
                    }
                    .task {
                        await bookings.refreshAll()
                        await bookings.syncHotelSelectionIfNeeded(bookingID: bookingID)
                        await loadSecurityConfirmation()
                        loadZiyaratDraft()
                        loadESIMDraft()
                    }
                    .sheet(isPresented: $showMakkahHotelChange) {
                        BookingHotelChangeView(bookingID: bookingID, role: .makkah)
                            .environmentObject(settings)
                            .environmentObject(bookings)
                    }
                    .sheet(isPresented: $showMadinahHotelChange) {
                        BookingHotelChangeView(bookingID: bookingID, role: .madinah)
                            .environmentObject(settings)
                            .environmentObject(bookings)
                    }
                    .sheet(isPresented: $showContactEdit) {
                        BookingContactEditSheet(
                            bookingID: bookingID,
                            telegram: session.telegram ?? "",
                            whatsapp: session.whatsapp ?? ""
                        )
                        .environmentObject(settings)
                        .environmentObject(bookings)
                    }
                    .sheet(isPresented: $showPackageCareExplanation) {
                        UmrahCarePackageExplanationView()
                            .environmentObject(settings)
                    }
                }

            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(L10n.text("detail_not_found", settings.language))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.iumrahPageBackground)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .overlay {
            if let session, showFullscreenBookingCard {
                fullscreenBookingPass(session)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .confirmationDialog(
            L10n.text("booking_delete_confirm_title", settings.language),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("booking_delete_confirm_action", settings.language), role: .destructive) {
                Task { await deleteBooking() }
            }
            Button(L10n.text("cancel", settings.language), role: .cancel) {}
        } message: {
            Text(L10n.text("booking_delete_confirm_body", settings.language))
        }
    }

    private var bookingPullThreshold: CGFloat {
        // The gesture intentionally requires a long, deliberate pull — about
        // half of the visible booking interface — so it reads as a physical
        // pass interaction rather than ordinary ScrollView rubber-banding.
        let viewport = bookingViewportHeight > 0 ? bookingViewportHeight : 720
        return min(max(viewport * 0.46, 300), 420)
    }

    private var bookingPullVisualOffset: CGFloat {
        min(max(bookingPullTranslation, 0), bookingPullThreshold)
    }

    private var bookingPullHintOffset: CGFloat {
        let visual = bookingPullVisualOffset
        return min(max(18, visual * 0.44), 150)
    }

    private func bookingTravelerName(_ session: StoredBookingSession) -> String {
        let value = session.travelerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? settings.displayName : value
    }

    private var bookingPullHint: some View {
        let progress = min(max(bookingPullTranslation / bookingPullThreshold, 0), 1)

        return VStack(spacing: 7) {
            Image(systemName: bookingPullArmed ? "arrow.down.circle.fill" : "arrow.down")
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .offset(y: bookingPullArmed ? 2 : 0)

            Text(BookingCardCopy.releaseToFlip(settings.language))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .iumrahGlass(in: Capsule())
        .scaleEffect(0.92 + (0.08 * progress))
        .opacity(0.18 + (0.82 * progress))
        .blur(radius: (1 - progress) * 2.2)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: bookingPullArmed)
    }

    private func updateBookingPull(translation: CGFloat) {
        guard !showFullscreenBookingCard else { return }

        if !bookingPullGestureDecisionMade {
            bookingPullGestureDecisionMade = true

            // The pass gesture is eligible only when this drag STARTS at the
            // real beginning of the booking page. `bookingScrollMinY` is the
            // live position of a single marker at content y = 0. Once the
            // user has scrolled down it is negative, so swipes on itinerary,
            // flights, hotels, Care, etc. remain ordinary scrolling gestures.
            if let topY = bookingScrollMinY {
                bookingPullGestureEligible = translation > 0 && topY >= -1.5
            } else {
                bookingPullGestureEligible = false
            }
            bookingPullGestureActive = bookingPullGestureEligible
        }

        // The decision is locked for the life of this drag. A user who began
        // while scrolled down cannot accidentally trigger the pass when that
        // same gesture later reaches the top of the ScrollView.
        guard bookingPullGestureEligible else { return }

        bookingPullTranslation = max(0, translation)

        if bookingPullTranslation >= bookingPullThreshold, !bookingPullArmed {
            bookingPullArmed = true
            IumrahHaptics.selection()
        } else if bookingPullTranslation < bookingPullThreshold * 0.86, bookingPullArmed {
            bookingPullArmed = false
        }
    }

    private func finishBookingPull(translation: CGFloat) {
        let eligible = bookingPullGestureEligible
        let shouldPresent = eligible && (bookingPullArmed || translation >= bookingPullThreshold)

        bookingPullGestureActive = false
        bookingPullGestureDecisionMade = false
        bookingPullGestureEligible = false
        bookingPullArmed = false

        guard eligible else { return }

        if shouldPresent {
            presentFullscreenBookingPass()
            withAnimation(.easeOut(duration: 0.18)) {
                bookingPullTranslation = 0
            }
        } else {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                bookingPullTranslation = 0
            }
        }
    }

    private func presentFullscreenBookingPass() {
        guard !showFullscreenBookingCard else { return }
        fullscreenBookingCardFlipped = false
        fullscreenCardLandscape = false
        IumrahHaptics.soft()

        withAnimation(.easeOut(duration: 0.22)) {
            showFullscreenBookingCard = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard showFullscreenBookingCard else { return }
            withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
                fullscreenCardLandscape = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            guard showFullscreenBookingCard else { return }
            withAnimation(.spring(response: 0.70, dampingFraction: 0.84)) {
                fullscreenBookingCardFlipped = true
            }
            IumrahHaptics.soft()
        }
    }

    private func dismissFullscreenBookingPass() {
        IumrahHaptics.selection()
        withAnimation(.easeInOut(duration: 0.22)) {
            showFullscreenBookingCard = false
            fullscreenCardLandscape = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            fullscreenBookingCardFlipped = false
        }
    }

    @ViewBuilder
    private func fullscreenBookingPass(_ session: StoredBookingSession) -> some View {
        GeometryReader { proxy in
            // Before the 90° rotation this is the card's landscape width.
            // After rotation the physical pass nearly fills the portrait
            // screen width while preserving its true 1.60:1 proportions.
            let landscapeCardWidth = min(
                proxy.size.height * 0.88,
                proxy.size.width * 0.94 * 1.60
            )

            ZStack {
                Color.black.opacity(0.985)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissFullscreenBookingPass() }

                IumrahBookingDomeCard(
                    bookingNumber: session.displayBookingNumber,
                    travelerName: bookingTravelerName(session),
                    language: settings.language,
                    isFlipped: $fullscreenBookingCardFlipped
                )
                .frame(width: landscapeCardWidth)
                .rotationEffect(.degrees(fullscreenCardLandscape ? 90 : 0))
                .scaleEffect(fullscreenCardLandscape ? 1.0 : 0.60)
                .opacity(showFullscreenBookingCard ? 1 : 0)
                .shadow(color: .black.opacity(0.38), radius: 34, y: 16)
                .accessibilityAddTraits(.isButton)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Group {
                if #available(iOS 26.0, *) {
                    Button {
                        IumrahHaptics.soft()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.glass)
                } else {
                    Button {
                        IumrahHaptics.soft()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)
                            .iumrahGlass(in: Circle(), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text("booking_detail_title", settings.language))
                    .font(.headline)
                if let session {
                    HStack(spacing: 7) {
                        Text("Бронь \(session.displayBookingNumber)")
                        if let pilgrimID = session.displayPilgrimID {
                            Text("·")
                            Text("iumrah ID \(pilgrimID)")
                        }
                    }
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                }
            }
            Spacer()
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 8)
        .background(Color.iumrahPageBackground)
    }

    private func outboundFallback(_ session: StoredBookingSession) -> String {
        if let trace = session.booking.generatorTrace?.outbound {
            let value = [trace.airline, trace.flightNumbers].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " · ")
            if !value.isEmpty { return value }
        }
        return session.booking.flight
    }

    private func inboundFallback(_ session: StoredBookingSession) -> String {
        if let trace = session.booking.generatorTrace?.inbound {
            let value = [trace.airline, trace.flightNumbers].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " · ")
            if !value.isEmpty { return value }
        }
        return session.booking.flight
    }

    private func statusHero(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.travelerName ?? L10n.text("booking_your_trip", settings.language))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text(L10n.status(session.effectiveStatus, settings.language))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                IumrahIconBadge(
                    systemName: statusIcon(session.effectiveStatus),
                    role: IumrahBookingStatusVisual.role(for: session.effectiveStatus),
                    size: 52,
                    symbolSize: 22,
                    cornerRadius: 26,
                    shape: .circle
                )
            }

            Text(L10n.text("detail_updates", settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let phase = lifecyclePhase(for: session) {
                lifecycleTimerCard(phase)
            }

            if shouldShowCheckoutEntry(for: session) {
                NavigationLink {
                    IumrahSecurityConfirmationView(bookingID: bookingID)
                        .environmentObject(settings)
                        .environmentObject(bookings)
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: securityConfirmationIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(securityConfirmation?.isConfirmed == true ? Color.green : Color.primary)
                            .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(securityConfirmationDisplayTitle)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(securityConfirmationSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true)
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PilgrimCheckoutView(bookingID: bookingID)
                } label: {
                    HStack(spacing: 13) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 42, height: 42)

                            Image(systemName: "person.text.rectangle.fill")
                                .font(.system(size: 18, weight: .semibold))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(checkoutCTA)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Text(checkoutCTASubtitle)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.72))
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.black)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(checkoutCTA)
            } else if ["BOOKING_CONFIRMED", "READY_TO_TRAVEL", "IN_TRIP"].contains(session.effectiveStatus) {
                NavigationLink {
                    PilgrimCheckoutView(bookingID: bookingID)
                } label: {
                    HStack {
                        Label(tripDocumentsTitle, systemImage: "doc.text.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    @ViewBuilder
    private func lifecycleTimerCard(_ phase: BookingDetailLifecyclePhase) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, phase.deadline.timeIntervalSince(context.date))
            let expired = remaining <= 0
            let tint = lifecycleTimerTint(phase)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lifecycleTimerTitle(phase, expired: expired))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(expired ? lifecycleOvertimeLabel : lifecycleCountdown(remaining))
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(tint)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: phase.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 40, height: 40)
                        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text(lifecycleTimerFootnote(phase, expired: expired))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func lifecyclePhase(for session: StoredBookingSession) -> BookingDetailLifecyclePhase? {
        switch session.effectiveStatus.uppercased() {
        case "NEW", "AVAILABILITY_CHECK":
            let deadline = lifecycleDeadline(
                explicit: session.availabilityDeadlineAt,
                start: session.availabilityStartedAt
                    ?? session.latestStatusTimestamp(matching: ["availability_check", "new"])
                    ?? session.booking.createdAt,
                duration: 6 * 60 * 60
            )
            return deadline.map { .availability($0) }
        case "PAYMENT_PENDING":
            if session.paymentReceivedAt != nil {
                let deadline = lifecycleDeadline(
                    explicit: session.paymentConfirmationDeadlineAt,
                    start: session.paymentReceivedAt,
                    duration: 10 * 60
                )
                return deadline.map { .paymentConfirmation($0) }
            }
            let deadline = lifecycleDeadline(
                explicit: session.priceLockExpiresAt,
                start: session.priceLockStartedAt
                    ?? session.latestStatusTimestamp(matching: ["payment_pending"])
                    ?? session.booking.updatedAt,
                duration: 30 * 60
            )
            return deadline.map { .priceLock($0) }
        case "PAID", "BOOKING_CONFIRMED":
            let deadline = lifecycleDeadline(
                explicit: session.documentsDeadlineAt,
                start: session.documentsStartedAt
                    ?? session.latestStatusTimestamp(matching: ["booking_confirmed", "paid"])
                    ?? session.booking.updatedAt,
                duration: 24 * 60 * 60
            )
            return deadline.map { .documents($0) }
        default:
            return nil
        }
    }

    private func lifecycleDeadline(explicit: String?, start: String?, duration: TimeInterval) -> Date? {
        if let explicit, let value = Self.isoDate(explicit) { return value }
        guard let start, let value = Self.isoDate(start) else { return nil }
        return value.addingTimeInterval(duration)
    }

    private func lifecycleTimerTint(_ phase: BookingDetailLifecyclePhase) -> Color {
        switch phase {
        case .availability: return .mint
        case .priceLock: return .orange
        case .paymentConfirmation: return .blue
        case .documents: return .green
        }
    }

    private func lifecycleCountdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var lifecycleOvertimeLabel: String {
        localized("Сверх срока", "Over time", "Muddatdan oshdi", "Муддатдан ошди")
    }

    private func lifecycleTimerTitle(_ phase: BookingDetailLifecyclePhase, expired: Bool) -> String {
        switch phase {
        case .availability:
            return expired ? localized("Проверка занимает дольше обычного", "The check is taking longer than usual", "Tekshiruv odatdagidan uzoqroq davom etmoqda", "Текширув одатдагидан узоқроқ давом этмоқда") : localized("До максимального срока проверки", "Until the maximum check time", "Tekshiruvning maksimal muddatigacha", "Текширувнинг максимал муддатигача")
        case .priceLock:
            return expired ? localized("Срок фиксации цены завершён", "Price hold has ended", "Narxni saqlash muddati tugadi", "Нархни сақлаш муддати тугади") : localized("Цена зафиксирована ещё", "Price held for", "Narx yana shuncha vaqtga saqlanadi", "Нарх яна шунча вақтга сақланади")
        case .paymentConfirmation:
            return expired ? localized("Подтверждение занимает дольше обычного", "Confirmation is taking longer than usual", "Tasdiqlash odatdagidan uzoqroq davom etmoqda", "Тасдиқлаш одатдагидан узоқроқ давом этмоқда") : localized("Подтверждаем оплату", "Confirming payment", "To‘lov tasdiqlanmoqda", "Тўлов тасдиқланмоқда")
        case .documents:
            return expired ? localized("Подготовка занимает дольше обычного", "Preparation is taking longer than usual", "Tayyorlash odatdagidan uzoqroq davom etmoqda", "Тайёрлаш одатдагидан узоқроқ давом этмоқда") : localized("Плановый срок подготовки", "Planned preparation time", "Rejalashtirilgan tayyorlash muddati", "Режалаштирилган тайёрлаш муддати")
        }
    }

    private func lifecycleTimerFootnote(_ phase: BookingDetailLifecyclePhase, expired: Bool) -> String {
        switch phase {
        case .availability:
            return expired ? localized("Мы продолжаем проверку. Статус обновится автоматически, как только все компоненты будут подтверждены.", "We are continuing the check. The status will update automatically once all components are confirmed.", "Tekshiruv davom etmoqda. Barcha qismlar tasdiqlangach holat avtomatik yangilanadi.", "Текширув давом этмоқда. Барча қисмлар тасдиқлангач ҳолат автоматик янгиланади.") : localized("Обычно подтверждение занимает 1–2 часа. Можно закрыть приложение — статус обновится автоматически.", "Confirmation usually takes 1–2 hours. You can close the app — the status will update automatically.", "Tasdiqlash odatda 1–2 soat davom etadi. Ilovani yopishingiz mumkin — holat avtomatik yangilanadi.", "Тасдиқлаш одатда 1–2 соат давом этади. Иловани ёпишингиз мумкин — ҳолат автоматик янгиланади.")
        case .priceLock:
            return expired ? localized("Перед подтверждением оплаты iumrah повторно проверит актуальную итоговую стоимость.", "Before confirming payment, iumrah will recheck the current total price.", "To‘lovni tasdiqlashdan oldin iumrah yakuniy narxning dolzarbligini qayta tekshiradi.", "Тўловни тасдиқлашдан олдин iumrah якуний нархнинг долзарблигини қайта текширади.") : localized("Авиабилеты и некоторые другие компоненты имеют динамическую стоимость и после окончания периода могут потребовать повторной проверки.", "Flights and some other components have dynamic pricing and may require a fresh check after this period.", "Aviachiptalar va ayrim boshqa qismlar dinamik narxga ega, muddat tugagach qayta tekshiruv talab qilinishi mumkin.", "Авиачипталар ва айрим бошқа қисмлар динамик нархга эга, муддат тугагач қайта текширув талаб қилиниши мумкин.")
        case .paymentConfirmation:
            return localized("Оплата получена. Обычно проверка и окончательная фиксация бронирования занимают до 10 минут.", "Payment received. Verification and final booking confirmation usually take up to 10 minutes.", "To‘lov qabul qilindi. Tekshiruv va bronni yakuniy tasdiqlash odatda 10 daqiqagacha davom etadi.", "Тўлов қабул қилинди. Текширув ва бронни якуний тасдиқлаш одатда 10 дақиқагача давом этади.")
        case .documents:
            return localized("Обычно доступные документы готовятся в течение 24 часов. Срок визы может зависеть от доступности официальных визовых систем Саудовской Аравии и внешних ограничений.", "Available travel documents are usually prepared within 24 hours. Visa timing can depend on the availability of Saudi Arabia’s official visa systems and external restrictions.", "Mavjud safar hujjatlari odatda 24 soat ichida tayyorlanadi. Viza muddati Saudiya Arabistonining rasmiy viza tizimlari mavjudligi va tashqi cheklovlarga bog‘liq bo‘lishi mumkin.", "Мавжуд сафар ҳужжатлари одатда 24 соат ичида тайёрланади. Виза муддати Саудия Арабистонининг расмий виза тизимлари мавжудлиги ва ташқи чекловларга боғлиқ бўлиши мумкин.")
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCyr: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCyr
        }
    }

    private static func isoDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    private func shouldShowCheckoutEntry(for session: StoredBookingSession) -> Bool {
        let candidates = [
            session.effectiveStatus,
            session.operationStatus ?? "",
            session.booking.status
        ]

        return candidates.contains { raw in
            let normalized = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "-", with: "_")
                .uppercased()

            return [
                "PAYMENT_PENDING",
                "PENDING_PAYMENT",
                "WAITING_PAYMENT",
                "AWAITING_PAYMENT",
                "PAYMENT_AND_DATA_PENDING",
                "AWAITING_PAYMENT_AND_DATA"
            ].contains(normalized)
        }
    }

    private var securityConfirmationTitle: String {
        switch settings.language {
        case .russian: return "Подтвердить личность"
        case .english: return "Confirm identity"
        case .uzbek: return "Shaxsni tasdiqlash"
        case .uzbekCyrillic: return "Шахсни тасдиқлаш"
        }
    }

    private var securityConfirmationPendingTitle: String {
        switch settings.language {
        case .russian: return "Проверка безопасности"
        case .english: return "Security verification"
        case .uzbek: return "Xavfsizlik tekshiruvi"
        case .uzbekCyrillic: return "Хавфсизлик текшируви"
        }
    }

    private var securityConfirmationDoneTitle: String {
        switch settings.language {
        case .russian: return "Личность подтверждена"
        case .english: return "Identity confirmed"
        case .uzbek: return "Shaxs tasdiqlandi"
        case .uzbekCyrillic: return "Шахс тасдиқланди"
        }
    }

    private var securityConfirmationDisplayTitle: String {
        if securityConfirmation?.isConfirmed == true { return securityConfirmationDoneTitle }
        if securityConfirmation?.isPendingReview == true { return securityConfirmationPendingTitle }
        if securityConfirmation?.needsResubmission == true {
            switch settings.language {
            case .russian: return "Исправить данные Iumrah Security"
            case .english: return "Correct Iumrah Security details"
            case .uzbek: return "Iumrah Security ma’lumotlarini tuzatish"
            case .uzbekCyrillic: return "Iumrah Security маълумотларини тузатиш"
            }
        }
        return securityConfirmationTitle
    }

    private var securityConfirmationIcon: String {
        if securityConfirmation?.isConfirmed == true { return "checkmark.shield.fill" }
        if securityConfirmation?.isPendingReview == true { return "hourglass.circle.fill" }
        if securityConfirmation?.needsResubmission == true { return "arrow.triangle.2.circlepath" }
        return "lock.shield.fill"
    }

    private var securityConfirmationSubtitle: String {
        switch settings.language {
        case .russian: return "Iumrah Security · защищённое бронирование"
        case .english: return "Iumrah Security · protected booking"
        case .uzbek: return "Iumrah Security · himoyalangan bron"
        case .uzbekCyrillic: return "Iumrah Security · ҳимояланган брон"
        }
    }

    @MainActor
    private func loadSecurityConfirmation() async {
        guard let session, shouldShowCheckoutEntry(for: session) else {
            securityConfirmation = nil
            return
        }
        if let response = try? await bookingService.securityConfirmation(id: bookingID, accessToken: session.accessToken) {
            securityConfirmation = response.confirmation
        }
    }

    private var checkoutCTA: String {
        switch settings.language {
        case .russian: return "Заполнить данные и оплатить"
        case .english: return "Complete details and pay"
        case .uzbek: return "Ma’lumotlarni to‘ldirish va to‘lash"
        case .uzbekCyrillic: return "Маълумотларни тўлдириш ва тўлаш"
        }
    }

    private var checkoutCTASubtitle: String {
        switch settings.language {
        case .russian: return "iumrah ID · анкеты · реквизиты · чек"
        case .english: return "iumrah ID · pilgrim forms · payment · receipt"
        case .uzbek: return "iumrah ID · anketalar · to‘lov · chek"
        case .uzbekCyrillic: return "iumrah ID · анкеталар · тўлов · чек"
        }
    }

    private var tripDocumentsTitle: String {
        switch settings.language {
        case .russian: return "Данные и документы поездки"
        case .english: return "Trip details and documents"
        case .uzbek: return "Safar ma’lumotlari va hujjatlar"
        case .uzbekCyrillic: return "Сафар маълумотлари ва ҳужжатлар"
        }
    }

    private func bookingMetaCard(_ booking: RemoteBooking) -> some View {
        VStack(spacing: 13) {
            summaryRow(
                title: L10n.text("detail_dates", settings.language),
                value: "\(L10n.date(booking.input.startDate, settings.language)) — \(L10n.date(booking.input.endDate, settings.language))"
            )
            summaryRow(
                title: L10n.text("travelers", settings.language),
                value: "\(booking.input.travelers.totalPeople)"
            )
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("booking_total_package", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(L10n.text("booking_all_in_one_price", settings.language))
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                PackagePriceView(amount: Decimal(booking.totalUsd), currency: "USD", showsPerPerson: false)
            }
        }
        .iumrahCard()
    }

    private func hotelCard(_ session: StoredBookingSession, role: HotelSelectionRole, isExpanded: Binding<Bool>) -> some View {
        let snapshot = role == .madinah ? session.madinahHotelSelection : session.hotelSelection
        let hotelName = snapshot?.hotelName ?? (role == .madinah ? session.booking.hotelNames.madinah : session.booking.hotelNames.makkah)
        let roomDisplayName = snapshot?.roomCategory.map { L10n.text($0.titleKey, settings.language) } ?? snapshot?.roomName
        let title = role == .madinah ? L10n.text("booking_madinah_hotel", settings.language) : L10n.text("booking_makkah_hotel", settings.language)
        let nights: Int? = role == .madinah ? session.booking.stay.madinahNights : session.booking.stay.makkahNights

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 14) {
                HotelCachedImage(
                    rawURL: snapshot?.coverImageURL,
                    placeholderSystemName: role == .madinah ? "moon.stars.fill" : "building.2.fill"
                )
                .frame(width: 82, height: 82)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(hotelName.isEmpty ? L10n.text("booking_hotel_pending", settings.language) : hotelName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    if let roomDisplayName, !roomDisplayName.isEmpty {
                        Label(roomDisplayName, systemImage: "bed.double.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if let nights, nights > 0 {
                    servicePill(icon: "moon.fill", text: L10n.format("booking_nights_count", settings.language, nights))
                }
                if let city = snapshot?.city, !city.isEmpty {
                    servicePill(icon: "mappin", text: L10n.city(city, settings.language))
                }
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Text(isExpanded.wrappedValue ? L10n.text("collapse", settings.language) : L10n.text("expand", settings.language))
                    Spacer()
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(spacing: 10) {
                    if let beds = snapshot?.roomBeds, !beds.isEmpty {
                        summaryRow(title: L10n.text("room_beds", settings.language), value: beds)
                    }
                    if let size = snapshot?.roomSizeM2 {
                        summaryRow(title: L10n.text("room_area", settings.language), value: L10n.format("room_size", settings.language, size))
                    }
                    if let guests = snapshot?.roomMaxGuests {
                        summaryRow(title: L10n.text("room_capacity", settings.language), value: L10n.format("room_sleeps", settings.language, guests))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                if role == .madinah { showMadinahHotelChange = true }
                else { showMakkahHotelChange = true }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(L10n.text("booking_change_hotel", settings.language))
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .iumrahCard()
    }

    private func transferCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            serviceHeader(
                icon: "car.side.fill",
                title: L10n.text("booking_transfer_title", settings.language),
                subtitle: L10n.text("booking_transfer_body", settings.language),
                badge: L10n.text("booking_included", settings.language)
            )

            VStack(spacing: 11) {
                serviceRouteRow(icon: "airplane.arrival", text: L10n.format("booking_transfer_arrival", settings.language, session.booking.input.arrivalAirportCode))
                serviceRouteRow(icon: "building.2.fill", text: L10n.text("booking_transfer_makkah", settings.language))
                if session.booking.input.includeMadinah {
                    serviceRouteRow(icon: "arrow.left.arrow.right", text: L10n.text("booking_transfer_intercity", settings.language))
                    serviceRouteRow(icon: "moon.stars.fill", text: L10n.text("booking_transfer_madinah", settings.language))
                }
                if currentZiyaratMakkah(session) || currentZiyaratMadinah(session) {
                    serviceRouteRow(icon: "sparkles", text: L10n.text("booking_transfer_ziyarat", settings.language))
                }
                serviceRouteRow(icon: "airplane.departure", text: L10n.format("booking_transfer_departure", settings.language, session.booking.route.returnOrigin))
            }
        }
        .iumrahCard()
    }

    private func guideCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            serviceHeader(
                icon: "person.badge.shield.checkmark.fill",
                title: L10n.text("booking_guide_title", settings.language),
                subtitle: session.guide == nil ? L10n.text("booking_guide_pending", settings.language) : L10n.text("booking_guide_assigned", settings.language),
                badge: nil
            )

            if let guide = session.guide {
                VStack(alignment: .leading, spacing: 8) {
                    Text(guide.displayName)
                        .font(.title3.weight(.bold))
                    if !guide.roleTitle.isEmpty {
                        Text(guide.roleTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !guide.whatsapp.isEmpty {
                        summaryRow(title: "WhatsApp", value: guide.whatsapp)
                    } else if !guide.phoneSA.isEmpty {
                        summaryRow(title: L10n.text("booking_phone", settings.language), value: guide.phoneSA)
                    } else if !guide.phoneUZ.isEmpty {
                        summaryRow(title: L10n.text("booking_phone", settings.language), value: guide.phoneUZ)
                    }
                }
                .padding(15)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Text(L10n.text("booking_guide_care_note", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .iumrahCard()
    }

    private func ziyaratCard(_ session: StoredBookingSession) -> some View {
        let savedMakkah = currentZiyaratMakkah(session)
        let savedMadinah = currentZiyaratMadinah(session)
        let hasChanges = ziyaratMakkah != savedMakkah || ziyaratMadinah != savedMadinah

        return VStack(alignment: .leading, spacing: 16) {
            serviceHeader(
                icon: "sparkles",
                title: L10n.text("booking_ziyarat_title", settings.language),
                subtitle: L10n.text("booking_ziyarat_body", settings.language),
                badge: nil
            )

            Toggle(isOn: $ziyaratMakkah) {
                Label(L10n.text("booking_ziyarat_makkah", settings.language), systemImage: "building.columns.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Color.iumrahCareLight)

            if session.booking.input.includeMadinah {
                Divider()
                Toggle(isOn: $ziyaratMadinah) {
                    Label(L10n.text("booking_ziyarat_madinah", settings.language), systemImage: "moon.stars.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(Color.iumrahCareLight)
            }

            if hasChanges {
                Button {
                    Task { await saveZiyarat() }
                } label: {
                    HStack {
                        if isSavingZiyarat { ProgressView().tint(.primary) }
                        Text(L10n.text("booking_save_changes", settings.language))
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
                .disabled(isSavingZiyarat)
            }

            if let mutationError {
                Text(mutationError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .iumrahCard()
    }

    private func esimCard(_ session: StoredBookingSession) -> some View {
        let saved = currentESIM(session)
        let hasChanges = esimIncluded != saved

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image("UmrahMobileLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 58)
                    .padding(6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("iumrah Mobile eSIM")
                        .font(.headline)
                    Text(esimBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
            }

            Toggle(isOn: $esimIncluded) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(esimToggleTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(esimToggleSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color.iumrahCareLight)

            if hasChanges {
                Button {
                    Task { await saveESIM() }
                } label: {
                    HStack {
                        if isSavingESIM { ProgressView().tint(.primary) }
                        Text(L10n.text("booking_save_changes", settings.language))
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
                .disabled(isSavingESIM)

                if !esimIncluded {
                    Text(esimConfirmationNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .iumrahCard()
    }

    private var esimBody: String {
        switch settings.language {
        case .russian: return "Интернет для поездки в Саудовской Аравии. После подготовки бронирования активация появится прямо в приложении."
        case .english: return "Connectivity for your trip in Saudi Arabia. Activation appears in the app once the booking is prepared."
        case .uzbek: return "Saudiya Arabistonidagi safaringiz uchun internet. Bron tayyor bo‘lgach, faollashtirish ilovada paydo bo‘ladi."
        case .uzbekCyrillic: return "Саудия Арабистонидаги сафарингиз учун интернет. Брон тайёр бўлгач, фаоллаштириш иловада пайдо бўлади."
        }
    }

    private var esimToggleTitle: String {
        switch settings.language {
        case .russian: return "Включить eSIM в поездку"
        case .english: return "Include eSIM in this trip"
        case .uzbek: return "eSIM’ni safarga qo‘shish"
        case .uzbekCyrillic: return "eSIM’ни сафарга қўшиш"
        }
    }

    private var esimToggleSubtitle: String {
        switch settings.language {
        case .russian: return esimIncluded ? "Включена в пакет" : "Будет исключена после подтверждения"
        case .english: return esimIncluded ? "Included in your package" : "Will be removed after confirmation"
        case .uzbek: return esimIncluded ? "Paketga kiritilgan" : "Tasdiqdan keyin olib tashlanadi"
        case .uzbekCyrillic: return esimIncluded ? "Пакетга киритилган" : "Тасдиқдан кейин олиб ташланади"
        }
    }

    private var esimConfirmationNote: String {
        switch settings.language {
        case .russian: return "После сохранения изменения потребуется отправить запрос на подтверждение — так же, как при изменении зияратов."
        case .english: return "After saving, this change must be submitted for confirmation just like a ziyarat change."
        case .uzbek: return "Saqlagandan keyin bu o‘zgarish ziyoratdagi kabi tasdiqlash uchun yuboriladi."
        case .uzbekCyrillic: return "Сақлагандан кейин бу ўзгариш зиёратдаги каби тасдиқлаш учун юборилади."
        }
    }

    private func contactCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.text("booking_contacts", settings.language))
                    .font(.headline)
                Spacer()
                Button {
                    showContactEdit = true
                } label: {
                    Label(L10n.text("booking_contact_edit", settings.language), systemImage: "pencil")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if let telegram = session.telegram, !telegram.isEmpty {
                summaryRow(title: "Telegram", value: telegram)
            }
            if let whatsapp = session.whatsapp, !whatsapp.isEmpty {
                summaryRow(title: "WhatsApp", value: whatsapp)
            }
            if (session.telegram ?? "").isEmpty && (session.whatsapp ?? "").isEmpty {
                Text(L10n.text("booking_contact_empty", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func confirmationCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: confirmationSent ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 27, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    Text(confirmationSent ? L10n.text("booking_request_sent", settings.language) : L10n.text("booking_changes_pending_title", settings.language))
                        .font(.headline)
                    Text(L10n.text("booking_changes_pending_body", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if session.pendingChangeConfirmation == true {
                Button {
                    Task { await requestConfirmation() }
                } label: {
                    HStack {
                        if isRequestingConfirmation { ProgressView().tint(.white) }
                        Text(L10n.text("booking_request_confirmation", settings.language))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isRequestingConfirmation)
            }
        }
        .padding(18)
        .background(Color.iumrahCareLight.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.iumrahCareLight.opacity(0.28), lineWidth: 1)
        }
    }

    private var bookingCareBalanceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("CarePriceSupport")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color.black)

            VStack(alignment: .leading, spacing: 10) {
                Text(bookingCareBalanceTitle)
                    .font(.headline)
                Text(bookingCareBalanceBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    showPackageCareExplanation = true
                    IumrahHaptics.soft()
                } label: {
                    HStack {
                        Text(bookingCareHowItWorks)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            }
            .padding(17)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var bookingCareBalanceTitle: String {
        switch settings.language {
        case .russian: return "iumrah Care проверит баланс вашей поездки"
        case .english: return "iumrah Care will review your journey balance"
        case .uzbek: return "iumrah Care safaringiz muvozanatini tekshiradi"
        case .uzbekCyrillic: return "iumrah Care сафарингиз мувозанатини текширади"
        }
    }

    private var bookingCareBalanceBody: String {
        switch settings.language {
        case .russian: return "Цена этой поездки выше обычного ориентира. До окончательного оформления мы дополнительно проверим более удобные рейсы, распределение ночей и сопоставимые отели, чтобы стабилизировать поездку без потери качества."
        case .english: return "This trip is above our usual reference range. Before final ticketing we will review more convenient flights, night allocation and comparable hotels to stabilize the journey without compromising quality."
        case .uzbek: return "Bu safar odatiy mo‘ljaldan yuqoriroq. Yakuniy rasmiylashtirishdan oldin qulayroq reyslar, tunlar taqsimoti va mos mehmonxonalar yana tekshiriladi."
        case .uzbekCyrillic: return "Бу сафар одатий мўлжалдан юқорироқ. Якуний расмийлаштиришдан олдин қулайроқ рейслар, тунлар тақсимоти ва мос меҳмонхоналар яна текширилади."
        }
    }

    private var bookingCareHowItWorks: String {
        switch settings.language {
        case .russian: return "Как это работает"
        case .english: return "How it works"
        case .uzbek: return "Qanday ishlaydi"
        case .uzbekCyrillic: return "Қандай ишлайди"
        }
    }

    private var careAction: some View {
        NavigationLink {
            BookingChatView(bookingID: bookingID)
        } label: {
            HStack(spacing: 15) {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .padding(9)
                    .frame(width: 58, height: 58)
                    .background(.white, in: Circle())
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("iumrah Care")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(L10n.text("booking_care_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.text("booking_open_care", settings.language))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.top, 2)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.iumrahCareDark.opacity(0.96), Color.iumrahCareLight.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var destructiveActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let deleteError {
                Text(deleteError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    if isDeleting { ProgressView().tint(.red) }
                    Text(L10n.text("booking_cancel_and_delete", settings.language))
                    Spacer()
                    Image(systemName: "trash")
                }
                .font(.headline)
                .foregroundStyle(.red)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Color.red.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .disabled(isDeleting)
        }
    }

    private func serviceHeader(icon: String, title: String, subtitle: String, badge: String?) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(Color.iumrahCareLight.opacity(0.16), in: Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func serviceRouteRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.iumrahRaisedBackground, in: Circle())
            Text(text)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.iumrahCareLight)
        }
    }

    private func servicePill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func currentZiyaratMakkah(_ session: StoredBookingSession) -> Bool {
        session.ziyaratMakkahOverride ?? session.booking.customization?.ziyaratMakkah ?? true
    }

    private func currentZiyaratMadinah(_ session: StoredBookingSession) -> Bool {
        session.ziyaratMadinahOverride ?? session.booking.customization?.ziyaratMadinah ?? session.booking.input.includeMadinah
    }

    private func currentESIM(_ session: StoredBookingSession) -> Bool {
        session.esimOverride ?? session.booking.customization?.esim ?? true
    }

    private func loadESIMDraft() {
        guard let session else { return }
        esimIncluded = currentESIM(session)
    }

    @MainActor
    private func saveESIM() async {
        guard !isSavingESIM else { return }
        isSavingESIM = true
        mutationError = nil
        defer { isSavingESIM = false }
        do {
            try await bookings.updateESIM(bookingID: bookingID, enabled: esimIncluded)
            IumrahHaptics.success()
        } catch {
            mutationError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    private func loadZiyaratDraft() {
        guard let session else { return }
        ziyaratMakkah = currentZiyaratMakkah(session)
        ziyaratMadinah = currentZiyaratMadinah(session)
    }

    @MainActor
    private func saveZiyarat() async {
        guard !isSavingZiyarat else { return }
        isSavingZiyarat = true
        mutationError = nil
        defer { isSavingZiyarat = false }
        do {
            try await bookings.updateZiyarat(
                bookingID: bookingID,
                makkah: ziyaratMakkah,
                madinah: session?.booking.input.includeMadinah == true ? ziyaratMadinah : false
            )
            IumrahHaptics.success()
        } catch {
            mutationError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func requestConfirmation() async {
        guard !isRequestingConfirmation else { return }
        isRequestingConfirmation = true
        mutationError = nil
        defer { isRequestingConfirmation = false }
        do {
            try await bookings.requestChangeConfirmation(
                bookingID: bookingID,
                message: L10n.text("booking_change_confirmation_message", settings.language)
            )
            confirmationSent = true
            IumrahHaptics.success()
        } catch {
            mutationError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func deleteBooking() async {
        guard !isDeleting else { return }
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        do {
            try await bookings.deleteBooking(id: bookingID)
            IumrahHaptics.success()
            dismiss()
        } catch {
            deleteError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }
}

private struct BookingContactEditSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String
    @State private var telegram: String
    @State private var whatsapp: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(bookingID: String, telegram: String, whatsapp: String) {
        self.bookingID = bookingID
        _telegram = State(initialValue: telegram)
        _whatsapp = State(initialValue: whatsapp)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.text("booking_contact_edit_title", settings.language))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(L10n.text("booking_contact_edit_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("Telegram", text: $telegram)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(Color.iumrahRaisedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    TextField("WhatsApp", text: $whatsapp)
                        .keyboardType(.phonePad)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(Color.iumrahRaisedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text(L10n.text("booking_save_changes", settings.language))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isSaving || (telegram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && whatsapp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                Spacer()
            }
            .padding(20)
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Color.iumrahRaisedBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await bookings.updateContacts(bookingID: bookingID, telegram: telegram, whatsapp: whatsapp)
            IumrahHaptics.success()
            dismiss()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }
}

private struct BookingFlightDisclosureCard: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let title: String
    let route: String
    let date: String
    let fallbackFlight: String
    let offer: FlightOffer?
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 13) {
                    AirlineLogoView(airlineCode: offer?.primaryAirlineCode ?? fallbackAirlineCode, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(route)
                            .font(.title3.weight(.bold))
                        Text(offer.map { "\($0.airlinesSummary) · \($0.flightNumbersSummary)" } ?? fallbackFlight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                Text(L10n.date(date, settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isExpanded ? L10n.text("collapse", settings.language) : L10n.text("expand", settings.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if isExpanded {
                Divider()
                if let offer {
                    offerDetails(offer)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(fallbackFlight)
                            .font(.subheadline.weight(.semibold))
                        Text(L10n.text("booking_legacy_flight_note", settings.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .iumrahCard()
    }

    private var fallbackAirlineCode: String? {
        let pattern = #"\b([A-Z0-9]{2})[\s-]?\d{1,4}\b"#
        guard let range = fallbackFlight.uppercased().range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(fallbackFlight.uppercased()[range])
        return FlightReferenceCatalog.airlineCode(from: match)
    }

    private func offerDetails(_ offer: FlightOffer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(offer.displaySegments.enumerated()), id: \.element.id) { index, segment in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(FlightReferenceCatalog.airlineName(code: segment.airlineCode, fallback: segment.airline)) · \(segment.flightNumber)")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text(durationText(segment.durationMinutes))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(segment.origin.code)
                                .font(.title3.weight(.bold))
                            Text(segment.origin.displayCity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "airplane")
                            .foregroundStyle(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(segment.destination.code)
                                .font(.title3.weight(.bold))
                            Text(segment.destination.displayCity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text(time(segment.departureAt, zone: segment.origin.timeZoneIdentifier))
                        Spacer()
                        Text(time(segment.arrivalAt, zone: segment.destination.timeZoneIdentifier))
                    }
                    .font(.subheadline.monospacedDigit().weight(.semibold))

                    if let terminal = segment.origin.terminal {
                        detailLine(L10n.text("flight_departure_terminal", settings.language), terminal)
                    }
                    if let terminal = segment.destination.terminal {
                        detailLine(L10n.text("flight_arrival_terminal", settings.language), terminal)
                    }
                    if let aircraft = segment.aircraft {
                        detailLine(L10n.text("flight_detail_aircraft", settings.language), aircraft)
                    }
                    if let cabin = segment.cabin {
                        detailLine(L10n.text("flight_detail_cabin", settings.language), cabin)
                    }
                }

                if index < offer.layovers.count {
                    let layover = offer.layovers[index]
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.format("flight_layover_title", settings.language, layover.airport.displayCity))
                                .font(.subheadline.weight(.semibold))
                            Text(durationText(layover.durationMinutes))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
    }

    private func durationText(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return L10n.format("flight_minutes_short", settings.language, m) }
        if m == 0 { return L10n.format("flight_hours_short", settings.language, h) }
        return L10n.format("flight_duration_short", settings.language, h, m)
    }

    private func time(_ date: Date, zone: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let zone, let timeZone = TimeZone(identifier: zone) { formatter.timeZone = timeZone }
        return formatter.string(from: date)
    }
}

func statusIcon(_ status: String) -> String {
    IumrahBookingStatusVisual.symbol(for: status)
}


private struct BookingPullDistancePreferenceKey: PreferenceKey {
    // nil means the marker has not been measured yet. This deliberately fails
    // closed so a drag can never arm before SwiftUI reports the real scroll
    // position. There is one marker, so the latest concrete value is exact.
    static var defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() {
            value = next
        }
    }
}


private enum BookingDetailLifecyclePhase {
    case availability(Date)
    case priceLock(Date)
    case paymentConfirmation(Date)
    case documents(Date)

    var deadline: Date {
        switch self {
        case .availability(let date), .priceLock(let date), .paymentConfirmation(let date), .documents(let date):
            return date
        }
    }

    var symbol: String {
        switch self {
        case .availability: return "hourglass"
        case .priceLock: return "lock.fill"
        case .paymentConfirmation: return "checkmark.seal.fill"
        case .documents: return "doc.text.fill"
        }
    }
}
