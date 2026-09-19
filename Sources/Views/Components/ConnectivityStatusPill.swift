import SwiftUI

/// Video-matched connectivity indicator used in the Home header.
///
/// Visual cycle (reference timing):
/// 1. compact globe + fast multicolor orbit,
/// 2. morph into a black capsule,
/// 3. reveal Online / Offline while the illuminated border keeps travelling,
/// 4. collapse back to the compact globe and repeat.
///
/// The network state remains driven by `IumrahConnectivityMonitor`; this view is
/// presentation-only and never changes connectivity behaviour.
struct IumrahAnimatedConnectivityIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var connectivity = IumrahConnectivityMonitor()

    var lightStyle = false

    @State private var isExpanded = false

    private let compactWidth: CGFloat = 34
    private let expandedWidth: CGFloat = 88
    private let height: CGFloat = 34

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            indicator(at: context.date)
        }
        .frame(width: expandedWidth, height: height, alignment: .trailing)
        .task(id: connectivity.status) {
            await runPresentationCycle(for: connectivity.status)
        }
        .task {
            // Preserve the existing reachability behaviour. The animated control
            // only changes presentation, not the network source of truth.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await connectivity.refresh()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Internet connection: \(connectivity.status.title)")
    }

    @ViewBuilder
    private func indicator(at date: Date) -> some View {
        let width = isExpanded ? expandedWidth : compactWidth
        let rotation = borderRotation(at: date)

        ZStack {
            // Soft moving halo visible in the reference around the bright rail.
            Capsule(style: .continuous)
                .stroke(borderGradient(rotation: rotation), lineWidth: isExpanded ? 4.8 : 4.2)
                .blur(radius: isExpanded ? 4.2 : 3.4)
                .opacity(isExpanded ? 0.34 : 0.42)

            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.985))

            Capsule(style: .continuous)
                .strokeBorder(borderGradient(rotation: rotation), lineWidth: 2.15)

            HStack(spacing: 5) {
                Text(connectivity.status.title)
                    .font(.system(size: 11.5, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .frame(width: isExpanded ? 40 : 0, alignment: .leading)
                    .opacity(isExpanded ? 1 : 0)
                    .offset(x: isExpanded ? 0 : 7)
                    .clipped()

                Spacer(minLength: 0)

                Image(systemName: "globe")
                    .font(.system(size: 18.5, weight: .bold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
            }
            .padding(.leading, isExpanded ? 10 : 7)
            .padding(.trailing, isExpanded ? 7 : 7)
        }
        .frame(width: width, height: height)
        .shadow(color: haloColor.opacity(isExpanded ? 0.18 : 0.12), radius: 6, y: 2)
        .animation(morphAnimation, value: isExpanded)
    }

    private var morphAnimation: Animation {
        // The reference reaches the full capsule in roughly four tenths of a
        // second with a soft spring and no visible hard stop.
        .spring(response: 0.42, dampingFraction: 0.82, blendDuration: 0.08)
    }

    @MainActor
    private func runPresentationCycle(for status: IumrahConnectivityStatus) async {
        isExpanded = false

        guard !reduceMotion else {
            isExpanded = status != .checking
            return
        }

        // While probing we intentionally stay as the compact spinning globe.
        // A real result restarts this task and begins the reference reveal cycle.
        guard status != .checking else { return }

        while !Task.isCancelled {
            // Compact orbit section from the reference clip.
            try? await Task.sleep(nanoseconds: 1_650_000_000)
            guard !Task.isCancelled else { break }

            withAnimation(morphAnimation) {
                isExpanded = true
            }

            // Full Online / Offline capsule remains readable while the highlight
            // continues to orbit around the rail.
            try? await Task.sleep(nanoseconds: 3_650_000_000)
            guard !Task.isCancelled else { break }

            withAnimation(morphAnimation) {
                isExpanded = false
            }

            // Small compact beat before the next cycle, matching the clip.
            try? await Task.sleep(nanoseconds: 620_000_000)
            guard !Task.isCancelled else { break }
        }
    }

    private func borderRotation(at date: Date) -> Double {
        guard !reduceMotion else { return 18 }
        // The bright rail completes a pass in ~1.55 s in the supplied reference.
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.55)
        return (cycle / 1.55) * 360
    }

    private func borderGradient(rotation: Double) -> AngularGradient {
        AngularGradient(
            gradient: gradient,
            center: .center,
            startAngle: .degrees(rotation),
            endAngle: .degrees(rotation + 360)
        )
    }

    private var gradient: Gradient {
        if !isExpanded || connectivity.status == .checking {
            // The compact globe in the reference deliberately cycles through the
            // full spectrum before the state label opens.
            return Gradient(stops: [
                .init(color: Color(red: 0.18, green: 0.96, blue: 0.37), location: 0.00),
                .init(color: Color(red: 0.08, green: 0.90, blue: 0.94), location: 0.14),
                .init(color: Color(red: 0.20, green: 0.42, blue: 1.00), location: 0.29),
                .init(color: Color(red: 0.62, green: 0.18, blue: 0.98), location: 0.43),
                .init(color: Color(red: 1.00, green: 0.12, blue: 0.54), location: 0.57),
                .init(color: Color(red: 1.00, green: 0.21, blue: 0.16), location: 0.70),
                .init(color: Color(red: 1.00, green: 0.66, blue: 0.10), location: 0.84),
                .init(color: Color(red: 0.18, green: 0.96, blue: 0.37), location: 1.00),
            ])
        }

        switch connectivity.status {
        case .offline:
            return Gradient(stops: [
                .init(color: Color(red: 1.00, green: 0.08, blue: 0.34), location: 0.00),
                .init(color: Color(red: 1.00, green: 0.17, blue: 0.56), location: 0.27),
                .init(color: Color(red: 1.00, green: 0.88, blue: 0.91), location: 0.45),
                .init(color: Color.black.opacity(0.22), location: 0.61),
                .init(color: Color(red: 0.96, green: 0.15, blue: 0.48), location: 0.80),
                .init(color: Color(red: 1.00, green: 0.08, blue: 0.34), location: 1.00),
            ])
        case .online:
            return Gradient(stops: [
                .init(color: Color(red: 0.08, green: 0.88, blue: 0.93), location: 0.00),
                .init(color: Color(red: 0.14, green: 0.95, blue: 0.70), location: 0.27),
                .init(color: Color(red: 0.89, green: 1.00, blue: 0.98), location: 0.45),
                .init(color: Color.black.opacity(0.20), location: 0.61),
                .init(color: Color(red: 0.11, green: 0.91, blue: 0.72), location: 0.80),
                .init(color: Color(red: 0.08, green: 0.88, blue: 0.93), location: 1.00),
            ])
        case .checking:
            return Gradient(colors: [.white.opacity(0.78), .cyan, .mint, .white.opacity(0.78)])
        }
    }

    private var haloColor: Color {
        switch connectivity.status {
        case .online: return Color(red: 0.10, green: 0.92, blue: 0.70)
        case .offline: return Color(red: 1.00, green: 0.12, blue: 0.42)
        case .checking: return .cyan
        }
    }
}

/// Compatibility wrapper for any older call sites. New Home headers use the
/// dedicated animated component directly.
struct ConnectivityStatusPill: View {
    var lightStyle = false

    var body: some View {
        IumrahAnimatedConnectivityIndicator(lightStyle: lightStyle)
    }
}
