import SwiftUI

struct IumrahStoryView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                heroCard

                storyParagraph(L10n.text("story_p1", settings.language))
                storyImage("AboutIumrahPilgrims", height: 310)
                storyParagraph(L10n.text("story_p2", settings.language))

                whyProjectCard
                storyImage("AboutIumrahKaabaTouch", height: 390)
                principlesSection
                storyImage("AboutIumrahMapDark", height: 220)
                missionCard
                storyImage("AboutIumrahKaabaCorner", height: 360)
                promiseCard
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .accessibilityIdentifier("iumrah.story")
        .iumrahInternalNavigation()
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            Image("AboutIumrahMapLight")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 430)
                .clipped()

            LinearGradient(
                colors: [.clear, .white.opacity(0.45), .white.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("story_kicker", settings.language))
                    .font(.caption.weight(.bold))
                    .tracking(1.15)
                    .foregroundStyle(.black.opacity(0.52))

                Text(L10n.text("story_title", settings.language))
                    .font(.system(size: 37, weight: .bold, design: .rounded))
                    .tracking(-0.95)
                    .foregroundStyle(.black)

                Text(L10n.text("story_intro", settings.language))
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    miniMetric(icon: "mappin.and.ellipse", title: storyMetricPlace)
                    miniMetric(icon: "person.2.fill", title: storyMetricPilgrims)
                    miniMetric(icon: "shield.checkered", title: storyMetricPurpose)
                }
            }
            .padding(20)
        }
        .frame(height: 430)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.8)
        }
    }

    private func miniMetric(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .lineLimit(2)
        }
        .foregroundStyle(.black.opacity(0.76))
        .padding(.horizontal, 11)
        .frame(minHeight: 38)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var whyProjectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("story_why_project_title", settings.language))
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .tracking(-0.45)

            Text(L10n.text("story_why_project_body", settings.language))
                .font(.system(size: 15.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .iumrahMarketingCard()
    }

    private var principlesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(storyPrinciplesTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(-0.35)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    principleCard(icon: "figure.walk", title: principleIndependentTitle, body: principleIndependentBody)
                    principleCard(icon: "person.2.fill", title: principleFamilyTitle, body: principleFamilyBody)
                }

                HStack(spacing: 12) {
                    principleCard(icon: "checklist", title: principleFullPackageTitle, body: principleFullPackageBody)
                    principleCard(icon: "sparkles", title: principleCareTitle, body: principleCareBody)
                }
            }
        }
    }

    private func principleCard(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            Text(body)
                .font(.system(size: 13.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("story_mission_title", settings.language))
                .font(.system(size: 25, weight: .bold, design: .rounded))
            Text(L10n.text("story_mission_body", settings.language))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
        .iumrahMarketingCard(dark: true)
        .foregroundStyle(.white)
    }

    private var promiseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(storyPromiseTitle)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .tracking(-0.35)

            Text(storyPromiseBody)
                .font(.system(size: 15.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .iumrahMarketingCard()
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
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
    }

    private func storyParagraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var storyMetricPlace: String {
        switch settings.language {
        case .russian: return "Рождён в Мекке"
        case .english: return "Born in Makkah"
        case .uzbek: return "Makkada tug‘ilgan"
        case .uzbekCyrillic: return "Маккада туғилган"
        }
    }

    private var storyMetricPilgrims: String {
        switch settings.language {
        case .russian: return "> 1 года рядом с паломниками"
        case .english: return "> 1 year with pilgrims"
        case .uzbek: return "> 1 yil ziyoratchilar bilan"
        case .uzbekCyrillic: return "> 1 йил зиёратчилар билан"
        }
    }

    private var storyMetricPurpose: String {
        switch settings.language {
        case .russian: return "Проект ради пользы"
        case .english: return "Built for benefit"
        case .uzbek: return "Foyda uchun loyiha"
        case .uzbekCyrillic: return "Фойда учун лойиҳа"
        }
    }

    private var storyPrinciplesTitle: String {
        switch settings.language {
        case .russian: return "На чём стоит iumrah"
        case .english: return "What iumrah stands on"
        case .uzbek: return "iumrah nimaga tayanadi"
        case .uzbekCyrillic: return "iumrah нимага таянади"
        }
    }

    private var principleIndependentTitle: String {
        switch settings.language {
        case .russian: return "Независимая Umrah"
        case .english: return "Independent Umrah"
        case .uzbek: return "Mustaqil Umra"
        case .uzbekCyrillic: return "Мустақил Умра"
        }
    }

    private var principleIndependentBody: String {
        switch settings.language {
        case .russian: return "Чтобы паломник мог пройти путь без группы, посредников и лишней путаницы."
        case .english: return "So a pilgrim can complete the journey without a group, middlemen or unnecessary confusion."
        case .uzbek: return "Ziyoratchi guruhsiz, vositachilarsiz va ortiqcha chalkashliksiz yo‘lni bosib o‘tishi uchun."
        case .uzbekCyrillic: return "Зиёратчи гуруҳсиз, воситачиларсиз ва ортиқча чалкашликсиз йўлни босиб ўтиши учун."
        }
    }

    private var principleFamilyTitle: String {
        switch settings.language {
        case .russian: return "Семья и друзья"
        case .english: return "Family and friends"
        case .uzbek: return "Oila va do‘stlar"
        case .uzbekCyrillic: return "Оила ва дўстлар"
        }
    }

    private var principleFamilyBody: String {
        switch settings.language {
        case .russian: return "Чтобы поездку можно было собрать для себя и близких, а не только под формат тургруппы."
        case .english: return "So the trip can be assembled for you and your close ones, not only around a tour-group format."
        case .uzbek: return "Safarni faqat tur-guruh uchun emas, o‘zingiz va yaqinlaringiz uchun ham yig‘ish mumkin bo‘lishi uchun."
        case .uzbekCyrillic: return "Сафарни фақат тур-гуруҳ учун эмас, ўзингиз ва яқинларингиз учун ҳам йиғиш мумкин бўлиши учун."
        }
    }

    private var principleFullPackageTitle: String {
        switch settings.language {
        case .russian: return "Полный пакет"
        case .english: return "Full package"
        case .uzbek: return "To‘liq paket"
        case .uzbekCyrillic: return "Тўлиқ пакет"
        }
    }

    private var principleFullPackageBody: String {
        switch settings.language {
        case .russian: return "Маршрут, рейсы, отель, трансфер и сервисы должны соединяться в один понятный путь."
        case .english: return "Route, flights, hotel, transfer and services should connect into one understandable journey."
        case .uzbek: return "Yo‘nalish, parvoz, mehmonxona, transfer va xizmatlar bitta tushunarli safarga birlashishi kerak."
        case .uzbekCyrillic: return "Йўналиш, парвоз, меҳмонхона, трансфер ва хизматлар битта тушунарли сафарга бирлашиши керак."
        }
    }

    private var principleCareTitle: String {
        switch settings.language {
        case .russian: return "Забота, а не шум"
        case .english: return "Care, not noise"
        case .uzbek: return "Shovqin emas, g‘amxo‘rlik"
        case .uzbekCyrillic: return "Шовқин эмас, ғамхўрлик"
        }
    }

    private var principleCareBody: String {
        switch settings.language {
        case .russian: return "Технология не должна отвлекать от поклонения — она должна спокойно помогать до, во время и после Umrah."
        case .english: return "Technology should not distract from worship — it should calmly help before, during and after Umrah."
        case .uzbek: return "Texnologiya ibodatdan chalg‘itmasligi kerak — u Umradan oldin, davomida va keyin sokin yordam berishi kerak."
        case .uzbekCyrillic: return "Технология ибодатдан чалғитмаслиги керак — у Умрадан олдин, давомида ва кейин сокин ёрдам бериши керак."
        }
    }

    private var storyPromiseTitle: String {
        switch settings.language {
        case .russian: return "Что такое iumrah сегодня"
        case .english: return "What iumrah is today"
        case .uzbek: return "iumrah bugun nima"
        case .uzbekCyrillic: return "iumrah бугун нима"
        }
    }

    private var storyPromiseBody: String {
        switch settings.language {
        case .russian: return "Это не просто идея и не просто контент о паломничестве. iumrah — реальный продукт и платформа, созданные, чтобы сделать путь к Umrah чище, понятнее и достойнее для гостя Аллаха."
        case .english: return "This is not just an idea and not just content about pilgrimage. iumrah is a real product and platform built to make the path to Umrah clearer, calmer and more dignified for the guest of Allah."
        case .uzbek: return "Bu shunchaki g‘oya ham, ziyorat haqidagi kontent ham emas. iumrah — Alloh mehmoni uchun Umraga eltuvchi yo‘lni yanada toza, tushunarli va munosib qilish uchun yaratilgan haqiqiy mahsulot va platforma."
        case .uzbekCyrillic: return "Бу шунчаки ғоя ҳам, зиёрат ҳақидаги контент ҳам эмас. iumrah — Аллоҳ меҳмони учун Умрага элтувчи йўлни янада тоза, тушунарли ва муносиб қилиш учун яратилган ҳақиқий маҳсулот ва платформа."
        }
    }
}
