import SwiftUI
import SwiftData

// MARK: - Report List View

struct ReportListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ReportTemplate.createdAt, order: .reverse) private var templates: [ReportTemplate]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(templates) { template in
                    NavigationLink(destination: ReportBuilderView(template: template)) {
                        ReportTemplateRow(template: template)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Raporlar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddReportTemplateView() }
            .overlay {
                if templates.isEmpty {
                    EmptyStateView(icon: "doc.text.below.ecg", title: "Şablon Yok",
                                   subtitle: "Rapor şablonu oluşturun")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(templates[i]) }
        do { try context.save() } catch { print("ReportListView delete error: \(error)") }
    }
}

private struct ReportTemplateRow: View {
    let template: ReportTemplate
    var body: some View {
        HStack {
            Image(systemName: template.reportType.icon)
                .foregroundColor(.hakedisOrange)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.templateName).font(.headline)
                Text(template.reportType.rawValue).font(.caption).foregroundColor(.secondary)
                Text("\(template.enabledSections.count) bölüm")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            if template.isDefault {
                Image(systemName: "star.fill").foregroundColor(.hakedisWarning).font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Report Builder View

struct ReportBuilderView: View {
    @Environment(\.modelContext) private var context
    @Bindable var template: ReportTemplate
    @State private var showPreview = false

    var body: some View {
        List {
            Section("Şablon Bilgileri") {
                TextField("Şablon Adı", text: $template.templateName)
                LabeledContent("Rapor Türü", value: template.reportType.rawValue)
                Toggle("Varsayılan Şablon", isOn: $template.isDefault)
            }
            Section("Bölümler") {
                ForEach(Array(template.sections.enumerated()), id: \.element.id) { idx, section in
                    ReportSectionToggleRow(section: section) { updated in
                        var sections = template.sections
                        if let pos = sections.firstIndex(where: { $0.id == updated.id }) {
                            sections[pos] = updated
                            template.sections = sections
                            do { try context.save() } catch { print("ReportBuilderView save error: \(error)") }
                        }
                    }
                }
            }
            Section {
                Button {
                    showPreview = true
                } label: {
                    Label("Önizle ve Oluştur", systemImage: "doc.preview")
                        .foregroundColor(.hakedisOrange)
                }
            }
        }
        .navigationTitle(template.templateName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPreview) { ReportPreviewView(template: template) }
    }
}

private struct ReportSectionToggleRow: View {
    let section: ReportSection
    let onChange: (ReportSection) -> Void

    var body: some View {
        HStack {
            Image(systemName: section.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(section.isEnabled ? .hakedisOrange : .secondary)
                .onTapGesture {
                    var updated = section
                    updated.isEnabled.toggle()
                    onChange(updated)
                }
            Text(section.sectionTitle).font(.subheadline)
            Spacer()
            Text(section.sectionType.rawValue).font(.caption).foregroundColor(.secondary)
        }
    }
}

// MARK: - Report Preview View

struct ReportPreviewView: View {
    let template: ReportTemplate
    @Environment(\.dismiss) private var dismiss
    @State private var reportDate = Date()
    @State private var projectName = ""
    @State private var preparedBy = ""
    @State private var pdfShareURL: URL? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ReportHeaderView(template: template, reportDate: reportDate,
                                     projectName: projectName, preparedBy: preparedBy)
                    ForEach(template.enabledSections) { section in
                        ReportSectionPreview(section: section)
                    }
                }
                .padding()
            }
            .navigationTitle("Rapor Önizleme")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $pdfShareURL) { url in ShareSheet(items: [url]) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let data = ComprehensiveReportPDFGenerator.generate(
                            template: template, reportDate: reportDate,
                            projectName: projectName, preparedBy: preparedBy)
                        let url = FileManager.default.temporaryDirectory
                            .appendingPathComponent("\(template.templateName.prefix(30)).pdf")
                        try? data.write(to: url)
                        pdfShareURL = url
                    } label: {
                        Label("PDF", systemImage: "doc.fill")
                    }
                }
            }
        }
    }
}

private struct ReportHeaderView: View {
    let template: ReportTemplate
    let reportDate: Date
    let projectName: String
    let preparedBy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: template.reportType.icon)
                    .font(.title2)
                    .foregroundColor(.hakedisOrange)
                VStack(alignment: .leading) {
                    Text(template.reportType.rawValue).font(.title2.bold())
                    Text(reportDate.formatted(date: .long, time: .omitted))
                        .font(.subheadline).foregroundColor(.secondary)
                }
            }
            if !projectName.isEmpty {
                LabeledContent("Proje", value: projectName)
            }
            if !preparedBy.isEmpty {
                LabeledContent("Hazırlayan", value: preparedBy)
            }
            Divider()
        }
    }
}

private struct ReportSectionPreview: View {
    let section: ReportSection
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.sectionTitle)
                .font(.headline)
                .foregroundColor(.hakedisOrange)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.hakedisCard)
                .frame(height: 80)
                .overlay(
                    Text("[\(section.sectionType.rawValue) içeriği]")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
        }
    }
}

// MARK: - Comprehensive Report PDF Generator

struct ComprehensiveReportPDFGenerator {
    private static let pageWidth:  CGFloat = 595.2
    private static let pageHeight: CGFloat = 841.8
    private static let margin:     CGFloat = 40.0

