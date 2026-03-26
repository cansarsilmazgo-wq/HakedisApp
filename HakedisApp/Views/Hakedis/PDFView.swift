import SwiftUI
import PDFKit

// MARK: - In-App PDF Preview

struct HakedisPDFPreviewView: View {
    let hakedis: Hakedis
    @State private var pdfData: Data?
    @State private var shareURL: URL?
    @State private var isSharing = false

    var body: some View {
        Group {
            if let data = pdfData {
                PDFKitView(data: data)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("PDF hazırlanıyor…").font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(hakedis.periodName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard let data = pdfData else { return }
                    let name = hakedis.periodName.replacingOccurrences(of: " ", with: "_")
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(name).pdf")
                    try? data.write(to: url)
                    shareURL = url
                    isSharing = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(pdfData == nil)
            }
        }
        .sheet(isPresented: $isSharing) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let data = HakedisPDFGenerator.generate(hakedis: hakedis)
                DispatchQueue.main.async { pdfData = data }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.backgroundColor = UIColor.systemGroupedBackground
        v.document = PDFDocument(data: data)
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) {}
}

// MARK: - Share Buttons

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
        .sheet(item: $pdfItem) { item in ShareSheet(items: [item.url]) }
    }
}

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
                Text("WhatsApp").font(.subheadline.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color(red: 0.07, green: 0.73, blue: 0.36))
            .clipShape(Capsule())
        }
        .sheet(item: $pdfItem) { item in ShareSheet(items: [item.url]) }
    }
}

// MARK: - PDF Generator

struct HakedisPDFGenerator {
    private static let pageWidth: CGFloat  = 595.2
    private static let pageHeight: CGFloat = 841.8
    private static let margin: CGFloat     = 36
    private static let orange = UIColor(red: 0.96, green: 0.45, blue: 0.13, alpha: 1)

    // Table column x-positions (from left margin)
    private enum Col {
        static let poz:       CGFloat = 4
        static let name:      CGFloat = 52
        static let prev:      CGFloat = 220
        static let curr:      CGFloat = 272
        static let cumul:     CGFloat = 328
        static let price:     CGFloat = 384
        static let amount:    CGFloat = 452
    }

    static func generate(hakedis: Hakedis) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        let companyName = UserDefaults.standard.string(forKey: "companyName") ?? ""
        var pageNumber = 1

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 0

            // --- HEADER ---
            y = drawHeader(hakedis: hakedis, companyName: companyName)

            // --- TAŞERON BİLGİLERİ ---
            y = drawSection(title: "TAŞERON BİLGİLERİ", y: y)
            y = drawRow(label: "Firma",     value: hakedis.contract?.contractor?.name ?? "—", y: y)
            y = drawRow(label: "Sözleşme", value: hakedis.contract?.title ?? "—",             y: y)
            y = drawRow(label: "Proje",    value: hakedis.contract?.project?.name ?? "—",     y: y)
            y = drawRow(label: "Dönem",
                        value: "\(hakedis.periodStart.shortFormatted) – \(hakedis.periodEnd.shortFormatted)", y: y)
            if let due = hakedis.dueDate {
                y = drawRow(label: "Vade Tarihi", value: due.shortFormatted, y: y, isRed: hakedis.isOverdue)
            }
            y += 10

            // --- İŞ KALEMLERİ ---
            y = drawSection(title: "İŞ KALEMLERİ", y: y)
            y = drawTableHeader(y: y)

            let sortedItems = hakedis.items.sorted { $0.workItemCode < $1.workItemCode }
            for item in sortedItems {
                if y > pageHeight - 90 {
                    drawPageFooter(page: pageNumber)
                    pageNumber += 1
                    ctx.beginPage()
                    y = margin
                    y = drawTableHeader(y: y)
                }
                y = drawTableRow(item: item, y: y)
            }

            // Totals row
            y = drawTableTotals(hakedis: hakedis, y: y)
            y += 14

