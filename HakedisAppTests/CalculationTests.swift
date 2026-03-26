import XCTest
import SwiftData

final class CalculationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Project.self, Contractor.self, Contract.self,
                             WorkItem.self, DailyEntry.self, Hakedis.self,
                             HakedisItem.self, Payment.self])
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
        let expected = 100_000 * (9.0 / 365.0 / 100.0) * 30
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

    // MARK: - Helpers

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
}
