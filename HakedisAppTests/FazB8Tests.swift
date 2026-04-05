import XCTest
import Foundation

// MARK: - B8 Geçici/Kesin Kabul Tests

final class ProvisionalAcceptanceModelTests: XCTestCase {

    func test_acceptance_noOlusturma() {
        let no = ProvisionalAcceptance.generateNo(existingCount: 0, year: 2026)
        XCTAssertEqual(no, "GKB-2026/001")
    }

    func test_acceptance_varsayilanDegerler() {
        let acc = ProvisionalAcceptance(acceptanceNo: "GKB-2026/001", contractNo: "SZ-001",
                                        contractorName: "ABC İnşaat",
                                        scheduledDate: Date().addingTimeInterval(30 * 86400))
        XCTAssertEqual(acc.status, .pending)
        XCTAssertEqual(acc.warrantyPeriodMonths, 12)
        XCTAssertTrue(acc.deficiencies.isEmpty)
        XCTAssertEqual(acc.openDeficiencyCount, 0)
        XCTAssertFalse(acc.isWarrantyExpired)
    }

    func test_acceptance_garantiSonuYaklasiyor() {
        let acc = ProvisionalAcceptance(acceptanceNo: "GKB-2026/002", contractNo: "SZ-002",
                                        contractorName: "XYZ Yapı",
                                        scheduledDate: Date())
        acc.warrantyEndDate = Calendar.current.date(byAdding: .day, value: 15, to: Date())!
        XCTAssertTrue(acc.isWarrantyExpiring)
        XCTAssertFalse(acc.isWarrantyExpired)
    }

    func test_acceptance_garantiBitti() {
        let acc = ProvisionalAcceptance(acceptanceNo: "GKB-2026/003", contractNo: "SZ-003",
                                        contractorName: "Test",
                                        scheduledDate: Date())
        acc.warrantyEndDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        XCTAssertTrue(acc.isWarrantyExpired)
    }

    func test_acceptance_openDeficiencyCount() {
        let acc = ProvisionalAcceptance(acceptanceNo: "GKB-2026/004", contractNo: "SZ-004",
                                        contractorName: "Test",
                                        scheduledDate: Date())
        let d1 = AcceptanceDeficiency(deficiencyNo: 1, deficiencyText: "Boya eksik", location: "1. Kat")
        d1.status = .open
        let d2 = AcceptanceDeficiency(deficiencyNo: 2, deficiencyText: "Karo kırık", location: "2. Kat")
        d2.status = .resolved
        acc.deficiencies = [d1, d2]
        XCTAssertEqual(acc.openDeficiencyCount, 1)
    }
}

final class FinalAcceptanceModelTests: XCTestCase {

    func test_finalAcceptance_noOlusturma() {
        let no = FinalAcceptance.generateNo(existingCount: 2, year: 2026)
        XCTAssertEqual(no, "KKB-2026/003")
    }

    func test_finalAcceptance_commissionJson() {
        let fa = FinalAcceptance(acceptanceNo: "KKB-2026/001", contractNo: "SZ-001",
                                 contractorName: "ABC", scheduledDate: Date())
        let member = CommissionMember(name: "Mehmet Demir", title: "Mühendis",
                                       affiliation: "İdare", isSigned: false)
        fa.commissionMembers = [member]
        let decoded = fa.commissionMembers
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].name, "Mehmet Demir")
        XCTAssertFalse(decoded[0].isSigned)
    }
}

final class AcceptanceDeficiencyModelTests: XCTestCase {

    func test_deficiency_gecikme() {
        let def = AcceptanceDeficiency(deficiencyNo: 1, deficiencyText: "Test", location: "Kat 1")
        def.deadline = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        def.status = .open
        XCTAssertTrue(def.isOverdue)
    }

    func test_deficiency_giderildi_gecikmiyor() {
        let def = AcceptanceDeficiency(deficiencyNo: 2, deficiencyText: "Test", location: "Kat 2")
        def.deadline = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        def.status = .resolved
        XCTAssertFalse(def.isOverdue)
    }
}
