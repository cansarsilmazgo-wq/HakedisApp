import XCTest
import Foundation

// MARK: - S-Eğrisi Testleri

final class SCurveTests: XCTestCase {

    func test_scurveDataPoint_identifiable() throws {
        let pt = SCurveDataPoint(date: Date(), plannedCumulative: 50, actualCumulative: 45)
        XCTAssertNotNil(pt.id)
        XCTAssertEqual(pt.plannedCumulative, 50, accuracy: 0.01)
        XCTAssertEqual(pt.actualCumulative, 45, accuracy: 0.01)
    }

    func test_scurveCalculator_emptyActivities() throws {
        let points = SCurveDataCalculator.calculateWeeklyData(
            activities: [],
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30)
        )
        XCTAssertTrue(points.isEmpty)
    }

    func test_scurveCalculator_singleActivity() throws {
        let start = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let end   = Calendar.current.date(byAdding: .month, value:  1, to: Date())!

        let activity = ProjectActivity(
            activityCode: "A1",
            activityName: "Test Aktivite",
            plannedStart: start,
            plannedEnd: end
        )
        activity.progressPercent = 60

        let points = SCurveDataCalculator.calculateWeeklyData(
            activities: [activity],
            startDate: start,
            endDate: end
        )
        XCTAssertFalse(points.isEmpty)

        // İlk nokta planlanan 0'dan büyük olmalı
        XCTAssertGreaterThan(points.first?.plannedCumulative ?? 0, 0)
        // Son nokta planlanan yaklaşık 100
        XCTAssertGreaterThan(points.last?.plannedCumulative ?? 0, 90)
    }
}
