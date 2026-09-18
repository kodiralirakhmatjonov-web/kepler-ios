import SwiftUI
import UIKit

struct IumrahInvoiceShareCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let session: StoredBookingSession
    var compact: Bool = false

    @State private var shareURL: URL?
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "doc.text.fill", role: .document, size: compact ? 40 : 44, symbolSize: 17, cornerRadius: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedTitle)
                        .font(compact ? .subheadline.weight(.semibold) : .headline)
                    Text(localizedBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }

            Button {
                do {
                    shareURL = try IumrahInvoiceRenderer.makeInvoice(session: session, language: settings.language)
                    IumrahHaptics.soft()
                } catch {
                    errorText = localizedError
                    IumrahHaptics.error()
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text(localizedAction)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL {
                IumrahFileShareSheet(url: shareURL)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var localizedTitle: String {
        switch settings.language {
        case .russian: return "Инвойс бронирования"
        case .english: return "Booking invoice"
        case .uzbek: return "Bron invoice"
        case .uzbekCyrillic: return "Брон invoice"
        }
    }

    private var localizedBody: String {
        switch settings.language {
        case .russian: return "Формируется из сохранённых данных этой поездки и доступен для сохранения в PDF."
        case .english: return "Generated from the saved booking snapshot and available to save as a PDF."
        case .uzbek: return "Saqlangan bron ma’lumotlaridan yaratiladi va PDF sifatida saqlanishi mumkin."
        case .uzbekCyrillic: return "Сақланган брон маълумотларидан яратилади ва PDF сифатида сақланиши мумкин."
        }
    }

    private var localizedAction: String {
        switch settings.language {
        case .russian: return "Сохранить инвойс PDF"
        case .english: return "Save invoice PDF"
        case .uzbek: return "Invoice PDF saqlash"
        case .uzbekCyrillic: return "Invoice PDF сақлаш"
        }
    }

    private var localizedError: String {
        switch settings.language {
        case .russian: return "Не удалось сформировать PDF. Попробуйте ещё раз."
        case .english: return "Could not create the PDF. Please try again."
        case .uzbek: return "PDF yaratilmadi. Qayta urinib ko‘ring."
        case .uzbekCyrillic: return "PDF яратилмади. Қайта уриниб кўринг."
        }
    }
}

struct IumrahFileShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum IumrahInvoiceRenderer {
    static func makeInvoice(session: StoredBookingSession, language: AppSettingsStore.Language) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let format = UIGraphicsPDFRendererFormat()
        let metadata: [String: Any] = [
            kCGPDFContextTitle as String: invoiceTitle(language),
            kCGPDFContextCreator as String: "iumrah"
        ]
        format.documentInfo = metadata
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)

        let safeNumber = session.displayBookingNumber.replacingOccurrences(of: "#", with: "")
        let filename = "iumrah-invoice-\(safeNumber.isEmpty ? session.id : safeNumber).pdf"
        let documentsRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let invoiceDirectory = documentsRoot
            .appendingPathComponent("iumrah", isDirectory: true)
            .appendingPathComponent("Invoices", isDirectory: true)
        try FileManager.default.createDirectory(at: invoiceDirectory, withIntermediateDirectories: true)
        let url = invoiceDirectory.appendingPathComponent(filename)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            var y: CGFloat = 48
            let left: CGFloat = 44
            let width: CGFloat = page.width - 88

            draw("iumrah", at: CGRect(x: left, y: y, width: width, height: 36), font: .systemFont(ofSize: 28, weight: .bold), color: .label)
            y += 42
            draw(invoiceTitle(language), at: CGRect(x: left, y: y, width: width, height: 28), font: .systemFont(ofSize: 20, weight: .bold), color: .label)
            y += 40

            drawKeyValue(key: bookingLabel(language), value: session.displayBookingNumber, x: left, y: &y, width: width)
            drawKeyValue(key: dateLabel(language), value: invoiceDate(language), x: left, y: &y, width: width)
            drawKeyValue(key: routeLabel(language), value: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)", x: left, y: &y, width: width)
            drawKeyValue(key: travelDatesLabel(language), value: "\(session.booking.input.startDate) — \(session.booking.input.endDate)", x: left, y: &y, width: width)
            drawKeyValue(key: travelersLabel(language), value: "\(session.booking.input.travelers.totalPeople)", x: left, y: &y, width: width)
            drawKeyValue(key: packageLabel(language), value: session.booking.planId.capitalized, x: left, y: &y, width: width)

            y += 12
            drawDivider(x: left, y: y, width: width)
            y += 22

            draw(totalLabel(language), at: CGRect(x: left, y: y, width: width * 0.55, height: 30), font: .systemFont(ofSize: 16, weight: .semibold), color: .secondaryLabel)
            let total = String(format: "$%.2f", session.booking.totalUsd)
            draw(total, at: CGRect(x: left + width * 0.55, y: y - 3, width: width * 0.45, height: 36), font: .monospacedDigitSystemFont(ofSize: 24, weight: .bold), color: .label, alignment: .right)
            y += 54

            draw(sectionTitle(language), at: CGRect(x: left, y: y, width: width, height: 24), font: .systemFont(ofSize: 15, weight: .bold), color: .label)
            y += 30
            let terms = termsText(language)
            let termHeight = (terms as NSString).boundingRect(with: CGSize(width: width, height: 220), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: 11)], context: nil).height + 8
            draw(terms, at: CGRect(x: left, y: y, width: width, height: termHeight), font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += termHeight + 18

            drawDivider(x: left, y: y, width: width)
            y += 18
            draw(footer(language), at: CGRect(x: left, y: y, width: width, height: 60), font: .systemFont(ofSize: 9), color: .tertiaryLabel)
        }

        return url
    }

    private static func drawKeyValue(key: String, value: String, x: CGFloat, y: inout CGFloat, width: CGFloat) {
        draw(key, at: CGRect(x: x, y: y, width: width * 0.42, height: 22), font: .systemFont(ofSize: 11, weight: .semibold), color: .secondaryLabel)
        draw(value, at: CGRect(x: x + width * 0.42, y: y, width: width * 0.58, height: 22), font: .systemFont(ofSize: 11, weight: .medium), color: .label, alignment: .right)
        y += 26
    }

    private static func drawDivider(x: CGFloat, y: CGFloat, width: CGFloat) {
        UIColor.separator.setFill()
        UIRectFill(CGRect(x: x, y: y, width: width, height: 0.6))
    }

    private static func draw(_ text: String, at rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]).draw(in: rect)
    }

    private static func invoiceTitle(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Инвойс бронирования"
        case .english: return "Booking Invoice"
        case .uzbek: return "Bron Invoice"
        case .uzbekCyrillic: return "Брон Invoice"
        }
    }

    private static func bookingLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Бронирование", "Booking", "Bron", "Брон") }
    private static func dateLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Дата инвойса", "Invoice date", "Invoice sanasi", "Invoice санаси") }
    private static func routeLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Маршрут", "Route", "Yo‘nalish", "Йўналиш") }
    private static func travelDatesLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Даты поездки", "Travel dates", "Safar sanalari", "Сафар саналари") }
    private static func travelersLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Паломники", "Pilgrims", "Ziyoratchilar", "Зиёратчилар") }
    private static func packageLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Пакет", "Package", "Paket", "Пакет") }
    private static func totalLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Сумма бронирования", "Booking total", "Bron summasi", "Брон суммаси") }
    private static func sectionTitle(_ language: AppSettingsStore.Language) -> String { label(language, "Оплата и возврат", "Payment & refunds", "To‘lov va qaytarish", "Тўлов ва қайтариш") }

    private static func invoiceDate(_ language: AppSettingsStore.Language) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private static func termsText(_ language: AppSettingsStore.Language) -> String {
        label(language,
              "В первой версии оплата временно выполняется вручную по реквизитам внутри бронирования. После оплаты необходимо прикрепить банковский чек. Возврат рассчитывается отдельно: авиабилеты и отели по умолчанию невозвратные, если конкретный тариф не говорит иначе; трансфер — полный возврат до 120 часов, затем удержание $100; неиспользованные сервисы iumrah возвращаются до начала услуги.",
              "In the first release, payment is temporarily made manually using the details inside the booking. After payment, upload the bank receipt. Refunds are calculated separately: flights and hotels are non-refundable by default unless the selected fare/rate says otherwise; transfer is fully refundable until 120 hours before service, then a $100 fee applies; unused iumrah services are refundable before they begin.",
              "Birinchi versiyada to‘lov vaqtincha bron ichidagi rekvizitlar bo‘yicha qo‘lda amalga oshiriladi. To‘lovdan keyin bank chekini yuklang. Qaytarish alohida hisoblanadi: aviachiptalar va mehmonxonalar aniq tarif boshqacha demasa, odatda qaytarilmaydi; transfer 120 soatgacha to‘liq qaytariladi, keyin $100 ushlab qolinadi; foydalanilmagan iumrah xizmatlari boshlanishidan oldin qaytariladi.",
              "Биринчи версияда тўлов вақтинча брон ичидаги реквизитлар бўйича қўлда амалга оширилади. Тўловдан кейин банк чекни юкланг. Қайтариш алоҳида ҳисобланади: авиачипталар ва меҳмонхоналар аниқ тариф бошқача демаса, одатда қайтарилмайди; трансфер 120 соатгача тўлиқ қайтарилади, кейин $100 ушлаб қолинади; фойдаланилмаган iumrah хизматлари бошланишидан олдин қайтарилади.")
    }

    private static func footer(_ language: AppSettingsStore.Language) -> String {
        label(language,
              "Этот PDF сформирован из сохранённого снимка бронирования iumrah. Он не является банковской квитанцией. Подтверждением ручной оплаты служит загруженный банковский чек после его сверки с бронированием.",
              "This PDF is generated from the saved iumrah booking snapshot. It is not a bank receipt. Proof of manual payment is the uploaded bank receipt after it is reconciled with the booking.",
              "Ushbu PDF saqlangan iumrah bron ma’lumotlaridan yaratilgan. U bank cheki emas. Qo‘lda to‘lov tasdig‘i — bron bilan tekshirilgan yuklangan bank cheki.",
              "Ушбу PDF сақланган iumrah брон маълумотларидан яратилган. У банк чеки эмас. Қўлда тўлов тасдиғи — брон билан текширилган юкланган банк чеки.")
    }

    private static func label(_ language: AppSettingsStore.Language, _ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private func iumrahNonBlank(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

struct IumrahPaidReceiptCard: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let session: StoredBookingSession
    let checkout: IumrahCheckoutResponse
    let receipt: IumrahPaymentReceipt?

    @State private var shareURL: URL?
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 13) {
                IumrahIconBadge(
                    systemName: "checkmark.seal.fill",
                    role: .success,
                    size: 52,
                    symbolSize: 22,
                    cornerRadius: 17
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("Оплата подтверждена", "Payment confirmed", "To‘lov tasdiqlandi", "Тўлов тасдиқланди"))
                        .font(.headline)
                    Text(localized("Официальный чек iumrah закреплён за этой поездкой.", "Your official iumrah receipt stays attached to this trip.", "Rasmiy iumrah cheki ushbu safarga biriktirilgan.", "Расмий iumrah чеки ушбу сафарга бириктирилган."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("PAID")
                    .font(.caption2.monospaced().weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .overlay {
                        Capsule().strokeBorder(Color.green, lineWidth: 1.5)
                    }
                    .rotationEffect(.degrees(-6))
                    .accessibilityLabel(localized("Оплачено", "Paid", "To‘langan", "Тўланган"))
            }

            VStack(spacing: 10) {
                receiptFact(localized("Бронирование", "Booking", "Bron", "Брон"), session.displayBookingNumber)
                if let pilgrimID = session.displayPilgrimID ?? normalizedCheckoutID {
                    receiptFact("iumrah ID", pilgrimID)
                }
                receiptFact(localized("Плательщик", "Paid by", "To‘lovchi", "Тўловчи"), payerName)
                receiptFact(localized("Получатель", "Received by", "Qabul qiluvchi", "Қабул қилувчи"), recipientName)
                receiptFact(localized("Ответственное лицо", "Responsible person", "Mas’ul shaxs", "Масъул шахс"), "Aziz Kodirov")
                receiptFact(localized("Платформа", "Platform", "Platforma", "Платформа"), "iumrah platform")
                receiptFact(localized("Способ оплаты", "Payment method", "To‘lov usuli", "Тўлов усули"), paymentMethodTitle)
                receiptFact(localized("Дата оплаты", "Payment date", "To‘lov sanasi", "Тўлов санаси"), paymentDate)
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text(localized("Оплачено", "Paid", "To‘langan", "Тўланган"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(amountText)
                    .font(.system(size: 25, weight: .bold, design: .rounded).monospacedDigit())
            }

            HStack(spacing: 10) {
                Button { export(.pdf) } label: {
                    exportButtonLabel(
                        icon: "doc.richtext.fill",
                        title: localized("PDF", "PDF", "PDF", "PDF")
                    )
                }
                .buttonStyle(.plain)

                Button { export(.image) } label: {
                    exportButtonLabel(
                        icon: "photo.fill",
                        title: localized("Картинка", "Image", "Rasm", "Расм")
                    )
                }
                .buttonStyle(.plain)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(17)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.green.opacity(0.24), lineWidth: 0.9)
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL {
                IumrahFileShareSheet(url: shareURL)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private enum ExportKind { case pdf, image }

    private var normalizedCheckoutID: String? {
        let digits = checkout.iumrahID.filter(\.isNumber)
        guard !digits.isEmpty, digits.count <= 8 else { return nil }
        return String(repeating: "0", count: 8 - digits.count) + digits
    }

    private var payerName: String {
        guard let traveler = checkout.travelers.first else {
            return iumrahNonBlank(session.travelerName) ?? localized("Паломник", "Pilgrim", "Ziyoratchi", "Зиёратчи")
        }
        let value = [traveler.firstName, traveler.middleName, traveler.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return value.isEmpty ? (iumrahNonBlank(session.travelerName) ?? localized("Паломник", "Pilgrim", "Ziyoratchi", "Зиёратчи")) : value
    }

    private var paymentMethod: String {
        receipt?.paymentMethod.lowercased() ?? "confirmed"
    }

    private var paymentMethodTitle: String {
        switch paymentMethod {
        case "visa": return "Visa"
        case "humo": return "Humo"
        case "payme": return "PayMe"
        default: return localized("Подтверждено iumrah", "Confirmed by iumrah", "iumrah tomonidan tasdiqlangan", "iumrah томонидан тасдиқланган")
        }
    }

    private var recipientName: String {
        switch paymentMethod {
        case "humo":
            return iumrahNonBlank(checkout.payment.humoHolder) ?? "Aziz Kodirov"
        case "visa":
            return iumrahNonBlank(checkout.payment.visaHolder) ?? "Aziz Kodirov"
        default:
            return "Aziz Kodirov"
        }
    }

    private var paymentDate: String {
        let raw = receipt?.createdAt ?? session.paymentReceivedAt ?? session.booking.updatedAt
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: session.booking.totalUsd)) ?? String(format: "$%.0f", session.booking.totalUsd)
    }

    private func receiptFact(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 10)
            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func exportButtonLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
            Spacer(minLength: 0)
            Image(systemName: "square.and.arrow.up")
                .font(.caption.weight(.bold))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func export(_ kind: ExportKind) {
        do {
            switch kind {
            case .pdf:
                shareURL = try IumrahPaidReceiptRenderer.makePDF(
                    session: session,
                    checkout: checkout,
                    receipt: receipt,
                    language: settings.language
                )
            case .image:
                shareURL = try IumrahPaidReceiptRenderer.makeImage(
                    session: session,
                    checkout: checkout,
                    receipt: receipt,
                    language: settings.language
                )
            }
            errorText = nil
            IumrahHaptics.soft()
        } catch {
            errorText = localized("Не удалось создать чек. Попробуйте ещё раз.", "Could not create the receipt. Please try again.", "Chek yaratilmadi. Qayta urinib ko‘ring.", "Чек яратилмади. Қайта уриниб кўринг.")
            IumrahHaptics.error()
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

enum IumrahPaidReceiptRenderer {
    static func makePDF(
        session: StoredBookingSession,
        checkout: IumrahCheckoutResponse,
        receipt: IumrahPaymentReceipt?,
        language: AppSettingsStore.Language
    ) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let url = outputURL(session: session, ext: "pdf")
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            drawReceipt(in: page, session: session, checkout: checkout, receipt: receipt, language: language)
        }
        return url
    }

    static func makeImage(
        session: StoredBookingSession,
        checkout: IumrahCheckoutResponse,
        receipt: IumrahPaymentReceipt?,
        language: AppSettingsStore.Language
    ) throws -> URL {
        let size = CGSize(width: 1240, height: 1754)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            UIColor.systemBackground.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let scale = size.width / 595
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.saveGState()
            context.scaleBy(x: scale, y: scale)
            drawReceipt(in: CGRect(x: 0, y: 0, width: 595, height: size.height / scale), session: session, checkout: checkout, receipt: receipt, language: language)
            context.restoreGState()
        }
        guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        let url = outputURL(session: session, ext: "png")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func outputURL(session: StoredBookingSession, ext: String) -> URL {
        let safeNumber = session.displayBookingNumber.replacingOccurrences(of: "#", with: "")
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = root.appendingPathComponent("iumrah", isDirectory: true).appendingPathComponent("Receipts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("iumrah-paid-receipt-\(safeNumber.isEmpty ? session.id : safeNumber).\(ext)")
    }

    private static func drawReceipt(
        in page: CGRect,
        session: StoredBookingSession,
        checkout: IumrahCheckoutResponse,
        receipt: IumrahPaymentReceipt?,
        language: AppSettingsStore.Language
    ) {
        let left: CGFloat = 44
        let width = page.width - 88
        var y: CGFloat = 46

        UIColor.systemBackground.setFill()
        UIRectFill(page)

        draw("iumrah", rect: CGRect(x: left, y: y, width: 260, height: 40), font: .systemFont(ofSize: 30, weight: .bold), color: .label)
        draw(label(language, "Чек об оплате", "Payment Receipt", "To‘lov cheki", "Тўлов чеки"), rect: CGRect(x: left, y: y + 43, width: 320, height: 28), font: .systemFont(ofSize: 19, weight: .bold), color: .label)

        drawPaidStamp(x: page.width - 188, y: y + 8, language: language)
        y += 102

        let method = receipt?.paymentMethod.lowercased() ?? "confirmed"
        let payer = payerName(checkout: checkout, session: session, language: language)
        let recipient = recipientName(method: method, checkout: checkout)
        let paidDate = formattedDate(receipt?.createdAt ?? session.paymentReceivedAt ?? session.booking.updatedAt, language: language)
        let iumrahID = session.displayPilgrimID ?? normalizedID(checkout.iumrahID) ?? "—"

        drawSectionTitle(label(language, "Платёж", "Payment", "To‘lov", "Тўлов"), x: left, y: &y, width: width)
        drawKeyValue(label(language, "Бронирование", "Booking", "Bron", "Брон"), session.displayBookingNumber, x: left, y: &y, width: width)
        drawKeyValue("iumrah ID", iumrahID, x: left, y: &y, width: width)
        drawKeyValue(label(language, "Статус", "Status", "Holat", "Ҳолат"), label(language, "ОПЛАЧЕНО", "PAID", "TO‘LANGAN", "ТЎЛАНГАН"), x: left, y: &y, width: width, valueColor: .systemGreen)
        drawKeyValue(label(language, "Дата оплаты", "Payment date", "To‘lov sanasi", "Тўлов санаси"), paidDate, x: left, y: &y, width: width)
        drawKeyValue(label(language, "Способ оплаты", "Payment method", "To‘lov usuli", "Тўлов усули"), paymentMethodTitle(method, language: language), x: left, y: &y, width: width)

        y += 12
        drawSectionTitle(label(language, "Стороны", "Parties", "Tomonlar", "Томонлар"), x: left, y: &y, width: width)
        drawKeyValue(label(language, "Плательщик", "Paid by", "To‘lovchi", "Тўловчи"), payer, x: left, y: &y, width: width)
        drawKeyValue(label(language, "Получатель", "Received by", "Qabul qiluvchi", "Қабул қилувчи"), recipient, x: left, y: &y, width: width)
        drawKeyValue(label(language, "Платформа", "Platform", "Platforma", "Платформа"), "iumrah platform", x: left, y: &y, width: width)
        drawKeyValue(label(language, "Ответственное лицо", "Responsible person", "Mas’ul shaxs", "Масъул шахс"), "Aziz Kodirov", x: left, y: &y, width: width)

        y += 12
        drawSectionTitle(label(language, "Поездка", "Journey", "Safar", "Сафар"), x: left, y: &y, width: width)
        drawKeyValue(label(language, "Маршрут", "Route", "Yo‘nalish", "Йўналиш"), "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)", x: left, y: &y, width: width)
        drawKeyValue(label(language, "Даты", "Dates", "Sanalar", "Саналар"), "\(session.booking.input.startDate) — \(session.booking.input.endDate)", x: left, y: &y, width: width)
        drawKeyValue(label(language, "Паломники", "Pilgrims", "Ziyoratchilar", "Зиёратчилар"), "\(session.booking.input.travelers.totalPeople)", x: left, y: &y, width: width)

        y += 18
        drawDivider(x: left, y: y, width: width)
        y += 20
        draw(label(language, "ИТОГО ОПЛАЧЕНО", "TOTAL PAID", "JAMI TO‘LANDI", "ЖАМИ ТЎЛАНДИ"), rect: CGRect(x: left, y: y, width: width * 0.55, height: 30), font: .systemFont(ofSize: 13, weight: .bold), color: .secondaryLabel)
        draw(currency(session.booking.totalUsd), rect: CGRect(x: left + width * 0.55, y: y - 4, width: width * 0.45, height: 38), font: .monospacedDigitSystemFont(ofSize: 26, weight: .bold), color: .label, alignment: .right)
        y += 64

        let note = label(
            language,
            "Этот чек сформирован iumrah после подтверждения оплаты и закреплён за бронированием. Документы поездки и авиабилеты появляются в статусе бронирования по мере готовности.",
            "This receipt is generated by iumrah after payment confirmation and remains attached to the booking. Travel documents and airline tickets appear in Booking Status as they become ready.",
            "Ushbu chek to‘lov tasdiqlangach iumrah tomonidan yaratiladi va bronga biriktiriladi. Safar hujjatlari hamda aviachiptalar tayyor bo‘lishi bilan Bron holatida paydo bo‘ladi.",
            "Ушбу чек тўлов тасдиқлангач iumrah томонидан яратилади ва бронга бириктирилади. Сафар ҳужжатлари ҳамда авиачипталар тайёр бўлиши билан Брон ҳолатида пайдо бўлади."
        )
        draw(note, rect: CGRect(x: left, y: y, width: width, height: 80), font: .systemFont(ofSize: 10.5), color: .secondaryLabel)

        let footer = "iumrah.app  •  \(session.displayBookingNumber)"
        draw(footer, rect: CGRect(x: left, y: page.height - 58, width: width, height: 20), font: .monospacedSystemFont(ofSize: 9, weight: .medium), color: .tertiaryLabel, alignment: .center)
    }

    private static func drawPaidStamp(x: CGFloat, y: CGFloat, language: AppSettingsStore.Language) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.translateBy(x: x + 62, y: y + 27)
        context.rotate(by: -.pi / 28)
        context.translateBy(x: -(x + 62), y: -(y + 27))
        let rect = CGRect(x: x, y: y, width: 124, height: 54)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 27)
        UIColor.systemGreen.setStroke()
        path.lineWidth = 2.1
        path.stroke()
        draw(label(language, "ОПЛАЧЕНО", "PAID", "TO‘LANGAN", "ТЎЛАНГАН"), rect: rect.insetBy(dx: 7, dy: 15), font: .monospacedSystemFont(ofSize: 12, weight: .black), color: .systemGreen, alignment: .center)
        context.restoreGState()
    }

    private static func drawSectionTitle(_ text: String, x: CGFloat, y: inout CGFloat, width: CGFloat) {
        draw(text.uppercased(), rect: CGRect(x: x, y: y, width: width, height: 20), font: .systemFont(ofSize: 10.5, weight: .bold), color: .secondaryLabel)
        y += 27
    }

    private static func drawKeyValue(_ key: String, _ value: String, x: CGFloat, y: inout CGFloat, width: CGFloat, valueColor: UIColor = .label) {
        draw(key, rect: CGRect(x: x, y: y, width: width * 0.40, height: 22), font: .systemFont(ofSize: 11, weight: .medium), color: .secondaryLabel)
        draw(value, rect: CGRect(x: x + width * 0.40, y: y, width: width * 0.60, height: 22), font: .systemFont(ofSize: 11, weight: .semibold), color: valueColor, alignment: .right)
        y += 26
    }

    private static func drawDivider(x: CGFloat, y: CGFloat, width: CGFloat) {
        UIColor.separator.setFill()
        UIRectFill(CGRect(x: x, y: y, width: width, height: 0.7))
    }

    private static func draw(_ text: String, rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]).draw(in: rect)
    }

    private static func payerName(checkout: IumrahCheckoutResponse, session: StoredBookingSession, language: AppSettingsStore.Language) -> String {
        if let traveler = checkout.travelers.first {
            let name = [traveler.firstName, traveler.middleName, traveler.lastName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !name.isEmpty { return name }
        }
        if let name = iumrahNonBlank(session.travelerName) { return name }
        return label(language, "Паломник", "Pilgrim", "Ziyoratchi", "Зиёратчи")
    }

    private static func recipientName(method: String, checkout: IumrahCheckoutResponse) -> String {
        switch method {
        case "humo": return iumrahNonBlank(checkout.payment.humoHolder) ?? "Aziz Kodirov"
        case "visa": return iumrahNonBlank(checkout.payment.visaHolder) ?? "Aziz Kodirov"
        default: return "Aziz Kodirov"
        }
    }

    private static func paymentMethodTitle(_ method: String, language: AppSettingsStore.Language) -> String {
        switch method {
        case "visa": return "Visa"
        case "humo": return "Humo"
        case "payme": return "PayMe"
        default: return label(language, "Подтверждено iumrah", "Confirmed by iumrah", "iumrah tomonidan tasdiqlangan", "iumrah томонидан тасдиқланган")
        }
    }

    private static func formattedDate(_ raw: String, language: AppSettingsStore.Language) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func normalizedID(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty, digits.count <= 8 else { return nil }
        return String(repeating: "0", count: 8 - digits.count) + digits
    }

    private static func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.0f", value)
    }

    private static func label(_ language: AppSettingsStore.Language, _ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}
