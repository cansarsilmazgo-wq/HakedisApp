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

    init(name: String, projectDescription: String = "", location: String = "", startDate: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.projectDescription = projectDescription
        self.location = location
        self.startDate = startDate
        self.status = .active
        self.createdAt = Date()
        self.contracts = []
        self.milestones = []
        self.siteReports = []
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case active = "Aktif"
    case completed = "Tamamlandı"
    case paused = "Askıda"
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

    init(workItemName: String, workItemCode: String, unit: String, unitPrice: Double, previousQuantity: Double, currentQuantity: Double) {
        self.id = UUID()
        self.workItemName = workItemName
        self.workItemCode = workItemCode
        self.unit = unit
        self.unitPrice = unitPrice
        self.previousQuantity = previousQuantity
        self.currentQuantity = currentQuantity
    }

    var cumulativeQuantity: Double { previousQuantity + currentQuantity }
    var periodAmount: Double { currentQuantity * unitPrice }
    var cumulativeAmount: Double { cumulativeQuantity * unitPrice }
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

// MARK: - Change Order (Ek İş Emri)

@Model
final class ChangeOrder {
    var id: UUID
    var title: String
    var changeDate: Date
    var reason: String
    var amount: Double          // pozitif = ek iş, negatif = keşif azaltması
    var status: ChangeOrderStatus
    var approvalNote: String
    var contract: Contract?
    var createdAt: Date

    init(title: String, changeDate: Date = Date(), reason: String = "", amount: Double) {
        self.id = UUID()
        self.title = title
        self.changeDate = changeDate
        self.reason = reason
        self.amount = amount
        self.status = .pending
        self.approvalNote = ""
        self.createdAt = Date()
    }
}

enum ChangeOrderStatus: String, Codable, CaseIterable {
    case pending  = "Beklemede"
    case approved = "Onaylandı"
    case rejected = "Reddedildi"
}

// MARK: - Milestone (İş Programı)

@Model
final class Milestone {
    var id: UUID
    var title: String
    var plannedDate: Date
    var actualDate: Date?
    var notes: String
    var isCritical: Bool
    var plannedAmount: Double = 0.0
    var project: Project?
    var createdAt: Date

    init(title: String, plannedDate: Date, notes: String = "", isCritical: Bool = false, plannedAmount: Double = 0.0) {
        self.id = UUID()
        self.title = title
        self.plannedDate = plannedDate
        self.notes = notes
        self.isCritical = isCritical
        self.plannedAmount = plannedAmount
        self.createdAt = Date()
    }

    var isCompleted: Bool { actualDate != nil }

    var delayDays: Int {
        if let actual = actualDate {
            let days = Calendar.current.dateComponents([.day], from: plannedDate, to: actual).day ?? 0
            return max(0, days)
        }
        guard Date() > plannedDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: plannedDate, to: Date()).day ?? 0
    }

    var daysUntilDue: Int {
        guard actualDate == nil else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: plannedDate).day ?? 0
        return max(0, days)
    }

    var isOverdue: Bool { actualDate == nil && Date() > plannedDate }

    var completedOnTime: Bool {
        guard let actual = actualDate else { return false }
        return actual <= plannedDate
    }
}

// MARK: - Site Report (Günlük Saha Raporu)

@Model
final class SiteReport {
    var id: UUID
    var date: Date
    var weather: SiteWeather
    var temperature: Double?
    var workerCount: Int
    var engineerCount: Int
    var workSummary: String
    var issues: String
    var tomorrowPlan: String
    var equipmentNotes: String
    var photoData: [Data]
    var project: Project?
    var createdAt: Date

    init(
        date: Date = Date(),
        weather: SiteWeather = .sunny,
        temperature: Double? = nil,
        workerCount: Int = 0,
        engineerCount: Int = 0,
        workSummary: String = "",
        issues: String = "",
        tomorrowPlan: String = "",
        equipmentNotes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.weather = weather
        self.temperature = temperature
        self.workerCount = workerCount
        self.engineerCount = engineerCount
        self.workSummary = workSummary
        self.issues = issues
        self.tomorrowPlan = tomorrowPlan
        self.equipmentNotes = equipmentNotes
        self.photoData = []
        self.createdAt = Date()
    }

    var totalPersonnel: Int { workerCount + engineerCount }
    var hasIssues: Bool { !issues.trimmingCharacters(in: .whitespaces).isEmpty }
}

enum SiteWeather: String, Codable, CaseIterable {
    case sunny  = "Güneşli"
    case cloudy = "Bulutlu"
    case rainy  = "Yağmurlu"
    case snowy  = "Karlı"
    case foggy  = "Sisli"
    case windy  = "Rüzgarlı"

    var icon: String {
        switch self {
        case .sunny:  return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy:  return "cloud.rain.fill"
        case .snowy:  return "cloud.snow.fill"
        case .foggy:  return "cloud.fog.fill"
        case .windy:  return "wind"
        }
    }
}

// MARK: - Approval Chain (İmza Zinciri)

enum ApprovalRole: String, Codable, CaseIterable {
    case santiyeSef  = "Şantiye Şefi"
    case sefMuhendis = "Şef Mühendis"
    case idare       = "İdare"

    var icon: String {
        switch self {
        case .santiyeSef:  return "person.fill.checkmark"
        case .sefMuhendis: return "person.2.fill"
        case .idare:       return "building.columns.fill"
        }
    }
}

enum ApprovalStepStatus: String, Codable, CaseIterable {
    case bekliyor        = "Bekliyor"
    case onaylandi       = "Onaylandı"
    case reddedildi      = "Reddedildi"
    case yetkiDevredildi = "Yetki Devredildi"
}

@Model
final class ApprovalStep {
    var id: UUID
    var stepOrder: Int
    var role: ApprovalRole
    var approverName: String
    var delegateName: String?
    var delegateReason: String?
    var approvedAt: Date?
    var deadline: Date?
    var comment: String?
    var status: ApprovalStepStatus
    var rejectionReason: String?
    var authorityDocNo: String?
    var authorityDocDate: Date?
    var authorityGrantedBy: String?
    var isCancelled: Bool
    var cancellationReason: String?
    var auditLog: String?
    var hakedis: Hakedis?

    init(stepOrder: Int, role: ApprovalRole, approverName: String) {
        self.id = UUID()
        self.stepOrder = stepOrder
        self.role = role
        self.approverName = approverName
        self.status = .bekliyor
        self.isCancelled = false
    }

    var deadlineDaysLeft: Int? {
        guard let d = deadline, status == .bekliyor, !isCancelled else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: d).day
    }

    var isNearingDeadline: Bool {
        guard let left = deadlineDaysLeft else { return false }
        return left >= 0 && left <= 3
    }

    var effectiveApproverName: String {
        delegateName.map { "\($0) (vekil)" } ?? approverName
    }
}

// MARK: - Rejection Flow (Red & İtiraz)

enum RevisionResolution: String, Codable, CaseIterable {
    case devam         = "Devam"
    case kismenKabul   = "Kısmen Kabul"
    case tamKabul      = "Tam Kabul"
    case hakemeGidildi = "Hakeme Gidildi"
}

@Model
final class HakedisRevision {
    var id: UUID
    var version: String
    var rejectionReason: String
    var officialLetterNo: String?
    var rejectedAt: Date
    var objectionText: String?
    var objectionDeadline: Date
    var revisedItemsJSON: String?
    var mediationDatesJSON: String?
    var resolution: RevisionResolution?
    var itirazKazanildi: Bool?
    var paymentDocNo: String?
    var hakedis: Hakedis?
    var createdAt: Date

    init(version: String, rejectionReason: String, rejectedAt: Date = Date(),
         officialLetterNo: String? = nil, objectionPeriodDays: Int = 30) {
        self.id = UUID()
        self.version = version
        self.rejectionReason = rejectionReason
        self.officialLetterNo = officialLetterNo
        self.rejectedAt = rejectedAt
        self.objectionDeadline = Calendar.current.date(byAdding: .day, value: objectionPeriodDays, to: rejectedAt)!
        self.createdAt = Date()
    }

    var objectionDaysLeft: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: objectionDeadline).day ?? 0)
    }

    var isExpired: Bool {
        (Calendar.current.dateComponents([.day], from: Date(), to: objectionDeadline).day ?? 0) < 0
    }
}

// MARK: - Unit Price Analysis (Birim Fiyat Analizi)

enum LaborShiftType: String, Codable, CaseIterable {
    case gunduz    = "Gündüz"
    case gece      = "Gece"
    case haftaSonu = "Hafta Sonu"

    var coefficient: Double {
        switch self {
        case .gunduz:    return 1.0
        case .gece:      return 1.25
        case .haftaSonu: return 1.50
        }
    }

    var coefficientLabel: String {
        switch self {
        case .gunduz:    return "×1,00"
        case .gece:      return "×1,25 (%25 zam)"
        case .haftaSonu: return "×1,50 (%50 zam)"
        }
    }
}

enum AnalysisApprovalStatus: String, Codable, CaseIterable {
    case taslak            = "Taslak"
    case idareOnayBekliyor = "İdare Onay Bekliyor"
    case onaylandi         = "Onaylandı"
    case reddedildi        = "Reddedildi"
}

@Model
final class UnitPriceAnalysis {
    var id: UUID
    var analysisNo: String
    var date: Date
    var version: Int
    var workItemCode: String
    var workItemName: String
    var isStandardPoz: Bool
    var standardPozCode: String?
    var laborCost: Double
    var laborShiftType: LaborShiftType
    var materialCost: Double
    var machineCost: Double
    var transportCost: Double
    var hasForeignCurrency: Bool
    var currencyCode: String?
    var exchangeRate: Double?
    var exchangeRateDate: Date?
    var marketResearchJSON: String?
    var overheadRate: Double
    var profitRate: Double
    var approvalStatus: AnalysisApprovalStatus
    var approvedBy: String?
    var approvedAt: Date?
    var contractUnitPrice: Double
    var workItem: WorkItem?
    var createdAt: Date

    init(analysisNo: String, workItemCode: String, workItemName: String,
         contractUnitPrice: Double, version: Int = 1) {
        self.id = UUID()
        self.analysisNo = analysisNo
        self.date = Date()
        self.version = version
        self.workItemCode = workItemCode
        self.workItemName = workItemName
        self.isStandardPoz = false
        self.laborCost = 0
        self.laborShiftType = .gunduz
        self.materialCost = 0
        self.machineCost = 0
        self.transportCost = 0
        self.hasForeignCurrency = false
        self.overheadRate = 15.0
        self.profitRate = 10.0
        self.approvalStatus = .taslak
        self.contractUnitPrice = contractUnitPrice
        self.createdAt = Date()
    }

    var directCost: Double {
        laborCost * laborShiftType.coefficient + materialCost + machineCost + transportCost
    }

    var totalCost: Double {
        directCost * (1 + overheadRate / 100) * (1 + profitRate / 100)
    }

    var diff: Double { totalCost - contractUnitPrice }

    var isSavings: Bool { diff < 0 }
}

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
    case sunny = "Güneşli"
    case cloudy = "Bulutlu"
    case rainy = "Yağmurlu"
    case snowy = "Karlı"
    case stormy = "Fırtınalı"

    var icon: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .snowy: return "cloud.snow.fill"
        case .stormy: return "cloud.bolt.fill"
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
    var project: Project?
    var createdAt: Date
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

// MARK: - Ekipman Yönetimi (EquipmentItem)

enum OwnershipType: String, Codable, CaseIterable {
    case owned = "Öz Mal"
    case rented = "Kiralık"
}

@Model
final class EquipmentItem {
    var id: UUID
    var name: String
    var plateNumber: String?
    var ownershipType: OwnershipType
    var dailyRentalCost: Double
    var fuelType: String?
    var brand: String?
    var modelName: String?
    var yearOfManufacture: Int?
    var enginePower: Double?
    var capacity: String?
    var insuranceExpiryDate: Date?
    var inspectionExpiryDate: Date?
    var registrationInfo: String?
    var hourlyFuelConsumption: Double?
    var depreciationYears: Int?
    var purchasePrice: Double?
    var purchaseDate: Date?
    var project: Project?
    var maintenanceIntervalHours: Double
    var totalOperatingHours: Double
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var logs: [EquipmentLog]
    @Relationship(deleteRule: .cascade) var failures: [EquipmentFailure]
    @Relationship(deleteRule: .cascade) var maintenancePlans: [MaintenancePlan]
    @Relationship(deleteRule: .cascade) var rentalContracts: [RentalContract]

    init(name: String, ownershipType: OwnershipType = .owned, maintenanceIntervalHours: Double = 250) {
        self.id = UUID()
        self.name = name
        self.ownershipType = ownershipType
        self.dailyRentalCost = 0
        self.maintenanceIntervalHours = maintenanceIntervalHours
        self.totalOperatingHours = 0
        self.logs = []
        self.failures = []
        self.maintenancePlans = []
        self.rentalContracts = []
        self.createdAt = Date()
    }

