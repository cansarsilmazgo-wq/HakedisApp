import Foundation
import SwiftData

// MARK: - Enums

enum StructuralSystem: String, Codable, CaseIterable {
    case reinforcedConcrete = "Betonarme Karkas"
    case masonryBearing     = "Yığma (Taşıyıcı Duvar)"
    case steelFrame         = "Çelik Karkas"
    case precast            = "Prefabrik"
    case mixed              = "Karma"
    case historical         = "Tarihi Yapı"
}

enum SoilClass: String, Codable, CaseIterable {
    case za = "ZA — Sağlam Kaya"
    case zb = "ZB — Kaya"
    case zc = "ZC — Sıkı Kum/Sert Kil"
    case zd = "ZD — Gevşek Kum/Yumuşak Kil"
    case ze = "ZE — Çok Yumuşak Zemin"

    var riskLevel: String {
        switch self {
        case .za, .zb: return "Düşük Risk"
        case .zc: return "Orta Risk"
        case .zd: return "Yüksek Risk"
        case .ze: return "Çok Yüksek Risk"
        }
    }
}

enum SeismicZone: String, Codable, CaseIterable {
    case zone1 = "1. Derece (Çok Yüksek)"
    case zone2 = "2. Derece (Yüksek)"
    case zone3 = "3. Derece (Orta)"
    case zone4 = "4. Derece (Düşük)"
    case zone5 = "5. Derece (Çok Düşük)"
}

enum AssessmentResult: String, Codable, CaseIterable {
    case safe            = "Güvenli"
    case limitedSafe     = "Sınırlı Güvenli"
    case unsafeLowRisk   = "Güvensiz — Düşük Risk"
    case unsafeHighRisk  = "Güvensiz — Yüksek Risk"
    case collapse        = "Göçme Riski"

    var icon: String {
        switch self {
        case .safe:           return "checkmark.shield.fill"
        case .limitedSafe:    return "exclamationmark.shield.fill"
        case .unsafeLowRisk:  return "shield.slash"
        case .unsafeHighRisk: return "shield.slash.fill"
        case .collapse:       return "flame.fill"
        }
    }

    static func fromScore(_ score: Double) -> AssessmentResult {
        switch score {
        case 80...:     return .safe
        case 60..<80:   return .limitedSafe
        case 40..<60:   return .unsafeLowRisk
        case 20..<40:   return .unsafeHighRisk
        default:        return .collapse
        }
    }
}

enum SeismicCheckCategory: String, Codable, CaseIterable {
    case foundation    = "Temel"
    case columns       = "Kolonlar"
    case beams         = "Kirişler"
    case slabs         = "Döşemeler"
    case shearWalls    = "Perde Duvarlar"
    case masonry       = "Dolgu Duvarlar"
    case connections   = "Birleşim Noktaları"
    case irregularity  = "Düzensizlikler"
    case nonStructural = "Yapısal Olmayan Elemanlar"

    var icon: String {
        switch self {
        case .foundation:    return "square.3.layers.3d.down.forward"
        case .columns:       return "rectangle.portrait.fill"
        case .beams:         return "minus.rectangle.fill"
        case .slabs:         return "square.grid.2x2.fill"
        case .shearWalls:    return "rectangle.fill"
        case .masonry:       return "brickwall.fill"
        case .connections:   return "link"
        case .irregularity:  return "exclamationmark.triangle.fill"
        case .nonStructural: return "house.fill"
        }
    }
}

enum SeismicCheckResult: String, Codable, CaseIterable {
    case pass          = "Uygun"
    case fail          = "Uygunsuz"
    case notApplicable = "Uygulanamaz"
}

// MARK: - SeismicAssessment

@Model
final class SeismicAssessment {
    var id: UUID
    var assessmentDate: Date
    var buildingAge: Int?
    var floorCount: Int
    var structuralSystemRaw: String
    var soilClassRaw: String
    var seismicZoneRaw: String
    var hasGeotechnicalReport: Bool
    var geotechnicalReportDate: Date?
    var geotechnicalReportNo: String?
    var assessmentResultRaw: String?
    var retrofitRequired: Bool
    var retrofitType: String?
    var estimatedRetrofitCost: Double?
    var notes: String?
    @Relationship(deleteRule: .cascade) var checklistItems: [SeismicChecklistItem]
    @Relationship var project: Project?
    var createdAt: Date

    init(floorCount: Int, structuralSystem: StructuralSystem = .reinforcedConcrete) {
        self.id = UUID()
        self.assessmentDate = Date()
        self.floorCount = floorCount
        self.structuralSystemRaw = structuralSystem.rawValue
        self.soilClassRaw = SoilClass.zc.rawValue
        self.seismicZoneRaw = SeismicZone.zone1.rawValue
        self.hasGeotechnicalReport = false
        self.retrofitRequired = false
        self.checklistItems = []
        self.createdAt = Date()
    }

    var structuralSystem: StructuralSystem {
        get { StructuralSystem(rawValue: structuralSystemRaw) ?? .reinforcedConcrete }
        set { structuralSystemRaw = newValue.rawValue }
    }

