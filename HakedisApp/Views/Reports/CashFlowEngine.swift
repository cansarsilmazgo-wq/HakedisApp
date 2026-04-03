import Foundation

// MARK: - Senaryo Türü (CashFlowEngine ile birlikte test edilebilir olması için buraya taşındı)

enum NakitSenaryosu: String, CaseIterable, Identifiable {
    case optimist  = "Optimist"
    case gercekci  = "Gerçekçi"
    case kotumser  = "Kötümser"

    var id: String { rawValue }

    var aciklama: String {
        switch self {
        case .optimist:  return "0 gün gecikme"
        case .gercekci:  return "Ort. gecikme"
        case .kotumser:  return "2× ort. gecikme"
        }
    }

    var icon: String {
        switch self {
        case .optimist:  return "arrow.up.forward.circle.fill"
        case .gercekci:  return "equal.circle.fill"
        case .kotumser:  return "arrow.down.forward.circle.fill"
        }
    }
}

// MARK: - Aylık Projeksiyon Verisi

struct AylikProje: Identifiable {
    let id = UUID()
    let ay: String               // "Nis 2026"
    let date: Date
    let beklenenHakedis: Double
    let beklenenTahsilat: Double
    let kumulatifNakit: Double
    let gecikmeSuresi: Double    // gün olarak bu senaryo için gecikme
}

// MARK: - CashFlowEngine
// Nakit akış projeksiyon hesaplarını View'dan bağımsız hale getirir.
// CashFlowView bu struct'ı kullanır; testler doğrudan bu struct'ı test eder.

struct CashFlowEngine {

    // MARK: - Gecikme Analizi

    /// Tüm ödemelerdeki ortalama gecikme süresi (gün).
    /// Yalnızca vadeden sonra yapılan ödemeler hesaba katılır.
    /// Hiç geç ödeme yoksa 0 döner (varsayılan "veri yok" durumu — View kararıyla 30 gösterilebilir).
    static func ortalamGecikmeGun(hakedisler: [Hakedis]) -> Double {
        var delayDays: [Double] = []
        for h in hakedisler {
            guard let due = h.dueDate else { continue }
            for payment in h.payments {
                let days = Calendar.current.dateComponents(
                    [.day], from: due, to: payment.paymentDate
                ).day ?? 0
                if days > 0 { delayDays.append(Double(days)) }
            }
        }
        guard !delayDays.isEmpty else { return 0 }
        return delayDays.reduce(0, +) / Double(delayDays.count)
    }

    // MARK: - Ortalama Aylık Hakediş

    /// Son 3 aya ait hakedişlerin aylık brüt ortalaması.
    /// Yeterli veri yoksa tüm hakedişlerin ortalamasına düşer.
    static func ortalamaAylikHakedis(hakedisler: [Hakedis], referenceDate: Date = Date()) -> Double {
        let cal = Calendar.current
        let son3 = cal.date(byAdding: .month, value: -3, to: referenceDate) ?? referenceDate
        let son3Hakedis = hakedisler.filter { $0.periodEnd >= son3 }

        if son3Hakedis.isEmpty {
            let total = hakedisler.reduce(0) { $0 + $1.grossAmount }
            return hakedisler.isEmpty ? 0 : total / Double(hakedisler.count)
        }

        let aylar = Set(son3Hakedis.map { h -> Date in
            let comps = cal.dateComponents([.year, .month], from: h.periodEnd)
            return cal.date(from: comps) ?? h.periodEnd
        })
        let ayCount = max(Double(aylar.count), 1)
        let total = son3Hakedis.reduce(0) { $0 + $1.grossAmount }
        return total / ayCount
    }

    // MARK: - Gecikme Senaryosu

    static func gecikmeGunu(senaryo: NakitSenaryosu, ortalama: Double) -> Double {
        switch senaryo {
        case .optimist:  return 0
        case .gercekci:  return ortalama
        case .kotumser:  return ortalama * 2
        }
    }

    // MARK: - 3 Aylık Projeksiyon

    /// 3 aylık nakit akış projeksiyonu.
    static func projeksiyonlar(
        hakedisler: [Hakedis],
        senaryo: NakitSenaryosu,
        referenceDate: Date = Date()
    ) -> [AylikProje] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.dateFormat = "MMM yyyy"

