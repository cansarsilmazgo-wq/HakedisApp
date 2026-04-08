import Foundation
import SwiftData
import Security
import os

// MARK: - Keychain Helper

struct KeychainHelper {
    static func write(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - New Enums (Phase 1)

enum WorkIncreaseStatus: String, Codable {
    case underContract = "Eksiliş"
    case normal = "Normal"
    case warning = "Uyarı"
    case exceeded = "Aşıldı"
}

enum ContractType: String, Codable, CaseIterable {
    case unitPrice = "Birim Fiyat"
    case lumpSum = "Götürü Bedel"
    case anahtarTeslim = "Anahtar Teslim"
    case mixed = "Karma"
}

enum ContractSector: String, Codable, CaseIterable {
    case kamu  = "Kamu İhalesi"
    case ozel  = "Özel Sektör"

    /// Kanun gereği varsayılan itiraz süresi (gün)
    var defaultObjectionDays: Int {
        switch self {
        case .kamu: return 30  // 4735 sayılı Kanun md. 58
        case .ozel: return 45  // Sözleşmeye göre, tipik özel sektör uygulaması
        }
    }
}

enum GuaranteeType: String, Codable, CaseIterable {
    case temporary = "Geçici Teminat"
    case permanent = "Kesin Teminat"
    case additional = "Ek Teminat"
    case other = "Diğer"
}

// MARK: - Guarantee Model

@Model
final class Guarantee {
    var id: UUID = UUID()
    var guaranteeType: GuaranteeType = GuaranteeType.temporary
    var amount: Double = 0.0
    var bankName: String = ""
    var referenceNumber: String = ""
    var issueDate: Date = Date()
    var expiryDate: Date = Date()
    var isReturned: Bool = false
    var returnedDate: Date? = nil
    var notes: String = ""
    var contract: Contract? = nil

    init(guaranteeType: GuaranteeType, amount: Double, bankName: String, referenceNumber: String, issueDate: Date, expiryDate: Date) {
        self.id = UUID()
        self.guaranteeType = guaranteeType
        self.amount = amount
        self.bankName = bankName
        self.referenceNumber = referenceNumber
        self.issueDate = issueDate
        self.expiryDate = expiryDate
    }

    var isExpiringSoon: Bool {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        return !isReturned && days >= 0 && days <= 30
    }
    var isExpired: Bool {
        !isReturned && expiryDate < Date()
    }
    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    }
}

@Model
final class Project {
    var id: UUID
    var name: String
    var projectDescription: String
    var location: String
    var startDate: Date
    var status: ProjectStatus
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var contracts: [Contract]
    @Relationship(deleteRule: .cascade) var milestones: [Milestone]
    @Relationship(deleteRule: .cascade) var siteReports: [SiteReport]

    var latitude: Double?
    var longitude: Double?
    var projectType: ProjectType = ProjectType.ozelSektor

    // FAZ 7 — Proje Formu Eksikleri
    var city: String = ""
    var district: String = ""
    var buildingPermitNo: String = ""
    var blockNo: String = ""
    var parcelNo: String = ""
    var employerName: String = ""
    var buildingType: BuildingType = BuildingType.residential
    var totalConstructionArea: Double = 0.0

    init(name: String, projectDescription: String = "", location: String = "", startDate: Date = Date(), projectType: ProjectType = .ozelSektor) {
        self.id = UUID()
        self.name = name
        self.projectDescription = projectDescription
        self.location = location
        self.startDate = startDate
        self.projectType = projectType
        self.status = .active
        self.createdAt = Date()
        self.contracts = []
        self.milestones = []
        self.siteReports = []
    }

    var hasCoordinates: Bool { latitude != nil && longitude != nil }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case active = "Aktif"
    case completed = "Tamamlandı"
    case paused = "Askıda"
}


enum ProjectType: String, Codable, CaseIterable {
    case kamuIhalesi  = "Kamu İhalesi"
    case ozelSektor   = "Özel Sektör"
    case katKarsiligi = "Kat Karşılığı"
    case yapSat       = "Yap-Sat"

    var displayName: String { rawValue }

    var stopajRequired: Bool {
        switch self {
        case .kamuIhalesi: return true
        default: return false
        }
    }

    var defaultStopajRate: Double {
        switch self {
        case .kamuIhalesi: return 3.0
        default: return 0.0
        }
    }

