import XCTest
import Foundation

// MARK: - B4 İş Programı Gantt Tests

final class ProjectActivityModelTests: XCTestCase {

    func test_activity_varsayilanDegerler() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 10, to: start)!
        let act = ProjectActivity(activityCode: "A1", activityName: "Temel", plannedStart: start, plannedEnd: end)
        XCTAssertEqual(act.status, .notStarted)
        XCTAssertEqual(act.progressPercent, 0)
        XCTAssertFalse(act.isCritical)
        XCTAssertEqual(act.wbsLevel, 1)
    }

    func test_activity_plannedDuration() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 14, to: start)!
        let act = ProjectActivity(activityCode: "B1", activityName: "Kaba İnşaat",
                                   plannedStart: start, plannedEnd: end)
        XCTAssertEqual(act.plannedDurationDays, 14)
    }

    func test_activity_gecikmeDetection_tamamlananGecikmiyor() {
        let start = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        let end = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let act = ProjectActivity(activityCode: "C1", activityName: "Bitti", plannedStart: start, plannedEnd: end)
        act.status = .completed
        XCTAssertFalse(act.isDelayed)
    }

    func test_activity_gecikme_bitisTarihi_Gecmis() {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let end = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let act = ProjectActivity(activityCode: "D1", activityName: "Gecikmiş", plannedStart: start, plannedEnd: end)
        act.status = .inProgress
        XCTAssertTrue(act.isDelayed)
    }

    func test_activity_scheduleVariance() {
        let plannedStart = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let plannedEnd = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let act = ProjectActivity(activityCode: "E1", activityName: "Test", plannedStart: plannedStart, plannedEnd: plannedEnd)
        act.actualStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        XCTAssertEqual(act.scheduleVarianceDays, 3)
    }
}

final class ActivityDependencyTests: XCTestCase {

    func test_dependency_jsonEncodeDecode() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 10, to: start)!
        let act = ProjectActivity(activityCode: "F1", activityName: "Temel", plannedStart: start, plannedEnd: end)
        let dep = ActivityDependency(predecessorId: UUID(), dependencyTypeRaw: DependencyType.finishToStart.rawValue, lagDays: 2)
        act.dependencies = [dep]
        let decoded = act.dependencies
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].dependencyType, .finishToStart)
        XCTAssertEqual(decoded[0].lagDays, 2)
    }
}
