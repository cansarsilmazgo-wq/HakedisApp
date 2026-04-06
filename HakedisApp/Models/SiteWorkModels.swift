import Foundation
import SwiftData
import os

// MARK: - Site Handover (Yer Teslim Tutanağı)

enum HandoverType: String, Codable, CaseIterable {
    case teslimAl       = "Yer Teslim Al"
    case teslimEt       = "Yer Teslim Et"
    case kabulTutanagi  = "Kabul Tutanağı"
}

enum HandoverSignatureStatus: String, Codable, CaseIterable {
    case taslak              = "Taslak"
    case yukleniciImzaladi   = "Yüklenici İmzaladı"
    case idareImzaladi       = "İdare İmzaladı"
    case tamamlandi          = "Tamamlandı"
}

@Model
final class SiteHandoverRecord {
    var id: UUID
    var handoverDate: Date
    var handoverType: HandoverType
    var contractorRepName: String
    var ownerRepName: String
    var location: String
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var existingCondition: String
    var photoData: [Data]
    var signatureStatus: HandoverSignatureStatus
    var notes: String?
    var weatherCondition: String?
    var witnessNamesJSON: String?   // JSON: [String]
    var contract: Contract?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var deficiencies: [SiteDeficiency]

    init(handoverType: HandoverType, handoverDate: Date = Date(),
         contractorRepName: String = "", ownerRepName: String = "",
         location: String = "", existingCondition: String = "") {
        self.id = UUID()
        self.handoverType = handoverType
        self.handoverDate = handoverDate
        self.contractorRepName = contractorRepName
        self.ownerRepName = ownerRepName
        self.location = location
        self.existingCondition = existingCondition
        self.photoData = []
        self.signatureStatus = .taslak
        self.deficiencies = []
        self.createdAt = Date()
    }

    var openDeficiencyCount: Int { deficiencies.filter { !$0.isClosed }.count }
    var hasOpenDeficiencies: Bool { openDeficiencyCount > 0 }
}

@Model
final class SiteDeficiency {
    var id: UUID
    var title: String
    var responsiblePerson: String
    var completionDate: Date
    var isClosed: Bool
    var closedDate: Date?
    var notes: String?
    var photoData: [Data]
    var record: SiteHandoverRecord?
    var createdAt: Date

    init(title: String, responsiblePerson: String = "",
         completionDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date())!) {
        self.id = UUID()
        self.title = title
        self.responsiblePerson = responsiblePerson
        self.completionDate = completionDate
        self.isClosed = false
        self.photoData = []
        self.createdAt = Date()
    }

    var isOverdue: Bool { !isClosed && Date() > completionDate }
    var daysLeft: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: completionDate).day ?? 0)
    }
}

// MARK: - Measurement Book (Metraj Defteri)

enum MeasurementType: String, Codable, CaseIterable {
    case uzunluk = "Uzunluk (m)"
    case alan    = "Alan (m²)"
    case hacim   = "Hacim (m³)"
    case adet    = "Adet"

    var formula: String {
        switch self {
        case .uzunluk: return "L"
        case .alan:    return "L × G"
        case .hacim:   return "L × G × Y"
        case .adet:    return "Adet"
        }
    }

    var usesWidth: Bool  { self == .alan || self == .hacim }
    var usesHeight: Bool { self == .hacim }
}

@Model
final class MeasurementEntry {
    var id: UUID
    var entryNo: String              // MB-2025-001
    var date: Date
    var workItemCode: String
    var location: String
    var measurementType: MeasurementType
    var dimensionsJSON: String?      // JSON: [{id, description, length, width, height}]
    var deductionsJSON: String?      // JSON: [{id, description, quantity}]
    var calculatedQuantity: Double   // brüt (set on save)
    var netQuantity: Double          // brüt - düşülen (set on save)
    var previousEntries: Double      // önceki dönem kümülatif
    var photoData: [Data]
    var checkedBy: String?
    var isVerified: Bool
    var workItem: WorkItem?
    var createdAt: Date

    init(entryNo: String, workItemCode: String, location: String,
         measurementType: MeasurementType, previousEntries: Double = 0) {
        self.id = UUID()
        self.entryNo = entryNo
        self.workItemCode = workItemCode
        self.location = location
        self.measurementType = measurementType
        self.previousEntries = previousEntries
        self.calculatedQuantity = 0
        self.netQuantity = 0
        self.photoData = []
        self.isVerified = false
        self.date = Date()
        self.createdAt = Date()
    }

    var cumulativeTotal: Double { previousEntries + netQuantity }
}

