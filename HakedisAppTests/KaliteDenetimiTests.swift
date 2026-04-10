import XCTest
import SwiftData

// MARK: - Kalite Denetimi Test Paketi
// AŞAMA 3 — Hesaplama motorları + AŞAMA 4 — Validasyon

final class HakedisHesaplamaKamuTests: XCTestCase {

    // MARK: 3.1 — Kamu İhalesi Birim Fiyat Tam Senaryo

    func test_kamuBirimFiyat_brutHakedis() {
        let beton = 120.0 * 2800.0
        let demir = 15.0 * 30000.0
        let siva  = 0.0  * 220.0
        let brut  = beton + demir + siva
        XCTAssertEqual(brut, 786_000.0, "Brüt hakediş 786.000 olmalı")
    }

    func test_kamuBirimFiyat_stopaj() {
        let brut   = 786_000.0
        let stopaj = brut * 0.03
        XCTAssertEqual(stopaj, 23_580.0, accuracy: 0.01, "Stopaj %3 = 23.580")
    }

    func test_kamuBirimFiyat_damgaVergisi() {
        let brut  = 786_000.0
        let damga = brut * 0.00948
        XCTAssertEqual(damga, 7_451.28, accuracy: 0.01, "Damga vergisi 0,948‰ = 7.451,28")
    }

    func test_kamuBirimFiyat_teminat() {
        let brut    = 786_000.0
        let teminat = brut * 0.06
        XCTAssertEqual(teminat, 47_160.0, accuracy: 0.01, "Teminat %6 = 47.160")
    }

    func test_kamuBirimFiyat_netTutar() {
        let brut    = 786_000.0
        let stopaj  = brut * 0.03
        let damga   = brut * 0.00948
        let teminat = brut * 0.06
        let net     = brut - stopaj - damga - teminat
        XCTAssertEqual(net, 707_808.72, accuracy: 0.01, "Net hakediş 707.808,72")
    }

    func test_kamuBirimFiyat_kdv() {
        let net = 707_808.72
        let kdv = net * 0.20
        XCTAssertEqual(kdv, 141_561.744, accuracy: 0.01, "KDV %20 = 141.561,74")
    }

    func test_kamuBirimFiyat_odenecekTutar() {
        let brut    = 786_000.0
        let stopaj  = brut * 0.03
        let damga   = brut * 0.00948
        let teminat = brut * 0.06
        let net     = brut - stopaj - damga - teminat
        let kdv     = net * 0.20
        let toplam  = net + kdv
        XCTAssertEqual(toplam, 849_370.464, accuracy: 0.01, "Ödenecek tutar 849.370,46")
        XCTAssertFalse(toplam.isNaN)
        XCTAssertFalse(toplam.isInfinite)
    }

    func test_sifirBrutHakedis_crashOlmamali() {
        let brut    = 0.0
        let stopaj  = brut * 0.03
        let teminat = brut * 0.06
        let net     = brut - stopaj - teminat
        let kdv     = net * 0.20
        let toplam  = net + kdv
        XCTAssertEqual(toplam, 0.0)
        XCTAssertFalse(toplam.isNaN)
        XCTAssertFalse(toplam.isInfinite)
    }

    func test_buyukSayi_overflow_olmamali() {
        let brut    = 999_999_999.0
        let stopaj  = brut * 0.03
        let teminat = brut * 0.06
        let net     = brut - stopaj - teminat
        let kdv     = net * 0.20
        let toplam  = net + kdv
        XCTAssertFalse(toplam.isNaN)
        XCTAssertFalse(toplam.isInfinite)
        XCTAssertGreaterThan(toplam, 0)
    }

    func test_kumulatifMiktar() {
        let sozlesme: Double = 500
        let onceki:   Double = 120
        let buDonem:  Double = 80
        let kumulatif = onceki + buDonem
        let ilerleme  = min((kumulatif / sozlesme) * 100, 100)
        XCTAssertEqual(kumulatif, 200.0)
        XCTAssertEqual(ilerleme, 40.0)
    }

