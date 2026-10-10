import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct IumrahIdentityCardData: Hashable {
    let iumrahID: String
    let displayName: String
    let phone: String?
    let email: String?
}

/// One shared animated identity-card component for Account and iumrah Wallet.
/// The front intentionally stays minimal: only the iumrah ID wordmark and the
/// living dome. Personal data lives on the back after the native-feeling flip.
struct IumrahIdentityDomeCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let data: IumrahIdentityCardData
    let language: AppSettingsStore.Language
    var copyMessage: String? = nil
    var allowsFlip = true
    var publicIdentityURL: String? = nil
    var showsPublicIdentityQR = false
    var onCopy: () -> Void = {}

    @State private var isFlipped = false

    var body: some View {
        ZStack {
            surfaced(frontFace)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? -180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.72
                )
                .zIndex(isFlipped ? 0 : 1)

            surfaced(backFace)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.72
                )
                .zIndex(isFlipped ? 1 : 0)
        }
        .aspectRatio(1.60, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            guard allowsFlip else { return }
            IumrahHaptics.soft()
            withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.66, dampingFraction: 0.84)) {
                isFlipped.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFlipped ? "\(data.displayName), iumrah ID \(normalizedID(data.iumrahID))" : "iumrah ID")
        .accessibilityHint(allowsFlip ? tapToFlip : "")
    }

    private func surfaced<Content: View>(_ content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.085), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.18), radius: 22, y: 12)
    }

    private var frontFace: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    cardBackground

                    Canvas(rendersAsynchronously: true) { context, size in
                        renderDome(
                            in: &context,
                            size: size,
                            time: reduceMotion ? 0.85 : timeline.date.timeIntervalSinceReferenceDate
                        )
                    }
                    .allowsHitTesting(false)

                    Text("iumrah ID")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .tracking(-0.35)
                        .foregroundStyle(.white)
                        .padding(.leading, 18)
                        .padding(.top, 16)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var backFace: some View {
        GeometryReader { proxy in
            let nameSize = min(29.0, max(22.0, proxy.size.width * 0.070))

            ZStack {
                cardBackground

                RadialGradient(
                    colors: [Color.white.opacity(0.07), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.72
                )

                VStack(alignment: .leading, spacing: 0) {
                    Text("iumrah ID")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .tracking(-0.3)
                        .foregroundStyle(.white.opacity(0.96))

                    Spacer(minLength: 10)

                    if showsPublicIdentityQR {
                        HStack(alignment: .center, spacing: 18) {
                            Text(displayName)
                                .font(.system(size: min(32.0, max(25.0, proxy.size.width * 0.078)), weight: .semibold, design: .rounded))
                                .tracking(-0.55)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.70)

                            Spacer(minLength: 10)
                            publicIdentityQRCode
                        }
                    } else {
                        Text(displayName)
                            .font(.system(size: nameSize, weight: .semibold, design: .rounded))
                            .tracking(-0.5)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: 10)
                        VStack(alignment: .leading, spacing: 4) {
                            if let phone = nonBlank(data.phone) {
                                Label(phone, systemImage: "phone.fill")
                            }
                            if let email = nonBlank(data.email) {
                                Label(email, systemImage: "envelope.fill")
                            }
                        }
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                    }

                    Spacer(minLength: 10)

                    Rectangle()
                        .fill(Color.white.opacity(0.13))
                        .frame(height: 0.7)

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iumrah ID")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.46))
                            Text(normalizedID(data.iumrahID))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.92))
                        }

                        Spacer(minLength: 8)

                        Button {
                            onCopy()
                        } label: {
                            Image(systemName: copyMessage == nil ? "doc.on.doc" : "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 9)
                }
                .padding(16)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }


    private var publicIdentityCaption: String {
        switch language {
        case .russian: return "QR-код открывает Вашу iumrah ID на сайте"
        case .turkish: return TurkishLocalization.phrase("Scan to open your iumrah ID on the web")
        case .indonesian, .malay, .english: return "Scan to open your iumrah ID on the web"
        case .uzbek: return "QR-kod iumrah ID’ingizni saytda ochadi"
        case .uzbekCyrillic: return "QR-код iumrah ID’ингизни сайтда очади"
        }
    }

    @ViewBuilder
    private var publicIdentityQRCode: some View {
        if let value = publicIdentityURL ?? fallbackPublicIdentityURL,
           let image = makeQRCode(value) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .padding(7)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: 106, height: 106)
                .overlay {
                    Image(systemName: "qrcode")
                        .font(.system(size: 29, weight: .medium))
                        .foregroundStyle(.white.opacity(0.76))
                }
        }
    }

    private var fallbackPublicIdentityURL: String? {
        let id = normalizedID(data.iumrahID)
        guard !id.isEmpty else { return nil }
        return "https://iumrah.app/id/\(id)"
    }

    private func makeQRCode(_ value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 9, y: 9))
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private var displayName: String {
        let value = data.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "iumrah" : value
    }

    private var tapToFlip: String {
        switch language {
        case .russian: return "Нажмите, чтобы перевернуть карту"
        case .turkish: return TurkishLocalization.phrase("Tap to flip the card")
        case .indonesian, .malay, .english: return "Tap to flip the card"
        case .uzbek: return "Kartani aylantirish uchun bosing"
        case .uzbekCyrillic: return "Картани айлантириш учун босинг"
        }
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

    private var cardBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.075, green: 0.076, blue: 0.082),
                Color(red: 0.032, green: 0.033, blue: 0.038)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func renderDome(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        guard size.width > 1, size.height > 1 else { return }

        let cycle: Double = 4.60
        let progress = identityPositiveRemainder(time, cycle) / cycle
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
            let hue = identityPositiveRemainder(
                0.585 + progress + (0.235 * nx) + (0.055 * ny) + (0.045 * depth),
                1.0
            )
            let travel = 0.5 + 0.5 * sin(
                2.0 * .pi * (progress + (0.30 * nx) - (0.10 * ny) + (0.07 * depth))
            )
            let breathe = 0.5 + 0.5 * sin(2.0 * .pi * ((2.0 * progress) + 0.08))
            let globalLight = 0.20 + (0.80 * breathe)
            let intensity = identityClamp(
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
        guard radius > 0 else { return }
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private static let points: [IdentityDomePoint] = {
        let ringCount = 18
        var output: [IdentityDomePoint] = []
        output.reserveCapacity(620)
        let thetaStart = 0.085
        let thetaEnd = (Double.pi / 2.0) - 0.115

        for ring in 0..<ringCount {
            let fraction = Double(ring) / Double(max(1, ringCount - 1))
            let theta = thetaStart + ((thetaEnd - thetaStart) * fraction)
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)
            let count = max(6, Int((48.0 * sinTheta).rounded()))
            let stagger = ring.isMultiple(of: 2) ? 0.0 : 0.25

            for index in 0..<count {
                let phi = Double.pi * ((Double(index) + 0.5 + stagger) / Double(count))
                let depth = sinTheta * sin(phi)
                let rawX = sinTheta * cos(phi)
                let rawY = -cosTheta
                let x = rawX * (0.94 + (0.06 * depth))
                output.append(IdentityDomePoint(x: x, y: rawY, depth: depth))
            }
        }

        return output.sorted { $0.depth < $1.depth }
    }()
}

struct IumrahAccountIdentityHeroCard: View {
    let profile: IumrahAccountProfile
    let language: AppSettingsStore.Language
    let publicIdentityURL: String
    let copyMessage: String?
    let onCopy: () -> Void

    var body: some View {
        IumrahIdentityDomeCard(
            data: IumrahIdentityCardData(
                iumrahID: profile.iumrahID,
                displayName: profile.displayName,
                phone: nil,
                email: nil
            ),
            language: language,
            copyMessage: copyMessage,
            allowsFlip: true,
            publicIdentityURL: publicIdentityURL,
            showsPublicIdentityQR: true,
            onCopy: onCopy
        )
    }
}

private struct IdentityDomePoint {
    let x: CGFloat
    let y: CGFloat
    let depth: CGFloat
}

private func identityPositiveRemainder(_ value: Double, _ divisor: Double) -> Double {
    let result = value.truncatingRemainder(dividingBy: divisor)
    return result < 0 ? result + divisor : result
}

private func identityClamp(_ value: Double, lower: Double, upper: Double) -> Double {
    min(max(value, lower), upper)
}
