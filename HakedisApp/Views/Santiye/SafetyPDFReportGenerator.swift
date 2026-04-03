import UIKit
import SwiftUI

// MARK: - SafetyPDFReportGenerator

struct SafetyPDFReportGenerator {

    // MARK: - Aylık İSG Özet Raporu

    static func generateMonthlyReport(
        incidents: [SafetyIncident],
        trainings: [SafetyTraining],
        correctiveActions: [CorrectiveAction],
        riskAssessments: [RiskAssessment],
        projectName: String,
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

            // Header
            y = drawHeader(ctx: ctx, title: "Aylık İSG Özet Raporu", subtitle: monthYearString(month), projectName: projectName, pageRect: pageRect, margin: margin, y: y)
            y += 16

            let cal = Calendar.current
            let comp = cal.dateComponents([.year, .month], from: month)
            let monthlyIncidents = incidents.filter {
                let ic = cal.dateComponents([.year, .month], from: $0.date)
                return ic.year == comp.year && ic.month == comp.month
            }

            // Özet istatistikler
            y = drawSectionTitle(title: "Olay İstatistikleri", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Toplam Olay Sayısı", value: "\(monthlyIncidents.count)", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Açık Olay", value: "\(monthlyIncidents.filter { !$0.isResolved }.count)", margin: margin, pageWidth: pageWidth, y: y)
            let accidents = monthlyIncidents.filter { $0.incidentType == .majorInjury || $0.incidentType == .minorInjury }
            y = drawKeyValue(key: "İş Kazası", value: "\(accidents.count)", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Ramak Kala", value: "\(monthlyIncidents.filter { $0.incidentType == .nearMiss }.count)", margin: margin, pageWidth: pageWidth, y: y)
            y += 12

            // Düzeltici faaliyetler
            y = drawSectionTitle(title: "Düzeltici Faaliyetler", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Açık", value: "\(correctiveActions.filter { $0.status == .open }.count)", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Tamamlandı", value: "\(correctiveActions.filter { $0.status == .completed || $0.status == .verified }.count)", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Gecikmiş", value: "\(correctiveActions.filter { $0.isOverdue }.count)", margin: margin, pageWidth: pageWidth, y: y)
            y += 12

            // Eğitimler
            let monthlyTrainings = trainings.filter {
                let tc = cal.dateComponents([.year, .month], from: $0.trainingDate)
                return tc.year == comp.year && tc.month == comp.month
            }
            y = drawSectionTitle(title: "Eğitimler", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Eğitim Sayısı", value: "\(monthlyTrainings.count)", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Toplam Katılımcı", value: "\(monthlyTrainings.reduce(0) { $0 + $1.attendees.count })", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Toplam Saat", value: String(format: "%.1f", monthlyTrainings.reduce(0) { $0 + $1.durationHours }), margin: margin, pageWidth: pageWidth, y: y)
            y += 12

            // Risk değerlendirme özeti
            y = drawSectionTitle(title: "Risk Değerlendirme", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Toplam Değerlendirme", value: "\(riskAssessments.count)", margin: margin, pageWidth: pageWidth, y: y)
            let highRisks = riskAssessments.filter { $0.riskLevel == .high || $0.riskLevel == .veryHigh }
            y = drawKeyValue(key: "Yüksek/Çok Yüksek Risk", value: "\(highRisks.count)", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Kontrolsüz Yüksek Risk", value: "\(highRisks.filter { !$0.isControlled }.count)", margin: margin, pageWidth: pageWidth, y: y)

            // Olay listesi
            if !monthlyIncidents.isEmpty {
                if y + 200 > pageHeight - margin { ctx.beginPage(); y = margin }
                y += 16
                y = drawSectionTitle(title: "Olay Listesi", margin: margin, pageWidth: pageWidth, y: y)
                for incident in monthlyIncidents {
                    if y + 50 > pageHeight - margin { ctx.beginPage(); y = margin }
                    y = drawKeyValue(key: incident.incidentType.rawValue, value: incident.date.shortFormatted, margin: margin, pageWidth: pageWidth, y: y)
                    let desc = String(incident.incidentDescription.prefix(80))
                    y = drawText(desc, margin: margin + 16, pageWidth: pageWidth, y: y, font: UIFont.systemFont(ofSize: 9), color: .gray)
                    y += 4
                }
            }

            drawFooter(ctx: ctx, pageRect: pageRect, margin: margin)
        }
    }

    // MARK: - Risk Değerlendirme Raporu

    static func generateRiskReport(
        assessments: [RiskAssessment],
        projectName: String
    ) -> Data {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 50
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            y = drawHeader(ctx: ctx, title: "Risk Değerlendirme Raporu", subtitle: "5×5 Risk Matrisi", projectName: projectName, pageRect: pageRect, margin: margin, y: y)
            y += 16

            // Tablo başlığı
            drawTableRow(
                cols: ["Konum", "Tehlike", "O", "Ş", "Skor", "Seviye", "Kontrol"],
                widths: [90, 130, 20, 20, 35, 70, 60],
                y: y, margin: margin, isHeader: true
            )
            y += 20

            for assessment in assessments {
                if y + 24 > pageHeight - margin { ctx.beginPage(); y = margin }
                drawTableRow(
                    cols: [
                        String(assessment.location.prefix(15)),
                        String(assessment.hazard.prefix(20)),
                        "\(assessment.likelihood)",
                        "\(assessment.severity)",
                        "\(assessment.riskScore)",
                        assessment.riskLevel.rawValue,
                        assessment.isControlled ? "Evet" : "Hayır"
                    ],
                    widths: [90, 130, 20, 20, 35, 70, 60],
                    y: y, margin: margin, isHeader: false
                )
                y += 20
            }

            drawFooter(ctx: ctx, pageRect: pageRect, margin: margin)
        }
    }

    // MARK: - Eğitim Katılım Formu

    static func generateTrainingAttendanceForm(
        training: SafetyTraining,
        projectName: String
    ) -> Data {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 50
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            y = drawHeader(ctx: ctx, title: "Eğitim Katılım Formu", subtitle: training.trainingType.rawValue, projectName: projectName, pageRect: pageRect, margin: margin, y: y)
            y += 12

            y = drawKeyValue(key: "Eğitim Tarihi", value: training.trainingDate.shortFormatted, margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Süre", value: String(format: "%.1f saat", training.durationHours), margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Eğitmen", value: training.trainer + (training.trainerTitle.map { " (\($0))" } ?? ""), margin: margin, pageWidth: pageWidth, y: y)
            if !training.topicsCovered.isEmpty {
                y = drawKeyValue(key: "Konular", value: "", margin: margin, pageWidth: pageWidth, y: y)
                y = drawText(training.topicsCovered, margin: margin + 16, pageWidth: pageWidth, y: y, font: UIFont.systemFont(ofSize: 10), color: .darkGray)
                y += 4
            }
            y += 12

            // Katılımcı tablosu
            y = drawSectionTitle(title: "Katılımcılar ve İmzalar", margin: margin, pageWidth: pageWidth, y: y)
            drawTableRow(cols: ["No", "Ad Soyad", "Unvan/Görev", "İmza"],
                         widths: [25, 150, 150, 100], y: y, margin: margin, isHeader: true)
            y += 22

            let attendees = training.attendees
            for (i, name) in attendees.enumerated() {
                if y + 28 > pageHeight - margin { ctx.beginPage(); y = margin }
                drawTableRow(cols: ["\(i+1)", name, "", ""],
                             widths: [25, 150, 150, 100], y: y, margin: margin, isHeader: false)
                y += 28
            }

            // Boş imza satırları (toplam 20'ye kadar)
            let emptyRows = max(0, 20 - attendees.count)
            for i in 0..<emptyRows {
                if y + 28 > pageHeight - margin { ctx.beginPage(); y = margin }
                drawTableRow(cols: ["\(attendees.count + i + 1)", "", "", ""],
                             widths: [25, 150, 150, 100], y: y, margin: margin, isHeader: false)
                y += 28
            }

            // Eğitmen imza
            y += 16
            if y + 60 > pageHeight - margin { ctx.beginPage(); y = margin }
            y = drawSectionTitle(title: "Eğitmen Onayı", margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "Eğitmen Adı", value: training.trainer, margin: margin, pageWidth: pageWidth, y: y)
            y = drawKeyValue(key: "İmza / Tarih", value: "______________________ / ______", margin: margin, pageWidth: pageWidth, y: y)

            drawFooter(ctx: ctx, pageRect: pageRect, margin: margin)
        }
    }

    // MARK: - Private drawing helpers

    @discardableResult
    private static func drawHeader(ctx: UIGraphicsPDFRendererContext, title: String, subtitle: String, projectName: String, pageRect: CGRect, margin: CGFloat, y: CGFloat) -> CGFloat {
        var currentY = y

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1) // hakedisOrange
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: margin, y: currentY))
        currentY += 24

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        NSAttributedString(string: subtitle, attributes: subtitleAttrs).draw(at: CGPoint(x: margin, y: currentY))
        currentY += 16

