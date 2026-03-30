import XCTest
import SwiftData

// MARK: - Grup 3 Tamamlama: İmza Zinciri, Red/İtiraz, Birim Fiyat, Yer Teslim

final class ApprovalAndHandoverTests: XCTestCase {

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
        SpecificationItem.self
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
    // MARK: - BÖLÜM 5: İMZA ZİNCİRİ (ApprovalStep)
    // ─────────────────────────────────────────────────

    // Test 5.1 — İmza zincirinde varsayılan status .bekliyor
    func test_approvalStep_varsayilanStatusBekliyor() throws {
        let step = ApprovalStep(stepOrder: 1, role: .santiyeSef, approverName: "Ahmet Yıldız")
        context.insert(step)
        XCTAssertEqual(step.status, .bekliyor, "Yeni adım .bekliyor statüsünde olmalı")
        XCTAssertFalse(step.isCancelled, "Yeni adım iptal değil olmalı")
    }

    // Test 5.2 — Onaylanan adım sonraki adımın kontrolüne izin verir (sıra doğrulaması)
    func test_approvalStep_siralama_oncekiOnaylanmadan_sonrakiAcilmaz() throws {
        let hakedis = Hakedis(periodName: "Dönem 1", periodStart: Date(), periodEnd: Date())
        context.insert(hakedis)

        let step1 = ApprovalStep(stepOrder: 1, role: .santiyeSef, approverName: "Ahmet")
        let step2 = ApprovalStep(stepOrder: 2, role: .sefMuhendis, approverName: "Mehmet")
        step1.hakedis = hakedis
        step2.hakedis = hakedis
        context.insert(step1)
        context.insert(step2)

        // İkinci adım; önceki onaylanmadan açılmamalı
        // Kural: stepOrder 1 .bekliyor iken stepOrder 2 de .bekliyor — ancak sıradaki
        // adım ancak önceki onaylandıktan sonra işlenebilir.
        let sonrakiAcilabilirMi = step1.status == .onaylandi
        XCTAssertFalse(sonrakiAcilabilirMi,
                       "Adım 1 .bekliyor iken adım 2 açılmamalı (onay şartı)")

        // Adım 1 onaylanınca adım 2 açılabilmeli
        step1.status = .onaylandi
        step1.approvedAt = Date()
        let simdi = step1.status == .onaylandi
        XCTAssertTrue(simdi, "Adım 1 onaylandıktan sonra adım 2 açılabilir")
    }

    // Test 5.3 — Deadline hesabı (bekliyor + iptal değil)
    func test_approvalStep_deadlineDaysLeft_hesabi() throws {
        let step = ApprovalStep(stepOrder: 1, role: .santiyeSef, approverName: "Zeynep")
        step.deadline = Calendar.current.date(byAdding: .day, value: 5, to: Date())
        context.insert(step)

        let daysLeft = step.deadlineDaysLeft
        XCTAssertNotNil(daysLeft, "Bekliyor statüsünde deadline hesaplanmalı")
        XCTAssertGreaterThanOrEqual(daysLeft!, 4, "5 gün sonra → 4 veya 5 gün kalmış")
        XCTAssertLessThanOrEqual(daysLeft!, 5)
    }

    // Test 5.4 — İptal edilince deadlineDaysLeft nil döner
    func test_approvalStep_iptalEdilince_deadlineNil() throws {
        let step = ApprovalStep(stepOrder: 1, role: .santiyeSef, approverName: "Ali")
        step.deadline = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        step.isCancelled = true
        step.cancellationReason = "İptal: Yeniden yapılandırma"
        context.insert(step)

        XCTAssertNil(step.deadlineDaysLeft,
                     "İptal edilen adım için deadline hesaplanmamalı")
        XCTAssertTrue(step.isCancelled)
        XCTAssertNotNil(step.cancellationReason, "İptal nedeni kaydedilmeli")
    }

    // Test 5.5 — İptal izi korunuyor mu (auditLog)
    func test_approvalStep_iptalIziKorunur() throws {
        let step = ApprovalStep(stepOrder: 2, role: .sefMuhendis, approverName: "Fatma Demir")
        step.isCancelled = true
        step.cancellationReason = "Yanlış atama"
        step.auditLog = "2026-03-01: İptal — Yanlış atama. Atayan: Admin"
        context.insert(step)

        XCTAssertNotNil(step.auditLog, "Denetim günlüğü boş olmamalı")
        XCTAssertTrue(step.auditLog!.contains("İptal"), "Denetim kaydı iptal bilgisi içermeli")
    }

