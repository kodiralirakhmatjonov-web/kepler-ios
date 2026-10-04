import SwiftUI
import UIKit

enum IumrahDesign {
    // Keep the same compact geometry discipline as the AutoSale Umar reference:
    // system surfaces, rounded continuous corners and restrained spacing.
    static let pagePadding: CGFloat = 18
    static let cardRadius: CGFloat = 28
    static let heroRadius: CGFloat = 34
    static let compactRadius: CGFloat = 19
    static let controlHeight: CGFloat = 56
    static let glassIconSize: CGFloat = 46
}

private extension UIColor {
    static let iumrahPage = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemBackground
            : .systemGroupedBackground
    }

    static let iumrahCard = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .secondarySystemBackground
            : .secondarySystemGroupedBackground
    }

    static let iumrahRaised = UIColor { _ in
        .tertiarySystemGroupedBackground
    }

    static let iumrahPrimaryButton = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.96, alpha: 1)
            : UIColor.black
    }

    static let iumrahPrimaryButtonText = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.075, blue: 0.085, alpha: 1)
            : UIColor.white
    }

    static let iumrahCareDark = UIColor(red: 14/255, green: 36/255, blue: 34/255, alpha: 1)
    static let iumrahCareLight = UIColor(red: 116/255, green: 161/255, blue: 135/255, alpha: 1)

    // Adaptive opaque/translucent content surface used over photography.
    // Unlike Liquid Glass this is a content card, so its contrast is deterministic
    // in both appearances and semantic text remains readable.
    static let iumrahPhotoCard = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.105, alpha: 0.975)
            : UIColor(white: 1.0, alpha: 0.975)
    }

    static let iumrahPhotoRaised = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.16, alpha: 0.96)
            : UIColor(white: 0.95, alpha: 0.96)
    }
}

extension Color {
    static let iumrahPageBackground = Color(uiColor: .iumrahPage)
    static let iumrahCardBackground = Color(uiColor: .iumrahCard)
    static let iumrahRaisedBackground = Color(uiColor: .iumrahRaised)
    static let iumrahPrimaryButtonBackground = Color(uiColor: .iumrahPrimaryButton)
    static let iumrahPrimaryButtonText = Color(uiColor: .iumrahPrimaryButtonText)
    static let iumrahGraphite = Color(red: 0.09, green: 0.10, blue: 0.115)
    static let iumrahCareDark = Color(uiColor: .iumrahCareDark)
    static let iumrahCareLight = Color(uiColor: .iumrahCareLight)
    static let iumrahPhotoCardBackground = Color(uiColor: .iumrahPhotoCard)
    static let iumrahPhotoRaisedBackground = Color(uiColor: .iumrahPhotoRaised)
}

// MARK: - Semantic icon language

/// A restrained semantic palette for content icons. Color is a navigation aid,
/// not decoration: the same kind of information keeps the same family across
/// Account, Booking, Hotels, Care, checkout and supporting screens.
enum IumrahIconRole: Hashable {
    case accent
    case travel
    case hotel
    case booking
    case umrah
    case care
    case profile
    case phone
    case mail
    case message
    case connectivity
    case device
    case gift
    case search
    case rating
    case calendar
    case location
    case security
    case notification
    case appearance
    case language
    case settings
    case document
    case payment
    case waiting
    case paymentPending
    case confirmed
    case ready
    case inTrip
    case completed
    case telegram
    case whatsapp
    case transfer
    case success
    case warning
    case destructive
    case neutral

    var color: Color {
        switch self {
        case .accent: return Color(uiColor: .systemBlue)
        case .travel: return Color(uiColor: .systemBlue)
        case .hotel: return Color(uiColor: .systemIndigo)
        case .booking: return Color(uiColor: .systemOrange)
        case .umrah: return Color(uiColor: .systemTeal)
        case .care: return Color(uiColor: .systemPink)
        case .profile: return Color(uiColor: .systemCyan)
        case .phone: return Color(uiColor: .systemGreen)
        case .mail: return Color(uiColor: .systemBlue)
        case .message: return Color(uiColor: .systemTeal)
        case .connectivity: return Color(uiColor: .systemBlue)
        case .device: return Color(uiColor: .systemBlue)
        case .gift: return Color(uiColor: .systemPurple)
        case .search: return Color(uiColor: .systemBlue)
        case .rating: return Color(uiColor: .systemYellow)
        case .calendar: return Color(uiColor: .systemOrange)
        case .location: return Color(uiColor: .systemRed)
        case .security: return Color(uiColor: .systemGreen)
        case .notification: return Color(uiColor: .systemRed)
        case .appearance: return Color(uiColor: .systemPurple)
        case .language: return Color(uiColor: .systemBlue)
        case .settings: return Color(uiColor: .systemGray)
        case .document: return Color(uiColor: .systemCyan)
        case .payment: return Color(uiColor: .systemGreen)
        case .waiting: return Color(uiColor: .systemYellow)
        case .paymentPending: return Color(uiColor: .systemOrange)
        case .confirmed: return Color(uiColor: .systemGreen)
        case .ready: return Color(uiColor: .systemTeal)
        case .inTrip: return Color(uiColor: .systemBlue)
        case .completed: return Color(uiColor: .systemIndigo)
        case .telegram: return Color(uiColor: .systemBlue)
        case .whatsapp: return Color(uiColor: .systemGreen)
        case .transfer: return Color(uiColor: .systemCyan)
        case .success: return Color(uiColor: .systemGreen)
        case .warning: return Color(uiColor: .systemYellow)
        case .destructive: return Color(uiColor: .systemRed)
        case .neutral: return Color(uiColor: .systemGray)
        }
    }

