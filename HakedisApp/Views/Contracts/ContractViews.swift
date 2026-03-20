import SwiftUI
import SwiftData

// MARK: - Contract Row
struct ContractRow: View {
    let contract: Contract

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(contract.title)
                .font(.headline)
            HStack {
                Text(contract.contractor?.name ?? "Taşeron yok")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(contract.totalContractAmount.currencyFormatted)
                    .font(.caption.bold())
                    .foregroundStyle(.hakedisOrange)
            }
            Text("\(contract.workItems.count) iş kalemi")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Contract
struct AddContractView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Contractor.name) private var contractors: [Contractor]

    let project: Project

    @State private var title = ""
    @State private var contractDate = Date()
    @State private var retentionRate = 10.0
    @State private var advanceRate = 0.0
    @State private var selectedContractor: Contractor?

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedContractor != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sözleşme Bilgileri") {
                    TextField("Sözleşme Başlığı *", text: $title)
                    DatePicker("Sözleşme Tarihi", selection: $contractDate, displayedComponents: .date)
                }

                Section("Taşeron *") {
                    if contractors.isEmpty {
                        Text("Önce taşeron ekleyin")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Taşeron Seç", selection: $selectedContractor) {
                            Text("Seçiniz").tag(Optional<Contractor>.none)
                            ForEach(contractors) { c in
                                Text(c.name).tag(Optional(c))
                            }
                        }
                    }
                }

                Section("Kesinti Oranları") {
                    HStack {
                        Text("Teminat Oranı")
                        Spacer()
                        TextField("10", value: $retentionRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%")
                    }
                    HStack {
                        Text("Avans Oranı")
                        Spacer()
                        TextField("0", value: $advanceRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%")
                    }
                }
            }
            .navigationTitle("Yeni Sözleşme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(!isValid)
                        .bold()
                }
            }
        }
    }

    private func save() {
        let contract = Contract(title: title, contractDate: contractDate,
                                retentionRate: retentionRate, advanceRate: advanceRate)
        contract.project = project
        contract.contractor = selectedContractor
        selectedContractor?.contracts.append(contract)
        project.contracts.append(contract)
        modelContext.insert(contract)
        dismiss()
    }
}

// MARK: - Contract Detail
struct ContractDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let contract: Contract
    @State private var showingAddWorkItem = false
    @State private var showingAddHakedis = false

    var body: some View {
        List {
            // Summary
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Toplam Tutar")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(contract.totalContractAmount.currencyFormatted)
                                .font(.title2.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Teminat")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("%\(Int(contract.retentionRate))")
                                .font(.headline)
                        }
                    }
                    LabeledContent("Taşeron", value: contract.contractor?.name ?? "—")
                    LabeledContent("Tarih", value: contract.contractDate.shortFormatted)
                }
                .padding(.vertical, 4)
            }

            // Work Items (Pozlar)
            Section {
                if contract.workItems.isEmpty {
                    Button {
                        showingAddWorkItem = true
                    } label: {
                        Label("İş Kalemi Ekle", systemImage: "plus.circle")
                    }
                    .foregroundStyle(.hakedisOrange)
                } else {
                    ForEach(contract.workItems) { item in
                        NavigationLink(destination: WorkItemDetailView(workItem: item)) {
                            WorkItemRow(workItem: item)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { contract.workItems[$0] }.forEach { modelContext.delete($0) }
                    }
                }
            } header: {
                HStack {
                    Text("İş Kalemleri (Pozlar)")
                    Spacer()
                    Button {
                        showingAddWorkItem = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.hakedisOrange)
                    }
                }
            }

            // Hakedişler
            Section {
                if contract.hakedisler.isEmpty {
                    Button {
                        showingAddHakedis = true
                    } label: {
                        Label("Hakediş Oluştur", systemImage: "doc.badge.plus")
                    }
                    .foregroundStyle(.hakedisOrange)
                } else {
                    ForEach(contract.hakedisler.sorted { $0.createdAt > $1.createdAt }) { hakedis in
                        NavigationLink(destination: HakedisDetailView(hakedis: hakedis)) {
                            HakedisListRow(hakedis: hakedis)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Hakedişler")
                    Spacer()
                    Button {
                        showingAddHakedis = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.hakedisOrange)
                    }
                }
            }
        }
        .navigationTitle(contract.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddWorkItem) {
            AddWorkItemView(contract: contract)
        }
        .sheet(isPresented: $showingAddHakedis) {
            AddHakedisView(contract: contract)
        }
    }
}

