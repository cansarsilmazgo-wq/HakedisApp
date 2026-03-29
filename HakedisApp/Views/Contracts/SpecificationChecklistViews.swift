import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Status Color Helper

private extension SpecStatus {
    var uiColor: Color {
        switch self {
        case .bekliyor:  return .secondary
        case .kontrol:   return .hakedisWarning
        case .uygun:     return .hakedisSuccess
        case .uygunsuz:  return .hakedisDanger
        case .gecersiz:  return .secondary
        }
    }

    var icon: String {
        switch self {
        case .bekliyor:  return "clock"
        case .kontrol:   return "magnifyingglass"
        case .uygun:     return "checkmark.circle.fill"
        case .uygunsuz:  return "xmark.circle.fill"
        case .gecersiz:  return "minus.circle"
        }
    }
}

// MARK: - Template Manager

struct SpecificationTemplateManager {

    private static let defaultsKey = "spec_templates"

    struct TemplateItem: Codable {
        var sectionNo: String
        var title: String
        var category: String
        var isRequired: Bool
        var description: String
    }

    struct Template: Codable {
        var name: String
        var items: [TemplateItem]
    }

    static func save(_ items: [SpecificationItem], name: String) {
        var all = loadRaw()
        all.removeAll { $0.name == name }
        let templateItems = items.map {
            TemplateItem(
                sectionNo: $0.sectionNo,
                title: $0.title,
                category: $0.category.rawValue,
                isRequired: $0.isRequired,
                description: $0.specDescription
            )
        }
        all.append(Template(name: name, items: templateItems))
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    static func loadAll() -> [(name: String, items: [(sectionNo: String, title: String, category: SpecCategory, isRequired: Bool, description: String)])] {
        loadRaw().map { template in
            let parsed = template.items.compactMap { item -> (sectionNo: String, title: String, category: SpecCategory, isRequired: Bool, description: String)? in
                guard let cat = SpecCategory(rawValue: item.category) else { return nil }
                return (item.sectionNo, item.title, cat, item.isRequired, item.description)
            }
            return (name: template.name, items: parsed)
        }
    }

    static func delete(name: String) {
        var all = loadRaw()
        all.removeAll { $0.name == name }
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func loadRaw() -> [Template] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([Template].self, from: data) else {
            return []
        }
        return decoded
    }
}

// MARK: - Readiness Badge

private struct ReadinessBadge: View {
    let isReady: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isReady ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.caption)
            Text(isReady ? "Kabule Hazır" : "Hazır Değil")
                .font(.caption.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background((isReady ? Color.hakedisSuccess : Color.hakedisDanger).opacity(0.15))
        .foregroundColor(isReady ? .hakedisSuccess : .hakedisDanger)
        .clipShape(Capsule())
    }
}

// MARK: - 1. SpecificationChecklistSection

struct SpecificationChecklistSection: View {
    let contract: Contract
    @State private var showAddSheet = false

    private var items: [SpecificationItem] {
        contract.specificationItems.sorted {
            if $0.status == .uygunsuz && $1.status != .uygunsuz { return true }
            if $0.status != .uygunsuz && $1.status == .uygunsuz { return false }
            return $0.sectionNo < $1.sectionNo
        }
    }

    private var requiredItems: [SpecificationItem] {
        contract.specificationItems.filter { $0.isRequired }
    }

    private var requiredCompletedCount: Int {
        requiredItems.filter { $0.status == .uygun }.count
    }

    private var isReadyForAcceptance: Bool {
        guard !requiredItems.isEmpty else { return true }
        return requiredItems.allSatisfy { $0.status == .uygun }
    }

    private var openNonConformances: [SpecificationItem] {
        contract.specificationItems.filter { $0.isOpen }
    }

    private var completionProgress: Double {
        guard !requiredItems.isEmpty else { return 0 }
        return Double(requiredCompletedCount) / Double(requiredItems.count) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Teknik Şartname", systemImage: "checklist")
                    .font(.headline)
                Spacer()
                ReadinessBadge(isReady: isReadyForAcceptance)
            }

