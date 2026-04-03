import SwiftUI
import SwiftData

// MARK: - MaintenancePlanListView
struct MaintenancePlanListView: View {
    @Query(sort: \MaintenancePlan.maintenanceTypeRaw) private var plans: [MaintenancePlan]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false

    private var duePlans: [MaintenancePlan] {
        plans.filter { plan in
            guard let eq = plan.equipment else { return false }
            return plan.isDue(currentHours: eq.totalOperatingHours)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if !duePlans.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill").foregroundColor(.hakedisWarning)
                        Text("\(duePlans.count) bakım zamanı geldi!")
                            .font(.caption.bold()).foregroundColor(.hakedisWarning)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisWarning.opacity(0.1))
                }

                if plans.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.checkmark",
                        title: "Bakım planı yok",
                        subtitle: "Ekipman bakım planları oluşturun",
                        actionTitle: "Plan Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(plans, id: \.id) { plan in
                            MaintenancePlanRow(plan: plan, modelContext: modelContext)
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(plans[i]) }
                            do { try modelContext.save() } catch { print("Silme: \(error)") }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Bakım planı ekle")
        }
        .sheet(isPresented: $showingAdd) { AddMaintenancePlanView() }
    }
}

// MARK: - MaintenancePlanRow
private struct MaintenancePlanRow: View {
    @Bindable var plan: MaintenancePlan
    let modelContext: ModelContext

    var isDue: Bool {
        guard let eq = plan.equipment else { return false }
        return plan.isDue(currentHours: eq.totalOperatingHours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: plan.maintenanceType.icon)
                    .foregroundColor(isDue ? .hakedisWarning : .hakedisOrange)
                Text(plan.maintenanceType.rawValue).font(.subheadline.bold())
                Spacer()
                if isDue {
                    StatusBadge(text: "Bakım Zamanı!", color: .hakedisWarning)
                }
            }
            if let eq = plan.equipment {
                Text(eq.name).font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 16) {
                if let last = plan.lastMaintenanceDate {
                    Text("Son: \(last.shortFormatted)").font(.caption2).foregroundColor(.secondary)
                }
                if let next = plan.nextDueHours {
                    Text("Sonraki: \(String(format: "%.0f", next)) saat").font(.caption2).foregroundColor(.secondary)
                }
                Text("Her \(String(format: "%.0f", plan.intervalHours)) saatte bir")
                    .font(.caption2).foregroundColor(.secondary)
            }
            if isDue {
                Button {
                    plan.lastMaintenanceDate = Date()
                    plan.lastMaintenanceHours = plan.equipment?.totalOperatingHours
                    if let last = plan.lastMaintenanceHours {
                        plan.nextDueHours = last + plan.intervalHours
                    }
                    do { try modelContext.save() } catch { print("Kayıt: \(error)") }
                } label: {
                    Label("Bakım Yapıldı", systemImage: "checkmark.circle")
                        .font(.caption.bold())
                        .foregroundColor(.hakedisSuccess)
                }
                .accessibilityLabel("Bakım yapıldı olarak işaretle")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.maintenanceType.rawValue), \(isDue ? "bakım zamanı" : "normal")")
    }
}

// MARK: - AddMaintenancePlanView
struct AddMaintenancePlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EquipmentItem.name) private var equipment: [EquipmentItem]

    @State private var maintenanceType: MaintenanceType = .oilChange
    @State private var intervalHours = "250"
    @State private var selectedEquipment: EquipmentItem? = nil
    @State private var lastMaintenanceHours = ""
    @State private var estimatedCost = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Bakım Türü") {
                    Picker("Bakım Türü", selection: $maintenanceType) {
                        ForEach(MaintenanceType.allCases, id: \.rawValue) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .accessibilityLabel("Bakım türü")
                    Picker("Ekipman", selection: $selectedEquipment) {
                        Text("Seçilmedi").tag(Optional<EquipmentItem>.none)
                        ForEach(equipment, id: \.id) { e in Text(e.name).tag(Optional(e)) }
                    }
                }
                Section("Interval & Maliyet") {
                    TextField("Her kaç saatte bir", text: $intervalHours)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Bakım aralığı (saat)")
                    TextField("Son Bakımdaki Saat (opsiyonel)", text: $lastMaintenanceHours)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Son bakımdaki saat sayacı")
                    TextField("Tahmini Maliyet (₺)", text: $estimatedCost)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Tahmini maliyet")
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                        .accessibilityLabel("Notlar")
                }
            }
            .navigationTitle("Bakım Planı Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        let interval = Double(intervalHours.replacingOccurrences(of: ",", with: ".")) ?? 250
        let plan = MaintenancePlan(maintenanceType: maintenanceType, intervalHours: interval)
        plan.equipment = selectedEquipment
        if let lastHrs = Double(lastMaintenanceHours.replacingOccurrences(of: ",", with: ".")) {
            plan.lastMaintenanceHours = lastHrs
            plan.nextDueHours = lastHrs + interval
            plan.lastMaintenanceDate = Date()
        } else if let eq = selectedEquipment {
            plan.nextDueHours = eq.totalOperatingHours + interval
        }
        plan.estimatedCost = Double(estimatedCost.replacingOccurrences(of: ",", with: "."))
        plan.notes = notes.isEmpty ? nil : notes
        modelContext.insert(plan)
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
