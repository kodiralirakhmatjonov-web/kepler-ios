import SwiftUI

/// Booking-scoped passport hub used from Status.
/// Unlike Account → Who is traveling with you, this page intentionally includes
/// the booking owner as well as every companion so the whole group can be cleared
/// without sending the user through KYC or long forms.
struct IumrahBookingPassportsView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    let bookingID: String

    @State private var checkout: IumrahCheckoutResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let service = IumrahAccountService()

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                securityAnimationCard
                instructionCard

                if isLoading && checkout == nil {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(tr("Loading passports…", "Загружаем паспорта…", "Pasportlar yuklanmoqda…", "Паспортлар юкланмоқда…"))
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .iumrahCard()
                } else if let travelers = checkout?.travelers, !travelers.isEmpty {
                    ForEach(travelers) { traveler in
                        NavigationLink {
                            IumrahTravelerProfileView(
                                bookingID: bookingID,
                                traveler: traveler,
                                onSaved: { Task { await loadCheckout(showLoader: false) } }
                            )
                        } label: {
                            travelerRow(traveler)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(tr("No travelers found.", "Участники не найдены.", "Sayohatchilar topilmadi.", "Саёҳатчилар топилмади."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .iumrahCard()
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(tr("Passports", "Паспорта", "Pasportlar", "Паспортлар"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await loadCheckout(showLoader: false) }
        .task { await loadCheckout(showLoader: true) }
    }

    private var securityAnimationCard: some View {
        VStack(spacing: 10) {
            LoopingVideoView(resource: "iumrah-security-identity", gravity: .resizeAspect)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            HStack(spacing: 9) {
                Image(systemName: "lock.shield.fill")
                Text(tr("Passport data is handled securely for your booking.", "Паспортные данные защищены и используются только для оформления поездки.", "Pasport ma’lumotlari himoyalangan va faqat safarni rasmiylashtirish uchun ishlatiladi.", "Паспорт маълумотлари ҳимояланган ва фақат сафарни расмийлаштириш учун ишлатилади."))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(tr("Attach passports", "Прикрепите паспорта", "Pasportlarni biriktiring", "Паспортларни бириктиринг"))
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(-0.6)
            Text(tr(
                "One clear information-page photo for every pilgrim is enough. Manual fields are optional.",
                "Для каждого паломника достаточно одной чёткой фотографии страницы с данными. Ручное заполнение — по желанию.",
                "Har bir ziyoratchi uchun ma’lumotlar sahifasining bitta aniq rasmi yetarli. Qo‘lda to‘ldirish ixtiyoriy.",
                "Ҳар бир зиёратчи учун маълумотлар саҳифасининг битта аниқ расми етарли. Қўлда тўлдириш ихтиёрий."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var instructionCard: some View {
        Label {
            Text(tr(
                "All passport fields must be visible. Iumrah uses them to issue tickets, reserve hotels and prepare booking documents.",
                "Все данные паспорта должны быть видны. Iumrah использует их для оформления авиабилетов, бронирования отелей и подготовки документов.",
                "Pasportdagi barcha ma’lumotlar ko‘rinishi kerak. Iumrah ulardan chipta, mehmonxona va bron hujjatlarini rasmiylashtirishda foydalanadi.",
                "Паспортдаги барча маълумотлар кўриниши керак. Iumrah улардан чипта, меҳмонхона ва брон ҳужжатларини расмийлаштиришда фойдаланади."
            ))
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.orange)
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func travelerRow(_ traveler: IumrahTravelerForm) -> some View {
        HStack(spacing: 14) {
            IumrahIconBadge(
                systemName: traveler.hasPassport ? "checkmark.circle.fill" : "passport.fill",
                role: traveler.hasPassport ? .success : .document,
                size: 52,
                symbolSize: 21,
                cornerRadius: 17
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(travelerName(traveler))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(traveler.hasPassport
                     ? tr("Passport attached", "Паспорт прикреплён", "Pasport biriktirilgan", "Паспорт бириктирилган")
                     : tr("Passport photo required", "Нужно фото паспорта", "Pasport rasmi kerak", "Паспорт расми керак"))
                    .font(.subheadline)
                    .foregroundStyle(traveler.hasPassport ? Color.green : Color.secondary)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(17)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @MainActor
    private func loadCheckout(showLoader: Bool) async {
        guard let session else {
            errorMessage = tr("Booking not found.", "Бронирование не найдено.", "Bron topilmadi.", "Брон топилмади.")
            isLoading = false
            return
        }

        if showLoader { isLoading = true }
        errorMessage = nil
        defer { isLoading = false }

        do {
            checkout = try await service.checkout(
                bookingID: bookingID,
                bookingToken: session.accessToken,
                accountToken: account.bearerToken
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func travelerName(_ traveler: IumrahTravelerForm) -> String {
        let name = [traveler.firstName, traveler.middleName, traveler.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { return name }
        let relationship = traveler.relationship?.lowercased() ?? ""
        if relationship == "self" || traveler.position == 1 {
            return tr("Booking holder", "Владелец бронирования", "Bron egasi", "Брон эгаси")
        }
        return tr("Traveler \(traveler.position)", "Участник \(traveler.position)", "Sayohatchi \(traveler.position)", "Саёҳатчи \(traveler.position)")
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