    var completedMaintenanceCount: Int { logs.filter { $0.isMaintenanceDay }.count }

    var isMaintenanceDue: Bool {
        guard maintenanceIntervalHours > 0 else { return false }
        let nextThreshold = maintenanceIntervalHours * Double(completedMaintenanceCount + 1)
        return totalOperatingHours >= nextThreshold
    }

    var monthlyCost: Double {
        let rentalDays = logs.filter { _ in ownershipType == .rented }.count
        let fuel = logs.reduce(0) { $0 + ($1.fuelCost ?? 0) }
        return Double(rentalDays) * dailyRentalCost + fuel
    }

    var totalRepairCost: Double { failures.filter { $0.isResolved }.reduce(0) { $0 + ($1.repairCost ?? 0) } }
    var totalFuelCost: Double { logs.reduce(0) { $0 + ($1.fuelCost ?? 0) } }
    var totalFuelLiters: Double { logs.reduce(0) { $0 + ($1.fuelLiters ?? 0) } }
    var totalOperatingCost: Double { totalRepairCost + totalFuelCost }
    var annualDepreciation: Double { (purchasePrice ?? 0) / Double(depreciationYears ?? 10) }
    var monthlyDepreciation: Double { annualDepreciation / 12 }
    var averageFuelConsumption: Double {
        guard totalOperatingHours > 0 else { return 0 }
        return totalFuelLiters / totalOperatingHours
    }
    var isOverConsumption: Bool {
        guard let baseline = hourlyFuelConsumption, baseline > 0 else { return false }
        return averageFuelConsumption > baseline * 1.15
    }
    var costPerHour: Double {
        guard totalOperatingHours > 0 else { return 0 }
        return totalOperatingCost / totalOperatingHours
    }
    var hasOpenFailure: Bool { failures.contains { !$0.isResolved } }
    var isInsuranceExpiringSoon: Bool {
        guard let d = insuranceExpiryDate else { return false }
        return (Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0) <= 30
    }
    var isInspectionExpiringSoon: Bool {
        guard let d = inspectionExpiryDate else { return false }
        return (Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0) <= 30
    }
}

@Model
final class EquipmentLog {
    var id: UUID
    var date: Date
    var operatingHours: Double
    var fuelLiters: Double?
    var fuelCost: Double?
    var maintenanceNote: String?
    var isMaintenanceDay: Bool
    var operatorName: String?
    var startHourMeter: Double?
    var endHourMeter: Double?
    var location: String?
    var equipment: EquipmentItem?
    @Relationship var operator_: Worker?

    init(date: Date = Date(), operatingHours: Double = 0) {
        self.id = UUID()
        self.date = date
        self.operatingHours = operatingHours
        self.isMaintenanceDay = false
    }
}

// MARK: - Ekipman Arıza / Bakım / Kiralık

enum MaintenanceType: String, Codable, CaseIterable {
    case oilChange        = "Yağ Değişimi"
    case filterChange     = "Filtre Değişimi"
    case beltChange       = "Kayış Değişimi"
    case generalService   = "Genel Bakım"
    case tireChange       = "Lastik Değişimi"
    case hydraulicService = "Hidrolik Bakım"
    case electricalCheck  = "Elektrik Kontrol"
    case other            = "Diğer"
    var icon: String {
        switch self {
        case .oilChange:        return "drop.fill"
        case .filterChange:     return "aqi.medium"
        case .beltChange:       return "link"
        case .generalService:   return "wrench.and.screwdriver"
        case .tireChange:       return "circle.circle"
        case .hydraulicService: return "bolt.fill"
        case .electricalCheck:  return "bolt.circle"
        case .other:            return "gearshape"
        }
    }
}

@Model
final class EquipmentFailure {
    var id: UUID
    var failureDate: Date
    var failureChangeDescription: String
    var repairDate: Date?
    var repairChangeDescription: String?
    var repairCost: Double?
    var spareParts: String?
    var downtimeHours: Double?
    var isResolved: Bool
    var photoData: [Data]
    var createdAt: Date
    @Relationship var equipment: EquipmentItem?

    init(failureDate: Date = Date(), failureChangeDescription: String) {
        self.id = UUID()
        self.failureDate = failureDate
        self.failureChangeDescription = failureChangeDescription
        self.isResolved = false
        self.photoData = []
        self.createdAt = Date()
    }
}

@Model
final class MaintenancePlan {
    var id: UUID
    var maintenanceTypeRaw: String
    var intervalHours: Double
    var lastMaintenanceDate: Date?
    var lastMaintenanceHours: Double?
    var nextDueHours: Double?
    var estimatedCost: Double?
    var notes: String?
    var createdAt: Date
    @Relationship var equipment: EquipmentItem?

    init(maintenanceType: MaintenanceType, intervalHours: Double) {
        self.id = UUID()
        self.maintenanceTypeRaw = maintenanceType.rawValue
        self.intervalHours = intervalHours
        self.createdAt = Date()
    }

    var maintenanceType: MaintenanceType {
        get { MaintenanceType(rawValue: maintenanceTypeRaw) ?? .other }
        set { maintenanceTypeRaw = newValue.rawValue }
    }

    func isDue(currentHours: Double) -> Bool {
        guard let next = nextDueHours else { return false }
        return currentHours >= next
    }
}

@Model
final class RentalContract {
    var id: UUID
    var rentalCompany: String
    var startDate: Date
    var endDate: Date?
    var dailyRate: Double
    var monthlyRate: Double?
    var minimumDays: Int?
    var depositAmount: Double?
    var contractNo: String?
    var penaltyPerDay: Double?
    var notes: String?
    var createdAt: Date
    @Relationship var equipment: EquipmentItem?

    init(rentalCompany: String, startDate: Date = Date(), dailyRate: Double = 0) {
        self.id = UUID()
        self.rentalCompany = rentalCompany
        self.startDate = startDate
        self.dailyRate = dailyRate
        self.createdAt = Date()
    }

    var totalDays: Int {
        let end = endDate ?? Date()
        return max(0, Calendar.current.dateComponents([.day], from: startDate, to: end).day ?? 0)
    }
    var totalCost: Double { Double(totalDays) * dailyRate }
    var daysRemaining: Int? {
        guard let end = endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0
        return max(0, days)
    }
    var isExpiringSoon: Bool {
        guard let rem = daysRemaining else { return false }
        return rem <= 7
    }
}

// MARK: - İSG (Güvenlik)

enum IncidentType: String, Codable, CaseIterable {
    case nearMiss = "Ramak Kala"
    case warning = "Uyarı/İhlal"
    case minorInjury = "Hafif Yaralanma"
    case majorInjury = "Ciddi Yaralanma"

    var icon: String {
        switch self {
        case .nearMiss: return "exclamationmark.triangle"
        case .warning: return "bell.badge"
        case .minorInjury: return "bandage"
        case .majorInjury: return "cross.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .nearMiss: return "hakedisWarning"
        case .warning: return "hakedisInfo"
        case .minorInjury: return "hakedisWarning"
        case .majorInjury: return "hakedisDanger"
        }
    }

}

enum ChecklistType: String, Codable, CaseIterable {
    case toolbox = "Toolbox Toplantısı"
    case ppe = "KKD Kontrolü"
    case dailyInspection = "Günlük Denetim"
    case scaffolding = "İskele Kontrolü"
    case excavation = "Kazı Güvenliği"
}

// MARK: - İSG Derinleştirme Modelleri

enum RiskLevel: String, Codable, CaseIterable {
    case veryLow  = "Çok Düşük"
    case low      = "Düşük"
    case medium   = "Orta"
    case high     = "Yüksek"
    case veryHigh = "Çok Yüksek"

    static func from(score: Int) -> RiskLevel {
        switch score {
        case 1...4:   return .veryLow
        case 5...8:   return .low
        case 9...12:  return .medium
        case 13...19: return .high
        default:      return .veryHigh
        }
    }

    var colorName: String {
        switch self {
        case .veryLow:  return "hakedisSuccess"
        case .low:      return "hakedisInfo"
        case .medium:   return "hakedisWarning"
        case .high:     return "hakedisDanger"
        case .veryHigh: return "hakedisDanger"
        }
    }
}

@Model
final class RiskAssessment {
    var id: UUID
    var assessmentDate: Date
    var location: String
    var activity: String
    var hazard: String
    var likelihood: Int
    var severity: Int
    var existingControls: String?
    var additionalControls: String?
    var responsiblePerson: String?
    var targetDate: Date?
    var isControlled: Bool
    var reassessmentDate: Date?
    var createdAt: Date
    @Relationship var project: Project?

    init(location: String, activity: String, hazard: String, likelihood: Int = 3, severity: Int = 3) {
        self.id = UUID()
        self.assessmentDate = Date()
        self.location = location
        self.activity = activity
        self.hazard = hazard
        self.likelihood = min(5, max(1, likelihood))
        self.severity = min(5, max(1, severity))
        self.isControlled = false
        self.createdAt = Date()
    }

    var riskScore: Int { likelihood * severity }
    var riskLevel: RiskLevel { RiskLevel.from(score: riskScore) }
}

@Model
final class RootCauseAnalysis {
    var id: UUID
    var why1: String
    var why2: String?
    var why3: String?
    var why4: String?
    var why5: String?
    var rootCause: String
    var createdAt: Date
    @Relationship var incident: SafetyIncident?

    init(why1: String, rootCause: String) {
        self.id = UUID()
        self.why1 = why1
        self.rootCause = rootCause
        self.createdAt = Date()
    }
}

enum CorrectiveActionStatus: String, Codable, CaseIterable {
    case open       = "Açık"
    case inProgress = "Devam Ediyor"
    case completed  = "Tamamlandı"
    case overdue    = "Gecikmiş"
    case verified   = "Doğrulandı"

    var icon: String {
        switch self {
        case .open:       return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed:  return "checkmark.circle"
        case .overdue:    return "exclamationmark.circle"
        case .verified:   return "checkmark.seal.fill"
        }
    }
}

@Model
final class CorrectiveAction {
    var id: UUID
    var actionChangeDescription: String
    var responsiblePerson: String
    var assignedDate: Date
    var dueDate: Date
    var completionDate: Date?
    var statusRaw: String
    var verifiedBy: String?
    var verificationDate: Date?
    var verificationNotes: String?
    var photoData: [Data]
    var createdAt: Date
    @Relationship var incident: SafetyIncident?
    @Relationship var project: Project?

    init(actionChangeDescription: String, responsiblePerson: String, dueDate: Date) {
        self.id = UUID()
        self.actionChangeDescription = actionChangeDescription
        self.responsiblePerson = responsiblePerson
        self.assignedDate = Date()
        self.dueDate = dueDate
        self.statusRaw = CorrectiveActionStatus.open.rawValue
        self.photoData = []
        self.createdAt = Date()
    }

    var status: CorrectiveActionStatus {
        get { CorrectiveActionStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var isOverdue: Bool { status != .completed && status != .verified && dueDate < Date() }
}

enum SafetyTrainingType: String, Codable, CaseIterable {
    case orientation    = "İşe Giriş Oryantasyonu"
    case basicOSH       = "Temel İSG Eğitimi"
    case heightWork     = "Yüksekte Çalışma"
    case confinedSpace  = "Kapalı Alan"
    case scaffolding    = "İskele Güvenliği"
    case excavation     = "Kazı Güvenliği"
    case electrical     = "Elektrik Güvenliği"
    case fireEvacuation = "Yangın ve Tahliye"
    case firstAid       = "İlk Yardım"
    case ppe            = "KKD Kullanımı"
    case toolbox        = "Toolbox Eğitimi"
    case emergency      = "Acil Durum Tatbikatı"
    case other          = "Diğer"
}

@Model
final class SafetyTraining {
    var id: UUID
    var trainingDate: Date
    var trainingTypeRaw: String
    var durationHours: Double
    var trainer: String
    var trainerTitle: String?
    var attendeesJSON: String
    var topicsCovered: String
    var notes: String?
    var photoData: Data?
    var createdAt: Date
    @Relationship var project: Project?

    init(trainingType: SafetyTrainingType, trainingDate: Date = Date(), trainer: String, durationHours: Double) {
        self.id = UUID()
        self.trainingTypeRaw = trainingType.rawValue
        self.trainingDate = trainingDate
        self.trainer = trainer
        self.durationHours = durationHours
        self.attendeesJSON = "[]"
        self.topicsCovered = ""
        self.createdAt = Date()
    }

    var trainingType: SafetyTrainingType {
        get { SafetyTrainingType(rawValue: trainingTypeRaw) ?? .other }
        set { trainingTypeRaw = newValue.rawValue }
    }

    var attendees: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(attendeesJSON.utf8))) ?? [] }
        set { attendeesJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }
}

enum PPEType: String, Codable, CaseIterable {
    case hardHat       = "Baret"
    case safetyVest    = "Reflektif Yelek"
    case safetyGlasses = "Koruyucu Gözlük"
    case gloves        = "Eldiven"
    case harness       = "Emniyet Kemeri"
    case safetyBoots   = "Çelik Burunlu Bot"
    case earProtection = "Kulak Koruyucu"
    case dustMask      = "Toz Maskesi"
    case faceShield    = "Yüz Siperi"
    case other         = "Diğer"

