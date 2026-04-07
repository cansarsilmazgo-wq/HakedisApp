import Foundation
import SwiftData

// MARK: - WeatherData (API response struct)

struct WeatherData: Codable {
    var temperature: Double        // °C
    var humidity: Double           // %
    var windSpeed: Double          // m/s
    var weatherDescription: String
    var weatherIcon: String        // SF Symbol adı
    var precipitation: Double?     // mm
    var visibility: Double?        // km
}

struct WeatherForecast: Codable {
    var date: Date
    var minTemp: Double
    var maxTemp: Double
    var humidity: Double
    var windSpeed: Double
    var weatherDescription: String
    var weatherIcon: String
    var precipitation: Double?
}

// MARK: - WeatherRecord Model (kalıcı kayıt)

@Model
final class WeatherRecord {
    var id: UUID
    var recordDate: Date
    var morningTemp: Double?
    var afternoonTemp: Double?
    var eveningTemp: Double?
    var humidity: Double?
    var windSpeed: Double?
    var windDirection: String?
    var weatherConditionRaw: String
    var precipitation: Double?       // mm
    var isWorkSuitable: Bool
    var unsuitableReason: String?
    var fetchedFromAPI: Bool
    @Relationship var project: Project?
    var createdAt: Date

    init(recordDate: Date = Date(), condition: WeatherCondition = .sunny) {
        self.id = UUID()
        self.recordDate = recordDate
        self.weatherConditionRaw = condition.rawValue
        self.isWorkSuitable = true
        self.fetchedFromAPI = false
        self.createdAt = Date()
    }

    var weatherCondition: WeatherCondition {
        get { WeatherCondition(rawValue: weatherConditionRaw) ?? .sunny }
        set { weatherConditionRaw = newValue.rawValue }
    }

    var averageTemp: Double? {
        let temps = [morningTemp, afternoonTemp, eveningTemp].compactMap { $0 }
        guard !temps.isEmpty else { return nil }
        return temps.reduce(0, +) / Double(temps.count)
    }
}

// MARK: - ConcretePouring Suitability

struct ConcretePouring {
    static func isSuitable(temp: Double, humidity: Double, wind: Double) -> (suitable: Bool, warnings: [String]) {
        var warnings: [String] = []
        var suitable = true

        if temp < 5 {
            warnings.append("Sıcaklık 5°C altında — beton donma riski! Antifriz katkı veya ısıtma gerekli.")
            suitable = false
        }
        if temp > 35 {
            warnings.append("Sıcaklık 35°C üstünde — hızlı kuruma riski! Kür önlemi alınmalı.")
        }
        if wind > 40 {
            warnings.append("Rüzgar 40 km/s üstünde — vinç çalışması tehlikeli!")
            suitable = false
        }
        if humidity > 90 {
            warnings.append("Nem %90 üstünde — yalıtım işleri ertelenmeli.")
        }
        if temp < 0 {
            warnings.append("Donma tehlikesi! Tüm beton işleri durdurulmalı.")
            suitable = false
        }

        return (suitable, warnings)
    }
}

// MARK: - WeatherService

class WeatherService {
    static let shared = WeatherService()
    private init() {}

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "openWeatherApiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openWeatherApiKey") }
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    func fetchWeather(latitude: Double, longitude: Double) async -> WeatherData? {
        guard isConfigured else { return nil }
        let urlStr = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric&lang=tr"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try parseWeatherResponse(data: data)
        } catch {
            return nil
        }
    }

    func fetchForecast(latitude: Double, longitude: Double, days: Int = 5) async -> [WeatherForecast]? {
        guard isConfigured else { return nil }
        let urlStr = "https://api.openweathermap.org/data/2.5/forecast?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric&lang=tr&cnt=\(days * 8)"
        guard let url = URL(string: urlStr) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try parseForecastResponse(data: data)
        } catch {
            return nil
        }
    }

    private func parseWeatherResponse(data: Data) throws -> WeatherData? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let main = json["main"] as? [String: Any],
              let wind = json["wind"] as? [String: Any],
              let weatherArr = json["weather"] as? [[String: Any]],
              let weatherObj = weatherArr.first else {
            return nil
        }
        let temp = main["temp"] as? Double ?? 0
        let humidity = main["humidity"] as? Double ?? 0
        let windSpeed = wind["speed"] as? Double ?? 0
        let desc = weatherObj["description"] as? String ?? ""
        let icon = mapIconCode(weatherObj["icon"] as? String ?? "")
        let precip = (json["rain"] as? [String: Any])?["1h"] as? Double
        let vis = json["visibility"] as? Double

        return WeatherData(
            temperature: temp,
            humidity: humidity,
            windSpeed: windSpeed,
            weatherDescription: desc,
            weatherIcon: icon,
            precipitation: precip,
            visibility: vis.map { $0 / 1000 }
        )
    }

    private func parseForecastResponse(data: Data) throws -> [WeatherForecast]? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["list"] as? [[String: Any]] else {
            return nil
        }
        // Group by day and take midday reading
        var dayMap: [String: WeatherForecast] = [:]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for item in list {
            guard let main = item["main"] as? [String: Any],
                  let wind = item["wind"] as? [String: Any],
                  let weatherArr = item["weather"] as? [[String: Any]],
                  let weatherObj = weatherArr.first,
                  let dtTxt = item["dt_txt"] as? String else { continue }

            let dateKey = String(dtTxt.prefix(10))
            if dayMap[dateKey] != nil { continue } // keep first entry per day

            let date = df.date(from: dateKey) ?? Date()
            let temp = main["temp"] as? Double ?? 0
            let humidity = main["humidity"] as? Double ?? 0
            let windSpeed = wind["speed"] as? Double ?? 0
            let desc = weatherObj["description"] as? String ?? ""
            let icon = mapIconCode(weatherObj["icon"] as? String ?? "")
            let precip = (item["rain"] as? [String: Any])?["3h"] as? Double

            dayMap[dateKey] = WeatherForecast(
                date: date,
                minTemp: temp,
                maxTemp: temp,
                humidity: humidity,
                windSpeed: windSpeed,
                weatherDescription: desc,
                weatherIcon: icon,
                precipitation: precip
            )
        }
        return Array(dayMap.values).sorted { $0.date < $1.date }
    }

    private func mapIconCode(_ code: String) -> String {
        switch code {
        case "01d", "01n": return "sun.max.fill"
        case "02d", "02n": return "cloud.sun.fill"
        case "03d", "03n", "04d", "04n": return "cloud.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d", "10n": return "cloud.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "cloud.snow.fill"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}
