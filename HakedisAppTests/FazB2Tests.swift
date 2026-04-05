import XCTest
import Foundation

// MARK: - B2 Toplantı ve Karar Takibi Tests

final class MeetingModelTests: XCTestCase {

    func test_meeting_varsayilanDegerler() {
        let m = Meeting(title: "Haftalık Koordinasyon", meetingType: .weeklyCoordination)
        XCTAssertEqual(m.title, "Haftalık Koordinasyon")
        XCTAssertEqual(m.meetingType, .weeklyCoordination)
        XCTAssertTrue(m.attendees.isEmpty)
        XCTAssertTrue(m.decisions.isEmpty)
        XCTAssertEqual(m.openDecisionCount, 0)
    }

    func test_meeting_katilimciJsonEncodeDecode() {
        let m = Meeting(title: "Test Toplantı", meetingType: .other)
        let att1 = MeetingAttendee(name: "Ahmet Mühendis", title: "İnşaat Müh.", company: "Firma A")
        let att2 = MeetingAttendee(name: "Mehmet Kontrol", title: nil, company: nil)
        m.attendees = [att1, att2]
        let decoded = m.attendees
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded.first?.name, "Ahmet Mühendis")
        XCTAssertEqual(decoded.first?.title, "İnşaat Müh.")
        XCTAssertNil(decoded.last?.title)
    }

    func test_decision_statusFlow() {
        let d = MeetingDecision(decisionNo: 1, decisionText: "Beton dökümü başlatılacak",
                                responsiblePerson: "Şantiye Şefi",
                                deadline: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
        XCTAssertEqual(d.status, .open)
        d.status = .inProgress
        XCTAssertEqual(d.status, .inProgress)
        d.status = .completed
        d.completionDate = Date()
        XCTAssertEqual(d.status, .completed)
        XCTAssertFalse(d.isOverdue)
    }

    func test_decision_gecikme_tespiti() {
        let d = MeetingDecision(decisionNo: 2, decisionText: "Rapor hazırlanacak",
                                responsiblePerson: "Mühendis",
                                deadline: Calendar.current.date(byAdding: .day, value: -5, to: Date())!)
        XCTAssertTrue(d.isOverdue)
        XCTAssertEqual(d.effectiveStatus, .overdue)
    }

    func test_decision_tamamlanan_gecikmiyor() {
        let d = MeetingDecision(decisionNo: 3, decisionText: "Döküm yapıldı",
                                responsiblePerson: "Şef",
                                deadline: Calendar.current.date(byAdding: .day, value: -3, to: Date())!)
        d.status = .completed
        XCTAssertFalse(d.isOverdue)
        XCTAssertEqual(d.effectiveStatus, .completed)
    }

    func test_meeting_openDecisionCount() {
        let m = Meeting(title: "Toplantı", meetingType: .monthlyProgress)
        let d1 = MeetingDecision(decisionNo: 1, decisionText: "Açık karar",
                                  responsiblePerson: "P", deadline: Date())
        let d2 = MeetingDecision(decisionNo: 2, decisionText: "Tamamlanan",
                                  responsiblePerson: "P", deadline: Date())
        d2.status = .completed
        m.decisions = [d1, d2]
        XCTAssertEqual(m.openDecisionCount, 1)
    }
}
