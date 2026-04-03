import XCTest
import SwiftData
import Foundation

// MARK: - AttachmentRecord Tests (BÖLÜM 1)

final class AttachmentRecordTests: XCTestCase {

    func test_attachmentRecord_olusturma_varsayilanDegerler() {
        let record = AttachmentRecord(attachmentNo: 1, location: "Bodrum Kat")
        XCTAssertEqual(record.attachmentNo, 1)
        XCTAssertEqual(record.location, "Bodrum Kat")
        XCTAssertNil(record.length)
        XCTAssertNil(record.width)
        XCTAssertNil(record.height)
        XCTAssertNil(record.quantity)
    }

    func test_attachmentRecord_ucBoyutHesabi_uzunlukXgenislikXyukseklik() {
        let record = AttachmentRecord(attachmentNo: 2, location: "Perde Beton")
        record.length = 10.0
        record.width = 0.3
        record.height = 3.5
        // L × W × H = 10 × 0.3 × 3.5 = 10.5
        XCTAssertEqual(record.calculatedQuantity, 10.5, accuracy: 0.001)
    }

    func test_attachmentRecord_ikiBoyutHesabi_uzunlukXgenislik() {
        let record = AttachmentRecord(attachmentNo: 3, location: "Döşeme")
        record.length = 5.0
        record.width = 4.0
        // height nil → L × W = 5 × 4 = 20
        XCTAssertEqual(record.calculatedQuantity, 20.0, accuracy: 0.001)
    }

    func test_attachmentRecord_miktar_direkt_gecerli() {
        let record = AttachmentRecord(attachmentNo: 4, location: "Boru")
        record.quantity = 42.5
        // length nil → use quantity
        XCTAssertEqual(record.calculatedQuantity, 42.5, accuracy: 0.001)
    }
}

// MARK: - PriceDifferenceCalc Tests (BÖLÜM 2)

final class PriceDifferenceCalcTests: XCTestCase {

    func test_priceDifferenceCalc_pnDegeri_dogru() {
        // Pn = a1*(i1c/i1b) + a2*(i2c/i2b) + a3*(i3c/i3b) + a4*(i4c/i4b) + a5
        // Tüm endeksler 1.0x — Pn = a1 + a2 + a3 + a4 + a5 = 1.0 (eğer katsayılar toplamı 1)
        let calc = PriceDifferenceCalc(baseMonth: "2025-01", applicationMonth: "2026-01")
        // katsayılar: a1=0.22, a2=0.30, a3=0.12, a4=0.24, a5=0.12 → toplam=1.0
        calc.a1 = 0.22; calc.a2 = 0.30; calc.a3 = 0.12; calc.a4 = 0.24; calc.a5 = 0.12
        calc.index1Base = 100; calc.index1Current = 110   // i1 ratio = 1.1
        calc.index2Base = 100; calc.index2Current = 120   // i2 ratio = 1.2
        calc.index3Base = 100; calc.index3Current = 100   // i3 ratio = 1.0
        calc.index4Base = 100; calc.index4Current = 130   // i4 ratio = 1.3
        // Pn = 0.22*1.1 + 0.30*1.2 + 0.12*1.0 + 0.24*1.3 + 0.12
        //    = 0.242 + 0.360 + 0.120 + 0.312 + 0.12 = 1.154
        XCTAssertEqual(calc.pnValue, 1.154, accuracy: 0.001)
    }

    func test_priceDifferenceCalc_fiyatFarkiTutari_dogru() {
        let calc = PriceDifferenceCalc(baseMonth: "2025-01", applicationMonth: "2026-01")
        calc.a1 = 0.22; calc.a2 = 0.30; calc.a3 = 0.12; calc.a4 = 0.24; calc.a5 = 0.12
        calc.index1Base = 100; calc.index1Current = 110
        calc.index2Base = 100; calc.index2Current = 120
        calc.index3Base = 100; calc.index3Current = 100
        calc.index4Base = 100; calc.index4Current = 130
        calc.hakedisAmount = 1_000_000
        // F = 1_000_000 × (1.154 - 1) = 154_000
        XCTAssertEqual(calc.priceDifferenceAmount, 154_000, accuracy: 10)
    }

    func test_priceDifferenceCalc_a5_sabit_0_12() {
        let calc = PriceDifferenceCalc(baseMonth: "2025-01", applicationMonth: "2026-01")
        XCTAssertEqual(calc.a5, 0.12, accuracy: 0.0001, "a5 varsayılan değeri 0.12 olmalıdır (4735 Md.8)")
    }
}

// MARK: - GenisletilmisCashFlowEngine Tests (BÖLÜM 3)

final class CashFlowProjectionTests: XCTestCase {

