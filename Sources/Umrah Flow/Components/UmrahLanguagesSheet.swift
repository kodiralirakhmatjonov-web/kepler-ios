import SwiftUI

enum UmrahGuideLanguage: String, CaseIterable, Identifiable, Hashable {
    case russian = "ru"
    case english = "en"
    case uzbek = "uz"
    case kazakh = "kk"
    case indonesian = "id"
    case turkish = "tr"
    case arabic = "ar"
    case malay = "ms"
    case bengali = "bn"
    case french = "fr"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        case .uzbek: return "O‘zbek"
        case .kazakh: return "Қазақша"
        case .indonesian: return "Bahasa Indonesia"
        case .turkish: return "Türkçe"
        case .arabic: return "العربية"
        case .malay: return "Bahasa Melayu"
        case .bengali: return "বাংলা"
        case .french: return "Français"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .russian: return "ru_RU"
        case .english: return "en_US"
        case .uzbek: return "uz_Latn_UZ"
        case .kazakh: return "kk_KZ"
        case .indonesian: return "id_ID"
        case .turkish: return "tr_TR"
        case .arabic: return "ar_SA"
        case .malay: return "ms_MY"
        case .bengali: return "bn_BD"
        case .french: return "fr_FR"
        }
    }

    static func preferred(for appLanguage: AppSettingsStore.Language) -> UmrahGuideLanguage {
        switch appLanguage {
        case .russian: return .russian
        case .english: return .english
        case .turkish: return .turkish
        case .indonesian: return .indonesian
        case .malay: return .malay
        case .uzbek, .uzbekCyrillic: return .uzbek
        }
    }
}

struct UmrahLanguagesSheet: View {
    @Binding var selection: UmrahGuideLanguage
    let onStart: (UmrahGuideLanguage) -> Void

    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(palette.textSecondary.opacity(0.24))
                .frame(width: 38, height: 5)
                .padding(.top, 7)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(palette.accent)

                        Text(copy.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                    }

                    Text(copy.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                UmrahGlassIconButton(
                    systemName: "xmark",
                    foreground: palette.textPrimary,
                    accessibilityLabel: copy.close
                ) {
                    dismiss()
                }
            }
            .padding(.horizontal, 20)

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(UmrahGuideLanguage.allCases) { language in
                        languageButton(language)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            Button {
                IumrahHaptics.selection()
                onStart(selection)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                    Text(copy.start)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .iumrahGlass(in: Capsule(), interactive: true, tint: palette.accent.opacity(colorScheme == .dark ? 0.52 : 0.62))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .presentationDetents([.fraction(0.68), .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
    }

    private func languageButton(_ language: UmrahGuideLanguage) -> some View {
        let isSelected = selection == language

        return Button {
            IumrahHaptics.selection()
            withAnimation(.smooth(duration: 0.28, extraBounce: 0)) {
                selection = language
            }
        } label: {
            HStack(spacing: 9) {
                Text(language.nativeName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 3)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : palette.textSecondary.opacity(0.42))
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: 19, style: .continuous),
                interactive: true,
                tint: isSelected ? palette.accent.opacity(colorScheme == .dark ? 0.52 : 0.62) : nil
            )
        }
        .buttonStyle(.plain)
    }

    private var copy: (title: String, subtitle: String, start: String, close: String) {
        switch settings.language {
        case .russian:
            return (
                "Язык iumrah Advisor",
                "Выберите язык голосового гида перед началом Умры.",
                "Начать Умру",
                "Закрыть"
            )
        case .english:
            return (
                "iumrah Advisor language",
                "Choose the voice-guide language before you begin Umrah.",
                "Start Umrah",
                "Close"
            )
        case .turkish:
            return (
                "iumrah Advisor dili",
                "Umreye başlamadan önce sesli rehberin dilini seçin.",
                "Umreye başla",
                "Kapat"
            )
        case .indonesian:
            return (
                "Bahasa iumrah Advisor",
                "Pilih bahasa panduan suara sebelum memulai Umrah.",
                "Mulai Umrah",
                "Tutup"
            )
        case .malay:
            return (
                "Bahasa iumrah Advisor",
                "Pilih bahasa panduan suara sebelum memulakan Umrah.",
                "Mulakan Umrah",
                "Tutup"
            )
        case .uzbek:
            return (
                "iumrah Advisor tili",
                "Umrani boshlashdan oldin ovozli gid tilini tanlang.",
                "Umrani boshlash",
                "Yopish"
            )
        case .uzbekCyrillic:
            return (
                "iumrah Advisor тили",
                "Умрани бошлашдан олдин овозли гид тилини танланг.",
                "Умрани бошлаш",
                "Ёпиш"
            )
        }
    }
}
