import PhotosUI
import SwiftUI
import UIKit

struct BookingChatView: View {
    private let directCarePhone = "+998508898845"
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore

    let bookingID: String

    @StateObject private var appearance: CareChatAppearanceStore

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var failedDraft: String?
    @State private var pendingOutgoing: PendingOutgoingMessage?
    @State private var launchingOutgoing: PendingOutgoingMessage?
    @State private var isSending = false
    @State private var isSendingPhoto = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var registeredImmersive = false
    @State private var careProfile: IumrahPublicProfile?
    @State private var showCareProfile = false
    @State private var isAtBottom = true
    @State private var unseenIncomingCount = 0
    @State private var presentationByID: [String: CareMessagePresentation] = [:]
    @FocusState private var composerFocused: Bool
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var composerPanelHeight: CGFloat = 78
    @Namespace private var sendNamespace

    private let bottomAnchorID = "care-chat-bottom-anchor"
    private let scrollCoordinateSpace = "care-chat-scroll-space"

    init(bookingID: String) {
        self.bookingID = bookingID
        _appearance = StateObject(wrappedValue: CareChatAppearanceStore(bookingID: bookingID))
    }

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                CareConversationBackground(
                    wallpaper: appearance.wallpaper,
                    customImage: appearance.customImage,
                    motionEnabled: !showCareProfile
                )

                conversation(proxy: proxy)
                    .ignoresSafeArea(.container, edges: .bottom)

