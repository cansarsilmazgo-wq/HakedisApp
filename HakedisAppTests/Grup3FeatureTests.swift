import XCTest
import SwiftData

// MARK: - Grup 3 Özellik Testleri
// Metraj Defteri, Malzeme Stok, Nakit Akış Projeksiyonu

final class Grup3FeatureTests: XCTestCase {

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
    // MARK: - BÖLÜM 1: METRAJ DEFTERİ (MeasurementEntry)
    // ─────────────────────────────────────────────────

    // Test 1.1 — Temel kümülatif toplam
    func test_metraj_cumulativeTotal_ilkGiris() throws {
        let entry = MeasurementEntry(
            entryNo: "MB-2026-001",
            workItemCode: "01",
            location: "Blok-A / Kat-1",
            measurementType: .hacim
        )
        entry.calculatedQuantity = 100
        entry.netQuantity        = 100      // düşülen yok
        entry.previousEntries    = 0
        context.insert(entry)

        XCTAssertEqual(entry.cumulativeTotal, 100,
                       "İlk giriş: önceki=0, net=100 → kümülatif=100")
    }

    // Test 1.2 — Önceki dönem mevcut
    func test_metraj_cumulativeTotal_oncekiDonemVar() throws {
        let entry = MeasurementEntry(
            entryNo: "MB-2026-002",
            workItemCode: "01",
            location: "Blok-A / Kat-2",
            measurementType: .hacim
        )
        entry.calculatedQuantity = 45
        entry.netQuantity        = 45
        entry.previousEntries    = 120    // önceki dönem kümülatifi
        context.insert(entry)

        XCTAssertEqual(entry.cumulativeTotal, 165,
                       "önceki=120 + net=45 → kümülatif=165")
    }

    // Test 1.3 — Düşülen (deduction) uygulandığında net < brüt
    func test_metraj_netQuantity_dusuleliOlcum() throws {
        let entry = MeasurementEntry(
            entryNo: "MB-2026-003",
            workItemCode: "04",
            location: "Cephe duvarı",
            measurementType: .alan
        )
        // Brüt alan: 5 × 4 × 3 kat = 60 m²
        // Düşülen: 2 pencere × 2 m² = 4 m²
        // Net: 60 - 4 = 56 m²
        let brutQty = 5.0 * 4.0 * 3.0   // = 60
        let dusülen = 2.0 * 2.0          // = 4
        entry.calculatedQuantity = brutQty
        entry.netQuantity        = brutQty - dusülen   // = 56
        entry.previousEntries    = 0
        context.insert(entry)

        XCTAssertEqual(entry.calculatedQuantity, 60, accuracy: 0.01, "Brüt alan 60 m² olmalı")
        XCTAssertEqual(entry.netQuantity, 56, accuracy: 0.01,        "Net alan 56 m² olmalı (−4 düşülen)")
        XCTAssertEqual(entry.cumulativeTotal, 56, accuracy: 0.01,    "Kümülatif = önceki(0) + net(56) = 56")
    }

    // Test 1.4 — Çok satırlı ölçüm: hacim hesabı (L × G × Y)
    func test_metraj_hacimHesabi_cokSatir() throws {
        // 3 beton dökümü:
        //   Satır-1: 5m × 3m × 0.5m = 7.5 m³
        //   Satır-2: 4m × 2m × 0.5m = 4.0 m³
        //   Satır-3: 6m × 2m × 0.5m = 6.0 m³
        // Brüt toplam: 17.5 m³
        let dims: [(l: Double, g: Double, y: Double)] = [
            (5, 3, 0.5),
            (4, 2, 0.5),
            (6, 2, 0.5)
        ]
        let brutQty = dims.reduce(0) { $0 + $1.l * $1.g * $1.y }
        XCTAssertEqual(brutQty, 17.5, accuracy: 0.001, "Brüt hacim 17.5 m³ olmalı")

        let entry = MeasurementEntry(
            entryNo: "MB-2026-004",
            workItemCode: "02",
            location: "Temel perde beton",
            measurementType: .hacim
        )
        entry.calculatedQuantity = brutQty
        entry.netQuantity        = brutQty   // düşülen yok
        entry.previousEntries    = 0
        context.insert(entry)

        XCTAssertEqual(entry.cumulativeTotal, 17.5, accuracy: 0.001)
    }

    // Test 1.5 — Sıralı 3 giriş → kümülatif zinciri doğrulaması
    func test_metraj_ucGiris_kumulatifZinciri() throws {
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 85, contractedQuantity: 100)
        context.insert(workItem)