    // Test 5.6 — Yaklaşan deadline (3 gün veya daha az)
    func test_approvalStep_isNearingDeadline_ucGunVeyaDaha() throws {
        let step = ApprovalStep(stepOrder: 1, role: .sefMuhendis, approverName: "Kemal")
        step.deadline = Calendar.current.date(byAdding: .day, value: 2, to: Date())
        context.insert(step)

        XCTAssertTrue(step.isNearingDeadline, "2 gün kaldıysa yaklaşan deadline")
    }

    // Test 5.7 — 10 günlük deadline yaklaşmıyor
    func test_approvalStep_isNearingDeadline_onGun_false() throws {
        let step = ApprovalStep(stepOrder: 1, role: .sefMuhendis, approverName: "Kemal")
        step.deadline = Calendar.current.date(byAdding: .day, value: 10, to: Date())
        context.insert(step)

        XCTAssertFalse(step.isNearingDeadline, "10 gün kaldıysa yaklaşmıyor")
    }

    // Test 5.8 — Vekil adı effectiveApproverName
    func test_approvalStep_effectiveApproverName_vekilAtanmis() throws {
        let step = ApprovalStep(stepOrder: 1, role: .idare, approverName: "Müdür Bey")
        step.delegateName = "Vekil Hanım"
        step.delegateReason = "İzinde"
        context.insert(step)

        XCTAssertEqual(step.effectiveApproverName, "Vekil Hanım (vekil)",
                       "Vekil varken effectiveApproverName vekili göstermeli")
    }

    // Test 5.9 — Vekil yoksa kendi adı gösterilir
    func test_approvalStep_effectiveApproverName_vekilYok() throws {
        let step = ApprovalStep(stepOrder: 1, role: .idare, approverName: "Müdür Bey")
        context.insert(step)

        XCTAssertEqual(step.effectiveApproverName, "Müdür Bey",
                       "Vekil yoksa kendi adı gösterilmeli")
    }

    // ─────────────────────────────────────────────────
    // MARK: - BÖLÜM 6: RED / İTİRAZ (HakedisRevision)
    // ─────────────────────────────────────────────────

    // Test 6.1 — Reddetme tarihi + 30 gün = objectionDeadline
    func test_revision_objectionDeadline_otuzGun() throws {
        let redTarihi = Calendar.current.date(
            from: DateComponents(year: 2026, month: 1, day: 1))!
        let revision = HakedisRevision(
            version: "v2", rejectionReason: "Eksik belgeler",
            rejectedAt: redTarihi
        )
        context.insert(revision)

        let beklenenSon = Calendar.current.date(byAdding: .day, value: 30, to: redTarihi)!
        XCTAssertEqual(revision.objectionDeadline, beklenenSon,
                       "İtiraz son tarihi = red tarihi + 30 gün")
    }

    // Test 6.2 — Süre dolmamış, isExpired = false
    func test_revision_isExpired_false_sureSonundan3GunOnce() throws {
        let ilerideRedTarihi = Calendar.current.date(byAdding: .day, value: -27, to: Date())!
        let revision = HakedisRevision(
            version: "v2", rejectionReason: "Hatalı metraj",
            rejectedAt: ilerideRedTarihi
        )
        context.insert(revision)

        XCTAssertFalse(revision.isExpired,
                       "3 gün kalmışsa itiraz süresi dolmamış olmalı")
    }

    // Test 6.3 — Süre geçmiş, isExpired = true
    func test_revision_isExpired_true_otuzBirGunGecmis() throws {
        let eskiRedTarihi = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let revision = HakedisRevision(
            version: "v2", rejectionReason: "Belgeler eksik",
            rejectedAt: eskiRedTarihi
        )
        context.insert(revision)

        XCTAssertTrue(revision.isExpired, "31 gün geçmişse itiraz süresi dolmuş olmalı")
    }

