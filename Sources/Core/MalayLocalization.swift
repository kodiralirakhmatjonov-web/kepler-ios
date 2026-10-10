import Foundation

/// Malay copy used by the language selector. Unknown phrases deliberately use
/// the original English text until a reviewed Malay translation is available.
/// This prevents missing symbols and avoids returning Indonesian by mistake.
enum MalayLocalization {
    static func phrase(_ english: String) -> String {
        translations[english] ?? english
    }

    private static let translations: [String: String] = [
        "Language": "Bahasa",
        "iumrah International Umrah Platform": "iumrah Platform Umrah Antarabangsa",
        "A world united by intention": "Dunia yang disatukan oleh niat",
        "Choose your app language": "Pilih bahasa aplikasi anda",
        "CURRENT": "SEMASA",
        "After confirmation, the iumrah interface switches to the language you selected.":
            "Selepas pengesahan, antara muka iumrah akan bertukar kepada bahasa pilihan anda.",
        "Current language already selected": "Bahasa semasa sudah dipilih"
    ]
}
