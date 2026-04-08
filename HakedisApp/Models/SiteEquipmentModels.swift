import Foundation
import SwiftData
import os

// MARK: - Ekipman Kategorisi (FAZ 17.4)

enum EquipmentCategory: String, Codable, CaseIterable {
    case vinc       = "Vinç"
    case forklift   = "Forklift"
    case kazici     = "Kazıcı/Ekskavatör"
    case kamyon     = "Kamyon/Nakliye"
    case beton      = "Beton Mikseri/Pompası"
    case jenerator  = "Jeneratör"
    case kompresor  = "Kompresör"
    case iskele     = "İskele/Platform"
    case diger      = "Diğer"
}

// MARK: - Ekipman Takibi (Equipment + EquipmentUsage)

enum EquipmentStatus: String, Codable, CaseIterable {
    case aktif      = "Aktif"
    case bakim      = "Bakımda"
    case pasif      = "Pasif"
    case arizali    = "Arızalı"
}

@Model
final class Equipment {
    var id: UUID
    var name: String
    var plateOrSerial: String
    var equipmentType: String
    var dailyRentalCost: Double
    var maintenancePeriodDays: Int    // Kaç günde bir bakım
    var lastMaintenanceDate: Date?
    var status: EquipmentStatus
    var contract: Contract?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var usageRecords: [EquipmentUsage]

    var muayenePeriodDays: Int     // muayene periyodu gün (ör: 365)
    var lastInspectionDate: Date?  // son muayene tarihi
    var malfunctionNotes: String?  // arıza kayıtları (gecikme gerekçesi için)
    // FAZ 17.4 — Ekipman Eksikleri
    var brand: String = ""
    var modelName: String = ""
    var yearManufactured: Int = 0
    var hourlyRentalCost: Double = 0.0
    var insuranceExpiryDate: Date?
    var assignedOperatorName: String = ""
    var equipmentCategoryRaw: String = "Diğer"

    init(name: String, plateOrSerial: String = "", equipmentType: String = "",
         dailyRentalCost: Double = 0, maintenancePeriodDays: Int = 90,
         muayenePeriodDays: Int = 365) {
        self.id = UUID()
        self.name = name
        self.plateOrSerial = plateOrSerial
        self.equipmentType = equipmentType
        self.dailyRentalCost = dailyRentalCost
        self.maintenancePeriodDays = maintenancePeriodDays
        self.muayenePeriodDays = muayenePeriodDays
        self.status = .aktif
        self.usageRecords = []
        self.createdAt = Date()
    }

    var totalUsageDays: Int { usageRecords.reduce(0) { $0 + $1.durationDays } }
    var totalRentalCost: Double { Double(totalUsageDays) * dailyRentalCost }

    var equipmentCategory: EquipmentCategory {
        get { EquipmentCategory(rawValue: equipmentCategoryRaw) ?? .diger }
        set { equipmentCategoryRaw = newValue.rawValue }
    }

    var isInsuranceExpiringSoon: Bool {
        guard let expiry = insuranceExpiryDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return days <= 30
    }

    var isMaintenanceDue: Bool {
        guard maintenancePeriodDays > 0, let last = lastMaintenanceDate else { return true }
        let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return daysSince >= maintenancePeriodDays
    }

    var isMuayeneDue: Bool {
        guard muayenePeriodDays > 0 else { return false }
        guard let last = lastInspectionDate else { return true }
        let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return daysSince >= muayenePeriodDays
    }
}

@Model
final class EquipmentUsage {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var operatorName: String
    var notes: String
    var equipment: Equipment?
    var createdAt: Date

    init(startDate: Date = Date(), operatorName: String = "") {
        self.id = UUID()
        self.startDate = startDate
        self.operatorName = operatorName
        self.notes = ""
        self.createdAt = Date()
    }

    var durationDays: Int {
        let end = endDate ?? Date()
        return max(1, Calendar.current.dateComponents([.day], from: startDate, to: end).day ?? 1)
    }
}

// MARK: - Zemin / Kazı Tutanağı (SoilRecord)

struct SoilLabTest: Codable {
    var testName: String
    var result: String
    var isCompliant: Bool
}

