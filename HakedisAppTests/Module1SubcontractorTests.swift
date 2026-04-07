import XCTest
import SwiftData

// MARK: - Module 1: Taşeron Portal Tests

final class Module1SubcontractorTests: XCTestCase {

    // Test 1: SubcontractorDispute CRUD
    func test_dispute_initializesWithOpenStatus() {
        let dispute = SubcontractorDispute(subject: "Test İtiraz", details: "Detay", disputeType: .hakedisAmount)
        XCTAssertEqual(dispute.status, .open)
        XCTAssertEqual(dispute.disputeType, .hakedisAmount)
        XCTAssertEqual(dispute.subject, "Test İtiraz")
        XCTAssertTrue(dispute.isOpen)
        XCTAssertFalse(dispute.isResolved)
    }

    func test_dispute_statusTransition_toResolved() {
        let dispute = SubcontractorDispute(subject: "İtiraz", details: "Detay")
        XCTAssertEqual(dispute.status, .open)
        dispute.status = .underReview
        XCTAssertEqual(dispute.status, .underReview)
        XCTAssertFalse(dispute.isResolved)
        dispute.status = .resolved
        XCTAssertEqual(dispute.status, .resolved)
        XCTAssertTrue(dispute.isResolved)
    }

    func test_dispute_statusTransition_toRejected() {
        let dispute = SubcontractorDispute(subject: "İtiraz", details: "Detay")
        dispute.status = .rejected
        XCTAssertTrue(dispute.isResolved)
        XCTAssertFalse(dispute.isOpen)
    }

    // Test 2: SubcontractorWorkOrder tamamlama akışı
    func test_workOrder_initializesAsPending() {
        let order = SubcontractorWorkOrder(orderTitle: "Kalıp İşi", orderDescription: "1. kat kalıpları", priority: .high)
        XCTAssertEqual(order.completionStatus, .pending)
        XCTAssertEqual(order.priority, .high)
        XCTAssertFalse(order.isCompleted)
    }

    func test_workOrder_completionFlow() {
        let order = SubcontractorWorkOrder(orderTitle: "Demir Döşeme")
        order.completionStatus = .completed
        order.completionDate = Date()
        order.completionNotes = "Tamamlandı"
        XCTAssertTrue(order.isCompleted)
        XCTAssertNotNil(order.completionDate)
        XCTAssertEqual(order.completionNotes, "Tamamlandı")
    }

    func test_workOrder_overdueDetection() {
        let order = SubcontractorWorkOrder(orderTitle: "Gecikmiş İş")
        order.dueDate = Date().addingTimeInterval(-86400)  // Dün
        XCTAssertTrue(order.isOverdue)
        order.completionStatus = .completed
        XCTAssertFalse(order.isOverdue)  // Tamamlanmışsa gecikmiş sayılmaz
    }

    // Test 3: Malzeme talep
    func test_materialRequest_initializesWithPendingStatus() {
        let req = SubcontractorMaterialRequest(materialName: "Çimento", quantity: 50, unit: "ton", justification: "Bodrum kat beton")
        XCTAssertEqual(req.status, .pending)
        XCTAssertEqual(req.materialName, "Çimento")
        XCTAssertEqual(req.quantity, 50)
        XCTAssertEqual(req.unit, "ton")
    }

    func test_materialRequest_statusTransitions() {
        let req = SubcontractorMaterialRequest(materialName: "Demir", quantity: 10, unit: "ton")
        req.status = .approved
        XCTAssertEqual(req.status, .approved)
        req.status = .delivered
        XCTAssertEqual(req.status, .delivered)
    }

    // Test 4: Ek iş bildirimi
    func test_additionalWork_initialization() {
        let work = SubcontractorAdditionalWork(workTitle: "Ek Yalıtım", workDescription: "Planlarda olmayan ıslak zemin yalıtımı")
        XCTAssertEqual(work.workTitle, "Ek Yalıtım")
        XCTAssertNil(work.estimatedAmount)
        XCTAssertEqual(work.status, .pending)
    }

    func test_additionalWork_withEstimatedAmount() {
        let work = SubcontractorAdditionalWork(workTitle: "Ek Kaplama", workDescription: "Mermer")
        work.estimatedAmount = 150_000
        XCTAssertEqual(work.estimatedAmount, 150_000)
    }

    // Test 5: DisputeType rawValues
    func test_disputeType_allCasesHaveRawValues() {
        for disputeType in DisputeType.allCases {
            XCTAssertFalse(disputeType.rawValue.isEmpty, "\(disputeType) rawValue boş olmamalı")
        }
    }

    // Test 6: DisputeStatus icons
    func test_disputeStatus_iconsAreNotEmpty() {
        for status in DisputeStatus.allCases {
            XCTAssertFalse(status.icon.isEmpty, "\(status) icon boş olmamalı")
        }
    }
}