    var icon: String {
        switch self {
        case .hardHat:       return "person.crop.circle.fill"
        case .safetyVest:    return "person.text.rectangle"
        case .safetyGlasses: return "eyeglasses"
        case .gloves:        return "hand.raised.fill"
        case .harness:       return "figure.climbing"
        case .safetyBoots:   return "figure.walk"
        case .earProtection: return "ear.fill"
        case .dustMask:      return "facemask.fill"
        case .faceShield:    return "theatermasks.fill"
        case .other:         return "questionmark.circle"
        }
    }
}

enum PPECondition: String, Codable, CaseIterable {
    case newPPE  = "Yeni"
    case good    = "İyi"
    case worn    = "Yıpranmış"
    case damaged = "Hasarlı"
    case returned = "İade Edildi"
}

@Model
final class PPEAssignment {
    var id: UUID
    var ppeTypeRaw: String
    var assignedDate: Date
    var returnDate: Date?
    var conditionRaw: String
    var serialNo: String?
    var createdAt: Date
    @Relationship var worker: Worker?
    @Relationship var project: Project?

    init(ppeType: PPEType, assignedDate: Date = Date()) {
        self.id = UUID()
        self.ppeTypeRaw = ppeType.rawValue
        self.conditionRaw = PPECondition.newPPE.rawValue
        self.assignedDate = assignedDate
        self.createdAt = Date()
    }

    var ppeType: PPEType {
        get { PPEType(rawValue: ppeTypeRaw) ?? .other }
        set { ppeTypeRaw = newValue.rawValue }
    }

    var condition: PPECondition {
        get { PPECondition(rawValue: conditionRaw) ?? .good }
        set { conditionRaw = newValue.rawValue }
    }
}

enum EmergencyPlanType: String, Codable, CaseIterable {
    case fire        = "Yangın"
    case earthquake  = "Deprem"
    case workAccident = "İş Kazası"
    case chemicalSpill = "Kimyasal Dökülme"
    case collapse    = "Göçük"
    case other       = "Diğer"

    var icon: String {
        switch self {
        case .fire:          return "flame.fill"
        case .earthquake:    return "waveform.path.ecg"
        case .workAccident:  return "cross.circle.fill"
        case .chemicalSpill: return "drop.triangle.fill"
        case .collapse:      return "building.2"
        case .other:         return "exclamationmark.triangle.fill"
        }
    }
}

@Model
final class EmergencyPlan {
    var id: UUID
    var planTypeRaw: String
    var procedures: String
    var assemblyPoint: String
    var emergencyContacts: String  // JSON encoded
    var lastDrillDate: Date?
    var nextDrillDate: Date?
    var createdAt: Date
    @Relationship var project: Project?

    init(planType: EmergencyPlanType, procedures: String, assemblyPoint: String) {
        self.id = UUID()
        self.planTypeRaw = planType.rawValue
        self.procedures = procedures
        self.assemblyPoint = assemblyPoint
        self.emergencyContacts = "[]"
        self.createdAt = Date()
    }

    var planType: EmergencyPlanType {
        get { EmergencyPlanType(rawValue: planTypeRaw) ?? .other }
        set { planTypeRaw = newValue.rawValue }
    }

    var isDrillOverdue: Bool {
        guard let next = nextDrillDate else { return false }
        return next < Date()
    }
}

@Model
final class SafetyIncident {
    var id: UUID
    var date: Date
    var incidentType: IncidentType
    var incidentDescription: String
    var location: String?
    var involvedWorker: String?
    var actionsTaken: String?
    var preventiveMeasures: String?
    var photoData: [Data]
    var isResolved: Bool
    var lostWorkDays: Int?
    var reportedToSGK: Bool
    var reportedToMinistry: Bool
    var project: Project?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var rootCauseAnalysis: RootCauseAnalysis?
    @Relationship(deleteRule: .cascade) var correctiveActions: [CorrectiveAction]

    init(date: Date = Date(), incidentType: IncidentType, incidentDescription: String) {
        self.id = UUID()
        self.date = date
        self.incidentType = incidentType
        self.incidentDescription = incidentDescription
        self.photoData = []
        self.isResolved = false
        self.reportedToSGK = false
        self.reportedToMinistry = false
        self.correctiveActions = []
        self.createdAt = Date()
    }

    var sgkReportDeadline: Date {
        var days = 0
        var current = date
        while days < 3 {
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
            let weekday = Calendar.current.component(.weekday, from: current)
            if weekday != 1 && weekday != 7 { days += 1 }
        }
        return current
    }

    var ministryReportDeadline: Date {
        var days = 0
        var current = date
        while days < 2 {
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
            let weekday = Calendar.current.component(.weekday, from: current)
            if weekday != 1 && weekday != 7 { days += 1 }
        }
        return current
    }

    var isSGKDeadlineApproaching: Bool {
        !reportedToSGK && Date() <= sgkReportDeadline
    }
    var isSGKDeadlineOverdue: Bool {
        !reportedToSGK && Date() > sgkReportDeadline
    }
}

@Model
final class SafetyChecklist {
    var id: UUID
    var date: Date
    var checklistType: ChecklistType
    var items: String  // JSON encoded [ChecklistItem]
    var completedBy: String
    var notes: String?
    var project: Project?
    var createdAt: Date

    init(date: Date = Date(), checklistType: ChecklistType, completedBy: String) {
        self.id = UUID()
        self.date = date
        self.checklistType = checklistType
        self.items = "[]"
        self.completedBy = completedBy
        self.createdAt = Date()
    }
}

struct ChecklistItem: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var isChecked: Bool = false
    var note: String = ""
}

// MARK: - Ataşman / Yeşil Defter

@Model
final class AttachmentRecord {
    var id: UUID
    var attachmentNo: Int
    var location: String
    var length: Double?
    var width: Double?
    var height: Double?
    var quantity: Double?
    var notes: String?
    var sketchPhotoData: Data?
    var formula: String?
    @Relationship var workItem: WorkItem?
    @Relationship var hakedis: Hakedis?
    var createdAt: Date

    init(attachmentNo: Int, location: String) {
        self.id = UUID()
        self.attachmentNo = attachmentNo
        self.location = location
        self.createdAt = Date()
    }

    /// L×W×H, L×W veya direkt miktar
    var calculatedQuantity: Double {
        if let l = length, let w = width, let h = height {
            return l * w * h
        } else if let l = length, let w = width {
            return l * w
        } else {
            return quantity ?? 0
        }
    }

    /// Hesaplama formülü açıklaması
    var formulaDescription: String {
        if let l = length, let w = width, let h = height {
            return String(format: "%.3g × %.3g × %.3g = %.4g", l, w, h, calculatedQuantity)
        } else if let l = length, let w = width {
            return String(format: "%.3g × %.3g = %.4g", l, w, calculatedQuantity)
        } else if let q = quantity {
            return String(format: "%.4g", q)
        }
        return "0"
    }
}

// MARK: - Fiyat Farkı Hesaplama (4735 Md.8)

@Model
final class PriceDifferenceCalc {
    var id: UUID
    var baseMonth: String          // Baz ayı: "2025-01"
    var applicationMonth: String   // Uygulama ayı: "2026-03"
    var a1: Double                 // İşçilik ağırlık katsayısı
    var a2: Double                 // Malzeme
    var a3: Double                 // Enerji
    var a4: Double                 // Makine amortismanı
    var a5: Double                 // Genel giderler + kâr (sabit 0.12)
    var index1Base: Double
    var index1Current: Double
    var index2Base: Double
    var index2Current: Double
    var index3Base: Double
    var index3Current: Double
    var index4Base: Double
    var index4Current: Double
    var hakedisAmount: Double
    @Relationship var contract: Contract?
    var createdAt: Date

    init(baseMonth: String, applicationMonth: String) {
        self.id = UUID()
        self.baseMonth = baseMonth
        self.applicationMonth = applicationMonth
        self.a1 = 0.25; self.a2 = 0.30; self.a3 = 0.15; self.a4 = 0.28; self.a5 = 0.12
        self.index1Base = 100; self.index1Current = 100
        self.index2Base = 100; self.index2Current = 100
        self.index3Base = 100; self.index3Current = 100
        self.index4Base = 100; self.index4Current = 100
        self.hakedisAmount = 0
        self.createdAt = Date()
    }

    /// Pn = a1×(İ1n/İ1₀) + a2×(İ2n/İ2₀) + a3×(İ3n/İ3₀) + a4×(İ4n/İ4₀) + a5
    var pnValue: Double {
        guard index1Base > 0, index2Base > 0, index3Base > 0, index4Base > 0 else { return 1.0 }
        return a1 * (index1Current / index1Base)
             + a2 * (index2Current / index2Base)
             + a3 * (index3Current / index3Base)
             + a4 * (index4Current / index4Base)
             + a5
    }

    /// F = An × (Pn - 1)
    var priceDifferenceAmount: Double { hakedisAmount * (pnValue - 1) }
}

// MARK: - Taşeron Hakediş

@Model
final class SubcontractorHakedis {
    var id: UUID
    var periodName: String
    var periodStart: Date
    var periodEnd: Date
    var grossAmount: Double
    var retentionAmount: Double
    var netAmount: Double
    var statusRaw: String
    @Relationship var contractor: Contractor?
    @Relationship var contract: Contract?
    var notes: String?
    var createdAt: Date

    init(periodName: String, periodStart: Date, periodEnd: Date) {
        self.id = UUID()
        self.periodName = periodName
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.grossAmount = 0
        self.retentionAmount = 0
        self.netAmount = 0
        self.statusRaw = HakedisStatus.draft.rawValue
        self.createdAt = Date()
    }

    var status: HakedisStatus {
        get { HakedisStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var profitMargin: Double {
        guard grossAmount > 0 else { return 0 }
        return (grossAmount - netAmount) / grossAmount * 100
    }
}

// MARK: - Kalite Kontrol Listesi

enum QualityChecklistType: String, Codable, CaseIterable {
    case concretePour    = "Beton Döküm"
    case reinforcement   = "Demir Donatı"
    case waterproofing   = "Su Yalıtım"
    case heatInsulation  = "Isı Yalıtım"
    case mechanical      = "Mekanik Tesisat"
    case electrical      = "Elektrik Tesisat"
    case elevator        = "Asansör"
    case steel           = "Çelik Konstrüksiyon"
    case plastering      = "Sıva"
    case painting        = "Boya"
    case general         = "Genel Kontrol"

    var defaultItems: [String] {
        switch self {
        case .concretePour:   return ["Kalıp kontrolü", "Donatı kontrolü", "Slump testi", "Küp numune alındı", "Beton sınıfı doğrulandı", "Dökme izni alındı"]
        case .reinforcement:  return ["Çap ve aralıklar uygun", "Bindirme boyu yeterli", "Pas payı standartlara uygun", "Filiz konumları kontrol edildi"]
        case .waterproofing:  return ["Yüzey temiz ve kuru", "Membran katman kalınlığı", "Birleşim yerleri kaplı", "Test suyu uygulandı"]
        case .heatInsulation: return ["Malzeme tipi ve kalınlığı", "Uygulama yüzeyi temiz", "Derz mesafeleri", "Dış köşe profilleri", "Mantar dübel aralıkları", "Isı köprüsü kontrolü", "Fire kesim uygunluğu", "Alt kat bağlantısı", "Sıva takviye filesi", "Derz bantları", "Su uzaklaştırma", "Onay kontrolü"]
        case .mechanical:     return ["Boru tipleri ve çapları", "Boru bağlantıları sızdırmaz", "Askı ve destek aralıkları", "Vana konumları", "Yalıtım kalınlıkları", "Basınç testi yapıldı", "Pis su eğimleri", "Temiz su hattı debi", "Kazan odası güvenliği", "Yangın söndürme sistemi", "Su sayacı konumu", "Onay belgesi"]
        case .electrical:     return ["Kablo tipleri ve kesitleri", "Topraklama sistemi", "Panolar ve şalterler", "Aydınlatma devre kontrolü", "Priz devre kontrolü", "Güç devre kontrolü", "DUYLU test edildi", "Sigorta seçimi", "Kablo izolasyon testi", "Kaçak akım rölesi", "Faz dengeleme", "Onay belgesi"]
        case .elevator:       return ["Kuyu boyutları uygun", "Makine dairesi erişim", "Emniyet donanımları", "Kablo ve zincir kontrolü", "Kabin seviyesi ayarı", "Kapı kilitleri", "Aşırı yük sensörü", "Hız sınırlayıcı", "Akustik ölçüm", "Bakım sözleşmesi"]
        case .steel:          return ["Profil boyut ve kalitesi", "Kaynak kalitesi (gözle)", "Cıvata sıkma kontrolü", "Boyama ve kaplama", "Ankraj levhası bağlantısı", "Kolon-kiriş birleşimi", "Kiriş sehim kontrolü", "Eğik bağlantılar", "Yangın koruma kaplama", "TS 648 uygunluğu", "Proje uyumu", "Onay belgesi"]
        case .plastering:     return ["Yüzey düzlüğü kontrol edildi", "Köşe profilleri takıldı", "Kalınlık uygun", "Çatlak kontrolü"]
        case .painting:       return ["Yüzey astarlandı", "Kat sayısı doğrulandı", "Renk uygunluğu", "Yüzey pürüzsüz"]
        case .general:        return ["KKD kontrolü", "Çalışma alanı güvenli", "Malzeme kalitesi uygun", "İş yöntemi onaylı", "Proje uyumu", "Zorunlu belgeler", "Personel yeterliliği", "Ekipman uygunluğu"]
        }
    }
}

enum CheckResult: String, Codable, CaseIterable {
    case pass        = "Uygun"
    case fail        = "Uygunsuz"
    case conditional = "Şartlı Uygun"

    var color: String {
        switch self {
        case .pass:        return "hakedisSuccess"
        case .fail:        return "hakedisDanger"
        case .conditional: return "hakedisWarning"
        }
    }
}

enum ItemResult: String, Codable, CaseIterable {
    case pass          = "Uygun"
    case fail          = "Uygunsuz"
    case notApplicable = "Uygulanamaz"

    var icon: String {
        switch self {
        case .pass:          return "checkmark.circle.fill"
        case .fail:          return "xmark.circle.fill"
        case .notApplicable: return "minus.circle"
        }
    }
    var colorName: String {
        switch self {
        case .pass:          return "hakedisSuccess"
        case .fail:          return "hakedisDanger"
        case .notApplicable: return "secondary"
        }
    }
}

struct QualityCheckItem: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var isChecked: Bool = false   // backward compat
    var note: String = ""         // backward compat
    var result: ItemResult? = nil // expanded field
    var photoRequired: Bool = false
    var hasPhoto: Bool = false

    // Effective result: new field takes priority over legacy isChecked
    var effectiveResult: ItemResult {
        get { result ?? (isChecked ? .pass : .fail) }
        set { result = newValue; isChecked = (newValue == .pass) }
    }
}

@Model
final class QualityChecklist {
    var id: UUID
    var checklistTypeRaw: String
    var date: Date
    var checkedBy: String
    var itemsJSON: String
    var overallResultRaw: String
    var photoData: [Data]
    var notes: String?
    var location: String?
    @Relationship var workItem: WorkItem?
    @Relationship var contract: Contract?
    @Relationship var attachedIncident: SafetyIncident?
    var createdAt: Date

