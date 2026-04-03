import UIKit

// MARK: - AttendancePDFGenerator
// Aylık puantaj tablosu PDF'i üretir. A4 (595.2 × 841.8 pt) yatay veya dikey.
// Satırlar: işçi adı; Sütunlar: ayın günleri (1–31); Alt toplam: adam-gün + SGK günü.

struct AttendancePDFGenerator {
    // A4 yatay: daha fazla gün sütunu sığar (gün sayısı ≤ 31)
    private static let pageWidth: CGFloat  = 841.8
    private static let pageHeight: CGFloat = 595.2
    private static let margin: CGFloat     = 28
    private static let orange = UIColor(red: 0.96, green: 0.45, blue: 0.13, alpha: 1)

    // MARK: - Public API

    /// Verilen ay ve projeye ait aylık puantaj tablosu PDF'i üretir.
    /// - Parameters:
    ///   - records: Tüm Attendance kayıtları (filtreleme burada yapılır)
    ///   - month: Ayın herhangi bir tarihi (takvim ayı otomatik hesaplanır)
    ///   - projectName: Başlıkta gösterilecek proje adı (nil → "Tüm Projeler")
    static func generateMonthly(
        records: [Attendance],
        month: Date,
        projectName: String? = nil
    ) -> Data {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: month)
        let firstDay = cal.date(from: comps)!
        let daysInMonth = cal.range(of: .day, in: .month, for: firstDay)!.count

        // Aya ait kayıtları filtrele
        let monthRecords = records.filter {
            let c = cal.dateComponents([.year, .month], from: $0.date)
            return c.year == comps.year && c.month == comps.month
        }

        // İşçileri alfabetik sırala
        let workerNames = Array(Set(monthRecords.map { $0.workerName })).sorted()

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y = drawPageHeader(
                month: firstDay,
                daysInMonth: daysInMonth,
                projectName: projectName ?? "Tüm Projeler"
            )

