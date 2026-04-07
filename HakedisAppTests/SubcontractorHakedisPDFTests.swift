import XCTest
import SwiftData

// MARK: - Taşeron Hakediş Testleri

final class SubcontractorHakedisPDFTests: XCTestCase {

    func test_subHakedis_olusturma() throws {
        let hakedis = SubcontractorHakedis(
            periodName: "Ocak 2026",
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 30)
        )
        XCTAssertEqual(hakedis.periodName, "Ocak 2026")
        XCTAssertEqual(hakedis.status, .draft)
        XCTAssertEqual(hakedis.grossAmount, 0)
    }

    func test_subHakedis_netHesap() throws {
        let hakedis = SubcontractorHakedis(
            periodName: "Şubat 2026",
            periodStart: Date(),
            periodEnd: Date()
        )
        hakedis.grossAmount = 100_000
        hakedis.retentionAmount = 5_000
        hakedis.netAmount = hakedis.grossAmount - hakedis.retentionAmount
        XCTAssertEqual(hakedis.netAmount, 95_000, accuracy: 0.01)
    }

    func test_subHakedis_statusTransition() throws {
        let hakedis = SubcontractorHakedis(
            periodName: "Mart 2026",
            periodStart: Date(),
            periodEnd: Date()
        )
        XCTAssertEqual(hakedis.status, .draft)
        hakedis.status = .approved
        XCTAssertEqual(hakedis.status, .approved)
        hakedis.status = .paid
        XCTAssertEqual(hakedis.status, .paid)
    }
}