        let ortGecikme = ortalamGecikmeGun(hakedisler: hakedisler)
        let hakedisOrtalama = ortalamaAylikHakedis(hakedisler: hakedisler, referenceDate: referenceDate)
        let gecikmeGun = gecikmeGunu(senaryo: senaryo, ortalama: ortGecikme > 0 ? ortGecikme : 30)

        var kumulatif: Double = 0
        return (1...3).map { offset in
            let baseDate = cal.date(byAdding: .month, value: offset, to: referenceDate) ?? referenceDate
            let comps = cal.dateComponents([.year, .month], from: baseDate)
            let monthDate = cal.date(from: comps) ?? baseDate

            let tahsilatOrani: Double
            if gecikmeGun == 0 {
                tahsilatOrani = 1.0
            } else {
                let offsetAy = Int(gecikmeGun / 30.0)
                tahsilatOrani = offset > offsetAy ? 1.0 : (offset == offsetAy ? 0.6 : 0.0)
            }

            let tahsilat = hakedisOrtalama * tahsilatOrani
            kumulatif += tahsilat - hakedisOrtalama

            return AylikProje(
                ay: fmt.string(from: monthDate),
                date: monthDate,
                beklenenHakedis: hakedisOrtalama,
                beklenenTahsilat: tahsilat,
                kumulatifNakit: kumulatif,
                gecikmeSuresi: gecikmeGun
            )
        }
    }

    // MARK: - Kümülatif Nakit

    static func toplamBeklenenTahsilat(projeksiyonlar: [AylikProje]) -> Double {
        projeksiyonlar.reduce(0) { $0 + $1.beklenenTahsilat }
    }

    static func kritikAyVarMi(projeksiyonlar: [AylikProje]) -> Bool {
        projeksiyonlar.contains { $0.kumulatifNakit < 0 }
    }
}

// MARK: - Genişletilmiş Nakit Akış (Bölüm 3)

struct AylikDetayliProje: Identifiable {
    let id = UUID()
    let ay: String
    let date: Date
    // Gelirler
    var hakedisGeliri: Double        // planlanan hakedişlerden
    var fiyatFarkiGeliri: Double     // fiyat farkı hesaplarından
    var diger: Double                // diğer
    // Giderler
    var malzemeGideri: Double        // stok girişleri
    var iscilikGideri: Double        // attendance adam-gün × maliyet
    var ekipmanGideri: Double        // equipment log fuel + rental
    var taseronGideri: Double        // taşeron ödemeleri (netAmount)

    var toplamGelir:  Double { hakedisGeliri + fiyatFarkiGeliri + diger }
    var toplamGider:  Double { malzemeGideri + iscilikGideri + ekipmanGideri + taseronGideri }
    var fark:         Double { toplamGelir - toplamGider }
    var kumulatif:    Double = 0
}

struct GenisletilmisCashFlowEngine {