                if !showCareProfile {
                    VStack(spacing: 6) {
                        if let errorMessage {
                            errorBar(errorMessage, proxy: proxy)
                        }
                        composer(proxy: proxy)
                    }
                    .padding(.bottom, composerFocused ? 8 : 12)
                    .background {
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear { composerPanelHeight = geometry.size.height }
                                .onChange(of: geometry.size.height) { _, value in
                                    composerPanelHeight = value
                                }
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }

            }
            // The conversation and its wallpaper extend through the physical bottom edge.
            // Only the keyboard safe area remains active, so the composer follows the
            // keyboard exactly instead of leaving the old static safe-area band.
            .ignoresSafeArea(.container, edges: .bottom)
            .task {
                await PushNotificationManager.shared.ensureAuthorizationForBookedTrips(hasBookings: true)
                await loadCareProfile()
                await load(proxy: proxy)
                await Task.yield()
                scrollToLatest(proxy, animated: false)

                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(6))
                    await load(silent: true, proxy: proxy)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await sendPhoto(item, proxy: proxy) }
            }
            .onChange(of: composerFocused) { _, focused in
                guard focused else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    scrollToLatest(proxy)
                }
            }
            .onChange(of: messages) { _, _ in
                rebuildMessagePresentation()
            }
            .toolbar {
                if !showCareProfile {
                    chatToolbarContent
                }
            }
        }
        .navigationDestination(isPresented: $showCareProfile) {
            CareContactInfoView(
                appearance: appearance,
                profile: careProfile,
                language: settings.language,
                bookingNumber: session?.displayBookingNumber,
                onCall: openPhone,
                onTelegram: openTelegram,
                onWhatsApp: openWhatsApp,
                onClose: { showCareProfile = false }
            )
        }
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            CareChatFeedback.shared.prepare()
            guard !registeredImmersive else { return }
            registeredImmersive = true
            chrome.beginInternalNavigation()
        }
        .onDisappear {
            guard registeredImmersive else { return }
            registeredImmersive = false
            chrome.endInternalNavigation()
        }
    }

    // MARK: - Conversation

    private func conversation(proxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if isLoading && messages.isEmpty {
                        loadingState
                            .padding(.top, 88)
                    } else if messages.isEmpty && pendingOutgoing == nil {
                        emptyState
                            .padding(.top, 78)
                    } else {
                        messageHistory
                    }

                    if let pendingOutgoing {
                        pendingBubble(pendingOutgoing)
                            .id(pendingOutgoing.id)
                            .padding(.top, 4)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom)
                                        .combined(with: .scale(scale: 0.94, anchor: .bottomTrailing))
                                        .combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }

                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: CareChatBottomYPreferenceKey.self,
                                value: geometry.frame(in: .named(scrollCoordinateSpace)).maxY
                            )
                    }
                    .frame(height: 2)
                    .id(bottomAnchorID)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .frame(minHeight: max(scrollViewportHeight - 24, 0), alignment: .bottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, max(86, composerPanelHeight + 10), for: .scrollContent)
            .coordinateSpace(name: scrollCoordinateSpace)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { scrollViewportHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { _, newValue in
                            scrollViewportHeight = newValue
                        }
                }
            }
            .onPreferenceChange(CareChatBottomYPreferenceKey.self) { bottomY in
                guard scrollViewportHeight > 0 else { return }
                let nearBottom = bottomY <= scrollViewportHeight + 84
                if nearBottom != isAtBottom {
                    withAnimation(.easeOut(duration: 0.16)) {
                        isAtBottom = nearBottom
                    }
                }
                if nearBottom {
                    unseenIncomingCount = 0
                }
            }

            if !isAtBottom && (!messages.isEmpty || pendingOutgoing != nil) {
                Button {
                    if appearance.hapticsEnabled { IumrahHaptics.selection() }
                    unseenIncomingCount = 0
                    scrollToLatest(proxy)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)

                        if unseenIncomingCount > 0 {
                            Text("\(min(unseenIncomingCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 20, minHeight: 20)
                                .background(outgoingAccentColor, in: Capsule())
                                .offset(x: 7, y: -6)
                        }
                    }
                    .foregroundStyle(conversationPrimary)
                }
                .careNativeGlassButton()
                .padding(.trailing, 16)
                .padding(.bottom, 14)
                .transition(.scale(scale: 0.86).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var messageHistory: some View {
        ForEach(messages) { message in
            let meta = presentationByID[message.id] ?? fallbackPresentation(for: message)

            if meta.showDateSeparator {
                dateSeparator(meta.dateSeparatorText)
                    .padding(.vertical, meta.isFirst ? 10 : 16)
            }

            CareChatMessageRow(
                message: message,
                bookingID: bookingID,
                language: settings.language,
                isMine: meta.isMine,
                groupStart: meta.groupStart,
                groupEnd: meta.groupEnd,
                showDelivery: meta.showDelivery,
                wallpaperActive: appearance.wallpaper.isVisual,
                timestampText: meta.timeText
            )
            .id(message.id)
            .padding(.bottom, meta.groupEnd ? 8 : 2)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .bottom)
                        .combined(with: .scale(scale: 0.96, anchor: meta.isMine ? .bottomTrailing : .bottomLeading))
                        .combined(with: .opacity),
                    removal: .opacity
                )
            )
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
            Text(L10n.text("chat_load", settings.language))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(conversationSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            CareProfileAvatar(profile: careProfile, size: 92)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)

            VStack(spacing: 7) {
                Text(L10n.text("chat_empty_title", settings.language))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(conversationPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.text("chat_empty_body", settings.language))
                    .font(.system(size: 17))
                    .foregroundStyle(conversationSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
            }

            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(careSupportText)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
            }
            .foregroundStyle(conversationPrimary.opacity(0.82))
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .iumrahGlass(in: Capsule())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func dateSeparator(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(conversationSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if appearance.wallpaper.isVisual {
                    Capsule()
                        .fill(Color.clear)
                        .iumrahGlass(in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
    }

    private func pendingBubble(_ pending: PendingOutgoingMessage) -> some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 42)

            VStack(alignment: .trailing, spacing: 0) {
                VStack(alignment: .trailing, spacing: 5) {
                    Text(pending.body)
                        .font(.system(size: 16.5))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 5) {
                        Text(messageTimeLabel(pending.createdAt))
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .monospacedDigit()
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white.opacity(0.76))
                    }
                    .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background {
                    CareMessageBubbleShape(isMine: true, groupStart: true, groupEnd: true)
                        .fill(outgoingAccentColor.opacity(0.98))
                }
            }
            .matchedGeometryEffect(id: "care-send-\(pending.id)", in: sendNamespace, isSource: false)
        }
    }

    // MARK: - Native Navigation Toolbar

    @ToolbarContentBuilder
    private var chatToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button {
                if appearance.hapticsEnabled { IumrahHaptics.selection() }
                composerFocused = false
                withAnimation(.spring(response: 0.42, dampingFraction: 0.92)) {
                    showCareProfile = true
                }
            } label: {
                HStack(spacing: 8) {
                    CareProfileAvatar(profile: careProfile, size: 30)
                        .shadow(
                            color: .black.opacity(appearance.wallpaper.isVisual ? 0.18 : 0.07),
                            radius: 4,
                            y: 2
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Text("iumrah Care")
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7.5, weight: .bold))
                        }
                        Text(tr("Support", "Поддержка", "Yordam", "Ёрдам"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(headerPrimary.opacity(0.62))
                    }
                }
                .foregroundStyle(headerPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr(
                "Open iumrah Care information",
                "Открыть информацию iumrah Care",
                "iumrah Care ma’lumotini ochish",
                "iumrah Care маълумотини очиш"
            ))
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if appearance.hapticsEnabled { IumrahHaptics.selection() }
                composerFocused = false
                withAnimation(.spring(response: 0.42, dampingFraction: 0.92)) {
                    showCareProfile = true
                }
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .medium))
            }
            .accessibilityLabel(tr(
                "Care information",
                "Информация iumrah Care",
                "iumrah Care ma’lumoti",
                "iumrah Care маълумоти"
            ))
        }
    }

    // MARK: - Composer

    private func composer(proxy: ScrollViewProxy) -> some View {
        CareNativeGlassContainer(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Group {
                        if isSendingPhoto {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .regular))
                        }
                    }
                    .foregroundStyle(composerControlColor)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
                }
                .controlSize(.small)
                .careNativeGlassButton()
                .disabled(isSending || isSendingPhoto)
                .accessibilityLabel(tr("Add photo", "Добавить фото", "Rasm qo‘shish", "Расм қўшиш"))

                HStack(alignment: .bottom, spacing: 5) {
                    TextField(L10n.text("chat_placeholder", settings.language), text: $draft, axis: .vertical)
                        .focused($composerFocused)
                        .font(.system(size: 16.5))
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .frame(minHeight: 24, maxHeight: 82, alignment: .center)
                        .submitLabel(.send)
                        .tint(appearance.wallpaper.isVisual ? .white : outgoingAccentColor)
                        .onSubmit {
                            guard canSend else { return }
                            Task { await send(proxy: proxy) }
                        }
                        .padding(.leading, 14)
                        .padding(.vertical, 8)

                    if canSend || isSending {
                        Button {
                            Task { await send(proxy: proxy) }
                        } label: {
                            Group {
                                if isSending {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 14.5, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                        }
                        .careNativeGlassButton(prominent: true)
                        .tint(outgoingAccentColor)
                        .disabled(!canSend)
                        .padding(.trailing, 5)
                        .padding(.bottom, 5)
                        .transition(.scale(scale: 0.76).combined(with: .opacity))
                    }
                }
                .frame(minHeight: 44, maxHeight: 98, alignment: .bottom)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture {
                    composerFocused = true
                }
                .careNativeGlassSurface(
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                    interactive: true,
                    tint: composerGlassTint
                )
                .scaleEffect(composerFocused ? 1.006 : 1)
                .shadow(
                    color: appearance.wallpaper.isVisual
                        ? Color.black.opacity(composerFocused ? 0.16 : 0.08)
                        : Color.black.opacity(composerFocused ? 0.07 : 0.025),
                    radius: composerFocused ? 10 : 5,
                    y: composerFocused ? 4 : 2
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: composerFocused)
                .animation(.spring(response: 0.28, dampingFraction: 0.84), value: canSend)
            }
        }
        .padding(.horizontal, 12)
        .overlay(alignment: .bottomTrailing) {
            if let launchingOutgoing {
                Text(launchingOutgoing.body)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background {
                        CareMessageBubbleShape(isMine: true, groupStart: true, groupEnd: true)
                            .fill(outgoingAccentColor)
                    }
                    .matchedGeometryEffect(id: "care-send-\(launchingOutgoing.id)", in: sendNamespace, isSource: true)
                    .padding(.trailing, 14)
                    .padding(.bottom, 2)
                    .allowsHitTesting(false)
                    .zIndex(5)
            }
        }
    }

    private var composerGlassTint: Color? {
        if appearance.wallpaper.isVisual {
            return Color.white.opacity(composerFocused ? 0.10 : 0.045)
        }
        if colorScheme == .dark {
            return composerFocused
                ? outgoingAccentColor.opacity(0.16)
                : Color.white.opacity(0.045)
        }
        return composerFocused
            ? Color.iumrahCareLight.opacity(0.070)
            : Color.primary.opacity(0.020)
    }

    /// A brighter iumrah accent is used only inside the chat in Dark Mode.
    /// The previous deep brand green merged into the system background and made
    /// outgoing bubbles / the send affordance look disabled.
    private var outgoingAccentColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.10, green: 0.62, blue: 0.47)
        }
        return Color.iumrahCareDark
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending && !isSendingPhoto
    }

    private var composerControlColor: Color {
        appearance.wallpaper.isVisual ? .white : .primary
    }

    // MARK: - Error

    private func errorBar(_ message: String, proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(conversationPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(L10n.text("chat_retry", settings.language)) {
                if let failedDraft, !failedDraft.isEmpty {
                    draft = failedDraft
                    composerFocused = true
                    Task { await send(proxy: proxy) }
                } else {
                    Task { await load(proxy: proxy) }
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(conversationPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.iumrahCardBackground)
    }

    // MARK: - Loading / Sending

    @MainActor
    private func load(silent: Bool = false, proxy: ScrollViewProxy? = nil) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }

        do {
            let previousIDs = Set(messages.map(\.id))
            let hadExistingMessages = !messages.isEmpty
            let loaded = try await bookings.loadChat(for: bookingID)
                .sorted(by: { $0.createdAt < $1.createdAt })

            let newIncoming = loaded.filter { message in
                !previousIDs.contains(message.id) && !isMine(message)
            }

            if loaded != messages {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                    messages = loaded
                }
            }

            if failedDraft == nil { errorMessage = nil }

            guard silent, hadExistingMessages, !newIncoming.isEmpty else { return }

            if appearance.soundsEnabled {
                CareChatFeedback.shared.play(.receive)
            }
            if appearance.hapticsEnabled {
                IumrahHaptics.soft()
            }

            if isAtBottom, let proxy {
                scrollToLatest(proxy)
            } else {
                unseenIncomingCount += newIncoming.count
            }
        } catch {
            if !silent { errorMessage = L10n.error(error, settings.language) }
        }
    }

    @MainActor
    private func send(proxy: ScrollViewProxy) async {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isSending else { return }

        isSending = true
        errorMessage = nil
        failedDraft = nil

        let pending = PendingOutgoingMessage(id: UUID().uuidString, body: message, createdAt: Date())
        launchingOutgoing = pending
        draft = ""

        await Task.yield()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            pendingOutgoing = pending
            launchingOutgoing = nil
        }

        if appearance.soundsEnabled {
            CareChatFeedback.shared.play(.send)
        }
        if appearance.hapticsEnabled {
            IumrahHaptics.selection()
        }

        await Task.yield()
        scrollToLatest(proxy)

        do {
            _ = try await bookings.send(message: message, for: bookingID)
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                messages = (bookings.chats[bookingID] ?? messages).sorted(by: { $0.createdAt < $1.createdAt })
                pendingOutgoing = nil
                launchingOutgoing = nil
            }
            composerFocused = true
            scrollToLatest(proxy)
        } catch {
            withAnimation(.easeOut(duration: 0.16)) {
                pendingOutgoing = nil
                launchingOutgoing = nil
            }
            draft = message
            failedDraft = message
            errorMessage = L10n.format("chat_send_failed", settings.language, L10n.error(error, settings.language))
            if appearance.soundsEnabled {
                CareChatFeedback.shared.play(.error)
            }
            if appearance.hapticsEnabled {
                IumrahHaptics.error()
            }
            composerFocused = true
        }

        isSending = false
    }

    @MainActor
    private func sendPhoto(_ item: PhotosPickerItem, proxy: ScrollViewProxy) async {
        selectedPhoto = nil
        isSendingPhoto = true
        errorMessage = nil
        defer { isSendingPhoto = false }

        do {
            guard let raw = try await item.loadTransferable(type: Data.self),
                  let data = optimizedChatJPEG(raw) else {
                throw APIError.invalidResponse
            }

            _ = try await bookings.sendPhoto(data: data, for: bookingID)
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                messages = (bookings.chats[bookingID] ?? messages).sorted(by: { $0.createdAt < $1.createdAt })
            }

            if appearance.soundsEnabled {
                CareChatFeedback.shared.play(.send)
            }
            if appearance.hapticsEnabled {
                IumrahHaptics.selection()
            }
            scrollToLatest(proxy)
        } catch {
            errorMessage = L10n.format("chat_send_failed", settings.language, L10n.error(error, settings.language))
            if appearance.soundsEnabled {
                CareChatFeedback.shared.play(.error)
            }
            if appearance.hapticsEnabled {
                IumrahHaptics.error()
            }
        }
    }

    // MARK: - Message Grouping / Dates

    private func isMine(_ message: ChatMessage) -> Bool {
        ["client", "pilgrim"].contains(message.senderType.lowercased())
    }

    private func isGroupStart(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        guard isMine(current) == isMine(previous) else { return true }
        guard let currentDate = parsedDate(current.createdAt), let previousDate = parsedDate(previous.createdAt) else { return true }
        return currentDate.timeIntervalSince(previousDate) > 120 || shouldShowDateSeparator(at: index)
    }

    private func isGroupEnd(at index: Int) -> Bool {
        guard index < messages.count - 1 else { return true }
        let current = messages[index]
        let next = messages[index + 1]
        guard isMine(current) == isMine(next) else { return true }
        guard let currentDate = parsedDate(current.createdAt), let nextDate = parsedDate(next.createdAt) else { return true }
        return nextDate.timeIntervalSince(currentDate) > 120 || shouldShowDateSeparator(at: index + 1)
    }

    private func rowBottomSpacing(at index: Int) -> CGFloat {
        isGroupEnd(at: index) ? 8 : 2
    }

    private func shouldShowDelivery(for index: Int) -> Bool {
        isMine(messages[index])
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        guard let current = parsedDate(messages[index].createdAt),
              let previous = parsedDate(messages[index - 1].createdAt) else { return false }

        return !Calendar.current.isDate(current, inSameDayAs: previous)
    }

    private func dateSeparatorLabel(_ raw: String) -> String {
        guard let date = parsedDate(raw) else { return "" }
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return tr("Today", "Сегодня", "Bugun", "Бугун")
        }

        if calendar.isDateInYesterday(date) {
            return tr("Yesterday", "Вчера", "Kecha", "Кеча")
        }

        let output = DateFormatter()
        output.locale = Locale(identifier: settings.language.localeIdentifier)
        output.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return output.string(from: date)
    }

    private func messageTimeLabel(_ raw: String) -> String {
        guard let date = parsedDate(raw) else { return "" }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private func messageTimeLabel(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private func rebuildMessagePresentation() {
        guard !messages.isEmpty else {
            presentationByID = [:]
            return
        }

        var next: [String: CareMessagePresentation] = [:]
        next.reserveCapacity(messages.count)

        for index in messages.indices {
            let message = messages[index]
            let showDate = shouldShowDateSeparator(at: index)
            next[message.id] = CareMessagePresentation(
                isMine: isMine(message),
                groupStart: isGroupStart(at: index),
                groupEnd: isGroupEnd(at: index),
                showDelivery: shouldShowDelivery(for: index),
                showDateSeparator: showDate,
                dateSeparatorText: showDate ? dateSeparatorLabel(message.createdAt) : "",
                timeText: messageTimeLabel(message.createdAt),
                isFirst: index == messages.startIndex
            )
        }

        presentationByID = next
    }

    private func fallbackPresentation(for message: ChatMessage) -> CareMessagePresentation {
        CareMessagePresentation(
            isMine: isMine(message),
            groupStart: true,
            groupEnd: true,
            showDelivery: false,
            showDateSeparator: false,
            dateSeparatorText: "",
            timeText: messageTimeLabel(message.createdAt),
            isFirst: false
        )
    }

    private func parsedDate(_ raw: String) -> Date? {
        ISO8601DateFormatter.chatDefault.date(from: raw) ?? ISO8601DateFormatter.chatFractional.date(from: raw)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.90)) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }

    // MARK: - Care Profile Actions

    @MainActor
    private func loadCareProfile() async {
        guard careProfile == nil else { return }
        careProfile = try? await ChatService().loadCareProfile()
    }

    private var preferredPhone: String {
        directCarePhone
    }

    private func openPhone() {
        let digits = preferredPhone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel:\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func openTelegram() {
        guard let raw = careProfile?.telegram.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return }
        let url: URL?
        if raw.lowercased().hasPrefix("http") {
            url = URL(string: raw)
        } else {
            let username = raw
                .replacingOccurrences(of: "@", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            url = URL(string: "https://t.me/\(username)")
        }
        if let url { UIApplication.shared.open(url) }
    }

    private func openWhatsApp() {
        guard let raw = careProfile?.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return }
        if raw.lowercased().hasPrefix("http"), let url = URL(string: raw) {
            UIApplication.shared.open(url)
            return
        }
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty, let url = URL(string: "https://wa.me/\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Presentation Helpers

    private var careSupportText: String {
        tr(
            "Support by your side throughout your journey",
            "Поддержка рядом на всех этапах вашей поездки",
            "Safaringizning barcha bosqichlarida yoningizdagi yordam",
            "Сафарингизнинг барча босқичларида ёнингиздаги ёрдам"
        )
    }

    private var conversationPrimary: Color {
        appearance.wallpaper.isVisual ? .white : .primary
    }

    private var conversationSecondary: Color {
        appearance.wallpaper.isVisual ? .white.opacity(0.68) : .secondary
    }

    private var headerPrimary: Color {
        appearance.wallpaper.isVisual ? .white : .primary
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private struct CareMessagePresentation {
    let isMine: Bool
    let groupStart: Bool
    let groupEnd: Bool
    let showDelivery: Bool
    let showDateSeparator: Bool
    let dateSeparatorText: String
    let timeText: String
    let isFirst: Bool
}

private struct CareChatBottomYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PendingOutgoingMessage: Identifiable, Equatable {
    let id: String
    let body: String
    let createdAt: Date
}

private func optimizedChatJPEG(_ data: Data) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let maxSide: CGFloat = 1600
    let sourceSize = image.size
    let largest = max(sourceSize.width, sourceSize.height)
    let scale = largest > maxSide ? maxSide / largest : 1
    let target = CGSize(
        width: max(1, sourceSize.width * scale),
        height: max(1, sourceSize.height * scale)
    )
    let renderer = UIGraphicsImageRenderer(size: target)
    let normalized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: target))
    }
    return normalized.jpegData(compressionQuality: 0.80)
}

private extension ISO8601DateFormatter {
    static let chatDefault: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let chatFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
