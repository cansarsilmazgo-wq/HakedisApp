import XCTest

final class CurrencyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "selectedCurrency")
    }

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "selectedCurrency")
    }

    func testDefaultCurrencyIsTRY() {
        let amount = 100.0
        XCTAssertTrue(amount.currencyFormatted.contains("₺"), "Varsayılan para birimi ₺ olmalı")
        XCTAssertFalse(amount.currencyFormatted.contains("$"), "Varsayılan para birimi $ olmamalı")
    }

    func testTRYSymbol() {
        XCTAssertEqual(SupportedCurrency.TRY.symbol, "₺")
    }

    func testUSDSymbol() {
        XCTAssertEqual(SupportedCurrency.USD.symbol, "$")
    }

    func testEURSymbol() {
        XCTAssertEqual(SupportedCurrency.EUR.symbol, "€")
    }

    func testGBPSymbol() {
        XCTAssertEqual(SupportedCurrency.GBP.symbol, "£")
    }

    func testAllCurrenciesExist() {
        XCTAssertEqual(SupportedCurrency.allCases.count, 4)
    }

    func testCurrencyFormattedSwitchesToUSD() {
        UserDefaults.standard.set("USD", forKey: "selectedCurrency")
        let amount = 1000.0
        let formatted = amount.currencyFormatted
        XCTAssertTrue(formatted.contains("$"), "USD seçilince $ görünmeli: \(formatted)")
    }

    func testCurrencyFormattedSwitchesToEUR() {
        UserDefaults.standard.set("EUR", forKey: "selectedCurrency")
        let amount = 1000.0
        let formatted = amount.currencyFormatted
        XCTAssertTrue(formatted.contains("€"), "EUR seçilince € görünmeli: \(formatted)")
    }

    func testCompactCurrencyTRY() {
        UserDefaults.standard.set("TRY", forKey: "selectedCurrency")
        let million = 1_500_000.0
        let compact = million.compactCurrency
        XCTAssertTrue(compact.contains("₺"), "Kompakt format ₺ içermeli: \(compact)")
        XCTAssertTrue(compact.contains("M") || compact.contains("1"), "Kompakt format kısaltma içermeli: \(compact)")
    }

    func testCompactCurrencyBinler() {
        UserDefaults.standard.set("TRY", forKey: "selectedCurrency")
        let binler = 250_000.0
        let compact = binler.compactCurrency
        XCTAssertTrue(compact.contains("₺"), "₺ içermeli: \(compact)")
    }

    func testLocaleForTRY() {
        XCTAssertEqual(SupportedCurrency.TRY.locale.identifier, "tr_TR")
    }

    func testLocaleForUSD() {
        XCTAssertEqual(SupportedCurrency.USD.locale.identifier, "en_US")
    }
}
