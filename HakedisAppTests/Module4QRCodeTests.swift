import XCTest
import SwiftData
import CoreImage

// MARK: - Module 4: QR Kod Puantaj Tests

final class Module4QRCodeTests: XCTestCase {

    // QR kod üretim yardımcısı (QRCodeManager görünüm katmanında olduğu için burada inline)
    private func generateQRCode(for uuid: UUID) -> UIImage? {
        let data = uuid.uuidString.data(using: .utf8)!
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 5, y: 5))
        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // UUID → string → UUID (QRCodeManager.workerID yeniden implement)
    private func workerID(from string: String) -> UUID? { UUID(uuidString: string) }

    // Test 1: QR kod üretme
    func test_qrCodeGeneration_returnsImage() {
        let uuid = UUID()
        let image = generateQRCode(for: uuid)
        XCTAssertNotNil(image, "QR kod üretilememedi")
    }

    func test_qrCodeGeneration_hasDimensions() {
        let uuid = UUID()
        guard let img = generateQRCode(for: uuid) else {
            XCTFail("QR kod nil döndü")
            return
        }
        XCTAssertGreaterThan(img.size.width, 0)
        XCTAssertGreaterThan(img.size.height, 0)
    }

    // Test 2: QR'dan Worker.id çözme
    func test_workerID_fromValidUUID() {
        let originalUUID = UUID()
        let parsed = workerID(from: originalUUID.uuidString)
        XCTAssertEqual(parsed, originalUUID)
    }

    func test_workerID_fromInvalidString_returnsNil() {
        let parsed = workerID(from: "GECERSIZ-QR-STRING")
        XCTAssertNil(parsed)
    }

    func test_workerID_fromEmptyString_returnsNil() {
        let parsed = workerID(from: "")
        XCTAssertNil(parsed)
    }

    func test_workerID_roundTrip() {
        let uuid = UUID()
        let str = uuid.uuidString
        let recovered = workerID(from: str)
        XCTAssertEqual(recovered, uuid)
    }

    // Test 3: Worker QR cache
    func test_worker_qrCodeData_defaultNil() {
        let worker = Worker(fullName: "Test İşçi")
        XCTAssertNil(worker.qrCodeData)
    }

    func test_worker_qrCodeData_canBeSet() {
        let worker = Worker(fullName: "Test İşçi")
        let uuid = UUID()
        if let qrImage = generateQRCode(for: uuid) {
            worker.qrCodeData = qrImage.pngData()
            XCTAssertNotNil(worker.qrCodeData)
        }
    }

    // Test 4: Aynı gün duplike giriş engeli (logic test)
    func test_attendance_duplicateEntryLogic() {
        let worker = Worker(fullName: "Ali Veli")
        let today = Date()

        let att1 = Attendance(date: today, workerName: worker.fullName)
        att1.worker = worker
        att1.isPresent = true

        let todayAtts = [att1]
        let isDuplicate = todayAtts.contains { att in
            Calendar.current.isDateInToday(att.date) && att.worker?.id == worker.id && att.isPresent
        }
        XCTAssertTrue(isDuplicate, "Duplike giriş tespit edilmeli")
    }

    func test_attendance_differentDay_isNotDuplicate() {
        let worker = Worker(fullName: "Mehmet Yılmaz")
        let yesterday = Date().addingTimeInterval(-86400)

        let att1 = Attendance(date: yesterday, workerName: worker.fullName)
        att1.worker = worker
        att1.isPresent = true

        let todayAtts = [att1]
        let isDuplicate = todayAtts.contains { att in
            Calendar.current.isDateInToday(att.date) && att.worker?.id == worker.id && att.isPresent
        }
        XCTAssertFalse(isDuplicate, "Dün yapılan giriş bugün duplike sayılmamalı")
    }
}
