import SwiftUI
import SwiftData
import PhotosUI

// MARK: - IncidentType color extension
extension IncidentType {
    var uiColor: Color {
        switch self {
        case .nearMiss: return .hakedisWarning
        case .warning: return .hakedisInfo
        case .minorInjury: return .hakedisWarning
        case .majorInjury: return .hakedisDanger
        }
    }
}

// MARK: - SafetyListView
struct SafetyListView: View {
    @Query(sort: \SafetyIncident.date, order: .reverse) private var incidents: [SafetyIncident]
    @Query(sort: \SafetyChecklist.date, order: .reverse) private var checklists: [SafetyChecklist]
    @Query private var projects: [Project]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedSegment = 0
    @State private var showingAddIncident = false
    @State private var showingAddChecklist = false
    @State private var selectedProjectID: UUID? = nil

    private var filteredIncidents: [SafetyIncident] {
        incidents.filter { i in
            if let pid = selectedProjectID { return i.project?.id == pid }
            return true
        }
    }

    private var filteredChecklists: [SafetyChecklist] {
        checklists.filter { c in
            if let pid = selectedProjectID { return c.project?.id == pid }
            return true
        }
    }

    private var openIncidentCount: Int {
        incidents.filter { !$0.isResolved }.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // ISG özet kartı
                if openIncidentCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(.hakedisDanger)
                        Text("\(openIncidentCount) açık olay kaydı")
                            .font(.caption.bold())
                            .foregroundColor(.hakedisDanger)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.1))
                }

                // Project filter
                if !projects.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tümü", isSelected: selectedProjectID == nil) {
                                selectedProjectID = nil
                            }
                            ForEach(projects, id: \.id) { p in
                                FilterChip(title: p.name, isSelected: selectedProjectID == p.id) {
                                    selectedProjectID = selectedProjectID == p.id ? nil : p.id
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.card)
                        .padding(.vertical, 6)
                    }
                    .background(Color.hakedisBackground)
                }

                Picker("", selection: $selectedSegment) {
                    Text("Olaylar").tag(0)
                    Text("Denetimler").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(Spacing.card)
                .background(Color.hakedisBackground)

                if selectedSegment == 0 {
                    if filteredIncidents.isEmpty {
                        EmptyStateView(
                            icon: "shield.checkered",
                            title: "İSG olayı yok",
                            subtitle: "Olay ve uyarı kayıtları burada görünür",
                            actionTitle: "Olay Kaydet",
                            action: { showingAddIncident = true }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredIncidents, id: \.id) { incident in
                                NavigationLink(destination: SafetyIncidentDetailView(incident: incident)) {
                                    SafetyIncidentRow(incident: incident)
                                }
                            }
                            .onDelete { offsets in
                                for i in offsets { modelContext.delete(filteredIncidents[i]) }
                                do { try modelContext.save() } catch { print("Silme: \(error)") }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                } else {
                    if filteredChecklists.isEmpty {
                        EmptyStateView(
                            icon: "checklist",
                            title: "Denetim kaydı yok",
                            subtitle: "Toolbox toplantısı ve denetim notları burada görünür",
                            actionTitle: "Denetim Ekle",
                            action: { showingAddChecklist = true }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredChecklists, id: \.id) { checklist in
                                NavigationLink(destination: SafetyChecklistDetailView(checklist: checklist)) {
                                    SafetyChecklistRow(checklist: checklist)
                                }
                            }
                            .onDelete { offsets in
                                for i in offsets { modelContext.delete(filteredChecklists[i]) }
                                do { try modelContext.save() } catch { print("Silme: \(error)") }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }

            Button {
                if selectedSegment == 0 {
                    showingAddIncident = true
                } else {
                    showingAddChecklist = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel(selectedSegment == 0 ? "Yeni olay kaydet" : "Yeni denetim ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAddIncident) {
            SafetyIncidentForm()
        }
        .sheet(isPresented: $showingAddChecklist) {
            SafetyChecklistForm()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if selectedSegment == 0 { showingAddIncident = true }
                    else { showingAddChecklist = true }
                } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Yeni kayıt ekle")
            }
        }
    }
}

// MARK: - SafetyIncidentRow
private struct SafetyIncidentRow: View {
    let incident: SafetyIncident

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: incident.incidentType.icon)
                    .foregroundColor(incident.incidentType.uiColor)
                Text(incident.incidentType.rawValue)
                    .font(.subheadline.bold())
                Spacer()
                if !incident.isResolved {
                    StatusBadge(text: "Açık", color: .hakedisDanger)
                } else {
                    StatusBadge(text: "Kapatıldı", color: .hakedisSuccess)
                }
            }
            Text(String(incident.incidentDescription.prefix(60)) + (incident.incidentDescription.count > 60 ? "..." : ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            HStack {
                Text(incident.date.shortFormatted)
                    .font(.caption2).foregroundColor(.secondary)
                if let loc = incident.location {
                    Text("· \(loc)").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(incident.incidentType.rawValue), \(incident.date.shortFormatted), \(incident.isResolved ? "kapatıldı" : "açık")")
    }
}

// MARK: - SafetyChecklistRow
private struct SafetyChecklistRow: View {
    let checklist: SafetyChecklist

    var itemCount: Int {
        (try? JSONDecoder().decode([ChecklistItem].self, from: Data(checklist.items.utf8)))?.count ?? 0
    }

    var completedCount: Int {
        (try? JSONDecoder().decode([ChecklistItem].self, from: Data(checklist.items.utf8)))?.filter(\.isChecked).count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(checklist.checklistType.rawValue)
                    .font(.subheadline.bold())
                Spacer()
                if itemCount > 0 {
                    Text("\(completedCount)/\(itemCount)")
                        .font(.caption.bold())
                        .foregroundColor(completedCount == itemCount ? .hakedisSuccess : .hakedisWarning)
                }
            }
            HStack {
                Text(checklist.date.shortFormatted)
                    .font(.caption2).foregroundColor(.secondary)
                Text("· \(checklist.completedBy)")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(checklist.checklistType.rawValue), \(checklist.date.shortFormatted)")
    }
}

// MARK: - SafetyIncidentDetailView
struct SafetyIncidentDetailView: View {
    let incident: SafetyIncident
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false

    var body: some View {
        List {
            Section("Olay Bilgileri") {
                LabeledContent("Tür") {
                    HStack {
                        Image(systemName: incident.incidentType.icon)
                        Text(incident.incidentType.rawValue)
                    }
                    .foregroundColor(incident.incidentType.uiColor)
                }
                LabeledContent("Tarih", value: incident.date.shortFormatted)
                if let loc = incident.location {
                    LabeledContent("Konum", value: loc)
                }
                if let worker = incident.involvedWorker {
                    LabeledContent("İlgili İşçi", value: worker)
                }
                HStack {
                    Text("Durum")
                    Spacer()
                    StatusBadge(
                        text: incident.isResolved ? "Kapatıldı" : "Açık",
                        color: incident.isResolved ? .hakedisSuccess : .hakedisDanger
                    )
                }
            }

            Section("Olay Açıklaması") {
                Text(incident.incidentDescription)
                    .font(.body)
            }

            if let actions = incident.actionsTaken, !actions.isEmpty {
                Section("Alınan Önlemler") {
                    Text(actions).font(.body)
                }
            }

            if let measures = incident.preventiveMeasures, !measures.isEmpty {
                Section("Önleyici Tedbirler") {
                    Text(measures).font(.body)
                }
            }

            if !incident.photoData.isEmpty {
                Section("Fotoğraflar") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(incident.photoData.indices, id: \.self) { i in
                            if let uiImg = UIImage(data: incident.photoData[i]) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(incident.incidentType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Düzenle") { showingEdit = true }
                    .accessibilityLabel("Düzenle")
                if !incident.isResolved {
                    Button("Kapat") {
                        incident.isResolved = true
                        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
                    }
                    .accessibilityLabel("Olayı kapat")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            SafetyIncidentForm(editingIncident: incident)
        }
    }
}

// MARK: - SafetyIncidentForm
struct SafetyIncidentForm: View {
    var editingIncident: SafetyIncident? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var date = Date()
    @State private var incidentType = IncidentType.nearMiss
    @State private var incidentDescription = ""
    @State private var location = ""
    @State private var involvedWorker = ""
    @State private var actionsTaken = ""
    @State private var preventiveMeasures = ""
    @State private var selectedProject: Project? = nil
    @State private var isResolved = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataList: [Data] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Olay Bilgileri") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                        .accessibilityLabel("Olay tarihi")
                    Picker("Olay Türü", selection: $incidentType) {
                        ForEach(IncidentType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .accessibilityLabel("Olay türü")
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                    .accessibilityLabel("Proje")
                    TextField("Konum (opsiyonel)", text: $location)
                        .accessibilityLabel("Olay konumu")
                    TextField("İlgili işçi (opsiyonel)", text: $involvedWorker)
                        .accessibilityLabel("İlgili işçi")
                }

                Section("Olay Açıklaması *") {
                    TextEditor(text: $incidentDescription)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Olay açıklaması")
                }

                Section("Alınan Önlemler") {
                    TextEditor(text: $actionsTaken)
                        .frame(minHeight: 60)
                        .accessibilityLabel("Alınan önlemler")
                }

                Section("Önleyici Tedbirler") {
                    TextEditor(text: $preventiveMeasures)
                        .frame(minHeight: 60)
                        .accessibilityLabel("Önleyici tedbirler")
                }

                Section {
                    Toggle("Olay kapatıldı", isOn: $isResolved)
                        .accessibilityLabel("Olayı kapalı olarak işaretle")
                }

                Section("Fotoğraflar") {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                        Label("Fotoğraf Ekle", systemImage: "photo.badge.plus")
                            .accessibilityLabel("Fotoğraf ekle")
                    }
                }
            }
            .navigationTitle(editingIncident == nil ? "Olay Kaydet" : "Olayı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }.accessibilityLabel("İptal")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.accessibilityLabel("Kaydet")
                }
            }
            .onChange(of: selectedPhotos) {
                Task {
                    var loaded: [Data] = []
                    for item in selectedPhotos {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            loaded.append(data)
                        }
                    }
                    await MainActor.run { photoDataList = loaded }
                }
            }
            .onAppear {
                if let e = editingIncident {
                    date = e.date; incidentType = e.incidentType
                    incidentDescription = e.incidentDescription
                    location = e.location ?? ""; involvedWorker = e.involvedWorker ?? ""
                    actionsTaken = e.actionsTaken ?? ""; preventiveMeasures = e.preventiveMeasures ?? ""
                    selectedProject = e.project; isResolved = e.isResolved
                    photoDataList = e.photoData
                }
            }
        }
    }

    private func save() {
        guard !incidentDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let incident = editingIncident ?? SafetyIncident(incidentType: incidentType, incidentDescription: "")
        incident.date = date
        incident.incidentType = incidentType
        incident.incidentDescription = incidentDescription
        incident.location = location.isEmpty ? nil : location
        incident.involvedWorker = involvedWorker.isEmpty ? nil : involvedWorker
        incident.actionsTaken = actionsTaken.isEmpty ? nil : actionsTaken
        incident.preventiveMeasures = preventiveMeasures.isEmpty ? nil : preventiveMeasures
        incident.project = selectedProject
        incident.isResolved = isResolved
        incident.photoData = photoDataList
        if editingIncident == nil { modelContext.insert(incident) }
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}

// MARK: - SafetyChecklistDetailView
struct SafetyChecklistDetailView: View {
    let checklist: SafetyChecklist
    @Environment(\.modelContext) private var modelContext
    @State private var items: [ChecklistItem] = []

    var body: some View {
        List {
            Section("Bilgiler") {
                LabeledContent("Tür", value: checklist.checklistType.rawValue)
                LabeledContent("Tarih", value: checklist.date.shortFormatted)
                LabeledContent("Yapan", value: checklist.completedBy)
            }

            Section("Kontrol Maddeleri") {
                ForEach($items) { $item in
                    HStack {
                        Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                            .foregroundColor(item.isChecked ? .hakedisSuccess : .secondary)
                            .onTapGesture {
                                item.isChecked.toggle()
                                saveItems()
                            }
                            .accessibilityLabel(item.isChecked ? "İşaretlendi" : "İşaretlenmedi")
                        Text(item.title).font(.body)
                    }
                }
            }

            if let notes = checklist.notes, !notes.isEmpty {
                Section("Notlar") {
                    Text(notes)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(checklist.checklistType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadItems() }
    }

    private func loadItems() {
        items = (try? JSONDecoder().decode([ChecklistItem].self, from: Data(checklist.items.utf8))) ?? defaultItems()
    }

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            checklist.items = String(data: data, encoding: .utf8) ?? "[]"
            do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        }
    }

    private func defaultItems() -> [ChecklistItem] {
        switch checklist.checklistType {
        case .toolbox:
            return [
                ChecklistItem(title: "Günün tehlikeleri anlatıldı"),
                ChecklistItem(title: "KKD kontrolü yapıldı"),
                ChecklistItem(title: "Acil çıkış yolları gösterildi"),
                ChecklistItem(title: "Ekip bilgilendirildi")
            ]
        case .ppe:
            return [
                ChecklistItem(title: "Baret kontrolü"),
                ChecklistItem(title: "Güvenlik yeleği"),
                ChecklistItem(title: "Güvenlik ayakkabısı"),
                ChecklistItem(title: "Gözlük (gerekiyorsa)"),
                ChecklistItem(title: "Eldiven (gerekiyorsa)")
            ]
        case .dailyInspection:
            return [
                ChecklistItem(title: "Sahada düzen sağlandı"),
                ChecklistItem(title: "Tehlikeli bölgeler işaretlendi"),
                ChecklistItem(title: "Yangın söndürücüler kontrol edildi"),
                ChecklistItem(title: "İlk yardım dolabı tam")
            ]
        case .scaffolding:
            return [
                ChecklistItem(title: "İskele tabanı sağlam"),
                ChecklistItem(title: "Korkuluklar mevcut"),
                ChecklistItem(title: "Bağlantı elemanları kontrol edildi"),
                ChecklistItem(title: "Aşırı yükleme yok")
            ]
        case .excavation:
            return [
                ChecklistItem(title: "Kazı şevleri güvenli"),
                ChecklistItem(title: "Bariyerler ve uyarı bantları mevcut"),
                ChecklistItem(title: "Drenaj sağlanmış"),
                ChecklistItem(title: "Yeraltı hatları kontrol edildi")
            ]
        }
    }
}

// MARK: - SafetyChecklistForm
struct SafetyChecklistForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var date = Date()
    @State private var checklistType = ChecklistType.toolbox
    @State private var completedBy = ""
    @State private var notes = ""
    @State private var selectedProject: Project? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Denetim Bilgileri") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                        .accessibilityLabel("Denetim tarihi")
                    Picker("Tür", selection: $checklistType) {
                        ForEach(ChecklistType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .accessibilityLabel("Denetim türü")
                    TextField("Yapan kişi *", text: $completedBy)
                        .accessibilityLabel("Denetimi yapan kişi")
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                    .accessibilityLabel("Proje")
                }
                Section("Notlar") {
                    TextField("Not (opsiyonel)", text: $notes)
                        .accessibilityLabel("Not")
                }
            }
            .navigationTitle("Yeni Denetim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }.accessibilityLabel("İptal")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.accessibilityLabel("Kaydet")
                }
            }
        }
    }

    private func save() {
        guard !completedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let cl = SafetyChecklist(date: date, checklistType: checklistType, completedBy: completedBy)
        cl.notes = notes.isEmpty ? nil : notes
        cl.project = selectedProject
        modelContext.insert(cl)
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
