import XCTest
import SwiftData

// MARK: - FAZ 7: Proje Formu Eksikleri Tests

final class ProjectFormTests: XCTestCase {

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

    // MARK: - BuildingType Tests

    func testBuildingTypeAllCases() {
        XCTAssertGreaterThanOrEqual(BuildingType.allCases.count, 3)
        XCTAssertTrue(BuildingType.allCases.contains(.residential))
        XCTAssertTrue(BuildingType.allCases.contains(.commercial))
        XCTAssertTrue(BuildingType.allCases.contains(.mixed))
    }

    func testBuildingTypeNewCases() {
        XCTAssertTrue(BuildingType.allCases.contains(.altyapi))
        XCTAssertTrue(BuildingType.allCases.contains(.sanayi))
        XCTAssertTrue(BuildingType.allCases.contains(.kamusal))
    }

    func testBuildingTypeRawValues() {
        XCTAssertEqual(BuildingType.residential.rawValue, "Konut")
        XCTAssertEqual(BuildingType.commercial.rawValue, "Ticari")
        XCTAssertEqual(BuildingType.mixed.rawValue, "Karma")
        XCTAssertEqual(BuildingType.altyapi.rawValue, "Altyapı")
        XCTAssertEqual(BuildingType.sanayi.rawValue, "Sanayi")
    }

    // MARK: - Project New Fields Tests

    func testProjectCityField() {
        let p = Project(name: "Test")
        p.city = "İstanbul"
        context.insert(p)
        try? context.save()
        XCTAssertEqual(p.city, "İstanbul")
    }

    func testProjectDistrictField() {
        let p = Project(name: "Test")
        p.city = "İstanbul"
        p.district = "Kadıköy"
        context.insert(p)
        try? context.save()
        XCTAssertEqual(p.district, "Kadıköy")
    }

    func testProjectPermitAndParcel() {
        let p = Project(name: "Test")
        p.buildingPermitNo = "R-2024/001"
        p.blockNo = "123"
        p.parcelNo = "45"
        context.insert(p)
        try? context.save()
        XCTAssertEqual(p.buildingPermitNo, "R-2024/001")
        XCTAssertEqual(p.blockNo, "123")
        XCTAssertEqual(p.parcelNo, "45")
    }

    func testProjectEmployerName() {
        let p = Project(name: "Test")
        p.employerName = "Ankara Büyükşehir Belediyesi"
        context.insert(p)
        try? context.save()
        XCTAssertEqual(p.employerName, "Ankara Büyükşehir Belediyesi")
    }

    func testProjectBuildingType() {
        let p = Project(name: "Test")
        p.buildingType = .kamusal
        context.insert(p)
        try? context.save()
        XCTAssertEqual(p.buildingType, .kamusal)
    }

    func testProjectTotalConstructionArea() {
        let p = Project(name: "Test")
        p.totalConstructionArea = 5000.0
        context.insert(p)
        try? context.save()
        XCTAssertEqual(p.totalConstructionArea, 5000.0, accuracy: 0.01)
    }
}

// MARK: - TurkiyeIller Tests (no SwiftData needed)

final class TurkiyeIllerTests: XCTestCase {

    func testIllerCount() {
        XCTAssertEqual(TurkiyeIller.iller.count, 81)
    }

    func testAnkaraDistrictsExist() {
        let districts = TurkiyeIller.districts(for: "Ankara")
        XCTAssertGreaterThan(districts.count, 0)
        XCTAssertTrue(districts.contains("Çankaya"))
    }

    func testIstanbulDistrictsExist() {
        let districts = TurkiyeIller.districts(for: "İstanbul")
        XCTAssertGreaterThan(districts.count, 0)
        XCTAssertTrue(districts.contains("Kadıköy"))
    }

    func testUnknownCityReturnsEmpty() {
        let districts = TurkiyeIller.districts(for: "BilinmeyenŞehir")
        XCTAssertEqual(districts.count, 0)
    }
}
