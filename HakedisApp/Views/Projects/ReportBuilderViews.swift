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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        ComprehensiveReportPDFGenerator.generate(template: template,
                                                                  reportDate: reportDate,
                                                                  projectName: projectName,
                                                                  preparedBy: preparedBy)
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
    static func generate(template: ReportTemplate, reportDate: Date,
                         projectName: String, preparedBy: String) {
        // PDF generation stub — renders to UIActivityViewController in real impl
        print("PDF: \(template.templateName) - \(reportDate)")
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
