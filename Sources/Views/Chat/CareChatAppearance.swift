import SwiftUI
import UIKit


final class CareChatAppearanceStore: ObservableObject {
    @Published var wallpaper: CareChatWallpaper {
        didSet {
            UserDefaults.standard.set(wallpaper.rawValue, forKey: wallpaperKey)
        }
    }

    @Published var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: Self.soundsKey) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Self.hapticsKey) }
    }

    @Published private(set) var founderConnected: Bool {
        didSet { UserDefaults.standard.set(founderConnected, forKey: founderConnectedKey) }
    }

    @Published private(set) var customImage: UIImage?

    private let bookingID: String
    private let wallpaperKey: String
    private let founderConnectedKey: String
    private static let soundsKey = "iumrah.care.chat.sounds.enabled.v2"
    private static let hapticsKey = "iumrah.care.chat.haptics.enabled.v2"

    init(bookingID: String) {
        self.bookingID = bookingID
        self.wallpaperKey = "iumrah.care.chat.wallpaper.\(bookingID).v2"
        self.founderConnectedKey = "iumrah.care.chat.founder-connected.\(bookingID).v1"

        // Preserve a v1 choice if the user already used the first Care chat build.
        let legacyWallpaperKey = "iumrah.care.chat.wallpaper.\(bookingID).v1"
        let saved = UserDefaults.standard.string(forKey: wallpaperKey)
            ?? UserDefaults.standard.string(forKey: legacyWallpaperKey)
        self.wallpaper = CareChatWallpaper(rawValue: saved ?? "") ?? .none

        if let stored = UserDefaults.standard.object(forKey: Self.soundsKey) as? Bool {
            self.soundsEnabled = stored
        } else if let legacy = UserDefaults.standard.object(forKey: "iumrah.care.chat.sounds.enabled.v1") as? Bool {
            self.soundsEnabled = legacy
        } else {
            self.soundsEnabled = true
        }

        if let stored = UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool {
            self.hapticsEnabled = stored
        } else if let legacy = UserDefaults.standard.object(forKey: "iumrah.care.chat.haptics.enabled.v1") as? Bool {
            self.hapticsEnabled = legacy
        } else {
            self.hapticsEnabled = true
        }

        self.founderConnected = UserDefaults.standard.bool(forKey: founderConnectedKey)
        self.customImage = Self.loadCustomImage(bookingID: bookingID)
        if wallpaper == .photo, customImage == nil {
            wallpaper = .none
        }
    }

    func connectFounder() {
        guard !founderConnected else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            founderConnected = true
        }
    }

    func select(_ value: CareChatWallpaper) {
        guard value != .photo || customImage != nil else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.92)) {
            wallpaper = value
        }
    }

    func setCustomPhoto(data: Data) {
        guard let image = UIImage(data: data) else { return }
        let normalized = Self.normalizedWallpaperImage(image)
        guard let jpeg = normalized.jpegData(compressionQuality: 0.88) else { return }

        do {
            let url = try Self.customImageURL(bookingID: bookingID, createDirectory: true)
            try jpeg.write(to: url, options: .atomic)
            customImage = normalized
            withAnimation(.spring(response: 0.42, dampingFraction: 0.92)) {
                wallpaper = .photo
            }
        } catch {
            // Wallpaper is presentation-only. Never let a disk failure affect chat.
        }
    }

    private static func normalizedWallpaperImage(_ image: UIImage) -> UIImage {
        let maxSide: CGFloat = 2200
        let sourceSize = image.size
        let largest = max(sourceSize.width, sourceSize.height)
        let scale = largest > maxSide ? maxSide / largest : 1
        let target = CGSize(
            width: max(1, sourceSize.width * scale),
            height: max(1, sourceSize.height * scale)
        )
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func loadCustomImage(bookingID: String) -> UIImage? {
        guard let url = try? customImageURL(bookingID: bookingID, createDirectory: false),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private static func customImageURL(bookingID: String, createDirectory: Bool) throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("IumrahCareWallpapers", isDirectory: true)
        if createDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let safeID = bookingID
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        return directory.appendingPathComponent("\(safeID).jpg")
    }
}

enum CareChatWallpaper: String, CaseIterable, Identifiable {
    case none
    case photo
    case dawn
    case sky
    case water
    case aurora
    case sand
    case makkah

    var id: String { rawValue }
    var isVisual: Bool { self != .none }