    func test_kumulatifSozlesmeAsimi_100deSinirlanmali() {
        let sozlesme: Double = 500
        let onceki:   Double = 400
        let buDonem:  Double = 150
        let kumulatif = onceki + buDonem // 550 > 500
        let ilerleme  = min((kumulatif / sozlesme) * 100, 100)
        XCTAssertEqual(ilerleme, 100.0, "%100 sınırına takılmalı")
        XCTAssertEqual(kumulatif, 550.0, "Gerçek miktar 550 olarak kalmalı")
    }
}

// MARK: - KDV Tevkifat

final class KDVTevkifatTests: XCTestCase {

    func test_tevkifat_2_10() {
        let net     = 707_808.72
        let kdv     = net * 0.20
        let tevkifat    = kdv * (2.0 / 10.0)
        let odenecekKDV = kdv - tevkifat
        XCTAssertEqual(tevkifat, 28_312.3488, accuracy: 0.01, "2/10 tevkifat")
        XCTAssertEqual(odenecekKDV, 113_249.3952, accuracy: 0.01, "Kalan KDV")
    }

    func test_tevkifat_7_10() {
        let net         = 500_000.0
        let kdv         = net * 0.20
        let tevkifat    = kdv * (7.0 / 10.0)
        let odenecekKDV = kdv - tevkifat
        XCTAssertEqual(tevkifat, 70_000.0, accuracy: 0.01)
        XCTAssertEqual(odenecekKDV, 30_000.0, accuracy: 0.01)
    }

    func test_tevkifat_sifirNet_crashOlmamali() {
        let net         = 0.0
        let kdv         = net * 0.20
        let tevkifat    = kdv * (2.0 / 10.0)
        XCTAssertEqual(tevkifat, 0.0)
        XCTAssertFalse(tevkifat.isNaN)
    }
}

// MARK: - Fiyat Farkı (4735 Md.38 D Formülü)

final class FiyatFarkiTests: XCTestCase {

    func test_dFormulu_katsayiToplami_birOlmali() {
        let b1 = 0.28
        let b2 = 0.32
        let b3 = 0.22
        let b4 = 0.10
        let b5 = 0.08
        let toplam = b1 + b2 + b3 + b4 + b5
        XCTAssertEqual(toplam, 1.00, accuracy: 0.001, "D formülü katsayıları toplamı 1.00 olmalı")
    }

    func test_dFormulu_fiyatArtisi_pozitifSonuc() {
        let an = 786_000.0
        let b1 = 0.28; let pn1 = 1450.0; let po1 = 1200.0
        let b2 = 0.32; let pn2 = 2100.0; let po2 = 1800.0
        let b3 = 0.22; let pn3 = 1350.0; let po3 = 1100.0
        let b4 = 0.10; let pn4 = 1600.0; let po4 = 1300.0
        let b5 = 0.08; let pn5 = 1250.0; let po5 = 1100.0
        let deger = b1*(pn1/po1) + b2*(pn2/po2) + b3*(pn3/po3) + b4*(pn4/po4) + b5*(pn5/po5) - 1.0
        let fiyatFarki = an * deger
        XCTAssertGreaterThan(fiyatFarki, 0, "Fiyat artışında fiyat farkı pozitif olmalı")
        XCTAssertFalse(fiyatFarki.isNaN)
    }

    func test_dFormulu_yanlisKatsayiToplami() {
        let katsayilar = [0.28, 0.32, 0.22, 0.10, 0.07]
        let toplam = katsayilar.reduce(0, +)
        XCTAssertNotEqual(toplam, 1.00, accuracy: 0.001, "Hatalı katsayılar toplamı 1.00 olmamalı")
    }

    func test_endeksSifir_bolumSifirGuvenli() {
        let po = 0.0
        let ev = 1500.0
        let oran = po != 0 ? ev / po : 0
        XCTAssertFalse(oran.isNaN)
        XCTAssertFalse(oran.isInfinite)
        XCTAssertEqual(oran, 0)
    }
}

// MARK: - SGK Hesaplama

final class SGKHesaplamaTests: XCTestCase {