            // Progress
            if !requiredItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Zorunlu Maddeler")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(requiredCompletedCount)/\(requiredItems.count)")
                            .font(.caption.bold())
                    }
                    ProgressBarView(progress: completionProgress, color: isReadyForAcceptance ? .hakedisSuccess : .hakedisOrange)
                }
            }

            // Open nonconformances warning
            if !openNonConformances.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.hakedisDanger)
                        .font(.caption)
                    Text("\(openNonConformances.count) açık uygunsuzluk mevcut")
                        .font(.caption)
                        .foregroundColor(.hakedisDanger)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.hakedisDanger.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // First 3 items
            if items.isEmpty {
                Text("Henüz şartname maddesi eklenmemiş.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(items.prefix(3)) { item in
                    SpecificationItemRow(item: item)
                        .padding(.vertical, 2)
                    if item.id != items.prefix(3).last?.id {
                        Divider()
                    }
                }
            }

            // Actions
            HStack(spacing: 12) {
                if !items.isEmpty {
                    NavigationLink(destination: SpecificationChecklistView(contract: contract)) {
                        Label("Tümünü Gör", systemImage: "list.bullet")
                            .font(.subheadline.bold())
                            .foregroundColor(.hakedisOrange)
                    }
                }
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("Madde Ekle", systemImage: "plus")
                        .font(.subheadline.bold())
                        .foregroundColor(.hakedisOrange)
                }
            }
        }
        .padding(16)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showAddSheet) {
            AddSpecificationItemView(contract: contract)
        }
    }
}

// MARK: - 3. SpecificationItemRow

