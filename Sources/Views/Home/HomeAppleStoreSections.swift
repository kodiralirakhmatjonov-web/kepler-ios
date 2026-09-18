import SwiftUI

struct IumrahHomeSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IumrahHomeAudienceSection: View {
    let language: AppSettingsStore.Language

    private struct Item: Identifiable {
        let id: String
        let icon: String
        let title: String
        let body: String
        let background: Color
        let foreground: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            IumrahHomeSectionHeader(title: sectionTitle)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        audienceCard(item)
                            .frame(width: 286, height: 235)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollClipDisabled()
        }
    }

    private func audienceCard(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: item.icon)
                    .font(.system(size: 23, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(item.foreground.opacity(0.10), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                Spacer()
            }

            Spacer(minLength: 14)

            Text(item.title)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(item.foreground)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.body)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(item.foreground.opacity(0.68))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
        }
        .padding(20)
        .background(item.background)
        .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 31, style: .continuous)
                .strokeBorder(item.foreground.opacity(0.06), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 18, y: 9)
    }

    private var sectionTitle: String {
        switch language {
        case .russian: return "Для кого создан Iumrah"
        case .english: return "Who Iumrah is for"
        case .uzbek: return "Iumrah kimlar uchun"
        case .uzbekCyrillic: return "Iumrah кимлар учун"
        }
    }

    private var items: [Item] {
        switch language {
        case .russian:
            return [
                Item(
                    id: "self",
                    icon: "slider.horizontal.3",
                    title: "Соберите поездку сами",
                    body: "Перелёт, отели, трансфер и сервисы — один персональный пакет Умры, который Вы собираете под себя.",
                    background: Color(red: 0.91, green: 0.95, blue: 1.00),
                    foreground: Color(red: 0.05, green: 0.16, blue: 0.34)
                ),
                Item(
                    id: "family",
                    icon: "person.3.fill",
                    title: "Семья и близкие",
                    body: "Организуйте Умру для семьи или друзей вместе, сохраняя приватность и удобный темп поездки.",
                    background: Color(red: 0.94, green: 0.98, blue: 0.92),
                    foreground: Color(red: 0.10, green: 0.28, blue: 0.13)
                ),
                Item(
                    id: "vip",
                    icon: "sparkles",
                    title: "Индивидуальный и VIP",
                    body: "Премиальные отели, приватный транспорт, индивидуальный сервис и максимум личного пространства.",
                    background: Color(red: 0.98, green: 0.94, blue: 0.89),
                    foreground: Color(red: 0.31, green: 0.18, blue: 0.07)
                ),
            ]
        case .english:
            return [
                Item(id: "self", icon: "slider.horizontal.3", title: "Build it your way", body: "Flights, hotels, transfer and services in one personal Umrah package you configure for yourself.", background: Color(red: 0.91, green: 0.95, blue: 1.00), foreground: Color(red: 0.05, green: 0.16, blue: 0.34)),
                Item(id: "family", icon: "person.3.fill", title: "Family & friends", body: "Organize Umrah together while keeping the journey private, comfortable and paced around your group.", background: Color(red: 0.94, green: 0.98, blue: 0.92), foreground: Color(red: 0.10, green: 0.28, blue: 0.13)),
                Item(id: "vip", icon: "sparkles", title: "Private & VIP", body: "Premium hotels, private transport, individual service and more personal space throughout the journey.", background: Color(red: 0.98, green: 0.94, blue: 0.89), foreground: Color(red: 0.31, green: 0.18, blue: 0.07)),
            ]
        case .uzbek:
            return [
                Item(id: "self", icon: "slider.horizontal.3", title: "Safarni o‘zingiz tuzing", body: "Parvoz, mehmonxona, transfer va servislar — o‘zingizga mos bitta shaxsiy Umra paketi.", background: Color(red: 0.91, green: 0.95, blue: 1.00), foreground: Color(red: 0.05, green: 0.16, blue: 0.34)),
                Item(id: "family", icon: "person.3.fill", title: "Oila va yaqinlar", body: "Oila yoki do‘stlar bilan guruhingizga mos, qulay va xususiy tempda Umra safarini tashkil qiling.", background: Color(red: 0.94, green: 0.98, blue: 0.92), foreground: Color(red: 0.10, green: 0.28, blue: 0.13)),
                Item(id: "vip", icon: "sparkles", title: "Individual va VIP", body: "Premium mehmonxonalar, xususiy transport, individual servis va safar davomida maksimal maxfiylik.", background: Color(red: 0.98, green: 0.94, blue: 0.89), foreground: Color(red: 0.31, green: 0.18, blue: 0.07)),
            ]
        case .uzbekCyrillic:
            return [
                Item(id: "self", icon: "slider.horizontal.3", title: "Сафарни ўзингиз тузинг", body: "Парвоз, меҳмонхона, трансфер ва сервислар — ўзингизга мос битта шахсий Умра пакети.", background: Color(red: 0.91, green: 0.95, blue: 1.00), foreground: Color(red: 0.05, green: 0.16, blue: 0.34)),
                Item(id: "family", icon: "person.3.fill", title: "Оила ва яқинлар", body: "Оила ёки дўстлар билан гуруҳингизга мос, қулай ва хусусий темпда Умра сафарини ташкил қилинг.", background: Color(red: 0.94, green: 0.98, blue: 0.92), foreground: Color(red: 0.10, green: 0.28, blue: 0.13)),
                Item(id: "vip", icon: "sparkles", title: "Индивидуал ва VIP", body: "Премиум меҳмонхоналар, хусусий транспорт, индивидуал сервис ва сафар давомида максимал махфийлик.", background: Color(red: 0.98, green: 0.94, blue: 0.89), foreground: Color(red: 0.31, green: 0.18, blue: 0.07)),
            ]
        }
    }
}

