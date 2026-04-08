import Foundation
import SwiftData

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
    // FAZ 17.4
    var equipmentCategoryRaw: String = EquipmentCategory.diger.rawValue
    var assignedOperatorName: String = ""
    var hourlyCost: Double = 0.0
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

    var equipmentCategory: EquipmentCategory {
        get { EquipmentCategory(rawValue: equipmentCategoryRaw) ?? .diger }
        set { equipmentCategoryRaw = newValue.rawValue }
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

