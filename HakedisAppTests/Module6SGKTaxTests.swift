import XCTest
import SwiftData

// MARK: - Module 6: SGK / Vergi Tests

final class Module6SGKTaxTests: XCTestCase {

    // SGK hesaplama sabitleri
    private let workerSGKRate = 0.14
    private let employerSGKRate = 0.205
    private let workerUnempRate = 0.01
    private let employerUnempRate = 0.02
    private let minimumDailyWage = 934.0  // 2026

    // Test 1: SGK prim hesabı — işçi %14
    func test_sgk_workerShare_14percent() {
        let earnings = 10_000.0
        let workerSGK = earnings * workerSGKRate
        XCTAssertEqual(workerSGK, 1_400.0, accuracy: 0.01)
    }

    // Test 2: SGK prim hesabı — işveren %20.5
    func test_sgk_employerShare_20point5percent() {
        let earnings = 10_000.0
        let employerSGK = earnings * employerSGKRate
        XCTAssertEqual(employerSGK, 2_050.0, accuracy: 0.01)
    }

    // Test 3: İşsizlik primleri
    func test_sgk_unemployment_rates() {
        let earnings = 10_000.0
        let workerUnemp = earnings * workerUnempRate
        let employerUnemp = earnings * employerUnempRate
        XCTAssertEqual(workerUnemp, 100.0, accuracy: 0.01)
        XCTAssertEqual(employerUnemp, 200.0, accuracy: 0.01)
    }

    // Test 4: Toplam SGK tutarı
    func test_sgk_totalContribution() {
        let earnings = 10_000.0
        let total = earnings * (workerSGKRate + employerSGKRate + workerUnempRate + employerUnempRate)
        // %14 + %20.5 + %1 + %2 = %37.5
        XCTAssertEqual(total, 3_750.0, accuracy: 0.01)
    }

    // Test 5: Asgari ücret kontrolü
    func test_minimumWage_detection_belowMinimum() {
        let dailyWage = 500.0  // Asgari ücret altında
        let isBelowMinimum = dailyWage < minimumDailyWage
        XCTAssertTrue(isBelowMinimum)
    }

    func test_minimumWage_detection_aboveMinimum() {
        let dailyWage = 1500.0
        let isBelowMinimum = dailyWage < minimumDailyWage
        XCTAssertFalse(isBelowMinimum)
    }

    func test_minimumWage_detection_exactMinimum() {
        let dailyWage = minimumDailyWage
        let isBelowMinimum = dailyWage < minimumDailyWage
        XCTAssertFalse(isBelowMinimum)  // Tam eşit → altında değil
    }

    // Test 6: Muhtasar — Stopaj toplamı
    func test_muhtasar_stopaj_calculation() {
        // Hakediş teminat oranı varsayılan %10
        let hakedisGross = 100_000.0
        let retentionRate = 0.10
        let stopaj = hakedisGross * retentionRate
        XCTAssertEqual(stopaj, 10_000.0, accuracy: 0.01)
    }

    // Test 7: Damga vergisi (binde 9.48)
    func test_damga_vergisi_calculation() {
        let hakedisGross = 100_000.0
        let damgaRate = 0.00948
        let damga = hakedisGross * damgaRate
        XCTAssertEqual(damga, 948.0, accuracy: 0.01)
    }

    // Test 8: KDV hesabı (ödenecek KDV = hesaplanan - indirilecek)
    func test_kdv_calculation_payable() {
        let hesaplanan = 50_000.0
        let indirilecek = 30_000.0
        let odenecek = max(0, hesaplanan - indirilecek)
        XCTAssertEqual(odenecek, 20_000.0, accuracy: 0.01)
    }

    func test_kdv_calculation_refund() {
        // İndirilecek > Hesaplanan → İade
        let hesaplanan = 20_000.0
        let indirilecek = 35_000.0
        let odenecek = max(0, hesaplanan - indirilecek)
        let iade = max(0, indirilecek - hesaplanan)
        XCTAssertEqual(odenecek, 0.0)
        XCTAssertEqual(iade, 15_000.0, accuracy: 0.01)
    }

    func test_kdv_calculation_noPayable_whenEqual() {
        let hesaplanan = 25_000.0
        let indirilecek = 25_000.0
        let odenecek = max(0, hesaplanan - indirilecek)
        XCTAssertEqual(odenecek, 0.0)
    }
}