// MARK: - Photo Annotation (Fotoğraf–İmalat Bağlantısı)

@Model
final class PhotoAnnotation {
    var id: UUID
    var photoIndex: Int              // DailyEntry.photoData dizisindeki indeks
    var workItemCode: String
    var workItemName: String
    var measuredQuantity: Double?
    var unit: String
    var locationDescription: String?
    var annotationText: String?
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var capturedAt: Date
    var isIncludedInHakedis: Bool
    var dailyEntry: DailyEntry?
    var createdAt: Date

    init(photoIndex: Int, workItemCode: String, workItemName: String, unit: String = "") {
        self.id = UUID()
        self.photoIndex = photoIndex
        self.workItemCode = workItemCode
        self.workItemName = workItemName
        self.unit = unit
        self.capturedAt = Date()
        self.isIncludedInHakedis = false
        self.createdAt = Date()
    }

    var gpsCoordinate: String? {
        guard let lat = gpsLatitude, let lon = gpsLongitude else { return nil }
        return String(format: "%.6f, %.6f", lat, lon)
    }
}

// MARK: - Labor Tracking (İşçilik Puantaj)

enum WorkerType: String, Codable, CaseIterable {
    case usta      = "Usta"
    case kalfa     = "Kalfa"
    case yardimci  = "Yardımcı"
    case muhendis  = "Mühendis"
    case tekniker  = "Tekniker"

    var icon: String {
        switch self {
        case .usta:     return "hammer.fill"
        case .kalfa:    return "wrench.fill"
        case .yardimci: return "figure.stand"
        case .muhendis: return "chart.line.uptrend.xyaxis"
        case .tekniker: return "gearshape.fill"
        }
    }
}

enum WorkShiftType: String, Codable, CaseIterable {
    case gunduz = "Gündüz"
    case gece   = "Gece"
    case mesai  = "Mesai"
}

struct LaborEntryData: Codable, Identifiable {
    var id: UUID = UUID()
    var workerType: WorkerType
    var count: Int
    var hoursWorked: Double   // varsayılan 8
    var shiftType: WorkShiftType
    var dailyCost: Double?
    var notes: String?

    var manDays: Double { Double(count) * hoursWorked / 8.0 }
}

@Model
final class LaborRecord {
    var id: UUID
    var date: Date
    var laborEntriesJSON: String?    // JSON: [LaborEntryData]
    var weather: String?
    var supervisorName: String?
    var sgkNotified: Bool
    var contract: Contract?
    var createdAt: Date

    init(date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.sgkNotified = false
        self.createdAt = Date()
    }

    var laborEntries: [LaborEntryData] {
        guard let json = laborEntriesJSON, let data = json.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([LaborEntryData].self, from: data)
        } catch {
            Logger(subsystem: "HakedisApp", category: "Models").error("LaborRecord JSON decode: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    var laborEntriesDecodeError: Bool {
        guard let json = laborEntriesJSON, let data = json.data(using: .utf8) else { return false }
        return (try? JSONDecoder().decode([LaborEntryData].self, from: data)) == nil
    }

    var totalWorkers: Int { laborEntries.reduce(0) { $0 + $1.count } }
    var totalManDays: Double { laborEntries.reduce(0) { $0 + $1.manDays } }
    var totalLaborCost: Double { laborEntries.compactMap { $0.dailyCost }.reduce(0, +) }
}

// MARK: - Material Inventory (Malzeme Takip)

enum MaterialCategory: String, Codable, CaseIterable {
    case cimento  = "Çimento"
    case demir    = "Demir"
    case kum      = "Kum"
    case cakil    = "Çakıl"
    case tugla    = "Tuğla"
    case ahsap    = "Ahşap"
    case boya     = "Boya"
    case diger    = "Diğer"

    var icon: String {
        switch self {
        case .cimento:  return "cylinder.fill"
        case .demir:    return "rectangle.fill"
        case .kum:      return "square.fill"
        case .cakil:    return "circle.hexagongrid.fill"
        case .tugla:    return "square.grid.2x2.fill"
        case .ahsap:    return "tree.fill"
        case .boya:     return "paintbrush.fill"
        case .diger:    return "shippingbox.fill"
        }
    }
}

enum MaterialTransactionType: String, Codable, CaseIterable {
    case siparis       = "Sipariş"
    case teslimAlindi  = "Teslim Alındı"
    case kullanildi    = "Kullanıldı"
    case iade          = "İade"
    case zayi          = "Zayi"
}

@Model
final class MaterialRecord {
    var id: UUID
    var materialName: String
    var unit: String
    var category: MaterialCategory
    var supplier: String?
    var minimumStockLevel: Double
    var contract: Contract?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var transactions: [MaterialTransaction]

