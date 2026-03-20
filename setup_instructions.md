# Xcode'da Kurulum Adımları

## 1. Xcode'u Aç → Yeni Proje

File → New → Project → App

Ayarlar:
- Product Name: HakedisApp
- Bundle Identifier: com.yourname.HakedisApp
- Interface: SwiftUI
- Storage: SwiftData (eğer seçenek yoksa None, biz kendimiz ekledik)
- Language: Swift
- Minimum Deployment: iOS 17.0

## 2. Dosyaları Ekle

Xcode projesini oluşturduktan sonra, varsayılan ContentView.swift ve App dosyasını SİL.

Aşağıdaki dosyaları Xcode projesine sürükle-bırak:

### Models/
- Models.swift

### Views/Shared/
- DesignSystem.swift

### Views/Projects/
- DashboardView.swift
- ProjectViews.swift
- ReportsView.swift

### Views/Contracts/
- ContractorViews.swift
- ContractViews.swift

### Views/DailyEntry/
- DailyEntryViews.swift

### Views/Hakedis/
- HakedisViews.swift

### Root/
- HakedisApp.swift
- ContentView.swift

## 3. Photos Permission

Info.plist'e şu key'i ekle:
- Key: NSPhotoLibraryUsageDescription
- Value: Saha fotoğraflarını eklemek için fotoğraf kütüphanesine erişim gerekiyor.

## 4. Build & Run

Simulator'da iOS 17+ seç ve çalıştır.