    init(checklistType: QualityChecklistType, date: Date = Date(), checkedBy: String) {
        self.id = UUID()
        self.checklistTypeRaw = checklistType.rawValue
        self.date = date
        self.checkedBy = checkedBy
        self.overallResultRaw = CheckResult.pass.rawValue
        self.photoData = []
        self.createdAt = Date()
        // Varsayılan maddeler
        let items = checklistType.defaultItems.map { QualityCheckItem(title: $0) }
        self.itemsJSON = (try? String(data: JSONEncoder().encode(items), encoding: .utf8)) ?? "[]"
    }

    var checklistType: QualityChecklistType {
        get { QualityChecklistType(rawValue: checklistTypeRaw) ?? .general }
        set { checklistTypeRaw = newValue.rawValue }
    }
    var overallResult: CheckResult {
        get { CheckResult(rawValue: overallResultRaw) ?? .pass }
        set { overallResultRaw = newValue.rawValue }
    }
    var checkItems: [QualityCheckItem] {
        get { (try? JSONDecoder().decode([QualityCheckItem].self, from: Data(itemsJSON.utf8))) ?? [] }
        set { itemsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }
    var passedCount: Int { checkItems.filter { $0.effectiveResult == .pass }.count }
    var failedCount: Int { checkItems.filter { $0.effectiveResult == .fail }.count }
    var applicableCount: Int { checkItems.filter { $0.effectiveResult != .notApplicable }.count }
    var totalCount: Int { checkItems.count }
    var overallScore: Double {
        guard applicableCount > 0 else { return 0 }
        return Double(passedCount) / Double(applicableCount) * 100
    }
    var hasFailures: Bool { failedCount > 0 }
}

// MARK: - Süre Uzatımı Talebi

@Model
final class TimeExtensionRequest {
    var id: UUID
    var requestDate: Date
    var extensionDays: Int
    var reasonCode: String      // "Mücbir Sebep", "İdare Kaynaklı", "Hava Şartları" vs
    var reasonDetails: String
    var statusRaw: String       // "Bekliyor", "Onaylandı", "Reddedildi"
    @Relationship var contract: Contract?
    var createdAt: Date

    init(extensionDays: Int, reasonCode: String, reasonDetails: String) {
        self.id = UUID()
        self.requestDate = Date()
        self.extensionDays = extensionDays
        self.reasonCode = reasonCode
        self.reasonDetails = reasonDetails
        self.statusRaw = "Bekliyor"
        self.createdAt = Date()
    }

    var status: String { statusRaw }
    var isApproved: Bool { statusRaw == "Onaylandı" }
}

// MARK: - İlerleme Raporu

@Model
final class ProgressReport {
    var id: UUID
    var reportPeriod: String
    var beforePhotoData: [Data]
    var afterPhotoData: [Data]
    var completionPercentage: Double
    var summaryText: String
    @Relationship var project: Project?
    var createdAt: Date

    init(reportPeriod: String, completionPercentage: Double = 0, summaryText: String = "") {
        self.id = UUID()
        self.reportPeriod = reportPeriod
        self.completionPercentage = completionPercentage
        self.summaryText = summaryText
        self.beforePhotoData = []
        self.afterPhotoData = []
        self.createdAt = Date()
    }
}

// MARK: - İş Artışı / Eksilişi Emri

@Model
final class WorkChangeOrder {
    var id: UUID
    var orderDate: Date
    var orderNo: String
    var changeType: String      // "Artış", "Eksilişi", "Keşif Revizyonu"
    var changePercent: Double   // % olarak
    var changeAmount: Double    // TL olarak
    var changeDescription: String
    var statusRaw: String       // "Taslak", "Onaylandı", "Reddedildi"
    @Relationship var contract: Contract?
    var createdAt: Date

    init(orderNo: String, changeType: String, changePercent: Double, changeAmount: Double, description: String) {
        self.id = UUID()
        self.orderDate = Date()
        self.orderNo = orderNo
        self.changeType = changeType
        self.changePercent = changePercent
        self.changeAmount = changeAmount
        self.changeDescription = description
        self.statusRaw = "Taslak"
        self.createdAt = Date()
    }

    var isApproved: Bool { statusRaw == "Onaylandı" }
    var exceedsLimit: Bool { abs(changePercent) > 20 }  // 4735 Md.15: %20 sınırı
}

// MARK: - İşçi Veritabanı (Worker)

enum WorkerProfession: String, Codable, CaseIterable {
    case carpenter    = "Kalıpçı"
    case ironworker   = "Demirci"
    case laborer      = "Düz İşçi"
    case painter      = "Boyacı"
    case plumber      = "Tesisatçı"
    case electrician  = "Elektrikçi"
    case operator_    = "Operatör"
    case foreman      = "Usta"
    case technician   = "Tekniker"
    case engineer     = "Mühendis"
    case welder       = "Kaynakçı"
    case insulator    = "Yalıtımcı"
    case tiler        = "Fayansçı"
    case other        = "Diğer"

    var icon: String {
        switch self {
        case .carpenter:   return "hammer"
        case .ironworker:  return "wrench"
        case .laborer:     return "figure.walk"
        case .painter:     return "paintbrush"
        case .plumber:     return "drop"
        case .electrician: return "bolt"
        case .operator_:   return "gearshape"
        case .foreman:     return "star"
        case .technician:  return "wrench.adjustable"
        case .engineer:    return "graduationcap"
        case .welder:      return "flame"
        case .insulator:   return "thermometer.snowflake"
        case .tiler:       return "square.grid.2x2"
        case .other:       return "person"
        }
    }
}

enum BloodType: String, Codable, CaseIterable {
    case aPlus  = "A Rh+"
    case aMinus = "A Rh-"
    case bPlus  = "B Rh+"
    case bMinus = "B Rh-"
    case abPlus  = "AB Rh+"
    case abMinus = "AB Rh-"
    case oPlus  = "0 Rh+"
    case oMinus = "0 Rh-"
}

enum CertificateType: String, Codable, CaseIterable {
    case scaffolding    = "İskele Kurulum"
    case craneOperator  = "Vinç Operatörü"
    case forklift       = "Forklift Operatörü"
    case osgTraining    = "İSG Eğitimi"
    case welding        = "Kaynak Belgesi"
    case heightWork     = "Yüksekte Çalışma"
    case firstAid       = "İlk Yardım"
    case driverLicense  = "Ehliyet"
    case other          = "Diğer"

    var requiredRenewalMonths: Int? {
        switch self {
        case .osgTraining: return 12
        case .firstAid:    return 36
        case .heightWork:  return 12
        default:           return nil
        }
    }

    var icon: String {
        switch self {
        case .scaffolding:   return "building.columns"
        case .craneOperator: return "arrow.up.and.down"
        case .forklift:      return "fork.knife"
        case .osgTraining:   return "heart.circle"
        case .welding:       return "flame"
        case .heightWork:    return "figure.climbing"
        case .firstAid:      return "cross.case"
        case .driverLicense: return "car"
        case .other:         return "doc.badge.checkmark"
        }
    }
}

@Model
final class Worker {
    var id: UUID
    var fullName: String
    var tcKimlikNo: String?
    var birthDate: Date?
    var bloodTypeRaw: String?
    var professionRaw: String
    var emergencyContactName: String?
    var emergencyContactPhone: String?
    var sgkSicilNo: String?
    var dailyCost: Double
    var hourlyCost: Double
    @Relationship var contractor: Contractor?
    @Relationship(deleteRule: .cascade) var certificates: [WorkerCertificate]
    @Relationship(deleteRule: .cascade) var attendances: [Attendance]
    var isActive: Bool
    var createdAt: Date

    init(fullName: String, profession: WorkerProfession = .laborer, dailyCost: Double = 0, hourlyCost: Double = 0) {
        self.id = UUID()
        self.fullName = fullName
        self.professionRaw = profession.rawValue
        self.dailyCost = dailyCost
        self.hourlyCost = hourlyCost
        self.isActive = true
        self.certificates = []
        self.attendances = []
        self.createdAt = Date()
    }

    var profession: WorkerProfession {
        get { WorkerProfession(rawValue: professionRaw) ?? .other }
        set { professionRaw = newValue.rawValue }
    }
    var bloodType: BloodType? {
        get { bloodTypeRaw.flatMap { BloodType(rawValue: $0) } }
        set { bloodTypeRaw = newValue?.rawValue }
    }

    // 4857 Md.53 yıllık izin hakkı
    func annualLeaveDays(since startDate: Date) -> Int {
        let years = Calendar.current.dateComponents([.year], from: startDate, to: Date()).year ?? 0
        switch years {
        case 0..<1:   return 0
        case 1..<5:   return 14
        case 5..<15:  return 20
        default:      return 26
        }
    }

    // Süresi dolan veya yakında dolacak sertifikalar
    func expiringSoonCertificates(within days: Int = 30) -> [WorkerCertificate] {
        let threshold = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return certificates.filter { cert in
            guard let expiry = cert.expiryDate else { return false }
            return expiry <= threshold
        }
    }
}

@Model
final class WorkerCertificate {
    var id: UUID
    var certificateTypeRaw: String
    var issueDate: Date
    var expiryDate: Date?
    var issuingAuthority: String?
    var certificateNo: String?
    @Relationship var worker: Worker?
    var createdAt: Date

    init(certificateType: CertificateType, issueDate: Date = Date()) {
        self.id = UUID()
        self.certificateTypeRaw = certificateType.rawValue
        self.issueDate = issueDate
        self.createdAt = Date()
    }

    var certificateType: CertificateType {
        get { CertificateType(rawValue: certificateTypeRaw) ?? .other }
        set { certificateTypeRaw = newValue.rawValue }
    }

    var isExpired: Bool {
        guard let exp = expiryDate else { return false }
        return exp < Date()
    }

    var isExpiringSoon: Bool {
        guard let exp = expiryDate else { return false }
        let threshold = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return !isExpired && exp <= threshold
    }

    var daysUntilExpiry: Int? {
        guard let exp = expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: exp).day
    }
}

// MARK: - A6 Hakediş Son Dokunuşlar

enum FinalAccountStatus: String, Codable, CaseIterable {
    case draft     = "Taslak"
    case submitted = "Gönderildi"
    case approved  = "Onaylandı"

