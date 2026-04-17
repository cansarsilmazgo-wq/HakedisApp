# HakedisApp — Crash / Freeze Log

## Tarih: 2026-04-11

---

## Sorun: Sözleşmelere Tıklayınca Uygulama Donuyor

### Belirtiler
- `ProjectDetailView → ContractDetailView` navigasyonunda uygulama donuyor
- Xcode "App Paused" gösteriyor (kullanıcı manuel duraklattığında)
- Crash değil — **main thread bloğu** (freeze / ANR benzeri durum)

---

## Kök Neden Analizi

### 1. SwiftData N+1 Lazy-Loading — Ana Neden

**Nerede:** `ContractDetailView.body` → 13+ alt bölüm → her biri farklı `@Relationship` koleksiyonu erişiyor.

**Mekanizma:**
SwiftData ilişki dizileri (`.workItems`, `.hakedisler`, `.laborRecords`, ...) ilk erişimde
SQLite'tan **senkron, ana thread üzerinde** yüklenir. `ContractDetailView` body'si render
edilirken aşağıdaki 13+ senkron SQLite sorgusu tetiklenir:

| Bölüm | Erişilen İlişki | Derinlik |
|---|---|---|
| `SiteHandoverSection` | `handoverRecords`, `deficiencies` | 2 |
| Finansal Özet | `hakedisler` → her biri için `netAmount` → `effectiveGrossAmount` | 3 |
| `LaborTrackingSection` | `laborRecords` → her biri için `totalManDays` | 2 |
| `MaterialInventorySection` | `materialRecords` → `isLowStock`, `stockValue` | 2 |
| `SpecificationChecklistSection` | `specificationItems` (3 kez) | 1 |
| `CorrespondenceSection` | `correspondenceRecords` → `isSureDoldu` | 2 |
| `PriceDifferenceSection` | `priceDifferenceRecords` → `priceDifference` | 2 |
| `SGKLaborSection` | `sgkLaborRecords` | 1 |
| `SiteLogSection` | `siteLogEntries` | 1 |
| `EquipmentSection` | `equipments` | 1 |
| `SoilRecordSection` | `soilRecords` | 1 |
| `TestRecordSection` | `testRecords` → `blocksApproval` | 2 |
| `AcceptanceSection` | `acceptanceRecords` → `isNearingWarrantyExpiry` | 2 |
| `GuaranteeSection` | `guarantees` → `isReturned` | 2 |

Ek olarak, `WorkItemRow` her iş kalemi için `dailyEntries` yükler:
- 50 iş kalemi × 1 sorgu = 50 ek SQLite sorgusu
- Toplam: **~65+ senkron SQLite sorgusu** tek render pass'te

### 2. `NavigationLink(destination:)` Eager Instantiation — Yeni Bulunan Kök Neden

**Nerede:** `ProjectDetailView.body` → `ForEach(project.contracts)` içinde

**Mekanizma:**
Eski stil `NavigationLink(destination: ContractDetailView(contract: contract))` kullanımı,
`ProjectDetailView` body'si render edildiğinde **TÜM contractlar için ContractDetailView örnekleri
oluşturur**. Her ContractDetailView body'si hesaplanır → yukarıdaki 65+ SQLite sorgusu × kontrat sayısı
kadar tetiklenir.

"Yeni Sözleşme" butonuna tıklandığında `showingAddContract = true` → body yeniden render →
tüm ContractDetailView'lar yeniden oluşturulur → **FREEZE.**

### 3. `Contractor.keychainPortalPassword` Getter İçinde Model Mutation — İkincil Risk

**Dosya:** `CoreModels.swift` — `Contractor.keychainPortalPassword.get`

**Risk:** Getter içinde `portalPassword = ""` yazılıyordu. Bu SwiftData gözlem sistemini tetikleyerek
görünüm yeniden render döngüsüne girebilir.

---

## Uygulanan Düzeltmeler

### Düzeltme 1: SwiftData İlişki Önbelleğe Alma (Pre-warming)

**Dosya:** `ContractViews.swift` — `ContractDetailView`

SwiftData ilişkileri, `.task` modifier içinde asenkron olarak önbelleğe alındı.

### Düzeltme 2: Güvenli `keychainPortalPassword` Getter

**Dosya:** `CoreModels.swift` — `Contractor`

Getter içindeki model mutation kaldırıldı.

### Düzeltme 3: NavigationLink Eager Instantiation — LazyView ile Kalıcı Çözüm ✅

**Dosyalar:** `ProjectViews.swift`, `ContractViews.swift`, `AllHakedisListView.swift`, `ContractorViews.swift`, `SearchFilterView.swift`
**Tarih:** 2026-04-16