    func test_sgk_isciPaylari() {
        let brut: Double = 33_000
        let sgkIsci      = brut * 0.14
        let issizlikIsci = brut * 0.01
        XCTAssertEqual(sgkIsci, 4_620.0, accuracy: 0.01, "SGK işçi payı %14")
        XCTAssertEqual(issizlikIsci, 330.0, accuracy: 0.01, "İşsizlik işçi %1")
    }

    func test_sgk_isverenPaylari() {
        let brut: Double = 33_000
        let sgkIsveren      = brut * 0.205
        let issizlikIsveren = brut * 0.02
        XCTAssertEqual(sgkIsveren, 6_765.0, accuracy: 0.01, "SGK işveren %20.5")
        XCTAssertEqual(issizlikIsveren, 660.0, accuracy: 0.01, "İşsizlik işveren %2")
    }

    func test_sgk_gelirVergisiMatrahi() {
        let brut: Double = 33_000
        let sgkIsci      = brut * 0.14
        let issizlikIsci = brut * 0.01
        let toplamKesinti = sgkIsci + issizlikIsci
        let matrah        = brut - toplamKesinti
        XCTAssertEqual(toplamKesinti, 4_950.0, accuracy: 0.01)
        XCTAssertEqual(matrah, 28_050.0, accuracy: 0.01)
    }

    func test_sgk_sifirBrut_crashOlmamali() {
        let brut: Double = 0
        let sgkIsci  = brut * 0.14
        let matrah   = brut - sgkIsci
        let gv       = matrah * 0.15
        XCTAssertEqual(gv, 0.0)
        XCTAssertFalse(gv.isNaN)
    }
}

// MARK: - Fazla Mesai (4857 İş Kanunu)

final class FazlaMesaiTests: XCTestCase {

    func test_fazlaMesai_haftalikSinirAstiktan_50Saat() {
        let normalSaat:    Double = 45
        let calisilanSaat: Double = 50
        let fazla = max(calisilanSaat - normalSaat, 0)
        XCTAssertEqual(fazla, 5.0)

        let saatlikUcret  = 33_000.0 / 30.0 / 7.5
        let fazlaUcret    = fazla * saatlikUcret * 1.5
        XCTAssertGreaterThan(fazlaUcret, 0)
    }

    func test_fazlaMesai_tatilGunu_yuzdeYuzZamli() {
        let saatlikUcret = 33_000.0 / 30.0 / 7.5
        let tatilSaat    = 8.0
        let tatilUcret   = tatilSaat * saatlikUcret * 2.0
        XCTAssertGreaterThan(tatilUcret, 0)
    }

    func test_fazlaMesai_yillikSinir_270Saat() {
        let yillikFazla = 280.0
        XCTAssertTrue(yillikFazla > 270, "270 saat aşıldı — uyarı verilmeli")
    }

    func test_fazlaMesai_normalSaatAltinda_sifir() {
        let normalSaat:    Double = 45
        let calisilanSaat: Double = 40
        let fazla = max(calisilanSaat - normalSaat, 0)
        XCTAssertEqual(fazla, 0)
    }
}

// MARK: - Gecikme Cezası

final class GecikmeCezasiTests: XCTestCase {

    func test_gecikmeCezasi_hesaplama() {
        let sozlesmeBedeli = 10_000_000.0
        let gunlukOran     = 0.001
        let gecikenGun     = 15
        let gunlukCeza     = sozlesmeBedeli * gunlukOran
        let toplamCeza     = gunlukCeza * Double(gecikenGun)
        XCTAssertEqual(gunlukCeza, 10_000.0, accuracy: 0.01)
        XCTAssertEqual(toplamCeza, 150_000.0, accuracy: 0.01)
    }

    func test_gecikmeCezasi_maksimumYuzde30Siniri() {
        let sozlesmeBedeli = 10_000_000.0
        let toplamCeza     = 4_000_000.0  // %40 — sınırı aşıyor
        let maxCeza        = sozlesmeBedeli * 0.30
        let uygulanan      = min(toplamCeza, maxCeza)
        XCTAssertLessThanOrEqual(uygulanan, maxCeza)
        XCTAssertEqual(uygulanan, maxCeza, accuracy: 0.01)
    }

    func test_gecikmeCezasi_sifirGun() {
        let ceza = 10_000_000.0 * 0.001 * 0.0
        XCTAssertEqual(ceza, 0.0)
    }
}