    var readabilityOverlayOpacity: Double {
        switch self {
        case .none: return 0
        case .photo: return 0.28
        case .dawn: return 0.20
        case .sky: return 0.24
        case .water: return 0.18
        case .aurora: return 0.14
        case .sand: return 0.24
        case .makkah: return 0.22
        }
    }

    var isAnimated: Bool {
        switch self {
        case .aurora, .water, .dawn: return true
        default: return false
        }
    }

    func title(_ language: AppSettingsStore.Language) -> String {
        switch self {
        case .none: return tr(language, "None", "Без фона", "Fonsiz", "Фонсиз")
        case .photo: return tr(language, "Photo", "Фото", "Foto", "Фото")
        case .dawn: return tr(language, "Color", "Цвет", "Rang", "Ранг")
        case .sky: return tr(language, "Sky", "Небо", "Osmon", "Осмон")
        case .water: return tr(language, "Water", "Вода", "Suv", "Сув")
        case .aurora: return tr(language, "Aurora", "Аврора", "Avrora", "Аврора")
        case .sand: return tr(language, "Sand", "Песок", "Qum", "Қум")
        case .makkah: return tr(language, "Makkah", "Мекка", "Makka", "Макка")
        }
    }

    private func tr(
        _ language: AppSettingsStore.Language,
        _ en: String,
        _ ru: String,
        _ uz: String,
        _ cyrl: String
    ) -> String {
        switch language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

struct CareConversationBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let wallpaper: CareChatWallpaper
    let customImage: UIImage?
    let motionEnabled: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if wallpaper.isAnimated && !reduceMotion && motionEnabled {
                    TimelineView(.periodic(from: .now, by: 1.0 / 15.0)) { context in
                        animatedBase(
                            wallpaper,
                            size: proxy.size,
                            time: context.date.timeIntervalSinceReferenceDate
                        )
                    }
                } else {
                    staticBase(wallpaper, size: proxy.size, time: 0)
                }

                if wallpaper.isVisual {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(wallpaper.readabilityOverlayOpacity * 0.45),
                            Color.black.opacity(wallpaper.readabilityOverlayOpacity * 0.72),
                            Color.black.opacity(wallpaper.readabilityOverlayOpacity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .id(wallpaper.rawValue)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.38), value: wallpaper)
    }

    @ViewBuilder
    private func animatedBase(_ value: CareChatWallpaper, size: CGSize, time: TimeInterval) -> some View {
        staticBase(value, size: size, time: time)
    }

    @ViewBuilder
    private func staticBase(_ value: CareChatWallpaper, size: CGSize, time: TimeInterval) -> some View {
        switch value {
        case .none:
            Color(uiColor: .systemBackground)

        case .photo:
            if let customImage {
                Image(uiImage: customImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Color.iumrahPageBackground
            }

        case .aurora:
            CareAuroraWallpaper(size: size, time: time)

        case .water:
            CareWaterWallpaper(size: size, time: time)

        case .dawn:
            CareDawnWallpaper(size: size, time: time)

        case .sky:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.31, blue: 0.57),
                        Color(red: 0.37, green: 0.66, blue: 0.86),
                        Color(red: 0.78, green: 0.90, blue: 0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.13 + Double(index % 2) * 0.025))
                        .frame(width: size.width * 1.25, height: 72 + CGFloat(index * 8))
                        .blur(radius: 27)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -5 : 4))
                        .offset(
                            x: index.isMultiple(of: 2) ? -size.width * 0.18 : size.width * 0.20,
                            y: CGFloat(index) * size.height * 0.19 - size.height * 0.35
                        )
                }
            }

        case .sand:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.91, blue: 0.82),
                        Color(red: 0.84, green: 0.74, blue: 0.61),
                        Color(red: 0.60, green: 0.51, blue: 0.44)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.white.opacity(0.36))
                    .frame(width: size.width * 1.18)
                    .blur(radius: 54)
                    .offset(x: size.width * 0.28, y: -size.height * 0.28)
                Circle()
                    .fill(Color.orange.opacity(0.10))
                    .frame(width: size.width * 1.35)
                    .blur(radius: 72)
                    .offset(x: -size.width * 0.34, y: size.height * 0.34)
            }

        case .makkah:
            Image("MakkahBackground")
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        }
    }
}

private struct CareAuroraWallpaper: View {
    let size: CGSize
    let time: TimeInterval

