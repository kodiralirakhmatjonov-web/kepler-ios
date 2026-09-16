import AuthenticationServices
import Foundation
import SwiftUI

struct IumrahAccountSecurityView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var overview: IumrahSecurityOverview?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingPrimarySheet = false
    @State private var primaryPassword = ""
    @State private var isClaimingPrimary = false
    @State private var pendingTermination: IumrahSecuritySession?
    @State private var workingSessionID: String?
    @State private var pendingTerminateOthers = false
    @State private var isTerminatingOthers = false
    @State private var appleNonce = ""
    @State private var isLinkingApple = false
    @State private var isLinkingGoogle = false
    @State private var showingEmailSheet = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                securityHero
                securityPrincipleNote

                if let overview {
                    primaryDeviceCard(overview)
                    emailCard(overview)
                    appleCard(overview)
                    googleCard(overview)
                    sessionsCard(overview)
                } else if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 70)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                privacyNote
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(tr("Security", "Безопасность", "Xavfsizlik", "Хавфсизлик"))
        .navigationBarTitleDisplayMode(.inline)
        .iumrahInternalNavigation()
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showingPrimarySheet) { primaryDeviceSheet }
        .sheet(isPresented: $showingEmailSheet, onDismiss: { Task { await load() } }) {
            IumrahEmailVerificationView(existingEmail: overview?.loginEmail?.email)
                .environmentObject(account)
                .environmentObject(settings)
        }
        .confirmationDialog(
            tr("End this session?", "Завершить этот сеанс?", "Seans tugatilsinmi?", "Сеанс тугатилсинми?"),
            isPresented: Binding(
                get: { pendingTermination != nil },
                set: { if !$0 { pendingTermination = nil } }
            ),
            presenting: pendingTermination
        ) { session in
            Button(
                session.isCurrent
                    ? tr("Sign out this device", "Выйти на этом устройстве", "Bu qurilmadan chiqish", "Бу қурилмадан чиқиш")
                    : tr("End session", "Завершить сеанс", "Seansni tugatish", "Сеансни тугатиш"),
                role: .destructive
            ) {
                Task { await terminate(session) }
            }
            Button(tr("Cancel", "Отмена", "Bekor qilish", "Бекор қилиш"), role: .cancel) {}
        } message: { session in
            Text(session.isCurrent
                 ? tr("You will need to sign in again.", "Для продолжения потребуется войти снова.", "Qayta kirish kerak bo‘ladi.", "Қайта кириш керак бўлади.")
                 : tr("This device will immediately lose access to your account.", "Это устройство сразу потеряет доступ к Вашему аккаунту.", "Bu qurilma akkauntga kirish huquqini darhol yo‘qotadi.", "Бу қурилма аккаунтга кириш ҳуқуқини дарҳол йўқотади."))
        }
        .confirmationDialog(
            tr("End all other sessions?", "Завершить все другие сеансы?", "Boshqa barcha seanslar tugatilsinmi?", "Бошқа барча сеанслар тугатилсинми?"),
            isPresented: $pendingTerminateOthers
        ) {
            Button(
                tr("End all", "Завершить все", "Barchasini tugatish", "Барчасини тугатиш"),
                role: .destructive
            ) {
                Task { await terminateOtherSessions() }
            }
            Button(tr("Cancel", "Отмена", "Bekor qilish", "Бекор қилиш"), role: .cancel) {}
        } message: {
            Text(tr(
                "All other devices will lose access. This device will stay signed in.",
                "Все остальные устройства потеряют доступ. Это устройство останется в аккаунте.",
                "Boshqa barcha qurilmalar kirish huquqini yo‘qotadi. Bu qurilma akkauntda qoladi.",
                "Бошқа барча қурилмалар кириш ҳуқуқини йўқотади. Бу қурилма аккаунтда қолади."
            ))
        }
    }

    private var securityHero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)

            // Standalone reusable renderer. The sphere owns only pixels and
            // motion; Security owns all copy, identity and composition.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                IumrahDataSphere(state: .idle, intensity: 1.00)
                    .frame(width: 292, height: 292)
                    .offset(x: 18, y: -24)
            }

            // A restrained left-side readability veil keeps the product copy
            // separate from the moving data field without muting the sphere.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.98), location: 0.00),
                    .init(color: .black.opacity(0.90), location: 0.36),
                    .init(color: .black.opacity(0.38), location: 0.63),
                    .init(color: .clear, location: 0.86)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 205)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.iumrahCareLight)
                        .shadow(color: Color.iumrahCareLight.opacity(0.18), radius: 8)

                    if let overview {
                        Text("ID \(overview.iumrahID)")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }

                Spacer(minLength: 30)

                Text("Iumrah Security")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(-0.5)
                    .frame(maxWidth: 148, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .frame(height: 246)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.16), radius: 24, y: 12)
    }

    private var securityPrincipleNote: some View {
        Text(tr(
            "A new session can end only itself. Only your protected primary device can end other sessions.",
            "Новый сеанс может завершить только себя. Остальные сеансы может завершать только Ваше защищённое основное устройство.",
            "Yangi seans faqat o‘zini tugata oladi. Boshqa seanslarni faqat himoyalangan asosiy qurilmangiz tugata oladi.",
            "Янги сеанс фақат ўзини тугата олади. Бошқа сеансларни фақат ҳимояланган асосий қурилмангиз тугата олади."
        ))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func primaryDeviceCard(_ value: IumrahSecurityOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                icon: value.primaryDeviceProtected ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                title: tr("Primary device", "Основное устройство", "Asosiy qurilma", "Асосий қурилма"),
                tint: value.primaryDeviceProtected ? Color.iumrahCareLight : .orange
            )

            if value.currentDeviceIsPrimary {
                statusRow(
                    icon: "iphone.gen3",
                    title: tr("This is your primary device", "Это Ваше основное устройство", "Bu asosiy qurilmangiz", "Бу асосий қурилмангиз"),
                    detail: tr("It can securely manage the other sessions.", "Оно может безопасно управлять остальными сеансами.", "U boshqa seanslarni xavfsiz boshqara oladi.", "У бошқа сеансларни хавфсиз бошқара олади."),
                    tint: Color.iumrahCareLight
                )
            } else if value.primaryDeviceProtected {
                statusRow(
                    icon: "lock.fill",
                    title: tr("Secondary session", "Дополнительный сеанс", "Qo‘shimcha seans", "Қўшимча сеанс"),
                    detail: tr("This device can end only its own session.", "Это устройство может завершить только свой сеанс.", "Bu qurilma faqat o‘z seansini tugata oladi.", "Бу қурилма фақат ўз сеансини тугата олади."),
                    tint: .secondary
                )
            } else {
                Text(tr(
                    "Confirm your current password once to make this iPhone the protected primary device.",
                    "Один раз подтвердите текущий пароль, чтобы сделать этот iPhone защищённым основным устройством.",
                    "Ushbu iPhone’ni himoyalangan asosiy qurilma qilish uchun joriy parolni bir marta tasdiqlang.",
                    "Ушбу iPhone’ни ҳимояланган асосий қурилма қилиш учун жорий паролни бир марта тасдиқланг."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    primaryPassword = ""
                    errorMessage = nil
                    showingPrimarySheet = true
                } label: {
                    Label(tr("Protect this iPhone", "Защитить этот iPhone", "Bu iPhone’ni himoyalash", "Бу iPhone’ни ҳимоялаш"), systemImage: "lock.shield.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
        }
        .iumrahCard()
    }

    private func appleCard(_ value: IumrahSecurityOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "apple.logo", title: "Sign in with Apple", tint: .primary)

            if value.apple.linked {
                statusRow(
                    icon: "checkmark.circle.fill",
                    title: tr("Apple is connected", "Apple подключён", "Apple ulangan", "Apple уланган"),
                    detail: tr(
                        "Apple signs in to this same iumrah ID — no second account is created.",
                        "Apple выполняет вход в этот же iumrah ID — второй аккаунт не создаётся.",
                        "Apple aynan shu iumrah ID’ga kiradi — ikkinchi akkaunt yaratilmaydi.",
                        "Apple айнан шу iumrah ID’га киради — иккинчи аккаунт яратилмайди."
                    ),
                    tint: Color.iumrahCareLight
                )
            } else {
                Text(tr(
                    "Connect Apple to ID \(value.iumrahID). After that you can sign in without typing the eight-digit ID or password.",
                    "Подключите Apple к ID \(value.iumrahID). После этого можно входить без ввода восьмизначного ID и пароля.",
                    "Apple’ni \(value.iumrahID) ID’ga ulang. Shundan keyin sakkiz xonali ID va parolsiz kirishingiz mumkin.",
                    "Apple’ни \(value.iumrahID) ID’га уланг. Шундан кейин саккиз хонали ID ва паролсиз киришингиз мумкин."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SignInWithAppleButton(.continue) { request in
                    prepareApple(request)
                } onCompletion: { result in
                    completeApple(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: IumrahDesign.controlHeight)
                .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
                .disabled(!value.currentDeviceIsPrimary || isLinkingApple || isLinkingGoogle)
                .opacity(value.currentDeviceIsPrimary ? 1 : 0.48)

                if !value.currentDeviceIsPrimary {
                    Label(
                        tr("Only the primary device can connect a new sign-in method.", "Новый способ входа может подключить только основное устройство.", "Yangi kirish usulini faqat asosiy qurilma ulashi mumkin.", "Янги кириш усулини фақат асосий қурилма улаши мумкин."),
                        systemImage: "lock.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .iumrahCard()
    }

    private func googleCard(_ value: IumrahSecurityOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "person.crop.circle.badge.checkmark", title: "Sign in with Google", tint: .blue)

            if value.google?.linked == true {
                statusRow(
                    icon: "checkmark.circle.fill",
                    title: tr("Google is connected", "Google подключён", "Google ulangan", "Google уланган"),
                    detail: tr(
                        "Google signs in to this same iumrah ID — no second account is created.",
                        "Google выполняет вход в этот же iumrah ID — второй аккаунт не создаётся.",
                        "Google aynan shu iumrah ID’ga kiradi — ikkinchi akkaunt yaratilmaydi.",
                        "Google айнан шу iumrah ID’га киради — иккинчи аккаунт яратилмайди."
                    ),
                    tint: Color.iumrahCareLight
                )
            } else {
                Text(tr(
                    "Connect Google to ID \(value.iumrahID). After that you can sign in without typing the eight-digit ID or password.",
                    "Подключите Google к ID \(value.iumrahID). После этого можно входить без ввода восьмизначного ID и пароля.",
                    "Google’ni \(value.iumrahID) ID’ga ulang. Shundan keyin sakkiz xonali ID va parolsiz kirishingiz mumkin.",
                    "Google’ни \(value.iumrahID) ID’га уланг. Шундан кейин саккиз хонали ID ва паролсиз киришингиз мумкин."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                IumrahGoogleAuthButton(
                    title: "Continue with Google",
                    isDisabled: !value.currentDeviceIsPrimary || isLinkingGoogle || isLinkingApple
                ) {
                    connectGoogle()
                }

                if !value.currentDeviceIsPrimary {
                    Label(
                        tr("Only the primary device can connect a new sign-in method.", "Новый способ входа может подключить только основное устройство.", "Yangi kirish usulini faqat asosiy qurilma ulashi mumkin.", "Янги кириш усулини фақат асосий қурилма улаши мумкин."),
                        systemImage: "lock.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .iumrahCard()
    }

    private func emailCard(_ value: IumrahSecurityOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "envelope.badge.shield.half.filled", title: tr("Email sign-in", "Вход по почте", "Email orqali kirish", "Email орқали кириш"), tint: .blue)

            if let loginEmail = value.loginEmail {
                statusRow(
                    icon: "checkmark.circle.fill",
                    title: loginEmail.email,
                    detail: tr(
                        "Verified for sign-in and password recovery.",
                        "Подтверждена для входа и восстановления пароля.",
                        "Kirish va parolni tiklash uchun tasdiqlangan.",
                        "Кириш ва паролни тиклаш учун тасдиқланган."
                    ),
                    tint: Color.iumrahCareLight
                )
            } else {
                Text(tr(
                    "Add and verify an email to sign in without remembering your iumrah ID and to recover your password.",
                    "Добавьте и подтвердите почту, чтобы входить без запоминания iumrah ID и восстанавливать пароль.",
                    "iumrah ID ni eslamasdan kirish va parolni tiklash uchun email qo‘shing va tasdiqlang.",
                    "iumrah ID ни эсламасдан кириш ва паролни тиклаш учун email қўшинг ва тасдиқланг."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                showingEmailSheet = true
            } label: {
                Label(
                    value.loginEmail == nil
                        ? tr("Add email", "Добавить почту", "Email qo‘shish", "Email қўшиш")
                        : tr("Change email", "Изменить почту", "Emailni o‘zgartirish", "Emailни ўзгартириш"),
                    systemImage: "envelope.arrow.triangle.branch"
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
            .disabled(!value.currentDeviceIsPrimary)
            .opacity(value.currentDeviceIsPrimary ? 1 : 0.48)

            if !value.currentDeviceIsPrimary {
                Label(
                    tr("Only the primary device can change the sign-in email.", "Почту для входа может изменить только основное устройство.", "Kirish emailini faqat asosiy qurilma o‘zgartira oladi.", "Кириш emailини фақат асосий қурилма ўзгартира олади."),
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .iumrahCard()
    }

    private func sessionsCard(_ value: IumrahSecurityOverview) -> some View {
        let current = value.sessions.first(where: \.isCurrent)
        let others = value.sessions.filter { !$0.isCurrent }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                sectionTitle(
                    icon: "rectangle.stack.badge.person.crop.fill",
                    title: tr("Devices and sessions", "Устройства и сеансы", "Qurilmalar va seanslar", "Қурилмалар ва сеанслар"),
                    tint: .blue
                )
                Spacer(minLength: 8)
                Text("\(value.sessions.count)")
                    .font(.caption.monospaced().weight(.bold))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .iumrahGlass(in: Capsule())
            }

            if let current {
                sessionGroupLabel(tr("THIS DEVICE", "ЭТО УСТРОЙСТВО", "BU QURILMA", "БУ ҚУРИЛМА"))
                sessionCard(current)
            }

            if !others.isEmpty {
                sessionGroupLabel(tr("ACTIVE SESSIONS", "АКТИВНЫЕ СЕАНСЫ", "FAOL SEANSLAR", "ФАОЛ СЕАНСЛАР"))
                VStack(spacing: 12) {
                    ForEach(others) { session in
                        sessionCard(session)
                    }
                }

                if value.currentDeviceIsPrimary {
                    Button(role: .destructive) {
                        IumrahHaptics.soft()
                        pendingTerminateOthers = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "hand.raised.fill")
                            Text(tr(
                                "End all other sessions",
                                "Завершить все другие сеансы",
                                "Boshqa barcha seanslarni tugatish",
                                "Бошқа барча сеансларни тугатиш"
                            ))
                            .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                            if isTerminatingOthers {
                                ProgressView().controlSize(.small)
                            }
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                    .buttonStyle(.plain)
                    .iumrahGlass(in: Capsule(), interactive: true)
                    .disabled(workingSessionID != nil || isTerminatingOthers)
                }
            }
        }
    }

    private func sessionGroupLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.top, 2)
    }

    private func sessionCard(_ session: IumrahSecuritySession) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 14) {
                sessionDeviceIcon(session)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(sessionDisplayName(session))
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        if session.isCurrent {
                            badge(
                                tr("THIS DEVICE", "ЭТО УСТРОЙСТВО", "BU QURILMA", "БУ ҚУРИЛМА"),
                                color: .blue
                            )
                        }
                    }

                    let software = sessionSoftwareLine(session)
                    if !software.isEmpty {
                        Text(software)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(sessionLocationAndActivity(session))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if session.isPrimary {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.orange)
                        .accessibilityLabel(tr("Primary device", "Основное устройство", "Asosiy qurilma", "Асосий қурилма"))
                }
            }

            Divider().opacity(0.65)

            if session.canTerminate {
                Button(role: .destructive) {
                    IumrahHaptics.soft()
                    pendingTermination = session
                } label: {
                    HStack {
                        Label(
                            session.isCurrent
                                ? tr("End this session", "Завершить этот сеанс", "Bu seansni tugatish", "Бу сеансни тугатиш")
                                : tr("End session", "Завершить сеанс", "Seansni tugatish", "Сеансни тугатиш"),
                            systemImage: "hand.raised"
                        )
                        .font(.subheadline.weight(.semibold))
                        Spacer()
                        if workingSessionID == session.id {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(workingSessionID != nil || isTerminatingOthers)
            } else {
                Label(
                    tr(
                        "Managed by the primary device",
                        "Управляется основным устройством",
                        "Asosiy qurilma orqali boshqariladi",
                        "Асосий қурилма орқали бошқарилади"
                    ),
                    systemImage: "lock.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .iumrahCard()
    }

    @ViewBuilder
    private func sessionDeviceIcon(_ session: IumrahSecuritySession) -> some View {
        let platform = session.platform.lowercased()
        let isAndroid = platform.contains("android")
        let tint: Color = isAndroid ? .green : .blue
        let icon = isAndroid ? "apps.iphone" : (platform.contains("ios") ? "iphone.gen3" : "desktopcomputer")

        IumrahIconBadge(
            systemName: icon,
            role: .device,
            tint: tint,
            size: 48,
            symbolSize: 21,
            cornerRadius: 14
        )
    }

    private var privacyNote: some View {
        Label(
            tr(
                "Email, Apple, Google and your eight-digit iumrah ID are secure keys to one account — never separate profiles.",
                "Почта, Apple, Google и восьмизначный iumrah ID являются защищёнными ключами к одному аккаунту, а не отдельными профилями.",
                "Email, Apple, Google va sakkiz xonali iumrah ID bitta akkauntning xavfsiz kalitlaridir — alohida profillar emas.",
                "Email, Apple, Google ва саккиз хонали iumrah ID битта аккаунтнинг хавфсиз калитларидир — алоҳида профиллар эмас."
            ),
            systemImage: "hand.raised.fill"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 4)
    }

    private var primaryDeviceSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.iumrahCareLight)
                Text(tr("Protect this iPhone", "Защитить этот iPhone", "Bu iPhone’ni himoyalash", "Бу iPhone’ни ҳимоялаш"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(tr(
                    "Enter the password for ID \(overview?.iumrahID ?? ""). It is checked only on the server and is not saved on this screen.",
                    "Введите пароль от ID \(overview?.iumrahID ?? ""). Он проверяется только на сервере и не сохраняется на этом экране.",
                    "\(overview?.iumrahID ?? "") ID parolini kiriting. U faqat serverda tekshiriladi va bu ekranda saqlanmaydi.",
                    "\(overview?.iumrahID ?? "") ID паролини киритинг. У фақат серверда текширилади ва бу экранда сақланмайди."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SecureField(tr("Current password", "Текущий пароль", "Joriy parol", "Жорий парол"), text: $primaryPassword)
                    .textContentType(.password)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await claimPrimary() }
                } label: {
                    HStack {
                        if isClaimingPrimary { ProgressView().tint(.white) }
                        Label(tr("Confirm and protect", "Подтвердить и защитить", "Tasdiqlash va himoyalash", "Тасдиқлаш ва ҳимоялаш"), systemImage: "checkmark.shield.fill")
                        Spacer()
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(primaryPassword.count < 8 || isClaimingPrimary)

                Spacer()
            }
            .padding(IumrahDesign.pagePadding)
            .background(Color.iumrahPageBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close", "Закрыть", "Yopish", "Ёпиш")) { showingPrimarySheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sectionTitle(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            IumrahIconBadge(
                systemName: icon,
                tint: tint,
                size: 38,
                symbolSize: 15,
                cornerRadius: 12
            )
            Text(title).font(.headline)
        }
    }

    private func statusRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(
                systemName: icon,
                tint: tint,
                size: 42,
                symbolSize: 17,
                cornerRadius: 13
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(color.opacity(0.10), in: Capsule())
    }

    @MainActor
    private func load() async {
        isLoading = overview == nil
        defer { isLoading = false }
        do {
            overview = try await account.securityOverview(locale: settings.language.rawValue)
            errorMessage = nil
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
        }
    }

    @MainActor
    private func claimPrimary() async {
        isClaimingPrimary = true
        defer { isClaimingPrimary = false }
        do {
            overview = try await account.claimPrimaryDevice(password: primaryPassword)
            primaryPassword = ""
            showingPrimarySheet = false
            errorMessage = nil
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func terminate(_ session: IumrahSecuritySession) async {
        workingSessionID = session.id
        pendingTermination = nil
        defer { workingSessionID = nil }
        do {
            let signedOut = try await account.terminateSecuritySession(id: session.id)
            IumrahHaptics.success()
            if signedOut {
                dismiss()
            } else {
                await load()
            }
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func terminateOtherSessions() async {
        guard let overview else { return }
        let targets = overview.sessions.filter { !$0.isCurrent && $0.canTerminate }
        guard !targets.isEmpty else { return }

        isTerminatingOthers = true
        pendingTerminateOthers = false
        defer { isTerminatingOthers = false }

        do {
            for session in targets {
                _ = try await account.terminateSecuritySession(id: session.id)
            }
            await load()
            IumrahHaptics.success()
        } catch {
            await load()
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    private func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        do {
            appleNonce = try IumrahAppleSignInSupport.prepare(request)
            isLinkingApple = true
            errorMessage = nil
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
        }
    }

    private func completeApple(_ result: Result<ASAuthorization, Error>) {
        Task { @MainActor in
            defer { isLinkingApple = false }
            do {
                let authorization = try result.get()
                let credential = try IumrahAppleSignInSupport.credential(from: authorization, nonce: appleNonce)
                _ = try await account.linkApple(credential)
                await load()
                IumrahHaptics.success()
            } catch let error as ASAuthorizationError where error.code == .canceled {
                errorMessage = nil
            } catch {
                errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
                IumrahHaptics.error()
            }
        }
    }

    private func connectGoogle() {
        guard let overview, overview.currentDeviceIsPrimary, !isLinkingGoogle, !isLinkingApple else { return }
        isLinkingGoogle = true
        errorMessage = nil
        Task { @MainActor in
            defer { isLinkingGoogle = false }
            do {
                let credential = try await IumrahGoogleSignInSupport.signIn()
                _ = try await account.linkGoogle(credential)
                await load()
                IumrahHaptics.success()
            } catch where IumrahGoogleSignInSupport.isCancellation(error) {
                errorMessage = nil
            } catch {
                errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
                IumrahHaptics.error()
            }
        }
    }

    private func sessionDisplayName(_ session: IumrahSecuritySession) -> String {
        let name = session.deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = session.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let genericNames = ["", "iPhone", "iPad", "Unknown device", "Apple device"]

        if !genericNames.contains(name) { return name }

        if model.hasPrefix("iPhone") {
            let resolved = IumrahAccountDeviceIdentity.friendlyModelName(for: model)
            if resolved != "iPhone" { return resolved }
        }
        if model.hasPrefix("iPad") {
            return name == "Unknown device"
                ? tr("iPad", "iPad", "iPad", "iPad")
                : name
        }

        let platform = session.platform.lowercased()
        if platform.contains("android") {
            if !model.isEmpty, model.lowercased() != "android" { return model }
            return "Android"
        }

        if !name.isEmpty, name != "Unknown device" { return name }
        if !model.isEmpty { return model }
        return tr("Unknown device", "Неизвестное устройство", "Noma’lum qurilma", "Номаълум қурилма")
    }

    private func sessionSoftwareLine(_ session: IumrahSecuritySession) -> String {
        let platform = session.platform.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = platform.lowercased()
        let osName: String
        if lower.contains("ios") {
            osName = "iOS"
        } else if lower.contains("android") {
            osName = "Android"
        } else {
            osName = platform
        }

        let os = [osName, session.osVersion]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")

        let version = normalizedAppVersion(session.appVersion)
        let app = version.isEmpty ? "" : "iumrah \(version)"
        return [os, app].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func normalizedAppVersion(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }
        if let range = value.range(of: " (") {
            return String(value[..<range.lowerBound])
        }
        return value
    }

    private func sessionLocationAndActivity(_ session: IumrahSecuritySession) -> String {
        let country = localizedCountry(session.country)
        let location = [session.city, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        let activity = session.isCurrent
            ? tr("online", "в сети", "onlayn", "онлайн")
            : relativeDate(session.lastActiveAt)
        return [location, activity].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func localizedCountry(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count == 2 else { return value }
        let code = value.uppercased()
        let locale: Locale
        switch settings.language {
        case .russian: locale = Locale(identifier: "ru_RU")
        case .english: locale = Locale(identifier: "en_US")
        case .uzbek: locale = Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: locale = Locale(identifier: "uz_Cyrl_UZ")
        }
        return locale.localizedString(forRegionCode: code) ?? value
    }

    private func relativeDate(_ raw: String) -> String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let regular = ISO8601DateFormatter()
        regular.formatOptions = [.withInternetDateTime]
        guard let date = fractional.date(from: raw) ?? regular.date(from: raw) else { return raw }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        switch settings.language {
        case .russian: relative.locale = Locale(identifier: "ru_RU")
        case .english: relative.locale = Locale(identifier: "en_US")
        case .uzbek: relative.locale = Locale(identifier: "uz-Latn")
        case .uzbekCyrillic: relative.locale = Locale(identifier: "uz-Cyrl")
        }
        return relative.localizedString(for: date, relativeTo: Date())
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

enum IumrahAccountSecurityCopy {
    static func message(for error: Error, language: AppSettingsStore.Language) -> String {
        let code: String
        if let apiError = error as? APIError {
            guard case .server(_, let value) = apiError else {
                return L10n.error(error, language)
            }
            code = value
        } else if let localized = error as? LocalizedError,
                  let description = localized.errorDescription,
                  !description.isEmpty {
            return description
        } else {
            return L10n.error(error, language)
        }

        let en: String
        let ru: String
        let uz: String
        let cyrl: String
        switch code {
        case "APPLE_ACCOUNT_EMAIL_REQUIRED":
            en = "Apple did not provide a verified email. Try Apple again or sign in with email or iumrah ID."
            ru = "Apple не предоставил подтверждённую почту. Повторите вход через Apple или войдите по почте либо iumrah ID."
            uz = "Apple tasdiqlangan email bermadi. Apple orqali qayta urinib ko‘ring yoki email yoxud iumrah ID bilan kiring."
            cyrl = "Apple тасдиқланган email бермади. Apple орқали қайта уриниб кўринг ёки email ёхуд iumrah ID билан киринг."
        case "PRIMARY_DEVICE_REQUIRED":
            en = "Only the protected primary device can do this."
            ru = "Это действие доступно только на защищённом основном устройстве."
            uz = "Bu amal faqat himoyalangan asosiy qurilmada mavjud."
            cyrl = "Бу амал фақат ҳимояланган асосий қурилмада мавжуд."
        case "PRIMARY_DEVICE_ALREADY_PROTECTED":
            en = "Another primary device is already protecting this account."
            ru = "Этот аккаунт уже защищён другим основным устройством."
            uz = "Bu akkaunt boshqa asosiy qurilma bilan himoyalangan."
            cyrl = "Бу аккаунт бошқа асосий қурилма билан ҳимояланган."
        case "INVALID_CREDENTIALS":
            en = "The email, iumrah ID or password is incorrect."
            ru = "Неверная почта, iumrah ID или пароль."
            uz = "Email, iumrah ID yoki parol noto‘g‘ri."
            cyrl = "Email, iumrah ID ёки парол нотўғри."
        case "ACCOUNT_ALREADY_ACTIVE":
            en = "This iumrah ID is already activated. Sign in or use password recovery."
            ru = "Этот iumrah ID уже активирован. Войдите в аккаунт или восстановите пароль."
            uz = "Bu iumrah ID allaqachon faollashtirilgan. Akkauntga kiring yoki parolni tiklang."
            cyrl = "Бу iumrah ID аллақачон фаоллаштирилган. Аккаунтга киринг ёки паролни тикланг."
        case "BOOKING_PROOF_INVALID":
            en = "This booking could not be securely verified. Reopen it from Bookings and try again."
            ru = "Не удалось безопасно подтвердить эту бронь. Откройте её заново из раздела «Бронирование» и повторите."
            uz = "Bu bronni xavfsiz tasdiqlab bo‘lmadi. Uni Bronlar bo‘limidan qayta ochib, yana urinib ko‘ring."
            cyrl = "Бу бронни хавфсиз тасдиқлаб бўлмади. Уни Бронлар бўлимидан қайта очиб, яна уриниб кўринг."
        case "BOOKING_ACCOUNT_NOT_READY":
            en = "Your iumrah ID is still being prepared. Refresh the booking in a moment and try again."
            ru = "Ваш iumrah ID ещё подготавливается. Обновите бронь через несколько секунд и повторите."
            uz = "iumrah ID hali tayyorlanmoqda. Bir necha soniyadan keyin bronni yangilab, qayta urinib ko‘ring."
            cyrl = "iumrah ID ҳали тайёрланмоқда. Бир неча сониядан кейин бронни янгилаб, қайта уриниб кўринг."
        case "ACCOUNT_TEMPORARILY_LOCKED":
            en = "Too many attempts. Try again in 15 minutes."
            ru = "Слишком много попыток. Повторите через 15 минут."
            uz = "Urinishlar ko‘p. 15 daqiqadan keyin qayta urinib ko‘ring."
            cyrl = "Уринишлар кўп. 15 дақиқадан кейин қайта уриниб кўринг."
        case "APPLE_ID_CONNECTED_TO_ANOTHER_ACCOUNT":
            en = "This Apple ID is already connected to another iumrah ID."
            ru = "Этот Apple ID уже подключён к другому iumrah ID."
            uz = "Bu Apple ID boshqa iumrah ID’ga ulangan."
            cyrl = "Бу Apple ID бошқа iumrah ID’га уланган."
        case "APPLE_ID_ALREADY_CONNECTED":
            en = "A different Apple ID is already connected to this account."
            ru = "К этому аккаунту уже подключён другой Apple ID."
            uz = "Bu akkauntga boshqa Apple ID ulangan."
            cyrl = "Бу аккаунтга бошқа Apple ID уланган."
        case "APPLE_EMAIL_CONNECTED_TO_ANOTHER_ACCOUNT":
            en = "The email verified by Apple already belongs to another iumrah account."
            ru = "Подтверждённая Apple почта уже принадлежит другому аккаунту iumrah."
            uz = "Apple tasdiqlagan email boshqa iumrah akkauntiga tegishli."
            cyrl = "Apple тасдиқлаган email бошқа iumrah аккаунтига тегишли."
        case "APPLE_TOKEN_INVALID", "APPLE_TOKEN_REPLAYED":
            en = "Apple authorization expired. Please try again."
            ru = "Подтверждение Apple устарело. Попробуйте ещё раз."
            uz = "Apple tasdig‘i eskirgan. Qayta urinib ko‘ring."
            cyrl = "Apple тасдиғи эскирган. Қайта уриниб кўринг."
        case "GOOGLE_ACCOUNT_EMAIL_REQUIRED":
            en = "Google did not provide a verified email. Try Google again or sign in with email or iumrah ID."
            ru = "Google не предоставил подтверждённую почту. Повторите вход через Google или войдите по почте либо iumrah ID."
            uz = "Google tasdiqlangan email bermadi. Google orqali qayta urinib ko‘ring yoki email yoxud iumrah ID bilan kiring."
            cyrl = "Google тасдиқланган email бермади. Google орқали қайта уриниб кўринг ёки email ёхуд iumrah ID билан киринг."
        case "GOOGLE_ID_CONNECTED_TO_ANOTHER_ACCOUNT":
            en = "This Google account is already connected to another iumrah ID."
            ru = "Этот Google-аккаунт уже подключён к другому iumrah ID."
            uz = "Bu Google akkaunti boshqa iumrah ID’ga ulangan."
            cyrl = "Бу Google аккаунти бошқа iumrah ID’га уланган."
        case "GOOGLE_ID_ALREADY_CONNECTED":
            en = "A different Google account is already connected to this iumrah account."
            ru = "К этому аккаунту iumrah уже подключён другой Google-аккаунт."
            uz = "Bu iumrah akkauntiga boshqa Google akkaunti ulangan."
            cyrl = "Бу iumrah аккаунтига бошқа Google аккаунти уланган."
        case "GOOGLE_EMAIL_CONNECTED_TO_ANOTHER_ACCOUNT":
            en = "The email verified by Google already belongs to another iumrah account."
            ru = "Подтверждённая Google почта уже принадлежит другому аккаунту iumrah."
            uz = "Google tasdiqlagan email boshqa iumrah akkauntiga tegishli."
            cyrl = "Google тасдиқлаган email бошқа iumrah аккаунтига тегишли."
        case "GOOGLE_TOKEN_INVALID", "GOOGLE_TOKEN_REPLAYED":
            en = "Google authorization expired. Please try again."
            ru = "Подтверждение Google устарело. Попробуйте ещё раз."
            uz = "Google tasdig‘i eskirgan. Qayta urinib ko‘ring."
            cyrl = "Google тасдиғи эскирган. Қайта уриниб кўринг."
        case "GOOGLE_AUTH_NOT_CONFIGURED":
            en = "Google Sign-In is not configured for this build yet."
            ru = "Вход через Google ещё не настроен для этой сборки."
            uz = "Google orqali kirish bu build uchun hali sozlanmagan."
            cyrl = "Google орқали кириш бу build учун ҳали созланмаган."
        case "EMAIL_INVALID":
            en = "Enter a valid email address."
            ru = "Введите корректный адрес электронной почты."
            uz = "To‘g‘ri email manzilini kiriting."
            cyrl = "Тўғри email манзилини киритинг."
        case "EMAIL_ALREADY_CONNECTED":
            en = "This email is already connected to another iumrah account."
            ru = "Эта почта уже подключена к другому аккаунту iumrah."
            uz = "Bu email boshqa iumrah akkauntiga ulangan."
            cyrl = "Бу email бошқа iumrah аккаунтига уланган."
        case "EMAIL_RATE_LIMITED":
            en = "Too many email requests. Please try again later."
            ru = "Слишком много запросов. Повторите отправку позже."
            uz = "Email so‘rovlari ko‘p. Keyinroq qayta urinib ko‘ring."
            cyrl = "Email сўровлари кўп. Кейинроқ қайта уриниб кўринг."
        case "EMAIL_DELIVERY_NOT_CONFIGURED", "EMAIL_DELIVERY_UNAVAILABLE":
            en = "The verification email could not be sent right now. Please try again later."
            ru = "Сейчас не удалось отправить письмо. Попробуйте повторить позже."
            uz = "Hozir tasdiqlash xatini yuborib bo‘lmadi. Keyinroq qayta urinib ko‘ring."
            cyrl = "Ҳозир тасдиқлаш хатини юбориб бўлмади. Кейинроқ қайта уриниб кўринг."
        case "VERIFICATION_CODE_INVALID":
            en = "The code is incorrect or expired. Request a new code."
            ru = "Код неверный или устарел. Запросите новый код."
            uz = "Kod noto‘g‘ri yoki muddati tugagan. Yangi kod so‘rang."
            cyrl = "Код нотўғри ёки муддати тугаган. Янги код сўранг."
        case "PASSWORD_TOO_WEAK":
            en = "The password must contain at least 8 characters."
            ru = "Пароль должен содержать не менее 8 символов."
            uz = "Parol kamida 8 ta belgidan iborat bo‘lishi kerak."
            cyrl = "Парол камида 8 та белгидан иборат бўлиши керак."
        default:
            en = "Account security is temporarily unavailable."
            ru = "Безопасность аккаунта временно недоступна."
            uz = "Akkaunt xavfsizligi vaqtincha mavjud emas."
            cyrl = "Аккаунт хавфсизлиги вақтинча мавжуд эмас."
        }
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
