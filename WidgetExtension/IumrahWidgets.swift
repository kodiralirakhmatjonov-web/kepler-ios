import WidgetKit
import SwiftUI
import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

private struct IumrahWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: IumrahWidgetSnapshot
}

private struct IumrahWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> IumrahWidgetEntry {
        IumrahWidgetEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (IumrahWidgetEntry) -> Void) {
        completion(IumrahWidgetEntry(date: Date(), snapshot: context.isPreview ? .preview : IumrahWidgetSharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IumrahWidgetEntry>) -> Void) {
        let now = Date()
        let refresh = Calendar.autoupdatingCurrent.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: [IumrahWidgetEntry(date: now, snapshot: IumrahWidgetSharedStore.load())], policy: .after(refresh)))
    }
}

@main
struct IumrahWidgetsBundle: WidgetBundle {
    var body: some Widget {
        IumrahActiveTripWidget()
        IumrahBookingStatusWidget()
        IumrahPlannedUmrahWidget()
        IumrahIdentityWidget()
        IumrahCountdownWidget()
    }
}

// MARK: - Widget configurations

private struct IumrahActiveTripWidget: Widget {
    let kind = "iumrah.active-trip"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IumrahWidgetProvider()) { entry in
            IumrahActiveTripWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.black }
        }
        .configurationDisplayName("iumrah — поездка")
        .description("Маршрут, даты и статус активной Umrah.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct IumrahBookingStatusWidget: Widget {
    let kind = "iumrah.booking-status"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IumrahWidgetProvider()) { entry in
            IumrahBookingStatusWidgetView(entry: entry)
                .containerBackground(for: .widget) { IumrahWidgetPalette.surface }
        }
        .configurationDisplayName("iumrah — статус")
        .description("Текущий этап бронирования и следующий шаг.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct IumrahPlannedUmrahWidget: Widget {
    let kind = "iumrah.planned-umrah"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IumrahWidgetProvider()) { entry in
            IumrahPlannedUmrahWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.black }
        }
        .configurationDisplayName("Следующая Umrah")
        .description("Обратный отсчёт до запланированной поездки.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct IumrahIdentityWidget: Widget {
    let kind = "iumrah.identity"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IumrahWidgetProvider()) { entry in
            IumrahIdentityWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.black }
        }
        .configurationDisplayName("iumrah ID")
        .description("Быстрый доступ к вашему iumrah ID и QR.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct IumrahCountdownWidget: Widget {
    let kind = "iumrah.countdown"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IumrahWidgetProvider()) { entry in
            IumrahCountdownWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("До Umrah")
        .description("Компактный обратный отсчёт для экрана блокировки.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Active trip

private struct IumrahActiveTripWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: IumrahWidgetEntry

    var body: some View {
        if let booking = entry.snapshot.activeBooking {
            ZStack {
                IumrahPhotoBackdrop(asset: "WidgetMakkahBackground", style: .dark)

                Group {
                    switch family {
                    case .systemSmall:
                        small(booking)
                    case .systemLarge:
                        large(booking)
                    default:
                        medium(booking)
                    }
                }
                .padding(family == .systemSmall ? 12 : 18)
            }
            .widgetURL(IumrahWidgetDeepLink.booking(booking.id))
        } else {
            IumrahPremiumEmptyState(
                icon: "airplane.departure",
                title: IumrahWidgetL10n.noActiveTrip,
                subtitle: IumrahWidgetL10n.openIumrah,
                dark: true
            )
            .widgetURL(URL(string: "iumrah://widget/account"))
        }
    }

    private func small(_ booking: IumrahWidgetBookingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            IumrahPremiumWordmark(inverted: true)
            Spacer(minLength: 8)

            Text("\(daysUntil(booking.startDate))")
                .font(.system(size: 43, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.68)
            Text(IumrahWidgetL10n.daysUntilTrip.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.7))

            Spacer(minLength: 10)
            route(booking, size: .compact)
            IumrahStatusPill(status: booking.status, dark: true)
                .padding(.top, 8)
        }
    }

    private func medium(_ booking: IumrahWidgetBookingSnapshot) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                IumrahPremiumWordmark(inverted: true)
                Spacer(minLength: 0)
                Text(IumrahWidgetL10n.activeUmrah)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                route(booking, size: .regular)
                IumrahStatusPill(status: booking.status, dark: true)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(daysUntil(booking.startDate))")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                Text(IumrahWidgetL10n.days)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.68))
                Spacer(minLength: 8)
                if let start = booking.startDate {
                    Label(start.formatted(.dateTime.day().month(.abbreviated)), systemImage: "calendar")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }

    private func large(_ booking: IumrahWidgetBookingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                IumrahPremiumWordmark(inverted: true)
                Spacer()
                IumrahStatusPill(status: booking.status, dark: true)
            }

            Spacer(minLength: 6)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(IumrahWidgetL10n.activeUmrah)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                    route(booking, size: .hero)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: -2) {
                    Text("\(daysUntil(booking.startDate))")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(IumrahWidgetL10n.daysUntilTrip)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            Spacer(minLength: 2)

            HStack(spacing: 8) {
                premiumFact(icon: "suitcase.fill", title: IumrahWidgetL10n.booking, value: booking.displayNumber)
                premiumFact(icon: "person.2.fill", title: IumrahWidgetL10n.travelers, value: "\(booking.travelerCount)")
                if let start = booking.startDate {
                    premiumFact(icon: "calendar", title: IumrahWidgetL10n.departure, value: start.formatted(.dateTime.day().month(.abbreviated)))
                }
            }
        }
    }

    private enum RouteSize { case compact, regular, hero }

    private func route(_ booking: IumrahWidgetBookingSnapshot, size: RouteSize) -> some View {
        HStack(spacing: size == .hero ? 9 : 6) {
            Text(booking.originCode.isEmpty ? "—" : booking.originCode)
            Image(systemName: "arrow.right")
                .font(size == .hero ? .headline.weight(.black) : .caption.weight(.black))
                .foregroundStyle(.white.opacity(0.72))
            Text(booking.destinationCode.isEmpty ? "KSA" : booking.destinationCode)
        }
        .font(routeFont(size))
        .foregroundStyle(.white)
        .lineLimit(1)
    }

    private func routeFont(_ size: RouteSize) -> Font {
        switch size {
        case .compact: return .system(size: 17, weight: .bold, design: .rounded)
        case .regular: return .system(size: 22, weight: .bold, design: .rounded)
        case .hero: return .system(size: 31, weight: .black, design: .rounded)
        }
    }

    private func premiumFact(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
            .textCase(.uppercase)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// MARK: - Booking status

private struct IumrahBookingStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: IumrahWidgetEntry

    var body: some View {
        if let booking = entry.snapshot.activeBooking {
            ZStack {
                IumrahWidgetPalette.surface
                decorativeOrb(status: booking.status)

                VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 12) {
                    HStack(alignment: .center) {
                        IumrahPremiumWordmark(inverted: colorScheme == .dark)
                        Spacer()
                        IumrahStatusIcon(status: booking.status)
                    }

                    Spacer(minLength: 0)

                    Text(IumrahWidgetL10n.status(booking.status))
                        .font(family == .systemSmall
                              ? .system(size: 20, weight: .bold, design: .rounded)
                              : .system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if family == .systemMedium {
                        Text(IumrahWidgetL10n.nextAction(booking.status))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack(spacing: 5) {
                            ForEach(0..<5, id: \.self) { index in
                                Capsule()
                                    .fill(index <= IumrahWidgetPalette.statusIndex(booking.status)
                                          ? IumrahWidgetPalette.statusColor(booking.status)
                                          : Color.secondary.opacity(0.14))
                                    .frame(height: 5)
                            }
                        }
                    } else {
                        Text(booking.displayNumber)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .widgetURL(IumrahWidgetDeepLink.booking(booking.id))
        } else {
            IumrahPremiumEmptyState(icon: "checkmark.seal.fill", title: IumrahWidgetL10n.noBooking, subtitle: IumrahWidgetL10n.openIumrah, dark: false)
                .widgetURL(IumrahWidgetDeepLink.account)
        }
    }

    private func decorativeOrb(status: String) -> some View {
        GeometryReader { proxy in
            Circle()
                .fill(IumrahWidgetPalette.statusColor(status).opacity(colorScheme == .dark ? 0.14 : 0.10))
                .frame(width: proxy.size.width * 0.66)
                .blur(radius: 18)
                .offset(x: proxy.size.width * 0.58, y: -proxy.size.height * 0.18)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Planned Umrah

private struct IumrahPlannedUmrahWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: IumrahWidgetEntry

    var body: some View {
        if let trip = entry.snapshot.plannedTrip {
            ZStack {
                IumrahPhotoBackdrop(asset: "WidgetKaabaBackground", style: .warm)

                Group {
                    switch family {
                    case .systemSmall: small(trip)
                    case .systemLarge: large(trip)
                    default: medium(trip)
                    }
                }
                .padding(family == .systemSmall ? 12 : 18)
            }
            .foregroundStyle(.white)
            .widgetURL(IumrahWidgetDeepLink.plannedTrip)
        } else {
            IumrahPremiumEmptyState(icon: "calendar.badge.plus", title: IumrahWidgetL10n.planUmrah, subtitle: IumrahWidgetL10n.planUmrahSubtitle, dark: true)
                .widgetURL(IumrahWidgetDeepLink.plannedTrip)
        }
    }

    private func small(_ trip: IumrahWidgetPlannedTripSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                IumrahPremiumWordmark(inverted: true)
                Spacer()
                Image(systemName: trip.notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 6)

            Text("\(daysUntil(trip.startDate))")
                .font(.system(size: 43, weight: .black, design: .rounded))
            Text(IumrahWidgetL10n.daysUntilUmrah.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.76))

            Spacer(minLength: 7)

            Text(trip.startDate, format: .dateTime.day().month(.wide))
                .font(.caption.weight(.bold))
                .lineLimit(1)
        }
    }

    private func medium(_ trip: IumrahWidgetPlannedTripSnapshot) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                IumrahPremiumWordmark(inverted: true)
                Spacer(minLength: 6)
                Text(IumrahWidgetL10n.nextUmrah.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.68))
                Text(trip.title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .lineLimit(2)
                Label(trip.startDate.formatted(.dateTime.day().month(.wide)), systemImage: "calendar")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.86))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: -2) {
                Text("\(daysUntil(trip.startDate))")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                Text(IumrahWidgetL10n.days)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func large(_ trip: IumrahWidgetPlannedTripSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IumrahPremiumWordmark(inverted: true)
                Spacer()
                Label(trip.notificationsEnabled ? IumrahWidgetL10n.remindersOn : IumrahWidgetL10n.remindersOff,
                      systemImage: trip.notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.24), in: Capsule())
            }

            Spacer(minLength: 8)

            Text(trip.title)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(daysUntil(trip.startDate))")
                    .font(.system(size: 70, weight: .black, design: .rounded))
                Text(IumrahWidgetL10n.daysUntilUmrah)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
            }

            Spacer(minLength: 2)

            HStack(spacing: 8) {
                dateChip(icon: "airplane.departure", date: trip.startDate)
                dateChip(icon: "airplane.arrival", date: trip.endDate)
                reminderChip(trip)
            }
        }
    }

    private func dateChip(icon: String, date: Date) -> some View {
        Label(date.formatted(.dateTime.day().month(.abbreviated)), systemImage: icon)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.black.opacity(0.24), in: Capsule())
            .lineLimit(1)
    }

    private func reminderChip(_ trip: IumrahWidgetPlannedTripSnapshot) -> some View {
        Label(String(format: "%02d:%02d", trip.reminderHour, trip.reminderMinute), systemImage: "clock.fill")
            .font(.caption2.monospacedDigit().weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.black.opacity(0.24), in: Capsule())
            .lineLimit(1)
    }
}

