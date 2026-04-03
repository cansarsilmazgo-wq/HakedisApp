import SwiftUI
import SwiftData

// MARK: - EmergencyPlanListView

struct EmergencyPlanListView: View {
    @Query(sort: \EmergencyPlan.createdAt, order: .reverse) private var plans: [EmergencyPlan]
    @Query private var projects: [Project]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedProjectID: UUID? = nil

    private var filtered: [EmergencyPlan] {
        plans.filter { p in selectedProjectID == nil || p.project?.id == selectedProjectID }
    }

    private var overdueDrills: Int { filtered.filter { $0.isDrillOverdue }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if overdueDrills > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisWarning)
                        Text("\(overdueDrills) planın tatbikat tarihi geçmiş").font(.caption.bold()).foregroundColor(.hakedisWarning)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisWarning.opacity(0.1))
                }

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
                        icon: "flame.fill",
                        title: "Acil durum planı yok",
                        subtitle: "Yangın, deprem ve diğer acil durum prosedürleri",
                        actionTitle: "Plan Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { plan in
                            NavigationLink(destination: EmergencyPlanDetailView(plan: plan)) {
                                EmergencyPlanRow(plan: plan)
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
            .padding(Spacing.card + 4).accessibilityLabel("Acil durum planı ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) { EmergencyPlanForm() }
    }
}

// MARK: - EmergencyPlanRow

private struct EmergencyPlanRow: View {
    let plan: EmergencyPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: plan.planType.icon).foregroundColor(.hakedisDanger)
                Text(plan.planType.rawValue).font(.subheadline.bold())
                Spacer()
                if plan.isDrillOverdue {
                    StatusBadge(text: "Tatbikat Gecikmiş", color: .hakedisWarning)
                }
            }
            Text("Toplanma Noktası: \(plan.assemblyPoint)").font(.caption).foregroundColor(.secondary)
            if let next = plan.nextDrillDate {
                Text("Sonraki Tatbikat: \(next.shortFormatted)")
                    .font(.caption2)
                    .foregroundColor(plan.isDrillOverdue ? .hakedisWarning : .secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.planType.rawValue) acil durum planı")
    }
}

// MARK: - EmergencyPlanDetailView

struct EmergencyPlanDetailView: View {
    let plan: EmergencyPlan
    @Environment(\.modelContext) private var modelContext
    @State private var showingDrill = false
    @State private var drillDate = Date()

    private var contacts: [[String: String]] {
        (try? JSONDecoder().decode([[String: String]].self, from: Data(plan.emergencyContacts.utf8))) ?? []
    }

    var body: some View {
        List {
            Section("Plan Bilgileri") {
                HStack {
                    Image(systemName: plan.planType.icon).foregroundColor(.hakedisDanger)
                    Text(plan.planType.rawValue)
                }
                LabeledContent("Toplanma Noktası", value: plan.assemblyPoint)
                if let proj = plan.project { LabeledContent("Proje", value: proj.name) }
            }

            Section("Prosedürler") {
                Text(plan.procedures).font(.body)
            }

            if !contacts.isEmpty {
                Section("Acil Durum Kişileri") {
                    ForEach(contacts.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contacts[i]["name"] ?? "").font(.subheadline.bold())
                            if let role = contacts[i]["role"] {
                                Text(role).font(.caption).foregroundColor(.secondary)
                            }
                            if let phone = contacts[i]["phone"] {
                                HStack {
                                    Image(systemName: "phone.fill").font(.caption2).foregroundColor(.hakedisOrange)
                                    Text(phone).font(.caption)
                                }
                            }
                        }
                    }
                }
            }

