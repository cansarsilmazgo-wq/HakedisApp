import XCTest
import SwiftData

final class FinancialTrackingTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Project.self, Contractor.self, Contract.self,
                             WorkItem.self, DailyEntry.self, Hakedis.self,
                             HakedisItem.self, Payment.self, RetentionRelease.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - Retention Tracking

    func test_retentionAccrued_singleHakedis() throws {
        let contract = makeContract(retentionRate: 10)
        let hakedis = makeHakedis(contract: contract)
        addItem(to: hakedis, price: 1_000, qty: 100)
        // brüt=100000, teminat=%10=10000
        XCTAssertEqual(contract.totalRetentionAccrued, 10_000)
        XCTAssertEqual(contract.retentionBalance, 10_000)
    }

    func test_retentionAccrued_multipleHakedisler() throws {
        let contract = makeContract(retentionRate: 10)
        let h1 = makeHakedis(contract: contract)
        let h2 = makeHakedis(contract: contract)
        addItem(to: h1, price: 1_000, qty: 100) // brüt=100000, teminat=10000
        addItem(to: h2, price: 500, qty: 200)   // brüt=100000, teminat=10000
        XCTAssertEqual(contract.totalRetentionAccrued, 20_000)
    }

    func test_retentionRelease_reducesBalance() throws {
        let contract = makeContract(retentionRate: 10)
        let hakedis = makeHakedis(contract: contract)
        addItem(to: hakedis, price: 1_000, qty: 100) // teminat=10000

        let release = RetentionRelease(amount: 6_000, releaseDescription: "Geçici Kabul")
        release.contract = contract
        contract.retentionReleases.append(release)
        context.insert(release)

        XCTAssertEqual(contract.totalRetentionReleased, 6_000)
        XCTAssertEqual(contract.retentionBalance, 4_000, "10000 biriken - 6000 iade = 4000 kalan")
    }

    func test_retentionBalance_zeroAfterFullRelease() throws {
        let contract = makeContract(retentionRate: 10)
        let hakedis = makeHakedis(contract: contract)
        addItem(to: hakedis, price: 1_000, qty: 100) // teminat=10000

        let release = RetentionRelease(amount: 10_000)
        release.contract = contract
        contract.retentionReleases.append(release)
        context.insert(release)

        XCTAssertEqual(contract.retentionBalance, 0)
    }

    func test_multipleRetentionReleases() throws {
        let contract = makeContract(retentionRate: 10)
        let hakedis = makeHakedis(contract: contract)
        addItem(to: hakedis, price: 1_000, qty: 100) // teminat=10000

        for amount in [3_000.0, 4_000.0] {
            let release = RetentionRelease(amount: amount)
            release.contract = contract
            contract.retentionReleases.append(release)
            context.insert(release)
        }

        XCTAssertEqual(contract.totalRetentionReleased, 7_000)
        XCTAssertEqual(contract.retentionBalance, 3_000)
    }

    // MARK: - Advance Tracking

    func test_advanceRecovered_fromHakedis() throws {
        let contract = makeContract(retentionRate: 0, advanceRate: 20)
        let hakedis = makeHakedis(contract: contract)
        addItem(to: hakedis, price: 1_000, qty: 100) // brüt=100000, avans=%20=20000
        XCTAssertEqual(contract.totalAdvanceRecovered, 20_000)
    }

    func test_advanceBalance_withAdvanceGiven() throws {
        let contract = makeContract(retentionRate: 0, advanceRate: 20)
        contract.advanceGiven = 80_000
        let h1 = makeHakedis(contract: contract)
        let h2 = makeHakedis(contract: contract)
        addItem(to: h1, price: 1_000, qty: 100) // avans=20000
        addItem(to: h2, price: 500, qty: 100)   // avans=10000
        // toplam kesilen=30000, verilen=80000, kalan=50000
        XCTAssertEqual(contract.totalAdvanceRecovered, 30_000)
        XCTAssertEqual(contract.advanceBalance, 50_000)
    }

    func test_advanceBalance_fullyRecovered() throws {
        let contract = makeContract(retentionRate: 0, advanceRate: 20)
        contract.advanceGiven = 20_000
        let hakedis = makeHakedis(contract: contract)
        addItem(to: hakedis, price: 1_000, qty: 100) // avans=20000
        XCTAssertEqual(contract.advanceBalance, 0)
    }

    func test_noAdvanceRecovery_whenRateZero() throws {
        let contract = makeContract(retentionRate: 0, advanceRate: 0)
        let hakedis = makeHakedis(contract: contract)
        addItem(to: hakedis, price: 1_000, qty: 100)
        XCTAssertEqual(contract.totalAdvanceRecovered, 0)
        XCTAssertEqual(hakedis.advanceDeduction, 0)
    }

    // MARK: - Budget Utilization

    func test_budgetUtilization_zero_noHakedis() throws {
        let contract = makeContract(retentionRate: 0)
        let workItem = WorkItem(code: "01", name: "Test", unit: "m²",
                                unitPrice: 1_000, contractedQuantity: 100)
        workItem.contract = contract
        contract.workItems.append(workItem)
        context.insert(workItem)
        XCTAssertEqual(contract.budgetUtilization, 0)
        XCTAssertFalse(contract.isOverBudget)
    }

    func test_budgetUtilization_50percent() throws {
        let contract = makeContract(retentionRate: 0)
        let workItem = WorkItem(code: "01", name: "Test", unit: "m²",
                                unitPrice: 1_000, contractedQuantity: 100)
        workItem.contract = contract
        contract.workItems.append(workItem)
        context.insert(workItem)
        // totalContractAmount = 100000
        let hakedis = makeHakedis(contract: contract)
        addItem(to: hakedis, price: 1_000, qty: 50) // net=50000
        // budgetUtilization = 50000/100000 = 50%
        XCTAssertEqual(contract.budgetUtilization, 50, accuracy: 0.1)
        XCTAssertFalse(contract.isOverBudget)
    }

    func test_budgetUtilization_overBudget() throws {
        let contract = makeContract(retentionRate: 0)
        let workItem = WorkItem(code: "01", name: "Test", unit: "m²",
                                unitPrice: 1_000, contractedQuantity: 100)
        workItem.contract = contract
        contract.workItems.append(workItem)
        context.insert(workItem)
        // totalContractAmount = 100000
        let hakedis = makeHakedis(contract: contract)
        addItem(to: hakedis, price: 1_000, qty: 120) // net=120000
        XCTAssertEqual(contract.budgetUtilization, 120, accuracy: 0.1)
        XCTAssertTrue(contract.isOverBudget)
    }

    func test_budgetUtilization_noWorkItems_isZero() throws {
        let contract = makeContract(retentionRate: 0)
        XCTAssertEqual(contract.budgetUtilization, 0)
        XCTAssertFalse(contract.isOverBudget)
    }

    // MARK: - Helpers

    @discardableResult
    private func makeContract(retentionRate: Double, advanceRate: Double = 0) -> Contract {
        let project = Project(name: "Test Proje")
        let contract = Contract(title: "Test Sözleşme",
                                retentionRate: retentionRate, advanceRate: advanceRate)
        contract.project = project
        project.contracts.append(contract)
        context.insert(project)
        context.insert(contract)
        return contract
    }

    @discardableResult
    private func makeHakedis(contract: Contract) -> Hakedis {
        let jan1  = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let jan31 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 31))!
        let hakedis = Hakedis(periodName: "Ocak 2025", periodStart: jan1, periodEnd: jan31)
        hakedis.contract = contract
        contract.hakedisler.append(hakedis)
        context.insert(hakedis)
        return hakedis
    }

    private func addItem(to hakedis: Hakedis, price: Double, qty: Double) {
        let item = HakedisItem(workItemName: "Test İş", workItemCode: "T01",
                               unit: "m²", unitPrice: price,
                               previousQuantity: 0, currentQuantity: qty)
        item.hakedis = hakedis
        hakedis.items.append(item)
        context.insert(item)
    }
}