@Model
final class SoilRecord {
    var id: UUID
    var recordDate: Date
    var location: String
    var depth: Double            // metre
    var area: Double             // m²
    var soilType: String
    var labTestsJSON: String?    // JSON: [SoilLabTest]
    var notes: String
    var contract: Contract?
    var createdAt: Date

    var engineerSignature: String?  // zemin mühendisi imzası
    var photoData: [Data]           // kazı fotoğrafları

    init(recordDate: Date = Date(), location: String = "",
         depth: Double = 0, area: Double = 0, soilType: String = "") {
        self.id = UUID()
        self.recordDate = recordDate
        self.location = location
        self.depth = depth
        self.area = area
        self.soilType = soilType
        self.notes = ""
        self.photoData = []
        self.createdAt = Date()
    }

    var calculatedVolume: Double { depth * area }

    var isSignedByEngineer: Bool {
        guard let sig = engineerSignature else { return false }
        return !sig.isEmpty
    }

    /// İmza + fotoğraf varsa hakediş kayıtlarına bağlanabilir
    var canBeIncludedInHakedis: Bool { isSignedByEngineer && !photoData.isEmpty }

    var labTests: [SoilLabTest] {
        guard let json = labTestsJSON, let data = json.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([SoilLabTest].self, from: data)
        } catch {
            Logger(subsystem: "HakedisApp", category: "Models").error("SoilRecord JSON decode: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    var labTestsDecodeError: Bool {
        guard let json = labTestsJSON, let data = json.data(using: .utf8) else { return false }
        return (try? JSONDecoder().decode([SoilLabTest].self, from: data)) == nil
    }
}

// MARK: - Test / Deney Sonuçları (TestRecord)

enum TestCategory: String, Codable, CaseIterable {
    case beton       = "Beton"
    case zemin       = "Zemin"
    case malzeme     = "Malzeme"
    case yanginlar   = "Yangın"
    case elektrik    = "Elektrik"
    case diger       = "Diğer"
}

enum TestStatus: String, Codable, CaseIterable {
    case bekliyor    = "Sonuç Bekleniyor"
    case gecti       = "Geçti"
    case kaldi       = "Kaldı"
}

@Model
final class TestRecord {
    var id: UUID
    var testDate: Date
    var category: TestCategory
    var testName: String
    var location: String
    var sampleNo: String
    var laboratoryName: String
    var minimumAcceptable: Double?
    var maximumAcceptable: Double?
    var result: Double?
    var unit: String
    var status: TestStatus
    var reportData: Data?
    var contract: Contract?
    var createdAt: Date

    var isRequiredForApproval: Bool  // true ise başarısız olduğunda hakediş onaylanamaz
    var testFrequencyM3: Double?     // m³ başına test sıklığı (ör: 50 m³/test)
    var concreteVolumeM3: Double?    // dökülen beton hacmi
    var followupTestDate: Date?      // 7 gün → 28 gün takip testi tarihi

    init(testName: String, category: TestCategory = .beton,
         location: String = "", sampleNo: String = "", laboratoryName: String = "",
         unit: String = "", isRequiredForApproval: Bool = false) {
        self.id = UUID()
        self.testDate = Date()
        self.category = category
        self.testName = testName
        self.location = location
        self.sampleNo = sampleNo
        self.laboratoryName = laboratoryName
        self.unit = unit
        self.isRequiredForApproval = isRequiredForApproval
        self.status = .bekliyor
        self.createdAt = Date()
    }

    var isInRange: Bool {
        guard let r = result else { return false }
        let minOK = minimumAcceptable.map { r >= $0 } ?? true
        let maxOK = maximumAcceptable.map { r <= $0 } ?? true
        return minOK && maxOK
    }

    /// Hakediş onayını bloke eden başarısız test mi?
    var blocksApproval: Bool { isRequiredForApproval && status == .kaldi }

