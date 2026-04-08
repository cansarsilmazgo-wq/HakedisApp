import XCTest

final class ProjectTypeTests: XCTestCase {

    func testKamuIhalesiDefaults() {
        let type = ProjectType.kamuIhalesi
        XCTAssertTrue(type.stopajRequired)
        XCTAssertEqual(type.defaultStopajRate, 3.0)
        XCTAssertEqual(type.defaultTeminatRate, 6.0)
        XCTAssertTrue(type.bayindirlikPozRequired)
        XCTAssertTrue(type.fiyatFarkiEnabled)
        XCTAssertTrue(type.damgaVergisiRequired)
    }

    func testOzelSektorDefaults() {
        let type = ProjectType.ozelSektor
        XCTAssertFalse(type.stopajRequired)
        XCTAssertEqual(type.defaultStopajRate, 0.0)
        XCTAssertEqual(type.defaultTeminatRate, 0.0)
        XCTAssertFalse(type.bayindirlikPozRequired)
        XCTAssertFalse(type.fiyatFarkiEnabled)
        XCTAssertTrue(type.damgaVergisiRequired)
    }

    func testKatKarsiligiDefaults() {
        let type = ProjectType.katKarsiligi
        XCTAssertFalse(type.stopajRequired)
        XCTAssertFalse(type.damgaVergisiRequired)
        XCTAssertEqual(type.defaultStopajRate, 0.0)
        XCTAssertEqual(type.defaultTeminatRate, 0.0)
        XCTAssertFalse(type.bayindirlikPozRequired)
        XCTAssertFalse(type.fiyatFarkiEnabled)
    }

    func testYapSatDefaults() {
        let type = ProjectType.yapSat
        XCTAssertFalse(type.stopajRequired)
        XCTAssertFalse(type.damgaVergisiRequired)
        XCTAssertEqual(type.defaultStopajRate, 0.0)
        XCTAssertEqual(type.defaultTeminatRate, 0.0)
    }

    func testAllCasesExist() {
        XCTAssertEqual(ProjectType.allCases.count, 4)
    }

    func testDisplayNames() {
        XCTAssertEqual(ProjectType.kamuIhalesi.displayName, "Kamu İhalesi")
        XCTAssertEqual(ProjectType.ozelSektor.displayName, "Özel Sektör")
        XCTAssertEqual(ProjectType.katKarsiligi.displayName, "Kat Karşılığı")
        XCTAssertEqual(ProjectType.yapSat.displayName, "Yap-Sat")
    }

    func testInfoTextNotEmpty() {
        for type in ProjectType.allCases {
            XCTAssertFalse(type.infoText.isEmpty, "\(type.rawValue) infoText boş")
        }
    }

    func testDefaultProjectTypeIsOzel() {
        let project = Project(name: "Test")
        XCTAssertEqual(project.projectType, .ozelSektor)
    }

    func testProjectTypeIsKamu() {
        let project = Project(name: "Kamu Projesi", projectType: .kamuIhalesi)
        XCTAssertEqual(project.projectType, .kamuIhalesi)
        XCTAssertTrue(project.projectType.stopajRequired)
        XCTAssertEqual(project.projectType.defaultTeminatRate, 6.0)
    }
}