    var body: some View {
        let slow = sin(time * 0.12)
        let medium = cos(time * 0.17)

        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.008, green: 0.028, blue: 0.065),
                    Color(red: 0.010, green: 0.18, blue: 0.25),
                    Color(red: 0.055, green: 0.055, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(Color.cyan.opacity(0.48))
                .frame(width: size.width * 0.56, height: size.height * 1.13)
                .blur(radius: 50)
                .rotationEffect(.degrees(12 + medium * 2.0))
                .offset(x: size.width * (0.20 + slow * 0.04), y: -size.height * 0.05)

            Ellipse()
                .fill(Color.blue.opacity(0.34))
                .frame(width: size.width * 0.74, height: size.height * 1.18)
                .blur(radius: 66)
                .rotationEffect(.degrees(-15 + slow * 2.2))
                .offset(x: -size.width * (0.30 + medium * 0.03), y: size.height * 0.10)

            Ellipse()
                .fill(Color.purple.opacity(0.29))
                .frame(width: size.width * 0.86, height: size.height * 0.82)
                .blur(radius: 74)
                .offset(x: size.width * (0.40 + slow * 0.035), y: size.height * 0.38)

            LinearGradient(
                colors: [Color.clear, Color.white.opacity(0.10), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: size.width * 0.18, height: size.height * 1.18)
            .blur(radius: 24)
            .rotationEffect(.degrees(9))
            .offset(x: size.width * (0.06 + medium * 0.05), y: -size.height * 0.04)
        }
    }
}

private struct CareWaterWallpaper: View {
    let size: CGSize
    let time: TimeInterval

    var body: some View {
        let drift = sin(time * 0.20)
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.24, blue: 0.34),
                    Color(red: 0.06, green: 0.50, blue: 0.60),
                    Color(red: 0.48, green: 0.80, blue: 0.80)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .stroke(Color.white.opacity(0.09 + Double(index % 3) * 0.018), lineWidth: 8)
                    .frame(width: size.width * 1.28, height: 74 + CGFloat(index * 3))
                    .blur(radius: 5)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -7 : 8))
                    .offset(
                        x: (index.isMultiple(of: 2) ? -size.width * 0.18 : size.width * 0.24) + CGFloat(drift) * 14,
                        y: CGFloat(index) * size.height * 0.15 - size.height * 0.36
                    )
            }

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: size.width * 0.72)
                .blur(radius: 60)
                .offset(x: size.width * 0.32, y: -size.height * 0.28)
        }
    }
}

private struct CareDawnWallpaper: View {
    let size: CGSize
    let time: TimeInterval

    var body: some View {
        let drift = cos(time * 0.13)
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.08, blue: 0.25),
                    Color(red: 0.43, green: 0.22, blue: 0.42),
                    Color(red: 0.94, green: 0.47, blue: 0.39),
                    Color(red: 0.99, green: 0.78, blue: 0.60)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.pink.opacity(0.24))
                .frame(width: size.width * 1.16)
                .blur(radius: 72)
                .offset(x: size.width * (0.34 + drift * 0.025), y: size.height * 0.08)

            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: size.width * 0.90)
                .blur(radius: 60)
                .offset(x: -size.width * 0.32, y: size.height * 0.34)
        }
    }
}

struct CareWallpaperPreview: View {
    let wallpaper: CareChatWallpaper
    let customImage: UIImage?

    var body: some View {
        ZStack {
            switch wallpaper {
            case .none:
                LinearGradient(
                    colors: [Color.iumrahPageBackground, Color.iumrahRaisedBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

            case .photo:
                if let customImage {
                    Image(uiImage: customImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color.white.opacity(0.92), Color.iumrahRaisedBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.secondary)
                    }
                }

            case .dawn:
                LinearGradient(
                    colors: [Color.purple.opacity(0.88), Color.pink, Color.orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

            case .sky:
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.38, blue: 0.68),
                        Color(red: 0.54, green: 0.78, blue: 0.94),
                        Color.white.opacity(0.86)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

            case .water:
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.28, blue: 0.40),
                        Color(red: 0.09, green: 0.60, blue: 0.69),
                        Color(red: 0.57, green: 0.86, blue: 0.84)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

            case .aurora:
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.04, blue: 0.10),
                        Color.cyan.opacity(0.86),
                        Color.blue.opacity(0.82),
                        Color.purple.opacity(0.74)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

            case .sand:
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.92, blue: 0.82),
                        Color(red: 0.81, green: 0.68, blue: 0.51),
                        Color(red: 0.56, green: 0.47, blue: 0.41)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

            case .makkah:
                Image("MakkahBackground")
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
    }
}
