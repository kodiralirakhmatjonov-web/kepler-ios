import SwiftUI

struct FlightSearchGateView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let direction: FlightDirection
    let anchorDate: Date
    let flexibility: DateFlexibility
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                IumrahGeneratorHeader(stage: .flight)

                SectionHeader(
                    title,
                    eyebrow: direction == .outbound ? outboundEyebrow : returnEyebrow,
                    subtitle: subtitle
                )

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(statusTitle)
                                .font(.headline.weight(.semibold))
                            Text(dateSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onRetry) {
                        HStack {
                            Text(retryTitle)
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                }
                .iumrahCard()
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 112)
        }
        .background(Color.iumrahPageBackground)
    }

    private var title: String {
        switch settings.language {
        case .russian: return "Поиск перелёта"
        case .turkish: return TurkishLocalization.phrase("Flight search")
        case .indonesian, .malay, .english: return "Flight search"
        case .uzbek: return "Parvoz qidiruvi"
        case .uzbekCyrillic: return "Парвоз қидируви"
        }
    }

    private var statusTitle: String {
        switch settings.language {
        case .russian: return "Рейсы пока не загружены"
        case .turkish: return TurkishLocalization.phrase("Flights are not loaded yet")
        case .indonesian, .malay, .english: return "Flights are not loaded yet"
        case .uzbek: return "Reyslar hali yuklanmadi"
        case .uzbekCyrillic: return "Рейслар ҳали юкланмади"
        }
    }

    private var subtitle: String {
        switch settings.language {
        case .russian: return "Экран выбора откроется только после получения хотя бы одного подтверждённого варианта."
        case .turkish: return TurkishLocalization.phrase("Flight selection opens only after at least one verified option is available.")
        case .indonesian, .malay, .english: return "Flight selection opens only after at least one verified option is available."
        case .uzbek: return "Kamida bitta tasdiqlangan variant kelgandan keyin tanlov ekrani ochiladi."
        case .uzbekCyrillic: return "Камида битта тасдиқланган вариант келгандан кейин танлов экрани очилади."
        }
    }

    private var dateSummary: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let date = formatter.string(from: anchorDate)
        if flexibility.isWeeklyDiscovery {
            switch settings.language {
            case .russian: return "Неделя вокруг \(date)"
            case .turkish: return TurkishLocalization.phrase("Week around \(date)")
            case .indonesian, .malay, .english: return "Week around \(date)"
            case .uzbek: return "\(date) atrofidagi hafta"
            case .uzbekCyrillic: return "\(date) атрофидаги ҳафта"
            }
        }
        return date
    }

    private var retryTitle: String {
        switch settings.language {
        case .russian: return "Повторить поиск"
        case .turkish: return TurkishLocalization.phrase("Retry search")
        case .indonesian, .malay, .english: return "Retry search"
        case .uzbek: return "Qidiruvni takrorlash"
        case .uzbekCyrillic: return "Қидирувни такрорлаш"
        }
    }

    private var outboundEyebrow: String {
        switch settings.language {
        case .russian: return "ТУДА"
        case .turkish: return TurkishLocalization.phrase("OUTBOUND")
        case .indonesian, .malay, .english: return "OUTBOUND"
        case .uzbek: return "BORISH"
        case .uzbekCyrillic: return "БОРИШ"
        }
    }

    private var returnEyebrow: String {
        switch settings.language {
        case .russian: return "ОБРАТНО"
        case .turkish: return TurkishLocalization.phrase("RETURN")
        case .indonesian, .malay, .english: return "RETURN"
        case .uzbek: return "QAYTISH"
        case .uzbekCyrillic: return "ҚАЙТИШ"
        }
    }
}
