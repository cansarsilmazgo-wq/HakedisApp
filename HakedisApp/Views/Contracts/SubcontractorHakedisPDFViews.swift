import SwiftUI
import SwiftData
import UIKit
import MessageUI

// MARK: - SubcontractorHakedisPDFGenerator

struct SubcontractorHakedisPDFGenerator {
    static func generatePDF(hakedis: SubcontractorHakedis) -> Data {
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40

            // --- Başlık ---
            y = drawCenteredText(
                "TAŞERON HAKEDİŞ BELGESİ",
                at: y, pageWidth: pageWidth,
                font: .boldSystemFont(ofSize: 18),
                color: UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1) // hakedisOrange
            )
            y += 6

            // --- Şirket / Proje Bilgileri ---
            let contractorName = hakedis.contractor?.name ?? "—"
            let contractName   = hakedis.contract?.title ?? "—"
            let projectName    = hakedis.contract?.project?.name ?? "—"

            let infoLines: [(String, String)] = [
                ("Taşeron Firma", contractorName),
                ("Proje",         projectName),
                ("Sözleşme",      contractName),
                ("Dönem",         hakedis.periodName),
                ("Dönem Başı",    hakedis.periodStart.formatted(date: .abbreviated, time: .omitted)),
                ("Dönem Sonu",    hakedis.periodEnd.formatted(date: .abbreviated, time: .omitted)),
                ("Durum",         hakedis.status.rawValue)
            ]

            y += 10
            y = drawSectionHeader("BİLGİLER", at: y, pageWidth: pageWidth)
            for (label, value) in infoLines {
                y = drawLabelValue(label: label, value: value, at: y, pageWidth: pageWidth)
            }

            // --- Finansal Tablo ---
            y += 14
            y = drawSectionHeader("FİNANSAL ÖZET", at: y, pageWidth: pageWidth)

            let finRows: [(String, String)] = [
                ("Brüt Hakediş",     hakedis.grossAmount.currencyFormatted),
                ("Teminat Kesintisi", hakedis.retentionAmount.currencyFormatted),
                ("Net Hakediş",       hakedis.netAmount.currencyFormatted)
            ]

            let margin: CGFloat = 40
            let col1W = pageWidth * 0.5
            let col2W = pageWidth - margin * 2 - col1W

            for (i, row) in finRows.enumerated() {
                let isLast = i == finRows.count - 1
                let bgColor: UIColor = isLast ? UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 0.12) : UIColor.clear
                bgColor.setFill()
                UIRectFill(CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 24))

                let font: UIFont = isLast ? .boldSystemFont(ofSize: 11) : .systemFont(ofSize: 10)
                (row.0 as NSString).draw(at: CGPoint(x: margin + 8, y: y + 6), withAttributes: [.font: font, .foregroundColor: UIColor.black])
                let valueStr = row.1 as NSString
                let valW = valueStr.size(withAttributes: [.font: font]).width
                valueStr.draw(at: CGPoint(x: margin + col1W + col2W - valW - 8, y: y + 6), withAttributes: [.font: font, .foregroundColor: UIColor.black])
                y += 24
            }

            // --- Notlar ---
            if let notes = hakedis.notes, !notes.isEmpty {
                y += 14
                y = drawSectionHeader("NOTLAR", at: y, pageWidth: pageWidth)
                y = drawWrappedText(notes, at: y, pageWidth: pageWidth, margin: margin)
            }

            // --- İmza Alanları ---
            y = max(y + 40, pageHeight - 160)
            y = drawSectionHeader("İMZALAR", at: y, pageWidth: pageWidth)
            y += 10
            let sigBoxWidth = (pageWidth - 80) / 3
            let sigBoxHeight: CGFloat = 80
            let sigLabels = ["Taşeron Firma", "Kontrol Mühendisi", "Proje Müdürü"]
            for (i, label) in sigLabels.enumerated() {
                let x = 40 + CGFloat(i) * (sigBoxWidth + 10)
                UIColor.systemGray4.setStroke()
                UIRectFrame(CGRect(x: x, y: y, width: sigBoxWidth, height: sigBoxHeight))
                (label as NSString).draw(
                    in: CGRect(x: x, y: y + sigBoxHeight + 4, width: sigBoxWidth, height: 16),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.gray
                    ]
                )
            }

            // Footer
            let footerText = "HakedisApp — Alphabi Systems — \(Date().formatted(date: .abbreviated, time: .omitted))"
            (footerText as NSString).draw(
                in: CGRect(x: 40, y: pageHeight - 24, width: pageWidth - 80, height: 16),
                withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.lightGray]
            )
        }
    }

    // MARK: Helpers

    @discardableResult
    private static func drawCenteredText(_ text: String, at y: CGFloat, pageWidth: CGFloat, font: UIFont, color: UIColor) -> CGFloat {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attr)
        (text as NSString).draw(at: CGPoint(x: (pageWidth - size.width) / 2, y: y), withAttributes: attr)
        return y + size.height
    }

    @discardableResult
    private static func drawSectionHeader(_ text: String, at y: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let margin: CGFloat = 40
        UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1).setFill()
        UIRectFill(CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 20))
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]
        (text as NSString).draw(at: CGPoint(x: margin + 8, y: y + 4), withAttributes: attr)
        return y + 22
    }

    @discardableResult
    private static func drawLabelValue(label: String, value: String, at y: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let margin: CGFloat = 40
        let labelAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray]
        let valueAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.black]
        (label as NSString).draw(at: CGPoint(x: margin + 8, y: y + 3), withAttributes: labelAttr)
        (value as NSString).draw(at: CGPoint(x: margin + (pageWidth - margin * 2) * 0.45, y: y + 3), withAttributes: valueAttr)
        UIColor.systemGray5.setFill()
        UIRectFill(CGRect(x: margin, y: y + 20, width: pageWidth - margin * 2, height: 0.5))
        return y + 22
    }

    @discardableResult
    private static func drawWrappedText(_ text: String, at y: CGFloat, pageWidth: CGFloat, margin: CGFloat) -> CGFloat {
        let attr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray]
        let rect = CGRect(x: margin + 8, y: y, width: pageWidth - margin * 2 - 16, height: 200)
        (text as NSString).draw(in: rect, withAttributes: attr)
        let height = text.boundingRect(
            with: CGSize(width: rect.width, height: .infinity),
            options: .usesLineFragmentOrigin,
            attributes: attr,
            context: nil
        ).height
        return y + height + 8
    }
}

