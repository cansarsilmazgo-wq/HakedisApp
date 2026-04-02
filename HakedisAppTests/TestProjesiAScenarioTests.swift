import XCTest
import SwiftData

// MARK: - Test Projesi A — Uçtan Uca Senaryo Testleri
// Görev: Tüm hesaplamaları ve iş kurallarını gerçek veriyle doğrula

final class TestProjesiAScenarioTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    // Tüm model tipleri dahil — Grup 1/2/3 ile eklenenler de var
    private static let fullSchema = Schema([
        Project.self, Contractor.self, Contract.self,
        WorkItem.self, DailyEntry.self, Hakedis.self,
        HakedisItem.self, Payment.self, RetentionRelease.self,
        ChangeOrder.self, Milestone.self, SiteReport.self,
        ApprovalStep.self, HakedisRevision.self,
        UnitPriceAnalysis.self, SiteHandoverRecord.self, SiteDeficiency.self,
        MeasurementEntry.self, PhotoAnnotation.self,
        LaborRecord.self, MaterialRecord.self, MaterialTransaction.self,
        SpecificationItem.self
    ])

    override func setUpWithError() throws {
        let config = ModelConfiguration(schema: Self.fullSchema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Self.fullSchema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - Yardımcı: Test Projesi A kurulumu

    /// Tam senaryoyu oluşturup döndürür:
    /// Proje → Sözleşme → 5 iş kalemi → Kazı için 3 günlük giriş
    private func kururTestProjesiA() -> (
        project: Project,
        contract: Contract,
        kazi: WorkItem,
        temelBeton: WorkItem,
        kolonBeton: WorkItem,
        duvar: WorkItem,
        siva: WorkItem,
        entries: [DailyEntry]
    ) {
        // 1. Proje
        let project = Project(name: "Test Projesi A")
        XCTAssertEqual(project.status, .active, "Proje başlangıçta aktif olmalı")

        // 2. Sözleşme — %6 teminat, %15 avans
        let contract = Contract(title: "İnşaat Sözleşmesi A", retentionRate: 6.0, advanceRate: 15.0)
        contract.project = project
        project.contracts.append(contract)

        // 3. İş Kalemleri
        let kazi      = WorkItem(code: "01", name: "Kazı",          unit: "m³", unitPrice: 85,  contractedQuantity: 100)
        let temel     = WorkItem(code: "02", name: "Temel Beton",   unit: "m³", unitPrice: 450, contractedQuantity: 50)
        let kolon     = WorkItem(code: "03", name: "Kolon Betonu",  unit: "m³", unitPrice: 480, contractedQuantity: 30)
        let duvar     = WorkItem(code: "04", name: "Duvar",         unit: "m²", unitPrice: 85,  contractedQuantity: 200)
        let siva      = WorkItem(code: "05", name: "Sıva",          unit: "m²", unitPrice: 45,  contractedQuantity: 200)

        for wi in [kazi, temel, kolon, duvar, siva] {
            wi.contract = contract
            contract.workItems.append(wi)
            context.insert(wi)
        }

        // 4. Günlük Saha Girişleri (sadece kazı — 30 + 20 + 25 m³)
        let cal = Calendar.current
        let mar1  = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let mar10 = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let mar20 = cal.date(from: DateComponents(year: 2026, month: 3, day: 20))!

        let e1 = DailyEntry(date: mar1,  quantity: 30, location: "Blok-A", notes: "1. gün kazısı")
        let e2 = DailyEntry(date: mar10, quantity: 20, location: "Blok-A", notes: "2. gün kazısı")
        let e3 = DailyEntry(date: mar20, quantity: 25, location: "Blok-B", notes: "3. gün kazısı")

        for e in [e1, e2, e3] {
            e.workItem = kazi
            kazi.dailyEntries.append(e)
            context.insert(e)
        }

        context.insert(project)
        context.insert(contract)

        return (project, contract, kazi, temel, kolon, duvar, siva, [e1, e2, e3])
    }

    // MARK: - Test 1: Proje ve Sözleşme Kurulumu

    func test_projeVeSozlesmeKurulumu() throws {
        let (project, contract, kazi, temel, kolon, duvar, siva, _) = kururTestProjesiA()

        XCTAssertEqual(project.name, "Test Projesi A")
        XCTAssertEqual(project.status, .active)
        XCTAssertEqual(contract.retentionRate, 6.0, "%6 teminat oranı")
        XCTAssertEqual(contract.advanceRate, 15.0, "%15 avans oranı")
        XCTAssertEqual(contract.workItems.count, 5, "5 iş kalemi olmalı")

        // Birim fiyat doğrulaması
        XCTAssertEqual(kazi.unitPrice,  85)
        XCTAssertEqual(temel.unitPrice, 450)
        XCTAssertEqual(kolon.unitPrice, 480)
        XCTAssertEqual(duvar.unitPrice, 85)
        XCTAssertEqual(siva.unitPrice,  45)
    }

    // MARK: - Test 2: Sözleşme Toplam Tutarı

    func test_sozlesmeTotalAmount() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()
        // 100×85 + 50×450 + 30×480 + 200×85 + 200×45
        // = 8500 + 22500 + 14400 + 17000 + 9000
        // = 71.400 TL
        XCTAssertEqual(contract.totalContractAmount, 71_400, accuracy: 0.01,
                       "Sözleşme toplam bedeli 71.400 TL olmalı")
    }

    // MARK: - Test 3: Günlük Giriş Toplamı ve Pursantaj

    func test_kaziGunlukGirisToplamı() throws {
        let (_, _, kazi, _, _, _, _, _) = kururTestProjesiA()

        XCTAssertEqual(kazi.dailyEntries.count, 3, "3 günlük giriş olmalı")
        XCTAssertEqual(kazi.completedQuantity, 75, "30+20+25 = 75 m³")
    }

    func test_pursantajHesabi() throws {
        let (_, _, kazi, temel, kolon, duvar, siva, _) = kururTestProjesiA()

        // Kazı: 75/100 = %75
        XCTAssertEqual(kazi.completionPercentage, 75.0, accuracy: 0.001,
                       "Kazı pursantajı 75/100 = %75 olmalı")

        // Diğer iş kalemlerinde henüz giriş yok → %0
        XCTAssertEqual(temel.completionPercentage, 0)
        XCTAssertEqual(kolon.completionPercentage, 0)
        XCTAssertEqual(duvar.completionPercentage, 0)
        XCTAssertEqual(siva.completionPercentage,  0)

        // Kalan miktar
        XCTAssertEqual(kazi.remainingQuantity, 25, "100 - 75 = 25 m³ kalan")
    }

    // MARK: - Test 4: HAKEDİŞ HESAPLAMALARI (ana senaryo)

    func test_hakedisHesaplamalari_tamSenaryo() throws {
        let (_, contract, kazi, _, _, _, _, _) = kururTestProjesiA()

        // Mart 2026 dönemini kapsayan hakediş oluştur
        let cal = Calendar.current
        let periodStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let periodEnd   = cal.date(from: DateComponents(year: 2026, month: 3, day: 31))!

        let hakedis = Hakedis(periodName: "Mart 2026", periodStart: periodStart, periodEnd: periodEnd)
        hakedis.contract = contract
        contract.hakedisler.append(hakedis)
        context.insert(hakedis)

        // Bu dönemdeki kazı miktarı = 75 m³ (tüm 3 giriş Mart içinde)
        let periodEntries = kazi.dailyEntries.filter { $0.date >= periodStart && $0.date <= periodEnd }
        let currentQty = periodEntries.reduce(0) { $0 + $1.quantity }
        XCTAssertEqual(currentQty, 75, "Dönem içi kazı = 75 m³")

        let item = HakedisItem(
            workItemName: kazi.name,
            workItemCode: kazi.code,
            unit: kazi.unit,
            unitPrice: kazi.unitPrice,
            previousQuantity: 0,
            currentQuantity: currentQty
        )
        item.hakedis = hakedis
        hakedis.items.append(item)
        context.insert(item)

        // ── HESAPLAMA DOĞRULAMALARI ──

        // Brüt hakediş = 75 × 85 = 6.375 TL
        XCTAssertEqual(hakedis.grossAmount, 6_375, accuracy: 0.01,
                       "Brüt hakediş 75×85 = 6.375 TL olmalı")

        // Teminat kesintisi = 6.375 × %6 = 382,50 TL
        XCTAssertEqual(hakedis.retentionAmount, 382.50, accuracy: 0.01,
                       "Teminat kesintisi 6.375×%6 = 382,50 TL olmalı")

        // Avans kesintisi = 6.375 × %15 = 956,25 TL
        XCTAssertEqual(hakedis.advanceDeduction, 956.25, accuracy: 0.01,
                       "Avans kesintisi 6.375×%15 = 956,25 TL olmalı")

        // Net hakediş = 6.375 - 382,50 - 956,25 = 5.036,25 TL
        XCTAssertEqual(hakedis.netAmount, 5_036.25, accuracy: 0.01,
                       "Net hakediş = 6375 - 382.50 - 956.25 = 5.036,25 TL olmalı")

        // KDV yok (kdvRate = 0)
        XCTAssertEqual(hakedis.kdvAmount, 0)
        XCTAssertEqual(hakedis.totalWithKDV, hakedis.netAmount)

        // Ödeme henüz yok
        XCTAssertEqual(hakedis.totalPaid, 0)
        XCTAssertEqual(hakedis.remainingAmount, 5_036.25, accuracy: 0.01)
    }

    // MARK: - Test 5: HakedisItem kümülatif değerleri

    func test_hakedisItem_kumulatif() throws {
        let item = HakedisItem(
            workItemName: "Kazı", workItemCode: "01", unit: "m³",
            unitPrice: 85, previousQuantity: 0, currentQuantity: 75
        )
        context.insert(item)

        XCTAssertEqual(item.periodAmount,      6_375, accuracy: 0.01,  "75×85 = 6375")
        XCTAssertEqual(item.cumulativeQuantity, 75,   accuracy: 0.01,  "0+75 = 75")
        XCTAssertEqual(item.cumulativeAmount,  6_375, accuracy: 0.01,  "75×85 = 6375")
    }

    func test_hakedisItem_kumulatif_oncekiHakedisVar() throws {
        // Bir sonraki hakediş döneminde kazı 10m³ daha yapıldıysa
        let item = HakedisItem(
            workItemName: "Kazı", workItemCode: "01", unit: "m³",
            unitPrice: 85, previousQuantity: 75, currentQuantity: 10
        )
        context.insert(item)

        XCTAssertEqual(item.periodAmount,       850,  accuracy: 0.01,  "10×85 = 850")
        XCTAssertEqual(item.cumulativeQuantity,  85,  accuracy: 0.01,  "75+10 = 85")
        XCTAssertEqual(item.cumulativeAmount,  7_225, accuracy: 0.01,  "85×85 = 7225")
    }

    // MARK: - Test 6: Gecikme Cezası

    func test_gecikmeCezasi_tamSenaryo() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()
        // Sözleşme tutarı: 71.400 TL
        // Günlük ceza oranı: %0.1, maks %20
        // 10 gün gecikme → 71.400 × 0.001 × 10 = 714 TL
        contract.dailyPenaltyRate = 0.1
        contract.maxPenaltyRate   = 20.0
        let deadline = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        contract.completionDeadline = deadline

        let expectedPenalty = 71_400 * (0.1 / 100) * 10  // = 714.0
        XCTAssertEqual(contract.delayPenalty(), expectedPenalty, accuracy: 0.01,
                       "10 günlük gecikme cezası 714 TL olmalı")
        XCTAssertEqual(contract.delayDays(), 10, "10 gün gecikme")
    }

    func test_gecikmeCezasi_maksimumeSinirlama() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()
        // 300 gün gecikme @ 1%/gün → teorik 213.600 TL
        // Maks %20 = 71.400 × 0.20 = 14.280 TL
        contract.dailyPenaltyRate = 1.0
        contract.maxPenaltyRate   = 20.0
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: -300, to: Date())

        let expectedMax = 71_400 * 0.20  // = 14.280
        XCTAssertEqual(contract.delayPenalty(), expectedMax, accuracy: 0.01,
                       "Gecikme cezası maksimum %20 ile sınırlı olmalı (14.280 TL)")
    }

    func test_gecikmeCezasi_teslimGunuGecmemis() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()
        contract.dailyPenaltyRate   = 0.1
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: 5, to: Date())

        XCTAssertEqual(contract.delayPenalty(), 0, "Vade geçmemişse ceza sıfır olmalı")
        XCTAssertEqual(contract.delayDays(),    0)
    }

    func test_gecikmeCezasi_oranSifir() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()
        // Günlük oran tanımlanmamışsa ceza hesaplanmamalı
        contract.dailyPenaltyRate   = 0
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: -30, to: Date())

        XCTAssertEqual(contract.delayPenalty(), 0, "Günlük oran 0 ise ceza sıfır olmalı")
    }

    // MARK: - Test 7: Gecikme Faizi (Ödeme Gecikmesi)

    func test_odemeGecikmeiFaizi() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()

        let cal = Calendar.current
        let periodStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let periodEnd   = cal.date(from: DateComponents(year: 2026, month: 3, day: 31))!
        let hakedis = Hakedis(periodName: "Mart 2026", periodStart: periodStart, periodEnd: periodEnd)
        hakedis.contract = contract
        context.insert(hakedis)

        let item = HakedisItem(
            workItemName: "Kazı", workItemCode: "01", unit: "m³",
            unitPrice: 85, previousQuantity: 0, currentQuantity: 75
        )
        item.hakedis = hakedis
        hakedis.items.append(item)
        context.insert(item)

        // 30 gün gecikmiş ödeme, durum approved
        hakedis.dueDate = cal.date(byAdding: .day, value: -30, to: Date())
        hakedis.status  = .approved

        // FIX-1: Stopaj ve damga vergisi netAmount (KDV matrahı) üzerinden hesaplanır
        // grossAmount=6375, retention=%6=382.5, advance=%15=956.25, netAmount=5036.25
        // stopaj = netAmount * 3% = 151.09, damga = netAmount * 0.948% = 47.74 → netAmtAfterTax≈4837.42
        let grossAmt = 75.0 * 85.0
        let netAmt = grossAmt * (1.0 - 0.06 - 0.15)          // 5036.25
        let netAmtAfterTax = netAmt - (netAmt * 3.0 / 100) - (netAmt * 0.948 / 100)
        let expectedInterest = netAmtAfterTax * (9.0 / 365.0 / 100.0) * 30
        XCTAssertEqual(hakedis.daysOverdue, 30)
        XCTAssertTrue(hakedis.isOverdue)
        XCTAssertEqual(hakedis.overdueInterest, expectedInterest, accuracy: 0.01,
                       "30 günlük gecikme faizi (FIX-1: netAmount bazlı stopaj/damga)")
    }

    // MARK: - Test 8: Statü Akışı

    func test_statüAkışı_draft_toPendingApproval() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()
        let hakedis = makeBasicHakedis(contract: contract, qty: 75)

        XCTAssertEqual(hakedis.status, .draft)
        hakedis.status = .pendingApproval
        XCTAssertEqual(hakedis.status, .pendingApproval)
    }

    func test_statüAkışı_approved_toPaid() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()
        let hakedis = makeBasicHakedis(contract: contract, qty: 75)

        hakedis.status = .pendingApproval
        hakedis.status = .approved

        let payment = Payment(amount: hakedis.netAmount)
        payment.hakedis = hakedis
        hakedis.payments.append(payment)
        context.insert(payment)

        XCTAssertEqual(hakedis.remainingAmount, 0, accuracy: 0.01)
        // Ödendi olarak işaretlenebilmeli
        XCTAssertLessThanOrEqual(hakedis.remainingAmount, 0)
    }

    func test_statüAkışı_rejected_toReDraft() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()
        let hakedis = makeBasicHakedis(contract: contract, qty: 75)

        hakedis.status = .pendingApproval
        hakedis.status = .rejected
        XCTAssertEqual(hakedis.status, .rejected)

        hakedis.status = .draft
        XCTAssertEqual(hakedis.status, .draft, "Reddedilen taslağa alınabilmeli")
    }

    // MARK: - Test 9: Birden Fazla Hakediş (Kümülatif Miktar)

    func test_ikinciHakedis_kumulatifMiktar() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()

        // 1. Hakediş: 75 m³ kazı
        let h1 = makeBasicHakedis(contract: contract, qty: 75)
        h1.status = .approved

        // 2. Hakediş: 20 m³ daha kazı (previousQty = 75)
        let cal = Calendar.current
        let apr1  = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let apr30 = cal.date(from: DateComponents(year: 2026, month: 4, day: 30))!
        let h2 = Hakedis(periodName: "Nisan 2026", periodStart: apr1, periodEnd: apr30)
        h2.contract = contract
        contract.hakedisler.append(h2)
        context.insert(h2)

        let item2 = HakedisItem(
            workItemName: "Kazı", workItemCode: "01", unit: "m³",
            unitPrice: 85, previousQuantity: 75, currentQuantity: 20
        )
        item2.hakedis = h2
        h2.items.append(item2)
        context.insert(item2)

        XCTAssertEqual(item2.cumulativeQuantity, 95,    "75+20 = 95 m³ kümülatif")
        XCTAssertEqual(item2.periodAmount,     1_700, accuracy: 0.01, "20×85 = 1.700 TL bu dönem")
        XCTAssertEqual(item2.cumulativeAmount, 8_075, accuracy: 0.01, "95×85 = 8.075 TL kümülatif")

        // Toplam 95/100 = %95 tamamlanma (dailyEntries üzerinden WorkItem.completionPercentage)
        // Bu test sadece HakedisItem'ı test eder
        XCTAssertEqual(item2.previousQuantity, 75, "Önceki hakediş miktarı 75 m³ olmalı")
    }

    // MARK: - Test 10: Bütçe Kullanımı

    func test_butceKullanimYuzdesi() throws {
        let (_, contract, _, _, _, _, _, _) = kururTestProjesiA()

        // İlk hakediş: net = 5.036,25
        let h1 = makeBasicHakedis(contract: contract, qty: 75)
        _ = h1

        // budgetUtilization = totalInvoiced / totalContractAmount × 100
        // totalInvoiced = netAmount = 5.036,25
        // totalContractAmount = 71.400
        let expectedUtil = (5_036.25 / 71_400.0) * 100  // ≈ 7.05%
        XCTAssertEqual(contract.budgetUtilization, expectedUtil, accuracy: 0.01,
                       "Bütçe kullanımı ≈ %7,05 olmalı")
        XCTAssertFalse(contract.isOverBudget, "Bütçe aşımı olmamalı")
    }

    // MARK: - Yardımcı

    private func makeBasicHakedis(contract: Contract, qty: Double) -> Hakedis {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let end   = cal.date(from: DateComponents(year: 2026, month: 3, day: 31))!
        let h = Hakedis(periodName: "Mart 2026", periodStart: start, periodEnd: end)
        h.contract = contract
        contract.hakedisler.append(h)
        context.insert(h)

        let item = HakedisItem(
            workItemName: "Kazı", workItemCode: "01", unit: "m³",
            unitPrice: 85, previousQuantity: 0, currentQuantity: qty
        )
        item.hakedis = h
        h.items.append(item)
        context.insert(item)
        return h
    }
}
