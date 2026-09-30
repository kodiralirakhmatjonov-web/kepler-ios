import SwiftUI

/// A short native hand-off between iOS' static launch screen and the live app.
///
/// The first rendered frame intentionally matches `UILaunchScreen` exactly:
/// adaptive launch background + centered `LaunchWordmark`. This prevents the
/// dark/blank flash that can otherwise appear while SwiftUI creates RootView.
struct IumrahLaunchExperience<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let content: Content

    @State private var splashVisible = true
    @State private var wordmarkScale: CGFloat = 1
    @State private var wordmarkOffset: CGFloat = 0
    @State private var wordmarkBlur: CGFloat = 0
    @State private var wordmarkOpacity: Double = 1
    @State private var sheenProgress: CGFloat = -1.15
    @State private var haloScale: CGFloat = 0.72
    @State private var haloOpacity: Double = 0
    @State private var backgroundOpacity: Double = 1
    @State private var contentScale: CGFloat = 1.008
    @State private var contentOpacity: Double = 0.985
    @State private var particleStartDate: Date?
    @State private var particleOpacity: Double = 1
    @State private var hasStarted = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .scaleEffect(contentScale)
                .opacity(contentOpacity)
                .allowsHitTesting(!splashVisible)

            if splashVisible {
                splashLayer
                    .zIndex(1000)
                    .transition(.identity)
            }
        }
        .background(Color("LaunchBackground"))
        .task {
            await runLaunchSequenceIfNeeded()
        }
    }

    private var splashLayer: some View {
        ZStack {
            Color("LaunchBackground")
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.primary.opacity(0.055),
                            Color.primary.opacity(0.018),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 122
                    )
                )
                .frame(width: 244, height: 244)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)
                .blur(radius: 10)
                .accessibilityHidden(true)

            if !reduceMotion {
                LaunchAirplaneFirework(startDate: particleStartDate)
                    .opacity(particleOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            launchWordmark
                .frame(width: 220, height: 90)
                .scaleEffect(wordmarkScale)
                .offset(y: wordmarkOffset)
                .blur(radius: wordmarkBlur)
                .opacity(wordmarkOpacity)
                .accessibilityHidden(true)
        }
        .compositingGroup()
    }

    private var launchWordmark: some View {
        ZStack {
            Image("LaunchWordmark")
                .resizable()
                .scaledToFit()

            GeometryReader { proxy in
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: sheenColor.opacity(0.02), location: 0.36),
                        .init(color: sheenColor.opacity(0.22), location: 0.49),
                        .init(color: sheenColor.opacity(0.04), location: 0.61),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 72, height: proxy.size.height * 1.55)
                .rotationEffect(.degrees(17))
                .offset(x: sheenProgress * (proxy.size.width + 100))
            }
            .mask {
                Image("LaunchWordmark")
                    .resizable()
                    .scaledToFit()
            }
            .allowsHitTesting(false)
        }
    }

    private var sheenColor: Color {
        colorScheme == .dark ? .black : .white
    }

    @MainActor
    private func runLaunchSequenceIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled else { return }
            IumrahHaptics.soft()

            withAnimation(.easeOut(duration: 0.22)) {
                wordmarkOpacity = 0
                backgroundOpacity = 0
                contentOpacity = 1
                contentScale = 1
            }

            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled else { return }
            splashVisible = false
            return
        }

        // The travel burst begins on the very first live SwiftUI frame. The
        // static UILaunchScreen has already shown the same background/wordmark,
        // so this feels like the system launch screen itself becoming alive.
        particleStartDate = Date()

        try? await Task.sleep(for: .milliseconds(90))
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.86, blendDuration: 0.08)) {
            wordmarkScale = 1.018
            haloScale = 1
            haloOpacity = 1
        }

        try? await Task.sleep(for: .milliseconds(190))
        guard !Task.isCancelled else { return }
        IumrahHaptics.soft()

        withAnimation(.easeInOut(duration: 0.54)) {
            sheenProgress = 1.18
            wordmarkScale = 1
            haloScale = 1.15
            haloOpacity = 0.36
        }

        try? await Task.sleep(for: .milliseconds(430))
        guard !Task.isCancelled else { return }

        // Reveal RootView through the splash rather than swapping screens.
        // This removes the visual seam between launch experience and app UI.
        withAnimation(.easeInOut(duration: 0.42)) {
            wordmarkOffset = -7
            wordmarkScale = 0.988
            wordmarkBlur = 5
            wordmarkOpacity = 0
            particleOpacity = 0
            haloScale = 1.34
            haloOpacity = 0
            backgroundOpacity = 0
            contentScale = 1
            contentOpacity = 1
        }

        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        IumrahHaptics.selection()

        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }
        splashVisible = false
    }
}

