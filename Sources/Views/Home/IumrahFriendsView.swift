import SwiftUI
import UIKit

struct IumrahGiftCardsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var dashboard: IumrahFriendsDashboard?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedArtwork = 1
    @State private var selectedGiftID: String?
    @State private var showShareSheet = false

    private let artworkNames = ["GiftCardTogether", "GiftCardKaaba", "GiftCardJourney"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            backgroundGlow

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    welcomeCarousel
                        .padding(.top, 10)

                    welcomeCopy
                        .padding(.top, 28)
                        .padding(.horizontal, 34)

                    actionArea
                        .padding(.top, 22)
                        .padding(.horizontal, 44)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .systemYellow))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 16)
                    }

                    footerStatus
                        .padding(.top, 18)
                        .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .preferredColorScheme(.dark)
        .task(id: account.bearerToken) { await loadDashboard() }
        .refreshable { await loadDashboard() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, account.isAuthenticated else { return }
            Task { await loadDashboard() }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            Task { await loadDashboard() }
        }) {
            shareSheet
                .preferredColorScheme(.dark)
        }
    }

    private var availableGifts: [IumrahFriendGift] {
        dashboard?.gifts.filter(\.isAvailable) ?? []
    }

    private var selectedGift: IumrahFriendGift? {
        if let selectedGiftID,
           let exact = availableGifts.first(where: { $0.id == selectedGiftID }) {
            return exact
        }
        return availableGifts.first
    }

    private var backgroundGlow: some View {
        GeometryReader { proxy in
            Image(artworkNames[max(0, min(selectedArtwork - 1, artworkNames.count - 1))])
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width * 1.15, height: proxy.size.height * 0.60)
                .blur(radius: 58)
                .saturation(0.85)
                .opacity(0.24)
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.70), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .offset(y: -50)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var welcomeCarousel: some View {
        let positions = dashboard == nil ? [1, 2, 3] : availableGifts.map(\.position)
        return GeometryReader { proxy in
            let width = min(238.0, proxy.size.width * 0.60)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    if positions.isEmpty {
                        GiftWelcomeEmptyArtwork(language: settings.language)
                            .frame(width: width)
                            .id(0)
                    } else {
                        ForEach(positions, id: \.self) { position in
                            let assetIndex = ((position - 1) % artworkNames.count + artworkNames.count) % artworkNames.count
                            GiftWelcomeArtwork(assetName: artworkNames[assetIndex], position: position, language: settings.language)
                                .frame(width: width)
                                .scrollTransition(axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1.0 : 0.91)
                                        .opacity(phase.isIdentity ? 1.0 : 0.70)
                                }
                                .id(position)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, max(0, (proxy.size.width - width) / 2))
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding(
                get: { selectedArtwork },
                set: { if let newValue = $0 { selectedArtwork = newValue } }
            ))
        }
        .frame(height: 360)
    }

    private var welcomeCopy: some View {
        VStack(spacing: 8) {
            Text(tr("Welcome to", "Добро пожаловать в", "Xush kelibsiz", "Хуш келибсиз"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            Text("iumrah Gift Card")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(-0.9)
                .foregroundStyle(.white)

            Text(tr(
                "Share a $100 Gift Card with someone close to you for their first eligible Umrah booking.",
                "Подарите близкому Gift Card на $100 для первого подходящего бронирования Умры.",
                "Yaqin insoningizga birinchi mos Umrah broni uchun $100 Gift Card ulashing.",
                "Яқин инсонингизга биринчи мос Умра брони учун $100 Gift Card улашинг."
            ))
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.62))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if account.isAuthenticated {
            Button {
                guard !availableGifts.isEmpty else { return }
                selectedGiftID = availableGifts.first?.id
                IumrahHaptics.selection()
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    if isLoading && dashboard == nil {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(tr("Share Gift Card", "Поделиться Gift Card", "Gift Card ulashish", "Gift Card улашиш"))
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .frame(height: 46)
                .background(Color.white, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(availableGifts.isEmpty || (isLoading && dashboard == nil))
            .opacity(availableGifts.isEmpty && dashboard != nil ? 0.48 : 1)
        } else {
            Button {
                dismiss()
                chrome.navigate(to: .account)
            } label: {
                Text(tr("Open iumrah account", "Открыть аккаунт iumrah", "iumrah akkauntini ochish", "iumrah аккаунтини очиш"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .frame(height: 46)
                    .background(Color.white, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var footerStatus: some View {
        if account.isAuthenticated, let dashboard {
            VStack(spacing: 4) {
                Text(tr(
                    "\(availableGifts.count) of 3 available",
                    "Доступно: \(availableGifts.count) из 3",
                    "3 tadan \(availableGifts.count) tasi mavjud",
                    "3 тадан \(availableGifts.count) таси мавжуд"
                ))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))

                if dashboard.availableCreditUsd > 0 {
                    Text(tr(
                        "iumrah Balance: \(money(dashboard.availableCreditUsd))",
                        "iumrah Balance: \(money(dashboard.availableCreditUsd))",
                        "iumrah Balance: \(money(dashboard.availableCreditUsd))",
                        "iumrah Balance: \(money(dashboard.availableCreditUsd))"
                    ))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
                }
            }
        }
    }

    private var shareSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text(tr("Choose a Gift Card", "Выберите Gift Card", "Gift Card tanlang", "Gift Card танланг"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(-0.6)
                        Text(tr(
                            "Choose one card, then send it with the system Share menu.",
                            "Выберите одну карту и отправьте её через системное меню «Поделиться».",
                            "Bitta kartani tanlang va tizimdagi ulashish menyusi orqali yuboring.",
                            "Битта картани танланг ва тизимдаги улашиш менюси орқали юборинг."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 22)

                    if availableGifts.isEmpty {
                        VStack(spacing: 10) {
                            IumrahIconBadge(systemName: "checkmark", role: .confirmed, size: 50, symbolSize: 20, cornerRadius: 17)
                            Text(tr("No Gift Cards available", "Нет доступных Gift Cards", "Mavjud Gift Card yo‘q", "Мавжуд Gift Card йўқ"))
                                .font(.headline)
                            Text(tr(
                                "Cards that are no longer available are removed from this list.",
                                "Карты, которые больше недоступны, исчезают из этого списка.",
                                "Endi mavjud bo‘lmagan kartalar bu ro‘yxatdan yo‘qoladi.",
                                "Энди мавжуд бўлмаган карталар бу рўйхатдан йўқолади."
                            ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 60)
                        .padding(.horizontal, 28)
                    } else {
                        GiftCardCarousel(
                            gifts: availableGifts,
                            language: settings.language,
                            selectedGiftID: $selectedGiftID
                        )
                        .frame(height: 356)

                        if let gift = selectedGift {
                            VStack(spacing: 14) {
                                HStack(spacing: 12) {
                                    IumrahIconBadge(systemName: "gift.fill", role: .gift, size: 42, symbolSize: 17, cornerRadius: 13)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tr("Gift code", "Код Gift Card", "Gift Card kodi", "Gift Card коди"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(gift.code)
                                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                            .textSelection(.enabled)
                                    }
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = gift.code
                                        IumrahHaptics.success()
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 15, weight: .semibold))
                                            .frame(width: 38, height: 38)
                                            .background(Color.iumrahRaisedBackground, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(14)
                                .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                                ShareLink(item: shareText(gift), preview: SharePreview("iumrah Gift Card", image: Image(systemName: "gift.fill"))) {
                                    Label(tr("Share Gift Card", "Поделиться Gift Card", "Gift Card ulashish", "Gift Card улашиш"), systemImage: "square.and.arrow.up")
                                        .font(.headline)
                                        .foregroundStyle(Color.iumrahPrimaryButtonText)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, IumrahDesign.pagePadding)
                        }
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShareSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .accessibilityLabel(tr("Close", "Закрыть", "Yopish", "Ёпиш"))
                }
            }
        }
        .presentationDetents([.fraction(0.84), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
    }

    private func shareText(_ gift: IumrahFriendGift) -> String {
        let sender = account.account?.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (sender?.isEmpty == false ? sender! : "iumrah")
        return tr(
            "🎁 \(name) sent you an iumrah Gift Card worth $100 toward your first eligible Umrah booking. Open iumrah and use code \(gift.code). https://iumrah.app",
            "🎁 \(name) отправил(а) Вам iumrah Gift Card на $100 для первого подходящего бронирования Умры. Откройте iumrah и примените код \(gift.code). https://iumrah.app",
            "🎁 \(name) Sizga birinchi mos Umrah broniga $100 iumrah Gift Card yubordi. iumrah ni oching va \(gift.code) kodini kiriting. https://iumrah.app",
            "🎁 \(name) Сизга биринчи мос Умра бронига $100 iumrah Gift Card юборди. iumrah ни очинг ва \(gift.code) кодини киритинг. https://iumrah.app"
        )
    }

    @MainActor
    private func loadDashboard() async {
        guard account.isAuthenticated else {
            dashboard = nil
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            dashboard = try await account.friendsDashboard()
            selectedGiftID = dashboard?.gifts.first(where: \.isAvailable)?.id
            if let firstPosition = dashboard?.gifts.first(where: \.isAvailable)?.position {
                selectedArtwork = firstPosition
            }
            errorMessage = nil
        } catch {
            errorMessage = L10n.error(error, settings.language)
        }
    }

    private func money(_ value: Double) -> String { "$\(Int(value.rounded()))" }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private struct GiftWelcomeArtwork: View {
    let assetName: String
    let position: Int
    let language: AppSettingsStore.Language

    var body: some View {
        ZStack {
            Image(assetName)
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [.clear, .clear, Color.black.opacity(0.58)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack {
                    Text("iumrah")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Text("$100")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }

                Spacer()

                Text(localized("Gift Card", "Gift Card", "Gift Card", "Gift Card"))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                Text(localized("For Umrah", "Для Умры", "Umrah uchun", "Умра учун"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.top, 3)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.34), radius: 8, y: 3)
            .padding(17)
        }
        .aspectRatio(0.67, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
    }

    private func localized(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private struct GiftWelcomeEmptyArtwork: View {
    let language: AppSettingsStore.Language

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.08))
            VStack(spacing: 12) {
                IumrahIconBadge(systemName: "checkmark", role: .confirmed, size: 50, symbolSize: 20, cornerRadius: 17)
                Text(localized("All shared", "Все отправлены", "Hammasi ulashildi", "Ҳаммаси улашилди"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(localized("No Gift Cards available right now", "Сейчас нет доступных Gift Cards", "Hozir mavjud Gift Card yo‘q", "Ҳозир мавжуд Gift Card йўқ"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
                    .multilineTextAlignment(.center)
            }
            .padding(18)
        }
        .aspectRatio(0.67, contentMode: .fill)
    }

    private func localized(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private struct GiftCardCarousel: View {
    let gifts: [IumrahFriendGift]
    let language: AppSettingsStore.Language
    @Binding var selectedGiftID: String?

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(220.0, proxy.size.width * 0.57)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(gifts) { gift in
                        IumrahGiftCardPass(gift: gift, language: language)
                            .frame(width: cardWidth)
                            .overlay {
                                if selectedGiftID == gift.id {
                                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.90), lineWidth: 2.2)
                                }
                            }
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.91)
                                    .opacity(phase.isIdentity ? 1.0 : 0.72)
                            }
                            .id(gift.id)
                            .onTapGesture {
                                selectedGiftID = gift.id
                                IumrahHaptics.selection()
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, max(0, (proxy.size.width - cardWidth) / 2))
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedGiftID)
        }
    }
}