    init(materialName: String, unit: String, category: MaterialCategory = .diger) {
        self.id = UUID()
        self.materialName = materialName
        self.unit = unit
        self.category = category
        self.minimumStockLevel = 0
        self.transactions = []
        self.createdAt = Date()
    }

    var orderedQty: Double  { transactions.filter { $0.type == .siparis }.reduce(0) { $0 + $1.quantity } }
    var receivedQty: Double { transactions.filter { $0.type == .teslimAlindi }.reduce(0) { $0 + $1.quantity } }
    var usedQty: Double     { transactions.filter { $0.type == .kullanildi }.reduce(0) { $0 + $1.quantity } }
    var wastageQty: Double  { transactions.filter { $0.type == .zayi }.reduce(0) { $0 + $1.quantity } }
    var returnedQty: Double { transactions.filter { $0.type == .iade }.reduce(0) { $0 + $1.quantity } }
    var stockQty: Double    { receivedQty - usedQty - wastageQty - returnedQty }

    var lastUnitPrice: Double? {
        transactions.filter { $0.type == .teslimAlindi && $0.unitPrice != nil }
            .sorted { $0.date > $1.date }.first?.unitPrice
    }

    var stockValue: Double {
        guard let price = lastUnitPrice else { return 0 }
        return stockQty * price
    }

    var isLowStock: Bool { minimumStockLevel > 0 && stockQty <= minimumStockLevel }
    var isStockEmpty: Bool { stockQty <= 0 }
}

@Model
final class MaterialTransaction {
    var id: UUID
    var type: MaterialTransactionType
    var quantity: Double
    var date: Date
    var workItemCode: String?
    var unitPrice: Double?
    var notes: String?
    var invoiceNo: String?
    var deliveryNoteNo: String?
    var photoData: Data?
    var material: MaterialRecord?
    var createdAt: Date

    init(type: MaterialTransactionType, quantity: Double, date: Date = Date()) {
        self.id = UUID()
        self.type = type
        self.quantity = quantity
        self.date = date
        self.createdAt = Date()
    }

    var totalCost: Double? {
        guard let price = unitPrice else { return nil }
        return quantity * price
    }
}

// MARK: - Specification Checklist (Teknik Şartname)

enum SpecCategory: String, Codable, CaseIterable {
    case malzeme  = "Malzeme"
    case iscilik  = "İşçilik"
    case test     = "Test"
    case belgeler = "Belgeler"
    case diger    = "Diğer"

    var icon: String {
        switch self {
        case .malzeme:  return "cube.box.fill"
        case .iscilik:  return "hammer.fill"
        case .test:     return "checkmark.shield.fill"
        case .belgeler: return "doc.fill"
        case .diger:    return "folder.fill"
        }
    }
}

enum SpecStatus: String, Codable, CaseIterable {
    case bekliyor    = "Bekliyor"
    case kontrol     = "Kontrol"
    case uygun       = "Uygun"
    case uygunsuz    = "Uygunsuz"
    case gecersiz    = "Geçerli Değil"

    var color: String {
        switch self {
        case .bekliyor:  return "secondary"
        case .kontrol:   return "warning"
        case .uygun:     return "success"
        case .uygunsuz:  return "danger"
        case .gecersiz:  return "secondary"
        }
    }
}

@Model
final class SpecificationItem {
    var id: UUID
    var sectionNo: String
    var title: String
    var specDescription: String
    var category: SpecCategory
    var isRequired: Bool
    var status: SpecStatus
    var inspectionDate: Date?
    var inspectedBy: String?
    var nonConformanceNote: String?
    var correctiveAction: String?
    var dueDate: Date?
    var evidenceData: [Data]
    var closedAt: Date?
    var templateName: String?
    var contract: Contract?
    var createdAt: Date

    init(sectionNo: String, title: String, category: SpecCategory = .diger, isRequired: Bool = true) {
        self.id = UUID()
        self.sectionNo = sectionNo
        self.title = title
        self.specDescription = ""
        self.category = category
        self.isRequired = isRequired
        self.status = .bekliyor
        self.evidenceData = []
        self.createdAt = Date()
    }

    var isOpen: Bool { status == .uygunsuz && closedAt == nil }
    var isOverdue: Bool {
        guard let due = dueDate, status == .uygunsuz, closedAt == nil else { return false }
        return Date() > due
    }
    var daysUntilDue: Int? {
        guard let due = dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: due).day
    }
}

