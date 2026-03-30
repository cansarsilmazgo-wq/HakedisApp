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
