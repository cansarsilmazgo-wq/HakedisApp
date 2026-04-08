import Foundation

struct PozItem: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let unit: String
    let category: String
    let unitPrice: Double

    static func == (lhs: PozItem, rhs: PozItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Poz Kütüphanesi

struct PozLibrary {

    static var allPozlar: [PozItem] { items }

    static let items: [PozItem] = [

        // 01 — İnşaat Genel (Şantiye Tesisleri)
        PozItem(code: "01.001", name: "Şantiye Binası Yapılması (Prefabrik)", unit: "m²", category: "İnşaat Genel", unitPrice: 3500.00),
        PozItem(code: "01.002", name: "Şantiye Çevre Çiti (Panel)", unit: "m", category: "İnşaat Genel", unitPrice: 850.00),
        PozItem(code: "01.003", name: "İş İskelesi Kurulması", unit: "m²", category: "İnşaat Genel", unitPrice: 180.00),
        PozItem(code: "01.004", name: "İş İskelesi Sökülmesi", unit: "m²", category: "İnşaat Genel", unitPrice: 90.00),
        PozItem(code: "01.005", name: "Geçici Elektrik Tesisatı", unit: "adet", category: "İnşaat Genel", unitPrice: 45000.00),
        PozItem(code: "01.006", name: "Geçici Su Tesisatı", unit: "adet", category: "İnşaat Genel", unitPrice: 25000.00),
        PozItem(code: "01.007", name: "Şantiye Yolu Yapılması (Stabilize)", unit: "m²", category: "İnşaat Genel", unitPrice: 120.00),
        PozItem(code: "01.008", name: "Güvenlik Kulübesi", unit: "adet", category: "İnşaat Genel", unitPrice: 35000.00),
        PozItem(code: "01.009", name: "Şantiye Tabelası", unit: "adet", category: "İnşaat Genel", unitPrice: 8500.00),
        PozItem(code: "01.010", name: "Portatif WC Temini", unit: "adet", category: "İnşaat Genel", unitPrice: 12000.00),

        // 04 — Kazı ve Toprak İşleri
        PozItem(code: "04.001", name: "Makine ile Yumuşak Toprak Kazısı", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 145.00),
        PozItem(code: "04.002", name: "Makine ile Sert Toprak Kazısı", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 195.00),
        PozItem(code: "04.003", name: "Makine ile Kaya Kazısı", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 380.00),
        PozItem(code: "04.004", name: "Elle Yumuşak Toprak Kazısı", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 320.00),
        PozItem(code: "04.005", name: "Elle Sert Toprak Kazısı", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 450.00),
        PozItem(code: "04.006", name: "Temel Kazısı (Makine)", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 165.00),
        PozItem(code: "04.007", name: "Dolgu Yapılması (Kum-Çakıl)", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 210.00),
        PozItem(code: "04.008", name: "Dolgu Yapılması (Toprak)", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 130.00),
        PozItem(code: "04.009", name: "Kazı Malzemesi Nakliyesi (0-1 km)", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 85.00),
        PozItem(code: "04.010", name: "Kazı Malzemesi Nakliyesi (1-5 km)", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 120.00),
        PozItem(code: "04.011", name: "Arazi Tesviyesi", unit: "m²", category: "Kazı ve Toprak İşleri", unitPrice: 35.00),
        PozItem(code: "04.012", name: "Sıkıştırma (Kompaktör ile)", unit: "m³", category: "Kazı ve Toprak İşleri", unitPrice: 45.00),

        // 07 — Beton İşleri
        PozItem(code: "07.001", name: "Grobeton (C8/10)", unit: "m³", category: "Beton İşleri", unitPrice: 1800.00),
        PozItem(code: "07.002", name: "C16/20 Beton (Temel)", unit: "m³", category: "Beton İşleri", unitPrice: 2200.00),
        PozItem(code: "07.003", name: "C20/25 Beton (Döşeme, Kolon)", unit: "m³", category: "Beton İşleri", unitPrice: 2500.00),
        PozItem(code: "07.004", name: "C25/30 Beton (Genel Yapı)", unit: "m³", category: "Beton İşleri", unitPrice: 2800.00),
        PozItem(code: "07.005", name: "C30/37 Beton (Yüksek Dayanım)", unit: "m³", category: "Beton İşleri", unitPrice: 3200.00),
        PozItem(code: "07.006", name: "C35/45 Beton (Özel Yapı)", unit: "m³", category: "Beton İşleri", unitPrice: 3600.00),
        PozItem(code: "07.007", name: "C40/50 Beton (Köprü, Baraj)", unit: "m³", category: "Beton İşleri", unitPrice: 4200.00),
        PozItem(code: "07.008", name: "Pompalı Beton Ek Ücreti", unit: "m³", category: "Beton İşleri", unitPrice: 180.00),
        PozItem(code: "07.009", name: "Beton Vibratör İşçiliği", unit: "m³", category: "Beton İşleri", unitPrice: 65.00),
        PozItem(code: "07.010", name: "Beton Küp Numune Alma", unit: "adet", category: "Beton İşleri", unitPrice: 350.00),
        PozItem(code: "07.011", name: "Beton Kür Malzemesi ve İşçiliği", unit: "m²", category: "Beton İşleri", unitPrice: 45.00),
        PozItem(code: "07.012", name: "Hazır Beton Bariyer", unit: "m", category: "Beton İşleri", unitPrice: 950.00),
        PozItem(code: "07.013", name: "Şap Betonu (5 cm)", unit: "m²", category: "Beton İşleri", unitPrice: 180.00),
        PozItem(code: "07.014", name: "Tesviye Betonu", unit: "m²", category: "Beton İşleri", unitPrice: 120.00),
        PozItem(code: "07.015", name: "Püskürtme Beton (Shotcrete)", unit: "m³", category: "Beton İşleri", unitPrice: 4500.00),

        // 07 — Beton İşleri (ek)
        PozItem(code: "07.016", name: "Çift Donatılı Beton Döşeme", unit: "m²", category: "Beton İşleri", unitPrice: 320.00),
        PozItem(code: "07.017", name: "Hafif Beton (Perlit)", unit: "m³", category: "Beton İşleri", unitPrice: 2000.00),

        // 08 — Kalıp İşleri
        PozItem(code: "08.001", name: "Düz Yüzey Kalıbı (Temel)", unit: "m²", category: "Kalıp İşleri", unitPrice: 280.00),
        PozItem(code: "08.002", name: "Kolon Kalıbı", unit: "m²", category: "Kalıp İşleri", unitPrice: 320.00),
        PozItem(code: "08.003", name: "Kiriş Kalıbı", unit: "m²", category: "Kalıp İşleri", unitPrice: 310.00),
        PozItem(code: "08.004", name: "Perde Kalıbı", unit: "m²", category: "Kalıp İşleri", unitPrice: 340.00),
        PozItem(code: "08.005", name: "Döşeme Kalıbı", unit: "m²", category: "Kalıp İşleri", unitPrice: 260.00),
        PozItem(code: "08.006", name: "Merdiven Kalıbı", unit: "m²", category: "Kalıp İşleri", unitPrice: 420.00),
        PozItem(code: "08.007", name: "Eğri Yüzey Kalıbı", unit: "m²", category: "Kalıp İşleri", unitPrice: 550.00),
        PozItem(code: "08.008", name: "Tünel Kalıp", unit: "m²", category: "Kalıp İşleri", unitPrice: 380.00),
        PozItem(code: "08.009", name: "Kayar Kalıp (Silo, Kule)", unit: "m²", category: "Kalıp İşleri", unitPrice: 650.00),
        PozItem(code: "08.010", name: "Kalıp Söküm İşçiliği", unit: "m²", category: "Kalıp İşleri", unitPrice: 85.00),

        // 10 — Demir İşleri
        PozItem(code: "10.001", name: "Nervürlü Demir Ø8 mm", unit: "ton", category: "Demir İşleri", unitPrice: 32000.00),
        PozItem(code: "10.002", name: "Nervürlü Demir Ø10 mm", unit: "ton", category: "Demir İşleri", unitPrice: 31500.00),
        PozItem(code: "10.003", name: "Nervürlü Demir Ø12 mm", unit: "ton", category: "Demir İşleri", unitPrice: 31000.00),
        PozItem(code: "10.004", name: "Nervürlü Demir Ø14 mm", unit: "ton", category: "Demir İşleri", unitPrice: 30500.00),
        PozItem(code: "10.005", name: "Nervürlü Demir Ø16 mm", unit: "ton", category: "Demir İşleri", unitPrice: 30000.00),
        PozItem(code: "10.006", name: "Nervürlü Demir Ø18 mm", unit: "ton", category: "Demir İşleri", unitPrice: 30000.00),
        PozItem(code: "10.007", name: "Nervürlü Demir Ø20 mm", unit: "ton", category: "Demir İşleri", unitPrice: 29500.00),
        PozItem(code: "10.008", name: "Nervürlü Demir Ø22 mm", unit: "ton", category: "Demir İşleri", unitPrice: 29500.00),
        PozItem(code: "10.009", name: "Nervürlü Demir Ø25 mm", unit: "ton", category: "Demir İşleri", unitPrice: 29000.00),
        PozItem(code: "10.010", name: "Nervürlü Demir Ø32 mm", unit: "ton", category: "Demir İşleri", unitPrice: 29000.00),
        PozItem(code: "10.011", name: "Hasır Çelik Q131", unit: "ton", category: "Demir İşleri", unitPrice: 33000.00),
        PozItem(code: "10.012", name: "Hasır Çelik Q188", unit: "ton", category: "Demir İşleri", unitPrice: 33000.00),
        PozItem(code: "10.013", name: "Hasır Çelik Q221", unit: "ton", category: "Demir İşleri", unitPrice: 33500.00),
        PozItem(code: "10.014", name: "Hasır Çelik Q283", unit: "ton", category: "Demir İşleri", unitPrice: 34000.00),
        PozItem(code: "10.015", name: "Ankraj Demiri", unit: "ton", category: "Demir İşleri", unitPrice: 35000.00),

        // 08 — Kalıp İşleri (ek)
        PozItem(code: "08.011", name: "Köşe ve Kenar Kalıbı", unit: "m", category: "Kalıp İşleri", unitPrice: 95.00),

        // 14 — Duvar İşleri
        PozItem(code: "14.001", name: "19'luk Tuğla Duvar", unit: "m²", category: "Duvar İşleri", unitPrice: 380.00),
        PozItem(code: "14.002", name: "8.5'luk Tuğla Duvar", unit: "m²", category: "Duvar İşleri", unitPrice: 250.00),
        PozItem(code: "14.003", name: "Gazbeton Duvar (10 cm)", unit: "m²", category: "Duvar İşleri", unitPrice: 320.00),
        PozItem(code: "14.004", name: "Gazbeton Duvar (15 cm)", unit: "m²", category: "Duvar İşleri", unitPrice: 380.00),
        PozItem(code: "14.005", name: "Gazbeton Duvar (20 cm)", unit: "m²", category: "Duvar İşleri", unitPrice: 450.00),
        PozItem(code: "14.006", name: "Briket Duvar (20 cm)", unit: "m²", category: "Duvar İşleri", unitPrice: 280.00),
        PozItem(code: "14.007", name: "Bims Blok Duvar (20 cm)", unit: "m²", category: "Duvar İşleri", unitPrice: 300.00),
        PozItem(code: "14.008", name: "Taş Duvar (Kuru)", unit: "m³", category: "Duvar İşleri", unitPrice: 850.00),
        PozItem(code: "14.009", name: "Taş Duvar (Harçlı)", unit: "m³", category: "Duvar İşleri", unitPrice: 1100.00),
        PozItem(code: "14.010", name: "Alçı Panel Bölme Duvar", unit: "m²", category: "Duvar İşleri", unitPrice: 350.00),

        // 14 — Duvar İşleri (ek)
        PozItem(code: "14.011", name: "Çift Tuğla Duvar (Boşluklu)", unit: "m²", category: "Duvar İşleri", unitPrice: 580.00),
        PozItem(code: "14.012", name: "Cam Tuğla Duvar", unit: "m²", category: "Duvar İşleri", unitPrice: 850.00),
        PozItem(code: "14.013", name: "Alçıpan Asma Tavan (Tek Kat)", unit: "m²", category: "Duvar İşleri", unitPrice: 280.00),

        // 15 — Sıva İşleri
        PozItem(code: "15.001", name: "İç Sıva (Çimento Harçlı, 2 cm)", unit: "m²", category: "Sıva İşleri", unitPrice: 220.00),
        PozItem(code: "15.002", name: "İç Sıva (Alçı Sıva, 2 cm)", unit: "m²", category: "Sıva İşleri", unitPrice: 180.00),
        PozItem(code: "15.003", name: "İç Sıva (Makine Sıva)", unit: "m²", category: "Sıva İşleri", unitPrice: 160.00),
        PozItem(code: "15.004", name: "Dış Sıva (Çimento Harçlı)", unit: "m²", category: "Sıva İşleri", unitPrice: 280.00),
        PozItem(code: "15.005", name: "Tavan Sıvası", unit: "m²", category: "Sıva İşleri", unitPrice: 250.00),
        PozItem(code: "15.006", name: "Derz Dolgu (Alçıpan)", unit: "m", category: "Sıva İşleri", unitPrice: 45.00),
        PozItem(code: "15.007", name: "Kaba Sıva (Şap Altı)", unit: "m²", category: "Sıva İşleri", unitPrice: 150.00),
        PozItem(code: "15.008", name: "İnce Sıva (Perdah)", unit: "m²", category: "Sıva İşleri", unitPrice: 120.00),
        PozItem(code: "15.009", name: "Dekoratif Sıva (Dış Cephe)", unit: "m²", category: "Sıva İşleri", unitPrice: 380.00),
        PozItem(code: "15.010", name: "Sıva Filesi Serilmesi", unit: "m²", category: "Sıva İşleri", unitPrice: 55.00),

        // 17 — Döşeme Kaplamaları
        PozItem(code: "17.001", name: "Seramik Yer Döşemesi (Yerli)", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 550.00),
        PozItem(code: "17.002", name: "Seramik Yer Döşemesi (İthal)", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 850.00),
        PozItem(code: "17.003", name: "Granit Döşeme", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 1200.00),
        PozItem(code: "17.004", name: "Mermer Döşeme", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 1500.00),
        PozItem(code: "17.005", name: "Laminat Parke", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 450.00),
        PozItem(code: "17.006", name: "Masif Parke", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 950.00),
        PozItem(code: "17.007", name: "Epoksi Zemin Kaplama", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 380.00),
        PozItem(code: "17.008", name: "PVC Yer Döşemesi", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 280.00),
        PozItem(code: "17.009", name: "Halı Kaplama", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 320.00),
        PozItem(code: "17.010", name: "Doğal Taş Döşeme (Traverten)", unit: "m²", category: "Döşeme Kaplamaları", unitPrice: 1100.00),

        // 18 — Duvar Kaplamaları
        PozItem(code: "18.001", name: "Fayans Duvar Kaplaması", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 480.00),
        PozItem(code: "18.002", name: "Seramik Duvar Kaplaması", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 550.00),
        PozItem(code: "18.003", name: "Mermer Duvar Kaplaması", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 1400.00),
        PozItem(code: "18.004", name: "Ahşap Duvar Kaplaması", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 650.00),
        PozItem(code: "18.005", name: "Alçıpan Duvar Kaplaması", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 280.00),
        PozItem(code: "18.006", name: "Asma Tavan (Alçıpan)", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 350.00),
        PozItem(code: "18.007", name: "Asma Tavan (Metal)", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 420.00),
        PozItem(code: "18.008", name: "Taş Kaplama (Dekoratif)", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 750.00),
        PozItem(code: "18.009", name: "Cam Mozaik", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 950.00),
        PozItem(code: "18.010", name: "Granit Duvar Kaplaması", unit: "m²", category: "Duvar Kaplamaları", unitPrice: 1300.00),

        // 19 — Boya İşleri
        PozItem(code: "19.001", name: "İç Cephe Plastik Boya (2 Kat)", unit: "m²", category: "Boya İşleri", unitPrice: 120.00),
        PozItem(code: "19.002", name: "Dış Cephe Boya (Silikonlu)", unit: "m²", category: "Boya İşleri", unitPrice: 180.00),
        PozItem(code: "19.003", name: "Tavan Boyası", unit: "m²", category: "Boya İşleri", unitPrice: 110.00),
        PozItem(code: "19.004", name: "Macun (İç Yüzey)", unit: "m²", category: "Boya İşleri", unitPrice: 85.00),
        PozItem(code: "19.005", name: "Astar Boya", unit: "m²", category: "Boya İşleri", unitPrice: 55.00),
        PozItem(code: "19.006", name: "Antipas Boya (Metal)", unit: "m²", category: "Boya İşleri", unitPrice: 95.00),
        PozItem(code: "19.007", name: "Vernik (Ahşap)", unit: "m²", category: "Boya İşleri", unitPrice: 130.00),
        PozItem(code: "19.008", name: "Epoksi Boya (Zemin)", unit: "m²", category: "Boya İşleri", unitPrice: 250.00),
        PozItem(code: "19.009", name: "Isı Yalıtım Boyası", unit: "m²", category: "Boya İşleri", unitPrice: 320.00),
        PozItem(code: "19.010", name: "Yağlı Boya (Metal)", unit: "m²", category: "Boya İşleri", unitPrice: 140.00),

        // 21 — Su Yalıtımı
        PozItem(code: "21.001", name: "Bitümlü Membran (3 mm)", unit: "m²", category: "Su Yalıtımı", unitPrice: 180.00),
        PozItem(code: "21.002", name: "Bitümlü Membran (4 mm)", unit: "m²", category: "Su Yalıtımı", unitPrice: 220.00),
        PozItem(code: "21.003", name: "PVC Membran", unit: "m²", category: "Su Yalıtımı", unitPrice: 280.00),
        PozItem(code: "21.004", name: "Likit Membran (Çimento Esaslı)", unit: "m²", category: "Su Yalıtımı", unitPrice: 150.00),
        PozItem(code: "21.005", name: "Likit Membran (Poliüretan)", unit: "m²", category: "Su Yalıtımı", unitPrice: 250.00),
        PozItem(code: "21.006", name: "Su Kesici Bant", unit: "m", category: "Su Yalıtımı", unitPrice: 120.00),
        PozItem(code: "21.007", name: "Kristalize Su Yalıtımı", unit: "m²", category: "Su Yalıtımı", unitPrice: 200.00),
        PozItem(code: "21.008", name: "Asfalt Esaslı Yalıtım", unit: "m²", category: "Su Yalıtımı", unitPrice: 160.00),
        PozItem(code: "21.009", name: "Drenaj Levhası", unit: "m²", category: "Su Yalıtımı", unitPrice: 95.00),
        PozItem(code: "21.010", name: "Koruyucu Keçe", unit: "m²", category: "Su Yalıtımı", unitPrice: 35.00),

        // 22 — Isı Yalıtımı
        PozItem(code: "22.001", name: "EPS Mantolama (3 cm)", unit: "m²", category: "Isı Yalıtımı", unitPrice: 750.00),
        PozItem(code: "22.002", name: "EPS Mantolama (5 cm)", unit: "m²", category: "Isı Yalıtımı", unitPrice: 950.00),
        PozItem(code: "22.003", name: "EPS Mantolama (8 cm)", unit: "m²", category: "Isı Yalıtımı", unitPrice: 1150.00),
        PozItem(code: "22.004", name: "XPS Mantolama (5 cm)", unit: "m²", category: "Isı Yalıtımı", unitPrice: 1100.00),
        PozItem(code: "22.005", name: "Taş Yünü Mantolama (5 cm)", unit: "m²", category: "Isı Yalıtımı", unitPrice: 1200.00),
        PozItem(code: "22.006", name: "Cam Yünü (5 cm)", unit: "m²", category: "Isı Yalıtımı", unitPrice: 180.00),
        PozItem(code: "22.007", name: "XPS Levha (Temel Yalıtım, 5 cm)", unit: "m²", category: "Isı Yalıtımı", unitPrice: 250.00),
        PozItem(code: "22.008", name: "Poliüretan Sprey Yalıtım", unit: "m²", category: "Isı Yalıtımı", unitPrice: 350.00),
        PozItem(code: "22.009", name: "Isı Yalıtım Levhası Yapıştırma", unit: "m²", category: "Isı Yalıtımı", unitPrice: 85.00),
        PozItem(code: "22.010", name: "Isı Yalıtım Dübeli", unit: "adet", category: "Isı Yalıtımı", unitPrice: 8.00),

        // 23 — Çatı İşleri
        PozItem(code: "23.001", name: "Ahşap Çatı İskeleti", unit: "m²", category: "Çatı İşleri", unitPrice: 650.00),
        PozItem(code: "23.002", name: "Çelik Çatı İskeleti", unit: "kg", category: "Çatı İşleri", unitPrice: 45.00),
        PozItem(code: "23.003", name: "Kiremit Çatı Örtüsü", unit: "m²", category: "Çatı İşleri", unitPrice: 350.00),
        PozItem(code: "23.004", name: "Membran Çatı Örtüsü", unit: "m²", category: "Çatı İşleri", unitPrice: 220.00),
        PozItem(code: "23.005", name: "Sandwich Panel Çatı", unit: "m²", category: "Çatı İşleri", unitPrice: 480.00),
        PozItem(code: "23.006", name: "Trapez Sac Çatı", unit: "m²", category: "Çatı İşleri", unitPrice: 280.00),
        PozItem(code: "23.007", name: "Çatı Oluğu (PVC)", unit: "m", category: "Çatı İşleri", unitPrice: 120.00),
        PozItem(code: "23.008", name: "Çatı Oluğu (Galvaniz)", unit: "m", category: "Çatı İşleri", unitPrice: 180.00),
        PozItem(code: "23.009", name: "Yağmur İniş Borusu (PVC)", unit: "m", category: "Çatı İşleri", unitPrice: 95.00),
        PozItem(code: "23.010", name: "Çatı Penceresi", unit: "adet", category: "Çatı İşleri", unitPrice: 8500.00),

        // 25 — Doğrama İşleri
        PozItem(code: "25.001", name: "PVC Pencere (Çift Cam)", unit: "m²", category: "Doğrama İşleri", unitPrice: 8500.00),
        PozItem(code: "25.002", name: "PVC Pencere (Isıcamlı)", unit: "m²", category: "Doğrama İşleri", unitPrice: 10500.00),
        PozItem(code: "25.003", name: "Alüminyum Doğrama (Eloksal)", unit: "m²", category: "Doğrama İşleri", unitPrice: 9500.00),
        PozItem(code: "25.004", name: "Alüminyum Doğrama (Boyalı)", unit: "m²", category: "Doğrama İşleri", unitPrice: 8000.00),
        PozItem(code: "25.005", name: "Çelik Kapı (Daire Giriş)", unit: "adet", category: "Doğrama İşleri", unitPrice: 12000.00),
        PozItem(code: "25.006", name: "İç Kapı (Amerikan Panel)", unit: "adet", category: "Doğrama İşleri", unitPrice: 5500.00),
        PozItem(code: "25.007", name: "İç Kapı (Lake)", unit: "adet", category: "Doğrama İşleri", unitPrice: 8000.00),
        PozItem(code: "25.008", name: "Yangın Kapısı (90 dk)", unit: "adet", category: "Doğrama İşleri", unitPrice: 18000.00),
        PozItem(code: "25.009", name: "Cam Balkon Sistemi", unit: "m²", category: "Doğrama İşleri", unitPrice: 6500.00),
        PozItem(code: "25.010", name: "Otomatik Garaj Kapısı", unit: "adet", category: "Doğrama İşleri", unitPrice: 35000.00),
        PozItem(code: "25.011", name: "Giydirme Cephe (Cam)", unit: "m²", category: "Doğrama İşleri", unitPrice: 12000.00),
        PozItem(code: "25.012", name: "Panjur (Alüminyum)", unit: "m²", category: "Doğrama İşleri", unitPrice: 3500.00),

        // 26 — Asansör
        PozItem(code: "26.001", name: "İnsan Asansörü (6 Kişilik, 5 Durak)", unit: "adet", category: "Asansör", unitPrice: 850000.00),
        PozItem(code: "26.002", name: "İnsan Asansörü (8 Kişilik, 8 Durak)", unit: "adet", category: "Asansör", unitPrice: 1100000.00),
        PozItem(code: "26.003", name: "İnsan Asansörü (10 Kişilik, 10 Durak)", unit: "adet", category: "Asansör", unitPrice: 1400000.00),
        PozItem(code: "26.004", name: "Yük Asansörü (1000 kg)", unit: "adet", category: "Asansör", unitPrice: 950000.00),
        PozItem(code: "26.005", name: "Yük Asansörü (2000 kg)", unit: "adet", category: "Asansör", unitPrice: 1500000.00),
        PozItem(code: "26.006", name: "Engelli Asansörü", unit: "adet", category: "Asansör", unitPrice: 650000.00),
        PozItem(code: "26.007", name: "Şantiye Asansörü (Geçici)", unit: "ay", category: "Asansör", unitPrice: 85000.00),

        // 27 — Mekanik Tesisat
        PozItem(code: "27.001", name: "PPR Temiz Su Borusu (Ø20 mm)", unit: "m", category: "Mekanik Tesisat", unitPrice: 65.00),
        PozItem(code: "27.002", name: "PPR Temiz Su Borusu (Ø32 mm)", unit: "m", category: "Mekanik Tesisat", unitPrice: 85.00),
        PozItem(code: "27.003", name: "PVC Pis Su Borusu (Ø50 mm)", unit: "m", category: "Mekanik Tesisat", unitPrice: 55.00),
        PozItem(code: "27.004", name: "PVC Pis Su Borusu (Ø100 mm)", unit: "m", category: "Mekanik Tesisat", unitPrice: 85.00),
        PozItem(code: "27.005", name: "Doğalgaz Borusu (Çelik, Ø1/2\")", unit: "m", category: "Mekanik Tesisat", unitPrice: 120.00),
        PozItem(code: "27.006", name: "Kalorifer Tesisatı (Panel Radyatör)", unit: "adet", category: "Mekanik Tesisat", unitPrice: 4500.00),
        PozItem(code: "27.007", name: "Yerden Isıtma Sistemi", unit: "m²", category: "Mekanik Tesisat", unitPrice: 350.00),
        PozItem(code: "27.008", name: "Klima Tesisatı (Split)", unit: "adet", category: "Mekanik Tesisat", unitPrice: 18000.00),
        PozItem(code: "27.009", name: "Havalandırma Kanalı (Galvaniz)", unit: "m²", category: "Mekanik Tesisat", unitPrice: 280.00),
        PozItem(code: "27.010", name: "Yangın Söndürme Tesisatı (Sprinkler)", unit: "m²", category: "Mekanik Tesisat", unitPrice: 180.00),
        PozItem(code: "27.011", name: "Kombi (24 kW)", unit: "adet", category: "Mekanik Tesisat", unitPrice: 35000.00),
        PozItem(code: "27.012", name: "Boyler (200 lt)", unit: "adet", category: "Mekanik Tesisat", unitPrice: 25000.00),

        // 27 — Mekanik Tesisat (ek)
        PozItem(code: "27.013", name: "Sıhhi Tesisat Grubu (Banyo)", unit: "adet", category: "Mekanik Tesisat", unitPrice: 22000.00),
        PozItem(code: "27.014", name: "Lavabo + Klozet + Duş Seti", unit: "set", category: "Mekanik Tesisat", unitPrice: 18000.00),
        PozItem(code: "27.015", name: "Mutfak Eviyesi ve Bataryası", unit: "adet", category: "Mekanik Tesisat", unitPrice: 8500.00),

        // 28 — Elektrik Tesisat
        PozItem(code: "28.001", name: "NYM Kablo (3x2.5 mm²)", unit: "m", category: "Elektrik Tesisat", unitPrice: 55.00),
        PozItem(code: "28.002", name: "NYM Kablo (3x1.5 mm²)", unit: "m", category: "Elektrik Tesisat", unitPrice: 38.00),
        PozItem(code: "28.003", name: "Priz (Sıvaaltı)", unit: "adet", category: "Elektrik Tesisat", unitPrice: 120.00),
        PozItem(code: "28.004", name: "Anahtar (Sıvaaltı)", unit: "adet", category: "Elektrik Tesisat", unitPrice: 95.00),
        PozItem(code: "28.005", name: "Aydınlatma Armatürü (LED Panel)", unit: "adet", category: "Elektrik Tesisat", unitPrice: 650.00),
        PozItem(code: "28.006", name: "Aydınlatma Armatürü (Spot)", unit: "adet", category: "Elektrik Tesisat", unitPrice: 280.00),
        PozItem(code: "28.007", name: "Dağıtım Panosu (12 Modül)", unit: "adet", category: "Elektrik Tesisat", unitPrice: 3500.00),
        PozItem(code: "28.008", name: "Ana Dağıtım Panosu", unit: "adet", category: "Elektrik Tesisat", unitPrice: 25000.00),
        PozItem(code: "28.009", name: "Topraklama Tesisatı", unit: "adet", category: "Elektrik Tesisat", unitPrice: 8500.00),
        PozItem(code: "28.010", name: "Jeneratör (100 kVA)", unit: "adet", category: "Elektrik Tesisat", unitPrice: 450000.00),
        PozItem(code: "28.011", name: "Paratoner Tesisatı", unit: "adet", category: "Elektrik Tesisat", unitPrice: 35000.00),
        PozItem(code: "28.012", name: "Kablaj Borusu (PVC, Ø20 mm)", unit: "m", category: "Elektrik Tesisat", unitPrice: 25.00),

        // 30 — Çevre Düzenleme
        PozItem(code: "30.001", name: "Beton Bordür (50x20x10 cm)", unit: "m", category: "Çevre Düzenleme", unitPrice: 120.00),
        PozItem(code: "30.002", name: "Kilitli Parke Taş (6 cm)", unit: "m²", category: "Çevre Düzenleme", unitPrice: 280.00),
        PozItem(code: "30.003", name: "Kilitli Parke Taş (8 cm)", unit: "m²", category: "Çevre Düzenleme", unitPrice: 320.00),
        PozItem(code: "30.004", name: "Bahçe Duvarı (Beton)", unit: "m³", category: "Çevre Düzenleme", unitPrice: 2800.00),
        PozItem(code: "30.005", name: "Çim Serimi (Rulo)", unit: "m²", category: "Çevre Düzenleme", unitPrice: 85.00),
        PozItem(code: "30.006", name: "Ağaç Dikimi", unit: "adet", category: "Çevre Düzenleme", unitPrice: 450.00),
        PozItem(code: "30.007", name: "Çiçek Dikimi", unit: "m²", category: "Çevre Düzenleme", unitPrice: 120.00),
        PozItem(code: "30.008", name: "Otomatik Sulama Sistemi", unit: "m²", category: "Çevre Düzenleme", unitPrice: 65.00),
        PozItem(code: "30.009", name: "Dış Mekan Aydınlatma Direği", unit: "adet", category: "Çevre Düzenleme", unitPrice: 8500.00),
        PozItem(code: "30.010", name: "Çocuk Oyun Alanı", unit: "set", category: "Çevre Düzenleme", unitPrice: 120000.00),

        // 31 — Altyapı
        PozItem(code: "31.001", name: "Kanalizasyon Borusu (PVC, Ø200 mm)", unit: "m", category: "Altyapı", unitPrice: 180.00),
        PozItem(code: "31.002", name: "Kanalizasyon Borusu (PVC, Ø300 mm)", unit: "m", category: "Altyapı", unitPrice: 280.00),
        PozItem(code: "31.003", name: "Beton Rögar (60×60 cm)", unit: "adet", category: "Altyapı", unitPrice: 4500.00),
        PozItem(code: "31.004", name: "Beton Rögar (80×80 cm)", unit: "adet", category: "Altyapı", unitPrice: 6500.00),
        PozItem(code: "31.005", name: "Fosseptik (10 m³)", unit: "adet", category: "Altyapı", unitPrice: 45000.00),
        PozItem(code: "31.006", name: "Yağmursuyu Borusu (PVC, Ø200 mm)", unit: "m", category: "Altyapı", unitPrice: 165.00),
        PozItem(code: "31.007", name: "İçmesuyu Hattı (PE, Ø63 mm)", unit: "m", category: "Altyapı", unitPrice: 120.00),
        PozItem(code: "31.008", name: "İçmesuyu Hattı (PE, Ø110 mm)", unit: "m", category: "Altyapı", unitPrice: 185.00),
        PozItem(code: "31.009", name: "Yangın Hidrantı", unit: "adet", category: "Altyapı", unitPrice: 15000.00),
        PozItem(code: "31.010", name: "Su Deposu (5 ton)", unit: "adet", category: "Altyapı", unitPrice: 25000.00),

        // 32 — Yol Yapım
        PozItem(code: "32.001", name: "Asfalt Kaplama (Aşınma, 5 cm)", unit: "m²", category: "Yol Yapım", unitPrice: 180.00),
        PozItem(code: "32.002", name: "Asfalt Kaplama (Binder, 7 cm)", unit: "m²", category: "Yol Yapım", unitPrice: 220.00),
        PozItem(code: "32.003", name: "Stabilize Yol", unit: "m²", category: "Yol Yapım", unitPrice: 85.00),
        PozItem(code: "32.004", name: "Beton Yol (20 cm)", unit: "m²", category: "Yol Yapım", unitPrice: 350.00),
        PozItem(code: "32.005", name: "Yol Bordürü (Beton)", unit: "m", category: "Yol Yapım", unitPrice: 140.00),
        PozItem(code: "32.006", name: "Tretuar (Kaldırım)", unit: "m²", category: "Yol Yapım", unitPrice: 280.00),
        PozItem(code: "32.007", name: "Yol Çizgisi (Termoplastik)", unit: "m", category: "Yol Yapım", unitPrice: 45.00),
        PozItem(code: "32.008", name: "Asfalt Söküm", unit: "m²", category: "Yol Yapım", unitPrice: 65.00),

        // 33 — Çelik Konstrüksiyon
        PozItem(code: "33.001", name: "Çelik Profil İmalatı (HEA/HEB)", unit: "kg", category: "Çelik Konstrüksiyon", unitPrice: 42.00),
        PozItem(code: "33.002", name: "Çelik Profil Montajı", unit: "kg", category: "Çelik Konstrüksiyon", unitPrice: 18.00),
        PozItem(code: "33.003", name: "Çelik Kaynak İşçiliği", unit: "m", category: "Çelik Konstrüksiyon", unitPrice: 120.00),
        PozItem(code: "33.004", name: "Çelik Boya (Antipas + Son Kat)", unit: "m²", category: "Çelik Konstrüksiyon", unitPrice: 150.00),
        PozItem(code: "33.005", name: "Galvaniz Kaplama", unit: "kg", category: "Çelik Konstrüksiyon", unitPrice: 25.00),
        PozItem(code: "33.006", name: "Çelik Merdiven", unit: "kg", category: "Çelik Konstrüksiyon", unitPrice: 55.00),
        PozItem(code: "33.007", name: "Çelik Korkuluk", unit: "m", category: "Çelik Konstrüksiyon", unitPrice: 850.00),
        PozItem(code: "33.008", name: "Cıvata/Bulon Bağlantısı", unit: "adet", category: "Çelik Konstrüksiyon", unitPrice: 35.00),

        // 34 — İksa ve Palplanş
        PozItem(code: "34.001", name: "Fore Kazık (Ø80 cm)", unit: "m", category: "İksa ve Palplanş", unitPrice: 5500.00),
        PozItem(code: "34.002", name: "Fore Kazık (Ø100 cm)", unit: "m", category: "İksa ve Palplanş", unitPrice: 7500.00),
        PozItem(code: "34.003", name: "Mini Kazık (Ø30 cm)", unit: "m", category: "İksa ve Palplanş", unitPrice: 2500.00),
        PozItem(code: "34.004", name: "Ankraj (Ön Germeli)", unit: "m", category: "İksa ve Palplanş", unitPrice: 1800.00),
        PozItem(code: "34.005", name: "Shotcrete (Çelik Lifli)", unit: "m²", category: "İksa ve Palplanş", unitPrice: 450.00),
        PozItem(code: "34.006", name: "Palplanş (Çelik)", unit: "m²", category: "İksa ve Palplanş", unitPrice: 1200.00),
        PozItem(code: "34.007", name: "Zemin İyileştirme (Jet Grout)", unit: "m", category: "İksa ve Palplanş", unitPrice: 3500.00),
        PozItem(code: "34.008", name: "İksa Kirişi (Çelik)", unit: "kg", category: "İksa ve Palplanş", unitPrice: 48.00),

        // 34 — İksa ve Palplanş (ek)
        PozItem(code: "34.009", name: "Zemin Çivisi (Soil Nail)", unit: "m", category: "İksa ve Palplanş", unitPrice: 850.00),
        PozItem(code: "34.010", name: "Geri Dolgu (İksa Arkası)", unit: "m³", category: "İksa ve Palplanş", unitPrice: 180.00),

        // 35 — Yıkım ve Söküm
        PozItem(code: "35.001", name: "Betonarme Yıkım (Makine)", unit: "m³", category: "Yıkım ve Söküm", unitPrice: 280.00),
        PozItem(code: "35.002", name: "Betonarme Yıkım (Elle)", unit: "m³", category: "Yıkım ve Söküm", unitPrice: 550.00),
        PozItem(code: "35.003", name: "Tuğla/Briket Duvar Söküm", unit: "m²", category: "Yıkım ve Söküm", unitPrice: 85.00),
        PozItem(code: "35.004", name: "Sıva Söküm", unit: "m²", category: "Yıkım ve Söküm", unitPrice: 45.00),
        PozItem(code: "35.005", name: "Döşeme Kaplama Söküm", unit: "m²", category: "Yıkım ve Söküm", unitPrice: 55.00),
        PozItem(code: "35.006", name: "Çatı Söküm", unit: "m²", category: "Yıkım ve Söküm", unitPrice: 120.00),
        PozItem(code: "35.007", name: "Doğrama Söküm", unit: "m²", category: "Yıkım ve Söküm", unitPrice: 65.00),
        PozItem(code: "35.008", name: "Asfalt Söküm", unit: "m²", category: "Yıkım ve Söküm", unitPrice: 55.00),
        PozItem(code: "35.009", name: "Moloz Kaldırma ve Nakliye", unit: "m³", category: "Yıkım ve Söküm", unitPrice: 150.00),
        PozItem(code: "35.010", name: "Yıkım Atığı Bertaraf", unit: "ton", category: "Yıkım ve Söküm", unitPrice: 180.00),
    ]

    static var allCategories: [String] {
        Array(Set(items.map { $0.category })).sorted()
    }
}
