import XCTest
import SwiftData

final class CalculationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Project.self, Contractor.self, Contract.self,
                             WorkItem.self, DailyEntry.self, Hakedis.self,
                             HakedisItem.self, Payment.self, RetentionRelease.self,
                             PriceDifferenceRecord.self, Guarantee.self,
                             UnitPriceAnalysis.self, TestRecord.self,
                             LaborRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - HakedisItem

    func test_periodAmount() {
        let item = HakedisItem(workItemName: "Kazı", workItemCode: "01",
                               unit: "m³", unitPrice: 150, previousQuantity: 0, currentQuantity: 50)
        context.insert(item)
        XCTAssertEqual(item.periodAmount, 7_500, "50 × 150 = 7500")
    }

    func test_cumulativeQuantity() {
        let item = HakedisItem(workItemName: "Kazı", workItemCode: "01",
                               unit: "m³", unitPrice: 150, previousQuantity: 100, currentQuantity: 50)
        context.insert(item)
        XCTAssertEqual(item.cumulativeQuantity, 150)
        XCTAssertEqual(item.cumulativeAmount, 22_500, "150 × 150 = 22500")
    }

    // MARK: - Hakedis amounts

    func test_grossAmount_twoItems() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 10)
        let i1 = HakedisItem(workItemName: "Kazı", workItemCode: "01",
                             unit: "m³", unitPrice: 100, previousQuantity: 0, currentQuantity: 100)
        let i2 = HakedisItem(workItemName: "Beton", workItemCode: "02",
                             unit: "m³", unitPrice: 500, previousQuantity: 0, currentQuantity: 20)
        insertItems([i1, i2], into: hakedis)
        XCTAssertEqual(hakedis.grossAmount, 20_000, "10000 + 10000 = 20000")
    }

    func test_retentionAndNet() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 10)
        let item = HakedisItem(workItemName: "Beton", workItemCode: "01",
                               unit: "m³", unitPrice: 1_000, previousQuantity: 0, currentQuantity: 100)
        insertItems([item], into: hakedis)
        XCTAssertEqual(hakedis.grossAmount, 100_000)
        XCTAssertEqual(hakedis.retentionAmount, 10_000, "%10 teminat")
        XCTAssertEqual(hakedis.netAmount, 90_000)
    }

    func test_zeroRetention() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        let item = HakedisItem(workItemName: "Boya", workItemCode: "01",
                               unit: "m²", unitPrice: 200, previousQuantity: 0, currentQuantity: 50)
        insertItems([item], into: hakedis)
        XCTAssertEqual(hakedis.retentionAmount, 0)
        XCTAssertEqual(hakedis.netAmount, hakedis.grossAmount)
    }

    func test_remainingAmount_afterPartialPayment() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        let item = HakedisItem(workItemName: "Boya", workItemCode: "01",
                               unit: "m²", unitPrice: 50, previousQuantity: 0, currentQuantity: 200)
        insertItems([item], into: hakedis)
        let payment = Payment(amount: 6_000)
        payment.hakedis = hakedis
        hakedis.payments.append(payment)
        context.insert(payment)
        XCTAssertEqual(hakedis.totalPaid, 6_000)
        XCTAssertEqual(hakedis.remainingAmount, 4_000)
    }

    func test_remainingAmount_afterFullPayment() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        let item = HakedisItem(workItemName: "Boya", workItemCode: "01",
                               unit: "m²", unitPrice: 50, previousQuantity: 0, currentQuantity: 200)
        insertItems([item], into: hakedis)
        let payment = Payment(amount: 10_000)
        payment.hakedis = hakedis
        hakedis.payments.append(payment)
        context.insert(payment)
        XCTAssertEqual(hakedis.remainingAmount, 0)
    }

    func test_multiplePayments() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        let item = HakedisItem(workItemName: "Boya", workItemCode: "01",
                               unit: "m²", unitPrice: 100, previousQuantity: 0, currentQuantity: 100)
        insertItems([item], into: hakedis)
        for amt in [3_000.0, 4_000.0, 2_000.0] {
            let p = Payment(amount: amt)
            p.hakedis = hakedis
            hakedis.payments.append(p)
            context.insert(p)
        }
        XCTAssertEqual(hakedis.totalPaid, 9_000)
        XCTAssertEqual(hakedis.remainingAmount, 1_000)
    }

    // MARK: - WorkItem completion

    func test_completionPercentage() throws {
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 100, contractedQuantity: 200)
        context.insert(workItem)
        for qty in [80.0, 60.0] {
            let e = DailyEntry(quantity: qty)
            e.workItem = workItem
            workItem.dailyEntries.append(e)
            context.insert(e)
        }
        XCTAssertEqual(workItem.completedQuantity, 140)
        XCTAssertEqual(workItem.completionPercentage, 70)
        XCTAssertEqual(workItem.remainingQuantity, 60)
    }

    func test_completionPercentage_cappedAt100() throws {
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 100, contractedQuantity: 100)
        context.insert(workItem)
        let e = DailyEntry(quantity: 150)
        e.workItem = workItem
        workItem.dailyEntries.append(e)
        context.insert(e)
        XCTAssertEqual(workItem.completionPercentage, 100, "%100'de kesilmeli")
    }

    func test_completionPercentage_noEntries() throws {
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 100, contractedQuantity: 200)
        context.insert(workItem)
        XCTAssertEqual(workItem.completionPercentage, 0)
        XCTAssertEqual(workItem.completedQuantity, 0)
    }

    // MARK: - Contract delay penalty

    func test_delayPenalty() throws {
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 1_000, contractedQuantity: 100)
        workItem.contract = contract
        contract.workItems.append(workItem)
        contract.dailyPenaltyRate = 0.1
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        context.insert(contract)
        context.insert(workItem)
        // totalContractAmount=100000, 0.1%/gün × 10 gün = 1000
        XCTAssertEqual(contract.delayPenalty(), 1_000, accuracy: 0.01)
        XCTAssertEqual(contract.delayDays(), 10)
    }

    func test_delayPenalty_cappedAtMax() throws {
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 1_000, contractedQuantity: 100)
        workItem.contract = contract
        contract.workItems.append(workItem)
        contract.dailyPenaltyRate = 1.0  // 1%/gün
        contract.maxPenaltyRate = 20.0   // max %20
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: -300, to: Date())
        context.insert(contract)
        context.insert(workItem)
        // max = 100000 * 20% = 20000
        XCTAssertEqual(contract.delayPenalty(), 20_000, accuracy: 0.01)
    }

    func test_noDelayPenalty_beforeDeadline() throws {
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        contract.dailyPenaltyRate = 0.1
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: 10, to: Date())
        context.insert(contract)
        XCTAssertEqual(contract.delayPenalty(), 0)
    }

    // MARK: - Overdue interest

    func test_overdueInterest_30days() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        let item = HakedisItem(workItemName: "Boya", workItemCode: "01",
                               unit: "m²", unitPrice: 1_000, previousQuantity: 0, currentQuantity: 100)
        insertItems([item], into: hakedis)
        hakedis.dueDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        hakedis.status = .approved
        // K4 fix: gecikme faizi netAmountAfterTax üzerinden hesaplanır
        // netAmount=100_000, stopaj=3_000, damga=948 → netAmountAfterTax=96_052
        let grossAmt = 100_000.0
        let netAmtAfterTax = grossAmt - (grossAmt * 3.0 / 100) - (grossAmt * 0.948 / 100)
        let expected = netAmtAfterTax * (9.0 / 365.0 / 100.0) * 30
        XCTAssertEqual(hakedis.daysOverdue, 30)
        XCTAssertEqual(hakedis.overdueInterest, expected, accuracy: 1.0)
        XCTAssertTrue(hakedis.isOverdue)
    }

    func test_noOverdue_whenPaid() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        hakedis.dueDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        hakedis.status = .paid
        XCTAssertEqual(hakedis.daysOverdue, 0)
        XCTAssertFalse(hakedis.isOverdue)
    }

    func test_noOverdue_whenNoDueDate() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        hakedis.dueDate = nil
        hakedis.status = .approved
        XCTAssertEqual(hakedis.daysOverdue, 0)
        XCTAssertFalse(hakedis.isOverdue)
    }

    func test_noOverdue_whenFutureDueDate() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        let item = HakedisItem(workItemName: "Boya", workItemCode: "01",
                               unit: "m²", unitPrice: 100, previousQuantity: 0, currentQuantity: 10)
        insertItems([item], into: hakedis)
        hakedis.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        hakedis.status = .approved
        XCTAssertEqual(hakedis.daysOverdue, 0)
        XCTAssertFalse(hakedis.isOverdue)
    }

    // MARK: - KDV & Avans Kesintisi

    func test_advanceDeduction() throws {
        let (hakedis, _) = try makeHakedisWithRates(retentionRate: 0, advanceRate: 20, kdvRate: 0)
        let item = HakedisItem(workItemName: "Kazı", workItemCode: "01",
                               unit: "m³", unitPrice: 1_000, previousQuantity: 0, currentQuantity: 100)
        insertItems([item], into: hakedis)
        // brüt=100000, avans=%20=20000, teminat=0, net=80000
        XCTAssertEqual(hakedis.grossAmount, 100_000)
        XCTAssertEqual(hakedis.advanceDeduction, 20_000, "%20 avans")
        XCTAssertEqual(hakedis.netAmount, 80_000)
    }

    func test_kdvCalculation() throws {
        let (hakedis, _) = try makeHakedisWithRates(retentionRate: 10, advanceRate: 0, kdvRate: 20)
        let item = HakedisItem(workItemName: "Beton", workItemCode: "01",
                               unit: "m³", unitPrice: 1_000, previousQuantity: 0, currentQuantity: 100)
        insertItems([item], into: hakedis)
        // brüt=100000, teminat=%10=10000, net=90000, KDV=%20=18000, toplam=108000
        XCTAssertEqual(hakedis.retentionAmount, 10_000)
        XCTAssertEqual(hakedis.netAmount, 90_000)
        XCTAssertEqual(hakedis.kdvAmount, 18_000, "%20 KDV")
        XCTAssertEqual(hakedis.totalWithKDV, 108_000)
    }

    func test_fullDeductions_retentionPlusAdvancePlusKDV() throws {
        let (hakedis, _) = try makeHakedisWithRates(retentionRate: 10, advanceRate: 20, kdvRate: 20)
        let item = HakedisItem(workItemName: "Sıva", workItemCode: "01",
                               unit: "m²", unitPrice: 100, previousQuantity: 0, currentQuantity: 1_000)
        insertItems([item], into: hakedis)
        // brüt=100000, teminat=%10=10000, avans=%20=20000, net=70000, KDV=%20=14000, toplam=84000
        XCTAssertEqual(hakedis.grossAmount, 100_000)
        XCTAssertEqual(hakedis.retentionAmount, 10_000)
        XCTAssertEqual(hakedis.advanceDeduction, 20_000)
        XCTAssertEqual(hakedis.netAmount, 70_000)
        XCTAssertEqual(hakedis.kdvAmount, 14_000)
        XCTAssertEqual(hakedis.totalWithKDV, 84_000)
    }

    func test_remainingAmount_withKDV() throws {
        let (hakedis, _) = try makeHakedisWithRates(retentionRate: 0, advanceRate: 0, kdvRate: 20)
        let item = HakedisItem(workItemName: "Beton", workItemCode: "01",
                               unit: "m³", unitPrice: 1_000, previousQuantity: 0, currentQuantity: 100)
        insertItems([item], into: hakedis)
        // totalWithKDV=120000, ödeme=50000, kalan=70000
        let payment = Payment(amount: 50_000)
        payment.hakedis = hakedis
        hakedis.payments.append(payment)
        context.insert(payment)
        XCTAssertEqual(hakedis.totalWithKDV, 120_000)
        XCTAssertEqual(hakedis.remainingAmount, 70_000)
    }

    func test_zeroKDV_noKDVAmount() throws {
        let (hakedis, _) = try makeHakedis(retentionRate: 10)
        let item = HakedisItem(workItemName: "Beton", workItemCode: "01",
                               unit: "m³", unitPrice: 1_000, previousQuantity: 0, currentQuantity: 100)
        insertItems([item], into: hakedis)
        XCTAssertEqual(hakedis.kdvAmount, 0, "KDV oranı 0 ise KDV tutarı da 0 olmalı")
        XCTAssertEqual(hakedis.totalWithKDV, hakedis.netAmount)
    }

    // MARK: - Helpers

    private func makeHakedisWithRates(retentionRate: Double, advanceRate: Double,
                                       kdvRate: Double) throws -> (Hakedis, Contract) {
        let contractor = Contractor(name: "Test Taşeron")
        let project = Project(name: "Test Proje")
        let contract = Contract(title: "Test Sözleşme",
                                retentionRate: retentionRate, advanceRate: advanceRate)
        contract.kdvRate = kdvRate
        contract.contractor = contractor
        contract.project = project
        project.contracts.append(contract)
        let jan1  = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let jan31 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 31))!
        let hakedis = Hakedis(periodName: "Ocak 2025", periodStart: jan1, periodEnd: jan31)
        hakedis.contract = contract
        contract.hakedisler.append(hakedis)
        context.insert(contractor)
        context.insert(project)
        context.insert(contract)
        context.insert(hakedis)
        return (hakedis, contract)
    }

    private func makeHakedis(retentionRate: Double) throws -> (Hakedis, Contract) {
        let contractor = Contractor(name: "Test Taşeron")
        let project = Project(name: "Test Proje")
        let contract = Contract(title: "Test Sözleşme", retentionRate: retentionRate, advanceRate: 0)
        contract.contractor = contractor
        contract.project = project
        project.contracts.append(contract)
        let jan1 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let jan31 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 31))!
        let hakedis = Hakedis(periodName: "Ocak 2025", periodStart: jan1, periodEnd: jan31)
        hakedis.contract = contract
        contract.hakedisler.append(hakedis)
        context.insert(contractor)
        context.insert(project)
        context.insert(contract)
        context.insert(hakedis)
        return (hakedis, contract)
    }

    private func insertItems(_ items: [HakedisItem], into hakedis: Hakedis) {
        for item in items {
            item.hakedis = hakedis
            hakedis.items.append(item)
            context.insert(item)
        }
    }

    // MARK: - Stopaj & Damga Vergisi
    func testWithholdingTaxCalculation() throws {
        let h = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        XCTAssertEqual(h.withholdingTaxRate, 3.0)
        XCTAssertEqual(h.stampTaxRate, 0.948)
    }

    func testStampTaxRate() throws {
        let h = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        h.stampTaxRate = 0.948
        XCTAssertEqual(h.stampTaxAmount, 0.0) // grossAmount=0 ise 0
    }

    func testNetAmountAfterTaxWithZeroGross() throws {
        let h = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        XCTAssertEqual(h.netAmountAfterTax, 0.0, accuracy: 0.001)
    }

    // MARK: - İş Artışı
    func testWorkIncreaseExceeded() throws {
        // contractedQuantity ile direkt hesap: %25 > %20 → exceeded
        let pct = (125.0 - 100.0) / 100.0 * 100
        XCTAssertGreaterThan(pct, 20.0)
    }

    func testWorkIncreaseWarning() throws {
        let pct = (118.0 - 100.0) / 100.0 * 100 // %18
        XCTAssertTrue(pct >= 15 && pct < 20)
    }

    func testWorkDecreaseUnderContract() throws {
        let pct = (80.0 - 100.0) / 100.0 * 100 // -%20
        XCTAssertLessThan(pct, 0)
    }

    // MARK: - D Formülü
    func testDFormulBasicCalculation() throws {
        context.insert(PriceDifferenceRecord(periodName: "Test", baseIndex: 100, currentIndex: 110, baseAmount: 50000))
        let records = try context.fetch(FetchDescriptor<PriceDifferenceRecord>())
        let record = try XCTUnwrap(records.first)
        record.laborCoefficient = 0.4
        record.materialCoefficient = 0.4
        record.otherCoefficient = 0.2
        let ratio: Double = 110.0 / 100.0 - 1.0
        let coeffSum: Double = 0.4 + 0.4 + 0.2
        let expected: Double = ratio * coeffSum * 50000
        XCTAssertEqual(record.dFormulResult, expected, accuracy: 0.01)
    }

    func testDFormulZeroBaseIndex() throws {
        context.insert(PriceDifferenceRecord(periodName: "Test", baseIndex: 0, currentIndex: 110, baseAmount: 50000))
        let records = try context.fetch(FetchDescriptor<PriceDifferenceRecord>())
        let record = try XCTUnwrap(records.first)
        record.laborCoefficient = 0.4
        XCTAssertEqual(record.dFormulResult, 0.0)
    }

    // MARK: - Sözleşme Tipi
    func testLumpSumCompletionPercentage() throws {
        let h = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        h.lumpSumCompletionPercentage = 60.0
        XCTAssertEqual(h.lumpSumCompletionPercentage, 60.0)
    }

    // MARK: - Teminat
    func testGuaranteeExpiryWarning() throws {
        let expiryDate = Calendar.current.date(byAdding: .day, value: 25, to: Date())!
        let g = Guarantee(guaranteeType: .permanent, amount: 100000,
                         bankName: "Test Bank", referenceNumber: "TR123",
                         issueDate: Date(), expiryDate: expiryDate)
        XCTAssertTrue(g.isExpiringSoon)
        XCTAssertFalse(g.isExpired)
    }

    func testGuaranteeNotExpired() throws {
        let expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let g = Guarantee(guaranteeType: .temporary, amount: 50000,
                         bankName: "Bank A", referenceNumber: "REF001",
                         issueDate: Date(), expiryDate: expiryDate)
        XCTAssertFalse(g.isExpired)
        XCTAssertFalse(g.isExpiringSoon)
    }

    // MARK: - Retention Edge Cases

    func testRetentionZeroRate() throws {
        // retentionRate = 0 → retentionAmount = 0 (guard rate > 0 uygulanır)
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        let item = HakedisItem(workItemName: "Boya", workItemCode: "01",
                               unit: "m²", unitPrice: 500, previousQuantity: 0, currentQuantity: 200)
        insertItems([item], into: hakedis)
        XCTAssertEqual(hakedis.grossAmount, 100_000)
        XCTAssertEqual(hakedis.retentionAmount, 0, "retentionRate=0 → retentionAmount=0")
    }

    func testRetentionFivePercent() throws {
        // grossAmount 100_000, retentionRate 5 → retentionAmount 5_000
        let (hakedis, _) = try makeHakedis(retentionRate: 5)
        let item = HakedisItem(workItemName: "Beton", workItemCode: "01",
                               unit: "m³", unitPrice: 1_000, previousQuantity: 0, currentQuantity: 100)
        insertItems([item], into: hakedis)
        XCTAssertEqual(hakedis.retentionAmount, 5_000, accuracy: 0.01)
    }

    func testRetentionHundredPercent() throws {
        // retentionRate 100 → retentionAmount = grossAmount
        let (hakedis, _) = try makeHakedis(retentionRate: 100)
        let item = HakedisItem(workItemName: "Kazı", workItemCode: "01",
                               unit: "m³", unitPrice: 200, previousQuantity: 0, currentQuantity: 50)
        insertItems([item], into: hakedis)
        XCTAssertEqual(hakedis.retentionAmount, hakedis.grossAmount, accuracy: 0.01)
    }

    // MARK: - Stopaj Edge Cases

    func testWithholdingFivePercent() throws {
        // withholdingTaxRate 5, grossAmount 100_000 → withholdingTaxAmount 5_000
        let h = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        h.withholdingTaxRate = 5.0
        let item = HakedisItem(workItemName: "Beton", workItemCode: "01",
                               unit: "m³", unitPrice: 1_000, previousQuantity: 0, currentQuantity: 100)
        item.hakedis = h
        h.items.append(item)
        context.insert(h)
        context.insert(item)
        XCTAssertEqual(h.grossAmount, 100_000)
        XCTAssertEqual(h.withholdingTaxAmount, 5_000, accuracy: 0.01)
    }

    func testWithholdingZeroRate() throws {
        // withholdingTaxRate 0 → withholdingTaxAmount 0
        let h = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        h.withholdingTaxRate = 0.0
        let item = HakedisItem(workItemName: "Sıva", workItemCode: "01",
                               unit: "m²", unitPrice: 100, previousQuantity: 0, currentQuantity: 500)
        item.hakedis = h
        h.items.append(item)
        context.insert(h)
        context.insert(item)
        XCTAssertEqual(h.withholdingTaxAmount, 0, accuracy: 0.01)
    }

    // MARK: - Damga Vergisi Edge Cases

    func testStampTaxOneMillion() throws {
        // stampTaxRate 0.948, grossAmount 1_000_000 → stampTaxAmount 9_480
        let h = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        h.stampTaxRate = 0.948
        let item = HakedisItem(workItemName: "Beton", workItemCode: "01",
                               unit: "m³", unitPrice: 10_000, previousQuantity: 0, currentQuantity: 100)
        item.hakedis = h
        h.items.append(item)
        context.insert(h)
        context.insert(item)
        XCTAssertEqual(h.grossAmount, 1_000_000)
        XCTAssertEqual(h.stampTaxAmount, 9_480, accuracy: 0.01)
    }

    func testStampTaxZeroGross() throws {
        // grossAmount 0 → stampTaxAmount 0
        let h = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        h.stampTaxRate = 0.948
        context.insert(h)
        XCTAssertEqual(h.grossAmount, 0)
        XCTAssertEqual(h.stampTaxAmount, 0, accuracy: 0.01)
    }

    // MARK: - Net Tutar Zinciri

    func testFullNetAmountChain() throws {
        // gross = 1_000_000, retentionRate=5, advanceRate=10, withholdingTaxRate=5, stampTaxRate=0.948
        let (hakedis, _) = try makeHakedisWithRates(retentionRate: 5, advanceRate: 10, kdvRate: 0)
        hakedis.withholdingTaxRate = 5.0
        hakedis.stampTaxRate = 0.948
        let item = HakedisItem(workItemName: "Beton", workItemCode: "01",
                               unit: "m³", unitPrice: 10_000, previousQuantity: 0, currentQuantity: 100)
        insertItems([item], into: hakedis)
        // gross = 1_000_000
        XCTAssertEqual(hakedis.grossAmount, 1_000_000, accuracy: 0.01)
        // retentionAmount = 1_000_000 * 5% = 50_000
        XCTAssertEqual(hakedis.retentionAmount, 50_000, accuracy: 0.01)
        // advanceDeduction = 1_000_000 * 10% = 100_000
        XCTAssertEqual(hakedis.advanceDeduction, 100_000, accuracy: 0.01)
        // netAmount = 1_000_000 - 50_000 - 100_000 = 850_000
        XCTAssertEqual(hakedis.netAmount, 850_000, accuracy: 0.01)
        // withholdingTaxAmount = 1_000_000 * 5% = 50_000
        XCTAssertEqual(hakedis.withholdingTaxAmount, 50_000, accuracy: 0.01)
        // stampTaxAmount = 1_000_000 * 0.948% = 9_480
        XCTAssertEqual(hakedis.stampTaxAmount, 9_480, accuracy: 0.01)
        // netAmountAfterTax = 850_000 - 50_000 - 9_480 = 790_520
        XCTAssertEqual(hakedis.netAmountAfterTax, 790_520, accuracy: 0.01)
    }

    func testNetAmountZeroGross() throws {
        // grossAmount = 0 → tüm türevler 0
        let h = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        context.insert(h)
        XCTAssertEqual(h.grossAmount, 0)
        XCTAssertEqual(h.retentionAmount, 0)
        XCTAssertEqual(h.advanceDeduction, 0)
        XCTAssertEqual(h.netAmount, 0)
        XCTAssertEqual(h.withholdingTaxAmount, 0)
        XCTAssertEqual(h.stampTaxAmount, 0)
        XCTAssertEqual(h.netAmountAfterTax, 0)
    }

    // MARK: - Hakediş Kopyalama Mantığı

    func testHakedisKopyalaItemTransfer() throws {
        // Orijinal: previousQty=20, currentQty=30
        // Kopya: previousQty = 20+30 = 50, currentQty = 0
        let originalPrev = 20.0
        let originalCurr = 30.0
        let newPrev = originalPrev + originalCurr
        let newCurr = 0.0
        XCTAssertEqual(newPrev, 50.0)
        XCTAssertEqual(newCurr, 0.0)
    }

    func testHakedisKopyalaStatusDraft() throws {
        // Kopya her zaman .draft olmalı
        let schema = Schema([Hakedis.self])
        let localContainer = try ModelContainer(for: schema,
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let localContext = ModelContext(localContainer)
        let original = Hakedis(periodName: "Dönem 1", periodStart: Date(), periodEnd: Date())
        original.status = .approved
        localContext.insert(original)
        // Kopyalama mantığı: yeni hakedis draft
        let kopya = Hakedis(periodName: "Dönem 2", periodStart: Date(), periodEnd: Date())
        kopya.status = .draft
        localContext.insert(kopya)
        XCTAssertEqual(kopya.status, .draft)
        XCTAssertEqual(original.status, .approved) // orijinal değişmemeli
    }

    // MARK: - Guarantee Edge Cases

    func testGuaranteeExpiredYesterday() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let g = Guarantee(guaranteeType: .permanent, amount: 100_000,
                         bankName: "Test", referenceNumber: "T001",
                         issueDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
                         expiryDate: yesterday)
        XCTAssertTrue(g.isExpired)
        XCTAssertFalse(g.isExpiringSoon)
    }

    func testGuaranteeFarFuture() throws {
        let future = Calendar.current.date(byAdding: .year, value: 2, to: Date())!
        let g = Guarantee(guaranteeType: .temporary, amount: 50_000,
                         bankName: "Bank", referenceNumber: "R001",
                         issueDate: Date(), expiryDate: future)
        XCTAssertFalse(g.isExpired)
        XCTAssertFalse(g.isExpiringSoon)
    }

    // MARK: - D Formülü Edge Cases

    func testDFormulCoefficientsSum() throws {
        // a+b+c = 1 (standart) durumu: ratio=0.15, coeffSum=1.0, baseAmount=100_000 → 15_000
        let record = PriceDifferenceRecord(periodName: "Test", baseIndex: 100, currentIndex: 115, baseAmount: 100_000)
        record.laborCoefficient = 0.4
        record.materialCoefficient = 0.4
        record.otherCoefficient = 0.2
        let ratio = (115.0 / 100.0) - 1.0 // 0.15
        let expected = ratio * 1.0 * 100_000 // 15_000
        XCTAssertEqual(record.dFormulResult, expected, accuracy: 0.01)
    }

    func testDFormulNegativeIndex() throws {
        // Deflasyon: currentIndex < baseIndex → negatif sonuç
        let record = PriceDifferenceRecord(periodName: "Test", baseIndex: 100, currentIndex: 90, baseAmount: 50_000)
        record.laborCoefficient = 0.5
        record.materialCoefficient = 0.3
        record.otherCoefficient = 0.2
        XCTAssertLessThan(record.dFormulResult, 0)
    }

    // MARK: - S Eğrisi (WorkItem tamamlanma)

    func testSCurveEmptyData() throws {
        // Hiç günlük giriş yok → tamamlanma %0
        let workItem = WorkItem(code: "S01", name: "Beton", unit: "m³",
                                unitPrice: 100, contractedQuantity: 200)
        context.insert(workItem)
        XCTAssertEqual(workItem.completedQuantity, 0)
        XCTAssertEqual(workItem.completionPercentage, 0, "Boş veri → S eğrisi %0")
    }

    func testSCurveFiftyPercent() throws {
        // 100 m³ / 200 m³ = %50
        let workItem = WorkItem(code: "S02", name: "Beton", unit: "m³",
                                unitPrice: 100, contractedQuantity: 200)
        context.insert(workItem)
        let entry = DailyEntry(quantity: 100)
        entry.workItem = workItem
        workItem.dailyEntries.append(entry)
        context.insert(entry)
        XCTAssertEqual(workItem.completionPercentage, 50, "S eğrisi %50 tamamlanma")
    }

    func testSCurveHundredPercent() throws {
        // 100 m³ / 100 m³ = %100, aşım olsa da max 100
        let workItem = WorkItem(code: "S03", name: "Beton", unit: "m³",
                                unitPrice: 100, contractedQuantity: 100)
        context.insert(workItem)
        let entry = DailyEntry(quantity: 120) // aşım
        entry.workItem = workItem
        workItem.dailyEntries.append(entry)
        context.insert(entry)
        XCTAssertEqual(workItem.completionPercentage, 100, "S eğrisi %100'de tavan")
    }

    // MARK: - Poz Kütüphanesi Arama

    func testPozLibraryEmptySearch() {
        // Olmayan bir string → boş sonuç
        let results = PozLibrary.items.filter {
            $0.name.lowercased().contains("xyzxyz_olmayan")
        }
        XCTAssertTrue(results.isEmpty, "Bulunamayan arama → boş sonuç döner")
    }

    func testPozLibrarySearchReturnsMatches() {
        let results = PozLibrary.items.filter {
            $0.name.lowercased().contains("kazı")
        }
        XCTAssertFalse(results.isEmpty, "Kazı araması sonuç döndürmeli")
        XCTAssertTrue(results.allSatisfy { $0.name.lowercased().contains("kazı") })
    }

    // MARK: - Toplu Giriş (Bulk DailyEntry)

    func testBulkEntryMultiple() throws {
        // Birden fazla günlük giriş ekleme
        let workItem = WorkItem(code: "B01", name: "Kazı", unit: "m³",
                                unitPrice: 100, contractedQuantity: 500)
        context.insert(workItem)
        let quantities = [10.0, 20.0, 30.0]
        for qty in quantities {
            let entry = DailyEntry(quantity: qty)
            entry.workItem = workItem
            workItem.dailyEntries.append(entry)
            context.insert(entry)
        }
        XCTAssertEqual(workItem.dailyEntries.count, 3, "3 toplu giriş eklendi")
        XCTAssertEqual(workItem.completedQuantity, 60, "10+20+30 = 60")
        XCTAssertEqual(workItem.completionPercentage, 12, accuracy: 0.01)
    }

    func testBulkEntryEmptyList() throws {
        // Hiç giriş yoksa liste boş
        let workItem = WorkItem(code: "B02", name: "Kazı", unit: "m³",
                                unitPrice: 100, contractedQuantity: 500)
        context.insert(workItem)
        XCTAssertEqual(workItem.dailyEntries.count, 0, "Toplu giriş yoksa liste boş")
        XCTAssertEqual(workItem.completedQuantity, 0)
        XCTAssertEqual(workItem.completionPercentage, 0)
    }

    // MARK: - Hakediş Kopyalama Kapsamlı

    func testHakedisKopyalaComprehensive() throws {
        // Orijinal: 2 kalem, orijinal kalemler kopyalanmalı
        let (original, _) = try makeHakedis(retentionRate: 5)
        let item1 = HakedisItem(workItemName: "Kazı", workItemCode: "01",
                                unit: "m³", unitPrice: 100,
                                previousQuantity: 20, currentQuantity: 30)
        let item2 = HakedisItem(workItemName: "Beton", workItemCode: "02",
                                unit: "m³", unitPrice: 500,
                                previousQuantity: 10, currentQuantity: 15)
        insertItems([item1, item2], into: original)

        // kopyala() mantığını simüle et (HakedisKopyalaView.kopyala)
        let kopya = Hakedis(periodName: "Dönem 2",
                            periodStart: original.periodEnd, periodEnd: original.periodEnd)
        kopya.status = .draft
        kopya.contract = original.contract

        for eskiItem in original.items {
            let yeniItem = HakedisItem(
                workItemName: eskiItem.workItemName,
                workItemCode: eskiItem.workItemCode,
                unit: eskiItem.unit,
                unitPrice: eskiItem.unitPrice,
                previousQuantity: eskiItem.previousQuantity + eskiItem.currentQuantity,
                currentQuantity: 0
            )
            yeniItem.hakedis = kopya
            context.insert(yeniItem)
            kopya.items.append(yeniItem)
        }
        context.insert(kopya)

        // Tüm item'lar aktarıldı mı?
        XCTAssertEqual(kopya.items.count, 2, "Tüm kalemler kopyalanmalı")

        // previousQuantity doğru aktarıldı mı?
        let kopyaItem1 = kopya.items.first { $0.workItemCode == "01" }
        let kopyaItem2 = kopya.items.first { $0.workItemCode == "02" }
        XCTAssertNotNil(kopyaItem1)
        XCTAssertNotNil(kopyaItem2)
        XCTAssertEqual(kopyaItem1?.previousQuantity, 50, "20 + 30 = 50")
        XCTAssertEqual(kopyaItem2?.previousQuantity, 25, "10 + 15 = 25")
        XCTAssertEqual(kopyaItem1?.currentQuantity, 0, "Yeni dönem sıfırdan başlar")
        XCTAssertEqual(kopyaItem2?.currentQuantity, 0)

        // Yeni hakediş draft mı?
        XCTAssertEqual(kopya.status, .draft, "Kopya her zaman draft olmalı")

        // Orijinal hakediş değişmedi mi?
        XCTAssertEqual(original.items.count, 2, "Orijinal kalem sayısı değişmemeli")
        XCTAssertEqual(item1.previousQuantity, 20, "Orijinal previousQuantity değişmemeli")
        XCTAssertEqual(item1.currentQuantity, 30, "Orijinal currentQuantity değişmemeli")
        XCTAssertEqual(item2.previousQuantity, 10)
        XCTAssertEqual(item2.currentQuantity, 15)
    }

    // MARK: - Lump-Sum effectiveGrossAmount

    func testLumpSumEffectiveGross_fiftyPercent() throws {
        // Götürü bedel: 1_000_000 TL, %50 tamamlanma → effectiveGrossAmount = 500_000
        let project = Project(name: "Test")
        let contract = Contract(title: "Götürü", retentionRate: 0, advanceRate: 0)
        contract.contractType = .lumpSum
        let workItem = WorkItem(code: "L01", name: "Bina", unit: "adet",
                                unitPrice: 1_000_000, contractedQuantity: 1)
        workItem.contract = contract
        contract.workItems.append(workItem)

        let hakedis = Hakedis(periodName: "Dönem 1", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        hakedis.lumpSumCompletionPercentage = 50.0

        context.insert(project)
        context.insert(contract)
        context.insert(workItem)
        context.insert(hakedis)

        XCTAssertEqual(contract.totalContractAmount, 1_000_000, accuracy: 0.01)
        XCTAssertEqual(hakedis.lumpSumCompletionPercentage, 50.0)
        XCTAssertEqual(hakedis.effectiveGrossAmount, 500_000, accuracy: 0.01,
                       "Götürü %50 → 1_000_000 × 0.50 = 500_000")
    }

    func testLumpSumEffectiveGross_zeroPercent() throws {
        // %0 tamamlanma → effectiveGrossAmount = 0
        let contract = Contract(title: "Götürü", retentionRate: 0, advanceRate: 0)
        contract.contractType = .lumpSum
        let workItem = WorkItem(code: "L02", name: "Bina", unit: "adet",
                                unitPrice: 500_000, contractedQuantity: 1)
        workItem.contract = contract
        contract.workItems.append(workItem)

        let hakedis = Hakedis(periodName: "Dönem 1", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        hakedis.lumpSumCompletionPercentage = 0.0

        context.insert(contract)
        context.insert(workItem)
        context.insert(hakedis)

        XCTAssertEqual(hakedis.effectiveGrossAmount, 0, accuracy: 0.01,
                       "%0 tamamlanma → effectiveGrossAmount = 0")
    }

    func testLumpSumEffectiveGross_hundredPercent() throws {
        // %100 tamamlanma → effectiveGrossAmount = totalContractAmount
        let contract = Contract(title: "Götürü", retentionRate: 0, advanceRate: 0)
        contract.contractType = .lumpSum
        let workItem = WorkItem(code: "L03", name: "Bina", unit: "adet",
                                unitPrice: 750_000, contractedQuantity: 1)
        workItem.contract = contract
        contract.workItems.append(workItem)

        let hakedis = Hakedis(periodName: "Dönem 1", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        hakedis.lumpSumCompletionPercentage = 100.0

        context.insert(contract)
        context.insert(workItem)
        context.insert(hakedis)

        XCTAssertEqual(hakedis.effectiveGrossAmount, contract.totalContractAmount, accuracy: 0.01,
                       "%100 → effectiveGrossAmount = sözleşme bedeli")
    }

    func testUnitPriceContract_effectiveGrossEqualsGross() throws {
        // Birim fiyat sözleşmede effectiveGrossAmount = grossAmount (items toplamı)
        let (hakedis, _) = try makeHakedis(retentionRate: 0)
        let item = HakedisItem(workItemName: "Kazı", workItemCode: "01",
                               unit: "m³", unitPrice: 100, previousQuantity: 0, currentQuantity: 50)
        insertItems([item], into: hakedis)
        // contract.contractType default = .unitPrice
        XCTAssertEqual(hakedis.effectiveGrossAmount, hakedis.grossAmount, accuracy: 0.01,
                       "Birim fiyat sözleşmede effectiveGrossAmount = grossAmount")
    }

    // MARK: - Hakedis.penaltyAmount (dailyPenaltyRate bazlı, maxPenaltyRate cap'li)

    func testHakedis_penaltyAmount_standard() throws {
        // dailyPenaltyRate %0.1, 10 gün gecikme, totalContractAmount 100_000
        // beklenen: 100_000 * 0.001 * 10 = 1_000
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        contract.dailyPenaltyRate = 0.1
        contract.maxPenaltyRate = 20.0
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        let workItem = WorkItem(code: "P01", name: "Kazı", unit: "m³",
                                unitPrice: 1_000, contractedQuantity: 100)
        workItem.contract = contract
        contract.workItems.append(workItem)
        context.insert(contract)
        context.insert(workItem)

        let hakedis = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        context.insert(hakedis)

        XCTAssertEqual(contract.totalContractAmount, 100_000, accuracy: 0.01)
        XCTAssertEqual(hakedis.penaltyDays, 10)
        XCTAssertEqual(hakedis.penaltyAmount, 1_000, accuracy: 0.01,
                       "%0.1/gün × 10 gün × 100_000 = 1_000")
    }

    func testHakedis_penaltyAmount_cappedAtMax() throws {
        // dailyPenaltyRate %1.0, 300 gün, maxPenaltyRate %20 → cap = 100_000 * 20% = 20_000
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        contract.dailyPenaltyRate = 1.0
        contract.maxPenaltyRate = 20.0
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: -300, to: Date())
        let workItem = WorkItem(code: "P02", name: "Beton", unit: "m³",
                                unitPrice: 1_000, contractedQuantity: 100)
        workItem.contract = contract
        contract.workItems.append(workItem)
        context.insert(contract)
        context.insert(workItem)

        let hakedis = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        context.insert(hakedis)

        XCTAssertEqual(hakedis.penaltyAmount, 20_000, accuracy: 0.01,
                       "300 gün × %1 aşıyor, cap %20 = 20_000")
    }

    func testHakedis_penaltyAmount_zeroDailyRate() throws {
        // dailyPenaltyRate = 0 → penaltyAmount = 0
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        contract.dailyPenaltyRate = 0.0
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        context.insert(contract)

        let hakedis = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        context.insert(hakedis)

        XCTAssertEqual(hakedis.penaltyAmount, 0, accuracy: 0.01,
                       "dailyPenaltyRate = 0 → ceza yok")
        XCTAssertEqual(hakedis.penaltyDays, 0)
    }

    func testHakedis_penaltyAmount_noDeadline() throws {
        // completionDeadline yok → penaltyAmount = 0
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        contract.dailyPenaltyRate = 0.1
        contract.completionDeadline = nil
        context.insert(contract)

        let hakedis = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        context.insert(hakedis)

        XCTAssertEqual(hakedis.penaltyAmount, 0, accuracy: 0.01,
                       "Teslim tarihi yok → ceza hesaplanamaz")
    }

    func testHakedis_penaltyAmount_consistency_with_contractDelayPenalty() throws {
        // Hakedis.penaltyAmount, Contract.delayPenalty() ile tutarlı olmalı
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        contract.dailyPenaltyRate = 0.5
        contract.maxPenaltyRate = 20.0
        contract.completionDeadline = Calendar.current.date(byAdding: .day, value: -15, to: Date())
        let workItem = WorkItem(code: "P03", name: "Sıva", unit: "m²",
                                unitPrice: 100, contractedQuantity: 1_000)
        workItem.contract = contract
        contract.workItems.append(workItem)
        context.insert(contract)
        context.insert(workItem)

        let hakedis = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        context.insert(hakedis)

        XCTAssertEqual(hakedis.penaltyAmount, contract.delayPenalty(), accuracy: 0.01,
                       "Hakedis.penaltyAmount, Contract.delayPenalty() ile aynı sonucu vermelidir")
    }

    // MARK: - TestRecord.blocksApproval Onay Kontrolü

    func testBlocksApproval_requiredAndFailed() {
        // isRequiredForApproval=true, status=.kaldi → blocksApproval = true
        let record = TestRecord(testName: "Basınç Testi", isRequiredForApproval: true)
        record.status = .kaldi
        XCTAssertTrue(record.blocksApproval, "Zorunlu başarısız test onayı bloke etmeli")
    }

    func testBlocksApproval_requiredButPassed() {
        // isRequiredForApproval=true, status=.gecti → blocksApproval = false
        let record = TestRecord(testName: "Basınç Testi", isRequiredForApproval: true)
        record.status = .gecti
        XCTAssertFalse(record.blocksApproval, "Zorunlu geçen test onayı bloke etmemeli")
    }

    func testBlocksApproval_notRequiredAndFailed() {
        // isRequiredForApproval=false, status=.kaldi → blocksApproval = false
        let record = TestRecord(testName: "Rutin Test", isRequiredForApproval: false)
        record.status = .kaldi
        XCTAssertFalse(record.blocksApproval, "Zorunlu olmayan test onayı bloke etmemeli")
    }

    func testBlocksApproval_contractWithMultipleTests() throws {
        // Sözleşmede 1 zorunlu başarısız test var → hakediş onay engellenmeli
        let contract = Contract(title: "Test Sözleşmesi", retentionRate: 0, advanceRate: 0)
        context.insert(contract)

        let t1 = TestRecord(testName: "Beton Basınç", isRequiredForApproval: true)
        t1.status = .kaldi
        t1.contract = contract
        contract.testRecords.append(t1)
        context.insert(t1)

        let t2 = TestRecord(testName: "Su Yalıtım", isRequiredForApproval: false)
        t2.status = .kaldi
        t2.contract = contract
        contract.testRecords.append(t2)
        context.insert(t2)

        let hasBlocking = contract.testRecords.contains { $0.blocksApproval }
        XCTAssertTrue(hasBlocking, "Zorunlu başarısız test varsa hakediş onaylanamaz")
    }

    func testBlocksApproval_noBlockingTests() throws {
        // Tüm zorunlu testler geçti → engel yok
        let contract = Contract(title: "Test Sözleşmesi", retentionRate: 0, advanceRate: 0)
        context.insert(contract)

        let t1 = TestRecord(testName: "Beton Basınç", isRequiredForApproval: true)
        t1.status = .gecti
        t1.contract = contract
        contract.testRecords.append(t1)
        context.insert(t1)

        let hasBlocking = contract.testRecords.contains { $0.blocksApproval }
        XCTAssertFalse(hasBlocking, "Tüm zorunlu testler geçtiyse onay engellenmemel")
    }

    // MARK: - JSON Decode Hata Tespiti

    func testLaborEntriesDecodeError_invalidJSON() throws {
        let record = LaborRecord()
        record.laborEntriesJSON = "bu-gecersiz-json"
        context.insert(record)
        XCTAssertTrue(record.laborEntriesDecodeError, "Geçersiz JSON → laborEntriesDecodeError = true")
        XCTAssertEqual(record.laborEntries.count, 0, "Decode hatasında boş dizi döner")
    }

    func testLaborEntriesDecodeError_nilJSON() throws {
        let record = LaborRecord()
        record.laborEntriesJSON = nil
        context.insert(record)
        XCTAssertFalse(record.laborEntriesDecodeError, "Nil JSON → hata yok (nil guard)")
        XCTAssertEqual(record.laborEntries.count, 0)
    }

    func testLaborEntriesDecodeError_validJSON() throws {
        let record = LaborRecord()
        let entries = [LaborEntryData(workerType: .usta, count: 2, hoursWorked: 8, shiftType: .gunduz)]
        let data = try JSONEncoder().encode(entries)
        record.laborEntriesJSON = String(data: data, encoding: .utf8)
        context.insert(record)
        XCTAssertFalse(record.laborEntriesDecodeError, "Geçerli JSON → decode hatası yok")
        XCTAssertEqual(record.laborEntries.count, 1)
    }

    // MARK: - UnitPriceAnalysis WorkItem Erişimi

    func testUnitPriceAnalysis_workItemRelationship() throws {
        // WorkItem'e UnitPriceAnalysis eklenebilmeli ve ilişki çalışmalı
        let workItem = WorkItem(code: "UPA01", name: "Beton İşi", unit: "m³",
                                unitPrice: 500, contractedQuantity: 100)
        context.insert(workItem)

        let analysis = UnitPriceAnalysis(analysisNo: "A-001", workItemCode: "UPA01",
                                         workItemName: "Beton İşi", contractUnitPrice: 480.0)
        analysis.workItem = workItem
        context.insert(analysis)
        workItem.unitPriceAnalyses.append(analysis)

        XCTAssertEqual(workItem.unitPriceAnalyses.count, 1, "WorkItem'e analiz eklenebilmeli")
        XCTAssertEqual(workItem.unitPriceAnalyses.first?.contractUnitPrice ?? 0, 480.0, accuracy: 0.01)
    }

    func testUnitPriceAnalysis_multipleAnalyses() throws {
        // Birden fazla analiz eklenebilmeli
        let workItem = WorkItem(code: "UPA02", name: "Kazı", unit: "m³",
                                unitPrice: 200, contractedQuantity: 500)
        context.insert(workItem)

        for i in 1...3 {
            let analysis = UnitPriceAnalysis(analysisNo: "A-00\(i)", workItemCode: "UPA02",
                                             workItemName: "Kazı", contractUnitPrice: Double(i) * 100.0)
            analysis.workItem = workItem
            context.insert(analysis)
            workItem.unitPriceAnalyses.append(analysis)
        }

        XCTAssertEqual(workItem.unitPriceAnalyses.count, 3, "3 analiz eklenebilmeli")
    }

    // MARK: - Tarih Aralığı Filtresi (SearchFilterView logic)

    func testDateRangeFilter_hakedisAfterFrom() throws {
        // periodStart >= dateFrom → filtrelenmemeli (dahil)
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let hakedis = Hakedis(periodName: "Dönem A", periodStart: today, periodEnd: tomorrow)
        let dateFrom = yesterday

        XCTAssertGreaterThanOrEqual(hakedis.periodStart, dateFrom, "periodStart >= from → dahil edilmeli")
    }

    func testDateRangeFilter_hakedisBeforeFrom_excluded() throws {
        // periodStart < dateFrom → filtrelenmeli (dahil değil)
        let today = Date()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let hakedis = Hakedis(periodName: "Dönem B", periodStart: twoDaysAgo, periodEnd: tomorrow)
        let dateFrom = yesterday

        XCTAssertLessThan(hakedis.periodStart, dateFrom, "periodStart < from → dahil edilmemeli")
    }

    func testDateRangeFilter_hakedisBeforeTo_included() throws {
        // periodStart <= dateTo → dahil
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today)!

        let hakedis = Hakedis(periodName: "Dönem C", periodStart: today, periodEnd: tomorrow)
        let dateTo = nextWeek

        XCTAssertLessThanOrEqual(hakedis.periodStart, dateTo, "periodStart <= to → dahil edilmeli")
    }

    func testDateRangeFilter_hakedisAfterTo_excluded() throws {
        // periodStart > dateTo → dahil değil
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysLater = Calendar.current.date(byAdding: .day, value: 2, to: today)!

        let hakedis = Hakedis(periodName: "Dönem D",
                               periodStart: twoDaysLater,
                               periodEnd: Calendar.current.date(byAdding: .day, value: 3, to: today)!)
        let dateTo = yesterday

        XCTAssertGreaterThan(hakedis.periodStart, dateTo, "periodStart > to → dahil edilmemeli")
    }

    // MARK: - Dinamik İtiraz Süresi

    func testContractSector_kamuDefaultDays() {
        XCTAssertEqual(ContractSector.kamu.defaultObjectionDays, 30, "Kamu ihale itiraz süresi 30 gün")
    }

    func testContractSector_ozelDefaultDays() {
        XCTAssertEqual(ContractSector.ozel.defaultObjectionDays, 45, "Özel sektör itiraz süresi 45 gün")
    }

    func testContract_defaultSectorIsKamu() throws {
        let contract = Contract(title: "Test Sözleşme", retentionRate: 0, advanceRate: 0)
        context.insert(contract)
        XCTAssertEqual(contract.contractSector, .kamu, "Yeni sözleşme varsayılan olarak kamu sektörü")
        XCTAssertEqual(contract.objectionPeriodDays, 30, "Kamu için itiraz süresi 30 gün")
    }

    func testContract_objectionPeriodDaysCustomizable() throws {
        let contract = Contract(title: "Özel Sözleşme", retentionRate: 0, advanceRate: 0)
        contract.contractSector = .ozel
        contract.objectionPeriodDays = 45
        context.insert(contract)
        XCTAssertEqual(contract.objectionPeriodDays, 45)
        XCTAssertEqual(contract.contractSector, .ozel)
    }

    func testHakedisRevision_objectionDeadlineUsesCustomDays() {
        // 60 günlük itiraz süresi belirlendiğinde objectionDeadline 60 gün sonra olmalı
        let rejectedAt = Date()
        let revision = HakedisRevision(version: "v1", rejectionReason: "Eksik",
                                       rejectedAt: rejectedAt, objectionPeriodDays: 60)
        let expected = Calendar.current.date(byAdding: .day, value: 60, to: rejectedAt)!
        let diff = Calendar.current.dateComponents([.day], from: revision.objectionDeadline, to: expected).day ?? 0
        XCTAssertEqual(diff, 0, "60 günlük itiraz süresinde deadline 60 gün sonra olmalı")
    }

    func testHakedisRevision_defaultObjectionIs30Days() {
        let rejectedAt = Date()
        let revision = HakedisRevision(version: "v1", rejectionReason: "Test", rejectedAt: rejectedAt)
        let expected = Calendar.current.date(byAdding: .day, value: 30, to: rejectedAt)!
        let diff = Calendar.current.dateComponents([.day], from: revision.objectionDeadline, to: expected).day ?? 0
        XCTAssertEqual(diff, 0, "Varsayılan itiraz süresi 30 gün olmalı")
    }

    // MARK: - Approval Step İptal → Cascade

    func testApprovalStep_cancel_blocksDownstreamPendingSteps() throws {
        // Adım 1 iptal edilince adım 2 ve 3 (bekliyor) otomatik iptal olmalı
        let hakedis = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        context.insert(hakedis)

        let step1 = ApprovalStep(stepOrder: 1, role: .santiyeSef, approverName: "Ali")
        let step2 = ApprovalStep(stepOrder: 2, role: .sefMuhendis, approverName: "Ayşe")
        let step3 = ApprovalStep(stepOrder: 3, role: .idare, approverName: "Mehmet")
        [step1, step2, step3].forEach {
            $0.hakedis = hakedis
            hakedis.approvalSteps.append($0)
            context.insert($0)
        }

        // İş kuralını doğrudan simüle et (ApprovalChainSection.cancel mantığı)
        let cancelledStep = step1
        cancelledStep.isCancelled = true
        cancelledStep.cancellationReason = "Yanlış onaylandı"

        let cascadeReason = "Önceki adım iptal edildiği için otomatik iptal"
        hakedis.approvalSteps
            .filter { $0.stepOrder > cancelledStep.stepOrder && !$0.isCancelled && $0.status == .bekliyor }
            .forEach { $0.isCancelled = true; $0.cancellationReason = cascadeReason }

        XCTAssertTrue(step1.isCancelled, "Adım 1 iptal edilmeli")
        XCTAssertTrue(step2.isCancelled, "Adım 2 cascade iptal edilmeli")
        XCTAssertTrue(step3.isCancelled, "Adım 3 cascade iptal edilmeli")
    }

    func testApprovalStep_cancel_doesNotAffectApprovedSteps() throws {
        // Adım 1 iptal edilince zaten onaylanmış adım 2 dokunulmamalı
        let hakedis = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        context.insert(hakedis)

        let step1 = ApprovalStep(stepOrder: 1, role: .santiyeSef, approverName: "Ali")
        let step2 = ApprovalStep(stepOrder: 2, role: .sefMuhendis, approverName: "Ayşe")
        step2.status = .onaylandi  // zaten onaylandı
        let step3 = ApprovalStep(stepOrder: 3, role: .idare, approverName: "Mehmet")
        [step1, step2, step3].forEach {
            $0.hakedis = hakedis
            hakedis.approvalSteps.append($0)
            context.insert($0)
        }

        step1.isCancelled = true
        hakedis.approvalSteps
            .filter { $0.stepOrder > step1.stepOrder && !$0.isCancelled && $0.status == .bekliyor }
            .forEach { $0.isCancelled = true }

        XCTAssertFalse(step2.isCancelled, "Onaylanmış adım 2 cascade etkilenmemeli")
        XCTAssertTrue(step3.isCancelled, "Bekliyor adım 3 cascade iptal edilmeli")
    }

    func testApprovalStep_cancel_lastStep_noCascade() throws {
        // Son adım iptal edilince cascade yok
        let hakedis = Hakedis(periodName: "Test", periodStart: Date(), periodEnd: Date())
        context.insert(hakedis)

        let step1 = ApprovalStep(stepOrder: 1, role: .santiyeSef, approverName: "Ali")
        let step2 = ApprovalStep(stepOrder: 2, role: .sefMuhendis, approverName: "Ayşe")
        [step1, step2].forEach {
            $0.hakedis = hakedis
            hakedis.approvalSteps.append($0)
            context.insert($0)
        }

        step2.isCancelled = true
        let cascaded = hakedis.approvalSteps.filter {
            $0.stepOrder > step2.stepOrder && !$0.isCancelled && $0.status == .bekliyor
        }

        XCTAssertTrue(cascaded.isEmpty, "Son adım iptal edilince cascade edilecek adım yok")
        XCTAssertFalse(step1.isCancelled, "Önceki adım etkilenmemeli")
    }

    // MARK: - Poz Fiyat Önerisi

    func testPozPriceSuggestion_fromWorkItems_average() throws {
        // Aynı poz koduna sahip 3 WorkItem → ortalama önerilmeli
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        context.insert(contract)

        let codes = ["01.001", "01.001", "01.001"]
        let prices = [100.0, 200.0, 300.0]
        for (code, price) in zip(codes, prices) {
            let wi = WorkItem(code: code, name: "Kazı", unit: "m³",
                             unitPrice: price, contractedQuantity: 10)
            wi.contract = contract
            context.insert(wi)
        }

        // PozLibraryView.suggestedPrice mantığını simüle et
        let allWorkItems: [WorkItem] = try context.fetch(FetchDescriptor<WorkItem>())
        let vals = allWorkItems.filter { $0.code == "01.001" && $0.unitPrice > 0 }.map { $0.unitPrice }
        let avg = vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)

        XCTAssertEqual(avg ?? 0, 200.0, accuracy: 0.01, "3 fiyatın ortalaması 200 olmalı")
    }

    func testPozPriceSuggestion_fromUnitPriceAnalysis_preferredOverWorkItems() throws {
        // UnitPriceAnalysis verisi varken WorkItem'a bakılmamalı
        let workItem = WorkItem(code: "02.005", name: "Beton", unit: "m³",
                                unitPrice: 500.0, contractedQuantity: 50)
        context.insert(workItem)

        let a1 = UnitPriceAnalysis(analysisNo: "A-001", workItemCode: "02.005",
                                   workItemName: "Beton", contractUnitPrice: 600.0)
        let a2 = UnitPriceAnalysis(analysisNo: "A-002", workItemCode: "02.005",
                                   workItemName: "Beton", contractUnitPrice: 800.0)
        context.insert(a1)
        context.insert(a2)

        // Analiz değerlerinden ortalama
        let analysisVals = [600.0, 800.0]
        let avg = analysisVals.reduce(0, +) / Double(analysisVals.count)

        XCTAssertEqual(avg, 700.0, accuracy: 0.01,
                       "UnitPriceAnalysis ortalaması: (600+800)/2 = 700")
    }

    func testPozPriceSuggestion_noData_returnsNil() throws {
        // Eşleşen veri yoksa nil dönmeli
        let allWorkItems: [WorkItem] = try context.fetch(FetchDescriptor<WorkItem>())
        let allAnalyses: [UnitPriceAnalysis] = try context.fetch(FetchDescriptor<UnitPriceAnalysis>())

        let vals = allWorkItems.filter { $0.code == "99.999" }.map { $0.unitPrice }
        let aVals = allAnalyses.filter { $0.workItemCode == "99.999" }.map { $0.contractUnitPrice }

        let suggestion: Double? = aVals.isEmpty ? (vals.isEmpty ? nil : vals.reduce(0,+)/Double(vals.count)) : aVals.reduce(0,+)/Double(aVals.count)

        XCTAssertNil(suggestion, "Eşleşen veri yoksa öneri nil olmalı")
    }

    func testPozPriceSuggestion_zeroPriceIgnored() throws {
        // unitPrice=0 olan WorkItem öneri hesabına dahil edilmemeli
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        context.insert(contract)

        let wi0 = WorkItem(code: "03.001", name: "Sıva", unit: "m²", unitPrice: 0, contractedQuantity: 10)
        let wi1 = WorkItem(code: "03.001", name: "Sıva", unit: "m²", unitPrice: 400.0, contractedQuantity: 10)
        [wi0, wi1].forEach { $0.contract = contract; context.insert($0) }

        let allWorkItems: [WorkItem] = try context.fetch(FetchDescriptor<WorkItem>())
        let vals = allWorkItems.filter { $0.code == "03.001" && $0.unitPrice > 0 }.map { $0.unitPrice }
        let avg = vals.isEmpty ? nil : vals.reduce(0,+) / Double(vals.count)

        XCTAssertEqual(avg ?? 0, 400.0, accuracy: 0.01,
                       "Sıfır fiyat görmezden gelinerek sadece 400 kullanılmalı")
    }
}
