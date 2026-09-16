import SwiftUI

struct IumrahLockedIdentityCard: View {
    let language: AppLanguage
    let action: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.soft()
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.black)

                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("iumrah ID")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                            Text(subtitle)
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.34))
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.40))
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text(hiddenName)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .redacted(reason: .placeholder)
                            .foregroundStyle(.white.opacity(0.22))
                        Text("••••••")
                            .font(.system(size: 33, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.24))
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text(unlockHint)
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.48))
                }
                .padding(24)
                .blur(radius: 1.2)

                IumrahIdentitySealOverlay(progress: 0, showsPrompt: true, language: language)
            }
            .frame(height: 238)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.14), radius: 24, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlockAccessibility)
    }

    private var subtitle: String {
        switch language {
        case .russian: return "ЦИФРОВАЯ ID-КАРТА ПАЛОМНИКА"
        case .english: return "DIGITAL PILGRIM IDENTITY"
        case .uzbek: return "RAQAMLI ZIYORATCHI ID"
        case .uzbekCyrillic: return "РАҚАМЛИ ЗИЁРАТЧИ ID"
        }
    }

    private var hiddenName: String {
        switch language {
        case .russian: return "Ваша цифровая карта"
        case .english: return "Your digital identity"
        case .uzbek: return "Sizning raqamli kartangiz"
        case .uzbekCyrillic: return "Сизнинг рақамли картангиз"
        }
    }

    private var unlockHint: String {
        switch language {
        case .russian: return "Откройте свою iumrah ID"
        case .english: return "Unlock your iumrah ID"
        case .uzbek: return "iumrah ID kartangizni oching"
        case .uzbekCyrillic: return "iumrah ID картангизни очинг"
        }
    }

    private var unlockAccessibility: String {
        switch language {
        case .russian: return "Закрытая iumrah ID. Нажмите, чтобы войти или зарегистрироваться."
        case .english: return "Locked iumrah ID. Tap to sign in or register."
        case .uzbek: return "Yopiq iumrah ID. Kirish yoki ro‘yxatdan o‘tish uchun bosing."
        case .uzbekCyrillic: return "Ёпиқ iumrah ID. Кириш ёки рўйхатдан ўтиш учун босинг."
        }
    }
}

struct IumrahIdentitySealOverlay: View {
    let progress: CGFloat
    let showsPrompt: Bool
    let language: AppLanguage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let clamped = min(max(progress, 0), 1)
            let travel = (width * 0.52) + 18

            ZStack {
                sealHalf(width: width, height: height, isLeading: true)
                    .offset(x: -travel * clamped)

                sealHalf(width: width, height: height, isLeading: false)
                    .offset(x: travel * clamped)

                if showsPrompt {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.58))
                                .frame(width: 58, height: 58)
                                .overlay {
                                    Circle().strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                                }
                            Image(systemName: "lock.fill")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        Text(promptTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(promptBody)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 24)
                    .opacity(1 - clamped)
                } else {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.52))
                            .frame(width: 48, height: 48)
                            .overlay {
                                Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
                            }
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(1 - (clamped * 0.20))
                    .opacity(1 - clamped)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .opacity(clamped >= 0.999 ? 0 : 1)
        }
        .allowsHitTesting(progress < 0.995)
    }

    @ViewBuilder
    private func sealHalf(width: CGFloat, height: CGFloat, isLeading: Bool) -> some View {
        let halfWidth = (width / 2) + 1

        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.035, green: 0.038, blue: 0.048),
                            Color.black,
                            Color(red: 0.060, green: 0.064, blue: 0.078),
                        ],
                        startPoint: isLeading ? .topLeading : .topTrailing,
                        endPoint: isLeading ? .bottomTrailing : .bottomLeading
                    )
                )

            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { context in
                let seconds = context.date.timeIntervalSinceReferenceDate
                let phase = CGFloat(seconds.truncatingRemainder(dividingBy: 3.2) / 3.2)
                let shimmerX = (-halfWidth * 0.8) + (phase * halfWidth * 2.2)

                LinearGradient(
                    colors: [.clear, .white.opacity(0.02), .white.opacity(0.17), .white.opacity(0.025), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: max(54, halfWidth * 0.22), height: height * 1.55)
                .rotationEffect(.degrees(-14))
                .offset(x: shimmerX)
                .blendMode(.screen)
            }

            Canvas { context, size in
                for index in 0..<22 {
                    let seed = CGFloat((index * 37) % 101) / 101
                    let seed2 = CGFloat((index * 67 + 11) % 103) / 103
                    let x = seed * size.width
                    let y = seed2 * size.height
                    let radius = CGFloat((index % 3) + 1) * 0.65
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(.white.opacity(0.08 + Double(index % 4) * 0.025))
                    )
                }
            }
        }
        .frame(width: halfWidth, height: height)
        .frame(maxWidth: .infinity, alignment: isLeading ? .leading : .trailing)
        .overlay(alignment: isLeading ? .trailing : .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(width: 0.6)
        }
    }

    private var promptTitle: String {
        switch language {
        case .russian: return "Ваша iumrah ID закрыта"
        case .english: return "Your iumrah ID is sealed"
        case .uzbek: return "iumrah ID kartangiz yopiq"
        case .uzbekCyrillic: return "iumrah ID картангиз ёпиқ"
        }
    }

    private var promptBody: String {
        switch language {
        case .russian: return "Войдите или зарегистрируйтесь, чтобы открыть карту"
        case .english: return "Sign in or register to reveal your card"
        case .uzbek: return "Kartani ochish uchun kiring yoki ro‘yxatdan o‘ting"
        case .uzbekCyrillic: return "Картани очиш учун киринг ёки рўйхатдан ўтинг"
        }
    }
}

