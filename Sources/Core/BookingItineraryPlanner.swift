import Foundation

/// Deterministic client-side itinerary baseline for a newly generated Umrah package.
/// Operational staff can still provide a richer server itinerary; this planner prevents
/// a sparse or legacy one-day itinerary from collapsing the whole journey into day one.
enum BookingItineraryPlanner {
    static func make(booking: RemoteBooking, language: AppSettingsStore.Language) -> [BookingItineraryItem] {
        let days = dayRange(from: booking.input.startDate, through: booking.input.endDate)
        guard !days.isEmpty else { return [] }

        let firstDay = days[0]
        let lastDay = days[days.count - 1]
        let madinahFirst = booking.stay.madinahCheckIn == firstDay || booking.input.arrivalAirportCode.uppercased() == "MED"
        let makkahHotel = booking.hotelNames.makkah
        let madinahHotel = booking.hotelNames.madinah
        let customization = booking.customization
        let includesMadinah = booking.input.includeMadinah
        let haramain = booking.includedServices?.contains("haramainTrain") == true

        var result: [BookingItineraryItem] = []
        var occupied = Set<String>()

        func add(_ day: String, order: Int, title: String, subtitle: String, icon: String, location: String) {
            guard days.contains(day) else { return }
            result.append(.init(
                id: "local-\(booking.id)-\(day)-\(order)-\(result.count)",
                bookingID: booking.id,
                dateLocal: day,
                sortOrder: order,
                title: title,
                subtitle: subtitle,
                icon: icon,
                location: location,
                notes: "",
                createdAt: "",
                updatedAt: "",
                timeLocal: nil,
                endTimeLocal: nil,
                kind: nil
            ))
            occupied.insert(day)
        }

        let outbound = booking.generatorTrace?.outbound
        let arrivalCity = madinahFirst ? city(.madinah, language) : city(.makkah, language)
        add(
            firstDay,
            order: 10,
            title: text(.arrival, language),
            subtitle: outbound.map { "\($0.airline) · \($0.flightNumbers)" } ?? text(.arrivalBody, language),
            icon: "airplane.arrival",
            location: arrivalCity
        )
        add(
            firstDay,
            order: 20,
            title: text(.hotelCheckIn, language),
            subtitle: madinahFirst ? madinahHotel : makkahHotel,
            icon: "building.2.fill",
            location: arrivalCity
        )

        var makkahCheckIn = booking.stay.makkahCheckIn
        var madinahCheckIn = booking.stay.madinahCheckIn

        if madinahFirst && includesMadinah {
            if customization?.ziyaratMadinah != false,
               let ziyaratDay = nextFreeDay(after: madinahCheckIn ?? firstDay, before: booking.stay.madinahCheckOut ?? lastDay, days: days) {
                add(
                    ziyaratDay,
                    order: 20,
                    title: text(.madinahZiyarat, language),
                    subtitle: text(.madinahZiyaratBody, language),
                    icon: "moon.stars.fill",
                    location: city(.madinah, language)
                )
            }

            let transferDay = makkahCheckIn
            if days.contains(transferDay), transferDay != firstDay {
                add(
                    transferDay,
                    order: 10,
                    title: text(.toMakkah, language),
                    subtitle: haramain ? text(.haramainBody, language) : text(.intercityBody, language),
                    icon: haramain ? "tram.fill" : "car.fill",
                    location: city(.makkah, language)
                )
                add(
                    transferDay,
                    order: 20,
                    title: text(.hotelCheckIn, language),
                    subtitle: makkahHotel,
                    icon: "building.2.fill",
                    location: city(.makkah, language)
                )
            }
        }

        let umrahBase = makkahCheckIn
        let umrahDay = preferredDay(afterOrSame: umrahBase, avoid: firstDay, before: lastDay, days: days)
        if let umrahDay {
            add(
                umrahDay,
                order: 30,
                title: text(.umrah, language),
                subtitle: text(.umrahBody, language),
                icon: "person.2.fill",
                location: city(.makkah, language)
            )

            let makkahZiyaratLimit = (!madinahFirst && includesMadinah) ? (booking.stay.madinahCheckIn ?? lastDay) : lastDay
            if customization?.ziyaratMakkah != false,
               let makkahZiyaratDay = nextFreeDay(after: umrahDay, before: makkahZiyaratLimit, days: days) {
                add(
                    makkahZiyaratDay,
                    order: 20,
                    title: text(.makkahZiyarat, language),
                    subtitle: text(.makkahZiyaratBody, language),
                    icon: "building.columns.fill",
                    location: city(.makkah, language)
                )
            }
        }

        if !madinahFirst && includesMadinah, let transferDay = madinahCheckIn, days.contains(transferDay), transferDay != firstDay {
            add(
                transferDay,
                order: 10,
                title: text(.toMadinah, language),
                subtitle: haramain ? text(.haramainBody, language) : text(.intercityBody, language),
                icon: haramain ? "tram.fill" : "car.fill",
                location: city(.madinah, language)
            )
            add(
                transferDay,
                order: 20,
                title: text(.hotelCheckIn, language),
                subtitle: madinahHotel,
                icon: "building.2.fill",
                location: city(.madinah, language)
            )

            if customization?.ziyaratMadinah != false,
               let ziyaratDay = nextFreeDay(after: transferDay, before: lastDay, days: days) {
                add(
                    ziyaratDay,
                    order: 20,
                    title: text(.madinahZiyarat, language),
                    subtitle: text(.madinahZiyaratBody, language),
                    icon: "moon.stars.fill",
                    location: city(.madinah, language)
                )
            }
        }

        if days.count >= 5 {
            for day in days.dropFirst().dropLast() where !occupied.contains(day) {
                add(
                    day,
                    order: 50,
                    title: text(.freeDay, language),
                    subtitle: text(.freeDayBody, language),
                    icon: "sparkles",
                    location: currentCity(on: day, booking: booking, madinahFirst: madinahFirst, language: language)
                )
            }
        }

        let departureCity = booking.route.returnOrigin.uppercased() == "MED" ? city(.madinah, language) : city(.jeddah, language)
        add(
            lastDay,
            order: 80,
            title: text(.airportTransfer, language),
            subtitle: text(.airportTransferBody, language),
            icon: "car.fill",
            location: departureCity
        )
        if let inbound = booking.generatorTrace?.inbound {
            add(
                lastDay,
                order: 90,
                title: text(.flightHome, language),
                subtitle: "\(inbound.airline) · \(inbound.flightNumbers)",
                icon: "airplane.departure",
                location: departureCity
            )
        }

        return result.sorted { lhs, rhs in
            if lhs.dateLocal != rhs.dateLocal { return lhs.dateLocal < rhs.dateLocal }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private static func preferredDay(afterOrSame day: String, avoid firstDay: String, before lastDay: String, days: [String]) -> String? {
        guard days.contains(day) else { return nil }
        if day == firstDay, let next = nextDay(after: day, days: days), next < lastDay { return next }
        if let next = nextDay(after: day, days: days), next < lastDay { return next }
        return day < lastDay ? day : nil
    }

    private static func nextFreeDay(after day: String, before limit: String, days: [String]) -> String? {
        guard let index = days.firstIndex(of: day), index + 1 < days.count else { return nil }
        let value = days[index + 1]
        return value < limit ? value : nil
    }

    private static func nextDay(after day: String, days: [String]) -> String? {
        guard let index = days.firstIndex(of: day), index + 1 < days.count else { return nil }
        return days[index + 1]
    }

    private static func currentCity(on day: String, booking: RemoteBooking, madinahFirst: Bool, language: AppSettingsStore.Language) -> String {
        if let madinahIn = booking.stay.madinahCheckIn,
           let madinahOut = booking.stay.madinahCheckOut,
           day >= madinahIn && day < madinahOut {
            return city(.madinah, language)
        }
        return city(.makkah, language)
    }

    private static func dayRange(from start: String, through end: String) -> [String] {
        guard let startDate = parser.date(from: start), let endDate = parser.date(from: end), startDate <= endDate else { return [] }
        var output: [String] = []
        var cursor = startDate
        let calendar = Calendar(identifier: .gregorian)
        while cursor <= endDate && output.count < 40 {
            output.append(parser.string(from: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return output
    }

    private enum Place { case makkah, madinah, jeddah }
    private static func city(_ place: Place, _ language: AppSettingsStore.Language) -> String {
        switch (place, language) {
        case (.makkah, .russian): return "Мекка"
        case (.madinah, .russian): return "Медина"
        case (.jeddah, .russian): return "Джидда"
        case (.makkah, .english): return "Makkah"
        case (.madinah, .english): return "Madinah"
        case (.jeddah, .english): return "Jeddah"
        case (.makkah, .uzbek): return "Makka"
        case (.madinah, .uzbek): return "Madina"
        case (.jeddah, .uzbek): return "Jidda"
        case (.makkah, .uzbekCyrillic): return "Макка"
        case (.madinah, .uzbekCyrillic): return "Мадина"
        case (.jeddah, .uzbekCyrillic): return "Жидда"
        }
    }

    private enum CopyKey { case arrival, arrivalBody, hotelCheckIn, madinahZiyarat, madinahZiyaratBody, makkahZiyarat, makkahZiyaratBody, toMakkah, toMadinah, intercityBody, haramainBody, umrah, umrahBody, freeDay, freeDayBody, airportTransfer, airportTransferBody, flightHome }
    private static func text(_ key: CopyKey, _ language: AppSettingsStore.Language) -> String {
        switch (key, language) {
        case (.arrival, .russian): return "Прилёт и встреча"
        case (.arrivalBody, .russian): return "Встреча по прилёте и начало поездки"
        case (.hotelCheckIn, .russian): return "Заселение в отель"
        case (.madinahZiyarat, .russian): return "Зияраты Медины"
        case (.madinahZiyaratBody, .russian): return "Мечеть Пророка ﷺ, Масджид Куба, Ухуд и исторические места · гид и трансфер"
        case (.makkahZiyarat, .russian): return "Зияраты Мекки"
        case (.makkahZiyaratBody, .russian): return "Значимые места Мекки · гид и трансфер"
        case (.toMakkah, .russian): return "Переезд в Мекку"
        case (.toMadinah, .russian): return "Переезд в Медину"
        case (.intercityBody, .russian): return "Междугородний трансфер между отелями"
        case (.haramainBody, .russian): return "Переезд между городами на Haramain"
        case (.umrah, .russian): return "Умра"
        case (.umrahBody, .russian): return "Ихрам, таваф, са’й и завершение Умры · сопровождение iumrah"
        case (.freeDay, .russian): return "Свободный день"
        case (.freeDayBody, .russian): return "Время для отдыха, поклонения и личных планов"
        case (.airportTransfer, .russian): return "Трансфер в аэропорт"
        case (.airportTransferBody, .russian): return "Выезд из отеля, трансфер к вашему рейсу и сопровождение iumrah"
        case (.flightHome, .russian): return "Вылет домой"

        case (.arrival, .english): return "Arrival and welcome"
        case (.arrivalBody, .english): return "Airport welcome and the start of your journey"
        case (.hotelCheckIn, .english): return "Hotel check-in"
        case (.madinahZiyarat, .english): return "Madinah ziyarat"
        case (.madinahZiyaratBody, .english): return "The Prophet’s Mosque ﷺ, Quba Mosque, Uhud and historic sites · guide and transfer"
        case (.makkahZiyarat, .english): return "Makkah ziyarat"
        case (.makkahZiyaratBody, .english): return "Important sites in Makkah · guide and transfer"
        case (.toMakkah, .english): return "Transfer to Makkah"
        case (.toMadinah, .english): return "Transfer to Madinah"
        case (.intercityBody, .english): return "Intercity transfer between your hotels"
        case (.haramainBody, .english): return "Intercity journey on Haramain"
        case (.umrah, .english): return "Umrah"
        case (.umrahBody, .english): return "Ihram, tawaf, sa’i and completion of Umrah · iumrah guidance"
        case (.freeDay, .english): return "Free day"
        case (.freeDayBody, .english): return "Time for rest, worship and your own plans"
        case (.airportTransfer, .english): return "Airport transfer"
        case (.airportTransferBody, .english): return "Hotel departure, transfer for your flight and iumrah guidance"
        case (.flightHome, .english): return "Flight home"

        case (.arrival, .uzbek): return "Kelish va kutib olish"
        case (.arrivalBody, .uzbek): return "Aeroportda kutib olish va safarning boshlanishi"
        case (.hotelCheckIn, .uzbek): return "Mehmonxonaga joylashish"
        case (.madinahZiyarat, .uzbek): return "Madina ziyoratlari"
        case (.madinahZiyaratBody, .uzbek): return "Payg‘ambar masjidi ﷺ, Qubo masjidi, Uhud va tarixiy joylar · gid va transfer"
        case (.makkahZiyarat, .uzbek): return "Makka ziyoratlari"
        case (.makkahZiyaratBody, .uzbek): return "Makkadagi muhim joylar · gid va transfer"
        case (.toMakkah, .uzbek): return "Makkaga yo‘l"
        case (.toMadinah, .uzbek): return "Madinaga yo‘l"
        case (.intercityBody, .uzbek): return "Mehmonxonalar orasida shaharlararo transfer"
        case (.haramainBody, .uzbek): return "Haramain orqali shaharlararo safar"
        case (.umrah, .uzbek): return "Umra"
        case (.umrahBody, .uzbek): return "Ihram, tavof, sa’y va Umrani yakunlash · iumrah yo‘riqnomasi"
        case (.freeDay, .uzbek): return "Erkin kun"
        case (.freeDayBody, .uzbek): return "Dam olish, ibodat va shaxsiy rejalaringiz uchun vaqt"
        case (.airportTransfer, .uzbek): return "Aeroportga transfer"
        case (.airportTransferBody, .uzbek): return "Mehmonxonadan chiqish, reysingizga transfer va iumrah yo‘riqnomasi"
        case (.flightHome, .uzbek): return "Uyga parvoz"

        case (.arrival, .uzbekCyrillic): return "Келиш ва кутиб олиш"
        case (.arrivalBody, .uzbekCyrillic): return "Аэропортда кутиб олиш ва сафарнинг бошланиши"
        case (.hotelCheckIn, .uzbekCyrillic): return "Меҳмонхонага жойлашиш"
        case (.madinahZiyarat, .uzbekCyrillic): return "Мадина зиёратлари"
        case (.madinahZiyaratBody, .uzbekCyrillic): return "Пайғамбар масжиди ﷺ, Қубо масжиди, Уҳуд ва тарихий жойлар · гид ва трансфер"
        case (.makkahZiyarat, .uzbekCyrillic): return "Макка зиёратлари"
        case (.makkahZiyaratBody, .uzbekCyrillic): return "Маккадаги муҳим жойлар · гид ва трансфер"
        case (.toMakkah, .uzbekCyrillic): return "Маккага йўл"
        case (.toMadinah, .uzbekCyrillic): return "Мадинага йўл"
        case (.intercityBody, .uzbekCyrillic): return "Меҳмонхоналар орасида шаҳарлараро трансфер"
        case (.haramainBody, .uzbekCyrillic): return "Haramain орқали шаҳарлараро сафар"
        case (.umrah, .uzbekCyrillic): return "Умра"
        case (.umrahBody, .uzbekCyrillic): return "Иҳром, тавоф, саъй ва Умрани якунлаш · iumrah йўриқномаси"
        case (.freeDay, .uzbekCyrillic): return "Эркин кун"
        case (.freeDayBody, .uzbekCyrillic): return "Дам олиш, ибодат ва шахсий режаларингиз учун вақт"
        case (.airportTransfer, .uzbekCyrillic): return "Аэропортга трансфер"
        case (.airportTransferBody, .uzbekCyrillic): return "Меҳмонхонадан чиқиш, рейсингизга трансфер ва iumrah йўриқномаси"
        case (.flightHome, .uzbekCyrillic): return "Уйга парвоз"
        }
    }

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
