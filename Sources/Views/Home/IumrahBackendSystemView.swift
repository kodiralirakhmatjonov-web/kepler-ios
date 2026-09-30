import SwiftUI

private enum IumrahBackendModule: String, CaseIterable, Identifiable {
    case flights
    case hotels
    case transfer
    case guide
    case esim
    case orders
    case payment
    case pricing

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .flights: return "airplane"
        case .hotels: return "building.2.fill"
        case .transfer: return "car.fill"
        case .guide: return "person.wave.2.fill"
        case .esim: return "antenna.radiowaves.left.and.right"
        case .orders: return "shippingbox.fill"
        case .payment: return "creditcard.fill"
        case .pricing: return "function"
        }
    }

    func title(_ language: AppSettingsStore.Language) -> String {
        switch (language, self) {
        case (.russian, .flights): return "Авиабилеты"
        case (.russian, .hotels): return "Отели"
        case (.russian, .transfer): return "Трансфер"
        case (.russian, .guide): return "Гид"
        case (.russian, .esim): return "eSIM"
        case (.russian, .orders): return "Заказы"
        case (.russian, .payment): return "Оплата"
        case (.russian, .pricing): return "Расчёт"

        case (.english, .flights): return "Flights"
        case (.english, .hotels): return "Hotels"
        case (.english, .transfer): return "Transfer"
        case (.english, .guide): return "Guide"
        case (.english, .esim): return "eSIM"
        case (.english, .orders): return "Orders"
        case (.english, .payment): return "Payment"
        case (.english, .pricing): return "Pricing"

        case (.uzbek, .flights): return "Aviachiptalar"
        case (.uzbek, .hotels): return "Mehmonxonalar"
        case (.uzbek, .transfer): return "Transfer"
        case (.uzbek, .guide): return "Gid"
        case (.uzbek, .esim): return "eSIM"
        case (.uzbek, .orders): return "Buyurtmalar"
        case (.uzbek, .payment): return "To‘lov"
        case (.uzbek, .pricing): return "Hisob-kitob"

        case (.uzbekCyrillic, .flights): return "Авиачипталар"
        case (.uzbekCyrillic, .hotels): return "Меҳмонхоналар"
        case (.uzbekCyrillic, .transfer): return "Трансфер"
        case (.uzbekCyrillic, .guide): return "Гид"
        case (.uzbekCyrillic, .esim): return "eSIM"
        case (.uzbekCyrillic, .orders): return "Буюртмалар"
        case (.uzbekCyrillic, .payment): return "Тўлов"
        case (.uzbekCyrillic, .pricing): return "Ҳисоб-китоб"
        }
    }
}

private enum IumrahBackendCopy {
    enum Key {
        case homeEyebrow
        case homeTitle
        case homeBody
        case homeCTA
        case pageEyebrow
        case pageTitle
        case pageBody
        case oneBooking
        case onePayment
        case oneJourney
        case oneBookingBody
        case onePaymentBody
        case oneJourneyBody
        case underHood
        case underHoodBody
        case finalTitle
        case finalBody
    }