            // --- FİNANSAL ÖZET ---
            if y > pageHeight - 220 {
                drawPageFooter(page: pageNumber)
                pageNumber += 1
                ctx.beginPage()
                y = margin
            }

            y = drawSection(title: "FİNANSAL ÖZET", y: y)
            y = drawRow(label: "Brüt Tutar (\(sortedItems.count) kalem)",
                        value: hakedis.grossAmount.currencyFormatted, y: y)
            y = drawRow(label: "Teminat Kesintisi (%\(Int(hakedis.contract?.retentionRate ?? 0)))",
                        value: "−\(hakedis.retentionAmount.currencyFormatted)", y: y, isRed: true)

            if hakedis.advanceDeduction > 0 {
                y = drawRow(label: "Avans Kesintisi (%\(Int(hakedis.contract?.advanceRate ?? 0)))",
                            value: "−\(hakedis.advanceDeduction.currencyFormatted)", y: y, isRed: true)
            }

            if let contract = hakedis.contract, contract.delayPenalty() > 0 {
                y = drawRow(label: "Gecikme Cezası (\(contract.delayDays()) gün)",
                            value: "−\(contract.delayPenalty().currencyFormatted)", y: y, isRed: true)
            }

            // KDV
            if hakedis.kdvAmount > 0 {
                y = drawRow(label: "KDV Matrahı",
                            value: hakedis.netAmount.currencyFormatted, y: y)
                y = drawRow(label: "KDV (%\(Int(hakedis.contract?.kdvRate ?? 0)))",
                            value: hakedis.kdvAmount.currencyFormatted, y: y)
            }