        // Giriş 1: net=30, önceki=0
        let e1 = makeMeasurementEntry(
            no: "MB-2026-001", code: "01",
            calculatedQty: 30, netQty: 30, previousEntries: 0,
            workItem: workItem
        )
        // Giriş 2: net=20, önceki=sum(e1.net)=30
        let e2 = makeMeasurementEntry(
            no: "MB-2026-002", code: "01",
            calculatedQty: 20, netQty: 20,
            previousEntries: workItem.measurementEntries.reduce(0) { $0 + $1.netQuantity },
            workItem: workItem
        )
        // Giriş 3: net=25, önceki=sum(e1+e2)=50
        let e3 = makeMeasurementEntry(
            no: "MB-2026-003", code: "01",
            calculatedQty: 25, netQty: 25,
            previousEntries: workItem.measurementEntries.reduce(0) { $0 + $1.netQuantity },
            workItem: workItem
        )

        XCTAssertEqual(e1.cumulativeTotal, 30,  "Giriş-1 kümülatif: 30")
        XCTAssertEqual(e2.cumulativeTotal, 50,  "Giriş-2 kümülatif: 30+20=50")
        XCTAssertEqual(e3.cumulativeTotal, 75,  "Giriş-3 kümülatif: 50+25=75")

        // Liste toplam = Σ netQuantity
        let listeToplam = workItem.measurementEntries.reduce(0) { $0 + $1.netQuantity }
        XCTAssertEqual(listeToplam, 75, "Liste toplam = 30+20+25 = 75 m³")

