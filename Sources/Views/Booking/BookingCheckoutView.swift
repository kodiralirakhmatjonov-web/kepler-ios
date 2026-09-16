import SwiftUI

struct BookingCheckoutView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var isSubmitting = false
    @State private var createdSession: StoredBookingSession?
    @State private var errorMessage: String?
    @State private var showProfileSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                summaryHero
                IumrahManualPaymentNotice()
                IumrahRefundPolicyCard(component: .package, compact: false)
                nextStepsCard
                actions
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .ready)
        .navigationDestination(item: $createdSession) { session in
            BookingDetailView(bookingID: session.id)
        }
        .sheet(isPresented: $showProfileSheet) {
            BookingProfileCaptureSheet(onContinue: {
                Task { await submitBooking() }
            })
            .environmentObject(settings)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var summaryHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("checkout_title", settings.language))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(L10n.text("checkout_subtitle", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
            if let hotel = journey.selectedHotel, let quote = journey.quote {
                VStack(alignment: .leading, spacing: 10) {
                    Text(hotel.name).font(.headline)
                    if let roomCategory = journey.selectedRoomCategory {
                        Label(L10n.text(roomCategory.category.titleKey, settings.language), systemImage: "bed.double")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let room = journey.selectedRoom {
                        Label(room.name, systemImage: "bed.double")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(journey.trip.originCode) → \(journey.trip.outboundDestinationCode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PackagePriceView(amount: quote.totalPackagePrice, currency: quote.currency, showsPerPerson: false)
                }
                .padding(16)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private var nextStepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("next_title", settings.language))
                .font(.headline)
            stepRow("01", L10n.text("next_one", settings.language))
            stepRow("02", L10n.text("next_two", settings.language))
            stepRow("03", L10n.text("next_three", settings.language))
            stepRow("04", L10n.text("next_four", settings.language))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func stepRow(_ number: String, _ body: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 30)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Circle())
            Text(body)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        VStack(spacing: 14) {
            if let createdSession {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("success_title", settings.language))
                        .font(.headline)
                    Text(L10n.text("success_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text("Бронь \(createdSession.displayBookingNumber)")
                        if let pilgrimID = createdSession.displayPilgrimID {
                            Text("· iumrah ID \(pilgrimID)")
                        }
                    }
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .iumrahCard()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            Button {
                // Always confirm the pilgrim's first and last name immediately before
                // creating a trip. Saved values remain prefilled in the sheet.
                showProfileSheet = true
            } label: {
                if isSubmitting {
                    ProgressView().tint(Color.iumrahPrimaryButtonText)
                } else {
                    Text(L10n.text("checkout_cta", settings.language))
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(isSubmitting)

            if createdSession != nil {
                NavigationLink {
                    BookingDetailView(bookingID: createdSession?.id ?? "")
                } label: {
                    Text(L10n.text("open_booking", settings.language))
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            }
        }
    }

    @MainActor
    private func submitBooking() async {
        guard !isSubmitting,
              let hotel = journey.selectedHotel,
              let outbound = journey.selectedOutbound,
              let quote = journey.quote else { return }
        let inbound = journey.selectedInbound
        guard !journey.trip.isRoundTripFlight || inbound != nil else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let profile = BookingPilgrimProfile(
                firstName: settings.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: settings.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                telegram: settings.telegram.trimmingCharacters(in: .whitespacesAndNewlines),
                whatsapp: settings.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let session = try await bookings.create(
                trip: journey.trip,
                hotel: hotel,
                madinahHotel: journey.selectedMadinahHotel,
                room: journey.selectedRoom,
                roomCategory: journey.selectedRoomCategory,
                madinahRoom: journey.selectedMadinahRoom,
                madinahRoomCategory: journey.selectedMadinahRoomCategory,
                outbound: outbound,
                inbound: inbound,
                quote: quote,
                language: settings.language,
                pilgrimProfile: profile
            )
            createdSession = session
            IumrahHaptics.success()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }
}

struct BookingProfileCaptureSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.text("profile_required_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section(L10n.text("profile_section", settings.language)) {
                    TextField(L10n.text("field_first_name", settings.language), text: $settings.firstName)
                    TextField(L10n.text("field_last_name", settings.language), text: $settings.lastName)
                    TextField(L10n.text("field_telegram", settings.language), text: $settings.telegram)
                        .autocapitalization(.none)
                    TextField(L10n.text("field_whatsapp", settings.language), text: $settings.whatsapp)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle(L10n.text("profile_required_title", settings.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("save_continue", settings.language)) {
                        dismiss()
                        onContinue()
                    }
                    .disabled(!settings.hasBookingIdentity)
                }
            }
        }
    }
}