        NSAttributedString(string: "Proje: \(projectName)", attributes: subtitleAttrs).draw(at: CGPoint(x: margin, y: currentY))
        currentY += 16

        NSAttributedString(string: "Tarih: \(Date().shortFormatted)", attributes: subtitleAttrs).draw(at: CGPoint(x: margin, y: currentY))
        currentY += 16

        // Divider
        ctx.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.cgContext.setLineWidth(0.5)
        ctx.cgContext.move(to: CGPoint(x: margin, y: currentY))
        ctx.cgContext.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
        ctx.cgContext.strokePath()
        currentY += 8

        return currentY
    }

    @discardableResult
    private static func drawSectionTitle(title: String, margin: CGFloat, pageWidth: CGFloat, y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        NSAttributedString(string: title, attributes: attrs).draw(at: CGPoint(x: margin, y: y))
        return y + 18
    }

    @discardableResult
    private static func drawKeyValue(key: String, value: String, margin: CGFloat, pageWidth: CGFloat, y: CGFloat) -> CGFloat {
        let keyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.darkGray]
        let valAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.black]
        NSAttributedString(string: "\(key): ", attributes: keyAttrs).draw(at: CGPoint(x: margin, y: y))
        NSAttributedString(string: value, attributes: valAttrs).draw(at: CGPoint(x: margin + 140, y: y))
        return y + 15
    }

    @discardableResult
    private static func drawText(_ text: String, margin: CGFloat, pageWidth: CGFloat, y: CGFloat, font: UIFont, color: UIColor) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let boundingRect = CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 500)
        let str = NSAttributedString(string: text, attributes: attrs)
        str.draw(in: boundingRect)
        let height = str.boundingRect(with: CGSize(width: pageWidth - margin * 2, height: .infinity),
                                       options: .usesLineFragmentOrigin, context: nil).height
        return y + height + 4
    }

    private static func drawTableRow(cols: [String], widths: [CGFloat], y: CGFloat, margin: CGFloat, isHeader: Bool) {
        let font: UIFont = isHeader ? UIFont.boldSystemFont(ofSize: 9) : UIFont.systemFont(ofSize: 9)
        let color: UIColor = isHeader ? .white : .black
        var x = margin

        if isHeader {
            let totalWidth = widths.reduce(0, +)
            let rect = CGRect(x: margin, y: y, width: totalWidth, height: 18)
            UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1).setFill()
            UIRectFill(rect)
        }

        for (col, width) in zip(cols, widths) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let rect = CGRect(x: x + 2, y: y + 2, width: width - 4, height: 16)
            NSAttributedString(string: col, attributes: attrs).draw(in: rect)

            if !isHeader {
                UIColor.lightGray.setStroke()
                UIRectFrame(CGRect(x: x, y: y, width: width, height: 20))
            }

            x += width
        }
    }

    private static func drawFooter(ctx: UIGraphicsPDFRendererContext, pageRect: CGRect, margin: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.lightGray
        ]
        let text = "HakedisApp — İSG Raporu — \(Date().shortFormatted)"
        NSAttributedString(string: text, attributes: attrs)
            .draw(at: CGPoint(x: margin, y: pageRect.height - margin + 8))
    }

    private static func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - SafetyPDFShareSheet

struct SafetyPDFShareSheet: UIViewControllerRepresentable {
    let data: Data
    let fileName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
