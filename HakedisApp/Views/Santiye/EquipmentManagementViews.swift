import SwiftUI
import SwiftData

// MARK: - EquipmentSubTabView
struct EquipmentSubTabView: View {
    @State private var selectedTab = 0
    private let tabs = ["Ekipmanlar", "Arızalar", "Bakım", "Kiralık", "Analiz"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button {
                            selectedTab = i
                        } label: {
                            Text(tabs[i])
                                .font(.subheadline.weight(selectedTab == i ? .semibold : .regular))
                                .foregroundColor(selectedTab == i ? .hakedisOrange : .secondary)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .overlay(
                                    Rectangle().frame(height: 2)
                                        .foregroundColor(selectedTab == i ? .hakedisOrange : .clear),
                                    alignment: .bottom
                                )
                        }
                        .accessibilityLabel(tabs[i])
                        .accessibilityAddTraits(selectedTab == i ? .isSelected : [])
                    }
                }
            }
            .background(Color.hakedisCard)
            Divider()
            ZStack {
                switch selectedTab {
                case 0: EquipmentManagementListView()
                case 1: EquipmentFailureListView()
                case 2: MaintenancePlanListView()
                case 3: RentalContractListView()
                case 4: EquipmentCostAnalysisView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.hakedisBackground)
    }
}

// MARK: - EquipmentManagementListView
struct EquipmentManagementListView: View {
    @Query(sort: \EquipmentItem.name) private var items: [EquipmentItem]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var searchText = ""

    private var filtered: [EquipmentItem] {
        items.filter { e in
            searchText.isEmpty || e.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var maintenanceDueCount: Int {
        items.filter { $0.isMaintenanceDue }.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if maintenanceDueCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.hakedisWarning)
                        Text("\(maintenanceDueCount) ekipman bakım gerektiriyor")
                            .font(.caption.bold())
                            .foregroundColor(.hakedisWarning)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, 8)
                    .background(Color.hakedisWarning.opacity(0.1))
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Ekipman ara...", text: $searchText)
                        .accessibilityLabel("Ekipman ara")
                }
                .padding(10)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(Spacing.card)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "wrench.adjustable",
                        title: "Ekipman kaydı yok",
                        subtitle: "İnşaat ekipmanlarını takip etmek için ekleyin",
                        actionTitle: "Ekipman Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { item in
                            NavigationLink(destination: EquipmentDetailView(item: item)) {
                                EquipmentItemRow(item: item)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            do { try modelContext.save() } catch { print("Silme: \(error)") }
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
            .accessibilityLabel("Yeni ekipman ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) {
            AddEquipmentItemView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Yeni ekipman")
            }
        }
    }
}

// MARK: - EquipmentItemRow
private struct EquipmentItemRow: View {
    let item: EquipmentItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .font(.subheadline.bold())
                Spacer()
                if item.isMaintenanceDue {
                    StatusBadge(text: "Bakım Gerekiyor", color: .hakedisWarning)
                } else {
                    StatusBadge(text: item.ownershipType.rawValue,
                                color: item.ownershipType == .owned ? .hakedisSuccess : .hakedisInfo)
                }
            }
            HStack(spacing: 8) {
                if let plate = item.plateNumber {
                    Text(plate).font(.caption).foregroundColor(.secondary)
                }
                if let brand = item.brand, let model = item.modelName {
                    Text("\(brand) \(model)").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(String(format: "%.0f", item.totalOperatingHours))s")
                    .font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                if item.ownershipType == .rented && item.dailyRentalCost > 0 {
                    Text("Kira: \(item.dailyRentalCost.currencyFormatted)/gün")
                        .font(.caption2).foregroundColor(.hakedisOrange)
                }
                if item.hasOpenFailure {
                    Text("Arıza!").font(.caption2.bold()).foregroundColor(.hakedisDanger)
                }
                if item.isInsuranceExpiringSoon {
                    Text("Sigorta!").font(.caption2.bold()).foregroundColor(.hakedisWarning)
                }
                if item.isInspectionExpiringSoon {
                    Text("Muayene!").font(.caption2.bold()).foregroundColor(.hakedisWarning)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.ownershipType.rawValue), \(String(format: "%.0f", item.totalOperatingHours)) saat")
    }
}

// MARK: - EquipmentDetailView
struct EquipmentDetailView: View {
    let item: EquipmentItem
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddLog = false

    private var sortedLogs: [EquipmentLog] {
        item.logs.sorted { $0.date > $1.date }
    }

