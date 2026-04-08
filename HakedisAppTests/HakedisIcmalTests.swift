import XCTest
import SwiftData
@testable import HakedisApp

// MARK: - FAZ 6: Hakediş İcmal Tablosu Tests

final class HakedisIcmalTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Project.self, Contract.self, WorkItem.self, DailyEntry.self, Hakedis.self, HakedisItem.self, Payment.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func makeHakedis(
        retentionRate: Double = 6,
        stopajRate: Double = 3,
        kdvRate: Double = 20,
        advanceRate: Double = 0,
        grossAmount: Double = 100_000
    ) -> Hakedis {
        let project = Project(name: "Test Proje")
        let contract = Contract(title: "Test Sözleşme", retentionRate: retentionRate, advanceRate: advanceRate)
        contract.kdvRate = kdvRate
        project.contracts.append(contract)
        context.insert(project)

        let hakedis = Hakedis(
            periodName: "1. Dönem",
            periodStart: Date(),
            periodEnd: Date()
        )
        contract.hakedisler.append(hakedis)

        let workItem = WorkItem(code: "01.001", name: "Test İş", unit: "m2", unitPrice: grossAmount, contractedQuantity: 10)
        workItem.contract = contract
        contract.workItems.append(workItem)

        let item = HakedisItem(
            workItemName: "Test İş",
            workItemCode: "01.001",
            unit: "m2",
            unitPrice: grossAmount,
            previousQuantity: 0,
            currentQuantity: 1,
            contractedQuantity: 10
        )
        hakedis.items.append(item)

        try? context.save()
        return hakedis
    }

    // MARK: - Stopaj (Withholding Tax) Tests

    func testWithholdingTaxRate() {
        let h = makeHakedis(stopajRate: 3, grossAmount: 100_000)
        // Default stopaj from contract field
        XCTAssertGreaterThanOrEqual(h.withholdingTaxRate, 0)
    }

    func testWithholdingTaxAmountNonNegative() {
        let h = makeHakedis(grossAmount: 100_000)
        XCTAssertGreaterThanOrEqual(h.withholdingTaxAmount, 0)
    }

    // MARK: - Teminat Kesintisi Tests

    func testRetentionCalculation() {
        let h = makeHakedis(retentionRate: 6, grossAmount: 100_000)
        let expected = h.grossAmount * 0.06
        XCTAssertEqual(h.retentionAmount, expected, accuracy: 0.01)
    }

    func testZeroRetention() {
        let h = makeHakedis(retentionRate: 0, grossAmount: 100_000)
        XCTAssertEqual(h.retentionAmount, 0)
    }

    // MARK: - Net Amount Tests

    func testNetAmountLessThanGross() {
        let h = makeHakedis(retentionRate: 6, grossAmount: 100_000)
        XCTAssertLessThan(h.netAmount, h.grossAmount)
    }

    func testNetAmountPositive() {
        let h = makeHakedis(grossAmount: 100_000)
        XCTAssertGreaterThan(h.netAmount, 0)
    }

    // MARK: - KDV Tests

    func testKDVCalculationPositive() {
        let h = makeHakedis(kdvRate: 20, grossAmount: 100_000)
        XCTAssertGreaterThan(h.kdvAmount, 0)
    }

    func testTotalWithKDVHigherThanNetAmount() {
        let h = makeHakedis(kdvRate: 20, grossAmount: 100_000)
        // KDV artırır, bu yüzden totalWithKDV > netAmount olmalı
        XCTAssertGreaterThan(h.totalWithKDV, h.netAmount)
    }

    // MARK: - Kümülatif Tests

    func testHakedisNumbering() {
        let project = Project(name: "Proje")
        let contract = Contract(title: "Sözleşme")
        project.contracts.append(contract)
        context.insert(project)

        let h1 = Hakedis(periodName: "Dönem 1", periodStart: Date(), periodEnd: Date())
        let h2 = Hakedis(periodName: "Dönem 2", periodStart: Date(), periodEnd: Date())
        contract.hakedisler.append(h1)
        contract.hakedisler.append(h2)
        try? context.save()

        let sorted = contract.hakedisler.sorted { $0.createdAt < $1.createdAt }
        let idx1 = (sorted.firstIndex(where: { $0.id == h1.id }) ?? 0) + 1
        let idx2 = (sorted.firstIndex(where: { $0.id == h2.id }) ?? 0) + 1
        XCTAssertLessThan(idx1, idx2)
        XCTAssertEqual(idx2 - idx1, 1)
    }

    // MARK: - Payment Tests

    func testTotalPaidAfterPayment() {
        let h = makeHakedis(grossAmount: 100_000)
        let payment = Payment(amount: 50_000, paymentDate: Date())
        h.payments.append(payment)
        try? context.save()

        XCTAssertEqual(h.totalPaid, 50_000, accuracy: 0.01)
    }

    func testRemainingAmountDecreaseAfterPayment() {
        let h = makeHakedis(grossAmount: 100_000)
        let before = h.remainingAmount
        let payment = Payment(amount: 50_000, paymentDate: Date())
        h.payments.append(payment)
        try? context.save()

        XCTAssertLessThan(h.remainingAmount, before)
    }

    // MARK: - Ödenecek Tutar Test

    func testOdenecekTutarPositive() {
        let h = makeHakedis(grossAmount: 100_000)
        XCTAssertGreaterThan(h.netAmountAfterPenalty, 0)
    }
}