    var defaultTeminatRate: Double {
        switch self {
        case .kamuIhalesi: return 6.0
        default: return 0.0
        }
    }

    var bayindirlikPozRequired: Bool {
        switch self {
        case .kamuIhalesi: return true
        default: return false
        }
    }

    var fiyatFarkiEnabled: Bool {
        switch self {
        case .kamuIhalesi: return true
        default: return false
        }
    }

    var damgaVergisiRequired: Bool {
        switch self {
        case .kamuIhalesi, .ozelSektor: return true
        default: return false
        }
    }

    var infoText: String {
        switch self {
        case .kamuIhalesi:  return "Stopaj %3, Kesin Teminat %6, Bayındırlık Pozları"
        case .ozelSektor:   return "Stopaj ve teminat oranları sözleşmeye göre belirlenir"
        case .katKarsiligi: return "Pursantaj takibi aktif, stopaj ve teminat yok"
        case .yapSat:       return "Maliyet takibi aktif, stopaj ve teminat yok"
        }
    }
}

@Model
final class Contractor {
    var id: UUID
    var name: String
    var contactPerson: String
    var phone: String
    var email: String
    var taxNumber: String
    var portalPassword: String
    var createdAt: Date
    // FAZ 16 — #119 Taşeron performans değerlendirmesi
    var qualityScore: Double = 0.0       // 0-10 iş kalitesi
    var onTimeScore: Double = 0.0        // 0-10 zamanında teslim
    var safetyScore: Double = 0.0        // 0-10 İSG puanı
    var performanceNotes: String = ""
    // FAZ 16 — #31 Taşeron firma profili
    var activityArea: String = ""        // Faaliyet alanı
    // FAZ 16 — #32 Subcontractor invite code (patron onayında kullanılacak)
    var subcontractorInviteCode: String = ""
    @Relationship(deleteRule: .cascade) var contracts: [Contract]

    init(name: String, contactPerson: String = "", phone: String = "", email: String = "", taxNumber: String = "") {
        self.id = UUID()
        self.name = name
        self.contactPerson = contactPerson
        self.phone = phone
        self.email = email
        self.taxNumber = taxNumber
        self.portalPassword = ""
        self.createdAt = Date()
        self.contracts = []
    }

    var keychainPortalPassword: String {
        get {
            if let kc = KeychainHelper.read(forKey: "portal_\(id.uuidString)") { return kc }
            if !portalPassword.isEmpty {
                KeychainHelper.write(portalPassword, forKey: "portal_\(id.uuidString)")
                portalPassword = ""
            }
            return KeychainHelper.read(forKey: "portal_\(id.uuidString)") ?? ""
        }
        set {
            KeychainHelper.write(newValue, forKey: "portal_\(id.uuidString)")
            if !portalPassword.isEmpty { portalPassword = "" }
        }
    }

    var hasPortalPassword: Bool { !keychainPortalPassword.isEmpty }

    var overallPerformanceScore: Double {
        let scores = [qualityScore, onTimeScore, safetyScore].filter { $0 > 0 }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var performanceRating: String {
        let s = overallPerformanceScore
        switch s {
        case 0:        return "Değerlendirilmedi"
        case ..<4:     return "Zayıf"
        case ..<6:     return "Orta"
        case ..<8:     return "İyi"
        default:       return "Mükemmel"
        }
    }
}

@Model
final class Contract {
    var id: UUID
    var title: String
    var contractDate: Date
    var retentionRate: Double
    var advanceRate: Double
    var completionDeadline: Date?
    var kdvRate: Double
    var advanceGiven: Double          // Fiilen ödenen avans tutarı
    var dailyPenaltyRate: Double
    var maxPenaltyRate: Double
    var project: Project?
    var contractor: Contractor?
    @Relationship(deleteRule: .cascade) var workItems: [WorkItem]
    @Relationship(deleteRule: .cascade) var hakedisler: [Hakedis]
    @Relationship(deleteRule: .cascade) var retentionReleases: [RetentionRelease]
    @Relationship(deleteRule: .cascade) var changeOrders: [ChangeOrder]
    @Relationship(deleteRule: .cascade) var handoverRecords: [SiteHandoverRecord]
    @Relationship(deleteRule: .cascade) var laborRecords: [LaborRecord]
    @Relationship(deleteRule: .cascade) var materialRecords: [MaterialRecord]
    @Relationship(deleteRule: .cascade) var specificationItems: [SpecificationItem]
    @Relationship(deleteRule: .cascade) var correspondenceRecords: [CorrespondenceRecord]
    @Relationship(deleteRule: .cascade) var priceDifferenceRecords: [PriceDifferenceRecord]
    @Relationship(deleteRule: .cascade) var sgkLaborRecords: [SGKLaborRecord]
    @Relationship(deleteRule: .cascade) var siteLogEntries: [SiteLogEntry]
    @Relationship(deleteRule: .cascade) var equipments: [Equipment]
    @Relationship(deleteRule: .cascade) var soilRecords: [SoilRecord]
    @Relationship(deleteRule: .cascade) var testRecords: [TestRecord]
    @Relationship(deleteRule: .cascade) var acceptanceRecords: [AcceptanceRecord]
    var contractType: ContractType = ContractType.unitPrice
    var contractSector: ContractSector = ContractSector.kamu
    var objectionPeriodDays: Int = 30
    var overdueInterestRate: Double = 9.0
    @Relationship(deleteRule: .cascade) var guarantees: [Guarantee] = []

