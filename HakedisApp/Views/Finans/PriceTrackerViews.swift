import SwiftUI
import SwiftData

// MARK: - PriceTrackerDashboardView

struct PriceTrackerDashboardView: View {
    @Query private var trackers: [PriceTracker]
    @Query private var entries: [MarketPriceEntry]
    @State private var showAddTracker = false
    @State private var showAddPrice = false
    @State private var selectedTracker: PriceTracker?
    @Environment(\.modelContext) private var modelContext

    private var alertTrackers: [PriceTracker] {
        trackers.filter { $0.isOverThreshold }.sorted { abs($0.variancePercentage) > abs($1.variancePercentage) }
    }

    private var totalCostImpact: Double {
        trackers.reduce(0) { $0 + $1.varianceAmount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.section) {
                    // Uyarı özeti
                    if !alertTrackers.isEmpty {
                        alertSummaryCard
                    }

                    // Toplam maliyet etkisi
                    StatCard(
                        title: "Toplam Maliyet Etkisi",
                        value: totalCostImpact.currencyFormatted,
                        subtitle: "\(trackers.count) malzeme takip ediliyor",
                        color: totalCostImpact > 0 ? .hakedisDanger : .hakedisSuccess,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                    .padding(.horizontal, Spacing.md)

                    // En çok artan
                    if !trackers.isEmpty {
                        topVarianceSection
                    }

                    // Tüm malzemeler
                    allMaterialsSection
                }
                .padding(.vertical, Spacing.md)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Fiyat Takibi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Malzeme Ekle") { showAddTracker = true }
                        Button("Piyasa Fiyatı Gir") { showAddPrice = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Fiyat Takip Ekle")
                }
            }
            .sheet(isPresented: $showAddTracker) {
                AddPriceTrackerView()
            }
            .sheet(isPresented: $showAddPrice) {
                AddMarketPriceView()
            }
            .sheet(item: $selectedTracker) { tracker in
                PriceDetailView(tracker: tracker)
            }
        }
    }

    private var alertSummaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.hakedisDanger)
                Text("Fiyat Uyarıları")
                    .font(.headline)
                Spacer()
                Text("\(alertTrackers.count) Malzeme")
                    .font(.caption.bold())
                    .foregroundColor(.hakedisDanger)
            }
            ForEach(alertTrackers.prefix(3), id: \.id) { tracker in
                HStack {
                    Text(tracker.materialName)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%+.1f%%", tracker.variancePercentage))
                        .font(.subheadline.bold())
                        .foregroundColor(.hakedisDanger)
                }
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisDanger.opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hakedisDanger, lineWidth: 1))
        .padding(.horizontal, Spacing.md)
    }

    private var topVarianceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader("En Çok Artan")
            ForEach(trackers.sorted { $0.variancePercentage > $1.variancePercentage }.prefix(5), id: \.id) { tracker in
                Button {
                    selectedTracker = tracker
                } label: {
                    priceTrackerRow(tracker)
                }
                .accessibilityLabel("\(tracker.materialName): \(String(format: "%.1f", tracker.variancePercentage))% sapma")
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private var allMaterialsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader("Tüm Malzemeler") { showAddTracker = true }
            if trackers.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Malzeme Yok",
                    subtitle: "Fiyat takibi başlatmak için malzeme ekleyin.",
                    actionTitle: "Malzeme Ekle"
                ) { showAddTracker = true }
            } else {
                ForEach(trackers, id: \.id) { tracker in
                    Button {
                        selectedTracker = tracker
                    } label: {
                        priceTrackerRow(tracker)
                    }
                    .accessibilityLabel("\(tracker.materialName) fiyat detayı")
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private func priceTrackerRow(_ tracker: PriceTracker) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.materialName)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                HStack {
                    Text("Sözleşme: \(tracker.contractPrice.currencyFormatted)/\(tracker.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("Güncel: \(tracker.currentMarketPrice.currencyFormatted)/\(tracker.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(String(format: "%+.1f%%", tracker.variancePercentage))
                    .font(.headline.bold())
                    .foregroundColor(tracker.isOverThreshold ? .hakedisDanger :
                                     tracker.variancePercentage > 0 ? .hakedisWarning : .hakedisSuccess)
                Text(tracker.varianceAmount.currencyFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .cornerRadius(10)
    }
}

// MARK: - AddPriceTrackerView

struct AddPriceTrackerView: View {
    @State private var materialName = ""
    @State private var unit = "ton"
    @State private var contractPriceText = ""
    @State private var currentPriceText = ""
    @State private var alertThresholdText = "10"
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let units = ["ton", "m³", "kg", "adet", "m²", "m", "lt", "çuval"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Malzeme") {
                    TextField("Malzeme adı (Çimento, Demir...)", text: $materialName)
                    Picker("Birim", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Fiyatlar") {
                    TextField("Sözleşme birim fiyatı (₺)", text: $contractPriceText)
                        .keyboardType(.decimalPad)
                    TextField("Güncel piyasa fiyatı (₺)", text: $currentPriceText)
                        .keyboardType(.decimalPad)
                }
                Section("Uyarı Eşiği") {
                    HStack {
                        TextField("Eşik %", text: $alertThresholdText)
                            .keyboardType(.decimalPad)
                        Text("%")
                    }
                    Text("Sapma bu değeri aşınca kırmızı uyarı verilir.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Malzeme Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        save()
                        dismiss()
                    }
                    .disabled(materialName.isEmpty || contractPriceText.isEmpty)
                }
            }
        }
    }

    private func save() {
        let contract = Double(contractPriceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let current = Double(currentPriceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let threshold = Double(alertThresholdText.replacingOccurrences(of: ",", with: ".")) ?? 10
        let tracker = PriceTracker(materialName: materialName, unit: unit, contractPrice: contract, currentMarketPrice: current)
        tracker.alertThreshold = threshold
        modelContext.insert(tracker)
        do { try modelContext.save() } catch { }
    }
}

// MARK: - AddMarketPriceView

struct AddMarketPriceView: View {
    @Query private var trackers: [PriceTracker]
    @State private var materialName = ""
    @State private var selectedTracker: PriceTracker?
    @State private var supplierName = ""
    @State private var unitPriceText = ""
    @State private var unit = "ton"
    @State private var region = ""
    @State private var source = "Piyasa araştırması"
    @State private var notes = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let sources = ["Piyasa araştırması", "Teklif", "İrsaliye", "Katalog"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Malzeme Seçimi") {
                    if !trackers.isEmpty {
                        Picker("Takip edilen malzeme", selection: $selectedTracker) {
                            Text("Manuel giriş").tag(Optional<PriceTracker>.none)
                            ForEach(trackers, id: \.id) { t in
                                Text(t.materialName).tag(Optional(t))
                            }
                        }
                        .onChange(of: selectedTracker) { _, t in
                            if let t {
                                materialName = t.materialName
                                unit = t.unit
                            }
                        }
                    }
                    if selectedTracker == nil {
                        TextField("Malzeme adı", text: $materialName)
                    }
                }
                Section("Fiyat Bilgisi") {
                    TextField("Birim fiyat (₺)", text: $unitPriceText)
                        .keyboardType(.decimalPad)
                    TextField("Birim", text: $unit)
                    TextField("Tedarikçi (opsiyonel)", text: $supplierName)
                }
                Section("Kaynak") {
                    Picker("Kaynak", selection: $source) {
                        ForEach(sources, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Bölge (İstanbul, Ankara...)", text: $region)
                }
                Section("Not") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 40)
                }
            }
            .navigationTitle("Piyasa Fiyatı Gir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        save()
                        dismiss()
                    }
                    .disabled(materialName.isEmpty || unitPriceText.isEmpty)
                }
            }
        }
    }

    private func save() {
        let price = Double(unitPriceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let entry = MarketPriceEntry(materialName: materialName, unitPrice: price, unit: unit)
        entry.supplierName = supplierName.isEmpty ? nil : supplierName
        entry.region = region.isEmpty ? nil : region
        entry.source = source
        entry.notes = notes.isEmpty ? nil : notes
        modelContext.insert(entry)

        // İlgili tracker varsa güncelle
        if let tracker = selectedTracker {
            tracker.addPricePoint(price: price)
        }

        do { try modelContext.save() } catch { }
    }
}