    var icon: String {
        switch self {
        case .draft:     return "doc"
        case .submitted: return "paperplane.fill"
        case .approved:  return "checkmark.seal.fill"
        }
    }
}

@Model
final class FinalAccount {
    var id: UUID
    var calculationDate: Date
    var totalContractAmount: Double
    var totalHakedisAmount: Double
    var totalWorkIncrease: Double
    var totalWorkDecrease: Double
    var totalPriceDifference: Double
    var totalRetentionAccrued: Double
    var totalRetentionReleased: Double
    var retentionBalance: Double
    var totalPenalty: Double
    var totalPayments: Double
    var statusRaw: String
    var notes: String?
    @Relationship var contract: Contract?
    var createdAt: Date

    init(contract: Contract? = nil) {
        self.id = UUID()
        self.calculationDate = Date()
        self.createdAt = Date()
        self.statusRaw = FinalAccountStatus.draft.rawValue

        guard let c = contract else {
            self.totalContractAmount = 0; self.totalHakedisAmount = 0
            self.totalWorkIncrease = 0; self.totalWorkDecrease = 0
            self.totalPriceDifference = 0; self.totalRetentionAccrued = 0
            self.totalRetentionReleased = 0; self.retentionBalance = 0
            self.totalPenalty = 0; self.totalPayments = 0
            self.contract = nil
            return
        }

        self.contract = c
        self.totalContractAmount = c.totalContractAmount

        let approvedHakedisler = c.hakedisler.filter { $0.status == .approved || $0.status == .paid }
        self.totalHakedisAmount = approvedHakedisler.reduce(0) { $0 + $1.effectiveGrossAmount }
        self.totalPayments = approvedHakedisler.reduce(0) { $0 + $1.totalPaid }
        self.totalRetentionAccrued = c.totalRetentionAccrued
        self.totalRetentionReleased = c.totalRetentionReleased
        self.retentionBalance = c.retentionBalance
        self.totalPenalty = c.delayPenalty()

        // WorkChangeOrder artış/eksilişleri
        let changeOrders = c.workItems.flatMap { _ in [Double]() } // placeholder
        self.totalWorkIncrease = 0
        self.totalWorkDecrease = 0
        self.totalPriceDifference = 0
    }

    var status: FinalAccountStatus {
        get { FinalAccountStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var finalBalance: Double {
        totalHakedisAmount + totalWorkIncrease - totalWorkDecrease + totalPriceDifference - totalPenalty - totalPayments
    }
}

enum AuditAction: String, Codable, CaseIterable {
    case created       = "Oluşturuldu"
    case edited        = "Düzenlendi"
    case submitted     = "Onaya Gönderildi"
    case approved      = "Onaylandı"
    case rejected      = "Reddedildi"
    case paid          = "Ödendi"
    case copied        = "Kopyalandı"
    case deleted       = "Silindi"
    case paymentAdded  = "Ödeme Eklendi"
    case paymentDeleted = "Ödeme Silindi"

    var icon: String {
        switch self {
        case .created:       return "plus.circle.fill"
        case .edited:        return "pencil.circle.fill"
        case .submitted:     return "paperplane.fill"
        case .approved:      return "checkmark.seal.fill"
        case .rejected:      return "xmark.seal.fill"
        case .paid:          return "banknote.fill"
        case .copied:        return "doc.on.doc.fill"
        case .deleted:       return "trash.fill"
        case .paymentAdded:  return "plus.circle"
        case .paymentDeleted: return "minus.circle"
        }
    }
}

@Model
final class HakedisAuditLog {
    var id: UUID
    var timestamp: Date
    var actionRaw: String
    var performedBy: String
    var details: String?
    @Relationship var hakedis: Hakedis?
    var createdAt: Date

    init(action: AuditAction, performedBy: String, details: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.actionRaw = action.rawValue
        self.performedBy = performedBy
        self.details = details
        self.createdAt = Date()
    }

    var action: AuditAction {
        get { AuditAction(rawValue: actionRaw) ?? .edited }
        set { actionRaw = newValue.rawValue }
    }
}

@Model
final class HakedisTemplate {
    var id: UUID
    var templateName: String
    var headerText: String
    var footerText: String
    // JSON-encoded [String] of section keys: "workItems", "payments", "retentionSummary", "signatureBlock"
    var sectionsJSON: String
    var isDefault: Bool
    var createdAt: Date

    init(templateName: String) {
        self.id = UUID()
        self.templateName = templateName
        self.headerText = ""
        self.footerText = ""
        self.isDefault = false
        self.createdAt = Date()
        let defaultSections = ["workItems", "payments", "retentionSummary", "approvalChain", "signatureBlock"]
        self.sectionsJSON = (try? String(data: JSONEncoder().encode(defaultSections), encoding: .utf8)) ?? "[]"
    }

    var sections: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(sectionsJSON.utf8))) ?? [] }
        set { sectionsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var sectionLabels: [String: String] {
        [
            "workItems": "İş Kalemleri Tablosu",
            "payments": "Ödeme Özeti",
            "retentionSummary": "Teminat Özeti",
            "approvalChain": "Onay Zinciri",
            "signatureBlock": "İmza Bloğu",
            "penaltySummary": "Gecikme Cezası",
            "advanceSummary": "Avans Özeti",
            "priceDifference": "Fiyat Farkı"
        ]
    }
}

// MARK: - A7 Kalite Kontrol Derinleştirme

enum NCRStatus: String, Codable, CaseIterable {
    case open                = "Açık"
    case correctionProposed  = "Düzeltme Önerildi"
    case correctionInProgress = "Düzeltme Devam"
    case correctionDone      = "Düzeltme Yapıldı"
    case verified            = "Doğrulandı"
    case closed              = "Kapatıldı"

    var icon: String {
        switch self {
        case .open:               return "exclamationmark.circle.fill"
        case .correctionProposed:  return "doc.fill"
        case .correctionInProgress: return "gear.circle.fill"
        case .correctionDone:     return "checkmark.circle"
        case .verified:           return "checkmark.seal.fill"
        case .closed:             return "lock.circle.fill"
        }
    }
    var colorName: String {
        switch self {
        case .open:               return "hakedisDanger"
        case .correctionProposed:  return "hakedisWarning"
        case .correctionInProgress: return "hakedisWarning"
        case .correctionDone:     return "hakedisInfo"
        case .verified:           return "hakedisSuccess"
        case .closed:             return "secondary"
        }
    }
}

@Model
final class NonConformanceReport {
    var id: UUID
    var ncrNo: String
    var detectionDate: Date
    var location: String
    var nonConformanceDescription: String
    var affectedWorkItem: String?
    var detectedBy: String
    var rootCause: String?
    var proposedCorrection: String?
    var correctionDeadline: Date?
    var correctionDate: Date?
    var correctionChangeDescription: String?
    var verifiedBy: String?
    var verificationDate: Date?
    var statusRaw: String
    var photoData: [Data]
    @Relationship var checklist: QualityChecklist?
    @Relationship var contract: Contract?
    var createdAt: Date

    init(ncrNo: String, location: String, nonConformanceDescription: String, detectedBy: String) {
        self.id = UUID()
        self.ncrNo = ncrNo
        self.detectionDate = Date()
        self.location = location
        self.nonConformanceDescription = nonConformanceDescription
        self.detectedBy = detectedBy
        self.statusRaw = NCRStatus.open.rawValue
        self.photoData = []
        self.createdAt = Date()
    }

    var status: NCRStatus {
        get { NCRStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let deadline = correctionDeadline,
              status != .correctionDone, status != .verified, status != .closed
        else { return false }
        return deadline < Date()
    }

    static func generateNCRNo(existingCount: Int, year: Int? = nil) -> String {
        let y = year ?? Calendar.current.component(.year, from: Date())
        return String(format: "NCR-%d-%03d", y, existingCount + 1)
    }
}

// MARK: - QualityChecklistTemplateProvider

struct QualityChecklistTemplateProvider {

    static func items(for type: QualityChecklistType) -> [QualityCheckItem] {
        switch type {
        case .concretePour:
            return [
                item("Kalıp temizliği ve yağlanması yapıldı mı"),
                item("Kalıp ölçüleri projeye uygun mu"),
                item("Donatı montajı kontrol edildi mi"),
                item("Paspayı kontrol edildi mi (min 25mm)", photoRequired: true),
                item("Bindirme boyları kontrol edildi mi"),
                item("Elektrik/mekanik boru geçişleri tamamlandı mı"),
                item("Beton sipariş fişi kontrol edildi mi (sınıf, slump, miktar)"),
                item("Beton pompası ve hortum temiz mi"),
                item("Vibratör hazır mı (yedek dahil)"),
                item("Slump testi yapıldı mı", photoRequired: true),
                item("Hava sıcaklığı beton dökümüne uygun mu (>5°C, <35°C)"),
                item("Küp numune alındı mı (7 ve 28 günlük)", photoRequired: true),
                item("Numune etiketleri yazıldı mı"),
                item("Kür önlemleri planlandı mı"),
                item("İSG önlemleri alındı mı (baret, çizme, gözlük)")
            ]
        case .reinforcement:
            return [
                item("Demir çap kontrolü (proje ile uyum)", photoRequired: true),
                item("Demir sınıfı kontrolü (S420/S500)"),
                item("Çekme testi sonucu uygun mu"),
                item("Donatı yerleşim planı kontrol edildi mi"),
                item("Bindirme boyları uygun mu (40Ø / 50Ø)"),
                item("Etriye aralıkları kontrol edildi mi"),
                item("Kancalar uygun mu (135°/90°)"),
                item("Paspayı takozları yerleştirildi mi"),
                item("Donatı temiz mi (pas, yağ, toprak yok mu)"),
                item("Ek yerlerinin konumları doğru mu"),
                item("Filiz boyları yeterli mi"),
                item("Sehpa demiri yerleştirildi mi"),
                item("Donatı bağlantıları sağlam mı"),
                item("Proje mühendisi donatı kontrolünü onayladı mı")
            ]
        case .waterproofing:
            return [
                item("Yüzey temiz ve kuru mu"),
                item("Köşe pahları yapıldı mı"),
                item("Primer sürüldü mü (bekleme süresi uygun mu)"),
                item("Membran tipi projeye uygun mu"),
                item("Membran kalınlığı kontrol edildi mi"),
                item("Bindirme genişliği uygun mu (min 10cm)"),
                item("Detay noktaları işlendi mi (boru geçişi, derz)", photoRequired: true),
                item("Su testi yapıldı mı (48 saat)"),
                item("Koruma tabakası/betonu planlandı mı"),
                item("Fotoğraflı kayıt alındı mı", photoRequired: true)
            ]
        case .heatInsulation:
            return [
                item("Malzeme tipi ve kalınlığı projeye uygun"),
                item("Uygulama yüzeyi temiz ve düz"),
                item("Derz mesafeleri uygun"),
                item("Dış köşe profilleri yerleştirildi"),
                item("Mantar dübel aralıkları standart"),
                item("Isı köprüsü önlendi mi"),
                item("Fire kesim uygunluğu"),
                item("Alt kat bağlantısı güvenli"),
                item("Sıva takviye filesi düzgün"),
                item("Derz bantları yerleştirildi"),
                item("Su uzaklaştırma sağlandı"),
                item("Onay belgesi mevcut")
            ]
        case .mechanical:
            return [
                item("Boru tipleri ve çapları uygun"),
                item("Boru bağlantıları sızdırmaz"),
                item("Askı ve destek aralıkları standart"),
                item("Vana konumları erişilebilir"),
                item("Yalıtım kalınlıkları uygun"),
                item("Basınç testi yapıldı mı", photoRequired: true),
                item("Pis su eğimleri uygun (min %2)"),
                item("Temiz su hattı debi yeterli"),
                item("Kazan odası güvenliği sağlandı"),
                item("Yangın söndürme sistemi kontrol edildi"),
                item("Su sayacı konumu erişilebilir"),
                item("Onay belgesi mevcut")
            ]
        case .electrical:
            return [
                item("Kablo tipleri ve kesitleri uygun"),
                item("Topraklama sistemi kontrol edildi"),
                item("Panolar ve şalterler takıldı"),
                item("Aydınlatma devre kontrolü yapıldı"),
                item("Priz devre kontrolü yapıldı"),
                item("Güç devre kontrolü yapıldı"),
                item("DUYLU test edildi"),
                item("Sigorta seçimi doğru"),
                item("Kablo izolasyon testi yapıldı"),
                item("Kaçak akım rölesi kontrol edildi"),
                item("Faz dengelemesi yapıldı"),
                item("Onay belgesi mevcut")
            ]
        case .elevator:
            return [
                item("Kuyu boyutları projeye uygun"),
                item("Makine dairesi erişimi uygun"),
                item("Emniyet donanımları mevcut"),
                item("Kablo ve zincir kontrolü yapıldı"),
                item("Kabin seviyesi ayarı doğru"),
                item("Kapı kilitleri çalışıyor"),
                item("Aşırı yük sensörü test edildi"),
                item("Hız sınırlayıcı kontrol edildi"),
                item("Akustik ölçüm yapıldı"),
                item("Bakım sözleşmesi imzalandı")
            ]
        case .steel:
            return [
                item("Profil boyut ve kalitesi uygun"),
                item("Kaynak kalitesi gözle kontrolü", photoRequired: true),
                item("Cıvata sıkma kontrolü yapıldı"),
                item("Boyama ve kaplama uygun"),
                item("Ankraj levhası bağlantısı güvenli"),
                item("Kolon-kiriş birleşimi doğru"),
                item("Kiriş sehim kontrolü"),
                item("Eğik bağlantılar uygun"),
                item("Yangın koruma kaplama tamamlandı"),
                item("TS 648 uygunluğu sağlandı"),
                item("Proje uyumu kontrol edildi"),
                item("Onay belgesi mevcut")
            ]
        case .plastering:
            return [
                item("Yüzey düzlüğü kontrol edildi"),
                item("Köşe profilleri takıldı"),
                item("Kalınlık uygun"),
                item("Çatlak kontrolü")
            ]
        case .painting:
            return [
                item("Yüzey astarlandı"),
                item("Kat sayısı doğrulandı"),
                item("Renk uygunluğu"),
                item("Yüzey pürüzsüz")
            ]
        case .general:
            return [
                item("KKD kontrolü"),
                item("Çalışma alanı güvenli"),
                item("Malzeme kalitesi uygun"),
                item("İş yöntemi onaylı"),
                item("Proje uyumu sağlandı"),
                item("Zorunlu belgeler mevcut"),
                item("Personel yeterliliği"),
                item("Ekipman uygunluğu")
            ]
        }
    }

