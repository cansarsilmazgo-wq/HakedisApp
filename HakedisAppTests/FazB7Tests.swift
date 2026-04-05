import XCTest
import Foundation

// MARK: - B7 Saha İletişim Tests

final class WorkOrderModelTests: XCTestCase {

    func test_workOrder_noOlusturma() {
        let no = WorkOrder.generateNo(existingCount: 0, year: 2026)
        XCTAssertEqual(no, "IO-2026/001")
    }

    func test_workOrder_varsayilanDegerler() {
        let wo = WorkOrder(orderNo: "IO-2026/001", orderTitle: "Test Onarım",
                           type: .repair, issuedBy: "Mühendis")
        XCTAssertEqual(wo.status, .open)
        XCTAssertEqual(wo.orderType, .repair)
        XCTAssertFalse(wo.isOverdue)
    }

    func test_workOrder_gecikme() {
        let wo = WorkOrder(orderNo: "IO-2026/002", orderTitle: "Gecikmiş",
                           type: .maintenance, issuedBy: "Müdür")
        wo.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        XCTAssertTrue(wo.isOverdue)
    }
}

final class RFIModelTests: XCTestCase {

    func test_rfi_noOlusturma() {
        let no = RFI.generateNo(existingCount: 4, year: 2026)
        XCTAssertEqual(no, "RFI-2026/005")
    }

    func test_rfi_varsayilanDegerler() {
        let rfi = RFI(rfiNo: "RFI-2026/001", subject: "Temel Detayı",
                      question: "Hangi çap?", askedBy: "Ustabası")
        XCTAssertEqual(rfi.status, .open)
        XCTAssertFalse(rfi.isOverdue)
    }

    func test_rfi_gecikme_yanıt() {
        let rfi = RFI(rfiNo: "RFI-2026/002", subject: "Test", question: "?", askedBy: "Test")
        rfi.responseDeadline = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        rfi.status = .pending
        XCTAssertTrue(rfi.isOverdue)
    }
}

final class SiteAnnouncementModelTests: XCTestCase {

    func test_announcement_varsayilanDegerler() {
        let ann = SiteAnnouncement(announcementTitle: "Toplantı", content: "Bugün saat 14:00",
                                    type: .general, postedBy: "Müdür")
        XCTAssertTrue(ann.isActive)
        XCTAssertFalse(ann.isExpired)
        XCTAssertTrue(ann.isVisible)
    }

    func test_announcement_surelSoldu() {
        let ann = SiteAnnouncement(announcementTitle: "Eski", content: "...",
                                    type: .schedule, postedBy: "Müdür")
        ann.expiresAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(ann.isExpired)
        XCTAssertFalse(ann.isVisible)
    }
}
