import XCTest
import SwiftData

// MARK: - Module 2: Fiyat Takip Tests

final class Module2PriceTrackerTests: XCTestCase {

    // Test 1: Variance hesaplama
    func test_priceTracker_variancePercentage_positive() {
        let tracker = PriceTracker(materialName: "Çimento", unit: "ton", contractPrice: 1000, currentMarketPrice: 1200)
        XCTAssertEqual(tracker.variancePercentage, 20.0, accuracy: 0.01)
        XCTAssertEqual(tracker.varianceAmount, 200.0, accuracy: 0.01)
    }

    func test_priceTracker_variancePercentage_negative() {
        let tracker = PriceTracker(materialName: "Kum", unit: "m³", contractPrice: 500, currentMarketPrice: 450)
        XCTAssertEqual(tracker.variancePercentage, -10.0, accuracy: 0.01)
        XCTAssertEqual(tracker.varianceAmount, -50.0, accuracy: 0.01)
    }

    func test_priceTracker_variancePercentage_zeroContractPrice() {
        // Sıfıra bölme koruması
        let tracker = PriceTracker(materialName: "Test", unit: "adet", contractPrice: 0, currentMarketPrice: 100)
        XCTAssertEqual(tracker.variancePercentage, 0.0)
    }

    // Test 2: Alert threshold kontrolü
    func test_priceTracker_alertThreshold_defaultIs10Percent() {
        let tracker = PriceTracker(materialName: "Demir", unit: "ton", contractPrice: 1000)
        XCTAssertEqual(tracker.alertThreshold, 10.0)
    }

    func test_priceTracker_isOverThreshold_when20PercentAboveDefault() {
        let tracker = PriceTracker(materialName: "Beton", unit: "m³", contractPrice: 1000, currentMarketPrice: 1200)
        XCTAssertTrue(tracker.isOverThreshold)
    }

    func test_priceTracker_isNotOverThreshold_when5Percent() {
        let tracker = PriceTracker(materialName: "Kum", unit: "m³", contractPrice: 1000, currentMarketPrice: 1050)
        XCTAssertFalse(tracker.isOverThreshold)  // %5 < %10 eşik
    }

    func test_priceTracker_customThreshold() {
        let tracker = PriceTracker(materialName: "Ahşap", unit: "m³", contractPrice: 1000, currentMarketPrice: 1150)
        tracker.alertThreshold = 20.0
        XCTAssertFalse(tracker.isOverThreshold)  // %15 < %20
        tracker.alertThreshold = 10.0
        XCTAssertTrue(tracker.isOverThreshold)   // %15 > %10
    }

    // Test 3: Fiyat geçmişi JSON encode/decode
    func test_priceTracker_priceHistory_encodeDecode() {
        let tracker = PriceTracker(materialName: "Çelik", unit: "ton", contractPrice: 2000)
        tracker.addPricePoint(price: 2100)
        tracker.addPricePoint(price: 2200)
        tracker.addPricePoint(price: 2300)

        let history = tracker.priceHistory
        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history.last?.price, 2300)
        XCTAssertEqual(tracker.currentMarketPrice, 2300)
    }

    func test_priceTracker_priceHistory_maxSize() {
        let tracker = PriceTracker(materialName: "Test", unit: "kg", contractPrice: 100)
        for i in 1...30 {
            tracker.addPricePoint(price: Double(i) * 10)
        }
        XCTAssertLessThanOrEqual(tracker.priceHistory.count, 24, "Geçmiş 24 kayıtla sınırlanmalı")
    }

    func test_priceTracker_emptyHistoryDefault() {
        let tracker = PriceTracker(materialName: "Yeni", unit: "m", contractPrice: 500)
        XCTAssertTrue(tracker.priceHistory.isEmpty)
        XCTAssertEqual(tracker.priceHistoryJSON, "[]")
    }

    // Test 4: MarketPriceEntry
    func test_marketPriceEntry_initialization() {
        let entry = MarketPriceEntry(materialName: "Kireç", unitPrice: 250, unit: "ton")
        XCTAssertEqual(entry.materialName, "Kireç")
        XCTAssertEqual(entry.unitPrice, 250)
        XCTAssertEqual(entry.unit, "ton")
        XCTAssertNil(entry.supplierName)
    }

    // Test 5: BayindirlikFiyat change percentage
    func test_bayindirlikFiyat_changePercentage() {
        let fiyat = BayindirlikFiyat(pozNo: "01.001", pozName: "Hafriyat", unit: "m³",
                                     previousYearPrice: 100, currentYearPrice: 125, updateYear: 2026)
        XCTAssertEqual(fiyat.changePercentage, 25.0, accuracy: 0.01)
    }

    func test_bayindirlikFiyat_changePercentage_zeroBase() {
        let fiyat = BayindirlikFiyat(pozNo: "01.002", pozName: "Test", unit: "m",
                                     previousYearPrice: 0, currentYearPrice: 100, updateYear: 2026)
        XCTAssertEqual(fiyat.changePercentage, 0.0)
    }
}