struct IumrahHomeServicesSection: View {
    let language: AppSettingsStore.Language
    let onTransfer: () -> Void
    let onESIM: () -> Void
    let onFlights: () -> Void
    let onZiyarats: () -> Void
    let onCare: () -> Void

    private struct Item: Identifiable {
        let id: String
        let assets: [String]
        let title: String
        let body: String
        let badge: String
        let icon: String
        let action: (() -> Void)?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            IumrahHomeSectionHeader(title: sectionTitle, subtitle: sectionSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 13) {
                    ForEach(items) { item in
                        IumrahAppleServiceCard(item: item)
                            .frame(width: 306, height: 455)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollClipDisabled()
        }
    }

    private var sectionTitle: String {
        switch language {
        case .russian: return "Что входит в Iumrah Services"
        case .english: return "What’s inside Iumrah Services"
        case .uzbek: return "Iumrah Services nimalarni o‘z ichiga oladi"
        case .uzbekCyrillic: return "Iumrah Services нималарни ўз ичига олади"
        }
    }

    private var sectionSubtitle: String {
        switch language {
        case .russian: return "Основные сервисы уже встроены в пакеты Iumrah и сопровождают поездку от вылета до возвращения."
        case .english: return "Core services are built into Iumrah packages and stay with the journey from departure to return."
        case .uzbek: return "Asosiy servislar Iumrah paketlariga kiritilgan va safarni uchishdan qaytishgacha kuzatadi."
        case .uzbekCyrillic: return "Асосий сервислар Iumrah пакетларига киритилган ва сафарни учишдан қайтишгача кузатади."
        }
    }

