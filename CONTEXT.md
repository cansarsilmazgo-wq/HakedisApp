# HakedisApp — Yeni Sohbet Context Dosyası

> Bu dosyayı yeni bir sohbete at. Claude bu dosyayla projeyi sıfırdan anlar ve kaldığı yerden devam eder.

---

## Ben Kimim / Ne İstiyorum
- iOS geliştirici değilim, Claude ile birlikte bu uygulamayı geliştiriyorum
- Her şeyi terminal ile yapmamı ister (indirme yok, terminal komutu ver)
- Yeni özellik/düzeltme sonrası hangi ekrana bakacağımı tarif et, ben screenshot atayım
- Pratikken (Chrome açık, token var vb.) işlemleri söylemeden yap
- Token oluşturunca push sonrası hemen otomatik sil

---

## Proje
**HakedisApp** — İnşaat sektöründe hakediş yönetim uygulaması

**Repo:** https://github.com/cansarsilmazgo-wq/HakedisApp

**Temel akış:** Şantiyede yapılan iş → Günlük giriş → Metraj → Hakediş → Onay → Ödeme

---

## Ortam
- Mac Mini (alphabisystems kullanıcısı)
- Xcode 26.3
- iOS 17+ target
- Proje yolu: `~/Desktop/HakedisApp/`
- GitHub kullanıcı: `cansarsilmazgo-wq`

---

## Tech Stack
- SwiftUI + SwiftData
- MVVM Architecture
- iOS 17+
- Xcode 26.3

---

## Veri Modeli
```
Project
  └── Contract (retentionRate, advanceRate)
        ├── WorkItem (code, name, unit, unitPrice, contractedQuantity)
        │     └── DailyEntry (date, quantity, location, notes, photoData: [Data])
        └── Hakedis (periodName, periodStart, periodEnd, status: HakedisStatus)
              ├── HakedisItem (workItemCode, workItemName, unit, unitPrice, previousQuantity, currentQuantity)
              └── Payment (amount, paymentDate, paymentDescription)

Contractor
  └── Contract (contractor ile ilişkili)
```

### Önemli İsimler (reserved keyword hatası yaşandı)
- `description` KULLANMA → `projectDescription`, `paymentDescription` kullan
- `foregroundStyle()` KULLANMA → `foregroundColor()` kullan

---

## İş Kuralları
```swift
grossAmount = Σ (currentQuantity × unitPrice)
retentionAmount = grossAmount × (retentionRate / 100)
netAmount = grossAmount - retentionAmount
cumulativeQuantity = previousQuantity + currentQuantity
completionPercentage = min((completedQuantity / contractedQuantity) × 100, 100)
remainingAmount = netAmount - totalPaid
```

## Statü Akışları
```
HakedisStatus: draft → pendingApproval → approved → paid
                                       ↘ rejected → draft
ProjectStatus: active ↔ paused → completed
RevisionType: priceRevision | quantityRevision | extraWork
```

---

## Dosya Yapısı (Tamamı Mevcut)
```
HakedisApp/
├── HakedisApp.swift
├── ContentView.swift              # 7 tab: Ana, Projeler, Taşeronlar, Saha, Galeri, Raporlar, Ayarlar
├── Models/
│   └── Models.swift
└── Views/
    ├── Shared/
    │   ├── DesignSystem.swift
    │   ├── SearchFilterView.swift
    │   ├── NotificationManager.swift
    │   ├── OfflineSyncManager.swift
    │   └── SettingsView.swift
    ├── Projects/
    │   ├── DashboardView.swift    # Ana ekran + arama butonu
    │   ├── ProjectViews.swift
    │   └── ReportsView.swift
    ├── Contracts/
    │   ├── ContractorViews.swift
    │   ├── ContractViews.swift    # HakedisComparisonView buraya bağlı
    │   └── RevisionViews.swift    # Ek iş / poz revize
    ├── Contractor/
    │   └── ContractorPortalView.swift
    ├── DailyEntry/
    │   └── DailyEntryViews.swift
    └── Hakedis/
        ├── HakedisViews.swift
        ├── PDFView.swift          # PDF oluşturma (PDFFileItem: Identifiable kullanıyor)
        └── ComparisonAndGallery.swift  # Dönem karşılaştırma + fotoğraf galerisi
```

---

## Tasarım Sistemi
```swift
// DesignSystem.swift'ten
Color.hakedisOrange    // UIColor(red:0.96, green:0.45, blue:0.13, alpha:1)
Color.hakedisBackground
Color.hakedisCard
Color.hakedisSuccess
Color.hakedisWarning
Color.hakedisDanger

// Hazır bileşenler
StatCard(title:, value:, subtitle:, color:, icon:)
StatusBadge(text:, color:)
ProgressBarView(progress:, color:)
SectionHeader(_ title:, action:)
EmptyStateView(icon:, title:, subtitle:, actionTitle:, action:)

// Formatters (Double extension)
.currencyFormatted   // ₺1.234,56
.percentFormatted    // %68.5
.quantityFormatted   // 45 veya 45.50
.shortFormatted      // 21.03.2025 (Date extension)
```