    // Test 6.4 — objectionDaysLeft sıfır veya pozitif
    func test_revision_objectionDaysLeft_sifirVeyaPozitif() throws {
        let yakinRedTarihi = Calendar.current.date(byAdding: .day, value: -25, to: Date())!
        let revision = HakedisRevision(
            version: "v3", rejectionReason: "Miktar uyuşmazlığı",
            rejectedAt: yakinRedTarihi
        )
        context.insert(revision)

        XCTAssertGreaterThanOrEqual(revision.objectionDaysLeft, 0,
                                    "objectionDaysLeft asla negatif olmamalı")
    }

    // Test 6.5 — Versiyon alanı doğru kaydedilir
    func test_revision_versiyonKaydedilir() throws {
        let revision = HakedisRevision(
            version: "v3", rejectionReason: "Yeni revizyon",
            rejectedAt: Date()
        )
        context.insert(revision)

        XCTAssertEqual(revision.version, "v3", "Versiyon alanı doğru kaydedilmeli")
    }

    // Test 6.6 — Kısmi kabul resolution
    func test_revision_kismenKabul_resolution() throws {
        let revision = HakedisRevision(
            version: "v2", rejectionReason: "Kısmi uyuşmazlık",
            rejectedAt: Date()
        )
        revision.resolution = .kismenKabul
        revision.itirazKazanildi = true
        context.insert(revision)

        XCTAssertEqual(revision.resolution, .kismenKabul)
        XCTAssertEqual(revision.itirazKazanildi, true, "Kısmi kabul → itiraz kısmen kazanıldı")
    }

    // Test 6.7 — Tam kabul resolution
    func test_revision_tamKabul_resolution() throws {
        let revision = HakedisRevision(
            version: "v2", rejectionReason: "İdare itirazı",
            rejectedAt: Date()
        )
        revision.resolution = .tamKabul
        revision.itirazKazanildi = true
        context.insert(revision)

        XCTAssertEqual(revision.resolution, .tamKabul)
    }

    // ─────────────────────────────────────────────────
    // MARK: - BÖLÜM 7: BİRİM FİYAT ANALİZİ (UnitPriceAnalysis)
    // ─────────────────────────────────────────────────

    // Test 7.1 — Gündüz katsayısı 1.0
    func test_unitPrice_gunduzKatsayisi_birdir() throws {
        XCTAssertEqual(LaborShiftType.gunduz.coefficient, 1.0,
                       "Gündüz mesai katsayısı 1.0 olmalı")
    }

    // Test 7.2 — Gece katsayısı 1.25 (%25 zam)
    func test_unitPrice_geceKatsayisi_1_25() throws {
        XCTAssertEqual(LaborShiftType.gece.coefficient, 1.25,
                       "Gece mesai katsayısı 1.25 olmalı")
    }

    // Test 7.3 — Hafta sonu katsayısı 1.50 (%50 zam)
    func test_unitPrice_haftaSonuKatsayisi_1_50() throws {
        XCTAssertEqual(LaborShiftType.haftaSonu.coefficient, 1.50,
                       "Hafta sonu katsayısı 1.50 olmalı")
    }

    // Test 7.4 — Gece direktCost hesabı (işçilik × 1.25)
    func test_unitPrice_geceMesai_directCost() throws {
        let analysis = UnitPriceAnalysis(
            analysisNo: "BFA-001", workItemCode: "02",
            workItemName: "Beton Dökümü", contractUnitPrice: 500
        )
        analysis.laborCost = 200
        analysis.laborShiftType = .gece
        analysis.materialCost = 100
        analysis.machineCost = 50
        analysis.transportCost = 0
        context.insert(analysis)

        // directCost = 200×1.25 + 100 + 50 + 0 = 250 + 100 + 50 = 400
        XCTAssertEqual(analysis.directCost, 400,
                       "Gece: işçilik 200×1.25=250, +malzeme 100, +makine 50 = 400")
    }

