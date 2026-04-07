import XCTest
import SwiftData

// MARK: - Module 3: Hava Durumu Tests

final class Module3WeatherTests: XCTestCase {

    // Test 1: ConcretePouring suitability hesabı
    func test_concretePouring_suitableConditions() {
        let result = ConcretePouring.isSuitable(temp: 20, humidity: 60, wind: 20)
        XCTAssertTrue(result.suitable)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func test_concretePouring_belowMinTemp() {
        let result = ConcretePouring.isSuitable(temp: 3, humidity: 60, wind: 20)
        XCTAssertFalse(result.suitable)
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(result.warnings.first?.contains("donma") ?? false)
    }

    func test_concretePouring_aboveMaxTemp() {
        let result = ConcretePouring.isSuitable(temp: 38, humidity: 50, wind: 15)
        XCTAssertTrue(result.suitable)  // Yüksek sıcaklık uygunsuz değil, sadece uyarı
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(result.warnings.first?.contains("kuruma") ?? false)
    }

    func test_concretePouring_highWind() {
        let result = ConcretePouring.isSuitable(temp: 20, humidity: 60, wind: 45)
        XCTAssertFalse(result.suitable)
        XCTAssertTrue(result.warnings.contains { $0.contains("vinç") })
    }

    func test_concretePouring_highHumidity() {
        let result = ConcretePouring.isSuitable(temp: 20, humidity: 95, wind: 15)
        XCTAssertTrue(result.suitable)
        XCTAssertTrue(result.warnings.contains { $0.contains("yalıtım") })
    }

    func test_concretePouring_freezingTemperature() {
        let result = ConcretePouring.isSuitable(temp: -5, humidity: 60, wind: 10)
        XCTAssertFalse(result.suitable)
        // Should have both below-5 warning and freezing warning
        XCTAssertGreaterThanOrEqual(result.warnings.count, 2)
    }

    // Test 2: WeatherCondition icon mapping
    func test_weatherCondition_iconMapping() {
        XCTAssertEqual(WeatherCondition.sunny.icon, "sun.max.fill")
        XCTAssertEqual(WeatherCondition.partlyCloudy.icon, "cloud.sun.fill")
        XCTAssertEqual(WeatherCondition.cloudy.icon, "cloud.fill")
        XCTAssertEqual(WeatherCondition.rainy.icon, "cloud.rain.fill")
        XCTAssertEqual(WeatherCondition.heavyRain.icon, "cloud.heavyrain.fill")
        XCTAssertEqual(WeatherCondition.snowy.icon, "cloud.snow.fill")
        XCTAssertEqual(WeatherCondition.stormy.icon, "cloud.bolt.fill")
        XCTAssertEqual(WeatherCondition.foggy.icon, "cloud.fog.fill")
        XCTAssertEqual(WeatherCondition.windy.icon, "wind")
    }

    func test_weatherCondition_workSuitability() {
        XCTAssertTrue(WeatherCondition.sunny.isWorkSuitable)
        XCTAssertTrue(WeatherCondition.partlyCloudy.isWorkSuitable)
        XCTAssertTrue(WeatherCondition.cloudy.isWorkSuitable)
        XCTAssertTrue(WeatherCondition.rainy.isWorkSuitable)
        XCTAssertFalse(WeatherCondition.heavyRain.isWorkSuitable)
        XCTAssertFalse(WeatherCondition.snowy.isWorkSuitable)
        XCTAssertFalse(WeatherCondition.stormy.isWorkSuitable)
    }

    // Test 3: WeatherRecord CRUD
    func test_weatherRecord_initialization() {
        let record = WeatherRecord(recordDate: Date(), condition: .sunny)
        XCTAssertEqual(record.weatherCondition, .sunny)
        XCTAssertTrue(record.isWorkSuitable)
        XCTAssertFalse(record.fetchedFromAPI)
    }

    func test_weatherRecord_averageTemp() {
        let record = WeatherRecord(recordDate: Date())
        record.morningTemp = 15
        record.afternoonTemp = 25
        record.eveningTemp = 20
        XCTAssertEqual(record.averageTemp ?? 0, 20.0, accuracy: 0.01)
    }

    func test_weatherRecord_averageTemp_nilWhenNoData() {
        let record = WeatherRecord(recordDate: Date())
        XCTAssertNil(record.averageTemp)
    }

    func test_weatherRecord_singleTemp() {
        let record = WeatherRecord(recordDate: Date())
        record.afternoonTemp = 22
        XCTAssertEqual(record.averageTemp ?? 0, 22.0, accuracy: 0.01)
    }

    // Test 4: WeatherService singleton
    func test_weatherService_isSingleton() {
        let s1 = WeatherService.shared
        let s2 = WeatherService.shared
        XCTAssertTrue(s1 === s2)
    }

    func test_weatherService_isConfigured_whenEmpty() {
        let ws = WeatherService.shared
        let originalKey = ws.apiKey
        ws.apiKey = ""
        XCTAssertFalse(ws.isConfigured)
        ws.apiKey = originalKey  // restore
    }

    func test_weatherService_isConfigured_whenKeySet() {
        let ws = WeatherService.shared
        let originalKey = ws.apiKey
        ws.apiKey = "test123"
        XCTAssertTrue(ws.isConfigured)
        ws.apiKey = originalKey  // restore
    }
}
