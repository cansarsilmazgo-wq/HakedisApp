import XCTest
import SwiftData

// MARK: - Module 5: Kentsel Dönüşüm Tests

final class Module5UrbanRenewalTests: XCTestCase {

    // Test 1: Anlaşma oranı hesabı
    func test_urbanRenewalProject_agreementRate_allAgreed() {
        let project = UrbanRenewalProject(projectName: "Test Proje", address: "Test Adres",
                                          district: "Kadıköy", city: "İstanbul")
        let s1 = Stakeholder(fullName: "Ali Kaya"); s1.isAgreed = true
        let s2 = Stakeholder(fullName: "Veli Demir"); s2.isAgreed = true
        let s3 = Stakeholder(fullName: "Ayşe Yıldız"); s3.isAgreed = true
        project.stakeholders = [s1, s2, s3]

        XCTAssertEqual(project.agreedStakeholderCount, 3)
        XCTAssertEqual(project.agreementRate, 100.0, accuracy: 0.01)
    }

    func test_urbanRenewalProject_agreementRate_partialAgreement() {
        let project = UrbanRenewalProject(projectName: "Test", address: "", district: "Üsküdar", city: "İstanbul")
        let s1 = Stakeholder(fullName: "A"); s1.isAgreed = true
        let s2 = Stakeholder(fullName: "B"); s2.isAgreed = true
        let s3 = Stakeholder(fullName: "C"); s3.isAgreed = false
        let s4 = Stakeholder(fullName: "D"); s4.isAgreed = false
        project.stakeholders = [s1, s2, s3, s4]

        XCTAssertEqual(project.agreedStakeholderCount, 2)
        XCTAssertEqual(project.agreementRate, 50.0, accuracy: 0.01)
    }

    func test_urbanRenewalProject_agreementRate_noStakeholders() {
        let project = UrbanRenewalProject(projectName: "Boş", address: "", district: "Bağcılar", city: "İstanbul")
        XCTAssertEqual(project.agreementRate, 0.0)
    }

    // Test 2: Daire dağılım (hak sahibi + müteahhit toplamı)
    func test_unitDistribution_allocationTargets() {
        let project = UrbanRenewalProject(projectName: "Proje", address: "", district: "D", city: "C")
        let u1 = UnitDistribution(unitNo: "A-1", unitType: .threePlusOne, grossArea: 120, netArea: 100, target: .stakeholder)
        let u2 = UnitDistribution(unitNo: "A-2", unitType: .twoPlusOne, grossArea: 100, netArea: 85, target: .contractor)
        let u3 = UnitDistribution(unitNo: "A-3", unitType: .onePlusOne, grossArea: 60, netArea: 50, target: .sale)
        project.unitDistributions = [u1, u2, u3]

        XCTAssertEqual(project.stakeholderUnits.count, 1)
        XCTAssertEqual(project.contractorUnits.count, 1)
        XCTAssertEqual(project.saleUnits.count, 1)
        XCTAssertEqual(project.unitDistributions.count, 3)
    }

    // Test 3: Gelir tahmini hesabı
    func test_urbanRenewalProject_estimatedRevenue() {
        let project = UrbanRenewalProject(projectName: "Gelir", address: "", district: "D", city: "C")
        let u1 = UnitDistribution(unitNo: "D-1", unitType: .threePlusOne, grossArea: 150, netArea: 120, target: .sale)
        u1.estimatedValue = 5_000_000
        let u2 = UnitDistribution(unitNo: "D-2", unitType: .twoPlusOne, grossArea: 110, netArea: 90, target: .sale)
        u2.estimatedValue = 3_500_000
        let u3 = UnitDistribution(unitNo: "D-3", unitType: .onePlusOne, grossArea: 65, netArea: 52, target: .contractor)
        u3.estimatedValue = 2_000_000  // Bu müteahhite ait, satışa dahil edilmemeli
        project.unitDistributions = [u1, u2, u3]

        XCTAssertEqual(project.estimatedRevenue, 8_500_000, accuracy: 1)
    }

    // Test 4: UnitDistribution CRUD
    func test_unitDistribution_initialization() {
        let unit = UnitDistribution(unitNo: "B Blok D.5", unitType: .fourPlusOne, grossArea: 180, netArea: 150, target: .stakeholder)
        XCTAssertEqual(unit.unitNo, "B Blok D.5")
        XCTAssertEqual(unit.unitType, .fourPlusOne)
        XCTAssertEqual(unit.grossArea, 180)
        XCTAssertEqual(unit.allocationTarget, .stakeholder)
        XCTAssertFalse(unit.isSold)
    }

    func test_unitDistribution_saleStatus() {
        let unit = UnitDistribution(unitNo: "C-1", unitType: .twoPlusOne, grossArea: 100, netArea: 85, target: .sale)
        unit.salePrice = 4_200_000
        unit.isSold = true
        unit.buyerName = "Ahmet Çelik"
        XCTAssertTrue(unit.isSold)
        XCTAssertEqual(unit.buyerName, "Ahmet Çelik")
        XCTAssertEqual(unit.salePrice, 4_200_000)
    }

    // Test 5: UrbanRenewalStatus step index
    func test_urbanRenewalStatus_stepIndexOrder() {
        XCTAssertLessThan(UrbanRenewalStatus.riskAssessment.stepIndex, UrbanRenewalStatus.stakeholderAgreement.stepIndex)
        XCTAssertLessThan(UrbanRenewalStatus.stakeholderAgreement.stepIndex, UrbanRenewalStatus.demolition.stepIndex)
        XCTAssertLessThan(UrbanRenewalStatus.demolition.stepIndex, UrbanRenewalStatus.permitting.stepIndex)
        XCTAssertLessThan(UrbanRenewalStatus.permitting.stepIndex, UrbanRenewalStatus.construction.stepIndex)
        XCTAssertLessThan(UrbanRenewalStatus.construction.stepIndex, UrbanRenewalStatus.delivery.stepIndex)
        XCTAssertLessThan(UrbanRenewalStatus.delivery.stepIndex, UrbanRenewalStatus.completed.stepIndex)
    }
}
