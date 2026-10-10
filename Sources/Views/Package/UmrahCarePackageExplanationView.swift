import SwiftUI

struct UmrahCarePackageExplanationView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Image("CarePriceSupport")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .tracking(-0.7)
                        Text(intro)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    explanationRow(icon: "square.stack.3d.up.fill", title: stepOneTitle, body: stepOneBody)
                    explanationRow(icon: "airplane", title: stepTwoTitle, body: stepTwoBody)
                    explanationRow(icon: "building.2.fill", title: stepThreeTitle, body: stepThreeBody)
                    explanationRow(icon: "person.2.fill", title: stepFourTitle, body: stepFourBody)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(careTitle)
                            .font(.headline)
                        Text(careBody)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .background(Color.iumrahCareLight.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(Color.iumrahPageBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func explanationRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IumrahIconBadge(
                systemName: icon,
                size: 44,
                symbolSize: 19,
                cornerRadius: 15
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var title: String {
        switch settings.language {
        case .russian: return "Как iumrah собирает вашу поездку"
        case .turkish: return TurkishLocalization.phrase("How iumrah builds your journey")
        case .indonesian, .malay, .english: return "How iumrah builds your journey"
        case .uzbek: return "iumrah safaringizni qanday yig‘adi"
        case .uzbekCyrillic: return "iumrah сафарингизни қандай йиғади"
        }
    }

    private var intro: String {
        switch settings.language {
        case .russian: return "iumrah — не просто сервис бронирования. Мы собираем перелёты, проживание, трансферы, сопровождение и ключевые этапы Умры как одну связанную поездку, чтобы паломнику не приходилось самому сводить десятки отдельных деталей."
        case .turkish: return TurkishLocalization.phrase("iumrah is more than a booking service. Flights, stays, transfers, guidance and the key stages of Umrah are assembled as one connected journey so the pilgrim does not have to reconcile dozens of separate details.")
        case .indonesian, .malay, .english: return "iumrah is more than a booking service. Flights, stays, transfers, guidance and the key stages of Umrah are assembled as one connected journey so the pilgrim does not have to reconcile dozens of separate details."
        case .uzbek: return "iumrah oddiy bronlash xizmati emas. Parvozlar, turar joy, transferlar, yo‘riqnoma va Umraning asosiy bosqichlari yagona bog‘langan safar sifatida yig‘iladi."
        case .uzbekCyrillic: return "iumrah оддий бронлаш хизмати эмас. Парвозлар, турар жой, трансферлар, йўриқнома ва Умранинг асосий босқичлари ягона боғланган сафар сифатида йиғилади."
        }
    }

    private var stepOneTitle: String { localized("Поездка просчитывается как единая система", "The trip is calculated as one system", "Safar yagona tizim sifatida hisoblanadi", "Сафар ягона тизим сифатида ҳисобланади") }
    private var stepOneBody: String { localized("Даты, число паломников, ночи в Мекке и Медине и выбранные услуги связываются между собой заранее, чтобы не возникали лишние ночи, разрывы между городами или дублирование услуг.", "Dates, traveler count, nights in Makkah and Madinah and selected services are connected in advance to avoid extra nights, broken city transitions or duplicated services.", "Sanalar, ziyoratchilar soni, Makka va Madinadagi tunlar hamda xizmatlar oldindan bog‘lanadi.", "Саналар, зиёратчилар сони, Макка ва Мадинадаги тунлар ҳамда хизматлар олдиндан боғланади.") }

    private var stepTwoTitle: String { localized("Рейс оценивается внутри всей поездки", "Flights are evaluated inside the whole journey", "Reys butun safar ichida baholanadi", "Рейс бутун сафар ичида баҳоланади") }
    private var stepTwoBody: String { localized("Система сравнивает варианты внутри общей стоимости пакета. Если даты гибкие или выбранный рейс заметно повышает цену, iumrah Care помогает найти более сбалансированный маршрут без изменения логики вашей поездки.", "The system compares options inside the total package price. If your dates are flexible or a selected flight raises the package price significantly, iumrah Care can help find a better-balanced itinerary without changing the journey logic.", "Tizim variantlarni umumiy paket narxi ichida taqqoslaydi. Sanalar moslashuvchan bo‘lsa yoki tanlangan reys narxni sezilarli oshirsa, iumrah Care yanada muvozanatli yo‘nalishga yordam beradi.", "Тизим вариантларни умумий пакет нархи ичида таққослайди. Саналар мослашувчан бўлса ёки танланган рейс нархни сезиларли оширса, iumrah Care янада мувозанатли йўналишга ёрдам беради.") }

    private var stepThreeTitle: String { localized("Отели закрепляются под реальные ночи", "Hotels are matched to the actual nights", "Mehmonxonalar haqiqiy tunlarga moslanadi", "Меҳмонхоналар ҳақиқий тунларга мосланади") }
    private var stepThreeBody: String { localized("Отель связан с точными ночами поездки ещё во время расчёта. После подтверждения и оплаты система запускает оформление выбранного проживания на ваши даты как часть одного Umrah-пакета.", "The hotel is tied to the exact trip nights during calculation. After confirmation and payment, the system starts arranging the selected stay for your dates as part of the same Umrah package.", "Mehmonxona hisoblash vaqtidayoq safarning aniq tunlariga bog‘lanadi. Tasdiq va to‘lovdan so‘ng tizim tanlangan turar joyni shu Umra paketining bir qismi sifatida rasmiylashtirishni boshlaydi.", "Меҳмонхона ҳисоблаш вақтидаёқ сафарнинг аниқ тунларига боғланади. Тасдиқ ва тўловдан сўнг тизим танланган турар жойни шу Умра пакетининг бир қисми сифатида расмийлаштиришни бошлайди.") }

    private var stepFourTitle: String { localized("Сопровождение привязано к вашей Умре", "Guidance is attached to your Umrah", "Yo‘riqnoma Umrangizga biriktiriladi", "Йўриқнома Умрангизга бириктирилади") }
    private var stepFourBody: String { localized("Трансферы и гид координируются вокруг вашей фактической поездки — прилёта, переезда между городами, Умры и вылета домой.", "Transfers and guidance are coordinated around your actual journey: arrival, city transfer, Umrah and the flight home.", "Transfer va gid haqiqiy safaringiz — kelish, shaharlararo o‘tish, Umra va qaytish atrofida muvofiqlashtiriladi.", "Трансфер ва гид ҳақиқий сафарингиз — келиш, шаҳарлараро ўтиш, Умра ва қайтиш атрофида мувофиқлаштирилади.") }

    private var careTitle: String { localized("Наша задача — забота, а не просто бронь", "Our role is care, not just booking", "Vazifamiz — faqat bron emas, g‘amxo‘rlik", "Вазифамиз — фақат брон эмас, ғамхўрлик") }
    private var careBody: String { localized("Основная сборка поездки выполняется системой автоматически. iumrah Care подключается как дополнительный уровень заботы — если вам нужно сбалансировать цену, рейс, расположение отеля или маршрут, не отвлекаясь от главного: вашей Умры и поклонения.", "The core journey is assembled automatically by the system. iumrah Care adds an extra layer of care when you want help balancing price, flights, hotel location or itinerary, so your focus can stay on Umrah and worship.", "Safarning asosiy yig‘ilishi tizim tomonidan avtomatik bajariladi. iumrah Care narx, reys, mehmonxona joylashuvi yoki yo‘nalishni muvozanatlash kerak bo‘lsa qo‘shimcha g‘amxo‘rlik sifatida yordam beradi.", "Сафарнинг асосий йиғилиши тизим томонидан автоматик бажарилади. iumrah Care нарх, рейс, меҳмонхона жойлашуви ёки йўналишни мувозанатлаш керак бўлса қўшимча ғамхўрлик сифатида ёрдам беради.") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .malay, .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCyrl
        }
    }
}