    static func generate(template: ReportTemplate, reportDate: Date,
                         projectName: String, preparedBy: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y = drawHeader(template: template, reportDate: reportDate,
                               projectName: projectName, preparedBy: preparedBy)

            for section in template.enabledSections {
                if y > pageHeight - 120 { ctx.beginPage(); y = margin }
                y = drawSection(section: section, y: y)
            }
            drawFooter(reportDate: reportDate)
        }
    }

    @discardableResult
    private static func drawHeader(template: ReportTemplate, reportDate: Date,
                                   projectName: String, preparedBy: String) -> CGFloat {
        let headerH: CGFloat = 80
        UIColor.systemOrange.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: headerH)).fill()

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.white]
        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.white]

        template.templateName.draw(at: CGPoint(x: margin, y: 16), withAttributes: titleAttr)
        template.reportType.rawValue.draw(at: CGPoint(x: margin, y: 38), withAttributes: subAttr)

        let dateStr = reportDate.formatted(date: .long, time: .omitted)
        dateStr.draw(at: CGPoint(x: margin, y: 56), withAttributes: subAttr)

        var y = headerH + 16
        let metaAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray]
        if !projectName.isEmpty {
            "Proje: \(projectName)".draw(at: CGPoint(x: margin, y: y), withAttributes: metaAttr); y += 14
        }
        if !preparedBy.isEmpty {
            "Hazırlayan: \(preparedBy)".draw(at: CGPoint(x: margin, y: y), withAttributes: metaAttr); y += 14
        }
        return y + 8
    }

    @discardableResult
    private static func drawSection(section: ReportSection, y: CGFloat) -> CGFloat {
        var cy = y
        // Bölüm başlığı
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.systemOrange]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray]

        // Alt çizgi
        UIColor.systemOrange.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: cy, width: pageWidth - margin * 2, height: 1)).fill()
        cy += 6

        section.sectionTitle.draw(at: CGPoint(x: margin, y: cy), withAttributes: titleAttr)
        cy += 20

        // Bölüm tipi bazlı içerik özeti
        let content: String
        switch section.sectionType {
        case .summary:
            content = "Proje genel durumu bu bölümde özetlenmektedir.\nAktivite ilerlemesi, temel metrikler ve öne çıkan bilgiler yer alır."
        case .financial:
            content = "Finansal Özet:\n• Toplam hakediş tutarları\n• Ödenen / Kalan tutarlar\n• Teminat ve avans durumu\n• KDV ve stopaj bilgileri"
        case .progress:
            content = "İlerleme Durumu:\n• Tamamlanma yüzdesi\n• Planlanan vs. gerçekleşen\n• Geciken aktiviteler\n• Kritik yol analizi"
        case .safety:
            content = "İSG Bilgileri:\n• Olay sayıları (ramak kala, yaralanma)\n• Ramak kala olayları\n• Açık düzeltici faaliyetler\n• Eğitim tamamlanma oranı"
        case .quality:
            content = "Kalite Kontrol:\n• Kontrol listesi tamamlanma oranı\n• Uygunsuzluk (NCR) sayısı\n• Test sonuç özeti\n• Kalite skoru"
        case .activities:
            content = "Aktiviteler:\n• Dönem içi tamamlanan işler\n• Devam eden aktiviteler\n• Bir sonraki dönem planı"
        case .issues:
            content = "Sorunlar ve Riskler:\n• Açık sorunlar listesi\n• Risk matrisi özeti\n• Alınan önlemler"
        case .decisions:
            content = "Kararlar:\n• Dönem içi alınan kararlar\n• Toplantı özeti\n• Açık kararlar ve sorumluları"
        case .photos:
            content = "Fotoğraflar:\n• Saha ilerleme fotoğrafları\n• Kalite kontrol belgeleri\n• Olay kayıtları"
        case .appendix:
            content = "Ekler:\n• Destekleyici belgeler\n• Referans dokümanlar\n• İlgili yazışmalar"
        }

        let rect = CGRect(x: margin, y: cy, width: pageWidth - margin * 2, height: 200)
        content.draw(in: rect, withAttributes: bodyAttr)
        cy += min(CGFloat(content.components(separatedBy: "\n").count) * 14 + 8, 120)
        return cy + 12
    }

    private static func drawFooter(reportDate: Date) {
        let attr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.gray]
        let text = "HakedisApp — \(reportDate.formatted(date: .abbreviated, time: .shortened))"
        text.draw(at: CGPoint(x: margin, y: pageHeight - 24), withAttributes: attr)
    }
}

// MARK: - Auto Report Scheduler (Stub)

struct AutoReportScheduler {
    static func scheduleWeeklyReport(templateId: UUID) {
        // Schedules a local notification for weekly report reminder
        print("Scheduled weekly report for template: \(templateId)")
    }
}

// MARK: - Add Report Template View

struct AddReportTemplateView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var templateName = ""
    @State private var reportType = ReportType.weekly
    @State private var isDefault = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Şablon Adı", text: $templateName)
                    Picker("Rapor Türü", selection: $reportType) {
                        ForEach(ReportType.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                        }
                    }
                    Toggle("Varsayılan", isOn: $isDefault)
                }
            }
            .navigationTitle("Yeni Şablon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") { save() }.disabled(templateName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let t = ReportTemplate(templateName: templateName, type: reportType)
        t.isDefault = isDefault
        t.sections = ReportTemplate.defaultSections(for: reportType)
        context.insert(t)
        do { try context.save() } catch { print("AddReportTemplateView save error: \(error)") }
        dismiss()
    }
}
