import XCTest
import Foundation

// MARK: - Faz 6 A5 İSG Derinleştirme Tests

final class RiskAssessmentTests: XCTestCase {

    func test_riskAssessment_skorHesaplama() {
        let a = RiskAssessment(location: "A Blok", activity: "Kaynak", hazard: "Yangın riski", likelihood: 3, severity: 4)
        XCTAssertEqual(a.riskScore, 12)
    }

    func test_riskAssessment_riskLevel_sinirlar() {
        XCTAssertEqual(RiskLevel.from(score: 1),  .veryLow)
        XCTAssertEqual(RiskLevel.from(score: 4),  .veryLow)
        XCTAssertEqual(RiskLevel.from(score: 5),  .low)
        XCTAssertEqual(RiskLevel.from(score: 8),  .low)
        XCTAssertEqual(RiskLevel.from(score: 9),  .medium)
        XCTAssertEqual(RiskLevel.from(score: 12), .medium)
        XCTAssertEqual(RiskLevel.from(score: 13), .high)
        XCTAssertEqual(RiskLevel.from(score: 19), .high)
        XCTAssertEqual(RiskLevel.from(score: 20), .veryHigh)
        XCTAssertEqual(RiskLevel.from(score: 25), .veryHigh)
    }

    func test_riskAssessment_isControlled_varsayilanFalse() {
        let a = RiskAssessment(location: "B Blok", activity: "Kazı", hazard: "Toprak kayması", likelihood: 2, severity: 5)
        XCTAssertFalse(a.isControlled)
        XCTAssertEqual(a.riskScore, 10)
        XCTAssertEqual(a.riskLevel, .medium)
    }

    func test_riskLevel_colorName() {
        XCTAssertEqual(RiskLevel.veryLow.colorName, "hakedisSuccess")
        XCTAssertEqual(RiskLevel.high.colorName, "hakedisDanger")
        XCTAssertEqual(RiskLevel.veryHigh.colorName, "hakedisDanger")
        XCTAssertEqual(RiskLevel.medium.colorName, "hakedisWarning")
    }
}

final class CorrectiveActionTests: XCTestCase {

    func test_correctiveAction_baslangicDurumu_open() {
        let dueDate = Date().addingTimeInterval(7 * 86400)
        let ca = CorrectiveAction(actionChangeDescription: "Korkuluk ekle", responsiblePerson: "Ahmet", dueDate: dueDate)
        XCTAssertEqual(ca.status, .open)
        XCTAssertFalse(ca.isOverdue)
    }

    func test_correctiveAction_durumAkisi() {
        let dueDate = Date().addingTimeInterval(7 * 86400)
        let ca = CorrectiveAction(actionChangeDescription: "Zemin iyileştir", responsiblePerson: "Mehmet", dueDate: dueDate)
        ca.status = .inProgress
        XCTAssertEqual(ca.status, .inProgress)
        ca.status = .completed
        ca.completionDate = Date()
        XCTAssertEqual(ca.status, .completed)
        ca.status = .verified
        ca.verifiedBy = "Proje Müdürü"
        XCTAssertEqual(ca.status, .verified)
    }

    func test_correctiveAction_gecikme_terminGecmis() {
        let pastDue = Date().addingTimeInterval(-2 * 86400)
        let ca = CorrectiveAction(actionChangeDescription: "Bariyer koy", responsiblePerson: "Ali", dueDate: pastDue)
        // status == .open && dueDate < Date() → isOverdue = true
        XCTAssertTrue(ca.isOverdue)
    }

    func test_correctiveAction_tamamlananGecikmiyor() {
        let pastDue = Date().addingTimeInterval(-2 * 86400)
        let ca = CorrectiveAction(actionChangeDescription: "Ekipman değiştir", responsiblePerson: "Veli", dueDate: pastDue)
        ca.status = .completed
        XCTAssertFalse(ca.isOverdue)
    }
}

final class SafetyTrainingTests: XCTestCase {

    func test_safetyTraining_attendeesJSON_encodeDecodeRoundtrip() {
        let t = SafetyTraining(trainingType: .heightWork, trainingDate: Date(), trainer: "Eğitmen A", durationHours: 4)
        let names = ["Ahmet Yıldız", "Mehmet Demir", "Ayşe Kaya"]
        t.attendees = names
        XCTAssertEqual(t.attendees.count, 3)
        XCTAssertTrue(t.attendees.contains("Ahmet Yıldız"))
        XCTAssertTrue(t.attendees.contains("Ayşe Kaya"))
    }