    // FAZ 4 — Sözleşme Formu Eksikleri
    var contractNumber: String = ""
    var employerName: String = ""
    var stopajRate: Double = 0.0
    var damgaVergisiRate: Double = 0.0
    var contractStartDate: Date? = nil
    var contractEndDate: Date? = nil
    var kdvTevkifatRate: String = "0"

    var workDuration: Int {
        guard let start = contractStartDate, let end = contractEndDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    init(title: String, contractDate: Date = Date(), retentionRate: Double = 10.0, advanceRate: Double = 0.0) {
        self.id = UUID()
        self.title = title
        self.contractDate = contractDate
        self.retentionRate = retentionRate
        self.advanceRate = advanceRate
        self.completionDeadline = nil
        self.kdvRate = 0.0
        self.advanceGiven = 0.0
        self.dailyPenaltyRate = 0.0
        self.maxPenaltyRate = 20.0
        self.workItems = []
        self.hakedisler = []
        self.retentionReleases = []
        self.changeOrders = []
        self.handoverRecords = []
        self.laborRecords = []
        self.materialRecords = []
        self.specificationItems = []
        self.correspondenceRecords = []
        self.priceDifferenceRecords = []
        self.sgkLaborRecords = []
        self.siteLogEntries = []
        self.equipments = []
        self.soilRecords = []
        self.testRecords = []
        self.acceptanceRecords = []
        self.guarantees = []
    }

    var hasHandover: Bool { !handoverRecords.isEmpty }
    var latestHandover: SiteHandoverRecord? {
        handoverRecords.sorted { $0.handoverDate > $1.handoverDate }.first
    }
    var openDeficiencyCount: Int {
        handoverRecords.flatMap { $0.deficiencies }.filter { !$0.isClosed }.count
    }

    // Gecikme cezası hesabı
    func delayPenalty(asOf date: Date = Date()) -> Double {
        guard let deadline = completionDeadline, dailyPenaltyRate > 0 else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: deadline, to: date).day ?? 0
        guard days > 0 else { return 0 }
        let daily = totalContractAmount * (dailyPenaltyRate / 100)
        let max = totalContractAmount * (maxPenaltyRate / 100)
        return min(daily * Double(days), max)
    }

    func delayDays(asOf date: Date = Date()) -> Int {
        guard let deadline = completionDeadline else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: deadline, to: date).day ?? 0
        return max(0, days)
    }

    var totalContractAmount: Double { workItems.reduce(0) { $0 + $1.totalAmount } }

    // Toplam hakedişlenen (KDV hariç net)
    var totalInvoiced: Double { hakedisler.reduce(0) { $0 + $1.netAmount } }

    // Bütçe kullanım yüzdesi
    var budgetUtilization: Double {
        guard totalContractAmount > 0 else { return 0 }
        return (totalInvoiced / totalContractAmount) * 100
    }
    var isOverBudget: Bool { budgetUtilization > 100 }

