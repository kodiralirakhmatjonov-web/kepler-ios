import SwiftUI

struct SystemNotificationsCarouselView: View {
    let notifications: [ClientSystemNotification]
    let onOpen: (ClientSystemNotification) -> Void
    let onDismiss: (ClientSystemNotification) -> Void

    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 11) {
            GeometryReader { proxy in
                let cardWidth = min(max(proxy.size.width * 0.93, 286), proxy.size.width)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(notifications) { notification in
                            SystemNotificationCard(
                                notification: notification,
                                onOpen: { onOpen(notification) },
                                onDismiss: { onDismiss(notification) }
                            )
                            .frame(width: cardWidth, height: 184)
                            .id(notification.id)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.975)
                                    .opacity(phase.isIdentity ? 1 : 0.90)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $selectedID, anchor: .center)
            }
            .frame(height: 188)

            if notifications.count > 1 {
                HStack(spacing: 7) {
                    ForEach(notifications) { notification in
                        Capsule(style: .continuous)
                            .fill(notification.id == selectedID ? signalBlue : Color.secondary.opacity(0.18))
                            .frame(width: notification.id == selectedID ? 20 : 7, height: 7)
                            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: selectedID)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
        }
        .onAppear {
            normalizeSelection()
        }
        .onChange(of: notifications.map(\.id)) { _, _ in
            normalizeSelection()
        }
    }

    private var signalBlue: Color {
        Color(red: 0.18, green: 0.40, blue: 0.90)
    }

    private func normalizeSelection() {
        guard !notifications.isEmpty else {
            selectedID = nil
            return
        }
        if let selectedID, notifications.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = notifications.first?.id
    }
}
