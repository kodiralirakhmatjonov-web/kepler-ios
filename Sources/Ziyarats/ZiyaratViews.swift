import SwiftUI
import MapKit
import UIKit

private enum ZiyaratJourneyCity: String, CaseIterable, Identifiable {
    case madinah = "Madinah"
    case makkah = "Makkah"
    var id: String { rawValue }
}

/// Stable production Ziyarats page.
/// This intentionally avoids the previous nested custom sheet/detent state machine,
/// which could enter an invalid presentation state while the navigation destination
/// was appearing. The page is now one native navigation surface: city switcher,
/// MapKit map, and card-based route content.
struct ZiyaratJourneyView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var selectedCity: ZiyaratJourneyCity = .madinah
    @State private var route = ZiyaratSeedData.medina
    @State private var camera: MapCameraPosition = .region(Self.defaultRegion(.madinah))
    @State private var isLoading = true
    @State private var selectedPlace: ZiyaratPlace?

    private var places: [ZiyaratPlace] {
        route.places.sorted { $0.routeOrder < $1.routeOrder }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                citySwitcher
                mapCard
                routeHeader
                placesGrid
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle("iumrah Ziyarats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await load(selectedCity) }
        .onChange(of: selectedCity) { _, city in
            IumrahHaptics.selection()
            Task { await load(city) }
        }
        .sheet(item: $selectedPlace) { place in
            NavigationStack {
                ZiyaratPlaceDetailView(place: place)
                    .environmentObject(settings)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var citySwitcher: some View {
        Picker("", selection: $selectedCity) {
            Text(localized("Медина", "Madinah", "Madina", "Мадина")).tag(ZiyaratJourneyCity.madinah)
            Text(localized("Мекка", "Makkah", "Makka", "Макка")).tag(ZiyaratJourneyCity.makkah)
        }
        .pickerStyle(.segmented)
    }

    private var mapCard: some View {
        Map(position: $camera) {
            ForEach(places) { place in
                Annotation(
                    place.localizedContent(locale: settings.language.rawValue).title,
                    coordinate: place.coordinate,
                    anchor: .bottom
                ) {
                    Button {
                        selectedPlace = place
                    } label: {
                        VStack(spacing: -2) {
                            Text("\(place.routeOrder)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.black, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                                .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 7))
                                .rotationEffect(.degrees(180))
                                .foregroundStyle(.black)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8)
        }
        .overlay(alignment: .topTrailing) {
            if isLoading {
                ProgressView()
                    .padding(12)
                    .background(.thinMaterial, in: Circle())
                    .padding(12)
            }
        }
    }

    private var routeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localized("Маршрут зиярата", "Ziyarat route", "Ziyorat yo‘nalishi", "Зиёрат йўналиши"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.55)
            Text(localized(
                "Все включённые места показаны карточками в порядке посещения. Нажмите на место, чтобы увидеть историю, фото и точку на карте.",
                "All included places are shown in visit order. Open a place to see its story, photos and map point.",
                "Barcha kiritilgan joylar tashrif tartibida ko‘rsatilgan. Tarix, rasmlar va xaritadagi nuqtani ko‘rish uchun joyni oching.",
                "Барча киритилган жойлар ташриф тартибида кўрсатилган. Тарих, расмлар ва харитадаги нуқтани кўриш учун жойни очинг."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var placesGrid: some View {
        if places.isEmpty && !isLoading {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(localized("Пока нет опубликованных мест", "No published places yet", "Hozircha joylar chop etilmagan", "Ҳозирча жойлар чоп этилмаган"))
                    .font(.headline)
                Text(localized(
                    "Точки, опубликованные в iumrah Business, появятся здесь автоматически.",
                    "Places published in iumrah Business appear here automatically.",
                    "iumrah Business’da chop etilgan joylar bu yerda avtomatik ko‘rinadi.",
                    "iumrah Business’да чоп этилган жойлар бу ерда автоматик кўринади."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahCard()
        } else {
            LazyVStack(spacing: 14) {
                ForEach(places) { place in
                    Button {
                        selectedPlace = place
                    } label: {
                        ZiyaratPlaceCard(place: place)
                            .environmentObject(settings)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func load(_ city: ZiyaratJourneyCity) async {
        isLoading = true
        selectedPlace = nil
        let loaded = await ZiyaratService.shared.route(city: city.rawValue)
        route = loaded
        camera = .region(loaded.places.isEmpty ? Self.defaultRegion(city) : Self.region(loaded.places, fallback: city))
        isLoading = false
    }

    private static func defaultRegion(_ city: ZiyaratJourneyCity) -> MKCoordinateRegion {
        switch city {
        case .madinah:
            return MKCoordinateRegion(center: .init(latitude: 24.4672, longitude: 39.6111), span: .init(latitudeDelta: 0.12, longitudeDelta: 0.12))
        case .makkah:
            return MKCoordinateRegion(center: .init(latitude: 21.4038, longitude: 39.8926), span: .init(latitudeDelta: 0.16, longitudeDelta: 0.18))
        }
    }

    private static func region(_ places: [ZiyaratPlace], fallback: ZiyaratJourneyCity) -> MKCoordinateRegion {
        guard let first = places.first else { return defaultRegion(fallback) }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for place in places.dropFirst() {
            minLat = min(minLat, place.latitude); maxLat = max(maxLat, place.latitude)
            minLon = min(minLon, place.longitude); maxLon = max(maxLon, place.longitude)
        }
        return MKCoordinateRegion(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: .init(latitudeDelta: max(0.035, (maxLat - minLat) * 1.8), longitudeDelta: max(0.035, (maxLon - minLon) * 1.8))
        )
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

/// Card catalog used from Booking → What's included → Ziyarats.
/// It is intentionally a full, useful sheet rather than the old two-line explainer.
struct ZiyaratIncludedCatalogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var city: ZiyaratJourneyCity = .makkah
    @State private var route = ZiyaratSeedData.fallback(city: "Makkah")
    @State private var isLoading = true

    private var places: [ZiyaratPlace] { route.places.sorted { $0.routeOrder < $1.routeOrder } }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("", selection: $city) {
                        Text(localized("Мекка", "Makkah", "Makka", "Макка")).tag(ZiyaratJourneyCity.makkah)
                        Text(localized("Медина", "Madinah", "Madina", "Мадина")).tag(ZiyaratJourneyCity.madinah)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(localized("Места Вашей программы", "Places in your program", "Dasturingizdagi joylar", "Дастурингиздаги жойлар"))
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                        Text(localized(
                            "Все точки, куда Вас повезёт команда iumrah, собраны здесь карточками.",
                            "Every place your iumrah team will take you is collected here as a card.",
                            "iumrah jamoasi olib boradigan barcha joylar shu yerda kartalar ko‘rinishida jamlangan.",
                            "iumrah жамоаси олиб борадиган барча жойлар шу ерда карталар кўринишида жамланган."
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
                    } else if places.isEmpty {
                        Text(localized("Пока нет опубликованных точек для этого города.", "No published stops for this city yet.", "Bu shahar uchun hozircha joylar yo‘q.", "Бу шаҳар учун ҳозирча жойлар йўқ."))
                            .foregroundStyle(.secondary)
                            .iumrahCard()
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(places) { place in
                                NavigationLink {
                                    ZiyaratPlaceDetailView(place: place)
                                        .environmentObject(settings)
                                } label: {
                                    ZiyaratPlaceCard(place: place)
                                        .environmentObject(settings)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle("iumrah Ziyarats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .task { await load(city) }
            .onChange(of: city) { _, newValue in Task { await load(newValue) } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @MainActor private func load(_ city: ZiyaratJourneyCity) async {
        isLoading = true
        route = await ZiyaratService.shared.route(city: city.rawValue)
        isLoading = false
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}

private struct ZiyaratPlaceCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let place: ZiyaratPlace

    private var content: ZiyaratPlaceTranslation { place.localizedContent(locale: settings.language.rawValue) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZiyaratPlaceImage(place: place)
                .frame(height: 190)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(place.routeOrder)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.black, in: Circle())
                    Text(content.title)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                Text(content.shortDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Label("\(place.durationMinutes) min", systemImage: "clock")
                    Label(place.category.capitalized, systemImage: "mappin.and.ellipse")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.035), radius: 14, y: 6)
    }
}

private struct ZiyaratPlaceImage: View {
    let place: ZiyaratPlace

    var body: some View {
        if let first = place.images.sorted(by: { $0.position < $1.position }).first {
            if let asset = first.bundledAssetName {
                Image(asset).resizable().scaledToFill()
            } else if let url = URL(string: first.url) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Color.iumrahRaisedBackground.overlay {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ZiyaratPlaceDetailView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.openURL) private var openURL
    let place: ZiyaratPlace

    private var content: ZiyaratPlaceTranslation { place.localizedContent(locale: settings.language.rawValue) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if !place.images.isEmpty {
                    TabView {
                        ForEach(place.images.sorted(by: { $0.position < $1.position })) { image in
                            if let asset = image.bundledAssetName {
                                Image(asset).resizable().scaledToFill()
                            } else if let url = URL(string: image.url) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image): image.resizable().scaledToFill()
                                    default: Color.iumrahRaisedBackground
                                    }
                                }
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: 310)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(content.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .tracking(-0.6)
                    if !place.titleArabic.isEmpty {
                        Text(place.titleArabic).font(.title3).foregroundStyle(.secondary)
                    }
                    Text(content.longDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !content.interestingFacts.isEmpty {
                    detailSection(title: localized("Интересные факты", "Interesting facts", "Qiziqarli faktlar", "Қизиқарли фактлар"), icon: "sparkles") {
                        ForEach(Array(content.interestingFacts.enumerated()), id: \.offset) { _, fact in
                            Label(fact, systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !content.visitNotes.isEmpty {
                    detailSection(title: localized("Как проходит остановка", "Visit notes", "Tashrif tartibi", "Ташриф тартиби"), icon: "figure.walk") {
                        Text(content.visitNotes).font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                Button {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
                    item.name = content.title
                    item.openInMaps()
                } label: {
                    HStack {
                        Image(systemName: "map.fill")
                        Text(localized("Открыть в Картах", "Open in Maps", "Xaritada ochish", "Харитада очиш"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(content.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}
