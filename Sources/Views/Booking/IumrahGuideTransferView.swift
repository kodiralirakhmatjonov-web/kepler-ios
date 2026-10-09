import PhotosUI
import SwiftUI
import UIKit

struct IumrahGuideTransferView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.openURL) private var openURL

    let bookingID: String

    @State private var guideProfile: IumrahPublicProfile?
    @State private var ownerProfile: IumrahPublicProfile?
    @State private var selectedFacePhoto: PhotosPickerItem?
    @State private var facePreview: UIImage?
    @State private var faceData: Data?
    @State private var isSendingFacePhoto = false
    @State private var facePhotoSent = false
    @State private var errorMessage: String?

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }
    private var guide: BookingGuideSnapshot? { session?.guide }
    private var vehicle: TransferVehicleKind { session?.transferVehicle ?? .carnival }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                guideCard
                ownerCard
                guideResponsibilitiesCard
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
        .task { await loadTeamProfiles() }
        .onChange(of: selectedFacePhoto) { _, item in
            guard let item else { return }
            Task { await prepareFacePhoto(item) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(tr("Your team in Saudi Arabia", "Ваша команда в Саудии", "Saudiya jamoangiz", "Саудия жамоангиз"))
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(-0.6)
            Text(tr(
                "Your lead guide, iumrah founder and confirmed transfer details are kept together for the airport meeting.",
                "Главный гид, основатель iumrah и подтверждённые данные трансфера собраны в одном месте для встречи в аэропорту.",
                "Bosh gid, iumrah asoschisi va tasdiqlangan transfer ma’lumotlari aeroportdagi uchrashuv uchun bir joyda.",
                "Бош гид, iumrah асосчиси ва тасдиқланган трансфер маълумотлари аэропортдаги учрашув учун бир жойда."
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
                VStack(alignment: .leading, spacing: 5) {
                    verifiedName(guideDisplayName)
                    Text(tr(
                        "Lead iumrah guide · 4 years experience",
                        "Главный гид iumrah · стаж 4 года",
                        "iumrah bosh gidi · 4 yil tajriba",
                        "iumrah бош гиди · 4 йил тажриба"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if let handle = instagramHandle(guideProfile?.instagram) {
                        Text(handle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .systemBlue))
                    }
                }
                Spacer(minLength: 0)
            }

            Text(tr(
                "Your main guide coordinates the airport meeting, Umrah assistance and key movements during the trip.",
                "Ваш главный гид координирует встречу в аэропорту, сопровождение Умры и ключевые переезды во время поездки.",
                "Bosh gidingiz aeroportdagi uchrashuv, Umra hamrohligi va safardagi asosiy ko‘chishlarni muvofiqlashtiradi.",
                "Бош гидингиз аэропортдаги учрашув, Умра ҳамроҳлиги ва сафардаги асосий кўчишларни мувофиқлаштиради."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if contactsUnlocked {
                contactButtons(phone: guidePhone, telegram: guideTelegram)
            } else {
                lockedContactsNote
            }
        }
        .iumrahCard()
    }

    private var ownerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ownerAvatar
                VStack(alignment: .leading, spacing: 5) {
                    verifiedName(ownerDisplayName)
                    Text("Founder · iumrah")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let handle = instagramHandle(ownerProfile?.instagram) {
                        Text(handle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .systemBlue))
                    }
                }
                Spacer(minLength: 0)
            }

            Text(tr(
                "Direct contact with the iumrah founder for your booking and trip support.",
                "Прямой контакт с основателем iumrah по Вашему бронированию и сопровождению поездки.",
                "Bron va safar yordami bo‘yicha iumrah asoschisi bilan bevosita aloqa.",
                "Брон ва сафар ёрдами бўйича iumrah асосчиси билан бевосита алоқа."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            ownerContactButtons
        }
        .iumrahCard()
    }

    private var guideResponsibilitiesCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "checklist", role: .profile, size: 48, symbolSize: 19, cornerRadius: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Your support from arrival to departure", "Сопровождение от прилёта до вылета", "Kelishdan qaytishgacha hamrohlik", "Келишдан қайтишгача ҳамроҳлик"))
                        .font(.headline)
                    Text(tr("Everything below is already part of your trip support.", "Всё ниже уже входит в сопровождение Вашей поездки.", "Quyidagilarning barchasi safar hamrohligiga kiradi.", "Қуйидагиларнинг барчаси сафар ҳамроҳлигига киради."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            guideDuty("airplane.arrival", tr("Airport meeting", "Встреча в аэропорту", "Aeroportda kutib olish", "Аэропортда кутиб олиш"), tr("The guide coordinates your arrival and helps the group meet the driver without unnecessary waiting.", "Гид координирует прилёт и помогает группе встретиться с водителем без лишнего ожидания.", "Gid kelishni muvofiqlashtiradi va guruhning haydovchi bilan ortiqcha kutmasdan uchrashishiga yordam beradi.", "Гид келишни мувофиқлаштиради ва гуруҳнинг ҳайдовчи билан ортиқча кутмасдан учрашишига ёрдам беради."))
            guideDuty("building.2.fill", tr("Hotel check-in support", "Сопровождение до отеля", "Mehmonxonagacha hamrohlik", "Меҳмонхонагача ҳамроҳлик"), tr("You are accompanied to the confirmed hotel and helped with the first practical steps after arrival.", "Вас сопровождают до подтверждённого отеля и помогают с первыми организационными вопросами после прилёта.", "Tasdiqlangan mehmonxonagacha hamrohlik qilinadi va kelgandan keyingi dastlabki tashkiliy masalalarda yordam beriladi.", "Тасдиқланган меҳмонхонагача ҳамроҳлик қилинади ва келгандан кейинги дастлабки ташкилий масалаларда ёрдам берилади."))
            guideDuty("figure.walk", tr("Umrah guidance", "Сопровождение Умры", "Umra hamrohligi", "Умра ҳамроҳлиги"), tr("The guide keeps the group oriented through the main Umrah stages and coordinates movement when needed.", "Гид помогает группе ориентироваться по основным этапам Умры и координирует перемещения, когда это необходимо.", "Gid Umraning asosiy bosqichlarida guruhga yo‘l-yo‘riq ko‘rsatadi va zarur paytda harakatni muvofiqlashtiradi.", "Гид Умранинг асосий босқичларида гуруҳга йўл-йўриқ кўрсатади ва зарур пайтда ҳаракатни мувофиқлаштиради."))
            guideDuty("map.fill", tr("Ziyarats", "Зияраты", "Ziyoratlar", "Зиёратлар"), tr("Your included Makkah and Madinah visits are coordinated with the guide and transfer route.", "Включённые посещения в Мекке и Медине координируются вместе с гидом и маршрутом трансфера.", "Makka va Madinadagi kiritilgan ziyoratlar gid va transfer yo‘nalishi bilan muvofiqlashtiriladi.", "Макка ва Мадинадаги киритилган зиёратлар гид ва трансфер йўналиши билан мувофиқлаштирилади."))
            guideDuty("tram.fill", tr("Intercity coordination", "Переезд между городами", "Shaharlararo yo‘l", "Шаҳарлараро йўл"), tr("The team coordinates the Makkah–Madinah movement, including the train segment when it is part of your itinerary.", "Команда координирует переезд Мекка–Медина, включая поезд, если он входит в Ваш маршрут.", "Jamoa Makka–Madina harakatini, yo‘nalishga kirsa poyezd qismini ham muvofiqlashtiradi.", "Жамоа Макка–Мадина ҳаракатини, йўналишга кирса поезд қисмини ҳам мувофиқлаштиради."))
            guideDuty("airplane.departure", tr("Departure support", "Сопровождение до аэропорта", "Aeroportgacha hamrohlik", "Аэропортгача ҳамроҳлик"), tr("At the end of the trip, the transfer and team coordinate your return to the departure airport.", "В конце поездки трансфер и команда координируют Ваш выезд в аэропорт обратного рейса.", "Safar oxirida transfer va jamoa qaytish reysi aeroportiga borishingizni muvofiqlashtiradi.", "Сафар охирида трансфер ва жамоа қайтиш рейси аэропортига боришингизни мувофиқлаштиради."))
        }
        .iumrahCard()
    }

    private func guideDuty(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBlue))
                .frame(width: 36, height: 36)
                .background(Color(uiColor: .systemBlue).opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var contactsUnlocked: Bool {
        guard let status = session?.effectiveStatus.uppercased() else { return false }
        return ["PAID", "BOOKING_CONFIRMED", "DOCUMENTS_READY", "READY_TO_TRAVEL", "IN_TRIP", "COMPLETED"].contains(status)
    }

    private var lockedContactsNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
            Text(tr(
                "Phone and Telegram unlock after payment is confirmed.",
                "Телефон и Telegram откроются после подтверждения оплаты.",
                "Telefon va Telegram to‘lov tasdiqlangandan keyin ochiladi.",
                "Телефон ва Telegram тўлов тасдиқлангандан кейин очилади."
            ))
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(13)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var transferCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                Image(vehicle.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 178)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(vehicle.modelName)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                        Text(tr("Your selected transfer vehicle", "Выбранный автомобиль трансфера", "Tanlangan transfer avtomobili", "Танланган трансфер автомобили"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("\(vehicle.passengerCapacity)", systemImage: "person.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
            }

            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "car.fill", role: .transfer, size: 48, symbolSize: 19, cornerRadius: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Airport transfer", "Трансфер по маршруту", "Yo‘nalish transferi", "Йўналиш трансфери"))
                        .font(.headline)
                    Text(tr(
                        "Pickup follows your confirmed flight and hotels.",
                        "Встреча привязана к подтверждённому рейсу и отелям.",
                        "Kutib olish tasdiqlangan reys va mehmonxonalarga bog‘langan.",
                        "Кутиб олиш тасдиқланган рейс ва меҳмонхоналарга боғланган."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if let session {
                routeRow(icon: "airplane.arrival", text: tr(
                    "Arrival airport: \(session.booking.input.arrivalAirportCode)",
                    "Аэропорт прилёта: \(session.booking.input.arrivalAirportCode)",
                    "Kelish aeroporti: \(session.booking.input.arrivalAirportCode)",
                    "Келиш аэропорти: \(session.booking.input.arrivalAirportCode)"
                ))

                routeRow(icon: "clock.fill", text: airportWaitText)

                if let window = airportWaitWindow {
                    routeRow(icon: "timer", text: window)
                }

                if !session.booking.hotelNames.makkah.isEmpty {
                    routeRow(icon: "building.2.fill", text: session.booking.hotelNames.makkah)
                }
                if !session.booking.hotelNames.madinah.isEmpty {
                    routeRow(icon: "moon.stars.fill", text: session.booking.hotelNames.madinah)
                }
                routeRow(icon: "airplane.departure", text: tr(
                    "Return from: \(session.booking.route.returnOrigin)",
                    "Обратный вылет: \(session.booking.route.returnOrigin)",
                    "Qaytish: \(session.booking.route.returnOrigin)",
                    "Қайтиш: \(session.booking.route.returnOrigin)"
                ))
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

    @ViewBuilder
    private var guideAvatar: some View {
        profileAvatar(url: guidePhotoURL, fallback: "person.crop.circle.fill")
    }

    @ViewBuilder
    private var ownerAvatar: some View {
        profileAvatar(url: founderPhotoURL, fallback: "person.crop.circle.fill")
    }

    @ViewBuilder
    private func profileAvatar(url: URL?, fallback: String) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default:
                    Image(systemName: fallback)
                        .resizable().scaledToFit().padding(16).foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .background(Color.iumrahRaisedBackground)
            .clipShape(Circle())
        } else {
            Image(systemName: fallback)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 72, height: 72)
                .background(Color.iumrahRaisedBackground, in: Circle())
        }
    }

    private func verifiedName(_ value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBlue))
                .accessibilityLabel(tr("Verified", "Подтверждено", "Tasdiqlangan", "Тасдиқланган"))
        }
    }

    private var ownerContactButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                contactButton(
                    title: tr("Call", "Позвонить", "Qo‘ng‘iroq", "Қўнғироқ"),
                    systemName: "phone.fill",
                    tint: Color(uiColor: .systemGreen),
                    enabled: !ownerPhone.isEmpty
                ) { openPhone(ownerPhone) }

                contactButton(
                    title: "Telegram",
                    systemName: "paperplane.fill",
                    tint: Color(uiColor: .systemBlue),
                    enabled: !ownerTelegram.isEmpty
                ) { openTelegram(ownerTelegram) }
            }

            NavigationLink {
                BookingChatView(bookingID: bookingID)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text(tr("Care chat", "Чат iumrah Care", "iumrah Care chat", "iumrah Care чат"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.7)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func contactButtons(phone: String, telegram: String) -> some View {
        HStack(spacing: 10) {
            contactButton(
                title: tr("Call", "Позвонить", "Qo‘ng‘iroq", "Қўнғироқ"),
                systemName: "phone.fill",
                tint: Color(uiColor: .systemGreen),
                enabled: !phone.isEmpty
            ) { openPhone(phone) }

            contactButton(
                title: "Telegram",
                systemName: "paperplane.fill",
                tint: Color(uiColor: .systemBlue),
                enabled: !telegram.isEmpty
            ) { openTelegram(telegram) }
        }
    }

    private func contactButton(title: String, systemName: String, tint: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(enabled ? tint : Color.secondary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background((enabled ? tint.opacity(0.11) : Color.iumrahRaisedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder((enabled ? tint : Color.secondary).opacity(0.12), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func routeRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    @MainActor
    private func loadTeamProfiles() async {
        do {
            let profiles = try await ChatService().loadTeamProfiles()
            ownerProfile = profiles.first(where: { $0.isOwner })
            if let id = guide?.id, !id.isEmpty {
                guideProfile = profiles.first(where: { $0.id == id })
            }
        } catch {
            // Booking assignment remains usable even if public team data is temporarily unavailable.
        }
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

    private var guideDisplayName: String {
        let value = guide?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? tr("Your guide", "Ваш гид", "Sizning gidingiz", "Сизнинг гидингиз") : value
    }

    private var ownerDisplayName: String {
        let value = ownerProfile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Abdulaziz" : value
    }

    private var guidePhotoURL: URL? { AppConfig.absoluteURL(guideProfile?.photoURL) }
    private var founderPhotoURL: URL? { AppConfig.absoluteURL(ownerProfile?.photoURL) }

    private var guidePhone: String {
        if let guideProfile {
            return preferredPhone(phoneSA: guideProfile.phoneSA, phoneUZ: guideProfile.phoneUZ)
        }
        guard let guide else { return "" }
        return preferredPhone(phoneSA: guide.phoneSA, phoneUZ: guide.phoneUZ)
    }

    private var guideTelegram: String {
        cleanHandle(guideProfile?.telegram ?? guide?.telegram ?? "")
    }

    private var ownerPhone: String {
        if let ownerProfile {
            let preferred = preferredPhone(phoneSA: ownerProfile.phoneSA, phoneUZ: ownerProfile.phoneUZ)
            if !preferred.isEmpty { return preferred }
        }
        return "+998 50 889 88 45"
    }

    private var ownerTelegram: String {
        let value = cleanHandle(ownerProfile?.telegram ?? "")
        return value.isEmpty ? "saudiclub966" : value
    }

    private var airportWaitText: String {
        tr(
            "Meeting: after the actual landing and baggage collection. The team follows your confirmed flight.",
            "Встреча: после фактического прилёта и получения багажа. Команда отслеживает Ваш подтверждённый рейс.",
            "Uchrashuv: haqiqiy qo‘nish va bagajni olgandan keyin. Jamoa tasdiqlangan reysingizni kuzatadi.",
            "Учрашув: ҳақиқий қўниш ва багажни олгандан кейин. Жамоа тасдиқланган рейсингизни кузатади."
        )
    }

    private var airportWaitWindow: String? {
        guard let raw = session?.booking.generatorTrace?.outbound.arrivalAt,
              let arrival = parseISO(raw) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.timeZone = TimeZone(identifier: "Asia/Riyadh")
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: arrival)
        return tr(
            "Scheduled arrival: \(time) Saudi time",
            "Плановое время прилёта: \(time) по времени Саудии",
            "Rejadagi kelish vaqti: \(time), Saudiya vaqti",
            "Режадаги келиш вақти: \(time), Саудия вақти"
        )
    }

    private func parseISO(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }

    private func preferredPhone(phoneSA: String, phoneUZ: String) -> String {
        [phoneSA, phoneUZ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private func instagramHandle(_ value: String?) -> String? {
        guard let value else { return nil }
        let handle = cleanHandle(value)
        return handle.isEmpty ? nil : "@\(handle)"
    }

    private func cleanHandle(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://t.me/", "http://t.me/", "t.me/"] {
            if result.lowercased().hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                break
            }
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: " @/"))
    }

    private func openPhone(_ value: String) {
        let digits = value.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }

    private func openTelegram(_ value: String) {
        let handle = cleanHandle(value)
        guard !handle.isEmpty, let url = URL(string: "https://t.me/\(handle)") else { return }
        openURL(url)
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
