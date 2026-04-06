import Foundation
import SwiftData

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
    /// Geçici teminat: ihale bedeli × %3 (4734 Md.33)
    /// Kullanıcı girişi yoksa hesaplanan bidAmount veya estimatedBudget'ı baz alır
    var bidBondAmount: Double {
        let base = bidAmount > 0 ? bidAmount : (totalWithTax > 0 ? totalWithTax : estimatedBudget)
        return base * 0.03
    }
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

// MARK: - B8 Geçici/Kesin Kabul

struct CommissionMember: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var title: String
    var affiliation: String
    var isSigned: Bool = false
}

enum AcceptanceStatus: String, Codable, CaseIterable {
    case pending = "Bekliyor"
    case inProgress = "Devam Ediyor"
    case acceptedWithDeficiency = "Eksiklikle Kabul"
    case accepted = "Kabul Edildi"
    case rejected = "Reddedildi"
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "arrow.right.circle"
        case .acceptedWithDeficiency: return "checkmark.triangle"
        case .accepted: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal"
        }
    }
    var colorName: String {
        switch self {
        case .pending: return "hakedisWarning"
        case .inProgress: return "hakedisOrange"
        case .acceptedWithDeficiency: return "hakedisWarning"
        case .accepted: return "hakedisSuccess"
        case .rejected: return "hakedisDanger"
        }
    }
}

@Model final class ProvisionalAcceptance {
    var id: UUID
    var acceptanceNo: String
    var contractNo: String
    var contractorName: String
    var statusRaw: String
    var acceptanceDate: Date?
    var scheduledDate: Date
    var commissionMembersJSON: String
    var acceptanceNotes: String
    var defectNotificationDeadline: Date?
    var warrantyPeriodMonths: Int
    var warrantyEndDate: Date?
    var guaranteeReturnDate: Date?
    var deficiencies: [AcceptanceDeficiency]
    var createdAt: Date

    init(acceptanceNo: String, contractNo: String, contractorName: String, scheduledDate: Date) {
        self.id = UUID()
        self.acceptanceNo = acceptanceNo
        self.contractNo = contractNo
        self.contractorName = contractorName
        self.statusRaw = AcceptanceStatus.pending.rawValue
        self.scheduledDate = scheduledDate
        self.commissionMembersJSON = "[]"
        self.acceptanceNotes = ""
        self.warrantyPeriodMonths = 12
        self.deficiencies = []
        self.createdAt = Date()
    }

    var status: AcceptanceStatus {
        get { AcceptanceStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    var commissionMembers: [CommissionMember] {
        get {
            guard let data = commissionMembersJSON.data(using: .utf8),
                  let items = try? JSONDecoder().decode([CommissionMember].self, from: data)
            else { return [] }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                commissionMembersJSON = str
            }
        }
    }
    var openDeficiencyCount: Int { deficiencies.filter { $0.statusRaw != "Giderildi" }.count }
    var isWarrantyExpiring: Bool {
        guard let end = warrantyEndDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0
        return days <= 30 && days >= 0
    }
    var isWarrantyExpired: Bool {
        guard let end = warrantyEndDate else { return false }
        return end < Date()
    }
    static func generateNo(existingCount: Int, year: Int) -> String {
        String(format: "GKB-%d/%03d", year, existingCount + 1)
    }
}

enum DeficiencyStatus: String, Codable, CaseIterable {
    case open = "Açık"
    case inProgress = "Gideriliyor"
    case resolved = "Giderildi"
    case disputed = "İhtilaf"
}

@Model final class AcceptanceDeficiency {
    var id: UUID
    var deficiencyNo: Int
    var deficiencyText: String
    var location: String
    var statusRaw: String
    var responsibleParty: String
    var deadline: Date?
    var resolvedDate: Date?
    var resolvedNotes: String
    var acceptance: ProvisionalAcceptance?

    init(deficiencyNo: Int, deficiencyText: String, location: String) {
        self.id = UUID()
        self.deficiencyNo = deficiencyNo
        self.deficiencyText = deficiencyText
        self.location = location
        self.statusRaw = DeficiencyStatus.open.rawValue
        self.responsibleParty = ""
        self.resolvedNotes = ""
    }

