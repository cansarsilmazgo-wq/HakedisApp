import XCTest
import Foundation

// MARK: - A1 Şantiye Günlüğü Derinleştirme Tests

final class ShiftTypeTests: XCTestCase {

    func test_shiftType_gunduzsVardiya_rawValue() {
        let shift = ShiftType.dayShift
        XCTAssertEqual(shift.rawValue, "Gündüz")
        XCTAssertEqual(shift.icon, "sun.max")
    }

    func test_shiftType_geceVardiya_rawValue() {
        let shift = ShiftType.nightShift
        XCTAssertEqual(shift.rawValue, "Gece")
        XCTAssertEqual(shift.icon, "moon.stars")
    }

    func test_delayReason_tumCaseIterable() {
        XCTAssertEqual(DelayReason.allCases.count, 6)
    }

    func test_delayReason_yagmur_rawValue() {
        let reason = DelayReason.rain
        XCTAssertEqual(reason.rawValue, "Yağmur")
    }

    func test_delayReason_ekipmanArizasi_icon() {
        let reason = DelayReason.equipmentFailure
        XCTAssertFalse(reason.icon.isEmpty)
    }
}

// MARK: - A2 Puantaj Derinleştirme Tests

final class WorkerModelTests: XCTestCase {

    func test_worker_olusturma_varsayilanDegerler() {
        let worker = Worker(fullName: "Ahmet Yılmaz", profession: .carpenter)
        XCTAssertEqual(worker.fullName, "Ahmet Yılmaz")
        XCTAssertEqual(worker.profession, .carpenter)
        XCTAssertTrue(worker.isActive)
        XCTAssertEqual(worker.dailyCost, 0.0, accuracy: 0.001)
        XCTAssertEqual(worker.hourlyCost, 0.0, accuracy: 0.001)
        XCTAssertTrue(worker.certificates.isEmpty)
    }

    func test_worker_meslekIkon_demir() {
        let worker = Worker(fullName: "Mehmet Demir", profession: .ironworker)
        XCTAssertEqual(worker.profession.icon, "wrench")
    }
}

final class WorkerCertificateTests: XCTestCase {

    func test_certificate_sureceDoldu_gecmisTarih() {
        let cert = WorkerCertificate(certificateType: .osgTraining, issueDate: Date())
        cert.expiryDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        XCTAssertTrue(cert.isExpired)
    }

    func test_certificate_sureceDolmadi_gelecekTarih() {
        let cert = WorkerCertificate(certificateType: .firstAid, issueDate: Date())
        cert.expiryDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())
        XCTAssertFalse(cert.isExpired)
    }

    func test_certificate_yakindaDolanSurec_29Gun() {
        let cert = WorkerCertificate(certificateType: .heightWork, issueDate: Date())
        cert.expiryDate = Calendar.current.date(byAdding: .day, value: 29, to: Date())
        XCTAssertTrue(cert.isExpiringSoon)
        XCTAssertFalse(cert.isExpired)
    }

    func test_certificate_renewalMonths_osgTraining() {
        XCTAssertEqual(CertificateType.osgTraining.requiredRenewalMonths, 12)
    }
}

final class OvertimeTypeTests: XCTestCase {

    func test_overtimeType_normalCarpan_1_5() {
        XCTAssertEqual(OvertimeType.normal.multiplier, 1.5, accuracy: 0.001)
    }

    func test_overtimeType_haftasonuCarpan_2_0() {
        XCTAssertEqual(OvertimeType.weekend.multiplier, 2.0, accuracy: 0.001)
    }

    func test_overtimeType_tatilCarpan_2_0() {
        XCTAssertEqual(OvertimeType.holiday.multiplier, 2.0, accuracy: 0.001)
    }
}

final class AttendanceCostTests: XCTestCase {

    func test_attendance_maliyetHesabi_normalMesai() {
        let worker = Worker(fullName: "Test İşçi", profession: .laborer)
        worker.hourlyCost = 100.0
        let att = Attendance(date: Date(), workerName: "Test İşçi")
        att.worker = worker
        att.normalHours = 8.0
        att.overtimeHours = 0.0
        // 8 * 100 = 800
        XCTAssertEqual(att.normalCost, 800.0, accuracy: 0.001)
        XCTAssertEqual(att.totalDailyCost, 800.0, accuracy: 0.001)
    }

    func test_attendance_fazlaMesaiMaliyeti_normalCarpan() {
        let worker = Worker(fullName: "Test İşçi", profession: .laborer)
        worker.hourlyCost = 100.0
        let att = Attendance(date: Date(), workerName: "Test İşçi")
        att.worker = worker
        att.normalHours = 8.0
        att.overtimeHours = 2.0
        att.overtimeType = .normal
        // normal cost: 8 * 100 = 800
        // overtime cost: 2 * 100 * 1.5 = 300
        // total: 1100
        XCTAssertEqual(att.normalCost, 800.0, accuracy: 0.001)
        XCTAssertEqual(att.overtimeCost, 300.0, accuracy: 0.001)
        XCTAssertEqual(att.totalDailyCost, 1100.0, accuracy: 0.001)
    }
}

final class PuantajApprovalTests: XCTestCase {

    func test_attendance_varsayilanOnay_taslak() {
        let att = Attendance(date: Date(), workerName: "Test")
        XCTAssertEqual(att.approvalStatus, .draft)
    }

    func test_attendance_onayDurumu_degistir() {
        let att = Attendance(date: Date(), workerName: "Test")
        att.approvalStatus = .submitted
        XCTAssertEqual(att.approvalStatus, .submitted)
        att.approvalStatus = .approved
        XCTAssertEqual(att.approvalStatus, .approved)
    }
}

final class YillikIzinTests: XCTestCase {

    func test_yillikIzin_1yildan5yilaKadar_14Gun() {
        let worker = Worker(fullName: "Test", profession: .laborer)
        let startDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        XCTAssertEqual(worker.annualLeaveDays(since: startDate), 14)
    }

    func test_yillikIzin_5yildan15yilaKadar_20Gun() {
        let worker = Worker(fullName: "Test", profession: .laborer)
        let startDate = Calendar.current.date(byAdding: .year, value: -8, to: Date())!
        XCTAssertEqual(worker.annualLeaveDays(since: startDate), 20)
    }

    func test_yillikIzin_15YilveUzeri_26Gun() {
        let worker = Worker(fullName: "Test", profession: .laborer)
        let startDate = Calendar.current.date(byAdding: .year, value: -16, to: Date())!
        XCTAssertEqual(worker.annualLeaveDays(since: startDate), 26)
    }
}

final class EffectiveNameTests: XCTestCase {

    func test_effectiveName_workerIliskisiVarsa_workerAdi() {
        let worker = Worker(fullName: "Kadir Şahin", profession: .foreman)
        let att = Attendance(date: Date(), workerName: "Eski Ad")
        att.worker = worker
        XCTAssertEqual(att.effectiveName, "Kadir Şahin")
    }

    func test_effectiveName_workerIliskisiYoksa_workerName() {
        let att = Attendance(date: Date(), workerName: "Manuel Girilen Ad")
        XCTAssertNil(att.worker)
        XCTAssertEqual(att.effectiveName, "Manuel Girilen Ad")
    }
}
