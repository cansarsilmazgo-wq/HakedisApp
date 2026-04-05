import XCTest
import Foundation

// MARK: - A8 Yazışma Tests

final class CorrespondenceModelTests: XCTestCase {

    func test_correspondence_otomatikSayi() {
        let no = Correspondence.generateNo(existingCount: 0, year: 2026)
        XCTAssertEqual(no, "2026/001")
    }

    func test_correspondence_siralama() {
        let no5 = Correspondence.generateNo(existingCount: 4, year: 2026)
        XCTAssertEqual(no5, "2026/005")
    }

    func test_correspondence_varsayilanDegerler() {
        let c = Correspondence(correspondenceNo: "2026/001", direction: .gelen,
                               subject: "Test Konu", senderOrRecipient: "İdare")
        XCTAssertEqual(c.direction, .gelen)
        XCTAssertEqual(c.category, .general)
        XCTAssertFalse(c.isResponded)
        XCTAssertNil(c.responseDeadline)
        XCTAssertFalse(c.isOverdue)
        XCTAssertFalse(c.isDueSoon)
    }

    func test_correspondence_gecikmisDurum() {
        let c = Correspondence(correspondenceNo: "2026/002", direction: .gelen,
                               subject: "Gecikmiş Yazı", senderOrRecipient: "İdare")
        c.responseDeadline = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        c.isResponded = false
        XCTAssertTrue(c.isOverdue)
    }

    func test_correspondence_cevaplandiysa_gecikmez() {
        let c = Correspondence(correspondenceNo: "2026/003", direction: .gelen,
                               subject: "Cevaplanan Yazı", senderOrRecipient: "İdare")
        c.responseDeadline = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        c.isResponded = true
        XCTAssertFalse(c.isOverdue)
    }
}

final class LetterCategoryTests: XCTestCase {

    func test_letterCategory_tumCaselerVar() {
        XCTAssertEqual(LetterCategory.allCases.count, 13)
    }

    func test_letterCategory_ikonlar() {
        for cat in LetterCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty, "\(cat.rawValue) ikonu boş olmamalı")
        }
    }
}

final class ContractMilestoneTests: XCTestCase {

    func test_milestone_varsayilanDurum() {
        let ms = ContractMilestone(milestoneName: "Kaba İnşaat", plannedDate: Date())
        XCTAssertEqual(ms.status, .notStarted)
        XCTAssertNil(ms.actualDate)
    }

    func test_milestone_gecikmeTespiti() {
        let ms = ContractMilestone(milestoneName: "Çatı",
                                   plannedDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)
        ms.status = .inProgress
        XCTAssertTrue(ms.isOverdue)
    }

    func test_milestone_tamamlananGecikmiyor() {
        let ms = ContractMilestone(milestoneName: "Teslim",
                                   plannedDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!)
        ms.status = .completed
        ms.actualDate = Date()
        XCTAssertFalse(ms.isOverdue)
    }
}

final class OfficialNotificationTests: XCTestCase {

    func test_notification_kayit() {
        let n = OfficialNotification(subject: "Gecikme Cezası Tebliği",
                                      givenBy: "İdare Yetkilisi",
                                      receivedBy: "Yüklenici Vekili",
                                      notificationType: .notification)
        XCTAssertEqual(n.notificationType, .notification)
        XCTAssertEqual(n.subject, "Gecikme Cezası Tebliği")
        XCTAssertEqual(n.givenBy, "İdare Yetkilisi")
        XCTAssertNil(n.witnessName)
    }
}
