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
        VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
            HStack(alignment: .bottom, spacing: 0) {
                if isMine { Spacer(minLength: 64) }

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

                if !isMine { Spacer(minLength: 64) }
            }

            HStack(spacing: 4) {
                if isMine && showDelivery && groupEnd {
                    Text(deliveryStatus)
                        .fontWeight(.semibold)
                }
                Text(timestampText)
            }
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(wallpaperActive ? Color.white.opacity(0.82) : Color.secondary)
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
            .transition(.opacity)
        }
        .padding(.top, groupStart ? 4 : 0)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: message.readByStaff)
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
                } else {
                    // Messages-style incoming bubble: always an opaque system surface.
                    // Wallpaper never bleeds through the text, so contrast stays stable.
                    shape.fill(Color(uiColor: .secondarySystemBackground).opacity(wallpaperActive ? 0.98 : 1))
                }
            }
            .overlay {
                shape.stroke(incomingStrokeColor, lineWidth: isMine ? 0 : 0.55)
            }
            .shadow(color: bubbleShadow, radius: 1.2, y: 0.6)
            .contentShape(shape)
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if message.messageType == "image", let path = message.attachmentURL {
                AuthenticatedCareChatImage(path: path, bookingID: bookingID)
                    .frame(maxWidth: 258)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            let trimmed = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                Text(message.body)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(isMine ? Color.white : Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
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
        message.messageType == "image" && message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 4 : 8
    }

    private var outgoingBubbleColor: Color {
        Color(uiColor: .systemBlue)
    }

    private var incomingStrokeColor: Color {
        wallpaperActive ? Color.white.opacity(0.16) : Color.primary.opacity(0.045)
    }

    private var bubbleShadow: Color {
        wallpaperActive ? Color.black.opacity(0.10) : Color.black.opacity(0.020)
    }

    private var metadataColor: Color {
        if isMine { return .white.opacity(0.72) }
        return .secondary
    }

    private var deliveryStatus: String {
        if message.readByStaff == true {
            return tr("Read", "Прочитано", "O‘qildi", "Ўқилди")
        }
        return tr("Delivered", "Доставлено", "Yetkazildi", "Етказилди")
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
        let tailWidth: CGFloat = groupEnd ? 7 : 0
        let large: CGFloat = 19.5
        let tight: CGFloat = 6

        let bodyRect = CGRect(
            x: isMine ? rect.minX : rect.minX + tailWidth,
            y: rect.minY,
            width: max(1, rect.width - tailWidth),
            height: rect.height
        )

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

        var path = rounded.path(in: bodyRect)
        guard groupEnd else { return path }

        var tail = Path()
        if isMine {
            let edge = bodyRect.maxX
            tail.move(to: CGPoint(x: edge - 2, y: bodyRect.maxY - 14))
            tail.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - 1.5),
                control1: CGPoint(x: edge + 0.5, y: bodyRect.maxY - 7),
                control2: CGPoint(x: rect.maxX - 1.5, y: rect.maxY - 3)
            )
            tail.addCurve(
                to: CGPoint(x: edge - 5, y: bodyRect.maxY - 4),
                control1: CGPoint(x: rect.maxX - 3, y: rect.maxY - 0.5),
                control2: CGPoint(x: edge - 1, y: rect.maxY - 1)
            )
            tail.closeSubpath()
        } else {
            let edge = bodyRect.minX
            tail.move(to: CGPoint(x: edge + 2, y: bodyRect.maxY - 14))
            tail.addCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - 1.5),
                control1: CGPoint(x: edge - 0.5, y: bodyRect.maxY - 7),
                control2: CGPoint(x: rect.minX + 1.5, y: rect.maxY - 3)
            )
            tail.addCurve(
                to: CGPoint(x: edge + 5, y: bodyRect.maxY - 4),
                control1: CGPoint(x: rect.minX + 3, y: rect.maxY - 0.5),
                control2: CGPoint(x: edge + 1, y: rect.maxY - 1)
            )
            tail.closeSubpath()
        }
        path.addPath(tail)
        return path
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
