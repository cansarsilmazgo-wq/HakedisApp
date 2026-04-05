import XCTest
import Foundation

// MARK: - B9 Raporlama Motoru Tests

final class ReportTemplateModelTests: XCTestCase {

    func test_reportTemplate_varsayilanDegerler() {
        let t = ReportTemplate(templateName: "Haftalık", type: .weekly)
        XCTAssertEqual(t.reportType, .weekly)
        XCTAssertFalse(t.isDefault)
        XCTAssertEqual(t.sections.count, 0)
    }

    func test_reportTemplate_defaultSections_weekly() {
        let sections = ReportTemplate.defaultSections(for: .weekly)
        XCTAssertFalse(sections.isEmpty)
        XCTAssertTrue(sections.contains(where: { $0.sectionType == .summary }))
        XCTAssertTrue(sections.contains(where: { $0.sectionType == .progress }))
    }

    func test_reportTemplate_sectionsJsonEncodeDecode() {
        let t = ReportTemplate(templateName: "Test", type: .financial)
        t.sections = ReportTemplate.defaultSections(for: .financial)
        let decoded = t.sections
        XCTAssertFalse(decoded.isEmpty)
        XCTAssertTrue(decoded.allSatisfy(\.isEnabled))
    }

    func test_reportTemplate_enabledSections() {
        let t = ReportTemplate(templateName: "Kalite", type: .quality)
        var sections = ReportTemplate.defaultSections(for: .quality)
        sections[0].isEnabled = false
        t.sections = sections
        XCTAssertEqual(t.enabledSections.count, sections.count - 1)
    }
}