    static func text(_ key: Key, _ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian:
            switch key {
            case .homeEyebrow: return "iumrah Configurator"
            case .homeTitle: return "Вся поездка — в одной системе"
            case .homeBody: return "Авиабилеты, отели, трансфер, гид, eSIM, расчёты и оплата работают как одно бронирование."
            case .homeCTA: return "Как работает iumrah"
            case .pageEyebrow: return "ЕДИНАЯ ИНФРАСТРУКТУРА ПОЕЗДКИ"
            case .pageTitle: return "Одно бронирование. Одна оплата. Одна поездка."
            case .pageBody: return "Вместо множества вкладок, заказов и подтверждений iumrah связывает компоненты поездки в единый Booking ID и единый поток."
            case .oneBooking: return "1 бронирование"
            case .onePayment: return "1 оплата"
            case .oneJourney: return "1 поездка"
            case .oneBookingBody: return "Компоненты связаны одним Booking ID."
            case .onePaymentBody: return "Пользователь оплачивает поездку как единый пакет."
            case .oneJourneyBody: return "Статусы и сервисы живут в одном маршруте."
            case .underHood: return "Что происходит под капотом"
            case .underHoodBody: return "iumrah Configurator связывает поставщиков и внутренние сервисы, нормализует заказы, собирает стоимость и возвращает клиентскому приложению один понятный результат."
            case .finalTitle: return "Не восемь отдельных заказов. Один iumrah Booking."
            case .finalBody: return "Система скрывает сложность инфраструктуры и оставляет паломнику только то, что ему действительно нужно для поездки."
            }
        case .english:
            switch key {
            case .homeEyebrow: return "iumrah Configurator"
            case .homeTitle: return "Your whole trip, one system"
            case .homeBody: return "Flights, hotels, transfer, guide, eSIM, pricing and payment work as one booking."
            case .homeCTA: return "See how iumrah works"
            case .pageEyebrow: return "ONE JOURNEY INFRASTRUCTURE"
            case .pageTitle: return "One booking. One payment. One journey."
            case .pageBody: return "Instead of separate tabs, orders and confirmations, iumrah connects every trip component to one Booking ID and one flow."
            case .oneBooking: return "1 booking"
            case .onePayment: return "1 payment"
            case .oneJourney: return "1 journey"
            case .oneBookingBody: return "Every component is tied to one Booking ID."
            case .onePaymentBody: return "The pilgrim pays for the trip as one package."
            case .oneJourneyBody: return "Statuses and services live in one itinerary."
            case .underHood: return "What happens under the hood"
            case .underHoodBody: return "iumrah Configurator connects providers and internal services, normalizes orders, calculates the package and returns one clear result to the client app."
            case .finalTitle: return "Not eight separate orders. One iumrah Booking."
            case .finalBody: return "The system hides infrastructure complexity and leaves the pilgrim with only what matters for the journey."
            }
        case .uzbek:
            switch key {
            case .homeEyebrow: return "iumrah Configurator"
            case .homeTitle: return "Butun safar — bitta tizimda"
            case .homeBody: return "Aviachiptalar, mehmonxonalar, transfer, gid, eSIM, hisob-kitob va to‘lov bitta booking sifatida ishlaydi."
            case .homeCTA: return "iumrah qanday ishlaydi"
            case .pageEyebrow: return "YAGONA SAFAR INFRASTRUKTURASI"
            case .pageTitle: return "Bitta booking. Bitta to‘lov. Bitta safar."
            case .pageBody: return "Alohida sahifalar, buyurtmalar va tasdiqlar o‘rniga iumrah safarning barcha qismlarini bitta Booking ID va bitta oqimga birlashtiradi."
            case .oneBooking: return "1 booking"
            case .onePayment: return "1 to‘lov"
            case .oneJourney: return "1 safar"
            case .oneBookingBody: return "Har bir komponent bitta Booking ID bilan bog‘langan."
            case .onePaymentBody: return "Ziyoratchi safarni yagona paket sifatida to‘laydi."
            case .oneJourneyBody: return "Statuslar va xizmatlar bitta marshrutda yashaydi."
            case .underHood: return "Tizim ichida nima sodir bo‘ladi"
            case .underHoodBody: return "iumrah Configurator provayderlar va ichki servislarni bog‘laydi, buyurtmalarni bir formatga keltiradi, narxni hisoblaydi va ilovaga bitta aniq natija qaytaradi."
            case .finalTitle: return "Sakkizta alohida buyurtma emas. Bitta iumrah Booking."
            case .finalBody: return "Tizim murakkab infratuzilmani yashiradi va ziyoratchiga safar uchun kerak bo‘lgan narsalarnigina qoldiradi."
            }
        case .uzbekCyrillic:
            switch key {
            case .homeEyebrow: return "iumrah Configurator"
            case .homeTitle: return "Бутун сафар — битта тизимда"
            case .homeBody: return "Авиачипталар, меҳмонхоналар, трансфер, гид, eSIM, ҳисоб-китоб ва тўлов битта booking сифатида ишлайди."
            case .homeCTA: return "iumrah қандай ишлайди"
            case .pageEyebrow: return "ЯГОНА САФАР ИНФРАТУЗИЛМАСИ"
            case .pageTitle: return "Битта booking. Битта тўлов. Битта сафар."
            case .pageBody: return "Алоҳида саҳифалар, буюртмалар ва тасдиқлар ўрнига iumrah сафарнинг барча қисмларини битта Booking ID ва битта оқимга бирлаштиради."
            case .oneBooking: return "1 booking"
            case .onePayment: return "1 тўлов"
            case .oneJourney: return "1 сафар"
            case .oneBookingBody: return "Ҳар бир компонент битта Booking ID билан боғланган."
            case .onePaymentBody: return "Зиёратчи сафарни ягона пакет сифатида тўлайди."
            case .oneJourneyBody: return "Статуслар ва хизматлар битта маршрутда яшайди."
            case .underHood: return "Тизим ичида нима содир бўлади"
            case .underHoodBody: return "iumrah Configurator провайдерлар ва ички сервисларни боғлайди, буюртмаларни бир форматга келтиради, нархни ҳисоблайди ва иловага битта аниқ натижа қайтаради."
            case .finalTitle: return "Саккизта алоҳида буюртма эмас. Битта iumrah Booking."
            case .finalBody: return "Тизим мураккаб инфратузилмани яширади ва зиёратчига сафар учун керак бўлган нарсаларнигина қолдиради."
            }
        }
    }
}

struct IumrahBackendSystemHomeCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationLink {
            IumrahBackendSystemPresentationView()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text(IumrahBackendCopy.text(.homeEyebrow, settings.language))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.62))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 34, height: 34)
                        .iumrahGlass(in: Circle(), tint: .white.opacity(0.075))
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                IumrahBackendNetworkView(style: .compact, reduceMotion: reduceMotion)
                    .frame(height: 220)
                    .padding(.horizontal, 2)

                VStack(alignment: .leading, spacing: 9) {
                    Text(IumrahBackendCopy.text(.homeTitle, settings.language))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .tracking(-0.65)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(IumrahBackendCopy.text(.homeBody, settings.language))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        Text(IumrahBackendCopy.text(.homeCTA, settings.language))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.90))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color(red: 0.025, green: 0.025, blue: 0.032))
                    .overlay(alignment: .bottom) {
                        RadialGradient(
                            colors: [
                                Color(red: 0.36, green: 0.22, blue: 0.88).opacity(0.26),
                                .clear
                            ],
                            center: .bottom,
                            startRadius: 0,
                            endRadius: 260
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded { IumrahHaptics.soft() }
        )
    }
}

struct IumrahBackendSystemPresentationView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let purple = Color(red: 0.33, green: 0.21, blue: 0.80)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(IumrahBackendCopy.text(.pageEyebrow, settings.language))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.35)
                        .foregroundStyle(.white.opacity(0.46))

                    Text(IumrahBackendCopy.text(.pageTitle, settings.language))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1.2)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(IumrahBackendCopy.text(.pageBody, settings.language))
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 18)

                IumrahBackendNetworkView(style: .full, reduceMotion: reduceMotion)
                    .frame(height: 420)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)

                HStack(spacing: 9) {
                    metricCard(
                        value: IumrahBackendCopy.text(.oneBooking, settings.language),
                        body: IumrahBackendCopy.text(.oneBookingBody, settings.language),
                        icon: "number.circle.fill"
                    )
                    metricCard(
                        value: IumrahBackendCopy.text(.onePayment, settings.language),
                        body: IumrahBackendCopy.text(.onePaymentBody, settings.language),
                        icon: "creditcard.fill"
                    )
                    metricCard(
                        value: IumrahBackendCopy.text(.oneJourney, settings.language),
                        body: IumrahBackendCopy.text(.oneJourneyBody, settings.language),
                        icon: "location.fill"
                    )
                }
                .padding(.horizontal, IumrahDesign.pagePadding)

                VStack(alignment: .leading, spacing: 14) {
                    Text(IumrahBackendCopy.text(.underHood, settings.language))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(.white)

                    Text(IumrahBackendCopy.text(.underHoodBody, settings.language))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(IumrahBackendModule.allCases) { module in
                            HStack(spacing: 11) {
                                Image(systemName: module.systemImage)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 11, style: .continuous), tint: purple.opacity(0.27))

                                Text(module.title(settings.language))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.86))
                                    .lineLimit(1)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 58)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(.white.opacity(0.065), lineWidth: 0.7)
                            }
                        }
                    }
                }
                .padding(20)
                .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.065), lineWidth: 0.7)
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 26)

                VStack(alignment: .leading, spacing: 12) {
                    Text(IumrahBackendCopy.text(.finalTitle, settings.language))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .tracking(-0.7)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(IumrahBackendCopy.text(.finalBody, settings.language))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [purple.opacity(0.36), Color.white.opacity(0.035)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 0.8)
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 16)
                .padding(.bottom, 50)
            }
        }
        .background(
            ZStack {
                Color(red: 0.018, green: 0.018, blue: 0.024)
                RadialGradient(
                    colors: [purple.opacity(0.11), .clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 430
                )
            }
            .ignoresSafeArea()
        )
        .navigationTitle("iumrah Configurator")
        .navigationBarTitleDisplayMode(.inline)
        .iumrahInternalNavigation()
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .onAppear { IumrahHaptics.soft() }
    }

    private func metricCard(value: String, body: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .frame(width: 30, height: 30)
                .iumrahGlass(in: Circle(), tint: purple.opacity(0.26))

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(body)
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(12)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.065), lineWidth: 0.7)
        }
    }
}

private struct IumrahBackendNetworkView: View {
    enum Style {
        case compact
        case full
    }