// MARK: - PriceAlertView

struct PriceAlertView: View {
    @Query private var trackers: [PriceTracker]

    private var alertTrackers: [PriceTracker] {
        trackers.filter { $0.isOverThreshold }
            .sorted { abs($0.variancePercentage) > abs($1.variancePercentage) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if alertTrackers.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.shield.fill",
                        title: "Uyarı Yok",
                        subtitle: "Hiçbir malzemenin fiyatı eşiği aşmıyor."
                    )
                } else {
                    List {
                        ForEach(alertTrackers, id: \.id) { tracker in
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.hakedisDanger)
                                    Text(tracker.materialName)
                                        .font(.headline)
                                    Spacer()
                                    Text(String(format: "%+.1f%%", tracker.variancePercentage))
                                        .font(.headline.bold())
                                        .foregroundColor(.hakedisDanger)
                                }
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Sözleşme: \(tracker.contractPrice.currencyFormatted)/\(tracker.unit)")
                                            .font(.caption)
                                        Text("Güncel: \(tracker.currentMarketPrice.currencyFormatted)/\(tracker.unit)")
                                            .font(.caption)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Fark:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(tracker.varianceAmount.currencyFormatted)
                                            .font(.caption.bold())
                                            .foregroundColor(.hakedisDanger)
                                    }
                                }
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Fiyat Uyarıları")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - PriceDetailView

struct PriceDetailView: View {
    let tracker: PriceTracker
    @State private var newPriceText = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Malzeme Bilgisi") {
                    LabeledContent("Malzeme", value: tracker.materialName)
                    LabeledContent("Birim", value: tracker.unit)
                    LabeledContent("Sözleşme Fiyatı", value: tracker.contractPrice.currencyFormatted)
                    LabeledContent("Güncel Fiyat", value: tracker.currentMarketPrice.currencyFormatted)
                    LabeledContent("Sapma", value: String(format: "%+.2f%%", tracker.variancePercentage))
                    LabeledContent("Fark (₺)", value: tracker.varianceAmount.currencyFormatted)
                    LabeledContent("Son Güncelleme", value: tracker.lastUpdateDate.formatted(date: .abbreviated, time: .omitted))
                }

                Section("Fiyat Güncelle") {
                    HStack {
                        TextField("Yeni piyasa fiyatı (₺)", text: $newPriceText)
                            .keyboardType(.decimalPad)
                        Button("Güncelle") {
                            if let price = Double(newPriceText.replacingOccurrences(of: ",", with: ".")) {
                                tracker.addPricePoint(price: price)
                                do { try modelContext.save() } catch { }
                                newPriceText = ""
                            }
                        }
                        .foregroundColor(.hakedisOrange)
                        .disabled(newPriceText.isEmpty)
                    }
                }

                Section("Fiyat Geçmişi (\(tracker.priceHistory.count) kayıt)") {
                    if tracker.priceHistory.isEmpty {
                        Text("Henüz geçmiş kayıt yok.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(tracker.priceHistory.reversed(), id: \.date) { point in
                            HStack {
                                Text(point.date.prefix(10))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(point.price.currencyFormatted)
                                    .font(.caption.bold())
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(tracker.materialName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
