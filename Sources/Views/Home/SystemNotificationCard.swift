import SwiftUI

struct SystemNotificationCard: View {
    let notification: ClientSystemNotification
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var settings: AppSettingsStore

    private let cardCorner: CGFloat = 28
    private let cardHeight: CGFloat = 184

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(signalGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                }

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 210, height: 210)
                .offset(x: 210, y: -78)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 9) {
                    HStack(spacing: 7) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("iumrah Signal")
                            .font(.caption.weight(.bold))
                            .tracking(0.35)
                    }
                    .foregroundStyle(Color.white.opacity(0.96))

                    if !notification.isRead {
                        Text(tr("NEW", "НОВОЕ", "YANGI", "ЯНГИ"))
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .frame(height: 23)
                            .background(Color.white.opacity(0.15), in: Capsule(style: .continuous))
                    }

                    Spacer(minLength: 8)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.94))
                            .frame(width: 32, height: 32)
                            .iumrahGlass(
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous),
                                interactive: true,
                                tint: .black.opacity(0.10),
                                chrome: true
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Dismiss", "Скрыть", "Yashirish", "Яшириш"))
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(notification.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .tracking(-0.3)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(notification.body)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.80))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Label(destinationTitle, systemImage: destinationIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Text(tr("Open", "Открыть", "Ochish", "Очиш"))
                            .font(.caption.weight(.bold))
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color.white.opacity(0.97))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .contentShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("iumrah Signal. \(notification.title). \(notification.body)")
    }

    private var signalGradient: LinearGradient {
        let colors: [Color]
        if notification.isRead {
            colors = [
                Color(red: 0.11, green: 0.20, blue: 0.42),
                Color(red: 0.17, green: 0.28, blue: 0.56),
                Color(red: 0.26, green: 0.31, blue: 0.62)
            ]
        } else {
            colors = [
                Color(red: 0.08, green: 0.24, blue: 0.61),
                Color(red: 0.18, green: 0.40, blue: 0.90),
                Color(red: 0.38, green: 0.32, blue: 0.82)
            ]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var signalShadow: Color {
        notification.isRead
            ? Color(red: 0.08, green: 0.18, blue: 0.38).opacity(0.16)
            : Color(red: 0.12, green: 0.32, blue: 0.78).opacity(0.22)
    }

    private var destinationIcon: String {
        switch notification.destination {
        case "hotels": return "building.2.fill"
        case "bookings", "booking": return "suitcase.fill"
        case "care": return "heart.fill"
        case "account": return "person.crop.circle.fill"
        default: return "house.fill"
        }
    }

    private var destinationTitle: String {
        switch notification.destination {
        case "hotels": return tr("Hotels", "Отели", "Mehmonxonalar", "Меҳмонхоналар")
        case "bookings": return tr("Trips", "Поездки", "Safarlar", "Сафарлар")
        case "booking": return tr("Trip details", "Детали поездки", "Safar tafsilotlari", "Сафар тафсилотлари")
        case "care": return "iumrah Care"
        case "account": return "Account"
        default: return tr("Home", "Главная", "Asosiy", "Асосий")
        }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
