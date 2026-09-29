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
            let cardWidth = max(proxy.size.width * 0.91, 278)

            ZStack(alignment: .bottom) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
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
                .contentMargins(.horizontal, IumrahDesign.pagePadding, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $activeStoryID, anchor: .center)
                .padding(.horizontal, -IumrahDesign.pagePadding)

                pageIndicator
                    .padding(.bottom, 14)
            }
        }
        .frame(height: carouselHeight)
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
        .accessibilityLabel("iumrah video stories")
    }

    private func videoCard(_ story: HomeEmotionalStory) -> some View {
        ZStack {
            LoopingVideoView(
                resource: story.resource,
                isPlaying: isVisible && scenePhase == .active && activeStoryID == story.id,
                isMuted: isMuted
            )
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .onTapGesture {
                openStory(story)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .topTrailing) {
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
        .shadow(color: Color.black.opacity(0.14), radius: 18, y: 9)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityLabel("Video \(storyIndex(story) + 1) of \(stories.count)")
        .accessibilityHint(openVideoTitle)
    }

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(stories) { story in
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(activeStoryID == story.id ? 0.96 : 0.46))
                    .frame(width: activeStoryID == story.id ? 18 : 6, height: 6)
                    .animation(.snappy(duration: 0.25), value: activeStoryID)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .iumrahGlass(in: Capsule(style: .continuous), allowsStaticGlass: true, chrome: true)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var openVideoTitle: String {
        switch settings.language {
        case .russian: return "Почувствовать"
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
