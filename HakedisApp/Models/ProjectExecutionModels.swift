import Foundation
import SwiftData

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

        // Ek iş / keşif eksilişi (ChangeOrder) — onaylanan tutarlar
        let approvedChanges = c.changeOrders.filter { $0.status == .approved }
        self.totalWorkIncrease = approvedChanges.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        self.totalWorkDecrease = abs(approvedChanges.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount })
        // Fiyat farkı — PriceDifferenceRecord hesaplarından (contract.priceDifferenceRecords)
        self.totalPriceDifference = c.priceDifferenceRecords.reduce(0) { $0 + $1.priceDifference }
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