    private static func item(_ title: String, photoRequired: Bool = false) -> QualityCheckItem {
        var q = QualityCheckItem(title: title)
        q.photoRequired = photoRequired
        return q
    }
}

// MARK: - A8 Yazışma Sistemi

enum LetterCategory: String, Codable, CaseIterable {
    case timeExtension = "Süre Uzatımı"
    case workChange = "İş Artışı/Eksilişi"
    case priceDifference = "Fiyat Farkı"
    case penaltyObjection = "Gecikme Cezası İtirazı"
    case provisionalAcceptance = "Geçici Kabul"
    case finalAcceptance = "Kesin Kabul"
    case guaranteeReturn = "Teminat İadesi"
    case experienceCertificate = "İş Deneyim Belgesi"
    case paymentRequest = "Ödeme Talebi"
    case siteInstruction = "Şantiye Talimatı"
    case designChange = "Proje Değişikliği"
    case claimNotice = "Hak Talebi Bildirimi"
    case general = "Genel Yazışma"

    var icon: String {
        switch self {
        case .timeExtension: return "calendar.badge.plus"
        case .workChange: return "arrow.up.arrow.down.circle"
        case .priceDifference: return "turkishlirasign.circle"
        case .penaltyObjection: return "hand.raised"
        case .provisionalAcceptance: return "checkmark.seal"
        case .finalAcceptance: return "checkmark.seal.fill"
        case .guaranteeReturn: return "lock.open"
        case .experienceCertificate: return "doc.badge.checkmark"
        case .paymentRequest: return "banknote"
        case .siteInstruction: return "hammer"
        case .designChange: return "pencil.and.ruler"
        case .claimNotice: return "exclamationmark.bubble"
        case .general: return "envelope"
        }
    }
}

@Model
final class Correspondence {
    var id: UUID
    var correspondenceNo: String
    var directionRaw: String
    var date: Date
    var subject: String
    var senderOrRecipient: String
    var attachmentCount: Int
    var categoryRaw: String
    var content: String?
    var responseDeadline: Date?
    var isResponded: Bool
    var responseCorrespondenceNo: String?
    var photoData: [Data]
    @Relationship var contract: Contract?
    @Relationship var project: Project?
    var createdAt: Date

    init(correspondenceNo: String, direction: CorrespondenceDirection, subject: String,
         senderOrRecipient: String, category: LetterCategory = .general, date: Date = Date()) {
        self.id = UUID()
        self.correspondenceNo = correspondenceNo
        self.directionRaw = direction.rawValue
        self.date = date
        self.subject = subject
        self.senderOrRecipient = senderOrRecipient
        self.attachmentCount = 0
        self.categoryRaw = category.rawValue
        self.isResponded = false
        self.photoData = []
        self.createdAt = Date()
    }

    var direction: CorrespondenceDirection {
        get { CorrespondenceDirection(rawValue: directionRaw) ?? .gelen }
        set { directionRaw = newValue.rawValue }
    }
    var category: LetterCategory {
        get { LetterCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }
    var isOverdue: Bool {
        guard let dl = responseDeadline, !isResponded else { return false }
        return dl < Date()
    }
    var isDueSoon: Bool {
        guard let dl = responseDeadline, !isResponded else { return false }
        return !isOverdue && dl < Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    }

    static func generateNo(existingCount: Int, year: Int? = nil) -> String {
        let y = year ?? Calendar.current.component(.year, from: Date())
        return String(format: "%d/%03d", y, existingCount + 1)
    }
}

enum NotificationType: String, Codable, CaseIterable {
    case notification = "Tebliğ"
    case acknowledgment = "Tebellüğ"
}

@Model
final class OfficialNotification {
    var id: UUID
    var notificationDate: Date
    var notificationTypeRaw: String
    var subject: String
    var givenBy: String
    var receivedBy: String
    var witnessName: String?
    var signaturePhotoData: Data?
    var relatedCorrespondenceNo: String?
    @Relationship var contract: Contract?
    var createdAt: Date

    init(subject: String, givenBy: String, receivedBy: String,
         notificationType: NotificationType = .notification, date: Date = Date()) {
        self.id = UUID()
        self.notificationDate = date
        self.notificationTypeRaw = notificationType.rawValue
        self.subject = subject
        self.givenBy = givenBy
        self.receivedBy = receivedBy
        self.createdAt = Date()
    }

    var notificationType: NotificationType {
        get { NotificationType(rawValue: notificationTypeRaw) ?? .notification }
        set { notificationTypeRaw = newValue.rawValue }
    }
}

enum MilestoneStatus: String, Codable, CaseIterable {
    case notStarted = "Başlamadı"
    case inProgress = "Devam Ediyor"
    case completed = "Tamamlandı"
    case delayed = "Gecikmiş"

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        case .delayed: return "exclamationmark.triangle.fill"
        }
    }
    var colorName: String {
        switch self {
        case .notStarted: return "secondary"
        case .inProgress: return "hakedisWarning"
        case .completed: return "hakedisSuccess"
        case .delayed: return "hakedisDanger"
        }
    }
}

@Model
final class ContractMilestone {
    var id: UUID
    var milestoneName: String
    var plannedDate: Date
    var actualDate: Date?
    var statusRaw: String
    var delayDays: Int?
    var notes: String?
    @Relationship var contract: Contract?
    var createdAt: Date

    init(milestoneName: String, plannedDate: Date, contract: Contract? = nil) {
        self.id = UUID()
        self.milestoneName = milestoneName
        self.plannedDate = plannedDate
        self.statusRaw = MilestoneStatus.notStarted.rawValue
        self.contract = contract
        self.createdAt = Date()
    }

    var status: MilestoneStatus {
        get { MilestoneStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }
    var isOverdue: Bool {
        status != .completed && plannedDate < Date()
    }
    var computedDelayDays: Int {
        guard isOverdue else { return 0 }
        return Calendar.current.dateComponents([.day], from: plannedDate, to: actualDate ?? Date()).day ?? 0
    }
}

// MARK: - B1 Doküman Yönetimi

enum DocumentType: String, Codable, CaseIterable {
    case drawing = "Çizim/Plan"
    case specification = "Şartname"
    case report = "Rapor"
    case contract = "Sözleşme"
    case correspondence = "Yazışma"
    case photo = "Fotoğraf"
    case calculation = "Hesap"
    case approval = "Onay Belgesi"
    case certificate = "Sertifika"
    case other = "Diğer"

    var icon: String {
        switch self {
        case .drawing: return "pencil.and.ruler.fill"
        case .specification: return "list.clipboard.fill"
        case .report: return "chart.bar.doc.horizontal.fill"
        case .contract: return "doc.plaintext.fill"
        case .correspondence: return "envelope.fill"
        case .photo: return "photo.fill"
        case .calculation: return "function"
        case .approval: return "checkmark.seal.fill"
        case .certificate: return "rosette"
        case .other: return "doc.fill"
        }
    }
}

enum DocumentDiscipline: String, Codable, CaseIterable {
    case architectural = "Mimari"
    case structural = "Statik"
    case mechanical = "Mekanik"
    case electrical = "Elektrik"
    case landscape = "Peyzaj"
    case infrastructure = "Altyapı"
    case general = "Genel"
}

@Model
final class ProjectDocument {
    var id: UUID
    var documentName: String
    var documentTypeRaw: String
    var disciplineRaw: String
    var revisionNo: String
    var revisionDate: Date
    var fileData: Data?
    var fileSizeKB: Int?
    var uploadedBy: String?
    var isCurrentRevision: Bool
    var notes: String?
    var tags: String?
    @Relationship var project: Project?
    @Relationship(deleteRule: .cascade) var previousRevisions: [DocumentRevision]
    var createdAt: Date

    init(documentName: String, documentType: DocumentType = .other,
         discipline: DocumentDiscipline = .general, revisionNo: String = "Rev.0") {
        self.id = UUID()
        self.documentName = documentName
        self.documentTypeRaw = documentType.rawValue
        self.disciplineRaw = discipline.rawValue
        self.revisionNo = revisionNo
        self.revisionDate = Date()
        self.isCurrentRevision = true
        self.previousRevisions = []
        self.createdAt = Date()
    }

    var documentType: DocumentType {
        get { DocumentType(rawValue: documentTypeRaw) ?? .other }
        set { documentTypeRaw = newValue.rawValue }
    }
    var discipline: DocumentDiscipline {
        get { DocumentDiscipline(rawValue: disciplineRaw) ?? .general }
        set { disciplineRaw = newValue.rawValue }
    }
    var tagList: [String] {
        tags?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
}

@Model
final class DocumentRevision {
    var id: UUID
    var revisionNo: String
    var revisionDate: Date
    var changeDescription: String?
    var fileData: Data?
    @Relationship var document: ProjectDocument?
    var createdAt: Date

    init(revisionNo: String, document: ProjectDocument? = nil) {
        self.id = UUID()
        self.revisionNo = revisionNo
        self.revisionDate = Date()
        self.document = document
        self.createdAt = Date()
    }
}

// MARK: - B2 Toplantı ve Karar Takibi

enum MeetingType: String, Codable, CaseIterable {
    case weeklyCoordination = "Haftalık Koordinasyon"
    case monthlyProgress = "Aylık İlerleme"
    case safety = "İSG Toplantısı"
    case quality = "Kalite Toplantısı"
    case design = "Tasarım Toplantısı"
    case kickoff = "Başlangıç Toplantısı"
    case handover = "Teslim Toplantısı"
    case emergency = "Acil Toplantı"
    case other = "Diğer"

    var icon: String {
        switch self {
        case .weeklyCoordination: return "calendar"
        case .monthlyProgress: return "chart.line.uptrend.xyaxis"
        case .safety: return "shield.fill"
        case .quality: return "checkmark.seal"
        case .design: return "pencil.and.ruler"
        case .kickoff: return "flag.fill"
        case .handover: return "tray.and.arrow.up.fill"
        case .emergency: return "exclamationmark.triangle.fill"
        case .other: return "person.3.fill"
        }
    }
}

struct MeetingAttendee: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var title: String?
    var company: String?
    var isSigned: Bool = false
}

enum DecisionStatus: String, Codable, CaseIterable {
    case open = "Açık"
    case inProgress = "Devam Ediyor"
    case completed = "Tamamlandı"
    case overdue = "Gecikmiş"

    var icon: String {
        switch self {
        case .open: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        }
    }
    var colorName: String {
        switch self {
        case .open: return "hakedisWarning"
        case .inProgress: return "hakedisInfo"
        case .completed: return "hakedisSuccess"
        case .overdue: return "hakedisDanger"
        }
    }
}

@Model
final class Meeting {
    var id: UUID
    var meetingDate: Date
    var meetingTypeRaw: String
    var title: String
    var location: String?
    var attendeesJSON: String
    var agendaItems: String?
    var minutesText: String?
    var previousMeetingId: UUID?
    @Relationship(deleteRule: .cascade) var decisions: [MeetingDecision]
    @Relationship var project: Project?
    var createdAt: Date

    init(title: String, meetingType: MeetingType = .other, meetingDate: Date = Date()) {
        self.id = UUID()
        self.meetingDate = meetingDate
        self.meetingTypeRaw = meetingType.rawValue
        self.title = title
        self.attendeesJSON = "[]"
        self.decisions = []
        self.createdAt = Date()
    }