    private var items: [Item] {
        switch language {
        case .russian:
            return [
                Item(id: "transfer", assets: ["TransferCarnival", "TransferMalibu", "TransferYukon"], title: "Iumrah Transfer", body: "Встреча в аэропорту и приватные поездки между ключевыми точками маршрута. Комфортный автомобиль под Ваш формат поездки.", badge: "В пакете", icon: "car.fill", action: onTransfer),
                Item(id: "ziyarat", assets: ["ZiyaratQuba1", "ZiyaratQuba2", "ZiyaratQuba3", "ZiyaratQuba4", "ZiyaratQuba5"], title: "Iumrah Ziyarat", body: "Места Мекки и Медины в одном маршруте. История, навигация и понятный порядок посещения без лишней суеты.", badge: "Маршруты", icon: "map.fill", action: onZiyarats),
                Item(id: "esim", assets: ["IumrahESIMHomeCard"], title: "Iumrah eSIM", body: "Интернет в Саудовской Аравии готов к подключению сразу после приземления — без поиска SIM-карты в аэропорту.", badge: "Связь", icon: "antenna.radiowaves.left.and.right", action: onESIM),
                Item(id: "flights", assets: ["IumrahFlightsHomeCard"], title: "Iumrah Flights", body: "Статус Вашего рейса в реальном времени: изменения времени, задержки и важные обновления поездки в одном месте.", badge: "Live status", icon: "airplane", action: onFlights),
                Item(id: "care", assets: ["IumrahCareShowcaseCard"], title: "Iumrah Care", body: "Человеческая поддержка, когда она действительно нужна: до поездки, в Саудовской Аравии и во время возвращения домой.", badge: "Поддержка", icon: "heart.fill", action: onCare),
            ]
        case .english:
            return [
                Item(id: "transfer", assets: ["TransferCarnival", "TransferMalibu", "TransferYukon"], title: "Iumrah Transfer", body: "Airport pickup and private rides between key stops, with the right vehicle for your journey.", badge: "Included", icon: "car.fill", action: onTransfer),
                Item(id: "ziyarat", assets: ["ZiyaratQuba1", "ZiyaratQuba2", "ZiyaratQuba3", "ZiyaratQuba4", "ZiyaratQuba5"], title: "Iumrah Ziyarat", body: "Makkah and Madinah places in one route, with context, navigation and a clear visit sequence.", badge: "Routes", icon: "map.fill", action: onZiyarats),
                Item(id: "esim", assets: ["IumrahESIMHomeCard"], title: "Iumrah eSIM", body: "Saudi internet ready from arrival, without having to search for a local SIM card at the airport.", badge: "Connectivity", icon: "antenna.radiowaves.left.and.right", action: onESIM),
                Item(id: "flights", assets: ["IumrahFlightsHomeCard"], title: "Iumrah Flights", body: "Real-time flight status with schedule changes, delays and important journey updates in one place.", badge: "Live status", icon: "airplane", action: onFlights),
                Item(id: "care", assets: ["IumrahCareShowcaseCard"], title: "Iumrah Care", body: "Human support when it matters — before the trip, in Saudi Arabia and on the way home.", badge: "Support", icon: "heart.fill", action: onCare),
            ]
        case .uzbek:
            return [
                Item(id: "transfer", assets: ["TransferCarnival", "TransferMalibu", "TransferYukon"], title: "Iumrah Transfer", body: "Aeroportdan kutib olish va yo‘nalishning muhim nuqtalari orasida safaringizga mos xususiy transport.", badge: "Paketda", icon: "car.fill", action: onTransfer),
                Item(id: "ziyarat", assets: ["ZiyaratQuba1", "ZiyaratQuba2", "ZiyaratQuba3", "ZiyaratQuba4", "ZiyaratQuba5"], title: "Iumrah Ziyarat", body: "Makka va Madina ziyorat joylari bitta yo‘nalishda: ma’lumot, navigatsiya va tushunarli tashrif tartibi.", badge: "Yo‘nalishlar", icon: "map.fill", action: onZiyarats),
                Item(id: "esim", assets: ["IumrahESIMHomeCard"], title: "Iumrah eSIM", body: "Saudiya Arabistonida internet qo‘nganingizdan boshlab tayyor — aeroportda SIM-karta izlash shart emas.", badge: "Internet", icon: "antenna.radiowaves.left.and.right", action: onESIM),
                Item(id: "flights", assets: ["IumrahFlightsHomeCard"], title: "Iumrah Flights", body: "Parvoz holati real vaqtda: vaqt o‘zgarishi, kechikish va safar uchun muhim yangilanishlar bir joyda.", badge: "Live status", icon: "airplane", action: onFlights),
                Item(id: "care", assets: ["IumrahCareShowcaseCard"], title: "Iumrah Care", body: "Kerak bo‘lgan paytda insoniy yordam — safardan oldin, Saudiya Arabistonida va uyga qaytishda.", badge: "Yordam", icon: "heart.fill", action: onCare),
            ]
        case .uzbekCyrillic:
            return [
                Item(id: "transfer", assets: ["TransferCarnival", "TransferMalibu", "TransferYukon"], title: "Iumrah Transfer", body: "Аэропортдан кутиб олиш ва йўналишнинг муҳим нуқталари орасида сафарингизга мос хусусий транспорт.", badge: "Пакетда", icon: "car.fill", action: onTransfer),
                Item(id: "ziyarat", assets: ["ZiyaratQuba1", "ZiyaratQuba2", "ZiyaratQuba3", "ZiyaratQuba4", "ZiyaratQuba5"], title: "Iumrah Ziyarat", body: "Макка ва Мадина зиёрат жойлари битта йўналишда: маълумот, навигация ва тушунарли ташриф тартиби.", badge: "Йўналишлар", icon: "map.fill", action: onZiyarats),
                Item(id: "esim", assets: ["IumrahESIMHomeCard"], title: "Iumrah eSIM", body: "Саудия Арабистонида интернет қўнганингиздан бошлаб тайёр — аэропортда SIM-карта излаш шарт эмас.", badge: "Интернет", icon: "antenna.radiowaves.left.and.right", action: onESIM),
                Item(id: "flights", assets: ["IumrahFlightsHomeCard"], title: "Iumrah Flights", body: "Парвоз ҳолати реал вақтда: вақт ўзгариши, кечикиш ва сафар учун муҳим янгиланишлар бир жойда.", badge: "Live status", icon: "airplane", action: onFlights),
                Item(id: "care", assets: ["IumrahCareShowcaseCard"], title: "Iumrah Care", body: "Керак бўлган пайтда инсоний ёрдам — сафардан олдин, Саудия Арабистонида ва уйга қайтишда.", badge: "Ёрдам", icon: "heart.fill", action: onCare),
            ]
        }
    }

