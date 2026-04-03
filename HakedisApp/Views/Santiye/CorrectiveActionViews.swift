import SwiftUI
import SwiftData

// MARK: - CorrectiveActionListView

struct CorrectiveActionListView: View {
    @Query(sort: \CorrectiveAction.dueDate) private var actions: [CorrectiveAction]
    @Query private var projects: [Project]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedStatus: CorrectiveActionStatus? = nil
    @State private var selectedProjectID: UUID? = nil

    private var filtered: [CorrectiveAction] {
        actions.filter { a in
            let statusMatch = selectedStatus == nil || a.status == selectedStatus!
            let projectMatch = selectedProjectID == nil || a.project?.id == selectedProjectID
            return statusMatch && projectMatch
        }
    }

    private var overdueCount: Int { actions.filter { $0.isOverdue }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if overdueCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.hakedisDanger)
                        Text("\(overdueCount) gecikmiş düzeltici faaliyet").font(.caption.bold()).foregroundColor(.hakedisDanger)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.08))
                }

                // Status filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: selectedStatus == nil) { selectedStatus = nil }
                        ForEach(CorrectiveActionStatus.allCases, id: \.self) { s in
                            FilterChip(title: s.rawValue, isSelected: selectedStatus == s) {
                                selectedStatus = selectedStatus == s ? nil : s
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                }
                .background(Color.hakedisBackground)

                if !projects.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tümü", isSelected: selectedProjectID == nil) { selectedProjectID = nil }
                            ForEach(projects, id: \.id) { p in
                                FilterChip(title: p.name, isSelected: selectedProjectID == p.id) {
                                    selectedProjectID = selectedProjectID == p.id ? nil : p.id
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                    }
                    .background(Color.hakedisBackground)
                }

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "Düzeltici faaliyet yok",
                        subtitle: "İSG olaylarına bağlı düzeltici faaliyetler",
                        actionTitle: "Faaliyet Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { action in
                            NavigationLink(destination: CorrectiveActionDetailView(action: action)) {
                                CorrectiveActionRow(action: action)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(Color.hakedisOrange).clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4).accessibilityLabel("Düzeltici faaliyet ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) { CorrectiveActionForm() }
    }
}

// MARK: - CorrectiveActionRow

private struct CorrectiveActionRow: View {
    let action: CorrectiveAction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: action.status.icon).foregroundColor(statusColor)
                Text(action.actionChangeDescription).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                StatusBadge(text: action.status.rawValue, color: statusColor)
            }
            HStack {
                Text(action.responsiblePerson).font(.caption).foregroundColor(.secondary)
                Spacer()
                if action.isOverdue {
                    Image(systemName: "clock.badge.exclamationmark.fill").foregroundColor(.hakedisDanger).font(.caption)
                    Text("Gecikmiş").font(.caption2).foregroundColor(.hakedisDanger)
                } else {
                    Text("Termin: \(action.dueDate.shortFormatted)").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action.actionChangeDescription), \(action.status.rawValue)")
    }

    private var statusColor: Color {
        if action.isOverdue { return .hakedisDanger }
        switch action.status {
        case .open: return .hakedisWarning
        case .inProgress: return .hakedisInfo
        case .completed: return .hakedisSuccess
        case .overdue: return .hakedisDanger
        case .verified: return .hakedisSuccess
        }
    }
}

// MARK: - CorrectiveActionDetailView

struct CorrectiveActionDetailView: View {
    let action: CorrectiveAction
    @Environment(\.modelContext) private var modelContext
    @State private var showingVerify = false
    @State private var verifiedBy = ""
    @State private var verificationNotes = ""

    var body: some View {
        List {
            Section("Faaliyet Bilgileri") {
                LabeledContent("Açıklama") { Text(action.actionChangeDescription).multilineTextAlignment(.trailing) }
                LabeledContent("Sorumlu", value: action.responsiblePerson)
                LabeledContent("Atama Tarihi", value: action.assignedDate.shortFormatted)
                LabeledContent("Termin", value: action.dueDate.shortFormatted)
                HStack {
                    Text("Durum")
                    Spacer()
                    Image(systemName: action.status.icon)
                    Text(action.status.rawValue)
                }
                if action.isOverdue {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.hakedisDanger)
                        Text("Termin tarihi geçti").font(.caption).foregroundColor(.hakedisDanger)
                    }
                }
            }

