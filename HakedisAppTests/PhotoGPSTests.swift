import XCTest
import CoreLocation

// MARK: - Fotoğraf GPS Testleri

final class PhotoGPSTests: XCTestCase {

    func test_geoTaggedPhoto_olusturma() throws {
        let photo = GeoTaggedPhoto(
            photoDate: Date(),
            latitude: 41.0082,
            longitude: 28.9784,
            caption: "Şantiye Girişi",
            sourceModule: "SiteDiary",
            sourceId: UUID().uuidString
        )
        XCTAssertEqual(photo.sourceModule, "SiteDiary")
        XCTAssertEqual(photo.latitude, 41.0082, accuracy: 0.0001)
        XCTAssertEqual(photo.longitude, 28.9784, accuracy: 0.0001)
        XCTAssertEqual(photo.caption, "Şantiye Girişi")
    }

    func test_geoTaggedPhoto_moduleColor() throws {
        let siteDiaryPhoto = GeoTaggedPhoto(latitude: 0, longitude: 0, sourceModule: "SiteDiary", sourceId: "")
        XCTAssertEqual(siteDiaryPhoto.moduleColor, "blue")

        let safetyPhoto = GeoTaggedPhoto(latitude: 0, longitude: 0, sourceModule: "SafetyIncident", sourceId: "")
        XCTAssertEqual(safetyPhoto.moduleColor, "red")

        let qualityPhoto = GeoTaggedPhoto(latitude: 0, longitude: 0, sourceModule: "QualityCheck", sourceId: "")
        XCTAssertEqual(qualityPhoto.moduleColor, "orange")
    }

    func test_photoLocationService_invalidData() throws {
        let fakeData = Data("not an image".utf8)
        let coord = PhotoLocationService.extractGPSLocation(from: fakeData)
        XCTAssertNil(coord)
    }
}