struct SpecificationItemRow: View {
    let item: SpecificationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // Section number
                Text(item.sectionNo)
                    .font(.caption2.bold())
                    .foregroundColor(.hakedisOrange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.hakedisOrange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.subheadline)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        StatusBadge(text: item.status.rawValue, color: item.status.uiColor)
                    }

                    HStack(spacing: 6) {
                        // Category
                        Label(item.category.rawValue, systemImage: item.category.icon)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if item.isRequired {
                            StatusBadge(text: "Zorunlu", color: .hakedisOrange)
                        }

                        if !item.evidenceData.isEmpty {
                            Label("\(item.evidenceData.count)", systemImage: "photo")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if item.isOverdue {
                            Label("Gecikmiş", systemImage: "clock.badge.exclamationmark")
                                .font(.caption2.bold())
                                .foregroundColor(.hakedisDanger)
                        } else if let days = item.daysUntilDue, days >= 0, days <= 7, item.status == .uygunsuz {
                            Label("\(days) gün", systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(.hakedisWarning)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 2. SpecificationChecklistView

struct SpecificationChecklistView: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext

    @State private var selectedCategory: SpecCategory? = nil
    @State private var statusFilter: StatusFilter = .all
    @State private var showAddSheet = false
    @State private var showSaveTemplateAlert = false
    @State private var showLoadTemplateSheet = false
    @State private var newTemplateName = ""
    @State private var showReadinessReport = false

    enum StatusFilter: String, CaseIterable {
        case all = "Tümü"
        case bekliyor = "Bekliyor"
        case uygunsuz = "Uygunsuz"

        var specStatus: SpecStatus? {
            switch self {
            case .all: return nil
            case .bekliyor: return .bekliyor
            case .uygunsuz: return .uygunsuz
            }
        }
    }

    private var filteredItems: [SpecificationItem] {
        contract.specificationItems.filter { item in
            let catMatch = selectedCategory == nil || item.category == selectedCategory
            let statMatch: Bool
            if let sf = statusFilter.specStatus {
                statMatch = item.status == sf
            } else {
                statMatch = true
            }
            return catMatch && statMatch
        }.sorted {
            if $0.status == .uygunsuz && $1.status != .uygunsuz { return true }
            if $0.status != .uygunsuz && $1.status == .uygunsuz { return false }
            return $0.sectionNo < $1.sectionNo
        }
    }

    private var categoriesWithItems: [SpecCategory] {
        SpecCategory.allCases.filter { cat in
            contract.specificationItems.contains { $0.category == cat }
        }
    }

    private func itemsForCategory(_ category: SpecCategory) -> [SpecificationItem] {
        filteredItems.filter { $0.category == category }
    }

    private func completionForCategory(_ category: SpecCategory) -> (completed: Int, total: Int) {
        let catItems = contract.specificationItems.filter { $0.category == category && $0.isRequired }
        let done = catItems.filter { $0.status == .uygun }.count
        return (done, catItems.count)
    }

    private var requiredItems: [SpecificationItem] {
        contract.specificationItems.filter { $0.isRequired }
    }

    private var requiredCompletedCount: Int {
        requiredItems.filter { $0.status == .uygun }.count
    }

    private var isReadyForAcceptance: Bool {
        guard !requiredItems.isEmpty else { return true }
        return requiredItems.allSatisfy { $0.status == .uygun }
    }

    private var completionProgress: Double {
        guard !requiredItems.isEmpty else { return 0 }
        return Double(requiredCompletedCount) / Double(requiredItems.count) * 100
    }

    var body: some View {
        List {
            // Kabule Hazır Summary
            Section {
                readinessSummaryView
            }

            // Category Filter
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SpecFilterChip(
                            label: "Tümü",
                            icon: "square.grid.2x2",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        ForEach(SpecCategory.allCases, id: \.self) { cat in
                            SpecFilterChip(
                                label: cat.rawValue,
                                icon: cat.icon,
                                isSelected: selectedCategory == cat
                            ) {
                                selectedCategory = (selectedCategory == cat) ? nil : cat
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Status Filter
            Section {
                Picker("Durum", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Items grouped by category
            if filteredItems.isEmpty {
                Section {
                    EmptyStateView(
                        icon: "checklist",
                        title: "Madde Bulunamadı",
                        subtitle: "Seçilen filtreye uygun şartname maddesi yok."
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                let activeCategories = (selectedCategory != nil)
                    ? [selectedCategory!]
                    : categoriesWithItems

                ForEach(activeCategories, id: \.self) { category in
                    let catItems = itemsForCategory(category)
                    if !catItems.isEmpty {
                        Section {
                            ForEach(catItems) { item in
                                NavigationLink(destination: SpecificationItemDetailView(item: item)) {
                                    SpecificationItemRow(item: item)
                                        .padding(.vertical, 2)
                                }
                            }
                            .onDelete { offsets in
                                deleteItems(catItems, at: offsets)
                            }
                        } header: {
                            categoryHeaderView(for: category)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Teknik Şartname")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showLoadTemplateSheet = true
                } label: {
                    Label("Şablon Yükle", systemImage: "arrow.down.doc")
                }

                Button {
                    newTemplateName = ""
                    showSaveTemplateAlert = true
                } label: {
                    Label("Şablon Kaydet", systemImage: "arrow.up.doc")
                }

                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Şablon Kaydet", isPresented: $showSaveTemplateAlert) {
            TextField("Şablon adı", text: $newTemplateName)
            Button("Kaydet") {
                guard !newTemplateName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                SpecificationTemplateManager.save(contract.specificationItems, name: newTemplateName)
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Bu sözleşmenin şartname maddelerini şablon olarak kaydedin.")
        }
        .sheet(isPresented: $showAddSheet) {
            AddSpecificationItemView(contract: contract)
        }
        .sheet(isPresented: $showLoadTemplateSheet) {
            LoadTemplateView(contract: contract)
        }
        .sheet(isPresented: $showReadinessReport) {
            NavigationStack {
                ReadinessReportView(contract: contract)
            }
        }
    }

    @ViewBuilder
    private var readinessSummaryView: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kabule Hazırlık")
                        .font(.headline)
                    Text("\(requiredCompletedCount)/\(requiredItems.count) zorunlu madde tamamlandı")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                ReadinessBadge(isReady: isReadyForAcceptance)
            }

            ProgressBarView(
                progress: completionProgress,
                color: isReadyForAcceptance ? .hakedisSuccess : .hakedisOrange
            )

            Button {
                showReadinessReport = true
            } label: {
                Text("Tam Raporu Gör")
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func categoryHeaderView(for category: SpecCategory) -> some View {
        let comp = completionForCategory(category)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .foregroundColor(.hakedisOrange)
                Text(category.rawValue)
                    .font(.subheadline.bold())
                Spacer()
                if comp.total > 0 {
                    Text("\(comp.completed)/\(comp.total)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            if comp.total > 0 {
                ProgressBarView(
                    progress: Double(comp.completed) / Double(comp.total) * 100,
                    color: comp.completed == comp.total ? .hakedisSuccess : .hakedisOrange
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func deleteItems(_ items: [SpecificationItem], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

// MARK: - Filter Chip

private struct SpecFilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.hakedisOrange : Color.hakedisCard)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.hakedisOrange : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4. AddSpecificationItemView

struct AddSpecificationItemView: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sectionNo = ""
    @State private var title = ""
    @State private var specDescription = ""
    @State private var category: SpecCategory = .diger
    @State private var isRequired = true
    @State private var selectedTemplate: String? = nil
    @State private var templates: [(name: String, items: [(sectionNo: String, title: String, category: SpecCategory, isRequired: Bool, description: String)])] = []
    @State private var showTemplateApplyConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Şablon") {
                    if templates.isEmpty {
                        Text("Kayıtlı şablon bulunamadı.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Şablondan Yükle", selection: $selectedTemplate) {
                            Text("Seçiniz").tag(Optional<String>.none)
                            ForEach(templates, id: \.name) { t in
                                Text(t.name).tag(Optional(t.name))
                            }
                        }
                        .onChange(of: selectedTemplate) { _, newVal in
                            if newVal != nil { showTemplateApplyConfirm = true }
                        }

                        if let name = selectedTemplate,
                           let tmpl = templates.first(where: { $0.name == name }) {
                            Text("\(tmpl.items.count) madde içeriyor")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Bu Şablonu Ekle") {
                                applyTemplate(tmpl)
                            }
                            .foregroundColor(.hakedisOrange)
                        }
                    }
                }

                Section("Madde Bilgileri") {
                    TextField("Bölüm No (ör. 1.2.3)", text: $sectionNo)
                        .autocorrectionDisabled()

                    TextField("Başlık", text: $title)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Açıklama")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $specDescription)
                            .frame(minHeight: 80)
                    }
                }

                Section("Kategori ve Zorunluluk") {
                    Picker("Kategori", selection: $category) {
                        ForEach(SpecCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }

                    Toggle("Zorunlu Madde", isOn: $isRequired)
                }
            }
            .navigationTitle("Madde Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(sectionNo.trimmingCharacters(in: .whitespaces).isEmpty || title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
            .onAppear {
                templates = SpecificationTemplateManager.loadAll()
            }
        }
    }

    private func save() {
        let item = SpecificationItem(
            sectionNo: sectionNo.trimmingCharacters(in: .whitespaces),
            title: title.trimmingCharacters(in: .whitespaces),
            category: category,
            isRequired: isRequired
        )
        item.specDescription = specDescription.trimmingCharacters(in: .whitespaces)
        item.contract = contract
        modelContext.insert(item)
        dismiss()
    }

    private func applyTemplate(_ tmpl: (name: String, items: [(sectionNo: String, title: String, category: SpecCategory, isRequired: Bool, description: String)])) {
        for rawItem in tmpl.items {
            let item = SpecificationItem(
                sectionNo: rawItem.sectionNo,
                title: rawItem.title,
                category: rawItem.category,
                isRequired: rawItem.isRequired
            )
            item.specDescription = rawItem.description
            item.contract = contract
            modelContext.insert(item)
        }
        dismiss()
    }
}

// MARK: - Load Template Sheet

private struct LoadTemplateView: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var templates: [(name: String, items: [(sectionNo: String, title: String, category: SpecCategory, isRequired: Bool, description: String)])] = []
    @State private var templateToDelete: String? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "Şablon Bulunamadı",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Henüz kaydedilmiş şablon yok. Şartname listesinden şablon kaydedebilirsiniz.")
                    )
                } else {
                    List {
                        ForEach(templates, id: \.name) { tmpl in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tmpl.name)
                                    .font(.headline)
                                Text("\(tmpl.items.count) madde")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    templateToDelete = tmpl.name
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    applyTemplate(tmpl)
                                } label: {
                                    Label("Yükle", systemImage: "arrow.down.doc.fill")
                                }
                                .tint(.hakedisOrange)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                applyTemplate(tmpl)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Şablon Yükle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .onAppear {
                templates = SpecificationTemplateManager.loadAll()
            }
            .confirmationDialog(
                "Şablonu sil?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Sil", role: .destructive) {
                    if let name = templateToDelete {
                        SpecificationTemplateManager.delete(name: name)
                        templates = SpecificationTemplateManager.loadAll()
                    }
                }
                Button("İptal", role: .cancel) {}
            } message: {
                if let name = templateToDelete {
                    Text("'\(name)' şablonu kalıcı olarak silinecek.")
                }
            }
        }
    }

    private func applyTemplate(_ tmpl: (name: String, items: [(sectionNo: String, title: String, category: SpecCategory, isRequired: Bool, description: String)])) {
        for rawItem in tmpl.items {
            let item = SpecificationItem(
                sectionNo: rawItem.sectionNo,
                title: rawItem.title,
                category: rawItem.category,
                isRequired: rawItem.isRequired
            )
            item.specDescription = rawItem.description
            item.contract = contract
            modelContext.insert(item)
        }
        dismiss()
    }
}

// MARK: - 5. SpecificationItemDetailView

struct SpecificationItemDetailView: View {
    @Bindable var item: SpecificationItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCloseConfirm = false

    var body: some View {
        Form {
            // Basic Info
            Section("Madde Bilgileri") {
                HStack {
                    Text("Bölüm No")
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("No", text: $item.sectionNo)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                }

                TextField("Başlık", text: $item.title)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Açıklama")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $item.specDescription)
                        .frame(minHeight: 80)
                }

                Picker("Kategori", selection: $item.category) {
                    ForEach(SpecCategory.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }

                Toggle("Zorunlu Madde", isOn: $item.isRequired)
            }

            // Status
            Section("Durum") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Durum", selection: $item.status) {
                        ForEach(SpecStatus.allCases, id: \.self) { s in
                            HStack {
                                Image(systemName: s.icon)
                                Text(s.rawValue)
                            }
                            .tag(s)
                        }
                    }
                    .pickerStyle(.menu)

                    StatusBadge(text: item.status.rawValue, color: item.status.uiColor)

                    if item.isOverdue {
                        Label("Gecikmiş — Düzeltici önlem alınmalı", systemImage: "clock.badge.exclamationmark.fill")
                            .font(.caption)
                            .foregroundColor(.hakedisDanger)
                    } else if let days = item.daysUntilDue {
                        if days < 0 {
                            Label("Vade geçti (\(-days) gün önce)", systemImage: "clock.badge.exclamationmark")
                                .font(.caption)
                                .foregroundColor(.hakedisDanger)
                        } else if days <= 7 {
                            Label("\(days) gün içinde vade dolacak", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.hakedisWarning)
                        }
                    }
                }
            }

            // Inspection (shown when status != bekliyor)
            if item.status != .bekliyor {
                Section("Muayene Bilgileri") {
                    HStack {
                        Text("Muayene Eden")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("Ad Soyad", text: Binding(
                            get: { item.inspectedBy ?? "" },
                            set: { item.inspectedBy = $0.isEmpty ? nil : $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }

                    DatePicker(
                        "Muayene Tarihi",
                        selection: Binding(
                            get: { item.inspectionDate ?? Date() },
                            set: { item.inspectionDate = $0 }
                        ),
                        displayedComponents: [.date]
                    )
                }
            }

            // Nonconformance (shown when status == uygunsuz)
            if item.status == .uygunsuz {
                Section("Uygunsuzluk") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Uygunsuzluk Notu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: Binding(
                            get: { item.nonConformanceNote ?? "" },
                            set: { item.nonConformanceNote = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 60)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Düzeltici Faaliyet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: Binding(
                            get: { item.correctiveAction ?? "" },
                            set: { item.correctiveAction = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 60)
                    }

                    DatePicker(
                        "Vade Tarihi",
                        selection: Binding(
                            get: { item.dueDate ?? Date().addingTimeInterval(7 * 86400) },
                            set: { item.dueDate = $0 }
                        ),
                        in: Date()...,
                        displayedComponents: [.date]
                    )

                    if item.closedAt == nil {
                        Button {
                            showCloseConfirm = true
                        } label: {
                            Label("Uygunsuzluğu Kapat", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.hakedisSuccess)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.hakedisSuccess)
                            Text("Kapatıldı: \(item.closedAt!.shortFormatted)")
                                .font(.subheadline)
                                .foregroundColor(.hakedisSuccess)
                        }
                    }
                }
            }

            // Evidence Photos
            Section("Kanıtlar") {
                if item.evidenceData.isEmpty {
                    Text("Henüz kanıt fotoğrafı eklenmemiş.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(item.evidenceData.enumerated()), id: \.offset) { index, data in
                                ZStack(alignment: .topTrailing) {
                                    if let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 90, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    Button {
                                        item.evidenceData.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.hakedisDanger)
                                            .background(Color.white.clipShape(Circle()))
                                    }
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                    Label("Fotoğraf Ekle", systemImage: "photo.badge.plus")
                        .foregroundColor(.hakedisOrange)
                }
                .onChange(of: selectedPhotoItems) { _, newItems in
                    Task {
                        for pickerItem in newItems {
                            if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                                item.evidenceData.append(data)
                            }
                        }
                        selectedPhotoItems = []
                    }
                }
            }

            // Metadata
            Section("Bilgi") {
                HStack {
                    Text("Oluşturulma")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(item.createdAt.shortFormatted)
                        .foregroundColor(.secondary)
                }
                if let closed = item.closedAt {
                    HStack {
                        Text("Kapatılma")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(closed.shortFormatted)
                            .foregroundColor(.hakedisSuccess)
                    }
                }
            }
        }
        .navigationTitle(item.sectionNo.isEmpty ? "Madde Detayı" : "Madde \(item.sectionNo)")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Uygunsuzluğu kapat?",
            isPresented: $showCloseConfirm,
            titleVisibility: .visible
        ) {
            Button("Kapat") {
                item.closedAt = Date()
                item.status = .uygun
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Bu uygunsuzluk kapatıldığında durum 'Uygun' olarak işaretlenecektir.")
        }
    }
}

// MARK: - 6. ReadinessReportView

struct ReadinessReportView: View {
    let contract: Contract
    @Environment(\.dismiss) private var dismiss

    private var requiredItems: [SpecificationItem] {
        contract.specificationItems.filter { $0.isRequired }
    }

    private var completedRequired: [SpecificationItem] {
        requiredItems.filter { $0.status == .uygun }
    }

    private var openNonConformances: [SpecificationItem] {
        contract.specificationItems.filter { $0.isOpen }
    }

    private var isReady: Bool {
        guard !requiredItems.isEmpty else { return true }
        return completedRequired.count == requiredItems.count
    }

    private var completionPercent: Double {
        guard !requiredItems.isEmpty else { return 100 }
        return Double(completedRequired.count) / Double(requiredItems.count) * 100
    }

    private func completionForCategory(_ cat: SpecCategory) -> (completed: Int, total: Int) {
        let catItems = contract.specificationItems.filter { $0.category == cat && $0.isRequired }
        return (catItems.filter { $0.status == .uygun }.count, catItems.count)
    }

    private var textSummary: String {
        var lines: [String] = []
        lines.append("KABUL HAZIRLIK RAPORU")
        lines.append("Sözleşme: \(contract.title)")
        lines.append("Tarih: \(Date().shortFormatted)")
        lines.append("")
        lines.append("GENEL DURUM: \(isReady ? "KABULE HAZIR ✓" : "HAZIR DEĞİL ✗")")
        lines.append("Zorunlu Madde Tamamlanma: \(completedRequired.count)/\(requiredItems.count) (\(String(format: "%.0f%%", completionPercent)))")
        lines.append("")
        lines.append("KATEGORİ BAZLI:")
        for cat in SpecCategory.allCases {
            let comp = completionForCategory(cat)
            if comp.total > 0 {
                lines.append("  \(cat.rawValue): \(comp.completed)/\(comp.total)")
            }
        }
        if !openNonConformances.isEmpty {
            lines.append("")
            lines.append("AÇIK UYGUNSUZLUKLAR (\(openNonConformances.count) adet):")
            for item in openNonConformances {
                lines.append("  [\(item.sectionNo)] \(item.title)")
                if let note = item.nonConformanceNote, !note.isEmpty {
                    lines.append("    Not: \(note)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((isReady ? Color.hakedisSuccess : Color.hakedisDanger).opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: isReady ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.system(size: 52))
                            .foregroundColor(isReady ? .hakedisSuccess : .hakedisDanger)
                    }

                    Text(isReady ? "Kabule Hazır" : "Hazır Değil")
                        .font(.title.bold())
                        .foregroundColor(isReady ? .hakedisSuccess : .hakedisDanger)

                    Text(isReady
                         ? "Tüm zorunlu şartname maddeleri tamamlandı."
                         : "Henüz tamamlanmamış zorunlu maddeler var.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 8)

                // Progress Ring (visual)
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 14)
                            .frame(width: 130, height: 130)
                        Circle()
                            .trim(from: 0, to: CGFloat(completionPercent / 100))
                            .stroke(
                                isReady ? Color.hakedisSuccess : Color.hakedisOrange,
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 130, height: 130)
                            .animation(.easeOut(duration: 0.8), value: completionPercent)
                        VStack(spacing: 2) {
                            Text("\(Int(completionPercent))%")
                                .font(.title2.bold())
                            Text("Tamamlandı")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("\(completedRequired.count)/\(requiredItems.count) zorunlu madde")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Category bars
                VStack(alignment: .leading, spacing: 16) {
                    Text("Kategori Bazlı Durum")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(SpecCategory.allCases, id: \.self) { cat in
                        let comp = completionForCategory(cat)
                        if comp.total > 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                        .foregroundColor(.hakedisOrange)
                                        .frame(width: 18)
                                    Text(cat.rawValue)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(comp.completed)/\(comp.total)")
                                        .font(.caption.bold())
                                        .foregroundColor(comp.completed == comp.total ? .hakedisSuccess : .secondary)
                                }
                                ProgressBarView(
                                    progress: Double(comp.completed) / Double(comp.total) * 100,
                                    color: comp.completed == comp.total ? .hakedisSuccess : .hakedisOrange
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Open nonconformances
                if !openNonConformances.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.hakedisDanger)
                            Text("Açık Uygunsuzluklar")
                                .font(.headline)
                                .foregroundColor(.hakedisDanger)
                        }
                        .padding(.horizontal)

                        ForEach(openNonConformances) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(item.sectionNo)
                                        .font(.caption2.bold())
                                        .foregroundColor(.hakedisOrange)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.hakedisOrange.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    Text(item.title)
                                        .font(.subheadline)
                                    Spacer()
                                    if item.isOverdue {
                                        Label("Gecikmiş", systemImage: "clock.badge.exclamationmark")
                                            .font(.caption2.bold())
                                            .foregroundColor(.hakedisDanger)
                                    }
                                }
                                if let note = item.nonConformanceNote, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                if let due = item.dueDate {
                                    Label("Vade: \(due.shortFormatted)", systemImage: "calendar")
                                        .font(.caption)
                                        .foregroundColor(item.isOverdue ? .hakedisDanger : .secondary)
                                }
                            }
                            .padding(12)
                            .background(Color.hakedisDanger.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.hakedisDanger.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.hakedisSuccess)
                        Text("Açık uygunsuzluk bulunmuyor.")
                            .font(.subheadline)
                            .foregroundColor(.hakedisSuccess)
                    }
                    .padding()
                    .background(Color.hakedisSuccess.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                // Share
                ShareLink(item: textSummary) {
                    Label("PDF Raporu Paylaş", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.hakedisOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                Spacer(minLength: 32)
            }
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Kabul Hazırlık Raporu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Kapat") { dismiss() }
            }
        }
    }
}

