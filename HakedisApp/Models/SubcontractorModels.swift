import Foundation
import SwiftData

// MARK: - Dispute Enums

enum DisputeType: String, Codable, CaseIterable {
    case hakedisAmount = "Hakediş Tutarı İtirazı"
    case paymentDelay  = "Ödeme Gecikmesi"
    case workScope     = "İş Kapsamı Anlaşmazlığı"
    case quality       = "Kalite İtirazı"
    case other         = "Diğer"
}

enum DisputeStatus: String, Codable, CaseIterable {
    case open        = "Açık"
    case underReview = "İnceleniyor"
    case resolved    = "Çözüldü"
    case rejected    = "Reddedildi"

    var icon: String {
        switch self {
        case .open:        return "exclamationmark.circle.fill"
        case .underReview: return "magnifyingglass.circle.fill"
        case .resolved:    return "checkmark.circle.fill"
        case .rejected:    return "xmark.circle.fill"
        }
    }
}

// MARK: - WorkOrderPriority

enum WorkOrderPriority: String, Codable, CaseIterable {
    case low    = "Düşük"
    case normal = "Normal"
    case high   = "Yüksek"
    case urgent = "Acil"

    var icon: String {
        switch self {
        case .low:    return "arrow.down.circle"
        case .normal: return "minus.circle"
        case .high:   return "arrow.up.circle"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }
}

enum WorkOrderCompletionStatus: String, Codable, CaseIterable {
    case pending    = "Beklemede"
    case inProgress = "Devam Ediyor"
    case completed  = "Tamamlandı"
    case overdue    = "Gecikmiş"
}

// MARK: - SubcontractorDispute Model

@Model
final class SubcontractorDispute {
    var id: UUID
    var disputeDate: Date
    var disputeTypeRaw: String
    var subject: String
    var details: String
    var requestedAmount: Double?
    var statusRaw: String
    var resolution: String?
    var photoData: [Data]
    @Relationship var contractor: Contractor?
    @Relationship var contract: Contract?
    @Relationship var hakedis: Hakedis?
    var createdAt: Date

    init(subject: String, details: String, disputeType: DisputeType = .other) {
        self.id = UUID()
        self.disputeDate = Date()
        self.disputeTypeRaw = disputeType.rawValue
        self.subject = subject
        self.details = details
        self.statusRaw = DisputeStatus.open.rawValue
        self.photoData = []
        self.createdAt = Date()
    }

    var disputeType: DisputeType {
        get { DisputeType(rawValue: disputeTypeRaw) ?? .other }
        set { disputeTypeRaw = newValue.rawValue }
    }

    var status: DisputeStatus {
        get { DisputeStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var isOpen: Bool { status == .open }
    var isResolved: Bool { status == .resolved || status == .rejected }
}

// MARK: - SubcontractorWorkOrder Model (taşerona özel iş emri)

@Model
final class SubcontractorWorkOrder {
    var id: UUID
    var orderTitle: String
    var orderDescription: String
    var assignedDate: Date
    var dueDate: Date?
    var priorityRaw: String
    var completionStatusRaw: String
    var completionDate: Date?
    var completionNotes: String?
    var completionPhotoData: [Data]
    @Relationship var contractor: Contractor?
    @Relationship var contract: Contract?
    var createdAt: Date

    init(orderTitle: String, orderDescription: String = "", priority: WorkOrderPriority = .normal) {
        self.id = UUID()
        self.orderTitle = orderTitle
        self.orderDescription = orderDescription
        self.assignedDate = Date()
        self.priorityRaw = priority.rawValue
        self.completionStatusRaw = WorkOrderCompletionStatus.pending.rawValue
        self.completionPhotoData = []
        self.createdAt = Date()
    }

    var priority: WorkOrderPriority {
        get { WorkOrderPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var completionStatus: WorkOrderCompletionStatus {
        get { WorkOrderCompletionStatus(rawValue: completionStatusRaw) ?? .pending }
        set { completionStatusRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let due = dueDate else { return false }
        return completionStatus != .completed && Date() > due
    }

    var isCompleted: Bool { completionStatus == .completed }
}

// MARK: - SubcontractorMaterialRequest Model

enum MaterialRequestStatus: String, Codable, CaseIterable {
    case pending   = "Beklemede"
    case approved  = "Onaylandı"
    case rejected  = "Reddedildi"
    case delivered = "Teslim Edildi"

    var icon: String {
        switch self {
        case .pending:   return "clock.fill"
        case .approved:  return "checkmark.seal.fill"
        case .rejected:  return "xmark.seal.fill"
        case .delivered: return "shippingbox.fill"
        }
    }
}

@Model
final class SubcontractorMaterialRequest {
    var id: UUID
    var requestDate: Date
    var materialName: String
    var quantity: Double
    var unit: String
    var neededByDate: Date?
    var justification: String
    var statusRaw: String
    var responseNotes: String?
    @Relationship var contractor: Contractor?
    @Relationship var contract: Contract?
    var createdAt: Date

    init(materialName: String, quantity: Double, unit: String, justification: String = "") {
        self.id = UUID()
        self.requestDate = Date()
        self.materialName = materialName
        self.quantity = quantity
        self.unit = unit
        self.justification = justification
        self.statusRaw = MaterialRequestStatus.pending.rawValue
        self.createdAt = Date()
    }

    var status: MaterialRequestStatus {
        get { MaterialRequestStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

// MARK: - SubcontractorAdditionalWork (İş artışı bildirimi)

@Model
final class SubcontractorAdditionalWork {
    var id: UUID
    var reportDate: Date
    var workTitle: String
    var workDescription: String
    var estimatedAmount: Double?
    var statusRaw: String
    var responseNotes: String?
    var photoData: [Data]
    @Relationship var contractor: Contractor?
    @Relationship var contract: Contract?
    var createdAt: Date

    init(workTitle: String, workDescription: String) {
        self.id = UUID()
        self.reportDate = Date()
        self.workTitle = workTitle
        self.workDescription = workDescription
        self.statusRaw = MaterialRequestStatus.pending.rawValue
        self.photoData = []
        self.createdAt = Date()
    }

    var status: MaterialRequestStatus {
        get { MaterialRequestStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
