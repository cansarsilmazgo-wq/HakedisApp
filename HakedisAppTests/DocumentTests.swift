import XCTest
import SwiftData

// MARK: - Doküman Yönetimi Testleri

final class DocumentTests: XCTestCase {

    func test_projectDocument_olusturma() throws {
        let doc = ProjectDocument(documentName: "Zemin Etüdü", documentType: .report, discipline: .structural)
        XCTAssertEqual(doc.documentName, "Zemin Etüdü")
        XCTAssertEqual(doc.documentType, .report)
        XCTAssertTrue(doc.isCurrentRevision)
        XCTAssertEqual(doc.revisionNo, "Rev.0")
    }

    func test_projectDocument_revizyon() throws {
        let doc = ProjectDocument(documentName: "Statik Hesap", revisionNo: "Rev.0")
        let revision = DocumentRevision(revisionNo: "Rev.1", document: doc)
        revision.changeDescription = "Kolon boyutları güncellendi"
        doc.previousRevisions.append(revision)

        XCTAssertEqual(doc.previousRevisions.count, 1)
        XCTAssertEqual(doc.previousRevisions.first?.revisionNo, "Rev.1")
        XCTAssertEqual(doc.previousRevisions.first?.changeDescription, "Kolon boyutları güncellendi")
    }

    func test_projectDocument_etiketParsing() throws {
        let doc = ProjectDocument(documentName: "Mimari Proje")
        doc.tags = "mimari, uygulama, onaylı"
        let tags = doc.tagList
        XCTAssertEqual(tags.count, 3)
        XCTAssertTrue(tags.contains("mimari"))
        XCTAssertTrue(tags.contains("onaylı"))
    }

    func test_projectDocument_varsayilanDegerleri() throws {
        let doc = ProjectDocument(documentName: "Test Dokümanı")
        XCTAssertEqual(doc.documentType, .other)
        XCTAssertEqual(doc.discipline, .general)
        XCTAssertTrue(doc.previousRevisions.isEmpty)
        XCTAssertNil(doc.project)
    }
}
