import SwiftUI

struct IumrahStoryView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                hero
                intro
                experienceStrip
                storyImage("AboutIumrahPilgrims", height: 310)
                whyCard
                storyImage("AboutIumrahKaabaTouch", height: 390)
                principles
                storyImage("AboutIumrahMapDark", height: 225)
                futureCard
                storyImage("AboutIumrahKaabaCorner", height: 360)
                closingCard
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 46)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color.iumrahPageBackground)
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
                .frame(height: 390)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.68)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(tr("3 YEARS OF EXPERIENCE", "3 ГОДА ОПЫТА", "3 YILLIK TAJRIBA", "3 ЙИЛЛИК ТАЖРИБА"))
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.78))

                Text(tr(
                    "A personal Umrah, built around you",
                    "Персональная Umrah, построенная вокруг Вас",
                    "Sizga mos shaxsiy Umra",
                    "Сизга мос шахсий Умра"
                ))
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(-0.65)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

                Text(tr(
                    "iumrah grew from real pilgrimage experience and a simple idea: the pilgrim should understand and control the journey, not depend on a large anonymous group.",
                    "iumrah вырос из реального опыта паломников и простой идеи: человек должен понимать и контролировать свою поездку, а не зависеть от большой безличной группы.",
                    "iumrah haqiqiy ziyorat tajribasidan va oddiy g‘oyadan tug‘ilgan: ziyoratchi safarini tushunishi va boshqarishi kerak.",
                    "iumrah ҳақиқий зиёрат тажрибасидан ва оддий ғоядан туғилган: зиёратчи сафарини тушуниши ва бошқариши керак."
                ))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(height: 390)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            .font(.system(size: 29, weight: .bold, design: .rounded))
            .tracking(-0.55)

            Text(tr(
                "Flights, hotel, transfer, guidance, Care and trip status are connected in one place so the pilgrim does not have to assemble the journey from scattered chats and promises.",
                "Перелёт, отель, трансфер, сопровождение, Care и статус поездки соединены в одном месте, чтобы паломнику не приходилось собирать путешествие из разрозненных чатов и обещаний.",
                "Parvoz, mehmonxona, transfer, yo‘l-yo‘riq, Care va safar holati bir joyda bog‘langan.",
                "Парвоз, меҳмонхона, трансфер, йўл-йўриқ, Care ва сафар ҳолати бир жойда боғланган."
            ))
            .font(.system(size: 16, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var experienceStrip: some View {
        HStack(spacing: 10) {
            metric(value: "3", label: tr("years in the niche", "года в этой нише", "yil tajriba", "йил тажриба"), icon: "clock.fill")
            metric(value: "1", label: tr("connected journey", "связанная поездка", "yagona safar", "ягона сафар"), icon: "link")
        }
    }

    private func metric(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 31, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
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
                "Вы выбираете даты, людей, уровень отеля и темп поездки. iumrah связывает операционные части и остаётся рядом, когда нужна помощь.",
                "Sanalar, hamrohlar, mehmonxona darajasi va safar tempini siz tanlaysiz. iumrah qolgan qismlarni bog‘laydi.",
                "Саналар, ҳамроҳлар, меҳмонхона даражаси ва сафар темпини сиз танлайсиз. iumrah қолган қисмларни боғлайди."
            )
        )
    }

    private var principles: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("What we protect", "Что для нас важно", "Biz uchun muhim", "Биз учун муҳим"))
                .font(.system(size: 26, weight: .bold, design: .rounded))

            principle(icon: "eye.fill", title: tr("Transparency", "Прозрачность", "Shaffoflik", "Шаффофлик"), body: tr("Clear status and clear next actions.", "Понятный статус и понятный следующий шаг.", "Aniq holat va keyingi qadam.", "Аниқ ҳолат ва кейинги қадам."))
            principle(icon: "person.2.fill", title: tr("Personal format", "Персональный формат", "Shaxsiy format", "Шахсий формат"), body: tr("A journey for you, your family or friends.", "Поездка для Вас, семьи или друзей.", "Siz, oila yoki do‘stlar uchun safar.", "Сиз, оила ёки дўстлар учун сафар."))
            principle(icon: "heart.fill", title: "iumrah Care", body: tr("Human support when an app alone is not enough.", "Живая поддержка, когда одного приложения недостаточно.", "Ilovaning o‘zi yetarli bo‘lmaganda inson yordami.", "Илованинг ўзи етарли бўлмаганда инсон ёрдами."))
        }
    }

    private func principle(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
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
                "Technology is useful only when it makes the journey clearer, calmer and more personal. That is the standard we are building iumrah around.",
                "Технология имеет смысл только тогда, когда делает поездку понятнее, спокойнее и персональнее. Вокруг этого стандарта мы и строим iumrah.",
                "Texnologiya safarni tushunarliroq, xotirjamroq va shaxsiyroq qilgandagina foydali. iumrah shu tamoyil atrofida quriladi.",
                "Технология сафарни тушунарлироқ, хотиржамроқ ва шахсийроқ қилгандагина фойдали. iumrah шу тамойил атрофида қурилади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .iumrahCard()
    }

    private func textCard(eyebrow: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .tracking(-0.45)
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
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.8)
            }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