    /// Ay-yıl anahtarı oluştur
    static func ayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)-\(String(format: "%02d", c.month ?? 0))"
    }

    static func ayLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.dateFormat = "MMM yyyy"
        return fmt.string(from: date)
    }

    /// n aylık (3/6/12) detaylı projeksiyon
    static func projeksiyon(
        hakedisler: [Hakedis],
        priceDiffCalcs: [PriceDifferenceCalc],
        stockEntries: [StockEntry],
        attendanceRecords: [Attendance],
        equipmentLogs: [EquipmentLog],
        subHakedisler: [SubcontractorHakedis],
        ayCount: Int,
        referenceDate: Date = Date(),
        laborDailyRate: Double = 800   // varsayılan işçilik birim maliyeti (TL/adam-gün)
    ) -> [AylikDetayliProje] {
        let cal = Calendar.current

        // Ay aralığı
        var months: [Date] = []
        for i in 1...ayCount {
            guard let d = cal.date(byAdding: .month, value: i, to: referenceDate) else { continue }
            let c = cal.dateComponents([.year, .month], from: d)
            if let md = cal.date(from: c) { months.append(md) }
        }

        // Geçmiş verilere dayalı aylık ortalamalar (referans ay bazında)
        let avgHakedis = CashFlowEngine.ortalamaAylikHakedis(hakedisler: hakedisler, referenceDate: referenceDate)
        let avgDelay   = max(CashFlowEngine.ortalamGecikmeGun(hakedisler: hakedisler), 30)

        // Stok gider map (ay → toplam giriş tutarı)
        var stockMap: [String: Double] = [:]
        for e in stockEntries where e.entryType == .incoming {
            let k = ayKey(e.date)
            stockMap[k, default: 0] += e.quantity * (e.material?.unitPrice ?? 0)
        }

        // İşçilik gider map (ay → adam-gün × birimMaliyet)
        var laborMap: [String: Double] = [:]
        for a in attendanceRecords where a.isPresent {
            let k = ayKey(a.date)
            laborMap[k, default: 0] += (a.totalHours / 8.0) * laborDailyRate
        }

        // Ekipman gider map (ay → yakıt + kira)
        var equipMap: [String: Double] = [:]
        for log in equipmentLogs {
            let k = ayKey(log.date)
            equipMap[k, default: 0] += (log.fuelCost ?? 0)
                + (log.equipment?.ownershipType == .rented ? (log.equipment?.dailyRentalCost ?? 0) : 0)
        }

        // Taşeron ödeme map (ay → netAmount)
        var taseronMap: [String: Double] = [:]
        for sh in subHakedisler {
            let k = ayKey(sh.periodEnd)
            taseronMap[k, default: 0] += sh.netAmount
        }

        // Fiyat farkı ortalama
        let avgPriceDiff = priceDiffCalcs.isEmpty ? 0 :
            priceDiffCalcs.reduce(0) { $0 + $1.priceDifferenceAmount } / Double(priceDiffCalcs.count)

        // Aylık projeksiyon listesi
        var result: [AylikDetayliProje] = []
        var cumulative: Double = 0

        for m in months {
            let k = ayKey(m)
            let delayOffset = Int(avgDelay / 30.0)
            let tahsilatOrani: Double = delayOffset == 0 ? 1.0 : 0.6

            var proje = AylikDetayliProje(
                ay: ayLabel(m), date: m,
                hakedisGeliri: avgHakedis * tahsilatOrani,
                fiyatFarkiGeliri: avgPriceDiff > 0 ? avgPriceDiff : 0,
                diger: 0,
                malzemeGideri: stockMap[k] ?? 0,
                iscilikGideri: laborMap[k] ?? 0,
                ekipmanGideri: equipMap[k] ?? 0,
                taseronGideri: taseronMap[k] ?? 0
            )
            cumulative += proje.fark
            proje.kumulatif = cumulative
            result.append(proje)
        }
        return result
    }

    /// Bu ayki net nakit akış
    static func buAyNetAkis(
        hakedisler: [Hakedis],
        priceDiffCalcs: [PriceDifferenceCalc],
        stockEntries: [StockEntry],
        attendanceRecords: [Attendance],
        equipmentLogs: [EquipmentLog],
        subHakedisler: [SubcontractorHakedis]
    ) -> Double {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let thisMonth = cal.date(from: comps) ?? now
        let key = ayKey(thisMonth)

        let avgH = CashFlowEngine.ortalamaAylikHakedis(hakedisler: hakedisler)
        let avgPD = priceDiffCalcs.isEmpty ? 0 :
            priceDiffCalcs.reduce(0) { $0 + $1.priceDifferenceAmount } / Double(priceDiffCalcs.count)

        var stockGider: Double = 0
        for e in stockEntries where e.entryType == .incoming && ayKey(e.date) == key {
            stockGider += e.quantity * (e.material?.unitPrice ?? 0)
        }
        var laborGider: Double = 0
        for a in attendanceRecords where a.isPresent && ayKey(a.date) == key {
            laborGider += (a.totalHours / 8.0) * 800
        }
        var equipGider: Double = 0
        for log in equipmentLogs where ayKey(log.date) == key {
            equipGider += (log.fuelCost ?? 0)
        }
        let taseronGider = subHakedisler.filter { ayKey($0.periodEnd) == key }
            .reduce(0) { $0 + $1.netAmount }

        let gelir = avgH + max(avgPD, 0)
        let gider = stockGider + laborGider + equipGider + taseronGider
        return gelir - gider
    }
}
