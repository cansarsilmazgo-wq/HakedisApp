import XCTest
import Foundation

// MARK: - B5 Maliyet Kontrol EVM Tests

final class EVMSnapshotTests: XCTestCase {

    private func makeSnapshot(bac: Double, pv: Double, ev: Double, ac: Double) -> EVMSnapshot {
        EVMSnapshot(snapshotDate: Date(), budgetAtCompletion: bac, plannedValue: pv,
                    earnedValue: ev, actualCost: ac)
    }

    func test_evm_spiHesabi() {
        let snap = makeSnapshot(bac: 100000, pv: 50000, ev: 45000, ac: 48000)
        XCTAssertEqual(snap.spi, 0.9, accuracy: 0.001)
    }

    func test_evm_cpiHesabi() {
        let snap = makeSnapshot(bac: 100000, pv: 50000, ev: 45000, ac: 48000)
        XCTAssertEqual(snap.cpi, 45000.0 / 48000.0, accuracy: 0.001)
    }

    func test_evm_eacHesabi() {
        let snap = makeSnapshot(bac: 100000, pv: 50000, ev: 50000, ac: 55000)
        // cpi = 50000/55000 ≈ 0.909, eac = 100000/0.909 ≈ 110000
        XCTAssertEqual(snap.eac, 100000.0 / (50000.0 / 55000.0), accuracy: 1.0)
    }

    func test_evm_scheduleCostVariance() {
        let snap = makeSnapshot(bac: 100000, pv: 50000, ev: 45000, ac: 48000)
        XCTAssertEqual(snap.scheduleVariance, -5000, accuracy: 0.01)
        XCTAssertEqual(snap.costVariance, -3000, accuracy: 0.01)
    }

    func test_evm_tcpiHesabi() {
        let snap = makeSnapshot(bac: 100000, pv: 60000, ev: 55000, ac: 58000)
        // tcpi = (100000-55000)/(100000-58000) = 45000/42000 ≈ 1.071
        XCTAssertEqual(snap.tcpi, 45000.0 / 42000.0, accuracy: 0.001)
    }

    func test_evm_completionPercent() {
        let snap = makeSnapshot(bac: 100000, pv: 60000, ev: 40000, ac: 45000)
        XCTAssertEqual(snap.completionPercent, 40.0, accuracy: 0.01)
    }

    func test_evm_isOnScheduleIsOnBudget() {
        let goodSnap = makeSnapshot(bac: 100000, pv: 50000, ev: 50000, ac: 50000)
        XCTAssertTrue(goodSnap.isOnSchedule)
        XCTAssertTrue(goodSnap.isOnBudget)

        let badSnap = makeSnapshot(bac: 100000, pv: 50000, ev: 40000, ac: 55000)
        XCTAssertFalse(badSnap.isOnSchedule)
        XCTAssertFalse(badSnap.isOnBudget)
    }

    func test_evm_vacHesabi() {
        let snap = makeSnapshot(bac: 100000, pv: 60000, ev: 60000, ac: 65000)
        // cpi = 60000/65000, eac = 100000/(60000/65000) = 100000*65000/60000 ≈ 108333
        let expectedEac = 100000.0 * 65000.0 / 60000.0
        XCTAssertEqual(snap.vac, 100000.0 - expectedEac, accuracy: 1.0)
    }
}

final class BudgetLineItemTests: XCTestCase {

    func test_lineItem_variance() {
        let item = BudgetLineItem(itemName: "İşçilik", category: .labor, budgetedAmount: 50000)
        item.actualAmount = 55000
        XCTAssertEqual(item.variance, -5000, accuracy: 0.01)
        XCTAssertEqual(item.variancePercent, -10.0, accuracy: 0.01)
    }

    func test_budget_toplam() {
        let budget = ProjectBudget(budgetName: "Test", projectName: "P", totalBudget: 200000)
        let i1 = BudgetLineItem(itemName: "A", category: .labor, budgetedAmount: 80000)
        i1.actualAmount = 85000
        let i2 = BudgetLineItem(itemName: "B", category: .material, budgetedAmount: 70000)
        i2.actualAmount = 68000
        budget.lineItems = [i1, i2]
        XCTAssertEqual(budget.budgetedCost, 150000, accuracy: 0.01)
        XCTAssertEqual(budget.actualCost, 153000, accuracy: 0.01)
        XCTAssertEqual(budget.costVariance, -3000, accuracy: 0.01)
    }
}
