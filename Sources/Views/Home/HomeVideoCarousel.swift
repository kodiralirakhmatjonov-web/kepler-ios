import SwiftUI
import UIKit

struct HomeVideoCarousel: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settings: AppSettingsStore

    private let stories = HomeEmotionalStory.all

    @State private var activeStoryID: String? = HomeEmotionalStory.all.first?.id
    @State private var isVisible = false
    @State private var isMuted = true
    @State private var presentedStory: HomeEmotionalStory?

    private var carouselHeight: CGFloat {
        min(max(UIScreen.main.bounds.height * 0.36, 250), 340)
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(max(proxy.size.width * 0.91, 278), proxy.size.width)

            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(stories) { story in
                            videoCard(story)
                                .frame(width: cardWidth, height: carouselHeight)
                                .id(story.id)
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.985)
                                        .opacity(phase.isIdentity ? 1 : 0.9)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .frame(height: carouselHeight)
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .scrollPosition(id: $activeStoryID, anchor: .center)
                .scrollClipDisabled()

                pageIndicator
            }
        }
        .frame(height: carouselHeight + 28)
        .onAppear {
            isVisible = true
            if activeStoryID == nil {
                activeStoryID = stories.first?.id
            }
        }
        .onDisappear {
            isVisible = false
        }
        .fullScreenCover(item: $presentedStory) { story in
            HomeEmotionalJourneyFullscreen(language: settings.language, initialStoryID: story.id)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(IumrahAccessibilityCopy.text(settings.language, ru: "Видеоистории iumrah", en: "iumrah video stories", uz: "iumrah video hikoyalari", cy: "iumrah видео ҳикоялари", tr: "iumrah video hikâyeleri", id: "Cerita video iumrah"))
    }

    private func videoCard(_ story: HomeEmotionalStory) -> some View {
        ZStack {
            LoopingVideoView(
                resource: story.resource,
                isPlaying: isVisible && presentedStory == nil && scenePhase == .active && activeStoryID == story.id,
                isMuted: isMuted
            )
            .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture { openStory(story) }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .topTrailing) {
            IumrahGlassIconButton(
                systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                size: 46,
                fontSize: 15,
                foreground: .white,
                tint: .black.opacity(0.08),
                accessibilityLabel: isMuted ? IumrahAccessibilityCopy.text(settings.language, ru: "Включить звук", en: "Unmute", uz: "Ovozni yoqish", cy: "Овозни ёқиш", tr: "Sesi aç", id: "Aktifkan suara") : IumrahAccessibilityCopy.text(settings.language, ru: "Выключить звук", en: "Mute", uz: "Ovozni o‘chirish", cy: "Овозни ўчириш", tr: "Sesi kapat", id: "Nonaktifkan suara")
            ) {
                isMuted.toggle()
            }
            .padding(12)
            .opacity(activeStoryID == story.id ? 1 : 0.78)
            .zIndex(20)
        }
        .overlay(alignment: .bottomLeading) {
            if activeStoryID == story.id {
                Button {
                    openStory(story)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(openVideoTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .frame(height: 43)
                    .background(Color.black.opacity(0.78), in: Capsule(style: .continuous))
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.leading, 13)
                .padding(.bottom, 48)
                .transition(.opacity)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityLabel("\(videoIndexLabel) \(storyIndex(story) + 1) \(videoOfLabel) \(stories.count)")
        .accessibilityHint(openVideoTitle)
    }

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(stories) { story in
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(activeStoryID == story.id ? 0.82 : 0.20))
                    .frame(width: activeStoryID == story.id ? 18 : 6, height: 6)
                    .animation(.snappy(duration: 0.25), value: activeStoryID)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var videoIndexLabel: String {
        IumrahAccessibilityCopy.text(settings.language, ru: "Видео", en: "Video", uz: "Video", cy: "Видео", tr: "Video", id: "Video")
    }

    private var videoOfLabel: String {
        IumrahAccessibilityCopy.text(settings.language, ru: "из", en: "of", uz: "dan", cy: "дан", tr: "/", id: "dari")
    }

    private var openVideoTitle: String {
        switch settings.language {
        case .russian: return "Почувствовать"
        case .indonesian: return IndonesianLocalization.phrase("Experience")
        case .turkish: return TurkishLocalization.phrase("Experience")
        case .english: return "Experience"
        case .uzbek: return "His etish"
        case .uzbekCyrillic: return "Ҳис этиш"
        }
    }

    private func openStory(_ story: HomeEmotionalStory) {
        IumrahHaptics.soft()
        activeStoryID = story.id
        presentedStory = story
    }

    private func storyIndex(_ story: HomeEmotionalStory) -> Int {
        stories.firstIndex(of: story) ?? 0
    }
}
