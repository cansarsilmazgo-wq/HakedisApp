import SwiftUI
import SwiftData

// MARK: - PPEAssignmentListView

struct PPEAssignmentListView: View {
    @Query(sort: \PPEAssignment.assignedDate, order: .reverse) private var assignments: [PPEAssignment]
    @Query private var projects: [Project]
    @Query private var workers: [Worker]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedProjectID: UUID? = nil
    @State private var showOnlyDamaged = false

    private var filtered: [PPEAssignment] {
        assignments.filter { a in
            let projectMatch = selectedProjectID == nil || a.project?.id == selectedProjectID
            let damageMatch = !showOnlyDamaged || a.condition == .damaged || a.condition == .worn
            return projectMatch && damageMatch
        }
    }

    private var damagedCount: Int { assignments.filter { $0.condition == .damaged }.count }
    private var activeCount: Int { assignments.filter { $0.returnDate == nil }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Özet
                HStack(spacing: 0) {
                    StatCard(title: "Zimmetli", value: "\(activeCount)", color: .hakedisOrange, icon: "shippingbox.fill")
                    StatCard(title: "Hasarlı", value: "\(damagedCount)", color: .hakedisDanger, icon: "exclamationmark.triangle.fill")
                    StatCard(title: "Toplam", value: "\(assignments.count)", color: .hakedisInfo, icon: "list.bullet")
                }
                .padding(Spacing.card).background(Color.hakedisCard)

                HStack {
                    if !projects.isEmpty {
                        Menu {
                            Button("Tümü") { selectedProjectID = nil }
                            ForEach(projects, id: \.id) { p in
                                Button(p.name) { selectedProjectID = p.id }
                            }
                        } label: {
                            Label(projects.first(where: { $0.id == selectedProjectID })?.name ?? "Tüm Projeler", systemImage: "building.2")
                                .font(.caption)
                        }
                    }
                    Spacer()
                    Toggle("Hasarlı", isOn: $showOnlyDamaged)
                        .toggleStyle(.button).tint(.hakedisDanger).font(.caption)
                        .accessibilityLabel("Sadece hasarlı KKD")
                }
                .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                .background(Color.hakedisBackground)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "shield.lefthalf.filled",
                        title: "KKD zimmet kaydı yok",
                        subtitle: "Kişisel Koruyucu Donanım zimmet ve takip",
                        actionTitle: "KKD Zimmetle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { assignment in
                            NavigationLink(destination: PPEAssignmentDetailView(assignment: assignment)) {
                                PPEAssignmentRow(assignment: assignment)
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
            .padding(Spacing.card + 4).accessibilityLabel("KKD zimmetle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) { PPEAssignmentForm(allWorkers: workers) }
    }
}

// MARK: - PPEAssignmentRow

private struct PPEAssignmentRow: View {
    let assignment: PPEAssignment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: assignment.ppeType.icon).foregroundColor(.hakedisOrange)
                Text(assignment.ppeType.rawValue).font(.subheadline.bold())
                Spacer()
                PPEConditionBadge(condition: assignment.condition)
            }
            HStack {
                Image(systemName: "person.fill").font(.caption2).foregroundColor(.secondary)
                Text(assignment.worker?.fullName ?? "Atanmadı").font(.caption).foregroundColor(.secondary)
                Spacer()
                if let ret = assignment.returnDate {
                    Text("İade: \(ret.shortFormatted)").font(.caption2).foregroundColor(.hakedisSuccess)
                } else {
                    Text("Zimmet: \(assignment.assignedDate.shortFormatted)").font(.caption2).foregroundColor(.secondary)
                }
            }
            if let sn = assignment.serialNo {
                Text("Seri No: \(sn)").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.ppeType.rawValue), \(assignment.worker?.fullName ?? "atanmadı")")
    }
}

private struct PPEConditionBadge: View {
    let condition: PPECondition

