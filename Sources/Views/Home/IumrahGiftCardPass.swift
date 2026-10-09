import SwiftUI

/// Portrait Gift Card artwork used by the Gift Card welcome carousel and share sheet.
/// This is content, not chrome: no Liquid Glass, blur material or glass interaction.
struct IumrahGiftCardPass: View {
    let gift: IumrahFriendGift
    let language: AppSettingsStore.Language

    var body: some View {
        ZStack {
            Image(assetName)
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.04),
                    Color.black.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack {
                    Text("iumrah")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(-0.2)
                    Spacer()
                    Text("$100")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 7, y: 2)

                Spacer()

                VStack(spacing: 5) {
                    Text(localized("Gift Card", "Gift Card", "Gift Card", "Gift Card"))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .tracking(-0.65)
                        .multilineTextAlignment(.center)
                    Text(localized(
                        "$100 toward Umrah",
                        "$100 на Умру",
                        "Umrah uchun $100",
                        "Умра учун $100"
                    ))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))

                    Text("#\(gift.position)")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.white.opacity(0.60))
                        .padding(.top, 3)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.34), radius: 9, y: 3)
                .padding(.bottom, 4)
            }
            .padding(18)
        }
        .aspectRatio(0.68, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.24), radius: 22, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localized(
            "iumrah Gift Card number \(gift.position), $100",
            "iumrah Gift Card номер \(gift.position), $100",
            "iumrah Gift Card \(gift.position), $100",
            "iumrah Gift Card \(gift.position), $100"
        ))
    }

    private var assetName: String {
        switch ((gift.position - 1) % 3 + 3) % 3 {
        case 0: return "GiftCardTogether"
        case 1: return "GiftCardKaaba"
        default: return "GiftCardJourney"
        }
    }

    private func localized(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .turkish: return TurkishLocalization.phrase(en)
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
