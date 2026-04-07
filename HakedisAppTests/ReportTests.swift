import XCTest
import SwiftData

// MARK: - Rapor Testleri

final class ReportTests: XCTestCase {

    func test_progressReport_olusturma() throws {
        let report = ProgressReport(reportPeriod: "Ocak 2026", completionPercentage: 35.0,
                                    summaryText: "Temel çalışmaları tamamlandı")
        XCTAssertEqual(report.reportPeriod, "Ocak 2026")
        XCTAssertEqual(report.completionPercentage, 35.0, accuracy: 0.001)
        XCTAssertEqual(report.summaryText, "Temel çalışmaları tamamlandı")
        XCTAssertTrue(report.beforePhotoData.isEmpty)
    }

    func test_progressReport_tamamlanmaYuzdesiSiniri() throws {
        let report = ProgressReport(reportPeriod: "Şubat 2026", completionPercentage: 100.0)
        XCTAssertEqual(report.completionPercentage, 100.0, accuracy: 0.001)
    }

    func test_progressReport_fotografEkleme() throws {
        let report = ProgressReport(reportPeriod: "Mart 2026", completionPercentage: 60.0)
        report.beforePhotoData = [Data([0xAA, 0xBB])]
        report.afterPhotoData = [Data([0xCC, 0xDD])]
        XCTAssertEqual(report.beforePhotoData.count, 1)
        XCTAssertEqual(report.afterPhotoData.count, 1)
    }
}
