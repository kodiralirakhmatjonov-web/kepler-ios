import SwiftUI

struct UmrahAdvisorHomeCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @AppStorage("iumrah.umrahFlow.guideLanguage") private var savedGuideLanguageCode = ""

    @State private var showsLanguagePicker = false
    @State private var startsFlow = false
    @State private var selectedGuideLanguage: UmrahGuideLanguage = .uzbek

    var body: some View {
        Button {
            IumrahHaptics.selection()
            selectedGuideLanguage = savedGuideLanguage
            showsLanguagePicker = true
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copy.title)
        .accessibilityHint(copy.subtitle)
        .sheet(isPresented: $showsLanguagePicker) {
            UmrahLanguagesSheet(selection: $selectedGuideLanguage) { language in
                savedGuideLanguageCode = language.rawValue
                showsLanguagePicker = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    startsFlow = true
                }
            }
            .environmentObject(settings)
        }
        .navigationDestination(isPresented: $startsFlow) {
            UmrahFlowRootView(initialStage: .start, guideLanguage: selectedGuideLanguage)
        }
    }

    private var cardContent: some View {
        ZStack(alignment: .bottom) {
            // A full-card living gradient. Black is part of the moving palette,
            // rather than a static cover above a colored glow at the bottom.
            UmrahAdvisorHomeAura()
                .allowsHitTesting(false)

            // Keep the interface readable without hiding the motion in the upper half.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.46),
                    Color.black.opacity(0.14),
                    Color.black.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .iumrahGlass(in: Circle(), tint: Color.white.opacity(0.10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("iumrah Advisor")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(copy.voiceGuide)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(copy.languages)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.66))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.white.opacity(0.075), in: Capsule())
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.09), lineWidth: 0.7)
                    }
                }

                Spacer(minLength: 16)

                Text(copy.title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.55)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(copy.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                Spacer(minLength: 22)

                HStack(spacing: 9) {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .bold))
                    Text(copy.button)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 17)
                .frame(height: 48)
                .background(Color.white.opacity(0.96), in: Capsule())
                .shadow(color: .black.opacity(0.16), radius: 14, y: 7)
            }
            .padding(19)
        }
        .frame(maxWidth: .infinity, minHeight: 268, maxHeight: 268, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 31, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
        }
        .shadow(color: Color(red: 0.24, green: 0.10, blue: 0.56).opacity(0.14), radius: 24, y: 12)
    }

    private var savedGuideLanguage: UmrahGuideLanguage {
        if let stored = UmrahGuideLanguage(rawValue: savedGuideLanguageCode) {
            return stored
        }
        return UmrahGuideLanguage.preferred(for: settings.language)
    }

    private var copy: (title: String, subtitle: String, button: String, languages: String, voiceGuide: String) {
        switch settings.language {
        case .russian:
            return (
                "Начать Умру",
                "Advisor проведёт Вас голосом через Таваф, Сафа и Марва и завершение Умры.",
                "Начать",
                "10 языков",
                "Голосовой гид для Умры"
            )
        case .turkish:
            return (
                "Umreye başla",
                "Advisor, tavaftan Safa ile Merve arasındaki sa'ye ve umrenin tamamlanmasına kadar size sesli rehberlik eder.",
                "Başla",
                "10 dil",
                "Umre için sesli rehber"
            )
        case .indonesian, .english:
            return (
                "Start Umrah",
                "Advisor guides you by voice through Tawaf, Safa & Marwa and the completion of Umrah.",
                "Start",
                "10 languages",
                "Voice guide for Umrah"
            )
        case .uzbek:
            return (
                "Umrani boshlash",
                "Advisor Tavof, Safo va Marva hamda Umrani yakunlashgacha ovoz bilan kuzatadi.",
                "Boshlash",
                "10 til",
                "Umra uchun ovozli gid"
            )
        case .uzbekCyrillic:
            return (
                "Умрани бошлаш",
                "Advisor Тавоф, Сафо ва Марва ҳамда Умрани якунлашгача овоз билан кузатади.",
                "Бошлаш",
                "10 тил",
                "Умра учун овозли гид"
            )
        }
    }
}

struct UmrahAdvisorHomeAura: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 8.0 : 1.0 / 30.0)) { timeline in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let radius = max(proxy.size.width, proxy.size.height) * 0.82

                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.008, green: 0.008, blue: 0.012),
                            Color(red: 0.055, green: 0.025, blue: 0.085),
                            Color(red: 0.010, green: 0.010, blue: 0.014),
                            Color(red: 0.070, green: 0.026, blue: 0.058)
                        ],
                        startPoint: UnitPoint(
                            x: 0.10 + sin(time * 0.105) * 0.08,
                            y: 0.02 + cos(time * 0.090) * 0.06
                        ),
                        endPoint: UnitPoint(
                            x: 0.92 + cos(time * 0.082) * 0.08,
                            y: 0.96 + sin(time * 0.096) * 0.05
                        )
                    )

                    RadialGradient(
                        colors: [
                            Color(red: 0.49, green: 0.12, blue: 1.00).opacity(0.74),
                            Color(red: 0.31, green: 0.05, blue: 0.72).opacity(0.30),
                            .clear
                        ],
                        center: UnitPoint(
                            x: 0.18 + sin(time * 0.116 + 0.7) * 0.14,
                            y: 0.64 + cos(time * 0.093 + 1.1) * 0.18
                        ),
                        startRadius: 0,
                        endRadius: radius * 0.74
                    )

                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.25, blue: 0.72).opacity(0.56),
                            Color(red: 0.88, green: 0.12, blue: 0.57).opacity(0.20),
                            .clear
                        ],
                        center: UnitPoint(
                            x: 0.48 + cos(time * 0.088 + 2.2) * 0.17,
                            y: 0.72 + sin(time * 0.109 + 0.4) * 0.16
                        ),
                        startRadius: 0,
                        endRadius: radius * 0.62
                    )

                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.43, blue: 0.08).opacity(0.54),
                            Color(red: 1.00, green: 0.28, blue: 0.04).opacity(0.17),
                            .clear
                        ],
                        center: UnitPoint(
                            x: 0.82 + sin(time * 0.079 + 4.0) * 0.12,
                            y: 0.53 + cos(time * 0.101 + 2.8) * 0.20
                        ),
                        startRadius: 0,
                        endRadius: radius * 0.66
                    )

                    // A drifting black field keeps the card deep and prevents the
                    // palette from turning into a permanently bright rainbow.
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.90),
                            Color.black.opacity(0.48),
                            .clear
                        ],
                        center: UnitPoint(
                            x: 0.56 + sin(time * 0.071 + 3.0) * 0.24,
                            y: 0.18 + cos(time * 0.067 + 1.7) * 0.13
                        ),
                        startRadius: 0,
                        endRadius: radius * 0.57
                    )

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.26),
                            Color.clear,
                            Color.black.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .drawingGroup(opaque: false, colorMode: .extendedLinear)
            }
        }
        .accessibilityHidden(true)
    }
}
