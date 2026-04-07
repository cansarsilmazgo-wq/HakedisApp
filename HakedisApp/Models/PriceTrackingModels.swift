import Foundation
import SwiftData

// MARK: - PriceTracker

@Model
final class PriceTracker {
    var id: UUID
    var materialName: String
    var unit: String
    var contractPrice: Double
    var currentMarketPrice: Double
    var lastUpdateDate: Date
    var priceHistoryJSON: String     // JSON: [{date, price}]
    var alertThreshold: Double       // % sapma eşiği
    @Relationship var project: Project?
    var createdAt: Date

    init(materialName: String, unit: String, contractPrice: Double, currentMarketPrice: Double = 0) {
        self.id = UUID()
        self.materialName = materialName
        self.unit = unit
        self.contractPrice = contractPrice
        self.currentMarketPrice = currentMarketPrice > 0 ? currentMarketPrice : contractPrice
        self.lastUpdateDate = Date()
        self.priceHistoryJSON = "[]"
        self.alertThreshold = 10.0
        self.createdAt = Date()
    }

    // (current - contract) / contract × 100
    var variancePercentage: Double {
        guard contractPrice > 0 else { return 0 }
        return (currentMarketPrice - contractPrice) / contractPrice * 100
    }

    var isOverThreshold: Bool { abs(variancePercentage) >= alertThreshold }

    var varianceAmount: Double { currentMarketPrice - contractPrice }

    var varianceColor: String {
        let pct = variancePercentage
        if pct > 20 { return "hakedisDanger" }
        if pct > alertThreshold { return "hakedisWarning" }
        return "hakedisSuccess"
    }

    // MARK: Price History

    struct PricePoint: Codable {
        var date: String   // ISO8601
        var price: Double
    }

    var priceHistory: [PricePoint] {
        get {
            guard let data = priceHistoryJSON.data(using: .utf8),
                  let points = try? JSONDecoder().decode([PricePoint].self, from: data) else {
                return []
            }
            return points
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                priceHistoryJSON = str
            }
        }
    }

    func addPricePoint(price: Double) {
        var history = priceHistory
        let point = PricePoint(date: ISO8601DateFormatter().string(from: Date()), price: price)
        history.append(point)
        if history.count > 24 { history.removeFirst() }
        priceHistory = history
        currentMarketPrice = price
        lastUpdateDate = Date()
    }
}

// MARK: - MarketPriceEntry

@Model
final class MarketPriceEntry {
    var id: UUID
    var entryDate: Date
    var materialName: String
    var supplierName: String?
    var unitPrice: Double
    var unit: String
    var region: String?
    var source: String?
    var notes: String?
    @Relationship var project: Project?
    var createdAt: Date

    init(materialName: String, unitPrice: Double, unit: String) {
        self.id = UUID()
        self.entryDate = Date()
        self.materialName = materialName
        self.unitPrice = unitPrice
        self.unit = unit
        self.createdAt = Date()
    }
}

// MARK: - BayindirlikFiyat (Bayındırlık Birim Fiyat)

@Model
final class BayindirlikFiyat {
    var id: UUID
    var pozNo: String         // Poz numarası
    var pozName: String       // Poz adı
    var unit: String          // Birim
    var previousYearPrice: Double  // Önceki yıl birim fiyatı
    var currentYearPrice: Double   // Bu yıl birim fiyatı
    var updateYear: Int
    var notes: String?
    var createdAt: Date

    init(pozNo: String, pozName: String, unit: String, previousYearPrice: Double, currentYearPrice: Double, updateYear: Int) {
        self.id = UUID()
        self.pozNo = pozNo
        self.pozName = pozName
        self.unit = unit
        self.previousYearPrice = previousYearPrice
        self.currentYearPrice = currentYearPrice
        self.updateYear = updateYear
        self.createdAt = Date()
    }

    var changePercentage: Double {
        guard previousYearPrice > 0 else { return 0 }
        return (currentYearPrice - previousYearPrice) / previousYearPrice * 100
    }
}
