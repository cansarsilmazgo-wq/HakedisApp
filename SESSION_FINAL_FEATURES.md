# HakedisApp — Son Özellikler Oturumu

## Tarih: 8 Nisan 2026

## Uygulanan Özellikler

### Özellik 1 — Malzeme QR Kod Sistemi
- **`SiteEquipmentModels.swift`**: `Material` modeline `qrCodeData: Data?` eklendi
- **`MaterialQRManager.swift`** (yeni): `MaterialQRCodeManager` sınıfı
  - `qrPayload(for:)`: `MATERIAL:<UUID>:<name>` formatında QR payload
  - `materialID(from:)`: QR string'den UUID parse
  - `generateQRCode(for:)`: CIQRCodeGenerator ile UIImage üretimi
  - `generateQRLabel(for:)`: UIGraphicsImageRenderer ile etiket görüntüsü
- **`MaterialQRViews.swift`** (yeni): UI bileşenleri
  - `MaterialQRDisplayView`: QR kodu göster, paylaş, etiket paylaş
  - `MaterialQRScannerView`: QRCameraPreview ile tarama, Giriş/Çıkış seçimi, miktar girişi, StockEntry kaydetme, toast
  - `MaterialQRLabelPDFGenerator`: A4 toplu etiket PDF (4×5 düzeni)
- **`MaterialStockViews.swift`**: MaterialDetailView'a QR butonu, MaterialListView'a "QR Tarama" toolbar butonu
- 4 test: `MaterialQRTests.swift`

### Özellik 2 — Fotoğraf GPS Harita Pini
- **`GeoTaggedPhotoModel.swift`** (yeni Model dosyası):
  - `PhotoLocationService.extractGPSLocation(from:)`: CGImageSource + kCGImagePropertyGPSDictionary ile Exif GPS
  - `PhotoLocationService.makeThumbnail(from:size:)`: Thumbnail üretimi
  - `GeoTaggedPhoto` @Model: id, photoDate, latitude, longitude, caption, sourceModule, sourceId, thumbnailData, project
- **`HakedisApp.swift`**: Schema'ya `GeoTaggedPhoto.self` eklendi
- **`PhotoMapView.swift`** (yeni): MapKit harita
  - Modüle göre renkli pinler: SiteDiary=mavi, SafetyIncident=kırmızı, QualityCheck=turuncu, DailyEntry=yeşil
  - Pin seçiminde detay kartı (thumbnail, modül, tarih, koordinat)
  - Tarih ve modül filtreleri (PhotoMapFilterView)
- **`SiteDiaryViews.swift`**: `save()` sonrası `extractAndSaveGPSPhotos(for:)` çağrısı
- **`MoreTabView.swift`**: "Saha Yönetimi" bölümüne "Fotoğraf Haritası" linki
- 3 test: `PhotoGPSTests.swift`

### Özellik 3 — Taşeron Hakediş PDF
- **`SubcontractorHakedisPDFViews.swift`** (yeni):
  - `SubcontractorHakedisPDFGenerator.generatePDF(hakedis:)`: A4 PDF üretimi
    - Kapak başlığı (turuncu), bilgi tablosu, finansal özet tablosu, notlar, imza alanları (3 sütun), footer
  - `SubHakedisDetailView`: Dönem bilgileri, finansal özet, kâr analizi (canSeeFinancials), PDF paylaş, e-posta butonu
  - `SubHakedisMailComposeView`: MFMailComposeViewController
- **`SubcontractorHakedisViews.swift`**: Liste satırlarına NavigationLink → SubHakedisDetailView
- 3 test: `SubcontractorHakedisPDFTests.swift`

### Özellik 4 — S-Curve Grafiği
- **`SCurveCalculator.swift`** (yeni, saf mantık):
  - `SCurveDataPoint`: Identifiable struct (date, plannedCumulative, actualCumulative)
  - `SCurveDataCalculator.calculateWeeklyData(activities:startDate:endDate:)`: Pro-rata haftalık hesap
- **`SCurveChartView.swift`** (yeni UI):
  - Swift Charts: LineMark planlanan (hakedisInfo, kesik), gerçekleşen (hakedisSuccess, düz)
  - RuleMark bugün (kırmızı)
  - Özet istatistik kutuları (planlanan/gerçekleşen/sapma)
- **`GanttChartViews.swift`**: ActivityListView toolbar'a "S-Eğrisi" butonu (chart.xyaxis.line)
- 3 test: `SCurveTests.swift`

### Özellik 5 — MoreTabView Reorganizasyonu + AboutView
- **`MoreTabView.swift`** yeniden yazıldı — 7 bölüm:
  1. **Proje Yönetimi**: Dokümanlar, Toplantılar, Karar Takibi, İş Programı, Program Karşılaştırma, Çizim Pinleri, Çizim Anotasyonu
  2. **Saha Yönetimi**: İş Emirleri, RFI, Duyurular, Fotoğraf Karşılaştırma, Fotoğraf Haritası, QR Yoklama
  3. **Finansal Yönetim** (canSeeFinancials → gizli): Bütçe, Nakit Akış, Fiyat Takibi, Teminat, Beyannameler
  4. **İhale & Keşif**: Keşif, İhale Hazırlık, Yaklaşık Maliyet, Poz Kütüphanesi, 4734/4735
  5. **Özel Modüller**: Kentsel Dönüşüm, Deprem Risk, Hava Durumu, Proje Haritası, Taşeron Portal, Taşeron İtirazları
  6. **Kabul & Raporlar**: Rapor Oluşturucu, Genel Raporlar, SGK, İlerleme Raporları, Geçici/Kesin Kabul, Eksiklik
  7. **Sistem**: Ayarlar, Kullanıcı Yönetimi (owner only), Yedekleme, iCloud, KVKK, Gizlilik, Veri Silme, Hakkında
- **`AboutView`** eklendi: v1.0, Alphabi Systems, geri bildirim, gizlilik

## Kalite Kontrolleri
- Force unwrap: Yeni dosyalarda hiçbiri yok
- BUILD: SUCCEEDED
- TEST: 653 test, 0 hata
- Rol bazlı erişim korundu (canExportData, canSeeFinancials, canManageUsers)
- DesignSystem renkleri kullanıldı
- Türkçe label/mesaj standartı korundu
- accessibilityLabel tüm yeni butonlarda mevcut

## Yeni Dosyalar (10 adet)
| Dosya | Tür |
|-------|-----|
| MaterialQRManager.swift | Mantık |
| MaterialQRViews.swift | UI |
| GeoTaggedPhotoModel.swift | Model |
| PhotoMapView.swift | UI |
| SubcontractorHakedisPDFViews.swift | UI + PDF |
| SCurveCalculator.swift | Mantık |
| SCurveChartView.swift | UI |
| MaterialQRTests.swift | Test |
| PhotoGPSTests.swift | Test |
| SubcontractorHakedisPDFTests.swift | Test |
| SCurveTests.swift | Test |

## Commit Özeti
```
feat: son özellikler — malzeme QR, GPS fotoğraf haritası, taşeron PDF, S-Curve, MoreTab reorganizasyon
```