// MARK: - Retention Release

@Model
final class RetentionRelease {
    var id: UUID
    var amount: Double
    var releaseDate: Date
    var releaseDescription: String
    var contract: Contract?

    init(amount: Double, releaseDate: Date = Date(), releaseDescription: String = "") {
        self.id = UUID()
        self.amount = amount
        self.releaseDate = releaseDate
        self.releaseDescription = releaseDescription
    }
}

// MARK: - Yazışma / Evrak Takibi (CorrespondenceRecord)

enum CorrespondenceDirection: String, Codable, CaseIterable {
    case gelen  = "Gelen"
    case giden  = "Giden"
}

enum CorrespondenceCategory: String, Codable, CaseIterable {
    case teknik   = "Teknik"
    case hukuki   = "Hukuki"
    case idari    = "İdari"
    case mali     = "Mali"
    case diger    = "Diğer"
}

@Model
final class CorrespondenceRecord {
    var id: UUID
    var recordNo: String          // YZ-2026-001
    var subject: String
    var direction: CorrespondenceDirection
    var category: CorrespondenceCategory
    var senderName: String
    var receiverName: String
    var documentDate: Date
    var receivedDate: Date
    var replyDeadline: Date?
    var replyDeadlineDays: Int?   // iş günü cevap süresi (ör: 15)
    var parentRecordNo: String?   // zincir: yanıtladığı yazı no
    var isReplied: Bool
    var repliedAt: Date?
    var summary: String
    var attachmentData: [Data]
    var contract: Contract?
    var createdAt: Date

    init(recordNo: String, subject: String, direction: CorrespondenceDirection,
         category: CorrespondenceCategory = .idari,
         senderName: String = "", receiverName: String = "",
         documentDate: Date = Date()) {
        self.id = UUID()
        self.recordNo = recordNo
        self.subject = subject
        self.direction = direction
        self.category = category
        self.senderName = senderName
        self.receiverName = receiverName
        self.documentDate = documentDate
        self.receivedDate = Date()
        self.isReplied = false
        self.summary = ""
        self.attachmentData = []
        self.createdAt = Date()
    }

    /// Hafta sonu gözetilerek iş günü hesaplı son tarih
    var businessDayDeadline: Date? {
        guard let days = replyDeadlineDays, days > 0 else { return replyDeadline }
        return CorrespondenceRecord.addBusinessDays(days, to: receivedDate)
    }

    /// Cevap süresi doldu mu (iş günü deadline'ı baz alır)
    var isSureDoldu: Bool {
        guard !isReplied else { return false }
        guard let deadline = businessDayDeadline ?? replyDeadline else { return false }
        return Date() > deadline
    }

    var isOverdue: Bool { isSureDoldu }

    var daysLeft: Int? {
        let deadline = businessDayDeadline ?? replyDeadline
        guard let d = deadline, !isReplied else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: d).day
    }

    /// Belirtilen tarihten itibaren N iş günü (Pazartesi–Cuma) sonrasını hesaplar
    static func addBusinessDays(_ days: Int, to date: Date) -> Date {
        let cal = Calendar(identifier: .gregorian)
        var remaining = days
        var current = date
        while remaining > 0 {
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            let weekday = cal.component(.weekday, from: current)
            if weekday != 1 && weekday != 7 { remaining -= 1 }   // 1=Pazar, 7=Cumartesi
        }
        return current
    }
}

// MARK: - Fiyat Farkı (PriceDifferenceRecord)

@Model
final class PriceDifferenceRecord {
    var id: UUID
    var periodName: String
    var baseIndex: Double
    var currentIndex: Double
    var baseAmount: Double
    var coefficient: Double       // katsayı (ör: 0.90)
    var contract: Contract?
    var createdAt: Date
    var laborCoefficient: Double = 0.0
    var materialCoefficient: Double = 0.0
    var otherCoefficient: Double = 0.0

    init(periodName: String, baseIndex: Double, currentIndex: Double,
         baseAmount: Double, coefficient: Double = 1.0) {
        self.id = UUID()
        self.periodName = periodName
        self.baseIndex = baseIndex
        self.currentIndex = currentIndex
        self.baseAmount = baseAmount
        self.coefficient = coefficient
        self.createdAt = Date()
    }

    var indexRatio: Double {
        guard baseIndex > 0 else { return 1.0 }
        return currentIndex / baseIndex
    }

