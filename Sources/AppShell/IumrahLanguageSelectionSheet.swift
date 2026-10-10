import SwiftUI

struct IumrahLanguageSelectionSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingLanguage: AppSettingsStore.Language

    init(currentLanguage: AppSettingsStore.Language = .uzbek) {
        _pendingLanguage = State(initialValue: currentLanguage)
    }

    private struct LanguageOption: Identifiable {
        let language: AppSettingsStore.Language
        let flag: String
        let nativeName: String
        let subtitle: String

        var id: String { language.id }
    }

    private var availableLanguages: [LanguageOption] {
        [
            LanguageOption(language: .english, flag: "EN", nativeName: "English", subtitle: "Global · Latin"),
            LanguageOption(language: .russian, flag: "RU", nativeName: "Русский", subtitle: "Россия · Кириллица"),
            LanguageOption(language: .turkish, flag: "TR", nativeName: "Türkçe", subtitle: "Türkiye · Latin"),
            LanguageOption(language: .indonesian, flag: "ID", nativeName: "Bahasa Indonesia", subtitle: "Indonesia · Latin"),
            LanguageOption(language: .malay, flag: "MY", nativeName: "Bahasa Melayu", subtitle: "Malaysia · Rumi"),
            LanguageOption(language: .uzbek, flag: "UZ", nativeName: "O‘zbekcha", subtitle: "O‘zbekiston · Lotin"),
            LanguageOption(language: .uzbekCyrillic, flag: "ЎЗ", nativeName: "Ўзбекча", subtitle: "Ўзбекистон · Кирилл")
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                languageSection
                helperFootnote
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            confirmBar
        }
        .onAppear {
            pendingLanguage = settings.language
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("LanguageSelectionHero")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(pageTitle)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.65)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pageSubtitle)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sectionTitle)
                .font(.caption.weight(.bold))
                .tracking(0.9)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(Array(availableLanguages.enumerated()), id: \.element.id) { index, option in
                    languageRow(option)

                    if index < availableLanguages.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .iumrahCard()
        }
    }

    private func languageRow(_ option: LanguageOption) -> some View {
        let isSelected = pendingLanguage == option.language
        let isCurrent = settings.language == option.language

        return Button {
            IumrahHaptics.selection()
            withAnimation(.easeInOut(duration: 0.18)) {
                pendingLanguage = option.language
            }
        } label: {
            HStack(spacing: 13) {
                Text(option.flag)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.nativeName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.iumrahCareLight)
                        .transition(.scale.combined(with: .opacity))
                } else if isCurrent {
                    Text(currentBadgeTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.primary.opacity(0.055), in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var helperFootnote: some View {
        Label(footnoteTitle, systemImage: "globe")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private var confirmBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.35)

            Button {
                guard pendingLanguage != settings.language else {
                    dismiss()
                    return
                }
                settings.language = pendingLanguage
                IumrahHaptics.success()
                dismiss()
            } label: {
                Text(confirmButtonTitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.plain)
            .foregroundStyle(buttonForeground)
            .background(buttonBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(pendingLanguage == settings.language ? 0.06 : 0.10), lineWidth: 1)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .disabled(pendingLanguage == settings.language)
            .opacity(pendingLanguage == settings.language ? 0.72 : 1)
        }
        .background(.ultraThinMaterial)
    }

    private var buttonBackground: Color {
        pendingLanguage == settings.language ? Color.primary.opacity(0.055) : Color.primary
    }

    private var buttonForeground: Color {
        pendingLanguage == settings.language ? .primary : .white
    }

    private var navigationTitle: String {
        localized(
            ru: "Язык",
            en: "Language",
            tr: "Dil",
            uz: "Til",
            uzCy: "Тил"
        )
    }

    private var pageTitle: String {
        localized(
            ru: "iumrah — международная платформа Umrah",
            en: "iumrah International Umrah Platform",
            tr: "iumrah Uluslararası Umre Platformu",
            uz: "iumrah xalqaro Umra platformasi",
            uzCy: "iumrah халқаро Умра платформаси"
        )
    }

    private var pageSubtitle: String {
        localized(
            ru: "Мир, объединённый намерением",
            en: "A world united by intention",
            tr: "Niyetle birleşen bir dünya",
            uz: "Niyat bilan birlashgan dunyo",
            uzCy: "Ният билан бирлашган дунё"
        )
    }

    private var sectionTitle: String {
        localized(
            ru: "Выберите язык приложения",
            en: "Choose your app language",
            tr: "Uygulama dilinizi seçin",
            uz: "Ilova tilini tanlang",
            uzCy: "Илова тилини танланг"
        )
    }

    private var currentBadgeTitle: String {
        localized(
            ru: "ТЕКУЩИЙ",
            en: "CURRENT",
            tr: "MEVCUT",
            uz: "JORIY",
            uzCy: "ЖОРИЙ"
        )
    }

    private var footnoteTitle: String {
        localized(
            ru: "После подтверждения интерфейс iumrah сразу переключится на выбранный язык.",
            en: "After confirmation, the iumrah interface switches to the language you selected.",
            tr: "Onaydan sonra iumrah arayüzü seçtiğiniz dile hemen geçer.",
            uz: "Tasdiqlagandan so‘ng iumrah interfeysi darhol tanlangan tilga o‘tadi.",
            uzCy: "Тасдиқлагандан сўнг iumrah интерфейси дарҳол танланган тилга ўтади."
        )
    }

    private var confirmButtonTitle: String {
        guard pendingLanguage != settings.language else {
            return localized(
                ru: "Текущий язык уже выбран",
                en: "Current language already selected",
                tr: "Geçerli dil zaten seçili",
                uz: "Joriy til allaqachon tanlangan",
                uzCy: "Жорий тил аллақачон танланган"
            )
        }

        switch pendingLanguage {
        case .russian:
            return "Переключить на Русский"
        case .english:
            return "Change to English"
        case .turkish:
            return "Türkçe’ye geç"
        case .indonesian:
            return "Ganti ke Bahasa Indonesia"
        case .malay:
            return "Tukar kepada Bahasa Melayu"
        case .uzbek:
            return "O‘zbekchaga o‘tish"
        case .uzbekCyrillic:
            return "Ўзбекчага ўтиш"
        }
    }

    private func localized(ru: String, en: String, tr: String, uz: String, uzCy: String) -> String {
        switch pendingLanguage {
        case .russian: return ru
        case .english: return en
        case .turkish: return tr
        case .indonesian: return IndonesianLocalization.phrase(en)
        case .malay: return MalayLocalization.phrase(en)
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}
