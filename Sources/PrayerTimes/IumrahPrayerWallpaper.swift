import SwiftUI

enum IumrahPrayerWallpaper: String, CaseIterable, Codable, Identifiable {
    case seaPrayer
    case rows
    case crowd
    case motion
    case kaabaCorner
    case touch
    case sujud

    var id: String { rawValue }

    var assetName: String {
        switch self {
        case .seaPrayer: return "PrayerWallpaperSeaPrayer"
        case .rows: return "PrayerWallpaperRows"
        case .crowd: return "PrayerWallpaperCrowd"
        case .motion: return "PrayerWallpaperMotion"
        case .kaabaCorner: return "PrayerWallpaperKaabaCorner"
        case .touch: return "PrayerWallpaperTouch"
        case .sujud: return "PrayerWallpaperSujud"
        }
    }

    func title(_ language: AppSettingsStore.Language) -> String {
        switch self {
        case .seaPrayer:
            return prayerText(language, "Sea Prayer", "Молитва над водой", "Suv ustidagi namoz", "Сув устидаги намоз")
        case .rows:
            return prayerText(language, "Prayer Rows", "Ряды ковров", "Namoz qatorlari", "Намоз қаторлари")
        case .crowd:
            return prayerText(language, "Pilgrim Light", "Свет паломников", "Ziyoratchilar nuri", "Зиёратчилар нури")
        case .motion:
            return prayerText(language, "Red Silence", "Красная тишина", "Qizil sukunat", "Қизил сукунат")
        case .kaabaCorner:
            return prayerText(language, "Kaaba Corner", "Угол Каабы", "Ka'ba burchagi", "Каъба бурчаги")
        case .touch:
            return prayerText(language, "Kaaba Touch", "Прикосновение к Каабе", "Ka'baga teginish", "Каъбага тегиниш")
        case .sujud:
            return prayerText(language, "Sujud", "Суджуд", "Sajda", "Сажда")
        }
    }

    func subtitle(_ language: AppSettingsStore.Language) -> String {
        switch self {
        case .seaPrayer:
            return prayerText(language, "Quiet and reflective", "Тихо и созерцательно", "Sokin va mulohazali", "Сокин ва мулоҳазали")
        case .rows:
            return prayerText(language, "Structured and calm", "Структурно и спокойно", "Tartibli va sokin", "Тартибли ва сокин")
        case .crowd:
            return prayerText(language, "Crowd with dramatic light", "Толпа и драматичный свет", "Olomon va chuqur yorug'lik", "Оломон ва чуқур ёруғлик")
        case .motion:
            return prayerText(language, "Soft motion blur", "Мягкое размытие движения", "Yumshoq harakat xiraligi", "Юмшоқ ҳаракат хиралиги")
        case .kaabaCorner:
            return prayerText(language, "Minimal Kaaba scene", "Минималистичный кадр Каабы", "Minimal Ka'ba manzarasi", "Минималистик Каъба манзараси")
        case .touch:
            return prayerText(language, "Close and personal", "Близко и лично", "Yaqin va samimiy", "Яқин ва самимий")
        case .sujud:
            return prayerText(language, "Minimal and spacious", "Минималистично и просторно", "Minimal va keng", "Минимал ва кенг")
        }
    }
}
