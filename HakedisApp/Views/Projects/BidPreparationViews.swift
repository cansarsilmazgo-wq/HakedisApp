import SwiftUI
import SwiftData

// MARK: - Bid Preparation List View

struct BidPreparationView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BidPreparation.createdAt, order: .reverse) private var bids: [BidPreparation]
    @State private var showAdd = false
    @State private var searchText = ""

    private var filtered: [BidPreparation] {
        if searchText.isEmpty { return bids }
        return bids.filter {
            $0.projectTitle.localizedCaseInsensitiveContains(searchText) ||
            $0.bidNo.localizedCaseInsensitiveContains(searchText) ||
            $0.clientName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { bid in
                    NavigationLink(destination: BidDetailView(bid: bid)) {
                        BidRow(bid: bid)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("İhale Hazırlık")
            .searchable(text: $searchText, prompt: "İhale ara...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddBidView() }
            .overlay {
                if filtered.isEmpty {
                    EmptyStateView(icon: "doc.text.magnifyingglass", title: "İhale Yok",
                                   subtitle: "Yeni ihale hazırlığı ekleyin")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(filtered[i]) }
        do { try context.save() } catch { print("BidPreparationView delete error: \(error)") }
    }
}

private struct BidRow: View {
    let bid: BidPreparation
    private var statusColor: Color {
        switch bid.status {
        case .preparation: return .hakedisWarning
        case .submitted: return .hakedisOrange
        case .won: return .hakedisSuccess
        case .lost, .cancelled: return .hakedisDanger
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(bid.bidNo).font(.caption).foregroundColor(.secondary)
                Spacer()
                StatusBadge(text: bid.status.rawValue, color: statusColor)
            }
            Text(bid.projectTitle).font(.headline)
            Text(bid.clientName).font(.subheadline).foregroundColor(.secondary)
            HStack {
                Label(bid.bidDeadline.formatted(date: .abbreviated, time: .omitted),
                      systemImage: bid.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                    .font(.caption)
                    .foregroundColor(bid.isOverdue ? .hakedisDanger : .secondary)
                Spacer()
                Text(bid.totalWithTax.currencyFormatted)
                    .font(.caption).bold().foregroundColor(.hakedisOrange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Bid Detail View

struct BidDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var bid: BidPreparation
    @State private var showAddAnalysis = false

    var body: some View {
        List {
            Section("İhale Bilgileri") {
                LabeledContent("İhale No", value: bid.bidNo)
                LabeledContent("İşveren", value: bid.clientName)
                LabeledContent("Son Teklif", value: bid.bidDeadline.formatted(date: .long, time: .omitted))
                LabeledContent("Durum", value: bid.status.rawValue)
            }
            Section("Maliyet Hesabı") {
                LabeledContent("Doğrudan Maliyet", value: bid.totalDirectCost.currencyFormatted)
                LabeledContent("Genel Gider (\(bid.overheadRate.percentFormatted))",
                               value: bid.overheadAmount.currencyFormatted)
                LabeledContent("Kâr (\(bid.profitRate.percentFormatted))",
                               value: bid.profitAmount.currencyFormatted)
                LabeledContent("KDV Hariç", value: bid.subtotalBeforeTax.currencyFormatted)
                LabeledContent("KDV (\(bid.taxRate.percentFormatted))",
                               value: bid.taxAmount.currencyFormatted)
                LabeledContent("TOPLAM (KDV Dahil)", value: bid.totalWithTax.currencyFormatted)
                    .bold()
            }
            Section {
                ForEach(bid.analysisRecords) { rec in
                    NavigationLink(destination: AnalysisRecordDetailView(record: rec)) {
                        AnalysisRecordRow(record: rec)
                    }
                }
                .onDelete { idx in
                    for i in idx { context.delete(bid.analysisRecords[i]) }
                    bid.analysisRecords.remove(atOffsets: idx)
                    do { try context.save() } catch { print("BidDetailView delete error: \(error)") }
                }
            } header: {
                HStack {
                    Text("Analiz Kayıtları")
                    Spacer()
                    Button { showAddAnalysis = true } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle(bid.projectTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddAnalysis) { AddAnalysisRecordView(bid: bid) }
    }
}

private struct AnalysisRecordRow: View {
    let record: AnalysisRecord
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.pozCode).font(.caption).foregroundColor(.secondary)
                Text(record.pozName).font(.headline)
                Text("\(record.quantity.quantityFormatted) \(record.unit) × \(record.unitCost.currencyFormatted)")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(record.totalCost.currencyFormatted)
                .font(.subheadline).bold().foregroundColor(.hakedisOrange)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Analysis Record Detail

struct AnalysisRecordDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var record: AnalysisRecord
    @State private var showAddResource = false

    var body: some View {
        List {
            Section("Poz Bilgileri") {
                LabeledContent("Poz Kodu", value: record.pozCode)
                LabeledContent("Birim", value: record.unit)
                LabeledContent("Miktar", value: record.quantity.quantityFormatted)
                LabeledContent("Birim Maliyet", value: record.unitCost.currencyFormatted)
                LabeledContent("Toplam Maliyet", value: record.totalCost.currencyFormatted)
            }
            Section {
                ForEach(record.resources) { res in
                    AnalysisResourceRow(resource: res)
                }
            } header: {
                HStack {
                    Text("Kaynaklar")
                    Spacer()
                    Button { showAddResource = true } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle(record.pozName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddResource) { AddAnalysisResourceView(record: record) }
    }
}

private struct AnalysisResourceRow: View {
    let resource: AnalysisResourceItem
    var body: some View {
        HStack {
            Image(systemName: resource.resourceType.icon)
                .foregroundColor(.hakedisOrange).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.resourceName).font(.headline)
                Text("\(resource.quantity.quantityFormatted) \(resource.unit) × \(resource.unitPrice.currencyFormatted)")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(resource.total.currencyFormatted)
                .font(.subheadline).bold()
        }
    }
}

// MARK: - Approximate Cost View

struct ApproximateCostView: View {
    @State private var laborRate: Double = 350
    @State private var materialMarkup: Double = 20
    @State private var equipmentRate: Double = 500
    @State private var overheadRate: Double = 15
    @State private var profitRate: Double = 10
    @State private var taxRate: Double = 20

    @State private var quantity = ""
    @State private var unitPrice = ""
    @State private var selectedUnit = "m²"

    private let units = ["m²", "m³", "m", "adet", "kg", "ton"]

    private var q: Double { Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var p: Double { Double(unitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var directCost: Double { q * p }
    private var overhead: Double { directCost * overheadRate / 100 }
    private var profit: Double { (directCost + overhead) * profitRate / 100 }
    private var subtotal: Double { directCost + overhead + profit }
    private var tax: Double { subtotal * taxRate / 100 }
    private var total: Double { subtotal + tax }

    var body: some View {
        NavigationStack {
            Form {
                Section("Parametreler") {
                    HStack {
                        Text("İşçilik Katsayısı (₺/gün)")
                        Spacer()
                        TextField("", value: $laborRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Malzeme Markap (%)")
                        Spacer()
                        TextField("", value: $materialMarkup, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Makine Saatlik (₺)")
                        Spacer()
                        TextField("", value: $equipmentRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                Section("Hesap") {
                    Picker("Birim", selection: $selectedUnit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Miktar", text: $quantity).keyboardType(.decimalPad)
                    TextField("Birim Fiyat (₺)", text: $unitPrice).keyboardType(.decimalPad)
                }
                Section("Sonuç") {
                    LabeledContent("Doğrudan Maliyet", value: directCost.currencyFormatted)
                    LabeledContent("Genel Gider (\(overheadRate, format: .number)%)",
                                   value: overhead.currencyFormatted)
                    LabeledContent("Kâr (\(profitRate, format: .number)%)",
                                   value: profit.currencyFormatted)
                    LabeledContent("KDV Hariç", value: subtotal.currencyFormatted)
                    LabeledContent("KDV (\(taxRate, format: .number)%)",
                                   value: tax.currencyFormatted)
                    LabeledContent("TOPLAM", value: total.currencyFormatted).bold()
                }
            }
            .navigationTitle("Yaklaşık Maliyet")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Add Bid View

struct AddBidView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var bids: [BidPreparation]

    @State private var projectTitle = ""
    @State private var clientName = ""
    @State private var bidDeadline = Date().addingTimeInterval(30 * 24 * 3600)
    @State private var overheadRate = 15.0
    @State private var profitRate = 10.0
    @State private var taxRate = 20.0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("İhale Bilgileri") {
                    TextField("Proje Başlığı", text: $projectTitle)
                    TextField("İşveren / İdare", text: $clientName)
                    DatePicker("Son Teklif Tarihi", selection: $bidDeadline, displayedComponents: .date)
                }
                Section("Oranlar") {
                    HStack {
                        Text("Genel Gider (%)")
                        Spacer()
                        TextField("", value: $overheadRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Kâr (%)")
                        Spacer()
                        TextField("", value: $profitRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("KDV (%)")
                        Spacer()
                        TextField("", value: $taxRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
                Section("Notlar") {
                    TextField("Notlar", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Yeni İhale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(projectTitle.isEmpty || clientName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let year = Calendar.current.component(.year, from: Date())
        let no = BidPreparation.generateNo(existingCount: bids.count, year: year)
        let bid = BidPreparation(bidNo: no, projectTitle: projectTitle, clientName: clientName, bidDeadline: bidDeadline)
        bid.overheadRate = overheadRate
        bid.profitRate = profitRate
        bid.taxRate = taxRate
        bid.notes = notes
        context.insert(bid)
        do { try context.save() } catch { print("AddBidView save error: \(error)") }
        dismiss()
    }
}

// MARK: - Add Analysis Record View

struct AddAnalysisRecordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var bid: BidPreparation

    @State private var pozCode = ""
    @State private var pozName = ""
    @State private var unit = "m²"
    @State private var quantityStr = ""

    private let units = ["m²", "m³", "m", "adet", "kg", "ton"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Poz Bilgileri") {
                    TextField("Poz Kodu", text: $pozCode)
                    TextField("Poz Adı", text: $pozName)
                    Picker("Birim", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Miktar", text: $quantityStr).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Analiz Kaydı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }.disabled(pozName.isEmpty || quantityStr.isEmpty)
                }
            }
        }
    }

    private func save() {
        let q = Double(quantityStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let rec = AnalysisRecord(pozCode: pozCode, pozName: pozName, unit: unit, quantity: q)
        rec.bidPreparation = bid
        context.insert(rec)
        bid.analysisRecords.append(rec)
        do { try context.save() } catch { print("AddAnalysisRecordView save error: \(error)") }
        dismiss()
    }
}

// MARK: - Add Analysis Resource View

struct AddAnalysisResourceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var record: AnalysisRecord

    @State private var resourceName = ""
    @State private var resourceType = AnalysisResourceType.material
    @State private var unit = "adet"
    @State private var quantityStr = ""
    @State private var unitPriceStr = ""

    private let units = ["adet", "kg", "m²", "m³", "m", "gün", "saat", "ton"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Kaynak Bilgileri") {
                    TextField("Kaynak Adı", text: $resourceName)
                    Picker("Tür", selection: $resourceType) {
                        ForEach(AnalysisResourceType.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                        }
                    }
                    Picker("Birim", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Miktar", text: $quantityStr).keyboardType(.decimalPad)
                    TextField("Birim Fiyat (₺)", text: $unitPriceStr).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Kaynak Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }.disabled(resourceName.isEmpty || quantityStr.isEmpty)
                }
            }
        }
    }

    private func save() {
        let q = Double(quantityStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let p = Double(unitPriceStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        var res = AnalysisResourceItem(resourceName: resourceName, typeRaw: resourceType.rawValue,
                                       unit: unit, quantity: q, unitPrice: p)
        res.resourceName = resourceName
        var current = record.resources
        current.append(res)
        record.resources = current
        do { try context.save() } catch { print("AddAnalysisResourceView save error: \(error)") }
        dismiss()
    }
}