    /// Frekansa göre gereken minimum test sayısı
    /// Her tam freq m³ doldukça 1 test: 75m³/50m³ = 1, 100m³/50m³ = 2, 150m³/50m³ = 3
    var requiredTestCount: Int {
        guard let freq = testFrequencyM3, let vol = concreteVolumeM3, freq > 0, vol > 0 else { return 1 }
        return max(1, Int(vol / freq))
    }
}

// MARK: - Geçici / Kesin Kabul (AcceptanceRecord)

enum AcceptanceType: String, Codable, CaseIterable {
    case gecici = "Geçici Kabul"
    case kesin  = "Kesin Kabul"
}

@Model
final class AcceptanceRecord {
    var id: UUID
    var acceptanceType: AcceptanceType
    var acceptanceDate: Date
    var warrantyMonths: Int
    var notes: String
    var prerequisitesJSON: String?          // JSON [String]: önşart listesi
    var completedPrerequisitesJSON: String? // JSON [String]: tamamlananlar
    var contractAmount: Double              // sözleşme bedeli
    var actualAmount: Double               // gerçekleşen bedel
    var extendedWarrantyUntil: Date?       // açık kusur varsa uzatılmış garanti sonu
    var contract: Contract?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var warrantyClaims: [WarrantyClaim]

    init(acceptanceType: AcceptanceType, acceptanceDate: Date = Date(),
         warrantyMonths: Int = 24, contractAmount: Double = 0, actualAmount: Double = 0) {
        self.id = UUID()
        self.acceptanceType = acceptanceType
        self.acceptanceDate = acceptanceDate
        self.warrantyMonths = warrantyMonths
        self.contractAmount = contractAmount
        self.actualAmount = actualAmount
        self.notes = ""
        self.warrantyClaims = []
        self.createdAt = Date()
    }

    var warrantyEndDate: Date? {
        Calendar.current.date(byAdding: .month, value: warrantyMonths, to: acceptanceDate)
    }

    /// Uzatma varsa onu, yoksa normal bitiş tarihi
    var effectiveWarrantyEnd: Date? { extendedWarrantyUntil ?? warrantyEndDate }

    var isWarrantyActive: Bool {
        guard let end = effectiveWarrantyEnd else { return false }
        return Date() <= end
    }

    var warrantyDaysLeft: Int {
        guard let end = effectiveWarrantyEnd else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0)
    }

    /// 60 gün veya daha az kaldığında uyarı tetiklenir
    var isNearingWarrantyExpiry: Bool { isWarrantyActive && warrantyDaysLeft <= 60 }

    /// Sözleşme – gerçekleşen = iş eksilişi (pozitif = eksilti)
    var deductionAmount: Double { contractAmount - actualAmount }

