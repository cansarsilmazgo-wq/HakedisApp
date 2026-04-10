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

### 2. `Contractor.keychainPortalPassword` Getter İçinde Model Mutation — İkincil Risk

**Dosya:** `CoreModels.swift` — `Contractor.keychainPortalPassword.get`

**Risk:** Getter içinde `portalPassword = ""` yazılıyordu. Bu SwiftData gözlem sistemini tetikleyerek
görünüm yeniden render döngüsüne girebilir (render sırasında model değişikliği → yeniden render → ...).

```swift
// YANLIŞ (eski kod):
get {
    ...
    portalPassword = ""  // ← Getter içinde mutation → potansiyel infinite render loop
}
```

---

## Uygulanan Düzeltmeler

### Düzeltme 1: SwiftData İlişki Önbelleğe Alma (Pre-warming)

**Dosya:** `ContractViews.swift` — `ContractDetailView`

SwiftData ilişkileri, `.task` modifier içinde asenkron olarak önbelleğe alındı.
`await Task.yield()` ile her tur arasında ana run-loop'a dönüş yapılıyor — UI
bloklanmadan arka planda kademeli yükleme yapılıyor.

```swift
.task(id: contract.id) {
    guard !relationshipsPrewarmed else { return }
    _ = contract.workItems; _ = contract.hakedisler ...
    await Task.yield()
    // İş kalemi başına dailyEntries yükle
    for item in contract.workItems {
        _ = item.dailyEntries
        await Task.yield()
    }
    relationshipsPrewarmed = true
}
```

**Sonuç:** İlk render hızlı (önbellek yok ama bölüm başına boş veri); arka planda kademeli
yükleme tamamlandıkça görünüm güncellenir. Ana thread bloklanmaz.

### Düzeltme 2: Güvenli `keychainPortalPassword` Getter

**Dosya:** `CoreModels.swift` — `Contractor`

Getter içindeki model mutation kaldırıldı. Geçiş işlemi için ayrı `migratePortalPasswordIfNeeded()`
metodu eklendi ve `ContractorDetailView.task` içinden çağrıldı (render döngüsü dışında).

---

## Test Edilmesi Gerekenler

- [ ] ContractDetailView navigasyonu: donma / gecikme olmadan açılıyor mu?
- [ ] Çok sayıda iş kalemi olan sözleşme (50+) hızlı açılıyor mu?
- [ ] Portal şifresi olan taşeron görüntüleme: sonsuz döngü yok mu?
- [ ] SwiftData verileri kayıpsız görüntüleniyor mu?

---

## Gelecekte Yapılabilecek İyileştirmeler

1. `NavigationLink(destination:)` → `NavigationLink(value:) + .navigationDestination` geçişi
   (destination view'ların eager instantiation'ını önler)
2. `WorkItemRow` için pre-computed progress değerleri (N+1 tamamen ortadan kalkar)
3. SwiftData `@Model` için background ModelActor kullanımı (iOS 17.4+)