/// A one-shot, fully native travel firework used only during live splash handoff.
/// Tiny SF Symbol airplanes launch from the bottom-centre and follow individual
/// ballistic arcs. No GIF/Lottie/video is involved and the effect self-destructs
/// with the splash view, so it has no background runtime cost.
private struct LaunchAirplaneFirework: View {
    let startDate: Date?

    var body: some View {
        GeometryReader { proxy in
            if let startDate {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let elapsed = max(0, timeline.date.timeIntervalSince(startDate))
                    let width = max(proxy.size.width, 1)
                    let height = max(proxy.size.height, 1)
                    let originX = width * 0.5
                    let originY = height * 0.955

                    ZStack {
                        ForEach(LaunchAirplaneParticle.particles) { particle in
                            let localTime = elapsed - particle.delay

                            if localTime >= 0, localTime <= particle.duration {
                                let life = min(max(localTime / particle.duration, 0), 1)
                                let seconds = CGFloat(localTime)
                                let fadeIn = min(max(life / 0.075, 0), 1)
                                let fadeOut = min(max((1 - life) / 0.30, 0), 1)
                                let opacity = fadeIn * fadeOut
                                let sway = sin((localTime * particle.swayFrequency) + particle.phase)
                                let x = originX
                                    + (particle.horizontalVelocity * width * seconds)
                                    + (CGFloat(sway) * width * particle.swayAmplitude)
                                let y = originY
                                    - (particle.upwardVelocity * height * seconds)
                                    + (0.5 * particle.gravity * height * seconds * seconds)
                                let scale = CGFloat(0.68 + (0.34 * fadeIn) - (0.14 * life))

                                Image(systemName: "airplane")
                                    .symbolRenderingMode(.monochrome)
                                    .font(.system(size: particle.size, weight: .semibold))
                                    .foregroundStyle(launchParticleColor(particle.colorIndex))
                                    .rotationEffect(
                                        .degrees(
                                            particle.baseRotation
                                            + (particle.spin * life)
                                            + (Double(sway) * 7.0)
                                        )
                                    )
                                    .scaleEffect(scale)
                                    .opacity(opacity)
                                    .position(x: x, y: y)
                            }
                        }
                    }
                    .frame(width: width, height: height)
                }
            }
        }
    }

    private func launchParticleColor(_ index: Int) -> Color {
        switch index % 5 {
        case 0:
            return Color(red: 0.19, green: 0.45, blue: 1.00) // electric blue
        case 1:
            return Color(red: 0.47, green: 0.24, blue: 1.00) // violet
        case 2:
            return Color(red: 0.05, green: 0.72, blue: 1.00) // cyan
        case 3:
            return Color(red: 1.00, green: 0.43, blue: 0.10) // travel orange
        default:
            return Color(red: 0.82, green: 0.24, blue: 0.92) // magenta
        }
    }
}

private struct LaunchAirplaneParticle: Identifiable {
    let id: Int
    let horizontalVelocity: CGFloat
    let upwardVelocity: CGFloat
    let gravity: CGFloat
    let delay: Double
    let duration: Double
    let size: CGFloat
    let baseRotation: Double
    let spin: Double
    let swayAmplitude: CGFloat
    let swayFrequency: Double
    let phase: Double
    let colorIndex: Int

    static let particles: [LaunchAirplaneParticle] = {
        let count = 34

        return (0..<count).map { index in
            let i = Double(index)
            let spread = -1.0 + (2.0 * i / Double(max(count - 1, 1)))
            let jitter = sin((i + 1.0) * 2.173) * 0.055
            let liftWave = 0.5 + (0.5 * cos((i + 0.7) * 1.619))

            return LaunchAirplaneParticle(
                id: index,
                horizontalVelocity: CGFloat((spread * 0.31) + jitter),
                upwardVelocity: CGFloat(0.58 + (0.24 * liftWave)),
                gravity: CGFloat(0.27 + (0.055 * (0.5 + 0.5 * sin(i * 1.31)))),
                delay: Double(index % 7) * 0.015,
                duration: 0.92 + (Double(index % 5) * 0.035),
                size: CGFloat(6.0 + (Double(index % 5) * 0.85)),
                baseRotation: (-58.0 * spread) + (sin(i * 0.91) * 13.0),
                spin: (index.isMultiple(of: 2) ? 1.0 : -1.0) * (12.0 + Double(index % 4) * 5.0),
                swayAmplitude: CGFloat(0.004 + (Double(index % 4) * 0.0017)),
                swayFrequency: 4.0 + (Double(index % 6) * 0.48),
                phase: i * 0.77,
                colorIndex: index
            )
        }
    }()
}
