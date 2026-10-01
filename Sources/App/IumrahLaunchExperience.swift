import SwiftUI

/// Conservative launch hand-off used for production stability.
///
/// The live app is intentionally NOT mounted behind the splash. This keeps RootView,
/// stores, network bootstrap and the Home hierarchy out of the critical launch path.
/// After the native-looking splash has been on screen for a short moment we mount the
/// app, yield one frame, then fade the splash away.
struct IumrahLaunchExperience<Content: View>: View {
    private let contentBuilder: () -> Content

    @State private var contentMounted = false
    @State private var splashVisible = true
    @State private var splashOpacity: Double = 1
    @State private var contentOpacity: Double = 0
    @State private var hasStarted = false

    init(@ViewBuilder content: @escaping () -> Content) {
        self.contentBuilder = content
    }

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            if contentMounted {
                contentBuilder()
                    .opacity(contentOpacity)
                    .allowsHitTesting(!splashVisible)
            }

            if splashVisible {
                splashLayer
                    .opacity(splashOpacity)
                    .zIndex(1000)
                    .transition(.identity)
            }
        }
        .background(Color("LaunchBackground"))
        .task {
            await runLaunchSequenceIfNeeded()
        }
    }

    private var splashLayer: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            Image("LaunchWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 90)
                .accessibilityHidden(true)
        }
    }

    @MainActor
    private func runLaunchSequenceIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        // Keep launch deterministic and cheap. The previous implementation mounted
        // RootView immediately and simultaneously ran a 60-fps particle animation,
        // which meant heavy app startup work happened while the splash was still shown.
        try? await Task.sleep(for: .milliseconds(320))
        guard !Task.isCancelled else { return }

        contentMounted = true
        await Task.yield()

        // Give SwiftUI one complete frame to construct the root hierarchy before the
        // splash starts disappearing. This avoids a blank/half-built first app frame.
        try? await Task.sleep(for: .milliseconds(90))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.20)) {
            contentOpacity = 1
            splashOpacity = 0
        }

        try? await Task.sleep(for: .milliseconds(230))
        guard !Task.isCancelled else { return }
        splashVisible = false
    }
}
