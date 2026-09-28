import SwiftUI

struct BookingStatusView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore

    let bookingID: String

    @State private var checkout: IumrahCheckoutResponse?
    @State private var isRefreshing = false

    private let accountService = IumrahAccountService()

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        Group {
            if let session {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        statusHero(session)
                        progressCard(session)
                        actionCard(session)
                        bookingSummary(session)
                    }
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .padding(.top, 14)
                    .padding(.bottom, 48)
                }
                .refreshable { await refresh(session) }
            } else {
                ContentUnavailableView(
                    localized("Бронирование не найдено", "Booking not found", "Bron topilmadi", "Брон топилмади"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(localized(
                        "Обновите список поездок и попробуйте снова.",
                        "Refresh your trips and try again.",
                        "Safarlar ro‘yxatini yangilang va qayta urinib ko‘ring.",
                        "Сафарлар рўйхатини янгиланг ва қайта уриниб кўринг."
                    ))
                )
            }
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(localized("Статус бронирования", "Booking status", "Bron holati", "Брон ҳолати"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: bookingID) {
            guard let session else { return }
            await refresh(session)
        }
    }

    private func statusHero(_ session: StoredBookingSession) -> some View {
        let visual = visualState(session)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: visual.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(visual.tint)
                    .frame(width: 54, height: 54)
                    .iumrahGlass(
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        allowsStaticGlass: true,
                        tint: visual.tint.opacity(0.08),
                        chrome: true
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(visual.title)
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .tracking(-0.65)
                    Text(visual.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }

            HStack(spacing: 8) {
                Label(session.displayBookingNumber, systemImage: "number")
                if let pilgrimID = session.displayPilgrimID, !pilgrimID.isEmpty {
                    Label(pilgrimID, systemImage: "person.text.rectangle")
                }
            }
            .font(.caption.monospaced().weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(visual.tint.opacity(0.16), lineWidth: 0.8)
        }
    }

    private func progressCard(_ session: StoredBookingSession) -> some View {
        let current = currentStageIndex(session.effectiveStatus)
        return VStack(alignment: .leading, spacing: 16) {
            Text(localized("Этапы поездки", "Trip progress", "Safar bosqichlari", "Сафар босқичлари"))
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    HStack(alignment: .top, spacing: 13) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(index <= current ? stage.tint : Color.iumrahRaisedBackground)
                                    .frame(width: 32, height: 32)
                                Image(systemName: index < current ? "checkmark" : stage.icon)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(index <= current ? Color.white : Color.secondary)
                            }
                            if index < stages.count - 1 {
                                Rectangle()
                                    .fill(index < current ? stage.tint.opacity(0.45) : Color.secondary.opacity(0.16))
                                    .frame(width: 2, height: 36)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(stage.title)
                                .font(.subheadline.weight(index == current ? .bold : .semibold))
                                .foregroundStyle(index <= current ? Color.primary : Color.secondary)
                            Text(stage.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    @ViewBuilder
    private func actionCard(_ session: StoredBookingSession) -> some View {
        let status = session.effectiveStatus.uppercased()
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localized("Что делать сейчас", "What to do now", "Hozir nima qilish kerak", "Ҳозир нима қилиш керак"))
                    .font(.headline)
                Spacer()
                if isRefreshing { ProgressView().controlSize(.small) }
            }

            if ["NEW", "AVAILABILITY_CHECK"].contains(status) {
                Text(localized(
                    "iumrah проверяет наличие. Пока идёт проверка, Вы можете заранее заполнить данные паломников.",
                    "iumrah is checking availability. You can complete pilgrim details while the check continues.",
                    "iumrah mavjudlikni tekshirmoqda. Tekshiruv davomida ziyoratchilar ma’lumotlarini oldindan to‘ldirishingiz mumkin.",
                    "iumrah мавжудликни текширмоқда. Текширув давомида зиёратчилар маълумотларини олдиндан тўлдиришингиз мумкин."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

                NavigationLink {
                    PilgrimCheckoutView(bookingID: session.id, presentation: .screen)
                } label: {
                    primaryActionLabel(localized("Заполнить данные паломников", "Complete pilgrim details", "Ziyoratchilar ma’lumotlarini to‘ldirish", "Зиёратчилар маълумотларини тўлдириш"))
                }
                .buttonStyle(.plain)
            } else if status == "PAYMENT_PENDING" {
                Text(localized(
                    "Наличие подтверждено. Проверьте личность, данные паломников и перейдите к оплате.",
                    "Availability is confirmed. Verify identity, review pilgrim details and continue to payment.",
                    "Mavjudlik tasdiqlandi. Shaxsni va ziyoratchilar ma’lumotlarini tekshirib, to‘lovga o‘ting.",
                    "Мавжудлик тасдиқланди. Шахсни ва зиёратчилар маълумотларини текшириб, тўловга ўтинг."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

                NavigationLink { IumrahSecurityConfirmationView(bookingID: session.id) } label: {
                    primaryActionLabel(localized("Подтвердить личность", "Verify identity", "Shaxsni tasdiqlash", "Шахсни тасдиқлаш"))
                }
                .buttonStyle(.plain)

                NavigationLink { PilgrimCheckoutView(bookingID: session.id, presentation: .screen) } label: {
                    secondaryActionLabel(localized("Данные и оплата", "Details and payment", "Ma’lumotlar va to‘lov", "Маълумотлар ва тўлов"))
                }
                .buttonStyle(.plain)
            } else {
                Text(localized(
                    "Статус обновляется автоматически. Все подтверждённые компоненты доступны внутри бронирования.",
                    "Status updates automatically. All confirmed components are available inside the booking.",
                    "Holat avtomatik yangilanadi. Tasdiqlangan barcha qismlar bron ichida mavjud.",
                    "Ҳолат автоматик янгиланади. Тасдиқланган барча қисмлар брон ичида мавжуд."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

                NavigationLink { BookingDetailView(bookingID: session.id) } label: {
                    primaryActionLabel(localized("Открыть бронирование", "Open booking", "Bronni ochish", "Бронни очиш"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    private func bookingSummary(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("Поездка", "Trip", "Safar", "Сафар"))
                .font(.headline)
            summaryRow(localized("Маршрут", "Route", "Yo‘nalish", "Йўналиш"), "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
            summaryRow(localized("Даты", "Dates", "Sanalar", "Саналар"), "\(L10n.date(session.booking.input.startDate, settings.language)) — \(L10n.date(session.booking.input.endDate, settings.language))")
            summaryRow(localized("Паломники", "Pilgrims", "Ziyoratchilar", "Зиёратчилар"), "\(session.booking.input.travelers.totalPeople)")
            summaryRow(localized("Пакет", "Package", "Paket", "Пакет"), money(session.booking.totalUsd))
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7) }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func primaryActionLabel(_ title: String) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "arrow.right").font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func secondaryActionLabel(_ title: String) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "arrow.right").font(.caption.weight(.bold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @MainActor
    private func refresh(_ session: StoredBookingSession) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await bookings.refreshAll()
        // Checkout is enrichment only. Authorization failures must never replace the
        // booking-status UI with a raw server error; the operational status is already
        // part of the stored trip snapshot and remains the source of truth for display.
        checkout = try? await accountService.checkout(
            bookingID: session.id,
            bookingToken: session.accessToken,
            accountToken: account.bearerToken
        )
    }

    private struct StageItem {
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
    }

    private var stages: [StageItem] {
        [
            StageItem(title: localized("Пакет создан", "Package created", "Paket yaratildi", "Пакет яратилди"), subtitle: localized("Поездка добавлена в iumrah", "Trip added to iumrah", "Safar iumrah’ga qo‘shildi", "Сафар iumrah’га қўшилди"), icon: "plus", tint: .blue),
            StageItem(title: localized("Проверка наличия", "Availability check", "Mavjudlik tekshiruvi", "Мавжудлик текшируви"), subtitle: localized("Проверяем перелёт, отель и услуги", "Checking flight, hotel and services", "Parvoz, mehmonxona va xizmatlar tekshirilmoqda", "Парвоз, меҳмонхона ва хизматлар текширилмоқда"), icon: "hourglass", tint: .cyan),
            StageItem(title: localized("Оплата и данные", "Payment and details", "To‘lov va ma’lumotlar", "Тўлов ва маълумотлар"), subtitle: localized("Требуется действие", "Action required", "Amal kerak", "Амал керак"), icon: "creditcard.fill", tint: .orange),
            StageItem(title: localized("Бронь подтверждена", "Booking confirmed", "Bron tasdiqlandi", "Брон тасдиқланди"), subtitle: localized("Компоненты закреплены", "Components secured", "Qismlar band qilindi", "Қисмлар банд қилинди"), icon: "checkmark.seal.fill", tint: .green),
            StageItem(title: localized("Документы готовы", "Documents ready", "Hujjatlar tayyor", "Ҳужжатлар тайёр"), subtitle: localized("Всё готово к поездке", "Ready for travel", "Safarga tayyor", "Сафарга тайёр"), icon: "doc.text.fill", tint: .purple),
            StageItem(title: localized("Паломник в поездке", "Pilgrim traveling", "Ziyoratchi safarda", "Зиёратчи сафарда"), subtitle: localized("Маршрут активен", "Journey is active", "Safar faol", "Сафар фаол"), icon: "location.fill", tint: .blue),
            StageItem(title: localized("Поездка завершена", "Trip completed", "Safar yakunlandi", "Сафар якунланди"), subtitle: localized("История сохранена", "History saved", "Tarix saqlandi", "Тарих сақланди"), icon: "checkmark.circle.fill", tint: .green)
        ]
    }

    private func currentStageIndex(_ status: String) -> Int {
        switch status.uppercased() {
        case "NEW": return 0
        case "AVAILABILITY_CHECK": return 1
        case "PAYMENT_PENDING": return 2
        case "PAID", "BOOKING_CONFIRMED": return 3
        case "DOCUMENTS_READY", "READY_TO_TRAVEL": return 4
        case "IN_TRIP": return 5
        case "COMPLETED": return 6
        case "CANCELLED": return 0
        default: return 0
        }
    }

    private func visualState(_ session: StoredBookingSession) -> (title: String, subtitle: String, icon: String, tint: Color) {
        let index = currentStageIndex(session.effectiveStatus)
        let stage = stages[index]
        if session.effectiveStatus.uppercased() == "CANCELLED" {
            return (
                localized("Бронирование отменено", "Booking cancelled", "Bron bekor qilingan", "Брон бекор қилинган"),
                localized("Поездка сохранена в истории.", "The trip remains in history.", "Safar tarixda saqlanadi.", "Сафар тарихда сақланади."),
                "xmark.circle.fill",
                .red
            )
        }
        return (stage.title, stage.subtitle, stage.icon, stage.tint)
    }

    private func money(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return "\(formatter.string(from: NSNumber(value: amount)) ?? String(Int(amount.rounded()))) US$"
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}