---

## Tab Bar (7 Sekme)
1. **Ana Ekran** — Dashboard, bekleyen hakedişler, geciken ödemeler, aktif projeler + arama butonu
2. **Projeler** — Proje CRUD → Sözleşme → Poz hiyerarşisi + Hakediş
3. **Taşeronlar** — Firma CRUD, finansal özet
4. **Saha** — Günlük giriş (tarih şeridi, poz seçimi, fotoğraf)
5. **Galeri** — Tüm saha fotoğrafları
6. **Raporlar** — Finansal özet, proje/taşeron bazlı
7. **Ayarlar** — Bildirim, Offline/Sync, Taşeron Portalı, Hakkında

---

## Tamamlanan Özellikler ✅
- Proje / Taşeron / Sözleşme / Poz CRUD
- Günlük saha girişi (fotoğraf dahil)
- Hakediş otomatik hesaplama
- Onay akışı (Taslak → Onay → Ödendi)
- Ödeme takibi (kısmi ödeme)
- Universal arama
- Taşeron portal ekranı (sınırlı erişim + itiraz)
- Sözleşme revize / ek iş
- Dönem karşılaştırma
- Fotoğraf galerisi
- PDF hakediş çıktısı + paylaşma
- Push notification (günlük hatırlatıcı, gecikme uyarısı)
- Network monitoring (offline banner)
- Ayarlar ekranı

---

## Kalan Özellikler (Sonraki Aşama)
- [ ] iCloud Sync (CloudKit)
- [ ] Taşeron şifre koruması
- [ ] Metraj raporu export (Excel)
- [ ] App Store hazırlığı (ikon, splash, metadata)
- [ ] iPad optimizasyonu
- [ ] Widget (Ana ekran özet widget'ı)

---

## Bilinen Hatalar ve Kurallar

### ASLA YAPMA
```swift
// ❌ YANLIŞ
var description: String          // reserved keyword
.foregroundStyle(.hakedisOrange) // ShapeStyle hatası
ForEach(items)                   // id eksik

// ✅ DOĞRU
var paymentDescription: String
.foregroundColor(.hakedisOrange)
ForEach(items, id: \.id)
```

### PDF Sheet Sorunu (Çözüldü)
```swift
// ❌ YANLIŞ - beyaz ekran açılır
@State private var pdfData: Data?
.sheet(isPresented: $showingShare)

// ✅ DOĞRU
struct PDFFileItem: Identifiable { let id = UUID(); let url: URL }
@State private var pdfItem: PDFFileItem?
.sheet(item: $pdfItem) { item in ShareSheet(items: [item.url]) }
```

---

## Xcode Proje Dosyası Durumu
`project.pbxproj` içinde kayıtlı dosyalar:
- A001-A011: Orijinal Swift dosyaları
- B001-B011: Build references
- C001-C008: Yeni eklenen dosyalar
- S001-S008: Yeni build references

Yeni dosya eklenince terminalde python3 ile pbxproj güncelle:
```bash
cd ~/Desktop/HakedisApp && python3 << 'EOF'
import os
proj_path = "HakedisApp.xcodeproj/project.pbxproj"
with open(proj_path, "r") as f:
    content = f.read()
# Yeni dosyayı ekle (C009, S009 gibi sıradaki ID'yi kullan)
new_files = [("C009", "S009", "HakedisApp/Views/YeniDosya.swift", "YeniDosya.swift")]
for fref, bref, path, name in new_files:
    if fref not in content:
        ref = f'\t\t{fref} = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {name}; path = {path}; sourceTree = "<group>"; }};\n'
        build = f'\t\t{bref} = {{isa = PBXBuildFile; fileRef = {fref}; }};\n'
        content = content.replace("/* End PBXFileReference section */", ref + "/* End PBXFileReference section */")
        content = content.replace("/* End PBXBuildFile section */", build + "/* End PBXBuildFile section */")
        content = content.replace("A011,", f"A011,\n\t\t\t\t{fref},")
        content = content.replace("B011,", f"B011,\n\t\t\t\t{bref},")
with open(proj_path, "w") as f:
    f.write(content)
print("✅ Eklendi")
EOF
```

---

## GitHub Push Akışı
1. Chrome'da github.com/settings/tokens/new aç
2. Note: herhangi isim, scope: repo → Generate
3. Token'ı JS ile oku: `document.querySelector('.js-newly-generated-token')?.value`
4. Bash'te push et
5. Push biter bitmez token'ı sil (Delete → confirm)

---

## Geliştirme Kuralları
- Terminal ile yapılabilecek her şeyi terminal ile yap
- Dosya indirme isteme, terminal komutu ver
- Yeni özellik/fix sonrası hangi ekrana gidileceğini tarif et
- Screenshot'ı ben atayım, Claude yorumlar
- Token push sonrası otomatik sil
- Türkçe label/mesaj kullan
- Her ekran kendi dosyasında
- Business logic → Model'e, UI logic → View'e