    private struct IumrahAppleServiceCard: View {
        let item: Item
        @State private var mediaIndex = 0

        var body: some View {
            Button {
                item.action?()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    media
                        .frame(height: 246)
                        .clipped()

                    VStack(alignment: .leading, spacing: 11) {
                        HStack(spacing: 8) {
                            Label(item.badge, systemImage: item.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.52))
                            Spacer(minLength: 0)
                            if item.action != nil {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.black.opacity(0.42))
                            }
                        }

                        Text(item.title)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .tracking(-0.55)
                            .foregroundStyle(.black)
                            .lineLimit(2)

                        Text(item.body)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.58))
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.white)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 31, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.055), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.07), radius: 21, y: 10)
                .contentShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
            }
            .buttonStyle(.plain)
        }

        private var media: some View {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Image(item.assets[mediaIndex])
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 18)
                                .onEnded { value in
                                    guard item.assets.count > 1, abs(value.translation.width) > 38 else { return }
                                    withAnimation(.snappy(duration: 0.24)) {
                                        if value.translation.width < 0 {
                                            mediaIndex = min(item.assets.count - 1, mediaIndex + 1)
                                        } else {
                                            mediaIndex = max(0, mediaIndex - 1)
                                        }
                                    }
                                    IumrahHaptics.selection()
                                }
                        )

                    if item.assets.count > 1 {
                        HStack(spacing: 5) {
                            ForEach(item.assets.indices, id: \.self) { index in
                                Circle()
                                    .fill(Color.white.opacity(index == mediaIndex ? 0.96 : 0.48))
                                    .frame(width: index == mediaIndex ? 7 : 6, height: index == mediaIndex ? 7 : 6)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.26), in: Capsule())
                        .padding(.bottom, 12)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }
}


