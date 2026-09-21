import Foundation
import SwiftUI
import UIKit
import LinkPresentation

struct IumrahPackageSharePayload: Hashable {
    let packageID: String
    let hotelID: String
    let hotelName: String
    let tierName: String
    let outboundRoute: String
    let inboundRoute: String
    let outboundAt: String
    let inboundAt: String
    let durationDays: Int
    let travelers: Int
    let adults: Int
    let children: Int
    let infants: Int
    let rooms: Int
    let scope: JourneyScope
    let firstSaudiCity: SaudiArrivalAirport
    let mealSelection: PackageMealSelection
    let totalPriceUSD: Decimal
    let perPersonPriceUSD: Decimal
    let mealsSummary: String
    let scopeSummary: String
    let outboundOptionID: String
    let inboundOptionID: String
}

extension IumrahPackageSharePayload {
    static func defaultHotelFirst(
        hotel: HotelSummary,
        preview: StorefrontFlightPackagePreview,
        language: AppSettingsStore.Language
    ) -> IumrahPackageSharePayload {
        let meals: String
        switch preview.tier {
        case .comfort, .luxury:
            meals = localized(
                language,
                "Завтрак включён · обед и ужин можно добавить",
                "Breakfast included · lunch and dinner can be added",
                "Nonushta kiritilgan · tushlik va kechki ovqatni qo‘shish mumkin",
                "Нонушта киритилган · тушлик ва кечки овқатни қўшиш мумкин"
            )
        case .economy, .standard:
            meals = localized(
                language,
                "Питание включено по категории пакета",
                "Meals included according to the package tier",
                "Ovqatlanish paket toifasiga muvofiq kiritilgan",
                "Овқатланиш пакет тоифасига мувофиқ киритилган"
            )
        }

        let scope: JourneyScope = preview.madinahNights > 0 ? .makkahAndMadinah : .makkahOnly
        let scopeSummary = preview.madinahNights > 0
            ? localized(language, "Мекка + Медина", "Makkah + Madinah", "Makka + Madina", "Макка + Мадина")
            : localized(language, "Только Мекка", "Makkah only", "Faqat Makka", "Фақат Макка")
        let config = preview.snapshotConfiguration
        let adults = max(1, config?.adults ?? 2)
        let children = max(0, config?.children ?? 0)
        let infants = max(0, config?.infants ?? 0)
        let travelers = max(1, adults + children + infants)
        let rooms = max(1, config?.rooms ?? 1)

        return IumrahPackageSharePayload(
            packageID: preview.packageID,
            hotelID: hotel.id,
            hotelName: hotel.name,
            tierName: preview.tier.title(language),
            outboundRoute: "\(preview.outbound.origin) → \(preview.outbound.destination)",
            inboundRoute: "\(preview.inbound.origin) → \(preview.inbound.destination)",
            outboundAt: preview.outbound.departureAt,
            inboundAt: preview.inbound.departureAt,
            durationDays: preview.durationDays,
            travelers: travelers,
            adults: adults,
            children: children,
            infants: infants,
            rooms: rooms,
            scope: scope,
            firstSaudiCity: preview.outbound.destination.uppercased() == "MED" ? .madinah : .jeddah,
            mealSelection: config?.mealSelection ?? .defaultSelection,
            totalPriceUSD: preview.totalPackagePrice,
            perPersonPriceUSD: preview.pricePerPerson,
            mealsSummary: meals,
            scopeSummary: scopeSummary,
            outboundOptionID: preview.outboundOptionID,
            inboundOptionID: preview.returnOptionID
        )
    }

