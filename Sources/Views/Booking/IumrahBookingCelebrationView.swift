import SwiftUI
import UIKit

struct IumrahBookingCelebrationView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let session: StoredBookingSession
    let onOpenBooking: () -> Void
    let onHome: () -> Void

    @State private var celebrationBurstTrigger = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.018, green: 0.024, blue: 0.040),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                IumrahCelebrationParticleField(
                    reduceMotion: reduceMotion,
                    burstTrigger: celebrationBurstTrigger
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: max(24, proxy.safeAreaInsets.top + 8))

                        appIcon
                            .padding(.top, 58)

                        Text(title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .tracking(-0.9)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 28)
                            .padding(.horizontal, 28)

                        Text(bodyText)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 10)
                            .padding(.horizontal, 34)

                        availabilityTimer
                            .padding(.top, 24)
                            .padding(.horizontal, 24)

                        VStack(spacing: 12) {
                            Button {
                                IumrahHaptics.soft()
                                onOpenBooking()
                            } label: {
                                HStack(spacing: 10) {
                                    Text(openBookingTitle)
                                    Spacer(minLength: 8)
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 20)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                IumrahHaptics.selection()
                                onHome()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "house.fill")
                                    Text(homeTitle)
                                }
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                        .padding(.bottom, max(28, proxy.safeAreaInsets.bottom + 16))
                    }
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("iumrah.booking.celebration")
    }

    private var appIcon: some View {
        Image(appIconPreviewName)
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.8)
            }
            .shadow(color: .white.opacity(0.14), radius: 24)
            .shadow(color: .black.opacity(0.70), radius: 18, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .onTapGesture {
                guard !reduceMotion else { return }
                celebrationBurstTrigger &+= 1
                IumrahHaptics.soft()
            }
            .accessibilityHidden(true)
    }

    private var availabilityTimer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, availabilityDeadline.timeIntervalSince(context.date))

            VStack(spacing: 11) {
                Text(timerEyebrow)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.15)
                    .foregroundStyle(.white.opacity(0.46))

                Text(countdown(remaining))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(timerBody)
                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            }
        }
    }

    private var availabilityDeadline: Date {
        if let raw = session.availabilityDeadlineAt, let value = Self.isoDate(raw) {
            return value
        }
        let raw = session.availabilityStartedAt ?? session.booking.createdAt
        if let value = Self.isoDate(raw) {
            return value.addingTimeInterval(6 * 60 * 60)
        }
        return Date().addingTimeInterval(6 * 60 * 60)
    }

    private func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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

    private var appIconPreviewName: String {
        switch UIApplication.shared.alternateIconName {
        case "AppIconBlue": return "AppIconBluePreview"
        case "AppIconCyan": return "AppIconCyanPreview"
        case "AppIconDeepBlue": return "AppIconDeepBluePreview"
        case "AppIconWorld": return "AppIconWorldPreview"
        case "AppIconMakkah": return "AppIconMakkahPreview"
        default: return "AppIconFurPreview"
        }
    }

    private var title: String {
        switch settings.language {
        case .russian: return "Ваша Umrah создана"
        case .english: return "Your Umrah is created"
        case .uzbek: return "Umrangiz yaratildi"
        case .uzbekCyrillic: return "Умрангиз яратилди"
        }
    }

    private var bodyText: String {
        switch settings.language {
        case .russian:
            return "Бронирование создано и передано на проверку наличия. Вам ничего не нужно делать прямо сейчас."
        case .english:
            return "Your booking has been created and sent for availability confirmation. Nothing else is required from you right now."
        case .uzbek:
            return "Bron yaratildi va mavjudlikni tekshirishga yuborildi. Hozir sizdan boshqa amal talab qilinmaydi."
        case .uzbekCyrillic:
            return "Брон яратилди ва мавжудликни текширишга юборилди. Ҳозир сиздан бошқа амал талаб қилинмайди."
        }
    }

    private var timerEyebrow: String {
        switch settings.language {
        case .russian: return "ПРОВЕРКА НАЛИЧИЯ"
        case .english: return "AVAILABILITY CHECK"
        case .uzbek: return "MAVJUDLIK TEKSHIRUVI"
        case .uzbekCyrillic: return "МАВЖУДЛИК ТЕКШИРУВИ"
        }
    }

    private var timerBody: String {
        switch settings.language {
        case .russian:
            return "После проверки наличия статус изменится автоматически. Можно закрыть приложение — iumrah обновит бронь и уведомит Вас."
        case .english:
            return "After availability is checked, the status will update automatically. You can close the app — iumrah will update the booking and notify you."
        case .uzbek:
            return "Mavjudlik tekshirilgach holat avtomatik yangilanadi. Ilovani yopishingiz mumkin — iumrah bronni yangilab, sizga xabar beradi."
        case .uzbekCyrillic:
            return "Мавжудлик текширилгач ҳолат автоматик янгиланади. Иловадан чиқишингиз мумкин — iumrah бронни янгилаб, сизга хабар беради."
        }
    }

    private var openBookingTitle: String {
        switch settings.language {
        case .russian: return "Открыть бронирование"
        case .english: return "Open booking"
        case .uzbek: return "Bronni ochish"
        case .uzbekCyrillic: return "Бронни очиш"
        }
    }

    private var homeTitle: String {
        switch settings.language {
        case .russian: return "На главную"
        case .english: return "Home"
        case .uzbek: return "Asosiy sahifa"
        case .uzbekCyrillic: return "Асосий саҳифа"
        }
    }
}