    var soilClass: SoilClass {
        get { SoilClass(rawValue: soilClassRaw) ?? .zc }
        set { soilClassRaw = newValue.rawValue }
    }

    var seismicZone: SeismicZone {
        get { SeismicZone(rawValue: seismicZoneRaw) ?? .zone1 }
        set { seismicZoneRaw = newValue.rawValue }
    }

    var assessmentResult: AssessmentResult? {
        get { assessmentResultRaw.flatMap { AssessmentResult(rawValue: $0) } }
        set { assessmentResultRaw = newValue?.rawValue }
    }

    // Otomatik skor: uygun / (uygun + uygunsuz) × 100
    var safetyScore: Double {
        let applicable = checklistItems.filter { $0.result != .notApplicable }
        guard !applicable.isEmpty else { return 0 }
        let passing = applicable.filter { $0.result == .pass }
        return Double(passing.count) / Double(applicable.count) * 100
    }

    var autoResult: AssessmentResult {
        AssessmentResult.fromScore(safetyScore)
    }

    func updateResult() {
        assessmentResult = autoResult
        retrofitRequired = autoResult != .safe
    }
}

// MARK: - SeismicChecklistItem

@Model
final class SeismicChecklistItem {
    var id: UUID
    var categoryRaw: String
    var checkDescription: String
    var resultRaw: String
    var notes: String?
    var photoData: Data?
    @Relationship var assessment: SeismicAssessment?
    var createdAt: Date

    init(category: SeismicCheckCategory, checkDescription: String) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.checkDescription = checkDescription
        self.resultRaw = SeismicCheckResult.notApplicable.rawValue
        self.createdAt = Date()
    }

    var category: SeismicCheckCategory {
        get { SeismicCheckCategory(rawValue: categoryRaw) ?? .foundation }
        set { categoryRaw = newValue.rawValue }
    }

    var result: SeismicCheckResult {
        get { SeismicCheckResult(rawValue: resultRaw) ?? .notApplicable }
        set { resultRaw = newValue.rawValue }
    }
}

// MARK: - Checklist Template Provider (TBDY 2018)

struct SeismicChecklistTemplateProvider {
    static func items(for category: SeismicCheckCategory) -> [String] {
        switch category {
        case .foundation:
            return [
                "Temel tipi yeterli mi (sürekli/radye/kazık)",
                "Temel derinliği yeterli mi",
                "Temel çatlak/oturma var mı",
                "Temel-kolon bağlantısı sağlam mı",
                "Su yalıtımı mevcut mu",
                "Zemin etüdüne uygun temel seçimi yapılmış mı"
            ]
        case .columns:
            return [
                "Kolon boyutları yeterli mi (min 30×30 cm)",
                "Kolon donatı oranı yeterli mi (min %1)",
                "Etriye aralığı uygun mu (max 10 cm — kritik bölge)",
                "Kolon-kiriş birleşim bölgesi yeterli mi",
                "135° kanca var mı",
                "Kolon çatlağı/hasar var mı",
                "Kolon pas payı yeterli mi",
                "Kısa kolon oluşumu var mı"
            ]
        case .beams:
            return [
                "Kiriş boyutları yeterli mi",
                "Kiriş donatısı yeterli mi",
                "Etriye sıklaştırma bölgesi var mı",
                "Kiriş çatlağı var mı",
                "Kiriş-kolon birleşim yeterli mi",
                "Geniş kiriş kullanımı var mı"
            ]
        case .slabs:
            return [
                "Döşeme kalınlığı yeterli mi (min 12 cm)",
                "Döşeme donatısı yeterli mi",
                "Döşeme çatlağı var mı",
                "Konsol döşeme güvenli mi"
            ]
        case .shearWalls:
            return [
                "Perde duvar yeterli mi",
                "Perde duvar donatısı uygun mu",
                "Perde duvar simetrik düzende mi",
                "Perde duvar-döşeme bağlantısı sağlam mı"
            ]
        case .masonry:
            return [
                "Dolgu duvar bağlantısı yeterli mi",
                "Dolgu duvarlar taşıyıcıları kesmekte mi",
                "Pencere/kapı boşlukları yeterli mi",
                "Dolu/boş oranı uygun mu"
            ]
        case .connections:
            return [
                "Tüm birleşimler düzgün mü",
                "Döşeme-kiriş bağlantısı sağlam mı",
                "Merdiven-yapı bağlantısı yeterli mi"
            ]
        case .irregularity:
            return [
                "Yumuşak kat var mı (zemin kat boş, üst katlar dolu)",
                "Ağır çıkma var mı",
                "Burulma düzensizliği var mı",
                "Bitişik nizam çarpma riski var mı",
                "Planda düzensizlik var mı",
                "Düşeyde düzensizlik var mı"
            ]
        case .nonStructural:
            return [
                "Cephe kaplaması güvenli mi",
                "Bölme duvarlar güvenli mi",
                "Tesisat bağlantıları yeterli mi",
                "Asma tavan güvenli mi"
            ]
        }
    }

    static func allItems() -> [SeismicChecklistItem] {
        SeismicCheckCategory.allCases.flatMap { category in
            items(for: category).map { SeismicChecklistItem(category: category, checkDescription: $0) }
        }
    }
}