// MARK: - SubcontractorHakedisDetailView

struct SubHakedisDetailView: View {
    let hakedis: SubcontractorHakedis
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showingMailCompose = false
    @State private var pdfData: Data?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingEdit = false

    var body: some View {
        List {
            // Status
            Section {
                HStack {
                    Spacer()
                    StatusBadge(
                        text: hakedis.status.rawValue,
                        color: hakedis.status == .paid ? .hakedisSuccess
                               : hakedis.status == .approved ? .hakedisInfo
                               : hakedis.status == .pendingApproval ? .hakedisWarning : .secondary
                    )
                    Spacer()
                }
            }

            // Bilgiler
            Section("Dönem Bilgileri") {
                LabeledContent("Dönem", value: hakedis.periodName)
                LabeledContent("Başlangıç", value: hakedis.periodStart.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Bitiş", value: hakedis.periodEnd.formatted(date: .abbreviated, time: .omitted))
                if let contractor = hakedis.contractor {
                    LabeledContent("Taşeron", value: contractor.name)
                }
                if let contract = hakedis.contract {
                    LabeledContent("Sözleşme", value: contract.title)
                    if let project = contract.project {
                        LabeledContent("Proje", value: project.name)
                    }
                }
            }

            // Finansal
            Section("Finansal Özet") {
                HStack {
                    Text("Brüt Hakediş")
                    Spacer()
                    Text(hakedis.grossAmount.currencyFormatted).bold()
                }
                HStack {
                    Text("Teminat Kesintisi")
                    Spacer()
                    Text("-\(hakedis.retentionAmount.currencyFormatted)")
                        .foregroundColor(.hakedisDanger)
                }
                HStack {
                    Text("Net Hakediş")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(hakedis.netAmount.currencyFormatted)
                        .font(.subheadline.bold())
                        .foregroundColor(.hakedisOrange)
                }
            }

            // Kâr Analizi
            if authManager.currentRole.canSeeFinancials {
                Section("Kâr Analizi") {
                    HStack {
                        Text("Taşeron Kâr Marjı")
                        Spacer()
                        Text(String(format: "%.1f%%", hakedis.profitMargin))
                            .foregroundColor(hakedis.profitMargin >= 0 ? .hakedisSuccess : .hakedisDanger)
                            .bold()
                    }
                    HStack {
                        Text("Kâr Tutarı")
                        Spacer()
                        Text(hakedis.profitAmount.currencyFormatted)
                            .foregroundColor(hakedis.profitAmount >= 0 ? .hakedisSuccess : .hakedisDanger)
                    }
                }
            }

            // Notlar
            if let notes = hakedis.notes, !notes.isEmpty {
                Section("Notlar") {
                    Text(notes).font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(hakedis.periodName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if authManager.currentRole.canExportData {
                    Button {
                        pdfData = SubcontractorHakedisPDFGenerator.generatePDF(hakedis: hakedis)
                        if let pdf = pdfData {
                            shareItems = [pdf]
                            showingShareSheet = true
                        }
                    } label: {
                        Image(systemName: "doc.richtext")
                    }
                    .accessibilityLabel("PDF olarak paylaş")

                    if MFMailComposeViewController.canSendMail() {
                        Button {
                            pdfData = SubcontractorHakedisPDFGenerator.generatePDF(hakedis: hakedis)
                            showingMailCompose = true
                        } label: {
                            Image(systemName: "envelope")
                        }
                        .accessibilityLabel("E-posta ile gönder")
                    }
                }
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Düzenle")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingMailCompose) {
            if let pdf = pdfData {
                SubHakedisMailComposeView(hakedis: hakedis, pdfData: pdf)
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddSubHakedisView(editingHakedis: hakedis)
        }
    }
}

// MARK: - SubHakedisMailComposeView

struct SubHakedisMailComposeView: UIViewControllerRepresentable {
    let hakedis: SubcontractorHakedis
    let pdfData: Data

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        let contractorName = hakedis.contractor?.name ?? "Taşeron"
        let projectName = hakedis.contract?.project?.name ?? "Proje"
        vc.setSubject("Taşeron Hakediş — \(hakedis.periodName) — \(contractorName)")
        vc.setMessageBody(
            """
            Sayın \(contractorName),

            \(hakedis.periodName) dönemi taşeron hakediş belgesi ekte yer almaktadır.

            Proje: \(projectName)
            Brüt Hakediş: \(hakedis.grossAmount.currencyFormatted)
            Net Hakediş: \(hakedis.netAmount.currencyFormatted)

            Saygılarımızla
            """,
            isHTML: false
        )
        vc.addAttachmentData(pdfData, mimeType: "application/pdf",
                              fileName: "taseron_hakedis_\(hakedis.periodName).pdf")
        return vc
    }
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
