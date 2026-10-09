import SwiftUI
import MapKit

/// A native MapKit globe used by iumrah Flights.
///
/// The map intentionally keeps direct pan / zoom / rotate interaction enabled so the
/// globe feels alive rather than like a static marketing image. It is reusable on the
/// Flights hero and the Home footer while keeping the visual overlays outside of MapKit
/// so they never swallow map gestures.
struct IumrahInteractiveGlobe: View {
    @EnvironmentObject private var settings: AppSettingsStore
    enum Presentation {
        case flightRoute
        case worldToMakkah
    }

    let presentation: Presentation

    @State private var position: MapCameraPosition

    private static let tashkent = CLLocationCoordinate2D(latitude: 41.2579, longitude: 69.2812)
    private static let jeddah = CLLocationCoordinate2D(latitude: 21.6702, longitude: 39.1525)
    private static let makkah = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    init(presentation: Presentation) {
        self.presentation = presentation

        let camera: MapCamera
        switch presentation {
        case .flightRoute:
            camera = MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: 28.0, longitude: 48.0),
                distance: 16_800_000,
                heading: 0,
                pitch: 0
            )
        case .worldToMakkah:
            camera = MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: 24.0, longitude: 37.0),
                distance: 18_600_000,
                heading: 0,
                pitch: 0
            )
        }

        _position = State(initialValue: .camera(camera))
    }

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom, .rotate]) {
            switch presentation {
            case .flightRoute:
                MapPolyline(coordinates: [Self.tashkent, Self.jeddah], contourStyle: .geodesic)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.96), .blue.opacity(0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [4, 6])
                    )

                Annotation("TAS", coordinate: Self.tashkent, anchor: .center) {
                    routePoint(code: "TAS", accent: .blue)
                }

                Annotation("JED", coordinate: Self.jeddah, anchor: .center) {
                    routePoint(code: "JED", accent: .blue)
                }

            case .worldToMakkah:
                Annotation("Makkah", coordinate: Self.makkah, anchor: .center) {
                    makkahPoint
                }
            }
        }
        .mapStyle(
            .hybrid(
                elevation: .realistic,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(IumrahAccessibilityCopy.text(settings.language, ru: "Вращайте, перетаскивайте или увеличивайте глобус", en: "Drag, pinch or rotate the globe", uz: "Globusni suring, kattalashtiring yoki aylantiring", cy: "Глобусни суринг, катталаштиринг ёки айлантиринг", tr: "Küreyi sürükleyin, yakınlaştırın veya döndürün", id: "Geser, cubit untuk memperbesar, atau putar globe"))
    }

    private var accessibilityLabel: String {
        switch presentation {
        case .flightRoute:
            return IumrahAccessibilityCopy.text(settings.language, ru: "Интерактивный глобус авиарейсов iumrah", en: "Interactive iumrah Flights globe", uz: "iumrah parvozlarining interaktiv globusi", cy: "iumrah парвозларининг интерактив глобуси", tr: "iumrah uçuşları için etkileşimli küre", id: "Globe interaktif penerbangan iumrah")
        case .worldToMakkah:
            return IumrahAccessibilityCopy.text(settings.language, ru: "Интерактивный глобус с центром в Мекке", en: "Interactive world globe centered on Makkah", uz: "Markazi Makka bo‘lgan interaktiv globus", cy: "Маркази Макка бўлган интерактив глобус", tr: "Merkezi Mekke olan etkileşimli dünya küresi", id: "Globe dunia interaktif dengan pusat di Makkah")
        }
    }

    private func routePoint(code: String, accent: Color) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .blur(radius: 7)

                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
                    .overlay {
                        Circle()
                            .stroke(accent.opacity(0.86), lineWidth: 2)
                    }
            }

            Text(code)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.black.opacity(0.58), in: Capsule())
        }
    }

    private var makkahPoint: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 38, height: 38)
                    .blur(radius: 9)

                Circle()
                    .fill(.white)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .stroke(.black.opacity(0.72), lineWidth: 2)
                    }
            }

            Text("Makkah")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.black.opacity(0.62), in: Capsule())
        }
    }
}
