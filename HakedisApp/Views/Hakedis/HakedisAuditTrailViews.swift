import SwiftUI
import SwiftData

// MARK: - HakedisAuditTrailView

struct HakedisAuditTrailView: View {
    let hakedis: Hakedis
    @Query(sort: \HakedisAuditLog.timestamp, order: .reverse) private var allLogs: [HakedisAuditLog]
    @State private var selectedAction: AuditAction? = nil

    private var logs: [HakedisAuditLog] {
        allLogs.filter { $0.hakedis?.id == hakedis.id && (selectedAction == nil || $0.action == selectedAction!) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Tümü", isSelected: selectedAction == nil) { selectedAction = nil }
                    ForEach(AuditAction.allCases, id: \.self) { action in
                        FilterChip(title: action.rawValue, isSelected: selectedAction == action) {
                            selectedAction = selectedAction == action ? nil : action
                        }
                    }
                }
                .padding(.horizontal, Spacing.card).padding(.vertical, 8)
            }
            .background(Color.hakedisBackground)

            if logs.isEmpty {
                EmptyStateView(icon: "clock.badge.questionmark", title: "Geçmiş Yok", subtitle: "Hakediş işlem geçmişi burada görünür")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(logs, id: \.id) { log in
                        AuditLogRow(log: log)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color.hakedisBackground)
        .navigationTitle("İşlem Geçmişi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AuditLogRow

private struct AuditLogRow: View {
    let log: HakedisAuditLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: log.action.icon).foregroundColor(actionColor)
                Text(log.action.rawValue).font(.subheadline.bold())
                Spacer()
                Text(log.timestamp.shortFormatted).font(.caption2).foregroundColor(.secondary)
            }
            HStack {
                Image(systemName: "person.fill").font(.caption2).foregroundColor(.secondary)
                Text(log.performedBy).font(.caption).foregroundColor(.secondary)
            }
            if let details = log.details, !details.isEmpty {
                Text(details).font(.caption2).foregroundColor(.secondary).lineLimit(2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.hakedisBackground).cornerRadius(6)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(log.action.rawValue), \(log.performedBy), \(log.timestamp.shortFormatted)")
    }

    private var actionColor: Color {
        switch log.action {
        case .created, .copied:      return .hakedisInfo
        case .edited:                return .hakedisWarning
        case .submitted:             return .hakedisOrange
        case .approved, .paid:       return .hakedisSuccess
        case .rejected, .deleted:    return .hakedisDanger
        case .paymentAdded:          return .hakedisSuccess
        case .paymentDeleted:        return .hakedisDanger
        }
    }
}

// MARK: - AuditLogHelper

struct AuditLogHelper {
    static func log(
        context: ModelContext,
        hakedis: Hakedis,
        action: AuditAction,
        performedBy: String = "Kullanıcı",
        details: String? = nil
    ) {
        let log = HakedisAuditLog(action: action, performedBy: performedBy, details: details)
        log.hakedis = hakedis
        context.insert(log)
        do {
            try context.save()
        } catch {
            print("HakedisAuditLog save error: \(error.localizedDescription)")
        }
    }
}

// MARK: - HakedisTemplateSettingsView

struct HakedisTemplateSettingsView: View {
    @Query private var templates: [HakedisTemplate]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false

    var body: some View {
        List {
            Section("PDF Şablonları") {
                ForEach(templates, id: \.id) { template in
                    NavigationLink(destination: HakedisTemplateDetailView(template: template)) {
                        HStack {
                            Image(systemName: "doc.text.fill").foregroundColor(.hakedisOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.templateName).font(.subheadline.bold())
                                Text("\(template.sections.count) bölüm").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if template.isDefault {
                                Text("Varsayılan").font(.caption2).foregroundColor(.hakedisSuccess)
                            }
                        }
                    }
                    .accessibilityLabel("\(template.templateName) şablonu")
                }
                .onDelete { offsets in
                    for i in offsets { modelContext.delete(templates[i]) }
                    try? modelContext.save()
                }
            }

            Section {
                Button("Yeni Şablon Oluştur") { showingAdd = true }
                    .foregroundColor(.hakedisOrange)
                    .accessibilityLabel("Yeni PDF şablonu")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("PDF Şablonları")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Şablon ekle")
            }
        }
        .sheet(isPresented: $showingAdd) { HakedisTemplateForm() }
        .onAppear { createDefaultIfNeeded() }
    }

    private func createDefaultIfNeeded() {
        if templates.isEmpty {
            let t = HakedisTemplate(templateName: "Standart Hakediş")
            t.isDefault = true
            t.headerText = "Hakediş Belgesi"
            t.footerText = "Bu belge otomatik oluşturulmuştur."
            modelContext.insert(t)
            try? modelContext.save()
        }
    }
}

// MARK: - HakedisTemplateDetailView

struct HakedisTemplateDetailView: View {
    let template: HakedisTemplate
    @Environment(\.modelContext) private var modelContext
    @State private var sections: [String] = []

    private let allSections = ["workItems", "payments", "retentionSummary", "approvalChain", "signatureBlock", "penaltySummary", "advanceSummary", "priceDifference"]

    var body: some View {
        List {
            Section("Şablon Bilgileri") {
                LabeledContent("Ad", value: template.templateName)
                HStack {
                    Text("Varsayılan")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { template.isDefault },
                        set: { template.isDefault = $0; try? modelContext.save() }
                    )).labelsHidden().tint(.hakedisSuccess)
                }
            }

            Section("Bölümler") {
                ForEach(allSections, id: \.self) { key in
                    Button {
                        if sections.contains(key) { sections.removeAll { $0 == key } }
                        else { sections.append(key) }
                        template.sections = sections
                        try? modelContext.save()
                    } label: {
                        HStack {
                            Image(systemName: sections.contains(key) ? "checkmark.square.fill" : "square")
                                .foregroundColor(sections.contains(key) ? .hakedisSuccess : .secondary)
                            Text(template.sectionLabels[key] ?? key).foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .accessibilityLabel("\(template.sectionLabels[key] ?? key), \(sections.contains(key) ? "seçili" : "seçili değil")")
                }
            }

            if !template.headerText.isEmpty {
                Section("Üstbilgi") { Text(template.headerText) }
            }
            if !template.footerText.isEmpty {
                Section("Altbilgi") { Text(template.footerText) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Şablon Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { sections = template.sections }
    }
}

// MARK: - HakedisTemplateForm

struct HakedisTemplateForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var templateName = ""
    @State private var headerText = ""
    @State private var footerText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Şablon Adı") {
                    TextField("Şablon adı *", text: $templateName).accessibilityLabel("Şablon adı")
                }
                Section("Üstbilgi") {
                    TextEditor(text: $headerText).frame(minHeight: 60).accessibilityLabel("Üstbilgi metni")
                }
                Section("Altbilgi") {
                    TextEditor(text: $footerText).frame(minHeight: 60).accessibilityLabel("Altbilgi metni")
                }
            }
            .navigationTitle("Yeni Şablon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.accessibilityLabel("İptal") }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        guard !templateName.isEmpty else { return }
                        let t = HakedisTemplate(templateName: templateName)
                        t.headerText = headerText
                        t.footerText = footerText
                        modelContext.insert(t)
                        try? modelContext.save()
                        dismiss()
                    }.accessibilityLabel("Kaydet")
                }
            }
        }
    }
}
