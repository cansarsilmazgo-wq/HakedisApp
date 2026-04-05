import XCTest
import Foundation

// MARK: - B6 Çizim Pin Sistemi Tests

final class DrawingPinModelTests: XCTestCase {

    func test_pin_varsayilanDegerler() {
        let pin = DrawingPin(pinNumber: 1, drawingName: "A1-Plan", title: "Test Pin",
                             xPosition: 0.5, yPosition: 0.3)
        XCTAssertEqual(pin.status, .open)
        XCTAssertEqual(pin.priority, .medium)
        XCTAssertEqual(pin.category, .general)
        XCTAssertTrue(pin.isOpen)
        XCTAssertFalse(pin.isOverdue)
    }

    func test_pin_gecikmeDetection() {
        let pin = DrawingPin(pinNumber: 2, drawingName: "B2-Kesit", title: "Gecikmiş",
                             xPosition: 0.2, yPosition: 0.7)
        pin.dueDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        pin.status = .open
        XCTAssertTrue(pin.isOverdue)
    }

    func test_pin_kapandiysa_gecikmiyor() {
        let pin = DrawingPin(pinNumber: 3, drawingName: "C1-Detay", title: "Kapalı",
                             xPosition: 0.8, yPosition: 0.1)
        pin.dueDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        pin.status = .closed
        XCTAssertFalse(pin.isOverdue)
        XCTAssertFalse(pin.isOpen)
    }

    func test_pin_numaraOlusturma() {
        let no = DrawingPin.generateNumber(existingCount: 5)
        XCTAssertEqual(no, 6)
    }
}
