import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("profile_section", settings.language)) {
                    TextField(L10n.text("field_first_name", settings.language), text: $settings.firstName)
                        .textContentType(.givenName)
                    TextField(L10n.text("field_last_name", settings.language), text: $settings.lastName)
                        .textContentType(.familyName)
                    TextField(L10n.text("field_telegram", settings.language), text: $settings.telegram)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    TextField(L10n.text("field_whatsapp", settings.language), text: $settings.whatsapp)
                        .keyboardType(.phonePad)
                }

                Section(L10n.text("language_section", settings.language)) {
                    Picker(L10n.text("app_language", settings.language), selection: $settings.language) {
                        ForEach(AppSettingsStore.Language.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                }

                Section(L10n.text("appearance_section", settings.language)) {
                    Picker(L10n.text("theme_label", settings.language), selection: $settings.appearance) {
                        ForEach(AppSettingsStore.Appearance.allCases) { appearance in
                            Text(appearance.title(settings.language)).tag(appearance)
                        }
                    }
                }


                Section {
                    IumrahPolicySettingsRows()
                } header: {
                    Text(policySectionTitle)
                }
            }
            .navigationTitle(L10n.text("settings_title", settings.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("settings_done", settings.language)) { dismiss() }
                }
            }
        }
    }

    private var policySectionTitle: String {
        switch settings.language {
        case .russian: return "Конфиденциальность, возвраты и оплата"
        case .turkish: return TurkishLocalization.phrase("Privacy, refunds & payment")
        case .indonesian, .english: return "Privacy, refunds & payment"
        case .uzbek: return "Maxfiylik, qaytarish va to‘lov"
        case .uzbekCyrillic: return "Махфийлик, қайтариш ва тўлов"
        }
    }
}
