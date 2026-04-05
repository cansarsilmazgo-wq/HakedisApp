import XCTest
import Foundation

// MARK: - B1 Doküman Yönetimi Tests

final class ProjectDocumentTests: XCTestCase {

    func test_document_varsayilanDegerler() {
        let doc = ProjectDocument(documentName: "Zemin Kat Planı",
                                  documentType: .drawing,
                                  discipline: .architectural,
                                  revisionNo: "Rev.0")
        XCTAssertEqual(doc.documentName, "Zemin Kat Planı")
        XCTAssertEqual(doc.documentType, .drawing)
        XCTAssertEqual(doc.discipline, .architectural)
        XCTAssertEqual(doc.revisionNo, "Rev.0")
        XCTAssertTrue(doc.isCurrentRevision)
        XCTAssertTrue(doc.previousRevisions.isEmpty)
    }

    func test_document_etiketAyrıştırma() {
        let doc = ProjectDocument(documentName: "Test", documentType: .drawing, discipline: .structural)
        doc.tags = "statik, beton, proje"
        let tags = doc.tagList
        XCTAssertEqual(tags.count, 3)
        XCTAssertTrue(tags.contains("statik"))
        XCTAssertTrue(tags.contains("beton"))
        XCTAssertTrue(tags.contains("proje"))
    }

    func test_document_disiplinFiltresi() {
        let docs = [
            ProjectDocument(documentName: "Mimari Plan", documentType: .drawing, discipline: .architectural),
            ProjectDocument(documentName: "Statik", documentType: .calculation, discipline: .structural),
            ProjectDocument(documentName: "Sıhhi", documentType: .drawing, discipline: .mechanical)
        ]
        let mimari = docs.filter { $0.discipline == .architectural }
        XCTAssertEqual(mimari.count, 1)
        XCTAssertEqual(mimari.first?.documentName, "Mimari Plan")
    }

    func test_documentRevision_versiyonlama() {
        let doc = ProjectDocument(documentName: "Strüktür", documentType: .drawing,
                                  discipline: .structural, revisionNo: "Rev.0")
        let rev = DocumentRevision(revisionNo: "Rev.0", document: doc)
        rev.changeDescription = "İlk versiyon arşivlendi"
        doc.previousRevisions.append(rev)
        doc.revisionNo = "Rev.A"
        XCTAssertEqual(doc.revisionNo, "Rev.A")
        XCTAssertEqual(doc.previousRevisions.count, 1)
        XCTAssertEqual(doc.previousRevisions.first?.revisionNo, "Rev.0")
    }
}