    static func inferred(from systemName: String) -> IumrahIconRole {
        let name = systemName.lowercased()

        if name.contains("trash") || name.contains("delete") { return .destructive }
        if name.contains("exclamation") || name.contains("warning") { return .warning }
        if name.contains("checkmark") || name.contains("seal") { return .success }
        if name.contains("creditcard") || name.contains("wallet") || name.contains("dollarsign") || name.contains("banknote") { return .payment }
        if name.contains("passport") || name.contains("doc") || name.contains("text.rectangle") || name.contains("id") { return .document }
        if name.contains("lock") || name.contains("shield") || name.contains("key") || name.contains("faceid") || name.contains("touchid") { return .security }
        if name.contains("bell") { return .notification }
        if name.contains("simcard") || name.contains("wifi") || name.contains("antenna") || name.contains("network") { return .connectivity }
        if name.contains("iphone") || name.contains("ipad") || name.contains("desktopcomputer") || name.contains("laptopcomputer") || name.contains("apps.iphone") { return .device }
        if name.contains("gift") { return .gift }
        if name.contains("magnifyingglass") || name.contains("scope") { return .search }
        if name.contains("star") { return .rating }
        if name.contains("lefthalf") || name.contains("sun.") || name == "sun.max.fill" || name.contains("paintpalette") { return .appearance }
        if name.contains("globe") || name.contains("character") { return .language }
        if name.contains("gear") || name.contains("slider") || name.contains("switch") { return .settings }
        if name.contains("mappin") || name.contains("location") || name.contains("map") { return .location }
        if name.contains("calendar") { return .calendar }
        if name.contains("clock") || name.contains("timer") { return .waiting }
        if name.contains("phone") { return .phone }
        if name.contains("envelope") || name.contains("mail") { return .mail }
        if name.contains("paperplane") || name.contains("message") || name.contains("bubble") || name.contains("chat") { return .message }
        if name.contains("heart") { return .care }
        if name.contains("building") || name.contains("bed") || name.contains("hotel") { return .hotel }
        if name.contains("suitcase") || name.contains("briefcase") || name.contains("ticket") { return .booking }
        if name.contains("airplane") || name.contains("car") || name.contains("bus") || name.contains("tram") || name.contains("ferry") { return .travel }
        if name.contains("book") || name.contains("moon.stars") || name.contains("hands") || name.contains("sparkles") { return .umrah }
        if name.contains("person") || name.contains("figure") { return .profile }
        if name.contains("plus") { return .accent }
        return .neutral
    }
}

/// One status = one color everywhere in the app. These are semantic state colors,
/// not decorative accents and never Liquid Glass tints.
enum IumrahBookingStatusVisual {
    static func role(for status: String) -> IumrahIconRole {
        switch status.uppercased() {
        case "NEW", "AVAILABILITY_CHECK": return .waiting
        case "PAYMENT_PENDING": return .paymentPending
        case "PAID", "BOOKING_CONFIRMED": return .confirmed
        case "DOCUMENTS_READY", "READY_TO_TRAVEL": return .ready
        case "IN_TRIP": return .inTrip
        case "COMPLETED": return .completed
        case "CANCELLED": return .destructive
        default: return .booking
        }
    }

    static func color(for status: String) -> Color { role(for: status).color }

    static func symbol(for status: String) -> String {
        switch status.uppercased() {
        case "NEW", "AVAILABILITY_CHECK": return "clock.fill"
        case "PAYMENT_PENDING": return "creditcard.fill"
        case "PAID", "BOOKING_CONFIRMED": return "checkmark.circle.fill"
        case "DOCUMENTS_READY", "READY_TO_TRAVEL": return "checkmark.seal.fill"
        case "IN_TRIP": return "location.fill"
        case "COMPLETED": return "flag.checkered"
        case "CANCELLED": return "xmark.circle.fill"
        default: return "suitcase.fill"
        }
    }
}

enum IumrahIconBadgeShape {
    case squircle
    case circle
}

/// Solid content icon badge. This intentionally never uses Liquid Glass.
/// It is the default for information rows, settings, cards and section headers.
struct IumrahIconBadge: View {
    let systemName: String
    var role: IumrahIconRole? = nil
    var tint: Color? = nil
    var size: CGFloat = 42
    var symbolSize: CGFloat = 16
    var cornerRadius: CGFloat = 14
    var shape: IumrahIconBadgeShape = .squircle

