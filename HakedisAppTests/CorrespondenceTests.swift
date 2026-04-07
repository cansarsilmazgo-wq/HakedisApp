import XCTest
import SwiftData

// MARK: - Yazışma Yönetimi Testleri

final class CorrespondenceTests: XCTestCase {

    func test_correspondenceRecord_olusturma() throws {
        let record = CorrespondenceRecord(
            recordNo: "YZ-2026-001",
            subject: "Hakediş Talebi",
            direction: .gelen,
            category: .mali,
            senderName: "İdare",
            receiverName: "Firma"
        )
        XCTAssertEqual(record.recordNo, "YZ-2026-001")
        XCTAssertEqual(record.subject, "Hakediş Talebi")
        XCTAssertEqual(record.direction, .gelen)
        XCTAssertFalse(record.isReplied)
    }

    func test_correspondenceRecord_isSureDoldu_dogruHesap() throws {
        let geçmişTarih = Date().addingTimeInterval(-86400 * 20) // 20 gün önce
        let record = CorrespondenceRecord(
            recordNo: "YZ-2026-002",
            subject: "Teknik Soru",
            direction: .giden,
            documentDate: geçmişTarih
        )
        record.replyDeadline = Date().addingTimeInterval(-86400) // dün
        record.isReplied = false
        XCTAssertTrue(record.isSureDoldu, "Cevap tarihi geçmiş ise isSureDoldu true olmalı")
    }

    func test_correspondenceRecord_isSureDoldu_yanitlandiysa() throws {
        let record = CorrespondenceRecord(
            recordNo: "YZ-2026-003",
            subject: "Proje Değişikliği",
            direction: .gelen
        )
        record.replyDeadline = Date().addingTimeInterval(-86400)
        record.isReplied = true
        XCTAssertFalse(record.isSureDoldu, "Yanıtlanmış yazışma süresi dolmuş sayılmamalı")
    }

    func test_correspondenceRecord_zincirTakibi() throws {
        let record1 = CorrespondenceRecord(recordNo: "YZ-001", subject: "Soru", direction: .gelen)
        let record2 = CorrespondenceRecord(recordNo: "YZ-002", subject: "Yanıt", direction: .giden)
        record2.parentRecordNo = record1.recordNo
        XCTAssertEqual(record2.parentRecordNo, "YZ-001")
    }

    func test_correspondenceRecord_eklerSayisi() throws {
        let record = CorrespondenceRecord(recordNo: "YZ-003", subject: "Doküman", direction: .giden)
        record.attachmentData = [Data([0x01]), Data([0x02]), Data([0x03])]
        XCTAssertEqual(record.attachmentData.count, 3)
    }
}
