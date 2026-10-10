import Foundation

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

// Centralized, module-visible translation helper: also used by the Prayer Times
// screen. The default branch keeps new languages from breaking exhaustive
// switches if AppSettingsStore.Language gains additional cases.
func prayerText(
    _ language: AppSettingsStore.Language,
    _ en: String,
    _ ru: String,
    _ uz: String,
    _ cyrl: String
) -> String {
    switch language {
    case .indonesian, .malay, .english: return en
    case .russian: return ru
    case .uzbek: return uz
    case .uzbekCyrillic: return cyrl
    default:
        if language.rawValue.lowercased().hasPrefix("tr") {
            return IumrahPrayerTurkishText.translations[en] ?? en
        }
        return en
    }
}

private enum IumrahPrayerTurkishText {
    static let translations: [String: String] = [
        "Sea Prayer": "Denizde Namaz",
        "Prayer Rows": "Namaz Safları",
        "Pilgrim Light": "Hacıların Işığı",
        "Red Silence": "Kızıl Sessizlik",
        "Kaaba Corner": "Kâbe Köşesi",
        "Kaaba Touch": "Kâbe'ye Dokunuş",
        "Sujud": "Secde",
        "Quiet and reflective": "Sakin ve huzurlu",
        "Structured and calm": "Düzenli ve sakin",
        "Crowd with dramatic light": "Etkileyici ışıkta kalabalık",
        "Soft motion blur": "Yumuşak hareket bulanıklığı",
        "Minimal Kaaba scene": "Sade Kâbe manzarası",
        "Close and personal": "Yakın ve samimi",
        "Minimal and spacious": "Sade ve ferah",
        "Prayer Times": "Namaz Vakitleri",
        "Change wallpaper": "Duvar Kağıdını Değiştir",
        "Calculation settings": "Hesaplama Ayarları",
        "YOUR DAILY PRAYERS": "GÜNLÜK NAMAZ VAKİTLERİ",
        "Change city": "Şehri Değiştir",
        "NEXT PRAYER": "SONRAKİ NAMAZ",
        "until the next prayer": "sonraki namaza kalan süre",
        "Daily schedule": "Günlük Namaz Vakitleri",
        "Today": "Bugün",
        "Not a prayer · sunrise time": "Namaz değil · güneş doğuş saati",
        "Tap to configure reminder": "Hatırlatıcıyı ayarlamak için dokunun",
        "Additional prayers": "Diğer Namazlar",
        "Starts after sunrise": "Güneş doğduktan sonra başlar",
        "Last third of the night": "Gecenin son üçte biri",
        "Calculated offline for the selected coordinates and time zone. Local mosque timetables may vary; verify during travel. Alerts require iOS notification permission.": "Vakitler seçilen konum ve saat dilimine göre çevrimdışı hesaplanır. Yerel cami vakitleri farklılık gösterebilir; yolculuk sırasında kontrol edin. Bildirimler için iOS izni gereklidir.",
        "Fajr": "Sabah",
        "Sunrise": "Güneş",
        "Dhuhr": "Öğle",
        "Asr": "İkindi",
        "Maghrib": "Akşam",
        "Isha": "Yatsı",
        "Duha": "Kuşluk",
        "Tahajjud": "Teheccüd",
        "All wallpapers are prepared in the same phone-sized portrait format to keep the screen stable while switching.": "Tüm duvar kağıtları telefon ekranına uygun aynı dikey boyutta hazırlandı. Değiştirirken ekran düzeni korunur.",
        "Done": "Bitti",
        "Search any city": "Şehir Ara",
        "City or town": "Şehir veya İlçe",
        "Use current location": "Mevcut Konumumu Kullan",
        "Cities": "Şehirler",
        "Prayer times are calculated for the chosen city's time zone. Location is only requested when you tap the button above.": "Namaz vakitleri seçilen şehrin saat dilimine göre hesaplanır. Konum izni yalnızca yukarıdaki düğmeye dokunduğunuzda istenir.",
        "Choose a city": "Şehir Seç",
        "City not found. Try another spelling or choose from the list.": "Şehir bulunamadı. Farklı bir yazım deneyin veya listeden seçin.",
        "Calculation method": "Hesaplama Yöntemi",
        "Asr calculation": "İkindi Hesaplaması",
        "Umm al-Qura uses the standard Makkah twilight method and a fixed interval after sunset for Isha. Your selected method is saved on this device.": "Ümmü'l-Kurâ yöntemi Mekke için alacakaranlık hesabını ve yatsı için gün batımından sonra sabit süreyi kullanır. Seçtiğiniz yöntem cihazınızda saklanır.",
        "Configure reminder and sound": "Hatırlatıcıyı ve sesi ayarlayın",
        "Notification": "Bildirim",
        "System notification sound": "Sistem Bildirim Sesi",
        "Reminder offset": "Hatırlatma Zamanı",
        "At prayer time": "Namaz vaktinde",
        "Reset offset": "Sıfırla",
        "Early reminder": "Ön Hatırlatma",
        "Before prayer": "Namazdan önce",
        "A test notification is scheduled in 5 seconds.": "Test bildirimi 5 saniye içinde gönderilecek.",
        "Enable notifications for iumrah in iOS Settings to receive reminders.": "Hatırlatıcı almak için iOS Ayarları'ndan iumrah bildirimlerini etkinleştirin.",
        "Test notification": "Test Bildirimi",
        "Swipe left or right to configure another prayer. Alerts use the selected city's local prayer times. Custom adhan audio is not included.": "Başka bir namazı ayarlamak için sola veya sağa kaydırın. Bildirimler seçtiğiniz şehrin namaz vakitlerini kullanır. Özel ezan sesi henüz desteklenmiyor.",
        "Enable notifications for iumrah in iOS Settings. Your choices have been saved.": "iOS Ayarları'ndan iumrah bildirimlerini açın. Tercihleriniz kaydedildi.",
        "Save settings": "Ayarları Kaydet",
        "Prayer notifications": "Namaz Bildirimleri",
        "Close": "Kapat",
        "On time": "Tam Vaktinde"
    ]
}
