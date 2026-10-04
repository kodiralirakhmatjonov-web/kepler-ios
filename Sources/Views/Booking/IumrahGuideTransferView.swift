import PhotosUI
import SwiftUI
import UIKit

struct IumrahGuideTransferView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.openURL) private var openURL

    let bookingID: String

    @State private var guideProfile: IumrahPublicProfile?
    @State private var selectedFacePhoto: PhotosPickerItem?
    @State private var facePreview: UIImage?
    @State private var faceData: Data?
    @State private var isSendingFacePhoto = false
    @State private var facePhotoSent = false
    @State private var errorMessage: String?

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }
    private var guide: BookingGuideSnapshot? { session?.guide }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                guideCard
                transferCard
                meetingPhotoCard

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .navigationTitle(tr("Guide & transfer", "Гид и трансфер", "Gid va transfer", "Гид ва трансфер"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await loadGuideProfile() }
        .onChange(of: selectedFacePhoto) { _, item in
            guard let item else { return }
            Task { await prepareFacePhoto(item) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(tr("Meet your team", "Ваша команда в Саудии", "Saudiya jamoangiz", "Саудия жамоангиз"))
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(-0.6)
            Text(tr(
                "Guide contacts and transfer details stay together so you know who will meet you and how the airport pickup works.",
                "Контакты гида и данные трансфера собраны в одном месте, чтобы Вы заранее знали, кто Вас встретит и как пройдёт встреча в аэропорту.",
                "Gid kontaktlari va transfer ma’lumotlari bir joyda — aeroportda kim kutib olishini oldindan bilasiz.",
                "Гид контактлари ва трансфер маълумотлари бир жойда — аэропортда ким кутиб олишини олдиндан биласиз."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                guideAvatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(guide?.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? (guide?.displayName ?? "") : "iumrah Guide")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(guide?.roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                         ? (guide?.roleTitle ?? "")
                         : tr("Your guide for this trip", "Ваш гид в этой поездке", "Safaringizdagi gid", "Сафарингиздаги гид"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if let guide {
                contactRow(icon: "phone.fill", title: tr("Phone", "Телефон", "Telefon", "Телефон"), value: preferredPhone(guide)) {
                    openPhone(preferredPhone(guide))
                }
                contactRow(icon: "paperplane.fill", title: "Telegram", value: cleanHandle(guide.telegram)) {
                    openTelegram(guide.telegram)
                }
                if !guide.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    contactRow(icon: "message.fill", title: "WhatsApp", value: guide.whatsapp) {
                        openWhatsApp(guide.whatsapp)
                    }
                }
            } else {
                Label(
                    tr("Guide details will appear here when the guide is assigned.", "Данные гида появятся здесь сразу после назначения.", "Gid tayinlangach, uning ma’lumotlari shu yerda chiqadi.", "Гид тайинлангач, унинг маълумотлари шу ерда чиқади."),
                    systemImage: "clock.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .iumrahCard()
    }

    @ViewBuilder
    private var guideAvatar: some View {
        if let url = guidePhotoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().scaledToFit().padding(16).foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .background(Color.iumrahRaisedBackground)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 72, height: 72)
                .background(Color.iumrahRaisedBackground, in: Circle())
        }
    }

    private var transferCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "car.fill", role: .transfer, size: 48, symbolSize: 19, cornerRadius: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Airport transfer", "Трансфер по маршруту", "Yo‘nalish transferi", "Йўналиш трансфери"))
                        .font(.headline)
                    Text(tr("Pickup follows your confirmed flight and hotels.", "Встреча привязана к подтверждённому рейсу и отелям.", "Kutib olish tasdiqlangan reys va mehmonxonalarga bog‘langan.", "Кутиб олиш тасдиқланган рейс ва меҳмонхоналарга боғланган."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let session {
                routeRow(icon: "airplane.arrival", text: tr("Arrival airport: \(session.booking.input.arrivalAirportCode)", "Аэропорт прилёта: \(session.booking.input.arrivalAirportCode)", "Kelish aeroporti: \(session.booking.input.arrivalAirportCode)", "Келиш аэропорти: \(session.booking.input.arrivalAirportCode)"))
                if !session.booking.hotelNames.makkah.isEmpty {
                    routeRow(icon: "building.2.fill", text: session.booking.hotelNames.makkah)
                }
                if !session.booking.hotelNames.madinah.isEmpty {
                    routeRow(icon: "moon.stars.fill", text: session.booking.hotelNames.madinah)
                }
                routeRow(icon: "airplane.departure", text: tr("Return from: \(session.booking.route.returnOrigin)", "Обратный вылет: \(session.booking.route.returnOrigin)", "Qaytish: \(session.booking.route.returnOrigin)", "Қайтиш: \(session.booking.route.returnOrigin)"))
            }
        }
        .iumrahCard()
    }

    private var meetingPhotoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                IumrahIconBadge(systemName: "person.crop.square.filled.and.at.rectangle", role: .profile, size: 48, symbolSize: 18, cornerRadius: 16)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Help us recognize you", "Помогите гиду быстрее Вас найти", "Sizni tezroq topishga yordam bering", "Сизни тезроқ топишга ёрдам беринг"))
                        .font(.headline)
                    Text(tr(
                        "Optional: attach a recent face photo. It will be sent to the iumrah Care conversation for the airport meeting team.",
                        "Не обязательно: прикрепите актуальную фотографию лица. Она будет отправлена в чат iumrah Care для команды встречи в аэропорту.",
                        "Ixtiyoriy: yuzingiz ko‘rinadigan yangi rasmni biriktiring. U aeroportda kutib olish jamoasi uchun iumrah Care chatiga yuboriladi.",
                        "Ихтиёрий: юзингиз кўринадиган янги расмни бириктиринг. У аэропортда кутиб олиш жамоаси учун iumrah Care чатига юборилади."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let facePreview {
                Image(uiImage: facePreview)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if facePhotoSent {
                Label(tr("Photo sent to the meeting team", "Фото отправлено команде встречи", "Rasm kutib olish jamoasiga yuborildi", "Расм кутиб олиш жамоасига юборилди"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }

            PhotosPicker(selection: $selectedFacePhoto, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text(facePreview == nil
                         ? tr("Choose face photo", "Выбрать фотографию", "Yuz rasmini tanlash", "Юз расмини танлаш")
                         : tr("Choose another photo", "Выбрать другое фото", "Boshqa rasm tanlash", "Бошқа расм танлаш"))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 15)
                .frame(height: 52)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)

            if faceData != nil && !facePhotoSent {
                Button {
                    Task { await sendFacePhoto() }
                } label: {
                    HStack(spacing: 10) {
                        if isSendingFacePhoto { ProgressView().tint(.white) }
                        Image(systemName: "paperplane.fill")
                        Text(tr("Send to meeting team", "Отправить команде встречи", "Kutib olish jamoasiga yuborish", "Кутиб олиш жамоасига юбориш"))
                        Spacer()
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isSendingFacePhoto)
            }
        }
        .iumrahCard()
    }

    private func contactRow(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.iumrahRaisedBackground, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value.isEmpty ? "—" : value).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .disabled(value.isEmpty)
    }

    private func routeRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary).frame(width: 24)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    @MainActor
    private func loadGuideProfile() async {
        guard let id = guide?.id, !id.isEmpty else { return }
        guideProfile = try? await ChatService().loadTeamProfile(id: id)
    }

    @MainActor
    private func prepareFacePhoto(_ item: PhotosPickerItem) async {
        errorMessage = nil
        facePhotoSent = false
        do {
            guard let raw = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: raw),
                  let jpeg = image.jpegData(compressionQuality: 0.88) else {
                throw APIError.invalidResponse
            }
            facePreview = image
            faceData = jpeg
        } catch {
            facePreview = nil
            faceData = nil
            errorMessage = tr("Could not prepare this photo.", "Не удалось подготовить фотографию.", "Rasmni tayyorlab bo‘lmadi.", "Расмни тайёрлаб бўлмади.")
        }
    }

    @MainActor
    private func sendFacePhoto() async {
        guard let data = faceData else { return }
        isSendingFacePhoto = true
        errorMessage = nil
        defer { isSendingFacePhoto = false }

        do {
            _ = try await bookings.send(
                message: tr(
                    "Face photo for airport pickup recognition.",
                    "Фото для быстрой встречи и узнавания в аэропорту.",
                    "Aeroportda tezroq tanish uchun yuz rasmi.",
                    "Аэропортда тезроқ таниш учун юз расми."
                ),
                for: bookingID
            )
            _ = try await bookings.sendPhoto(data: data, for: bookingID)
            facePhotoSent = true
            IumrahHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            IumrahHaptics.error()
        }
    }

    private var guidePhotoURL: URL? {
        AppConfig.absoluteURL(guideProfile?.photoURL)
    }

    private func preferredPhone(_ guide: BookingGuideSnapshot) -> String {
        let values = [guide.phoneSA, guide.phoneUZ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return values.first(where: { !$0.isEmpty }) ?? ""
    }

    private func cleanHandle(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: " @"))
    }

    private func openPhone(_ value: String) {
        let digits = value.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }

    private func openTelegram(_ value: String) {
        let handle = cleanHandle(value)
        guard !handle.isEmpty, let url = URL(string: "https://t.me/\(handle)") else { return }
        openURL(url)
    }

    private func openWhatsApp(_ value: String) {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty, let url = URL(string: "https://wa.me/\(digits)") else { return }
        openURL(url)
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