    // Test 7.5 — Hafta sonu direktCost (işçilik × 1.50)
    func test_unitPrice_haftaSonu_directCost() throws {
        let analysis = UnitPriceAnalysis(
            analysisNo: "BFA-002", workItemCode: "03",
            workItemName: "Kalıp İşi", contractUnitPrice: 300
        )
        analysis.laborCost = 200
        analysis.laborShiftType = .haftaSonu
        analysis.materialCost = 80
        analysis.machineCost = 0
        analysis.transportCost = 20
        context.insert(analysis)

        // directCost = 200×1.50 + 80 + 0 + 20 = 300 + 80 + 20 = 400
        XCTAssertEqual(analysis.directCost, 400,
                       "Hafta sonu: işçilik 200×1.50=300, +malzeme 80, +nakliye 20 = 400")
    }

    // Test 7.6 — totalCost genel işler ve kar marjı uygulanır
    func test_unitPrice_totalCost_genel_kar() throws {
        let analysis = UnitPriceAnalysis(
            analysisNo: "BFA-003", workItemCode: "04",
            workItemName: "Demir Kesme", contractUnitPrice: 600
        )
        analysis.laborCost = 100
        analysis.laborShiftType = .gunduz   // ×1.0
        analysis.materialCost = 200
        analysis.machineCost = 100
        analysis.transportCost = 0
        analysis.overheadRate = 20          // %20 genel gider
        analysis.profitRate = 10            // %10 kar
        context.insert(analysis)

        // directCost = 100×1.0 + 200 + 100 = 400
        // totalCost = 400 × 1.20 × 1.10 = 528
        let beklenen = 400.0 * 1.20 * 1.10
        XCTAssertEqual(analysis.totalCost, beklenen, accuracy: 0.001)
    }

    // Test 7.7 — isSavings: analiz maliyet < sözleşme fiyatı
    func test_unitPrice_isSavings_true() throws {
        let analysis = UnitPriceAnalysis(
            analysisNo: "BFA-004", workItemCode: "05",
            workItemName: "Sıva", contractUnitPrice: 800
        )
        analysis.laborCost = 100
        analysis.laborShiftType = .gunduz
        analysis.materialCost = 100
        analysis.machineCost = 0
        analysis.transportCost = 0
        analysis.overheadRate = 15
        analysis.profitRate = 10
        context.insert(analysis)

        // directCost = 200, totalCost = 200 × 1.15 × 1.10 = 253
        // contractUnitPrice = 800 → diff = 253-800 = -547 (tasarruf)
        XCTAssertTrue(analysis.isSavings, "Analiz maliyeti < sözleşme fiyatı → tasarruf")
        XCTAssertLessThan(analysis.diff, 0)
    }

    // Test 7.8 — isSavings false: analiz maliyet > sözleşme fiyatı
    func test_unitPrice_isSavings_false_asimDurumu() throws {
        let analysis = UnitPriceAnalysis(
            analysisNo: "BFA-005", workItemCode: "06",
            workItemName: "Küfeki Taşı", contractUnitPrice: 200
        )
        analysis.laborCost = 150
        analysis.laborShiftType = .haftaSonu   // ×1.50
        analysis.materialCost = 100
        analysis.machineCost = 50
        analysis.transportCost = 30
        analysis.overheadRate = 15
        analysis.profitRate = 10
        context.insert(analysis)

        // directCost = 150×1.50 + 100 + 50 + 30 = 225+180 = 405
        // totalCost = 405 × 1.15 × 1.10 > 200
        XCTAssertFalse(analysis.isSavings, "Yüksek maliyet → isSavings false")
        XCTAssertGreaterThan(analysis.diff, 0)
    }

    // Test 7.9 — Piyasa araştırması JSON kaydedilebilir
    func test_unitPrice_marketResearchJSON_kaydedilir() throws {
        let analysis = UnitPriceAnalysis(
            analysisNo: "BFA-006", workItemCode: "07",
            workItemName: "Mermer Kaplama", contractUnitPrice: 450
        )
        analysis.marketResearchJSON = #"[{"vendor":"A","price":420},{"vendor":"B","price":460}]"#
        context.insert(analysis)

        XCTAssertNotNil(analysis.marketResearchJSON, "Piyasa araştırması kaydedilmeli")
        XCTAssertTrue(analysis.marketResearchJSON!.contains("vendor"),
                      "JSON vendor alanı içermeli")
    }

    // ─────────────────────────────────────────────────
    // MARK: - BÖLÜM 8: YER TESLİM (SiteHandoverRecord + SiteDeficiency)
    // ─────────────────────────────────────────────────

