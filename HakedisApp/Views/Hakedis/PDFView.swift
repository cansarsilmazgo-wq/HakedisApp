import SwiftUI

struct PDFFileItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct HakedisShareButton: View {
    let hakedis: Hakedis
    @State private var pdfItem: PDFFileItem?

    var body: some View {
        Button {
            let data = HakedisPDFGenerator.generate(hakedis: hakedis)
            let name = hakedis.periodName.replacingOccurrences(of: " ", with: "_")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
            try? data.write(to: url)
            pdfItem = PDFFileItem(url: url)
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .sheet(item: $pdfItem) { item in
            ShareSheet(items: [item.url])
        }
    }
}

// MARK: - WhatsApp Paylaşım Kısayolu
struct WhatsAppShareButton: View {
    let hakedis: Hakedis
    @State private var pdfItem: PDFFileItem?

    private func generateAndShare() {
        let data = HakedisPDFGenerator.generate(hakedis: hakedis)
        let name = hakedis.periodName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
        try? data.write(to: url)
        pdfItem = PDFFileItem(url: url)
    }

    var body: some View {
        Button(action: generateAndShare) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                Text("WhatsApp")
                    .font(.subheadline.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(red: 0.07, green: 0.73, blue: 0.36))
            .clipShape(Capsule())
        }
        .sheet(item: $pdfItem) { item in
            ShareSheet(items: [item.url])
        }
    }
}

