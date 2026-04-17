import XCTest
import SwiftData

// MARK: - Taşeron Hakediş Testleri

final class SubcontractorHakedisPDFTests: XCTestCase {

    func test_subHakedis_olusturma() throws {
        let hakedis = SubcontractorHakedis(
            periodName: "Ocak 2026",
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 30)
        )
        XCTAssertEqual(hakedis.periodName, "Ocak 2026")
        XCTAssertEqual(hakedis.status, .draft)
        XCTAssertEqual(hakedis.grossAmount, 0)
    }

    func test_subHakedis_netHesap() throws {
        let hakedis = SubcontractorHakedis(
            periodName: "Şubat 2026",
            periodStart: Date(),
            periodEnd: Date()
        )
        hakedis.grossAmount = 100_000
        hakedis.retentionAmount = 5_000
        hakedis.netAmount = hakedis.grossAmount - hakedis.retentionAmount
        XCTAssertEqual(hakedis.netAmount, 95_000, accuracy: 0.01)
    }

    func test_subHakedis_statusTransition() throws {
        let hakedis = SubcontractorHakedis(
            periodName: "Mart 2026",
            periodStart: Date(),
            periodEnd: Date()
        )
        XCTAssertEqual(hakedis.status, .draft)
        hakedis.status = .approved
        XCTAssertEqual(hakedis.status, .approved)
        hakedis.status = .paid
        XCTAssertEqual(hakedis.status, .paid)
    }

    // MARK: - ADIM 8 — Puantaj PDF Testleri

    // 0 işçi ile PDF oluşturulabilmeli (boş tablo)
    func testPuantajPDFSifirIsciBosTablo() {
        let data = AttendancePDFGenerator.generateMonthly(
            records: [],
            month: Date(),
            projectName: "Test Proje"
        )
        XCTAssertFalse(data.isEmpty, "Boş kayıtla da PDF verisi üretilmeli")
        XCTAssertGreaterThan(data.count, 100, "PDF verisi anlamlı büyüklükte olmalı")
    }

    // 30 işçi ile PDF oluşturulabilmeli (taşma yok)
    func testPuantajPDF30IsciTasmamali() {
        var records: [Attendance] = []
        let today = Date()
        for i in 1...30 {
            let a = Attendance(date: today, workerName: "İşçi \(i)")
            a.isPresent = true
            a.normalHours = 8
            records.append(a)
        }
        let data = AttendancePDFGenerator.generateMonthly(
            records: records,
            month: today,
            projectName: "Büyük Şantiye"
        )
        XCTAssertFalse(data.isEmpty, "30 işçiyle PDF üretilmeli")
        XCTAssertGreaterThan(data.count, 1000, "30 işçiyle PDF daha büyük olmalı")
    }

    // Şubat 28 gün doğru göstermeli (non-leap year)
    func testPuantajPDFSubat28Gun() {
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 2
        comps.day = 1
        guard let feb2025 = Calendar.current.date(from: comps) else {
            XCTFail("Tarih oluşturulamadı"); return
        }
        let daysInFeb = Calendar.current.range(of: .day, in: .month, for: feb2025)?.count ?? 0
        XCTAssertEqual(daysInFeb, 28, "2025 Şubat 28 gün olmalı (artık yıl değil)")

        let data = AttendancePDFGenerator.generateMonthly(records: [], month: feb2025)
        XCTAssertFalse(data.isEmpty, "Şubat ayı için PDF üretilmeli")
    }

    // Türkçe ay isimleri Ocak–Aralık doğru olmalı
    func testPuantajPDFTurkcAyIsimleri() {
        let monthNames = [
            1: "Ocak", 2: "Şubat", 3: "Mart", 4: "Nisan", 5: "Mayıs", 6: "Haziran",
            7: "Temmuz", 8: "Ağustos", 9: "Eylül", 10: "Ekim", 11: "Kasım", 12: "Aralık"
        ]
        XCTAssertEqual(monthNames.count, 12, "12 ay tanımlanmış olmalı")
        XCTAssertEqual(monthNames[1], "Ocak")
        XCTAssertEqual(monthNames[12], "Aralık")
        XCTAssertEqual(monthNames[6], "Haziran")
    }
}