// MARK: - Work Item Row
struct WorkItemRow: View {
    let workItem: WorkItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("[\(workItem.code)]")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(workItem.name)
                    .font(.subheadline.bold())
            }
            HStack {
                Text("\(workItem.completedQuantity.quantityFormatted) / \(workItem.contractedQuantity.quantityFormatted) \(workItem.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(workItem.completionPercentage.percentFormatted)
                    .font(.caption.bold())
                    .foregroundStyle(workItem.completionPercentage >= 100 ? .hakedisSuccess : .hakedisOrange)
            }
            ProgressBarView(
                progress: workItem.completionPercentage,
                color: workItem.completionPercentage >= 100 ? .hakedisSuccess : .hakedisOrange
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Work Item
struct AddWorkItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let contract: Contract

    @State private var code = ""
    @State private var name = ""
    @State private var unit = "m²"
    @State private var unitPrice = ""
    @State private var contractedQuantity = ""
    @State private var location = ""

    let units = ["m²", "m³", "m", "adet", "ton", "kg", "lt", "saat", "gün"]

    var isValid: Bool {
        !code.isEmpty && !name.isEmpty &&
        Double(unitPrice.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(contractedQuantity.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Poz Bilgileri") {
                    TextField("Poz No *", text: $code)
                    TextField("İş Kalemi Adı *", text: $name)
                    TextField("Mahal / Konum", text: $location)
                }
                Section("Miktar ve Fiyat") {
                    Picker("Birim", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                    HStack {
                        Text("Sözleşme Miktarı *")
                        Spacer()
                        TextField("0", text: $contractedQuantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text(unit).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Birim Fiyat *")
                        Spacer()
                        TextField("0,00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("₺").foregroundStyle(.secondary)
                    }
                }

                if let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")),
                   let qty = Double(contractedQuantity.replacingOccurrences(of: ",", with: ".")) {
                    Section("Toplam Tutar") {
                        Text((price * qty).currencyFormatted)
                            .font(.headline)
                            .foregroundStyle(.hakedisOrange)
                    }
                }
            }
            .navigationTitle("İş Kalemi Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(!isValid)
                        .bold()
                }
            }
        }
    }

    private func save() {
        let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        let qty = Double(contractedQuantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let item = WorkItem(code: code, name: name, unit: unit, unitPrice: price,
                           contractedQuantity: qty, location: location)
        item.contract = contract
        contract.workItems.append(item)
        modelContext.insert(item)
        dismiss()
    }
}

// MARK: - Work Item Detail
struct WorkItemDetailView: View {
    let workItem: WorkItem

    var body: some View {
        List {
            Section("Poz Bilgileri") {
                LabeledContent("Poz No", value: workItem.code)
                LabeledContent("İş Kalemi", value: workItem.name)
                LabeledContent("Mahal", value: workItem.location.isEmpty ? "—" : workItem.location)
                LabeledContent("Birim", value: workItem.unit)
                LabeledContent("Birim Fiyat", value: workItem.unitPrice.currencyFormatted)
            }

            Section("İlerleme") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Tamamlanma")
                        Spacer()
                        Text(workItem.completionPercentage.percentFormatted)
                            .bold()
                            .foregroundStyle(.hakedisOrange)
                    }
                    ProgressBarView(progress: workItem.completionPercentage, color: .hakedisOrange)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Yapılan").font(.caption).foregroundStyle(.secondary)
                            Text("\(workItem.completedQuantity.quantityFormatted) \(workItem.unit)")
                                .font(.subheadline.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Sözleşme").font(.caption).foregroundStyle(.secondary)
                            Text("\(workItem.contractedQuantity.quantityFormatted) \(workItem.unit)")
                                .font(.subheadline.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Kalan").font(.caption).foregroundStyle(.secondary)
                            Text("\(workItem.remainingQuantity.quantityFormatted) \(workItem.unit)")
                                .font(.subheadline.bold())
                                .foregroundStyle(workItem.remainingQuantity < 0 ? .hakedisDanger : .primary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Günlük Girişler") {
                if workItem.dailyEntries.isEmpty {
                    Text("Henüz giriş yapılmadı")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workItem.dailyEntries.sorted { $0.date > $1.date }) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.date.shortFormatted)
                                    .font(.subheadline.bold())
                                if !entry.location.isEmpty {
                                    Text(entry.location)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(entry.quantity.quantityFormatted) \(workItem.unit)")
                                .font(.subheadline)
                                .foregroundStyle(.hakedisOrange)
                        }
                    }
                }
            }
        }
        .navigationTitle(workItem.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
