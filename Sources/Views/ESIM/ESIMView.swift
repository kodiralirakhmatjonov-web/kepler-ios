import Foundation
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct ESIMView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var bookings: BookingStore
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private var activeSession: StoredBookingSession? {
        bookings.sessions.first { session in
            let value = (session.operationStatus ?? session.booking.status).lowercased()
            return value != "completed" && value != "cancelled"
        } ?? bookings.sessions.first
    }

    private var profiles: [ClientESIMProfile] {
        guard let activeSession else { return [] }
        return bookings.esimProfiles(for: activeSession.id)
    }

    private var activePackageIncludesESIM: Bool {
        guard let activeSession else { return false }
        return activeSession.booking.customization?.esim == true ||
            activeSession.booking.includedServices?.contains(where: { $0.lowercased() == "esim" }) == true
    }

    var body: some View {
        ZStack {
            Color.iumrahPageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    introCard

                    if profiles.isEmpty {
                        emptyState
                        planPreview
                    } else {
                        ForEach(profiles) { profile in
                            ESIMProfileCard(profile: profile, language: settings.language)
                        }
                    }

                    privacyCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 110)
            }
            .refreshable { await refresh() }
        }
        .task(id: activeSession?.id) {
            guard activeSession != nil else { return }
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refresh() }
        }
        .iumrahInternalNavigation()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("iumrah eSIM")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.8)
            Text(copy(.headerSubtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("IumrahESIMHomeCard")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 228)
                .clipped()
                .background(Color(red: 0.015, green: 0.035, blue: 0.09))

            VStack(alignment: .leading, spacing: 14) {
                Text(copy(.introTitle))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(-0.45)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(copy(.packageBadge))
                    .font(.caption2.weight(.bold))
                    .tracking(0.45)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground, in: Capsule())

                Text(copy(.introBody))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(copy(.tariffsTitle), systemImage: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(IumrahIconRole.connectivity.color)
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }

    @ViewBuilder
    private var emptyState: some View {
        if let session = activeSession {
            VStack(alignment: .leading, spacing: 14) {
                Label(activePackageIncludesESIM ? copy(.waitingTitle) : copy(.notIncludedTitle), systemImage: activePackageIncludesESIM ? "clock.badge.checkmark" : "simcard")
                    .font(.headline)
                Text(activePackageIncludesESIM ? copy(.waitingBody) : copy(.notIncludedBody))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Image(systemName: "suitcase.fill")
                    Text(session.displayBookingNumber)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color.iumrahRaisedBackground, in: Capsule())

                if activePackageIncludesESIM {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(copy(.refresh)) { Task { await refresh() } }
                            .buttonStyle(IumrahSecondaryButtonStyle())
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .iumrahCard()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Label(copy(.noTripTitle), systemImage: "suitcase")
                    .font(.headline)
                Text(copy(.noTripBody))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(copy(.buildPackage)) {
                    chrome.isESIMPresented = false
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { chrome.startNewTrip() }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
            .iumrahCard()
        }
    }

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(copy(.tariffsTitle))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(copy(.tariffsSubtitle))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                IumrahInlineIcon(
                    systemName: "antenna.radiowaves.left.and.right",
                    role: .connectivity,
                    size: 16
                )
            }

            planRow("5 GB", validity: "30", recommended: false)
            planRow("10 GB", validity: "30", recommended: true)
            planRow("20 GB", validity: "30", recommended: false)

            Text(copy(.previewDisclaimer))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .iumrahCard()
    }

    private func planRow(_ data: String, validity: String, recommended: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(data).font(.headline)
                Text("Saudi Arabia · \(validity) \(copy(.days))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if recommended {
                Text(copy(.recommended))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(Color.iumrahCareLight.opacity(0.24), in: Capsule())
            } else {
                Text(copy(.inPackage))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.iumrahRaisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(
                systemName: "lock.shield.fill",
                role: .security,
                size: 40,
                symbolSize: 18,
                cornerRadius: 13
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(copy(.privacyTitle)).font(.subheadline.weight(.semibold))
                Text(copy(.privacyBody))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @MainActor
    private func refresh() async {
        guard let activeSession, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            _ = try await bookings.loadESIMs(for: activeSession.id)
            errorMessage = nil
        } catch {
            if bookings.esimProfiles(for: activeSession.id).isEmpty {
                errorMessage = copy(.refreshUnavailable)
            }
        }
    }

    private enum CopyKey {
        case headerSubtitle, packageBadge, introTitle, introBody, waitingTitle, waitingBody, notIncludedTitle, notIncludedBody, refresh, noTripTitle, noTripBody, buildPackage
        case tariffsTitle, tariffsSubtitle, previewDisclaimer, recommended, inPackage, days, privacyTitle, privacyBody, refreshUnavailable

        var rawKey: String {
            switch self {
            case .headerSubtitle: return "header_subtitle"
            case .packageBadge: return "package_badge"
            case .introTitle: return "intro_title"
            case .introBody: return "intro_body"
            case .waitingTitle: return "waiting_title"
            case .waitingBody: return "waiting_body"
            case .notIncludedTitle: return "not_included_title"
            case .notIncludedBody: return "not_included_body"
            case .refresh: return "refresh"
            case .noTripTitle: return "no_trip_title"
            case .noTripBody: return "no_trip_body"
            case .buildPackage: return "build_package"
            case .tariffsTitle: return "tariffs_title"
            case .tariffsSubtitle: return "tariffs_subtitle"
            case .previewDisclaimer: return "preview_disclaimer"
            case .recommended: return "recommended"
            case .inPackage: return "in_package"
            case .days: return "days"
            case .privacyTitle: return "privacy_title"
            case .privacyBody: return "privacy_body"
            case .refreshUnavailable: return "refresh_unavailable"
            }
        }
    }

    private func copy(_ key: CopyKey) -> String {
        ESIMCopy.text(key.rawKey, settings.language)
    }
}

private struct ESIMProfileCard: View {
    @Environment(\.openURL) private var openURL
    let profile: ClientESIMProfile
    let language: AppSettingsStore.Language
    @State private var showManual = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                ESIMUsageRing(profile: profile, language: language)
                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.label.isEmpty ? "Saudi Arabia eSIM" : profile.label)
                        .font(.headline)
                    Text(profile.planName.isEmpty ? ESIMCopy.text("your_plan", language) : profile.planName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    statusBadge
                    if let validityText {
                        Text(validityText)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }

            if profile.usageAvailable {
                HStack(spacing: 10) {
                    metric(title: ESIMCopy.text("remaining", language), value: dataText(profile.remainingMB))
                    metric(title: ESIMCopy.text("used", language), value: dataText(profile.usedMB))
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(ESIMCopy.text("usage_pending", language))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(14)
                .background(Color.iumrahRaisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if profile.hasActivationData {
                if #available(iOS 17.4, *) {
                    Button {
                        activate()
                    } label: {
                        HStack {
                            Image(systemName: "iphone.gen3")
                            Text(ESIMCopy.text("activate", language))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                }
            }

            if !qrPayload.isEmpty {
                VStack(spacing: 12) {
                    ESIMQRCode(payload: qrPayload)
                        .frame(width: 190, height: 190)
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    Text(ESIMCopy.text("qr_help", language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            if !profile.smdpAddress.isEmpty || !profile.activationCode.isEmpty || !profile.iccid.isEmpty {
                DisclosureGroup(isExpanded: $showManual) {
                    VStack(spacing: 10) {
                        if !profile.smdpAddress.isEmpty { copyRow("SM-DP+", profile.smdpAddress) }
                        if !profile.activationCode.isEmpty { copyRow(ESIMCopy.text("activation_code", language), profile.activationCode) }
                        if !profile.iccid.isEmpty { copyRow("ICCID", profile.iccid) }
                    }
                    .padding(.top, 10)
                } label: {
                    Label(ESIMCopy.text("manual_install", language), systemImage: "key.viewfinder")
                        .font(.subheadline.weight(.semibold))
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text(syncText)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .iumrahCard()
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption.weight(.bold))
            .foregroundStyle(IumrahIconRole.success.color)
            .padding(.horizontal, 10)
            .frame(height: 29)
            .background(IumrahIconRole.success.color.opacity(0.14), in: Capsule())
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.iumrahRaisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func copyRow(_ title: String, _ value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            IumrahHaptics.success()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(.footnote, design: .monospaced).weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private var qrPayload: String {
        let lpa = profile.lpaString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !lpa.isEmpty { return lpa }
        if !profile.smdpAddress.isEmpty && !profile.activationCode.isEmpty {
            return "LPA:1$\(profile.smdpAddress)$\(profile.activationCode)"
        }
        return ""
    }

    private func activate() {
        guard !qrPayload.isEmpty else { return }
        if #available(iOS 17.4, *) {
            var components = URLComponents(string: "https://esimsetup.apple.com/esim_qrcode_provisioning")
            components?.queryItems = [URLQueryItem(name: "carddata", value: qrPayload)]
            if let url = components?.url { openURL(url) }
        }
    }

    private var statusText: String {
        let raw = ([profile.providerSmdpStatus, profile.providerStatus, profile.status]
            .compactMap { $0 }
            .joined(separator: " ")).lowercased()
        if raw.contains("expired") { return ESIMCopy.text("status_expired", language) }
        if raw.contains("used up") || raw.contains("used_up") { return ESIMCopy.text("status_used_up", language) }
        if raw.contains("in use") || raw.contains("in_use") || raw.contains("enabled") || raw.contains("active") { return ESIMCopy.text("status_active", language) }
        if raw.contains("install") || raw.contains("onboard") { return ESIMCopy.text("status_installed", language) }
        return ESIMCopy.text("status_ready", language)
    }

    private var validityText: String? {
        if let expires = profile.expiresAt, !expires.isEmpty {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: expires) {
                return "\(ESIMCopy.text("valid_until", language)) \(date.formatted(date: .abbreviated, time: .omitted))"
            }
        }
        if let days = profile.validityDays, days > 0 {
            return "\(days) \(ESIMCopy.text("days", language))"
        }
        return nil
    }

    private var syncText: String {
        if profile.usageAvailable { return ESIMCopy.text("provider_sync", language) }
        return ESIMCopy.text("pending_sync", language)
    }

    private func dataText(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        return "\(Int(max(0, mb).rounded())) MB"
    }
}

private struct ESIMUsageRing: View {
    let profile: ClientESIMProfile
    let language: AppSettingsStore.Language

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 10)
            if profile.usageAvailable {
                Circle()
                    .trim(from: 0, to: profile.remainingFraction)
                    .stroke(Color.iumrahCareDark, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text(dataText(profile.remainingMB))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(language == .turkish ? "Kalan" : "left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 4) {
                    ProgressView().controlSize(.small)
                    Text(language == .turkish ? "OTOMATİK" : "AUTO")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityLabel(profile.usageAvailable ? (language == .turkish ? "Kalan internet: \(dataText(profile.remainingMB))" : "Remaining data \(dataText(profile.remainingMB))") : (language == .turkish ? "İnternet bakiyesi güncelleniyor" : "Data balance syncing"))
    }

    private func dataText(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        return "\(Int(max(0, mb).rounded())) MB"
    }
}

private struct ESIMQRCode: View {
    let payload: String

    var body: some View {
        if let image = QRRenderer.image(payload) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .padding(18)
        }
    }
}

private enum QRRenderer {
    static let context = CIContext()

    static func image(_ payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

private enum ESIMCopy {
    static func text(_ key: String, _ language: AppSettingsStore.Language) -> String {
        let ru: [String: String] = [
            "header_subtitle":"Связь в Саудовской Аравии", "package_badge":"ТОЛЬКО В ПАКЕТЕ · V1", "intro_title":"Интернет уже внутри вашей умры", "intro_body":"В первой версии eSIM предоставляется только в составе пакета iumrah. Отдельная покупка появится позже. Активация, статус и остаток трафика доступны прямо в приложении.", "waiting_title":"eSIM будет выдана к вашей поездке", "waiting_body":"После подтверждения и подготовки поездки iumrah добавит eSIM к вашему бронированию. Здесь автоматически появятся активация, QR-код и остаток интернета.", "not_included_title":"eSIM не включена в этот пакет", "not_included_body":"Эта поездка была создана без eSIM. Новые пакеты iumrah уже подготовлены для eSIM внутри пакета; отдельная покупка появится позже.", "refresh":"Проверить eSIM", "no_trip_title":"Сначала создайте Umrah-пакет", "no_trip_body":"В этой версии отдельная продажа eSIM отключена. Добавьте eSIM вместе с вашим пакетом умры.", "build_package":"Собрать пакет", "tariffs_title":"Доступные форматы", "tariffs_subtitle":"Тариф подбирается для вашей поездки", "preview_disclaimer":"Показанные объёмы — варианты для интерфейса. Конкретный тариф и срок будут указаны после выдачи eSIM к вашей поездке.", "recommended":"ОПТИМАЛЬНО", "in_package":"В пакете", "days":"дней", "privacy_title":"Данные активации защищены", "privacy_body":"QR, Activation Code и ICCID доступны только владельцу конкретной поездки после авторизации.", "refresh_unavailable":"Сейчас не удалось обновить eSIM. Уже загруженные данные остаются доступны.", "your_plan":"Ваш тариф", "valid_until":"Действует до", "remaining":"Осталось", "used":"Использовано", "activate":"Активировать eSIM", "qr_help":"Отсканируйте этот QR другим устройством, если системная установка недоступна.", "activation_code":"Код активации", "manual_install":"Данные ручной установки", "status_active":"Активна", "status_installed":"Установлена", "status_expired":"Истекла", "status_used_up":"Трафик закончился", "status_ready":"Готова к активации", "provider_sync":"Остаток обновляется автоматически", "pending_sync":"Подключаем автоматический остаток", "usage_pending":"Получаем остаток трафика у оператора…"
        ]
        let en: [String: String] = [
            "header_subtitle":"Connectivity in Saudi Arabia", "package_badge":"PACKAGE ONLY · V1", "intro_title":"Internet is part of your Umrah", "intro_body":"In the first version, eSIM is available only as part of an iumrah package. Standalone purchase will come later. Activation, status and data balance are available directly in the app.", "waiting_title":"Your eSIM will be assigned to this trip", "waiting_body":"Once the trip is prepared, iumrah will attach an eSIM to your booking. Activation, QR code and data balance will appear here automatically.", "not_included_title":"eSIM is not included in this package", "not_included_body":"This trip was created without eSIM. New iumrah packages are prepared for package-included eSIM; standalone purchase will come later.", "refresh":"Check eSIM", "no_trip_title":"Build an Umrah package first", "no_trip_body":"Standalone eSIM sales are disabled in this version. Add connectivity with your Umrah package.", "build_package":"Build package", "tariffs_title":"Available formats", "tariffs_subtitle":"The plan is selected for your trip", "preview_disclaimer":"Displayed data sizes are interface previews. Your exact plan and validity will be shown after the eSIM is assigned.", "recommended":"RECOMMENDED", "in_package":"In package", "days":"days", "privacy_title":"Activation data is protected", "privacy_body":"QR, Activation Code and ICCID are available only to the owner of the specific trip after authorization.", "refresh_unavailable":"eSIM could not be refreshed right now. Previously loaded data remains available.", "your_plan":"Your plan", "valid_until":"Valid until", "remaining":"Remaining", "used":"Used", "activate":"Activate eSIM", "qr_help":"Scan this QR from another device if system installation is unavailable.", "activation_code":"Activation code", "manual_install":"Manual installation data", "status_active":"Active", "status_installed":"Installed", "status_expired":"Expired", "status_used_up":"Data used up", "status_ready":"Ready to activate", "provider_sync":"Balance updates automatically", "pending_sync":"Connecting automatic balance", "usage_pending":"Fetching your data balance from the carrier…"
        ]
        let tr: [String: String] = [
            "header_subtitle": "Suudi Arabistan’da internet bağlantısı",
            "package_badge": "YALNIZCA PAKETTE · V1",
            "intro_title": "İnternet umre paketinize dahil",
            "intro_body": "İlk sürümde eSIM yalnızca iumrah paketinin bir parçası olarak sunulur. Ayrı satın alma seçeneği daha sonra eklenecektir. Etkinleştirme, durum ve kalan internet hakkı doğrudan uygulamada görüntülenir.",
            "waiting_title": "eSIM seyahatinize atanacak",
            "waiting_body": "Seyahatiniz hazırlandığında iumrah, rezervasyonunuza bir eSIM tanımlar. Etkinleştirme, QR kodu ve kalan internet hakkı burada otomatik olarak görünür.",
            "not_included_title": "Bu pakete eSIM dahil değil",
            "not_included_body": "Bu seyahat eSIM olmadan oluşturuldu. Yeni iumrah paketleri paket içi eSIM için hazır; ayrı satın alma özelliği daha sonra eklenecek.",
            "refresh": "eSIM’i kontrol et",
            "no_trip_title": "Önce umre paketi oluşturun",
            "no_trip_body": "Bu sürümde eSIM tek başına satılmamaktadır. İnternet bağlantısını umre paketinizle birlikte edinin.",
            "build_package": "Paket oluştur",
            "tariffs_title": "Mevcut seçenekler",
            "tariffs_subtitle": "Tarife seyahatinize göre seçilir",
            "preview_disclaimer": "Gösterilen internet miktarları arayüz örnekleridir. eSIM atandıktan sonra kesin tarifeniz ve geçerlilik süreniz gösterilir.",
            "recommended": "ÖNERİLEN",
            "in_package": "Pakete dahil",
            "days": "gün",
            "privacy_title": "Etkinleştirme bilgileriniz güvende",
            "privacy_body": "QR, etkinleştirme kodu ve ICCID, yalnızca ilgili seyahatin hesap sahibi tarafından giriş yapıldıktan sonra görüntülenebilir.",
            "refresh_unavailable": "eSIM şu anda güncellenemedi. Önceden yüklenen bilgiler kullanılabilir durumda.",
            "your_plan": "Tarifeniz",
            "valid_until": "Geçerlilik bitişi",
            "remaining": "Kalan",
            "used": "Kullanılan",
            "activate": "eSIM’i etkinleştir",
            "qr_help": "Sistem üzerinden kurulum kullanılamıyorsa bu QR kodunu başka bir cihazla tarayın.",
            "activation_code": "Etkinleştirme kodu",
            "manual_install": "Elle kurulum bilgileri",
            "status_active": "Etkin",
            "status_installed": "Yüklendi",
            "status_expired": "Süresi doldu",
            "status_used_up": "İnternet hakkı tükendi",
            "status_ready": "Etkinleştirmeye hazır",
            "provider_sync": "Kalan internet hakkı otomatik güncellenir",
            "pending_sync": "Otomatik bakiye kontrolü bağlanıyor",
            "usage_pending": "Operatörden kalan internet hakkı alınıyor…"
        ]
        let uz: [String: String] = [
            "header_subtitle":"Saudiya Arabistonida aloqa", "package_badge":"FAQAT PAKETDA · V1", "intro_title":"Internet Umra paketingiz ichida", "intro_body":"Birinchi versiyada eSIM faqat iumrah paketi tarkibida beriladi. Alohida xarid keyinroq qo‘shiladi. Faollashtirish, holat va trafik qoldig‘i ilovaning o‘zida ko‘rinadi.", "waiting_title":"eSIM safaringizga biriktiriladi", "waiting_body":"Safar tayyorlangach iumrah eSIM’ni broningizga qo‘shadi. Faollashtirish, QR-kod va internet qoldig‘i shu yerda avtomatik paydo bo‘ladi.", "not_included_title":"eSIM bu paketga kiritilmagan", "not_included_body":"Bu safar eSIM’siz yaratilgan. Yangi iumrah paketlari paket ichidagi eSIM uchun tayyor; alohida xarid keyinroq qo‘shiladi.", "refresh":"eSIM’ni tekshirish", "no_trip_title":"Avval Umra paketini yarating", "no_trip_body":"Bu versiyada alohida eSIM savdosi o‘chirilgan. eSIM’ni Umra paketingiz bilan oling.", "build_package":"Paket yaratish", "tariffs_title":"Mavjud formatlar", "tariffs_subtitle":"Tarif safaringiz uchun tanlanadi", "preview_disclaimer":"Ko‘rsatilgan hajmlar interfeys namunalari. Aniq tarif va muddat eSIM biriktirilgach ko‘rsatiladi.", "recommended":"TAVSIYA", "in_package":"Paketda", "days":"kun", "privacy_title":"Faollashtirish ma’lumotlari himoyalangan", "privacy_body":"QR, Activation Code va ICCID faqat shu safar egasiga avtorizatsiyadan keyin ko‘rsatiladi.", "refresh_unavailable":"Hozir eSIM yangilanmadi. Oldin yuklangan ma’lumotlar saqlanadi.", "your_plan":"Tarifingiz", "valid_until":"Amal qiladi", "remaining":"Qoldi", "used":"Ishlatildi", "activate":"eSIM’ni faollashtirish", "qr_help":"Tizimli o‘rnatish ishlamasa QR-kodni boshqa qurilmadan skanerlang.", "activation_code":"Faollashtirish kodi", "manual_install":"Qo‘lda o‘rnatish ma’lumotlari", "status_active":"Faol", "status_installed":"O‘rnatilgan", "status_expired":"Muddati tugagan", "status_used_up":"Trafik tugagan", "status_ready":"Faollashtirishga tayyor", "provider_sync":"Qoldiq avtomatik yangilanadi", "pending_sync":"Avtomatik qoldiq ulanmoqda", "usage_pending":"Operator orqali trafik qoldig‘i olinmoqda…"
        ]
        let cy: [String: String] = [
            "header_subtitle":"Саудия Арабистонида алоқа", "package_badge":"ФАҚАТ ПАКЕТДА · V1", "intro_title":"Интернет Умра пакетингиз ичида", "intro_body":"Биринчи версияда eSIM фақат iumrah пакети таркибида берилади. Алоҳида харид кейинроқ қўшилади. Фаоллаштириш, ҳолат ва трафик қолдиғи илованинг ўзида кўринади.", "waiting_title":"eSIM сафарингизга бириктирилади", "waiting_body":"Сафар тайёрлангач iumrah eSIM’ни бронга қўшади. Фаоллаштириш, QR-код ва интернет қолдиғи шу ерда автоматик пайдо бўлади.", "not_included_title":"eSIM бу пакетга киритилмаган", "not_included_body":"Бу сафар eSIM’сиз яратилган. Янги iumrah пакетлари пакет ичидаги eSIM учун тайёр; алоҳида харид кейинроқ қўшилади.", "refresh":"eSIM’ни текшириш", "no_trip_title":"Аввал Умра пакетини яратинг", "no_trip_body":"Бу версияда алоҳида eSIM савдоси ўчирилган. eSIM’ни Умра пакетингиз билан олинг.", "build_package":"Пакет яратиш", "tariffs_title":"Мавжуд форматлар", "tariffs_subtitle":"Тариф сафарингиз учун танланади", "preview_disclaimer":"Кўрсатилган ҳажмлар интерфейс намуналари. Аниқ тариф ва муддат eSIM бириктирилгач кўрсатилади.", "recommended":"ТАВСИЯ", "in_package":"Пакетда", "days":"кун", "privacy_title":"Фаоллаштириш маълумотлари ҳимояланган", "privacy_body":"QR, Activation Code ва ICCID фақат шу сафар эгасига авторизациядан кейин кўрсатилади.", "refresh_unavailable":"Ҳозир eSIM янгиланмади. Олдин юкланган маълумотлар сақланади.", "your_plan":"Тарифингиз", "valid_until":"Амал қилади", "remaining":"Қолди", "used":"Ишлатилди", "activate":"eSIM’ни фаоллаштириш", "qr_help":"Тизимли ўрнатиш ишламаса QR-кодни бошқа қурилмадан сканерланг.", "activation_code":"Фаоллаштириш коди", "manual_install":"Қўлда ўрнатиш маълумотлари", "status_active":"Фаол", "status_installed":"Ўрнатилган", "status_expired":"Муддати тугаган", "status_used_up":"Трафик тугаган", "status_ready":"Фаоллаштиришга тайёр", "provider_sync":"Қолдиқ автоматик янгиланади", "pending_sync":"Автоматик қолдиқ уланмоқда", "usage_pending":"Оператор орқали трафик қолдиғи олинмоқда…"
        ]
        switch language {
        case .russian: return ru[key] ?? key
        case .turkish: return tr[key] ?? en[key] ?? key
        case .indonesian, .english: return en[key] ?? ru[key] ?? key
        case .uzbek: return uz[key] ?? ru[key] ?? key
        case .uzbekCyrillic: return cy[key] ?? ru[key] ?? key
        }
    }
}