struct HakedisPDFGenerator {
    static func generate(hakedis: Hakedis) -> Data {
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin
            let orange = UIColor(red: 0.96, green: 0.45, blue: 0.13, alpha: 1)
            orange.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: 80)).fill()
            let ta: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.white]
            "HAKEDİŞ BELGESİ".draw(at: CGPoint(x: margin, y: 20), withAttributes: ta)
            let sa: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.white]
            hakedis.periodName.draw(at: CGPoint(x: margin, y: 48), withAttributes: sa)
            y = 100
            y = drawSection(title: "TAŞERON BİLGİLERİ", y: y, margin: margin, pageWidth: pageWidth)
            y = drawRow(label: "Firma", value: hakedis.contract?.contractor?.name ?? "—", y: y, margin: margin, pageWidth: pageWidth)
            y = drawRow(label: "Sözleşme", value: hakedis.contract?.title ?? "—", y: y, margin: margin, pageWidth: pageWidth)
            y = drawRow(label: "Proje", value: hakedis.contract?.project?.name ?? "—", y: y, margin: margin, pageWidth: pageWidth)
            y = drawRow(label: "Dönem", value: "\(hakedis.periodStart.shortFormatted) - \(hakedis.periodEnd.shortFormatted)", y: y, margin: margin, pageWidth: pageWidth)
            y += 16
            y = drawSection(title: "İŞ KALEMLERİ", y: y, margin: margin, pageWidth: pageWidth)
            y = drawTableHeader(y: y, margin: margin, pageWidth: pageWidth)
            for item in hakedis.items {
                if y > pageHeight - 120 { ctx.beginPage(); y = margin }
                y = drawTableRow(code: item.workItemCode, name: item.workItemName, unit: item.unit, prevQty: item.previousQuantity, currQty: item.currentQuantity, unitPrice: item.unitPrice, total: item.periodAmount, y: y, margin: margin, pageWidth: pageWidth)
            }
            y += 16
            if y > pageHeight - 180 { ctx.beginPage(); y = margin }
            y = drawSection(title: "FİNANSAL ÖZET", y: y, margin: margin, pageWidth: pageWidth)
            y = drawRow(label: "Brüt Tutar", value: hakedis.grossAmount.currencyFormatted, y: y, margin: margin, pageWidth: pageWidth)
            y = drawRow(label: "Teminat (%\(Int(hakedis.contract?.retentionRate ?? 0)))", value: "-\(hakedis.retentionAmount.currencyFormatted)", y: y, margin: margin, pageWidth: pageWidth, isRed: true)
            orange.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 32)).fill()
            let na: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.white]
            "NET HAKEDİŞ".draw(at: CGPoint(x: margin + 8, y: y + 8), withAttributes: na)
            let nv = hakedis.netAmount.currencyFormatted
            let ns = (nv as NSString).size(withAttributes: na)
            nv.draw(at: CGPoint(x: pageWidth - margin - ns.width - 8, y: y + 8), withAttributes: na)
            y += 40
            if hakedis.totalPaid > 0 {
                y += 8
                y = drawRow(label: "Ödenen", value: hakedis.totalPaid.currencyFormatted, y: y, margin: margin, pageWidth: pageWidth, isGreen: true)
                y = drawRow(label: "Kalan", value: hakedis.remainingAmount.currencyFormatted, y: y, margin: margin, pageWidth: pageWidth, isRed: hakedis.remainingAmount > 0)
            }
            y += 40
            let sg: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.gray]
            "Hazırlayan".draw(at: CGPoint(x: margin, y: y), withAttributes: sg)
            "Kontrol Eden".draw(at: CGPoint(x: pageWidth / 2 - 40, y: y), withAttributes: sg)
            "Onaylayan".draw(at: CGPoint(x: pageWidth - margin - 70, y: y), withAttributes: sg)
            y += 40
            UIColor.lightGray.setStroke()
            [(margin), (pageWidth / 2 - 60), (pageWidth - margin - 130)].forEach { x in
                let l = UIBezierPath(); l.move(to: CGPoint(x: x, y: y)); l.addLine(to: CGPoint(x: x + 120, y: y)); l.lineWidth = 0.5; l.stroke()
            }
            let da: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.lightGray]
            "Oluşturulma: \(Date().shortFormatted) | HakedisApp".draw(at: CGPoint(x: margin, y: pageHeight - 30), withAttributes: da)
        }
    }

    @discardableResult static func drawSection(title: String, y: CGFloat, margin: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor(red: 0.96, green: 0.45, blue: 0.13, alpha: 1)]
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: a)
        UIColor(red: 0.96, green: 0.45, blue: 0.13, alpha: 0.5).setStroke()
        let l = UIBezierPath(); l.move(to: CGPoint(x: margin, y: y+16)); l.addLine(to: CGPoint(x: pageWidth-margin, y: y+16)); l.lineWidth = 1; l.stroke()
        return y + 24
    }

    @discardableResult static func drawRow(label: String, value: String, y: CGFloat, margin: CGFloat, pageWidth: CGFloat, isRed: Bool = false, isGreen: Bool = false) -> CGFloat {
        let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.gray]
        let vc: UIColor = isRed ? .init(red:0.95,green:0.23,blue:0.23,alpha:1) : isGreen ? .init(red:0.2,green:0.78,blue:0.35,alpha:1) : .black
        let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: vc]
        label.draw(at: CGPoint(x: margin, y: y), withAttributes: la)
        let vs = (value as NSString).size(withAttributes: va)
        value.draw(at: CGPoint(x: pageWidth-margin-vs.width, y: y), withAttributes: va)
        UIColor(white:0.9,alpha:1).setStroke()
        let l = UIBezierPath(); l.move(to: CGPoint(x:margin,y:y+18)); l.addLine(to: CGPoint(x:pageWidth-margin,y:y+18)); l.lineWidth=0.3; l.stroke()
        return y + 22
    }

    @discardableResult static func drawTableHeader(y: CGFloat, margin: CGFloat, pageWidth: CGFloat) -> CGFloat {
        UIColor(red:0.96,green:0.45,blue:0.13,alpha:0.1).setFill()
        UIBezierPath(rect: CGRect(x:margin,y:y,width:pageWidth-margin*2,height:20)).fill()
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize:9), .foregroundColor: UIColor.darkGray]
        "POZ".draw(at: CGPoint(x:margin+4,y:y+5), withAttributes:a)
        "İŞ KALEMİ".draw(at: CGPoint(x:margin+55,y:y+5), withAttributes:a)
        "ÖNCEKİ".draw(at: CGPoint(x:margin+235,y:y+5), withAttributes:a)
        "BU DÖNEM".draw(at: CGPoint(x:margin+288,y:y+5), withAttributes:a)
        "BİRİM FİYAT".draw(at: CGPoint(x:margin+348,y:y+5), withAttributes:a)
        "TUTAR".draw(at: CGPoint(x:margin+440,y:y+5), withAttributes:a)
        return y + 22
    }

    @discardableResult static func drawTableRow(code: String, name: String, unit: String, prevQty: Double, currQty: Double, unitPrice: Double, total: Double, y: CGFloat, margin: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize:9), .foregroundColor: UIColor.black]
        let g: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize:9), .foregroundColor: UIColor.gray]
        let o: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize:9), .foregroundColor: UIColor(red:0.96,green:0.45,blue:0.13,alpha:1)]
        code.draw(at: CGPoint(x:margin+4,y:y+4), withAttributes:g)
        let n = name.count > 26 ? String(name.prefix(26))+"..." : name
        n.draw(at: CGPoint(x:margin+55,y:y+4), withAttributes:a)
        "\(prevQty.quantityFormatted) \(unit)".draw(at: CGPoint(x:margin+235,y:y+4), withAttributes:g)
        "\(currQty.quantityFormatted) \(unit)".draw(at: CGPoint(x:margin+288,y:y+4), withAttributes:a)
        unitPrice.currencyFormatted.draw(at: CGPoint(x:margin+348,y:y+4), withAttributes:a)
        total.currencyFormatted.draw(at: CGPoint(x:margin+440,y:y+4), withAttributes:o)
        UIColor(white:0.9,alpha:1).setStroke()
        let l = UIBezierPath(); l.move(to: CGPoint(x:margin,y:y+18)); l.addLine(to: CGPoint(x:pageWidth-margin,y:y+18)); l.lineWidth=0.3; l.stroke()
        return y + 20
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