    @EnvironmentObject private var settings: AppSettingsStore

    let style: Style
    let reduceMotion: Bool

    private let purple = Color(red: 0.33, green: 0.21, blue: 0.80)
    private let violet = Color(red: 0.61, green: 0.46, blue: 0.98)

    private var modules: [IumrahBackendModule] {
        style == .compact
            ? [.flights, .hotels, .transfer, .guide, .esim, .payment]
            : IumrahBackendModule.allCases
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let points = modulePoints(in: size)

            TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let phase = reduceMotion ? 0.34 : seconds.truncatingRemainder(dividingBy: 4.2) / 4.2

                ZStack {
                    Canvas { context, canvasSize in
                        drawNetwork(
                            context: &context,
                            size: canvasSize,
                            center: center,
                            points: points,
                            phase: phase
                        )
                    }
                    .allowsHitTesting(false)

                    ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                        if index < points.count {
                            IumrahBackendNodeView(
                                module: module,
                                language: settings.language,
                                compact: style == .compact
                            )
                            .position(points[index])
                        }
                    }

                    IumrahBackendHubView(compact: style == .compact, phase: phase, reduceMotion: reduceMotion)
                        .position(center)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("iumrah Configurator")
    }

    private func modulePoints(in size: CGSize) -> [CGPoint] {
        let leftX = size.width * (style == .compact ? 0.14 : 0.13)
        let rightX = size.width * (style == .compact ? 0.86 : 0.87)

        if style == .compact {
            return [
                CGPoint(x: leftX, y: size.height * 0.20),
                CGPoint(x: rightX, y: size.height * 0.20),
                CGPoint(x: leftX, y: size.height * 0.50),
                CGPoint(x: rightX, y: size.height * 0.50),
                CGPoint(x: leftX, y: size.height * 0.80),
                CGPoint(x: rightX, y: size.height * 0.80)
            ]
        }

        return [
            CGPoint(x: leftX, y: size.height * 0.13),
            CGPoint(x: leftX, y: size.height * 0.37),
            CGPoint(x: leftX, y: size.height * 0.63),
            CGPoint(x: leftX, y: size.height * 0.87),
            CGPoint(x: rightX, y: size.height * 0.13),
            CGPoint(x: rightX, y: size.height * 0.37),
            CGPoint(x: rightX, y: size.height * 0.63),
            CGPoint(x: rightX, y: size.height * 0.87)
        ]
    }

    private func drawNetwork(
        context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        points: [CGPoint],
        phase: Double
    ) {
        let edgeColor = Color(red: 0.36, green: 0.24, blue: 0.88)
        let brightColor = Color(red: 0.66, green: 0.52, blue: 1.0)

        for (index, point) in points.enumerated() {
            let from = centerAnchor(center: center, toward: point)
            let to = nodeAnchor(point: point, toward: center)
            let controls = controlPoints(from: from, to: to, size: size)

            var base = Path()
            base.move(to: from)
            base.addCurve(to: to, control1: controls.0, control2: controls.1)

            context.stroke(base, with: .color(Color.white.opacity(0.07)), lineWidth: 1.0)
            context.stroke(base, with: .color(edgeColor.opacity(0.19)), lineWidth: 1.25)

            let local = positiveRemainder(phase + Double(index) * 0.117, 1)
            let eased = smoothstep(local)

            for trailIndex in 0..<7 {
                let trailT = max(0, eased - Double(trailIndex) * 0.021)
                let p = cubicPoint(from, controls.0, controls.1, to, trailT)
                let decay = 1.0 - Double(trailIndex) / 7.0
                let radius = CGFloat(1.7 + 2.3 * decay)
                let opacity = 0.13 + 0.76 * decay

                let glowRect = CGRect(
                    x: p.x - radius * 2.0,
                    y: p.y - radius * 2.0,
                    width: radius * 4.0,
                    height: radius * 4.0
                )
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(edgeColor.opacity(opacity * 0.13))
                )

                let dotRect = CGRect(
                    x: p.x - radius * 0.48,
                    y: p.y - radius * 0.48,
                    width: radius * 0.96,
                    height: radius * 0.96
                )
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(brightColor.opacity(opacity))
                )
            }

