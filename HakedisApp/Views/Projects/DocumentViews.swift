import SwiftUI
import SwiftData

// MARK: - DocumentListView (B1)

struct DocumentListView: View {
    @Query(sort: \ProjectDocument.revisionDate, order: .reverse) private var allDocs: [ProjectDocument]
    @Environment(\.modelContext) private var modelContext
    var project: Project? = nil

    @State private var showingAdd = false
    @State private var typeFilter: DocumentType? = nil
    @State private var disciplineFilter: DocumentDiscipline? = nil
    @State private var searchText = ""

    private var filtered: [ProjectDocument] {
        allDocs.filter { d in
            let projMatch = project.map { d.project?.id == $0.id } ?? true
            let typeMatch = typeFilter.map { d.documentType == $0 } ?? true
            let discMatch = disciplineFilter.map { d.discipline == $0 } ?? true
            let searchMatch = searchText.isEmpty ||
                d.documentName.localizedCaseInsensitiveContains(searchText) ||
                (d.tags ?? "").localizedCaseInsensitiveContains(searchText)
            return projMatch && typeMatch && discMatch && searchMatch
        }
    }

    private var grouped: [(DocumentType, [ProjectDocument])] {
        let g = Dictionary(grouping: filtered) { $0.documentType }
        return DocumentType.allCases.compactMap { t in
            guard let items = g[t], !items.isEmpty else { return nil }
            return (t, items)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Discipline filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: disciplineFilter == nil) { disciplineFilter = nil }
                        ForEach(DocumentDiscipline.allCases, id: \.self) { d in
                            FilterChip(title: d.rawValue, isSelected: disciplineFilter == d) {
                                disciplineFilter = disciplineFilter == d ? nil : d
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                }
                .background(Color.hakedisBackground)

                if filtered.isEmpty {
                    EmptyStateView(icon: "doc.fill",
                                   title: "Doküman yok",
                                   subtitle: "Proje dokümanlarını buradan yönetin",
                                   actionTitle: "Doküman Ekle",
                                   action: { showingAdd = true })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(grouped, id: \.0.rawValue) { type, docs in
                            Section(type.rawValue) {
                                ForEach(docs, id: \.id) { doc in
                                    NavigationLink(destination: DocumentDetailView(document: doc)) {
                                        DocumentRow(document: doc)
                                    }
                                }
                                .onDelete { offsets in
                                    for i in offsets { modelContext.delete(docs[i]) }
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Doküman adı veya etiket ara")
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(Color.hakedisOrange).clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4).accessibilityLabel("Doküman ekle")
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Dokümanlar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) { AddDocumentView(project: project) }
    }
}

// MARK: - DocumentRow

private struct DocumentRow: View {
    let document: ProjectDocument

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: document.documentType.icon)
                .foregroundColor(document.isCurrentRevision ? .hakedisOrange : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.documentName).font(.subheadline.bold())
                    .foregroundColor(document.isCurrentRevision ? .primary : .secondary)
                HStack {
                    Text(document.revisionNo).font(.caption2.bold()).foregroundColor(.hakedisOrange)
                    Text(document.discipline.rawValue).font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    if let kb = document.fileSizeKB { Text("\(kb) KB").font(.caption2).foregroundColor(.secondary) }
                    Text(document.revisionDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
                }
                if let tags = document.tags, !tags.isEmpty {
                    Text(tags).font(.caption2).foregroundColor(.hakedisInfo).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(document.isCurrentRevision ? 1 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.documentName), \(document.revisionNo)")
    }
}

// MARK: - DocumentDetailView

struct DocumentDetailView: View {
    let document: ProjectDocument
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddRevision = false

    var body: some View {
        List {
            Section("Doküman Bilgileri") {
                LabeledContent("Ad", value: document.documentName)
                LabeledContent("Tür", value: document.documentType.rawValue)
                LabeledContent("Disiplin", value: document.discipline.rawValue)
                LabeledContent("Revizyon No", value: document.revisionNo)
                LabeledContent("Revizyon Tarihi", value: document.revisionDate.shortFormatted)
                if let kb = document.fileSizeKB { LabeledContent("Boyut", value: "\(kb) KB") }
                if let by = document.uploadedBy { LabeledContent("Yükleyen", value: by) }
                if let tags = document.tags, !tags.isEmpty { LabeledContent("Etiketler", value: tags) }
                if let notes = document.notes, !notes.isEmpty { Text(notes).font(.caption).foregroundColor(.secondary) }
            }

            if !document.previousRevisions.isEmpty {
                Section("Revizyon Geçmişi") {
                    ForEach(document.previousRevisions.sorted { $0.revisionDate > $1.revisionDate }, id: \.id) { rev in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(rev.revisionNo).font(.caption.bold()).foregroundColor(.hakedisOrange)
                                Spacer()
                                Text(rev.revisionDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
                            }
                            if let desc = rev.changeDescription, !desc.isEmpty {
                                Text(desc).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("İşlemler") {
                Button { showingAddRevision = true } label: {
                    Label("Yeni Revizyon Ekle", systemImage: "plus.circle")
                }
                .foregroundColor(.hakedisOrange).accessibilityLabel("Yeni revizyon ekle")

                if document.fileData != nil {
                    Button {
                        // ShareSheet: fileData
                    } label: { Label("Paylaş", systemImage: "square.and.arrow.up") }
                        .foregroundColor(.hakedisInfo)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(document.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddRevision) { AddDocumentRevisionView(document: document) }
    }
}

// MARK: - AddDocumentView

struct AddDocumentView: View {
    var project: Project? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var documentName = ""
    @State private var documentType: DocumentType = .drawing
    @State private var discipline: DocumentDiscipline = .general
    @State private var revisionNo = "Rev.0"
    @State private var uploadedBy = ""
    @State private var tags = ""
    @State private var notes = ""
    @State private var selectedProject: Project? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Doküman Bilgileri") {
                    TextField("Doküman adı *", text: $documentName).accessibilityLabel("Doküman adı")
                    Picker("Tür", selection: $documentType) {
                        ForEach(DocumentType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    Picker("Disiplin", selection: $discipline) {
                        ForEach(DocumentDiscipline.allCases, id: \.self) { d in Text(d.rawValue).tag(d) }
                    }
                    TextField("Revizyon No", text: $revisionNo).accessibilityLabel("Revizyon no")
                    TextField("Yükleyen", text: $uploadedBy)
                    if project == nil {
                        Picker("Proje", selection: $selectedProject) {
                            Text("Seçilmedi").tag(Optional<Project>.none)
                            ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                        }
                    }
                }
                Section("Etiketler") {
                    TextField("Virgülle ayrılmış etiketler", text: $tags)
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
            }
            .navigationTitle("Doküman Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(documentName.isEmpty)
                }
            }
            .onAppear { selectedProject = project }
        }
    }

    private func save() {
        let doc = ProjectDocument(documentName: documentName, documentType: documentType,
                                  discipline: discipline, revisionNo: revisionNo)
        doc.uploadedBy = uploadedBy.isEmpty ? nil : uploadedBy
        doc.tags = tags.isEmpty ? nil : tags
        doc.notes = notes.isEmpty ? nil : notes
        doc.project = project ?? selectedProject
        modelContext.insert(doc)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - AddDocumentRevisionView

struct AddDocumentRevisionView: View {
    let document: ProjectDocument
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var revisionNo = ""
    @State private var changeDescription = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Revizyon Bilgileri") {
                    TextField("Revizyon No (ör: Rev.B) *", text: $revisionNo).accessibilityLabel("Revizyon no")
                    TextEditor(text: $changeDescription).frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if changeDescription.isEmpty {
                                Text("Değişiklik açıklaması").foregroundColor(.secondary).font(.body)
                                    .padding(.leading, 4).padding(.top, 8).allowsHitTesting(false)
                            }
                        }
                }
            }
            .navigationTitle("Yeni Revizyon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(revisionNo.isEmpty)
                }
            }
        }
    }

    private func save() {
        // Archive current as revision
        let rev = DocumentRevision(revisionNo: document.revisionNo, document: document)
        rev.changeDescription = changeDescription.isEmpty ? nil : changeDescription
        rev.fileData = document.fileData
        document.previousRevisions.append(rev)
        modelContext.insert(rev)
        // Update document
        document.revisionNo = revisionNo
        document.revisionDate = Date()
        document.isCurrentRevision = true
        try? modelContext.save()
        dismiss()
    }
}
