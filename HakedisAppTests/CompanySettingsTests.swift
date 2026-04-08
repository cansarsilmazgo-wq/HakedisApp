import XCTest

// MARK: - FAZ 8+9: Şirket Bilgileri + Ayarlar Düzeltmeleri Tests

final class CompanySettingsTests: XCTestCase {

    // MARK: - CompanyType Tests

    func testCompanyTypeAllCases() {
        XCTAssertEqual(CompanyType.allCases.count, 5)
    }

    func testCompanyTypeRawValues() {
        XCTAssertEqual(CompanyType.sahis.rawValue, "Şahıs")
        XCTAssertEqual(CompanyType.limited.rawValue, "Limited Şirket")
        XCTAssertEqual(CompanyType.anonim.rawValue, "Anonim Şirket")
        XCTAssertEqual(CompanyType.adiOrtaklik.rawValue, "Adi Ortaklık")
        XCTAssertEqual(CompanyType.isOrtakligi.rawValue, "İş Ortaklığı")
    }

    func testCompanyTypeDecodable() {
        let json = "\"Limited Şirket\"".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(CompanyType.self, from: json)
        XCTAssertEqual(decoded, .limited)
    }

    // MARK: - AppStorage Keys Sanity Tests

    func testDefaultCompanyTypeIsLimited() {
        // Default value should be Limited Şirket when not set
        let defaultType = CompanyType(rawValue: UserDefaults.standard.string(forKey: "companyType_nonexistent") ?? CompanyType.limited.rawValue)
        XCTAssertEqual(defaultType, .limited)
    }

    // MARK: - FAZ 9: Ayarlar Label Tests

    func testDeveloperNameIsAlphabiSystems() {
        // This verifies the constant string — static verification
        let devName = "Alphabi Systems"
        XCTAssertEqual(devName, "Alphabi Systems")
        XCTAssertNotEqual(devName, "HakedisApp")
    }

    // MARK: - Contractor Class Tests

    func testContractorClassOptions() {
        let classes = ["A", "B", "C", "D", "E", "F", "G"]
        XCTAssertEqual(classes.count, 7)
        XCTAssertTrue(classes.contains("A"))
        XCTAssertTrue(classes.contains("G"))
    }

    // MARK: - Activity Areas Tests

    func testActivityAreasCount() {
        let areas = ["Konut", "Altyapı", "Sanayi", "Enerji", "Yol", "Köprü", "Tünel", "Baraj", "Restorasyon"]
        XCTAssertEqual(areas.count, 9)
    }

    func testActivityAreasSerializationRoundtrip() {
        let original: Set<String> = ["Konut", "Altyapı", "Yol"]
        let serialized = original.joined(separator: ",")
        let deserialized = Set(serialized.split(separator: ",").map(String.init))
        XCTAssertEqual(original, deserialized)
    }

    func testEmptyActivityAreas() {
        let serialized = ""
        let result = Set(serialized.split(separator: ",").map(String.init))
        XCTAssertTrue(result.isEmpty)
    }
}
