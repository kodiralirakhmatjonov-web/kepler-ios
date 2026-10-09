import Foundation

/// Indonesian interface strings. Untranslated application keys fall back to the
/// English catalogue, keeping placeholders and runtime copy safe and predictable.
/// The glossary is deliberately explicit: do not invent machine translations
/// at runtime or transform formatted placeholders.
enum IndonesianLocalization {
    static func key(_ identifier: String, english: String) -> String {
        byKey[identifier] ?? phrase(english)
    }

    static func phrase(_ english: String) -> String {
        byPhrase[english] ?? english
    }

    private static let byKey: [String: String] = [
        "language_section": "Bahasa",
        "language_english": "Bahasa Inggris",
        "language_russian": "Bahasa Rusia",
        "language_turkish": "Bahasa Turki",
        "language_uzbek": "Bahasa Uzbek",
        "language_uzbek_cyr": "Bahasa Uzbek (Sirilik)",
        "tab_home": "Beranda",
        "tab_hotels": "Hotel",
        "tab_booking": "Pemesanan",
        "tab_care": "Bantuan",
        "tab_umrah": "Umrah",
        "city_makkah": "Makkah",
        "city_madinah": "Madinah"
    ]

    private static let byPhrase: [String: String] = [
        "Feel it before your journey": "Rasakan sebelum perjalanan Anda",
        "Experience now": "Rasakan sekarang",
        "Experience": "Rasakan",
        "Confirm identity": "Konfirmasi identitas",
        "Security verification": "Verifikasi keamanan",
        "Identity confirmed": "Identitas telah dikonfirmasi",
        "Correct iUmrah Security details": "Perbaiki data iUmrah Security",
        "iUmrah Security · protected booking": "iUmrah Security · pemesanan terlindungi",
        "Complete details and pay": "Lengkapi data dan bayar",
        "iumrah ID · pilgrim forms · payment · receipt": "iumrah ID · formulir jemaah · pembayaran · bukti bayar",
        "Trip details and documents": "Rincian perjalanan dan dokumen",
        "Connectivity for your trip in Saudi Arabia. Activation appears in the app once the booking is prepared.": "Koneksi selama perjalanan Anda di Arab Saudi. Aktivasi akan muncul di aplikasi setelah pemesanan disiapkan.",
        "Include eSIM in this trip": "Sertakan eSIM dalam perjalanan ini",
        "After saving, this change must be submitted for confirmation just like a ziyarat change.": "Setelah disimpan, perubahan ini harus diajukan untuk konfirmasi seperti perubahan ziarah.",
        "iumrah Care will review your journey balance": "iumrah Care akan meninjau biaya perjalanan Anda",
        "This trip is above our usual reference range. Before final ticketing we will review more convenient flights, night allocation and comparable hotels to stabilize the journey without compromising quality.": "Biaya perjalanan ini melebihi kisaran biasanya. Sebelum tiket diterbitkan, kami akan meninjau penerbangan yang lebih nyaman, pembagian malam, dan hotel sebanding agar biaya tetap stabil tanpa mengurangi kualitas.",
        "iumrah International Umrah Platform": "iumrah Platform Umrah Internasional",
        "A world united by intention": "Dunia yang dipersatukan oleh niat",
        "Choose your app language": "Pilih bahasa aplikasi",
        "CURRENT": "SAAT INI",
        "After confirmation, the iumrah interface switches to the language you selected.": "Setelah dikonfirmasi, antarmuka iumrah akan langsung beralih ke bahasa pilihan Anda.",
        "Current language already selected": "Bahasa saat ini sudah dipilih",
        "Language": "Bahasa"
    ]
}