        // Son girişin cumulativeTotal ile liste toplamı eşleşmeli
        XCTAssertEqual(e3.cumulativeTotal, listeToplam,
                       "Son giriş cumulativeTotal == liste toplamı olmalı")
    }

    // Test 1.6 — Sözleşme miktarı aşım tespiti
    func test_metraj_sozlesmeAsimi() throws {
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 85, contractedQuantity: 100)
        context.insert(workItem)

        // 95 m³ girildi
        let e1 = makeMeasurementEntry(
            no: "MB-001", code: "01",
            calculatedQty: 95, netQty: 95, previousEntries: 0,
            workItem: workItem
        )
        let cumulative1 = workItem.measurementEntries.reduce(0) { $0 + $1.netQuantity }
        XCTAssertFalse(cumulative1 > workItem.contractedQuantity,
                       "95 m³ ≤ 100 m³ sözleşme — aşım yok")

        // 10 m³ daha giriliyor → toplam 105 m³
        let e2 = makeMeasurementEntry(
            no: "MB-002", code: "01",
            calculatedQty: 10, netQty: 10, previousEntries: 95,
            workItem: workItem
        )
        _ = e1; _ = e2
        let cumulative2 = workItem.measurementEntries.reduce(0) { $0 + $1.netQuantity }
        XCTAssertTrue(cumulative2 > workItem.contractedQuantity,
                      "105 m³ > 100 m³ sözleşme — aşım tespit edilmeli")
        XCTAssertEqual(cumulative2 - workItem.contractedQuantity, 5, accuracy: 0.01,
                       "Sözleşme aşımı = 5 m³")
    }

    // Test 1.7 — Doğrulama durumu
    func test_metraj_dogrulamaDurumu() throws {
        let entry = MeasurementEntry(
            entryNo: "MB-2026-005",
            workItemCode: "01",
            location: "Test",
            measurementType: .uzunluk
        )
        entry.netQuantity = 50
        entry.isVerified = false
        context.insert(entry)

        XCTAssertFalse(entry.isVerified, "Varsayılan: doğrulanmamış")

        entry.isVerified = true
        entry.checkedBy = "Müh. Ali Yılmaz"
        XCTAssertTrue(entry.isVerified)
        XCTAssertEqual(entry.checkedBy, "Müh. Ali Yılmaz")
    }

    // ─────────────────────────────────────────────────
    // MARK: - BÖLÜM 2: MALZEME STOK (MaterialRecord)
    // ─────────────────────────────────────────────────

    // Test 2.1 — Boş stok: tüm hesaplamalar sıfır
    func test_malzeme_boslStok() throws {
        let malzeme = MaterialRecord(materialName: "Çimento", unit: "ton",
                                     category: .cimento)
        context.insert(malzeme)

        XCTAssertEqual(malzeme.orderedQty,  0, "Sipariş yok → 0")
        XCTAssertEqual(malzeme.receivedQty, 0, "Teslim alınan yok → 0")
        XCTAssertEqual(malzeme.usedQty,     0, "Kullanılan yok → 0")
        XCTAssertEqual(malzeme.wastageQty,  0, "Zayi yok → 0")
        XCTAssertEqual(malzeme.returnedQty, 0, "İade yok → 0")
        XCTAssertEqual(malzeme.stockQty,    0, "Stok = 0")
        XCTAssertTrue(malzeme.isStockEmpty, "Boş stok → isStockEmpty = true")
        XCTAssertNil(malzeme.lastUnitPrice, "Fiyat yok → nil")
        XCTAssertEqual(malzeme.stockValue,  0, "Stok değeri = 0")
    }

    // Test 2.2 — Temel stok akışı: teslim al → kullan
    func test_malzeme_temelAkis_teslimVeKullanim() throws {
        let malzeme = makeMalzeme(name: "Çimento", unit: "ton")

        // 100 ton sipariş verildi
        addTransaction(to: malzeme, type: .siparis, qty: 100)
        XCTAssertEqual(malzeme.orderedQty, 100, "Sipariş: 100 ton")
        XCTAssertEqual(malzeme.stockQty,   0,   "Sipariş stoku artırmaz")

        // 80 ton teslim alındı (1.500 TL/ton)
        addTransaction(to: malzeme, type: .teslimAlindi, qty: 80, unitPrice: 1_500)
        XCTAssertEqual(malzeme.receivedQty, 80, "Teslim alınan: 80 ton")
        XCTAssertEqual(malzeme.stockQty,    80, "Stok = 80 ton")

        // 30 ton kullanıldı
        addTransaction(to: malzeme, type: .kullanildi, qty: 30)
        XCTAssertEqual(malzeme.usedQty,  30, "Kullanılan: 30 ton")
        XCTAssertEqual(malzeme.stockQty, 50, "Stok = 80 - 30 = 50 ton")
    }

    // Test 2.3 — Zayi ve iade dahil tam stok formülü
    func test_malzeme_stokFormulu_tumTipler() throws {
        let malzeme = makeMalzeme(name: "Demir", unit: "ton")

        // Teslim alınan: 200 ton
        addTransaction(to: malzeme, type: .teslimAlindi, qty: 200, unitPrice: 12_000)
        // Kullanılan: 120 ton
        addTransaction(to: malzeme, type: .kullanildi, qty: 120)
        // Zayi: 5 ton
        addTransaction(to: malzeme, type: .zayi, qty: 5)
        // İade: 10 ton
        addTransaction(to: malzeme, type: .iade, qty: 10)

        // stockQty = received(200) - used(120) - wastage(5) - returned(10) = 65
        XCTAssertEqual(malzeme.receivedQty, 200, accuracy: 0.01)
        XCTAssertEqual(malzeme.usedQty,     120, accuracy: 0.01)
        XCTAssertEqual(malzeme.wastageQty,    5, accuracy: 0.01)
        XCTAssertEqual(malzeme.returnedQty,  10, accuracy: 0.01)
        XCTAssertEqual(malzeme.stockQty,     65, accuracy: 0.01,
                       "200 - 120 - 5 - 10 = 65 ton")
    }

    // Test 2.4 — Stok değeri: miktar × son teslim fiyatı
    func test_malzeme_stokDegeri() throws {
        let malzeme = makeMalzeme(name: "Demir", unit: "ton")

        addTransaction(to: malzeme, type: .teslimAlindi, qty: 100, unitPrice: 10_000)   // eski fiyat
        addTransaction(to: malzeme, type: .teslimAlindi, qty: 50,  unitPrice: 12_000)   // güncel fiyat
        addTransaction(to: malzeme, type: .kullanildi,   qty: 30)

        // stockQty = 100+50 - 30 = 120 ton
        // lastUnitPrice = 12.000 (en son teslim fiyatı)
        XCTAssertEqual(malzeme.stockQty,       120, accuracy: 0.01, "Stok: 120 ton")
        XCTAssertEqual(malzeme.lastUnitPrice!, 12_000, accuracy: 0.01, "Son fiyat: 12.000 TL/ton")
        XCTAssertEqual(malzeme.stockValue, 120 * 12_000, accuracy: 0.01,
                       "Stok değeri = 120 × 12.000 = 1.440.000 TL")
    }

    // Test 2.5 — Son birim fiyatı: en yeni teslim kaydı
    func test_malzeme_lastUnitPrice_enYeniKayit() throws {
        let cal = Calendar.current
        let onceki  = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let guncel  = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!

        let malzeme = makeMalzeme(name: "Kum", unit: "m³")

        // Eski teslimat: 500 TL
        let t1 = MaterialTransaction(type: .teslimAlindi, quantity: 50, date: onceki)
        t1.unitPrice = 500
        link(t1, to: malzeme)

        // Yeni teslimat: 600 TL
        let t2 = MaterialTransaction(type: .teslimAlindi, quantity: 30, date: guncel)
        t2.unitPrice = 600
        link(t2, to: malzeme)

        XCTAssertEqual(malzeme.lastUnitPrice!, 600, accuracy: 0.01,
                       "En son teslimat fiyatı 600 TL/m³ olmalı")
    }

    // Test 2.6 — Minimum stok uyarısı
    func test_malzeme_minimumStokUyarisi() throws {
        let malzeme = makeMalzeme(name: "Çimento", unit: "ton")
        malzeme.minimumStockLevel = 20    // kritik seviye: 20 ton

        addTransaction(to: malzeme, type: .teslimAlindi, qty: 50)
        XCTAssertFalse(malzeme.isLowStock, "50 ton > 20 ton minimum — uyarı yok")

        addTransaction(to: malzeme, type: .kullanildi, qty: 35)
        // Stok = 50 - 35 = 15 ton → minimum altında
        XCTAssertEqual(malzeme.stockQty, 15, accuracy: 0.01)
        XCTAssertTrue(malzeme.isLowStock, "15 ton ≤ 20 ton minimum — UYARI")
    }

    // Test 2.7 — Sıfır minimum seviye: isLowStock her zaman false
    func test_malzeme_sifirMinimum_lowStockYok() throws {
        let malzeme = makeMalzeme(name: "Boya", unit: "lt")
        malzeme.minimumStockLevel = 0    // minimum tanımlanmamış

        addTransaction(to: malzeme, type: .teslimAlindi, qty: 10)
        addTransaction(to: malzeme, type: .kullanildi, qty: 9)
        // Stok = 1 lt (çok az ama minimum tanımlı değil)
        XCTAssertFalse(malzeme.isLowStock,
                       "minimumStockLevel=0 ise isLowStock her zaman false olmalı")
    }

    // Test 2.8 — Sıfır ve negatif stok
    func test_malzeme_sifirStok() throws {
        let malzeme = makeMalzeme(name: "Ahşap", unit: "m³")
        addTransaction(to: malzeme, type: .teslimAlindi, qty: 30)
        addTransaction(to: malzeme, type: .kullanildi,   qty: 30)

        XCTAssertEqual(malzeme.stockQty, 0)
        XCTAssertTrue(malzeme.isStockEmpty, "Stok = 0 → isStockEmpty = true")
        XCTAssertFalse(malzeme.isLowStock, "minimum=0 olduğunda isLowStock = false")
    }

    // Test 2.9 — Sipariş, teslim farkı (bekleme durumu)
    func test_malzeme_siparisVsTeslimFarki() throws {
        let malzeme = makeMalzeme(name: "Çakıl", unit: "ton")
        // 200 ton sipariş, sadece 150 ton teslim alındı
        addTransaction(to: malzeme, type: .siparis,       qty: 200)
        addTransaction(to: malzeme, type: .teslimAlindi,  qty: 150)

        XCTAssertEqual(malzeme.orderedQty,  200, "Sipariş: 200 ton")
        XCTAssertEqual(malzeme.receivedQty, 150, "Teslim alınan: 150 ton")
        XCTAssertEqual(malzeme.stockQty,    150, "Stok = teslim − kullanılan = 150")
        // 50 ton hâlâ bekleniyor
        let beklenen = malzeme.orderedQty - malzeme.receivedQty
        XCTAssertEqual(beklenen, 50, accuracy: 0.01, "50 ton hâlâ teslimat bekleniyor")
    }

    // Test 2.10 — totalCost hesabı
    func test_malzeme_transaction_totalCost() throws {
        let t = MaterialTransaction(type: .teslimAlindi, quantity: 45, date: Date())
        t.unitPrice = 800
        context.insert(t)

        XCTAssertEqual(t.totalCost!, 45 * 800, accuracy: 0.01,
                       "totalCost = 45 × 800 = 36.000 TL")
    }

    func test_malzeme_transaction_nilTotalCost_fiyatYok() throws {
        let t = MaterialTransaction(type: .kullanildi, quantity: 20, date: Date())
        // unitPrice set edilmedi
        context.insert(t)

        XCTAssertNil(t.totalCost, "Fiyat tanımlı değilse totalCost nil olmalı")
    }

    // ─────────────────────────────────────────────────
    // MARK: - BÖLÜM 3: NAKİT AKIŞ PROJEKSİYONU
    // ─────────────────────────────────────────────────

    // Test 3.1 — Gecikme ortalaması: geç ödemelerden hesaplanır
    func test_nakitAkis_ortalamGecikme_gecOdemeler() throws {
        let cal = Calendar.current
        let h = makeHakedisWithDueDate(
            daysFromNow: -60,   // vade 60 gün önce geçti
            grossAmount: 10_000
        )
        // Ödeme 30 gün geç yapıldı
        let odeme = Payment(amount: 10_000, paymentDate: cal.date(byAdding: .day, value: -30, to: Date())!)
        odeme.hakedis = h
        h.payments.append(odeme)
        context.insert(odeme)

        let ortalama = CashFlowEngine.ortalamGecikmeGun(hakedisler: [h])
        XCTAssertEqual(ortalama, 30, accuracy: 1.0,
                       "30 günlük tek geç ödeme → ortalama = 30")
    }

    // Test 3.2 — Gecikme ortalaması: birden fazla ödeme
    func test_nakitAkis_ortalamGecikme_cokluOdeme() throws {
        let cal = Calendar.current
        // Hakedis 1: 30 gün geç
        let h1 = makeHakedisWithDueDate(daysFromNow: -90, grossAmount: 10_000)
        let p1 = Payment(amount: 10_000,
                         paymentDate: cal.date(byAdding: .day, value: -60, to: Date())!)
        p1.hakedis = h1; h1.payments.append(p1); context.insert(p1)

        // Hakedis 2: 50 gün geç
        let h2 = makeHakedisWithDueDate(daysFromNow: -100, grossAmount: 10_000)
        let p2 = Payment(amount: 10_000,
                         paymentDate: cal.date(byAdding: .day, value: -50, to: Date())!)
        p2.hakedis = h2; h2.payments.append(p2); context.insert(p2)

        let ortalama = CashFlowEngine.ortalamGecikmeGun(hakedisler: [h1, h2])
        XCTAssertEqual(ortalama, 40, accuracy: 1.0,
                       "(30 + 50) / 2 = 40 gün ortalama gecikme")
    }

    // Test 3.3 — Gecikme ortalaması: zamanında ödemede sıfır döner
    func test_nakitAkis_ortalamGecikme_zamanindaOdeme() throws {
        let cal = Calendar.current
        let h = makeHakedisWithDueDate(daysFromNow: -30, grossAmount: 10_000)
        // Ödeme vadeden 5 gün ÖNCE yapıldı (negatif gecikme → filtrelenir)
        let p = Payment(amount: 10_000,
                        paymentDate: cal.date(byAdding: .day, value: -35, to: Date())!)
        p.hakedis = h; h.payments.append(p); context.insert(p)

        let ortalama = CashFlowEngine.ortalamGecikmeGun(hakedisler: [h])
        XCTAssertEqual(ortalama, 0,
                       "Zamanında ödeme → gecikme filtreler → ortalama = 0")
    }

    // Test 3.4 — Veri yoksa ortalama sıfır döner
    func test_nakitAkis_ortalamGecikme_veriYok() throws {
        let ortalama = CashFlowEngine.ortalamGecikmeGun(hakedisler: [])
        XCTAssertEqual(ortalama, 0, "Hakediş yok → ortalama = 0")
    }

    // Test 3.5 — Aylık ortalama hakediş: son 3 ay dahilinde
    func test_nakitAkis_ortalamaAylik_son3ay() throws {
        let cal = Calendar.current
        let ref = cal.date(from: DateComponents(year: 2026, month: 3, day: 31))!
        let twoMonthsAgo = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!

        // Son 3 ay içinde 3 hakediş, her biri farklı ay → ortalama = toplam / 3
        let h1 = makeHakedisWithPeriodEnd(cal.date(from: DateComponents(year: 2026, month: 1, day: 31))!, gross: 30_000)
        let h2 = makeHakedisWithPeriodEnd(cal.date(from: DateComponents(year: 2026, month: 2, day: 28))!, gross: 60_000)
        let h3 = makeHakedisWithPeriodEnd(cal.date(from: DateComponents(year: 2026, month: 3, day: 20))!, gross: 90_000)
        _ = twoMonthsAgo

        let ort = CashFlowEngine.ortalamaAylikHakedis(hakedisler: [h1, h2, h3], referenceDate: ref)
        // Toplam = 180.000, 3 farklı ay → ortalama = 60.000
        XCTAssertEqual(ort, 60_000, accuracy: 1.0,
                       "(30K + 60K + 90K) / 3 ay = 60.000 TL aylık ortalama")
    }

    // Test 3.6 — Son 3 ay dışında veri yoksa tüm hakedişler kullanılır
    func test_nakitAkis_ortalamaAylik_eskiVeri() throws {
        let cal = Calendar.current
        let ref = cal.date(from: DateComponents(year: 2026, month: 3, day: 31))!
        // 6 ay önce 2 hakediş
        let h1 = makeHakedisWithPeriodEnd(cal.date(from: DateComponents(year: 2025, month: 9, day: 30))!, gross: 50_000)
        let h2 = makeHakedisWithPeriodEnd(cal.date(from: DateComponents(year: 2025, month: 8, day: 31))!, gross: 70_000)

        let ort = CashFlowEngine.ortalamaAylikHakedis(hakedisler: [h1, h2], referenceDate: ref)
        // Son 3 ayda veri yok → tüm hakedişlerin ortalaması: (50K + 70K) / 2 = 60K
        XCTAssertEqual(ort, 60_000, accuracy: 1.0,
                       "Eski veri: (50K + 70K) / 2 = 60.000 TL fallback ortalama")
    }

    // Test 3.7 — Optimist senaryo (gecikme=0): her ay tam tahsilat
    func test_nakitAkis_optimistSenaryo() throws {
        let cal = Calendar.current
        let ref = cal.date(from: DateComponents(year: 2026, month: 3, day: 31))!
        let h = makeHakedisWithPeriodEnd(
            cal.date(from: DateComponents(year: 2026, month: 3, day: 20))!,
            gross: 120_000
        )
        // Zamanında ödeme → ortalama gecikme = 0
        let p = Payment(amount: 120_000, paymentDate: h.dueDate ?? Date())
        p.hakedis = h; h.payments.append(p); context.insert(p)

        let projeler = CashFlowEngine.projeksiyonlar(
            hakedisler: [h],
            senaryo: .optimist,
            referenceDate: ref
        )

        // Ortalama aylık = 120.000
        // Optimist gecikme = 0 → her ay tahsilat = beklenenHakedis
        for (i, proje) in projeler.enumerated() {
            XCTAssertEqual(proje.beklenenTahsilat, proje.beklenenHakedis, accuracy: 1.0,
                           "Optimist: ay \(i+1) → tahsilat = hakediş (gecikme yok)")
        }

        // Kümülatif nakit = 0 (her ay tahsilat - harcama = 0)
        for proje in projeler {
            XCTAssertEqual(proje.kumulatifNakit, 0, accuracy: 1.0,
                           "Optimist: kümülatif nakit = 0 (denge)")
        }
    }

    // Test 3.8 — Gerçekçi senaryo: 30 gün gecikme → 1. ay kısmi, sonrası tam
    func test_nakitAkis_gercekciSenaryo_30GunGecikme() throws {
        let cal = Calendar.current
        let ref = cal.date(from: DateComponents(year: 2026, month: 1, day: 31))!

        // 1 hakediş, 120.000 TL brüt
        let h = makeHakedisWithPeriodEnd(
            cal.date(from: DateComponents(year: 2026, month: 1, day: 20))!,
            gross: 120_000
        )
        // 30 gün geç ödeme → ortalama gecikme = 30
        let vadeTarihi = cal.date(byAdding: .day, value: -60, to: Date())!
        h.dueDate = vadeTarihi
        let p = Payment(amount: 120_000,
                        paymentDate: cal.date(byAdding: .day, value: -30, to: Date())!)
        p.hakedis = h; h.payments.append(p); context.insert(p)

        let projeler = CashFlowEngine.projeksiyonlar(
            hakedisler: [h],
            senaryo: .gercekci,
            referenceDate: ref
        )

        // gecikme = 30 gün → offsetAy = Int(30/30) = 1
        // Ay 1 (offset=1 == offsetAy=1): tahsilatOrani = 0.6
        // Ay 2 (offset=2 > offsetAy=1): tahsilatOrani = 1.0
        // Ay 3 (offset=3 > offsetAy=1): tahsilatOrani = 1.0
        XCTAssertEqual(projeler.count, 3, "3 aylık projeksiyon üretilmeli")
        XCTAssertEqual(projeler[0].beklenenTahsilat, 120_000 * 0.6, accuracy: 1.0,
                       "1. ay: %60 tahsilat (30 gün gecikme)")
        XCTAssertEqual(projeler[1].beklenenTahsilat, 120_000, accuracy: 1.0,
                       "2. ay: %100 tahsilat")
        XCTAssertEqual(projeler[2].beklenenTahsilat, 120_000, accuracy: 1.0,
                       "3. ay: %100 tahsilat")

        // Kümülatif nakit
        // Ay 1: kümülatif = (72K - 120K) = -48K
        XCTAssertEqual(projeler[0].kumulatifNakit, -48_000, accuracy: 1.0,
                       "1. ay kümülatif: 72K - 120K = -48K (nakit açığı)")
        // Ay 2: kümülatif = -48K + (120K - 120K) = -48K
        XCTAssertEqual(projeler[1].kumulatifNakit, -48_000, accuracy: 1.0,
                       "2. ay kümülatif: -48K + 0 = -48K")
        // Ay 3: kümülatif = -48K + 0 = -48K
        XCTAssertEqual(projeler[2].kumulatifNakit, -48_000, accuracy: 1.0,
                       "3. ay kümülatif: -48K")
    }

    // Test 3.9 — Kötümser senaryo: 2× gecikme → ilk 2 ay sıfır tahsilat
    func test_nakitAkis_kotumserSenaryo_60GunGecikme() throws {
        let cal = Calendar.current
        let ref = cal.date(from: DateComponents(year: 2026, month: 1, day: 31))!

        // 30 gün geç ödeme → ortalama = 30, kötümser = 60
        let h = makeHakedisWithPeriodEnd(
            cal.date(from: DateComponents(year: 2026, month: 1, day: 20))!,
            gross: 100_000
        )
        h.dueDate = cal.date(byAdding: .day, value: -60, to: Date())!
        let p = Payment(amount: 100_000,
                        paymentDate: cal.date(byAdding: .day, value: -30, to: Date())!)
        p.hakedis = h; h.payments.append(p); context.insert(p)

        let projeler = CashFlowEngine.projeksiyonlar(
            hakedisler: [h],
            senaryo: .kotumser,
            referenceDate: ref
        )

        // gecikme = 60 → offsetAy = Int(60/30) = 2
        // Ay 1: offset=1 < offsetAy=2 → tahsilatOrani=0.0
        // Ay 2: offset=2 == offsetAy=2 → tahsilatOrani=0.6
        // Ay 3: offset=3 > offsetAy=2 → tahsilatOrani=1.0
        XCTAssertEqual(projeler[0].beklenenTahsilat, 0, accuracy: 1.0,
                       "Kötümser 1. ay: tahsilat yok (60 gün gecikme)")
        XCTAssertEqual(projeler[1].beklenenTahsilat, 100_000 * 0.6, accuracy: 1.0,
                       "Kötümser 2. ay: %60 tahsilat")
        XCTAssertEqual(projeler[2].beklenenTahsilat, 100_000, accuracy: 1.0,
                       "Kötümser 3. ay: %100 tahsilat")

        // Kritik ay tespiti: ilk ay negatif
        XCTAssertTrue(CashFlowEngine.kritikAyVarMi(projeksiyonlar: projeler),
                      "Kötümser senaryoda kritik ay (nakit açığı) olmalı")
    }

    // Test 3.10 — Toplam beklenen tahsilat
    func test_nakitAkis_toplamTahsilat() throws {
        let projeler = [
            AylikProje(ay: "Nis", date: Date(), beklenenHakedis: 100_000, beklenenTahsilat: 60_000,  kumulatifNakit: -40_000, gecikmeSuresi: 30),
            AylikProje(ay: "May", date: Date(), beklenenHakedis: 100_000, beklenenTahsilat: 100_000, kumulatifNakit: -40_000, gecikmeSuresi: 30),
            AylikProje(ay: "Haz", date: Date(), beklenenHakedis: 100_000, beklenenTahsilat: 100_000, kumulatifNakit: -40_000, gecikmeSuresi: 30)
        ]

        let toplam = CashFlowEngine.toplamBeklenenTahsilat(projeksiyonlar: projeler)
        XCTAssertEqual(toplam, 260_000, accuracy: 1.0,
                       "60K + 100K + 100K = 260.000 TL toplam tahsilat")
    }

    // Test 3.11 — kritikAyVarMi: sadece pozitif senaryoda false
    func test_nakitAkis_kritikAyYok_optimist() throws {
        let projeler = [
            AylikProje(ay: "Nis", date: Date(), beklenenHakedis: 100_000, beklenenTahsilat: 100_000, kumulatifNakit: 0, gecikmeSuresi: 0),
            AylikProje(ay: "May", date: Date(), beklenenHakedis: 100_000, beklenenTahsilat: 100_000, kumulatifNakit: 0, gecikmeSuresi: 0),
            AylikProje(ay: "Haz", date: Date(), beklenenHakedis: 100_000, beklenenTahsilat: 100_000, kumulatifNakit: 0, gecikmeSuresi: 0)
        ]
        XCTAssertFalse(CashFlowEngine.kritikAyVarMi(projeksiyonlar: projeler),
                       "Optimist senaryoda kümülatif=0 → kritik ay yok")
    }

    // ─────────────────────────────────────────────────
    // MARK: - BÖLÜM 4: KÜMÜLATIF MİKTAR TUTARLILIK
    // ─────────────────────────────────────────────────

    // Test 4.1 — 2 hakediş arası kümülatif miktar tutarlılığı
    func test_kumulatif_ikiHakedis_tutarlilik() throws {
        let contract = makeContract()

        // 1. Hakediş: kazı 75 m³
        let h1 = makeHakedisWithItem(contract: contract, prevQty: 0, currQty: 75)
        _ = h1

        // 2. Hakediş: kazı 20 m³ daha (önceki=75)
        let h2 = makeHakedisWithItem(contract: contract, prevQty: 75, currQty: 20)

        XCTAssertEqual(h2.items[0].previousQuantity, 75, "2. hakedişin öncekisi 75 olmalı")
        XCTAssertEqual(h2.items[0].currentQuantity,  20, "Bu dönem 20 m³")
        XCTAssertEqual(h2.items[0].cumulativeQuantity, 95, "75+20 = 95 m³ kümülatif")
        XCTAssertEqual(h2.items[0].cumulativeAmount, 95 * 85, accuracy: 0.01,
                       "95 × 85 = 8.075 TL kümülatif tutar")
    }

    // Test 4.2 — Kümülatif miktarın sözleşme miktarını aşması
    func test_kumulatif_sozlesmeAsimTespiti() throws {
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 85, contractedQuantity: 100)
        context.insert(workItem)

        // completedQuantity = Σ dailyEntries
        for qty in [40.0, 35.0, 30.0] {   // toplam 105 → aşım
            let e = DailyEntry(quantity: qty)
            e.workItem = workItem
            workItem.dailyEntries.append(e)
            context.insert(e)
        }

        XCTAssertEqual(workItem.completedQuantity, 105)
        // completionPercentage max 100'e sınırlanmış
        XCTAssertEqual(workItem.completionPercentage, 100,
                       "%105 → %100'e sınırlanmalı (iş kalemi model kuralı)")
        XCTAssertEqual(workItem.remainingQuantity, -5,
                       "Negatif kalan = sözleşme aşımı 5 m³")
    }

    // ─────────────────────────────────────────────────
    // MARK: - Yardımcı Metotlar
    // ─────────────────────────────────────────────────

    @discardableResult
    private func makeMeasurementEntry(
        no: String, code: String,
        calculatedQty: Double, netQty: Double,
        previousEntries: Double,
        workItem: WorkItem
    ) -> MeasurementEntry {
        let entry = MeasurementEntry(
            entryNo: no, workItemCode: code, location: "Test",
            measurementType: .hacim, previousEntries: previousEntries
        )
        entry.calculatedQuantity = calculatedQty
        entry.netQuantity        = netQty
        entry.workItem           = workItem
        workItem.measurementEntries.append(entry)
        context.insert(entry)
        return entry
    }

    private func makeMalzeme(name: String, unit: String) -> MaterialRecord {
        let m = MaterialRecord(materialName: name, unit: unit)
        context.insert(m)
        return m
    }

    private func addTransaction(
        to malzeme: MaterialRecord,
        type: MaterialTransactionType,
        qty: Double,
        unitPrice: Double? = nil
    ) {
        let t = MaterialTransaction(type: type, quantity: qty, date: Date())
        t.unitPrice = unitPrice
        link(t, to: malzeme)
    }

    private func link(_ t: MaterialTransaction, to malzeme: MaterialRecord) {
        t.material = malzeme
        malzeme.transactions.append(t)
        context.insert(t)
    }

    private func makeHakedisWithDueDate(daysFromNow: Int, grossAmount: Double) -> Hakedis {
        let contract = makeContract()
        let cal = Calendar.current
        let periodEnd = cal.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        let h = Hakedis(periodName: "Test", periodStart: periodEnd, periodEnd: periodEnd,
                        dueDate: cal.date(byAdding: .day, value: daysFromNow, to: Date()))
        h.contract = contract
        h.status   = .approved
        context.insert(h)

        let item = HakedisItem(workItemName: "Test", workItemCode: "01",
                               unit: "m³", unitPrice: grossAmount,
                               previousQuantity: 0, currentQuantity: 1)
        item.hakedis = h; h.items.append(item); context.insert(item)
        return h
    }

    private func makeHakedisWithPeriodEnd(_ periodEnd: Date, gross: Double) -> Hakedis {
        let contract = makeContract()
        let h = Hakedis(periodName: "Test", periodStart: periodEnd, periodEnd: periodEnd)
        h.contract = contract
        context.insert(h)

        let item = HakedisItem(workItemName: "Test", workItemCode: "01",
                               unit: "m³", unitPrice: gross,
                               previousQuantity: 0, currentQuantity: 1)
        item.hakedis = h; h.items.append(item); context.insert(item)
        return h
    }

    private func makeContract() -> Contract {
        let c = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        context.insert(c)
        return c
    }

    private func makeHakedisWithItem(contract: Contract, prevQty: Double, currQty: Double) -> Hakedis {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let end   = cal.date(from: DateComponents(year: 2026, month: 3, day: 31))!
        let h = Hakedis(periodName: "Test", periodStart: start, periodEnd: end)
        h.contract = contract
        contract.hakedisler.append(h)
        context.insert(h)

        let item = HakedisItem(workItemName: "Kazı", workItemCode: "01",
                               unit: "m³", unitPrice: 85,
                               previousQuantity: prevQty, currentQuantity: currQty)
        item.hakedis = h; h.items.append(item); context.insert(item)
        return h
    }
}
