import SwiftUI

struct BookingScheduleView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    let bookingID: String

    @State private var showBookingPage = false
    @State private var showStatusPage = false

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        Group {
            if let session {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BookingPageSwitcher(
                            selection: .schedule,
                            onBooking: { showBookingPage = true },
                            onStatus: { showStatusPage = true },
                            onSchedule: {}
                        )

                        summaryCard(session)

                        BookingItineraryCalendarView(
                            bookingID: session.id,
                            startDate: session.booking.input.startDate,
                            endDate: session.booking.input.endDate,
                            booking: session.booking,
                            presentation: .fullScreen
                        )
                    }
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .padding(.top, 12)
                    .padding(.bottom, 44)
                }
                .background(Color.iumrahPageBackground)
                .toolbar(.hidden, for: .tabBar)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                    Text(localized("Расписание не найдено", "Schedule not found", "Jadval topilmadi", "Жадвал топилмади"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.iumrahPageBackground)
            }
        }
        .navigationTitle(localized("Расписание", "Schedule", "Jadval", "Жадвал"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showBookingPage) {
            BookingDetailView(bookingID: bookingID)
        }
        .navigationDestination(isPresented: $showStatusPage) {
            PilgrimCheckoutView(bookingID: bookingID, presentation: .screen)
        }
    }

    private func summaryCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                IumrahIconBadge(systemName: "clock.badge.checkmark", role: .calendar, size: 48, symbolSize: 18, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(L10n.date(session.booking.input.startDate, settings.language)) – \(L10n.date(session.booking.input.endDate, settings.language))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(localized(
                "iumrah показывает поездку как цепочку по времени: прилёт, выход из аэропорта, трансферы, заселение, Умра, зияраты и вылет.",
                "iumrah shows the journey as a timed chain: arrival, airport exit, transfers, hotel check-in, Umrah, visits and departure.",
                "iumrah safarni vaqt bo‘yicha zanjir sifatida ko‘rsatadi: kelish, aeroportdan chiqish, transfer, joylashish, Umra, ziyoratlar va jo‘nab ketish.",
                "iumrah сафарни вақт бўйича занжир сифатида кўрсатади: келиш, аэропортдан чиқиш, трансфер, жойлашиш, Умра, зиёратлар ва жўнаб кетиш."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .malay, .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