    var meetingType: MeetingType {
        get { MeetingType(rawValue: meetingTypeRaw) ?? .other }
        set { meetingTypeRaw = newValue.rawValue }
    }
    var attendees: [MeetingAttendee] {
        get { (try? JSONDecoder().decode([MeetingAttendee].self, from: Data(attendeesJSON.utf8))) ?? [] }
        set { attendeesJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }
    var openDecisionCount: Int { decisions.filter { $0.status == .open || $0.status == .inProgress }.count }
}

@Model
final class MeetingDecision {
    var id: UUID
    var decisionNo: Int
    var decisionText: String
    var responsiblePerson: String
    var deadline: Date
    var completionDate: Date?
    var statusRaw: String
    var notes: String?
    @Relationship var meeting: Meeting?
    var createdAt: Date

    init(decisionNo: Int, decisionText: String, responsiblePerson: String, deadline: Date) {
        self.id = UUID()
        self.decisionNo = decisionNo
        self.decisionText = decisionText
        self.responsiblePerson = responsiblePerson
        self.deadline = deadline
        self.statusRaw = DecisionStatus.open.rawValue
        self.createdAt = Date()
    }

    var status: DecisionStatus {
        get { DecisionStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
    var isOverdue: Bool {
        status != .completed && deadline < Date()
    }
    var effectiveStatus: DecisionStatus {
        if status == .completed { return .completed }
        if isOverdue { return .overdue }
        return status
    }
}

// MARK: - B3 Keşif ve İhale Hazırlık

enum SurveyStatus: String, Codable, CaseIterable {
    case draft = "Taslak"
    case inProgress = "Devam Ediyor"
    case completed = "Tamamlandı"
    case approved = "Onaylandı"
    var icon: String {
        switch self {
        case .draft: return "doc"
        case .inProgress: return "pencil"
        case .completed: return "checkmark.circle"
        case .approved: return "checkmark.seal.fill"
        }
    }
    var colorName: String {
        switch self {
        case .draft: return "secondary"
        case .inProgress: return "hakedisWarning"
        case .completed: return "hakedisSuccess"
        case .approved: return "hakedisOrange"
        }
    }
}

@Model final class Survey {
    var id: UUID
    var surveyNo: String
    var surveyName: String
    var projectName: String
    var surveyDate: Date
    var statusRaw: String
    var preparedBy: String
    var approvedBy: String?
    var approvalDate: Date?
    var notes: String
    var locations: [SurveyLocation]
    var createdAt: Date

    init(surveyNo: String, surveyName: String, projectName: String, preparedBy: String) {
        self.id = UUID()
        self.surveyNo = surveyNo
        self.surveyName = surveyName
        self.projectName = projectName
        self.surveyDate = Date()
        self.statusRaw = SurveyStatus.draft.rawValue
        self.preparedBy = preparedBy
        self.notes = ""
        self.locations = []
        self.createdAt = Date()
    }

    var status: SurveyStatus {
        get { SurveyStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }
    var totalItems: Int { locations.reduce(0) { $0 + $1.items.count } }
    var totalEstimatedCost: Double {
        locations.reduce(0.0) { $0 + $1.items.reduce(0.0) { $0 + $1.estimatedTotal } }
    }
    static func generateNo(existingCount: Int, year: Int) -> String {
        String(format: "KES-%d/%03d", year, existingCount + 1)
    }
}

enum LocationType: String, Codable, CaseIterable {
    case floor = "Kat"
    case zone = "Bölge"
    case block = "Blok"
    case exterior = "Dış Alan"
    case basement = "Bodrum"
    case other = "Diğer"
    var icon: String {
        switch self {
        case .floor: return "building.2"
        case .zone: return "square.dashed"
        case .block: return "building"
        case .exterior: return "tree"
        case .basement: return "arrow.down.to.line"
        case .other: return "mappin"
        }
    }
}

@Model final class SurveyLocation {
    var id: UUID
    var locationName: String
    var typeRaw: String
    var sortOrder: Int
    var items: [SurveyItem]
    var survey: Survey?

    init(locationName: String, type: LocationType, sortOrder: Int) {
        self.id = UUID()
        self.locationName = locationName
        self.typeRaw = type.rawValue
        self.sortOrder = sortOrder
        self.items = []
    }

    var locationType: LocationType {
        get { LocationType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }
    var subtotal: Double { items.reduce(0.0) { $0 + $1.estimatedTotal } }
}

@Model final class SurveyItem {
    var id: UUID
    var pozCode: String
    var pozName: String
    var unit: String
    var quantity: Double
    var unitPrice: Double
    var notes: String
    var location: SurveyLocation?

    init(pozCode: String, pozName: String, unit: String, quantity: Double, unitPrice: Double) {
        self.id = UUID()
        self.pozCode = pozCode
        self.pozName = pozName
        self.unit = unit
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.notes = ""
    }

    var estimatedTotal: Double { quantity * unitPrice }
}

enum BidStatus: String, Codable, CaseIterable {
    case preparation = "Hazırlanıyor"
    case submitted = "Teklif Verildi"
    case won = "Kazanıldı"
    case lost = "Kaybedildi"
    case cancelled = "İptal"
    var icon: String {
        switch self {
        case .preparation: return "pencil"
        case .submitted: return "paperplane"
        case .won: return "trophy.fill"
        case .lost: return "xmark.circle"
        case .cancelled: return "minus.circle"
        }
    }
    var colorName: String {
        switch self {
        case .preparation: return "hakedisWarning"
        case .submitted: return "hakedisOrange"
        case .won: return "hakedisSuccess"
        case .lost: return "hakedisDanger"
        case .cancelled: return "secondary"
        }
    }
}

@Model final class BidPreparation {
    var id: UUID
    var bidNo: String
    var projectTitle: String
    var clientName: String
    var bidDeadline: Date
    var statusRaw: String
    var estimatedBudget: Double
    var bidAmount: Double
    var overheadRate: Double
    var profitRate: Double
    var taxRate: Double
    var notes: String
    var analysisRecords: [AnalysisRecord]
    var createdAt: Date

    init(bidNo: String, projectTitle: String, clientName: String, bidDeadline: Date) {
        self.id = UUID()
        self.bidNo = bidNo
        self.projectTitle = projectTitle
        self.clientName = clientName
        self.bidDeadline = bidDeadline
        self.statusRaw = BidStatus.preparation.rawValue
        self.estimatedBudget = 0
        self.bidAmount = 0
        self.overheadRate = 15.0
        self.profitRate = 10.0
        self.taxRate = 20.0
        self.notes = ""
        self.analysisRecords = []
        self.createdAt = Date()
    }

    var status: BidStatus {
        get { BidStatus(rawValue: statusRaw) ?? .preparation }
        set { statusRaw = newValue.rawValue }
    }
    var totalDirectCost: Double { analysisRecords.reduce(0.0) { $0 + $1.totalCost } }
    var overheadAmount: Double { totalDirectCost * overheadRate / 100 }
    var profitAmount: Double { (totalDirectCost + overheadAmount) * profitRate / 100 }
    var subtotalBeforeTax: Double { totalDirectCost + overheadAmount + profitAmount }
    var taxAmount: Double { subtotalBeforeTax * taxRate / 100 }
    var totalWithTax: Double { subtotalBeforeTax + taxAmount }
    var isOverdue: Bool { status == .preparation && bidDeadline < Date() }
    static func generateNo(existingCount: Int, year: Int) -> String {
        String(format: "IH-%d/%03d", year, existingCount + 1)
    }
}

enum AnalysisResourceType: String, Codable, CaseIterable {
    case labor = "İşçilik"
    case material = "Malzeme"
    case equipment = "Makine"
    case subcontract = "Taşeron"
    var icon: String {
        switch self {
        case .labor: return "person.2"
        case .material: return "shippingbox"
        case .equipment: return "wrench.and.screwdriver"
        case .subcontract: return "building.2"
        }
    }
}

struct AnalysisResourceItem: Codable, Identifiable {
    var id: UUID = UUID()
    var resourceName: String
    var typeRaw: String
    var unit: String
    var quantity: Double
    var unitPrice: Double

    var resourceType: AnalysisResourceType {
        get { AnalysisResourceType(rawValue: typeRaw) ?? .material }
        set { typeRaw = newValue.rawValue }
    }
    var total: Double { quantity * unitPrice }
}

@Model final class AnalysisRecord {
    var id: UUID
    var pozCode: String
    var pozName: String
    var unit: String
    var quantity: Double
    var resourcesJSON: String
    var notes: String
    var bidPreparation: BidPreparation?
    var createdAt: Date

    init(pozCode: String, pozName: String, unit: String, quantity: Double) {
        self.id = UUID()
        self.pozCode = pozCode
        self.pozName = pozName
        self.unit = unit
        self.quantity = quantity
        self.resourcesJSON = "[]"
        self.notes = ""
        self.createdAt = Date()
    }

    var resources: [AnalysisResourceItem] {
        get {
            guard let data = resourcesJSON.data(using: .utf8),
                  let items = try? JSONDecoder().decode([AnalysisResourceItem].self, from: data)
            else { return [] }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                resourcesJSON = str
            }
        }
    }
    var unitCost: Double { resources.reduce(0.0) { $0 + $1.total } }
    var totalCost: Double { unitCost * quantity }
}

// MARK: - B4 İş Programı Gantt

enum DependencyType: String, Codable, CaseIterable {
    case finishToStart = "Bitiş-Başlangıç"
    case startToStart = "Başlangıç-Başlangıç"
    case finishToFinish = "Bitiş-Bitiş"
    case startToFinish = "Başlangıç-Bitiş"
}

enum ActivityStatus: String, Codable, CaseIterable {
    case notStarted = "Başlamadı"
    case inProgress = "Devam Ediyor"
    case completed = "Tamamlandı"
    case delayed = "Gecikmiş"
    case onHold = "Beklemede"
    var colorName: String {
        switch self {
        case .notStarted: return "secondary"
        case .inProgress: return "hakedisOrange"
        case .completed: return "hakedisSuccess"
        case .delayed: return "hakedisDanger"
        case .onHold: return "hakedisWarning"
        }
    }
    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "arrow.right.circle"
        case .completed: return "checkmark.circle.fill"
        case .delayed: return "exclamationmark.circle.fill"
        case .onHold: return "pause.circle"
        }
    }
}

struct ActivityDependency: Codable, Identifiable {
    var id: UUID = UUID()
    var predecessorId: UUID
    var dependencyTypeRaw: String
    var lagDays: Int
    var dependencyType: DependencyType {
        get { DependencyType(rawValue: dependencyTypeRaw) ?? .finishToStart }
        set { dependencyTypeRaw = newValue.rawValue }
    }
}

@Model final class ProjectActivity {
    var id: UUID
    var activityCode: String
    var activityName: String
    var plannedStart: Date
    var plannedEnd: Date
    var actualStart: Date?
    var actualEnd: Date?
    var statusRaw: String
    var progressPercent: Double
    var isCritical: Bool
    var responsiblePerson: String
    var dependenciesJSON: String
    var wbsLevel: Int
    var parentCode: String?
    var notes: String
    var createdAt: Date

    init(activityCode: String, activityName: String, plannedStart: Date, plannedEnd: Date) {
        self.id = UUID()
        self.activityCode = activityCode
        self.activityName = activityName
        self.plannedStart = plannedStart
        self.plannedEnd = plannedEnd
        self.statusRaw = ActivityStatus.notStarted.rawValue
        self.progressPercent = 0
        self.isCritical = false
        self.responsiblePerson = ""
        self.dependenciesJSON = "[]"
        self.wbsLevel = 1
        self.notes = ""
        self.createdAt = Date()
    }

    var status: ActivityStatus {
        get { ActivityStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }
    var plannedDurationDays: Int {
        Calendar.current.dateComponents([.day], from: plannedStart, to: plannedEnd).day ?? 0
    }
    var isDelayed: Bool {
        if status == .completed { return false }
        return plannedEnd < Date() || (progressPercent < expectedProgress && plannedStart < Date())
    }
    var expectedProgress: Double {
        let total = Double(plannedDurationDays)
        guard total > 0 else { return 0 }
        let elapsed = max(0, Double(Calendar.current.dateComponents([.day], from: plannedStart, to: Date()).day ?? 0))
        return min(100, elapsed / total * 100)
    }
    var scheduleVarianceDays: Int {
        guard let actualS = actualStart else { return 0 }
        return Calendar.current.dateComponents([.day], from: plannedStart, to: actualS).day ?? 0
    }
    var dependencies: [ActivityDependency] {
        get {
            guard let data = dependenciesJSON.data(using: .utf8),
                  let items = try? JSONDecoder().decode([ActivityDependency].self, from: data)
            else { return [] }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                dependenciesJSON = str
            }
        }
    }
}

// MARK: - B5 Maliyet Kontrol EVM

enum BudgetCategory: String, Codable, CaseIterable {
    case labor = "İşçilik"
    case material = "Malzeme"
    case equipment = "Makine/Ekipman"
    case subcontract = "Taşeron"
    case overhead = "Genel Gider"
    case contingency = "Risk Payı"
    case other = "Diğer"
    var icon: String {
        switch self {
        case .labor: return "person.2"
        case .material: return "shippingbox"
        case .equipment: return "wrench.and.screwdriver"
        case .subcontract: return "building.2"
        case .overhead: return "building"
        case .contingency: return "shield"
        case .other: return "square.grid.2x2"
        }
    }
}

@Model final class ProjectBudget {
    var id: UUID
    var budgetName: String
    var projectName: String
    var totalBudget: Double
    var approvedDate: Date?
    var notes: String
    var lineItems: [BudgetLineItem]
    var evmSnapshots: [EVMSnapshot]
    var overheadExpenses: [OverheadExpense]
    var createdAt: Date