    var prerequisites: [String] {
        guard let json = prerequisitesJSON, let data = json.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            Logger(subsystem: "HakedisApp", category: "Models").error("AcceptanceRecord prerequisites JSON decode: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    var prerequisitesDecodeError: Bool {
        guard let json = prerequisitesJSON, let data = json.data(using: .utf8) else { return false }
        return (try? JSONDecoder().decode([String].self, from: data)) == nil
    }

    var completedPrerequisites: [String] {
        guard let json = completedPrerequisitesJSON, let data = json.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            Logger(subsystem: "HakedisApp", category: "Models").error("AcceptanceRecord completedPrerequisites JSON decode: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    var completedPrerequisitesDecodeError: Bool {
        guard let json = completedPrerequisitesJSON, let data = json.data(using: .utf8) else { return false }
        return (try? JSONDecoder().decode([String].self, from: data)) == nil
    }

    var allPrerequisitesMet: Bool {
        let req = prerequisites
        guard !req.isEmpty else { return true }
        return completedPrerequisites.count >= req.count
    }

    var canApply: Bool { allPrerequisitesMet }

    var openClaimsExist: Bool { warrantyClaims.contains { $0.isOpen } }
}

// MARK: - Garanti Süresi Takibi (WarrantyClaim)

enum ClaimCategory: String, Codable, CaseIterable {
    case yapisal  = "Yapısal"
    case mekanik  = "Mekanik"
    case elektrik = "Elektrik"
    case boya     = "Boya/Kaplama"
    case diger    = "Diğer"
}

enum ClaimSeverity: String, Codable, CaseIterable {
    case kritik  = "Kritik"
    case yuksek  = "Yüksek"
    case orta    = "Orta"
    case dusuk   = "Düşük"
}

enum ClaimStatus: String, Codable, CaseIterable {
    case acik       = "Açık"
    case islemde    = "İşlemde"
    case kapatildi  = "Kapatıldı"
}

@Model
final class WarrantyClaim {
    var id: UUID
    var claimDate: Date
    var category: ClaimCategory
    var severity: ClaimSeverity
    var claimDescription: String
    var location: String
    var responseDeadline: Date?
    var status: ClaimStatus
    var closedAt: Date?
    var closureNote: String?
    var acceptanceRecord: AcceptanceRecord?
    var createdAt: Date

    init(claimDescription: String, category: ClaimCategory = .diger,
         severity: ClaimSeverity = .orta, location: String = "",
         claimDate: Date = Date()) {
        self.id = UUID()
        self.claimDate = claimDate
        self.category = category
        self.severity = severity
        self.claimDescription = claimDescription
        self.location = location
        self.status = .acik
        self.createdAt = Date()
    }

    var isOpen: Bool { status != .kapatildi }

    var isOverdue: Bool {
        guard let deadline = responseDeadline, isOpen else { return false }
        return Date() > deadline
    }
}

// MARK: - Şantiye Günlüğü (SiteDiary)

enum ShiftType: String, Codable, CaseIterable {
    case dayShift   = "Gündüz"
    case nightShift = "Gece"
    var icon: String { self == .dayShift ? "sun.max" : "moon.stars" }
}

enum DelayReason: String, Codable, CaseIterable {
    case rain             = "Yağmur"
    case materialShortage = "Malzeme Yetersiz"
    case laborShortage    = "İşçi Yetersiz"
    case adminWaiting     = "İdare Talimatı Bekleniyor"
    case equipmentFailure = "Ekipman Arızası"
    case other            = "Diğer"
    var icon: String {
        switch self {
        case .rain:             return "cloud.rain"
        case .materialShortage: return "shippingbox"
        case .laborShortage:    return "person.slash"
        case .adminWaiting:     return "clock.badge.questionmark"
        case .equipmentFailure: return "wrench.slash"
        case .other:            return "ellipsis.circle"
        }
    }
}

enum WeatherCondition: String, Codable, CaseIterable {
    case sunny        = "Güneşli"
    case partlyCloudy = "Parçalı Bulutlu"
    case cloudy       = "Bulutlu"
    case rainy        = "Yağmurlu"
    case heavyRain    = "Şiddetli Yağmur"
    case snowy        = "Karlı"
    case stormy       = "Fırtınalı"
    case foggy        = "Sisli"
    case windy        = "Rüzgarlı"

    var icon: String {
        switch self {
        case .sunny:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .rainy:        return "cloud.rain.fill"
        case .heavyRain:    return "cloud.heavyrain.fill"
        case .snowy:        return "cloud.snow.fill"
        case .stormy:       return "cloud.bolt.fill"
        case .foggy:        return "cloud.fog.fill"
        case .windy:        return "wind"
        }
    }

    var workSuitability: String {
        switch self {
        case .sunny, .partlyCloudy, .cloudy:
            return "Çalışmaya Uygun"
        case .rainy, .windy, .foggy:
            return "Dikkatli Çalışılabilir"
        case .heavyRain, .snowy, .stormy:
            return "Çalışma Önerilmez"
        }
    }

    var isWorkSuitable: Bool {
        switch self {
        case .sunny, .partlyCloudy, .cloudy: return true
        case .rainy, .windy, .foggy: return true
        case .heavyRain, .snowy, .stormy: return false
        }
    }
}

@Model
final class SiteDiary {
    var id: UUID
    var date: Date
    var weatherCondition: WeatherCondition
    var temperature: Double?
    var workDescription: String
    var problems: String?
    var visitors: String?
    var notes: String?
    var photoData: [Data]
    var project: Project?
    var createdAt: Date
    // Faz 6 — yeni alanlar
    var shiftTypeRaw: String
    var delayReasonRaw: String?
    var delayHours: Double?
    var signedByChief: String?
    var signedByController: String?
    var windSpeed: String?
    var humidity: Double?
    // FAZ 17.1 — Şantiye Günlüğü Eksikleri
    var tomorrowPlan: String = ""
    var securityNote: String = ""
    var visitorLog: String = ""   // Ziyaretçi kaydı (ayrı alan)

    init(date: Date = Date(), weatherCondition: WeatherCondition = .sunny, workDescription: String = "") {
        self.id = UUID()
        self.date = date
        self.weatherCondition = weatherCondition
        self.workDescription = workDescription
        self.photoData = []
        self.createdAt = Date()
        self.shiftTypeRaw = ShiftType.dayShift.rawValue
    }

    var shiftType: ShiftType {
        get { ShiftType(rawValue: shiftTypeRaw) ?? .dayShift }
        set { shiftTypeRaw = newValue.rawValue }
    }
    var delayReason: DelayReason? {
        get { delayReasonRaw.flatMap { DelayReason(rawValue: $0) } }
        set { delayReasonRaw = newValue?.rawValue }
    }
    var hasDelay: Bool { delayHours != nil && (delayHours ?? 0) > 0 }
}

// MARK: - Puantaj (Attendance)

enum OvertimeType: String, Codable, CaseIterable {
    case normal  = "Normal Fazla Mesai %50"
    case weekend = "Hafta Sonu %100"
    case holiday = "Resmi Tatil %100"
    var multiplier: Double {
        switch self { case .normal: return 1.5; case .weekend, .holiday: return 2.0 }
    }
}

enum PuantajApproval: String, Codable, CaseIterable {
    case draft     = "Taslak"
    case submitted = "Gönderildi"
    case approved  = "Onaylandı"
    var color: String {
        switch self { case .draft: return "secondary"; case .submitted: return "hakedisWarning"; case .approved: return "hakedisSuccess" }
    }
}

@Model
final class Attendance {
    var id: UUID
    var date: Date
    var workerName: String
    var workerRole: String?
    @Relationship var worker: Worker?
    @Relationship var contractor: Contractor?
    @Relationship var project: Project?
    var isPresent: Bool
    var normalHours: Double
    var overtimeHours: Double
    var overtimeTypeRaw: String?
    var approvalStatusRaw: String
    var notes: String?
    var createdAt: Date

    init(date: Date = Date(), workerName: String, workerRole: String? = nil) {
        self.id = UUID()
        self.date = date
        self.workerName = workerName
        self.workerRole = workerRole
        self.isPresent = true
        self.normalHours = 8.0
        self.overtimeHours = 0.0
        self.approvalStatusRaw = PuantajApproval.draft.rawValue
        self.createdAt = Date()
    }

    var totalHours: Double { normalHours + overtimeHours }
    var isSGKDay: Bool { isPresent && totalHours >= 4 }
    var overtimeType: OvertimeType? {
        get { overtimeTypeRaw.flatMap { OvertimeType(rawValue: $0) } }
        set { overtimeTypeRaw = newValue?.rawValue }
    }
    var approvalStatus: PuantajApproval {
        get { PuantajApproval(rawValue: approvalStatusRaw) ?? .draft }
        set { approvalStatusRaw = newValue.rawValue }
    }
    var effectiveName: String { worker?.fullName ?? workerName }

    // 4857 Md.41 maliyet hesabı
    var hourlyCost: Double { worker?.hourlyCost ?? 0 }
    var normalCost: Double { normalHours * hourlyCost }
    var overtimeCost: Double {
        guard let ot = overtimeType else { return overtimeHours * hourlyCost }
        return overtimeHours * hourlyCost * ot.multiplier
    }
    var totalDailyCost: Double { normalCost + overtimeCost }
}

// MARK: - Malzeme / Stok Takibi

enum StockEntryType: String, Codable, CaseIterable {
    case incoming = "Giriş"
    case outgoing = "Çıkış"
}

enum QualityStatus: String, Codable, CaseIterable {
    case pending  = "Bekliyor"
    case approved = "Onaylı"
    case rejected = "Reddedildi"
    var icon: String {
        switch self {
        case .pending:  return "clock"
        case .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        }
    }
}

enum OrderStatus: String, Codable, CaseIterable {
    case created      = "Oluşturuldu"
    case approved     = "Onaylandı"
    case shipped      = "Sevk Edildi"
    case delivered    = "Teslim Alındı"
    case qualityCheck = "Kalite Kontrol"
    case completed    = "Tamamlandı"
    case cancelled    = "İptal"
    var icon: String {
        switch self {
        case .created:      return "doc.badge.plus"
        case .approved:     return "checkmark.seal"
        case .shipped:      return "shippingbox"
        case .delivered:    return "truck.box.fill"
        case .qualityCheck: return "magnifyingglass"
        case .completed:    return "checkmark.circle.fill"
        case .cancelled:    return "xmark.circle"
        }
    }
}

enum MaterialTestType: String, Codable, CaseIterable {
    case concreteCube   = "Beton Küp Kırım"
    case steelTensile   = "Demir Çekme Testi"
    case aggregateSieve = "Agrega Elek Analizi"
    case waterproofTest = "Su Yalıtım Testi"
    case soilTest       = "Zemin Testi"
    case other          = "Diğer"
}

enum RequestStatus: String, Codable, CaseIterable {
    case draft     = "Taslak"
    case submitted = "Gönderildi"
    case approved  = "Onaylandı"
    case rejected  = "Reddedildi"
    case ordered   = "Sipariş Verildi"
}

enum RequestUrgency: String, Codable, CaseIterable {
    case normal   = "Normal"
    case urgent   = "Acil"
    case critical = "Kritik"
    var colorName: String {
        switch self {
        case .normal:   return "hakedisSuccess"
        case .urgent:   return "hakedisWarning"
        case .critical: return "hakedisDanger"
        }
    }
}

@Model
final class Supplier {
    var id: UUID
    var companyName: String
    var contactPerson: String?
    var phone: String?
    var email: String?
    var address: String?
    var taxNumber: String?
    var iban: String?
    var rating: Int?
    var notes: String?
    var createdAt: Date
    @Relationship(deleteRule: .nullify) var stockEntries: [StockEntry]
    @Relationship(deleteRule: .cascade) var orders: [MaterialOrder]

    init(companyName: String) {
        self.id = UUID()
        self.companyName = companyName
        self.stockEntries = []
        self.orders = []
        self.createdAt = Date()
    }

    var averageDeliveryScore: Double {
        let delivered = orders.filter { $0.status == .delivered || $0.status == .completed }
        guard !delivered.isEmpty else { return Double(rating ?? 0) }
        let onTime = delivered.filter { order in
            guard let actual = order.actualDeliveryDate, let expected = order.expectedDeliveryDate else { return true }
            return actual <= expected
        }
        return Double(onTime.count) / Double(delivered.count) * 5.0
    }
}

@Model
final class MaterialOrder {
    var id: UUID
    var orderNo: String
    var orderDate: Date
    var expectedDeliveryDate: Date?
    var actualDeliveryDate: Date?
    var statusRaw: String
    var totalAmount: Double
    var notes: String?
    var orderedQuantity: Double
    var deliveredQuantity: Double?
    var unitPrice: Double
    var createdAt: Date
    @Relationship var supplier: Supplier?
    @Relationship var material: Material?
    @Relationship var project: Project?

    init(orderNo: String, orderDate: Date = Date(), orderedQuantity: Double = 0, unitPrice: Double = 0) {
        self.id = UUID()
        self.orderNo = orderNo
        self.orderDate = orderDate
        self.statusRaw = OrderStatus.created.rawValue
        self.totalAmount = orderedQuantity * unitPrice
        self.orderedQuantity = orderedQuantity
        self.unitPrice = unitPrice
        self.createdAt = Date()
    }

    var status: OrderStatus {
        get { OrderStatus(rawValue: statusRaw) ?? .created }
        set { statusRaw = newValue.rawValue }
    }

    var isDelayed: Bool {
        guard let expected = expectedDeliveryDate,
              status != .completed && status != .cancelled else { return false }
        return Date() > expected
    }

    var deliveryRate: Double {
        guard orderedQuantity > 0 else { return 0 }
        return ((deliveredQuantity ?? 0) / orderedQuantity) * 100
    }
}

@Model
final class MaterialTestResult {
    var id: UUID
    var testTypeRaw: String
    var testDate: Date
    var sampleId: String?
    var testLaboratory: String?
    var result: String
    var isConforming: Bool
    var targetValue: String?
    var actualValue: String?
    var photoData: Data?
    var notes: String?
    var createdAt: Date
    @Relationship var material: Material?
    @Relationship var project: Project?

    init(testType: MaterialTestType, testDate: Date = Date(), result: String, isConforming: Bool) {
        self.id = UUID()
        self.testTypeRaw = testType.rawValue
        self.testDate = testDate
        self.result = result
        self.isConforming = isConforming
        self.createdAt = Date()
    }

    var testType: MaterialTestType {
        get { MaterialTestType(rawValue: testTypeRaw) ?? .other }
        set { testTypeRaw = newValue.rawValue }
    }
}

@Model
final class MaterialRequest {
    var id: UUID
    var requestDate: Date
    var requestedBy: String
    var statusRaw: String
    var urgencyRaw: String
    var requestedQuantity: Double
    var reason: String?
    var neededByDate: Date?
    var approvedBy: String?
    var approvalDate: Date?
    var notes: String?
    var createdAt: Date
    @Relationship var material: Material?
    @Relationship var project: Project?

    init(requestedBy: String, requestedQuantity: Double = 0) {
        self.id = UUID()
        self.requestDate = Date()
        self.requestedBy = requestedBy
        self.statusRaw = RequestStatus.draft.rawValue
        self.urgencyRaw = RequestUrgency.normal.rawValue
        self.requestedQuantity = requestedQuantity
        self.createdAt = Date()
    }

    var status: RequestStatus {
        get { RequestStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var urgency: RequestUrgency {
        get { RequestUrgency(rawValue: urgencyRaw) ?? .normal }
        set { urgencyRaw = newValue.rawValue }
    }
}

@Model
final class Material {
    var id: UUID
    var name: String
    var unit: String
    var currentStock: Double
    var minimumStock: Double
    var unitPrice: Double
    var wastageRate: Double?
    var theoreticalConsumption: Double?
    var qrCodeData: Data?
    var project: Project?
    var createdAt: Date
    // FAZ 17.3 — Malzeme Eksikleri
    var categoryRaw: String = "Diğer"
    var brand: String = ""
    var modelName: String = ""
    var storageLocation: String = ""
    var supplierName: String = ""
    var isCritical: Bool = false
    @Relationship(deleteRule: .cascade) var entries: [StockEntry]
    @Relationship(deleteRule: .cascade) var testResults: [MaterialTestResult]
    @Relationship(deleteRule: .nullify) var orders: [MaterialOrder]
    @Relationship(deleteRule: .nullify) var requests: [MaterialRequest]

    init(name: String, unit: String = "adet", minimumStock: Double = 0, unitPrice: Double = 0) {
        self.id = UUID()
        self.name = name
        self.unit = unit
        self.currentStock = 0
        self.minimumStock = minimumStock
        self.unitPrice = unitPrice
        self.entries = []
        self.testResults = []
        self.orders = []
        self.requests = []
        self.createdAt = Date()
    }

    var materialCategory: MaterialCategory {
        get { MaterialCategory(rawValue: categoryRaw) ?? .diger }
        set { categoryRaw = newValue.rawValue }
    }

    var isLowStock: Bool { currentStock < minimumStock }
    var stockValue: Double { currentStock * unitPrice }
    var actualWastage: Double? {
        guard let theoretical = theoreticalConsumption, theoretical > 0 else { return nil }
        let totalOut = entries.filter { $0.entryType == .outgoing }.reduce(0.0) { $0 + $1.quantity }
        return (totalOut - theoretical) / theoretical * 100
    }
    var pendingOrderCount: Int { orders.filter { $0.status != .completed && $0.status != .cancelled }.count }
    var hasNonConformingTest: Bool { testResults.contains { !$0.isConforming } }
}

@Model
final class StockEntry {
    var id: UUID
    var date: Date
    var entryType: StockEntryType
    var quantity: Double
    var supplierName: String?
    var deliveryNoteNo: String?
    var usedForWorkItem: String?
    var notes: String?
    var photoData: Data?
    var batchNo: String?
    var qualityStatusRaw: String?
    var material: Material?
    @Relationship var supplier: Supplier?
    var createdAt: Date

    init(date: Date = Date(), entryType: StockEntryType, quantity: Double) {
        self.id = UUID()
        self.date = date
        self.entryType = entryType
        self.quantity = quantity
        self.createdAt = Date()
    }

    var qualityStatus: QualityStatus? {
        get { qualityStatusRaw.flatMap { QualityStatus(rawValue: $0) } }
        set { qualityStatusRaw = newValue?.rawValue }
    }
}

