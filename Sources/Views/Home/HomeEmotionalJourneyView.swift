import SwiftUI

struct HomeEmotionalStory: Identifiable, Hashable {
    let id: String
    let resource: String
    let copyIndex: Int

    static let all: [HomeEmotionalStory] = [
        HomeEmotionalStory(id: "home-story-01", resource: "home-story-01", copyIndex: 0),
        HomeEmotionalStory(id: "home-story-03", resource: "home-story-03", copyIndex: 1),
        HomeEmotionalStory(id: "home-story-04", resource: "home-story-04", copyIndex: 2),
        HomeEmotionalStory(id: "home-story-05", resource: "home-story-05", copyIndex: 3),
        HomeEmotionalStory(id: "home-story-07", resource: "home-story-07", copyIndex: 4),
        HomeEmotionalStory(id: "home-story-08", resource: "home-story-08", copyIndex: 5)
    ]

    func title(_ language: AppSettingsStore.Language) -> String {
        HomeEmotionalCopy.storyTitle(copyIndex, language: language)
    }

    func subtitle(_ language: AppSettingsStore.Language) -> String? {
        HomeEmotionalCopy.storySubtitle(copyIndex, language: language)
    }
}

struct HomeEmotionalJourneyPrompt: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var isPresented = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(HomeEmotionalCopy.promptTitle(settings.language))
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .tracking(-0.35)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 10)

            Button {
                IumrahHaptics.soft()
                isPresented = true
            } label: {
                HStack(spacing: 7) {
                    Text(HomeEmotionalCopy.tryButton(settings.language))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 17)
                .frame(height: 44)
                .background(Color.black, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.emotionalJourney.open")
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .fullScreenCover(isPresented: $isPresented) {
            HomeEmotionalJourneyFullscreen(language: settings.language, initialStoryID: nil)
        }
    }
}

struct HomeEmotionalJourneyFullscreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let language: AppSettingsStore.Language

    @State private var activeStoryID: String?
    @State private var isMuted = false
    @State private var captionVisible = false

    init(language: AppSettingsStore.Language, initialStoryID: String? = nil) {
        self.language = language
        let resolvedID: String?
        if let initialStoryID, HomeEmotionalStory.all.contains(where: { $0.id == initialStoryID }) {
            resolvedID = initialStoryID
        } else {
            resolvedID = HomeEmotionalStory.all.first?.id
        }
        _activeStoryID = State(initialValue: resolvedID)
    }

    private var activeStory: HomeEmotionalStory? {
        guard let activeStoryID else { return HomeEmotionalStory.all.first }
        return HomeEmotionalStory.all.first(where: { $0.id == activeStoryID })
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(HomeEmotionalStory.all) { story in
                            storyPage(story, size: proxy.size)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .id(story.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $activeStoryID, anchor: .center)
                .background(Color.black)

                bottomGradient

                topGradient

                controls(safeTop: proxy.safeAreaInsets.top)

                captionLayer(safeBottom: proxy.safeAreaInsets.bottom)
            }
            .ignoresSafeArea()
        }
        .background(Color.black)
        .statusBarHidden(true)
        .onAppear {
            revealCaption(after: 0.34)
        }
        .onChange(of: activeStoryID) { _, newValue in
            guard newValue != nil else { return }
            captionVisible = false
            IumrahHaptics.selection()
            revealCaption(after: 0.24)
        }
        .accessibilityIdentifier("home.emotionalJourney.fullscreen")
    }

    private func storyPage(_ story: HomeEmotionalStory, size: CGSize) -> some View {
        LoopingVideoView(
            resource: story.resource,
            gravity: .resizeAspectFill,
            isPlaying: scenePhase == .active && activeStoryID == story.id,
            isMuted: isMuted
        )
        .frame(width: size.width, height: size.height)
        .clipped()
        .background(Color.black)
        .allowsHitTesting(false)
        .accessibilityLabel("\(videoIndexLabel) \(storyIndex(story) + 1) \(videoOfLabel) \(HomeEmotionalStory.all.count)")
    }

    private var videoIndexLabel: String {
        IumrahAccessibilityCopy.text(language, ru: "Видео", en: "Video", uz: "Video", cy: "Видео", tr: "Video", id: "Video")
    }

    private var videoOfLabel: String {
        IumrahAccessibilityCopy.text(language, ru: "из", en: "of", uz: "dan", cy: "дан", tr: "/", id: "dari")
    }

    private var bottomGradient: some View {
        VStack(spacing: 0) {
            Spacer()
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.50),
                    Color.black.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 340)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topGradient: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0.48), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func controls(safeTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(pageCounter)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 13)
                    .frame(height: 40)
                    .iumrahGlass(in: Capsule(style: .continuous), allowsStaticGlass: true, chrome: true)

                Spacer()

                IumrahGlassGroup(spacing: 10) {
                    HStack(spacing: 10) {
                        IumrahGlassIconButton(
                            systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                            size: 46,
                            fontSize: 15,
                            foreground: .white,
                            tint: .black.opacity(0.08),
                            accessibilityLabel: isMuted ? "Unmute" : "Mute"
                        ) {
                            isMuted.toggle()
                        }

                        IumrahGlassIconButton(
                            systemName: "xmark",
                            size: 46,
                            fontSize: 16,
                            foreground: .white,
                            tint: .black.opacity(0.08),
                            accessibilityLabel: "Close"
                        ) {
                            dismiss()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, max(safeTop, 14) + 8)

            Spacer()
        }
        .contentShape(Rectangle())
        .zIndex(100)
    }

    @ViewBuilder
    private func captionLayer(safeBottom: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            if let story = activeStory, captionVisible {
                VStack(alignment: .leading, spacing: 9) {
                    Text(story.title(language))
                        .font(.system(size: 29, weight: .semibold, design: .rounded))
                        .tracking(-0.65)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = story.subtitle(language) {
                        Text(subtitle)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .tracking(-0.15)
                            .foregroundStyle(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .id(story.id)
                .transition(.iumrahVapor)
            }

            HStack(spacing: 5) {
                ForEach(HomeEmotionalStory.all) { story in
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(activeStoryID == story.id ? 0.98 : 0.34))
                        .frame(width: activeStoryID == story.id ? 22 : 7, height: 6)
                        .animation(.snappy(duration: 0.28), value: activeStoryID)
                }
            }
            .padding(.top, 20)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, max(safeBottom, 16) + 22)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.82), value: captionVisible)
    }

    private var pageCounter: String {
        guard let activeStory else { return "1 / \(HomeEmotionalStory.all.count)" }
        return "\(storyIndex(activeStory) + 1) / \(HomeEmotionalStory.all.count)"
    }

    private func storyIndex(_ story: HomeEmotionalStory) -> Int {
        HomeEmotionalStory.all.firstIndex(of: story) ?? 0
    }

    private func revealCaption(after delay: Double) {
        let targetID = activeStoryID
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard activeStoryID == targetID else { return }
            withAnimation(.easeOut(duration: 0.82)) {
                captionVisible = true
            }
        }
    }
}

private struct IumrahVaporModifier: ViewModifier {
    let opacity: Double
    let blurRadius: CGFloat
    let verticalOffset: CGFloat
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blurRadius)
            .offset(y: verticalOffset)
            .scaleEffect(scale, anchor: .bottomLeading)
    }
}

private extension AnyTransition {
    static var iumrahVapor: AnyTransition {
        .modifier(
            active: IumrahVaporModifier(opacity: 0, blurRadius: 13, verticalOffset: 14, scale: 0.985),
            identity: IumrahVaporModifier(opacity: 1, blurRadius: 0, verticalOffset: 0, scale: 1)
        )
    }
}

