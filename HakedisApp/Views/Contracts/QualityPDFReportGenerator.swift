import UIKit

// MARK: - QualityPDFReportGenerator

struct QualityPDFReportGenerator {

    // MARK: - Checklist Raporu

    static func generateChecklistReport(checklist: QualityChecklist, contractTitle: String) -> Data {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 50
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            // Header
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1)
            ]
            NSAttributedString(string: "Kalite Kontrol Raporu", attributes: titleAttrs).draw(at: CGPoint(x: margin, y: y)); y += 22
            let sub: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkGray]
            NSAttributedString(string: "Tip: \(checklist.checklistType.rawValue)", attributes: sub).draw(at: CGPoint(x: margin, y: y)); y += 16
            NSAttributedString(string: "Sözleşme: \(contractTitle)", attributes: sub).draw(at: CGPoint(x: margin, y: y)); y += 16
            NSAttributedString(string: "Tarih: \(checklist.date.shortFormatted)  |  Kontrol Eden: \(checklist.checkedBy)", attributes: sub).draw(at: CGPoint(x: margin, y: y)); y += 16
            if let loc = checklist.location {
                NSAttributedString(string: "Mahal: \(loc)", attributes: sub).draw(at: CGPoint(x: margin, y: y)); y += 16
            }
            NSAttributedString(string: String(format: "Genel Skor: %.1f%% (%d/%d uygun)", checklist.overallScore, checklist.passedCount, checklist.applicableCount), attributes: [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor.black]).draw(at: CGPoint(x: margin, y: y)); y += 20

            // Divider
            ctx.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            ctx.cgContext.setLineWidth(0.5)
            ctx.cgContext.move(to: CGPoint(x: margin, y: y))
            ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            ctx.cgContext.strokePath(); y += 10

            // Items
            let boldAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.white]
            let normalAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.black]
            let noteAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: 8), .foregroundColor: UIColor.gray]

            // Table header
            let headerBg = UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1)
            UIRectFill(CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 18).applying(CGAffineTransform(scaleX: 1, y: 1)))
            headerBg.setFill()
            UIRectFill(CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 18))
            NSAttributedString(string: "No", attributes: boldAttrs).draw(at: CGPoint(x: margin + 2, y: y + 2))
            NSAttributedString(string: "Kontrol Maddesi", attributes: boldAttrs).draw(at: CGPoint(x: margin + 24, y: y + 2))
            NSAttributedString(string: "Sonuç", attributes: boldAttrs).draw(at: CGPoint(x: pageWidth - margin - 70, y: y + 2))
            y += 20

            for (i, item) in checklist.checkItems.enumerated() {
                if y + 22 > pageHeight - margin { ctx.beginPage(); y = margin }
                let result = item.effectiveResult
                let resultColor: UIColor = result == .pass ? .systemGreen : result == .fail ? .systemRed : .gray
                let rowBg = i % 2 == 0 ? UIColor.white : UIColor(white: 0.97, alpha: 1)
                rowBg.setFill(); UIRectFill(CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 20))
                NSAttributedString(string: "\(i+1)", attributes: normalAttrs).draw(at: CGPoint(x: margin + 2, y: y + 2))
                let titleStr = NSAttributedString(string: item.title, attributes: normalAttrs)
                titleStr.draw(in: CGRect(x: margin + 24, y: y + 2, width: pageWidth - margin * 2 - 100, height: 18))
                let resultAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: resultColor]
                NSAttributedString(string: result.rawValue, attributes: resultAttrs).draw(at: CGPoint(x: pageWidth - margin - 70, y: y + 2))
                y += 20
                if !item.note.isEmpty {
                    NSAttributedString(string: "  Not: \(item.note)", attributes: noteAttrs).draw(at: CGPoint(x: margin + 24, y: y))
                    y += 12
                }
            }

            // Notes
            if let notes = checklist.notes, !notes.isEmpty {
                y += 8
                if y + 40 > pageHeight - margin { ctx.beginPage(); y = margin }
                NSAttributedString(string: "Notlar:", attributes: [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.black]).draw(at: CGPoint(x: margin, y: y)); y += 14
                NSAttributedString(string: notes, attributes: noteAttrs).draw(in: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 60)); y += 60
            }

            drawFooter(ctx: ctx, pageRect: pageRect, margin: margin)
        }
    }

    // MARK: - NCR Raporu

    static func generateNCRReport(ncrs: [NonConformanceReport], contractTitle: String) -> Data {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 50
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1)]
            NSAttributedString(string: "NCR Raporu", attributes: titleAttrs).draw(at: CGPoint(x: margin, y: y)); y += 22
            let sub: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkGray]
            NSAttributedString(string: "Sözleşme: \(contractTitle)", attributes: sub).draw(at: CGPoint(x: margin, y: y)); y += 16
            NSAttributedString(string: "Tarih: \(Date().shortFormatted)  |  Toplam NCR: \(ncrs.count)", attributes: sub).draw(at: CGPoint(x: margin, y: y)); y += 20

            ctx.cgContext.setStrokeColor(UIColor.lightGray.cgColor); ctx.cgContext.setLineWidth(0.5)
            ctx.cgContext.move(to: CGPoint(x: margin, y: y)); ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y)); ctx.cgContext.strokePath(); y += 12

            for ncr in ncrs {
                if y + 80 > pageHeight - margin { ctx.beginPage(); y = margin }
                let boldAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.black]
                let normalAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.black]
                let smallAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.gray]

                NSAttributedString(string: "\(ncr.ncrNo) — \(ncr.nonConformanceDescription.prefix(60))", attributes: boldAttrs)
                    .draw(in: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 16)); y += 14
                NSAttributedString(string: "Mahal: \(ncr.location)  |  Tespit: \(ncr.detectionDate.shortFormatted)  |  Durum: \(ncr.status.rawValue)", attributes: normalAttrs)
                    .draw(in: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 14)); y += 12
                if let rc = ncr.rootCause {
                    NSAttributedString(string: "Kök Neden: \(rc.prefix(80))", attributes: smallAttrs).draw(in: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 12)); y += 10
                }
                if let pc = ncr.proposedCorrection {
                    NSAttributedString(string: "Önerilen Düzeltme: \(pc.prefix(80))", attributes: smallAttrs).draw(in: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 12)); y += 10
                }
                if let cd = ncr.correctionDate {
                    NSAttributedString(string: "Düzeltme Tarihi: \(cd.shortFormatted)", attributes: smallAttrs).draw(at: CGPoint(x: margin, y: y)); y += 10
                }
                ctx.cgContext.setStrokeColor(UIColor.lightGray.cgColor); ctx.cgContext.setLineWidth(0.3)
                ctx.cgContext.move(to: CGPoint(x: margin, y: y + 4)); ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y + 4)); ctx.cgContext.strokePath()
                y += 12
            }

            drawFooter(ctx: ctx, pageRect: pageRect, margin: margin)
        }
    }

    // MARK: - Aylık Kalite Özet Raporu

    static func generateMonthlyQualityReport(
        checklists: [QualityChecklist],
        ncrs: [NonConformanceReport],
        contractTitle: String,
        month: Date = Date()
    ) -> Data {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 50
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1)]
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "tr_TR"); formatter.dateFormat = "MMMM yyyy"
            NSAttributedString(string: "Aylık Kalite Özet Raporu", attributes: titleAttrs).draw(at: CGPoint(x: margin, y: y)); y += 22
            let sub: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkGray]
            NSAttributedString(string: "Dönem: \(formatter.string(from: month))", attributes: sub).draw(at: CGPoint(x: margin, y: y)); y += 16
            NSAttributedString(string: "Sözleşme: \(contractTitle)", attributes: sub).draw(at: CGPoint(x: margin, y: y)); y += 20

            let cal = Calendar.current
            let comp = cal.dateComponents([.year, .month], from: month)
            let monthlyChecklists = checklists.filter {
                let c = cal.dateComponents([.year, .month], from: $0.date)
                return c.year == comp.year && c.month == comp.month
            }
            let monthlyNCRs = ncrs.filter {
                let c = cal.dateComponents([.year, .month], from: $0.detectionDate)
                return c.year == comp.year && c.month == comp.month
            }
            let avgScore = monthlyChecklists.isEmpty ? 0.0 : monthlyChecklists.reduce(0) { $0 + $1.overallScore } / Double(monthlyChecklists.count)

            let bold: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor.black]
            let normal: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.black]

            NSAttributedString(string: "Checklist Sayısı: \(monthlyChecklists.count)", attributes: normal).draw(at: CGPoint(x: margin, y: y)); y += 16
            NSAttributedString(string: String(format: "Ortalama Uygunluk Skoru: %.1f%%", avgScore), attributes: bold).draw(at: CGPoint(x: margin, y: y)); y += 16
            NSAttributedString(string: "Yeni NCR Sayısı: \(monthlyNCRs.count)", attributes: normal).draw(at: CGPoint(x: margin, y: y)); y += 16
            NSAttributedString(string: "Kapanan NCR: \(monthlyNCRs.filter { $0.status == .closed || $0.status == .verified }.count)", attributes: normal).draw(at: CGPoint(x: margin, y: y)); y += 16
            NSAttributedString(string: "Toplam Açık NCR: \(ncrs.filter { $0.status == .open || $0.status == .correctionProposed }.count)", attributes: bold).draw(at: CGPoint(x: margin, y: y)); y += 24

            drawFooter(ctx: ctx, pageRect: pageRect, margin: margin)
        }
    }

    private static func drawFooter(ctx: UIGraphicsPDFRendererContext, pageRect: CGRect, margin: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.lightGray]
        NSAttributedString(string: "HakedisApp — Kalite Raporu — \(Date().shortFormatted)", attributes: attrs)
            .draw(at: CGPoint(x: margin, y: pageRect.height - margin + 8))
    }
}