private struct IumrahCelebrationParticleField: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    let reduceMotion: Bool
    let burstTrigger: Int

    @State private var startDate = Date()
    @State private var tapBursts: [IumrahCelebrationBurst] = []
    @State private var burstSeed: UInt64 = 1000

    private let automaticParticleCount = 34
    private let tapParticleCount = 24

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                ZStack {
                    if !(reduceMotion || systemReduceMotion) {
                        automaticParticles(
                            date: context.date,
                            size: proxy.size
                        )

                        tapParticles(
                            date: context.date,
                            size: proxy.size
                        )
                    } else {
                        reducedMotionHalo(date: context.date, size: proxy.size)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
            }
            .onChange(of: burstTrigger) { _, _ in
                guard !(reduceMotion || systemReduceMotion) else { return }
                addTapBurst(
                    at: CGPoint(x: proxy.size.width * 0.5, y: min(proxy.size.height * 0.24, 190)),
                    in: proxy.size
                )
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func automaticParticles(date: Date, size: CGSize) -> some View {
        let elapsed = max(0, date.timeIntervalSince(startDate))
        let origin = CGPoint(x: size.width * 0.5, y: min(size.height * 0.24, 190))

        ForEach(0..<automaticParticleCount, id: \.self) { index in
            let spec = IumrahCelebrationParticleSpec.make(index: index, seed: 73)
            let cycle = 3.1
            let phase = positiveRemainder(elapsed + spec.delay, cycle) / cycle
            let state = particleState(spec: spec, progress: phase, origin: origin, intensity: 1.0)

            IumrahCelebrationParticleTile(spec: spec, state: state)
        }
    }

    @ViewBuilder
    private func tapParticles(date: Date, size: CGSize) -> some View {
        ForEach(tapBursts) { burst in
            let elapsed = date.timeIntervalSince(burst.createdAt)
            if elapsed >= 0, elapsed < 2.25 {
                ForEach(0..<tapParticleCount, id: \.self) { index in
                    let spec = IumrahCelebrationParticleSpec.make(index: index, seed: burst.seed)
                    let phase = min(max((elapsed - spec.delay * 0.16) / 2.0, 0), 1)
                    let origin = CGPoint(
                        x: burst.normalizedOrigin.x * size.width,
                        y: burst.normalizedOrigin.y * size.height
                    )
                    let state = particleState(spec: spec, progress: phase, origin: origin, intensity: 1.25)

                    IumrahCelebrationParticleTile(spec: spec, state: state)
                }
            }
        }
    }

    @ViewBuilder
    private func reducedMotionHalo(date: Date, size: CGSize) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let pulse = 0.84 + (0.16 * (0.5 + 0.5 * sin(t * 1.4)))

        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.08), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 150
                )
            )
            .frame(width: 300, height: 300)
            .scaleEffect(pulse)
            .position(x: size.width * 0.5, y: min(size.height * 0.24, 190))
    }

    private func particleState(
        spec: IumrahCelebrationParticleSpec,
        progress: Double,
        origin: CGPoint,
        intensity: CGFloat
    ) -> IumrahCelebrationParticleState {
        let p = CGFloat(progress)
        let eased = CGFloat(1 - pow(Double(1 - p), 1.62))
        let radius = (18 + spec.travel * eased) * intensity
        let gravity = 120 * p * p * intensity
        let drift = sin((p * .pi * 2) + spec.phase) * spec.wobble
        let x = origin.x + cos(spec.angle) * radius + drift
        let y = origin.y + sin(spec.angle) * radius * 0.76 + gravity - (52 * p * intensity)
        let fadeIn = min(1, p / 0.10)
        let fadeOut = min(1, max(0, (1 - p) / 0.22))
        let opacity = Double(fadeIn * fadeOut)
        let scale = (0.50 + (0.55 * sin(min(1, p) * .pi))) * spec.scale
        let spin = spec.spin * p * 360

        return IumrahCelebrationParticleState(
            position: CGPoint(x: x, y: y),
            opacity: opacity,
            scale: scale,
            spin: spin,
            tiltX: spec.tiltX * sin((p * .pi) + spec.phase),
            tiltY: spec.tiltY * cos((p * .pi * 1.3) + spec.phase)
        )
    }

    private func addTapBurst(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        burstSeed &+= 7919
        let normalized = CGPoint(
            x: min(max(location.x / size.width, 0.12), 0.88),
            y: min(max(location.y / size.height, 0.12), 0.72)
        )
        tapBursts.append(
            IumrahCelebrationBurst(
                id: UUID(),
                createdAt: Date(),
                normalizedOrigin: normalized,
                seed: burstSeed
            )
        )
        tapBursts.removeAll { Date().timeIntervalSince($0.createdAt) > 2.5 }
        if tapBursts.count > 5 {
            tapBursts.removeFirst(tapBursts.count - 5)
        }
    }

    private func positiveRemainder(_ value: Double, _ divisor: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: divisor)
        return result >= 0 ? result : result + divisor
    }
}

