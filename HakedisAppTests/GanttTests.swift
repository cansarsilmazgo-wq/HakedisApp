import XCTest
import SwiftData

// MARK: - Gantt / İş Programı Testleri

final class GanttTests: XCTestCase {

    func test_projectActivity_olusturma() throws {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: start)!
        let activity = ProjectActivity(
            activityCode: "A-001",
            activityName: "Temel Kazısı",
            plannedStart: start,
            plannedEnd: end
        )
        XCTAssertEqual(activity.activityCode, "A-001")
        XCTAssertEqual(activity.activityName, "Temel Kazısı")
        XCTAssertEqual(activity.status, .notStarted)
        XCTAssertFalse(activity.isCritical)
        XCTAssertEqual(activity.progressPercent, 0)
    }

    func test_projectActivity_plannedDurationDays() throws {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 15, to: start)!
        let activity = ProjectActivity(activityCode: "A-002", activityName: "Kalıp İşleri",
                                       plannedStart: start, plannedEnd: end)
        XCTAssertEqual(activity.plannedDurationDays, 15)
    }

    func test_projectActivity_isDelayed_tamamlanmisDegilse() throws {
        let gecmisBaslangic = Date().addingTimeInterval(-86400 * 10)
        let gecmisBitis = Date().addingTimeInterval(-86400 * 2)
        let activity = ProjectActivity(activityCode: "A-003", activityName: "Gecikmiş",
                                       plannedStart: gecmisBaslangic, plannedEnd: gecmisBitis)
        activity.status = .inProgress
        XCTAssertTrue(activity.isDelayed, "Bitis tarihi geçmiş ve tamamlanmamış aktivite gecikmiş olmalı")
    }

    func test_projectActivity_isDelayed_false_tamamlandiysa() throws {
        let gecmis = Date().addingTimeInterval(-86400 * 5)
        let activity = ProjectActivity(activityCode: "A-004", activityName: "Tamamlandı",
                                       plannedStart: gecmis.addingTimeInterval(-86400 * 10), plannedEnd: gecmis)
        activity.status = .completed
        XCTAssertFalse(activity.isDelayed, "Tamamlanmış aktivite gecikmiş sayılmamalı")
    }
}