    // Teminat takibi
    var totalRetentionAccrued: Double  { hakedisler.reduce(0) { $0 + $1.retentionAmount } }
    var totalRetentionReleased: Double { retentionReleases.reduce(0) { $0 + $1.amount } }
    var retentionBalance: Double       { totalRetentionAccrued - totalRetentionReleased }

    // Avans takibi
    var totalAdvanceRecovered: Double { hakedisler.reduce(0) { $0 + $1.advanceDeduction } }
    var advanceBalance: Double        { advanceGiven - totalAdvanceRecovered }

    // Ek iş emri takibi
    var approvedChangeOrderAmount: Double {
        changeOrders.filter { $0.status == .approved }.reduce(0) { $0 + $1.amount }
    }
    var pendingChangeOrderAmount: Double {
        changeOrders.filter { $0.status == .pending }.reduce(0) { $0 + $1.amount }
    }
    /// Onaylı ek işler dahil efektif sözleşme tutarı
    var effectiveContractAmount: Double { totalContractAmount + approvedChangeOrderAmount }
}

@Model
final class WorkItem {
    var id: UUID
    var code: String
    var name: String
    var unit: String
    var unitPrice: Double
    var contractedQuantity: Double
    var location: String
    var revisionHistory: [String]
    var contract: Contract?
    @Relationship(deleteRule: .cascade) var dailyEntries: [DailyEntry]
    @Relationship(deleteRule: .cascade) var unitPriceAnalyses: [UnitPriceAnalysis]
    @Relationship(deleteRule: .cascade) var measurementEntries: [MeasurementEntry]
    @Relationship(deleteRule: .cascade) var attachments: [AttachmentRecord]

    init(code: String, name: String, unit: String, unitPrice: Double, contractedQuantity: Double, location: String = "") {
        self.id = UUID()
        self.code = code
        self.name = name
        self.unit = unit
        self.unitPrice = max(0, unitPrice)
        self.contractedQuantity = max(0, contractedQuantity)
        self.location = location
        self.revisionHistory = []
        self.dailyEntries = []
        self.unitPriceAnalyses = []
        self.measurementEntries = []
        self.attachments = []
    }

    var totalAmount: Double { contractedQuantity * unitPrice }
    var completedQuantity: Double { dailyEntries.reduce(0) { $0 + $1.quantity } }
    var completionPercentage: Double {
        guard contractedQuantity > 0 else { return 0 }
        return min((completedQuantity / contractedQuantity) * 100, 100)
    }
    var remainingQuantity: Double { contractedQuantity - completedQuantity }
    var workIncreasePercentage: Double {
        guard contractedQuantity > 0 else { return 0 }
        return ((completedQuantity - contractedQuantity) / contractedQuantity) * 100
    }
    var workIncreaseStatus: WorkIncreaseStatus {
        let pct = workIncreasePercentage
        if pct >= 20 { return .exceeded }
        else if pct >= 15 { return .warning }
        else if pct > 0 { return .normal }
        else { return .underContract }
    }
}

@Model
final class DailyEntry {
    var id: UUID
    var date: Date
    var quantity: Double
    var location: String
    var notes: String
    var photoData: [Data]
    var workItem: WorkItem?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var photoAnnotations: [PhotoAnnotation]
    var gpsLatitude: Double? = nil
    var gpsLongitude: Double? = nil
    var gpsAccuracy: Double? = nil
    var weatherCondition: String = ""
    var temperatureC: Double? = nil
    var windSpeedKmh: Double? = nil
    var weatherFetchedAt: Date? = nil

    init(date: Date = Date(), quantity: Double, location: String = "", notes: String = "") {
        self.id = UUID()
        self.date = date
        self.quantity = max(0, quantity)
        self.location = location
        self.notes = notes
        self.photoData = []
        self.photoAnnotations = []
        self.createdAt = Date()
    }
}

@Model
final class Hakedis {
    var id: UUID
    var periodName: String
    var periodStart: Date
    var periodEnd: Date
    var dueDate: Date?
    var status: HakedisStatus
    var notes: String
    var approvalNote: String     // Onay/red gerekçesi
    var contract: Contract?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var items: [HakedisItem]
    @Relationship(deleteRule: .cascade) var payments: [Payment]
    @Relationship(deleteRule: .cascade) var approvalSteps: [ApprovalStep]
    @Relationship(deleteRule: .cascade) var revisions: [HakedisRevision]
    @Relationship(deleteRule: .cascade) var vatWithholdings: [VATWithholdingRecord]
    var withholdingTaxRate: Double = 3.0
    var stampTaxRate: Double = 0.948
    var lumpSumCompletionPercentage: Double = 0.0

