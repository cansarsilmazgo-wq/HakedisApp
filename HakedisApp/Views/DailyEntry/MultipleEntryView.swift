import SwiftUI
import SwiftData
import CoreLocation

struct MultipleEntryView: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var entryDate = Date()
    @State private var quantities: [String: String] = [:]
    @State private var locationNote = ""
    @State private var gpsLatitude: Double? = nil
    @State private var gpsLongitude: Double? = nil
    @State private var gpsAccuracy: Double? = nil
    @State private var weatherCondition = ""
    @State private var temperatureC: Double? = nil
    @State private var windSpeedKmh: Double? = nil
    @State private var isFetchingLocation = false
    @State private var isFetchingWeather = false
    @State private var locationManager = CLLocationManager()
    @State private var locationDelegate: LocationDelegate? = nil
    @State private var hasGPS = false

    private var sortedWorkItems: [WorkItem] {
        contract.workItems.sorted { $0.code < $1.code }
    }
    private var filledCount: Int {
        quantities.values.filter { Double($0.replacingOccurrences(of: ",", with: ".")) != nil && !$0.isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tarih") {
                    DatePicker("Giriş Tarihi", selection: $entryDate, displayedComponents: .date)
                }

                Section("Konum & Hava Durumu") {
                    if hasGPS, let lat = gpsLatitude, let lon = gpsLongitude {
                        HStack {
                            Image(systemName: "location.fill").foregroundColor(.hakedisSuccess)
                            Text(String(format: "%.4f, %.4f", lat, lon))
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Button {
                        fetchLocation()
                    } label: {
                        HStack {
                            if isFetchingLocation {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: hasGPS ? "location.fill" : "location")
                            }
                            Text(isFetchingLocation ? "Konum alınıyor..." : hasGPS ? "Konumu Güncelle" : "Konumu Al")
                                .foregroundColor(.hakedisOrange)
                        }
                    }
                    .disabled(isFetchingLocation)

                    if hasGPS {
                        Button {
                            fetchWeather()
                        } label: {
                            HStack {
                                if isFetchingWeather {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "cloud.sun")
                                }
                                Text(isFetchingWeather ? "Hava durumu alınıyor..." : "Hava Durumu Al")
                                    .foregroundColor(.hakedisOrange)
                            }
                        }
                        .disabled(isFetchingWeather)
                    }

                    if !weatherCondition.isEmpty {
                        HStack {
                            Image(systemName: "thermometer").foregroundColor(.hakedisOrange)
                            if let temp = temperatureC {
                                Text(String(format: "%.0f°C", temp))
                            }
                            Text(weatherCondition).foregroundColor(.secondary)
                            if let wind = windSpeedKmh {
                                Spacer()
                                Text(String(format: "%.0f km/h", wind)).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }

                    TextField("Konum Notu (opsiyonel)", text: $locationNote)
                }

                Section("İş Kalemleri (\(filledCount) giriş)") {
                    ForEach(sortedWorkItems, id: \.id) { item in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.code).font(.caption.bold()).foregroundColor(.hakedisOrange)
                                Text(item.name).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            TextField("Miktar", text: Binding(
                                get: { quantities[item.id.uuidString] ?? "" },
                                set: { quantities[item.id.uuidString] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            Text(item.unit).font(.caption).foregroundColor(.secondary).frame(width: 30)
                        }
                    }
                }
            }
            .navigationTitle("Toplu Saha Girişi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tümünü Kaydet") { saveAll() }
                        .disabled(filledCount == 0)
                        .bold()
                }
            }
        }
    }

    private func fetchLocation() {
        isFetchingLocation = true
        locationManager.requestWhenInUseAuthorization()
        let delegate = LocationDelegate { loc in
            DispatchQueue.main.async {
                gpsLatitude = loc.coordinate.latitude
                gpsLongitude = loc.coordinate.longitude
                gpsAccuracy = loc.horizontalAccuracy
                hasGPS = true
                isFetchingLocation = false
            }
        }
        locationDelegate = delegate
        locationManager.delegate = delegate
        locationManager.requestLocation()
    }

    private func fetchWeather() {
        guard let lat = gpsLatitude, let lon = gpsLongitude else { return }
        isFetchingWeather = true
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weathercode,windspeed_10m"
        guard let url = URL(string: urlStr) else { isFetchingWeather = false; return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                isFetchingWeather = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let current = json["current"] as? [String: Any] else { return }
                temperatureC = current["temperature_2m"] as? Double
                windSpeedKmh = current["windspeed_10m"] as? Double
                if let code = current["weathercode"] as? Int {
                    weatherCondition = wmoCodeToTurkish(code)
                }
            }
        }.resume()
    }

    private func wmoCodeToTurkish(_ code: Int) -> String {
        switch code {
        case 0: return "Açık"
        case 1...3: return "Parçalı Bulutlu"
        case 45...48: return "Sisli"
        case 51...67: return "Yağmurlu"
        case 71...77: return "Karlı"
        case 80...82: return "Sağanaklı"
        case 95...99: return "Fırtınalı"
        default: return "Bulutlu"
        }
    }

    private func saveAll() {
        for item in sortedWorkItems {
            guard let qtyStr = quantities[item.id.uuidString],
                  let qty = Double(qtyStr.replacingOccurrences(of: ",", with: ".")),
                  qty > 0 else { continue }
            let entry = DailyEntry(date: entryDate, quantity: qty, location: locationNote)
            entry.gpsLatitude = gpsLatitude
            entry.gpsLongitude = gpsLongitude
            entry.gpsAccuracy = gpsAccuracy
            entry.weatherCondition = weatherCondition
            entry.temperatureC = temperatureC
            entry.windSpeedKmh = windSpeedKmh
            if !weatherCondition.isEmpty { entry.weatherFetchedAt = Date() }
            entry.workItem = item
            modelContext.insert(entry)
            item.dailyEntries.append(entry)
        }
        dismiss()
    }
}

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onLocation: (CLLocation) -> Void
    init(onLocation: @escaping (CLLocation) -> Void) { self.onLocation = onLocation }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.first { onLocation(loc) }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}