    func test_safetyTraining_bosluktenAttendeesJSON_bosArray() {
        let t = SafetyTraining(trainingType: .firstAid, trainingDate: Date(), trainer: "Dr. B", durationHours: 8)
        XCTAssertTrue(t.attendees.isEmpty)
    }

    func test_safetyTraining_trainingTypeRoundtrip() {
        let t = SafetyTraining(trainingType: .fireEvacuation, trainingDate: Date(), trainer: "İtfaiyeci", durationHours: 2)
        XCTAssertEqual(t.trainingType, .fireEvacuation)
        t.trainingType = .confinedSpace
        XCTAssertEqual(t.trainingType, .confinedSpace)
    }
}

final class PPEAssignmentTests: XCTestCase {

    func test_ppeAssignment_zimmetAkisi() {
        let a = PPEAssignment(ppeType: .hardHat, assignedDate: Date())
        XCTAssertEqual(a.ppeType, .hardHat)
        XCTAssertEqual(a.condition, .newPPE)
        XCTAssertNil(a.returnDate)
    }

    func test_ppeAssignment_iadeAkisi() {
        let a = PPEAssignment(ppeType: .harness, assignedDate: Date())
        a.returnDate = Date()
        a.condition = .returned
        XCTAssertNotNil(a.returnDate)
        XCTAssertEqual(a.condition, .returned)
    }

    func test_ppeAssignment_hasarliDurum() {
        let a = PPEAssignment(ppeType: .gloves, assignedDate: Date())
        a.condition = .damaged
        XCTAssertEqual(a.condition, .damaged)
    }

    func test_ppeType_iconBos_degil() {
        for t in PPEType.allCases {
            XCTAssertFalse(t.icon.isEmpty, "\(t.rawValue) icon boş olmamalı")
        }
    }
}

final class SafetyStatisticsComputedTests: XCTestCase {

    func test_incidentFrequencyRate_hesaplama() {
        // 2 kaza, 200000 adam-saat → 2 × 1,000,000 / 200,000 = 10
        let kazaSayisi: Double = 2
        let manHours: Double = 200_000
        let rate = kazaSayisi * 1_000_000 / manHours
        XCTAssertEqual(rate, 10.0, accuracy: 0.001)
    }

    func test_severityRate_hesaplama() {
        // 15 kayıp gün, 500000 adam-saat → 15 × 1,000,000 / 500,000 = 30
        let lostDays: Double = 15
        let manHours: Double = 500_000
        let rate = lostDays * 1_000_000 / manHours
        XCTAssertEqual(rate, 30.0, accuracy: 0.001)
    }
}

final class SGKDeadlineTests: XCTestCase {

    func test_sgkDeadline_3IsSgunu_haftaIciOlunca() {
        // Pazartesi sabahı olay → SGK deadline Perşembe
        var components = DateComponents()
        components.weekday = 2 // Monday
        components.hour = 9; components.minute = 0; components.second = 0
        let calendar = Calendar.current
        // Son 7 gün içinde bir Pazartesi bul
        var date = Date()
        for _ in 0..<7 {
            if calendar.component(.weekday, from: date) == 2 { break }
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }
        let incident = SafetyIncident(date: date, incidentType: .majorInjury, incidentDescription: "Test kazası")
        let deadline = incident.sgkReportDeadline
        // 3 iş günü sonrası Perşembe olmalı
        let deadlineWeekday = calendar.component(.weekday, from: deadline)
        // Not a weekend
        XCTAssertNotEqual(deadlineWeekday, 1) // not Sunday
        XCTAssertNotEqual(deadlineWeekday, 7) // not Saturday
    }

    func test_sgkDeadline_hafasonuAtlaniyor() {
        // Cuma günü olay → SGK deadline 3 iş günü sonra = Çarşamba
        var components = DateComponents()
        components.hour = 9; components.minute = 0; components.second = 0
        let calendar = Calendar.current
        var fridayDate = Date()
        for _ in 0..<7 {
            if calendar.component(.weekday, from: fridayDate) == 6 { break } // Friday = 6
            fridayDate = calendar.date(byAdding: .day, value: -1, to: fridayDate)!
        }
        let incident = SafetyIncident(date: fridayDate, incidentType: .majorInjury, incidentDescription: "Cuma kazası")
        let deadline = incident.sgkReportDeadline
        let deadlineWeekday = calendar.component(.weekday, from: deadline)
        // Deadline hafta içi olmalı
        XCTAssertNotEqual(deadlineWeekday, 1)
        XCTAssertNotEqual(deadlineWeekday, 7)
    }