            // A subtler return packet makes the diagram feel like a live two-way backend.
            let returnPhase = positiveRemainder(phase * 0.78 + 0.52 + Double(index) * 0.083, 1)
            let returnPoint = cubicPoint(from, controls.0, controls.1, to, 1.0 - smoothstep(returnPhase))
            let returnRect = CGRect(x: returnPoint.x - 1.4, y: returnPoint.y - 1.4, width: 2.8, height: 2.8)
            context.fill(Path(ellipseIn: returnRect), with: .color(violet.opacity(0.52)))
        }

        let corePulse = 0.5 + 0.5 * sin(phase * .pi * 2.0)
        let coreRadius = CGFloat(48 + corePulse * 10)
        let coreRect = CGRect(
            x: center.x - coreRadius,
            y: center.y - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        )
        context.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                Gradient(colors: [purple.opacity(0.11), .clear]),
                center: center,
                startRadius: 0,
                endRadius: coreRadius
            )
        )
    }

    private func centerAnchor(center: CGPoint, toward point: CGPoint) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = max(CGFloat(1), (dx * dx + dy * dy).squareRoot())
        let radius: CGFloat = style == .compact ? 41 : 50
        return CGPoint(
            x: center.x + dx / distance * radius,
            y: center.y + dy / distance * radius
        )
    }

    private func nodeAnchor(point: CGPoint, toward center: CGPoint) -> CGPoint {
        let dx = center.x - point.x
        let dy = center.y - point.y
        let distance = max(CGFloat(1), (dx * dx + dy * dy).squareRoot())
        let radius: CGFloat = style == .compact ? 23 : 27
        return CGPoint(
            x: point.x + dx / distance * radius,
            y: point.y + dy / distance * radius
        )
    }

    private func controlPoints(from: CGPoint, to: CGPoint, size: CGSize) -> (CGPoint, CGPoint) {
        let isLeft = to.x < from.x
        let horizontal = abs(to.x - from.x)
        let bend = min(horizontal * 0.52, size.width * 0.18)

        return (
            CGPoint(x: from.x + (isLeft ? -bend : bend), y: from.y),
            CGPoint(x: to.x + (isLeft ? bend * 0.38 : -bend * 0.38), y: to.y)
        )
    }

    private func cubicPoint(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
        let t = CGFloat(min(1, max(0, t)))
        let mt = 1 - t
        let x = mt * mt * mt * p0.x
            + 3 * mt * mt * t * p1.x
            + 3 * mt * t * t * p2.x
            + t * t * t * p3.x
        let y = mt * mt * mt * p0.y
            + 3 * mt * mt * t * p1.y
            + 3 * mt * t * t * p2.y
            + t * t * t * p3.y
        return CGPoint(x: x, y: y)
    }

    private func smoothstep(_ value: Double) -> Double {
        let x = min(1, max(0, value))
        return x * x * (3 - 2 * x)
    }

    private func positiveRemainder(_ value: Double, _ modulus: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: modulus)
        return result < 0 ? result + modulus : result
    }
}

private struct IumrahBackendHubView: View {
    let compact: Bool
    let phase: Double
    let reduceMotion: Bool

    private let purple = Color(red: 0.33, green: 0.21, blue: 0.80)
    private let violet = Color(red: 0.62, green: 0.47, blue: 0.99)

    var body: some View {
        let pulse = reduceMotion ? 0.35 : 0.5 + 0.5 * sin(phase * .pi * 2.0)
        let side: CGFloat = compact ? 78 : 96

        ZStack {
            RoundedRectangle(cornerRadius: compact ? 23 : 29, style: .continuous)
                .fill(Color(red: 0.025, green: 0.025, blue: 0.034))

            RadialGradient(
                colors: [
                    violet.opacity(0.20 + pulse * 0.18),
                    purple.opacity(0.08),
                    .clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: side * 0.88
            )
            .clipShape(RoundedRectangle(cornerRadius: compact ? 23 : 29, style: .continuous))

            Image("HeaderWordmarkLight")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: compact ? 58 : 70)
                .opacity(0.96)

            RoundedRectangle(cornerRadius: compact ? 23 : 29, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.20),
                            violet.opacity(0.38 + pulse * 0.22),
                            .white.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        }
        .frame(width: side, height: side)
        .shadow(color: purple.opacity(0.28 + pulse * 0.18), radius: 22 + pulse * 7, y: 7)
        .scaleEffect(reduceMotion ? 1 : 0.995 + pulse * 0.012)
    }
}

private struct IumrahBackendNodeView: View {
    let module: IumrahBackendModule
    let language: AppSettingsStore.Language
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 5 : 7) {
            Image(systemName: module.systemImage)
                .font(.system(size: compact ? 15 : 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: compact ? 43 : 50, height: compact ? 43 : 50)
                .iumrahGlass(
                    in: Circle(),
                    tint: Color(red: 0.33, green: 0.21, blue: 0.80).opacity(0.20)
                )

            Text(module.title(language))
                .font(.system(size: compact ? 8.8 : 10.2, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: compact ? 72 : 88)
        }
    }
}
