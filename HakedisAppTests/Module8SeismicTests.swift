import XCTest
import SwiftData

// MARK: - Module 8: Deprem Risk Tests

final class Module8SeismicTests: XCTestCase {

    // Test 1: Skor hesaplama (uygun / toplam)
    func test_seismicAssessment_safetyScore_allPass() {
        let assessment = SeismicAssessment(floorCount: 4)
        let item1 = SeismicChecklistItem(category: .columns, checkDescription: "Test 1")
        item1.result = .pass
        let item2 = SeismicChecklistItem(category: .beams, checkDescription: "Test 2")
        item2.result = .pass
        assessment.checklistItems = [item1, item2]

        XCTAssertEqual(assessment.safetyScore, 100.0, accuracy: 0.01)
    }

    func test_seismicAssessment_safetyScore_halfPass() {
        let assessment = SeismicAssessment(floorCount: 4)
        let item1 = SeismicChecklistItem(category: .columns, checkDescription: "Test 1")
        item1.result = .pass
        let item2 = SeismicChecklistItem(category: .beams, checkDescription: "Test 2")
        item2.result = .fail
        assessment.checklistItems = [item1, item2]

        XCTAssertEqual(assessment.safetyScore, 50.0, accuracy: 0.01)
    }

    func test_seismicAssessment_safetyScore_excludesNotApplicable() {
        let assessment = SeismicAssessment(floorCount: 4)
        let item1 = SeismicChecklistItem(category: .columns, checkDescription: "Pass")
        item1.result = .pass
        let item2 = SeismicChecklistItem(category: .beams, checkDescription: "N/A")
        item2.result = .notApplicable  // Bu sayılmamalı
        let item3 = SeismicChecklistItem(category: .foundation, checkDescription: "Pass")
        item3.result = .pass
        assessment.checklistItems = [item1, item2, item3]

        // 2 applicable, 2 pass → %100
        XCTAssertEqual(assessment.safetyScore, 100.0, accuracy: 0.01)
    }

    func test_seismicAssessment_safetyScore_noItems() {
        let assessment = SeismicAssessment(floorCount: 4)
        XCTAssertEqual(assessment.safetyScore, 0.0)
    }

    // Test 2: Sonuç otomatik belirleme
    func test_assessmentResult_fromScore_80plus_isSafe() {
        XCTAssertEqual(AssessmentResult.fromScore(100), .safe)
        XCTAssertEqual(AssessmentResult.fromScore(80), .safe)
        XCTAssertEqual(AssessmentResult.fromScore(85), .safe)
    }

    func test_assessmentResult_fromScore_60to80_isLimitedSafe() {
        XCTAssertEqual(AssessmentResult.fromScore(60), .limitedSafe)
        XCTAssertEqual(AssessmentResult.fromScore(70), .limitedSafe)
        XCTAssertEqual(AssessmentResult.fromScore(79.9), .limitedSafe)
    }

    func test_assessmentResult_fromScore_40to60_isUnsafeLow() {
        XCTAssertEqual(AssessmentResult.fromScore(40), .unsafeLowRisk)
        XCTAssertEqual(AssessmentResult.fromScore(50), .unsafeLowRisk)
        XCTAssertEqual(AssessmentResult.fromScore(59.9), .unsafeLowRisk)
    }

    func test_assessmentResult_fromScore_20to40_isUnsafeHigh() {
        XCTAssertEqual(AssessmentResult.fromScore(20), .unsafeHighRisk)
        XCTAssertEqual(AssessmentResult.fromScore(30), .unsafeHighRisk)
        XCTAssertEqual(AssessmentResult.fromScore(39.9), .unsafeHighRisk)
    }

    func test_assessmentResult_fromScore_below20_isCollapse() {
        XCTAssertEqual(AssessmentResult.fromScore(0), .collapse)
        XCTAssertEqual(AssessmentResult.fromScore(10), .collapse)
        XCTAssertEqual(AssessmentResult.fromScore(19.9), .collapse)
    }

    // Test 3: Kontrol listesi şablon doğruluğu
    func test_seismicTemplate_allCategories_haveItems() {
        for category in SeismicCheckCategory.allCases {
            let items = SeismicChecklistTemplateProvider.items(for: category)
            XCTAssertGreaterThan(items.count, 0, "\(category) kategorisi boş olamaz")
        }
    }

    func test_seismicTemplate_columns_hasMinimumItems() {
        let items = SeismicChecklistTemplateProvider.items(for: .columns)
        XCTAssertGreaterThanOrEqual(items.count, 6, "Kolon kategorisi en az 6 madde içermeli")
    }

    func test_seismicTemplate_allItems_countIsSignificant() {
        let allItems = SeismicChecklistTemplateProvider.allItems()
        XCTAssertGreaterThan(allItems.count, 30, "Toplam madde sayısı 30'dan fazla olmalı")
    }

    // Test 4: Zemin sınıfı mapping
    func test_soilClass_riskLevels() {
        XCTAssertEqual(SoilClass.za.riskLevel, "Düşük Risk")
        XCTAssertEqual(SoilClass.zb.riskLevel, "Düşük Risk")
        XCTAssertEqual(SoilClass.zc.riskLevel, "Orta Risk")
        XCTAssertEqual(SoilClass.zd.riskLevel, "Yüksek Risk")
        XCTAssertEqual(SoilClass.ze.riskLevel, "Çok Yüksek Risk")
    }

    func test_soilClass_allCasesHaveRawValues() {
        for sc in SoilClass.allCases {
            XCTAssertFalse(sc.rawValue.isEmpty)
        }
    }

    // Test 5: SeismicAssessment initialization
    func test_seismicAssessment_defaultValues() {
        let assessment = SeismicAssessment(floorCount: 8, structuralSystem: .steelFrame)
        XCTAssertEqual(assessment.floorCount, 8)
        XCTAssertEqual(assessment.structuralSystem, .steelFrame)
        XCTAssertEqual(assessment.soilClass, .zc)
        XCTAssertEqual(assessment.seismicZone, .zone1)
        XCTAssertFalse(assessment.hasGeotechnicalReport)
        XCTAssertFalse(assessment.retrofitRequired)
        XCTAssertTrue(assessment.checklistItems.isEmpty)
    }

    func test_seismicAssessment_updateResult() {
        let assessment = SeismicAssessment(floorCount: 4)
        // Tüm maddeler uygun → %100 → Güvenli
        let items = (0..<5).map { i -> SeismicChecklistItem in
            let item = SeismicChecklistItem(category: .columns, checkDescription: "Test \(i)")
            item.result = .pass
            item.assessment = assessment
            return item
        }
        assessment.checklistItems = items
        assessment.updateResult()
        XCTAssertEqual(assessment.assessmentResult, .safe)
        XCTAssertFalse(assessment.retrofitRequired)
    }

    func test_seismicAssessment_updateResult_requiresRetrofit() {
        let assessment = SeismicAssessment(floorCount: 4)
        let items = (0..<5).map { i -> SeismicChecklistItem in
            let item = SeismicChecklistItem(category: .columns, checkDescription: "Test \(i)")
            item.result = .fail  // Tümü başarısız → %0 → Göçme riski
            item.assessment = assessment
            return item
        }
        assessment.checklistItems = items
        assessment.updateResult()
        XCTAssertNotEqual(assessment.assessmentResult, .safe)
        XCTAssertTrue(assessment.retrofitRequired)
    }
}