private struct IumrahCelebrationBurst: Identifiable {
    let id: UUID
    let createdAt: Date
    let normalizedOrigin: CGPoint
    let seed: UInt64
}

private struct IumrahCelebrationParticleState {
    let position: CGPoint
    let opacity: Double
    let scale: CGFloat
    let spin: CGFloat
    let tiltX: CGFloat
    let tiltY: CGFloat
}

private struct IumrahCelebrationParticleSpec {
    let symbol: String
    let palette: Int
    let angle: CGFloat
    let travel: CGFloat
    let delay: Double
    let phase: CGFloat
    let wobble: CGFloat
    let scale: CGFloat
    let spin: CGFloat
    let tiltX: CGFloat
    let tiltY: CGFloat

    static func make(index: Int, seed: UInt64) -> IumrahCelebrationParticleSpec {
        let symbols = [
            "airplane",
            "building.2.fill",
            "car.fill",
            "suitcase.fill",
            "globe.europe.africa.fill",
            "map.fill",
            "location.fill",
            "calendar",
            "ticket.fill",
            "heart.fill",
            "sparkles",
            "checkmark.seal.fill",
            "shield.fill",
            "fork.knife",
            "moon.stars.fill",
            "wifi",
            "bed.double.fill",
            "person.2.fill"
        ]

        let base = seed &+ UInt64(index &* 977)
        let angle = CGFloat(unit(base &+ 11) * Double.pi * 2)
        let travel = CGFloat(104 + unit(base &+ 23) * 132)
        let delay = unit(base &+ 37) * 2.8
        let phase = CGFloat(unit(base &+ 41) * Double.pi * 2)
        let wobble = CGFloat(4 + unit(base &+ 53) * 18)
        let scale = CGFloat(0.76 + unit(base &+ 67) * 0.54)
        let spin = CGFloat((unit(base &+ 79) - 0.5) * 2.2)
        let tiltX = CGFloat(22 + unit(base &+ 83) * 48)
        let tiltY = CGFloat(18 + unit(base &+ 97) * 52)
        let palette = Int(unit(base &+ 101) * 5.999)
        let symbolIndex = Int(unit(base &+ 107) * Double(symbols.count - 1))

        return IumrahCelebrationParticleSpec(
            symbol: symbols[min(max(symbolIndex, 0), symbols.count - 1)],
            palette: palette,
            angle: angle,
            travel: travel,
            delay: delay,
            phase: phase,
            wobble: wobble,
            scale: scale,
            spin: spin,
            tiltX: tiltX,
            tiltY: tiltY
        )
    }

    private static func unit(_ value: UInt64) -> Double {
        var x = value &+ 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x ^= x >> 31
        return Double(x % 10_000) / 10_000.0
    }
}

private struct IumrahCelebrationParticleTile: View {
    let spec: IumrahCelebrationParticleSpec
    let state: IumrahCelebrationParticleState

    var body: some View {
        let colors = paletteColors(spec.palette)
        let primary = colors.first ?? .white
        let secondary = colors.last ?? primary

        ZStack {
            Circle()
                .fill(primary.opacity(0.26))
                .frame(width: 34, height: 34)
                .blur(radius: 10)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [primary.opacity(0.72), secondary.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 20, height: 9)
                .blur(radius: 6)
                .offset(y: 10)

            Image(systemName: spec.symbol)
                .font(.system(size: 18, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(primary)
                .shadow(color: primary.opacity(0.55), radius: 8)
                .shadow(color: .white.opacity(0.42), radius: 2)
        }
        .frame(width: 44, height: 44)
        .scaleEffect(state.scale)
        .rotationEffect(.degrees(Double(state.spin * 6)))
        .rotation3DEffect(
            .degrees(Double(state.tiltX)),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.48
        )
        .rotation3DEffect(
            .degrees(Double(state.tiltY)),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.48
        )
        .opacity(state.opacity)
        .position(state.position)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func paletteColors(_ index: Int) -> [Color] {
        switch index % 6 {
        case 0:
            return [Color(red: 0.11, green: 0.74, blue: 0.98), Color(red: 0.08, green: 0.33, blue: 0.92)]
        case 1:
            return [Color(red: 0.54, green: 0.31, blue: 0.98), Color(red: 0.25, green: 0.12, blue: 0.78)]
        case 2:
            return [Color(red: 0.98, green: 0.26, blue: 0.65), Color(red: 0.72, green: 0.08, blue: 0.42)]
        case 3:
            return [Color(red: 1.00, green: 0.56, blue: 0.16), Color(red: 0.93, green: 0.25, blue: 0.06)]
        case 4:
            return [Color(red: 0.21, green: 0.86, blue: 0.56), Color(red: 0.04, green: 0.52, blue: 0.32)]
        default:
            return [Color(red: 0.20, green: 0.84, blue: 0.88), Color(red: 0.04, green: 0.42, blue: 0.59)]
        }
    }
}
