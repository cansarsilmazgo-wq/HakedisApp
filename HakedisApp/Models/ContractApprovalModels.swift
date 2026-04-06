import Foundation
import SwiftData

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