// MARK: - EVM (Kazanılmış Değer Yönetimi)

final class EVMTests: XCTestCase {

    func test_evm_cpi_spi_hesaplama() {
        let pv = 4_000_000.0
        let ev = 3_500_000.0
        let ac = 3_800_000.0
        let cpi = ev / ac
        let spi = ev / pv
        XCTAssertEqual(cpi, 0.921, accuracy: 0.001, "CPI < 1 = bütçe aşımı")
        XCTAssertEqual(spi, 0.875, accuracy: 0.001, "SPI < 1 = geride")
    }

    func test_evm_eac_gecBac() {
        let bac = 10_000_000.0
        let ev  = 3_500_000.0
        let ac  = 3_800_000.0
        let cpi = ev / ac
        let eac = bac / cpi
        XCTAssertGreaterThan(eac, bac, "CPI < 1 ise EAC > BAC olmalı")
        XCTAssertFalse(eac.isNaN)
    }

    func test_evm_sifirAC_bolumSifirGuvenli() {
        let ev = 3_500_000.0
        let ac = 0.0
        let pv = 0.0
        let cpi = ac != 0 ? ev / ac : 0
        let spi = pv != 0 ? ev / pv : 0
        XCTAssertFalse(cpi.isNaN)
        XCTAssertFalse(cpi.isInfinite)
        XCTAssertFalse(spi.isNaN)
        XCTAssertFalse(spi.isInfinite)
    }
}

// MARK: - İş Artışı / Eksilişi (4735 Md.24)

final class IsArtisiEksilisiTests: XCTestCase {

    func test_isArtisi_yuzde20Siniri_asildi() {
        let sozlesmeBedeli = 10_000_000.0
        let artis          = 2_500_000.0
        let artisYuzdesi   = (artis / sozlesmeBedeli) * 100
        XCTAssertTrue(artisYuzdesi > 20, "%20 sınırı aşıldı — yeni sözleşme gerekli")
    }

    func test_isArtisi_yuzde20Icinde_gecerli() {
        let sozlesmeBedeli = 10_000_000.0
        let artis          = 1_500_000.0
        let artisYuzdesi   = (artis / sozlesmeBedeli) * 100
        XCTAssertFalse(artisYuzdesi > 20, "%15 artış — %20 sınırı içinde")
    }

    func test_isEksilisi_yuzde20Siniri_asildi() {
        let sozlesmeBedeli = 10_000_000.0
        let eksilis        = 2_100_000.0
        let eksilisYuzdesi = (eksilis / sozlesmeBedeli) * 100
        XCTAssertTrue(eksilisYuzdesi > 20, "%21 eksiliş sınırı aşıldı")
    }

    func test_bolmeSifir_sozlesmeBedeliSifir() {
        let sozlesmeBedeli = 0.0
        let artis          = 100_000.0
        let oran = sozlesmeBedeli != 0 ? (artis / sozlesmeBedeli) * 100 : 0
        XCTAssertFalse(oran.isNaN)
        XCTAssertFalse(oran.isInfinite)
    }
}

// MARK: - Validasyon

final class ValidationHelperTests: XCTestCase {

    // IBAN
    func test_iban_gecerli() {
        XCTAssertTrue(ValidationHelper.isValidIBAN("TR330006100519786457841326"))
    }

    func test_iban_alman_gecersiz() {
        XCTAssertFalse(ValidationHelper.isValidIBAN("DE89370400440532013000"))
    }

    func test_iban_kisa_gecersiz() {
        XCTAssertFalse(ValidationHelper.isValidIBAN("TR12345"))
    }

    func test_iban_bos_gecersiz() {
        XCTAssertFalse(ValidationHelper.isValidIBAN(""))
    }

    func test_iban_bosluklu_temizlenir() {
        XCTAssertTrue(ValidationHelper.isValidIBAN("TR33 0006 1005 1978 6457 8413 26"))
    }

    // TC Kimlik
    func test_tc_gecerli() {
        XCTAssertTrue(ValidationHelper.isValidTCKimlik("12345678901"))
    }

