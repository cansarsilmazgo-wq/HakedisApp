import Foundation
import SwiftData

// MARK: - Enums

enum BuildingType: String, Codable, CaseIterable {
    case residential = "Konut"
    case commercial  = "Ticari"
    case mixed       = "Karma"
}

enum UrbanRenewalContractType: String, Codable, CaseIterable {
    case landShare     = "Kat Karşılığı"
    case revenueShare  = "Hasılat Paylaşımı"
    case freeTransfer  = "Bedelsiz Devir"
}

enum UrbanRenewalStatus: String, Codable, CaseIterable {
    case riskAssessment      = "Risk Tespiti"
    case stakeholderAgreement = "Hak Sahibi Anlaşması"
    case demolition          = "Yıkım"
    case permitting          = "Ruhsat"
    case construction        = "İnşaat"
    case delivery            = "Teslim"
    case completed           = "Tamamlandı"

    var stepIndex: Int {
        switch self {
        case .riskAssessment: return 0
        case .stakeholderAgreement: return 1
        case .demolition: return 2
        case .permitting: return 3
        case .construction: return 4
        case .delivery: return 5
        case .completed: return 6
        }
    }

    var icon: String {
        switch self {
        case .riskAssessment: return "magnifyingglass.circle.fill"
        case .stakeholderAgreement: return "person.2.fill"
        case .demolition: return "trash.fill"
        case .permitting: return "doc.badge.checkmark"
        case .construction: return "hammer.fill"
        case .delivery: return "key.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

enum UnitType: String, Codable, CaseIterable {
    case studio      = "1+0"
    case onePlusOne  = "1+1"
    case twoPlusOne  = "2+1"
    case threePlusOne = "3+1"
    case fourPlusOne = "4+1"
    case shop        = "Dükkan"
    case office      = "Ofis"
    case parking     = "Otopark"
    case storage     = "Depo"
}

enum AllocationTarget: String, Codable, CaseIterable {
    case stakeholder = "Hak Sahibi"
    case contractor  = "Müteahhit"
    case sale        = "Satış"
}

// MARK: - UrbanRenewalProject

@Model
final class UrbanRenewalProject {
    var id: UUID
    var projectName: String
    var address: String
    var district: String
    var city: String
    var parcelNo: String
    var riskReportDate: Date?
    var riskReportNo: String?
    var demolitionDate: Date?
    var constructionStartDate: Date?
    var estimatedCompletionDate: Date?
    var buildingTypeRaw: String
    var totalFloors: Int
    var totalUnits: Int
    var totalArea: Double
    var contractTypeRaw: String
    var statusRaw: String
    @Relationship(deleteRule: .cascade) var stakeholders: [Stakeholder]
    @Relationship(deleteRule: .cascade) var unitDistributions: [UnitDistribution]
    @Relationship var project: Project?
    var createdAt: Date

    init(projectName: String, address: String, district: String, city: String) {
        self.id = UUID()
        self.projectName = projectName
        self.address = address
        self.district = district
        self.city = city
        self.parcelNo = ""
        self.buildingTypeRaw = BuildingType.residential.rawValue
        self.totalFloors = 0
        self.totalUnits = 0
        self.totalArea = 0
        self.contractTypeRaw = UrbanRenewalContractType.landShare.rawValue
        self.statusRaw = UrbanRenewalStatus.riskAssessment.rawValue
        self.stakeholders = []
        self.unitDistributions = []
        self.createdAt = Date()
    }

    var buildingType: BuildingType {
        get { BuildingType(rawValue: buildingTypeRaw) ?? .residential }
        set { buildingTypeRaw = newValue.rawValue }
    }

    var contractType: UrbanRenewalContractType {
        get { UrbanRenewalContractType(rawValue: contractTypeRaw) ?? .landShare }
        set { contractTypeRaw = newValue.rawValue }
    }

    var status: UrbanRenewalStatus {
        get { UrbanRenewalStatus(rawValue: statusRaw) ?? .riskAssessment }
        set { statusRaw = newValue.rawValue }
    }

    var agreedStakeholderCount: Int {
        stakeholders.filter { $0.isAgreed }.count
    }

    var agreementRate: Double {
        guard !stakeholders.isEmpty else { return 0 }
        return Double(agreedStakeholderCount) / Double(stakeholders.count) * 100
    }

    var stakeholderUnits: [UnitDistribution] {
        unitDistributions.filter { $0.allocationTargetRaw == AllocationTarget.stakeholder.rawValue }
    }

    var contractorUnits: [UnitDistribution] {
        unitDistributions.filter { $0.allocationTargetRaw == AllocationTarget.contractor.rawValue }
    }

    var saleUnits: [UnitDistribution] {
        unitDistributions.filter { $0.allocationTargetRaw == AllocationTarget.sale.rawValue }
    }

    var estimatedRevenue: Double {
        saleUnits.reduce(0) { $0 + ($1.estimatedValue ?? 0) }
    }
}

// MARK: - Stakeholder

@Model
final class Stakeholder {
    var id: UUID
    var fullName: String
    var phone: String?
    var email: String?
    var currentUnitNo: String?
    var currentArea: Double?
    var sharePercentage: Double?
    var isAgreed: Bool
    var agreementDate: Date?
    var agreementType: String?
    var notes: String?
    @Relationship var urbanProject: UrbanRenewalProject?
    @Relationship(deleteRule: .cascade) var distributions: [UnitDistribution]
    var createdAt: Date

    init(fullName: String) {
        self.id = UUID()
        self.fullName = fullName
        self.isAgreed = false
        self.distributions = []
        self.createdAt = Date()
    }
}

// MARK: - UnitDistribution

@Model
final class UnitDistribution {
    var id: UUID
    var unitNo: String
    var unitTypeRaw: String
    var grossArea: Double
    var netArea: Double
    var allocationTargetRaw: String
    var estimatedValue: Double?
    var salePrice: Double?
    var isSold: Bool
    var buyerName: String?
    @Relationship var stakeholder: Stakeholder?
    @Relationship var urbanProject: UrbanRenewalProject?
    var createdAt: Date

    init(unitNo: String, unitType: UnitType, grossArea: Double, netArea: Double, target: AllocationTarget) {
        self.id = UUID()
        self.unitNo = unitNo
        self.unitTypeRaw = unitType.rawValue
        self.grossArea = grossArea
        self.netArea = netArea
        self.allocationTargetRaw = target.rawValue
        self.isSold = false
        self.createdAt = Date()
    }

    var unitType: UnitType {
        get { UnitType(rawValue: unitTypeRaw) ?? .onePlusOne }
        set { unitTypeRaw = newValue.rawValue }
    }

    var allocationTarget: AllocationTarget {
        get { AllocationTarget(rawValue: allocationTargetRaw) ?? .sale }
        set { allocationTargetRaw = newValue.rawValue }
    }
}
