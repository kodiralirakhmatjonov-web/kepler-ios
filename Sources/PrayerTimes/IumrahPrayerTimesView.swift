import SwiftUI
import CoreLocation

struct IumrahPrayerTimesView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @StateObject private var state = IumrahPrayerState()
    @StateObject private var location = IumrahPrayerLocation()
    @State private var chosenDate = Date()
    @State private var showingCity = false
    @State private var showingCalculation = false
    @State private var showingWallpapers = false
    @AppStorage("iumrah.booking.travelInfo.city") private var holyCityRaw = "makkah"
    @State private var editingPrayer: IumrahPrayerKind?

    private var schedule: IumrahPrayerSchedule {
        IumrahPrayerCalculator.calculate(on: chosenDate, place: state.place, method: state.method, hanafi: state.hanafi)
    }
    private var isToday: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = state.place.timeZone
        return calendar.isDate(chosenDate, inSameDayAs: Date())
    }

    var body: some View {
        ZStack {
            wallpaperBackground
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    topHeader
                    nextPrayerHero
                    dateSelector
                    dailySchedule
                    extraPrayers
                    calculationFootnote
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(tr("Prayer Times", "Времена молитв", "Namoz vaqtlari", "Намоз вақтлари"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showingWallpapers = true } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .accessibilityLabel(tr("Change wallpaper", "Изменить обои", "Fon rasmini o‘zgartirish", "Фон расмини ўзгартириш"))

                Button { showingCalculation = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel(tr("Calculation settings", "Метод расчёта", "Hisoblash sozlamalari", "Ҳисоблаш созламалари"))
            }
        }
        .sheet(isPresented: $showingCity) {
            IumrahPrayerCitySheet(state: state, location: location)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showingCalculation) {
            IumrahPrayerMethodSheet(state: state)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showingWallpapers) {
            IumrahPrayerWallpaperSheet(state: state)
                .environmentObject(settings)
        }
        .sheet(item: $editingPrayer) { kind in
            IumrahPrayerNotificationSheet(start: kind, state: state)
                .environmentObject(settings)
        }
        .task { _ = await IumrahPrayerNotifications.synchronize(state: state) }
        .onChange(of: state.place) { _, _ in refreshNotifications() }
        .onChange(of: state.method) { _, _ in refreshNotifications() }
        .onChange(of: state.hanafi) { _, _ in refreshNotifications() }
    }

    private var wallpaperBackground: some View {
        ZStack {
            Image(state.wallpaper.assetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.40),
                            Color.black.opacity(0.28),
                            Color(red: 0.96, green: 0.97, blue: 0.99).opacity(0.84),
                            Color(red: 0.96, green: 0.97, blue: 0.99).opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .blur(radius: 20)
            Color.iumrahPageBackground.opacity(0.18)
        }
        .ignoresSafeArea()
    }

    private var topHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("YOUR DAILY PRAYERS", "РАСПИСАНИЕ НАМАЗОВ", "KUNLIK NAMOZLAR", "КУНЛИК НАМОЗЛАР"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Button { showingCity = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                        Text(state.place.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Change city", "Изменить город", "Shaharni o‘zgartirish", "Шаҳарни ўзгартириш"))
            }
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                glassCircleButton(icon: "photo") { showingWallpapers = true }
                glassCircleButton(icon: "gearshape.fill") { showingCalculation = true }
            }
        }
    }

    private var makkahMadinahPicker: some View {
        HStack(spacing: 8) {
            ForEach(IumrahHolyCity.allCases) { holyCity in
                Button {
                    guard state.place.id != holyCity.rawValue else { return }
                    if let selected = IumrahPrayerPlace.presets.first(where: { $0.id == holyCity.rawValue }) {
                        withAnimation(.snappy(duration: 0.26)) {
                            state.place = selected
                            holyCityRaw = holyCity.rawValue
                        }
                        IumrahHaptics.selection()
                    }
                } label: {
                    Text(holyCity.title(settings.language))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(state.place.id == holyCity.rawValue ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            if state.place.id == holyCity.rawValue {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color.iumrahCardBackground)
                                    .shadow(color: Color.black.opacity(0.045), radius: 4, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(state.place.id == holyCity.rawValue ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
    }

    private var nextPrayerHero: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let next = IumrahPrayerCalculator.upcoming(now: context.date, place: state.place,
                method: state.method, hanafi: state.hanafi)
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label(tr("NEXT PRAYER", "СЛЕДУЮЩИЙ НАМАЗ", "KEYINGI NAMOZ", "КЕЙИНГИ НАМОЗ"), systemImage: "sparkle")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(1)
                    Spacer()
                    Text(state.wallpaper.title(settings.language))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .foregroundStyle(Color.white.opacity(0.84))

                VStack(alignment: .leading, spacing: 4) {
                    Text(next.map { prayerTitle($0.kind) } ?? "—")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(next.map { timeText($0.date) } ?? "--:--")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    Text(next.map { countdown($0.date, since: context.date) } ?? "--:--:--")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)
                        .foregroundStyle(Color.white)
                        .contentTransition(.numericText())
                    Text(tr("until the next prayer", "до следующего намаза", "keyingi namozgacha", "кейинги намозгача"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 290)
            .background {
                ZStack {
                    Image(state.wallpaper.assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            LinearGradient(colors: [Color.black.opacity(0.42), Color.black.opacity(0.18), Color.black.opacity(0.48)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    Circle()
                        .fill(Color.orange.opacity(0.22))
                        .frame(width: 240, height: 240)
                        .blur(radius: 48)
                        .offset(x: 125, y: -115)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        .frame(width: 220, height: 220)
                        .offset(x: 148, y: 80)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 20, y: 10)
            .accessibilityElement(children: .combine)
        }
    }

    private var dateSelector: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Daily schedule", "Расписание на день", "Kunlik jadval", "Кунлик жадвал"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(dateLabel(chosenDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button { moveDate(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel("Previous day")
            Button { chosenDate = Date() } label: {
                Text(tr("Today", "Сегодня", "Bugun", "Бугун"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
            }
            .disabled(isToday)
            Button { moveDate(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel("Next day")
        }
        .buttonStyle(.plain)
    }

    private var dailySchedule: some View {
        VStack(spacing: 0) {
            ForEach([IumrahPrayerKind.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]) { kind in
                if let time = schedule.date(for: kind) {
                    Button { editingPrayer = kind } label: {
                        HStack(spacing: 14) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(iconTint(kind))
                                .frame(width: 46, height: 46)
                                .background(iconTint(kind).opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(prayerTitle(kind))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text(kind == .sunrise ? tr("Not a prayer · sunrise time", "Не намаз · время восхода", "Namoz emas · quyosh chiqishi", "Намоз эмас · қуёш чиқиши") : tr("Tap to configure reminder", "Нажмите для напоминания", "Eslatma sozlash uchun bosing", "Эслатма созлаш учун босинг"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 10)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(timeText(time))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                                if state.preference(for: kind).enabled {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.orange)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 77)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if kind != .isha {
                        Divider().padding(.leading, 78)
                    }
                }
            }
        }
        .background(Color.iumrahCardBackground.opacity(0.96), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var extraPrayers: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Additional prayers", "Дополнительные молитвы", "Qo‘shimcha namozlar", "Қўшимча намозлар"))
                .font(.system(size: 21, weight: .bold, design: .rounded))
            ForEach([IumrahPrayerKind.duha, .tahajjud]) { kind in
                if let date = schedule.date(for: kind) {
                    Button { editingPrayer = kind } label: {
                        HStack(spacing: 13) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 23))
                                .foregroundStyle(iconTint(kind))
                                .frame(width: 45)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(prayerTitle(kind))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(kind == .duha ? tr("Starts after sunrise", "Начинается после восхода", "Quyosh chiqqandan keyin", "Қуёш чиққандан кейин") :
                                    tr("Last third of the night", "Последняя треть ночи", "Tunning oxirgi uchdan biri", "Туннинг охирги учдан бири"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(timeText(date))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(Color.iumrahCardBackground.opacity(0.96), in: RoundedRectangle(cornerRadius: 21))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var calculationFootnote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "photo")
                Text(state.wallpaper.title(settings.language))
                Text("·")
                Text(state.method.title + " · " + (state.hanafi ? "Hanafi Asr" : "Standard Asr"))
            }
            .font(.caption.weight(.medium))
            Text(tr("Calculated offline for the selected coordinates and time zone. Local mosque timetables may vary; verify during travel. Alerts require iOS notification permission.",
                "Расчёт офлайн по координатам и часовому поясу. Расписание местной мечети может отличаться; проверяйте во время поездки. Для напоминаний нужно разрешение iOS.",
                "Vaqtlar koordinata va vaqt mintaqasi bo‘yicha oflayn hisoblanadi. Mahalliy masjid jadvali farq qilishi mumkin. Eslatmalar uchun iOS ruxsati kerak.",
                "Вақтлар координата ва вақт минтақаси бўйича офлайн ҳисобланади. Маҳаллий масжид жадвали фарқ қилиши мумкин. Эслатмалар учун iOS рухсати керак."))
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 3)
    }

    private func glassCircleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func moveDate(_ offset: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = state.place.timeZone
        if let moved = calendar.date(byAdding: .day, value: offset, to: chosenDate) { chosenDate = moved }
    }
    private func refreshNotifications() {
        Task { _ = await IumrahPrayerNotifications.synchronize(state: state) }
    }
    private func countdown(_ date: Date, since now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
    private func timeText(_ date: Date) -> String { schedule.displayTime(date) }
    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language == .russian ? "ru_RU" : settings.language == .english ? "en_US" : "uz_UZ")
        formatter.timeZone = state.place.timeZone
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    private func iconTint(_ kind: IumrahPrayerKind) -> Color {
        switch kind {
        case .fajr, .tahajjud: return .indigo
        case .sunrise, .duha: return .orange
        case .dhuhr: return .yellow
        case .asr: return .teal
        case .maghrib: return .pink
        case .isha: return .purple
        }
    }
    private func prayerTitle(_ kind: IumrahPrayerKind) -> String {
        switch kind {
        case .fajr: return tr("Fajr", "Фаджр", "Bomdod", "Бомдод")
        case .sunrise: return tr("Sunrise", "Восход", "Quyosh chiqishi", "Қуёш чиқиши")
        case .dhuhr: return tr("Dhuhr", "Зухр", "Peshin", "Пешин")
        case .asr: return tr("Asr", "Аср", "Asr", "Аср")
        case .maghrib: return tr("Maghrib", "Магриб", "Shom", "Шом")
        case .isha: return tr("Isha", "Иша", "Xufton", "Хуфтон")
        case .duha: return tr("Duha", "Духа", "Zuho", "Зуҳо")
        case .tahajjud: return tr("Tahajjud", "Тахаджуд", "Tahajjud", "Таҳажжуд")
        }
    }
    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        prayerText(settings.language, en, ru, uz, cyrl)
    }
}

private struct IumrahPrayerWallpaperSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: IumrahPrayerState

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(IumrahPrayerWallpaper.allCases) { wallpaper in
                        Button {
                            state.wallpaper = wallpaper
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                ZStack(alignment: .topTrailing) {
                                    Image(wallpaper.assetName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 215)
                                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .strokeBorder(state.wallpaper == wallpaper ? Color.orange : Color.white.opacity(0.10), lineWidth: state.wallpaper == wallpaper ? 2.5 : 1)
                                        }
                                    if state.wallpaper == wallpaper {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white, .orange)
                                            .padding(10)
                                    }
                                }
                                Text(wallpaper.title(settings.language))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(wallpaper.subtitle(settings.language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                VStack(alignment: .leading, spacing: 6) {
                    Text(prayerText(settings.language, "All wallpapers are prepared in the same phone-sized portrait format to keep the screen stable while switching.", "Все обои подготовлены в одном вертикальном формате экрана телефона, чтобы при смене всё отображалось стабильно.", "Barcha oboylar telefon ekrani uchun bir xil vertikal formatda tayyorlangan, shuning uchun almashtirish barqaror bo‘ladi.", "Барча обойлар телефон экрани учун бир хил вертикал форматда тайёрланган, шунинг учун алмаштириш барқарор бўлади."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .navigationTitle(prayerText(settings.language, "Change wallpaper", "Изменить обои", "Fon rasmini o‘zgartirish", "Фон расмини ўзгартириш"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(prayerText(settings.language, "Done", "Готово", "Tayyor", "Тайёр")) { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.65), .large])
    }
}

private struct IumrahPrayerCitySheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: IumrahPrayerState
    @ObservedObject var location: IumrahPrayerLocation
    @State private var cityQuery = ""
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        NavigationStack {
            List {
                Section(prayerText(settings.language, "Search any city", "Поиск города", "Shahar qidirish", "Шаҳар қидириш")) {
                    HStack {
                        TextField(prayerText(settings.language, "City or town", "Город", "Shahar", "Шаҳар"), text: $cityQuery)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .onSubmit { searchCity() }
                        Button { searchCity() } label: {
                            if isSearching { ProgressView() }
                            else { Image(systemName: "magnifyingglass") }
                        }
                        .disabled(cityQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || isSearching)
                        .accessibilityLabel("Find city")
                    }
                    if let searchError {
                        Text(searchError).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button {
                        location.request()
                    } label: {
                        HStack {
                            Label(prayerText(settings.language, "Use current location", "Моё местоположение", "Joylashuvim", "Жойлашувим"), systemImage: "location.north.circle.fill")
                            Spacer()
                            if location.working { ProgressView() }
                        }
                    }
                    if let message = location.message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section(prayerText(settings.language, "Cities", "Города", "Shaharlar", "Шаҳарлар")) {
                    ForEach(IumrahPrayerPlace.presets) { city in
                        Button {
                            state.place = city
                            dismiss()
                        } label: {
                            HStack {
                                Text(city.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if state.place.id == city.id { Image(systemName: "checkmark").foregroundStyle(.orange) }
                            }
                        }
                    }
                }
                Section {
                    Text(prayerText(settings.language, "Prayer times are calculated for the chosen city's time zone. Location is only requested when you tap the button above.", "Время молитв рассчитывается для часового пояса выбранного города. Геопозиция запрашивается только после нажатия кнопки выше.", "Namoz vaqtlari tanlangan shahar vaqt mintaqasi bo‘yicha hisoblanadi. Joylashuv faqat yuqoridagi tugma bosilganda so‘raladi.", "Намоз вақтлари танланган шаҳар вақт минтақаси бўйича ҳисобланади. Жойлашув фақат юқоридаги тугма босилганда сўралади."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(prayerText(settings.language, "Choose a city", "Выбрать город", "Shahar tanlash", "Шаҳар танлаш"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(prayerText(settings.language, "Done", "Готово", "Tayyor", "Тайёр")) { dismiss() } } }
            .onChange(of: location.resolved) { _, city in
                if let city { state.place = city; dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func searchCity() {
        let query = cityQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, !isSearching else { return }
        isSearching = true
        searchError = nil
        Task { @MainActor in
            defer { isSearching = false }
            guard let placemark = try? await CLGeocoder().geocodeAddressString(query).first,
                  let coordinate = placemark.location?.coordinate,
                  CLLocationCoordinate2DIsValid(coordinate) else {
                searchError = prayerText(settings.language, "City not found. Try another spelling or choose from the list.", "Город не найден. Попробуйте другое написание или выберите из списка.", "Shahar topilmadi. Boshqa yozilishini sinab ko‘ring yoki ro‘yxatdan tanlang.", "Шаҳар топилмади. Бошқа ёзилишини синаб кўринг ёки рўйхатдан танланг.")
                return
            }
            let city = IumrahPrayerPlace(
                id: "searched", name: placemark.locality ?? placemark.name ?? query,
                latitude: coordinate.latitude, longitude: coordinate.longitude,
                timeZoneID: placemark.timeZone?.identifier ?? TimeZone.autoupdatingCurrent.identifier
            )
            state.place = city
            dismiss()
        }
    }
}

private struct IumrahPrayerMethodSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: IumrahPrayerState

    var body: some View {
        NavigationStack {
            Form {
                Section(prayerText(settings.language, "Calculation method", "Метод расчёта", "Hisoblash usuli", "Ҳисоблаш усули")) {
                    Picker("Method", selection: $state.method) {
                        ForEach(IumrahPrayerMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section(prayerText(settings.language, "Asr calculation", "Расчёт Асра", "Asr hisobi", "Аср ҳисоби")) {
                    Picker("Juristic method", selection: $state.hanafi) {
                        Text("Standard (Shafi'i / Maliki / Hanbali)").tag(false)
                        Text("Hanafi").tag(true)
                    }
                    .pickerStyle(.inline)
                }
                Section {
                    Text(prayerText(settings.language, "Umm al-Qura uses the standard Makkah twilight method and a fixed interval after sunset for Isha. Your selected method is saved on this device.", "Umm al-Qura использует стандартный метод Мекки и фиксированный интервал после заката для Иши. Выбранный метод сохраняется на этом устройстве.", "Umm al-Qura Makka usulidan va Xufton uchun quyosh botgandan keyingi qat'iy oraliqdan foydalanadi. Tanlangan usul qurilmada saqlanadi.", "Umm al-Qura Макка усулидан ва Хуфтон учун қуёш ботгандан кейинги қатъий оралиқдан фойдаланади. Танланган усул қурилмада сақланади."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(prayerText(settings.language, "Calculation settings", "Настройки расчёта", "Hisoblash sozlamalari", "Ҳисоблаш созламалари"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(prayerText(settings.language, "Done", "Готово", "Tayyor", "Тайёр")) { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}

// Keep notification controls split into small views. Large nested SwiftUI expressions
// cause the Xcode type-checker to time out, particularly with inline Bindings.
private struct IumrahPrayerNotificationSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: IumrahPrayerState
    @State private var selected: IumrahPrayerKind
    @State private var edited: [String: IumrahPrayerNotificationPreference]
    @State private var message: String?
    @State private var saving = false

    init(start: IumrahPrayerKind, state: IumrahPrayerState) {
        self.state = state
        _selected = State(initialValue: start)
        _edited = State(initialValue: state.notifications)
    }

    private func preference(_ kind: IumrahPrayerKind) -> IumrahPrayerNotificationPreference {
        edited[kind.rawValue] ?? .init()
    }

    private func enabled(_ kind: IumrahPrayerKind) -> Binding<Bool> {
        Binding<Bool>(
            get: { preference(kind).enabled },
            set: { value in
                var item = preference(kind)
                item.enabled = value
                edited[kind.rawValue] = item
            }
        )
    }

    private func sound(_ kind: IumrahPrayerKind) -> Binding<Bool> {
        Binding<Bool>(
            get: { preference(kind).sound },
            set: { value in
                var item = preference(kind)
                item.sound = value
                edited[kind.rawValue] = item
            }
        )
    }

    private func offset(_ kind: IumrahPrayerKind) -> Binding<Double> {
        Binding<Double>(
            get: { Double(preference(kind).offsetMinutes) },
            set: { value in
                var item = preference(kind)
                item.offsetMinutes = Int(value)
                edited[kind.rawValue] = item
            }
        )
    }

    private func earlyEnabled(_ kind: IumrahPrayerKind) -> Binding<Bool> {
        Binding<Bool>(
            get: { preference(kind).earlyReminderMinutes != nil },
            set: { value in
                var item = preference(kind)
                item.earlyReminderMinutes = value ? (item.earlyReminderMinutes ?? 10) : nil
                edited[kind.rawValue] = item
            }
        )
    }

    private func earlyMinutes(_ kind: IumrahPrayerKind) -> Binding<Int> {
        Binding<Int>(
            get: { preference(kind).earlyReminderMinutes ?? 10 },
            set: { value in
                var item = preference(kind)
                item.earlyReminderMinutes = value
                edited[kind.rawValue] = item
            }
        )
    }

    private var showingMessage: Binding<Bool> {
        Binding<Bool>(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                prayerPager
                saveButton
            }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .navigationTitle(prayerText(settings.language, "Prayer notifications", "Уведомления о намазе", "Namoz eslatmalari", "Намоз эслатмалари"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(prayerText(settings.language, "Close", "Закрыть", "Yopish", "Ёпиш")) {
                        dismiss()
                    }
                }
            }
            .alert(
                prayerText(settings.language, "Prayer notifications", "Уведомления о намазе", "Namoz eslatmalari", "Намоз эслатмалари"),
                isPresented: showingMessage
            ) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
        .presentationDetents([.large])
    }

    private var prayerPager: some View {
        TabView(selection: $selected) {
            ForEach(IumrahPrayerKind.allCases) { kind in
                prayerPage(kind)
                    .tag(kind)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
    }

    private func prayerPage(_ kind: IumrahPrayerKind) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                prayerHeading(kind)
                notificationControls(kind)
                offsetControls(kind)
                earlyReminderControls(kind)
                testNotificationButton(kind)
                explanation
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
    }

    private func prayerHeading(_ kind: IumrahPrayerKind) -> some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 29))
                .foregroundStyle(.orange)
                .frame(width: 58, height: 58)
                .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                Text(prayerText(settings.language, "Configure reminder and sound", "Напоминание и звук", "Eslatma va ovoz", "Эслатма ва овоз"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func notificationControls(_ kind: IumrahPrayerKind) -> some View {
        VStack(spacing: 0) {
            Toggle(isOn: enabled(kind)) {
                Label(
                    prayerText(settings.language, "Notification", "Уведомление", "Bildirishnoma", "Билдиришнома"),
                    systemImage: "bell"
                )
            }
            .tint(.green)
            .padding(16)

            Divider().padding(.leading, 18)

            Toggle(isOn: sound(kind)) {
                Label(
                    prayerText(settings.language, "System notification sound", "Системный звук", "Tizim ovozi", "Тизим овози"),
                    systemImage: "speaker.wave.2"
                )
            }
            .padding(16)
        }
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22))
    }

    private func offsetControls(_ kind: IumrahPrayerKind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    prayerText(settings.language, "Reminder offset", "Время уведомления", "Eslatma vaqti", "Эслатма вақти"),
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.headline)
                Spacer()
                Text(offsetDescription(preference(kind).offsetMinutes))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Slider(value: offset(kind), in: -30...30, step: 5)
                .tint(.orange)
                .accessibilityLabel("Minutes before or after prayer")
            HStack {
                Text("−30 min")
                Spacer()
                Text(prayerText(settings.language, "At prayer time", "Вовремя", "O‘z vaqtida", "Ўз вақтида"))
                Spacer()
                Text("+30 min")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            Button(prayerText(settings.language, "Reset offset", "Сбросить", "Qaytarish", "Қайтариш")) {
                var item = preference(kind)
                item.offsetMinutes = 0
                edited[kind.rawValue] = item
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder
    private func earlyReminderControls(_ kind: IumrahPrayerKind) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Toggle(isOn: earlyEnabled(kind)) {
                Label(
                    prayerText(settings.language, "Early reminder", "Предварительное уведомление", "Oldindan eslatma", "Олдиндан эслатма"),
                    systemImage: "bell.badge"
                )
            }
            .tint(.orange)
            if preference(kind).earlyReminderMinutes != nil {
                earlyReminderPicker(kind)
            }
        }
        .padding(17)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22))
    }

    private func earlyReminderPicker(_ kind: IumrahPrayerKind) -> some View {
        Picker(
            prayerText(settings.language, "Before prayer", "До молитвы", "Namozgacha", "Намозгача"),
            selection: earlyMinutes(kind)
        ) {
            ForEach([5, 10, 15, 30], id: \.self) { minutes in
                Text("\(minutes) min").tag(minutes)
            }
        }
        .pickerStyle(.segmented)
    }

    private func testNotificationButton(_ kind: IumrahPrayerKind) -> some View {
        Button {
            Task { await sendPreview(kind) }
        } label: {
            Label(
                prayerText(settings.language, "Test notification", "Проверить уведомление", "Eslatmani sinash", "Эслатмани синаш"),
                systemImage: "bell.badge"
            )
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
    }

    private var explanation: some View {
        Text(prayerText(
            settings.language,
            "Swipe left or right to configure another prayer. Alerts use the selected city's local prayer times. Custom adhan audio is not included.",
            "Свайпайте влево или вправо, чтобы настроить другой намаз. Напоминания используют время выбранного города. Пользовательский азан пока не включён.",
            "Boshqa namozni sozlash uchun chapga yoki o‘ngga suring. Eslatmalar tanlangan shahar vaqtlaridan foydalanadi. Maxsus azon ovozi hozircha yo‘q.",
            "Бошқа намозни созлаш учун чапга ёки ўнгга суринг. Эслатмалар танланган шаҳар вақтларидан фойдаланади. Махсус азон овози ҳозирча йўқ."
        ))
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var saveButton: some View {
        Button {
            Task { await saveSettings() }
        } label: {
            HStack {
                if saving { ProgressView().tint(.white) }
                Text(prayerText(settings.language, "Save settings", "Сохранить", "Saqlash", "Сақлаш"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 49)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(Color.green, in: Capsule())
        .disabled(saving)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    @MainActor
    private func sendPreview(_ kind: IumrahPrayerKind) async {
        let success = await IumrahPrayerNotifications.preview(kind: kind, sound: preference(kind).sound)
        message = success
            ? prayerText(settings.language, "A test notification is scheduled in 5 seconds.", "Тестовое уведомление придёт через 5 секунд.", "Sinov bildirishnomasi 5 soniyada keladi.", "Синов билдиришномаси 5 сонияда келади.")
            : prayerText(settings.language, "Enable notifications for iumrah in iOS Settings to receive reminders.", "Включите уведомления для iumrah в настройках iOS.", "Eslatmalar uchun iOS sozlamalarida iumrah bildirishnomalarini yoqing.", "Эслатмалар учун iOS созламаларида iumrah билдиришномаларини ёқинг.")
    }

    @MainActor
    private func saveSettings() async {
        guard !saving else { return }
        saving = true
        state.notifications = edited
        let success = await IumrahPrayerNotifications.synchronize(state: state, allowPermissionPrompt: true)
        saving = false
        if success {
            dismiss()
        } else {
            message = prayerText(
                settings.language,
                "Enable notifications for iumrah in iOS Settings. Your choices have been saved.",
                "Включите уведомления для iumrah в настройках iOS. Ваши настройки сохранены.",
                "iOS sozlamalarida iumrah bildirishnomalarini yoqing. Tanlovlaringiz saqlandi.",
                "iOS созламаларида iumrah билдиришномаларини ёқинг. Танловларингиз сақланди."
            )
        }
    }

    private func offsetDescription(_ minutes: Int) -> String {
        if minutes == 0 {
            return prayerText(settings.language, "On time", "Вовремя", "O‘z vaqtida", "Ўз вақтида")
        }
        let sign = minutes < 0 ? "−" : "+"
        return "\(sign)\(abs(minutes)) min"
    }
}
