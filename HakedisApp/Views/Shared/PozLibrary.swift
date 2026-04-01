import Foundation

struct PozItem: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let unit: String
    let category: PozCategory
}

enum PozCategory: String, CaseIterable {
    case toprak = "Toprak İşleri"
    case beton = "Beton İşleri"
    case demir = "Demir İşleri"
    case duvar = "Duvar İşleri"
    case cati = "Çatı İşleri"
    case zemin = "Zemin Kaplamaları"
    case elektrik = "Elektrik Tesisatı"
    case mekanik = "Mekanik Tesisat"
    case peyzaj = "Peyzaj"
    case diger = "Diğer"
}

struct PozLibrary {
    static let items: [PozItem] = [
        // TOPRAK İŞLERİ
        PozItem(code: "12.001", name: "Kazı (Makine ile)", unit: "m³", category: .toprak),
        PozItem(code: "12.002", name: "Kazı (El ile)", unit: "m³", category: .toprak),
        PozItem(code: "12.003", name: "Dolgu (Sıkıştırmalı)", unit: "m³", category: .toprak),
        PozItem(code: "12.004", name: "Moloz Taşıma", unit: "m³", category: .toprak),
        PozItem(code: "12.005", name: "Temel Zemin Islahı", unit: "m²", category: .toprak),
        PozItem(code: "12.006", name: "Geri Dolgu", unit: "m³", category: .toprak),
        PozItem(code: "12.007", name: "Drenaj Dolgusu (Çakıl)", unit: "m³", category: .toprak),
        PozItem(code: "12.008", name: "Kamyon ile Nakliye", unit: "m³km", category: .toprak),
        PozItem(code: "12.009", name: "Kaya Kazısı", unit: "m³", category: .toprak),
        PozItem(code: "12.010", name: "Derin Kazı (>3m)", unit: "m³", category: .toprak),
        PozItem(code: "12.011", name: "Zemin Stabilizasyonu", unit: "m²", category: .toprak),
        PozItem(code: "12.012", name: "Taban Sıkıştırma", unit: "m²", category: .toprak),
        // BETON İŞLERİ
        PozItem(code: "16.001", name: "Temel Betonu (C25/30)", unit: "m³", category: .beton),
        PozItem(code: "16.002", name: "Kolon Betonu (C30/37)", unit: "m³", category: .beton),
        PozItem(code: "16.003", name: "Kiriş Betonu (C30/37)", unit: "m³", category: .beton),
        PozItem(code: "16.004", name: "Döşeme Betonu (C25/30)", unit: "m³", category: .beton),
        PozItem(code: "16.005", name: "Grobeton (C12/15)", unit: "m³", category: .beton),
        PozItem(code: "16.006", name: "Perde Betonu (C30/37)", unit: "m³", category: .beton),
        PozItem(code: "16.007", name: "Merdiven Betonu", unit: "m³", category: .beton),
        PozItem(code: "16.008", name: "Beton Pompası ile Dökme", unit: "m³", category: .beton),
        PozItem(code: "16.009", name: "Kalıp (Düz Yüzey)", unit: "m²", category: .beton),
        PozItem(code: "16.010", name: "Kalıp (Kolon-Kiriş)", unit: "m²", category: .beton),
        PozItem(code: "16.011", name: "Hazır Beton Nakli", unit: "m³", category: .beton),
        PozItem(code: "16.012", name: "Su Yalıtımlı Beton", unit: "m³", category: .beton),
        PozItem(code: "16.013", name: "Beton Kür İşlemi", unit: "m²", category: .beton),
        PozItem(code: "16.014", name: "Beton Yüzey Perdahı", unit: "m²", category: .beton),
        // DEMİR İŞLERİ
        PozItem(code: "21.001", name: "Nervürlü Çelik Φ8-Φ12", unit: "kg", category: .demir),
        PozItem(code: "21.002", name: "Nervürlü Çelik Φ14-Φ20", unit: "kg", category: .demir),
        PozItem(code: "21.003", name: "Nervürlü Çelik Φ22-Φ32", unit: "kg", category: .demir),
        PozItem(code: "21.004", name: "Hasır Çelik (Q188)", unit: "m²", category: .demir),
        PozItem(code: "21.005", name: "Hasır Çelik (Q257)", unit: "m²", category: .demir),
        PozItem(code: "21.006", name: "Yüksek Mukavemetli Çelik", unit: "kg", category: .demir),
        PozItem(code: "21.007", name: "Çelik Profil (HEA)", unit: "kg", category: .demir),
        PozItem(code: "21.008", name: "Çelik Profil (IPE)", unit: "kg", category: .demir),
        PozItem(code: "21.009", name: "Çelik Levha", unit: "kg", category: .demir),
        PozItem(code: "21.010", name: "Kaynaklı Birleşim", unit: "kg", category: .demir),
        // DUVAR İŞLERİ
        PozItem(code: "23.001", name: "Tuğla Duvar (19cm)", unit: "m²", category: .duvar),
        PozItem(code: "23.002", name: "Tuğla Duvar (8.5cm)", unit: "m²", category: .duvar),
        PozItem(code: "23.003", name: "Gazbeton Duvar (20cm)", unit: "m²", category: .duvar),
        PozItem(code: "23.004", name: "Gazbeton Duvar (10cm)", unit: "m²", category: .duvar),
        PozItem(code: "23.005", name: "Alçı Sıva (İç)", unit: "m²", category: .duvar),
        PozItem(code: "23.006", name: "Çimento Sıva (Dış)", unit: "m²", category: .duvar),
        PozItem(code: "23.007", name: "Taş Duvar", unit: "m³", category: .duvar),
        PozItem(code: "23.008", name: "Alçıpan Bölme (12mm)", unit: "m²", category: .duvar),
        PozItem(code: "23.009", name: "Isı Yalıtım Levhası (EPS)", unit: "m²", category: .duvar),
        PozItem(code: "23.010", name: "Dış Cephe Sıvası", unit: "m²", category: .duvar),
        // ÇATI İŞLERİ
        PozItem(code: "27.001", name: "Kiremit Çatı (Alaturka)", unit: "m²", category: .cati),
        PozItem(code: "27.002", name: "Kiremit Çatı (Marsilya)", unit: "m²", category: .cati),
        PozItem(code: "27.003", name: "Trapez Sac Çatı", unit: "m²", category: .cati),
        PozItem(code: "27.004", name: "Çatı Ahşap Konstrüksiyon", unit: "m²", category: .cati),
        PozItem(code: "27.005", name: "Çatı Su Yalıtımı (Bitümlü)", unit: "m²", category: .cati),
        PozItem(code: "27.006", name: "Çatı Isı Yalıtımı (XPS)", unit: "m²", category: .cati),
        PozItem(code: "27.007", name: "Düz Çatı Terası", unit: "m²", category: .cati),
        PozItem(code: "27.008", name: "Oluk ve İniş Borusu", unit: "m", category: .cati),
        // ZEMİN KAPLAMALARI
        PozItem(code: "26.001", name: "Seramik Kaplama (30x30)", unit: "m²", category: .zemin),
        PozItem(code: "26.002", name: "Seramik Kaplama (60x60)", unit: "m²", category: .zemin),
        PozItem(code: "26.003", name: "Mermer Kaplama", unit: "m²", category: .zemin),
        PozItem(code: "26.004", name: "Granit Kaplama", unit: "m²", category: .zemin),
        PozItem(code: "26.005", name: "Parke (Laminat)", unit: "m²", category: .zemin),
        PozItem(code: "26.006", name: "Parke (Ahşap)", unit: "m²", category: .zemin),
        PozItem(code: "26.007", name: "Beton Zemin Perdahı", unit: "m²", category: .zemin),
        PozItem(code: "26.008", name: "Epoksi Zemin Kaplaması", unit: "m²", category: .zemin),
        PozItem(code: "26.009", name: "Şap Atılması", unit: "m²", category: .zemin),
        PozItem(code: "26.010", name: "Pvc Yer Kaplaması", unit: "m²", category: .zemin),
        // ELEKTRİK TESİSATI
        PozItem(code: "30.001", name: "NYM Kablo 3x2.5mm²", unit: "m", category: .elektrik),
        PozItem(code: "30.002", name: "NYM Kablo 3x4mm²", unit: "m", category: .elektrik),
        PozItem(code: "30.003", name: "NYY Kablo 4x10mm²", unit: "m", category: .elektrik),
        PozItem(code: "30.004", name: "Elektrik Panosu (Sigortalı)", unit: "adet", category: .elektrik),
        PozItem(code: "30.005", name: "Priz (Topraklı)", unit: "adet", category: .elektrik),
        PozItem(code: "30.006", name: "Aydınlatma Armatürü LED", unit: "adet", category: .elektrik),
        PozItem(code: "30.007", name: "Tesisat Borusu (PVC Ø20)", unit: "m", category: .elektrik),
        PozItem(code: "30.008", name: "Topraklama Tesisatı", unit: "m", category: .elektrik),
        PozItem(code: "30.009", name: "Zil + Kapı Telefonu", unit: "adet", category: .elektrik),
        PozItem(code: "30.010", name: "Sigorta Kutusu", unit: "adet", category: .elektrik),
        // MEKANİK TESİSAT
        PozItem(code: "35.001", name: "PPR Boru Ø20 (Su Tesisatı)", unit: "m", category: .mekanik),
        PozItem(code: "35.002", name: "PPR Boru Ø25", unit: "m", category: .mekanik),
        PozItem(code: "35.003", name: "Pik Döküm Boru Ø100 (Pis Su)", unit: "m", category: .mekanik),
        PozItem(code: "35.004", name: "Asansör Tesisatı", unit: "adet", category: .mekanik),
        PozItem(code: "35.005", name: "Kalorifer Kazanı (Doğalgaz)", unit: "adet", category: .mekanik),
        PozItem(code: "35.006", name: "Radyatör (Panel Tip)", unit: "m²", category: .mekanik),
        PozItem(code: "35.007", name: "Klima Tesisatı (Split)", unit: "adet", category: .mekanik),
        PozItem(code: "35.008", name: "Sprinkler Sistemi", unit: "m²", category: .mekanik),
        PozItem(code: "35.009", name: "Havalandırma Kanalı", unit: "m²", category: .mekanik),
        PozItem(code: "35.010", name: "Çelik Baca", unit: "m", category: .mekanik),
        // PEYZAJ
        PozItem(code: "40.001", name: "Çim Ekimi", unit: "m²", category: .peyzaj),
        PozItem(code: "40.002", name: "Ağaç Dikimi (2. Sınıf)", unit: "adet", category: .peyzaj),
        PozItem(code: "40.003", name: "Çalı Dikimi", unit: "adet", category: .peyzaj),
        PozItem(code: "40.004", name: "Sulama Sistemi", unit: "m²", category: .peyzaj),
        PozItem(code: "40.005", name: "Bordür Taşı", unit: "m", category: .peyzaj),
        PozItem(code: "40.006", name: "Parke Kaldırım Taşı", unit: "m²", category: .peyzaj),
        PozItem(code: "40.007", name: "Dekoratif Taş Kaplama", unit: "m²", category: .peyzaj),
        PozItem(code: "40.008", name: "Bitki Toprağı Hazırlama", unit: "m³", category: .peyzaj),
        // DİĞER
        PozItem(code: "50.001", name: "Ahşap Doğrama (Pencere)", unit: "m²", category: .diger),
        PozItem(code: "50.002", name: "PVC Doğrama (Pencere)", unit: "m²", category: .diger),
        PozItem(code: "50.003", name: "Alüminyum Doğrama", unit: "m²", category: .diger),
        PozItem(code: "50.004", name: "Çelik Kapı", unit: "adet", category: .diger),
        PozItem(code: "50.005", name: "Yangın Kapısı", unit: "adet", category: .diger),
        PozItem(code: "50.006", name: "Asma Tavan (Alçıpan)", unit: "m²", category: .diger),
        PozItem(code: "50.007", name: "Boya (İç, 2 Kat)", unit: "m²", category: .diger),
        PozItem(code: "50.008", name: "Dış Cephe Boyası", unit: "m²", category: .diger),
        PozItem(code: "50.009", name: "Su Yalıtımı (Temel)", unit: "m²", category: .diger),
        PozItem(code: "50.010", name: "Çelik Korkuluk", unit: "m", category: .diger),
        PozItem(code: "50.011", name: "Asansör (6 Katlı)", unit: "adet", category: .diger),
        PozItem(code: "50.012", name: "Yapı İskelesi", unit: "m²ay", category: .diger),
    ]
}
