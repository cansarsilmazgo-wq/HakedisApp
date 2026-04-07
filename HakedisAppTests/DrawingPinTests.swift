import XCTest
import SwiftData

// MARK: - Çizim Pini Testleri

final class DrawingPinTests: XCTestCase {

    func test_drawingPin_olusturma() throws {
        let pin = DrawingPin(pinNumber: 1, drawingName: "Kat Planı A1", title: "Kolon Ölçüsü Hatası",
                             xPosition: 0.35, yPosition: 0.72)
        XCTAssertEqual(pin.pinNumber, 1)
        XCTAssertEqual(pin.drawingName, "Kat Planı A1")
        XCTAssertEqual(pin.status, .open)
        XCTAssertTrue(pin.isOpen)
        XCTAssertFalse(pin.isOverdue)
    }

    func test_drawingPin_isOverdue_vadesiGecmisse() throws {
        let pin = DrawingPin(pinNumber: 2, drawingName: "Çatı Planı", title: "Eksik Detay",
                             xPosition: 0.5, yPosition: 0.5)
        pin.dueDate = Date().addingTimeInterval(-86400)
        XCTAssertTrue(pin.isOverdue, "Vade tarihi geçmiş ve açık pin gecikmiş olmalı")
    }

    func test_drawingPin_generateNumber() throws {
        let number = DrawingPin.generateNumber(existingCount: 5)
        XCTAssertEqual(number, 6)
    }
}