private enum HomeEmotionalCopy {
    static func promptTitle(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Почувствуйте перед поездкой"
        case .indonesian: return IndonesianLocalization.phrase("Feel it before your journey")
        case .turkish: return TurkishLocalization.phrase("Feel it before your journey")
        case .english: return "Feel it before your journey"
        case .uzbek: return "Safardan oldin his eting"
        case .uzbekCyrillic: return "Сафардан олдин ҳис этинг"
        }
    }

    static func tryButton(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Почувствовать сейчас"
        case .indonesian: return IndonesianLocalization.phrase("Experience now")
        case .turkish: return TurkishLocalization.phrase("Experience now")
        case .english: return "Experience now"
        case .uzbek: return "Hozir his eting"
        case .uzbekCyrillic: return "Ҳозир ҳис этинг"
        }
    }

    static func storyTitle(_ index: Int, language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian:
            return [
                "Однажды это будет не на экране.",
                "Есть места, к которым сердце приходит раньше нас.",
                "У каждого здесь своя история.",
                "Здесь становится тише внутри.",
                "То, о чём вы просили в тишине…",
                "А потом — Медина."
            ][safe: index] ?? ""
        case .indonesian:
            return [
                "Suatu hari nanti, ini bukan hanya gambar di layar.",
                "Ada tempat yang lebih dulu dijangkau hati sebelum kaki melangkah.",
                "Setiap orang di sini memiliki kisah.",
                "Di sini, hati terasa lebih tenang.",
                "Doa-doa yang Anda panjatkan diam-diam…",
                "Dan kemudian — Madinah."
            ][safe: index] ?? ""
        case .turkish:
            return [
                "Bir gün, bu manzara yalnızca ekranda kalmayacak.",
                "Bazı yerlere ayaklarımızdan önce kalbimiz varır.",
                "Buradaki herkesin bir hikâyesi var.",
                "Burada insanın içi biraz daha huzur buluyor.",
                "Sessizce diledikleriniz…",
                "Ve sonra — Medine."
            ][safe: index] ?? ""
        case .english:
            return [
                "One day, this will not be on a screen.",
                "Some places are reached by the heart before we arrive.",
                "Everyone here carries a story.",
                "Something inside becomes quieter here.",
                "What you asked for in silence…",
                "And then — Madinah."
            ][safe: index] ?? ""
        case .uzbek:
            return [
                "Bir kuni bu faqat ekranda bo‘lmaydi.",
                "Shunday joylar borki, qalbimiz bizdan oldin yetib boradi.",
                "Bu yerda har kimning o‘z hikoyasi bor.",
                "Bu yerda ichingiz sokinlashadi.",
                "Sukunatda so‘ragan narsalaringiz…",
                "Keyin esa — Madina."
            ][safe: index] ?? ""
        case .uzbekCyrillic:
            return [
                "Бир куни бу фақат экранда бўлмайди.",
                "Шундай жойлар борки, қалбимиз биздан олдин етиб боради.",
                "Бу ерда ҳар кимнинг ўз ҳикояси бор.",
                "Бу ерда ичингиз сокинлашади.",
                "Сукунатда сўраган нарсаларингиз…",
                "Кейин эса — Мадина."
            ][safe: index] ?? ""
        }
    }

    static func storySubtitle(_ index: Int, language: AppSettingsStore.Language) -> String? {
        switch language {
        case .russian:
            return [
                "Вы будете здесь.",
                nil,
                "И своя молитва.",
                nil,
                "…однажды может привести вас сюда.",
                "Город, из которого сердце уезжает не сразу."
            ][safe: index] ?? nil
        case .indonesian:
            return [
                "Anda pun akan berada di sini.",
                nil,
                "Dan masing-masing memiliki doanya sendiri.",
                nil,
                "…mungkin suatu hari akan membawa Anda ke sini.",
                "Kota yang tak mudah ditinggalkan hati."
            ][safe: index] ?? nil
        case .turkish:
            return [
                "Siz de burada olacaksınız.",
                nil,
                "Ve her birinin kendi duası var.",
                nil,
                "…bir gün sizi buraya getirebilir.",
                "Kalbin bir anda ayrılamadığı şehir."
            ][safe: index] ?? nil
        case .english:
            return [
                "You will be here.",
                nil,
                "And a prayer of their own.",
                nil,
                "…may one day bring you here.",
                "A city the heart does not leave all at once."
            ][safe: index] ?? nil
        case .uzbek:
            return [
                "Siz shu yerda bo‘lasiz.",
                nil,
                "Va o‘z duosi.",
                nil,
                "…bir kuni sizni shu yerga olib kelishi mumkin.",
                "Yurak darrov tark eta olmaydigan shahar."
            ][safe: index] ?? nil
        case .uzbekCyrillic:
            return [
                "Сиз шу ерда бўласиз.",
                nil,
                "Ва ўз дуоси.",
                nil,
                "…бир куни сизни шу ерга олиб келиши мумкин.",
                "Юрак дарров тарк эта олмайдиган шаҳар."
            ][safe: index] ?? nil
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