    private var resolvedRole: IumrahIconRole {
        role ?? IumrahIconRole.inferred(from: systemName)
    }

    private var resolvedColor: Color { tint ?? resolvedRole.color }

    private var symbolColor: Color {
        switch resolvedRole {
        case .waiting, .warning, .rating:
            return Color.black.opacity(0.78)
        default:
            return .white
        }
    }

    @ViewBuilder
    var body: some View {
        let symbol = Image(systemName: systemName)
            .font(.system(size: symbolSize, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(symbolColor)
            .frame(width: size, height: size)

        switch shape {
        case .squircle:
            symbol
                .background(resolvedColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        case .circle:
            symbol
                .background(resolvedColor, in: Circle())
        }
    }
}

/// Small semantic SF Symbol without a badge, for inline metadata.
struct IumrahInlineIcon: View {
    let systemName: String
    var role: IumrahIconRole? = nil
    var size: CGFloat = 14

    var body: some View {
        let resolvedRole = role ?? IumrahIconRole.inferred(from: systemName)
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(resolvedRole.color)
    }
}

struct IumrahCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.095), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
    }
}

struct IumrahMarketingCardModifier: ViewModifier {
    var dark: Bool

    func body(content: Content) -> some View {
        content
            .padding(22)
            .background {
                RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                    .fill(
                        dark
                        ? LinearGradient(colors: [Color.iumrahCareDark, Color.iumrahGraphite], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.iumrahCardBackground, Color.iumrahCardBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                    .strokeBorder(dark ? Color.white.opacity(0.08) : Color.primary.opacity(0.075), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(dark ? 0.14 : 0.045), radius: 20, y: 9)
    }
}

extension View {
    func iumrahCard() -> some View { modifier(IumrahCardModifier()) }
    func iumrahMarketingCard(dark: Bool = false) -> some View { modifier(IumrahMarketingCardModifier(dark: dark)) }
}

/// Primary call-to-action follows the AutoSale Umar reference: a crisp system
/// primary surface. Liquid Glass is reserved for floating / secondary controls.
struct IumrahPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .foregroundStyle(Color.iumrahPrimaryButtonText)
            .background(
                Color.iumrahPrimaryButtonBackground.opacity(configuration.isPressed ? 0.84 : 1),
                in: RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct IumrahSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .foregroundStyle(.primary)
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous),
                interactive: true,
                chrome: true
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

enum IumrahHaptics {
    static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

private struct IumrahGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?
    let allowsStaticGlass: Bool
    let chrome: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), chrome || allowsStaticGlass {
            // Liquid Glass is opt-in chrome only. `interactive` changes the glass
            // response after a control has been classified as chrome; it no longer
            // turns ordinary content controls into glass by itself.
            if let tint {
                content.glassEffect(.regular.interactive(interactive).tint(tint), in: shape)
            } else {
                content.glassEffect(.regular.interactive(interactive), in: shape)
            }
        } else {
            // Content/static fallback: deterministic adaptive surface, never fake glass.
            content
                .background(tint ?? Color.iumrahRaisedBackground, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.07), lineWidth: 0.7))
        }
    }
}

extension View {
    func iumrahGlass<S: Shape>(
        in shape: S,
        interactive: Bool = false,
        tint: Color? = nil,
        allowsStaticGlass: Bool = false,
        chrome: Bool = false
    ) -> some View {
        modifier(IumrahGlassModifier(
            shape: shape,
            interactive: interactive,
            tint: tint,
            allowsStaticGlass: allowsStaticGlass,
            chrome: chrome
        ))
    }
}

/// Canonical floating icon control used throughout the app.
/// Its iOS 26 appearance is entirely provided by Apple's Liquid Glass API.
struct IumrahGlassIconButton: View {
    let systemName: String
    var size: CGFloat = IumrahDesign.glassIconSize
    var fontSize: CGFloat = 17
    var foreground: Color? = nil
    var tint: Color? = nil
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(foreground ?? Color.primary)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .iumrahGlass(in: Circle(), interactive: true, tint: tint, chrome: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? systemName)
    }
}

/// Canonical glass surface for compact floating information and controls.
struct IumrahGlassSurface<Content: View>: View {
    var radius: CGFloat = 22
    var interactive = false
    var tint: Color? = nil
    private let content: Content

    init(
        radius: CGFloat = 22,
        interactive: Bool = false,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.interactive = interactive
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content.iumrahGlass(
            in: RoundedRectangle(cornerRadius: radius, style: .continuous),
            interactive: interactive,
            tint: tint,
            allowsStaticGlass: true,
            chrome: true
        )
    }
}

/// Groups nearby native Liquid Glass elements so iOS 26 can sample and morph
/// them as one visual system. Older iOS versions simply render the content.
struct IumrahGlassGroup<Content: View>: View {
    let spacing: CGFloat?
    private let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}