            if workerNames.isEmpty {
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.gray
                ]
                "Bu aya ait puantaj kaydı bulunamadı.".draw(
                    at: CGPoint(x: margin, y: y + 20), withAttributes: attr)
                drawPageFooter(page: 1)
                return
            }

            // Tablo geometrisi
            let nameColW: CGFloat = 120
            let totalColW: CGFloat = 50   // "Adam-Gün" sütunu
            let sgkColW: CGFloat  = 44   // "SGK Gün"
            let remainingW = pageWidth - margin * 2 - nameColW - totalColW - sgkColW
            let dayColW = remainingW / CGFloat(daysInMonth)
            let rowH: CGFloat = 18

            // Tablo başlığı
            y = drawTableHeader(
                y: y, daysInMonth: daysInMonth, firstDay: firstDay,
                nameColW: nameColW, dayColW: dayColW,
                totalColW: totalColW, sgkColW: sgkColW
            )

            var pageNumber = 1
            var grandManDays: Double = 0
            var grandSGKDays: Int = 0

            for (idx, workerName) in workerNames.enumerated() {
                if y + rowH > pageHeight - 60 {
                    drawPageFooter(page: pageNumber)
                    pageNumber += 1
                    ctx.beginPage()
                    y = margin
                    y = drawTableHeader(
                        y: y, daysInMonth: daysInMonth, firstDay: firstDay,
                        nameColW: nameColW, dayColW: dayColW,
                        totalColW: totalColW, sgkColW: sgkColW
                    )
                }

                let workerRecords = monthRecords.filter { $0.workerName == workerName }
                // gün → kayıt map'i
                var dayMap: [Int: Attendance] = [:]
                for r in workerRecords {
                    let d = cal.component(.day, from: r.date)
                    dayMap[d] = r
                }

                let manDays = workerRecords.filter { $0.isPresent }.reduce(0.0) { $0 + $1.totalHours / 8.0 }
                let sgkDays = workerRecords.filter { $0.isSGKDay }.count
                grandManDays += manDays
                grandSGKDays += sgkDays

                y = drawWorkerRow(
                    workerName: workerName,
                    dayMap: dayMap,
                    daysInMonth: daysInMonth,
                    manDays: manDays,
                    sgkDays: sgkDays,
                    y: y,
                    rowH: rowH,
                    isEven: idx % 2 == 0,
                    nameColW: nameColW,
                    dayColW: dayColW,
                    totalColW: totalColW,
                    sgkColW: sgkColW
                )
            }

            // Alt toplam satırı
            if y + rowH + 4 > pageHeight - 60 {
                drawPageFooter(page: pageNumber)
                pageNumber += 1
                ctx.beginPage()
                y = margin
            }
            y = drawTotalsRow(
                workerCount: workerNames.count,
                manDays: grandManDays,
                sgkDays: grandSGKDays,
                y: y,
                daysInMonth: daysInMonth,
                nameColW: nameColW,
                dayColW: dayColW,
                totalColW: totalColW,
                sgkColW: sgkColW
            )

            drawPageFooter(page: pageNumber)
        }
    }

    // MARK: - Draw Helpers

    @discardableResult
    private static func drawPageHeader(
        month: Date,
        daysInMonth: Int,
        projectName: String
    ) -> CGFloat {
        let headerH: CGFloat = 54
        orange.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: headerH)).fill()

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.white
        ]
        "AYLIK PUANTAJ TABLOSU".draw(at: CGPoint(x: margin, y: 10), withAttributes: titleAttr)

        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        df.locale = Locale(identifier: "tr_TR")
        let monthStr = df.string(from: month).capitalized
        monthStr.draw(at: CGPoint(x: margin, y: 32), withAttributes: subAttr)

        let sz = (projectName as NSString).size(withAttributes: subAttr)
        projectName.draw(at: CGPoint(x: pageWidth - margin - sz.width, y: 32), withAttributes: subAttr)

        return headerH + 10
    }

    @discardableResult
    private static func drawTableHeader(
        y: CGFloat,
        daysInMonth: Int,
        firstDay: Date,
        nameColW: CGFloat,
        dayColW: CGFloat,
        totalColW: CGFloat,
        sgkColW: CGFloat
    ) -> CGFloat {
        let rowH: CGFloat = 22
        orange.withAlphaComponent(0.12).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: rowH)).fill()

        let hAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8),
            .foregroundColor: UIColor.darkGray
        ]
        "İŞÇİ ADI".draw(at: CGPoint(x: margin + 4, y: y + 7), withAttributes: hAttr)

        var x = margin + nameColW
        let cal = Calendar.current
        for day in 1...daysInMonth {
            var comps = cal.dateComponents([.year, .month], from: firstDay)
            comps.day = day
            let dayDate = cal.date(from: comps)!
            let weekday = cal.component(.weekday, from: dayDate)
            let isWeekend = weekday == 1 || weekday == 7
            let dayAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 7.5),
                .foregroundColor: isWeekend ? UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1) : UIColor.darkGray
            ]
            "\(day)".draw(at: CGPoint(x: x + (dayColW - 8) / 2, y: y + 7), withAttributes: dayAttr)
            x += dayColW
        }

        let totalAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 7.5),
            .foregroundColor: UIColor.darkGray
        ]
        "A.Gün".draw(at: CGPoint(x: x + 4, y: y + 7), withAttributes: totalAttr)
        x += totalColW
        "SGK".draw(at: CGPoint(x: x + 4, y: y + 7), withAttributes: totalAttr)

        return y + rowH
    }

    @discardableResult
    private static func drawWorkerRow(
        workerName: String,
        dayMap: [Int: Attendance],
        daysInMonth: Int,
        manDays: Double,
        sgkDays: Int,
        y: CGFloat,
        rowH: CGFloat,
        isEven: Bool,
        nameColW: CGFloat,
        dayColW: CGFloat,
        totalColW: CGFloat,
        sgkColW: CGFloat
    ) -> CGFloat {
        if isEven {
            UIColor(white: 0.97, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: rowH)).fill()
        }

        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5),
            .foregroundColor: UIColor.black
        ]
        let truncated = workerName.count > 18 ? String(workerName.prefix(17)) + "…" : workerName
        truncated.draw(at: CGPoint(x: margin + 4, y: y + 4), withAttributes: nameAttr)

        var x = margin + nameColW
        for day in 1...daysInMonth {
            if let rec = dayMap[day] {
                let cellText: String
                let cellColor: UIColor
                if rec.isPresent {
                    cellText = rec.overtimeHours > 0 ? "M+" : "M"
                    cellColor = UIColor(red: 0.13, green: 0.70, blue: 0.30, alpha: 1)
                } else {
                    cellText = "G"
                    cellColor = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
                }
                let cellAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 7.5),
                    .foregroundColor: cellColor
                ]
                cellText.draw(at: CGPoint(x: x + (dayColW - 8) / 2, y: y + 4), withAttributes: cellAttr)
            }
            x += dayColW
        }

        let valAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8),
            .foregroundColor: UIColor.darkGray
        ]
        String(format: "%.1f", manDays).draw(at: CGPoint(x: x + 4, y: y + 4), withAttributes: valAttr)
        x += totalColW
        "\(sgkDays)".draw(at: CGPoint(x: x + 4, y: y + 4), withAttributes: valAttr)

        // Yatay çizgi
        UIColor(white: 0.88, alpha: 1).setStroke()
        let sep = UIBezierPath()
        sep.move(to: CGPoint(x: margin, y: y + rowH))
        sep.addLine(to: CGPoint(x: pageWidth - margin, y: y + rowH))
        sep.lineWidth = 0.25
        sep.stroke()

        return y + rowH
    }

    @discardableResult
    private static func drawTotalsRow(
        workerCount: Int,
        manDays: Double,
        sgkDays: Int,
        y: CGFloat,
        daysInMonth: Int,
        nameColW: CGFloat,
        dayColW: CGFloat,
        totalColW: CGFloat,
        sgkColW: CGFloat
    ) -> CGFloat {
        let rowH: CGFloat = 22
        orange.withAlphaComponent(0.15).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y + 4, width: pageWidth - margin * 2, height: rowH)).fill()

        let boldAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: UIColor.darkGray
        ]
        let orangeAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: orange
        ]

        "TOPLAM (\(workerCount) işçi)".draw(at: CGPoint(x: margin + 4, y: y + 10), withAttributes: boldAttr)

        var x = margin + nameColW + CGFloat(daysInMonth) * dayColW
        String(format: "%.1f", manDays).draw(at: CGPoint(x: x + 4, y: y + 10), withAttributes: orangeAttr)
        x += totalColW
        "\(sgkDays)".draw(at: CGPoint(x: x + 4, y: y + 10), withAttributes: orangeAttr)

        return y + rowH + 10
    }

    private static func drawPageFooter(page: Int) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.lightGray
        ]
        UIColor.lightGray.withAlphaComponent(0.4).setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: pageHeight - 28))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - 28))
        line.lineWidth = 0.3
        line.stroke()

        "M = Mevcut   G = Gelmedi   M+ = Fazla Mesai | HakedisApp".draw(
            at: CGPoint(x: margin, y: pageHeight - 22), withAttributes: attr)
        let pt = "Sayfa \(page)"
        let ps = (pt as NSString).size(withAttributes: attr)
        pt.draw(at: CGPoint(x: pageWidth - margin - ps.width, y: pageHeight - 22), withAttributes: attr)
    }
}