            if let completedAt = action.completionDate {
                Section("Tamamlanma") { LabeledContent("Tarih", value: completedAt.shortFormatted) }
            }

            if action.status == .verified, let verifiedBy = action.verifiedBy {
                Section("Doğrulama") {
                    LabeledContent("Doğrulayan", value: verifiedBy)
                    if let vd = action.verificationDate { LabeledContent("Tarih", value: vd.shortFormatted) }
                    if let notes = action.verificationNotes, !notes.isEmpty { Text(notes).font(.caption).foregroundColor(.secondary) }
                }
            }

            // Durum geçiş butonları
            Section("İşlemler") {
                if action.status == .open || action.status == .overdue {
                    Button {
                        action.status = .inProgress
                        try? modelContext.save()
                    } label: { Label("Devam Ediyor Yap", systemImage: "circle.lefthalf.filled") }
                    .accessibilityLabel("Devam ediyor yap")
                }
                if action.status == .inProgress {
                    Button {
                        action.status = .completed
                        action.completionDate = Date()
                        try? modelContext.save()
                    } label: { Label("Tamamlandı Yap", systemImage: "checkmark.circle") }.foregroundColor(.hakedisSuccess)
                    .accessibilityLabel("Tamamlandı yap")
                }
                if action.status == .completed {
                    Button { showingVerify = true } label: { Label("Doğrula", systemImage: "checkmark.seal.fill") }
                        .foregroundColor(.hakedisSuccess).accessibilityLabel("Faaliyeti doğrula")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Düzeltici Faaliyet")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingVerify) {
            NavigationStack {
                Form {
                    Section("Doğrulama Bilgileri") {
                        TextField("Doğrulayan kişi *", text: $verifiedBy).accessibilityLabel("Doğrulayan")
                        TextField("Notlar (opsiyonel)", text: $verificationNotes).accessibilityLabel("Doğrulama notu")
                    }
                }
                .navigationTitle("Doğrulama")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("İptal") { showingVerify = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Onayla") {
                            guard !verifiedBy.isEmpty else { return }
                            action.status = .verified
                            action.verifiedBy = verifiedBy
                            action.verificationDate = Date()
                            action.verificationNotes = verificationNotes.isEmpty ? nil : verificationNotes
                            try? modelContext.save()
                            showingVerify = false
                        }.accessibilityLabel("Onayla")
                    }
                }
            }
        }
    }
}

// MARK: - CorrectiveActionForm

