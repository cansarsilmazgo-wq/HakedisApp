import SwiftUI
import SwiftData

// MARK: - Market Research JSON Helper

struct MarketResearchEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var supplierName: String
    var price: Double
    var date: Date
    var reason: String
}

private func decodeMarket(_ json: String?) -> [MarketResearchEntry] {
    guard let data = json?.data(using: .utf8),
          let entries = try? JSONDecoder().decode([MarketResearchEntry].self, from: data)
    else { return [] }
    return entries
}

private func encodeMarket(_ entries: [MarketResearchEntry]) -> String? {
    guard let data = try? JSONEncoder().encode(entries) else { return nil }
    return String(data: data, encoding: .utf8)
}

// MARK: - Analysis List Sheet (WorkItem'dan açılır)

struct UnitPriceAnalysisListSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workItem: WorkItem

    @State private var showingAdd = false
    @State private var selectedAnalysis: UnitPriceAnalysis?

    private var sorted: [UnitPriceAnalysis] {
        workItem.unitPriceAnalyses.sorted { $0.version > $1.version }
    }

    var body: some View {
        NavigationStack {
            List {
                if sorted.isEmpty {
                    EmptyStateView(
                        icon: "function",
                        title: "Henüz analiz yok",
                        subtitle: "Bu iş kalemi için birim fiyat analizi oluşturun",
                        actionTitle: "Analiz Oluştur",
                        action: { showingAdd = true }
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sorted) { analysis in
                        Button {
                            selectedAnalysis = analysis
                        } label: {
                            AnalysisListRow(analysis: analysis)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        offsets.map { sorted[$0] }.forEach { modelContext.delete($0) }
                    }
                }
            }
            .navigationTitle("Birim Fiyat Analizleri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddUnitPriceAnalysisView(workItem: workItem)
            }
            .sheet(item: $selectedAnalysis) { analysis in
                UnitPriceAnalysisDetailView(analysis: analysis)
            }
        }
    }
}

// MARK: - Analysis List Row

struct AnalysisListRow: View {
    let analysis: UnitPriceAnalysis

    var diffColor: Color {
        analysis.isSavings ? .hakedisSuccess : .hakedisDanger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(analysis.analysisNo)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                Spacer()
                StatusBadge(text: "v\(analysis.version)", color: .hakedisOrange)
                StatusBadge(text: analysis.approvalStatus.rawValue,
                            color: analysis.approvalStatus == .onaylandi ? .hakedisSuccess
                                   : analysis.approvalStatus == .reddedildi ? .hakedisDanger
                                   : .secondary)
            }
            Text(analysis.workItemName)
                .font(.subheadline.bold())
                .lineLimit(1)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Analiz Fiyatı")
                        .font(.caption2).foregroundColor(.secondary)
                    Text(analysis.totalCost.currencyFormatted)
                        .font(.caption.bold()).foregroundColor(.hakedisOrange)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(analysis.isSavings ? "Tasarruf" : "Aşım")
                        .font(.caption2).foregroundColor(.secondary)
                    Text(abs(analysis.diff).currencyFormatted)
                        .font(.caption.bold()).foregroundColor(diffColor)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Analysis View (5 bölümlü form)

struct AddUnitPriceAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workItem: WorkItem

    // Bölüm 1 - Temel Bilgi
    @State private var isStandardPoz = false
    @State private var standardPozCode = ""

    // Bölüm 2 - Maliyet
    @State private var laborCostStr = ""
    @State private var laborShiftType: LaborShiftType = .gunduz
    @State private var materialCostStr = ""
    @State private var machineCostStr = ""
    @State private var transportCostStr = ""

    // Bölüm 3 - Döviz
    @State private var hasForeignCurrency = false
    @State private var currencyCode = "EUR"
    @State private var exchangeRateStr = ""
    @State private var exchangeRateDate = Date()

    // Bölüm 4 - Piyasa Araştırması
    @State private var marketEntries: [MarketResearchEntry] = []
    @State private var showingAddSupplier = false

    // Bölüm 5 - Oranlar
    @State private var overheadRateStr = "15"
    @State private var profitRateStr = "10"