// MARK: - iumrah ID

private struct IumrahIdentityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: IumrahWidgetEntry

    var body: some View {
        if let identity = entry.snapshot.identity {
            ZStack {
                IumrahIdentityBackground()

                Group {
                    if family == .systemSmall {
                        small(identity)
                    } else {
                        medium(identity)
                    }
                }
                .padding(family == .systemSmall ? 12 : 18)
            }
            .widgetURL(URL(string: identity.publicURL) ?? IumrahWidgetDeepLink.account)
        } else {
            IumrahPremiumEmptyState(icon: "person.text.rectangle", title: "iumrah ID", subtitle: IumrahWidgetL10n.signIn, dark: true)
                .widgetURL(IumrahWidgetDeepLink.account)
        }
    }

    private func small(_ identity: IumrahWidgetIdentitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("iumrah ID")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 0)

            qr(identity.publicURL, size: 60)

            Spacer(minLength: 0)

            Text(identity.displayName)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(identity.iumrahID)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func medium(_ identity: IumrahWidgetIdentitySnapshot) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image("WidgetAppIcon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text("iumrah ID")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Text(identity.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(identity.iumrahID)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))

                Text(IumrahWidgetL10n.scanToOpen)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer(minLength: 4)

            qr(identity.publicURL, size: 108)
        }
    }

    @ViewBuilder
    private func qr(_ value: String, size: CGFloat) -> some View {
        if let image = IumrahWidgetQRCode.image(value) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .padding(7)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: size * 0.58))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Lock Screen

