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
                LabeledContent("Geçici Teminat (%3)", value: bid.bidBondAmount.currencyFormatted)
                    .foregroundColor(.hakedisOrange)
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

// MARK: - Yapı Sınıfı Birim Maliyet Tablosu (2026 referans değerleri)

struct BuildingCostRate: Identifiable {
    let id = UUID()
    let sinif: String          // I, II, III, IV, V
    let grup: String           // A, B, C, D
    let aciklama: String
    var birimMaliyet: Double   // TL/m² — SettingsView'dan güncellenebilir

    static let defaults: [BuildingCostRate] = [
        BuildingCostRate(sinif: "I",   grup: "A", aciklama: "Basit yapı (ahşap çatılı, kerpiç)", birimMaliyet: 8_500),
        BuildingCostRate(sinif: "I",   grup: "B", aciklama: "Basit kagir yapı",                   birimMaliyet: 10_000),
        BuildingCostRate(sinif: "II",  grup: "A", aciklama: "Normal yapı (betonarme)",             birimMaliyet: 14_000),
        BuildingCostRate(sinif: "II",  grup: "B", aciklama: "Normal yapı (çelik karkas)",          birimMaliyet: 16_000),
        BuildingCostRate(sinif: "III", grup: "A", aciklama: "Lüks konut (<5 kat)",                 birimMaliyet: 22_000),
        BuildingCostRate(sinif: "III", grup: "B", aciklama: "Lüks konut (≥5 kat)",                 birimMaliyet: 26_000),
        BuildingCostRate(sinif: "IV",  grup: "A", aciklama: "Çok lüks konut / rezidans",           birimMaliyet: 36_000),
        BuildingCostRate(sinif: "IV",  grup: "B", aciklama: "Ofis / AVM",                          birimMaliyet: 32_000),
        BuildingCostRate(sinif: "V",   grup: "A", aciklama: "Endüstriyel / fabrika",               birimMaliyet: 12_000),
        BuildingCostRate(sinif: "V",   grup: "B", aciklama: "Altyapı / yol / köprü",              birimMaliyet: 18_000),
    ]
}

struct ApproximateCostView: View {
    // Yapı sınıfı hesabı
    @State private var rates = BuildingCostRate.defaults
    @State private var selectedRateIndex = 2        // varsayılan: II-A
    @State private var alanM2 = ""
    @State private var customBirimMaliyet = ""
    @State private var useCustomRate = false
    @AppStorage("buildingCostRatesJSON") private var savedRatesJSON = ""

    // Manuel hesap
    @State private var overheadRate: Double = 15
    @State private var profitRate: Double = 10
    @State private var taxRate: Double = 20
    @State private var quantity = ""
    @State private var unitPrice = ""
    @State private var selectedUnit = "m²"

    private let units = ["m²", "m³", "m", "adet", "kg", "ton"]

    // Yapı sınıfı hesabı
    private var secilenRate: BuildingCostRate { rates[min(selectedRateIndex, rates.count - 1)] }
    private var alan: Double { Double(alanM2.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var gecerliBirimMaliyet: Double {
        if useCustomRate, let v = Double(customBirimMaliyet.replacingOccurrences(of: ",", with: ".")) { return v }
        return secilenRate.birimMaliyet
    }
    private var yapiMaliyeti: Double { alan * gecerliBirimMaliyet }
    private var yapiGenel: Double { yapiMaliyeti * overheadRate / 100 }
    private var yapiKar: Double { (yapiMaliyeti + yapiGenel) * profitRate / 100 }
    private var yapiAra: Double { yapiMaliyeti + yapiGenel + yapiKar }
    private var yapiKDV: Double { yapiAra * taxRate / 100 }
    private var yapiToplam: Double { yapiAra + yapiKDV }

    // Manuel hesap
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
                // --- YAPI SINIFI HESABI ---
                Section("Yapı Sınıfı Bazlı Hesap") {
                    Picker("Yapı Sınıfı", selection: $selectedRateIndex) {
                        ForEach(rates.indices, id: \.self) { i in
                            Text("Sınıf \(rates[i].sinif)-\(rates[i].grup): \(rates[i].aciklama)")
                                .tag(i)
                        }
                    }
                    .pickerStyle(.menu)

                    LabeledContent("Birim Maliyet (TL/m²)",
                                   value: secilenRate.birimMaliyet.currencyFormatted)

                    Toggle("Özel birim maliyet gir", isOn: $useCustomRate)
                    if useCustomRate {
                        TextField("Birim maliyet (₺/m²)", text: $customBirimMaliyet)
                            .keyboardType(.decimalPad)
                    }

                    TextField("Alan (m²)", text: $alanM2)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Alan metrekare")
                }

                if alan > 0 {
                    Section("Yapı Sınıfı Sonucu") {
                        LabeledContent("Yapım Maliyeti", value: yapiMaliyeti.currencyFormatted)
                        LabeledContent("Genel Gider (\(overheadRate, format: .number)%)", value: yapiGenel.currencyFormatted)
                        LabeledContent("Kâr (\(profitRate, format: .number)%)", value: yapiKar.currencyFormatted)
                        LabeledContent("KDV Hariç", value: yapiAra.currencyFormatted)
                        LabeledContent("KDV (\(taxRate, format: .number)%)", value: yapiKDV.currencyFormatted)
                        LabeledContent("YAKLAŞIK MALİYET", value: yapiToplam.currencyFormatted).bold()
                    }
                }

                // --- ORTAK ORANLAR ---
                Section("Genel Oranlar") {
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

                // --- ÖZEL/MANUEL HESAP ---
                Section("Manuel Birim Fiyat Hesabı") {
                    Picker("Birim", selection: $selectedUnit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Miktar", text: $quantity).keyboardType(.decimalPad)
                    TextField("Birim Fiyat (₺)", text: $unitPrice).keyboardType(.decimalPad)
                }
                if q > 0 && p > 0 {
                    Section("Manuel Hesap Sonucu") {
                        LabeledContent("Doğrudan Maliyet", value: directCost.currencyFormatted)
                        LabeledContent("Genel Gider", value: overhead.currencyFormatted)
                        LabeledContent("Kâr", value: profit.currencyFormatted)
                        LabeledContent("KDV Hariç", value: subtotal.currencyFormatted)
                        LabeledContent("KDV", value: tax.currencyFormatted)
                        LabeledContent("TOPLAM", value: total.currencyFormatted).bold()
                    }
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
    @State private var tenzilatRate = 0.0
    @State private var bidType: BidType = .birimFiyat
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("İhale Bilgileri") {
                    TextField("Proje Başlığı", text: $projectTitle)
                    TextField("İşveren / İdare", text: $clientName)
                    DatePicker("Son Teklif Tarihi", selection: $bidDeadline, displayedComponents: .date)
                    // FAZ 17.15 — İhale türü
                    Picker("İhale Türü", selection: $bidType) {
                        ForEach(BidType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
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
                    // FAZ 17.15 — Tenzilat
                    HStack {
                        Text("Tenzilat (%)")
                        Spacer()
                        TextField("0", value: $tenzilatRate, format: .number)
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
        bid.tenzilatRate = tenzilatRate
        bid.bidType = bidType
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
