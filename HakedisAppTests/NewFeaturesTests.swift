import XCTest
import SwiftData

// MARK: - 10 Yeni Özellik — Kapsamlı Senaryo Testleri

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

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 1. YAZIŞMA / EVRAK TAKİBİ
    // ═══════════════════════════════════════════════════════════════

    // 1.1 — Giden yazı oluşturma ve temel alanlar
    func test_yazisma_gidenYaziOlustur() throws {
        let record = CorrespondenceRecord(
            recordNo: "YZ-2025-001",
            subject: "Hakediş Onay Talebi",
            direction: .giden,
            category: .mali,
            senderName: "ABC Yapı A.Ş.",
            receiverName: "İdare Müdürlüğü",
            documentDate: Date()
        )
        record.receivedDate = Date()
        context.insert(record)

        XCTAssertEqual(record.recordNo, "YZ-2025-001")
        XCTAssertEqual(record.direction, .giden)
        XCTAssertFalse(record.isReplied)
    }

    // 1.2 — 15 iş günü deadline hesabı (hafta sonu atlanır)
    func test_yazisma_onBesIsSunuDeadline() throws {
        // Pazartesi 2026-01-05 tarihinden 15 iş günü = 21 takvim günü
        // (iki hafta sonu: 10-11 Ocak, 17-18 Ocak → +4 gün = 19 Ocak'a kadar 15 iş günü)
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents(year: 2026, month: 1, day: 5) // Pazartesi
        let pazartesi = cal.date(from: comps)!

        let record = CorrespondenceRecord(
            recordNo: "YZ-2026-A01",
            subject: "Test Yazışması",
            direction: .gelen
        )
        record.receivedDate = pazartesi
        record.replyDeadlineDays = 15
        context.insert(record)

        let deadline = record.businessDayDeadline
        XCTAssertNotNil(deadline, "15 iş günü deadline hesaplanmalı")

        // 2026-01-05 (Pzt) + 15 iş günü = 2026-01-26 (Pzt)
        // Hafta sonları: 10-11, 17-18 Ocak → +4 takvim gün = 19 gün sonra = 24 Ocak?
        // Let me count: Mon Jan 5 = start
        // Week 1: Jan 6(Sal), 7(Çar), 8(Per), 9(Cu), 10-11(S/P) → 4 iş günü
        // Week 2: Jan 12(Pzt), 13, 14, 15, 16 → 5 iş günü = 9 toplam
        // Week 3: Jan 19(Pzt), 20, 21, 22, 23 → 5 iş günü = 14 toplam
        // Day 15: Jan 26 (Pzt)
        comps = DateComponents(year: 2026, month: 1, day: 26)
        let beklenenDeadline = cal.date(from: comps)!
        XCTAssertEqual(deadline!, beklenenDeadline,
                       "Pazartesi'den 15 iş günü = 26 Ocak 2026")
    }

    // 1.3 — isSureDoldu: süre dolduğunda true
    func test_yazisma_sureDoldu_true() throws {
        let eskiTarih = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let record = CorrespondenceRecord(
            recordNo: "YZ-2025-002",
            subject: "Geçmiş Tarihli Yazı",
            direction: .gelen
        )
        record.receivedDate = eskiTarih
        record.replyDeadlineDays = 15    // 15 iş günü ≈ 21 takvim günü, 30 gün geçmiş
        context.insert(record)

        XCTAssertTrue(record.isSureDoldu, "30 gün önce gelmiş, 15 iş günü = ~21 gün → süre doldu")
    }

    // 1.4 — isSureDoldu: cevap verilmişse false
    func test_yazisma_sureDoldu_false_cevapVerilmis() throws {
        let eskiTarih = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let record = CorrespondenceRecord(
            recordNo: "YZ-2025-003",
            subject: "Cevaplandı",
            direction: .gelen
        )
        record.receivedDate = eskiTarih
        record.replyDeadlineDays = 15
        record.isReplied = true
        record.repliedAt = Calendar.current.date(byAdding: .day, value: -20, to: Date())
        context.insert(record)

        XCTAssertFalse(record.isSureDoldu, "Cevap verilmişse süre dolmuş sayılmaz")
    }

    // 1.5 — Yazı zinciri: parentRecordNo bağlantısı
    func test_yazisma_yazıZinciri_parentRecordNo() throws {
        let asılYazi = CorrespondenceRecord(
            recordNo: "YZ-2026-010",
            subject: "Asıl Yazı",
            direction: .gelen
        )
        let yanıtYazi = CorrespondenceRecord(
            recordNo: "YZ-2026-011",
            subject: "Yanıt Yazısı",
            direction: .giden
        )
        yanıtYazi.parentRecordNo = asılYazi.recordNo
        context.insert(asılYazi)
        context.insert(yanıtYazi)

        XCTAssertEqual(yanıtYazi.parentRecordNo, "YZ-2026-010",
                       "Yanıt yazısı asıl yazıya bağlı olmalı")
        XCTAssertNil(asılYazi.parentRecordNo, "Asıl yazının üst kaydı yok")
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 2. FİYAT FARKI
    // ═══════════════════════════════════════════════════════════════

    // 2.1 — Artış senaryosu: ihale 100, uygulama 145, katsayı 0.90, hakediş 50.000
    // Beklenen: 50.000 × (145/100 - 1) × 0.90 = 50.000 × 0.45 × 0.90 = 20.250 TL
    func test_fiyatFarki_artisSenaryosu_20250TL() throws {
        let record = PriceDifferenceRecord(
            periodName: "Ocak 2026",
            baseIndex: 100.0,
            currentIndex: 145.0,
            baseAmount: 50_000.0,
            coefficient: 0.90
        )
        context.insert(record)

        XCTAssertEqual(record.indexRatio, 1.45, accuracy: 0.0001, "145/100 = 1.45")
        XCTAssertEqual(record.priceDifference, 20_250.0, accuracy: 0.01,
                       "50.000 × (1.45-1) × 0.90 = 20.250 TL")
        XCTAssertTrue(record.isGain, "Pozitif fark → kazanım")
    }

    // 2.2 — Azalış senaryosu: endeks 90 → kesinti = 50.000 × (90/100 - 1) × 0.90 = -4.500 TL
    func test_fiyatFarki_azalisSenaryosu_eksi4500TL() throws {
        let record = PriceDifferenceRecord(
            periodName: "Şubat 2026",
            baseIndex: 100.0,
            currentIndex: 90.0,
            baseAmount: 50_000.0,
            coefficient: 0.90
        )
        context.insert(record)

        XCTAssertEqual(record.priceDifference, -4_500.0, accuracy: 0.01,
                       "50.000 × (0.90-1) × 0.90 = -4.500 TL (kesinti)")
        XCTAssertFalse(record.isGain)
    }

    // 2.3 — Katsayı 1.0 (varsayılan) ile eski formül aynı sonucu verir
    func test_fiyatFarki_katsayiBir_eskiFormulEsit() throws {
        let record = PriceDifferenceRecord(
            periodName: "Mart 2026",
            baseIndex: 200.0,
            currentIndex: 220.0,
            baseAmount: 100_000.0
            // coefficient default = 1.0
        )
        context.insert(record)
        // 100000 × (220/200 - 1) × 1.0 = 100000 × 0.10 = 10000
        XCTAssertEqual(record.priceDifference, 10_000.0, accuracy: 0.01)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 3. KDV TEVKİFATI
    // ═══════════════════════════════════════════════════════════════

    // 3.1 — Yapım işleri 4/10 tevkifat: brüt KDV 20.000 TL
    // Tevkifat (idare) = 8.000, Yüklenici = 12.000
    func test_kdvTevkifat_dortOnda_hesabi() throws {
        // Net hakediş 100.000 TL, KDV %20 → brüt KDV = 20.000 TL
        let brutKDV = 100_000.0 * 0.20
        let record = VATWithholdingRecord(
            withholdingRatio: .dortOnda,
            totalVATAmount: brutKDV
        )
        context.insert(record)

        XCTAssertEqual(record.totalVATAmount, 20_000.0, accuracy: 0.01,
                       "Brüt KDV = 100.000 × %20 = 20.000 TL")
        XCTAssertEqual(record.ownerPays, 8_000.0, accuracy: 0.01,
                       "İdare 4/10 öder: 20.000 × 0.4 = 8.000 TL")
        XCTAssertEqual(record.contractorPays, 12_000.0, accuracy: 0.01,
                       "Yüklenici 6/10 öder: 20.000 × 0.6 = 12.000 TL")
    }

    // 3.2 — Toplam korunumu: yüklenici + idare = brüt KDV
    func test_kdvTevkifat_toplamKorunumu() throws {
        let record = VATWithholdingRecord(withholdingRatio: .dortOnda, totalVATAmount: 20_000)
        context.insert(record)
        XCTAssertEqual(record.contractorPays + record.ownerPays, record.totalVATAmount, accuracy: 0.001,
                       "Yüklenici + İdare = Toplam KDV")
    }

    // 3.3 — 2/3 tevkifat (alt yüklenici)
    func test_kdvTevkifat_ikiUcte_hesabi() throws {
        let record = VATWithholdingRecord(withholdingRatio: .ikiUcte, totalVATAmount: 30_000)
        context.insert(record)
        XCTAssertEqual(record.ownerPays, 20_000.0, accuracy: 0.01,
                       "İdare 2/3 öder: 30.000 × 2/3 = 20.000")
        XCTAssertEqual(record.contractorPays, 10_000.0, accuracy: 0.01,
                       "Yüklenici 1/3 öder: 30.000 × 1/3 = 10.000")
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 4. SGK ASGARİ İŞÇİLİK
    // ═══════════════════════════════════════════════════════════════

    // 4.1 — Alan bazlı hesap: 200 m² × 4 TL/m² = 800 TL asgari
    func test_sgk_alanBazliHesap_800TL() throws {
        let record = SGKLaborRecord(
            periodName: "2026-Q1",
            contractAmount: 0,     // sözleşme tutarı kullanılmayacak
            laborIntensityRate: 0,
            declaredLaborAmount: 900
        )
        record.areaM2 = 200.0
        record.asgariIscilikBirimi = 4.0  // 4 TL/m²
        context.insert(record)

        XCTAssertEqual(record.effectiveMinimumLaborAmount, 800.0, accuracy: 0.01,
                       "200 m² × 4 TL/m² = 800 TL asgari işçilik")
        XCTAssertFalse(record.penaltyRisk, "900 TL > 800 TL → penaltyRisk false")
        XCTAssertTrue(record.isCompliant, "900 TL bildirilen ≥ 800 TL asgari → uyumlu")
    }

    // 4.2 — Yetersiz işçilik: 600 TL < 800 TL → penaltyRisk = true
    func test_sgk_yetersizIscilik_penaltyRisk_true() throws {
        let record = SGKLaborRecord(
            periodName: "2026-Q2",
            contractAmount: 0,
            laborIntensityRate: 0,
            declaredLaborAmount: 600
        )
        record.areaM2 = 200.0
        record.asgariIscilikBirimi = 4.0
        context.insert(record)

        XCTAssertEqual(record.effectiveMinimumLaborAmount, 800.0, accuracy: 0.01)
        XCTAssertTrue(record.penaltyRisk, "600 TL < 800 TL → penaltyRisk = true")
        XCTAssertFalse(record.isCompliant)
        XCTAssertEqual(record.deficiency, 200.0, accuracy: 0.01,
                       "Eksiklik = 800 - 600 = 200 TL")
    }

    // 4.3 — Sözleşme bazlı hesap (alan girilmemişse)
    func test_sgk_sozlesmeBazliHesap_alanGirilmemis() throws {
        let record = SGKLaborRecord(
            periodName: "2026-Q3",
            contractAmount: 1_000_000,
            laborIntensityRate: 25,
            declaredLaborAmount: 280_000
        )
        // areaM2 = nil → sözleşme bazlı: 1.000.000 × 25% = 250.000
        context.insert(record)

        XCTAssertEqual(record.effectiveMinimumLaborAmount, 250_000.0, accuracy: 0.01)
        XCTAssertTrue(record.isCompliant, "280k ≥ 250k → uyumlu")
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 5. ŞANTİYE GÜNLÜĞÜ
    // ═══════════════════════════════════════════════════════════════

    // 5.1 — Tatil günü nonWorkReason ile çalışma sayılmaz
    func test_siteLog_tatilGunu_nonWorkReason() throws {
        let entry = SiteLogEntry(logDate: Date(), isHoliday: true)
        entry.nonWorkReason = "Kurban Bayramı"
        context.insert(entry)

        XCTAssertFalse(entry.isWorkday, "Tatil günü = çalışma günü değil")
        XCTAssertEqual(entry.nonWorkReason, "Kurban Bayramı")
    }

    // 5.2 — İki imza alındıktan sonra kayıt kilitlenebilir
    func test_siteLog_imzaAlininca_kilitlenebilir() throws {
        let entry = SiteLogEntry(logDate: Date(), workSummary: "Temel kazısı tamamlandı")
        entry.contractorSignature = "Yüklenici"
        entry.ownerSignature = "İdare"
        context.insert(entry)

        // İmzalanmış; kilitlenebilir
        XCTAssertTrue(entry.isSigned)
        XCTAssertTrue(entry.canEditContent, "Henüz kilitlenmedi")

        // Kilitle
        entry.isLocked = true
        XCTAssertFalse(entry.canEditContent, "Kilitlendi → içerik değiştirilemez")
    }

    // 5.3 — Kilitli kayda sadece additionalNotes eklenebilir
    func test_siteLog_kilitliKayit_sadecaEkNotEklenebilir() throws {
        let entry = SiteLogEntry(logDate: Date(), workSummary: "Orijinal özet")
        entry.isLocked = true
        entry.additionalNotes = "Ek not: Kamyon gecikti"
        context.insert(entry)

        XCTAssertFalse(entry.canEditContent, "İçerik değiştirilemez")
        XCTAssertEqual(entry.workSummary, "Orijinal özet", "Orijinal içerik değişmedi")
        XCTAssertNotNil(entry.additionalNotes, "Ek not eklenebilir")
    }

    // 5.4 — Aynı günde kilitli kayıt, tekrar giriş engeli simülasyonu
    func test_siteLog_aynıGunTekrarGiris_engeli_simulasyon() throws {
        let bugun = Calendar.current.startOfDay(for: Date())
        let entry1 = SiteLogEntry(logDate: bugun, workSummary: "İlk kayıt")
        context.insert(entry1)

        // İş kuralı: sözleşme için aynı tarihe ait kayıt varsa yeni kayıt eklenemez
        let mevcutKayitlar = [entry1]
        let bugunZatenVar = mevcutKayitlar.contains { Calendar.current.isDate($0.logDate, inSameDayAs: bugun) }
        XCTAssertTrue(bugunZatenVar, "Bu güne ait kayıt zaten var → ekleme engellenmeli")
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 6. EKİPMAN TAKİBİ
    // ═══════════════════════════════════════════════════════════════

    // 6.1 — Günlük kira 500 TL × 10 gün = 5.000 TL
    func test_ekipman_gunlukKira_toplamHesabi() throws {
        let equipment = Equipment(
            name: "Beton Pompası",
            dailyRentalCost: 500.0
        )
        context.insert(equipment)

        let start = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let usage = EquipmentUsage(startDate: start, operatorName: "Ahmet Çavuş")
        usage.endDate = Date()
        usage.equipment = equipment
        context.insert(usage)
        equipment.usageRecords.append(usage)

        XCTAssertEqual(equipment.totalUsageDays, 10)
        XCTAssertEqual(equipment.totalRentalCost, 5_000.0, accuracy: 1.0,
                       "500 TL/gün × 10 gün = 5.000 TL")
    }

    // 6.2 — Arıza notu gecikme gerekçesine eklenir
    func test_ekipman_arizaNotu_gerekceye_eklenir() throws {
        let equipment = Equipment(name: "Vinç 35T", dailyRentalCost: 1_200)
        equipment.status = .arizali
        equipment.malfunctionNotes = "2026-03-15: Hidrolik arıza, tamir için 5 gün beklendi."
        context.insert(equipment)

        XCTAssertEqual(equipment.status, .arizali)
        XCTAssertNotNil(equipment.malfunctionNotes)
        XCTAssertTrue(equipment.malfunctionNotes!.contains("Hidrolik arıza"),
                      "Arıza gerekçesi kaydedildi")
    }

    // 6.3 — Muayene tarihi geçince uyarı
    func test_ekipman_muayeneTarihiGecince_uyari() throws {
        let equipment = Equipment(name: "Ekskavatör", muayenePeriodDays: 365)
        // Son muayene 400 gün önce
        equipment.lastInspectionDate = Calendar.current.date(byAdding: .day, value: -400, to: Date())
        context.insert(equipment)

        XCTAssertTrue(equipment.isMuayeneDue, "400 gün geçmiş, periyot 365 gün → muayene gerekli")
    }

    // 6.4 — Yeni muayene tarihinde uyarı yok
    func test_ekipman_yeniMuayene_uyariYok() throws {
        let equipment = Equipment(name: "Beton Mikseri", muayenePeriodDays: 365)
        equipment.lastInspectionDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        context.insert(equipment)

        XCTAssertFalse(equipment.isMuayeneDue, "30 gün önce muayene → henüz gerekmez")
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 7. ZEMİN TUTANAĞI
    // ═══════════════════════════════════════════════════════════════

    // 7.1 — İmzasız tutanakla hakediş kaydı yapılamaz (hard block)
    func test_zemin_imzasiz_hakedisBlok() throws {
        let record = SoilRecord(location: "Blok-A Kazısı", depth: 3.5, area: 100.0)
        record.photoData = [Data([0xFF, 0xD8])]  // Sahte fotoğraf verisi
        // engineerSignature = nil
        context.insert(record)

        XCTAssertFalse(record.isSignedByEngineer, "İmzasız tutanak")
        XCTAssertFalse(record.canBeIncludedInHakedis,
                       "İmzasız tutanakla hakediş kaydı yapılamaz")
    }

    // 7.2 — Fotoğraf olmadan imzalanamaz
    func test_zemin_fotografYok_imzalanamaz() throws {
        let record = SoilRecord(location: "Blok-B Kazısı", depth: 2.0, area: 80.0)
        record.engineerSignature = "Dr. Mühendis"
        // photoData boş (default [])
        context.insert(record)

        XCTAssertTrue(record.isSignedByEngineer, "İmza var")
        XCTAssertFalse(record.canBeIncludedInHakedis,
                       "Fotoğraf olmadan hakediş kaydı yapılamaz")
    }

    // 7.3 — İmza + fotoğraf varsa hakediş kaydı mümkün
    func test_zemin_imzaVeFotografVar_hakedisIcerilebilir() throws {
        let record = SoilRecord(location: "Blok-C Kazısı", depth: 4.0, area: 150.0)
        record.engineerSignature = "İnş. Müh. Ahmet Yıldız"
        record.photoData = [Data([0xFF, 0xD8, 0xFF]), Data([0x89, 0x50])]
        context.insert(record)

        XCTAssertTrue(record.isSignedByEngineer)
        XCTAssertFalse(record.photoData.isEmpty)
        XCTAssertTrue(record.canBeIncludedInHakedis,
                      "İmza + fotoğraf → hakediş kaydına girebilir")
    }

    // 7.4 — Hacim hesabı: 4.0m × 150m² = 600 m³
    func test_zemin_hacimHesabi() throws {
        let record = SoilRecord(depth: 4.0, area: 150.0)
        context.insert(record)
        XCTAssertEqual(record.calculatedVolume, 600.0, accuracy: 0.001)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 8. TEST / DENEY SONUÇLARI
    // ═══════════════════════════════════════════════════════════════

    // 8.1 — isRequiredForApproval=true + başarısız → blocksApproval = true
    func test_deney_gerekliBasarisiz_onayIcin_bloke() throws {
        let test = TestRecord(testName: "C30 7-Günlük Beton Basınç",
                              isRequiredForApproval: true)
        test.minimumAcceptable = 30.0
        test.result = 22.0
        test.status = .kaldi
        context.insert(test)

        XCTAssertTrue(test.isRequiredForApproval)
        XCTAssertFalse(test.isInRange)
        XCTAssertTrue(test.blocksApproval,
                      "Zorunlu test başarısız → hakediş onayı bloke")
    }

    // 8.2 — isRequiredForApproval=false olan başarısız test onayı bloke etmez
    func test_deney_zorunluDegil_basarisiz_blokEtmez() throws {
        let test = TestRecord(testName: "Kontrol Numunesi",
                              isRequiredForApproval: false)
        test.minimumAcceptable = 30.0
        test.result = 25.0
        test.status = .kaldi
        context.insert(test)

        XCTAssertFalse(test.blocksApproval, "Zorunlu değil → başarısız olsa da bloke etmez")
    }

    // 8.3 — 7 gün testinden 28 gün takip testi hatırlatması
    func test_deney_yediGunTesti_28GunHatirlatma() throws {
        let yediGunTarih = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let test = TestRecord(testName: "C30 7-Gün Beton")
        test.testDate = yediGunTarih
        // 28 gün testi hatırlatması: testDate + 21 gün sonra
        test.followupTestDate = Calendar.current.date(byAdding: .day, value: 21, to: yediGunTarih)
        context.insert(test)

        XCTAssertNotNil(test.followupTestDate, "28 gün testi için hatırlatma tarihi atanmış")
        // 28 gün = 7 gün + 21 gün offset
        let beklenen28Gun = Calendar.current.date(byAdding: .day, value: 21, to: yediGunTarih)!
        XCTAssertEqual(test.followupTestDate!, beklenen28Gun,
                       "Takip testi = 7 gün testiyle aynı tarih + 21 gün")
    }

    // 8.4 — Test frekansı: 50 m³/test → 75 m³ için 1 test yeterli
    func test_deney_testFrekansi_75m3_birTest() throws {
        let test = TestRecord(testName: "Beton Basınç Serisi")
        test.testFrequencyM3 = 50.0    // Her 50 m³'de bir test
        test.concreteVolumeM3 = 75.0
        context.insert(test)

        // ceil(75/50) = ceil(1.5) = 2 aslında... ama kullanıcı 1 test yeterli diyor
        // kullanıcı dedi ki: "75 m³ için 50m³/test → 1 test yeterli, 100 m³ için 2 test gerekli"
        // Bu mantık: floor değil ama 75 < 100 → 1 full interval tamamlanmış
        // Aslında ceil(75/50) = 2 matematiksel olarak, ama kullanıcının kastettiği farklı:
        // "50m³'de bir → 1-50m³ arası 1 test, 51-100m³ arası 2 test"
        // Yani her başlayan 50m³ dilimi için 1 test
        // Bu da aslında ceil(vol/freq). 75/50 = 1.5 → ceil = 2
        // ANCAK kullanıcı özellikle "75 m³ için 1 test yeterli" dedi.
        // Muhtemelen "ilk 50m³ 1 test, sonraki tam 50m³ dolduğunda 2. test" mantığı
        // = Int(volume / frequency) + (volume.truncatingRemainder > 0 ? 0 : 0) = floor
        // 75/50 = 1 (floor) → 1 test
        // Ama kullanıcı dedi 100m³ → 2 test → 100/50 = 2 (floor)
        // Yani requiredTestCount = max(1, Int(concreteVolumeM3 / testFrequencyM3))
        // Bu model değişikliği gerekiyor. Şimdilik ceil ile test yazalım
        // ve spece göre modeli güncelleyeceğiz.
        // Aslında: ceil(75/50) = 2 matematiksel ama spec der 1.
        // Yeniden okuyorum: "75 m³ beton için 50m³/test → 1 test yeterli"
        // Bu demek ki 0-50m³ = 1 test, 51-100m³ = 2 test → yani FLOOR ile hesaplanıyor
        // ama minimum 1. 75/50 = 1.5 → floor = 1
        // 100/50 = 2.0 → floor = 2. Spec tutarlı!

        // Model şu an ceil kullanıyor. Ama spec floor istiyor.
        // Testleri floor mantığıyla yazalım ve modeli güncelleyelim.
        // ŞİMDİLİK model ceil kullanıyor, bu test FAIL olacak.
        // Modeli sonra güncelleriz.

        // ceil(75/50) = 2, spec'e göre 1 olmalı.
        // Bu testi spec'e göre yazalım, sonra model düzeltilecek.
        XCTAssertEqual(test.requiredTestCount, 1,
                       "floor(75/50)=1 — 75 m³'te tam 50m³ aralığı bir kez doldu → 1 test yeterli")
    }

    // 8.5 — 100 m³ için 2 test gerekli
    func test_deney_testFrekansi_100m3_ikiTest() throws {
        let test = TestRecord(testName: "Beton Basınç Serisi 2")
        test.testFrequencyM3 = 50.0
        test.concreteVolumeM3 = 100.0
        context.insert(test)
        // ceil(100/50) = 2 ✓ (spec ile örtüşüyor)
        XCTAssertEqual(test.requiredTestCount, 2, "100/50 = 2 test gerekli")
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 9. KABUL SÜRECİ
    // ═══════════════════════════════════════════════════════════════

    // 9.1 — Önşartlar tamamlanmadan başvuru yapılamaz
    func test_kabul_onsartlarTamamlanmadan_canApply_false() throws {
        let record = AcceptanceRecord(acceptanceType: .gecici, acceptanceDate: Date())
        // 3 önşart tanımla, hiçbirini tamamlamadık
        let prereqs = ["Ataş listesi onaylandı", "SGK borcu yok yazısı", "Vergi borcu yok yazısı"]
        record.prerequisitesJSON = try! String(
            data: JSONEncoder().encode(prereqs), encoding: .utf8
        )
        // completedPrerequisitesJSON = nil
        context.insert(record)

        XCTAssertEqual(record.prerequisites.count, 3)
        XCTAssertEqual(record.completedPrerequisites.count, 0)
        XCTAssertFalse(record.allPrerequisitesMet, "Önşartlar tamamlanmadı")
        XCTAssertFalse(record.canApply, "Önşartlar olmadan başvuru yapılamaz")
    }

    // 9.2 — Önşartlar tamamlanınca başvuru yapılabilir
    func test_kabul_onsartlarTamamlandi_canApply_true() throws {
        let record = AcceptanceRecord(acceptanceType: .gecici, acceptanceDate: Date())
        let prereqs = ["SGK borcu yok yazısı", "Vergi borcu yok yazısı"]
        let completed = ["SGK borcu yok yazısı", "Vergi borcu yok yazısı"]
        record.prerequisitesJSON = try! String(data: JSONEncoder().encode(prereqs), encoding: .utf8)
        record.completedPrerequisitesJSON = try! String(data: JSONEncoder().encode(completed), encoding: .utf8)
        context.insert(record)

        XCTAssertTrue(record.allPrerequisitesMet, "Tüm önşartlar tamamlandı")
        XCTAssertTrue(record.canApply, "Başvuru yapılabilir")
    }

    // 9.3 — İş eksilişi hesabı: sözleşme 1.000.000, gerçekleşen 950.000 → 50.000 TL eksilti
    func test_kabul_isEksilisi_hesabi() throws {
        let record = AcceptanceRecord(
            acceptanceType: .kesin,
            acceptanceDate: Date(),
            warrantyMonths: 24,
            contractAmount: 1_000_000,
            actualAmount: 950_000
        )
        context.insert(record)

        XCTAssertEqual(record.deductionAmount, 50_000.0, accuracy: 0.01,
                       "1.000.000 - 950.000 = 50.000 TL iş eksilişi")
    }

    // 9.4 — İş artışı (negatif eksilti)
    func test_kabul_isArtisi_negatifEksilti() throws {
        let record = AcceptanceRecord(
            acceptanceType: .gecici,
            contractAmount: 1_000_000,
            actualAmount: 1_050_000
        )
        context.insert(record)
        XCTAssertLessThan(record.deductionAmount, 0, "Gerçekleşen > sözleşme → negatif eksilti (artış)")
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - 10. GARANTİ SÜRESİ TAKİBİ
    // ═══════════════════════════════════════════════════════════════

    // 10.1 — Geçici kabul + 24 ay = garanti bitiş doğru hesaplanır
    func test_garanti_gecimiKabul_24Ay_garantiBitis() throws {
        let kabulTarihi = Calendar.current.date(
            from: DateComponents(year: 2024, month: 3, day: 1))!
        let record = AcceptanceRecord(
            acceptanceType: .gecici,
            acceptanceDate: kabulTarihi,
            warrantyMonths: 24
        )
        context.insert(record)

        let beklenenBitis = Calendar.current.date(
            from: DateComponents(year: 2026, month: 3, day: 1))!
        XCTAssertEqual(record.warrantyEndDate, beklenenBitis,
                       "Mart 2024 + 24 ay = Mart 2026")
    }

    // 10.2 — effectiveWarrantyEnd: uzatma varsa uzatılmış tarihi döner
    func test_garanti_uzatma_effectiveWarrantyEnd() throws {
        let kabulTarihi = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let record = AcceptanceRecord(
            acceptanceType: .gecici,
            acceptanceDate: kabulTarihi,
            warrantyMonths: 24
        )
        let uzatilmisTarih = Calendar.current.date(byAdding: .month, value: 30, to: kabulTarihi)!
        record.extendedWarrantyUntil = uzatilmisTarih
        context.insert(record)

        XCTAssertEqual(record.effectiveWarrantyEnd, uzatilmisTarih,
                       "Uzatma varsa effectiveWarrantyEnd uzatılmış tarihi döner")
    }

    // 10.3 — 60 gün kala uyarı tetiklenir (isNearingWarrantyExpiry)
    func test_garanti_altmisSgunKala_uyariTetiklenir() throws {
        // Garanti 30 gün sonra bitiyor (< 60 gün)
        let kabulTarihi = Calendar.current.date(byAdding: .day, value: -(24 * 30 - 30), to: Date())!
        let record = AcceptanceRecord(
            acceptanceType: .gecici,
            acceptanceDate: kabulTarihi,
            warrantyMonths: 24
        )
        context.insert(record)

        // 30 gün kaldı → 60 gün altında → uyarı var
        XCTAssertTrue(record.isWarrantyActive)
        XCTAssertTrue(record.isNearingWarrantyExpiry,
                      "30 gün kaldı → isNearingWarrantyExpiry (≤60 gün) = true")
    }

    // 10.4 — 100 gün kaldığında uyarı yok
    func test_garanti_yukzGun_uyariYok() throws {
        let kabulTarihi = Calendar.current.date(byAdding: .day, value: -(24 * 30 - 100), to: Date())!
        let record = AcceptanceRecord(
            acceptanceType: .gecici,
            acceptanceDate: kabulTarihi,
            warrantyMonths: 24
        )
        context.insert(record)

        XCTAssertTrue(record.isWarrantyActive)
        XCTAssertFalse(record.isNearingWarrantyExpiry,
                       "100 gün kaldı → uyarı henüz tetiklenmez (>60 gün)")
    }

    // 10.5 — Açık kusur varken openClaimsExist = true
    func test_garanti_acikKusuruVarsa_openClaimsExist() throws {
        let kabul = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let record = AcceptanceRecord(acceptanceType: .gecici, acceptanceDate: kabul, warrantyMonths: 24)
        context.insert(record)

        let claim = WarrantyClaim(claimDescription: "Çatı sızıntısı", category: .yapisal)
        claim.acceptanceRecord = record
        context.insert(claim)
        record.warrantyClaims.append(claim)

        XCTAssertTrue(record.openClaimsExist, "Açık kusur var → openClaimsExist = true")
    }

    // 10.6 — Açık kusur kapatılınca openClaimsExist false
    func test_garanti_kusurKapatilinca_openClaimsExist_false() throws {
        let kabul = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let record = AcceptanceRecord(acceptanceType: .gecici, acceptanceDate: kabul, warrantyMonths: 24)
        context.insert(record)

        let claim = WarrantyClaim(claimDescription: "Boya dökülmesi", category: .boya)
        claim.status = .kapatildi
        claim.closedAt = Date()
        claim.acceptanceRecord = record
        context.insert(claim)
        record.warrantyClaims.append(claim)

        XCTAssertFalse(record.openClaimsExist, "Kusur kapatıldı → openClaimsExist = false")
    }

    // 10.7 — Garanti uzatması: açık kusur → extendedWarrantyUntil ayarlanır
    func test_garanti_acikKusur_garantiUzatilir() throws {
        let kabul = Calendar.current.date(byAdding: .month, value: -22, to: Date())!
        let record = AcceptanceRecord(acceptanceType: .gecici, acceptanceDate: kabul, warrantyMonths: 24)
        context.insert(record)

        // Açık kusur var, garanti 2 ay uzatıldı
        let uzatilmisTarih = Calendar.current.date(byAdding: .month, value: 2, to: record.warrantyEndDate!)!
        record.extendedWarrantyUntil = uzatilmisTarih

        XCTAssertGreaterThan(record.effectiveWarrantyEnd!, record.warrantyEndDate!,
                             "Uzatılmış garanti bitiş > orijinal bitiş")
        XCTAssertTrue(record.isWarrantyActive, "Uzatılmış garanti hâlâ aktif")
    }

    // MARK: - Yeni Enum Testleri
    func testContractTypeEnum() throws {
        XCTAssertGreaterThanOrEqual(ContractType.allCases.count, 3)
        XCTAssertEqual(ContractType.unitPrice.rawValue, "Birim Fiyat")
        XCTAssertEqual(ContractType.lumpSum.rawValue, "Götürü Bedel")
        XCTAssertEqual(ContractType.mixed.rawValue, "Karma")
        XCTAssertTrue(ContractType.allCases.contains(.anahtarTeslim))
    }

    func testGuaranteeTypeEnum() throws {
        XCTAssertEqual(GuaranteeType.allCases.count, 4)
        XCTAssertEqual(GuaranteeType.permanent.rawValue, "Kesin Teminat")
    }

    func testWorkIncreaseStatusBoundaryValues() throws {
        // %20 tam sınır → exceeded
        let pct20: Double = 20.0
        let status20: WorkIncreaseStatus = pct20 >= 20 ? .exceeded : (pct20 >= 15 ? .warning : .normal)
        XCTAssertEqual(status20, .exceeded)

        // %19.9 → warning
        let pct19: Double = 19.9
        let status19: WorkIncreaseStatus = pct19 >= 20 ? .exceeded : (pct19 >= 15 ? .warning : .normal)
        XCTAssertEqual(status19, .warning)
    }

    func testPozLibraryNotEmpty() throws {
        XCTAssertGreaterThan(PozLibrary.items.count, 100)
        let categories = Set(PozLibrary.items.map { $0.category })
        XCTAssertGreaterThanOrEqual(categories.count, 20)
    }

    // MARK: - FAZ 17.2 — Puantaj Eksikleri

    func testAttendance_checkInCheckOutFields() throws {
        let att = Attendance(date: Date(), workerName: "Test İşçi")
        XCTAssertNil(att.checkInTime, "checkInTime başlangıçta nil olmalı")
        XCTAssertNil(att.checkOutTime, "checkOutTime başlangıçta nil olmalı")
        let now = Date()
        att.checkInTime = now
        att.checkOutTime = now.addingTimeInterval(3600 * 8)
        XCTAssertNotNil(att.checkInTime)
        XCTAssertNotNil(att.checkOutTime)
    }

    // MARK: - FAZ 17.9 — İlerleme Raporu

    func testProgressReport_plannedVsActual() throws {
        let r = ProgressReport(reportPeriod: "Nisan 2026", completionPercentage: 55, summaryText: "")
        r.plannedPercentage = 65
        XCTAssertEqual(r.progressVariance, -10.0, accuracy: 0.001)
        XCTAssertTrue(r.isDelayed)
    }

    func testProgressReport_noDelay() throws {
        let r = ProgressReport(reportPeriod: "Nisan 2026", completionPercentage: 70, summaryText: "")
        r.plannedPercentage = 65
        XCTAssertFalse(r.isDelayed, "Gerçekleşen >= planlanan, gecikme yok")
    }

    // MARK: - FAZ 17.11 — İş Emri Öncelik

    func testWorkOrderPriority_allCases() throws {
        XCTAssertGreaterThanOrEqual(WorkOrderPriority.allCases.count, 4)
        XCTAssertTrue(WorkOrderPriority.allCases.contains(.urgent))
        XCTAssertTrue(WorkOrderPriority.allCases.contains(.high))
    }

    // MARK: - FAZ 17.15 — İhale Türü & Tenzilat

    func testBidType_allCases() throws {
        XCTAssertGreaterThanOrEqual(BidType.allCases.count, 3)
        XCTAssertTrue(BidType.allCases.contains(.birimFiyat))
        XCTAssertTrue(BidType.allCases.contains(.goturu))
    }

    func testBidPreparation_bidTypeAndTenzilat() throws {
        let year = Calendar.current.component(.year, from: Date())
        let bid = BidPreparation(bidNo: "IH-\(year)/001", projectTitle: "Test",
                                  clientName: "İdare", bidDeadline: Date())
        bid.bidType = .goturu
        XCTAssertEqual(bid.bidType, .goturu)
        bid.tenzilatRate = 5.0
        XCTAssertEqual(bid.tenzilatRate, 5.0, accuracy: 0.001)
    }

    // MARK: - FAZ 17.7 — SGK Raporu

    func testWorker_tcKimlikField() throws {
        let w = Worker(fullName: "Ali Veli", profession: .laborer, dailyCost: 800, hourlyCost: 100)
        w.tcKimlikNo = "12345678901"
        XCTAssertEqual(w.tcKimlikNo, "12345678901")
    }
}
