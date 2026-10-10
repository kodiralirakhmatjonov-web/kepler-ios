import SwiftUI
import UIKit

// Separate creative workspace. No booking/customer/admin access is granted here.
// Kepler Studio is a downloadable Python/FFmpeg engine and a skill catalog;
// the iOS app does NOT execute arbitrary skills, render MP4 or perform OAuth sync.
private enum KeplerStudioTab: Hashable { case overview, library, connect }

private struct KeplerStudioSkill: Decodable, Identifiable {
    let id: String
    let title: String
    let category: String
    let symbol: String
    let status: String
    let detail: String
    let repositoryURL: String?
    let guideFile: String?
    let archiveFile: String?
}

private struct KeplerStudioPreset: Decodable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let entryMs: Int
    let exitMs: Int
}

private struct KeplerStudioCatalog: Decodable {
    let schemaVersion: Int
    let engineVersion: String
    let source: String
    let repositoryURL: String?
    let buildURL: String?
    let engineArchive: String
    let coreSkillArchive: String
    let originalAssetsIncluded: Bool
    let runtimeNote: String
    let presets: [KeplerStudioPreset]
    let skills: [KeplerStudioSkill]
}

private enum KeplerStudioResources {
    // XcodeGen can copy resource folders as a bundle subdirectory or as a flat
    // list. Look up both without assuming a simulator/physical-device layout.
    static func file(_ filename: String) -> URL? {
        let parts = (filename as NSString)
        let name = parts.deletingPathExtension
        let ext = parts.pathExtension
        guard !name.isEmpty, !ext.isEmpty else { return nil }
        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "KeplerStudio")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    static func content(_ filename: String?) -> String? {
        guard let filename, let url = file(filename) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static let catalog: KeplerStudioCatalog? = {
        guard let url = file("KeplerStudioCatalog.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let parsed = try? decoder.decode(KeplerStudioCatalog.self, from: data),
              parsed.schemaVersion == 2, parsed.engineVersion == "0.2",
              parsed.skills.count >= 9, parsed.presets.count == 4 else { return nil }
        return parsed
    }()

    static var instructions: String {
        content("KeplerStudioSkill.md") ?? "Kepler Studio skill file unavailable. Export the full engine ZIP and read skills/kepler-studio/SKILL.md. Never redraw user-provided assets."
    }
}

private struct KeplerStudioCopy {
    let language: String

    func text(_ en: String, ru: String, uz: String? = nil) -> String {
        switch language {
        case "ru", "uz-cyrl": return ru
        case "uz", "uz-Latn", "uz-UZ": return uz ?? en
        default: return en
        }
    }
}

struct KeplerBusinessRootView: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.openURL) private var openURL
    @State private var selection: KeplerStudioTab = .overview
    @State private var selectedSkill: KeplerStudioSkill?
    @State private var selectedPreset: KeplerStudioPreset?
    @State private var didCopy = false

