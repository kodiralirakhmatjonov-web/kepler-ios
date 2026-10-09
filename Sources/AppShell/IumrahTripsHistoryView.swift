import SwiftUI

private enum IumrahTripsHistoryScope: String, CaseIterable, Identifiable {
    case active
    case past
    var id: String { rawValue }
}

struct IumrahTripsHistoryView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let sessions: [StoredBookingSession]
    @State private var scope: IumrahTripsHistoryScope

    init(sessions: [StoredBookingSession], initialScopePast: Bool = false) {
        self.sessions = sessions
        _scope = State(initialValue: initialScopePast ? .past : .active)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Picker("", selection: $scope) {
                    Text(localized("Активные", "Active", "Faol", "Фаол")).tag(IumrahTripsHistoryScope.active)
                    Text(localized("Прошлые", "Past", "Oldingi", "Олдинги")).tag(IumrahTripsHistoryScope.past)
                }
                .pickerStyle(.segmented)
                .onChange(of: scope) { _, _ in IumrahHaptics.selection() }

                if filteredSessions.isEmpty {
                    emptyCard
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSessions) { session in
                            NavigationLink {
                                BookingDetailView(bookingID: session.id)
                            } label: {
                                tripCard(session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 14)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(localized("Мои поездки", "My trips", "Safarlarim", "Сафарларим"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var filteredSessions: [StoredBookingSession] {
        sessions.filter { session in
            let status = session.effectiveStatus.uppercased()
            switch scope {
            case .active:
                return !["COMPLETED", "CANCELLED"].contains(status)
            case .past:
                return ["COMPLETED", "CANCELLED"].contains(status)
            }
        }
        .sorted { lhs, rhs in
            if lhs.booking.input.startDate == rhs.booking.input.startDate {
                return lhs.booking.createdAt > rhs.booking.createdAt
            }
            return lhs.booking.input.startDate > rhs.booking.input.startDate
        }
    }

    private var emptyCard: some View {
        HStack(spacing: 14) {
            Image(systemName: scope == .active ? "suitcase" : "clock.arrow.circlepath")
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 54, height: 54)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), allowsStaticGlass: true, chrome: true)

            VStack(alignment: .leading, spacing: 5) {
                Text(scope == .active
                     ? localized("Нет активных поездок", "No active trips", "Faol safar yo‘q", "Фаол сафар йўқ")
                     : localized("История пока пуста", "No past trips yet", "Tarix hozircha bo‘sh", "Тарих ҳозирча бўш"))
                    .font(.headline)
                Text(scope == .active
                     ? localized("Новая бронь появится здесь автоматически.", "A new booking will appear here automatically.", "Yangi bron shu yerda avtomatik paydo bo‘ladi.", "Янги брон шу ерда автоматик пайдо бўлади.")
                     : localized("Завершённые и отменённые поездки будут храниться здесь.", "Completed and cancelled trips will stay here.", "Yakunlangan va bekor qilingan safarlar shu yerda saqlanadi.", "Якунланган ва бекор қилинган сафарлар шу ерда сақланади."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), allowsStaticGlass: true)
    }

    private func tripCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusIcon(session.effectiveStatus))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(IumrahBookingStatusVisual.color(for: session.effectiveStatus))
                    .frame(width: 46, height: 46)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), allowsStaticGlass: true, chrome: true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("\(L10n.date(session.booking.input.startDate, settings.language)) — \(L10n.date(session.booking.input.endDate, settings.language))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 15)
            }

            HStack(spacing: 8) {
                Text(L10n.status(session.effectiveStatus, settings.language))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(IumrahBookingStatusVisual.color(for: session.effectiveStatus))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(IumrahBookingStatusVisual.color(for: session.effectiveStatus).opacity(0.10), in: Capsule())
                Text(session.displayBookingNumber)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground, in: Capsule())
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status.uppercased() {
        case "COMPLETED": return "checkmark.circle.fill"
        case "CANCELLED": return "xmark.circle.fill"
        case "IN_TRIP": return "location.fill"
        case "READY_TO_TRAVEL", "DOCUMENTS_READY": return "airplane.departure"
        case "BOOKING_CONFIRMED", "PAID": return "checkmark.seal.fill"
        default: return "clock.fill"
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .turkish: return TurkishLocalization.phrase(en)
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cy
        }
    }
}