            // Net/Toplam bar
            y += 6
            orange.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 36)).fill()
            let netAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 13),
                .foregroundColor: UIColor.white
            ]
            let netLabel = hakedis.kdvAmount > 0 ? "KDV DAHİL TOPLAM" : "NET HAKEDİŞ"
            let netValue = hakedis.kdvAmount > 0 ? hakedis.totalWithKDV : hakedis.netAmount
            netLabel.draw(at: CGPoint(x: margin + 10, y: y + 11), withAttributes: netAttr)
            let nv = netValue.currencyFormatted
            let ns = (nv as NSString).size(withAttributes: netAttr)
            nv.draw(at: CGPoint(x: pageWidth - margin - ns.width - 10, y: y + 11), withAttributes: netAttr)
            y += 44

            // Payments
            if hakedis.totalPaid > 0 {
                y = drawRow(label: "Toplam Ödenen",
                            value: hakedis.totalPaid.currencyFormatted, y: y, isGreen: true)
                y = drawRow(label: "Kalan Bakiye",
                            value: hakedis.remainingAmount.currencyFormatted, y: y,
                            isRed: hakedis.remainingAmount > 0)
            }

            if hakedis.overdueInterest > 0 {
                y = drawRow(label: "Gecikme Faizi (\(hakedis.daysOverdue) gün, %9 yıllık)",
                            value: hakedis.overdueInterest.currencyFormatted, y: y, isRed: true)
            }

            y += 30

            // --- İMZA ---
            if y > pageHeight - 130 {
                drawPageFooter(page: pageNumber)
                pageNumber += 1
                ctx.beginPage()
                y = margin
            }
            drawSignatures(y: y)
            drawPageFooter(page: pageNumber)
        }
    }

    // MARK: - Drawing Helpers

    @discardableResult
    private static func drawHeader(hakedis: Hakedis, companyName: String) -> CGFloat {
        let headerH: CGFloat = companyName.isEmpty ? 82 : 96
        orange.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: headerH)).fill()

        var textY: CGFloat = 12
        if !companyName.isEmpty {
            let ca: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]
            companyName.uppercased().draw(at: CGPoint(x: margin, y: textY), withAttributes: ca)
            textY += 16
        }

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.white
        ]
        "HAKEDİŞ BELGESİ".draw(at: CGPoint(x: margin, y: textY), withAttributes: titleAttr)

        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        hakedis.periodName.draw(at: CGPoint(x: margin, y: textY + 28), withAttributes: subAttr)

        // Status badge
        let statusText = hakedis.status.rawValue
        let sta: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9.5),
            .foregroundColor: UIColor.white
        ]
        let stSz = (statusText as NSString).size(withAttributes: sta)
        let badgeX = pageWidth - margin - stSz.width - 16
        let badgeY = textY + 2
        UIColor.white.withAlphaComponent(0.22).setFill()
        UIBezierPath(roundedRect: CGRect(x: badgeX - 6, y: badgeY, width: stSz.width + 16, height: 18),
                     cornerRadius: 9).fill()
        statusText.draw(at: CGPoint(x: badgeX + 2, y: badgeY + 4), withAttributes: sta)

        return headerH + 14
    }

    @discardableResult
    static func drawSection(title: String, y: CGFloat) -> CGFloat {
        let a: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9.5),
            .foregroundColor: orange
        ]
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: a)
        orange.withAlphaComponent(0.35).setStroke()
        let l = UIBezierPath()
        l.move(to: CGPoint(x: margin, y: y + 14))
        l.addLine(to: CGPoint(x: pageWidth - margin, y: y + 14))
        l.lineWidth = 0.8; l.stroke()
        return y + 22
    }

    @discardableResult
    static func drawRow(label: String, value: String, y: CGFloat,
                        isRed: Bool = false, isGreen: Bool = false) -> CGFloat {
        let la: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        let vc: UIColor = isRed   ? .init(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
                        : isGreen ? .init(red: 0.13, green: 0.70, blue: 0.30, alpha: 1)
                        : .black
        let va: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: vc
        ]
        label.draw(at: CGPoint(x: margin, y: y + 2), withAttributes: la)
        let vs = (value as NSString).size(withAttributes: va)
        value.draw(at: CGPoint(x: pageWidth - margin - vs.width, y: y + 2), withAttributes: va)
        UIColor(white: 0.9, alpha: 1).setStroke()
        let l = UIBezierPath()
        l.move(to: CGPoint(x: margin, y: y + 16))
        l.addLine(to: CGPoint(x: pageWidth - margin, y: y + 16))
        l.lineWidth = 0.25; l.stroke()
        return y + 20
    }

    @discardableResult
    private static func drawTableHeader(y: CGFloat) -> CGFloat {
        orange.withAlphaComponent(0.12).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 22)).fill()
        let a: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8),
            .foregroundColor: UIColor.darkGray
        ]
        let base = margin
        "POZ".draw(at:           CGPoint(x: base + Col.poz,   y: y + 7), withAttributes: a)
        "İŞ KALEMİ ADI".draw(at: CGPoint(x: base + Col.name,  y: y + 7), withAttributes: a)
        "ÖNCEKİ".draw(at:        CGPoint(x: base + Col.prev,  y: y + 7), withAttributes: a)
        "BU DÖNEM".draw(at:      CGPoint(x: base + Col.curr,  y: y + 7), withAttributes: a)
        "KÜMÜLATİF".draw(at:     CGPoint(x: base + Col.cumul, y: y + 7), withAttributes: a)
        "BİRİM FİYAT".draw(at:   CGPoint(x: base + Col.price, y: y + 7), withAttributes: a)
        "TUTAR".draw(at:         CGPoint(x: base + Col.amount,y: y + 7), withAttributes: a)
        return y + 24
    }

    @discardableResult
    private static func drawTableRow(item: HakedisItem, y: CGFloat) -> CGFloat {
        let norm: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8.5),   .foregroundColor: UIColor.black]
        let gray: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8.5),   .foregroundColor: UIColor.gray]
        let orng: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: orange]

        let base = margin
        item.workItemCode.draw(at: CGPoint(x: base + Col.poz, y: y + 4), withAttributes: gray)
        let n = item.workItemName.count > 27 ? String(item.workItemName.prefix(27)) + "…" : item.workItemName
        n.draw(at: CGPoint(x: base + Col.name, y: y + 4), withAttributes: norm)
        "\(item.previousQuantity.quantityFormatted) \(item.unit)".draw(
            at: CGPoint(x: base + Col.prev, y: y + 4), withAttributes: gray)
        "\(item.currentQuantity.quantityFormatted) \(item.unit)".draw(
            at: CGPoint(x: base + Col.curr, y: y + 4), withAttributes: norm)
        "\(item.cumulativeQuantity.quantityFormatted) \(item.unit)".draw(
            at: CGPoint(x: base + Col.cumul, y: y + 4), withAttributes: norm)
        item.unitPrice.currencyFormatted.draw(
            at: CGPoint(x: base + Col.price, y: y + 4), withAttributes: norm)
        item.periodAmount.currencyFormatted.draw(
            at: CGPoint(x: base + Col.amount, y: y + 4), withAttributes: orng)

        UIColor(white: 0.92, alpha: 1).setStroke()
        let l = UIBezierPath()
        l.move(to: CGPoint(x: margin, y: y + 18))
        l.addLine(to: CGPoint(x: pageWidth - margin, y: y + 18))
        l.lineWidth = 0.25; l.stroke()
        return y + 20
    }

    @discardableResult
    private static func drawTableTotals(hakedis: Hakedis, y: CGFloat) -> CGFloat {
        UIColor(white: 0.94, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 24)).fill()
        let la: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: UIColor.darkGray]
        let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: orange]
        "TOPLAM  (\(hakedis.items.count) kalem)".draw(
            at: CGPoint(x: margin + Col.poz + 4, y: y + 7), withAttributes: la)
        hakedis.grossAmount.currencyFormatted.draw(
            at: CGPoint(x: margin + Col.amount, y: y + 7), withAttributes: va)
        return y + 26
    }

    private static func drawSignatures(y: CGFloat) {
        let titles = ["Hazırlayan", "Kontrol Eden", "Onaylayan"]
        let slotW = (pageWidth - margin * 2) / CGFloat(titles.count)
        let tAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray]
        let sAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8),  .foregroundColor: UIColor.lightGray]

        for (i, title) in titles.enumerated() {
            let x = margin + CGFloat(i) * slotW
            let tSz = (title as NSString).size(withAttributes: tAttr)
            title.draw(at: CGPoint(x: x + (slotW - tSz.width) / 2, y: y), withAttributes: tAttr)

            UIColor.lightGray.setStroke()
            let line = UIBezierPath()
            line.move(to: CGPoint(x: x + 12, y: y + 50))
            line.addLine(to: CGPoint(x: x + slotW - 12, y: y + 50))
            line.lineWidth = 0.6; line.stroke()

            let sub = "Ad Soyad / İmza / Tarih"
            let sSz = (sub as NSString).size(withAttributes: sAttr)
            sub.draw(at: CGPoint(x: x + (slotW - sSz.width) / 2, y: y + 54), withAttributes: sAttr)
        }
    }

    private static func drawPageFooter(page: Int) {
        let fAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.lightGray
        ]
        UIColor.lightGray.withAlphaComponent(0.4).setStroke()
        let fl = UIBezierPath()
        fl.move(to: CGPoint(x: margin, y: pageHeight - 32))
        fl.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - 32))
        fl.lineWidth = 0.3; fl.stroke()

        "Oluşturulma: \(Date().shortFormatted) | HakedisApp".draw(
            at: CGPoint(x: margin, y: pageHeight - 26), withAttributes: fAttr)

        let pt = "Sayfa \(page)"
        let ps = (pt as NSString).size(withAttributes: fAttr)
        pt.draw(at: CGPoint(x: pageWidth - margin - ps.width, y: pageHeight - 26), withAttributes: fAttr)
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
