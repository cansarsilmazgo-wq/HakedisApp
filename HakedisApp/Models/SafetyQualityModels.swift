import Foundation
import SwiftData

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

    /// Taşeron kârı: idare hakediş geliri - taşerona ödenen tutar
    /// Ana sözleşmedeki aynı dönem onaylı hakedişler toplamından taşeron gross tutarını çıkar
    var profitAmount: Double {
        guard let c = contract else { return 0 }
        let anaGross = c.hakedisler
            .filter { ($0.status == .approved || $0.status == .paid)
                   && $0.periodStart >= periodStart && $0.periodEnd <= periodEnd }
            .reduce(0) { $0 + $1.effectiveGrossAmount }
        return anaGross > 0 ? anaGross - grossAmount : 0
    }
    var profitMargin: Double {
        guard let c = contract else { return 0 }
        let anaGross = c.hakedisler
            .filter { ($0.status == .approved || $0.status == .paid)
                   && $0.periodStart >= periodStart && $0.periodEnd <= periodEnd }
            .reduce(0) { $0 + $1.effectiveGrossAmount }
        guard anaGross > 0 else { return 0 }
        return (anaGross - grossAmount) / anaGross * 100
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

