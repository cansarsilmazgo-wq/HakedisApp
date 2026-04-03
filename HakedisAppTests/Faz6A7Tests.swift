import XCTest
import Foundation

// MARK: - A6 Hakediş Kesin Hesap Tests

final class FinalAccountTests: XCTestCase {

    func test_finalAccount_varsayilanDegerler() {
        let account = FinalAccount(contract: nil)
        XCTAssertEqual(account.totalContractAmount, 0)
        XCTAssertEqual(account.totalHakedisAmount, 0)
        XCTAssertEqual(account.status, .draft)
        XCTAssertEqual(account.finalBalance, 0)
    }

    func test_finalAccount_bakiyeHesaplama_tamOdeme() {
        let account = FinalAccount(contract: nil)
        account.totalHakedisAmount = 1_000_000
        account.totalWorkIncrease = 50_000
        account.totalWorkDecrease = 20_000
        account.totalPriceDifference = 30_000
        account.totalPenalty = 10_000
        account.totalPayments = 1_050_000
        // finalBalance = 1,000,000 + 50,000 - 20,000 + 30,000 - 10,000 - 1,050,000 = 0
        XCTAssertEqual(account.finalBalance, 0, accuracy: 0.01)
    }

    func test_finalAccount_bakiye_alacakliHal() {
        let account = FinalAccount(contract: nil)
        account.totalHakedisAmount = 500_000
        account.totalPayments = 400_000
        account.totalPenalty = 0
        account.totalWorkIncrease = 0; account.totalWorkDecrease = 0; account.totalPriceDifference = 0
        // 500,000 - 400,000 = 100,000 (yüklenici alacağı)
        XCTAssertEqual(account.finalBalance, 100_000, accuracy: 0.01)
    }

    func test_finalAccount_durumAkisi() {
        let account = FinalAccount(contract: nil)
        XCTAssertEqual(account.status, .draft)
        account.status = .submitted
        XCTAssertEqual(account.status, .submitted)
        account.status = .approved
        XCTAssertEqual(account.status, .approved)
    }
}

final class HakedisAuditLogTests: XCTestCase {

    func test_auditLog_kayit() {
        let hakedis = Hakedis(periodName: "1. Hakediş", periodStart: Date(), periodEnd: Date())
        let log = HakedisAuditLog(action: .created, performedBy: "Ahmet Mühendis", details: "Hakediş oluşturuldu")
        log.hakedis = hakedis
        XCTAssertEqual(log.action, .created)
        XCTAssertEqual(log.performedBy, "Ahmet Mühendis")
        XCTAssertEqual(log.details, "Hakediş oluşturuldu")
        XCTAssertNotNil(log.hakedis)
    }

    func test_auditLog_tumActionlariTamlanmis() {
        for action in AuditAction.allCases {
            XCTAssertFalse(action.rawValue.isEmpty, "\(action) rawValue boş olmamalı")
            XCTAssertFalse(action.icon.isEmpty, "\(action) icon boş olmamalı")
        }
    }

    func test_hakedisTemplate_defaultSections() {
        let t = HakedisTemplate(templateName: "Test Şablon")
        XCTAssertFalse(t.sections.isEmpty)
        XCTAssertTrue(t.sections.contains("workItems"))
        XCTAssertTrue(t.sections.contains("signatureBlock"))
    }
}

// MARK: - A7 Kalite Kontrol Tests

final class QualityChecklistTemplateTests: XCTestCase {

    func test_betonDokum_15Madde() {
        let items = QualityChecklistTemplateProvider.items(for: .concretePour)
        XCTAssertEqual(items.count, 15, "Beton döküm şablonu 15 madde içermeli")
    }

    func test_demirDonati_14Madde() {
        let items = QualityChecklistTemplateProvider.items(for: .reinforcement)
        XCTAssertEqual(items.count, 14, "Demir donatı şablonu 14 madde içermeli")
    }

    func test_suYalitim_10Madde() {
        let items = QualityChecklistTemplateProvider.items(for: .waterproofing)
        XCTAssertEqual(items.count, 10, "Su yalıtım şablonu 10 madde içermeli")
    }

    func test_tumSablonlarBosDegildir() {
        for type in QualityChecklistType.allCases {
            let items = QualityChecklistTemplateProvider.items(for: type)
            XCTAssertFalse(items.isEmpty, "\(type.rawValue) şablonu boş olmamalı")
        }
    }
}

final class OverallScoreTests: XCTestCase {