    private static func localized(
        _ language: AppSettingsStore.Language,
        _ ru: String,
        _ en: String,
        _ uz: String,
        _ uzCy: String
    ) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

struct IumrahPackageShareArtifacts: Identifiable {
    let id = UUID()
    let message: String
    let deepLink: URL
    let pdfURL: URL
    let imageURL: URL
}

struct IumrahPackageActivitySheet: UIViewControllerRepresentable {
    let artifacts: IumrahPackageShareArtifacts

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let richLink = IumrahPackageShareLinkSource(artifacts: artifacts)
        return UIActivityViewController(
            activityItems: [artifacts.message, richLink, artifacts.pdfURL, artifacts.imageURL],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class IumrahPackageShareLinkSource: NSObject, UIActivityItemSource {
    let artifacts: IumrahPackageShareArtifacts

    init(artifacts: IumrahPackageShareArtifacts) {
        self.artifacts = artifacts
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        artifacts.deepLink
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        artifacts.deepLink
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = artifacts.deepLink
        metadata.url = artifacts.deepLink
        metadata.title = artifacts.message.components(separatedBy: "\n").first ?? "iumrah Configurator"
        if let image = UIImage(contentsOfFile: artifacts.imageURL.path) {
            metadata.imageProvider = NSItemProvider(object: image)
        }
        return metadata
    }
}

enum IumrahPackageShareFactory {
    static func make(
        payload: IumrahPackageSharePayload,
        language: AppSettingsStore.Language,
        invitation: Bool
    ) throws -> IumrahPackageShareArtifacts {
        let link = packageLink(payload)
        let message = shareMessage(payload: payload, language: language, invitation: invitation, link: link)
        let slug = safeSlug(payload.hotelName)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("iumrah-share", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pdfURL = directory.appendingPathComponent("iumrah-package-\(slug).pdf")
        let imageURL = directory.appendingPathComponent("iumrah-package-\(slug).png")

        try renderPDF(payload: payload, language: language, link: link, to: pdfURL)
        try renderImage(payload: payload, language: language, link: link, to: imageURL)

        return IumrahPackageShareArtifacts(
            message: message,
            deepLink: link,
            pdfURL: pdfURL,
            imageURL: imageURL
        )
    }

    private static func packageLink(_ payload: IumrahPackageSharePayload) -> URL {
        AppConfig.apiBaseURL
            .appendingPathComponent("flights")
            .appendingPathComponent("package")
            .appendingPathComponent(payload.packageID)
    }

    private static func shareMessage(
        payload: IumrahPackageSharePayload,
        language: AppSettingsStore.Language,
        invitation: Bool,
        link: URL
    ) -> String {
        let price = money(payload.totalPriceUSD)
        let perPerson = money(payload.perPersonPriceUSD)
        let header: String
        let details: String
        switch language {
        case .russian:
            header = invitation ? "Присоединяйтесь к моей Умре с iumrah" : "Пакет Умры · iumrah Configurator"
            details = "\(payload.hotelName) · \(payload.tierName)\n\(payload.outboundRoute) · \(payload.inboundRoute)\n\(travelDates(payload, language: language))\n\(payload.durationDays) дн. · \(payload.scopeSummary) · \(travelerBreakdown(payload, language: language)) · \(payload.rooms) комн.\n\(price) за пакет · \(perPerson) на человека\n\(payload.mealsSummary)"
        case .english:
            header = invitation ? "Join my Umrah trip with iumrah" : "Umrah package · iumrah Configurator"
            details = "\(payload.hotelName) · \(payload.tierName)\n\(payload.outboundRoute) · \(payload.inboundRoute)\n\(travelDates(payload, language: language))\n\(payload.durationDays) days · \(payload.scopeSummary) · \(travelerBreakdown(payload, language: language)) · \(payload.rooms) rooms\n\(price) package · \(perPerson) per person\n\(payload.mealsSummary)"
        case .uzbek:
            header = invitation ? "iumrah bilan Umra safarimga qo‘shiling" : "Umra paketi · iumrah Configurator"
            details = "\(payload.hotelName) · \(payload.tierName)\n\(payload.outboundRoute) · \(payload.inboundRoute)\n\(travelDates(payload, language: language))\n\(payload.durationDays) kun · \(payload.scopeSummary) · \(travelerBreakdown(payload, language: language)) · \(payload.rooms) xona\nPaket \(price) · kishi boshiga \(perPerson)\n\(payload.mealsSummary)"
        case .uzbekCyrillic:
            header = invitation ? "iumrah билан Умра сафаримга қўшилинг" : "Умра пакети · iumrah Configurator"
            details = "\(payload.hotelName) · \(payload.tierName)\n\(payload.outboundRoute) · \(payload.inboundRoute)\n\(travelDates(payload, language: language))\n\(payload.durationDays) кун · \(payload.scopeSummary) · \(travelerBreakdown(payload, language: language)) · \(payload.rooms) хона\nПакет \(price) · киши бошига \(perPerson)\n\(payload.mealsSummary)"
        }
        return "\(header)\n\n\(details)\n\n\(link.absoluteString)"
    }

    private static func renderPDF(
        payload: IumrahPackageSharePayload,
        language: AppSettingsStore.Language,
        link: URL,
        to url: URL
    ) throws {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            UIColor.white.setFill()
            context.cgContext.fill(page)

            drawBrandHeader(in: context.cgContext, width: page.width)

            var y: CGFloat = 118
            y = drawText(localizedTitle(language), x: 42, y: y, width: 511, font: .systemFont(ofSize: 31, weight: .bold), color: .black) + 8
            y = drawText(payload.hotelName, x: 42, y: y, width: 511, font: .systemFont(ofSize: 20, weight: .semibold), color: .darkGray) + 24

            let cards: [(String, String)] = [
                (localized(language, "Маршрут", "Route", "Yo‘nalish", "Йўналиш"), "\(payload.outboundRoute)  ·  \(payload.inboundRoute)"),
                (localized(language, "Даты", "Dates", "Sanalar", "Саналар"), travelDates(payload, language: language)),
                (localized(language, "Поездка", "Trip", "Safar", "Сафар"), "\(payload.durationDays) · \(payload.scopeSummary)"),
                (localized(language, "Паломники", "Pilgrims", "Ziyoratchilar", "Зиёратчилар"), "\(travelerBreakdown(payload, language: language)) · \(localized(language, "комнат", "rooms", "xona", "хона")) \(payload.rooms)"),
                (localized(language, "Питание", "Meals", "Ovqatlanish", "Овқатланиш"), payload.mealsSummary)
            ]
            for item in cards {
                y = drawInfoRow(title: item.0, value: item.1, y: y, pageWidth: page.width)
            }

            y += 20
            y = drawText(money(payload.totalPriceUSD), x: 42, y: y, width: 330, font: .systemFont(ofSize: 39, weight: .bold), color: .black) + 2
            y = drawText(localized(language, "итоговая цена пакета", "total package price", "paketning umumiy narxi", "пакетнинг умумий нархи"), x: 42, y: y, width: 330, font: .systemFont(ofSize: 13, weight: .medium), color: .gray) + 18
            _ = drawText("\(money(payload.perPersonPriceUSD)) · \(localized(language, "на человека", "per person", "kishi boshiga", "киши бошига"))", x: 42, y: y, width: 330, font: .systemFont(ofSize: 17, weight: .semibold), color: .darkGray)

            let linkText = link.absoluteString
            _ = drawText(localized(language, "Открыть этот пакет в iumrah Configurator", "Open this package in iumrah Configurator", "Bu paketni iumrah Configurator’da ochish", "Бу пакетни iumrah Configurator’да очиш"), x: 42, y: 690, width: 511, font: .systemFont(ofSize: 15, weight: .semibold), color: .black)
            _ = drawText(linkText, x: 42, y: 716, width: 511, font: .systemFont(ofSize: 10, weight: .regular), color: .gray)
            _ = drawText(localized(language, "Цена и наличие перепроверяются перед бронированием.", "Price and availability are rechecked before booking.", "Narx va mavjudlik bron qilishdan oldin qayta tekshiriladi.", "Нарх ва мавжудлик брон қилишдан олдин қайта текширилади."), x: 42, y: 776, width: 511, font: .systemFont(ofSize: 10, weight: .regular), color: .gray)
        }
    }

    private static func renderImage(
        payload: IumrahPackageSharePayload,
        language: AppSettingsStore.Language,
        link: URL,
        to url: URL
    ) throws {
        let size = CGSize(width: 1080, height: 1350)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: 310))

            _ = drawText("iumrah", x: 72, y: 64, width: 600, font: .systemFont(ofSize: 62, weight: .bold), color: .white)
            _ = drawText("Configurator", x: 72, y: 136, width: 600, font: .systemFont(ofSize: 28, weight: .medium), color: UIColor.white.withAlphaComponent(0.72))
            _ = drawText("\(payload.outboundRoute)  ·  \(payload.inboundRoute)", x: 72, y: 215, width: 930, font: .systemFont(ofSize: 34, weight: .bold), color: .white)

            var y: CGFloat = 370
            y = drawText(payload.hotelName, x: 72, y: y, width: 936, font: .systemFont(ofSize: 51, weight: .bold), color: .black) + 18
            y = drawText("\(payload.tierName) · \(payload.durationDays) \(localized(language, "дн.", "days", "kun", "кун")) · \(payload.travelers) \(localized(language, "паломн.", "pilgrims", "ziyoratchi", "зиёратчи"))", x: 72, y: y, width: 936, font: .systemFont(ofSize: 28, weight: .medium), color: .darkGray) + 12
            y = drawText(travelDates(payload, language: language), x: 72, y: y, width: 936, font: .systemFont(ofSize: 24, weight: .medium), color: .gray) + 52

            y = drawText(money(payload.perPersonPriceUSD), x: 72, y: y, width: 600, font: .systemFont(ofSize: 88, weight: .bold), color: .black) + 2
            y = drawText(localized(language, "на человека", "per person", "kishi boshiga", "киши бошига"), x: 72, y: y, width: 600, font: .systemFont(ofSize: 27, weight: .medium), color: .gray) + 42
            y = drawText("\(money(payload.totalPriceUSD)) · \(localized(language, "весь пакет", "full package", "to‘liq paket", "тўлиқ пакет"))", x: 72, y: y, width: 780, font: .systemFont(ofSize: 34, weight: .semibold), color: .darkGray) + 54
            _ = drawText(payload.mealsSummary, x: 72, y: y, width: 936, font: .systemFont(ofSize: 25, weight: .regular), color: .darkGray)

            UIColor.black.setFill()
            let buttonRect = CGRect(x: 72, y: 1126, width: 936, height: 112)
            UIBezierPath(roundedRect: buttonRect, cornerRadius: 34).fill()
            _ = drawText(localized(language, "Открыть в iumrah", "Open in iumrah", "iumrah’da ochish", "iumrah’да очиш"), x: 112, y: 1156, width: 650, font: .systemFont(ofSize: 34, weight: .bold), color: .white)
            _ = drawText(link.host ?? "iumrah.app", x: 72, y: 1270, width: 936, font: .systemFont(ofSize: 20, weight: .medium), color: .gray)
        }
        guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }

