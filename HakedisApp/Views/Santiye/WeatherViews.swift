import SwiftUI
import SwiftData
import CoreLocation

// MARK: - WeatherDashboardView

struct WeatherDashboardView: View {
    @Query(sort: \WeatherRecord.recordDate, order: .reverse) private var records: [WeatherRecord]
    @State private var selectedProject: Project?
    @State private var showAddWeather = false
    @State private var todayWeather: WeatherRecord?
    @State private var isFetchingWeather = false
    @StateObject private var locationManager = SimpleLocationManager()
    @Environment(\.modelContext) private var modelContext

    private var today: WeatherRecord? {
        let calendar = Calendar.current
        return records.first { calendar.isDateInToday($0.recordDate) }
    }

    private var thisMonthRecords: [WeatherRecord] {
        let calendar = Calendar.current
        let now = Date()
        return records.filter { calendar.isDate($0.recordDate, equalTo: now, toGranularity: .month) }
    }

    private var workSuitableDays: Int {
        thisMonthRecords.filter { $0.isWorkSuitable }.count
    }

    private var unsuitableDays: Int {
        thisMonthRecords.filter { !$0.isWorkSuitable }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.section) {
                    // Bugünkü hava
                    todayCard

                    // Beton döküm uygunluk
                    if let today = today {
                        concreteCard(for: today)
                    }

                    // Aylık özet
                    monthlySection

                    // Son kayıtlar
                    recentRecordsSection
                }
                .padding(.vertical, Spacing.md)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Hava Durumu")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            fetchWeatherFromAPI()
                        } label: {
                            Label("Otomatik Çek", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        Button {
                            showAddWeather = true
                        } label: {
                            Label("Manuel Giriş", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Hava Durumu Ekle")
                }
            }
            .sheet(isPresented: $showAddWeather) {
                AddWeatherRecordView()
            }
        }
    }

    private var todayCard: some View {
        VStack(spacing: Spacing.xs) {
            if let today = today {
                HStack {
                    Image(systemName: today.weatherCondition.icon)
                        .font(.system(size: 48))
                        .foregroundColor(.hakedisOrange)
                    VStack(alignment: .leading) {
                        Text(today.weatherCondition.rawValue)
                            .font(.title2.bold())
                        if let temp = today.averageTemp {
                            Text(String(format: "%.1f°C", temp))
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        if let humidity = today.humidity {
                            Text(String(format: "Nem: %.0f%%", humidity))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let wind = today.windSpeed {
                            Text(String(format: "Rüzgar: %.1f m/s", wind))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    StatusBadge(
                        text: today.isWorkSuitable ? "Çalışmaya Uygun" : "Dikkat",
                        color: today.isWorkSuitable ? .hakedisSuccess : .hakedisWarning
                    )
                }
            } else {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading) {
                        Text("Bugün Hava Kaydı Yok")
                            .font(.headline)
                        Text("Otomatik çek veya manuel giriş yapın.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                if isFetchingWeather {
                    ProgressView("Hava verisi alınıyor...")
                }
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .cornerRadius(12)
        .padding(.horizontal, Spacing.md)
    }

    private func concreteCard(for record: WeatherRecord) -> some View {
        let temp = record.averageTemp ?? 20
        let humidity = record.humidity ?? 50
        let wind = (record.windSpeed ?? 0) * 3.6  // m/s → km/s
        let result = ConcretePouring.isSuitable(temp: temp, humidity: humidity, wind: wind)

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: result.suitable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.suitable ? .hakedisSuccess : .hakedisDanger)
                Text("Beton Döküm Uygunluk")
                    .font(.headline)
                Spacer()
                StatusBadge(
                    text: result.suitable ? "Uygun" : "Uygun Değil",
                    color: result.suitable ? .hakedisSuccess : .hakedisDanger
                )
            }
            if !result.warnings.isEmpty {
                ForEach(result.warnings, id: \.self) { warning in
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.hakedisWarning)
                            .font(.caption)
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            } else {
                Text("Tüm koşullar beton dökümü için uygundur.")
                    .font(.caption)
                    .foregroundColor(.hakedisSuccess)
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .cornerRadius(12)
        .padding(.horizontal, Spacing.md)
    }

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader("Bu Ay Özeti")
            HStack(spacing: Spacing.md) {
                StatCard(
                    title: "Çalışma Günleri",
                    value: "\(workSuitableDays)",
                    subtitle: "Uygun hava",
                    color: .hakedisSuccess,
                    icon: "sun.max.fill"
                )
                StatCard(
                    title: "Durdurulan",
                    value: "\(unsuitableDays)",
                    subtitle: "Olumsuz hava",
                    color: .hakedisDanger,
                    icon: "cloud.bolt.fill"
                )
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader("Son Kayıtlar")
            if records.isEmpty {
                EmptyStateView(
                    icon: "cloud.fill",
                    title: "Kayıt Yok",
                    subtitle: "Henüz hava durumu kaydı girilmemiş."
                )
            } else {
                ForEach(records.prefix(7), id: \.id) { record in
                    HStack {
                        Image(systemName: record.weatherCondition.icon)
                            .foregroundColor(.hakedisOrange)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(record.recordDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                            Text(record.weatherCondition.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let temp = record.averageTemp {
                            Text(String(format: "%.1f°C", temp))
                                .font(.caption)
                        }
                        StatusBadge(
                            text: record.isWorkSuitable ? "Uygun" : "Olumsuz",
                            color: record.isWorkSuitable ? .hakedisSuccess : .hakedisDanger
                        )
                    }
                    .padding(Spacing.cardSmall)
                    .background(Color.hakedisCard)
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private func fetchWeatherFromAPI() {
        guard WeatherService.shared.isConfigured else {
            showAddWeather = true
            return
        }
        locationManager.requestLocation { location in
            guard let location else { return }
            isFetchingWeather = true
            Task {
                if let data = await WeatherService.shared.fetchWeather(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ) {
                    await MainActor.run {
                        let record = WeatherRecord(recordDate: Date())
                        record.afternoonTemp = data.temperature
                        record.humidity = data.humidity
                        record.windSpeed = data.windSpeed
                        record.fetchedFromAPI = true

                        // Hava koşulunu icon'dan belirle
                        if data.weatherIcon.contains("sun") {
                            record.weatherCondition = .sunny
                        } else if data.weatherIcon.contains("bolt") {
                            record.weatherCondition = .stormy
                        } else if data.weatherIcon.contains("snow") {
                            record.weatherCondition = .snowy
                        } else if data.weatherIcon.contains("heavyrain") {
                            record.weatherCondition = .heavyRain
                        } else if data.weatherIcon.contains("rain") {
                            record.weatherCondition = .rainy
                        } else if data.weatherIcon.contains("fog") {
                            record.weatherCondition = .foggy
                        } else {
                            record.weatherCondition = .cloudy
                        }
                        record.isWorkSuitable = record.weatherCondition.isWorkSuitable

                        modelContext.insert(record)
                        do { try modelContext.save() } catch { }
                        isFetchingWeather = false
                    }
                } else {
                    await MainActor.run {
                        isFetchingWeather = false
                        showAddWeather = true
                    }
                }
            }
        }
    }
}

// MARK: - AddWeatherRecordView

struct AddWeatherRecordView: View {
    @State private var recordDate = Date()
    @State private var condition = WeatherCondition.sunny
    @State private var morningTempText = ""
    @State private var afternoonTempText = ""
    @State private var eveningTempText = ""
    @State private var humidityText = ""
    @State private var windSpeedText = ""
    @State private var windDirection = ""
    @State private var precipitationText = ""
    @State private var isWorkSuitable = true
    @State private var unsuitableReason = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Tarih ve Hava") {
                    DatePicker("Tarih", selection: $recordDate, displayedComponents: .date)
                    Picker("Hava Koşulu", selection: $condition) {
                        ForEach(WeatherCondition.allCases, id: \.self) { c in
                            Label(c.rawValue, systemImage: c.icon).tag(c)
                        }
                    }
                    .onChange(of: condition) { _, newVal in
                        isWorkSuitable = newVal.isWorkSuitable
                    }
                }
                Section("Sıcaklık (°C)") {
                    TextField("Sabah", text: $morningTempText).keyboardType(.decimalPad)
                    TextField("Öğleden Sonra", text: $afternoonTempText).keyboardType(.decimalPad)
                    TextField("Akşam", text: $eveningTempText).keyboardType(.decimalPad)
                }
                Section("Diğer") {
                    TextField("Nem (%)", text: $humidityText).keyboardType(.decimalPad)
                    TextField("Rüzgar (m/s)", text: $windSpeedText).keyboardType(.decimalPad)
                    TextField("Rüzgar Yönü", text: $windDirection)
                    TextField("Yağış (mm)", text: $precipitationText).keyboardType(.decimalPad)
                }
                Section("Çalışma Uygunluğu") {
                    Toggle("Çalışmaya Uygun", isOn: $isWorkSuitable)
                    if !isWorkSuitable {
                        TextField("Neden uygun değil", text: $unsuitableReason)
                    }
                }
            }
            .navigationTitle("Hava Kaydı Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        let record = WeatherRecord(recordDate: recordDate, condition: condition)
        record.morningTemp = Double(morningTempText.replacingOccurrences(of: ",", with: "."))
        record.afternoonTemp = Double(afternoonTempText.replacingOccurrences(of: ",", with: "."))
        record.eveningTemp = Double(eveningTempText.replacingOccurrences(of: ",", with: "."))
        record.humidity = Double(humidityText.replacingOccurrences(of: ",", with: "."))
        record.windSpeed = Double(windSpeedText.replacingOccurrences(of: ",", with: "."))
        record.windDirection = windDirection.isEmpty ? nil : windDirection
        record.precipitation = Double(precipitationText.replacingOccurrences(of: ",", with: "."))
        record.isWorkSuitable = isWorkSuitable
        record.unsuitableReason = unsuitableReason.isEmpty ? nil : unsuitableReason
        modelContext.insert(record)
        do { try modelContext.save() } catch { }
    }
}

// MARK: - SimpleLocationManager

class SimpleLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        completion?(locations.first)
        completion = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil)
        completion = nil
    }
}