    func test_overallScore_hesaplama_10_15() {
        let cl = QualityChecklist(checklistType: .general, checkedBy: "Test")
        // 15 madde, 10 uygun → skor = 10/15 × 100 = 66.67
        var items = (0..<15).map { QualityCheckItem(title: "Madde \($0)") }
        for i in 0..<10 { items[i].result = .pass }
        for i in 10..<15 { items[i].result = .fail }
        cl.checkItems = items
        XCTAssertEqual(cl.passedCount, 10)
        XCTAssertEqual(cl.failedCount, 5)
        XCTAssertEqual(cl.overallScore, 10.0 / 15.0 * 100, accuracy: 0.1)
    }

    func test_overallScore_uygulanamaz_haric() {
        let cl = QualityChecklist(checklistType: .general, checkedBy: "Test")
        var items = [QualityCheckItem]()
        for i in 0..<10 {
            var item = QualityCheckItem(title: "Madde \(i)")
            item.result = i < 8 ? .pass : .notApplicable
            items.append(item)
        }
        cl.checkItems = items
        // Applicable = 8 (notApplicable 2 hariç), passed = 8 → skor = 100%
        XCTAssertEqual(cl.applicableCount, 8)
        XCTAssertEqual(cl.overallScore, 100.0, accuracy: 0.01)
    }

    func test_hasFailures_dogru() {
        let cl = QualityChecklist(checklistType: .general, checkedBy: "Test")
        var items = [QualityCheckItem(title: "A"), QualityCheckItem(title: "B")]
        items[0].result = .pass
        items[1].result = .fail
        cl.checkItems = items
        XCTAssertTrue(cl.hasFailures)
    }
}

final class NCRTests: XCTestCase {

    func test_ncrNo_otomatikOlusturma() {
        let ncrNo = NonConformanceReport.generateNCRNo(existingCount: 0, year: 2026)
        XCTAssertEqual(ncrNo, "NCR-2026-001")
    }

    func test_ncrNo_siralama() {
        let ncrNo5 = NonConformanceReport.generateNCRNo(existingCount: 4, year: 2026)
        XCTAssertEqual(ncrNo5, "NCR-2026-005")
    }

    func test_ncr_durumAkisi() {
        let ncr = NonConformanceReport(ncrNo: "NCR-2026-001", location: "A Blok", nonConformanceDescription: "Paspayı yetersiz", detectedBy: "Kontrol Mühendisi")
        XCTAssertEqual(ncr.status, .open)
        ncr.status = .correctionProposed
        XCTAssertEqual(ncr.status, .correctionProposed)
        ncr.status = .correctionInProgress
        XCTAssertEqual(ncr.status, .correctionInProgress)
        ncr.status = .correctionDone
        ncr.correctionDate = Date()
        XCTAssertEqual(ncr.status, .correctionDone)
        ncr.status = .verified
        XCTAssertEqual(ncr.status, .verified)
        ncr.status = .closed
        XCTAssertEqual(ncr.status, .closed)
    }

    func test_ncr_gecikme_terminGecmis() {
        let ncr = NonConformanceReport(ncrNo: "NCR-001", location: "B Kat", nonConformanceDescription: "Hasarlı iskele", detectedBy: "Mühendis")
        ncr.correctionDeadline = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        XCTAssertTrue(ncr.isOverdue)
    }

    func test_ncr_kapali_gecikmiyor() {
        let ncr = NonConformanceReport(ncrNo: "NCR-002", location: "C Blok", nonConformanceDescription: "Test", detectedBy: "Test")
        ncr.correctionDeadline = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        ncr.status = .closed
        XCTAssertFalse(ncr.isOverdue)
    }
}

final class QualityScoreWorkItemTests: XCTestCase {

    func test_itemResult_effectiveResult_yeniAlanlar() {
        var item = QualityCheckItem(title: "Test maddesi")
        item.result = .fail
        XCTAssertEqual(item.effectiveResult, .fail)
        item.result = .notApplicable
        XCTAssertEqual(item.effectiveResult, .notApplicable)
    }

    func test_itemResult_legacyIsChecked_geriUyumlu() {
        var item = QualityCheckItem(title: "Legacy madde")
        item.isChecked = true
        // result == nil → effectiveResult uses isChecked
        XCTAssertEqual(item.effectiveResult, .pass)
        item.isChecked = false
        XCTAssertEqual(item.effectiveResult, .fail)
    }
}