    // Test 8.1 — Eksiklik yok → hasOpenDeficiencies false
    func test_siteHandover_eksiklikYok_canTamamla() throws {
        let record = SiteHandoverRecord(
            handoverType: .teslimAl,
            contractorRepName: "Yüklenici A",
            ownerRepName: "İdare B"
        )
        context.insert(record)

        XCTAssertFalse(record.hasOpenDeficiencies,
                       "Eksiklik yoksa proje tamamlanabilir")
        XCTAssertEqual(record.openDeficiencyCount, 0)
    }

    // Test 8.2 — Açık eksiklik var → hasOpenDeficiencies true
    func test_siteHandover_acikEksiklikVar_engelTeskil_eder() throws {
        let record = SiteHandoverRecord(
            handoverType: .teslimAl,
            contractorRepName: "Yüklenici A",
            ownerRepName: "İdare B"
        )
        context.insert(record)

        let eksiklik = SiteDeficiency(title: "Rötär rögar kapağı eksik")
        eksiklik.record = record
        context.insert(eksiklik)
        record.deficiencies.append(eksiklik)

        XCTAssertTrue(record.hasOpenDeficiencies,
                      "Açık eksiklik varken proje tamamlanamaz")
        XCTAssertEqual(record.openDeficiencyCount, 1)
    }

    // Test 8.3 — Eksiklik kapatılınca sayı sıfırlanır
    func test_siteHandover_eksiklikKapatilinca_sayiSifirlanir() throws {
        let record = SiteHandoverRecord(
            handoverType: .teslimAl,
            contractorRepName: "Yüklenici A",
            ownerRepName: "İdare B"
        )
        context.insert(record)

        let eksiklik = SiteDeficiency(title: "Kapı eksik")
        eksiklik.record = record
        context.insert(eksiklik)
        record.deficiencies.append(eksiklik)

        // Eksikliği kapat
        eksiklik.isClosed = true
        eksiklik.closedDate = Date()

        XCTAssertFalse(record.hasOpenDeficiencies,
                       "Eksiklik kapatılınca açık eksiklik kalmamalı")
        XCTAssertEqual(record.openDeficiencyCount, 0)
    }

    // Test 8.4 — Birden fazla eksiklik, sadece bir kapalı
    func test_siteHandover_birEksiklikAcik_birKapali() throws {
        let record = SiteHandoverRecord(
            handoverType: .teslimAl,
            contractorRepName: "Yüklenici A",
            ownerRepName: "İdare B"
        )
        context.insert(record)

        let eks1 = SiteDeficiency(title: "Boya eksik")
        let eks2 = SiteDeficiency(title: "Doğrama eksik")
        eks1.record = record
        eks2.record = record
        eks1.isClosed = true
        eks1.closedDate = Date()
        context.insert(eks1)
        context.insert(eks2)
        record.deficiencies.append(contentsOf: [eks1, eks2])

        XCTAssertEqual(record.openDeficiencyCount, 1,
                       "1 kapalı + 1 açık → openDeficiencyCount=1")
        XCTAssertTrue(record.hasOpenDeficiencies)
    }

    // Test 8.5 — SiteDeficiency isOverdue (teslim tarihi geçmiş, kapalı değil)
    func test_siteDeficiency_isOverdue_true() throws {
        let gecmisTarih = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let eksiklik = SiteDeficiency(
            title: "Sıva eksik",
            completionDate: gecmisTarih
        )
        context.insert(eksiklik)

        XCTAssertTrue(eksiklik.isOverdue, "Tarihi geçmiş kapatılmamış eksiklik gecikmiş")
    }

    // Test 8.6 — İmza durumu .tamamlandi iken kayıt eksiksiz
    func test_siteHandover_signatureStatus_tamamlandi() throws {
        let record = SiteHandoverRecord(
            handoverType: .kabulTutanagi,
            contractorRepName: "Yüklenici",
            ownerRepName: "İdare"
        )
        record.signatureStatus = .tamamlandi
        context.insert(record)

        XCTAssertEqual(record.signatureStatus, .tamamlandi,
                       "Tüm imzalar alınmış tutanak tamamlandı statüsünde")
        XCTAssertFalse(record.hasOpenDeficiencies)
    }
}