struct CorrectiveActionForm: View {
    var incident: SafetyIncident? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var actionDesc = ""
    @State private var responsiblePerson = ""
    @State private var dueDate = Date().addingTimeInterval(7 * 86400)
    @State private var selectedProject: Project? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Faaliyet Bilgileri") {
                    TextEditor(text: $actionDesc).frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if actionDesc.isEmpty {
                                Text("Yapılacak düzeltici faaliyet *").foregroundColor(.secondary).font(.body).padding(.leading, 4).padding(.top, 8).allowsHitTesting(false)
                            }
                        }
                    TextField("Sorumlu kişi *", text: $responsiblePerson).accessibilityLabel("Sorumlu kişi")
                    DatePicker("Termin Tarihi", selection: $dueDate, displayedComponents: .date).accessibilityLabel("Termin tarihi")
                    if incident == nil {
                        Picker("Proje", selection: $selectedProject) {
                            Text("Seçilmedi").tag(Optional<Project>.none)
                            ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                        }
                        .accessibilityLabel("Proje")
                    }
                }
            }
            .navigationTitle("Düzeltici Faaliyet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.accessibilityLabel("İptal") }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.accessibilityLabel("Kaydet") }
            }
        }
    }

    private func save() {
        guard !actionDesc.isEmpty, !responsiblePerson.isEmpty else { return }
        let ca = CorrectiveAction(actionChangeDescription: actionDesc, responsiblePerson: responsiblePerson, dueDate: dueDate)
        ca.incident = incident
        ca.project = incident?.project ?? selectedProject
        modelContext.insert(ca)
        if let inc = incident { inc.correctiveActions.append(ca) }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - RootCauseAnalysisView

struct RootCauseAnalysisView: View {
    let incident: SafetyIncident
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var editing: RootCauseAnalysis? = nil

    var body: some View {
        Group {
            if let rca = incident.rootCauseAnalysis {
                List {
                    Section("5 Neden Analizi") {
                        WhyRow(number: 1, text: rca.why1)
                        if let w2 = rca.why2 { WhyRow(number: 2, text: w2) }
                        if let w3 = rca.why3 { WhyRow(number: 3, text: w3) }
                        if let w4 = rca.why4 { WhyRow(number: 4, text: w4) }
                        if let w5 = rca.why5 { WhyRow(number: 5, text: w5) }
                    }
                    Section("Kök Neden") {
                        HStack(alignment: .top) {
                            Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.hakedisDanger)
                            Text(rca.rootCause).font(.body.bold())
                        }
                    }
                    Section {
                        Button("Düzenle") { editing = rca }
                            .accessibilityLabel("Kök neden analizi düzenle")
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("5 Neden Analizi Yok").font(.headline)
                    Text("Olayın kök nedenini bulmak için 5 Neden yöntemini uygulayın").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    Button("Analiz Başlat") { showingAdd = true }
                        .buttonStyle(.borderedProminent).tint(.hakedisOrange)
                        .accessibilityLabel("5 Neden analizi başlat")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Kök Neden Analizi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) { RCAForm(incident: incident) }
        .sheet(item: $editing) { rca in RCAForm(incident: incident, editing: rca) }
    }
}

private struct WhyRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text("Neden \(number)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.hakedisOrange)
                    .cornerRadius(6)
                if number < 5 {
                    Rectangle().fill(Color.hakedisOrange.opacity(0.3)).frame(width: 2, height: 16)
                }
            }
            Text(text).font(.body).padding(.top, 4)
        }
        .padding(.vertical, 2)
    }
}

private struct RCAForm: View {
    let incident: SafetyIncident
    var editing: RootCauseAnalysis? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var why1 = ""
    @State private var why2 = ""
    @State private var why3 = ""
    @State private var why4 = ""
    @State private var why5 = ""
    @State private var rootCause = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("5 Neden") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neden 1 *").font(.caption.bold()).foregroundColor(.hakedisOrange)
                        TextEditor(text: $why1).frame(minHeight: 60).accessibilityLabel("Birinci neden")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neden 2").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $why2).frame(minHeight: 60).accessibilityLabel("İkinci neden")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neden 3").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $why3).frame(minHeight: 60).accessibilityLabel("Üçüncü neden")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neden 4").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $why4).frame(minHeight: 60).accessibilityLabel("Dördüncü neden")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neden 5").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $why5).frame(minHeight: 60).accessibilityLabel("Beşinci neden")
                    }
                }
                Section("Kök Neden *") {
                    TextEditor(text: $rootCause).frame(minHeight: 80).accessibilityLabel("Kök neden")
                }
            }
            .navigationTitle("5 Neden Analizi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.accessibilityLabel("İptal") }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.accessibilityLabel("Kaydet") }
            }
            .onAppear {
                if let e = editing {
                    why1 = e.why1; why2 = e.why2 ?? ""; why3 = e.why3 ?? ""
                    why4 = e.why4 ?? ""; why5 = e.why5 ?? ""; rootCause = e.rootCause
                }
            }
        }
    }

    private func save() {
        guard !why1.isEmpty, !rootCause.isEmpty else { return }
        let rca = editing ?? RootCauseAnalysis(why1: why1, rootCause: rootCause)
        rca.why1 = why1
        rca.why2 = why2.isEmpty ? nil : why2
        rca.why3 = why3.isEmpty ? nil : why3
        rca.why4 = why4.isEmpty ? nil : why4
        rca.why5 = why5.isEmpty ? nil : why5
        rca.rootCause = rootCause
        rca.incident = incident
        if editing == nil {
            modelContext.insert(rca)
            incident.rootCauseAnalysis = rca
        }
        try? modelContext.save()
        dismiss()
    }
}