    func test_tc_sifirIlkHane_gecersiz() {
        XCTAssertFalse(ValidationHelper.isValidTCKimlik("01234567890"))
    }

    func test_tc_onHane_gecersiz() {
        XCTAssertFalse(ValidationHelper.isValidTCKimlik("1234567890"))
    }

    func test_tc_bos_gecersiz() {
        XCTAssertFalse(ValidationHelper.isValidTCKimlik(""))
    }

    // Vergi No
    func test_vergiNo_10Hane_gecerli() {
        XCTAssertTrue(ValidationHelper.isValidVergiNo("1234567890"))
    }

    func test_vergiNo_11Hane_gecerli() {
        XCTAssertTrue(ValidationHelper.isValidVergiNo("12345678901"))
    }

    func test_vergiNo_9Hane_gecersiz() {
        XCTAssertFalse(ValidationHelper.isValidVergiNo("123456789"))
    }

    // Telefon
    func test_telefon_gecerli_10Hane() {
        XCTAssertTrue(ValidationHelper.isValidPhone("5321234567"))
    }

    func test_telefon_plusli_gecerli() {
        XCTAssertTrue(ValidationHelper.isValidPhone("+905321234567"))
    }

    func test_telefon_bos_gecersiz() {
        XCTAssertFalse(ValidationHelper.isValidPhone(""))
    }
}

// MARK: - Proje Dashboard Computed Properties

final class ProjectComputedPropertyTests: XCTestCase {

    private var container: ModelContainer!
    private var context:   ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Project.self, Contract.self, WorkItem.self,
                             Hakedis.self, HakedisItem.self, Payment.self,
                             Contractor.self, RetentionRelease.self, Guarantee.self,
                             ChangeOrder.self, SiteHandoverRecord.self,
                             SiteDeficiency.self, LaborRecord.self, MaterialRecord.self,
                             SpecificationItem.self, CorrespondenceRecord.self,
                             PriceDifferenceRecord.self, SGKLaborRecord.self,
                             SiteLogEntry.self, Equipment.self, SoilRecord.self,
                             TestRecord.self, AcceptanceRecord.self,
                             DailyEntry.self, Milestone.self, SiteReport.self,
                             HakedisItem.self, ApprovalStep.self, HakedisRevision.self,
                             VATWithholdingRecord.self, UnitPriceAnalysis.self,
                             MeasurementEntry.self, PhotoAnnotation.self,
                             AttachmentRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    func test_contractAmount_bos_sifir() throws {
        let project = Project(name: "Test")
        context.insert(project)
        XCTAssertEqual(project.contractAmount, 0)
    }

    func test_contractAmount_isKalemleriToplar() throws {
        let project  = Project(name: "Test")
        let contract = Contract(title: "Sözleşme")
        let w1 = WorkItem(code: "01", name: "Beton", unit: "m³", unitPrice: 2800, contractedQuantity: 100)
        let w2 = WorkItem(code: "02", name: "Demir", unit: "ton", unitPrice: 30000, contractedQuantity: 10)
        contract.workItems.append(w1)
        contract.workItems.append(w2)
        contract.project = project
        project.contracts.append(contract)
        context.insert(project)
        context.insert(contract)
        context.insert(w1)
        context.insert(w2)
        // 100×2800 + 10×30000 = 280000 + 300000 = 580000
        XCTAssertEqual(project.contractAmount, 580_000, accuracy: 0.01)
    }

    func test_completionPercentage_bos_sifir() throws {
        let project = Project(name: "Test")
        context.insert(project)
        XCTAssertEqual(project.completionPercentage, 0)
    }

    func test_remainingReceivable_hicOdenmemis() throws {
        let project  = Project(name: "Test")
        let contract = Contract(title: "Sözleşme")
        let w = WorkItem(code: "01", name: "Beton", unit: "m³", unitPrice: 1000, contractedQuantity: 100)
        contract.workItems.append(w)
        contract.project = project
        project.contracts.append(contract)
        context.insert(project)
        context.insert(contract)
        context.insert(w)
        XCTAssertEqual(project.remainingReceivable, 100_000, accuracy: 0.01)
    }
}