    var body: some View {
        Text(condition.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(conditionColor.opacity(0.15))
            .foregroundColor(conditionColor)
            .cornerRadius(6)
    }

    private var conditionColor: Color {
        switch condition {
        case .newPPE: return .hakedisSuccess
        case .good: return .hakedisInfo
        case .worn: return .hakedisWarning
        case .damaged: return .hakedisDanger
        case .returned: return .secondary
        }
    }
}

// MARK: - PPEAssignmentDetailView

struct PPEAssignmentDetailView: View {
    let assignment: PPEAssignment
    @Environment(\.modelContext) private var modelContext
    @State private var showingReturn = false

    var body: some View {
        List {
            Section("KKD Bilgileri") {
                HStack {
                    Image(systemName: assignment.ppeType.icon).foregroundColor(.hakedisOrange)
                    Text(assignment.ppeType.rawValue).font(.body)
                }
                LabeledContent("Durum") { PPEConditionBadge(condition: assignment.condition) }
                if let sn = assignment.serialNo { LabeledContent("Seri No", value: sn) }
            }
            Section("Zimmet") {
                LabeledContent("Zimmetlenen", value: assignment.worker?.fullName ?? "Belirtilmemiş")
                LabeledContent("Zimmet Tarihi", value: assignment.assignedDate.shortFormatted)
                if let proj = assignment.project { LabeledContent("Proje", value: proj.name) }
            }
            if let ret = assignment.returnDate {
                Section("İade") { LabeledContent("İade Tarihi", value: ret.shortFormatted) }
            } else {
                Section("İşlem") {
                    Button {
                        showingReturn = true
                    } label: {
                        Label("KKD İade Al", systemImage: "arrow.uturn.backward.circle.fill")
                    }
                    .foregroundColor(.hakedisOrange)
                    .accessibilityLabel("KKD iade al")

                    if assignment.condition == .damaged || assignment.condition == .worn {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                            Text("Değiştirme önerilir").font(.caption).foregroundColor(.hakedisDanger)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("KKD Zimmet")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("KKD İade", isPresented: $showingReturn, titleVisibility: .visible) {
            Button("İade Edildi (İyi Durumda)") {
                assignment.returnDate = Date(); assignment.condition = .returned
                try? modelContext.save()
            }
            Button("İade Edildi (Hasarlı)") {
                assignment.returnDate = Date(); assignment.condition = .damaged
                try? modelContext.save()
            }
            Button("İptal", role: .cancel) {}
        }
    }
}

// MARK: - PPEAssignmentForm

struct PPEAssignmentForm: View {
    let allWorkers: [Worker]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var ppeType = PPEType.hardHat
    @State private var condition = PPECondition.newPPE
    @State private var assignedDate = Date()
    @State private var serialNo = ""
    @State private var selectedWorker: Worker? = nil
    @State private var selectedProject: Project? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("KKD Bilgileri") {
                    Picker("KKD Türü", selection: $ppeType) {
                        ForEach(PPEType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .accessibilityLabel("KKD türü")
                    Picker("Durum", selection: $condition) {
                        ForEach(PPECondition.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .accessibilityLabel("KKD durumu")
                    TextField("Seri No (opsiyonel)", text: $serialNo).accessibilityLabel("Seri numarası")
                }
                Section("Zimmet Bilgileri") {
                    DatePicker("Zimmet Tarihi", selection: $assignedDate, displayedComponents: .date).accessibilityLabel("Zimmet tarihi")
                    if allWorkers.isEmpty {
                        Text("İşçi kaydı bulunamadı").foregroundColor(.secondary).font(.caption)
                    } else {
                        Picker("İşçi", selection: $selectedWorker) {
                            Text("Seçilmedi").tag(Optional<Worker>.none)
                            ForEach(allWorkers, id: \.id) { w in Text(w.fullName).tag(Optional(w)) }
                        }
                        .accessibilityLabel("İşçi")
                    }
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                    }
                    .accessibilityLabel("Proje")
                }
            }
            .navigationTitle("KKD Zimmet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.accessibilityLabel("İptal") }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.accessibilityLabel("Kaydet") }
            }
        }
    }

    private func save() {
        let a = PPEAssignment(ppeType: ppeType, assignedDate: assignedDate)
        a.condition = condition
        a.serialNo = serialNo.isEmpty ? nil : serialNo
        a.worker = selectedWorker
        a.project = selectedProject
        modelContext.insert(a)
        try? modelContext.save()
        dismiss()
    }
}