    private static func drawBrandHeader(in context: CGContext, width: CGFloat) {
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: 86))
        _ = drawText("iumrah", x: 42, y: 24, width: 250, font: .systemFont(ofSize: 26, weight: .bold), color: .white)
        _ = drawText("CONFIGURATOR", x: width - 210, y: 31, width: 168, font: .systemFont(ofSize: 10, weight: .bold), color: UIColor.white.withAlphaComponent(0.74), alignment: .right)
    }

    @discardableResult
    private static func drawInfoRow(title: String, value: String, y: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let x: CGFloat = 42
        let width = pageWidth - 84
        UIColor(white: 0.96, alpha: 1).setFill()
        UIBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: 64), cornerRadius: 16).fill()
        _ = drawText(title.uppercased(), x: x + 16, y: y + 13, width: 125, font: .systemFont(ofSize: 9, weight: .bold), color: .gray)
        _ = drawText(value, x: x + 150, y: y + 12, width: width - 166, font: .systemFont(ofSize: 13, weight: .semibold), color: .black, alignment: .right)
        return y + 74
    }

    @discardableResult
    private static func drawText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: width, height: 1000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: ceil(bounding.height) + 4), withAttributes: attributes)
        return y + ceil(bounding.height) + 4
    }

    private static func localizedTitle(_ language: AppSettingsStore.Language) -> String {
        localized(language, "Ваша Умра", "Your Umrah", "Sizning Umrangiz", "Сизнинг Умрангиз")
    }

    private static func localized(_ language: AppSettingsStore.Language, _ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private static func travelerBreakdown(_ payload: IumrahPackageSharePayload, language: AppSettingsStore.Language) -> String {
        var parts: [String] = []
        if payload.adults > 0 {
            parts.append("\(payload.adults) \(localized(language, "взр.", "adults", "katta", "катта"))")
        }
        if payload.children > 0 {
            parts.append("\(payload.children) \(localized(language, "дет.", "children", "bola", "бола"))")
        }
        if payload.infants > 0 {
            parts.append("\(payload.infants) \(localized(language, "млад.", "infants", "chaqaloq", "чақалоқ"))")
        }
        return parts.isEmpty ? String(payload.travelers) : parts.joined(separator: " + ")
    }

    private static func travelDates(_ payload: IumrahPackageSharePayload, language: AppSettingsStore.Language) -> String {
        let outbound = displayDate(payload.outboundAt, language: language)
        let inbound = displayDate(payload.inboundAt, language: language)
        return "\(outbound) – \(inbound)"
    }

    private static func displayDate(_ value: String, language: AppSettingsStore.Language) -> String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        guard let date = fractional.date(from: value) ?? standard.date(from: value) else {
            return String(value.prefix(10))
        }
        let formatter = DateFormatter()
        switch language {
        case .russian: formatter.locale = Locale(identifier: "ru_RU")
        case .english: formatter.locale = Locale(identifier: "en_US")
        case .uzbek, .uzbekCyrillic: formatter.locale = Locale(identifier: "uz_UZ")
        }
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private static func money(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private static func safeSlug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let raw = String(mapped).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String((trimmed.isEmpty ? "umrah" : trimmed).prefix(48)).lowercased()
    }
}
