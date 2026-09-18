import SwiftUI
import Foundation
import MapKit
import UserNotifications
import UIKit

struct IumrahFlightsView: View {
    let preferredBookingID: String?

    init(preferredBookingID: String? = nil) {
        self.preferredBookingID = preferredBookingID
    }

    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.dismiss) private var dismiss

    @State private var flightQuery = ""
    @State private var notificationScheduled = false
    @State private var notificationPermissionDenied = false

    private var accessSession: StoredBookingSession? {
        if let preferredBookingID,
           let preferred = bookings.sessions.first(where: { $0.id == preferredBookingID }),
           IumrahFlightsAccess.isEligible(preferred) {
            return preferred
        }
        return bookings.sessions.first(where: IumrahFlightsAccess.isEligible)
    }

    private var hasAccess: Bool { accessSession != nil }

    private var primaryFlight: FlightOffer? {
        accessSession?.outboundFlight ?? accessSession?.inboundFlight
    }

    private var tripFlights: [FlightOffer] {
        guard let accessSession else { return [] }
        return [accessSession.outboundFlight, accessSession.inboundFlight].compactMap { $0 }
    }

    private var filteredTripFlights: [FlightOffer] {
        let query = flightQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return tripFlights }
        return tripFlights.filter { offer in
            [offer.airline, offer.flightNumber, offer.origin, offer.destination, offer.flightNumbersSummary]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                globeHero

                VStack(spacing: 20) {
                    flightIntelligenceCard
                    notificationDemoCard
                    tripFlightSearchCard
                    friendsCard
                    accessPrincipleCard
                    flightsWordmarkFooter
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 22)
                .padding(.bottom, 50)
            }
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .iumrahInternalNavigation()
        .alert(
            IumrahFlightsCopy.text(.notificationsDisabledTitle, settings.language),
            isPresented: $notificationPermissionDenied
        ) {
            Button(IumrahFlightsCopy.text(.openSettings, settings.language)) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button(IumrahFlightsCopy.text(.cancel, settings.language), role: .cancel) {}
        } message: {
            Text(IumrahFlightsCopy.text(.notificationsDisabledBody, settings.language))
        }
    }

    // MARK: - Hero

    private var globeHero: some View {
        VStack(spacing: 0) {
            Text("iumrah Flights")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.9)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ZStack(alignment: .bottom) {
                IumrahInteractiveGlobe(presentation: .flightRoute)
                    .frame(height: 520)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.00),
                                .init(color: .black, location: 0.08),
                                .init(color: .black, location: 0.70),
                                .init(color: .clear, location: 1.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                LinearGradient(
                    stops: [
                        .init(color: Color.iumrahPageBackground.opacity(0.00), location: 0.00),
                        .init(color: Color.iumrahPageBackground.opacity(0.08), location: 0.46),
                        .init(color: Color.iumrahPageBackground.opacity(0.78), location: 0.70),
                        .init(color: Color.iumrahPageBackground, location: 0.88),
                        .init(color: Color.iumrahPageBackground, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 560)
                .allowsHitTesting(false)

                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Text(IumrahFlightsCopy.text(.heroTitle, settings.language))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .tracking(-1.0)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(IumrahFlightsCopy.text(.heroBody, settings.language))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    accessBadge
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
                .allowsHitTesting(false)
            }
            .frame(height: 590)
            .clipped()
        }
        .background(Color.iumrahPageBackground)
    }

    private var accessBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: hasAccess ? "checkmark.circle.fill" : "lock.fill")
            Text(
                hasAccess
                    ? IumrahFlightsCopy.text(.accessActive, settings.language)
                    : IumrahFlightsCopy.text(.accessLocked, settings.language)
            )
            .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .iumrahGlass(in: Capsule())
    }

    // MARK: - Flight intelligence

    private var flightIntelligenceCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionEyebrow(
                icon: "airplane.circle.fill",
                text: IumrahFlightsCopy.text(.liveEyebrow, settings.language)
            )

            Text(IumrahFlightsCopy.text(.liveTitle, settings.language))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.6)

            Text(IumrahFlightsCopy.text(.liveBody, settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            flightStatusPreview

            HStack(spacing: 10) {
                featurePill(icon: "clock.badge.exclamationmark", text: IumrahFlightsCopy.text(.featureDelay, settings.language))
                featurePill(icon: "rectangle.portrait.and.arrow.right", text: IumrahFlightsCopy.text(.featureGate, settings.language))
                featurePill(icon: "bell.badge.fill", text: IumrahFlightsCopy.text(.featureAlerts, settings.language))
            }
        }
        .darkCard()
    }

    private var flightStatusPreview: some View {
        let offer = primaryFlight
        let origin = offer?.origin ?? "TAS"
        let destination = offer?.destination ?? "JED"
        let airline = offer?.airline ?? "Uzbekistan Airways"
        let flightNumber = offer?.flightNumber ?? "HY123"

        return VStack(spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(airline)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(flightNumber)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(hasAccess ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(
                        hasAccess
                            ? IumrahFlightsCopy.text(.monitoring, settings.language)
                            : IumrahFlightsCopy.text(.demo, settings.language)
                    )
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 14) {
                airportCode(origin)

                VStack(spacing: 7) {
                    Image(systemName: "airplane")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.primary.opacity(0.12), .blue.opacity(0.85), Color.primary.opacity(0.12)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                }
                .frame(maxWidth: .infinity)

                airportCode(destination)
            }

            if let offer {
                HStack {
                    statusMetric(
                        title: IumrahFlightsCopy.text(.departure, settings.language),
                        value: timeText(offer.departureAt)
                    )
                    Spacer()
                    statusMetric(
                        title: IumrahFlightsCopy.text(.arrival, settings.language),
                        value: timeText(offer.arrivalAt),
                        alignment: .trailing
                    )
                }
            } else {
                HStack {
                    statusMetric(title: IumrahFlightsCopy.text(.departure, settings.language), value: "22:50")
                    Spacer()
                    statusMetric(title: IumrahFlightsCopy.text(.arrival, settings.language), value: "02:25", alignment: .trailing)
                }
            }
        }
        .padding(18)
        .background(Color.iumrahRaisedBackground.opacity(0.62), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private func airportCode(_ code: String) -> some View {
        Text(code.uppercased())
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(.primary)
    }

    private func statusMetric(title: String, value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
        }
    }

    // MARK: - Notification demo

    private var notificationDemoCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionEyebrow(icon: "bell.fill", text: IumrahFlightsCopy.text(.notificationEyebrow, settings.language))

            Text(IumrahFlightsCopy.text(.notificationTitle, settings.language))
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.5)

            Text(IumrahFlightsCopy.text(.notificationBody, settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            notificationPreview

            Button {
                IumrahHaptics.soft()
                Task { await sendDemoNotification() }
            } label: {
                HStack {
                    Image(systemName: notificationScheduled ? "checkmark.circle.fill" : "bell.badge.fill")
                    Text(
                        notificationScheduled
                            ? IumrahFlightsCopy.text(.notificationSent, settings.language)
                            : IumrahFlightsCopy.text(.notificationButton, settings.language)
                    )
                    Spacer()
                    if !notificationScheduled {
                        Image(systemName: "arrow.up.right")
                    }
                }
                .font(.headline)
                .foregroundStyle(Color.iumrahPrimaryButtonText)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .darkCard()
    }

    private var notificationPreview: some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(
                systemName: "airplane",
                role: .travel,
                size: 42,
                symbolSize: 18,
                cornerRadius: 13
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("iumrah Flights")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(IumrahFlightsCopy.text(.now, settings.language))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(IumrahFlightsCopy.text(.sampleNotificationTitle, settings.language))
                    .font(.subheadline.weight(.bold))
                Text(IumrahFlightsCopy.text(.sampleNotificationBody, settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Active-trip-only search

    private var tripFlightSearchCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                sectionEyebrow(icon: "magnifyingglass", text: IumrahFlightsCopy.text(.searchEyebrow, settings.language))
                Spacer()
                Image(systemName: hasAccess ? "checkmark.shield.fill" : "lock.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(hasAccess ? .green : .secondary)
            }

            Text(IumrahFlightsCopy.text(.searchTitle, settings.language))
                .font(.system(size: 29, weight: .bold, design: .rounded))

            Text(
                hasAccess
                    ? IumrahFlightsCopy.text(.searchUnlockedBody, settings.language)
                    : IumrahFlightsCopy.text(.searchLockedBody, settings.language)
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 11) {
                Image(systemName: hasAccess ? "magnifyingglass" : "lock.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField(IumrahFlightsCopy.text(.searchPlaceholder, settings.language), text: $flightQuery)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .disabled(!hasAccess)
                    .foregroundStyle(.primary)
                if !flightQuery.isEmpty, hasAccess {
                    Button {
                        flightQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)

            if hasAccess {
                activeTripFlightResults
            } else {
                lockedSearchPreview
            }
        }
        .darkCard()
    }

    @ViewBuilder
    private var activeTripFlightResults: some View {
        if filteredTripFlights.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                Text(IumrahFlightsCopy.text(.searchNoMatch, settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 10) {
                ForEach(filteredTripFlights.prefix(2)) { offer in
                    HStack(spacing: 13) {
                        IumrahIconBadge(
                            systemName: offer.direction == .outbound ? "airplane.departure" : "airplane.arrival",
                            role: .travel,
                            size: 46,
                            symbolSize: 18,
                            cornerRadius: 15
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(offer.flightNumber)
                                .font(.headline.monospaced())
                            Text("\(offer.origin) → \(offer.destination) · \(offer.airline)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    .padding(12)
                    .background(Color.iumrahRaisedBackground.opacity(0.54), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
    }

    private var lockedSearchPreview: some View {
        VStack(spacing: 0) {
            lockedRow(icon: "airplane", title: "Uzbekistan Airways", subtitle: "HY • TAS")
            Divider().overlay(Color.primary.opacity(0.07))
            lockedRow(icon: "building.2.fill", title: "Tashkent", subtitle: "TAS • Tashkent International Airport")
            Divider().overlay(Color.primary.opacity(0.07))
            lockedRow(icon: "mappin.and.ellipse", title: "Jeddah", subtitle: "JED • King Abdulaziz International Airport")
        }
        .opacity(0.54)
        .overlay(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                Text(IumrahFlightsCopy.text(.activeTripsOnly, settings.language))
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(Color.iumrahCardBackground.opacity(0.94), in: Capsule())
            .overlay { Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1) }
        }
    }

    private func lockedRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            IumrahIconBadge(
                systemName: icon,
                size: 42,
                symbolSize: 17,
                cornerRadius: 14
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 11)
    }

    // MARK: - Friends

    private var friendsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                sectionEyebrow(icon: "person.2.fill", text: "iumrah Friends")
                Spacer()
                friendAvatars
            }

            Text(IumrahFlightsCopy.text(.friendsTitle, settings.language))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.6)

            Text(IumrahFlightsCopy.text(.friendsBody, settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                friendStatus(icon: "clock.badge.exclamationmark", title: IumrahFlightsCopy.text(.friendDelay, settings.language), value: "+15 min")
                friendDivider
                friendStatus(icon: "person.crop.circle.badge.checkmark", title: IumrahFlightsCopy.text(.friendBoarding, settings.language), value: "22:35")
                friendDivider
                friendStatus(icon: "airplane.arrival", title: IumrahFlightsCopy.text(.friendArrival, settings.language), value: "02:25")
                friendDivider
                friendStatus(icon: "figure.walk", title: IumrahFlightsCopy.text(.friendAirportExit, settings.language), value: IumrahFlightsCopy.text(.live, settings.language))
                friendDivider
                friendStatus(icon: "moon.stars.fill", title: IumrahFlightsCopy.text(.friendUmrah, settings.language), value: "05:20")
            }
            .padding(.horizontal, 15)
            .background(Color.iumrahRaisedBackground.opacity(0.54), in: RoundedRectangle(cornerRadius: 25, style: .continuous))

            Label(IumrahFlightsCopy.text(.friendsPrivacy, settings.language), systemImage: "hand.raised.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .darkCard()
    }

    private var friendAvatars: some View {
        HStack(spacing: -9) {
            friendAvatar("A")
            friendAvatar("M")
            friendAvatar("S")
        }
    }

    private func friendAvatar(_ initial: String) -> some View {
        Text(initial)
            .font(.caption.weight(.bold))
            .frame(width: 34, height: 34)
            .foregroundStyle(.primary)
            .background(
                LinearGradient(colors: [.blue.opacity(0.95), .purple.opacity(0.90)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle()
            )
            .overlay { Circle().strokeBorder(Color.iumrahCardBackground, lineWidth: 2) }
    }

    private func friendStatus(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            IumrahIconBadge(
                systemName: icon,
                role: .travel,
                size: 34,
                symbolSize: 15,
                shape: .circle
            )
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private var friendDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.065))
            .frame(height: 1)
            .padding(.leading, 46)
    }

    // MARK: - Product positioning

    private var accessPrincipleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahIconBadge(
                systemName: "checkmark.shield.fill",
                role: .security,
                size: 58,
                symbolSize: 27,
                cornerRadius: 20
            )

            Text(IumrahFlightsCopy.text(.principleTitle, settings.language))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.6)

            Text(IumrahFlightsCopy.text(.principleBody, settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let accessSession {
                Label(
                    "\(IumrahFlightsCopy.text(.connectedToTrip, settings.language)) \(accessSession.displayBookingNumber)",
                    systemImage: "link.circle.fill"
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
            } else {
                Button {
                    IumrahHaptics.selection()
                    dismiss()
                    DispatchQueue.main.async {
                        chrome.startNewTrip()
                    }
                } label: {
                    HStack {
                        Text(IumrahFlightsCopy.text(.buildTrip, settings.language))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(Color.iumrahPrimaryButtonText)
                    .padding(.horizontal, 18)
                    .frame(height: 56)
                    .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.18), Color.indigo.opacity(0.09), Color.iumrahCardBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var flightsWordmarkFooter: some View {
        Image("IumrahFlightsWordmark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.primary)
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 6)
            .accessibilityLabel("iumrah Flights")
            .allowsHitTesting(false)
    }

    // MARK: - Shared UI

    private func sectionEyebrow(icon: String, text: String) -> some View {
        Label(text.uppercased(), systemImage: icon)
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    private func featurePill(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.blue)
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(Color.iumrahRaisedBackground.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    @MainActor
    private func sendDemoNotification() async {
        let center = UNUserNotificationCenter.current()
        var notificationSettings = await center.notificationSettings()

        if notificationSettings.authorizationStatus == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                notificationSettings = await center.notificationSettings()
            } catch {
                notificationPermissionDenied = true
                return
            }
        }

        switch notificationSettings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            notificationPermissionDenied = true
            return
        }

        let content = UNMutableNotificationContent()
        content.title = IumrahFlightsCopy.text(.localNotificationTitle, settings.language)
        content.body = IumrahFlightsCopy.text(.localNotificationBody, settings.language)
        content.sound = .default
        content.userInfo = ["type": "iumrah_flights_demo"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "iumrah-flights-demo-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            notificationScheduled = true
            IumrahHaptics.success()
        } catch {
            notificationPermissionDenied = true
        }
    }
}

private enum IumrahFlightsAccess {
    static func isEligible(_ session: StoredBookingSession) -> Bool {
        switch session.effectiveStatus.uppercased() {
        case "BOOKING_CONFIRMED", "READY_TO_TRAVEL", "IN_TRIP":
            return true
        default:
            return false
        }
    }
}

private struct IumrahFlightsDarkCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.065), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.07), radius: 24, y: 12)
    }
}

private extension View {
    func darkCard() -> some View {
        modifier(IumrahFlightsDarkCard())
    }
}

private enum IumrahFlightsCopyKey {
    case back
    case heroTitle
    case heroBody
    case accessActive
    case accessLocked
    case liveEyebrow
    case liveTitle
    case liveBody
    case featureDelay
    case featureGate
    case featureAlerts
    case monitoring
    case demo
    case departure
    case arrival
    case notificationEyebrow
    case notificationTitle
    case notificationBody
    case notificationButton
    case notificationSent
    case now
    case sampleNotificationTitle
    case sampleNotificationBody
    case localNotificationTitle
    case localNotificationBody
    case notificationsDisabledTitle
    case notificationsDisabledBody
    case openSettings
    case cancel
    case searchEyebrow
    case searchTitle
    case searchUnlockedBody
    case searchLockedBody
    case searchPlaceholder
    case searchNoMatch
    case activeTripsOnly
    case friendsTitle
    case friendsBody
    case friendDelay
    case friendBoarding
    case friendArrival
    case friendAirportExit
    case friendUmrah
    case friendsPrivacy
    case live
    case principleTitle
    case principleBody
    case connectedToTrip
    case buildTrip
    case homeAccessibility
}

private enum IumrahFlightsCopy {
    static func text(_ key: IumrahFlightsCopyKey, _ language: AppSettingsStore.Language) -> String {
        switch (language, key) {
        case (.russian, .back): return "Назад"
        case (.russian, .heroTitle): return "Ваш рейс — часть поездки"
        case (.russian, .heroBody): return "iumrah Flights держит ключевые этапы перелёта рядом с вашей Umrah-поездкой: расписание, задержки и важные изменения."
        case (.russian, .accessActive): return "Подключено к активной поездке"
        case (.russian, .accessLocked): return "Доступно для активных поездок"
        case (.russian, .liveEyebrow): return "СТАТУС РЕЙСА"
        case (.russian, .liveTitle): return "Знайте, что происходит с рейсом"
        case (.russian, .liveBody): return "Не отдельный трекер для любопытства, а часть вашей поездки в iumrah. Когда маршрут оформлен, Flights помогает следить за самым важным по пути."
        case (.russian, .featureDelay): return "Задержка"
        case (.russian, .featureGate): return "Посадка"
        case (.russian, .featureAlerts): return "Уведомления"
        case (.russian, .monitoring): return "МОНИТОРИНГ"
        case (.russian, .demo): return "ПРИМЕР"
        case (.russian, .departure): return "Вылет"
        case (.russian, .arrival): return "Прибытие"
        case (.russian, .notificationEyebrow): return "ТОЧНЫЕ УВЕДОМЛЕНИЯ"
        case (.russian, .notificationTitle): return "Изменение рейса приходит к вам само"
        case (.russian, .notificationBody): return "Проверьте, как выглядит уведомление iumrah Flights. Кнопка ниже отправит тестовый пример прямо на этот iPhone."
        case (.russian, .notificationButton): return "Посмотреть уведомление"
        case (.russian, .notificationSent): return "Уведомление отправлено"
        case (.russian, .now): return "сейчас"
        case (.russian, .sampleNotificationTitle): return "HY123 задерживается на 15 минут"
        case (.russian, .sampleNotificationBody): return "Uzbekistan Airways · новый вылет в 23:05. Мы продолжим следить за рейсом."
        case (.russian, .localNotificationTitle): return "iumrah Flights · пример"
        case (.russian, .localNotificationBody): return "Uzbekistan Airways HY123 задерживается на 15 минут. Новый вылет — 23:05."
        case (.russian, .notificationsDisabledTitle): return "Уведомления отключены"
        case (.russian, .notificationsDisabledBody): return "Разрешите уведомления для iumrah в настройках iPhone, чтобы увидеть тестовый пример Flights."
        case (.russian, .openSettings): return "Открыть настройки"
        case (.russian, .cancel): return "Отмена"
        case (.russian, .searchEyebrow): return "ПОИСК РЕЙСА"
        case (.russian, .searchTitle): return "Рейсы только внутри вашей поездки"
        case (.russian, .searchUnlockedBody): return "Flights уже связан с оформленной поездкой. Найдите один из рейсов по номеру, авиакомпании или аэропорту."
        case (.russian, .searchLockedBody): return "Поиск рейса открывается только для оформленных активных поездок iumrah. Без поездки это не публичный flight tracker."
        case (.russian, .searchPlaceholder): return "Uzbekistan Airways, HY123 или TAS"
        case (.russian, .searchNoMatch): return "В активной поездке нет рейса, совпадающего с этим запросом."
        case (.russian, .activeTripsOnly): return "Доступно для активных поездок"
        case (.russian, .friendsTitle): return "Ваши близкие понимают, где вы в поездке"
        case (.russian, .friendsBody): return "Люди, которых вы добавите в iumrah Friends, смогут видеть выбранные вами этапы поездки: задержку, посадку, прибытие, выход из аэропорта и время Umrah."
        case (.russian, .friendDelay): return "Рейс задерживается"
        case (.russian, .friendBoarding): return "Посадка началась"
        case (.russian, .friendArrival): return "Прибытие в Jeddah"
        case (.russian, .friendAirportExit): return "Выход из аэропорта"
        case (.russian, .friendUmrah): return "Планируемое время Umrah"
        case (.russian, .friendsPrivacy): return "Вы сами решаете, кого добавить и какие этапы поездки показывать."
        case (.russian, .live): return "LIVE"
        case (.russian, .principleTitle): return "iumrah Flights начинается с поездки, а не с поиска"
        case (.russian, .principleBody): return "Функция предназначена для паломников, которые оформили поездку через iumrah. Рейс становится частью единой поездки вместе с отелями, трансфером, Care и другими сервисами."
        case (.russian, .connectedToTrip): return "Подключено к поездке"
        case (.russian, .buildTrip): return "Собрать Umrah-поездку"
        case (.russian, .homeAccessibility): return "Открыть iumrah Flights"

        case (.english, .back): return "Back"
        case (.english, .heroTitle): return "Your flight belongs to your journey"
        case (.english, .heroBody): return "iumrah Flights keeps the important parts of your flight next to your Umrah journey: schedule, delays and meaningful changes."
        case (.english, .accessActive): return "Connected to an active trip"
        case (.english, .accessLocked): return "Available for active trips"
        case (.english, .liveEyebrow): return "FLIGHT STATUS"
        case (.english, .liveTitle): return "Know what is happening with your flight"
        case (.english, .liveBody): return "Not a public tracker for curiosity. It is part of your iumrah journey. Once a trip is booked, Flights keeps the most important flight changes close."
        case (.english, .featureDelay): return "Delay"
        case (.english, .featureGate): return "Boarding"
        case (.english, .featureAlerts): return "Alerts"
        case (.english, .monitoring): return "MONITORING"
        case (.english, .demo): return "DEMO"
        case (.english, .departure): return "Departure"
        case (.english, .arrival): return "Arrival"
        case (.english, .notificationEyebrow): return "PRECISE ALERTS"
        case (.english, .notificationTitle): return "Flight changes come to you"
        case (.english, .notificationBody): return "See what an iumrah Flights alert feels like. The button below sends a test example directly to this iPhone."
        case (.english, .notificationButton): return "Preview notification"
        case (.english, .notificationSent): return "Notification sent"
        case (.english, .now): return "now"
        case (.english, .sampleNotificationTitle): return "HY123 is delayed by 15 minutes"
        case (.english, .sampleNotificationBody): return "Uzbekistan Airways · new departure 23:05. We will keep watching the flight."
        case (.english, .localNotificationTitle): return "iumrah Flights · demo"
        case (.english, .localNotificationBody): return "Uzbekistan Airways HY123 is delayed by 15 minutes. New departure — 23:05."
        case (.english, .notificationsDisabledTitle): return "Notifications are off"
        case (.english, .notificationsDisabledBody): return "Allow iumrah notifications in iPhone Settings to preview the Flights alert."
        case (.english, .openSettings): return "Open Settings"
        case (.english, .cancel): return "Cancel"
        case (.english, .searchEyebrow): return "FLIGHT LOOKUP"
        case (.english, .searchTitle): return "Flights inside your trip only"
        case (.english, .searchUnlockedBody): return "Flights is already linked to your booked trip. Find one of its flights by number, airline or airport."
        case (.english, .searchLockedBody): return "Flight lookup unlocks only for booked active iumrah trips. Without a trip, this is not a public flight tracker."
        case (.english, .searchPlaceholder): return "Uzbekistan Airways, HY123 or TAS"
        case (.english, .searchNoMatch): return "No flight in the active trip matches this search."
        case (.english, .activeTripsOnly): return "Available for active trips"
        case (.english, .friendsTitle): return "Your loved ones understand where you are"
        case (.english, .friendsBody): return "People you add to iumrah Friends can see the trip stages you choose to share: delays, boarding, arrival, airport exit and Umrah timing."
        case (.english, .friendDelay): return "Flight delayed"
        case (.english, .friendBoarding): return "Boarding started"
        case (.english, .friendArrival): return "Arrival in Jeddah"
        case (.english, .friendAirportExit): return "Leaving the airport"
        case (.english, .friendUmrah): return "Planned Umrah time"
        case (.english, .friendsPrivacy): return "You decide who is added and which stages of the journey they can see."
        case (.english, .live): return "LIVE"
        case (.english, .principleTitle): return "iumrah Flights starts with a journey, not a search"
        case (.english, .principleBody): return "The feature is designed for pilgrims who booked through iumrah. The flight becomes part of one connected journey alongside hotels, transfer, Care and other services."
        case (.english, .connectedToTrip): return "Connected to trip"
        case (.english, .buildTrip): return "Build an Umrah trip"
        case (.english, .homeAccessibility): return "Open iumrah Flights"

        case (.uzbek, .back): return "Orqaga"
        case (.uzbek, .heroTitle): return "Parvozingiz safaringizning bir qismi"
        case (.uzbek, .heroBody): return "iumrah Flights Umra safaringiz bilan birga parvozning muhim bosqichlarini kuzatadi: jadval, kechikishlar va muhim o‘zgarishlar."
        case (.uzbek, .accessActive): return "Faol safarga ulangan"
        case (.uzbek, .accessLocked): return "Faol safarlar uchun mavjud"
        case (.uzbek, .liveEyebrow): return "PARVOZ HOLATI"
        case (.uzbek, .liveTitle): return "Parvoz bilan nima bo‘layotganini biling"
        case (.uzbek, .liveBody): return "Bu hammaga ochiq tracker emas. Bu iumrah safaringizning bir qismi. Safar rasmiylashtirilgach, Flights eng muhim parvoz o‘zgarishlarini kuzatadi."
        case (.uzbek, .featureDelay): return "Kechikish"
        case (.uzbek, .featureGate): return "Boarding"
        case (.uzbek, .featureAlerts): return "Xabarlar"
        case (.uzbek, .monitoring): return "KUZATUVDA"
        case (.uzbek, .demo): return "NAMUNA"
        case (.uzbek, .departure): return "Uchish"
        case (.uzbek, .arrival): return "Yetib kelish"
        case (.uzbek, .notificationEyebrow): return "ANIQ XABARLAR"
        case (.uzbek, .notificationTitle): return "Parvozdagi o‘zgarish sizga o‘zi keladi"
        case (.uzbek, .notificationBody): return "iumrah Flights xabari qanday ko‘rinishini tekshiring. Pastdagi tugma shu iPhone’ga test xabarini yuboradi."
        case (.uzbek, .notificationButton): return "Xabarni ko‘rish"
        case (.uzbek, .notificationSent): return "Xabar yuborildi"
        case (.uzbek, .now): return "hozir"
        case (.uzbek, .sampleNotificationTitle): return "HY123 15 daqiqaga kechikmoqda"
        case (.uzbek, .sampleNotificationBody): return "Uzbekistan Airways · yangi uchish vaqti 23:05. Parvozni kuzatishda davom etamiz."
        case (.uzbek, .localNotificationTitle): return "iumrah Flights · namuna"
        case (.uzbek, .localNotificationBody): return "Uzbekistan Airways HY123 15 daqiqaga kechikmoqda. Yangi uchish vaqti — 23:05."
        case (.uzbek, .notificationsDisabledTitle): return "Bildirishnomalar o‘chirilgan"
        case (.uzbek, .notificationsDisabledBody): return "Flights test xabarini ko‘rish uchun iPhone sozlamalarida iumrah bildirishnomalariga ruxsat bering."
        case (.uzbek, .openSettings): return "Sozlamalarni ochish"
        case (.uzbek, .cancel): return "Bekor qilish"
        case (.uzbek, .searchEyebrow): return "PARVOZ QIDIRUVI"
        case (.uzbek, .searchTitle): return "Parvozlar faqat safaringiz ichida"
        case (.uzbek, .searchUnlockedBody): return "Flights rasmiylashtirilgan safaringizga ulangan. Parvozni raqam, aviakompaniya yoki aeroport bo‘yicha toping."
        case (.uzbek, .searchLockedBody): return "Parvoz qidiruvi faqat rasmiylashtirilgan faol iumrah safarlarida ochiladi. Safarsiz bu ommaviy flight tracker emas."
        case (.uzbek, .searchPlaceholder): return "Uzbekistan Airways, HY123 yoki TAS"
        case (.uzbek, .searchNoMatch): return "Faol safarda bu so‘rovga mos parvoz topilmadi."
        case (.uzbek, .activeTripsOnly): return "Faol safarlar uchun mavjud"
        case (.uzbek, .friendsTitle): return "Yaqinlaringiz safarning qayerida ekaningizni biladi"
        case (.uzbek, .friendsBody): return "iumrah Friends’ga qo‘shgan yaqinlaringiz siz ulashishni tanlagan bosqichlarni ko‘ra oladi: kechikish, boarding, yetib kelish, aeroportdan chiqish va Umra vaqti."
        case (.uzbek, .friendDelay): return "Parvoz kechikmoqda"
        case (.uzbek, .friendBoarding): return "Boarding boshlandi"
        case (.uzbek, .friendArrival): return "Jeddahga yetib kelish"
        case (.uzbek, .friendAirportExit): return "Aeroportdan chiqish"
        case (.uzbek, .friendUmrah): return "Rejalashtirilgan Umra vaqti"
        case (.uzbek, .friendsPrivacy): return "Kimni qo‘shish va qaysi safar bosqichlarini ko‘rsatishni o‘zingiz tanlaysiz."
        case (.uzbek, .live): return "LIVE"
        case (.uzbek, .principleTitle): return "iumrah Flights qidiruvdan emas, safardan boshlanadi"
        case (.uzbek, .principleBody): return "Funksiya iumrah orqali safar rasmiylashtirgan ziyoratchilar uchun. Parvoz mehmonxona, transfer, Care va boshqa xizmatlar bilan bitta safarning qismiga aylanadi."
        case (.uzbek, .connectedToTrip): return "Safarga ulangan"
        case (.uzbek, .buildTrip): return "Umra safarini tuzish"
        case (.uzbek, .homeAccessibility): return "iumrah Flights’ni ochish"

        case (.uzbekCyrillic, .back): return "Орқага"
        case (.uzbekCyrillic, .heroTitle): return "Парвозингиз сафарингизнинг бир қисми"
        case (.uzbekCyrillic, .heroBody): return "iumrah Flights Умра сафарингиз билан бирга парвознинг муҳим босқичларини кузатади: жадвал, кечикишлар ва муҳим ўзгаришлар."
        case (.uzbekCyrillic, .accessActive): return "Фаол сафарга уланган"
        case (.uzbekCyrillic, .accessLocked): return "Фаол сафарлар учун мавжуд"
        case (.uzbekCyrillic, .liveEyebrow): return "ПАРВОЗ ҲОЛАТИ"
        case (.uzbekCyrillic, .liveTitle): return "Парвоз билан нима бўлаётганини билинг"
        case (.uzbekCyrillic, .liveBody): return "Бу ҳаммага очиқ tracker эмас. Бу iumrah сафарингизнинг бир қисми. Сафар расмийлаштирилгач, Flights энг муҳим парвоз ўзгаришларини кузатади."
        case (.uzbekCyrillic, .featureDelay): return "Кечикиш"
        case (.uzbekCyrillic, .featureGate): return "Boarding"
        case (.uzbekCyrillic, .featureAlerts): return "Хабарлар"
        case (.uzbekCyrillic, .monitoring): return "КУЗАТУВДА"
        case (.uzbekCyrillic, .demo): return "НАМУНА"
        case (.uzbekCyrillic, .departure): return "Учиш"
        case (.uzbekCyrillic, .arrival): return "Етиб келиш"
        case (.uzbekCyrillic, .notificationEyebrow): return "АНИҚ ХАБАРЛАР"
        case (.uzbekCyrillic, .notificationTitle): return "Парвоздаги ўзгариш сизга ўзи келади"
        case (.uzbekCyrillic, .notificationBody): return "iumrah Flights хабари қандай кўринишини текширинг. Пастдаги тугма шу iPhone’га тест хабарини юборади."
        case (.uzbekCyrillic, .notificationButton): return "Хабарни кўриш"
        case (.uzbekCyrillic, .notificationSent): return "Хабар юборилди"
        case (.uzbekCyrillic, .now): return "ҳозир"
        case (.uzbekCyrillic, .sampleNotificationTitle): return "HY123 15 дақиқага кечикмоқда"
        case (.uzbekCyrillic, .sampleNotificationBody): return "Uzbekistan Airways · янги учиш вақти 23:05. Парвозни кузатишда давом этамиз."
        case (.uzbekCyrillic, .localNotificationTitle): return "iumrah Flights · намуна"
        case (.uzbekCyrillic, .localNotificationBody): return "Uzbekistan Airways HY123 15 дақиқага кечикмоқда. Янги учиш вақти — 23:05."
        case (.uzbekCyrillic, .notificationsDisabledTitle): return "Билдиришномалар ўчирилган"
        case (.uzbekCyrillic, .notificationsDisabledBody): return "Flights тест хабарини кўриш учун iPhone созламаларида iumrah билдиришномаларига рухсат беринг."
        case (.uzbekCyrillic, .openSettings): return "Созламаларни очиш"
        case (.uzbekCyrillic, .cancel): return "Бекор қилиш"
        case (.uzbekCyrillic, .searchEyebrow): return "ПАРВОЗ ҚИДИРУВИ"
        case (.uzbekCyrillic, .searchTitle): return "Парвозлар фақат сафарингиз ичида"
        case (.uzbekCyrillic, .searchUnlockedBody): return "Flights расмийлаштирилган сафарингизга уланган. Парвозни рақам, авиакомпания ёки аэропорт бўйича топинг."
        case (.uzbekCyrillic, .searchLockedBody): return "Парвоз қидируви фақат расмийлаштирилган фаол iumrah сафарларида очилади. Сафарсиз бу оммавий flight tracker эмас."
        case (.uzbekCyrillic, .searchPlaceholder): return "Uzbekistan Airways, HY123 ёки TAS"
        case (.uzbekCyrillic, .searchNoMatch): return "Фаол сафарда бу сўровга мос парвоз топилмади."
        case (.uzbekCyrillic, .activeTripsOnly): return "Фаол сафарлар учун мавжуд"
        case (.uzbekCyrillic, .friendsTitle): return "Яқинларингиз сафарнинг қаерида эканингизни билади"
        case (.uzbekCyrillic, .friendsBody): return "iumrah Friends’га қўшган яқинларингиз сиз улашишни танлаган босқичларни кўра олади: кечикиш, boarding, етиб келиш, аэропортдан чиқиш ва Умра вақти."
        case (.uzbekCyrillic, .friendDelay): return "Парвоз кечикмоқда"
        case (.uzbekCyrillic, .friendBoarding): return "Boarding бошланди"
        case (.uzbekCyrillic, .friendArrival): return "Jeddahга етиб келиш"
        case (.uzbekCyrillic, .friendAirportExit): return "Аэропортдан чиқиш"
        case (.uzbekCyrillic, .friendUmrah): return "Режалаштирилган Умра вақти"
        case (.uzbekCyrillic, .friendsPrivacy): return "Кимни қўшиш ва қайси сафар босқичларини кўрсатишни ўзингиз танлайсиз."
        case (.uzbekCyrillic, .live): return "LIVE"
        case (.uzbekCyrillic, .principleTitle): return "iumrah Flights қидирувдан эмас, сафардан бошланади"
        case (.uzbekCyrillic, .principleBody): return "Функция iumrah орқали сафар расмийлаштирган зиёратчилар учун. Парвоз меҳмонхона, трансфер, Care ва бошқа хизматлар билан битта сафарнинг қисмига айланади."
        case (.uzbekCyrillic, .connectedToTrip): return "Сафарга уланган"
        case (.uzbekCyrillic, .buildTrip): return "Умра сафарини тузиш"
        case (.uzbekCyrillic, .homeAccessibility): return "iumrah Flights’ни очиш"
        }
    }
}
