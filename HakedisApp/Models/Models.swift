import Foundation
import SwiftData

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

    init(code: String, name: String, unit: String, unitPrice: Double, contractedQuantity: Double, location: String = "") {
        self.id = UUID()
        self.code = code
        self.name = name
        self.unit = unit
        self.unitPrice = unitPrice
        self.contractedQuantity = contractedQuantity
        self.location = location
        self.revisionHistory = []
        self.dailyEntries = []
        self.unitPriceAnalyses = []
    }

    var totalAmount: Double { contractedQuantity * unitPrice }
    var completedQuantity: Double { dailyEntries.reduce(0) { $0 + $1.quantity } }
    var completionPercentage: Double {
        guard contractedQuantity > 0 else { return 0 }
        return min((completedQuantity / contractedQuantity) * 100, 100)
    }
    var remainingQuantity: Double { contractedQuantity - completedQuantity }
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

    init(date: Date = Date(), quantity: Double, location: String = "", notes: String = "") {
        self.id = UUID()
        self.date = date
        self.quantity = quantity
        self.location = location
        self.notes = notes
        self.photoData = []
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
        self.createdAt = Date()
    }

    var nextRevisionVersion: String { "v1.\(revisions.count)" }

    var grossAmount: Double { items.reduce(0) { $0 + $1.periodAmount } }

    var retentionAmount: Double {
        guard let rate = contract?.retentionRate, rate > 0 else { return 0 }
        return grossAmount * (rate / 100)
    }

    /// Avans kesintisi: brüt × avans oranı
    var advanceDeduction: Double {
        guard let rate = contract?.advanceRate, rate > 0 else { return 0 }
        return grossAmount * (rate / 100)
    }

    /// Teminat ve avans sonrası KDV matrahı
    var netAmount: Double { grossAmount - retentionAmount - advanceDeduction }

    /// KDV tutarı (net × kdv oranı)
    var kdvAmount: Double {
        guard let rate = contract?.kdvRate, rate > 0 else { return 0 }
        return netAmount * (rate / 100)
    }

    /// Ödenecek toplam (net + KDV)
    var totalWithKDV: Double { netAmount + kdvAmount }

    var totalPaid: Double { payments.reduce(0) { $0 + $1.amount } }

    /// Kalan ödeme (KDV dahil toplam – ödenen)
    var remainingAmount: Double { totalWithKDV - totalPaid }

    /// Ödeme gecikme günü (vade tarihi geçmişse ve hâlâ ödenmemişse)
    var daysOverdue: Int {
        guard let due = dueDate, remainingAmount > 0, status != .paid else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: due, to: Date()).day ?? 0
        return max(0, days)
    }

    /// Gecikme faizi (yasal oran: %9 yıllık → günlük %0.0246575)
    var overdueInterest: Double {
        guard daysOverdue > 0 else { return 0 }
        let dailyRate = 9.0 / 365.0 / 100.0
        return remainingAmount * dailyRate * Double(daysOverdue)
    }

    var isOverdue: Bool { daysOverdue > 0 }
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
    var project: Project?
    var createdAt: Date

    init(title: String, plannedDate: Date, notes: String = "", isCritical: Bool = false) {
        self.id = UUID()
        self.title = title
        self.plannedDate = plannedDate
        self.notes = notes
        self.isCritical = isCritical
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
         officialLetterNo: String? = nil) {
        self.id = UUID()
        self.version = version
        self.rejectionReason = rejectionReason
        self.officialLetterNo = officialLetterNo
        self.rejectedAt = rejectedAt
        self.objectionDeadline = Calendar.current.date(byAdding: .day, value: 30, to: rejectedAt)!
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