private struct IumrahCountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: IumrahWidgetEntry

    private var targetDate: Date? {
        entry.snapshot.activeBooking?.startDate ?? entry.snapshot.plannedTrip?.startDate
    }

    private var destination: URL? {
        entry.snapshot.activeBooking.flatMap { IumrahWidgetDeepLink.booking($0.id) } ?? IumrahWidgetDeepLink.plannedTrip
    }

    var body: some View {
        let days = daysUntil(targetDate)
        switch family {
        case .accessoryInline:
            Label(targetDate == nil ? IumrahWidgetL10n.planUmrah : "iumrah · \(days) \(IumrahWidgetL10n.shortDays)", systemImage: "airplane")
                .font(.caption.weight(.semibold))
                .widgetURL(destination)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Circle()
                    .stroke(.primary.opacity(0.20), lineWidth: 2)
                    .padding(3)
                VStack(spacing: -1) {
                    Text(targetDate == nil ? "—" : "\(days)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Text(IumrahWidgetL10n.shortDays.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                }
            }
            .widgetURL(destination)

        default:
            HStack(spacing: 8) {
                Image(systemName: "airplane.departure")
                    .font(.headline.weight(.bold))
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    if let targetDate {
                        Text("\(days) \(IumrahWidgetL10n.daysUntilUmrah)")
                            .font(.headline.monospacedDigit())
                        Text(targetDate, format: .dateTime.day().month(.abbreviated))
                            .font(.caption2.weight(.semibold))
                    } else {
                        Text(IumrahWidgetL10n.planUmrah)
                            .font(.headline)
                        Text("iumrah")
                            .font(.caption2.weight(.semibold))
                    }
                }
            }
            .widgetURL(destination)
        }
    }
}