    // MARK: - Live Calculations
    private var laborCost: Double     { Double(laborCostStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var materialCost: Double  { Double(materialCostStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var machineCost: Double   { Double(machineCostStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var transportCost: Double { Double(transportCostStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var overheadRate: Double  { Double(overheadRateStr.replacingOccurrences(of: ",", with: ".")) ?? 15 }
    private var profitRate: Double    { Double(profitRateStr.replacingOccurrences(of: ",", with: ".")) ?? 10 }

    private var directCost: Double {
        laborCost * laborShiftType.coefficient + materialCost + machineCost + transportCost
    }
    private var totalCost: Double {
        directCost * (1 + overheadRate / 100) * (1 + profitRate / 100)
    }
    private var contractPrice: Double { workItem.unitPrice }
    private var diff: Double { totalCost - contractPrice }

    private var isValid: Bool { totalCost > 0 && marketEntries.count >= 3 }

    private var nextAnalysisNo: String {
        let year = Calendar.current.component(.year, from: Date())
        let seq = workItem.unitPriceAnalyses.count + 1
        return "BFA-\(year)-\(String(format: "%03d", seq))"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Bölüm 1 - Temel Bilgi
                Section("1. Temel Bilgi") {
                    LabeledContent("İş Kalemi", value: workItem.name)
                    LabeledContent("Poz No", value: workItem.code)
                    LabeledContent("Analiz No", value: nextAnalysisNo)
                    Toggle("Standart Poza Bağlı", isOn: $isStandardPoz)
                    if isStandardPoz {
                        TextField("Standart Poz Kodu", text: $standardPozCode)
                    }
                }

                // Bölüm 2 - Maliyet Girişi
                Section("2. Maliyet Girişi") {
                    HStack {
                        Text("İşçilik")
                        Spacer()
                        TextField("0,00", text: $laborCostStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("₺").foregroundColor(.secondary)
                    }
                    Picker("Vardiya", selection: $laborShiftType) {
                        ForEach(LaborShiftType.allCases, id: \.self) { s in
                            Text("\(s.rawValue)  \(s.coefficientLabel)").tag(s)
                        }
                    }
                    HStack {
                        Text("Malzeme")
                        Spacer()
                        TextField("0,00", text: $materialCostStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("₺").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Makine")
                        Spacer()
                        TextField("0,00", text: $machineCostStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("₺").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Nakliye")
                        Spacer()
                        TextField("0,00", text: $transportCostStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("₺").foregroundColor(.secondary)
                    }
                }

                // Bölüm 3 - İthal Malzeme
                Section("3. İthal Malzeme") {
                    Toggle("Dövizli Malzeme Var", isOn: $hasForeignCurrency)
                    if hasForeignCurrency {
                        Picker("Döviz", selection: $currencyCode) {
                            Text("EUR").tag("EUR")
                            Text("USD").tag("USD")
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Text("Kur (\(currencyCode)/₺)")
                            Spacer()
                            TextField("0,00", text: $exchangeRateStr)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        DatePicker("Kur Tarihi", selection: $exchangeRateDate, displayedComponents: .date)
                    }
                }

                // Bölüm 4 - Piyasa Araştırması
                Section {
                    if marketEntries.isEmpty {
                        Text("En az 3 tedarikçi ekleyin")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(marketEntries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.supplierName).font(.subheadline.bold())
                                    Spacer()
                                    Text(entry.price.currencyFormatted)
                                        .font(.subheadline)
                                        .foregroundColor(.hakedisOrange)
                                }
                                if !entry.reason.isEmpty {
                                    Text(entry.reason).font(.caption).foregroundColor(.secondary)
                                }
                                Text(entry.date.shortFormatted)
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            marketEntries.remove(atOffsets: offsets)
                        }
                        // Min/Ortalama/Maks
                        let prices = marketEntries.map { $0.price }
                        if let minP = prices.min(), let maxP = prices.max() {
                            let avg = prices.reduce(0, +) / Double(prices.count)
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("En Düşük").font(.caption2).foregroundColor(.secondary)
                                    Text(minP.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisSuccess)
                                }
                                Spacer()
                                VStack(alignment: .center) {
                                    Text("Ortalama").font(.caption2).foregroundColor(.secondary)
                                    Text(avg.currencyFormatted).font(.caption.bold())
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("En Yüksek").font(.caption2).foregroundColor(.secondary)
                                    Text(maxP.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisDanger)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    Button {
                        showingAddSupplier = true
                    } label: {
                        Label("Tedarikçi Ekle", systemImage: "plus.circle")
                            .foregroundColor(.hakedisOrange)
                    }
                    .disabled(marketEntries.count >= 10)
                } header: {
                    HStack {
                        Text("4. Piyasa Araştırması")
                        Spacer()
                        if marketEntries.count < 3 {
                            Text("Min. 3 tedarikçi")
                                .font(.caption)
                                .foregroundColor(.hakedisDanger)
                        }
                    }
                }

                // Bölüm 5 - Genel Gider & Kar
                Section("5. Genel Gider & Kar") {
                    HStack {
                        Text("Genel Gider")
                        Spacer()
                        TextField("15", text: $overheadRateStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Müteahhit Karı")
                        Spacer()
                        TextField("10", text: $profitRateStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%").foregroundColor(.secondary)
                    }
                }

                // Canlı Hesap Özeti
                Section("Hesap Özeti") {
                    LabeledContent("Direkt Maliyet", value: directCost.currencyFormatted)
                    LabeledContent("Genel Gider (%\(Int(overheadRate)))",
                                   value: (directCost * overheadRate / 100).currencyFormatted)
                    LabeledContent("Kar (%\(Int(profitRate)))",
                                   value: (directCost * (1 + overheadRate/100) * profitRate / 100).currencyFormatted)
                    Divider()
                    LabeledContent("Analiz Birim Fiyatı") {
                        Text(totalCost.currencyFormatted)
                            .font(.headline)
                            .foregroundColor(.hakedisOrange)
                    }
                    LabeledContent("Sözleşme Birim Fiyatı") {
                        Text(contractPrice.currencyFormatted)
                            .foregroundColor(.secondary)
                    }
                    LabeledContent(diff < 0 ? "Tasarruf" : "Aşım") {
                        HStack(spacing: 4) {
                            Image(systemName: diff < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            Text(abs(diff).currencyFormatted)
                        }
                        .foregroundColor(diff < 0 ? .hakedisSuccess : .hakedisDanger)
                        .font(.subheadline.bold())
                    }
                }
            }
            .navigationTitle("Yeni Birim Fiyat Analizi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .bold()
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingAddSupplier) {
                AddSupplierSheet { entry in
                    marketEntries.append(entry)
                }
            }
        }
    }

    private func save() {
        let version = workItem.unitPriceAnalyses.count + 1
        let analysis = UnitPriceAnalysis(
            analysisNo: nextAnalysisNo,
            workItemCode: workItem.code,
            workItemName: workItem.name,
            contractUnitPrice: workItem.unitPrice,
            version: version
        )
        analysis.isStandardPoz = isStandardPoz
        analysis.standardPozCode = standardPozCode.isEmpty ? nil : standardPozCode
        analysis.laborCost = laborCost
        analysis.laborShiftType = laborShiftType
        analysis.materialCost = materialCost
        analysis.machineCost = machineCost
        analysis.transportCost = transportCost
        analysis.hasForeignCurrency = hasForeignCurrency
        if hasForeignCurrency {
            analysis.currencyCode = currencyCode
            analysis.exchangeRate = Double(exchangeRateStr.replacingOccurrences(of: ",", with: "."))
            analysis.exchangeRateDate = exchangeRateDate
        }
        analysis.marketResearchJSON = encodeMarket(marketEntries)
        analysis.overheadRate = overheadRate
        analysis.profitRate = profitRate
        analysis.workItem = workItem
        workItem.unitPriceAnalyses.append(analysis)
        modelContext.insert(analysis)
        dismiss()
    }
}

// MARK: - Add Supplier Sheet

struct AddSupplierSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MarketResearchEntry) -> Void

    @State private var supplierName = ""
    @State private var priceStr = ""
    @State private var date = Date()
    @State private var reason = ""

    private var isValid: Bool {
        !supplierName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(priceStr.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tedarikçi Bilgisi") {
                    TextField("Firma Adı *", text: $supplierName)
                    HStack {
                        Text("Fiyat *")
                        Spacer()
                        TextField("0,00", text: $priceStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("₺").foregroundColor(.secondary)
                    }
                    DatePicker("Fiyat Tarihi", selection: $date, displayedComponents: .date)
                    TextField("Seçilme Gerekçesi", text: $reason)
                }
            }
            .navigationTitle("Tedarikçi Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") {
                        let price = Double(priceStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                        onSave(MarketResearchEntry(supplierName: supplierName, price: price,
                                                   date: date, reason: reason))
                        dismiss()
                    }
                    .bold()
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Analysis Detail View

struct UnitPriceAnalysisDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var analysis: UnitPriceAnalysis

    private var marketEntries: [MarketResearchEntry] { decodeMarket(analysis.marketResearchJSON) }

    var body: some View {
        NavigationStack {
            List {
                Section("Analiz Bilgileri") {
                    LabeledContent("No", value: analysis.analysisNo)
                    LabeledContent("Versiyon", value: "v\(analysis.version)")
                    LabeledContent("Tarih", value: analysis.date.shortFormatted)
                    LabeledContent("Poz", value: "[\(analysis.workItemCode)] \(analysis.workItemName)")
                    Picker("Durum", selection: $analysis.approvalStatus) {
                        ForEach(AnalysisApprovalStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    if analysis.approvalStatus == .onaylandi {
                        TextField("Onaylayan", text: Binding(
                            get: { analysis.approvedBy ?? "" },
                            set: { analysis.approvedBy = $0.isEmpty ? nil : $0 }
                        ))
                    }
                }

                Section("Maliyet Kırılımı") {
                    LabeledContent("İşçilik (\(analysis.laborShiftType.rawValue))",
                                   value: (analysis.laborCost * analysis.laborShiftType.coefficient).currencyFormatted)
                    LabeledContent("Malzeme", value: analysis.materialCost.currencyFormatted)
                    LabeledContent("Makine", value: analysis.machineCost.currencyFormatted)
                    LabeledContent("Nakliye", value: analysis.transportCost.currencyFormatted)
                    Divider()
                    LabeledContent("Direkt Maliyet") {
                        Text(analysis.directCost.currencyFormatted).bold()
                    }
                    LabeledContent("Genel Gider (%\(Int(analysis.overheadRate)))",
                                   value: (analysis.directCost * analysis.overheadRate / 100).currencyFormatted)
                    LabeledContent("Kar (%\(Int(analysis.profitRate)))",
                                   value: (analysis.directCost * (1 + analysis.overheadRate/100) * analysis.profitRate / 100).currencyFormatted)
                    LabeledContent("Analiz Birim Fiyatı") {
                        Text(analysis.totalCost.currencyFormatted)
                            .font(.headline).foregroundColor(.hakedisOrange)
                    }
                }

                Section("Sözleşme Karşılaştırması") {
                    LabeledContent("Sözleşme Birim Fiyatı",
                                   value: analysis.contractUnitPrice.currencyFormatted)
                    LabeledContent(analysis.isSavings ? "Tasarruf" : "Aşım") {
                        HStack(spacing: 4) {
                            Image(systemName: analysis.isSavings ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            Text(abs(analysis.diff).currencyFormatted)
                        }
                        .foregroundColor(analysis.isSavings ? .hakedisSuccess : .hakedisDanger)
                        .font(.subheadline.bold())
                    }
                }

                if !marketEntries.isEmpty {
                    Section("Piyasa Araştırması (\(marketEntries.count) tedarikçi)") {
                        ForEach(marketEntries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.supplierName).font(.subheadline.bold())
                                    Spacer()
                                    Text(entry.price.currencyFormatted)
                                        .foregroundColor(.hakedisOrange)
                                }
                                HStack {
                                    Text(entry.date.shortFormatted)
                                        .font(.caption).foregroundColor(.secondary)
                                    if !entry.reason.isEmpty {
                                        Text("· \(entry.reason)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        let prices = marketEntries.map { $0.price }
                        if !prices.isEmpty {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Min").font(.caption2).foregroundColor(.secondary)
                                    Text((prices.min() ?? 0).currencyFormatted)
                                        .font(.caption.bold()).foregroundColor(.hakedisSuccess)
                                }
                                Spacer()
                                VStack {
                                    Text("Ort.").font(.caption2).foregroundColor(.secondary)
                                    Text((prices.reduce(0,+)/Double(prices.count)).currencyFormatted)
                                        .font(.caption.bold())
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Maks").font(.caption2).foregroundColor(.secondary)
                                    Text((prices.max() ?? 0).currencyFormatted)
                                        .font(.caption.bold()).foregroundColor(.hakedisDanger)
                                }
                            }
                        }
                    }
                }

                if analysis.hasForeignCurrency, let code = analysis.currencyCode,
                   let rate = analysis.exchangeRate {
                    Section("Döviz Bilgisi") {
                        LabeledContent("Döviz", value: code)
                        LabeledContent("Kur", value: String(format: "%.4f ₺", rate))
                        if let d = analysis.exchangeRateDate {
                            LabeledContent("Kur Tarihi", value: d.shortFormatted)
                        }
                    }
                }
            }
            .navigationTitle(analysis.analysisNo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Kapat") { dismiss() } }
            }
        }
    }
}