    func test_cashFlowProjection_aylikProjeKount_3_6_12() {
        let result3 = GenisletilmisCashFlowEngine.projeksiyon(
            hakedisler: [], priceDiffCalcs: [], stockEntries: [],
            attendanceRecords: [], equipmentLogs: [], subHakedisler: [], ayCount: 3
        )
        let result6 = GenisletilmisCashFlowEngine.projeksiyon(
            hakedisler: [], priceDiffCalcs: [], stockEntries: [],
            attendanceRecords: [], equipmentLogs: [], subHakedisler: [], ayCount: 6
        )
        XCTAssertEqual(result3.count, 3)
        XCTAssertEqual(result6.count, 6)
    }

    func test_cashFlowProjection_bosVeri_sifirGelirVeSifirGider() {
        let result = GenisletilmisCashFlowEngine.projeksiyon(
            hakedisler: [], priceDiffCalcs: [], stockEntries: [],
            attendanceRecords: [], equipmentLogs: [], subHakedisler: [], ayCount: 3
        )
        // No hakedis data → avgHakedis = 0, so hakedisGeliri should be 0
        for p in result {
            XCTAssertEqual(p.malzemeGideri, 0, "Malzeme gideri sıfır olmalı")
            XCTAssertEqual(p.iscilikGideri, 0, "İşçilik gideri sıfır olmalı")
            XCTAssertEqual(p.ekipmanGideri, 0, "Ekipman gideri sıfır olmalı")
            XCTAssertEqual(p.taseronGideri, 0, "Taşeron gideri sıfır olmalı")
        }
    }
}

// MARK: - SubcontractorHakedis Tests (BÖLÜM 4)

final class SubcontractorHakedisTests: XCTestCase {

    func test_subHakedis_olusturma_varsayilanStatus_draft() {
        let h = SubcontractorHakedis(
            periodName: "Mart 2026",
            periodStart: Date(),
            periodEnd: Date()
        )
        XCTAssertEqual(h.status, .draft)
        XCTAssertEqual(h.statusRaw, HakedisStatus.draft.rawValue)
    }

    func test_subHakedis_netAmount_grossMinusRetention() {
        let h = SubcontractorHakedis(periodName: "Nisan 2026", periodStart: Date(), periodEnd: Date())
        h.grossAmount = 100_000
        h.retentionAmount = 5_000
        h.netAmount = 95_000
        XCTAssertEqual(h.netAmount, 95_000, accuracy: 0.01)
    }

    func test_subHakedis_profitMargin_dogru_hesaplama() {
        let h = SubcontractorHakedis(periodName: "Mayıs 2026", periodStart: Date(), periodEnd: Date())
        h.grossAmount = 100_000
        h.retentionAmount = 5_000
        h.netAmount = 95_000
        // profitMargin = (grossAmount - netAmount) / grossAmount * 100
        //              = (100_000 - 95_000) / 100_000 * 100 = 5.0%
        XCTAssertEqual(h.profitMargin, 5.0, accuracy: 0.001)
    }
}

// MARK: - QualityChecklist Tests (BÖLÜM 5)

final class QualityChecklistTests: XCTestCase {

    func test_qualityChecklist_varsayilanMaddeler_concretePour() {
        let cl = QualityChecklist(checklistType: .concretePour, checkedBy: "Mühendis A")
        let items = cl.checkItems
        XCTAssertFalse(items.isEmpty, "Beton döküm için varsayılan maddeler olmalı")
        XCTAssertTrue(items.count >= 4, "En az 4 madde bekleniyor")
        XCTAssertFalse(items.allSatisfy { $0.isChecked }, "Başlangıçta tüm maddeler işaretlenmemiş olmalı")
    }

    func test_qualityChecklist_passedCount_guncellenir() {
        let cl = QualityChecklist(checklistType: .general, checkedBy: "Test")
        var items = cl.checkItems
        XCTAssertGreaterThan(items.count, 0)
        items[0].isChecked = true
        cl.checkItems = items
        XCTAssertEqual(cl.passedCount, 1)
    }

    func test_workChangeOrder_exceedsLimit_20percent() {
        let o = WorkChangeOrder(orderNo: "İAE-001", changeType: "Artış", changePercent: 25.0, changeAmount: 250_000, description: "Ek iş")
        XCTAssertTrue(o.exceedsLimit, "%25 > %20 sınırı aşıyor olmalı")

        let o2 = WorkChangeOrder(orderNo: "İAE-002", changeType: "Eksilişi", changePercent: 15.0, changeAmount: 150_000, description: "İş eksilişi")
        XCTAssertFalse(o2.exceedsLimit, "%15 < %20 sınırı içinde olmalı")
    }
}
