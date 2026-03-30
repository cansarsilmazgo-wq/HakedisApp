import XCTest
import SwiftData

// MARK: - 10 Yeni Özellik Testleri

final class NewFeaturesTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    private static let fullSchema = Schema([
        Project.self, Contractor.self, Contract.self,
        WorkItem.self, DailyEntry.self, Hakedis.self,
        HakedisItem.self, Payment.self, RetentionRelease.self,
        ChangeOrder.self, Milestone.self, SiteReport.self,
        ApprovalStep.self, HakedisRevision.self,
        UnitPriceAnalysis.self, SiteHandoverRecord.self, SiteDeficiency.self,
        MeasurementEntry.self, PhotoAnnotation.self,
        LaborRecord.self, MaterialRecord.self, MaterialTransaction.self,
        SpecificationItem.self,
        CorrespondenceRecord.self, PriceDifferenceRecord.self,
        VATWithholdingRecord.self, SGKLaborRecord.self, SiteLogEntry.self,
        Equipment.self, EquipmentUsage.self,
        SoilRecord.self, TestRecord.self,
        AcceptanceRecord.self, WarrantyClaim.self
    ])

    override func setUpWithError() throws {
        let config = ModelConfiguration(schema: Self.fullSchema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Self.fullSchema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // ─────────────────────────────────────────────────
    // MARK: - 1. Yazışma / Evrak Takibi
    // ─────────────────────────────────────────────────

    func test_correspondence_temelKayit() throws {
        let record = CorrespondenceRecord(
            recordNo: "YZ-2026-001",
            subject: "Hakediş Belgesi Talep",
            direction: .gelen,
            category: .mali
        )
        context.insert(record)
        XCTAssertEqual(record.recordNo, "YZ-2026-001")
        XCTAssertEqual(record.direction, .gelen)
        XCTAssertFalse(record.isReplied, "Yeni kayıt cevaplandı değil")
    }

    func test_correspondence_isOverdue_true() throws {
        let record = CorrespondenceRecord(
            recordNo: "YZ-2026-002",
            subject: "İtiraz Mektubu",
            direction: .giden
        )
        record.replyDeadline = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        context.insert(record)
        XCTAssertTrue(record.isOverdue, "Tarihi geçmiş, cevap verilmemiş → gecikmiş")
    }

    func test_correspondence_isOverdue_false_cevaplandiysa() throws {
        let record = CorrespondenceRecord(
            recordNo: "YZ-2026-003",
            subject: "Onay Yazısı",
            direction: .gelen
        )
        record.replyDeadline = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        record.isReplied = true
        context.insert(record)
        XCTAssertFalse(record.isOverdue, "Cevap verilmişse gecikmiş sayılmaz")
    }

    func test_correspondence_daysLeft_hesabi() throws {
        let record = CorrespondenceRecord(
            recordNo: "YZ-2026-004",
            subject: "Cevap Talep",
            direction: .gelen
        )
        record.replyDeadline = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        context.insert(record)
        let days = record.daysLeft
        XCTAssertNotNil(days)
        XCTAssertGreaterThanOrEqual(days!, 6)
        XCTAssertLessThanOrEqual(days!, 7)
    }

    // ─────────────────────────────────────────────────
    // MARK: - 2. Fiyat Farkı
    // ─────────────────────────────────────────────────

    func test_priceDifference_indexRatio_hesabi() throws {
        let record = PriceDifferenceRecord(
            periodName: "Ocak 2026",
            baseIndex: 100.0,
            currentIndex: 115.0,
            baseAmount: 200_000
        )
        context.insert(record)
        XCTAssertEqual(record.indexRatio, 1.15, accuracy: 0.0001, "115/100 = 1.15")
    }

    func test_priceDifference_fiyatFarki_artisSenaryosu() throws {
        let record = PriceDifferenceRecord(
            periodName: "Şubat 2026",
            baseIndex: 200.0,
            currentIndex: 240.0,
            baseAmount: 500_000
        )
        context.insert(record)
        // ratio = 240/200 = 1.20 → fark = 500000 × 0.20 = 100000
        XCTAssertEqual(record.priceDifference, 100_000, accuracy: 1.0)
        XCTAssertTrue(record.isGain)
    }

    func test_priceDifference_azalisSenaryosu() throws {
        let record = PriceDifferenceRecord(
            periodName: "Mart 2026",
            baseIndex: 300.0,
            currentIndex: 270.0,
            baseAmount: 300_000
        )
        context.insert(record)
        // ratio = 270/300 = 0.90 → fark = 300000 × (-0.10) = -30000
        XCTAssertLessThan(record.priceDifference, 0)
        XCTAssertFalse(record.isGain)
    }

    // ─────────────────────────────────────────────────
    // MARK: - 3. KDV Tevkifatı
    // ─────────────────────────────────────────────────

    func test_vatWithholding_ikiUcteOran() throws {
        let record = VATWithholdingRecord(withholdingRatio: .ikiUcte, totalVATAmount: 30_000)
        context.insert(record)
        // Oran 2/3 → idare öder: 30000 × 2/3 = 20000, yüklenici öder: 10000
        XCTAssertEqual(record.ownerPays, 20_000, accuracy: 1.0, "İdare 2/3 öder")
        XCTAssertEqual(record.contractorPays, 10_000, accuracy: 1.0, "Yüklenici 1/3 öder")
    }

    func test_vatWithholding_yariYariOran() throws {
        let record = VATWithholdingRecord(withholdingRatio: .yariYari, totalVATAmount: 20_000)
        context.insert(record)
        XCTAssertEqual(record.ownerPays, 10_000, accuracy: 1.0)
        XCTAssertEqual(record.contractorPays, 10_000, accuracy: 1.0)
    }

    func test_vatWithholding_toplamKorunur() throws {
        let total = 45_000.0
        let record = VATWithholdingRecord(withholdingRatio: .ikiUcte, totalVATAmount: total)
        context.insert(record)
        XCTAssertEqual(record.contractorPays + record.ownerPays, total, accuracy: 0.001,
                       "Yüklenici + İdare = Toplam KDV")
    }

    // ─────────────────────────────────────────────────
    // MARK: - 4. SGK Asgari İşçilik
    // ─────────────────────────────────────────────────

    func test_sgkLabor_asgariHesap_uyumlu() throws {
        // Sözleşme: 1,000,000 TL, işçilik yoğunluk %25 → asgari: 250,000
        let record = SGKLaborRecord(
            periodName: "2026-Q1",
            contractAmount: 1_000_000,
            laborIntensityRate: 25,
            declaredLaborAmount: 280_000
        )
        context.insert(record)
        XCTAssertEqual(record.minimumLaborAmount, 250_000, accuracy: 1.0)
        XCTAssertTrue(record.isCompliant, "280k > 250k → uyumlu")
        XCTAssertEqual(record.deficiency, 0)
    }

    func test_sgkLabor_eksiklik_hesabi() throws {
        let record = SGKLaborRecord(
            periodName: "2026-Q2",
            contractAmount: 500_000,
            laborIntensityRate: 30,
            declaredLaborAmount: 100_000
        )
        context.insert(record)
        // Asgari: 500000 × 0.30 = 150000, bildirilen: 100000, eksik: 50000
        XCTAssertEqual(record.minimumLaborAmount, 150_000, accuracy: 1.0)
        XCTAssertFalse(record.isCompliant)
        XCTAssertEqual(record.deficiency, 50_000, accuracy: 1.0)
    }

    // ─────────────────────────────────────────────────
    // MARK: - 5. Resmi Şantiye Günlüğü
    // ─────────────────────────────────────────────────

    func test_siteLog_isWorkday_tatilOlmayan() throws {
        let entry = SiteLogEntry(logDate: Date(), weatherCondition: .sunny, isHoliday: false, isSuspended: false)
        context.insert(entry)
        XCTAssertTrue(entry.isWorkday, "Tatil ve askı yoksa çalışma günü")
    }

    func test_siteLog_isWorkday_false_tatilGunu() throws {
        let entry = SiteLogEntry(logDate: Date(), isHoliday: true)
        context.insert(entry)
        XCTAssertFalse(entry.isWorkday, "Tatil günü çalışma günü değil")
    }

    func test_siteLog_isSigned_ikiImzaVar() throws {
        let entry = SiteLogEntry(logDate: Date())
        entry.contractorSignature = "Yüklenici İmzası"
        entry.ownerSignature = "İdare İmzası"
        context.insert(entry)
        XCTAssertTrue(entry.isSigned, "İki imza mevcut → imzalı")
    }

    func test_siteLog_isSigned_false_birImzaEksik() throws {
        let entry = SiteLogEntry(logDate: Date())
        entry.contractorSignature = "Yüklenici İmzası"
        context.insert(entry)
        XCTAssertFalse(entry.isSigned, "Sadece bir imza → imzalı değil")
    }

    // ─────────────────────────────────────────────────
    // MARK: - 6. Ekipman Takibi
    // ─────────────────────────────────────────────────

    func test_equipment_totalUsageDays_veRentalCost() throws {
        let equipment = Equipment(
            name: "Vinç 50T",
            dailyRentalCost: 5_000,
            maintenancePeriodDays: 90
        )
        context.insert(equipment)

        let usage1 = EquipmentUsage(startDate: Date())
        usage1.endDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())
        usage1.equipment = equipment
        context.insert(usage1)
        equipment.usageRecords.append(usage1)

        // durationDays = 10
        XCTAssertEqual(equipment.totalUsageDays, 10)
        XCTAssertEqual(equipment.totalRentalCost, 50_000, accuracy: 1.0)
    }

    func test_equipment_isMaintenanceDue_bakimGerekli() throws {
        let equipment = Equipment(name: "Ekskavatör", maintenancePeriodDays: 30)
        equipment.lastMaintenanceDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())
        context.insert(equipment)
        XCTAssertTrue(equipment.isMaintenanceDue, "31 gün geçmiş, periyot 30 gün → bakım gerekli")
    }

    func test_equipment_isMaintenanceDue_false_yenibakim() throws {
        let equipment = Equipment(name: "Beton Mikseri", maintenancePeriodDays: 60)
        equipment.lastMaintenanceDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        context.insert(equipment)
        XCTAssertFalse(equipment.isMaintenanceDue, "10 gün geçmiş, periyot 60 gün → bakım gerekmez")
    }

    // ─────────────────────────────────────────────────
    // MARK: - 7. Zemin / Kazı Tutanağı
    // ─────────────────────────────────────────────────

    func test_soilRecord_calculatedVolume() throws {
        let record = SoilRecord(location: "Temel Kazısı A", depth: 4.5, area: 200.0)
        context.insert(record)
        // Hacim = 4.5 × 200 = 900 m³
        XCTAssertEqual(record.calculatedVolume, 900, accuracy: 0.001)
    }

    func test_soilRecord_labTestsJSON_decode() throws {
        let record = SoilRecord(location: "B Aksı", depth: 2.0, area: 50.0)
        record.labTestsJSON = #"[{"testName":"Granülometri","result":"Uygun","isCompliant":true}]"#
        context.insert(record)
        XCTAssertEqual(record.labTests.count, 1)
        XCTAssertEqual(record.labTests.first?.testName, "Granülometri")
        XCTAssertTrue(record.labTests.first?.isCompliant == true)
    }

    // ─────────────────────────────────────────────────
    // MARK: - 8. Test / Deney Sonuçları
    // ─────────────────────────────────────────────────

    func test_testRecord_isInRange_true() throws {
        let record = TestRecord(testName: "C30 Beton Basınç", category: .beton, unit: "MPa")
        record.minimumAcceptable = 30.0
        record.maximumAcceptable = 60.0
        record.result = 35.0
        context.insert(record)
        XCTAssertTrue(record.isInRange, "35 MPa, [30-60] aralığında → geçti")
    }

    func test_testRecord_isInRange_false_altindaKaldi() throws {
        let record = TestRecord(testName: "C30 Basınç", category: .beton, unit: "MPa")
        record.minimumAcceptable = 30.0
        record.result = 22.0
        context.insert(record)
        XCTAssertFalse(record.isInRange, "22 MPa < 30 MPa → kaldı")
    }

    func test_testRecord_isInRange_false_sonucYok() throws {
        let record = TestRecord(testName: "Zemin Taşıma", category: .zemin, unit: "kPa")
        record.minimumAcceptable = 150.0
        context.insert(record)
        XCTAssertFalse(record.isInRange, "Sonuç girilmemişse isInRange false")
    }

    // ─────────────────────────────────────────────────
    // MARK: - 9. Geçici / Kesin Kabul
    // ─────────────────────────────────────────────────

    func test_acceptance_warrantyEndDate_24Ay() throws {
        let kabul = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let record = AcceptanceRecord(acceptanceType: .gecici, acceptanceDate: kabul, warrantyMonths: 24)
        context.insert(record)

        let beklenenBitis = Calendar.current.date(from: DateComponents(year: 2028, month: 1, day: 1))!
        XCTAssertEqual(record.warrantyEndDate, beklenenBitis, "24 aylık garanti → Ocak 2028 bitiş")
    }

    func test_acceptance_isWarrantyActive_true() throws {
        let kabul = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let record = AcceptanceRecord(acceptanceType: .gecici, acceptanceDate: kabul, warrantyMonths: 24)
        context.insert(record)
        XCTAssertTrue(record.isWarrantyActive, "6 ay geçmiş, 24 aylık garanti → hâlâ aktif")
    }

    func test_acceptance_isWarrantyActive_false_sureGecmis() throws {
        let eskiKabul = Calendar.current.date(byAdding: .month, value: -30, to: Date())!
        let record = AcceptanceRecord(acceptanceType: .kesin, acceptanceDate: eskiKabul, warrantyMonths: 24)
        context.insert(record)
        XCTAssertFalse(record.isWarrantyActive, "30 ay geçmiş, 24 aylık garanti → sona erdi")
    }

    func test_acceptance_warrantyDaysLeft_sifirVeyaPozitif() throws {
        let kabul = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let record = AcceptanceRecord(acceptanceType: .gecici, acceptanceDate: kabul, warrantyMonths: 24)
        context.insert(record)
        XCTAssertGreaterThan(record.warrantyDaysLeft, 0, "1 ay geçmiş, 24 aylık garanti → gün kaldı")
    }

    // ─────────────────────────────────────────────────
    // MARK: - 10. Garanti Süresi / Talep Takibi
    // ─────────────────────────────────────────────────

    func test_warrantyClaim_isOpen_true() throws {
        let claim = WarrantyClaim(claimDescription: "Çatı sızıntısı", category: .yapisal, severity: .yuksek)
        context.insert(claim)
        XCTAssertTrue(claim.isOpen, "Yeni talep açık statüde")
        XCTAssertEqual(claim.status, .acik)
    }

    func test_warrantyClaim_isOpen_false_kapandiysa() throws {
        let claim = WarrantyClaim(claimDescription: "Boya dökülmesi", category: .boya, severity: .dusuk)
        claim.status = .kapatildi
        claim.closedAt = Date()
        context.insert(claim)
        XCTAssertFalse(claim.isOpen, "Kapatılmış talep açık değil")
    }

    func test_warrantyClaim_isOverdue_true() throws {
        let claim = WarrantyClaim(claimDescription: "Zemin çökmesi", category: .yapisal, severity: .kritik)
        claim.responseDeadline = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        context.insert(claim)
        XCTAssertTrue(claim.isOverdue, "Tarihi geçmiş açık talep gecikmiş")
    }

    func test_warrantyClaim_isOverdue_false_kapandiysa() throws {
        let claim = WarrantyClaim(claimDescription: "Kapı rayı", category: .mekanik, severity: .orta)
        claim.responseDeadline = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        claim.status = .kapatildi
        context.insert(claim)
        XCTAssertFalse(claim.isOverdue, "Kapatılmış talep gecikmiş sayılmaz")
    }
}