// MARK: - Premium components

private struct IumrahPremiumWordmark: View {
    let inverted: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image("WidgetAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text("iumrah")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(inverted ? .white : .primary)
        }
    }
}

private struct IumrahStatusIcon: View {
    let status: String

    var body: some View {
        Image(systemName: IumrahWidgetPalette.statusSymbol(status))
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(IumrahWidgetPalette.statusColor(status))
            .frame(width: 38, height: 38)
            .background(IumrahWidgetPalette.statusColor(status).opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct IumrahStatusPill: View {
    let status: String
    let dark: Bool

    var body: some View {
        Label(IumrahWidgetL10n.status(status), systemImage: IumrahWidgetPalette.statusSymbol(status))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(dark ? .white : IumrahWidgetPalette.statusColor(status))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(dark ? Color.black.opacity(0.28) : IumrahWidgetPalette.statusColor(status).opacity(0.12), in: Capsule())
            .lineLimit(1)
    }
}

private struct IumrahPhotoBackdrop: View {
    enum Style { case dark, warm }
    let asset: String
    let style: Style

    var body: some View {
        GeometryReader { proxy in
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay {
                    switch style {
                    case .dark:
                        LinearGradient(
                            colors: [.black.opacity(0.36), .black.opacity(0.68), .black.opacity(0.92)],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    case .warm:
                        LinearGradient(
                            colors: [.black.opacity(0.18), .black.opacity(0.42), .black.opacity(0.86)],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    }
                }
        }
        .allowsHitTesting(false)
    }
}

private struct IumrahIdentityBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.08, green: 0.08, blue: 0.095)], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { proxy in
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: proxy.size.width * 0.72)
                    .offset(x: proxy.size.width * 0.64, y: -proxy.size.height * 0.12)
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: proxy.size.width * 0.55)
                    .offset(x: proxy.size.width * 0.78, y: proxy.size.height * 0.38)
            }
        }
    }
}

