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
            CareConversationBackground(
                wallpaper: appearance.wallpaper,
                customImage: appearance.customImage,
                motionEnabled: true
            )

            if appearance.wallpaper.isVisual {
                LinearGradient(
                    colors: [Color.black.opacity(0.10), Color.clear, Color.black.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHero
                        .padding(.top, 10)

                    segmentControl
                        .padding(.top, 22)

                    ZStack(alignment: .top) {
                        if section == .info {
                            informationSection
                                .transition(.opacity.combined(with: .offset(x: -12)))
                        } else {
                            backgroundSection
                                .transition(.opacity.combined(with: .offset(x: 12)))
                        }
                    }
                    .padding(.top, 18)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 34)
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


    private var profileHero: some View {
        VStack(spacing: 12) {
            CareProfileAvatar(profile: nil, size: 92)
                .shadow(color: .black.opacity(appearance.wallpaper.isVisual ? 0.18 : 0.10), radius: 16, y: 7)

            Text("iumrah Care")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.55)
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)

            Text(tr("Support for every stage of your journey", "Поддержка на всех этапах вашей поездки", "Safaringizning barcha bosqichlarida yordam", "Сафарингизнинг барча босқичларида ёрдам"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
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
            .padding(.top, 8)
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
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .foregroundStyle(enabled ? primaryText : secondaryText.opacity(0.42))
            .controlSize(.small)
            .careNativeGlassButton()
            .disabled(!enabled)

            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(enabled ? primaryText : secondaryText.opacity(0.42))
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
        .frame(maxWidth: 258)
        .onChange(of: section) { _, _ in
            if appearance.hapticsEnabled { IumrahHaptics.selection() }
        }
    }

    private var informationSection: some View {
        VStack(spacing: 12) {
            founderConnectCard

            glassCard {
                VStack(spacing: 0) {
                    settingsToggle(
                        title: tr("Chat sounds", "Звуки чата", "Chat tovushlari", "Чат товушлари"),
                        icon: "speaker.wave.2.fill",
                        isOn: $appearance.soundsEnabled
                    )
                    Divider().opacity(0.22).padding(.leading, 52)
                    settingsToggle(
                        title: tr("Haptics", "Виброотклик", "Haptika", "Ҳаптика"),
                        icon: "hand.tap.fill",
                        isOn: $appearance.hapticsEnabled
                    )
                }
                .padding(.horizontal, 14)
            }

            if let bookingNumber, !bookingNumber.isEmpty {
                glassCard {
                    HStack(spacing: 11) {
                        Image(systemName: "suitcase.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .careNativeGlassSurface(in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Booking", "Бронирование", "Bron", "Брон"))
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                            Text(bookingNumber)
                                .font(.system(size: 15.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(primaryText)
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
                Image(systemName: appearance.founderConnected ? "checkmark.circle.fill" : "person.crop.circle.badge.plus")
                    .font(.system(size: 19, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, height: 36)
                    .careNativeGlassSurface(in: Circle(), interactive: !appearance.founderConnected)

                VStack(alignment: .leading, spacing: 3) {
                    Text(founderButtonTitle)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(primaryText)
                        .multilineTextAlignment(.leading)

                    Text(founderButtonSubtitle)
                        .font(.system(size: 13.2))
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 2)

                if !appearance.founderConnected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(secondaryText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .careNativeGlassSurface(
                in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                interactive: !appearance.founderConnected,
                tint: appearance.founderConnected ? Color.iumrahCareLight.opacity(0.08) : nil
            )
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

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 28) {
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

            VStack(alignment: .leading, spacing: 15) {
                Text(tr("Suggestions", "Предложения", "Takliflar", "Таклифлар"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(primaryText)

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
                                appearance.wallpaper == wallpaper ? Color.white : Color.white.opacity(0.18),
                                lineWidth: appearance.wallpaper == wallpaper ? 3 : 0.8
                            )
                        }
                        .shadow(color: .black.opacity(0.11), radius: 9, y: 5)

                    if appearance.wallpaper == wallpaper {
                        selectionBadge
                            .offset(x: 2, y: 2)
                    }
                }

                Text(wallpaper.title(language))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(primaryText)
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
                                LinearGradient(
                                    colors: [Color.white.opacity(0.88), Color.white.opacity(0.34)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(primaryText.opacity(0.66))
                            }
                        }
                    }
                    .frame(width: 76, height: 76)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(
                            appearance.wallpaper == .photo ? Color.white : Color.white.opacity(0.18),
                            lineWidth: appearance.wallpaper == .photo ? 3 : 0.8
                        )
                    }
                    .shadow(color: .black.opacity(0.11), radius: 9, y: 5)

                    if appearance.wallpaper == .photo {
                        selectionBadge.offset(x: 2, y: 2)
                    }
                }

                Text(CareChatWallpaper.photo.title(language))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(primaryText)
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
                    .frame(height: 224)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.48)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

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
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        Color.white.opacity(appearance.wallpaper == wallpaper ? 0.90 : 0.15),
                        lineWidth: appearance.wallpaper == wallpaper ? 2 : 0.8
                    )
            }
            .shadow(color: .black.opacity(0.13), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var selectionBadge: some View {
        IumrahIconBadge(
            systemName: "checkmark",
            role: .success,
            size: 25,
            symbolSize: 11,
            shape: .circle
        )
    }

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .careNativeGlassSurface(
                in: RoundedRectangle(cornerRadius: 29, style: .continuous),
                interactive: false
            )
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .careNativeGlassSurface(in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(primaryText)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    private func settingsToggle(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .careNativeGlassSurface(in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(primaryText)

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

    private var primaryText: Color {
        appearance.wallpaper.isVisual ? .white : .primary
    }

    private var secondaryText: Color {
        appearance.wallpaper.isVisual ? .white.opacity(0.68) : .secondary
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .english: return en
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
                    .stroke(Color.white.opacity(0.62), lineWidth: 0.8)
            }
            .contentShape(Circle())
            .accessibilityLabel("iumrah Care")
    }
}
