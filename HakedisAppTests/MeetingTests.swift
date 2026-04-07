import XCTest
import SwiftData

// MARK: - Toplantı Yönetimi Testleri

final class MeetingTests: XCTestCase {

    func test_meeting_olusturma() throws {
        let meeting = Meeting(title: "Şantiye Koordinasyon Toplantısı", meetingType: .weeklyCoordination)
        XCTAssertEqual(meeting.title, "Şantiye Koordinasyon Toplantısı")
        XCTAssertEqual(meeting.meetingType, .weeklyCoordination)
        XCTAssertTrue(meeting.decisions.isEmpty)
    }

    func test_meeting_kararEkleme() throws {
        let meeting = Meeting(title: "Haftalık Değerlendirme")
        let karar = MeetingDecision(
            decisionNo: 1,
            decisionText: "Beton dökümü 3 gün ertelendi",
            responsiblePerson: "Şantiye Şefi",
            deadline: Date().addingTimeInterval(86400 * 3)
        )
        karar.meeting = meeting
        meeting.decisions.append(karar)

        XCTAssertEqual(meeting.decisions.count, 1)
        XCTAssertEqual(meeting.openDecisionCount, 1)
    }

    func test_meetingDecision_gecikmiHesap() throws {
        let gecmis = Date().addingTimeInterval(-86400 * 5)
        let karar = MeetingDecision(
            decisionNo: 1,
            decisionText: "Gecikmeli karar",
            responsiblePerson: "Mühendis",
            deadline: gecmis
        )
        XCTAssertTrue(karar.isOverdue)
        XCTAssertEqual(karar.effectiveStatus, .overdue)
    }

    func test_meetingDecision_tamamlanmis() throws {
        let gecmis = Date().addingTimeInterval(-86400)
        let karar = MeetingDecision(
            decisionNo: 2,
            decisionText: "Tamamlandı",
            responsiblePerson: "Ekip",
            deadline: gecmis
        )
        karar.status = .completed
        XCTAssertFalse(karar.isOverdue)
        XCTAssertEqual(karar.effectiveStatus, .completed)
    }

    func test_meeting_katilimcilarJSON() throws {
        let meeting = Meeting(title: "İSG Toplantısı", meetingType: .safety)
        let katilimci = MeetingAttendee(name: "Ahmet Kaya", title: "İSG Uzmanı")
        meeting.attendees = [katilimci]
        XCTAssertEqual(meeting.attendees.count, 1)
        XCTAssertEqual(meeting.attendees.first?.name, "Ahmet Kaya")
    }
}