    init(periodName: String, periodStart: Date, periodEnd: Date, dueDate: Date? = nil) {
        self.id = UUID()
        self.periodName = periodName
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.dueDate = dueDate
        self.status = .draft
        self.notes = ""
        self.approvalNote = ""
        self.items = []
        self.payments = []
        self.approvalSteps = []
        self.revisions = []
        self.vatWithholdings = []
        self.createdAt = Date()
    }

    var nextRevisionVersion: String { "v1.\(revisions.count)" }

    var grossAmount: Double { items.reduce(0) { $0 + $1.periodAmount } }

    var retentionAmount: Double {
        guard let rate = contract?.retentionRate, rate > 0 else { return 0 }
        return effectiveGrossAmount * (rate / 100)
    }

    /// Avans kesintisi: efektif brüt × avans oranı (lumpSum'da effectiveGrossAmount kullanılır)
    var advanceDeduction: Double {
        guard let rate = contract?.advanceRate, rate > 0 else { return 0 }
        return effectiveGrossAmount * (rate / 100)
    }

    /// Teminat ve avans sonrası KDV matrahı
    var netAmount: Double { effectiveGrossAmount - retentionAmount - advanceDeduction }

    /// KDV tutarı (net × kdv oranı)
    var kdvAmount: Double {
        guard let rate = contract?.kdvRate, rate > 0 else { return 0 }
        return netAmount * (rate / 100)
    }

    /// Ödenecek toplam (net + KDV)
    var totalWithKDV: Double { netAmount + kdvAmount }

    var totalPaid: Double { payments.reduce(0) { $0 + $1.amount } }

    /// Kalan ödeme (KDV dahil toplam – gecikme cezası – ödenen)
    var remainingAmount: Double { totalWithKDV - penaltyAmount - totalPaid }

    /// Ödeme gecikme günü (vade tarihi geçmişse ve hâlâ ödenmemişse)
    var daysOverdue: Int {
        guard let due = dueDate, remainingAmount > 0, status != .paid else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: due, to: Date()).day ?? 0
        return max(0, days)
    }

    /// Gecikme faizi — sözleşmedeki yıllık faiz oranı, KDV öncesi net tutar üzerinden hesaplanır
    var overdueInterest: Double {
        guard daysOverdue > 0 else { return 0 }
        let rate = contract?.overdueInterestRate ?? 9.0
        let dailyRate = rate / 365.0 / 100.0
        return netAmountAfterTax * dailyRate * Double(daysOverdue)
    }

    var isOverdue: Bool { daysOverdue > 0 }

    /// Stopaj: KDV matrahı (netAmount) üzerinden kesilir — mevzuat gereği
    var withholdingTaxAmount: Double { netAmount * withholdingTaxRate / 100 }
    /// Damga vergisi: KDV matrahı (netAmount) üzerinden kesilir
    var stampTaxAmount: Double { netAmount * stampTaxRate / 100 }
    /// Stopaj ve damga sonrası net
    var netAmountAfterTax: Double { netAmount - withholdingTaxAmount - stampTaxAmount }
    /// Gecikme cezası da düşüldükten sonra net ödeme
    var netAmountAfterPenalty: Double { netAmountAfterTax - penaltyAmount }
    var effectiveGrossAmount: Double {
        guard let c = contract else { return grossAmount }
        if c.contractType == .lumpSum {
            return c.totalContractAmount * (lumpSumCompletionPercentage / 100)
        }
        return grossAmount
    }
    /// Gecikme cezası — Contract.delayPenalty() delegasyonu
    var penaltyAmount: Double { contract?.delayPenalty() ?? 0 }
    var penaltyDays: Int {
        guard let c = contract, c.dailyPenaltyRate > 0 else { return 0 }
        return c.delayDays()
    }
}

enum HakedisStatus: String, Codable, CaseIterable {
    case draft = "Taslak"
    case pendingApproval = "Onay Bekliyor"
    case approved = "Onaylandı"
    case rejected = "Reddedildi"
    case paid = "Ödendi"
}

