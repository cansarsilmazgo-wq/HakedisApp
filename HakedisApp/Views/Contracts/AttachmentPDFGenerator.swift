import UIKit

// MARK: - AttachmentPDFGenerator
// Yeşil defter (ataşman) PDF'i üretir. A4 yatay (landscape) format.

struct AttachmentPDFGenerator {
    // A4 Landscape
    private static let pageWidth: CGFloat  = 841.8
    private static let pageHeight: CGFloat = 595.2
    private static let margin: CGFloat     = 36
    private static let orange = UIColor(red: 0.96, green: 0.45, blue: 0.13, alpha: 1)
    private static let green  = UIColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1)

    // Sütun genişlikleri
    private enum Col {
        static let no:      CGFloat = 36
        static let location:CGFloat = 160
        static let length:  CGFloat = 64
        static let width:   CGFloat = 64
        static let height:  CGFloat = 64
        static let formula: CGFloat = 160
        static let qty:     CGFloat = 80
        static let notes:   CGFloat = 140
    }

    static func generate(workItem: WorkItem, records: [AttachmentRecord]) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        var pageNumber = 1
        let total = records.reduce(0.0) { $0 + $1.calculatedQuantity }

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y = drawHeader(workItem: workItem)
            y = drawTableHeader(y: y)

            for (idx, rec) in records.enumerated() {
                if y + 44 > pageHeight - 50 {
                    drawFooter(page: pageNumber)
                    pageNumber += 1
                    ctx.beginPage()
                    y = margin
                    y = drawTableHeader(y: y)
                }
                y = drawRow(rec: rec, y: y, isEven: idx % 2 == 0)

                // Kroki fotoğrafı varsa satırın altında göster
                if let photoData = rec.sketchPhotoData, let img = UIImage(data: photoData) {
                    if y + 80 > pageHeight - 50 {
                        drawFooter(page: pageNumber)
                        pageNumber += 1
                        ctx.beginPage()
                        y = margin
                    }
                    let photoH: CGFloat = 80
                    let photoW = photoH * (img.size.width / max(img.size.height, 1))
                    img.draw(in: CGRect(x: margin + Col.no + Col.location + 4, y: y + 2,
                                       width: min(photoW, 100), height: photoH))
                    y += photoH + 4
                }
            }

            // Toplam satırı
            y = drawTotalsRow(total: total, unit: workItem.unit, y: y)
            drawFooter(page: pageNumber)
        }
    }

    // MARK: - Private

    @discardableResult
    private static func drawHeader(workItem: WorkItem) -> CGFloat {
        let headerH: CGFloat = 62

        // Yeşil başlık bar
        green.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: headerH)).fill()

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 15),
            .foregroundColor: UIColor.white
        ]
        "YEŞİL DEFTER / ATAŞMAN".draw(at: CGPoint(x: margin, y: 10), withAttributes: titleAttr)

        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        "Poz: \(workItem.code)  |  \(workItem.name)  |  Birim: \(workItem.unit)".draw(
            at: CGPoint(x: margin, y: 34), withAttributes: subAttr)

        let dateStr = "Tarih: \(Date().shortFormatted)"
        let ds = (dateStr as NSString).size(withAttributes: subAttr)
        dateStr.draw(at: CGPoint(x: pageWidth - margin - ds.width, y: 10), withAttributes: subAttr)

        let company = UserDefaults.standard.string(forKey: "companyName") ?? ""
        if !company.isEmpty {
            let cs = (company as NSString).size(withAttributes: subAttr)
            company.draw(at: CGPoint(x: pageWidth - margin - cs.width, y: 34), withAttributes: subAttr)
        }

        return headerH + 8
    }

    @discardableResult
    private static func drawTableHeader(y: CGFloat) -> CGFloat {
        let rowH: CGFloat = 22
        orange.withAlphaComponent(0.15).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: rowH)).fill()

        let hAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8),
            .foregroundColor: UIColor.darkGray
        ]
        var x = margin + 4
        "No".draw(at: CGPoint(x: x, y: y + 7), withAttributes: hAttr); x += Col.no
        "Mahal".draw(at: CGPoint(x: x, y: y + 7), withAttributes: hAttr); x += Col.location
        "L (m)".draw(at: CGPoint(x: x, y: y + 7), withAttributes: hAttr); x += Col.length
        "W (m)".draw(at: CGPoint(x: x, y: y + 7), withAttributes: hAttr); x += Col.width
        "H (m)".draw(at: CGPoint(x: x, y: y + 7), withAttributes: hAttr); x += Col.height
        "Formül".draw(at: CGPoint(x: x, y: y + 7), withAttributes: hAttr); x += Col.formula
        "Miktar".draw(at: CGPoint(x: x, y: y + 7), withAttributes: hAttr); x += Col.qty
        "Notlar".draw(at: CGPoint(x: x, y: y + 7), withAttributes: hAttr)
        return y + rowH
    }

    @discardableResult
    private static func drawRow(rec: AttachmentRecord, y: CGFloat, isEven: Bool) -> CGFloat {
        let rowH: CGFloat = 20
        if isEven {
            UIColor(white: 0.97, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: rowH)).fill()
        }
        let norm: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.black]
        let orng: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: orange]
        let gray: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8.5), .foregroundColor: UIColor.gray]

        var x = margin + 4
        "\(rec.attachmentNo)".draw(at: CGPoint(x: x, y: y + 5), withAttributes: norm); x += Col.no

        let locTrunc = rec.location.count > 22 ? String(rec.location.prefix(21)) + "…" : rec.location
        locTrunc.draw(at: CGPoint(x: x, y: y + 5), withAttributes: norm); x += Col.location

        if let l = rec.length { String(format: "%.3g", l).draw(at: CGPoint(x: x, y: y + 5), withAttributes: gray) }
        x += Col.length
        if let w = rec.width  { String(format: "%.3g", w).draw(at: CGPoint(x: x, y: y + 5), withAttributes: gray) }
        x += Col.width
        if let h = rec.height { String(format: "%.3g", h).draw(at: CGPoint(x: x, y: y + 5), withAttributes: gray) }
        x += Col.height

        let form = rec.formula ?? rec.formulaDescription
        let ft = form.count > 22 ? String(form.prefix(21)) + "…" : form
        ft.draw(at: CGPoint(x: x, y: y + 5), withAttributes: gray); x += Col.formula

        String(format: "%.4g", rec.calculatedQuantity).draw(at: CGPoint(x: x, y: y + 5), withAttributes: orng)
        x += Col.qty

        if let notes = rec.notes, !notes.isEmpty {
            let nt = notes.count > 18 ? String(notes.prefix(17)) + "…" : notes
            nt.draw(at: CGPoint(x: x, y: y + 5), withAttributes: gray)
        }

        // Yatay çizgi
        UIColor(white: 0.88, alpha: 1).setStroke()
        let sep = UIBezierPath()
        sep.move(to: CGPoint(x: margin, y: y + rowH))
        sep.addLine(to: CGPoint(x: pageWidth - margin, y: y + rowH))
        sep.lineWidth = 0.25; sep.stroke()

        return y + rowH
    }

    @discardableResult
    private static func drawTotalsRow(total: Double, unit: String, y: CGFloat) -> CGFloat {
        let rowH: CGFloat = 24
        orange.withAlphaComponent(0.15).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y + 4, width: pageWidth - margin * 2, height: rowH)).fill()

        let bAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9.5), .foregroundColor: UIColor.darkGray]
        let oAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9.5), .foregroundColor: orange]

        "GENEL TOPLAM".draw(at: CGPoint(x: margin + 4, y: y + 11), withAttributes: bAttr)

        let totStr = String(format: "%.4g \(unit)", total)
        let x = margin + 4 + Col.no + Col.location + Col.length + Col.width + Col.height + Col.formula
        totStr.draw(at: CGPoint(x: x, y: y + 11), withAttributes: oAttr)

        return y + rowH + 10
    }

    private static func drawFooter(page: Int) {
        let attr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.lightGray]
        UIColor.lightGray.withAlphaComponent(0.4).setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: pageHeight - 28))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - 28))
        line.lineWidth = 0.3; line.stroke()

        "Oluşturulma: \(Date().shortFormatted) | HakedisApp".draw(
            at: CGPoint(x: margin, y: pageHeight - 22), withAttributes: attr)
        let pt = "Sayfa \(page)"
        let ps = (pt as NSString).size(withAttributes: attr)
        pt.draw(at: CGPoint(x: pageWidth - margin - ps.width, y: pageHeight - 22), withAttributes: attr)
    }
}