struct IumrahIdentityUnlockSheet: View {
    let language: AppLanguage
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer(minLength: 10)

                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black)
                        .frame(width: 106, height: 82)
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.16), radius: 20, y: 10)

                VStack(spacing: 9) {
                    Text(title)
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .tracking(-0.55)
                        .multilineTextAlignment(.center)

                    Text(bodyText)
                        .font(.system(size: 15.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    benefit(icon: "qrcode", text: benefitID)
                    benefit(icon: "wallet.pass.fill", text: benefitWallet)
                    benefit(icon: "suitcase.fill", text: benefitTrips)
                }
                .frame(maxWidth: .infinity)

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        onContinue()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text(primaryCTA)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func benefit(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(text)
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
        }
    }

    private var title: String {
        switch language {
        case .russian: return "Откройте свою iumrah ID"
        case .english: return "Unlock your iumrah ID"
        case .uzbek: return "iumrah ID kartangizni oching"
        case .uzbekCyrillic: return "iumrah ID картангизни очинг"
        }
    }

    private var bodyText: String {
        switch language {
        case .russian: return "Чтобы активировать виртуальную ID-карту Iumrah, войдите в существующий аккаунт или зарегистрируйтесь через Apple или Google."
        case .english: return "To activate your virtual iumrah ID, sign in to your account or create one with Apple or Google."
        case .uzbek: return "Virtual iumrah ID kartangizni faollashtirish uchun akkauntingizga kiring yoki Apple yoxud Google orqali ro‘yxatdan o‘ting."
        case .uzbekCyrillic: return "Виртуал iumrah ID картангизни фаоллаштириш учун аккаунтингизга киринг ёки Apple ёхуд Google орқали рўйхатдан ўтинг."
        }
    }

    private var benefitID: String {
        switch language {
        case .russian: return "Постоянный шестизначный iumrah ID"
        case .english: return "Permanent six-digit iumrah ID"
        case .uzbek: return "Doimiy olti xonali iumrah ID"
        case .uzbekCyrillic: return "Доимий олти хонали iumrah ID"
        }
    }

    private var benefitWallet: String {
        switch language {
        case .russian: return "Добавление цифровой карты в Apple Wallet"
        case .english: return "Add your digital card to Apple Wallet"
        case .uzbek: return "Raqamli kartani Apple Wallet’ga qo‘shish"
        case .uzbekCyrillic: return "Рақамли картани Apple Wallet’га қўшиш"
        }
    }

    private var benefitTrips: String {
        switch language {
        case .russian: return "Все Ваши поездки привязаны к одной ID"
        case .english: return "All your trips stay linked to one ID"
        case .uzbek: return "Barcha safarlaringiz bitta ID bilan bog‘lanadi"
        case .uzbekCyrillic: return "Барча сафарларингиз битта ID билан боғланади"
        }
    }

    private var primaryCTA: String {
        switch language {
        case .russian: return "Войти или зарегистрироваться"
        case .english: return "Sign in or register"
        case .uzbek: return "Kirish yoki ro‘yxatdan o‘tish"
        case .uzbekCyrillic: return "Кириш ёки рўйхатдан ўтиш"
        }
    }
}