@Model
final class HakedisItem {
    var id: UUID
    var workItemName: String
    var workItemCode: String
    var unit: String
    var unitPrice: Double
    var previousQuantity: Double
    var currentQuantity: Double
    var hakedis: Hakedis?

    var contractedQuantity: Double = 0.0

    init(workItemName: String, workItemCode: String, unit: String, unitPrice: Double, previousQuantity: Double, currentQuantity: Double, contractedQuantity: Double = 0.0) {
        self.id = UUID()
        self.workItemName = workItemName
        self.workItemCode = workItemCode
        self.unit = unit
        self.unitPrice = unitPrice
        self.previousQuantity = previousQuantity
        self.currentQuantity = currentQuantity
        self.contractedQuantity = contractedQuantity
    }

    var cumulativeQuantity: Double { previousQuantity + currentQuantity }
    var periodAmount: Double { currentQuantity * unitPrice }
    var cumulativeAmount: Double { cumulativeQuantity * unitPrice }
    var completionRate: Double {
        guard contractedQuantity > 0 else { return 0 }
        return min((cumulativeQuantity / contractedQuantity) * 100, 100)
    }
}

// MARK: - FAZ 11: Objection (İtiraz) Model

enum ObjectionCategory: String, Codable, CaseIterable {
    case miktar     = "Miktar İtirazı"
    case fiyat      = "Fiyat İtirazı"
    case kesinti    = "Kesinti İtirazı"
    case sureBitis  = "Süre/Bitiş İtirazı"
    case diger      = "Diğer"
}

enum ObjectionStatus: String, Codable, CaseIterable {
    case acik       = "Açık"
    case incelemede = "İncelemede"
    case kabul      = "Kabul Edildi"
    case kismiKabul = "Kısmi Kabul"
    case red        = "Reddedildi"

    var color: String {
        switch self {
        case .acik:       return "warning"
        case .incelemede: return "orange"
        case .kabul:      return "success"
        case .kismiKabul: return "success"
        case .red:        return "danger"
        }
    }
}

@Model
final class Objection {
    var id: UUID
    var objectionNumber: String
    var objectionDate: Date
    var reason: String
    var categoryRaw: String
    var claimedAmount: Double
    var approvedAmount: Double
    var statusRaw: String
    var responseDate: Date?
    var responseNote: String?
    var createdAt: Date
    @Relationship var relatedHakedis: Hakedis?

    var category: ObjectionCategory {
        get { ObjectionCategory(rawValue: categoryRaw) ?? .diger }
        set { categoryRaw = newValue.rawValue }
    }
    var status: ObjectionStatus {
        get { ObjectionStatus(rawValue: statusRaw) ?? .acik }
        set { statusRaw = newValue.rawValue }
    }
    var deadlineDate: Date { Calendar.current.date(byAdding: .day, value: 30, to: objectionDate) ?? objectionDate }
    var daysUntilDeadline: Int { Calendar.current.dateComponents([.day], from: Date(), to: deadlineDate).day ?? 0 }
    var isDeadlineApproaching: Bool { daysUntilDeadline <= 7 && status == .acik }

    init(objectionNumber: String, objectionDate: Date = Date(), reason: String, category: ObjectionCategory, claimedAmount: Double) {
        self.id = UUID()
        self.objectionNumber = objectionNumber
        self.objectionDate = objectionDate
        self.reason = reason
        self.categoryRaw = category.rawValue
        self.claimedAmount = claimedAmount
        self.approvedAmount = 0
        self.statusRaw = ObjectionStatus.acik.rawValue
        self.createdAt = Date()
    }

    static func generateNumber(existing: [Objection]) -> String {
        let year = Calendar.current.component(.year, from: Date())
        let next = existing.filter { $0.objectionNumber.contains("\(year)") }.count + 1
        return String(format: "ITR-%d-%03d", year, next)
    }
}

@Model
final class Payment {
    var id: UUID
    var amount: Double
    var paymentDate: Date
    var paymentDescription: String
    var hakedis: Hakedis?

    init(amount: Double, paymentDate: Date = Date(), paymentDescription: String = "") {
        self.id = UUID()
        self.amount = amount
        self.paymentDate = paymentDate
        self.paymentDescription = paymentDescription
    }
}

