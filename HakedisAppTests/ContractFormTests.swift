import XCTest

final class ContractFormTests: XCTestCase {

    func testContractTypeEnumAllCases() {
        XCTAssertEqual(ContractType.allCases.count, 4)
    }

    func testContractTypeDisplayNames() {
        XCTAssertEqual(ContractType.unitPrice.rawValue, "Birim Fiyat")
        XCTAssertEqual(ContractType.lumpSum.rawValue, "Götürü Bedel")
        XCTAssertEqual(ContractType.anahtarTeslim.rawValue, "Anahtar Teslim")
        XCTAssertEqual(ContractType.mixed.rawValue, "Karma")
    }

    func testContractDefaultFields() {
        let contract = Contract(title: "Test Sözleşme")
        XCTAssertEqual(contract.contractNumber, "")
        XCTAssertEqual(contract.employerName, "")
        XCTAssertEqual(contract.stopajRate, 0.0)
        XCTAssertEqual(contract.damgaVergisiRate, 0.0)
        XCTAssertEqual(contract.kdvTevkifatRate, "0")
        XCTAssertNil(contract.contractStartDate)
        XCTAssertNil(contract.contractEndDate)
    }

    func testContractWorkDurationZeroWithoutDates() {
        let contract = Contract(title: "Test")
        XCTAssertEqual(contract.workDuration, 0)
    }

    func testContractWorkDuration() {
        let contract = Contract(title: "Test")
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let end   = cal.date(from: DateComponents(year: 2026, month: 4, day: 10))!
        contract.contractStartDate = start
        contract.contractEndDate = end
        XCTAssertEqual(contract.workDuration, 99)
    }

    func testContractStopajFields() {
        let contract = Contract(title: "Kamu Sözleşmesi")
        contract.stopajRate = 3.0
        contract.damgaVergisiRate = 0.948
        XCTAssertEqual(contract.stopajRate, 3.0)
        XCTAssertEqual(contract.damgaVergisiRate, 0.948)
    }

    func testContractKdvTevkifatRates() {
        let validRates = ["0", "2/10", "4/10", "5/10", "7/10", "9/10"]
        for rate in validRates {
            let contract = Contract(title: "Test")
            contract.kdvTevkifatRate = rate
            XCTAssertEqual(contract.kdvTevkifatRate, rate, "\(rate) tevkifat oranı kaydedilmeli")
        }
    }

    func testKamuIhalesiAutoDefaults() {
        let type = ProjectType.kamuIhalesi
        XCTAssertEqual(type.defaultStopajRate, 3.0)
        XCTAssertEqual(type.defaultTeminatRate, 6.0)
        XCTAssertTrue(type.damgaVergisiRequired)
    }
}