    private var monthlyFuelCost: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        return item.logs
            .filter { $0.date >= startOfMonth }
            .reduce(0) { $0 + ($1.fuelCost ?? 0) }
    }

    var body: some View {
        List {
            Section("Ekipman Bilgileri") {
                if let plate = item.plateNumber { LabeledContent("Plaka", value: plate) }
                LabeledContent("Sahiplik", value: item.ownershipType.rawValue)
                if let brand = item.brand { LabeledContent("Marka", value: brand) }
                if let model = item.modelName { LabeledContent("Model", value: model) }
                if let year = item.yearOfManufacture { LabeledContent("Yıl", value: "\(year)") }
                if let hp = item.enginePower { LabeledContent("Motor Gücü", value: "\(String(format: "%.0f", hp)) HP") }
                if let cap = item.capacity { LabeledContent("Kapasite", value: cap) }
                if let fuel = item.fuelType { LabeledContent("Yakıt", value: fuel) }
                if item.ownershipType == .rented {
                    LabeledContent("Günlük Kira", value: item.dailyRentalCost.currencyFormatted)
                }
            }
            Section("Belgeler") {
                if let insDate = item.insuranceExpiryDate {
                    HStack {
                        Text("Sigorta Bitiş")
                        Spacer()
                        Text(insDate.shortFormatted)
                            .foregroundColor(item.isInsuranceExpiringSoon ? .hakedisWarning : .secondary)
                    }
                }
                if let insp = item.inspectionExpiryDate {
                    HStack {
                        Text("Muayene Bitiş")
                        Spacer()
                        Text(insp.shortFormatted)
                            .foregroundColor(item.isInspectionExpiringSoon ? .hakedisWarning : .secondary)
                    }
                }
                if let reg = item.registrationInfo { LabeledContent("Ruhsat", value: reg) }
            }
            Section("Çalışma & Maliyet Özeti") {
                LabeledContent("Toplam Çalışma", value: "\(String(format: "%.0f", item.totalOperatingHours)) saat")
                LabeledContent("Bakım Aralığı", value: "\(String(format: "%.0f", item.maintenanceIntervalHours)) saat")
                LabeledContent("Yapılan Bakım", value: "\(item.completedMaintenanceCount) kez")
                HStack {
                    Text("Bakım Durumu")
                    Spacer()
                    StatusBadge(
                        text: item.isMaintenanceDue ? "Bakım Gerekiyor" : "Normal",
                        color: item.isMaintenanceDue ? .hakedisWarning : .hakedisSuccess
                    )
                }
                LabeledContent("Toplam Yakıt", value: item.totalFuelCost.currencyFormatted)
                LabeledContent("Toplam Tamir", value: item.totalRepairCost.currencyFormatted)
                if item.totalOperatingHours > 0 {
                    LabeledContent("Maliyet/Saat", value: item.costPerHour.currencyFormatted)
                }
                if item.ownershipType == .owned {
                    LabeledContent("Aylık Amortisman", value: item.monthlyDepreciation.currencyFormatted)
                }
                if item.isOverConsumption {
                    HStack {
                        Image(systemName: "fuelpump.exclamationmark.fill").foregroundColor(.hakedisDanger)
                        Text("Yakıt tüketim aşımı tespit edildi!").font(.caption).foregroundColor(.hakedisDanger)
                    }
                }
                LabeledContent("Bu Ay Akaryakıt", value: monthlyFuelCost.currencyFormatted)
            }
            Section("Arızalar (\(item.failures.count))") {
                if item.failures.isEmpty {
                    Text("Arıza kaydı yok").font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(item.failures.sorted { $0.failureDate > $1.failureDate }.prefix(3), id: \.id) { f in
                        HStack {
                            Image(systemName: f.isResolved ? "checkmark.circle" : "exclamationmark.circle.fill")
                                .foregroundColor(f.isResolved ? .hakedisSuccess : .hakedisDanger)
                            Text(f.failureChangeDescription).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text(f.failureDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section {
                if sortedLogs.isEmpty {
                    Text("Henüz çalışma kaydı yok")
                        .foregroundColor(.secondary).font(.caption)
                } else {
                    ForEach(sortedLogs, id: \.id) { log in
                        EquipmentLogRow(log: log)
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { sortedLogs[$0] }
                        for log in toDelete {
                            item.totalOperatingHours -= log.operatingHours
                            modelContext.delete(log)
                        }
                        do { try modelContext.save() } catch { print("Silme: \(error)") }
                    }
                }
            } header: {
                Text("Günlük Kayıtlar")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddLog = true
                } label: {
                    Label("Kayıt Ekle", systemImage: "plus")
                }
                .accessibilityLabel("Günlük kayıt ekle")
            }
        }
        .sheet(isPresented: $showingAddLog) {
            EquipmentLogForm(item: item)
        }
    }
}

private struct EquipmentLogRow: View {
    let log: EquipmentLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.date.shortFormatted)
                    .font(.subheadline.bold())
                Spacer()
                if log.isMaintenanceDay {
                    StatusBadge(text: "Bakım Günü", color: .hakedisWarning)
                }
            }
            HStack(spacing: 16) {
                Label("\(String(format: "%.0f", log.operatingHours))s", systemImage: "clock")
                    .font(.caption).foregroundColor(.secondary)
                if let liters = log.fuelLiters {
                    Label("\(String(format: "%.0f", liters))L", systemImage: "fuelpump")
                        .font(.caption).foregroundColor(.secondary)
                }
                if let cost = log.fuelCost, cost > 0 {
                    Text(cost.currencyFormatted)
                        .font(.caption).foregroundColor(.hakedisOrange)
                }
            }
            if let note = log.maintenanceNote, !note.isEmpty {
                Text(note).font(.caption2).foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(log.date.shortFormatted), \(String(format: "%.0f", log.operatingHours)) saat")
    }
}

// MARK: - AddEquipmentView
struct AddEquipmentItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var plateNumber = ""
    @State private var ownershipType = OwnershipType.owned
    @State private var dailyRentalCostText = "0"
    @State private var fuelType = ""
    @State private var maintenanceIntervalText = "250"

    var body: some View {
        NavigationStack {
            Form {
                Section("Ekipman Bilgileri") {
                    TextField("Ekipman adı (Vinç, Ekskavatör...)", text: $name)
                        .accessibilityLabel("Ekipman adı")
                    TextField("Plaka (opsiyonel)", text: $plateNumber)
                        .accessibilityLabel("Plaka numarası")
                    Picker("Sahiplik", selection: $ownershipType) {
                        ForEach(OwnershipType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .accessibilityLabel("Sahiplik türü")
                    if ownershipType == .rented {
                        HStack {
                            Text("Günlük Kira (₺)")
                            Spacer()
                            TextField("0", text: $dailyRentalCostText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .accessibilityLabel("Günlük kira bedeli")
                        }
                    }
                    TextField("Yakıt türü (Dizel, Benzin...)", text: $fuelType)
                        .accessibilityLabel("Yakıt türü")
                }
                Section("Bakım") {
                    HStack {
                        Text("Bakım Aralığı (saat)")
                        Spacer()
                        TextField("250", text: $maintenanceIntervalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Bakım aralığı saat")
                    }
                }
            }
            .navigationTitle("Yeni Ekipman")
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
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let item = EquipmentItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            ownershipType: ownershipType,
            maintenanceIntervalHours: Double(maintenanceIntervalText) ?? 250
        )
        item.plateNumber = plateNumber.isEmpty ? nil : plateNumber
        item.dailyRentalCost = Double(dailyRentalCostText) ?? 0
        item.fuelType = fuelType.isEmpty ? nil : fuelType
        modelContext.insert(item)
        do {
            try modelContext.save()
            NotificationManager.shared.scheduleEquipmentInsuranceAlerts(equipment: item)
            NotificationManager.shared.scheduleEquipmentMaintenanceAlert(equipment: item)
        } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}

// MARK: - EquipmentLogForm
struct EquipmentLogForm: View {
    let item: EquipmentItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var operatingHoursText = "8"
    @State private var fuelLitersText = ""
    @State private var fuelCostText = ""
    @State private var maintenanceNote = ""
    @State private var isMaintenanceDay = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Çalışma Bilgileri") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                        .accessibilityLabel("Kayıt tarihi")
                    HStack {
                        Text("Çalışma Saati")
                        Spacer()
                        TextField("0", text: $operatingHoursText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Çalışma saati")
                    }
                }

                if item.fuelType != nil {
                    Section("Akaryakıt") {
                        HStack {
                            Text("Litre")
                            Spacer()
                            TextField("0", text: $fuelLitersText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .accessibilityLabel("Akaryakıt litresi")
                        }
                        HStack {
                            Text("Maliyet (₺)")
                            Spacer()
                            TextField("0", text: $fuelCostText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .accessibilityLabel("Akaryakıt maliyeti")
                        }
                    }
                }

                Section("Bakım") {
                    Toggle("Bakım Günü", isOn: $isMaintenanceDay)
                        .accessibilityLabel("Bakım günü olarak işaretle")
                    if isMaintenanceDay {
                        TextField("Bakım notu", text: $maintenanceNote)
                            .accessibilityLabel("Bakım notu")
                    }
                }
            }
            .navigationTitle("Günlük Kayıt — \(item.name)")
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
        let hours = Double(operatingHoursText) ?? 0
        let log = EquipmentLog(date: date, operatingHours: hours)
        log.fuelLiters = Double(fuelLitersText)
        log.fuelCost = Double(fuelCostText)
        log.isMaintenanceDay = isMaintenanceDay
        log.maintenanceNote = maintenanceNote.isEmpty ? nil : maintenanceNote
        log.equipment = item
        item.totalOperatingHours += hours
        modelContext.insert(log)
        do {
            try modelContext.save()
            NotificationManager.shared.scheduleEquipmentMaintenanceAlert(equipment: item)
        } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
