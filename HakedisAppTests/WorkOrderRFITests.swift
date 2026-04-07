import XCTest
import SwiftData

// MARK: - İş Emri & RFI Testleri

final class WorkOrderRFITests: XCTestCase {

    func test_workOrder_olusturma() throws {
        let order = WorkOrder(orderNo: "IO-2026/001", orderTitle: "Boya Tadilat",
                              type: .repair, issuedBy: "Şantiye Şefi")
        XCTAssertEqual(order.status, .open)
        XCTAssertEqual(order.orderType, .repair)
        XCTAssertFalse(order.isOverdue)
    }

    func test_workOrder_isOverdue() throws {
        let order = WorkOrder(orderNo: "IO-2026/002", orderTitle: "Gecikmeli",
                              type: .maintenance, issuedBy: "Mühendis")
        order.dueDate = Date().addingTimeInterval(-86400)
        XCTAssertTrue(order.isOverdue)
    }

    func test_workOrder_generateNo() throws {
        let no = WorkOrder.generateNo(existingCount: 0, year: 2026)
        XCTAssertEqual(no, "IO-2026/001")
    }

    func test_rfi_olusturmaVeDurumu() throws {
        let rfi = RFI(rfiNo: "RFI-2026/001", subject: "Temel Derinliği",
                      question: "Temel derinliği 1.5m mi olmalı?", askedBy: "İnşaat Müh.")
        XCTAssertEqual(rfi.status, .open)
        XCTAssertFalse(rfi.isOverdue)
        XCTAssertTrue(rfi.answer.isEmpty)
    }
}
