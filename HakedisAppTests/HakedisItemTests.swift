import XCTest

final class HakedisItemTests: XCTestCase {

    func testCumulativeQuantity() {
        let item = HakedisItem(workItemName: "Test", workItemCode: "T01", unit: "m³",
                               unitPrice: 1000, previousQuantity: 100, currentQuantity: 50)
        XCTAssertEqual(item.cumulativeQuantity, 150)
    }

    func testCurrentAmount() {
        let item = HakedisItem(workItemName: "Test", workItemCode: "T01", unit: "m³",
                               unitPrice: 2800, previousQuantity: 0, currentQuantity: 50)
        XCTAssertEqual(item.periodAmount, 140000)
    }

    func testCompletionRate() {
        let item = HakedisItem(workItemName: "Test", workItemCode: "T01", unit: "m³",
                               unitPrice: 1000, previousQuantity: 100, currentQuantity: 50,
                               contractedQuantity: 200)
        XCTAssertEqual(item.completionRate, 75.0)
    }

    func testCompletionRateMax100() {
        let item = HakedisItem(workItemName: "Test", workItemCode: "T01", unit: "m³",
                               unitPrice: 1000, previousQuantity: 80, currentQuantity: 30,
                               contractedQuantity: 100)
        XCTAssertEqual(item.completionRate, 100.0)
    }

    func testCompletionRateZeroWhenNoContracted() {
        let item = HakedisItem(workItemName: "Test", workItemCode: "T01", unit: "m³",
                               unitPrice: 1000, previousQuantity: 50, currentQuantity: 10,
                               contractedQuantity: 0)
        XCTAssertEqual(item.completionRate, 0)
    }

    func testCumulativeAmount() {
        let item = HakedisItem(workItemName: "Test", workItemCode: "T01", unit: "m²",
                               unitPrice: 500, previousQuantity: 100, currentQuantity: 50,
                               contractedQuantity: 200)
        XCTAssertEqual(item.cumulativeAmount, 75000) // 150 * 500
    }

    func testContractedQuantityDefault() {
        let item = HakedisItem(workItemName: "Test", workItemCode: "T01", unit: "m³",
                               unitPrice: 1000, previousQuantity: 0, currentQuantity: 10)
        XCTAssertEqual(item.contractedQuantity, 0)
        XCTAssertEqual(item.completionRate, 0)
    }

    func testZeroPreviousQuantity() {
        let item = HakedisItem(workItemName: "İlk Hakediş", workItemCode: "B01", unit: "m³",
                               unitPrice: 3000, previousQuantity: 0, currentQuantity: 25,
                               contractedQuantity: 100)
        XCTAssertEqual(item.cumulativeQuantity, 25)
        XCTAssertEqual(item.completionRate, 25.0)
        XCTAssertEqual(item.periodAmount, 75000)
    }
}