    private var copy: KeplerStudioCopy {
        KeplerStudioCopy(language: settings.language.rawValue)
    }
    private var catalog: KeplerStudioCatalog? { KeplerStudioResources.catalog }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                overview
                    .tabItem { Label(copy.text("Studio", ru: "Студия", uz: "Studiya"), systemImage: "square.grid.2x2") }
                    .tag(KeplerStudioTab.overview)
                library
                    .tabItem { Label(copy.text("Skills", ru: "Навыки", uz: "Skillar"), systemImage: "square.stack.3d.up") }
                    .tag(KeplerStudioTab.library)
                connections
                    .tabItem { Label(copy.text("Connect", ru: "Подключить", uz: "Ulash"), systemImage: "link") }
                    .tag(KeplerStudioTab.connect)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(Color.primary)
            .background(Color.iumrahPageBackground.ignoresSafeArea())
        }
        .sheet(item: $selectedSkill) { skill in skillDetail(skill) }
        .sheet(item: $selectedPreset) { preset in presetDetail(preset) }
        .accessibilityIdentifier("kepler.business.root")
    }

    private var overview: some View {
        page {
            VStack(alignment: .leading, spacing: 10) {
                Text("KEPLER STUDIO · v\(catalog?.engineVersion ?? "—")")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(copy.text("The Iumrah creative studio", ru: "Творческая студия Iumrah", uz: "Iumrah ijodiy studiyasi"))
                    .font(.system(size: 33, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text(copy.text("Original assets. Approved motion. Evidence-based AI planning.", ru: "Оригинальные компоненты. Проверенные анимации. AI-планирование по смыслу речи.", uz: "Asl komponentlar. Tasdiqlangan animatsiyalar. Nutqqa asoslangan AI reja."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)

            if let catalog {
                HStack(spacing: 12) {
                    metric("\(catalog.presets.count)", title: copy.text("Motion presets", ru: "Пресета", uz: "Harakat uslubi"))
                    metric("\(catalog.skills.count)", title: copy.text("Sources & Skills", ru: "Навыков и модулей", uz: "Skill va modul"))
                }

                SectionTitle(text: copy.text("Kepler Studio engine", ru: "Движок Kepler Studio", uz: "Kepler Studio engine"))
                surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Kepler Studio v\(catalog.engineVersion)", systemImage: "shippingbox")
                            .font(.headline)
                        Text(copy.text("Download the current source snapshot. Original user photos and third-party images are excluded.", ru: "Скачайте актуальные исходники. Личные фотографии и сторонние изображения не включены."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let url = KeplerStudioResources.file(catalog.engineArchive) {
                            ShareLink(item: url) {
                                actionLabel(copy.text("Export engine ZIP", ru: "Экспорт ZIP движка", uz: "Engine ZIP ulashish"), systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("kepler.business.engine.export")
                        } else {
                            missingFile
                        }
                    }
                }

                SectionTitle(text: copy.text("Motion presets", ru: "Готовые анимации", uz: "Harakat uslublari"))
                ForEach(catalog.presets) { preset in
                    Button { selectedPreset = preset; IumrahHaptics.selection() } label: {
                        HStack(spacing: 13) {
                            iconTile(preset.symbol)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.title).font(.headline).foregroundStyle(.primary)
                                Text("\(preset.entryMs) ms · \(preset.exitMs) ms")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                }

                statusNotice(copy.text("This is a source and skill library, not a built-in video renderer or a booking administration login.", ru: "Это библиотека исходников и навыков, а не встроенный видеоредактор или доступ к административным бронированиям."))
            } else {
                statusNotice(copy.text("Kepler Studio catalog v0.2 could not be loaded. Please check bundled resources.", ru: "Не удалось загрузить каталог Kepler Studio v0.2. Проверьте ресурсы приложения."))
            }
        }
    }

    private var library: some View {
        page {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.text("Skill Library", ru: "Библиотека навыков", uz: "Skill kutubxonasi"))
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                Text(copy.text("Source-verified tools from the eight supplied archives.", ru: "Проверенные исходные проекты из восьми полученных архивов."))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            if let catalog {
                ForEach(catalog.skills) { skill in
                    Button { selectedSkill = skill; IumrahHaptics.selection() } label: {
                        HStack(alignment: .center, spacing: 14) {
                            iconTile(skill.symbol)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(skill.title).font(.headline).foregroundStyle(.primary)
                                Text(skill.category).font(.caption).foregroundStyle(.secondary)
                                Text(statusLabel(skill.status)).font(.caption2.weight(.semibold))
                                    .foregroundStyle(statusColor(skill.status))
                            }
                            Spacer(minLength: 2)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 23))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                missingFile
            }
            statusNotice(copy.text("Bundled reference Skills are not installed as runnable iOS plugins. External integrations must be installed and tested on a server or agent environment.", ru: "Включённые справочные Skills не исполняются в iOS. Внешние зависимости устанавливаются и проверяются отдельно на сервере или в AI-среде."))
        }
    }

    private var connections: some View {
        page {
            Text(copy.text("Connect & export", ru: "Подключение и экспорт", uz: "Ulash va eksport"))
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .padding(.vertical, 8)

            SectionTitle(text: copy.text("Kepler Studio source", ru: "Исходники Kepler Studio"))
            if let catalog {
                if let repository = link(catalog.repositoryURL) {
                    externalLink(copy.text("Open Kepler Studio repository", ru: "Открыть репозиторий Kepler Studio"), subtitle: repository.absoluteString, symbol: "chevron.left.forwardslash.chevron.right", url: repository)
                } else {
                    statusNotice(copy.text("The public Kepler Studio GitHub repository URL has not been configured. Export the included source ZIP instead.", ru: "Публичная ссылка на репозиторий Kepler Studio ещё не настроена. Вместо неё можно экспортировать ZIP исходников."))
                }
                if let build = link(catalog.buildURL) {
                    externalLink(copy.text("Open build", ru: "Открыть билд"), subtitle: build.absoluteString, symbol: "arrow.up.right", url: build)
                }
                if let url = KeplerStudioResources.file(catalog.engineArchive) {
                    ShareLink(item: url) { actionLabel(copy.text("Share Kepler Studio v\(catalog.engineVersion) source", ru: "Поделиться исходниками v\(catalog.engineVersion)"), systemName: "square.and.arrow.up") }
                        .buttonStyle(.plain)
                }
            }

            SectionTitle(text: copy.text("AI assistants", ru: "AI-ассистенты"))
            aiConnection(name: "Sync with ChatGPT", subtitle: copy.text("Copy the v0.2 contract and open ChatGPT", ru: "Копировать правила v0.2 и открыть ChatGPT"), url: "https://chatgpt.com", symbol: "bubble.left.and.bubble.right")
            aiConnection(name: "Sync with Claude", subtitle: copy.text("Copy the v0.2 contract and open Claude", ru: "Копировать правила v0.2 и открыть Claude"), url: "https://claude.ai", symbol: "sparkles")

            if let catalog, let url = KeplerStudioResources.file(catalog.coreSkillArchive) {
                ShareLink(item: url) {
                    actionLabel(copy.text("Share core SKILL.md ZIP", ru: "Поделиться ZIP основного Skill"), systemName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }
            if didCopy {
                Label(copy.text("Instructions copied", ru: "Инструкции скопированы"), systemImage: "checkmark.circle.fill")
                    .font(.footnote).foregroundStyle(.green)
            }
            statusNotice(copy.text("These buttons only copy instructions and open official websites. They do not sign you in, import skills automatically or connect a database.", ru: "Кнопки только копируют инструкции и открывают сайты. Они не устанавливают Skills автоматически и не дают доступ к аккаунтам или базе данных."))
        }
    }

    private func skillDetail(_ skill: KeplerStudioSkill) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    iconTile(skill.symbol)
                    Text(skill.title).font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(skill.category).font(.subheadline).foregroundStyle(.secondary)
                    Text(statusLabel(skill.status))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor(skill.status))
                    Text(skill.detail).font(.body)
                    if let repo = link(skill.repositoryURL) {
                        externalLink(copy.text("Open original GitHub repository", ru: "Открыть оригинальный репозиторий GitHub"), subtitle: repo.absoluteString, symbol: "arrow.up.right", url: repo)
                    }
                    if let filename = skill.archiveFile,
                       let bundled = KeplerStudioResources.file(filename) {
                        ShareLink(item: bundled) {
                            actionLabel(copy.text("Export this Skill ZIP", ru: "Экспортировать ZIP этого Skill"), systemName: "square.and.arrow.up")
                        }.buttonStyle(.plain)
                    }
                    if let instructions = KeplerStudioResources.content(skill.guideFile) {
                        Button {
                            UIPasteboard.general.string = "Kepler Studio v0.2 · \(skill.title)\n\n" + instructions
                            didCopy = true
                            IumrahHaptics.selection()
                        } label: {
                            actionLabel(copy.text("Copy SKILL.md", ru: "Скопировать SKILL.md"), systemName: "doc.on.doc")
                        }.buttonStyle(.plain)
                    }
                    if skill.status == "external" || skill.status == "optional" {
                        statusNotice(copy.text("This integration is not included as an installed runtime in the iOS app. Open GitHub for installation steps.", ru: "Эта интеграция не установлена как исполняемый модуль в iOS. Инструкции по установке находятся на GitHub."))
                    } else if skill.status == "reference" {
                        statusNotice(copy.text("Included for agent guidance only; dependencies and video execution must run separately.", ru: "Включён как справочный Skill. Зависимости и обработка видео запускаются отдельно."))
                    }
                    if didCopy {
                        Label(copy.text("Copied", ru: "Скопировано"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .padding(23)
            }
            .navigationTitle("Kepler Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.text("Done", ru: "Готово")) { selectedSkill = nil }
                }
            }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
        }
    }

    private func presetDetail(_ preset: KeplerStudioPreset) -> some View {
        KeplerMotionPresetSheet(preset: preset, language: settings.language.rawValue)
    }

    private func aiConnection(name: String, subtitle: String, url: String, symbol: String) -> some View {
        Button {
            UIPasteboard.general.string = "Kepler Studio v0.2 — preserve original image assets; require transcript evidence and an approved plan.\n\n" + KeplerStudioResources.instructions
            didCopy = true
            if let target = URL(string: url) { openURL(target) }
            IumrahHaptics.selection()
        } label: {
            HStack(spacing: 13) {
                iconTile(symbol)
                VStack(alignment: .leading, spacing: 5) {
                    Text(name).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 22), interactive: true, chrome: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(name == "Sync with Claude" ? "kepler.business.claude" : "kepler.business.chatgpt")
    }

    private func externalLink(_ title: String, subtitle: String, symbol: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 13) {
                iconTile(symbol)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22))
        }
    }

    private func link(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
        return url
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "engine": return copy.text("Source included · external runtime", ru: "Исходники включены · внешний запуск")
        case "reference": return copy.text("Reference Skill included", ru: "Справочный Skill включён")
        case "optional": return copy.text("Optional dependency", ru: "Дополнительная зависимость")
        default: return copy.text("External install", ru: "Внешняя установка")
        }
    }
    private func statusColor(_ status: String) -> Color {
        status == "engine" || status == "reference" ? .green : .secondary
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 19) {
                header
                content()
            }
            .frame(maxWidth: 710)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Iumrah Business")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Kepler Studio").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { chrome.leaveKeplerBusinessMode() } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .iumrahGlass(in: Circle(), interactive: true, chrome: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copy.text("Return to Iumrah", ru: "Вернуться в Iumrah"))
            .accessibilityIdentifier("kepler.business.exit")
        }
    }

    private func metric(_ number: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(number).font(.system(size: 31, weight: .bold, design: .rounded))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22))
    }

    private func surface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24))
    }

    private func iconTile(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 47, height: 47)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
    }
    private func actionLabel(_ title: String, systemName: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: systemName)
            Text(title).font(.headline)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 20), interactive: true, chrome: true)
    }

    private func statusNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text(message).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 21))
    }
    private var missingFile: some View {
        Label(copy.text("Bundled file unavailable", ru: "Файл не найден в ресурсах приложения"), systemImage: "exclamationmark.triangle")
            .font(.footnote).foregroundStyle(.secondary)
    }
}

private struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.title2.weight(.bold)).frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Generic visual sample — never a recreation of the user's original card.
private struct KeplerMotionPresetSheet: View {
    let preset: KeplerStudioPreset
    let language: String
    @Environment(\.dismiss) private var dismiss
    @State private var visible = true
    private var isRU: Bool { language == "ru" || language == "uz-cyrl" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    Text(preset.title).font(.system(size: 29, weight: .bold, design: .rounded))
                    Text(preset.detail).font(.subheadline).foregroundStyle(.secondary)
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color(.secondarySystemGroupedBackground))
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.iumrahCardBackground)
                            .frame(width: 204, height: 118)
                            .overlay {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 36, weight: .ultraLight))
                                    .foregroundStyle(.secondary)
                            }
                            .shadow(color: .black.opacity(0.08), radius: 16, y: 7)
                            .opacity(visible ? 1 : 0)
                            .offset(x: preset.id == "slide_right_soft" ? (visible ? 0 : -20) : 0,
                                    y: preset.id == "fade" ? 0 : (visible ? 0 : 20))
                            .scaleEffect(visible ? 1 : 0.98)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .accessibilityLabel(isRU ? "Демонстрация движения абстрактной карточки" : "Generic motion preview")

                    Button {
                        visible = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                            withAnimation(.easeOut(duration: Double(preset.entryMs) / 1000.0)) {
                                visible = true
                            }
                        }
                    } label: {
                        Label(isRU ? "Повторить анимацию" : "Replay motion", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(15)
                            .iumrahGlass(in: Capsule(), interactive: true, chrome: true)
                    }.buttonStyle(.plain)
                    Text(isRU ? "Предпросмотр на нейтральном примере. Исходные карточки Iumrah не меняются и не перерисовываются." : "Neutral example only. Original Iumrah artwork is never redrawn.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Entry \(preset.entryMs) ms · Exit \(preset.exitMs) ms")
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                .padding(22)
            }
            .navigationTitle("Kepler Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(isRU ? "Готово" : "Done") { dismiss() } } }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
        }
    }
}
