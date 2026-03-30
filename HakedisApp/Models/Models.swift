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
        self.measurementEntries = []
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
    @Relationship(deleteRule: .cascade) var photoAnnotations: [PhotoAnnotation]

    init(date: Date = Date(), quantity: Double, location: String = "", notes: String = "") {
        self.id = UUID()
        self.date = date
        self.quantity = quantity
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
        guard let json = laborEntriesJSON,
              let data = json.data(using: .utf8),
              let entries = try? JSONDecoder().decode([LaborEntryData].self, from: data)
        else { return [] }
        return entries
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

    var isOverdue: Bool {
        guard let deadline = replyDeadline, !isReplied else { return false }
        return Date() > deadline
    }

    var daysLeft: Int? {
        guard let deadline = replyDeadline, !isReplied else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
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
    var contract: Contract?
    var createdAt: Date

    init(periodName: String, baseIndex: Double, currentIndex: Double, baseAmount: Double) {
        self.id = UUID()
        self.periodName = periodName
        self.baseIndex = baseIndex
        self.currentIndex = currentIndex
        self.baseAmount = baseAmount
        self.createdAt = Date()
    }

    var indexRatio: Double {
        guard baseIndex > 0 else { return 1.0 }
        return currentIndex / baseIndex
    }

    var priceDifference: Double { baseAmount * (indexRatio - 1) }

    var isGain: Bool { priceDifference > 0 }
}

// MARK: - KDV Tevkifatı (VATWithholdingRecord)

enum VATWithholdingRatio: String, Codable, CaseIterable {
    case ikiUcte  = "2/3"
    case yariYari = "1/2"

    var ratio: Double {
        switch self {
        case .ikiUcte:  return 2.0 / 3.0
        case .yariYari: return 0.5
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

    var isCompliant: Bool { declaredLaborAmount >= minimumLaborAmount }
    var deficiency: Double { max(0, minimumLaborAmount - declaredLaborAmount) }
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
    var workSummary: String
    var issues: String?
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
        self.createdAt = Date()
    }

    var isSigned: Bool {
        contractorSignature != nil && ownerSignature != nil
    }

    var isWorkday: Bool { !isHoliday && !isSuspended }
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

    init(name: String, plateOrSerial: String = "", equipmentType: String = "",
         dailyRentalCost: Double = 0, maintenancePeriodDays: Int = 90) {
        self.id = UUID()
        self.name = name
        self.plateOrSerial = plateOrSerial
        self.equipmentType = equipmentType
        self.dailyRentalCost = dailyRentalCost
        self.maintenancePeriodDays = maintenancePeriodDays
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

    init(recordDate: Date = Date(), location: String = "",
         depth: Double = 0, area: Double = 0, soilType: String = "") {
        self.id = UUID()
        self.recordDate = recordDate
        self.location = location
        self.depth = depth
        self.area = area
        self.soilType = soilType
        self.notes = ""
        self.createdAt = Date()
    }

    var calculatedVolume: Double { depth * area }

    var labTests: [SoilLabTest] {
        guard let json = labTestsJSON,
              let data = json.data(using: .utf8),
              let tests = try? JSONDecoder().decode([SoilLabTest].self, from: data)
        else { return [] }
        return tests
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

    init(testName: String, category: TestCategory = .beton,
         location: String = "", sampleNo: String = "", laboratoryName: String = "",
         unit: String = "") {
        self.id = UUID()
        self.testDate = Date()
        self.category = category
        self.testName = testName
        self.location = location
        self.sampleNo = sampleNo
        self.laboratoryName = laboratoryName
        self.unit = unit
        self.status = .bekliyor
        self.createdAt = Date()
    }

    var isInRange: Bool {
        guard let r = result else { return false }
        let minOK = minimumAcceptable.map { r >= $0 } ?? true
        let maxOK = maximumAcceptable.map { r <= $0 } ?? true
        return minOK && maxOK
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
    var contract: Contract?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var warrantyClaims: [WarrantyClaim]

    init(acceptanceType: AcceptanceType, acceptanceDate: Date = Date(),
         warrantyMonths: Int = 24) {
        self.id = UUID()
        self.acceptanceType = acceptanceType
        self.acceptanceDate = acceptanceDate
        self.warrantyMonths = warrantyMonths
        self.notes = ""
        self.warrantyClaims = []
        self.createdAt = Date()
    }

    var warrantyEndDate: Date? {
        Calendar.current.date(byAdding: .month, value: warrantyMonths, to: acceptanceDate)
    }

    var isWarrantyActive: Bool {
        guard let end = warrantyEndDate else { return false }
        return Date() <= end
    }

    var warrantyDaysLeft: Int {
        guard let end = warrantyEndDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0)
    }
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