struct IumrahTransferServiceView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var selectedVehicle: TransferVehicleKind = .carnival
    @State private var transferDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var showDatePicker = false
    @State private var searched = false

    private let vehicles: [TransferVehicleKind] = [.carnival, .yukon, .malibu]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(sectionTitle)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .tracking(-0.7)
                    Text(sectionSubtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TabView(selection: $selectedVehicle) {
                    ForEach(vehicles, id: \.self) { vehicle in
                        transferVehicleCard(vehicle)
                            .tag(vehicle)
                            .padding(.horizontal, 1)
                    }
                }
                .frame(height: 410)
                .tabViewStyle(.page(indexDisplayMode: .automatic))

                transferBookingCard

                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        searched = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(searchTransferTitle)
                            .font(.headline.weight(.semibold))
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)

                if searched {
                    searchResultCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker(
                        bookingDateTitle,
                        selection: $transferDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Spacer()
                }
                .navigationTitle(bookingDateTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(doneTitle) { showDatePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .iumrahInternalNavigation(progress: .transfer, showsGeneratorAmbient: true)
    }

    private func transferVehicleCard(_ vehicle: TransferVehicleKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(vehicle.assetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 232)
                .clipped()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(vehicle.modelName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(vehicleSubtitle(vehicle))
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    specPill(icon: "person.2.fill", title: passengerTitle(vehicle.passengerCapacity))
                    specPill(icon: "suitcase.rolling.fill", title: luggageTitle(vehicle.luggageCapacity))
                    if vehicle == .yukon {
                        specPill(icon: "sparkles", title: vipTitle)
                    }
                }

                Text(vehicleDescription(vehicle))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }

    private var transferBookingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(bookingCardTitle)
                .font(.system(size: 21, weight: .bold, design: .rounded))

            Button {
                showDatePicker = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bookingDateTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(dateLabel(transferDate))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(bookingCardBody)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var searchResultCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.iumrahCareLight)

            VStack(alignment: .leading, spacing: 6) {
                Text(resultTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(resultBody)
                    .font(.system(size: 14.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color(red: 0.95, green: 0.98, blue: 1.0), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.iumrahCareLight.opacity(0.18), lineWidth: 0.8)
        }
    }

    private func specPill(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func vehicleSubtitle(_ vehicle: TransferVehicleKind) -> String {
        switch settings.language {
        case .russian:
            return vehicle == .yukon ? "Просторный VIP-вариант для комфортных поездок" : "Комфортный автомобиль для маршрута паломника"
        case .english:
            return vehicle == .yukon ? "A spacious VIP option for a more private ride" : "A comfortable ride for the key parts of your journey"
        case .uzbek:
            return vehicle == .yukon ? "Qulay va xususiyroq safar uchun VIP variant" : "Safarning asosiy qismlari uchun qulay avtomobil"
        case .uzbekCyrillic:
            return vehicle == .yukon ? "Қулай ва хусусийроқ сафар учун VIP вариант" : "Сафарнинг асосий қисмлари учун қулай автомобиль"
        }
    }

    private func vehicleDescription(_ vehicle: TransferVehicleKind) -> String {
        switch settings.language {
        case .russian:
            switch vehicle {
            case .carnival: return "Удобный минивэн для семьи и небольших групп: аэропорт, отель и важные точки маршрута без лишних пересадок."
            case .yukon: return "Флагманский SUV для более приватного и просторного трансфера, когда нужен повышенный комфорт."
            case .malibu: return "Лёгкий городской седан для компактного маршрута и быстрых перемещений между ключевыми точками."
            }
        case .english:
            switch vehicle {
            case .carnival: return "A practical minivan for families and small groups, ideal for airport pickup and the main journey points."
            case .yukon: return "A flagship SUV for a more private, spacious transfer when you want a higher comfort tier."
            case .malibu: return "A clean city sedan for lighter transfer needs and smooth rides between essential stops."
            }
        case .uzbek:
            switch vehicle {
            case .carnival: return "Oila va kichik guruhlar uchun qulay miniven: aeroport, mehmonxona va asosiy nuqtalar orasida ortiqcha ovora bo‘lmasdan."
            case .yukon: return "Ko‘proq maxfiylik va kenglik kerak bo‘lsa, yuqori qulaylikdagi flagman SUV."
            case .malibu: return "Ixcham yo‘nalish va asosiy nuqtalar orasida yengil harakatlanish uchun toza shahar sedani."
            }
        case .uzbekCyrillic:
            switch vehicle {
            case .carnival: return "Оила ва кичик гуруҳлар учун қулай минивен: аэропорт, меҳмонхона ва асосий нуқталар орасида ортиқча овора бўлмасдан."
            case .yukon: return "Кўпроқ махфийлик ва кенглик керак бўлса, юқори қулайликдаги флагман SUV."
            case .malibu: return "Ихчам йўналиш ва асосий нуқталар орасида енгил ҳаракатланиш учун тоза шаҳар седани."
            }
        }
    }

    private func passengerTitle(_ count: Int) -> String {
        switch settings.language {
        case .russian: return "до \(count) пассажиров"
        case .english: return "up to \(count) guests"
        case .uzbek: return "\(count) gacha yo‘lovchi"
        case .uzbekCyrillic: return "\(count) гача йўловчи"
        }
    }

    private func luggageTitle(_ count: Int) -> String {
        switch settings.language {
        case .russian: return "\(count) багажа"
        case .english: return "\(count) bags"
        case .uzbek: return "\(count) ta bagaj"
        case .uzbekCyrillic: return "\(count) та багаж"
        }
    }

    private var vipTitle: String {
        switch settings.language {
        case .russian: return "VIP"
        case .english: return "VIP"
        case .uzbek: return "VIP"
        case .uzbekCyrillic: return "VIP"
        }
    }

    private var sectionTitle: String {
        switch settings.language {
        case .russian: return "Iumrah Transfer"
        case .english: return "Iumrah Transfer"
        case .uzbek: return "Iumrah Transfer"
        case .uzbekCyrillic: return "Iumrah Transfer"
        }
    }

    private var sectionSubtitle: String {
        switch settings.language {
        case .russian: return "Выберите подходящий автомобиль и посмотрите, как устроен трансфер внутри экосистемы iumrah."
        case .english: return "Browse the vehicle options and see how transfer fits into the iumrah journey."
        case .uzbek: return "Mos avtomobil variantlarini ko‘ring va transfer iumrah ekotizimida qanday ishlashini tushuning."
        case .uzbekCyrillic: return "Мос автомобиль вариантларини кўринг ва трансфер iumrah экотизимида қандай ишлашини тушунинг."
        }
    }

    private var bookingCardTitle: String {
        switch settings.language {
        case .russian: return "Забронировать дату"
        case .english: return "Reserve a date"
        case .uzbek: return "Sanani band qilish"
        case .uzbekCyrillic: return "Санани банд қилиш"
        }
    }

    private var bookingDateTitle: String {
        switch settings.language {
        case .russian: return "Дата трансфера"
        case .english: return "Transfer date"
        case .uzbek: return "Transfer sanasi"
        case .uzbekCyrillic: return "Трансфер санаси"
        }
    }

    private var bookingCardBody: String {
        switch settings.language {
        case .russian: return "Выберите ориентировочную дату заказа автомобиля из аэропорта или между точками маршрута."
        case .english: return "Choose an approximate date for your airport pickup or the transfer between the main journey points."
        case .uzbek: return "Aeroportdan kutib olish yoki asosiy yo‘nalish nuqtalari orasidagi transfer uchun taxminiy sanani tanlang."
        case .uzbekCyrillic: return "Аэропортдан кутиб олиш ёки асосий йўналиш нуқталари орасидаги трансфер учун тахминий санани танланг."
        }
    }

    private var searchTransferTitle: String {
        switch settings.language {
        case .russian: return "Поиск трансфера"
        case .english: return "Search transfer"
        case .uzbek: return "Transferni qidirish"
        case .uzbekCyrillic: return "Трансферни қидириш"
        }
    }

    private var resultTitle: String {
        switch settings.language {
        case .russian: return "Пока доступно только внутри пакетов"
        case .english: return "Currently available only inside packages"
        case .uzbek: return "Hozircha faqat paketlar ichida mavjud"
        case .uzbekCyrillic: return "Ҳозирча фақат пакетлар ичида мавжуд"
        }
    }

    private var resultBody: String {
        switch settings.language {
        case .russian: return "На данный момент поиск и бронирование трансферов доступно только внутри Umra пакетов."
        case .english: return "At the moment, transfer search and booking are available only inside Umrah packages."
        case .uzbek: return "Hozirda transferlarni qidirish va bron qilish faqat Umra paketlari ichida mavjud."
        case .uzbekCyrillic: return "Ҳозирда трансферларни қидириш ва брон қилиш фақат Умра пакетлари ичида мавжуд."
        }
    }

    private var doneTitle: String {
        switch settings.language {
        case .russian: return "Готово"
        case .english: return "Done"
        case .uzbek: return "Tayyor"
        case .uzbekCyrillic: return "Тайёр"
        }
    }
}


struct HomeStorefrontFlightOptionCard: View {
    let option: StorefrontFlightOption
    let packagePreview: StorefrontFlightPackagePreview?
    let isCalculating: Bool
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            media
                .frame(height: 118)
                .clipped()

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(routeTitle)
                            .font(.headline)
                        Text(airlineTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    packagePrice
                }

                HStack(spacing: 12) {
                    flightTime(option.outbound)
                    if let inbound = option.inbound {
                        Divider().frame(height: 34)
                        flightTime(inbound)
                    }
                }

                if let packagePreview {
                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox.fill")
                            .font(.caption2.weight(.bold))
                        Text(packageRouteText(packagePreview))
                            .lineLimit(2)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(generatedStampText, systemImage: "seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(packagePreview == nil ? Color.secondary : IumrahIconRole.umrah.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.iumrahRaisedBackground, in: Capsule())

                    Spacer(minLength: 4)
                    if packagePreview != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.035), radius: 14, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            if packagePreview != nil { onOpen() }
        }
        .accessibilityAddTraits(.isButton)
    }

    private var media: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                if let imageURL = packagePreview?.primaryHotel?.coverImageURL, !imageURL.isEmpty {
                    HotelCachedImage(rawURL: imageURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Image("IumrahFlightsShowcaseHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 10) {
                    HStack(spacing: 6) {
                        AirlineLogoView(airlineCode: option.outbound.airlineCode, size: 40)
                        if let preview = packagePreview,
                           preview.inbound.airlineCode.uppercased() != option.outbound.airlineCode.uppercased() {
                            AirlineLogoView(airlineCode: preview.inbound.airlineCode, size: 40)
                        }
                    }

                    Spacer(minLength: 8)

                    if let preview = packagePreview {
                        Text(packageTypeText(preview))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.36), in: Capsule())
                    }
                }
                .padding(13)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    @ViewBuilder
    private var packagePrice: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let packagePreview {
                Text(money(packagePreview.pricePerPerson))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(packagePerPersonText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            } else if isCalculating {
                ProgressView()
                    .controlSize(.small)
                Text(calculatingPackageText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(packageUnavailableText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 132, alignment: .trailing)
    }

    private var routeTitle: String {
        if let inbound = option.inbound {
            return "\(option.outbound.origin) → \(option.outbound.destination) · \(inbound.origin) → \(inbound.destination)"
        }
        return "\(option.outbound.origin) → \(option.outbound.destination)"
    }

    private var airlineTitle: String {
        let first = "\(option.outbound.airline) \(option.outbound.flightNumber)"
        guard let inbound = option.inbound else { return first }
        return first + " · \(inbound.airline) \(inbound.flightNumber)"
    }

    private func flightTime(_ leg: StorefrontFlightLeg) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(homeDay(leg.departureAt))
                .font(.caption.weight(.semibold))
            Text("\(homeClock(leg.departureAt))  \(leg.origin) → \(leg.destination)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func parseFlightDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }

    private func homeClock(_ value: String) -> String {
        guard let date = parseFlightDate(value) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func homeDay(_ value: String) -> String {
        guard let date = parseFlightDate(value) else { return String(value.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func money(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func packageRouteText(_ preview: StorefrontFlightPackagePreview) -> String {
        let route = "\(preview.outbound.origin) → \(preview.outbound.destination) + \(preview.inbound.origin) → \(preview.inbound.destination)"
        switch language {
        case .russian: return "\(route) · \(preview.durationDays) дн. · \(packageScopeText(preview))"
        case .english: return "\(route) · \(preview.durationDays) days · \(packageScopeText(preview))"
        case .uzbek: return "\(route) · \(preview.durationDays) kun · \(packageScopeText(preview))"
        case .uzbekCyrillic: return "\(route) · \(preview.durationDays) кун · \(packageScopeText(preview))"
        }
    }

    private func packageTypeText(_ preview: StorefrontFlightPackagePreview) -> String {
        "\(packageScopeText(preview)) · \(preview.tier.title(language))"
    }

    private func packageScopeText(_ preview: StorefrontFlightPackagePreview) -> String {
        switch (preview.kind, language) {
        case (.makkahComfortShort, .russian), (.hotelFirstMakkah, .russian): return "Только Мекка"
        case (.makkahComfortShort, .english), (.hotelFirstMakkah, .english): return "Makkah only"
        case (.makkahComfortShort, .uzbek), (.hotelFirstMakkah, .uzbek): return "Faqat Makka"
        case (.makkahComfortShort, .uzbekCyrillic), (.hotelFirstMakkah, .uzbekCyrillic): return "Фақат Макка"
        case (.makkahMadinahStandard, .russian): return "Мекка + Медина"
        case (.makkahMadinahStandard, .english): return "Makkah + Madinah"
        case (.makkahMadinahStandard, .uzbek): return "Makka + Madina"
        case (.makkahMadinahStandard, .uzbekCyrillic): return "Макка + Мадина"
        }
    }

    private var generatedStampText: String {
        switch language {
        case .russian: return packagePreview == nil ? "Iumrah Flights Scanner" : "Сгенерировано Iumrah Configurator"
        case .english: return packagePreview == nil ? "Iumrah Flights Scanner" : "Generated by Iumrah Configurator"
        case .uzbek: return packagePreview == nil ? "Iumrah Flights Scanner" : "Iumrah Configurator yaratdi"
        case .uzbekCyrillic: return packagePreview == nil ? "Iumrah Flights Scanner" : "Iumrah Configurator яратди"
        }
    }

    private var packagePerPersonText: String {
        switch language {
        case .russian: return "пакет · 1 человек"
        case .english: return "package · 1 person"
        case .uzbek: return "paket · 1 kishi"
        case .uzbekCyrillic: return "пакет · 1 киши"
        }
    }

    private var calculatingPackageText: String {
        switch language {
        case .russian: return "Считаем пакет"
        case .english: return "Calculating package"
        case .uzbek: return "Paket hisoblanmoqda"
        case .uzbekCyrillic: return "Пакет ҳисобланмоқда"
        }
    }

    private var packageUnavailableText: String {
        switch language {
        case .russian: return "нет пары 2–15 дней"
        case .english: return "no 2–15 day pair"
        case .uzbek: return "2–15 kunlik juftlik yo‘q"
        case .uzbekCyrillic: return "2–15 кунлик жуфтлик йўқ"
        }
    }
}