    /// fiyatFarkı = baseAmount × (endeksOranı - 1) × katsayı
    var priceDifference: Double { baseAmount * (indexRatio - 1) * coefficient }

    var isGain: Bool { priceDifference > 0 }

    var dFormulResult: Double {
        guard baseIndex > 0 else { return 0 }
        let ratio = (currentIndex / baseIndex) - 1
        let coeffSum = laborCoefficient + materialCoefficient + otherCoefficient
        return ratio * coeffSum * baseAmount
    }
}

// MARK: - KDV Tevkifatı (VATWithholdingRecord)

enum VATWithholdingRatio: String, Codable, CaseIterable {
    case ikiUcte  = "2/3"
    case yariYari = "1/2"
    case dortOnda = "4/10"

    var ratio: Double {
        switch self {
        case .ikiUcte:  return 2.0 / 3.0
        case .yariYari: return 0.5
        case .dortOnda: return 4.0 / 10.0
        }
    }
}

@Model
final class VATWithholdingRecord {
    var id: UUID
    var withholdingRatio: VATWithholdingRatio
    var totalVATAmount: Double
    var hakedis: Hakedis?
    var createdAt: Date

    init(withholdingRatio: VATWithholdingRatio, totalVATAmount: Double) {
        self.id = UUID()
        self.withholdingRatio = withholdingRatio
        self.totalVATAmount = totalVATAmount
        self.createdAt = Date()
    }

    var contractorPays: Double { totalVATAmount * (1 - withholdingRatio.ratio) }
    var ownerPays: Double { totalVATAmount * withholdingRatio.ratio }
}

// MARK: - SGK Asgari İşçilik (SGKLaborRecord)

@Model
final class SGKLaborRecord {
    var id: UUID
    var periodName: String
    var contractAmount: Double
    var laborIntensityRate: Double   // %
    var minimumLaborAmount: Double
    var declaredLaborAmount: Double
    var areaM2: Double?              // m² (konut/alan bazlı hesap için)
    var asgariIscilikBirimi: Double? // TL/m² birim bedel (ör: 4.0 TL/m²)
    var contract: Contract?
    var createdAt: Date

    init(periodName: String, contractAmount: Double,
         laborIntensityRate: Double, declaredLaborAmount: Double) {
        self.id = UUID()
        self.periodName = periodName
        self.contractAmount = contractAmount
        self.laborIntensityRate = laborIntensityRate
        self.minimumLaborAmount = contractAmount * (laborIntensityRate / 100)
        self.declaredLaborAmount = declaredLaborAmount
        self.createdAt = Date()
    }

    /// Alan × birim bedel bazlı asgari işçilik (alan verisi girilmişse bunu kullanır)
    var effectiveMinimumLaborAmount: Double {
        if let area = areaM2, let unit = asgariIscilikBirimi, area > 0, unit > 0 {
            return area * unit
        }
        return minimumLaborAmount
    }

    var isCompliant: Bool { declaredLaborAmount >= effectiveMinimumLaborAmount }
    var deficiency: Double { max(0, effectiveMinimumLaborAmount - declaredLaborAmount) }
    var penaltyRisk: Bool { !isCompliant }
}

// MARK: - Resmi Şantiye Günlüğü (SiteLogEntry)

@Model
final class SiteLogEntry {
    var id: UUID
    var logDate: Date
    var contractorSignature: String?
    var ownerSignature: String?
    var weatherCondition: SiteWeather
    var isHoliday: Bool
    var isSuspended: Bool
    var suspensionReason: String?
    var nonWorkReason: String?      // tatil/askı açıklaması
    var workSummary: String
    var issues: String?
    var additionalNotes: String?    // sonradan eklenebilen ek not (kayıt kilitliyken)
    var isLocked: Bool              // bir kez imzalandıktan sonra kilitlenir
    var contract: Contract?
    var createdAt: Date

    init(logDate: Date = Date(), weatherCondition: SiteWeather = .sunny,
         isHoliday: Bool = false, isSuspended: Bool = false, workSummary: String = "") {
        self.id = UUID()
        self.logDate = logDate
        self.weatherCondition = weatherCondition
        self.isHoliday = isHoliday
        self.isSuspended = isSuspended
        self.workSummary = workSummary
        self.isLocked = false
        self.createdAt = Date()
    }

    var isSigned: Bool {
        contractorSignature != nil && ownerSignature != nil
    }

    var isWorkday: Bool { !isHoliday && !isSuspended }

    /// İmzalandıktan sonra içerik değiştirilemez; yalnızca additionalNotes eklenebilir
    var canEditContent: Bool { !isLocked }
}

