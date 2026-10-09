import SwiftUI
import MapKit
import UIKit
import ImageIO

// Rebuilt 2026-10-09. Ziyarats has an immediately usable offline screen.
// The map is opt-in and never constructed while entering this page.
// No custom bottom-sheet gestures, MKDirections, auto-playing animations,
// UserDefaults catalogue reads, or speculative image prefetching.

private enum ZiyaratCity: String, CaseIterable, Identifiable {
    case madinah = "Madinah"
    case makkah = "Makkah"
    var id: String { rawValue }
}

private struct ZiyaratCopy {
    let language: AppSettingsStore.Language
    func text(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch language {
        case .russian: return ru
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
    var locale: String { language.rawValue }
    func city(_ city: ZiyaratCity) -> String {
        city == .makkah ? text("Мекка", "Makkah", "Makka", "Макка") :
            text("Медина", "Madinah", "Madina", "Мадина")
    }
}

struct ZiyaratJourneyView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var selectedCity: ZiyaratCity = .madinah
    @State private var route: ZiyaratRoute = ZiyaratFallbackCatalog.route(city: "Madinah")
    @State private var isLoading = false
    @State private var selectedPlace: ZiyaratPlace?
    @State private var showMap = false

    private var copy: ZiyaratCopy { ZiyaratCopy(language: settings.language) }
    private var orderedPlaces: [ZiyaratPlace] { route.places }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                cityPicker
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(copy.text("Места посещения", "Places to visit", "Ziyorat joylari", "Зиёрат жойлари"))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text(copy.text(
                            "История, фотографии и навигация",
                            "History, photographs and directions",
                            "Tarix, suratlar va yo‘nalish",
                            "Тарих, суратлар ва йўналиш"
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 6)
                    Button { showMap = true } label: {
                        Image(systemName: "map")
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(copy.text("Открыть карту", "Open map", "Xaritani ochish", "Харитани очиш"))
                }

                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(copy.text("Обновляем места…", "Updating places…", "Joylar yangilanmoqda…", "Жойлар янгиланмоқда…"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                if route.status == "offline" && !isLoading {
                    Label(copy.text(
                        "Доступен встроенный каталог. Потяните вниз, чтобы обновить.",
                        "Built-in places are available. Pull to refresh.",
                        "Ichki katalog mavjud. Yangilash uchun pastga torting.",
                        "Ички каталог мавжуд. Янгилаш учун пастга тортинг."
                    ), systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                LazyVStack(spacing: 12) {
                    ForEach(orderedPlaces) { place in
                        Button { selectedPlace = place } label: {
                            ZiyaratPlaceRow(place: place, copy: copy)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if orderedPlaces.isEmpty {
                    ContentUnavailableView(
                        copy.text("Места не найдены", "No places found", "Joylar topilmadi", "Жойлар топилмади"),
                        systemImage: "mappin.slash"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("iumrah Ziyarats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await load(city: selectedCity) }
        .task(id: selectedCity) { await load(city: selectedCity) }
        .sheet(item: $selectedPlace) { place in
            ZiyaratPlaceDetailSheet(place: place, copy: copy)
        }
        .sheet(isPresented: $showMap) {
            ZiyaratMapSheet(places: orderedPlaces, city: selectedCity, copy: copy)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("iumrah Ziyarats")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(copy.text(
                "Открывайте исторические места Мекки и Медины в удобном порядке.",
                "Explore historic sites in Makkah and Madinah at your own pace.",
                "Makka va Madinaning tarixiy joylarini qulay tartibda kashf eting.",
                "Макка ва Мадинанинг тарихий жойларини қулай тартибда кашф этинг."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cityPicker: some View {
        Picker(copy.text("Город", "City", "Shahar", "Шаҳар"), selection: $selectedCity) {
            ForEach(ZiyaratCity.allCases) { city in
                Text(copy.city(city)).tag(city)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedCity) { _, next in
            selectedPlace = nil
            route = ZiyaratFallbackCatalog.route(city: next.rawValue)
        }
    }

    @MainActor
    private func load(city: ZiyaratCity) async {
        isLoading = true
        let updated = await ZiyaratService.shared.route(city: city.rawValue)
        guard !Task.isCancelled, selectedCity == city else { return }
        route = updated
        isLoading = false
    }
}

private struct ZiyaratPlaceRow: View {
    let place: ZiyaratPlace
    let copy: ZiyaratCopy
    private var content: ZiyaratPlaceTranslation { place.localizedContent(locale: copy.locale) }

    var body: some View {
        HStack(spacing: 14) {
            ZiyaratThumbnailView(image: place.images.first)
                .frame(width: 100, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(content.title.isEmpty ? place.title : content.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                Text(content.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Label(copy.text("Подробнее", "View details", "Batafsil", "Батафсил"), systemImage: "arrow.up.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ZiyaratPlaceDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let place: ZiyaratPlace
    let copy: ZiyaratCopy

    private var content: ZiyaratPlaceTranslation { place.localizedContent(locale: copy.locale) }
    private var photos: [ZiyaratImage] { Array(place.images.prefix(8)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let first = photos.first {
                        ZiyaratThumbnailView(image: first)
                            .frame(height: 260)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        ZiyaratSitePlaceholder()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    Text(content.title.isEmpty ? place.title : content.title)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    if !place.titleArabic.isEmpty {
                        Text(place.titleArabic)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text(content.longDescription.isEmpty ? content.shortDescription : content.longDescription)
                        .font(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    if !content.interestingFacts.isEmpty {
                        Text(copy.text("Интересные факты", "Interesting facts", "Qiziqarli ma’lumotlar", "Қизиқарли маълумотлар"))
                            .font(.headline)
                        ForEach(Array(content.interestingFacts.prefix(10).enumerated()), id: \.offset) { _, fact in
                            Label(fact, systemImage: "info.circle")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if !content.visitNotes.isEmpty {
                        Label(content.visitNotes, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if photos.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(photos.dropFirst()) { photo in
                                    ZiyaratThumbnailView(image: photo)
                                        .frame(width: 210, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                    }
                    Button { ZiyaratExternalMaps.open(place) } label: {
                        Label(copy.text("Маршрут в Apple Maps", "Directions in Apple Maps", "Apple Maps orqali yo‘nalish", "Apple Maps орқали йўналиш"), systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.text("Место", "Place", "Joy", "Жой"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.text("Готово", "Done", "Tayyor", "Тайёр")) { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

// The MapKit view exists only inside this user-invoked sheet. No polylines,
// MKDirections, custom camera animations or continuous route re-calculations.
private struct ZiyaratMapSheet: View {
    @Environment(\.dismiss) private var dismiss
    let places: [ZiyaratPlace]
    let city: ZiyaratCity
    let copy: ZiyaratCopy
    @State private var chosen: ZiyaratPlace?

    private var region: MKCoordinateRegion {
        let center = city == .makkah
            ? CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
            : CLLocationCoordinate2D(latitude: 24.4672, longitude: 39.6100)
        let valid = places.filter { ZiyaratService.validCoordinate($0.latitude, $0.longitude) }
        guard !valid.isEmpty else {
            return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10))
        }
        let minLat = valid.map(\.latitude).min() ?? center.latitude
        let maxLat = valid.map(\.latitude).max() ?? center.latitude
        let minLon = valid.map(\.longitude).min() ?? center.longitude
        let maxLon = valid.map(\.longitude).max() ?? center.longitude
        return MKCoordinateRegion(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: .init(latitudeDelta: min(max((maxLat - minLat) * 1.45, 0.025), 1.0),
                        longitudeDelta: min(max((maxLon - minLon) * 1.45, 0.025), 1.0))
        )
    }

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(region)) {
                ForEach(places.filter { ZiyaratService.validCoordinate($0.latitude, $0.longitude) }) { place in
                    Annotation(place.localizedContent(locale: copy.locale).title,
                               coordinate: place.coordinate, anchor: .bottom) {
                        Button { chosen = place } label: {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.orange)
                                .background(.white, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, showsTraffic: false))
            .safeAreaInset(edge: .bottom) {
                if let chosen {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(chosen.localizedContent(locale: copy.locale).title)
                                .font(.headline)
                                .lineLimit(2)
                            Text(copy.city(city))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { ZiyaratExternalMaps.open(chosen) } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                    }
                    .padding(16)
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 22))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle(copy.city(city))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.text("Закрыть", "Close", "Yopish", "Ёпиш")) { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

private enum ZiyaratExternalMaps {
    static func open(_ place: ZiyaratPlace) {
        guard ZiyaratService.validCoordinate(place.latitude, place.longitude) else { return }
        let point = MKPlacemark(coordinate: place.coordinate)
        let item = MKMapItem(placemark: point)
        item.name = place.title
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

private struct ZiyaratSitePlaceholder: View {
    var body: some View {
        ZStack {
            Color(uiColor: .tertiarySystemGroupedBackground)
            Image(systemName: "building.columns.fill")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ZiyaratThumbnailView: View {
    let image: ZiyaratImage?
    @State private var loaded: UIImage?

    var body: some View {
        ZStack {
            ZiyaratSitePlaceholder()
            if let loaded {
                Image(uiImage: loaded)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        }
        .task(id: image?.url) {
            loaded = nil
            guard let image else { return }
            let thumbnail = await ZiyaratThumbnailLoader.load(image)
            guard !Task.isCancelled else { return }
            loaded = thumbnail
        }
        .accessibilityHidden(true)
    }
}

// ImageIO downsampling from a temporary file avoids allocating full-size
// UIImage bitmaps. Only visible thumbnails request network data.
private enum ZiyaratThumbnailLoader {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 20 * 1024 * 1024
        cache.countLimit = 24
        return cache
    }()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    static func load(_ image: ZiyaratImage) async -> UIImage? {
        let key = image.url as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let thumbnail: UIImage?
        if let bundledName = image.bundledAssetName {
            // The seed's bundled photos are already controlled application assets.
            thumbnail = UIImage(named: bundledName)
        } else {
            guard let url = URL(string: image.url), url.scheme?.lowercased() == "https" else { return nil }
            do {
                let (file, response) = try await session.download(from: url)
                defer { try? FileManager.default.removeItem(at: file) }
                guard !Task.isCancelled, (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 0),
                      response.expectedContentLength <= 8 * 1024 * 1024 else { return nil }
                let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0
                guard size > 0, size <= 8 * 1024 * 1024 else { return nil }
                thumbnail = await Task.detached(priority: .utility) {
                    let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
                    guard let source = CGImageSourceCreateWithURL(file as CFURL, options as CFDictionary) else { return nil as UIImage? }
                    let thumbOptions: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 850
                    ]
                    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else { return nil }
                    return UIImage(cgImage: cg)
                }.value
            } catch {
                return nil
            }
        }
        guard !Task.isCancelled, let thumbnail else { return nil }
        let cost = Int(thumbnail.size.width * thumbnail.scale * thumbnail.size.height * thumbnail.scale * 4)
        cache.setObject(thumbnail, forKey: key, cost: min(cost, 20 * 1024 * 1024))
        return thumbnail
    }
}

// Also rebuild the booking-facing Ziyarats screen; it shares the validated
// catalogue but has no separate background prefetch or SwiftUI page-index state.
struct ZiyaratIncludedCatalogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var selectedCity: ZiyaratCity = .makkah
    @State private var route = ZiyaratFallbackCatalog.route(city: "Makkah")
    @State private var selectedPlace: ZiyaratPlace?
    @State private var isLoading = false

    private var copy: ZiyaratCopy { ZiyaratCopy(language: settings.language) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker(copy.text("Город", "City", "Shahar", "Шаҳар"), selection: $selectedCity) {
                        ForEach(ZiyaratCity.allCases) { city in
                            Text(copy.city(city)).tag(city)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(copy.text("Места вашей программы", "Places in your program", "Dasturingizdagi joylar", "Дастурингиздаги жойлар"))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    if isLoading { ProgressView().controlSize(.small) }
                    LazyVStack(spacing: 12) {
                        ForEach(route.places) { place in
                            Button { selectedPlace = place } label: {
                                ZiyaratPlaceRow(place: place, copy: copy)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("iumrah Ziyarats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.text("Готово", "Done", "Tayyor", "Тайёр")) { dismiss() }
                }
            }
            .task(id: selectedCity) {
                await load(city: selectedCity)
            }
            .onChange(of: selectedCity) { _, next in
                selectedPlace = nil
                route = ZiyaratFallbackCatalog.route(city: next.rawValue)
            }
            .sheet(item: $selectedPlace) { place in
                ZiyaratPlaceDetailSheet(place: place, copy: copy)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func load(city: ZiyaratCity) async {
        isLoading = true
        let response = await ZiyaratService.shared.route(city: city.rawValue)
        guard !Task.isCancelled, selectedCity == city else { return }
        route = response
        isLoading = false
    }
}