private struct IumrahPremiumEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    let dark: Bool

    var body: some View {
        ZStack {
            if dark {
                LinearGradient(colors: [.black, Color(red: 0.12, green: 0.12, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                IumrahWidgetPalette.surface
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    IumrahPremiumWordmark(inverted: dark)
                    Spacer()
                    Image(systemName: icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(dark ? .white.opacity(0.86) : IumrahWidgetPalette.brandBlue)
                }
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(dark ? .white : .primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(dark ? .white.opacity(0.62) : .secondary)
                    .lineLimit(2)
            }
            .padding(16)
        }
    }
}

// MARK: - QR

private enum IumrahWidgetQRCode {
    static func image(_ value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Palette

private enum IumrahWidgetPalette {
    static let brandBlue = Color(red: 0.10, green: 0.48, blue: 0.98)
    static let surface = Color(uiColor: .systemBackground)

    static func statusColor(_ raw: String) -> Color {
        switch raw.uppercased() {
        case "AVAILABILITY_CHECK": return .orange
        case "PAYMENT_PENDING": return .yellow
        case "BOOKING_CONFIRMED": return .green
        case "READY_TO_TRAVEL": return brandBlue
        case "IN_TRIP": return .cyan
        case "COMPLETED": return .green
        case "CANCELLED": return .red
        default: return .secondary
        }
    }

    static func statusSymbol(_ raw: String) -> String {
        switch raw.uppercased() {
        case "AVAILABILITY_CHECK": return "clock.arrow.circlepath"
        case "PAYMENT_PENDING": return "creditcard.fill"
        case "BOOKING_CONFIRMED": return "checkmark.seal.fill"
        case "READY_TO_TRAVEL": return "suitcase.rolling.fill"
        case "IN_TRIP": return "airplane"
        case "COMPLETED": return "checkmark.circle.fill"
        case "CANCELLED": return "xmark.circle.fill"
        default: return "circle.fill"
        }
    }

    static func statusIndex(_ raw: String) -> Int {
        switch raw.uppercased() {
        case "AVAILABILITY_CHECK": return 0
        case "PAYMENT_PENDING": return 1
        case "BOOKING_CONFIRMED": return 2
        case "READY_TO_TRAVEL": return 3
        case "IN_TRIP", "COMPLETED": return 4
        default: return 0
        }
    }
}

// MARK: - Localisation

private enum IumrahWidgetL10n {
    private enum Language { case ru, en, uz, uzCyrl }

    private static var language: Language {
        let id = Locale.current.identifier.lowercased()
        if id.contains("uz") && id.contains("cyrl") { return .uzCyrl }
        if id.hasPrefix("uz") { return .uz }
        if id.hasPrefix("ru") { return .ru }
        return .en
    }

    static var days: String { pick("дней", "days", "kun", "кун") }
    static var shortDays: String { pick("дн", "d", "kun", "кун") }
    static var daysUntilTrip: String { pick("до поездки", "until trip", "safargacha", "сафаргача") }
    static var daysUntilUmrah: String { pick("дней до Umrah", "days until Umrah", "kun Umragacha", "кун Умрагача") }
    static var activeUmrah: String { pick("Ваша Umrah", "Your Umrah", "Sizning Umrangiz", "Сизнинг Умрангиз") }
    static var nextUmrah: String { pick("следующая Umrah", "next Umrah", "keyingi Umra", "кейинги Умра") }
    static var booking: String { pick("Бронь", "Booking", "Bron", "Брон") }
    static var travelers: String { pick("Паломники", "Travelers", "Ziyoratchilar", "Зиёратчилар") }
    static var departure: String { pick("Вылет", "Departure", "Uchish", "Учиш") }
    static var noActiveTrip: String { pick("Нет активной поездки", "No active trip", "Faol safar yo‘q", "Фаол сафар йўқ") }
    static var noBooking: String { pick("Нет активной брони", "No active booking", "Faol bron yo‘q", "Фаол брон йўқ") }
    static var openIumrah: String { pick("Откройте iumrah, чтобы начать", "Open iumrah to start", "Boshlash uchun iumrah’ni oching", "Бошлаш учун iumrah’ни очинг") }
    static var planUmrah: String { pick("Запланировать Umrah", "Plan your Umrah", "Umrani rejalashtirish", "Умрани режалаштириш") }
    static var planUmrahSubtitle: String { pick("Выберите даты и включите напоминания", "Choose dates and reminders", "Sanalar va eslatmalarni tanlang", "Саналар ва эслатмаларни танланг") }
    static var signIn: String { pick("Войдите в аккаунт iumrah", "Sign in to iumrah", "iumrah akkauntiga kiring", "iumrah аккаунтига киринг") }
    static var scanToOpen: String { pick("Сканируйте, чтобы открыть ID", "Scan to open ID", "ID ochish uchun skanerlang", "ID очиш учун сканерланг") }
    static var remindersOn: String { pick("Напоминания включены", "Reminders on", "Eslatmalar yoqilgan", "Эслатмалар ёқилган") }
    static var remindersOff: String { pick("Напоминания выключены", "Reminders off", "Eslatmalar o‘chiq", "Эслатмалар ўчиқ") }

    static func status(_ raw: String) -> String {
        switch raw.uppercased() {
        case "AVAILABILITY_CHECK": return pick("Проверяем наличие", "Checking availability", "Mavjudlik tekshirilmoqda", "Мавжудлик текширилмоқда")
        case "PAYMENT_PENDING": return pick("Ожидаем оплату", "Waiting for payment", "To‘lov kutilmoqda", "Тўлов кутилмоқда")
        case "BOOKING_CONFIRMED": return pick("Бронирование подтверждено", "Booking confirmed", "Bron tasdiqlandi", "Брон тасдиқланди")
        case "READY_TO_TRAVEL": return pick("Готово к поездке", "Ready to travel", "Safarga tayyor", "Сафарга тайёр")
        case "IN_TRIP": return pick("Вы в поездке", "You are traveling", "Siz safardasiz", "Сиз сафардасиз")
        case "COMPLETED": return pick("Завершено", "Completed", "Yakunlandi", "Якунланди")
        case "CANCELLED": return pick("Отменено", "Cancelled", "Bekor qilindi", "Бекор қилинди")
        default: return pick("Статус поездки", "Trip status", "Safar holati", "Сафар ҳолати")
        }
    }

    static func nextAction(_ raw: String) -> String {
        switch raw.uppercased() {
        case "AVAILABILITY_CHECK": return pick("Команда проверяет места и подтверждает пакет.", "The team is confirming availability for your package.", "Jamoa paket mavjudligini tekshirmoqda.", "Жамоа пакет мавжудлигини текширмоқда.")
        case "PAYMENT_PENDING": return pick("Откройте бронь, чтобы заполнить данные и оплатить.", "Open the booking to add details and pay.", "Ma’lumot va to‘lov uchun bronni oching.", "Маълумот ва тўлов учун бронни очинг.")
        case "BOOKING_CONFIRMED": return pick("Бронь подтверждена. Документы готовятся.", "Your booking is confirmed. Documents are being prepared.", "Bron tasdiqlandi. Hujjatlar tayyorlanmoqda.", "Брон тасдиқланди. Ҳужжатлар тайёрланмоқда.")
        case "READY_TO_TRAVEL": return pick("Документы готовы — проверьте детали поездки.", "Your documents are ready — review the trip details.", "Hujjatlar tayyor — safar tafsilotlarini tekshiring.", "Ҳужжатлар тайёр — сафар тафсилотларини текширинг.")
        case "IN_TRIP": return pick("Все ключевые детали поездки доступны в iumrah.", "Your trip details are available in iumrah.", "Safar tafsilotlari iumrah’da mavjud.", "Сафар тафсилотлари iumrah’да мавжуд.")
        default: return openIumrah
        }
    }

    private static func pick(_ ru: String, _ en: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .ru: return ru
        case .en: return en
        case .uz: return uz
        case .uzCyrl: return cyrl
        }
    }
}

private func daysUntil(_ date: Date?) -> Int {
    guard let date else { return 0 }
    let calendar = Calendar.autoupdatingCurrent
    let start = calendar.startOfDay(for: Date())
    let end = calendar.startOfDay(for: date)
    return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
}

private extension IumrahWidgetSnapshot {
    static var preview: IumrahWidgetSnapshot {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: 26, to: Date()) ?? Date()
        let end = calendar.date(byAdding: .day, value: 34, to: Date()) ?? Date()
        return IumrahWidgetSnapshot(
            updatedAt: Date(),
            activeBooking: IumrahWidgetBookingSnapshot(
                id: "preview",
                displayNumber: "#2048",
                status: "BOOKING_CONFIRMED",
                originCode: "TAS",
                destinationCode: "MED",
                startDate: start,
                endDate: end,
                travelerCount: 2,
                perPilgrimUSD: 1250
            ),
            plannedTrip: IumrahWidgetPlannedTripSnapshot(
                id: UUID(),
                title: "Umrah · December",
                startDate: start,
                endDate: end,
                backgroundID: "gradient-sunset",
                notificationsEnabled: true,
                reminderHour: 19,
                reminderMinute: 0
            ),
            identity: IumrahWidgetIdentitySnapshot(
                displayName: "iumrah pilgrim",
                iumrahID: "00001234",
                publicURL: "https://iumrah.app/id/00001234"
            )
        )
    }
}
