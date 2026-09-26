import SwiftUI
import UIKit

struct CareChatMessageRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let message: ChatMessage
    let bookingID: String
    let language: AppSettingsStore.Language
    let isMine: Bool
    let groupStart: Bool
    let groupEnd: Bool
    let showDelivery: Bool
    let wallpaperActive: Bool
    let timestampText: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if isMine { Spacer(minLength: 42) }

            if !isMine {
                if groupEnd {
                    Image("CareChatAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(Color.white.opacity(0.58), lineWidth: 0.6) }
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                } else {
                    Color.clear.frame(width: 26, height: 1)
                }
            }

            bubbleSurface
                .contextMenu {
                    if !message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            UIPasteboard.general.string = message.body
                        } label: {
                            Label(tr("Copy", "Копировать", "Nusxalash", "Нусхалаш"), systemImage: "doc.on.doc")
                        }

                        ShareLink(item: message.body) {
                            Label(tr("Share", "Поделиться", "Ulashish", "Улашиш"), systemImage: "square.and.arrow.up")
                        }
                    }
                } preview: {
                    bubbleSurface
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                }

            if !isMine { Spacer(minLength: 42) }
        }
        .padding(.top, groupStart ? 5 : 0)
    }

    private var bubbleSurface: some View {
        let shape = CareMessageBubbleShape(isMine: isMine, groupStart: groupStart, groupEnd: groupEnd)

        return bubbleContent
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .padding(.top, verticalPadding)
            .padding(.bottom, metadataBottomPadding)
            .background {
                if isMine {
                    shape.fill(outgoingBubbleColor.opacity(wallpaperActive ? 0.96 : 1))
                } else if wallpaperActive {
                    shape
                        .fill(Color.clear)
                        .iumrahGlass(in: shape)
                        .overlay {
                            shape.fill(
                                colorScheme == .dark
                                    ? Color.black.opacity(0.10)
                                    : Color.white.opacity(0.14)
                            )
                        }
                } else {
                    shape.fill(Color(uiColor: .systemGray6))
                }
            }
            .overlay {
                shape.stroke(incomingStrokeColor, lineWidth: isMine ? 0 : 0.55)
            }
            .shadow(color: bubbleShadow, radius: wallpaperActive ? 7 : 1.25, y: wallpaperActive ? 3 : 1)
            .contentShape(shape)
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        // Keep the bubble content-sized. A Spacer/maxWidth here makes short
        // messages stretch into oversized pills, which was the main source of
        // the uneven Telegram/iMessage comparison.
        VStack(alignment: .trailing, spacing: 5) {
            VStack(alignment: .leading, spacing: 6) {
                if message.messageType == "image", let path = message.attachmentURL {
                    AuthenticatedCareChatImage(path: path, bookingID: bookingID)
                        .frame(maxWidth: 258)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                let trimmed = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Text(message.body)
                        .font(.system(size: 16.5, weight: .regular))
                        .foregroundStyle(isMine ? Color.white : Color.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            HStack(spacing: 4) {
                Text(timestampText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .monospacedDigit()

                if isMine && showDelivery {
                    CareDeliveryTicks(isRead: message.readByStaff == true)
                }
            }
            .foregroundStyle(metadataColor)
        }
    }

    private var leadingPadding: CGFloat {
        let imageOnly = message.messageType == "image" && message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if imageOnly { return groupEnd && !isMine ? 7 : 4 }
        return groupEnd && !isMine ? 16 : 12
    }

    private var trailingPadding: CGFloat {
        let imageOnly = message.messageType == "image" && message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if imageOnly { return groupEnd && isMine ? 7 : 4 }
        return groupEnd && isMine ? 16 : 12
    }

    private var verticalPadding: CGFloat {
        message.messageType == "image" && message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 4 : 8
    }

    private var metadataBottomPadding: CGFloat {
        message.messageType == "image" && message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 5 : 6
    }

    private var outgoingBubbleColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.10, green: 0.62, blue: 0.47)
        }
        return Color.iumrahCareDark
    }

    private var incomingStrokeColor: Color {
        wallpaperActive ? Color.white.opacity(0.16) : Color.primary.opacity(0.045)
    }

    private var bubbleShadow: Color {
        wallpaperActive ? Color.black.opacity(0.10) : Color.black.opacity(0.020)
    }

    private var metadataColor: Color {
        if isMine { return .white.opacity(0.72) }
        return wallpaperActive ? .white.opacity(0.68) : .secondary
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

private struct CareDeliveryTicks: View {
    let isRead: Bool

    var body: some View {
        HStack(spacing: isRead ? -3.5 : 0) {
            Image(systemName: "checkmark")
            if isRead {
                Image(systemName: "checkmark")
            }
        }
        .font(.system(size: 9.5, weight: .bold))
        .accessibilityLabel(isRead ? "Read" : "Delivered")
    }
}

struct CareMessageBubbleShape: Shape {
    let isMine: Bool
    let groupStart: Bool
    let groupEnd: Bool

    func path(in rect: CGRect) -> Path {
        let large: CGFloat = 18
        let tight: CGFloat = 7

        let rounded: UnevenRoundedRectangle
        if isMine {
            rounded = UnevenRoundedRectangle(
                topLeadingRadius: large,
                bottomLeadingRadius: large,
                bottomTrailingRadius: groupEnd ? tight : large,
                topTrailingRadius: groupStart ? large : tight,
                style: .continuous
            )
        } else {
            rounded = UnevenRoundedRectangle(
                topLeadingRadius: groupStart ? large : tight,
                bottomLeadingRadius: groupEnd ? tight : large,
                bottomTrailingRadius: large,
                topTrailingRadius: large,
                style: .continuous
            )
        }
        return rounded.path(in: rect)
    }
}

private struct AuthenticatedCareChatImage: View {
    @EnvironmentObject private var bookings: BookingStore

    let path: String
    let bookingID: String

    @State private var image: UIImage?
    @State private var showViewer = false

    var body: some View {
        Button {
            guard image != nil else { return }
            showViewer = true
        } label: {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ZStack {
                        Color.black.opacity(0.055)
                        ProgressView()
                    }
                    .frame(width: 226, height: 156)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: path) {
            guard image == nil,
                  let data = try? await bookings.chatAttachmentData(path: path, bookingID: bookingID),
                  let loaded = UIImage(data: data) else { return }
            withAnimation(.easeInOut(duration: 0.20)) {
                image = loaded
            }
        }
        .fullScreenCover(isPresented: $showViewer) {
            if let image {
                CareChatImageViewer(image: image)
            }
        }
    }
}

private struct CareChatImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var committedScale: CGFloat = 1
    @GestureState private var liveScale: CGFloat = 1
    @GestureState private var dragY: CGFloat = 0

    let image: UIImage

    private var scale: CGFloat {
        min(5, max(1, committedScale * liveScale))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(y: committedScale == 1 ? max(0, dragY) : 0)
                .opacity(committedScale == 1 ? 1 - min(0.28, max(0, dragY) / 900) : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    MagnifyGesture()
                        .updating($liveScale) { value, state, _ in
                            state = value.magnification
                        }
                        .onEnded { value in
                            committedScale = min(5, max(1, committedScale * value.magnification))
                            if committedScale < 1.05 { committedScale = 1 }
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .updating($dragY) { value, state, _ in
                            guard committedScale == 1, value.translation.height > 0 else { return }
                            state = value.translation.height
                        }
                        .onEnded { value in
                            guard committedScale == 1 else { return }
                            if value.translation.height > 120 || value.predictedEndTranslation.height > 220 {
                                dismiss()
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        committedScale = committedScale > 1 ? 1 : 2.2
                    }
                }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .careNativeGlassButton()
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .statusBarHidden(true)
    }
}