**Sorun (tekrar eden):** `NavigationLink(value:)` ile `.navigationDestination(for:)` kombinasyonu,
eski-stil NavigationLink ile push edilen view'lar içinde çalışmıyordu. iOS, push edilmiş view'ın içinde
kayıtlı `.navigationDestination`'ı bulamıyor ve "!" gösteriyordu.

**Çözüm:** `DesignSystem.swift` içine `LazyView<Content>` yardımcı yapısı eklendi.
Her kritik `NavigationLink(destination:)` için `LazyView` wrapper kullandı:

```swift
// Eski (eager body evaluation → freeze):
NavigationLink(destination: ContractDetailView(contract: contract)) { ... }

// Yeni (lazy body evaluation → freeze yok, "!" yok):
NavigationLink(destination: LazyView(ContractDetailView(contract: contract))) { ... }
```

**Sonuç:** 
- ContractDetailView body'si ekrana gelene kadar değerlendirilmez → SwiftData N+1 tetiklenmiyor
- Tüm navigation eski-stil → "!" ünlem sorunu yok
- "Yeni Sözleşme" butonuna tıklandığında freeze yok

---

## Tarih: 2026-04-15 — Kapsamlı Analiz

### Bulunan ve Düzeltilen Ek Buglar

| # | Ekran | Sorun | Öncelik | Durum |
|---|-------|-------|---------|-------|
| 1 | ProjectDetailView → AddContractView | Freeze: NavigationLink eager instantiation | Kritik | ✅ Düzeltildi |
| 2 | SubcontractorPortalView | Veri izolasyonu: tüm taşeronların hakedişleri görünüyor | Kritik | ✅ Düzeltildi |
| 3 | SubcontractorHakedisPortalView | @Query tüm hakedişleri çekiyor, filtre yok | Kritik | ✅ Düzeltildi |
| 4 | HakedisViews — create() | Stopaj ve damga vergisi sözleşmeden aktarılmıyor (sabit %3 ve %0.948) | Yüksek | ✅ Düzeltildi |
| 5 | PozLibraryView | Boş arama sonucunda EmptyState yok | Orta | ✅ Düzeltildi |
| 6 | UserDetailEditView | Taşeron kullanıcısına Contractor bağlama alanı yok | Yüksek | ✅ Düzeltildi |
| 7 | UserAccountModel | linkedContractorId alanı yoktu | Yüksek | ✅ Eklendi |

### Bekleyen Konular

✅ Tüm bekleyen konular 2026-04-15 tarihinde çözüldü (ADIM 1-8):

| # | Konu | Tarih | Durum |
|---|------|-------|-------|
| A1 | linkedContractorId otomatik set — JoinRequest onayında | 2026-04-15 | ✅ Düzeltildi |
| A2 | DashboardView N+1 — @Query ile Contract/Milestone/ChangeOrder | 2026-04-15 | ✅ Düzeltildi |
| A3 | ContractDetailView — WorkItem/Hakedis ForEach lazy NavigationLink | 2026-04-15 | ✅ Düzeltildi |
| A4 | WeatherService API key — Settings ekranına eklendi | 2026-04-15 | ✅ Eklendi |
| A5 | AttendanceListView — Toplu "Herkesi Geldi İşaretle" butonu | 2026-04-15 | ✅ Eklendi |
| A6 | NotificationManager — app açılışında yeniden schedule | 2026-04-15 | ✅ Eklendi |
| A7 | SiteDiaryDetailView — tomorrowPlan görüntüleme + PDF | 2026-04-15 | ✅ Eklendi |
| A8 | AttendanceListView — Aylık puantaj PDF butonu bağlantısı | 2026-04-15 | ✅ Eklendi |

---

## Tarih: 2026-04-16 — Kritik Navigasyon Düzeltmeleri

### Bulunan ve Düzeltilen Buglar

| # | Sorun | Kök Neden | Durum |
|---|-------|-----------|-------|
| 1 | Build 200+ hata | `CoreModels.swift` satır 1: `wimport` yazım hatası | ✅ |
| 2 | Sözleşmelere "!" ünlem, navigate edilemiyor | `NavigationLink(value:)` eski-stil push içinde çalışmıyor | ✅ |
| 3 | Sözleşme açılırken freeze riski (tekrar) | Önceki fix `NavigationLink(value:)` kaldırılmış, eager eval dönmüş | ✅ `LazyView` ile kalıcı çözüm |

**Test Durumu:** 844 test — 0 hata (2026-04-16)
