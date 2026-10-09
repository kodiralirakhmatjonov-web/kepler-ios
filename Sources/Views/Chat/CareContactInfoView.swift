import PhotosUI
import SwiftUI

struct CareContactInfoView: View {
    enum Section: String, CaseIterable {
        case info
        case background
    }

    @ObservedObject var appearance: CareChatAppearanceStore

    let profile: IumrahPublicProfile?
    let language: AppSettingsStore.Language
    let bookingNumber: String?
    let onCall: () -> Void
    let onTelegram: () -> Void
    let onWhatsApp: () -> Void
    let onClose: () -> Void

    @State private var section: Section = .info
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHero
                        .padding(.top, 16)

                    segmentControl
                        .padding(.top, 24)

                    Group {
                        if section == .info {
                            informationSection
                                .transition(.opacity.combined(with: .offset(x: -10)))
                        } else {
                            backgroundSection
                                .transition(.opacity.combined(with: .offset(x: 10)))
                        }
                    }
                    .padding(.top, 18)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 38)
            }
        }
        .navigationTitle("iumrah Care")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(tr("Done", "Готово", "Tayyor", "Тайёр")) {
                    if appearance.hapticsEnabled { IumrahHaptics.selection() }
                    onClose()
                }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    selectedPhoto = nil
                    if let data {
                        if appearance.hapticsEnabled { IumrahHaptics.selection() }
                        appearance.setCustomPhoto(data: data)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var profileHero: some View {
        VStack(spacing: 10) {
            CareProfileAvatar(profile: nil, size: 104)
                .shadow(color: .black.opacity(0.10), radius: 16, y: 8)

            Text("iumrah Care")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.55)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)

            Text(tr(
                "Support for every stage of your journey",
                "Поддержка на всех этапах вашей поездки",
                "Safaringizning barcha bosqichlarida yordam",
                "Сафарингизнинг барча босқичларида ёрдам"
            ))
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color.secondary)
            .multilineTextAlignment(.center)

            HStack(spacing: 28) {
                actionButton(
                    title: tr("Call", "Позвонить", "Qo‘ng‘iroq", "Қўнғироқ"),
                    icon: "phone.fill",
                    enabled: !preferredPhone.isEmpty,
                    action: onCall
                )
                actionButton(
                    title: "Telegram",
                    icon: "paperplane.fill",
                    enabled: hasTelegram,
                    action: onTelegram
                )
                actionButton(
                    title: "WhatsApp",
                    icon: "message.fill",
                    enabled: hasWhatsApp,
                    action: onWhatsApp
                )
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(
        title: String,
        icon: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Button {
                guard enabled else { return }
                if appearance.hapticsEnabled { IumrahHaptics.selection() }
                action()
            } label: {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(enabled ? Color(uiColor: .systemBlue) : Color.secondary.opacity(0.40))
                    .frame(width: 48, height: 48)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!enabled)

            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.45))
        }
    }

    private var segmentControl: some View {
        Picker("", selection: $section) {
            Text(tr("Info", "Сведения", "Ma’lumot", "Маълумот"))
                .tag(Section.info)
            Text(tr("Background", "Фон", "Fon", "Фон"))
                .tag(Section.background)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 290)
        .onChange(of: section) { _, _ in
            if appearance.hapticsEnabled { IumrahHaptics.selection() }
        }
    }

    // MARK: - Info

    private var informationSection: some View {
        VStack(spacing: 12) {
            founderConnectCard

            card {
                VStack(spacing: 0) {
                    settingsToggle(
                        title: tr("Chat sounds", "Звуки чата", "Chat tovushlari", "Чат товушлари"),
                        icon: "speaker.wave.2.fill",
                        isOn: $appearance.soundsEnabled
                    )

                    Divider()
                        .padding(.leading, 54)

                    settingsToggle(
                        title: tr("Haptics", "Виброотклик", "Haptika", "Ҳаптика"),
                        icon: "hand.tap.fill",
                        isOn: $appearance.hapticsEnabled
                    )
                }
                .padding(.horizontal, 14)
            }

            if let bookingNumber, !bookingNumber.isEmpty {
                card {
                    HStack(spacing: 12) {
                        settingsIcon("suitcase.fill")

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Booking", "Бронирование", "Bron", "Брон"))
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            Text(bookingNumber)
                                .font(.system(size: 15.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.primary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                }
            }
        }
    }

    private var founderConnectCard: some View {
        Button {
            guard !appearance.founderConnected else { return }
            if appearance.hapticsEnabled { IumrahHaptics.selection() }
            appearance.connectFounder()
        } label: {
            HStack(spacing: 12) {
                settingsIcon(appearance.founderConnected ? "checkmark.circle.fill" : "person.crop.circle.badge.plus")
                    .foregroundStyle(appearance.founderConnected ? Color.green : Color(uiColor: .systemBlue))

                VStack(alignment: .leading, spacing: 3) {
                    Text(founderButtonTitle)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)

                    Text(founderButtonSubtitle)
                        .font(.system(size: 13.2))
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 2)

                if !appearance.founderConnected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        appearance.founderConnected ? Color.green.opacity(0.24) : Color.primary.opacity(0.05),
                        lineWidth: 0.6
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(appearance.founderConnected)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: appearance.founderConnected)
        .accessibilityHint(founderButtonSubtitle)
    }

    private var founderButtonTitle: String {
        if appearance.founderConnected {
            return tr(
                "Abdulaziz is connected",
                "Абдулазиз подключён",
                "Abdulaziz ulandi",
                "Абдулазиз уланди"
            )
        }
        return tr(
            "Connect Abdulaziz",
            "Подключить Абдулазиза",
            "Abdulazizni ulash",
            "Абдулазизни улаш"
        )
    }

    private var founderButtonSubtitle: String {
        if appearance.founderConnected {
            return tr(
                "We connected your chat with the founder’s chat as well. He can now see your conversation too.",
                "Мы соединили ваш чат одновременно с чатом основателя, и он тоже видит вашу переписку.",
                "Chatingizni asoschining chatiga ham uladik. Endi u ham yozishmalaringizni ko‘radi.",
                "Чатингизни асосчининг чатига ҳам уладик. Энди у ҳам ёзишмаларингизни кўради."
            )
        }
        return tr(
            "The founder will personally review your trip once more.",
            "Основатель сам ещё раз проверит вашу поездку.",
            "Asoschi safaringizni yana bir bor shaxsan tekshiradi.",
            "Асосчи сафарингизни яна бир бор шахсан текширади."
        )
    }

    // MARK: - Backgrounds

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text(tr("Chat background", "Фон чата", "Chat foni", "Чат фони"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 76), spacing: 14)],
                    alignment: .center,
                    spacing: 20
                ) {
                    wallpaperCircle(.none)
                    customPhotoCircle
                    wallpaperCircle(.dawn)
                    wallpaperCircle(.sky)
                    wallpaperCircle(.water)
                    wallpaperCircle(.aurora)
                }
            }

            VStack(alignment: .leading, spacing: 15) {
                Text(tr("Suggestions", "Предложения", "Takliflar", "Таклифлар"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 14
                ) {
                    wallpaperCard(.makkah)
                    wallpaperCard(.sand)
                    wallpaperCard(.aurora)
                    wallpaperCard(.water)
                }
            }
        }
    }

    private func wallpaperCircle(_ wallpaper: CareChatWallpaper) -> some View {
        Button {
            if appearance.hapticsEnabled { IumrahHaptics.selection() }
            appearance.select(wallpaper)
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CareWallpaperPreview(wallpaper: wallpaper, customImage: appearance.customImage)
                        .frame(width: 76, height: 76)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(
                                appearance.wallpaper == wallpaper ? Color(uiColor: .systemBlue) : Color.primary.opacity(0.10),
                                lineWidth: appearance.wallpaper == wallpaper ? 3 : 0.8
                            )
                        }

                    if appearance.wallpaper == wallpaper {
                        selectionBadge.offset(x: 2, y: 2)
                    }
                }

                Text(wallpaper.title(language))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .buttonStyle(.plain)
    }

    private var customPhotoCircle: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let image = appearance.customImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Color(uiColor: .secondarySystemGroupedBackground)
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .frame(width: 76, height: 76)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(
                            appearance.wallpaper == .photo ? Color(uiColor: .systemBlue) : Color.primary.opacity(0.10),
                            lineWidth: appearance.wallpaper == .photo ? 3 : 0.8
                        )
                    }

                    if appearance.wallpaper == .photo {
                        selectionBadge.offset(x: 2, y: 2)
                    }
                }

                Text(CareChatWallpaper.photo.title(language))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func wallpaperCard(_ wallpaper: CareChatWallpaper) -> some View {
        Button {
            if appearance.hapticsEnabled { IumrahHaptics.selection() }
            appearance.select(wallpaper)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CareWallpaperPreview(wallpaper: wallpaper, customImage: appearance.customImage)
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.48)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                HStack(spacing: 8) {
                    Text(wallpaper.title(language))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    if appearance.wallpaper == wallpaper {
                        selectionBadge
                    }
                }
                .padding(14)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        appearance.wallpaper == wallpaper ? Color(uiColor: .systemBlue) : Color.primary.opacity(0.07),
                        lineWidth: appearance.wallpaper == wallpaper ? 2 : 0.7
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var selectionBadge: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .systemBlue))
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 25, height: 25)
    }

    // MARK: - Shared controls

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.045), lineWidth: 0.5)
            }
    }

    private func settingsIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(uiColor: .systemBlue))
            .frame(width: 36, height: 36)
            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func settingsToggle(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.primary)

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.vertical, 10)
    }

    private var preferredPhone: String {
        "+998508898845"
    }

    private var hasTelegram: Bool {
        !(profile?.telegram.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
    }

    private var hasWhatsApp: Bool {
        !(profile?.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

struct CareProfileAvatar: View {
    let profile: IumrahPublicProfile?
    let size: CGFloat

    var body: some View {
        Image("CareChatAvatar")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
            }
            .background(Color.white, in: Circle())
            .contentShape(Circle())
            .accessibilityLabel("iumrah Care")
    }
}
