# HakedisApp — Claude Code Context

## Proje Nedir?
İnşaat sektöründe hakediş (progress payment) süreçlerini yönetmek için iOS uygulaması.

**Temel akış:** Şantiyede yapılan iş → Günlük giriş → Metraj → Hakediş → Onay → Ödeme

## Tech Stack
- **Platform:** iOS 17+
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **Architecture:** MVVM
- **Language:** Swift 5.9+

## Klasör Yapısı
```
HakedisApp/
├── HakedisApp.swift          # App entry + modelContainer
├── ContentView.swift          # TabView navigation
├── Models/
│   └── Models.swift           # Tüm SwiftData modelleri
├── Views/
│   ├── Shared/
│   │   └── DesignSystem.swift # Renkler, bileşenler, formatter'lar
│   ├── Projects/
│   │   ├── DashboardView.swift
│   │   ├── ProjectViews.swift
│   │   └── ReportsView.swift
│   ├── Contracts/
│   │   ├── ContractorViews.swift
│   │   └── ContractViews.swift
│   ├── DailyEntry/
│   │   └── DailyEntryViews.swift  ← EN KRİTİK EKRAN
│   └── Hakedis/
│       └── HakedisViews.swift
```

## Veri Modeli
```
Project
  └── Contract (retentionRate, advanceRate)
        ├── WorkItem (code, name, unit, unitPrice, contractedQuantity)
        │     └── DailyEntry (date, quantity, location, notes, photoData)
        └── Hakedis (periodName, periodStart, periodEnd, status)
              ├── HakedisItem (previousQty, currentQty, unitPrice)
              └── Payment (amount, paymentDate)
```

## İş Kuralları
- **Hakediş brüt** = Σ (currentQuantity × unitPrice)
- **Teminat kesintisi** = brüt × retentionRate / 100
- **Net hakediş** = brüt - teminat
- **Kümülatif miktar** = previousQuantity + currentQuantity
- **Tamamlanma %** = completedQuantity / contractedQuantity × 100
- **Kalan ödeme** = netAmount - totalPaid

## Statü Akışları
```
Hakedis: draft → pendingApproval → approved → paid
                                 ↘ rejected → draft
Project: active ↔ paused → completed
```

## Tasarım Sistemi (DesignSystem.swift)
```swift
Color.hakedisOrange    // Ana renk #F5731F
Color.hakedisSuccess   // Yeşil - tamamlandı, ödendi
Color.hakedisWarning   // Sarı - onay bekliyor
Color.hakedisDanger    // Kırmızı - gecikme, aşım, hata
Color.hakedisBackground
Color.hakedisCard
```

Hazır bileşenler: `StatCard`, `StatusBadge`, `ProgressBarView`, `SectionHeader`, `EmptyStateView`

Formatter'lar: `.currencyFormatted`, `.percentFormatted`, `.quantityFormatted`, `.shortFormatted`

## GitHub
Repo: https://github.com/cansarsilmazgo-wq/HakedisApp

## Öncelik Sırası (MVP Sonrası)
1. Offline sync (Core Data + CloudKit veya custom sync)
2. PDF hakediş çıktısı
3. Taşeron portal ekranı (sınırlı erişim)
4. Push notification (onay/ödeme bildirimleri)
5. Arama ve filtreleme

## Geliştirme Kuralları
- Her ekran kendi dosyasında
- Model'e business logic ekle, View'e koyma
- Yeni renk/bileşen ekleme — DesignSystem.swift'i genişlet
- SwiftData cascade delete kurallarını koru
- Türkçe label/mesaj kullan (kullanıcı Türkçe konuşuyor)
