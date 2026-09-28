import SwiftUI

struct IumrahAccountIdentityHeroCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let iumrahID: String
    let language: AppSettingsStore.Language
    let copyMessage: String?
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.075, green: 0.076, blue: 0.082),
                                        Color(red: 0.032, green: 0.033, blue: 0.038)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Canvas(rendersAsynchronously: true) { context, size in
                            renderDome(
                                in: &context,
                                size: size,
                                time: reduceMotion ? 0.85 : timeline.date.timeIntervalSinceReferenceDate
                            )
                        }
                        .allowsHitTesting(false)

                        RadialGradient(
                            colors: [Color.white.opacity(0.08), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: proxy.size.width * 0.7
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .allowsHitTesting(false)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                HStack(spacing: 7) {
                                    Text("iumrah ID")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .tracking(-0.25)

                                    IdentityActivityDots()
                                }
                                .foregroundStyle(.white)

                                Spacer(minLength: 12)

                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.95))
                                }
                            }

                            Spacer(minLength: 18)

                            Text(identityLabel)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.50))

                            HStack(alignment: .lastTextBaseline, spacing: 12) {
                                Text(iumrahID)
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .tracking(-0.8)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)

                                Spacer(minLength: 8)

                                Button(action: onCopy) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(Color.white.opacity(0.12), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(copyAccessibilityLabel)
                            }

                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 0.7)
                                .padding(.top, 12)

                            HStack(spacing: 8) {
                                if let copyMessage, !copyMessage.isEmpty {
                                    Label(copyMessage, systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.56, green: 0.96, blue: 0.64))
                                } else {
                                    Label(copyHint, systemImage: "hand.tap.fill")
                                        .foregroundStyle(.white.opacity(0.50))
                                }
                                Spacer(minLength: 10)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.top, 10)
                        }
                        .padding(18)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.085), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 22, y: 12)
                }
            }
            .frame(height: 216)
        }
    }

    private var identityLabel: String {
        switch language {
        case .russian: return "ВАШ IUMRAH ID"
        case .english: return "YOUR IUMRAH ID"
        case .uzbek: return "SIZNING IUMRAH ID"
        case .uzbekCyrillic: return "СИЗНИНГ IUMRAH ID"
        }
    }

    private var copyHint: String {
        switch language {
        case .russian: return "Нажмите, чтобы скопировать"
        case .english: return "Tap to copy"
        case .uzbek: return "Nusxalash uchun bosing"
        case .uzbekCyrillic: return "Нусхалаш учун босинг"
        }
    }

    private var copyAccessibilityLabel: String {
        switch language {
        case .russian: return "Копировать iumrah ID"
        case .english: return "Copy iumrah ID"
        case .uzbek: return "iumrah ID ni nusxalash"
        case .uzbekCyrillic: return "iumrah ID ни нусхалаш"
        }
    }

    private func renderDome(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        guard size.width > 1, size.height > 1 else { return }

        let cycle: Double = 4.60
        let progress = positiveRemainder(time, cycle) / cycle
        let center = CGPoint(x: size.width * 0.5, y: size.height * 1.005)
        let sphereRadius = min(size.width * 0.49, size.height * 0.79)
        let unitDot = size.width * 0.00615

        for point in Self.points {
            let depth = point.depth
            let perspective = 0.88 + (0.18 * depth)

            let x = center.x + (point.x * sphereRadius * perspective)
            let y = center.y + (point.y * sphereRadius * (0.90 + 0.18 * depth))
            let radius = unitDot * (0.66 + 0.68 * depth)

            let nx = point.x
            let ny = point.y + 1.0
            let hue = positiveRemainder(
                0.585 + progress + (0.235 * nx) + (0.055 * ny) + (0.045 * depth),
                1.0
            )
            let travel = 0.5 + 0.5 * sin(
                2.0 * .pi * (progress + (0.30 * nx) - (0.10 * ny) + (0.07 * depth))
            )
            let breathe = 0.5 + 0.5 * sin(2.0 * .pi * ((2.0 * progress) + 0.08))
            let globalLight = 0.20 + (0.80 * breathe)
            let intensity = clamp(
                0.10 + (0.90 * (0.28 + (0.72 * travel)) * globalLight),
                lower: 0.06,
                upper: 1.0
            )

            let spectral = Color(hue: hue, saturation: 0.78, brightness: 1.0)
            let neutralAlpha = 0.17 + (0.16 * depth)

            fillCircle(in: &context, center: CGPoint(x: x, y: y), radius: radius, color: Color.white.opacity(neutralAlpha))
            fillCircle(in: &context, center: CGPoint(x: x, y: y), radius: radius * 1.62, color: spectral.opacity(0.10 * intensity))
            fillCircle(in: &context, center: CGPoint(x: x, y: y), radius: radius, color: spectral.opacity(0.92 * intensity))
            fillCircle(in: &context, center: CGPoint(x: x, y: y), radius: radius * 0.43, color: Color(red: 0.018, green: 0.019, blue: 0.023).opacity(0.92))
            let highlightCenter = CGPoint(x: x - (radius * 0.27), y: y - (radius * 0.28))
            fillCircle(in: &context, center: highlightCenter, radius: max(0.28, radius * 0.17), color: Color.white.opacity(0.26 * intensity))
        }
    }

    private func fillCircle(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private static let points: [DomePoint] = {
        var points: [DomePoint] = []
        let rowCount = 12
        let columnCount = 26

        for row in 0..<rowCount {
            let normalizedRow = CGFloat(row) / CGFloat(max(rowCount - 1, 1))
            let theta = normalizedRow * (.pi / 2)
            let y = -cos(theta)
            let ringRadius = sin(theta)
            let columns = max(8, Int(round(CGFloat(columnCount) * ringRadius)))

            for column in 0..<columns {
                let normalizedColumn = CGFloat(column) / CGFloat(columns)
                let phi = (.pi * 1.07) + (normalizedColumn * (.pi * 0.86))
                let x = cos(phi) * ringRadius
                let z = sin(phi) * ringRadius
                let depth = max(0, z)
                points.append(DomePoint(x: x, y: y, depth: depth))
            }
        }
        return points
    }()
}

private struct IdentityActivityDots: View {
    @State private var highlightedIndex = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index == highlightedIndex ? 0.95 : 0.34))
                    .frame(width: 5.5, height: 5.5)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 420_000_000)
                highlightedIndex = (highlightedIndex + 1) % 3
            }
        }
    }
}

private struct DomePoint {
    let x: CGFloat
    let y: CGFloat
    let depth: CGFloat
}

private func positiveRemainder(_ value: Double, _ modulus: Double) -> Double {
    let remainder = value.truncatingRemainder(dividingBy: modulus)
    return remainder >= 0 ? remainder : remainder + modulus
}

private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
    min(max(value, lower), upper)
}
