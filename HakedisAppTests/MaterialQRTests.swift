import XCTest
import SwiftData

// MARK: - Malzeme QR Testleri

final class MaterialQRTests: XCTestCase {

    func test_materialQRPayload_format() throws {
        let material = Material(name: "Çimento", unit: "kg", minimumStock: 100, unitPrice: 5)
        let payload = MaterialQRCodeManager.qrPayload(for: material)
        XCTAssertTrue(payload.hasPrefix("MATERIAL:"))
        XCTAssertTrue(payload.contains(material.id.uuidString))
        XCTAssertTrue(payload.contains("Çimento"))
    }

    func test_materialQRParsing_validPayload() throws {
        let material = Material(name: "Demir", unit: "ton", minimumStock: 5, unitPrice: 1500)
        let payload = MaterialQRCodeManager.qrPayload(for: material)
        let parsed = MaterialQRCodeManager.materialID(from: payload)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed, material.id)
    }

    func test_materialQRParsing_invalidPayload() throws {
        let parsed = MaterialQRCodeManager.materialID(from: "WORKER:abc123")
        XCTAssertNil(parsed)

        let parsed2 = MaterialQRCodeManager.materialID(from: "randomstring")
        XCTAssertNil(parsed2)
    }

    func test_materialQRCodeGeneration() throws {
        let material = Material(name: "Kum", unit: "m3", minimumStock: 10, unitPrice: 80)
        let image = MaterialQRCodeManager.generateQRCode(for: material)
        XCTAssertNotNil(image)
        XCTAssertGreaterThan(image?.size.width ?? 0, 0)
        XCTAssertGreaterThan(image?.size.height ?? 0, 0)
    }
}