    var status: DeficiencyStatus {
        get { DeficiencyStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
    var isOverdue: Bool {
        guard let d = deadline, status != .resolved else { return false }
        return d < Date()
    }
}

@Model final class FinalAcceptance {
    var id: UUID
    var acceptanceNo: String
    var contractNo: String
    var contractorName: String
    var statusRaw: String
    var acceptanceDate: Date?
    var scheduledDate: Date
    var commissionMembersJSON: String
    var finalAcceptanceNotes: String
    var guaranteeReturnDate: Date?
    var retentionReleaseDate: Date?
    var provisionalAcceptanceId: UUID?
    var createdAt: Date

    init(acceptanceNo: String, contractNo: String, contractorName: String, scheduledDate: Date) {
        self.id = UUID()
        self.acceptanceNo = acceptanceNo
        self.contractNo = contractNo
        self.contractorName = contractorName
        self.statusRaw = AcceptanceStatus.pending.rawValue
        self.scheduledDate = scheduledDate
        self.commissionMembersJSON = "[]"
        self.finalAcceptanceNotes = ""
        self.createdAt = Date()
    }

    var status: AcceptanceStatus {
        get { AcceptanceStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    var commissionMembers: [CommissionMember] {
        get {
            guard let data = commissionMembersJSON.data(using: .utf8),
                  let items = try? JSONDecoder().decode([CommissionMember].self, from: data)
            else { return [] }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                commissionMembersJSON = str
            }
        }
    }
    static func generateNo(existingCount: Int, year: Int) -> String {
        String(format: "KKB-%d/%03d", year, existingCount + 1)
    }
}

// MARK: - B9 Raporlama Motoru

enum ReportType: String, Codable, CaseIterable {
    case weekly = "Haftalık Rapor"
    case monthly = "Aylık Rapor"
    case hakedis = "Hakediş Raporu"
    case financial = "Finansal Rapor"
    case safety = "İSG Raporu"
    case quality = "Kalite Raporu"
    case progress = "İlerleme Raporu"
    case acceptance = "Kabul Raporu"
    case evm = "EVM Raporu"
    case survey = "Keşif Raporu"
    case bid = "İhale Raporu"
    var icon: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .hakedis: return "doc.text.fill"
        case .financial: return "dollarsign.circle"
        case .safety: return "shield.checkered"
        case .quality: return "checkmark.seal"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .acceptance: return "checkmark.seal.fill"
        case .evm: return "chart.xyaxis.line"
        case .survey: return "ruler"
        case .bid: return "doc.text.magnifyingglass"
        }
    }
}

enum ReportSectionType: String, Codable, CaseIterable {
    case summary = "Özet"
    case financial = "Finansal Bilgiler"
    case progress = "İlerleme Durumu"
    case safety = "İSG Bilgileri"
    case quality = "Kalite Kontrol"
    case activities = "Aktiviteler"
    case issues = "Sorunlar"
    case decisions = "Kararlar"
    case photos = "Fotoğraflar"
    case appendix = "Ekler"
}

struct ReportSection: Codable, Identifiable {
    var id: UUID = UUID()
    var typeRaw: String
    var sectionTitle: String
    var isEnabled: Bool = true
    var sortOrder: Int
    var sectionType: ReportSectionType {
        get { ReportSectionType(rawValue: typeRaw) ?? .summary }
        set { typeRaw = newValue.rawValue }
    }
}

@Model final class ReportTemplate {
    var id: UUID
    var templateName: String
    var typeRaw: String
    var sectionsJSON: String
    var isDefault: Bool
    var notes: String
    var createdAt: Date

    init(templateName: String, type: ReportType) {
        self.id = UUID()
        self.templateName = templateName
        self.typeRaw = type.rawValue
        self.sectionsJSON = "[]"
        self.isDefault = false
        self.notes = ""
        self.createdAt = Date()
    }

    var reportType: ReportType {
        get { ReportType(rawValue: typeRaw) ?? .weekly }
        set { typeRaw = newValue.rawValue }
    }
    var sections: [ReportSection] {
        get {
            guard let data = sectionsJSON.data(using: .utf8),
                  let items = try? JSONDecoder().decode([ReportSection].self, from: data)
            else { return [] }
            return items.sorted(by: { $0.sortOrder < $1.sortOrder })
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                sectionsJSON = str
            }
        }
    }
    var enabledSections: [ReportSection] { sections.filter(\.isEnabled) }
    static func defaultSections(for type: ReportType) -> [ReportSection] {
        let sectionTypes: [ReportSectionType]
        switch type {
        case .weekly, .monthly, .progress:
            sectionTypes = [.summary, .progress, .activities, .issues, .photos]
        case .financial, .evm:
            sectionTypes = [.summary, .financial, .appendix]
        case .safety:
            sectionTypes = [.summary, .safety, .issues, .appendix]
        case .quality:
            sectionTypes = [.summary, .quality, .issues, .appendix]
        case .hakedis:
            sectionTypes = [.summary, .financial, .progress, .appendix]
        default:
            sectionTypes = [.summary, .appendix]
        }
        return sectionTypes.enumerated().map { i, t in
            ReportSection(typeRaw: t.rawValue, sectionTitle: t.rawValue, sortOrder: i)
        }
    }
}
