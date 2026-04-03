import SwiftUI
import SwiftData

// MARK: - QualityChecklistListView

struct QualityChecklistListView: View {
    @Query(sort: \QualityChecklist.date, order: .reverse) private var checklists: [QualityChecklist]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedType: QualityChecklistType? = nil

    private var filtered: [QualityChecklist] {
        guard let t = selectedType else { return checklists }
        return checklists.filter { $0.checklistType == t }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: selectedType == nil) {
                            selectedType = nil
                        }
                        ForEach(QualityChecklistType.allCases, id: \.rawValue) { t in
                            FilterChip(title: t.rawValue, isSelected: selectedType == t) {
                                selectedType = selectedType == t ? nil : t
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, 6)
                }
                .background(Color.hakedisBackground)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.seal",
                        title: "Kalite kontrol listesi yok",
                        subtitle: "İş kalitesini kontrol listesiyle belgeleyin",
                        actionTitle: "Kontrol Listesi Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { cl in
                            NavigationLink(destination: QualityChecklistDetailView(checklist: cl)) {
                                QualityChecklistRow(checklist: cl)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(cl)
                                } label: { Label("Sil", systemImage: "trash") }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Kontrol listesi ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) {
            AddQualityChecklistView()
        }
    }
}

// MARK: - QualityChecklistRow

private struct QualityChecklistRow: View {
    let checklist: QualityChecklist

    private var resultColor: Color {
        switch checklist.overallResult {
        case .pass:        return .hakedisSuccess
        case .fail:        return .hakedisDanger
        case .conditional: return .hakedisWarning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(checklist.checklistType.rawValue).font(.subheadline.bold())
                Spacer()
                StatusBadge(text: checklist.overallResult.rawValue, color: resultColor)
            }
            if let name = checklist.workItem?.name {
                Text(name).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            HStack {
                Text(checklist.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("\(checklist.passedCount)/\(checklist.totalCount) madde")
                    .font(.caption2.bold())
                    .foregroundColor(checklist.passedCount == checklist.totalCount ? .hakedisSuccess : .hakedisWarning)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(checklist.checklistType.rawValue), \(checklist.overallResult.rawValue), \(checklist.passedCount)/\(checklist.totalCount) madde")
    }
}

// MARK: - QualityChecklistDetailView

struct QualityChecklistDetailView: View {
    @Bindable var checklist: QualityChecklist
    @State private var items: [QualityCheckItem] = []
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section("Bilgiler") {
                LabeledContent("Tür", value: checklist.checklistType.rawValue)
                LabeledContent("Tarih", value: checklist.date.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Kontrol Eden", value: checklist.checkedBy)
                if let wname = checklist.workItem?.name {
                    LabeledContent("İş Kalemi", value: wname)
                }
            }

            Section("Genel Sonuç") {
                Picker("Sonuç", selection: $checklist.overallResultRaw) {
                    ForEach(CheckResult.allCases, id: \.rawValue) { r in
                        Text(r.rawValue).tag(r.rawValue)
                    }
                }
                .onChange(of: checklist.overallResultRaw) { _, _ in
                    try? modelContext.save()
                }
            }

            Section("Kontrol Maddeleri (\(checklist.passedCount)/\(checklist.totalCount))") {
                ForEach(items.indices, id: \.self) { i in
                    HStack {
                        Image(systemName: items[i].isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(items[i].isChecked ? .hakedisSuccess : .secondary)
                            .font(.title3)
                            .onTapGesture {
                                items[i].isChecked.toggle()
                                checklist.checkItems = items
                                try? modelContext.save()
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(items[i].title).font(.subheadline)
                            if !items[i].note.isEmpty {
                                Text(items[i].note).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let notes = checklist.notes, !notes.isEmpty {
                Section("Notlar") {
                    Text(notes).font(.body)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Kontrol Listesi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { items = checklist.checkItems }
    }
}

// MARK: - AddQualityChecklistView

struct AddQualityChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var workItems: [WorkItem]

    @State private var selectedType: QualityChecklistType = .general
    @State private var date = Date()
    @State private var checkedBy = ""
    @State private var selectedWorkItem: WorkItem? = nil
    @State private var notes = ""
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Kontrol Bilgileri") {
                    Picker("Kontrol Türü", selection: $selectedType) {
                        ForEach(QualityChecklistType.allCases, id: \.rawValue) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    TextField("Kontrol Eden Kişi", text: $checkedBy)
                    if showValidation && checkedBy.isEmpty {
                        Text("Kontrol eden kişi zorunludur").font(.caption).foregroundColor(.hakedisDanger)
                    }
                }
                Section("İlişkilendir") {
                    Picker("İş Kalemi", selection: $selectedWorkItem) {
                        Text("Seçilmedi").tag(Optional<WorkItem>.none)
                        ForEach(workItems, id: \.id) { w in Text(w.name).tag(Optional(w)) }
                    }
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Varsayılan Kontrol Maddeleri").font(.caption.bold()).foregroundColor(.secondary)
                        ForEach(selectedType.defaultItems, id: \.self) { item in
                            HStack(spacing: 6) {
                                Image(systemName: "circle").font(.caption2).foregroundColor(.secondary)
                                Text(item).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                } header: { Text("Önizleme") }
            }
            .navigationTitle("Kontrol Listesi Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Oluştur") { save() } }
            }
        }
    }

    private func save() {
        guard !checkedBy.isEmpty else { showValidation = true; return }
        let cl = QualityChecklist(checklistType: selectedType, date: date, checkedBy: checkedBy)
        cl.workItem = selectedWorkItem
        cl.notes = notes.isEmpty ? nil : notes
        modelContext.insert(cl)
        do { try modelContext.save() } catch { print(error) }
        dismiss()
    }
}
