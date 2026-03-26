import SwiftUI
import SwiftData

// MARK: - ShareableCSV
struct ShareableCSV: Transferable, Identifiable {
    let id = UUID()
    let content: String
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { csv in
            Data(csv.content.utf8)
        }
    }
}

extension View {
    func shareSheet(item: Binding<ShareableCSV?>) -> some View {
        sheet(item: item) { csv in
            if let url = csv.temporaryURL() {
                ShareSheet(items: [url])
                    .ignoresSafeArea()
            }
        }
    }
}

extension ShareableCSV {
    func temporaryURL() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

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
                    .foregroundColor(.secondary)
                Spacer()
                Text(contract.totalContractAmount.currencyFormatted)
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
            }
            Text("\(contract.workItems.count) iş kalemi")
                .font(.caption2)
                .foregroundColor(.secondary)
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
    @State private var kdvRate = 0.0
    @State private var selectedContractor: Contractor?
    @State private var hasDeadline = false
    @State private var completionDeadline = Date()
    @State private var dailyPenaltyRate = 0.1
    @State private var maxPenaltyRate = 20.0

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
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Taşeron Seç", selection: $selectedContractor) {
                            Text("Seçiniz").tag(Optional<Contractor>.none)
                            ForEach(contractors) { c in
                                Text(c.name).tag(Optional(c))
                            }
                        }
                    }
                }

                Section {
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
                    HStack {
                        Text("KDV Oranı")
                        Spacer()
                        Picker("KDV", selection: $kdvRate) {
                            Text("KDV Yok").tag(0.0)
                            Text("%1").tag(1.0)
                            Text("%10").tag(10.0)
                            Text("%20").tag(20.0)
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Kesinti ve Vergi Oranları")
                } footer: {
                    Text("KDV, teminat ve avans kesintisi yapıldıktan sonraki net tutara uygulanır.")
                        .font(.caption)
                }

                Section("Gecikme Cezası") {
                    Toggle("Bitiş tarihi ve ceza oranı tanımla", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Sözleşme Bitiş Tarihi", selection: $completionDeadline, displayedComponents: .date)
                        HStack {
                            Text("Günlük Ceza Oranı")
                            Spacer()
                            TextField("0.1", value: $dailyPenaltyRate, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("%")
                        }
                        HStack {
                            Text("Maksimum Ceza Tavanı")
                            Spacer()
                            TextField("20", value: $maxPenaltyRate, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("%")
                        }
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
        contract.kdvRate = kdvRate
        contract.project = project
        contract.contractor = selectedContractor
        if hasDeadline {
            contract.completionDeadline = completionDeadline
            contract.dailyPenaltyRate = dailyPenaltyRate
            contract.maxPenaltyRate = maxPenaltyRate
        }
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
    @State private var showingPenaltyCalc = false
    @State private var showingCSVPicker = false
    @State private var csvImportResult: CSVImportResult?
    @State private var showingImportPreview = false
    @State private var exportItem: ShareableCSV?

    private var delayDays: Int { contract.delayDays() }
    private var isOverdue: Bool { delayDays > 0 }

    var body: some View {
        List {
            // Summary
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Toplam Tutar")
                                .font(.caption).foregroundColor(.secondary)
                            Text(contract.totalContractAmount.currencyFormatted)
                                .font(.title2.bold())
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            VStack(alignment: .trailing) {
                                Text("Teminat")
                                    .font(.caption).foregroundColor(.secondary)
                                Text("%\(Int(contract.retentionRate))")
                                    .font(.headline)
                            }
                            if contract.advanceRate > 0 {
                                VStack(alignment: .trailing) {
                                    Text("Avans")
                                        .font(.caption).foregroundColor(.secondary)
                                    Text("%\(Int(contract.advanceRate))")
                                        .font(.headline).foregroundColor(.hakedisWarning)
                                }
                            }
                            if contract.kdvRate > 0 {
                                VStack(alignment: .trailing) {
                                    Text("KDV")
                                        .font(.caption).foregroundColor(.secondary)
                                    Text("%\(Int(contract.kdvRate))")
                                        .font(.headline).foregroundColor(.hakedisOrange)
                                }
                            }
                        }
                    }
                    LabeledContent("Taşeron", value: contract.contractor?.name ?? "—")
                    LabeledContent("Tarih", value: contract.contractDate.shortFormatted)

                    if let deadline = contract.completionDeadline {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sözleşme Bitiş").font(.caption).foregroundColor(.secondary)
                                Text(deadline.shortFormatted).font(.subheadline.bold())
                            }
                            Spacer()
                            if isOverdue {
                                StatusBadge(text: "\(delayDays) gün gecikme", color: .hakedisDanger)
                            } else {
                                let remaining = -delayDays
                                StatusBadge(text: remaining == 0 ? "Bugün bitiyor" : "\(remaining) gün kaldı",
                                            color: remaining <= 7 ? .hakedisWarning : .hakedisSuccess)
                            }
                        }
                        Button {
                            showingPenaltyCalc = true
                        } label: {
                            Label("Gecikme Cezası Hesapla", systemImage: "calendar.badge.exclamationmark")
                                .font(.subheadline)
                                .foregroundColor(isOverdue ? .hakedisDanger : .hakedisOrange)
                        }
                    }
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
                    .foregroundColor(.hakedisOrange)
                    Button {
                        showingCSVPicker = true
                    } label: {
                        Label("CSV'den İçe Aktar", systemImage: "doc.badge.arrow.up")
                    }
                    .foregroundColor(.hakedisOrange)
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
                    if !contract.workItems.isEmpty {
                        Button {
                            exportItem = ShareableCSV(
                                content: CSVExporter.exportWorkItems(contract),
                                filename: "\(contract.title)_pozlar.csv"
                            )
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button {
                        showingCSVPicker = true
                    } label: {
                        Image(systemName: "doc.badge.arrow.up")
                            .foregroundColor(.hakedisOrange)
                    }
                    Button {
                        showingAddWorkItem = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.hakedisOrange)
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
                    .foregroundColor(.hakedisOrange)
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
                            .foregroundColor(.hakedisOrange)
                    }
                }
            }
        }
        .navigationTitle(contract.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: ContractRevisionHistoryView(contract: contract)) {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(isPresented: $showingAddWorkItem) {
            AddWorkItemView(contract: contract)
        }
        .sheet(isPresented: $showingAddHakedis) {
            AddHakedisView(contract: contract)
        }
        .sheet(isPresented: $showingPenaltyCalc) {
            DelayPenaltyCalculatorView(contract: contract)
        }
        .sheet(isPresented: $showingCSVPicker) {
            CSVDocumentPicker { content in
                let result = WorkItemCSVParser.parse(content)
                csvImportResult = result
                showingCSVPicker = false
                if !result.rows.isEmpty {
                    showingImportPreview = true
                }
            }
        }
        .sheet(isPresented: $showingImportPreview) {
            if let result = csvImportResult {
                CSVImportPreviewView(result: result) { rows in
                    for row in rows {
                        let item = WorkItem(
                            code: row.code, name: row.name, unit: row.unit,
                            unitPrice: row.unitPrice, contractedQuantity: row.contractedQuantity,
                            location: row.location
                        )
                        item.contract = contract
                        contract.workItems.append(item)
                        modelContext.insert(item)
                    }
                }
            }
        }
        .shareSheet(item: $exportItem)
    }
}

// MARK: - Delay Penalty Calculator
struct DelayPenaltyCalculatorView: View {
    let contract: Contract
    @Environment(\.dismiss) private var dismiss
    @State private var completionDate = Date()

    private var deadline: Date { contract.completionDeadline ?? Date() }
    private var delayDays: Int {
        let d = Calendar.current.dateComponents([.day], from: deadline, to: completionDate).day ?? 0
        return max(0, d)
    }
    private var contractAmount: Double { contract.totalContractAmount }
    private var dailyPenalty: Double { contractAmount * (contract.dailyPenaltyRate / 100) }
    private var rawPenalty: Double { dailyPenalty * Double(delayDays) }
    private var maxPenalty: Double { contractAmount * (contract.maxPenaltyRate / 100) }
    private var totalPenalty: Double { min(rawPenalty, maxPenalty) }
    private var isCapped: Bool { rawPenalty > maxPenalty && delayDays > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sözleşme") {
                    LabeledContent("Sözleşme", value: contract.title)
                    LabeledContent("Sözleşme Tutarı", value: contractAmount.currencyFormatted)
                    LabeledContent("Bitiş Tarihi", value: deadline.shortFormatted)
                    LabeledContent("Günlük Ceza Oranı", value: "%\(contract.dailyPenaltyRate.quantityFormatted)")
                    LabeledContent("Maksimum Ceza Tavanı", value: "%\(Int(contract.maxPenaltyRate))")
                }

                Section("Fiili Tamamlanma") {
                    DatePicker("Tamamlanma Tarihi", selection: $completionDate, displayedComponents: .date)
                }

                Section("Hesap Sonucu") {
                    if delayDays == 0 {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.hakedisSuccess)
                            Text("Gecikme yok — ceza uygulanmaz")
                                .foregroundColor(.hakedisSuccess)
                        }
                    } else {
                        LabeledContent("Gecikme Süresi") {
                            Text("\(delayDays) gün")
                                .bold().foregroundColor(.hakedisDanger)
                        }
                        LabeledContent("Günlük Ceza Tutarı") {
                            Text(dailyPenalty.currencyFormatted)
                        }
                        LabeledContent("Hesaplanan Ceza") {
                            Text(rawPenalty.currencyFormatted)
                                .foregroundColor(isCapped ? .secondary : .hakedisDanger)
                        }
                        if isCapped {
                            LabeledContent("Uygulanan Ceza (Tavan)") {
                                Text(totalPenalty.currencyFormatted)
                                    .bold().foregroundColor(.hakedisDanger)
                            }
                            Text("Hesaplanan ceza maksimum ceza tavanını (%\(Int(contract.maxPenaltyRate))) aştığı için \(maxPenalty.currencyFormatted) uygulandı.")
                                .font(.caption).foregroundColor(.secondary)
                        } else {
                            LabeledContent("Toplam Gecikme Cezası") {
                                Text(totalPenalty.currencyFormatted)
                                    .bold().foregroundColor(.hakedisDanger)
                            }
                        }
                        Divider()
                        LabeledContent("Ceza Sonrası Net Tutar") {
                            Text((contractAmount - totalPenalty).currencyFormatted)
                                .bold().foregroundColor(.hakedisOrange)
                        }
                    }
                }
            }
            .navigationTitle("Gecikme Cezası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
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
                    .foregroundColor(.secondary)
                Text(workItem.name)
                    .font(.subheadline.bold())
            }
            HStack {
                Text("\(workItem.completedQuantity.quantityFormatted) / \(workItem.contractedQuantity.quantityFormatted) \(workItem.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(workItem.completionPercentage.percentFormatted)
                    .font(.caption.bold())
                    .foregroundColor(workItem.completionPercentage >= 100 ? .hakedisSuccess : .hakedisOrange)
            }
            ProgressBarView(
                progress: workItem.completionPercentage,
                color: workItem.completionPercentage >= 100 ? .hakedisSuccess : .hakedisOrange
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Poz Şablon Kütüphanesi

struct WorkItemTemplate {
    let code: String
    let name: String
    let unit: String
    let category: String
}

private let pozSablonlari: [WorkItemTemplate] = [
    // Kazı / Dolgu
    WorkItemTemplate(code: "16.001", name: "Makine ile kazı",           unit: "m³",  category: "Kazı/Dolgu"),
    WorkItemTemplate(code: "16.002", name: "El ile kazı",               unit: "m³",  category: "Kazı/Dolgu"),
    WorkItemTemplate(code: "16.003", name: "Granüler malzeme dolgu",    unit: "m³",  category: "Kazı/Dolgu"),
    WorkItemTemplate(code: "16.004", name: "Geri dolgu ve sıkıştırma",  unit: "m³",  category: "Kazı/Dolgu"),
    // Beton
    WorkItemTemplate(code: "15.001", name: "C20/25 Beton (kalıpsız)",   unit: "m³",  category: "Beton"),
    WorkItemTemplate(code: "15.002", name: "C25/30 Beton (kalıplı)",    unit: "m³",  category: "Beton"),
    WorkItemTemplate(code: "15.003", name: "C30/37 Beton",              unit: "m³",  category: "Beton"),
    WorkItemTemplate(code: "15.010", name: "Φ8-Φ12 Nervürlü çelik",    unit: "ton", category: "Beton"),
    WorkItemTemplate(code: "15.011", name: "Φ14-Φ32 Nervürlü çelik",   unit: "ton", category: "Beton"),
    WorkItemTemplate(code: "15.012", name: "Hasır çelik Q188",          unit: "ton", category: "Beton"),
    WorkItemTemplate(code: "15.020", name: "Ahşap kalıp",               unit: "m²",  category: "Beton"),
    // Duvar
    WorkItemTemplate(code: "20.001", name: "Tuğla duvar (19x19x38)",   unit: "m²",  category: "Duvar"),
    WorkItemTemplate(code: "20.002", name: "Gazbeton blok (10 cm)",     unit: "m²",  category: "Duvar"),
    WorkItemTemplate(code: "20.003", name: "Gazbeton blok (20 cm)",     unit: "m²",  category: "Duvar"),
    WorkItemTemplate(code: "20.004", name: "Briket duvar (19x19x38)",   unit: "m²",  category: "Duvar"),
    // Sıva / Boya
    WorkItemTemplate(code: "21.001", name: "İç cephe alçı sıva",       unit: "m²",  category: "Sıva/Boya"),
    WorkItemTemplate(code: "21.002", name: "Dış cephe çimento sıva",   unit: "m²",  category: "Sıva/Boya"),
    WorkItemTemplate(code: "21.003", name: "İç cephe su bazlı boya",   unit: "m²",  category: "Sıva/Boya"),
    WorkItemTemplate(code: "21.004", name: "Dış cephe silikonlu boya", unit: "m²",  category: "Sıva/Boya"),
    WorkItemTemplate(code: "21.005", name: "Alçıpan asma tavan",       unit: "m²",  category: "Sıva/Boya"),
    // Zemin / Kaplama
    WorkItemTemplate(code: "22.001", name: "Seramik zemin kaplama",    unit: "m²",  category: "Zemin"),
    WorkItemTemplate(code: "22.002", name: "Granit zemin kaplama",     unit: "m²",  category: "Zemin"),
    WorkItemTemplate(code: "22.003", name: "Laminant parke",           unit: "m²",  category: "Zemin"),
    WorkItemTemplate(code: "22.004", name: "Şap (50 kg/m²)",           unit: "m²",  category: "Zemin"),
    WorkItemTemplate(code: "22.005", name: "Mermer merdiven basamağı", unit: "adet", category: "Zemin"),
    // Çatı
    WorkItemTemplate(code: "23.001", name: "Alaturka kiremit çatı",   unit: "m²",  category: "Çatı"),
    WorkItemTemplate(code: "23.002", name: "Trapez sac çatı kaplama", unit: "m²",  category: "Çatı"),
    WorkItemTemplate(code: "23.003", name: "Isı yalıtımı XPS 5 cm",  unit: "m²",  category: "Çatı"),
    WorkItemTemplate(code: "23.004", name: "Su yalıtımı 2 kat bitüm",unit: "m²",  category: "Çatı"),
    // Doğrama
    WorkItemTemplate(code: "24.001", name: "PVC pencere (çift cam)",       unit: "m²",  category: "Doğrama"),
    WorkItemTemplate(code: "24.002", name: "Alüminyum sürgülü balkon kapı",unit: "m²",  category: "Doğrama"),
    WorkItemTemplate(code: "24.003", name: "Ahşap iç kapı (PVC kaplı)",    unit: "adet", category: "Doğrama"),
    WorkItemTemplate(code: "24.004", name: "Çelik dış kapı",               unit: "adet", category: "Doğrama"),
    // Elektrik
    WorkItemTemplate(code: "30.001", name: "Tesisat borusu + kablo",  unit: "m",    category: "Elektrik"),
    WorkItemTemplate(code: "30.002", name: "Priz + anahtar montajı",  unit: "adet", category: "Elektrik"),
    WorkItemTemplate(code: "30.003", name: "Elektrik panosu montajı", unit: "adet", category: "Elektrik"),
    // Tesisat
    WorkItemTemplate(code: "31.001", name: "PPR boru tesisatı Ø20",   unit: "m",    category: "Tesisat"),
    WorkItemTemplate(code: "31.002", name: "PVC pis su borusu Ø100",  unit: "m",    category: "Tesisat"),
    WorkItemTemplate(code: "31.003", name: "Banyo sıhhi tesisat seti",unit: "adet", category: "Tesisat"),
    WorkItemTemplate(code: "31.004", name: "Mutfak evye + armatür",   unit: "adet", category: "Tesisat"),
]

struct WorkItemTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (WorkItemTemplate) -> Void

    @State private var searchText = ""

    private var filtered: [WorkItemTemplate] {
        if searchText.isEmpty { return pozSablonlari }
        return pozSablonlari.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedFiltered: [(String, [WorkItemTemplate])] {
        let dict = Dictionary(grouping: filtered, by: \.category)
        return dict.keys.sorted().map { ($0, dict[$0]!) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedFiltered, id: \.0) { category, templates in
                    Section(category) {
                        ForEach(templates, id: \.code) { template in
                            Button {
                                onSelect(template)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text("[\(template.code)]  ·  \(template.unit)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.hakedisOrange)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Poz veya kategori ara...")
            .navigationTitle("Poz Şablonları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
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
    @State private var showingTemplatePicker = false

    let units = ["m²", "m³", "m", "adet", "ton", "kg", "lt", "saat", "gün"]

    var isValid: Bool {
        !code.isEmpty && !name.isEmpty &&
        Double(unitPrice.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(contractedQuantity.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("Şablondan Seç", systemImage: "list.bullet.rectangle")
                            .foregroundColor(.hakedisOrange)
                    }
                } footer: {
                    Text("Sık kullanılan pozları kütüphaneden seçerek hızlıca ekleyin.")
                        .font(.caption)
                }

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
                        Text(unit).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Birim Fiyat *")
                        Spacer()
                        TextField("0,00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("₺").foregroundColor(.secondary)
                    }
                }

                if let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")),
                   let qty = Double(contractedQuantity.replacingOccurrences(of: ",", with: ".")) {
                    Section("Toplam Tutar") {
                        Text((price * qty).currencyFormatted)
                            .font(.headline)
                            .foregroundColor(.hakedisOrange)
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
            .sheet(isPresented: $showingTemplatePicker) {
                WorkItemTemplatePicker { template in
                    code = template.code
                    name = template.name
                    unit = template.unit
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
                            .foregroundColor(.hakedisOrange)
                    }
                    ProgressBarView(progress: workItem.completionPercentage, color: .hakedisOrange)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Yapılan").font(.caption).foregroundColor(.secondary)
                            Text("\(workItem.completedQuantity.quantityFormatted) \(workItem.unit)")
                                .font(.subheadline.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Sözleşme").font(.caption).foregroundColor(.secondary)
                            Text("\(workItem.contractedQuantity.quantityFormatted) \(workItem.unit)")
                                .font(.subheadline.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Kalan").font(.caption).foregroundColor(.secondary)
                            Text("\(workItem.remainingQuantity.quantityFormatted) \(workItem.unit)")
                                .font(.subheadline.bold())
                                .foregroundColor(workItem.remainingQuantity < 0 ? .hakedisDanger : .primary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Günlük Girişler") {
                if workItem.dailyEntries.isEmpty {
                    Text("Henüz giriş yapılmadı")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(workItem.dailyEntries.sorted { $0.date > $1.date }) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.date.shortFormatted)
                                    .font(.subheadline.bold())
                                if !entry.location.isEmpty {
                                    Text(entry.location)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(entry.quantity.quantityFormatted) \(workItem.unit)")
                                .font(.subheadline)
                                .foregroundColor(.hakedisOrange)
                        }
                    }
                }
            }
        }
        .navigationTitle(workItem.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