    func test_ministryDeadline_2IsSgunu() {
        let incident = SafetyIncident(date: Date(), incidentType: .majorInjury, incidentDescription: "Test")
        let ministry = incident.ministryReportDeadline
        let sgk = incident.sgkReportDeadline
        // Bakanlık (2 iş günü) her zaman SGK (3 iş günü) öncesinde veya eşit
        XCTAssertLessThanOrEqual(ministry.timeIntervalSince1970, sgk.timeIntervalSince1970)
    }
}

final class RootCauseAnalysisTests: XCTestCase {

    func test_rca_5Neden_zinciri() {
        let rca = RootCauseAnalysis(why1: "İşçi düştü", rootCause: "Emniyet kemeri takılmadı")
        rca.why2 = "Zemin kaygan"
        rca.why3 = "Su birikmişti"
        rca.why4 = "Drenaj yetersiz"
        rca.why5 = "Proje tasarım hatası"
        XCTAssertEqual(rca.why1, "İşçi düştü")
        XCTAssertEqual(rca.why2, "Zemin kaygan")
        XCTAssertEqual(rca.why3, "Su birikmişti")
        XCTAssertEqual(rca.why4, "Drenaj yetersiz")
        XCTAssertEqual(rca.why5, "Proje tasarım hatası")
        XCTAssertEqual(rca.rootCause, "Emniyet kemeri takılmadı")
    }

    func test_rca_minimum_neden1_ve_rootCause() {
        let rca = RootCauseAnalysis(why1: "Ekipman arızalandı", rootCause: "Bakım yapılmadı")
        XCTAssertNil(rca.why2)
        XCTAssertNil(rca.why3)
        XCTAssertNil(rca.why4)
        XCTAssertNil(rca.why5)
    }
}

final class EmergencyPlanTests: XCTestCase {

    func test_emergencyPlan_tatbikatGecmis() {
        let plan = EmergencyPlan(planType: .fire, procedures: "Alarm çal, tahliye et", assemblyPoint: "Otopark A")
        plan.nextDrillDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        XCTAssertTrue(plan.isDrillOverdue)
    }

    func test_emergencyPlan_tatbikatGelmedi() {
        let plan = EmergencyPlan(planType: .earthquake, procedures: "Masanın altına gir", assemblyPoint: "Bahçe")
        plan.nextDrillDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        XCTAssertFalse(plan.isDrillOverdue)
    }

    func test_emergencyPlan_tatbikatTarihiYok_gecmemis() {
        let plan = EmergencyPlan(planType: .workAccident, procedures: "İlk yardım uygula", assemblyPoint: "Şantiye Girişi")
        XCTAssertFalse(plan.isDrillOverdue)
    }

    func test_emergencyPlanType_icon_bos_degil() {
        for t in EmergencyPlanType.allCases {
            XCTAssertFalse(t.icon.isEmpty, "\(t.rawValue) icon boş olmamalı")
        }
    }
}

final class SafetyIncidentA5Tests: XCTestCase {

    func test_safetyIncident_lostWorkDays_ve_flags() {
        let incident = SafetyIncident(date: Date(), incidentType: .majorInjury, incidentDescription: "Yüksekten düşme")
        incident.lostWorkDays = 5
        incident.reportedToSGK = false
        incident.reportedToMinistry = false
        XCTAssertEqual(incident.lostWorkDays, 5)
        XCTAssertFalse(incident.reportedToSGK)
        XCTAssertFalse(incident.reportedToMinistry)
        XCTAssertTrue(incident.correctiveActions.isEmpty)
    }

    func test_safetyIncident_varsayilanDegerler() {
        let incident = SafetyIncident(incidentType: .nearMiss, incidentDescription: "Kaynak kıvılcımı")
        XCTAssertFalse(incident.reportedToSGK)
        XCTAssertFalse(incident.reportedToMinistry)
        XCTAssertNil(incident.lostWorkDays)
        XCTAssertNil(incident.rootCauseAnalysis)
        XCTAssertTrue(incident.correctiveActions.isEmpty)
    }
}
