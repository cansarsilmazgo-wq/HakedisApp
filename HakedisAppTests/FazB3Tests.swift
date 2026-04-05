import XCTest
import Foundation

// MARK: - B3 Keşif ve İhale Hazırlık Tests

final class SurveyModelTests: XCTestCase {

    func test_survey_noOlusturma() {
        let no = Survey.generateNo(existingCount: 0, year: 2026)
        XCTAssertEqual(no, "KES-2026/001")
    }

    func test_survey_noSiralama() {
        let no = Survey.generateNo(existingCount: 9, year: 2026)
        XCTAssertEqual(no, "KES-2026/010")
    }

    func test_survey_varsayilanDeger() {
        let s = Survey(surveyNo: "KES-2026/001", surveyName: "Bodrum Keşfi",
                       projectName: "Proje A", preparedBy: "Mühendis")
        XCTAssertEqual(s.status, .draft)
        XCTAssertEqual(s.totalItems, 0)
        XCTAssertEqual(s.totalEstimatedCost, 0.0)
        XCTAssertTrue(s.locations.isEmpty)
    }

    func test_survey_toplamMaliyet() {
        let s = Survey(surveyNo: "KES-2026/001", surveyName: "Test", projectName: "P", preparedBy: "M")
        let loc = SurveyLocation(locationName: "1. Kat", type: .floor, sortOrder: 0)
        let item1 = SurveyItem(pozCode: "01.001", pozName: "Sıva", unit: "m²", quantity: 100, unitPrice: 50)
        let item2 = SurveyItem(pozCode: "01.002", pozName: "Boya", unit: "m²", quantity: 100, unitPrice: 30)
        loc.items = [item1, item2]
        s.locations = [loc]
        XCTAssertEqual(s.totalEstimatedCost, 8000.0, accuracy: 0.01)
        XCTAssertEqual(s.totalItems, 2)
    }
}

final class SurveyItemTests: XCTestCase {

    func test_surveyItem_hesap() {
        let item = SurveyItem(pozCode: "02.001", pozName: "Kalıp", unit: "m²", quantity: 150, unitPrice: 120)
        XCTAssertEqual(item.estimatedTotal, 18000.0, accuracy: 0.01)
    }

    func test_surveyLocation_subtotal() {
        let loc = SurveyLocation(locationName: "Bodrum", type: .basement, sortOrder: 0)
        let i1 = SurveyItem(pozCode: "A", pozName: "Demir", unit: "kg", quantity: 500, unitPrice: 25)
        let i2 = SurveyItem(pozCode: "B", pozName: "Beton", unit: "m³", quantity: 20, unitPrice: 1200)
        loc.items = [i1, i2]
        XCTAssertEqual(loc.subtotal, 36500.0, accuracy: 0.01)
    }
}

final class BidPreparationModelTests: XCTestCase {

    func test_bid_noOlusturma() {
        let no = BidPreparation.generateNo(existingCount: 0, year: 2026)
        XCTAssertEqual(no, "IH-2026/001")
    }

    func test_bid_varsayilanDeger() {
        let bid = BidPreparation(bidNo: "IH-2026/001", projectTitle: "Okul",
                                 clientName: "İdare", bidDeadline: Date().addingTimeInterval(3600 * 24 * 30))
        XCTAssertEqual(bid.status, .preparation)
        XCTAssertEqual(bid.overheadRate, 15.0)
        XCTAssertEqual(bid.profitRate, 10.0)
        XCTAssertFalse(bid.isOverdue)
        XCTAssertTrue(bid.analysisRecords.isEmpty)
    }

    func test_bid_maliyetHesabi() {
        let bid = BidPreparation(bidNo: "IH-2026/001", projectTitle: "Köprü",
                                 clientName: "İdare", bidDeadline: Date().addingTimeInterval(86400))
        bid.overheadRate = 15
        bid.profitRate = 10
        bid.taxRate = 20
        // rec: quantity=1, resource unitPrice=100, unitCost=100, totalCost=100*1=100
        let rec = AnalysisRecord(pozCode: "X", pozName: "Test", unit: "m²", quantity: 1)
        let res = AnalysisResourceItem(resourceName: "İşçilik", typeRaw: AnalysisResourceType.labor.rawValue,
                                       unit: "gün", quantity: 1, unitPrice: 100)
        rec.resources = [res]
        bid.analysisRecords = [rec]
        // totalDirectCost=100, overhead=15, profit=(100+15)*0.10=11.5, subtotal=126.5, tax=25.3, total=151.8
        XCTAssertEqual(bid.totalDirectCost, 100.0, accuracy: 0.01)
        XCTAssertEqual(bid.overheadAmount, 15.0, accuracy: 0.01)
        XCTAssertEqual(bid.profitAmount, 11.5, accuracy: 0.01)
        XCTAssertEqual(bid.subtotalBeforeTax, 126.5, accuracy: 0.01)
        XCTAssertEqual(bid.taxAmount, 25.3, accuracy: 0.01)
        XCTAssertEqual(bid.totalWithTax, 151.8, accuracy: 0.01)
    }
}

final class AnalysisResourceTests: XCTestCase {

    func test_analysisRecord_kaynakJsonEncodeDecode() {
        let rec = AnalysisRecord(pozCode: "01", pozName: "Kaba İnşaat", unit: "m²", quantity: 50)
        let r1 = AnalysisResourceItem(resourceName: "Çimento", typeRaw: AnalysisResourceType.material.rawValue,
                                      unit: "kg", quantity: 200, unitPrice: 2)
        let r2 = AnalysisResourceItem(resourceName: "İşçilik", typeRaw: AnalysisResourceType.labor.rawValue,
                                      unit: "gün", quantity: 5, unitPrice: 350)
        rec.resources = [r1, r2]
        let decoded = rec.resources
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].resourceName, "Çimento")
        XCTAssertEqual(decoded[1].resourceType, .labor)
    }

    func test_analysisRecord_unitCost() {
        let rec = AnalysisRecord(pozCode: "02", pozName: "Sıva", unit: "m²", quantity: 100)
        let r = AnalysisResourceItem(resourceName: "Malzeme", typeRaw: AnalysisResourceType.material.rawValue,
                                     unit: "m²", quantity: 1, unitPrice: 80)
        rec.resources = [r]
        XCTAssertEqual(rec.unitCost, 80.0, accuracy: 0.01)
        XCTAssertEqual(rec.totalCost, 8000.0, accuracy: 0.01)
    }
}