    init(budgetName: String, projectName: String, totalBudget: Double) {
        self.id = UUID()
        self.budgetName = budgetName
        self.projectName = projectName
        self.totalBudget = totalBudget
        self.notes = ""
        self.lineItems = []
        self.evmSnapshots = []
        self.overheadExpenses = []
        self.createdAt = Date()
    }

    var budgetedCost: Double { lineItems.reduce(0.0) { $0 + $1.budgetedAmount } }
    var actualCost: Double { lineItems.reduce(0.0) { $0 + $1.actualAmount } }
    var costVariance: Double { budgetedCost - actualCost }
    var totalOverheadCost: Double { overheadExpenses.reduce(0.0) { $0 + $1.amount } }
    var totalCost: Double { actualCost + totalOverheadCost }
}

@Model final class BudgetLineItem {
    var id: UUID
    var categoryRaw: String
    var itemName: String
    var budgetedAmount: Double
    var actualAmount: Double
    var notes: String
    var budget: ProjectBudget?

    init(itemName: String, category: BudgetCategory, budgetedAmount: Double) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.itemName = itemName
        self.budgetedAmount = budgetedAmount
        self.actualAmount = 0
        self.notes = ""
    }

    var category: BudgetCategory {
        get { BudgetCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    var variance: Double { budgetedAmount - actualAmount }
    var variancePercent: Double {
        guard budgetedAmount > 0 else { return 0 }
        return variance / budgetedAmount * 100
    }
}

@Model final class EVMSnapshot {
    var id: UUID
    var snapshotDate: Date
    var budgetAtCompletion: Double
    var plannedValue: Double
    var earnedValue: Double
    var actualCost: Double
    var notes: String
    var budget: ProjectBudget?

    init(snapshotDate: Date, budgetAtCompletion: Double, plannedValue: Double,
         earnedValue: Double, actualCost: Double) {
        self.id = UUID()
        self.snapshotDate = snapshotDate
        self.budgetAtCompletion = budgetAtCompletion
        self.plannedValue = plannedValue
        self.earnedValue = earnedValue
        self.actualCost = actualCost
        self.notes = ""
    }

    var scheduleVariance: Double { earnedValue - plannedValue }
    var costVariance: Double { earnedValue - actualCost }
    var spi: Double { plannedValue > 0 ? earnedValue / plannedValue : 0 }
    var cpi: Double { actualCost > 0 ? earnedValue / actualCost : 0 }
    var eac: Double { cpi > 0 ? budgetAtCompletion / cpi : budgetAtCompletion }
    var etc: Double { eac - actualCost }
    var vac: Double { budgetAtCompletion - eac }
    var tcpi: Double {
        let denominator = budgetAtCompletion - actualCost
        guard denominator > 0 else { return 0 }
        return (budgetAtCompletion - earnedValue) / denominator
    }
    var completionPercent: Double {
        guard budgetAtCompletion > 0 else { return 0 }
        return earnedValue / budgetAtCompletion * 100
    }
    var isOnSchedule: Bool { spi >= 0.95 }
    var isOnBudget: Bool { cpi >= 0.95 }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case officeRent = "Ofis Kirası"
    case utilities = "Elektrik/Su/Gaz"
    case vehicleFuel = "Araç Yakıtı"
    case communication = "Haberleşme"
    case insurance = "Sigorta"
    case accounting = "Muhasebe"
    case other = "Diğer"
    var icon: String {
        switch self {
        case .officeRent: return "building"
        case .utilities: return "bolt"
        case .vehicleFuel: return "car"
        case .communication: return "phone"
        case .insurance: return "shield.checkered"
        case .accounting: return "doc.text"
        case .other: return "square.grid.2x2"
        }
    }
}

@Model final class OverheadExpense {
    var id: UUID
    var categoryRaw: String
    var expenseName: String
    var amount: Double
    var expenseDate: Date
    var invoiceNo: String
    var notes: String
    var budget: ProjectBudget?

    init(expenseName: String, category: ExpenseCategory, amount: Double, expenseDate: Date) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.expenseName = expenseName
        self.amount = amount
        self.expenseDate = expenseDate
        self.invoiceNo = ""
        self.notes = ""
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

// MARK: - B6 Çizim Pin Sistemi

enum PinCategory: String, Codable, CaseIterable {
    case structural = "Yapısal"
    case mechanical = "Mekanik"
    case electrical = "Elektrik"
    case finishing = "İmalat"
    case safety = "İSG"
    case quality = "Kalite"
    case general = "Genel"
    var icon: String {
        switch self {
        case .structural: return "building.columns"
        case .mechanical: return "wrench"
        case .electrical: return "bolt"
        case .finishing: return "paintbrush"
        case .safety: return "shield.checkered"
        case .quality: return "checkmark.seal"
        case .general: return "mappin"
        }
    }
    var colorName: String {
        switch self {
        case .structural: return "hakedisOrange"
        case .mechanical: return "blue"
        case .electrical: return "yellow"
        case .finishing: return "green"
        case .safety: return "hakedisDanger"
        case .quality: return "purple"
        case .general: return "secondary"
        }
    }
}

enum PinStatus: String, Codable, CaseIterable {
    case open = "Açık"
    case inProgress = "İşlemde"
    case resolved = "Çözüldü"
    case closed = "Kapatıldı"
    var icon: String {
        switch self {
        case .open: return "circle"
        case .inProgress: return "arrow.right.circle"
        case .resolved: return "checkmark.circle"
        case .closed: return "xmark.circle.fill"
        }
    }
}

enum PinPriority: String, Codable, CaseIterable {
    case low = "Düşük"
    case medium = "Orta"
    case high = "Yüksek"
    case critical = "Kritik"
    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .critical: return "exclamationmark.2"
        }
    }
    var colorName: String {
        switch self {
        case .low: return "hakedisSuccess"
        case .medium: return "hakedisWarning"
        case .high: return "hakedisOrange"
        case .critical: return "hakedisDanger"
        }
    }
}

@Model final class DrawingPin {
    var id: UUID
    var pinNumber: Int
    var drawingName: String
    var title: String
    var pinDetails: String
    var categoryRaw: String
    var statusRaw: String
    var priorityRaw: String
    var xPosition: Double
    var yPosition: Double
    var assignedTo: String
    var dueDate: Date?
    var resolvedDate: Date?
    var createdBy: String
    var createdAt: Date

    init(pinNumber: Int, drawingName: String, title: String, xPosition: Double, yPosition: Double) {
        self.id = UUID()
        self.pinNumber = pinNumber
        self.drawingName = drawingName
        self.title = title
        self.pinDetails = ""
        self.categoryRaw = PinCategory.general.rawValue
        self.statusRaw = PinStatus.open.rawValue
        self.priorityRaw = PinPriority.medium.rawValue
        self.xPosition = xPosition
        self.yPosition = yPosition
        self.assignedTo = ""
        self.createdBy = ""
        self.createdAt = Date()
    }

    var category: PinCategory {
        get { PinCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }
    var status: PinStatus {
        get { PinStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
    var priority: PinPriority {
        get { PinPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }
    var isOverdue: Bool {
        guard let due = dueDate, status != .resolved && status != .closed else { return false }
        return due < Date()
    }
    var isOpen: Bool { status == .open || status == .inProgress }
    static func generateNumber(existingCount: Int) -> Int { existingCount + 1 }
}

// MARK: - B7 Saha İletişim

enum WorkOrderStatus: String, Codable, CaseIterable {
    case open = "Açık"
    case assigned = "Atandı"
    case inProgress = "Devam Ediyor"
    case completed = "Tamamlandı"
    case cancelled = "İptal"
    var icon: String {
        switch self {
        case .open: return "circle"
        case .assigned: return "person.badge.plus"
        case .inProgress: return "arrow.right.circle"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
    var colorName: String {
        switch self {
        case .open: return "hakedisWarning"
        case .assigned: return "hakedisOrange"
        case .inProgress: return "hakedisOrange"
        case .completed: return "hakedisSuccess"
        case .cancelled: return "secondary"
        }
    }
}

enum WorkOrderType: String, Codable, CaseIterable {
    case repair = "Onarım"
    case installation = "Montaj"
    case inspection = "Muayene"
    case maintenance = "Bakım"
    case demolition = "Yıkım"
    case other = "Diğer"
}

@Model final class WorkOrder {
    var id: UUID
    var orderNo: String
    var orderTitle: String
    var typeRaw: String
    var statusRaw: String
    var issuedBy: String
    var assignedTo: String
    var location: String
    var issueDate: Date
    var dueDate: Date?
    var completedDate: Date?
    var workOrderDetails: String
    var completionNotes: String
    var createdAt: Date

    init(orderNo: String, orderTitle: String, type: WorkOrderType, issuedBy: String) {
        self.id = UUID()
        self.orderNo = orderNo
        self.orderTitle = orderTitle
        self.typeRaw = type.rawValue
        self.statusRaw = WorkOrderStatus.open.rawValue
        self.issuedBy = issuedBy
        self.assignedTo = ""
        self.location = ""
        self.issueDate = Date()
        self.workOrderDetails = ""
        self.completionNotes = ""
        self.createdAt = Date()
    }

    var status: WorkOrderStatus {
        get { WorkOrderStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
    var orderType: WorkOrderType {
        get { WorkOrderType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }
    var isOverdue: Bool {
        guard let due = dueDate, status != .completed && status != .cancelled else { return false }
        return due < Date()
    }
    static func generateNo(existingCount: Int, year: Int) -> String {
        String(format: "IO-%d/%03d", year, existingCount + 1)
    }
}

enum RFIStatus: String, Codable, CaseIterable {
    case open = "Açık"
    case pending = "Yanıt Bekleniyor"
    case answered = "Yanıtlandı"
    case closed = "Kapatıldı"
    var icon: String {
        switch self {
        case .open: return "questionmark.circle"
        case .pending: return "clock"
        case .answered: return "checkmark.message"
        case .closed: return "checkmark.circle.fill"
        }
    }
}

@Model final class RFI {
    var id: UUID
    var rfiNo: String
    var subject: String
    var question: String
    var askedBy: String
    var answeredBy: String?
    var answer: String
    var statusRaw: String
    var submittedDate: Date
    var responseDeadline: Date?
    var answeredDate: Date?
    var drawingReference: String
    var specSection: String
    var createdAt: Date

    init(rfiNo: String, subject: String, question: String, askedBy: String) {
        self.id = UUID()
        self.rfiNo = rfiNo
        self.subject = subject
        self.question = question
        self.askedBy = askedBy
        self.answer = ""
        self.statusRaw = RFIStatus.open.rawValue
        self.submittedDate = Date()
        self.drawingReference = ""
        self.specSection = ""
        self.createdAt = Date()
    }

    var status: RFIStatus {
        get { RFIStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
    var isOverdue: Bool {
        guard let deadline = responseDeadline, status != .answered && status != .closed else { return false }
        return deadline < Date()
    }
    static func generateNo(existingCount: Int, year: Int) -> String {
        String(format: "RFI-%d/%03d", year, existingCount + 1)
    }
}

enum AnnouncementType: String, Codable, CaseIterable {
    case safety = "İSG Duyurusu"
    case workInstruction = "İş Talimatı"
    case schedule = "Program Değişikliği"
    case general = "Genel"
    case urgent = "Acil"
    var icon: String {
        switch self {
        case .safety: return "shield.checkered"
        case .workInstruction: return "doc.text"
        case .schedule: return "calendar.badge.exclamationmark"
        case .general: return "megaphone"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }
}

@Model final class SiteAnnouncement {
    var id: UUID
    var announcementTitle: String
    var content: String
    var typeRaw: String
    var postedBy: String
    var isActive: Bool
    var expiresAt: Date?
    var createdAt: Date

    init(announcementTitle: String, content: String, type: AnnouncementType, postedBy: String) {
        self.id = UUID()
        self.announcementTitle = announcementTitle
        self.content = content
        self.typeRaw = type.rawValue
        self.postedBy = postedBy
        self.isActive = true
        self.createdAt = Date()
    }

    var announcementType: AnnouncementType {
        get { AnnouncementType(rawValue: typeRaw) ?? .general }
        set { typeRaw = newValue.rawValue }
    }
    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return exp < Date()
    }
    var isVisible: Bool { isActive && !isExpired }
}
