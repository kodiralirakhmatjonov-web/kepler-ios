import SwiftUI

struct IumrahCareRequestView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var account: IumrahAccountStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var originAirport: Airport?
    @State private var originCode = "TAS"
    @State private var timingMode: IumrahCareTimingMode = .flexibleMonth
    @State private var preferredMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var flexibleWindowDays = 7
    @State private var exactStartDate = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
    @State private var exactEndDate = Calendar.current.date(byAdding: .day, value: 28, to: Date()) ?? Date()

    @State private var adults = 2
    @State private var children = 0
    @State private var infants = 0
    @State private var rooms = 1
    @State private var scope: JourneyScope = .makkahAndMadinah
    @State private var firstSaudiCity: SaudiArrivalAirport = .jeddah
    @State private var priority: IumrahCareTripPriority = .balanced
    @State private var hotelClass = 4
    @State private var transferPreference: IumrahCareTransferPreference = .comfortable
    @State private var directFlightsPreferred = true
    @State private var checkedBaggagePreferred = true
    @State private var includeZiyarat = true
    @State private var includeESIM = true
    @State private var guidePreference: IumrahCareGuidePreference = .voice
    @State private var budgetText = ""
    @State private var notes = ""

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var telegram = ""
    @State private var isSubmitting = false
    @State private var response: IumrahCarePackageRequestResponse?
    @State private var errorMessage: String?
    @State private var carePhone = ""

    private let service = IumrahCareRequestService()
    private let chatService = ChatService()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                introCard
                timingCard
                travelersCard
                routeCard
                priorityCard
                comfortCard
                servicesCard
                contactCard
                notesCard
                submitArea
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.iumrahPageBackground)
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prefillContact()
            Task { await loadCarePhone() }
        }
        .onChange(of: exactStartDate) { _, newValue in
            if exactEndDate <= newValue {
                exactEndDate = Calendar.current.date(byAdding: .day, value: 7, to: newValue) ?? newValue
            }
        }
        .alert(errorTitle, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(okTitle, role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IumrahIconBadge(systemName: "heart.fill", role: .care, size: 46, symbolSize: 18, cornerRadius: 15)
                Spacer()
                Text("Iumrah Care")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground, in: Capsule())
            }

            Text(introTitle)
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)

            Text(introBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                callCare()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "phone.fill")
                    Text(callCareTitle)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(resolvedCarePhone.isEmpty)
            .opacity(resolvedCarePhone.isEmpty ? 0.55 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private var timingCard: some View {
        formCard(title: timingTitle, icon: "calendar") {
            Picker(timingTitle, selection: $timingMode) {
                Text(flexibleTitle).tag(IumrahCareTimingMode.flexibleMonth)
                Text(exactDatesTitle).tag(IumrahCareTimingMode.exactDates)
            }
            .pickerStyle(.segmented)

            if timingMode == .flexibleMonth {
                DatePicker(preferredMonthTitle, selection: $preferredMonth, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)

                VStack(alignment: .leading, spacing: 8) {
                    Text(flexibilityTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker(flexibilityTitle, selection: $flexibleWindowDays) {
                        Text("± 3").tag(3)
                        Text("± 7").tag(7)
                        Text("± 14").tag(14)
                    }
                    .pickerStyle(.segmented)
                }
            } else {
                DatePicker(startDateTitle, selection: $exactStartDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                DatePicker(endDateTitle, selection: $exactEndDate, in: exactStartDate..., displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
    }

    private var travelersCard: some View {
        formCard(title: travelersTitle, icon: "person.3.fill") {
            stepperRow(title: adultsTitle, value: $adults, range: 1...20)
            Divider()
            stepperRow(title: childrenTitle, value: $children, range: 0...20)
            Divider()
            stepperRow(title: infantsTitle, value: $infants, range: 0...10)
            Divider()
            stepperRow(title: roomsTitle, value: $rooms, range: 1...10)
        }
    }

    private var routeCard: some View {
        formCard(title: routeTitle, icon: "airplane.departure") {
            AirportSelectorButton(airport: $originAirport, fallbackCode: $originCode)

            VStack(alignment: .leading, spacing: 8) {
                Text(saudiRouteTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(saudiRouteTitle, selection: $scope) {
                    Text(scopeMakkahTitle).tag(JourneyScope.makkahOnly)
                    Text(scopeBothTitle).tag(JourneyScope.makkahAndMadinah)
                }
                .pickerStyle(.segmented)
            }

            if scope == .makkahAndMadinah {
                VStack(alignment: .leading, spacing: 8) {
                    Text(firstCityTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker(firstCityTitle, selection: $firstSaudiCity) {
                        Text(jeddahTitle).tag(SaudiArrivalAirport.jeddah)
                        Text(madinahTitle).tag(SaudiArrivalAirport.madinah)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var priorityCard: some View {
        formCard(title: priorityTitle, icon: "scope") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                priorityButton(.lowestPrice, icon: "tag.fill", title: lowestPriceTitle, subtitle: lowestPriceSubtitle)
                priorityButton(.nearHaram, icon: "location.fill", title: nearHaramTitle, subtitle: nearHaramSubtitle)
                priorityButton(.balanced, icon: "slider.horizontal.3", title: balancedTitle, subtitle: balancedSubtitle)
                priorityButton(.premium, icon: "sparkles", title: premiumTitle, subtitle: premiumSubtitle)
            }
        }
    }

    private var comfortCard: some View {
        formCard(title: comfortTitle, icon: "building.2.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text(hotelClassTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(hotelClassTitle, selection: $hotelClass) {
                    Text("3★").tag(3)
                    Text("4★").tag(4)
                    Text("5★").tag(5)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(transferTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(transferTitle, selection: $transferPreference) {
                    Text(comfortableTransferTitle).tag(IumrahCareTransferPreference.comfortable)
                    Text(privateSUVTitle).tag(IumrahCareTransferPreference.privateSUV)
                    Text(vipTransferTitle).tag(IumrahCareTransferPreference.vip)
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }

            Toggle(directFlightsTitle, isOn: $directFlightsPreferred)
            Toggle(checkedBaggageTitle, isOn: $checkedBaggagePreferred)

            TextField(budgetTitle, text: $budgetText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var servicesCard: some View {
        formCard(title: servicesTitle, icon: "shippingbox.fill") {
            Toggle(ziyaratTitle, isOn: $includeZiyarat)
            Toggle(esimTitle, isOn: $includeESIM)

            VStack(alignment: .leading, spacing: 8) {
                Text(guideTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(guideTitle, selection: $guidePreference) {
                    Text(noGuideTitle).tag(IumrahCareGuidePreference.none)
                    Text(voiceGuideTitle).tag(IumrahCareGuidePreference.voice)
                    Text(liveGuideTitle).tag(IumrahCareGuidePreference.live)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var contactCard: some View {
        formCard(title: contactTitle, icon: "person.crop.circle.fill") {
            TextField(firstNameTitle, text: $firstName)
                .textContentType(.givenName)
                .textFieldStyle(.roundedBorder)
            TextField(lastNameTitle, text: $lastName)
                .textContentType(.familyName)
                .textFieldStyle(.roundedBorder)
            TextField(phoneTitle, text: $phone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
            TextField(telegramTitle, text: $telegram)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
        }
    }

    private var notesCard: some View {
        formCard(title: wishesTitle, icon: "text.bubble.fill") {
            TextEditor(text: $notes)
                .frame(minHeight: 112)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text(wishesPlaceholder)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    @ViewBuilder
    private var submitArea: some View {
        if let response {
            successCard(response)
        } else {
            Button {
                Task { await submit() }
            } label: {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(submitTitle)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 19)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || !isValid)
            .opacity(isValid ? 1 : 0.48)

            Text("Iumrah Care")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func successCard(_ response: IumrahCarePackageRequestResponse) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                IumrahIconBadge(systemName: "checkmark", role: .success, size: 44, symbolSize: 17, shape: .circle)
                Spacer()
                Text(newRequestTitle)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground, in: Capsule())
            }

            Text(successTitle)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.5)
            Text(successBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(requestNumberTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(response.requestID)
                        .font(.subheadline.monospaced().weight(.semibold))
                }
                Spacer()
                responseTimer(response.responseDueAt)
            }

            Button(doneTitle) { dismiss() }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    @ViewBuilder
    private func responseTimer(_ rawDate: String) -> some View {
        if let due = ISO8601DateFormatter().date(from: rawDate) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(due.timeIntervalSince(context.date)))
                let hours = remaining / 3600
                let minutes = (remaining % 3600) / 60
                let seconds = remaining % 60
                VStack(alignment: .trailing, spacing: 3) {
                    Text(responseTimeTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                        .font(.system(.headline, design: .monospaced).weight(.bold))
                }
            }
        }
    }

    private func formCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                IumrahIconBadge(systemName: icon, size: 38, symbolSize: 15, cornerRadius: 13)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .font(.body.weight(.medium))
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 24, alignment: .trailing)
            }
            .labelsHidden()
            Text("\(value.wrappedValue)")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 26, alignment: .trailing)
        }
    }

    private func priorityButton(_ item: IumrahCareTripPriority, icon: String, title: String, subtitle: String) -> some View {
        Button {
            priority = item
            IumrahHaptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(priority == item ? Color.white.opacity(0.76) : Color.secondary)
                    .lineLimit(2)
            }
            .foregroundStyle(priority == item ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .padding(14)
            .background(priority == item ? Color.black : Color.iumrahRaisedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        originCode.trimmingCharacters(in: .whitespacesAndNewlines).count == 3 &&
        (timingMode == .flexibleMonth || exactEndDate > exactStartDate)
    }

    @MainActor
    private func submit() async {
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let request = IumrahCarePackageRequest(
            locale: settings.language.rawValue,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            telegram: telegram.trimmingCharacters(in: .whitespacesAndNewlines),
            accountID: account.iumrahID,
            originCode: originCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            timingMode: timingMode,
            preferredMonth: timingMode == .flexibleMonth ? Self.monthFormatter.string(from: preferredMonth) : nil,
            flexibleWindowDays: timingMode == .flexibleMonth ? flexibleWindowDays : nil,
            exactStartDate: timingMode == .exactDates ? Self.dayFormatter.string(from: exactStartDate) : nil,
            exactEndDate: timingMode == .exactDates ? Self.dayFormatter.string(from: exactEndDate) : nil,
            adults: adults,
            children: children,
            infants: infants,
            rooms: rooms,
            scope: scope.rawValue,
            firstSaudiCity: scope == .makkahAndMadinah ? firstSaudiCity.rawValue : nil,
            priority: priority,
            hotelClass: hotelClass,
            transferPreference: transferPreference,
            directFlightsPreferred: directFlightsPreferred,
            checkedBaggagePreferred: checkedBaggagePreferred,
            includeZiyarat: includeZiyarat,
            includeESIM: includeESIM,
            guidePreference: guidePreference,
            budgetUSD: Int(budgetText.filter { $0.isNumber }),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let result = try await service.submit(request, accountToken: account.bearerToken)
            response = result
            IumrahHaptics.success()
        } catch {
            errorMessage = localizedSubmissionError(error)
            IumrahHaptics.error()
        }
    }

    private func prefillContact() {
        guard firstName.isEmpty, phone.isEmpty else { return }
        if let profile = account.account {
            firstName = profile.firstName
            lastName = profile.lastName
            phone = profile.phone.isEmpty ? settings.whatsapp : profile.phone
            telegram = profile.telegram.isEmpty ? settings.telegram : profile.telegram
        } else {
            firstName = settings.firstName
            lastName = settings.lastName
            phone = settings.whatsapp
            telegram = settings.telegram
        }
    }

    private func localizedSubmissionError(_ error: Error) -> String {
        let detail = (error as NSError).localizedDescription
        switch settings.language {
        case .russian: return "Не удалось отправить запрос в Iumrah Care. Проверьте интернет и попробуйте ещё раз.\n\n\(detail)"
        case .turkish: return TurkishLocalization.phrase("We couldn’t send the request to Iumrah Care. Check your connection and try again.\n\n\(detail)")
        case .indonesian, .malay, .english: return "We couldn’t send the request to Iumrah Care. Check your connection and try again.\n\n\(detail)"
        case .uzbek: return "So‘rovni Iumrah Care’ga yuborib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.\n\n\(detail)"
        case .uzbekCyrillic: return "Сўровни Iumrah Care’га юбориб бўлмади. Интернетни текшириб, қайта уриниб кўринг.\n\n\(detail)"
        }
    }

    @MainActor
    private func loadCarePhone() async {
        if let profile = try? await chatService.loadCareProfile() {
            let preferred = profile.phoneUZ.trimmingCharacters(in: .whitespacesAndNewlines)
            if !preferred.isEmpty { carePhone = preferred }
        }
    }

    private var resolvedCarePhone: String {
        let candidate = carePhone.isEmpty ? settings.whatsapp : carePhone
        return candidate.filter { $0.isNumber || $0 == "+" }
    }

    private func callCare() {
        let value = resolvedCarePhone
        guard !value.isEmpty, let url = URL(string: "tel:\(value)") else { return }
        IumrahHaptics.selection()
        openURL(url)
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var pageTitle: String { tr("Собрать Умру за меня", "Build my Umrah", "Umramni men uchun tuzing", "Умрамни мен учун тузинг") }
    private var introTitle: String { tr("Расскажите, какой должна быть Ваша Умра — или позвоните", "Tell us what your Umrah should be like — or call us", "Umrangiz qanday bo‘lishini ayting — yoki qo‘ng‘iroq qiling", "Умрангиз қандай бўлишини айтинг — ёки қўнғироқ қилинг") }
    private var callCareTitle: String { tr("Позвонить", "Call Iumrah Care", "Qo‘ng‘iroq qilish", "Қўнғироқ қилиш") }
    private var introBody: String { tr("Вы задаёте даты, бюджет и приоритеты. Iumrah Care получает запрос как новую заявку и подбирает персональный вариант.", "Set your dates, budget and priorities. Iumrah Care receives a new request and prepares a personal option for you.", "Sana, budjet va ustuvorliklarni belgilang. Iumrah Care yangi so‘rovni qabul qilib, shaxsiy variant tayyorlaydi.", "Сана, бюджет ва устуворликларни белгиланг. Iumrah Care янги сўровни қабул қилиб, шахсий вариант тайёрлайди.") }
    private var timingTitle: String { tr("Когда Вы планируете Умру", "When do you plan to travel?", "Umrani qachon rejalashtirgansiz", "Умрани қачон режалаштиргансиз") }
    private var flexibleTitle: String { tr("Гибко", "Flexible", "Moslashuvchan", "Мослашувчан") }
    private var exactDatesTitle: String { tr("Точные даты", "Exact dates", "Aniq sanalar", "Аниқ саналар") }
    private var preferredMonthTitle: String { tr("Предпочтительный месяц", "Preferred month", "Afzal oy", "Афзал ой") }
    private var flexibilityTitle: String { tr("Допустимое отклонение, дней", "Date flexibility, days", "Sana moslashuvi, kun", "Сана мослашуви, кун") }
    private var startDateTitle: String { tr("Вылет", "Departure", "Uchish", "Учиш") }
    private var endDateTitle: String { tr("Возвращение", "Return", "Qaytish", "Қайтиш") }
    private var travelersTitle: String { tr("Кто едет", "Travelers", "Kimlar boradi", "Кимлар боради") }
    private var adultsTitle: String { tr("Взрослые", "Adults", "Kattalar", "Катталар") }
    private var childrenTitle: String { tr("Дети", "Children", "Bolalar", "Болалар") }
    private var infantsTitle: String { tr("Младенцы", "Infants", "Chaqaloqlar", "Чақалоқлар") }
    private var roomsTitle: String { tr("Номера", "Rooms", "Xonalar", "Хоналар") }
    private var routeTitle: String { tr("Маршрут", "Route", "Yo‘nalish", "Йўналиш") }
    private var saudiRouteTitle: String { tr("Города в Саудовской Аравии", "Cities in Saudi Arabia", "Saudiya Arabistonidagi shaharlar", "Саудия Арабистонидаги шаҳарлар") }
    private var scopeMakkahTitle: String { tr("Только Мекка", "Makkah only", "Faqat Makka", "Фақат Макка") }
    private var scopeBothTitle: String { tr("Мекка + Медина", "Makkah + Madinah", "Makka + Madina", "Макка + Мадина") }
    private var firstCityTitle: String { tr("Первый город", "First city", "Birinchi shahar", "Биринчи шаҳар") }
    private var jeddahTitle: String { tr("Через Джидду", "Via Jeddah", "Jidda orqali", "Жидда орқали") }
    private var madinahTitle: String { tr("Сначала Медина", "Madinah first", "Avval Madina", "Аввал Мадина") }
    private var priorityTitle: String { tr("Главный приоритет", "Main priority", "Asosiy ustuvorlik", "Асосий устуворлик") }
    private var lowestPriceTitle: String { tr("Выгодная цена", "Best value", "Yaxshi narx", "Яхши нарх") }
    private var lowestPriceSubtitle: String { tr("Снизить итог", "Lower total", "Narxni kamaytirish", "Нархни камайтириш") }
    private var nearHaramTitle: String { tr("Ближе к Хараму", "Near the Haram", "Haramga yaqin", "Ҳарамга яқин") }
    private var nearHaramSubtitle: String { tr("Локация важнее", "Location first", "Joylashuv muhim", "Жойлашув муҳим") }
    private var balancedTitle: String { tr("Баланс", "Balanced", "Muvozanat", "Мувозанат") }
    private var balancedSubtitle: String { tr("Цена + комфорт", "Value + comfort", "Narx + qulaylik", "Нарх + қулайлик") }
    private var premiumTitle: String { tr("Premium", "Premium", "Premium", "Premium") }
    private var premiumSubtitle: String { tr("Комфорт важнее", "Comfort first", "Qulaylik muhim", "Қулайлик муҳим") }
    private var comfortTitle: String { tr("Комфорт и бюджет", "Comfort & budget", "Qulaylik va budjet", "Қулайлик ва бюджет") }
    private var hotelClassTitle: String { tr("Уровень отеля", "Hotel level", "Mehmonxona darajasi", "Меҳмонхона даражаси") }
    private var transferTitle: String { tr("Трансфер", "Transfer", "Transfer", "Трансфер") }
    private var comfortableTransferTitle: String { tr("Комфорт", "Comfort", "Komfort", "Комфорт") }
    private var privateSUVTitle: String { tr("Private SUV", "Private SUV", "Private SUV", "Private SUV") }
    private var vipTransferTitle: String { tr("VIP", "VIP", "VIP", "VIP") }
    private var directFlightsTitle: String { tr("По возможности прямые рейсы", "Prefer direct flights", "Imkon qadar to‘g‘ridan-to‘g‘ri reyslar", "Имкон қадар тўғридан-тўғри рейслар") }
    private var checkedBaggageTitle: String { tr("Нужен багаж", "Checked baggage", "Bagaj kerak", "Багаж керак") }
    private var budgetTitle: String { tr("Желаемый бюджет на человека, USD (необязательно)", "Budget per person, USD (optional)", "Bir kishi uchun budjet, USD (ixtiyoriy)", "Бир киши учун бюджет, USD (ихтиёрий)") }
    private var servicesTitle: String { tr("Iumrah Services", "Iumrah Services", "Iumrah Services", "Iumrah Services") }
    private var ziyaratTitle: String { tr("Добавить Iumrah Ziyarat", "Include Iumrah Ziyarat", "Iumrah Ziyarat qo‘shish", "Iumrah Ziyarat қўшиш") }
    private var esimTitle: String { tr("Добавить Iumrah eSIM", "Include Iumrah eSIM", "Iumrah eSIM qo‘shish", "Iumrah eSIM қўшиш") }
    private var guideTitle: String { tr("Сопровождение", "Guidance", "Hamrohlik", "Ҳамроҳлик") }
    private var noGuideTitle: String { tr("Без гида", "None", "Gidsiz", "Гидсиз") }
    private var voiceGuideTitle: String { tr("Voice Guide", "Voice Guide", "Voice Guide", "Voice Guide") }
    private var liveGuideTitle: String { tr("Живой гид", "Live guide", "Jonli gid", "Жонли гид") }
    private var contactTitle: String { tr("Как с Вами связаться", "How to reach you", "Siz bilan qanday bog‘lanamiz", "Сиз билан қандай боғланамиз") }
    private var firstNameTitle: String { tr("Имя", "First name", "Ism", "Исм") }
    private var lastNameTitle: String { tr("Фамилия", "Last name", "Familiya", "Фамилия") }
    private var phoneTitle: String { tr("Телефон / WhatsApp", "Phone / WhatsApp", "Telefon / WhatsApp", "Телефон / WhatsApp") }
    private var telegramTitle: String { tr("Telegram (необязательно)", "Telegram (optional)", "Telegram (ixtiyoriy)", "Telegram (ихтиёрий)") }
    private var wishesTitle: String { tr("Дополнительные пожелания", "Extra preferences", "Qo‘shimcha istaklar", "Қўшимча истаклар") }
    private var wishesPlaceholder: String { tr("Например: отдельные кровати, поздний вылет, коляска, особые пожелания по отелю…", "For example: twin beds, late departure, wheelchair, specific hotel preferences…", "Masalan: alohida karavotlar, kech parvoz, aravacha, mehmonxona bo‘yicha istaklar…", "Масалан: алоҳида каравотлар, кеч парвоз, аравача, меҳмонхона бўйича истаклар…") }
    private var submitTitle: String { tr("Собрать мою Умру за меня", "Build my Umrah for me", "Umramni men uchun tuzing", "Умрамни мен учун тузинг") }
    private var successTitle: String { tr("Запрос отправлен", "Request sent", "So‘rov yuborildi", "Сўров юборилди") }
    private var successBody: String { tr("Iumrah Care получил Ваши предпочтения. Мы сохранили запрос как отдельную заявку с двухчасовым окном ответа.", "Iumrah Care received your preferences. Your request is saved as a separate case with a two-hour response window.", "Iumrah Care istaklaringizni oldi. So‘rov alohida ariza sifatida ikki soatlik javob oynasi bilan saqlandi.", "Iumrah Care истакларингизни олди. Сўров алоҳида ариза сифатида икки соатлик жавоб ойнаси билан сақланди.") }
    private var newRequestTitle: String { tr("Новый запрос", "New request", "Yangi so‘rov", "Янги сўров") }
    private var requestNumberTitle: String { tr("Номер запроса", "Request ID", "So‘rov raqami", "Сўров рақами") }
    private var responseTimeTitle: String { tr("Окно ответа", "Response window", "Javob oynasi", "Жавоб ойнаси") }
    private var doneTitle: String { tr("Готово", "Done", "Tayyor", "Тайёр") }
    private var errorTitle: String { tr("Не удалось отправить", "Couldn’t send", "Yuborilmadi", "Юборилмади") }
    private var okTitle: String { tr("OK", "OK", "OK", "OK") }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzc: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .turkish: return TurkishLocalization.phrase(en)
        case .indonesian, .malay, .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzc
        }
    }
}
