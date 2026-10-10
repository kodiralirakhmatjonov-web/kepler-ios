import SwiftUI

struct IumrahStoryView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                hero
                intro
                experienceStrip
                storyImage("AboutIumrahPilgrims", height: 270)
                whyCard
                storyImage("AboutIumrahKaabaTouch", height: 320)
                principles
                storyImage("AboutIumrahMapDark", height: 205)
                futureCard
                storyImage("AboutIumrahKaabaCorner", height: 300)
                closingCard
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 46)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(tr("About iumrah", "О проекте iumrah", "iumrah haqida", "iumrah ҳақида"))
        .navigationBarTitleDisplayMode(.inline)
        .iumrahInternalNavigation()
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("AboutIumrahMapLight")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 326)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 9) {
                Text(tr("3 YEARS OF EXPERIENCE", "3 ГОДА ОПЫТА", "3 YILLIK TAJRIBA", "3 ЙИЛЛИК ТАЖРИБА"))
                    .font(.caption.weight(.bold))
                    .tracking(1.15)
                    .foregroundStyle(.white.opacity(0.78))

                Text(tr(
                    "A personal Umrah, built around you",
                    "Персональная Umrah, построенная вокруг Вас",
                    "Sizga mos shaxsiy Umra",
                    "Сизга мос шахсий Умра"
                ))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.55)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

                Text(tr(
                    "iumrah grew from real pilgrimage experience: the pilgrim should understand and control the journey without losing support.",
                    "iumrah вырос из реального опыта паломников: человек должен понимать и контролировать поездку, не оставаясь без поддержки.",
                    "iumrah haqiqiy ziyorat tajribasidan tug‘ilgan: ziyoratchi yordamni yo‘qotmasdan safarini tushunishi va boshqarishi kerak.",
                    "iumrah ҳақиқий зиёрат тажрибасидан туғилган: зиёратчи ёрдамни йўқотмасдан сафарини тушуниши ва бошқариши керак."
                ))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 326)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("iumrah")
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(.secondary)

            Text(tr(
                "One journey. One clear system.",
                "Одна поездка. Одна понятная система.",
                "Bitta safar. Bitta tushunarli tizim.",
                "Битта сафар. Битта тушунарли тизим."
            ))
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .tracking(-0.5)
            .fixedSize(horizontal: false, vertical: true)

            Text(tr(
                "Flights, hotel, transfer, guidance, Care and trip status are connected in one place.",
                "Перелёт, отель, трансфер, сопровождение, Care и статус поездки соединены в одном месте.",
                "Parvoz, mehmonxona, transfer, yo‘l-yo‘riq, Care va safar holati bir joyda bog‘langan.",
                "Парвоз, меҳмонхона, трансфер, йўл-йўриқ, Care ва сафар ҳолати бир жойда боғланган."
            ))
            .font(.system(size: 16, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var experienceStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                metric(value: "3", label: tr("years in the niche", "года в этой нише", "yil tajriba", "йил тажриба"), icon: "clock.fill")
                metric(value: "1", label: tr("connected journey", "связанная поездка", "yagona safar", "ягона сафар"), icon: "link")
            }

            VStack(spacing: 12) {
                metric(value: "3", label: tr("years in the niche", "года в этой нише", "yil tajriba", "йил тажриба"), icon: "clock.fill")
                metric(value: "1", label: tr("connected journey", "связанная поездка", "yagona safar", "ягона сафар"), icon: "link")
            }
        }
    }

    private func metric(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.8)
        }
    }

    private var whyCard: some View {
        textCard(
            eyebrow: tr("WHY IUMRAH", "ПОЧЕМУ IUMRAH", "NEGA IUMRAH", "НЕГА IUMRAH"),
            title: tr("Freedom without losing support", "Самостоятельность без потери поддержки", "Yordamni yo‘qotmasdan mustaqillik", "Ёрдамни йўқотмасдан мустақиллик"),
            body: tr(
                "You choose dates, people, hotel level and the pace of the journey. iumrah connects the operational pieces and stays with you when you need help.",
                "Вы выбираете даты, людей, уровень отеля и темп поездки. iumrah связывает все части и остаётся рядом, когда нужна помощь.",
                "Sanalar, hamrohlar, mehmonxona darajasi va safar tempini siz tanlaysiz. iumrah qolgan qismlarni bog‘laydi.",
                "Саналар, ҳамроҳлар, меҳмонхона даражаси ва сафар темпини сиз танлайсиз. iumrah қолган қисмларни боғлайди."
            )
        )
    }

    private var principles: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("What matters to us", "Что для нас важно", "Biz uchun muhim", "Биз учун муҳим"))
                .font(.system(size: 26, weight: .bold, design: .rounded))

            principle(icon: "eye.fill", title: tr("Transparency", "Прозрачность", "Shaffoflik", "Шаффофлик"), body: tr("Clear status and clear next actions.", "Понятный статус и следующий шаг.", "Aniq holat va keyingi qadam.", "Аниқ ҳолат ва кейинги қадам."))
            principle(icon: "person.2.fill", title: tr("Personal format", "Персональный формат", "Shaxsiy format", "Шахсий формат"), body: tr("A journey for you, your family or friends.", "Поездка для Вас, семьи или друзей.", "Siz, oila yoki do‘stlar uchun safar.", "Сиз, оила ёки дўстлар учун сафар."))
            principle(icon: "heart.fill", title: "iumrah Care", body: tr("Human support when an app alone is not enough.", "Живая поддержка, когда одного приложения недостаточно.", "Ilovaning o‘zi yetarli bo‘lmaganda inson yordami.", "Илованинг ўзи етарли бўлмаганда инсон ёрдами."))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func principle(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            IumrahIconBadge(systemName: icon, size: 44, symbolSize: 17, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.8)
        }
    }

    private var futureCard: some View {
        textCard(
            eyebrow: tr("THE DIRECTION", "КУДА МЫ ИДЁМ", "YO‘NALISH", "ЙЎНАЛИШ"),
            title: tr("Nusuk for permits. iumrah for the rest of the journey.", "Nusuk — для разрешений. iumrah — для всей остальной поездки.", "Nusuk — ruxsatlar uchun. iumrah — safarning qolgan qismi uchun.", "Nusuk — рухсатлар учун. iumrah — сафарнинг қолган қисми учун."),
            body: tr(
                "The goal is a calm digital companion before, during and after Umrah: planning, booking, status, guidance and human Care in one system.",
                "Цель — спокойный цифровой спутник до, во время и после Umrah: планирование, бронирование, статус, сопровождение и живая Care-поддержка в одной системе.",
                "Maqsad — Umradan oldin, davomida va keyin rejalashtirish, bron, holat va Care’ni bir tizimda birlashtirish.",
                "Мақсад — Умрадан олдин, давомида ва кейин режалаштириш, брон, ҳолат ва Care’ни бир тизимда бирлаштириш."
            )
        )
    }

    private var closingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Built around the pilgrim", "Создано вокруг паломника", "Ziyoratchi uchun yaratilgan", "Зиёратчи учун яратилган"))
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.45)
            Text(tr(
                "Technology matters only when it makes the journey clearer, calmer and more personal.",
                "Технология имеет смысл только тогда, когда делает поездку понятнее, спокойнее и персональнее.",
                "Texnologiya safarni tushunarliroq, xotirjamroq va shaxsiyroq qilgandagina foydali.",
                "Технология сафарни тушунарлироқ, хотиржамроқ ва шахсийроқ қилгандагина фойдали."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func textCard(eyebrow: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func storyImage(_ asset: String, height: CGFloat) -> some View {
        Image(asset)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.8)
            }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .malay, .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
