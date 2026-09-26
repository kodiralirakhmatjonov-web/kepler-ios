import AuthenticationServices
import SwiftUI
import UserNotifications
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import PassKit

private enum IumrahGuestAccountMode: String, CaseIterable, Identifiable {
    case register
    case signIn
    var id: String { rawValue }
}

private enum IumrahGuestAuthMethod: String, CaseIterable, Identifiable {
    case sms
    case email
    case iumrahID
    var id: String { rawValue }
}

struct IumrahAccountView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared
    @ObservedObject private var push = PushNotificationManager.shared

    @State private var guestAccountMode: IumrahGuestAccountMode = .signIn
    @State private var guestAuthMethod: IumrahGuestAuthMethod = .sms
    @State private var loginID = ""
    @State private var loginEmail = ""
    @State private var loginPhone = "+998"
    @State private var loginPassword = ""
    @State private var registrationFirstName = ""
    @State private var registrationLastName = ""
    @State private var registrationEmail = ""
    @State private var registrationEmailCode = ""
    @State private var registrationEmailChallengeID = ""
    @State private var registrationPassword = ""
    @State private var registrationPasswordConfirm = ""
    @State private var isRegistering = false
    @State private var showSignOutConfirmation = false
    @State private var isLoggingIn = false
    @State private var loginError: String?
    @State private var appleNonce = ""
    @State private var isAppleSigningIn = false
    @State private var isGoogleSigningIn = false

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var telegram = ""
    @State private var whatsapp = ""
    @State private var isSavingProfile = false
    @State private var profileMessage: String?
    @State private var profileLoadedForID: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showProfileEditor = false
    @State private var identityCardFlipped = false
    @State private var showIdentityFullscreen = false
    @State private var showLanguageSheet = false
    @State private var showIdentityUnlockSheet = false
    @State private var identityRevealProgress: CGFloat = 0
    @State private var loginScrollNonce = 0
    @State private var walletPass: PKPass?
    @State private var showWalletPassSheet = false
    @State private var isLoadingWalletPass = false
    @State private var walletAlertMessage: String?
    @State private var identityPublicURL: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    accountHeader

                    if let profile = account.account {
                        identityCard(profile)
                        if let active = activeTrip {
                            IumrahTripWalletEntry(session: active, profile: profile, language: settings.language)
                        }
                        walletSection(profile)
                        if let active = activeTrip {
                            activeTripCard(active)
                        }
                        tripsSection
                        travelCompanionsSection
                        paymentSecuritySection
                        profileSection(profile)
                        settingsSection
                        signOutButton
                    } else {
                        guestCard
                        loginCard
                            .id("account-login")
                        paymentSecuritySection
                        guestSettingsSection
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 46)
            }
            .onChange(of: loginScrollNonce) { _, _ in
                withAnimation(.spring(response: 0.55, dampingFraction: 0.90)) {
                    proxy.scrollTo("account-login", anchor: .top)
                }
            }
        }
        .background(Color.iumrahPageBackground)
        .refreshable {
            await refreshAccountContent()
        }
        .task {
            loadProfileDraftIfNeeded(force: false)
            prepareIdentityRevealIfNeeded(account.iumrahID)
            await refreshNotificationStatus()
            await refreshAccountContent()
            await refreshPublicIdentityLink()
        }
        .onChange(of: account.iumrahID) { oldValue, newValue in
            loadProfileDraftIfNeeded(force: true)
            if oldValue != newValue {
                prepareIdentityRevealIfNeeded(newValue, force: newValue != nil && oldValue != newValue)
                Task { await refreshPublicIdentityLink() }
            }
        }
        .sheet(isPresented: $showProfileEditor) {
            profileEditorSheet
        }
        .sheet(isPresented: $showLanguageSheet) {
            IumrahLanguageSelectionSheet()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showIdentityUnlockSheet) {
            IumrahIdentityUnlockSheet(language: settings.language) {
                loginScrollNonce += 1
            }
        }
        .sheet(isPresented: $showWalletPassSheet) {
            if let walletPass {
                IumrahAddPassesView(pass: walletPass, isPresented: $showWalletPassSheet)
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showIdentityFullscreen) {
            identityFullscreenView
        }
        .alert("Apple Wallet", isPresented: Binding(
            get: { walletAlertMessage != nil },
            set: { if !$0 { walletAlertMessage = nil } }
        )) {
            Button(tr("OK", "OK", "OK", "OK"), role: .cancel) {
                walletAlertMessage = nil
            }
        } message: {
            Text(walletAlertMessage ?? "")
        }
        .confirmationDialog(
            tr("Sign out of iumrah?", "Выйти из iumrah?", "iumrah akkauntidan chiqasizmi?", "iumrah аккаунтидан чиқасизми?"),
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button(tr("Sign out", "Выйти", "Chiqish", "Чиқиш"), role: .destructive) {
                Task {
                    await account.logout()
                    bookings.setAccountToken(nil)
                    IumrahHaptics.soft()
                }
            }
            Button(tr("Cancel", "Отмена", "Bekor qilish", "Бекор қилиш"), role: .cancel) {}
        } message: {
            Text(tr(
                "Your trips stay safely linked to your iumrah account. You will need to sign in again on this device.",
                "Ваши поездки останутся безопасно привязаны к аккаунту iumrah. На этом устройстве потребуется войти снова.",
                "Safarlaringiz iumrah akkauntingizga xavfsiz bog‘langan holda qoladi. Bu qurilmada qayta kirishingiz kerak bo‘ladi.",
                "Сафарларингиз iumrah аккаунтингизга хавфсиз боғланган ҳолда қолади. Бу қурилмада қайта киришингиз керак бўлади."
            ))
        }
    }

    private var accountHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Account")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-1)
                Text(account.isAuthenticated ? tr("Your iumrah profile and trips", "Ваш профиль и поездки iumrah", "iumrah profilingiz va safarlaringiz", "iumrah профилингиз ва сафарларингиз") : tr("Sign in or create your permanent iumrah account", "Войдите или создайте постоянный аккаунт iumrah", "Doimiy iumrah akkauntingizga kiring yoki uni yarating", "Доимий iumrah аккаунтингизга киринг ёки уни яратинг"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 10)
            IumrahIconBadge(
                systemName: account.isAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle",
                role: account.isAuthenticated ? .success : .profile,
                size: 50,
                symbolSize: 24,
                shape: .circle
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func identityCard(_ profile: IumrahAccountProfile) -> some View {
        VStack(spacing: 10) {
            ZStack {
                identityFront(profile)
                    .opacity(identityCardFlipped ? 0 : 1)

                identityBack(profile)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(identityCardFlipped ? 1 : 0)
            }
            .frame(height: 238)
            .overlay {
                IumrahIdentitySealOverlay(
                    progress: identityRevealProgress,
                    showsPrompt: false,
                    language: settings.language
                )
            }
            .rotation3DEffect(.degrees(identityCardFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
            .animation(.spring(response: 0.52, dampingFraction: 0.82), value: identityCardFlipped)
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .onTapGesture {
                IumrahHaptics.selection()
                identityCardFlipped.toggle()
            }

            HStack(spacing: 8) {
                Label(
                    identityCardFlipped ? tr("Front side", "Лицевая сторона", "Old tomoni", "Олд томони") : tr("Tap to flip", "Нажмите, чтобы перевернуть", "Aylantirish uchun bosing", "Айлантириш учун босинг"),
                    systemImage: identityCardFlipped ? "rectangle.portrait.rotate" : "hand.tap.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Spacer()
                Button {
                    IumrahHaptics.selection()
                    showIdentityFullscreen = true
                } label: {
                    Label(tr("Full screen", "На весь экран", "To‘liq ekran", "Тўлиқ экран"), systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .iumrahGlass(in: Capsule(), interactive: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
        }
    }

    private func identityFront(_ profile: IumrahAccountProfile) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)

            LinearGradient(
                colors: [Color.white.opacity(0.10), .clear, Color.white.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            Circle()
                .fill(Color.white.opacity(0.055))
                .frame(width: 190, height: 190)
                .offset(x: 220, y: -98)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("iumrah ID")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                        Text(tr("DIGITAL PILGRIM IDENTITY", "ЦИФРОВАЯ ID-КАРТА ПАЛОМНИКА", "RAQAMLI ZIYORATCHI ID", "РАҚАМЛИ ЗИЁРАТЧИ ID"))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.52))
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(displayName(profile))
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(normalizedID(profile.iumrahID))
                        .font(.system(size: 33, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .textSelection(.enabled)
                }

                HStack(spacing: 18) {
                    Label("\(bookings.sessions.count) \(tr("trips", "поездок", "safar", "сафар"))", systemImage: "suitcase.fill")
                    Label(tr("Permanent ID", "Постоянный ID", "Doimiy ID", "Доимий ID"), systemImage: "person.text.rectangle.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1) }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }

    private func identityBack(_ profile: IumrahAccountProfile) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)

            LinearGradient(
                colors: [Color.white.opacity(0.08), .clear, Color.white.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            HStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Image("HeaderWordmarkDark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 142, height: 34, alignment: .leading)
                        .accessibilityLabel("Iumrah")

                    Text(tr("Digital pilgrim identity", "Цифровая ID-карта паломника", "Raqamli ziyoratchi ID", "Рақамли зиёратчи ID"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.54))

                    Spacer(minLength: 4)

                    Text("iumrah ID")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.48))

                    Text(normalizedID(profile.iumrahID))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white)

                    Text("iumrah.app")
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer(minLength: 4)

                qrCodeView(identityPublicURL ?? fallbackIdentityURL(profile.iumrahID), size: 116)
                    .padding(9)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                    }
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }

    private var identityFullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let profile = account.account {
                VStack(spacing: 22) {
                    HStack {
                        Spacer()
                        Button {
                            IumrahHaptics.soft()
                            showIdentityFullscreen = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .contentShape(Circle())
                                .iumrahGlass(in: Circle(), interactive: true, tint: .black.opacity(0.18), chrome: true)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    ZStack {
                        identityFront(profile).opacity(identityCardFlipped ? 0 : 1)
                        identityBack(profile)
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            .opacity(identityCardFlipped ? 1 : 0)
                    }
                    .frame(height: 260)
                    .rotation3DEffect(.degrees(identityCardFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                    .animation(.spring(response: 0.52, dampingFraction: 0.82), value: identityCardFlipped)
                    .onTapGesture {
                        IumrahHaptics.selection()
                        identityCardFlipped.toggle()
                    }

                    Text(tr("Tap the card to flip it", "Нажмите на карту, чтобы перевернуть", "Kartani aylantirish uchun bosing", "Картани айлантириш учун босинг"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }

    @ViewBuilder
    private func qrCodeView(_ value: String, size: CGFloat) -> some View {
        if let image = makeQRCode(value) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: size * 0.66, weight: .medium))
                .frame(width: size, height: size)
                .foregroundStyle(.black)
        }
    }

    private func makeQRCode(_ value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext(options: nil)
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func walletSection(_ profile: IumrahAccountProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black)
                        .frame(width: 48, height: 48)
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("iumrah ID in Apple Wallet", "iumrah ID в Apple Wallet", "iumrah ID Apple Wallet’da", "iumrah ID Apple Wallet’да"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(tr(
                        "Keep your digital pilgrim ID and QR code available from Wallet.",
                        "Храните цифровую ID-карту паломника и QR-код прямо в Wallet.",
                        "Raqamli ziyoratchi ID va QR-kodni Wallet’da saqlang.",
                        "Рақамли зиёратчи ID ва QR-кодни Wallet’да сақланг."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iumrah ID")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(normalizedID(profile.iumrahID))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                }

                Spacer(minLength: 10)

                if isLoadingWalletPass {
                    ProgressView()
                        .controlSize(.regular)
                        .frame(width: 162, height: 48)
                } else if PKPassLibrary.isPassLibraryAvailable() {
                    IumrahAddToWalletButton {
                        Task { await addIdentityToWallet() }
                    }
                    .frame(width: 162, height: 48)
                } else {
                    Text(tr("Wallet unavailable", "Wallet недоступен", "Wallet mavjud emas", "Wallet мавжуд эмас"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color.iumrahRaisedBackground.opacity(0.60), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .iumrahCard()
    }

    private func activeTripCard(_ session: StoredBookingSession) -> some View {
        NavigationLink {
            BookingDetailView(bookingID: session.id)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    IumrahIconBadge(
                        systemName: session.effectiveStatus.uppercased() == "IN_TRIP" ? "location.fill" : "airplane.departure",
                        role: session.effectiveStatus.uppercased() == "IN_TRIP" ? .location : .travel,
                        size: 48,
                        symbolSize: 19,
                        cornerRadius: 16
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Active trip", "Активная поездка", "Faol safar", "Фаол сафар"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                        Text("Бронь \(session.displayBookingNumber)")
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                }

                HStack(spacing: 8) {
                    statusChip(session.effectiveStatus)
                    tripDateChip(session)
                }

                if !session.booking.hotelNames.makkah.isEmpty {
                    Label(session.booking.hotelNames.makkah, systemImage: "building.2.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahCard()
        }
        .buttonStyle(.plain)
    }

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("My trips", "Мои поездки", "Safarlarim", "Сафарларим"))
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    Text(tr("Current, completed and cancelled bookings", "Текущие, завершённые и отменённые бронирования", "Joriy, yakunlangan va bekor qilingan bronlar", "Жорий, якунланган ва бекор қилинган бронлар"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                IumrahIconBadge(systemName: "suitcase.fill", role: .booking, size: 38, symbolSize: 16, shape: .circle)
            }

            if allTrips.isEmpty {
                HStack(spacing: 12) {
                    IumrahIconBadge(systemName: "suitcase", role: .booking, size: 42, symbolSize: 18, cornerRadius: 14)
                    Text(tr("Your trips will appear here after they are linked to this iumrah ID.", "Все поездки, привязанные к этому iumrah ID, появятся здесь.", "Ushbu iumrah ID ga bog‘langan safarlar shu yerda ko‘rinadi.", "Ушбу iumrah ID га боғланган сафарлар шу ерда кўринади."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.iumrahRaisedBackground.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allTrips.enumerated()), id: \.element.id) { index, session in
                        NavigationLink {
                            BookingDetailView(bookingID: session.id)
                        } label: {
                            tripRow(session)
                        }
                        .buttonStyle(.plain)
                        if index < allTrips.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .iumrahCard()
    }

    private var travelCompanionsSection: some View {
        NavigationLink {
            IumrahTravelCompanionsView()
        } label: {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 13) {
                    IumrahIconBadge(systemName: "person.2.fill", role: .profile, size: 50, symbolSize: 20, cornerRadius: 17)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Who is traveling with you", "Кто едет с Вами", "Siz bilan kim bormoqda", "Сиз билан ким бормоқда"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(tr("Your family and loved ones", "Ваша семья и близкие", "Oilangiz va yaqinlaringiz", "Оилангиз ва яқинларингиз"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 17)
                }

                Text(tr("Keep each traveler’s passport details in a separate, clear card and reuse them for the booking.", "Храните данные каждого участника в отдельной понятной карточке и используйте их в бронировании.", "Har bir sayohatchi ma’lumotini alohida kartada saqlang va bronda ishlating.", "Ҳар бир саёҳатчи маълумотини алоҳида картада сақланг ва бронда ишлатинг."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .iumrahCard()
        }
        .buttonStyle(.plain)
    }

    private func profileSection(_ profile: IumrahAccountProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                sectionHeader(
                    icon: "person.text.rectangle.fill",
                    title: tr("Account details", "Данные аккаунта", "Akkaunt ma’lumotlari", "Аккаунт маълумотлари"),
                    subtitle: tr("Used for your profile and future trips", "Используются в профиле и новых поездках", "Profil va yangi safarlarda ishlatiladi", "Профил ва янги сафарларда ишлатилади")
                )
                Spacer(minLength: 4)
                Button {
                    loadProfileDraftIfNeeded(force: true, profile: profile)
                    profileMessage = nil
                    showProfileEditor = true
                    IumrahHaptics.selection()
                } label: {
                    Label(tr("Edit", "Изменить", "Tahrirlash", "Таҳрирлаш"), systemImage: "pencil")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .iumrahGlass(in: Capsule(), interactive: true)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                accountSummaryRow(icon: "person.fill", role: .profile, title: tr("Name", "Имя", "Ism", "Исм"), value: displayName(profile))
                Divider().padding(.leading, 52)
                accountSummaryRow(icon: "phone.fill", role: .phone, title: tr("Phone", "Телефон", "Telefon", "Телефон"), value: profile.phone)
                Divider().padding(.leading, 52)
                accountSummaryRow(icon: "envelope.fill", role: .mail, title: "Email", value: profile.email)
                Divider().padding(.leading, 52)
                accountSummaryRow(icon: "paperplane.fill", role: .telegram, title: "Telegram", value: profile.telegram)
                Divider().padding(.leading, 52)
                accountSummaryRow(icon: "message.fill", role: .whatsapp, title: "WhatsApp", value: profile.whatsapp)
            }
            .padding(.horizontal, 4)
        }
        .iumrahCard()
        .onAppear { loadProfileDraftIfNeeded(force: false, profile: profile) }
    }

    private func accountSummaryRow(icon: String, role: IumrahIconRole, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            IumrahIconBadge(systemName: icon, role: role, size: 38, symbolSize: 14, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    private var profileEditorSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(tr("Account details", "Данные аккаунта", "Akkaunt ma’lumotlari", "Аккаунт маълумотлари"))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(tr("These details are reused for future Iumrah trips.", "Эти данные будут использоваться для Ваших следующих поездок Iumrah.", "Bu ma’lumotlar keyingi Iumrah safarlarida ishlatiladi.", "Бу маълумотлар кейинги Iumrah сафарларида ишлатилади."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        accountField(tr("First name", "Имя", "Ism", "Исм"), text: $firstName, contentType: .givenName)
                        accountField(tr("Last name", "Фамилия", "Familiya", "Фамилия"), text: $lastName, contentType: .familyName)
                        accountField(tr("Phone", "Телефон", "Telefon", "Телефон"), text: $phone, keyboard: .phonePad, contentType: .telephoneNumber)
                        accountField("Email", text: $email, keyboard: .emailAddress, contentType: .emailAddress, autocapitalization: .never)
                        accountField("Telegram", text: $telegram, autocapitalization: .never)
                        accountField("WhatsApp", text: $whatsapp, keyboard: .phonePad, contentType: .telephoneNumber)
                    }
                    .padding(16)
                    .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                    if let profileMessage {
                        Text(profileMessage)
                            .font(.footnote)
                            .foregroundStyle(profileMessage == savedText ? Color.green : Color.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await saveProfile(dismissAfterSave: true) }
                    } label: {
                        HStack(spacing: 10) {
                            if isSavingProfile { ProgressView().tint(.white) }
                            Image(systemName: "checkmark.circle.fill")
                            Text(tr("Save account details", "Сохранить данные аккаунта", "Akkaunt ma’lumotlarini saqlash", "Аккаунт маълумотларини сақлаш"))
                            Spacer(minLength: 8)
                        }
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                    .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingProfile)
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(Color.iumrahPageBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close", "Закрыть", "Yopish", "Ёпиш")) { showProfileEditor = false }
                }
            }
        }
    }

    private var paymentSecuritySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(
                icon: "lock.shield.fill",
                title: tr("Payment & security", "Оплата и безопасность", "To‘lov va xavfsizlik", "Тўлов ва хавфсизлик"),
                subtitle: tr(
                    "Payment, policies, KYC and account protection",
                    "Оплата, правила, KYC и защита аккаунта",
                    "To‘lov, qoidalar, KYC va akkaunt himoyasi",
                    "Тўлов, қоидалар, KYC ва аккаунт ҳимояси"
                )
            )
            .padding(.bottom, 8)

            NavigationLink {
                IumrahPolicyDetailView(kind: .paymentSecurity)
            } label: {
                settingsRow(
                    icon: "creditcard.fill",
                    title: tr("Payment", "Оплата", "To‘lov", "Тўлов"),
                    value: tr(
                        "Method, confirmation and payment security",
                        "Способ, подтверждение и безопасность платежа",
                        "Usul, tasdiqlash va to‘lov xavfsizligi",
                        "Усул, тасдиқлаш ва тўлов хавфсизлиги"
                    )
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            NavigationLink {
                IumrahPolicyDetailView(kind: .refund)
            } label: {
                settingsRow(
                    icon: "arrow.uturn.backward.circle.fill",
                    title: IumrahPolicyKind.refund.title(settings.language),
                    value: tr(
                        "Flights, hotels, transfer and services",
                        "Авиабилеты, отели, трансфер и сервисы",
                        "Aviachipta, mehmonxona, transfer va xizmatlar",
                        "Авиачипта, меҳмонхона, трансфер ва хизматлар"
                    )
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            NavigationLink {
                IumrahPolicyDetailView(kind: .privacy)
            } label: {
                settingsRow(
                    icon: "hand.raised.fill",
                    title: IumrahPolicyKind.privacy.title(settings.language),
                    value: tr(
                        "Personal data and privacy",
                        "Персональные данные и конфиденциальность",
                        "Shaxsiy ma’lumotlar va maxfiylik",
                        "Шахсий маълумотлар ва махфийлик"
                    )
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            if let trip = kycTrip {
                NavigationLink {
                    IumrahSecurityConfirmationView(bookingID: trip.id)
                } label: {
                    settingsRow(
                        icon: "person.text.rectangle.fill",
                        title: "KYC · iumrah Security",
                        value: tr(
                            "Identity confirmation for booking \(trip.displayBookingNumber)",
                            "Подтверждение личности для брони \(trip.displayBookingNumber)",
                            "\(trip.displayBookingNumber) broni uchun shaxsni tasdiqlash",
                            "\(trip.displayBookingNumber) брони учун шахсни тасдиқлаш"
                        )
                    )
                }
                .buttonStyle(.plain)
            } else {
                settingsRow(
                    icon: "person.text.rectangle.fill",
                    title: "KYC · iumrah Security",
                    value: tr(
                        "Available when you have a booking",
                        "Доступно после создания бронирования",
                        "Bron yaratilgandan keyin mavjud",
                        "Брон яратилгандан кейин мавжуд"
                    )
                )
                .opacity(0.58)
            }

            if account.isAuthenticated {
                Divider().padding(.leading, 54)

                NavigationLink {
                    IumrahAccountSecurityView()
                } label: {
                    settingsRow(
                        icon: "lock.shield.fill",
                        title: tr("Account security", "Безопасность аккаунта", "Akkaunt xavfsizligi", "Аккаунт хавфсизлиги"),
                        value: tr("Apple, Google and active sessions", "Apple, Google и активные сеансы", "Apple, Google va faol seanslar", "Apple, Google ва фаол сеанслар")
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .iumrahCard()
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(
                icon: "gearshape.fill",
                title: tr("Settings", "Настройки", "Sozlamalar", "Созламалар"),
                subtitle: tr(
                    "Language, appearance and notifications",
                    "Язык, оформление и уведомления",
                    "Til, ko‘rinish va bildirishnomalar",
                    "Тил, кўриниш ва билдиришномалар"
                )
            )
            .padding(.bottom, 8)

            Button {
                IumrahHaptics.soft()
                showLanguageSheet = true
            } label: {
                settingsRow(icon: "globe", title: tr("Language", "Язык", "Til", "Тил"), value: settings.language.title)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            NavigationLink {
                IumrahAppearanceView()
            } label: {
                settingsRow(
                    icon: "circle.lefthalf.filled",
                    title: tr("Appearance", "Оформление", "Ko‘rinish", "Кўриниш"),
                    value: settings.appearance.title(settings.language)
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            NavigationLink {
                AccountNotificationsView()
            } label: {
                settingsRow(icon: "bell.and.waves.left.and.right.fill", title: "iumrah Signal", value: signalHistoryValueText)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            Button {
                openSystemSettings()
            } label: {
                settingsRow(
                    icon: "bell.badge.fill",
                    title: tr("Notifications", "Уведомления", "Bildirishnomalar", "Билдиришномалар"),
                    value: notificationStatusText
                )
            }
            .buttonStyle(.plain)
        }
        .iumrahCard()
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            showSignOutConfirmation = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text(tr("Sign out", "Выйти из аккаунта", "Akkauntdan chiqish", "Аккаунтдан чиқиш"))
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .foregroundStyle(.red)
            .background(Color.red.opacity(0.075), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var guestCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            IumrahIconBadge(systemName: "person.crop.circle.badge.key.fill", role: .security, size: 54, symbolSize: 25, cornerRadius: 18)

            Text(tr("Your permanent iumrah account", "Ваш постоянный аккаунт iumrah", "Doimiy iumrah akkauntingiz", "Доимий iumrah аккаунтингиз"))
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text(tr("Sign in once to restore all trips after reinstalling the app and automatically link future bookings to the same ID.", "Войдите один раз, чтобы восстанавливать все поездки после переустановки приложения и автоматически привязывать новые брони к одному ID.", "Ilovani qayta o‘rnatgandan keyin barcha safarlarni tiklash va yangi bronlarni bitta ID ga bog‘lash uchun kiring.", "Иловани қайта ўрнатгандан кейин барча сафарларни тиклаш ва янги бронларни битта ID га боғлаш учун киринг."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                icon: guestAccountMode == .signIn ? "key.fill" : "person.badge.plus",
                title: guestAccountMode == .signIn
                    ? tr("Sign in", "Вход", "Kirish", "Кириш")
                    : tr("Create account", "Регистрация", "Ro‘yxatdan o‘tish", "Рўйхатдан ўтиш"),
                subtitle: guestAccountMode == .signIn
                    ? tr("Use the method linked to your permanent iumrah account", "Используйте способ, привязанный к Вашему постоянному аккаунту iumrah", "Doimiy iumrah akkauntingizga ulangan usuldan foydalaning", "Доимий iumrah аккаунтингизга уланган усулдан фойдаланинг")
                    : tr("Create one permanent account for all future trips", "Создайте один постоянный аккаунт для всех будущих поездок", "Barcha keyingi safarlar uchun bitta doimiy akkaunt yarating", "Барча кейинги сафарлар учун битта доимий аккаунт яратинг")
            )

            Picker("", selection: $guestAccountMode) {
                Text(tr("Register", "Регистрация", "Ro‘yxatdan o‘tish", "Рўйхатдан ўтиш")).tag(IumrahGuestAccountMode.register)
                Text(tr("Sign in", "Вход", "Kirish", "Кириш")).tag(IumrahGuestAccountMode.signIn)
            }
            .pickerStyle(.segmented)
            .onChange(of: guestAccountMode) { _, _ in
                loginError = nil
                registrationEmailChallengeID = ""
                registrationEmailCode = ""
            }

            Picker("", selection: $guestAuthMethod) {
                Text("SMS").tag(IumrahGuestAuthMethod.sms)
                Text("Email").tag(IumrahGuestAuthMethod.email)
                Text("iumrah ID").tag(IumrahGuestAuthMethod.iumrahID)
            }
            .pickerStyle(.segmented)
            .onChange(of: guestAuthMethod) { _, _ in loginError = nil }

            if guestAccountMode == .signIn {
                guestSignInFields
            } else {
                guestRegistrationFields
            }

            if let loginError {
                Text(loginError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Rectangle().fill(Color.secondary.opacity(0.20)).frame(height: 1)
                Text(tr("or", "или", "yoki", "ёки"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Rectangle().fill(Color.secondary.opacity(0.20)).frame(height: 1)
            }

            IumrahLocalizedAppleAuthButton(
                title: guestAccountMode == .signIn
                    ? tr("Sign in with Apple", "Войти с Apple", "Apple orqali kirish", "Apple орқали кириш")
                    : tr("Continue with Apple", "Продолжить с Apple", "Apple bilan davom etish", "Apple билан давом этиш"),
                isDisabled: isAppleSigningIn || isGoogleSigningIn || isLoggingIn || isRegistering,
                onRequest: prepareAppleSignIn,
                onCompletion: completeAppleSignIn
            )

            IumrahGoogleAuthButton(
                title: guestAccountMode == .signIn
                    ? tr("Sign in with Google", "Войти с Google", "Google orqali kirish", "Google орқали кириш")
                    : tr("Continue with Google", "Продолжить с Google", "Google bilan davom etish", "Google билан давом этиш"),
                isDisabled: isGoogleSigningIn || isAppleSigningIn || isLoggingIn || isRegistering
            ) {
                startGoogleSignIn()
            }

            Text(tr(
                "Apple and Google use the same permanent iumrah account; they do not create a separate trip profile.",
                "Apple и Google используют тот же постоянный аккаунт iumrah и не создают отдельный профиль поездки.",
                "Apple va Google aynan shu doimiy iumrah akkauntidan foydalanadi va alohida safar profili yaratmaydi.",
                "Apple ва Google айнан шу доимий iumrah аккаунтидан фойдаланади ва алоҳида сафар профили яратмайди."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .iumrahCard()
    }

    @ViewBuilder
    private var guestSignInFields: some View {
        switch guestAuthMethod {
        case .iumrahID:
            accountInputField(symbol: "number", placeholder: "00000016", text: $loginID, keyboard: .numberPad, contentType: .username) { raw in
                let digits = String(raw.filter(\.isNumber).prefix(8))
                if digits != raw { loginID = digits }
            }
        case .email:
            accountInputField(symbol: "envelope.fill", placeholder: "name@example.com", text: $loginEmail, keyboard: .emailAddress, contentType: .emailAddress) { raw in
                let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if cleaned != raw { loginEmail = cleaned }
            }
        case .sms:
            accountInputField(symbol: "phone.fill", placeholder: "+998 90 123 45 67", text: $loginPhone, keyboard: .phonePad, contentType: .telephoneNumber) { raw in
                let formatted = normalizedUZPhoneInput(raw)
                if formatted != raw { loginPhone = formatted }
            }
            if !loginPhone.isEmpty && !normalizedUZPhoneInput(loginPhone).hasPrefix("+998") {
                unsupportedSMSNotice
            }
        }

        accountPasswordField(text: $loginPassword, placeholder: tr("Password", "Пароль", "Parol", "Парол"))

        Button {
            Task { await login() }
        } label: {
            HStack(spacing: 10) {
                if isLoggingIn { ProgressView().tint(.white) }
                Image(systemName: "person.crop.circle.fill")
                Text(tr("Sign in to iumrah", "Войти в iumrah", "iumrah ga kirish", "iumrah га кириш"))
                Spacer(minLength: 10)
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(!guestLoginReady || isLoggingIn || isAppleSigningIn || isGoogleSigningIn)
    }

    @ViewBuilder
    private var guestRegistrationFields: some View {
        switch guestAuthMethod {
        case .email:
            HStack(spacing: 10) {
                accountInputField(symbol: "person.fill", placeholder: tr("First name", "Имя", "Ism", "Исм"), text: $registrationFirstName, keyboard: .default, contentType: .givenName)
                accountInputField(symbol: "person.fill", placeholder: tr("Last name", "Фамилия", "Familiya", "Фамилия"), text: $registrationLastName, keyboard: .default, contentType: .familyName)
            }

            accountInputField(symbol: "envelope.fill", placeholder: "name@example.com", text: $registrationEmail, keyboard: .emailAddress, contentType: .emailAddress) { raw in
                let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if cleaned != raw { registrationEmail = cleaned }
            }
            .disabled(!registrationEmailChallengeID.isEmpty)

            if !registrationEmailChallengeID.isEmpty {
                accountInputField(symbol: "number.square.fill", placeholder: tr("6-digit code", "Код из 6 цифр", "6 xonali kod", "6 хонали код"), text: $registrationEmailCode, keyboard: .numberPad, contentType: .oneTimeCode) { raw in
                    let digits = String(raw.filter(\.isNumber).prefix(6))
                    if digits != raw { registrationEmailCode = digits }
                }
                accountPasswordField(text: $registrationPassword, placeholder: tr("Create password", "Создайте пароль", "Parol yarating", "Парол яратинг"))
                accountPasswordField(text: $registrationPasswordConfirm, placeholder: tr("Confirm password", "Подтвердите пароль", "Parolni tasdiqlang", "Паролни тасдиқланг"))
            }

            Button {
                Task {
                    if registrationEmailChallengeID.isEmpty { await startGuestEmailRegistration() }
                    else { await confirmGuestEmailRegistration() }
                }
            } label: {
                HStack {
                    if isRegistering { ProgressView().tint(.white) }
                    Text(registrationEmailChallengeID.isEmpty
                         ? tr("Send verification code", "Отправить код", "Tasdiqlash kodini yuborish", "Тасдиқлаш кодини юбориш")
                         : tr("Create iumrah account", "Создать аккаунт iumrah", "iumrah akkauntini yaratish", "iumrah аккаунтини яратиш"))
                    Spacer()
                    Image(systemName: registrationEmailChallengeID.isEmpty ? "envelope.badge.fill" : "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(!guestEmailRegistrationReady || isRegistering || isAppleSigningIn || isGoogleSigningIn)

        case .sms:
            accountInputField(symbol: "phone.fill", placeholder: "+998 90 123 45 67", text: $loginPhone, keyboard: .phonePad, contentType: .telephoneNumber) { raw in
                let formatted = normalizedUZPhoneInput(raw)
                if formatted != raw { loginPhone = formatted }
            }
            if normalizedUZPhoneInput(loginPhone).hasPrefix("+998") {
                bookingBoundRegistrationNotice(
                    icon: "message.badge.fill",
                    title: tr("SMS registration is protected by your booking", "SMS-регистрация защищена Вашей бронью", "SMS ro‘yxatdan o‘tish broningiz bilan himoyalangan", "SMS рўйхатдан ўтиш броннингиз билан ҳимояланган"),
                    text: tr("For security, the first SMS activation is linked to a booking that issued your iumrah ID.", "Для безопасности первая SMS-активация привязывается к брони, которая выдала Ваш iumrah ID.", "Xavfsizlik uchun birinchi SMS faollashtirish iumrah ID bergan bron bilan bog‘lanadi.", "Хавфсизлик учун биринчи SMS фаоллаштириш iumrah ID берган брон билан боғланади.")
                )
            } else {
                unsupportedSMSNotice
            }
            pendingActivationButton

        case .iumrahID:
            bookingBoundRegistrationNotice(
                icon: "person.text.rectangle.fill",
                title: tr("iumrah ID is issued with your booking", "iumrah ID выдаётся вместе с бронью", "iumrah ID bron bilan beriladi", "iumrah ID брон билан берилади"),
                text: tr("Open a booking that is ready for activation. Your permanent ID will be shown there and can be activated immediately.", "Откройте бронь, готовую к активации. Там будет показан Ваш постоянный ID, который можно сразу активировать.", "Faollashtirishga tayyor bronni oching. Doimiy ID shu yerda ko‘rinadi va uni darhol faollashtirish mumkin.", "Фаоллаштиришга тайёр бронни очинг. Доимий ID шу ерда кўринади ва уни дарҳол фаоллаштириш мумкин.")
            )
            pendingActivationButton
        }
    }

    @ViewBuilder
    private var pendingActivationButton: some View {
        if let pending = pendingActivationTrip {
            NavigationLink {
                PilgrimCheckoutView(bookingID: pending.id)
            } label: {
                HStack {
                    Text(tr("Open booking activation", "Открыть активацию брони", "Bron faollashtirishini ochish", "Брон фаоллаштиришини очиш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        } else {
            Text(tr(
                "There is no booking awaiting account activation on this device yet. You can register by Email, Apple or Google now.",
                "На этом устройстве пока нет брони, ожидающей активации аккаунта. Сейчас можно зарегистрироваться по Email, Apple или Google.",
                "Bu qurilmada akkaunt faollashtirishini kutayotgan bron hali yo‘q. Hozir Email, Apple yoki Google orqali ro‘yxatdan o‘tishingiz mumkin.",
                "Бу қурилмада аккаунт фаоллаштиришини кутаётган брон ҳали йўқ. Ҳозир Email, Apple ёки Google орқали рўйхатдан ўтишингиз мумкин."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bookingBoundRegistrationNotice(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(Color.blue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.blue.opacity(0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.blue.opacity(0.16), lineWidth: 0.8) }
    }

    private var unsupportedSMSNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.bubble.fill")
                .foregroundStyle(.orange)
            Text(tr(
                "SMS is temporarily unavailable for this country. Continue by Email or use Google or Apple. SMS currently supports Uzbekistan numbers beginning with +998.",
                "SMS для этой страны временно недоступны. Продолжите по Email или используйте Google либо Apple. Сейчас SMS поддерживает номера Узбекистана, начинающиеся с +998.",
                "Bu davlat uchun SMS vaqtincha mavjud emas. Email orqali davom eting yoki Google/Apple’dan foydalaning. Hozir SMS faqat +998 bilan boshlanuvchi O‘zbekiston raqamlarini qo‘llaydi.",
                "Бу давлат учун SMS вақтинча мавжуд эмас. Email орқали давом этинг ёки Google/Apple’дан фойдаланинг. Ҳозир SMS фақат +998 билан бошланувчи Ўзбекистон рақамларини қўллайди."
            ))
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(Color.orange.opacity(0.18), lineWidth: 0.8) }
    }

    private func accountInputField(
        symbol: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        contentType: UITextContentType?,
        onChange: ((String) -> Void)? = nil
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .onChange(of: text.wrappedValue) { _, raw in onChange?(raw) }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
    }

    private func accountPasswordField(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .frame(width: 22)
            SecureField(placeholder, text: text)
                .textContentType(.password)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
    }

    private var guestLoginReady: Bool {
        guard loginPassword.count >= 8 else { return false }
        switch guestAuthMethod {
        case .iumrahID:
            return [6, 8].contains(loginID.filter(\.isNumber).count)
        case .email:
            let value = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.contains("@") && value.contains(".")
        case .sms:
            return normalizedUZPhoneInput(loginPhone).count == 13 && normalizedUZPhoneInput(loginPhone).hasPrefix("+998")
        }
    }

    private var guestEmailRegistrationReady: Bool {
        let mail = registrationEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mail.contains("@"), mail.contains("."),
              !registrationFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !registrationLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if registrationEmailChallengeID.isEmpty { return true }
        return registrationEmailCode.count == 6 && registrationPassword.count >= 8 && registrationPassword == registrationPasswordConfirm
    }

    private func activationShortcut(_ session: StoredBookingSession) -> some View {
        NavigationLink {
            PilgrimCheckoutView(bookingID: session.id)
        } label: {
            HStack(spacing: 14) {
                IumrahIconBadge(systemName: "person.badge.key.fill", role: .security, size: 46, symbolSize: 19, cornerRadius: 15)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Activate your iumrah ID", "Активировать iumrah ID", "iumrah ID ni faollashtirish", "iumrah ID ни фаоллаштириш"))
                        .font(.subheadline.weight(.bold))
                    if let id = session.displayPilgrimID {
                        Text("ID \(id) · \(tr("booking ready for details", "бронь готова к заполнению", "bron ma’lumotlarga tayyor", "брон маълумотларга тайёр"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 10)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.primary.opacity(0.055), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private var guestSettingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(
                icon: "slider.horizontal.3",
                title: tr("App settings", "Настройки приложения", "Ilova sozlamalari", "Илова созламалари"),
                subtitle: nil
            )
            .padding(.bottom, 8)

            Button {
                IumrahHaptics.soft()
                showLanguageSheet = true
            } label: {
                settingsRow(icon: "globe", title: tr("Language", "Язык", "Til", "Тил"), value: settings.language.title)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            NavigationLink {
                IumrahAppearanceView()
            } label: {
                settingsRow(
                    icon: "circle.lefthalf.filled",
                    title: tr("Appearance", "Оформление", "Ko‘rinish", "Кўриниш"),
                    value: settings.appearance.title(settings.language)
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            NavigationLink {
                AccountNotificationsView()
            } label: {
                settingsRow(icon: "bell.and.waves.left.and.right.fill", title: "iumrah Signal", value: signalHistoryValueText)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            Button {
                openSystemSettings()
            } label: {
                settingsRow(
                    icon: "bell.badge.fill",
                    title: tr("Notifications", "Уведомления", "Bildirishnomalar", "Билдиришномалар"),
                    value: notificationStatusText
                )
            }
            .buttonStyle(.plain)
        }
        .iumrahCard()
    }

    private func tripRow(_ session: StoredBookingSession) -> some View {
        HStack(spacing: 12) {
            IumrahIconBadge(
                systemName: tripIcon(session.effectiveStatus),
                role: tripRole(session.effectiveStatus),
                size: 42,
                symbolSize: 16,
                cornerRadius: 14
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                    .font(.subheadline.weight(.bold))
                Text("Бронь \(session.displayBookingNumber) · \(L10n.date(session.booking.input.startDate, settings.language))")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(L10n.status(session.effectiveStatus, settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func sectionHeader(icon: String, title: String, subtitle: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, size: 40, symbolSize: 16, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func accountField(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .words
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(keyboard == .emailAddress)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7) }
    }

    private func settingsRow(icon: String, title: String, value: String, showsChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            IumrahIconBadge(systemName: icon, size: 40, symbolSize: 16, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    private func tripRole(_ status: String) -> IumrahIconRole {
        IumrahBookingStatusVisual.role(for: status)
    }

    private func statusChip(_ status: String) -> some View {
        Text(L10n.status(status, settings.language))
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(statusColor(status).opacity(0.10), in: Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func tripDateChip(_ session: StoredBookingSession) -> some View {
        Label(L10n.date(session.booking.input.startDate, settings.language), systemImage: "calendar")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private var activeTrip: StoredBookingSession? {
        allTrips
            .filter { !["COMPLETED", "CANCELLED"].contains($0.effectiveStatus.uppercased()) }
            .sorted { tripPriority($0) < tripPriority($1) }
            .first
    }

    private var kycTrip: StoredBookingSession? {
        activeTrip ?? allTrips.first
    }

    private var allTrips: [StoredBookingSession] {
        bookings.sessions.sorted { lhs, rhs in
            let l = lhs.booking.input.startDate
            let r = rhs.booking.input.startDate
            if l == r { return lhs.booking.createdAt > rhs.booking.createdAt }
            return l > r
        }
    }

    private var pendingActivationTrip: StoredBookingSession? {
        bookings.sessions.first { $0.effectiveStatus.uppercased() == "PAYMENT_PENDING" && $0.displayPilgrimID != nil }
    }

    private func tripPriority(_ session: StoredBookingSession) -> String {
        let status = session.effectiveStatus.uppercased()
        let rank: Int
        switch status {
        case "IN_TRIP": rank = 0
        case "READY_TO_TRAVEL": rank = 1
        case "BOOKING_CONFIRMED": rank = 2
        case "PAYMENT_PENDING": rank = 3
        case "AVAILABILITY_CHECK": rank = 4
        default: rank = 9
        }
        return "\(rank)-\(session.booking.input.startDate)"
    }

    private func tripIcon(_ status: String) -> String {
        switch status.uppercased() {
        case "IN_TRIP": return "location.fill"
        case "READY_TO_TRAVEL": return "checkmark.seal.fill"
        case "BOOKING_CONFIRMED": return "checkmark.circle.fill"
        case "PAYMENT_PENDING": return "creditcard.fill"
        case "CANCELLED": return "xmark.circle.fill"
        case "COMPLETED": return "flag.checkered"
        default: return "clock.fill"
        }
    }

    private func statusColor(_ status: String) -> Color {
        IumrahBookingStatusVisual.color(for: status)
    }

    @MainActor
    private func login() async {
        isLoggingIn = true
        loginError = nil
        defer { isLoggingIn = false }
        do {
            let identifier: String
            switch guestAuthMethod {
            case .iumrahID: identifier = normalizedLoginIdentifier(loginID)
            case .email: identifier = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            case .sms: identifier = normalizedUZPhoneInput(loginPhone)
            }
            let profile = try await account.login(identifier: identifier, password: loginPassword, locale: settings.language.rawValue)
            await completeAuthenticatedLogin(profile)
            loginPassword = ""
            IumrahHaptics.success()
        } catch {
            loginError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func startGuestEmailRegistration() async {
        isRegistering = true
        loginError = nil
        defer { isRegistering = false }
        do {
            let response = try await IumrahAccountActivationBridge().startEmailRegistration(
                email: registrationEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                locale: settings.language.rawValue
            )
            registrationEmailChallengeID = response.challengeID
            registrationEmailCode = ""
            IumrahHaptics.success()
        } catch {
            loginError = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func confirmGuestEmailRegistration() async {
        guard !registrationEmailChallengeID.isEmpty else { return }
        isRegistering = true
        loginError = nil
        defer { isRegistering = false }
        do {
            let response = try await IumrahAccountActivationBridge().confirmEmailRegistration(
                challengeID: registrationEmailChallengeID,
                code: registrationEmailCode,
                password: registrationPassword,
                firstName: registrationFirstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: registrationLastName.trimmingCharacters(in: .whitespacesAndNewlines),
                locale: settings.language.rawValue
            )
            // Establish the normal app session through IumrahAccountStore so Keychain,
            // push registration and trip restore follow the same path as every login.
            let profile = try await account.login(
                identifier: response.account.iumrahID,
                password: registrationPassword,
                locale: settings.language.rawValue
            )
            await completeAuthenticatedLogin(profile)
            registrationPassword = ""
            registrationPasswordConfirm = ""
            registrationEmailCode = ""
            IumrahHaptics.success()
        } catch {
            loginError = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    private func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        do {
            appleNonce = try IumrahAppleSignInSupport.prepare(request)
            isAppleSigningIn = true
            loginError = nil
        } catch {
            loginError = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
        }
    }

    private func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task { @MainActor in
            defer { isAppleSigningIn = false }
            do {
                let authorization = try result.get()
                let credential = try IumrahAppleSignInSupport.credential(from: authorization, nonce: appleNonce)
                let profile = try await account.signInWithApple(credential, locale: settings.language.rawValue)
                await completeAuthenticatedLogin(profile)
                IumrahHaptics.success()
            } catch let error as ASAuthorizationError where error.code == .canceled {
                loginError = nil
            } catch {
                loginError = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
                IumrahHaptics.error()
            }
        }
    }

    private func startGoogleSignIn() {
        guard !isGoogleSigningIn, !isAppleSigningIn, !isLoggingIn else { return }
        isGoogleSigningIn = true
        loginError = nil
        Task { @MainActor in
            defer { isGoogleSigningIn = false }
            do {
                let credential = try await IumrahGoogleSignInSupport.signIn()
                let profile = try await account.signInWithGoogle(credential, locale: settings.language.rawValue)
                await completeAuthenticatedLogin(profile)
                IumrahHaptics.success()
            } catch where IumrahGoogleSignInSupport.isCancellation(error) {
                loginError = nil
            } catch {
                loginError = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
                IumrahHaptics.error()
            }
        }
    }

    @MainActor
    private func completeAuthenticatedLogin(_ profile: IumrahAccountProfile) async {
        bookings.setAccountToken(account.bearerToken)
        if let token = account.bearerToken {
            await bookings.restoreAccountTrips(token: token)
            await bookings.refreshAll()
        }
        applyProfileToLocalSettings(profile)
        loadProfileDraftIfNeeded(force: true, profile: profile)
        await refreshPublicIdentityLink()
    }

    @MainActor
    private func refreshPublicIdentityLink() async {
        guard account.isAuthenticated, let profile = account.account else {
            identityPublicURL = nil
            return
        }
        do {
            let link = try await account.publicIdentityLink()
            identityPublicURL = link.url
        } catch {
            // The signed link is a convenience layer. Keep the identity card usable even
            // if this endpoint is temporarily unavailable; the fallback page itself does
            // not expose private trip data without a valid signature.
            identityPublicURL = fallbackIdentityURL(profile.iumrahID)
        }
    }

    @MainActor
    private func saveProfile(dismissAfterSave: Bool = false) async {
        isSavingProfile = true
        profileMessage = nil
        defer { isSavingProfile = false }
        do {
            let profile = try await account.updateProfile(
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                telegram: telegram.trimmingCharacters(in: .whitespacesAndNewlines),
                whatsapp: whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            applyProfileToLocalSettings(profile)
            profileMessage = savedText
            IumrahHaptics.success()
            if dismissAfterSave { showProfileEditor = false }
        } catch {
            profileMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func refreshAccountContent() async {
        if let token = account.bearerToken {
            await bookings.restoreAccountTrips(token: token)
            await bookings.refreshAll()
        }

        // Revalidate the entire push chain instead of checking only the iOS permission.
        // This catches the common "notifications enabled but nothing arrives" case where
        // APNs has a token but the booking/provider registration is not ready.
        await push.refreshAndRegisterIfAllowed()
        if let deviceToken = push.deviceToken, !deviceToken.isEmpty {
            await bookings.syncPushSubscriptions(deviceToken: deviceToken, locale: settings.language.rawValue)
        }
        await clientNotifications.sync(
            deviceToken: push.deviceToken,
            accountToken: account.bearerToken,
            hasTrip: !bookings.sessions.isEmpty,
            locale: settings.language.rawValue
        )
    }

    @MainActor
    private func loadProfileDraftIfNeeded(force: Bool, profile explicit: IumrahAccountProfile? = nil) {
        guard let profile = explicit ?? account.account else { return }
        if !force, profileLoadedForID == profile.iumrahID { return }
        profileLoadedForID = profile.iumrahID
        firstName = profile.firstName
        lastName = profile.lastName
        phone = profile.phone
        email = profile.email
        telegram = profile.telegram
        whatsapp = profile.whatsapp
    }

    @MainActor
    private func applyProfileToLocalSettings(_ profile: IumrahAccountProfile) {
        settings.firstName = profile.firstName
        settings.lastName = profile.lastName
        settings.phone = profile.phone
        settings.email = profile.email
        settings.telegram = profile.telegram
        settings.whatsapp = profile.whatsapp.isEmpty ? profile.phone : profile.whatsapp
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let value = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = value.authorizationStatus
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var signalHistoryValueText: String {
        let unread = clientNotifications.unreadCount
        if unread > 0 {
            return tr(
                "\(unread) new · full history",
                "\(unread) новых · вся история",
                "\(unread) yangi · to‘liq tarix",
                "\(unread) янги · тўлиқ тарих"
            )
        }
        return tr("Open history", "Открыть историю", "Tarixni ochish", "Тарихни очиш")
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            if push.deviceToken == nil {
                return tr("Registering with APNs…", "Регистрация APNs…", "APNs ro‘yxatdan o‘tmoqda…", "APNs рўйхатдан ўтмоқда…")
            }
            if bookings.pushRegistrationError != nil || clientNotifications.lastError != nil {
                return tr("Delivery connection error", "Ошибка подключения доставки", "Yetkazish ulanishida xato", "Етказиш уланишида хато")
            }
            if bookings.pushRegistrationReady == false || clientNotifications.pushProviderReady == false {
                return tr("Push service is not ready", "Push-сервис не готов", "Push xizmati tayyor emas", "Push хизмати тайёр эмас")
            }
            return tr("Enabled · delivery connected", "Включены · доставка подключена", "Yoqilgan · yetkazish ulangan", "Ёқилган · етказиш уланган")
        case .denied:
            return tr("Disabled in iOS Settings", "Выключены в настройках iOS", "iOS sozlamalarida o‘chirilgan", "iOS созламаларида ўчирилган")
        default:
            return tr("Not configured", "Не настроены", "Sozlanmagan", "Созланмаган")
        }
    }

    private var savedText: String { tr("Saved", "Сохранено", "Saqlandi", "Сақланди") }

    private func displayName(_ profile: IumrahAccountProfile) -> String {
        let value = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { return value }
        let fallback = [profile.firstName, profile.lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return fallback.isEmpty ? tr("Pilgrim", "Паломник", "Ziyoratchi", "Зиёратчи") : fallback
    }

    private func normalizedID(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return value }
        if digits.count >= 8 { return digits }
        return String(repeating: "0", count: 8 - digits.count) + digits
    }

    private func normalizedUZPhoneInput(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(12))
        return digits.isEmpty ? "" : "+" + digits
    }

    private func normalizedLoginIdentifier(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count == 6 || digits.count == 8 else { return value }
        return normalizedID(digits)
    }

    private func fallbackIdentityURL(_ value: String) -> String {
        "https://iumrah.app/id/\(normalizedID(value))"
    }

    private func prepareIdentityRevealIfNeeded(_ rawID: String?, force: Bool = false) {
        guard let rawID, !rawID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            identityRevealProgress = 0
            return
        }

        let id = normalizedID(rawID)
        let key = "iumrah.identity-card.revealed.\(id)"
        if !force, UserDefaults.standard.bool(forKey: key) {
            identityRevealProgress = 1
            return
        }

        identityCardFlipped = false
        identityRevealProgress = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 1.45)) {
                identityRevealProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
                IumrahHaptics.success()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
                UserDefaults.standard.set(true, forKey: key)
            }
        }
    }

    @MainActor
    private func addIdentityToWallet() async {
        guard !isLoadingWalletPass else { return }
        guard PKPassLibrary.isPassLibraryAvailable() else {
            walletAlertMessage = tr(
                "Apple Wallet is not available on this device.",
                "Apple Wallet недоступен на этом устройстве.",
                "Apple Wallet bu qurilmada mavjud emas.",
                "Apple Wallet бу қурилмада мавжуд эмас."
            )
            return
        }

        isLoadingWalletPass = true
        defer { isLoadingWalletPass = false }

        do {
            let data = try await account.walletPassData()
            let pass = try PKPass(data: data)
            walletPass = pass
            showWalletPassSheet = true
            IumrahHaptics.soft()
        } catch {
            walletAlertMessage = walletErrorText(error)
            IumrahHaptics.error()
        }
    }

    private func walletErrorText(_ error: Error) -> String {
        if case APIError.server(_, let message) = error,
           message == "WALLET_PASS_NOT_CONFIGURED" {
            return tr(
                "iumrah ID for Apple Wallet is being activated on the server. Please try again later.",
                "iumrah ID для Apple Wallet ещё активируется на сервере. Попробуйте немного позже.",
                "Apple Wallet uchun iumrah ID serverda faollashtirilmoqda. Birozdan keyin qayta urinib ko‘ring.",
                "Apple Wallet учун iumrah ID серверда фаоллаштирилмоқда. Бироздан кейин қайта уриниб кўринг."
            )
        }
        return tr(
            "We could not prepare the Wallet pass right now. Please try again.",
            "Сейчас не удалось подготовить карту для Wallet. Попробуйте ещё раз.",
            "Hozir Wallet kartasini tayyorlab bo‘lmadi. Qayta urinib ko‘ring.",
            "Ҳозир Wallet картасини тайёрлаб бўлмади. Қайта уриниб кўринг."
        )
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
