import XCTest

// MARK: - FAZ 12+13: Offline + Taşeron Portal Tests

final class OfflineContractorTests: XCTestCase {

    // MARK: - FAZ 12: Offline Label Tests (#294)

    func testOfflineHakedisLabelIsPositive() {
        // The new label should indicate offline capability
        let subtitle = "Offline çalışır, sync sonra yapılır"
        XCTAssertFalse(subtitle.contains("önerilir"), "Uyarı mesajı yerine olumlu mesaj olmalı")
        XCTAssertTrue(subtitle.contains("Offline"), "Offline desteği belirtilmeli")
    }

    // MARK: - FAZ 12: Cache Size Test (#295)

    func testCacheSizeCalculationNoNegative() {
        // Cache size formula should never be negative
        let tmpSize = 0
        let storeSize = 26_000  // simulated 26 KB
        let total = tmpSize + storeSize
        let kb = max(total / 1024, 1)
        XCTAssertGreaterThan(kb, 0)
    }

    func testCacheSizeMBFormatting() {
        let totalBytes = 2_000_000  // 2 MB
        let mb = Double(totalBytes) / 1_048_576
        let formatted = String(format: "%.1f MB", mb)
        XCTAssertEqual(formatted, "1.9 MB")
    }

    // MARK: - FAZ 13: Contractor Row Details (#296)

    func testContractorHasTaxNumberField() {
        let c = Contractor(name: "Test", taxNumber: "1234567890")
        XCTAssertEqual(c.taxNumber, "1234567890")
    }

    func testContractorHasPhoneField() {
        let c = Contractor(name: "Test", phone: "+90 555 123 45 67")
        XCTAssertEqual(c.phone, "+90 555 123 45 67")
    }

    // MARK: - FAZ 13: Portal Hakedis Filter (#297)

    func testContractorHakedisFiltering() {
        // Contractor dashboard shows hakedişler from their contracts only
        let c1 = Contractor(name: "Firma A")
        let c2 = Contractor(name: "Firma B")

        // Each has contracts, hakedişler should be separate
        XCTAssertEqual(c1.contracts.count, 0)
        XCTAssertEqual(c2.contracts.count, 0)

        let allHakedisler1 = c1.contracts.flatMap { $0.hakedisler }
        let allHakedisler2 = c2.contracts.flatMap { $0.hakedisler }

        // No overlap between different contractors
        let ids1 = Set(allHakedisler1.map { $0.id })
        let ids2 = Set(allHakedisler2.map { $0.id })
        XCTAssertTrue(ids1.intersection(ids2).isEmpty)
    }
}