            Section("Tatbikat") {
                if let last = plan.lastDrillDate {
                    LabeledContent("Son Tatbikat", value: last.shortFormatted)
                }
                if let next = plan.nextDrillDate {
                    HStack {
                        Text("Sonraki Tatbikat")
                        Spacer()
                        Text(next.shortFormatted)
                            .foregroundColor(plan.isDrillOverdue ? .hakedisWarning : .primary)
                    }
                }
                if plan.isDrillOverdue {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisWarning)
                        Text("Tatbikat tarihi geçmiş").font(.caption).foregroundColor(.hakedisWarning)
                    }
                }
                Button { showingDrill = true } label: {
                    Label("Tatbikat Yapıldı", systemImage: "checkmark.circle.fill")
                }
                .foregroundColor(.hakedisSuccess)
                .accessibilityLabel("Tatbikat yapıldı olarak işaretle")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Acil Durum Planı")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDrill) {
            NavigationStack {
                Form {
                    Section("Tatbikat Tarihi") {
                        DatePicker("Yapılma Tarihi", selection: $drillDate, displayedComponents: .date)
                            .accessibilityLabel("Tatbikat tarihi")
                        DatePicker("Sonraki Tatbikat", selection: Binding(
                            get: { plan.nextDrillDate ?? Date().addingTimeInterval(365 * 86400) },
                            set: { plan.nextDrillDate = $0 }
                        ), displayedComponents: .date)
                        .accessibilityLabel("Sonraki tatbikat tarihi")
                    }
                }
                .navigationTitle("Tatbikat Kaydı")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("İptal") { showingDrill = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Kaydet") {
                            plan.lastDrillDate = drillDate
                            try? modelContext.save()
                            showingDrill = false
                        }.accessibilityLabel("Tatbikat kaydet")
                    }
                }
            }
        }
    }
}

// MARK: - EmergencyPlanForm

struct EmergencyPlanForm: View {
    var editing: EmergencyPlan? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var planType = EmergencyPlanType.fire
    @State private var procedures = ""
    @State private var assemblyPoint = ""
    @State private var nextDrillDate = Date().addingTimeInterval(90 * 86400)
    @State private var hasNextDrill = false
    @State private var selectedProject: Project? = nil

    // Basit iletişim listesi
    @State private var contactName = ""
    @State private var contactRole = ""
    @State private var contactPhone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Bilgileri") {
                    Picker("Acil Durum Türü", selection: $planType) {
                        ForEach(EmergencyPlanType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .accessibilityLabel("Acil durum türü")
                    TextField("Toplanma Noktası *", text: $assemblyPoint).accessibilityLabel("Toplanma noktası")
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                    }
                    .accessibilityLabel("Proje")
                }

                Section("Prosedürler *") {
                    TextEditor(text: $procedures).frame(minHeight: 100).accessibilityLabel("Acil durum prosedürleri")
                }

                Section("Acil İletişim (İlk Kişi)") {
                    TextField("Ad Soyad", text: $contactName).accessibilityLabel("İletişim kişi adı")
                    TextField("Görevi", text: $contactRole).accessibilityLabel("İletişim kişi görevi")
                    TextField("Telefon", text: $contactPhone).keyboardType(.phonePad).accessibilityLabel("Telefon numarası")
                }

                Section("Tatbikat") {
                    Toggle("Tatbikat tarihi belirle", isOn: $hasNextDrill).tint(.hakedisOrange)
                    if hasNextDrill {
                        DatePicker("Sonraki Tatbikat", selection: $nextDrillDate, displayedComponents: .date)
                            .accessibilityLabel("Tatbikat tarihi")
                    }
                }
            }
            .navigationTitle(editing == nil ? "Yeni Acil Durum Planı" : "Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.accessibilityLabel("İptal") }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.accessibilityLabel("Kaydet") }
            }
            .onAppear {
                if let e = editing {
                    planType = e.planType; procedures = e.procedures
                    assemblyPoint = e.assemblyPoint; selectedProject = e.project
                    if let nd = e.nextDrillDate { hasNextDrill = true; nextDrillDate = nd }
                }
            }
        }
    }

    private func save() {
        guard !assemblyPoint.isEmpty, !procedures.isEmpty else { return }
        let p = editing ?? EmergencyPlan(planType: planType, procedures: procedures, assemblyPoint: assemblyPoint)
        p.planType = planType; p.procedures = procedures; p.assemblyPoint = assemblyPoint
        p.nextDrillDate = hasNextDrill ? nextDrillDate : nil
        p.project = selectedProject

        // Encode single contact
        if !contactName.isEmpty {
            var contact: [String: String] = ["name": contactName]
            if !contactRole.isEmpty { contact["role"] = contactRole }
            if !contactPhone.isEmpty { contact["phone"] = contactPhone }
            p.emergencyContacts = (try? String(data: JSONEncoder().encode([contact]), encoding: .utf8)) ?? "[]"
        }

        if editing == nil { modelContext.insert(p) }
        try? modelContext.save()
        dismiss()
    }
}
