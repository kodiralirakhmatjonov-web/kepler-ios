import SwiftUI
import UIKit

struct IumrahAppearanceView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentAlternateIconName: String? = nil
    @State private var iconBeingChanged: AppIconOption? = nil
    @State private var isChangingIcon = false
    @State private var iconErrorMessage: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                themeSection
                appIconSection
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 14)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(tr("Appearance", "Оформление", "Ko‘rinish", "Кўриниш"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshCurrentIcon()
        }
        .alert(
            tr("Couldn’t change icon", "Не удалось изменить иконку", "Ikonkani o‘zgartirib bo‘lmadi", "Иконкани ўзгартириб бўлмади"),
            isPresented: Binding(
                get: { iconErrorMessage != nil },
                set: { if !$0 { iconErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { iconErrorMessage = nil }
        } message: {
            if let iconErrorMessage {
                Text(iconErrorMessage)
            }
        }
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                tr("Theme", "Тема", "Mavzu", "Мавзу"),
                subtitle: tr(
                    "Choose how iumrah looks on this iPhone.",
                    "Выберите, как iumrah выглядит на этом iPhone.",
                    "iumrah ushbu iPhone’da qanday ko‘rinishini tanlang.",
                    "iumrah ушбу iPhone’да қандай кўринишини танланг."
                )
            )

            VStack(spacing: 0) {
                ForEach(Array(AppSettingsStore.Appearance.allCases.enumerated()), id: \.element.id) { index, appearance in
                    Button {
                        IumrahHaptics.selection()
                        withAnimation(.easeInOut(duration: 0.18)) {
                            settings.appearance = appearance
                        }
                    } label: {
                        HStack(spacing: 13) {
                            IumrahIconBadge(
                                systemName: appearanceSymbol(appearance),
                                role: .appearance,
                                size: 42,
                                symbolSize: 17,
                                cornerRadius: 14
                            )

                            Text(appearance.title(settings.language))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)

                            Spacer(minLength: 10)

                            if settings.appearance == appearance {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(Color.iumrahCareLight)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 62)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < AppSettingsStore.Appearance.allCases.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .iumrahCard()
        }
    }

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                tr("App icon", "Иконка приложения", "Ilova ikonkasi", "Илова иконкаси"),
                subtitle: tr(
                    "Choose how iumrah appears on your Home Screen.",
                    "Выберите, как iumrah выглядит на главном экране.",
                    "iumrah bosh ekranda qanday ko‘rinishini tanlang.",
                    "iumrah бош экранда қандай кўринишини танланг."
                )
            )

            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(AppIconOption.allCases) { option in
                            appIconButton(option)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollClipDisabled()

                Divider()

                Button {
                    changeAppIcon(to: nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 38, height: 38)
                            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Standard icon", "Стандартная иконка", "Standart ikonka", "Стандарт иконка"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(tr("Restore the original iumrah icon", "Вернуть исходную иконку iumrah", "Asl iumrah ikonkasini qaytarish", "Асл iumrah иконкасини қайтариш"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        if currentAlternateIconName == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.iumrahCareLight)
                        } else if iconBeingChanged == nil {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isChangingIcon || currentAlternateIconName == nil)
                .opacity(currentAlternateIconName == nil ? 0.82 : 1)
            }
            .padding(16)
            .iumrahCard()

            if !UIApplication.shared.supportsAlternateIcons {
                Label(
                    tr(
                        "Icon switching isn’t available on this device.",
                        "Смена иконки недоступна на этом устройстве.",
                        "Bu qurilmada ikonka almashtirish mavjud emas.",
                        "Бу қурилмада иконка алмаштириш мавжуд эмас."
                    ),
                    systemImage: "info.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
        }
    }

    private func appIconButton(_ option: AppIconOption) -> some View {
        let isSelected = currentAlternateIconName == option.alternateIconName
        let isLoading = iconBeingChanged == option

        return Button {
            changeAppIcon(to: option)
        } label: {
            VStack(spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    Image(option.previewAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.primary.opacity(0.30) : Color.primary.opacity(0.07),
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                        }
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.09), radius: 12, y: 6)

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 28, height: 28)
                            .background(.black.opacity(0.72), in: Circle())
                            .padding(6)
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.black.opacity(0.82), in: Circle())
                            .overlay { Circle().strokeBorder(.white.opacity(0.24), lineWidth: 1) }
                            .padding(6)
                    }
                }

                Text(option.displayName)
                    .font(.caption2.weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
            .frame(width: 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isChangingIcon || isSelected || !UIApplication.shared.supportsAlternateIcons)
        .accessibilityLabel(option.accessibilityName(settings.language))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(-0.25)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private func changeAppIcon(to option: AppIconOption?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let targetName = option?.alternateIconName
        guard currentAlternateIconName != targetName else { return }

        isChangingIcon = true
        iconBeingChanged = option
        IumrahHaptics.selection()

        UIApplication.shared.setAlternateIconName(targetName) { error in
            DispatchQueue.main.async {
                isChangingIcon = false
                iconBeingChanged = nil

                if let error {
                    IumrahHaptics.error()
                    iconErrorMessage = error.localizedDescription
                    refreshCurrentIcon()
                    return
                }

                currentAlternateIconName = UIApplication.shared.alternateIconName
                IumrahHaptics.success()
            }
        }
    }

    private func refreshCurrentIcon() {
        currentAlternateIconName = UIApplication.shared.alternateIconName
    }

    private func appearanceSymbol(_ appearance: AppSettingsStore.Appearance) -> String {
        switch appearance {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private enum AppIconOption: String, CaseIterable, Identifiable {
    case blue
    case cyan
    case deepBlue
    case world
    case makkah

    var id: String { rawValue }

    var alternateIconName: String {
        switch self {
        case .blue: return "AppIconBlue"
        case .cyan: return "AppIconCyan"
        case .deepBlue: return "AppIconDeepBlue"
        case .world: return "AppIconWorld"
        case .makkah: return "AppIconMakkah"
        }
    }

    var previewAssetName: String {
        switch self {
        case .blue: return "AppIconBluePreview"
        case .cyan: return "AppIconCyanPreview"
        case .deepBlue: return "AppIconDeepBluePreview"
        case .world: return "AppIconWorldPreview"
        case .makkah: return "AppIconMakkahPreview"
        }
    }

    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .deepBlue: return "Deep"
        case .world: return "World"
        case .makkah: return "Makkah"
        }
    }

    func accessibilityName(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian:
            switch self {
            case .blue: return "Синяя иконка iumrah"
            case .cyan: return "Бирюзово-синяя иконка iumrah"
            case .deepBlue: return "Тёмно-синяя иконка iumrah"
            case .world: return "Иконка iumrah с картой мира"
            case .makkah: return "Иконка iumrah с Каабой"
            }
        case .uzbek:
            switch self {
            case .blue: return "Ko‘k iumrah ikonkasi"
            case .cyan: return "Moviy iumrah ikonkasi"
            case .deepBlue: return "To‘q ko‘k iumrah ikonkasi"
            case .world: return "Dunyo xaritasi bilan iumrah ikonkasi"
            case .makkah: return "Ka’ba bilan iumrah ikonkasi"
            }
        case .uzbekCyrillic:
            switch self {
            case .blue: return "Кўк iumrah иконкаси"
            case .cyan: return "Мовий iumrah иконкаси"
            case .deepBlue: return "Тўқ кўк iumrah иконкаси"
            case .world: return "Дунё харитаси билан iumrah иконкаси"
            case .makkah: return "Каъба билан iumrah иконкаси"
            }
        case .turkish:
            switch self {
            case .blue: return "Mavi iumrah uygulama simgesi"
            case .cyan: return "Turkuaz iumrah uygulama simgesi"
            case .deepBlue: return "Koyu mavi iumrah uygulama simgesi"
            case .world: return "Dünya haritalı iumrah uygulama simgesi"
            case .makkah: return "Mekke temalı iumrah uygulama simgesi"
            }
        case .indonesian, .english:
            switch self {
            case .blue: return "Blue iumrah app icon"
            case .cyan: return "Cyan iumrah app icon"
            case .deepBlue: return "Deep blue iumrah app icon"
            case .world: return "iumrah world map app icon"
            case .makkah: return "iumrah Makkah app icon"
            }
        }
    }
}
