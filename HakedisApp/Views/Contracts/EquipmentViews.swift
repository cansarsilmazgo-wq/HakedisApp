import SwiftUI
import SwiftData

// MARK: - Ekipman Takibi

struct EquipmentSection: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    private var maintenanceDueCount: Int {
        contract.equipments.filter { $0.isMaintenanceDue }.count
    }
    private var muayeneDueCount: Int {
        contract.equipments.filter { $0.isMuayeneDue }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Ekipman Takibi")

            if !contract.equipments.isEmpty {
                if maintenanceDueCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.hakedisWarning)
                        Text("\(maintenanceDueCount) ekipman bakım bekliyor")
                            .font(.caption.bold())
                            .foregroundColor(.hakedisWarning)
                    }
                    .padding(10)
                    .background(Color.hakedisWarning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if muayeneDueCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(.hakedisDanger)
                        Text("\(muayeneDueCount) ekipman periyodik muayene süresi doldu")
                            .font(.caption.bold())
                            .foregroundColor(.hakedisDanger)
                    }
                    .padding(10)
                    .background(Color.hakedisDanger.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                ForEach(contract.equipments.sorted { $0.name < $1.name }) { equipment in
                    EquipmentRow(equipment: equipment)
                        .contextMenu {
                            Button(role: .destructive) {
                                contract.equipments.removeAll { $0.id == equipment.id }
                                context.delete(equipment)
                            } label: { Label("Sil", systemImage: "trash") }
                        }
                }
            } else {
                EmptyStateView(
                    icon: "truck.box.fill",
                    title: "Ekipman Yok",
                    subtitle: "Henüz ekipman kaydı bulunmuyor."
                )
            }

            Button {
                showAdd = true
            } label: {
                Label("Ekipman Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEquipmentView(contract: contract)
        }
    }
}

struct EquipmentRow: View {
    let equipment: Equipment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(equipment.name).font(.subheadline.bold())
                    Text(equipment.equipmentType).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(
                    text: equipment.status.rawValue,
                    color: equipment.status == .aktif ? .hakedisSuccess :
                           equipment.status == .bakim ? .hakedisWarning : .hakedisDanger
                )
            }
            HStack(spacing: 16) {
                Label("\(equipment.totalUsageDays) gün", systemImage: "calendar")
                    .font(.caption)
                Label(equipment.totalRentalCost.currencyFormatted, systemImage: "banknote")
                    .font(.caption)
                if equipment.isMaintenanceDue {
                    Label("Bakım Gerekli", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.hakedisWarning)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AddEquipmentView: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var plateOrSerial = ""
    @State private var equipmentType = ""
    @State private var dailyRentalCost = ""
    @State private var maintenancePeriodDays = "90"

    var body: some View {
        NavigationStack {
            Form {
                Section("Ekipman Bilgisi") {
                    TextField("Ekipman Adı", text: $name)
                    TextField("Plaka / Seri No", text: $plateOrSerial)
                    TextField("Tür (Ör: Vinç, Beton Mikseri)", text: $equipmentType)
                }
                Section("Maliyet") {
                    TextField("Günlük Kiralama (₺)", text: $dailyRentalCost).keyboardType(.decimalPad)
                }
                Section("Bakım") {
                    TextField("Bakım Periyodu (gün)", text: $maintenancePeriodDays).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Ekipman Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let rental = Double(dailyRentalCost) ?? 0
        let period = Int(maintenancePeriodDays) ?? 90
        let equipment = Equipment(
            name: name,
            plateOrSerial: plateOrSerial,
            equipmentType: equipmentType,
            dailyRentalCost: rental,
            maintenancePeriodDays: period
        )
        equipment.contract = contract
        context.insert(equipment)
        contract.equipments.append(equipment)
        dismiss()
    }
}
