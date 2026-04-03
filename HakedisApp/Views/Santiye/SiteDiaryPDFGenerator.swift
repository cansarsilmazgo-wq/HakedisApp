import UIKit

// MARK: - SiteDiaryPDFGenerator
// Günlük ve haftalık şantiye günlüğü PDF'i üretir. A4 (595.2 × 841.8 pt) format.

struct SiteDiaryPDFGenerator {
    private static let pageWidth: CGFloat  = 595.2
    private static let pageHeight: CGFloat = 841.8
    private static let margin: CGFloat     = 36
    private static let contentWidth: CGFloat = 595.2 - 72  // pageWidth - margin*2
    private static let orange = UIColor(red: 0.96, green: 0.45, blue: 0.13, alpha: 1)

    // MARK: - Public API

    /// Tek günlük için A4 PDF üretir
    static func generateDaily(diary: SiteDiary) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y = drawPageHeader(
                title: "ŞANTİYE GÜNLÜĞEsı",
                subtitle: diary.date.shortFormatted
            )
            _ = drawDiaryBlock(diary: diary, ctx: ctx, y: &y, page: 1)
            drawPageFooter(page: 1)
        }
    }

    /// Haftalık şantiye raporu PDF'i üretir (weekStart dahil 7 gün)
    static func generateWeekly(diaries: [SiteDiary], weekStart: Date) -> Data {
        let cal = Calendar.current
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let weekDiaries = diaries
            .filter { cal.startOfDay(for: $0.date) >= cal.startOfDay(for: weekStart)
                   && cal.startOfDay(for: $0.date) <= cal.startOfDay(for: weekEnd) }
            .sorted { $0.date < $1.date }

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        var pageNumber = 1

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y = drawPageHeader(
                title: "HAFTALIK ŞANTİYE RAPORU",
                subtitle: "\(weekStart.shortFormatted) – \(weekEnd.shortFormatted)  |  \(weekDiaries.count) günlük"
            )

            if weekDiaries.isEmpty {
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.gray
                ]
                "Bu hafta için şantiye günlüğü bulunamadı.".draw(
                    at: CGPoint(x: margin, y: y + 20), withAttributes: attr)
            }

            for (idx, diary) in weekDiaries.enumerated() {
                if y > pageHeight - 180 {
                    drawPageFooter(page: pageNumber)
                    pageNumber += 1
                    ctx.beginPage()
                    y = margin
                }
                pageNumber = drawDiaryBlock(diary: diary, ctx: ctx, y: &y, page: pageNumber)
                if idx < weekDiaries.count - 1 { y += 12 }
            }
            drawPageFooter(page: pageNumber)
        }
    }

    // MARK: - Private Draw Helpers

    /// Günlük blok çizer. Gerekirse yeni sayfa açar. Güncel sayfa numarasını döner.
    @discardableResult
    private static func drawDiaryBlock(
        diary: SiteDiary,
        ctx: UIGraphicsPDFRendererContext,
        y: inout CGFloat,
        page: Int
    ) -> Int {
        var pageNumber = page

        // ─── Tarih + Hava başlık kutusu ───
        orange.withAlphaComponent(0.10).setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: contentWidth, height: 30),
                     cornerRadius: 4).fill()

        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: orange
        ]
        diary.date.shortFormatted.draw(at: CGPoint(x: margin + 8, y: y + 8), withAttributes: dateAttr)

        let weatherText: String = {
            if let temp = diary.temperature {
                return "\(diary.weatherCondition.rawValue)  \(String(format: "%.0f", temp))°C"
            }
            return diary.weatherCondition.rawValue
        }()
        let weatherAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        let ws = (weatherText as NSString).size(withAttributes: weatherAttr)
        weatherText.draw(
            at: CGPoint(x: pageWidth - margin - ws.width - 8, y: y + 10),
            withAttributes: weatherAttr
        )
        y += 38

        // ─── Metin alanları ───
        y = drawLabeledText(label: "Yapılan İşler", value: diary.workDescription, y: y)

        if let problems = diary.problems, !problems.isEmpty {
            if y > pageHeight - 80 { drawPageFooter(page: pageNumber); pageNumber += 1; ctx.beginPage(); y = margin }
            y = drawLabeledText(label: "Sorunlar", value: problems, y: y)
        }
        if let visitors = diary.visitors, !visitors.isEmpty {
            if y > pageHeight - 80 { drawPageFooter(page: pageNumber); pageNumber += 1; ctx.beginPage(); y = margin }
            y = drawLabeledText(label: "Ziyaretçiler", value: visitors, y: y)
        }
        if let notes = diary.notes, !notes.isEmpty {
            if y > pageHeight - 80 { drawPageFooter(page: pageNumber); pageNumber += 1; ctx.beginPage(); y = margin }
            y = drawLabeledText(label: "Notlar", value: notes, y: y)
        }

        // ─── Fotoğraflar ───
        let photos = diary.photoData.compactMap { UIImage(data: $0) }
        if !photos.isEmpty {
            if y > pageHeight - 80 { drawPageFooter(page: pageNumber); pageNumber += 1; ctx.beginPage(); y = margin }

            let captionAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 9.5),
                .foregroundColor: UIColor.gray
            ]
            "Fotoğraflar (\(photos.count))".draw(at: CGPoint(x: margin, y: y), withAttributes: captionAttr)
            y += 14

            let photoSize: CGFloat = 108
            let gap: CGFloat = 8
            var xPos = margin

            for img in photos.prefix(9) {
                if xPos + photoSize > pageWidth - margin + 1 {
                    xPos = margin
                    y += photoSize + gap
                }
                if y + photoSize > pageHeight - 60 {
                    drawPageFooter(page: pageNumber)
                    pageNumber += 1
                    ctx.beginPage()
                    y = margin
                    xPos = margin
                }
                img.draw(in: CGRect(x: xPos, y: y, width: photoSize, height: photoSize))
                xPos += photoSize + gap
            }
            y += photoSize + gap
        }

        return pageNumber
    }

    /// Etiket + gövde metni çizer; metni sarmalar; güncellenen y değerini döner
    @discardableResult
    private static func drawLabeledText(label: String, value: String, y: CGFloat) -> CGFloat {
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9.5),
            .foregroundColor: UIColor.gray
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]

        label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttr)
        let boundingRect = (value as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: 400),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: bodyAttr,
            context: nil
        )
        value.draw(
            in: CGRect(x: margin, y: y + 13, width: contentWidth, height: ceil(boundingRect.height) + 4),
            withAttributes: bodyAttr
        )

        let lineY = y + 13 + ceil(boundingRect.height) + 6
        UIColor(white: 0.88, alpha: 1).setStroke()
        let sep = UIBezierPath()
        sep.move(to: CGPoint(x: margin, y: lineY))
        sep.addLine(to: CGPoint(x: pageWidth - margin, y: lineY))
        sep.lineWidth = 0.25
        sep.stroke()

        return lineY + 10
    }

    /// Turuncu başlık barını çizer; başladığı y'yi (headerHeight) döner
    @discardableResult
    private static func drawPageHeader(title: String, subtitle: String) -> CGFloat {
        let headerH: CGFloat = 58
        orange.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: headerH)).fill()

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 15),
            .foregroundColor: UIColor.white
        ]
        title.draw(at: CGPoint(x: margin, y: 11), withAttributes: titleAttr)

        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        subtitle.draw(at: CGPoint(x: margin, y: 34), withAttributes: subAttr)

        let company = UserDefaults.standard.string(forKey: "companyName") ?? ""
        if !company.isEmpty {
            let sz = (company as NSString).size(withAttributes: subAttr)
            company.draw(at: CGPoint(x: pageWidth - margin - sz.width, y: 34), withAttributes: subAttr)
        }

        return headerH + 14
    }

    private static func drawPageFooter(page: Int) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.lightGray
        ]
        UIColor.lightGray.withAlphaComponent(0.4).setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: pageHeight - 32))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - 32))
        line.lineWidth = 0.3
        line.stroke()

        "Oluşturulma: \(Date().shortFormatted) | HakedisApp".draw(
            at: CGPoint(x: margin, y: pageHeight - 26), withAttributes: attr)
        let pt = "Sayfa \(page)"
        let ps = (pt as NSString).size(withAttributes: attr)
        pt.draw(at: CGPoint(x: pageWidth - margin - ps.width, y: pageHeight - 26), withAttributes: attr)
    }
}
