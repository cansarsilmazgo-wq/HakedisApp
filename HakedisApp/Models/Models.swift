import Foundation
import SwiftData

// MARK: - Project
@Model
final class Project {
    var id: UUID
    var name: String
    var projectDescription: String
    var location: String
    var startDate: Date
    var status: ProjectStatus
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var contracts: [Contract]

    init(name: String, projectDescription: String = "", location: String = "", startDate: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.projectDescription = projectDescription
        self.location = location
        self.startDate = startDate
        self.status = .active
        self.createdAt = Date()
        self.contracts = []
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case active = "Aktif"
    case completed = "Tamamlandı"
    case paused = "Askıda"
}

// MARK: - Contractor (Taşeron)
@Model
final class Contractor {
    var id: UUID
    var name: String
    var contactPerson: String
    var phone: String
    var email: String
    var taxNumber: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var contracts: [Contract]

    init(name: String, contactPerson: String = "", phone: String = "", email: String = "", taxNumber: String = "") {
        self.id = UUID()
        self.name = name
        self.contactPerson = contactPerson
        self.phone = phone
        self.email = email
        self.taxNumber = taxNumber
        self.createdAt = Date()
        self.contracts = []
    }
}

// MARK: - Contract (Sözleşme)
@Model
final class Contract {
    var id: UUID
    var title: String
    var contractDate: Date
    var retentionRate: Double    // Teminat oranı (%)
    var advanceRate: Double      // Avans oranı (%)
    var project: Project?
    var contractor: Contractor?

    @Relationship(deleteRule: .cascade)
    var workItems: [WorkItem]

    @Relationship(deleteRule: .cascade)
    var hakedisler: [Hakedis]

    init(title: String, contractDate: Date = Date(), retentionRate: Double = 10.0, advanceRate: Double = 0.0) {
        self.id = UUID()
        self.title = title
        self.contractDate = contractDate
        self.retentionRate = retentionRate
        self.advanceRate = advanceRate
        self.workItems = []
        self.hakedisler = []
    }

    var totalContractAmount: Double {
        workItems.reduce(0) { $0 + $1.totalAmount }
    }
}

// MARK: - WorkItem (Poz / İş Kalemi)
@Model
final class WorkItem {
    var id: UUID
    var code: String            // Poz no
    var name: String            // İş kalemi adı
    var unit: String            // Birim (m², m³, adet...)
    var unitPrice: Double       // Birim fiyat
    var contractedQuantity: Double  // Sözleşme miktarı
    var location: String        // Mahal / kat
    var contract: Contract?

    @Relationship(deleteRule: .cascade)
    var dailyEntries: [DailyEntry]

    init(code: String, name: String, unit: String, unitPrice: Double, contractedQuantity: Double, location: String = "") {
        self.id = UUID()
        self.code = code
        self.name = name
        self.unit = unit
        self.unitPrice = unitPrice
        self.contractedQuantity = contractedQuantity
        self.location = location
        self.dailyEntries = []
    }

    var totalAmount: Double {
        contractedQuantity * unitPrice
    }

    var completedQuantity: Double {
        dailyEntries.reduce(0) { $0 + $1.quantity }
    }

    var completionPercentage: Double {
        guard contractedQuantity > 0 else { return 0 }
        return min((completedQuantity / contractedQuantity) * 100, 100)
    }

    var remainingQuantity: Double {
        contractedQuantity - completedQuantity
    }
}

// MARK: - DailyEntry (Günlük Saha Girişi)
@Model
final class DailyEntry {
    var id: UUID
    var date: Date
    var quantity: Double
    var location: String        // Mahal / kat
    var notes: String
    var photoData: [Data]       // Fotoğraflar
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

// MARK: - Hakedis
@Model
final class Hakedis {
    var id: UUID
    var periodName: String      // Örn: "Ocak 2025"
    var periodStart: Date
    var periodEnd: Date
    var status: HakedisStatus
    var notes: String
    var contract: Contract?
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var items: [HakedisItem]

    @Relationship(deleteRule: .cascade)
    var payments: [Payment]

    init(periodName: String, periodStart: Date, periodEnd: Date) {
        self.id = UUID()
        self.periodName = periodName
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.status = .draft
        self.notes = ""
        self.items = []
        self.payments = []
        self.createdAt = Date()
    }

    var grossAmount: Double {
        items.reduce(0) { $0 + $1.periodAmount }
    }

    var retentionAmount: Double {
        guard let rate = contract?.retentionRate else { return 0 }
        return grossAmount * (rate / 100)
    }

    var netAmount: Double {
        grossAmount - retentionAmount
    }

    var totalPaid: Double {
        payments.reduce(0) { $0 + $1.amount }
    }

    var remainingAmount: Double {
        netAmount - totalPaid
    }
}

enum HakedisStatus: String, Codable, CaseIterable {
    case draft = "Taslak"
    case pendingApproval = "Onay Bekliyor"
    case approved = "Onaylandı"
    case rejected = "Reddedildi"
    case paid = "Ödendi"
}

// MARK: - HakedisItem (Hakediş Satırı)
@Model
final class HakedisItem {
    var id: UUID
    var workItemName: String
    var workItemCode: String
    var unit: String
    var unitPrice: Double
    var previousQuantity: Double    // Önceki hakedişe kadar yapılan
    var currentQuantity: Double     // Bu dönem yapılan
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

    var cumulativeQuantity: Double {
        previousQuantity + currentQuantity
    }

    var periodAmount: Double {
        currentQuantity * unitPrice
    }

    var cumulativeAmount: Double {
        cumulativeQuantity * unitPrice
    }
}

// MARK: - Payment (Ödeme)
@Model
final class Payment {
    var id: UUID
    var amount: Double
    var paymentDate: Date
    var description: String
    var hakedis: Hakedis?

    init(amount: Double, paymentDate: Date = Date(), description: String = "") {
        self.id = UUID()
        self.amount = amount
        self.paymentDate = paymentDate
        self.description = description
    }
}
