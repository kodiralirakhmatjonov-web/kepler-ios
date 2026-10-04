import SwiftUI

private enum BookingIncludedServiceDetail: String, Identifiable {
    case transfer
    case guide
    case ziyarats
    case esim
    case care
    case meals

    var id: String { rawValue }
}

struct BookingFlightFirstComponentsView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let session: StoredBookingSession
    let onChangeMakkahHotel: () -> Void
    let onChangeMadinahHotel: () -> Void

    @State private var serviceDetail: BookingIncludedServiceDetail?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let outbound = session.outboundFlight {
                SectionHeader(flightsTitle, eyebrow: "iumrah Flights", subtitle: nil)
                BookingFlightFirstLegCard(
                    flight: outbound,
                    direction: outboundTitle,
                    language: settings.language
                )
            }

            if let inbound = session.inboundFlight {
                BookingFlightFirstLegCard(
                    flight: inbound,
                    direction: returnTitle,
                    language: settings.language
                )
            }

            if session.hotelSelection != nil || session.madinahHotelSelection != nil {
                SectionHeader(hotelsTitle, eyebrow: "iumrah Hotels", subtitle: nil)

                if let makkah = session.hotelSelection {
                    BookingFlightFirstHotelCard(
                        hotel: makkah,
                        nights: session.booking.stay.makkahNights,
                        language: settings.language,
                        onOpen: onChangeMakkahHotel
                    )
                }

                if let madinah = session.madinahHotelSelection {
                    BookingFlightFirstHotelCard(
                        hotel: madinah,
                        nights: session.booking.stay.madinahNights ?? 0,
                        language: settings.language,
                        onOpen: onChangeMadinahHotel
                    )
                }
            }

            SectionHeader(includedTitle, eyebrow: "iumrah", subtitle: nil)
            includedServicesCard
        }
        .sheet(item: $serviceDetail) { detail in
            if detail == .ziyarats {
                ZiyaratIncludedCatalogSheet()
                    .environmentObject(settings)
            } else {
                BookingIncludedServiceDetailSheet(
                    detail: detail,
                    session: session,
                    language: settings.language
                )
            }
        }
    }

    private var includedServicesCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                IumrahGuideTransferView(bookingID: session.id)
            } label: {
                guideTransferFeatureCard
            }
            .buttonStyle(.plain)

            if session.ziyaratMakkahEnabled || session.ziyaratMadinahEnabled {
                Divider().padding(.leading, 58)
                includedRow(
                    detail: .ziyarats,
                    icon: "map.fill",
                    title: localized("Зияраты", "Ziyarats", "Ziyoratlar", "Зиёратлар"),
                    subtitle: ziyaratSubtitle
                )
            }

            if session.esimEnabled {
                Divider().padding(.leading, 58)
                includedRow(
                    detail: .esim,
                    icon: "simcard.fill",
                    title: "iumrah eSIM",
                    subtitle: localized("Связь в Саудовской Аравии внутри поездки", "Connectivity in Saudi Arabia inside your trip", "Saudiya Arabistonida safar ichidagi aloqa", "Саудия Арабистонида сафар ичидаги алоқа")
                )
            }

            Divider().padding(.leading, 58)
            includedRow(
                detail: .care,
                icon: "heart.fill",
                title: "iumrah Care",
                subtitle: localized("Поддержка по поездке и бронированию", "Trip and booking support", "Safar va bron bo‘yicha yordam", "Сафар ва брон бўйича ёрдам")
            )

            if session.booking.customization?.meals == true {
                Divider().padding(.leading, 58)
                includedRow(
                    detail: .meals,
                    icon: "fork.knife",
                    title: localized("Питание", "Meals", "Ovqatlanish", "Овқатланиш"),
                    subtitle: localized("Включено по выбранной категории пакета", "Included according to your package category", "Tanlangan paket toifasi bo‘yicha kiritilgan", "Танланган пакет тоифаси бўйича киритилган")
                )
            }
        }
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    private var guideTransferFeatureCard: some View {
        HStack(spacing: 14) {
            ZStack {
                IumrahIconBadge(systemName: "person.2.fill", role: .profile, size: 54, symbolSize: 21, cornerRadius: 18)
                Image(systemName: "car.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 23, height: 23)
                    .background(Color(uiColor: .systemBlue), in: Circle())
                    .offset(x: 21, y: 20)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(localized("Ваш гид и трансфер в Саудовской Аравии", "Your guide & transfer in Saudi Arabia", "Saudiya Arabistonidagi gid va transferingiz", "Саудия Арабистонидаги гид ва трансферингиз"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(localized(
                    "Команда встречи, выбранный автомобиль и полный маршрут сопровождения",
                    "Meeting team, selected vehicle and your full support route",
                    "Kutib olish jamoasi, tanlangan avtomobil va to‘liq hamrohlik yo‘nalishi",
                    "Кутиб олиш жамоаси, танланган автомобиль ва тўлиқ ҳамроҳлик йўналиши"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
        }
        .padding(10)
    }

    private func includedRow(
        detail: BookingIncludedServiceDetail,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            IumrahHaptics.selection()
            serviceDetail = detail
        } label: {
            HStack(spacing: 14) {
                IumrahIconBadge(
                    systemName: icon,
                    role: role(for: icon),
                    size: 44,
                    symbolSize: 17,
                    cornerRadius: 15
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func role(for icon: String) -> IumrahIconRole {
        if icon.contains("car") { return .transfer }
        if icon.contains("simcard") { return .connectivity }
        if icon.contains("heart") { return .care }
        if icon.contains("map") { return .location }
        if icon.contains("person") { return .profile }
        return .umrah
    }

    private var flightsTitle: String { localized("Авиабилеты", "Flights", "Aviachiptalar", "Авиачипталар") }
    private var hotelsTitle: String { localized("Отели", "Hotels", "Mehmonxonalar", "Меҳмонхоналар") }
    private var includedTitle: String { localized("Что включено", "What's included", "Nimalar kiradi", "Нималар киради") }
    private var outboundTitle: String { localized("Туда", "Outbound", "Borish", "Бориш") }
    private var returnTitle: String { localized("Обратно", "Return", "Qaytish", "Қайтиш") }

    private var guideSubtitle: String {
        if let guide = session.guide?.displayName, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localized("Гид: \(guide)", "Guide: \(guide)", "Gid: \(guide)", "Гид: \(guide)")
        }
        return localized("Сопровождение и координация поездки", "Journey guidance and coordination", "Safarni kuzatish va muvofiqlashtirish", "Сафарни кузатиш ва мувофиқлаштириш")
    }

    private var ziyaratSubtitle: String {
        var cities: [String] = []
        if session.ziyaratMakkahEnabled { cities.append(L10n.city("Makkah", settings.language)) }
        if session.ziyaratMadinahEnabled { cities.append(L10n.city("Madinah", settings.language)) }
        return cities.joined(separator: " · ")
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

private struct BookingIncludedServiceDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let detail: BookingIncludedServiceDetail
    let session: StoredBookingSession
    let language: AppSettingsStore.Language

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    VStack(spacing: 12) {
                        ForEach(Array(detailRows.enumerated()), id: \.offset) { _, row in
                            detailRow(icon: row.icon, title: row.title, body: row.body)
                        }
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(closeText)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            IumrahIconBadge(
                systemName: symbol,
                role: role,
                size: 54,
                symbolSize: 22,
                cornerRadius: 18
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    private func detailRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(role.color)
                .frame(width: 38, height: 38)
                .background(role.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var title: String {
        switch detail {
        case .transfer: return localized("Трансфер по маршруту", "Route transfer", "Yo‘nalish transferi", "Йўналиш трансфери")
        case .guide: return localized("Ваш гид", "Your guide", "Sizning gidingiz", "Сизнинг гидингиз")
        case .ziyarats: return localized("Зияраты", "Ziyarats", "Ziyoratlar", "Зиёратлар")
        case .esim: return "iumrah eSIM"
        case .care: return "iumrah Care"
        case .meals: return localized("Питание", "Meals", "Ovqatlanish", "Овқатланиш")
        }
    }

    private var subtitle: String {
        switch detail {
        case .transfer:
            return localized("Переезды привязаны к реальному маршруту поездки.", "Transfers follow your actual journey route.", "Transferlar haqiqiy safar yo‘nalishiga bog‘langan.", "Трансферлар ҳақиқий сафар йўналишига боғланган.")
        case .guide:
            let name = session.guide?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty
                ? localized("Сопровождение и координация Умры.", "Guidance and Umrah coordination.", "Umra bo‘yicha hamrohlik va muvofiqlashtirish.", "Умра бўйича ҳамроҳлик ва мувофиқлаштириш.")
                : localized("Ваш гид: \(name)", "Your guide: \(name)", "Gidingiz: \(name)", "Гидингиз: \(name)")
        case .ziyarats:
            return localized("Программа зияратов по включённым городам.", "Ziyarat program for the included cities.", "Kiritilgan shaharlardagi ziyorat dasturi.", "Киритилган шаҳарлардаги зиёрат дастури.")
        case .esim:
            return localized("Связь во время поездки в Саудовской Аравии.", "Connectivity during your Saudi Arabia journey.", "Saudiya Arabistonidagi safar davomida aloqa.", "Саудия Арабистонидаги сафар давомида алоқа.")
        case .care:
            return localized("Поддержка по брони, перелётам, отелям и маршруту.", "Support for booking, flights, hotels and itinerary.", "Bron, parvoz, mehmonxona va yo‘nalish bo‘yicha yordam.", "Брон, парвоз, меҳмонхона ва йўналиш бўйича ёрдам.")
        case .meals:
            return localized("Питание по выбранной категории пакета.", "Meals according to the selected package category.", "Tanlangan paket toifasi bo‘yicha ovqatlanish.", "Танланган пакет тоифаси бўйича овқатланиш.")
        }
    }

    private var detailRows: [(icon: String, title: String, body: String)] {
        switch detail {
        case .transfer:
            return [
                ("airplane.arrival", localized("Встреча после прилёта", "Arrival pickup", "Kelishdan keyin kutib olish", "Келишдан кейин кутиб олиш"), localized("Трансфер координируется по фактическому рейсу и маршруту бронирования.", "The transfer is coordinated around the actual flight and booking itinerary.", "Transfer haqiqiy reys va bron yo‘nalishi bo‘yicha muvofiqlashtiriladi.", "Трансфер ҳақиқий рейс ва брон йўналиши бўйича мувофиқлаштирилади.")),
                ("building.2", localized("Отели и ключевые точки", "Hotels and key points", "Mehmonxonalar va asosiy nuqtalar", "Меҳмонхоналар ва асосий нуқталар"), localized("Переезды между аэропортом, отелями и основными точками поездки входят в программу.", "Transfers between the airport, hotels and key journey points are part of the program.", "Aeroport, mehmonxonalar va asosiy safar nuqtalari orasidagi transferlar dasturga kiradi.", "Аэропорт, меҳмонхоналар ва асосий сафар нуқталари орасидаги трансферлар дастурга киради."))
            ]
        case .guide:
            return [
                ("person.2.fill", localized("Сопровождение", "Guidance", "Hamrohlik", "Ҳамроҳлик"), localized("Гид помогает ориентироваться по этапам поездки и Умры.", "Your guide helps you navigate the journey and Umrah stages.", "Gid safar va Umra bosqichlarida yo‘l-yo‘riq beradi.", "Гид сафар ва Умра босқичларида йўл-йўриқ беради.")),
                ("message.fill", localized("Связь", "Contact", "Aloqa", "Алоқа"), localized("Контакт и актуальные инструкции доступны внутри бронирования.", "Contact and current instructions are available inside the booking.", "Aloqa va joriy ko‘rsatmalar bron ichida mavjud.", "Алоқа ва жорий кўрсатмалар брон ичида мавжуд."))
            ]
        case .ziyarats:
            var rows: [(String,String,String)] = []
            if session.ziyaratMakkahEnabled {
                rows.append(("mappin.and.ellipse", L10n.city("Makkah", language), localized("Зияраты в Мекке включены в Вашу программу.", "Makkah ziyarats are included in your program.", "Makkadagi ziyoratlar dasturingizga kiritilgan.", "Маккадаги зиёратлар дастурингизга киритилган.")))
            }
            if session.ziyaratMadinahEnabled {
                rows.append(("mappin.and.ellipse", L10n.city("Madinah", language), localized("Зияраты в Медине включены в Вашу программу.", "Madinah ziyarats are included in your program.", "Madinadagi ziyoratlar dasturingizga kiritilgan.", "Мадинадаги зиёратлар дастурингизга киритилган.")))
            }
            return rows
        case .esim:
            return [
                ("simcard.fill", localized("Связь в поездке", "Trip connectivity", "Safardagi aloqa", "Сафардаги алоқа"), localized("eSIM предназначена для использования во время поездки в Саудовской Аравии.", "The eSIM is intended for use during your Saudi Arabia journey.", "eSIM Saudiya Arabistonidagi safar davomida foydalanish uchun mo‘ljallangan.", "eSIM Саудия Арабистонидаги сафар давомида фойдаланиш учун мўлжалланган.")),
                ("iphone", localized("Активация", "Activation", "Faollashtirish", "Фаоллаштириш"), localized("Инструкции активации появятся в документах поездки, когда они будут готовы.", "Activation instructions will appear in trip documents when ready.", "Faollashtirish ko‘rsatmalari tayyor bo‘lganda safar hujjatlarida paydo bo‘ladi.", "Фаоллаштириш кўрсатмалари тайёр бўлганда сафар ҳужжатларида пайдо бўлади."))
            ]
        case .care:
            return [
                ("heart.fill", localized("Помощь по брони", "Booking help", "Bron bo‘yicha yordam", "Брон бўйича ёрдам"), localized("iumrah Care видит контекст поездки и помогает без повторного объяснения всей брони.", "iumrah Care sees your trip context so you do not need to explain the whole booking again.", "iumrah Care safar kontekstini ko‘radi, shuning uchun bronni qayta tushuntirish shart emas.", "iumrah Care сафар контекстини кўради, шунинг учун бронни қайта тушунтириш шарт эмас.")),
                ("airplane", localized("Рейсы, отели и маршрут", "Flights, hotels and itinerary", "Parvoz, mehmonxona va yo‘nalish", "Парвоз, меҳмонхона ва йўналиш"), localized("Поддержка связана с компонентами именно этой поездки.", "Support is tied to the components of this exact journey.", "Yordam aynan shu safar komponentlariga bog‘langan.", "Ёрдам айнан шу сафар компонентларига боғланган."))
            ]
        case .meals:
            return [
                ("fork.knife", localized("По программе пакета", "According to package", "Paket dasturi bo‘yicha", "Пакет дастури бўйича"), localized("Конкретные приёмы пищи и формат зависят от выбранной категории и подтверждённых отелей.", "Specific meals and format depend on the selected package tier and confirmed hotels.", "Aniq ovqatlar va format tanlangan paket toifasi hamda tasdiqlangan mehmonxonalarga bog‘liq.", "Аниқ овқатлар ва формат танланган пакет тоифаси ҳамда тасдиқланган меҳмонхоналарга боғлиқ."))
            ]
        }
    }

    private var symbol: String {
        switch detail {
        case .transfer: return "car.fill"
        case .guide: return "person.badge.shield.checkmark.fill"
        case .ziyarats: return "map.fill"
        case .esim: return "simcard.fill"
        case .care: return "heart.fill"
        case .meals: return "fork.knife"
        }
    }

    private var role: IumrahIconRole {
        switch detail {
        case .transfer: return .transfer
        case .guide: return .profile
        case .ziyarats: return .location
        case .esim: return .connectivity
        case .care: return .care
        case .meals: return .umrah
        }
    }

    private var closeText: String {
        localized("Закрыть", "Close", "Yopish", "Ёпиш")
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private struct BookingFlightFirstLegCard: View {
    let flight: FlightOffer
    let direction: String
    let language: AppSettingsStore.Language
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                    expanded.toggle()
                }
                IumrahHaptics.selection()
            } label: {
                HStack(spacing: 14) {
                    AirlineLogoView(airlineCode: flight.airlineCode, size: 50)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(direction.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("\(flight.origin) → \(flight.destination)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(flight.airline) · \(flight.flightNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("\(day(flight.departureAt)) · \(clock(flight.departureAt))")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 6) {
                        Image(systemName: "airplane")
                            .font(.headline)
                            .foregroundStyle(IumrahIconRole.travel.color)
                        Text(directText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.vertical, 14)
                VStack(spacing: 11) {
                    fact(localized("Аэропорт вылета", "Departure airport", "Jo‘nash aeroporti", "Жўнаш аэропорти"), airportText(flight.origin))
                    fact(localized("Аэропорт прилёта", "Arrival airport", "Yetib borish aeroporti", "Етиб бориш аэропорти"), airportText(flight.destination))
                    fact(localized("Вылет", "Departure", "Jo‘nash", "Жўнаш"), fullDateTime(flight.departureAt))
                    fact(localized("Прилёт", "Arrival", "Yetib kelish", "Етиб келиш"), fullDateTime(flight.arrivalAt))
                    fact(localized("В пути", "Duration", "Yo‘lda", "Йўлда"), durationText(flight.durationMinutes))
                    fact(localized("Класс", "Cabin", "Klass", "Класс"), nonBlank(flight.cabinClass)?.capitalized ?? "—")
                    fact(localized("Багаж", "Baggage", "Bagaj", "Багаж"), baggageText)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .iumrahCard()
    }

    private func nonBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func fact(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
        }
    }

    private var directText: String {
        switch language {
        case .russian: return flight.stops == 0 ? "прямой" : "\(flight.stops) пересад."
        case .english: return flight.stops == 0 ? "direct" : "\(flight.stops) stops"
        case .uzbek: return flight.stops == 0 ? "to‘g‘ridan-to‘g‘ri" : "\(flight.stops) ulanish"
        case .uzbekCyrillic: return flight.stops == 0 ? "тўғридан-тўғри" : "\(flight.stops) уланиш"
        }
    }

    private var baggageText: String {
        guard let baggage = flight.baggage else { return "—" }
        var parts: [String] = []
        if let carry = baggage.carryOn { parts.append("\(carry) kg") }
        if let checked = baggage.checked { parts.append("\(checked) kg") }
        return parts.isEmpty ? "—" : parts.joined(separator: " + ")
    }

    private func airportText(_ code: String) -> String {
        if let airport = FlightReferenceCatalog.airport(code) {
            return "\(airport.city) · \(airport.name) · \(code.uppercased())"
        }
        return code.uppercased()
    }

    private func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func fullDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy HH:mm")
        return formatter.string(from: date)
    }

    private func durationText(_ minutes: Int) -> String {
        let h = max(0, minutes) / 60
        let m = max(0, minutes) % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct BookingFlightFirstHotelCard: View {
    let hotel: BookingHotelSelectionSnapshot
    let nights: Int
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onOpen()
        } label: {
            GeometryReader { proxy in
                let mediaWidth = min(max(proxy.size.width * 0.31, 108), 124)
                HStack(spacing: 0) {
                    ZStack {
                        if let imageURL = nonBlank(hotel.coverImageURL) {
                            HotelCachedImage(rawURL: imageURL)
                                .frame(width: mediaWidth, height: 150)
                        } else {
                            Color.iumrahRaisedBackground
                                .overlay {
                                    Image(systemName: "building.2.fill")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: mediaWidth, height: 150)
                    .clipped()

                    VStack(alignment: .leading, spacing: 7) {
                        Text(hotel.hotelName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(L10n.city(hotel.city, language))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Label(nightsText, systemImage: "moon.stars.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        HStack(spacing: 6) {
                            Image(systemName: "bed.double.fill")
                                .font(.caption)
                            Text(nonBlank(hotel.roomName) ?? chooseRoomText)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(nonBlank(hotel.roomName) == nil ? Color.secondary : Color.primary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(width: proxy.size.width, height: 150)
            }
            .frame(height: 150)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
    }

    private var nightsText: String {
        switch language {
        case .russian: return "\(nights) ноч."
        case .english: return "\(nights) nights"
        case .uzbek: return "\(nights) tun"
        case .uzbekCyrillic: return "\(nights) тун"
        }
    }

    private var chooseRoomText: String {
        switch language {
        case .russian: return "Открыть отель"
        case .english: return "Open hotel"
        case .uzbek: return "Mehmonxonani ochish"
        case .uzbekCyrillic: return "Меҳмонхонани очиш"
        }
    }

    private func nonBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension StoredBookingSession {
    var ziyaratMakkahEnabled: Bool {
        ziyaratMakkahOverride ?? booking.customization?.ziyaratMakkah ?? false
    }

    var ziyaratMadinahEnabled: Bool {
        ziyaratMadinahOverride ?? booking.customization?.ziyaratMadinah ?? false
    }

    var esimEnabled: Bool {
        esimOverride ?? booking.customization?.esim ?? false
    }
}
