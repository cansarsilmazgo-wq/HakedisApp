import SwiftUI
import SwiftData

// MARK: - JSON Helpers

struct DimensionEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var description: String = ""
    var length: Double = 0
    var width: Double?
    var height: Double?
}

struct DeductionEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var description: String = ""
    var quantity: Double = 0
}

func decodeDimensions(_ json: String?) -> [DimensionEntry] {
    guard let data = json?.data(using: .utf8),
          let items = try? JSONDecoder().decode([DimensionEntry].self, from: data)
    else { return [] }
    return items
}

func decodeDeductions(_ json: String?) -> [DeductionEntry] {
    guard let data = json?.data(using: .utf8),
          let items = try? JSONDecoder().decode([DeductionEntry].self, from: data)
    else { return [] }
    return items
}

private func calcQuantity(_ dims: [DimensionEntry], type: MeasurementType) -> Double {
    dims.reduce(0) { sum, d in
        switch type {
        case .uzunluk: return sum + d.length
        case .alan:    return sum + d.length * (d.width ?? 1)
        case .hacim:   return sum + d.length * (d.width ?? 1) * (d.height ?? 1)
        case .adet:    return sum + d.length
        }
    }
}

// MARK: - Measurement Book List Sheet

struct MeasurementBookListSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workItem: WorkItem

    @State private var showingAdd = false
    @State private var selectedEntry: MeasurementEntry?

    private var sorted: [MeasurementEntry] {
        workItem.measurementEntries.sorted { $0.date > $1.date }
    }

    private var cumulative: Double {
        sorted.reduce(0) { $0 + $1.netQuantity }
    }

    private var isOverContract: Bool {
        cumulative > workItem.contractedQuantity
    }

    var body: some View {
        NavigationStack {
            List {
                // Özet
                Section {
                    VStack(spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sözleşme").font(.caption2).foregroundColor(.secondary)
                                Text("\(workItem.contractedQuantity.quantityFormatted) \(workItem.unit)")
                                    .font(.subheadline.bold())
                            }
                            Spacer()
                            VStack(alignment: .center, spacing: 2) {
                                Text("Metraj Toplam").font(.caption2).foregroundColor(.secondary)
                                Text("\(cumulative.quantityFormatted) \(workItem.unit)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(isOverContract ? .hakedisDanger : .hakedisOrange)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Kalan").font(.caption2).foregroundColor(.secondary)
                                let rem = workItem.contractedQuantity - cumulative
                                Text("\(rem.quantityFormatted) \(workItem.unit)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(rem < 0 ? .hakedisDanger : .secondary)
                            }
                        }
                        ProgressBarView(
                            progress: workItem.contractedQuantity > 0
                                ? cumulative / workItem.contractedQuantity * 100 : 0,
                            color: isOverContract ? .hakedisDanger : .hakedisOrange
                        )
                    }
                    .padding(.vertical, 4)
                }

                if sorted.isEmpty {
                    EmptyStateView(
                        icon: "ruler",
                        title: "Henüz metraj yok",
                        subtitle: "Bu iş kalemi için ölçüm girişi ekleyin",
                        actionTitle: "Ölçüm Ekle",
                        action: { showingAdd = true }
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("Ölçüm Girişleri") {
                        ForEach(sorted) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                MeasurementEntryRow(entry: entry, unit: workItem.unit)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            offsets.map { sorted[$0] }.forEach { modelContext.delete($0) }
                        }
                    }
                }
            }
            .navigationTitle("Metraj Defteri — \(workItem.code)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddMeasurementView(workItem: workItem)
            }
            .sheet(item: $selectedEntry) { entry in
                MeasurementEntryDetailView(entry: entry, unit: workItem.unit)
            }
        }
    }
}

// MARK: - Measurement Entry Row

struct MeasurementEntryRow: View {
    let entry: MeasurementEntry
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.entryNo)
                    .font(.caption.monospaced()).foregroundColor(.secondary)
                Spacer()
                if entry.isVerified {
                    StatusBadge(text: "Doğrulandı", color: .hakedisSuccess)
                } else {
                    StatusBadge(text: "Taslak", color: .secondary)
                }
            }
            Text(entry.location.isEmpty ? "Konum belirtilmedi" : entry.location)
                .font(.subheadline)
                .lineLimit(1)
            HStack {
                Text(entry.date.shortFormatted)
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if entry.calculatedQuantity != entry.netQuantity {
                        Text("Brüt: \(entry.calculatedQuantity.quantityFormatted) \(unit)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Text("Net: \(entry.netQuantity.quantityFormatted) \(unit)")
                        .font(.caption.bold()).foregroundColor(.hakedisOrange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Measurement View

struct AddMeasurementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workItem: WorkItem

    @State private var location = ""
    @State private var date = Date()
    @State private var measurementType: MeasurementType = .alan
    @State private var dimensions: [DimensionEntry] = [DimensionEntry()]
    @State private var deductions: [DeductionEntry] = []
    @State private var checkedBy = ""
    @State private var isVerified = false

    // Live calculations
    private var calcQty: Double {
        calcQuantity(dimensions, type: measurementType)
    }
    private var deductTotal: Double {
        deductions.reduce(0) { $0 + $1.quantity }
    }
    private var netQty: Double {
        max(0, calcQty - deductTotal)
    }
    private var isOverContract: Bool {
        let existing = workItem.measurementEntries.reduce(0) { $0 + $1.netQuantity }
        return existing + netQty > workItem.contractedQuantity
    }

    private var nextEntryNo: String {
        let year = Calendar.current.component(.year, from: Date())
        let seq = workItem.measurementEntries.count + 1
        return "MB-\(year)-\(String(format: "%03d", seq))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Temel Bilgi") {
                    LabeledContent("No", value: nextEntryNo)
                    LabeledContent("Poz", value: "[\(workItem.code)] \(workItem.name)")
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    TextField("Konum / Açıklama", text: $location)
                    Picker("Ölçüm Türü", selection: $measurementType) {
                        ForEach(MeasurementType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }

                // Boyutlar
                Section {
                    ForEach($dimensions) { $dim in
                        DimensionInputRow(dim: $dim, type: measurementType)
                    }
                    .onDelete { dimensions.remove(atOffsets: $0) }

                    Button {
                        dimensions.append(DimensionEntry())
                    } label: {
                        Label("Ölçüm Satırı Ekle", systemImage: "plus.circle")
                            .foregroundColor(.hakedisOrange)
                    }
                } header: {
                    HStack {
                        Text("Ölçümler (\(measurementType.formula))")
                        Spacer()
                        Text("Toplam: \(calcQty.quantityFormatted)")
                            .font(.caption).foregroundColor(.hakedisOrange)
                    }
                }

                // Düşülecekler
                if calcQty > 0 {
                    Section {
                        if deductions.isEmpty {
                            Text("Düşülecek alan/hacim yok")
                                .font(.caption).foregroundColor(.secondary)
                        } else {
                            ForEach($deductions) { $ded in
                                HStack {
                                    TextField("Açıklama (kap., pencere…)", text: $ded.description)
                                    Spacer()
                                    TextField("0.00", value: $ded.quantity, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 70)
                                    Text(workItem.unit).foregroundColor(.secondary)
                                }
                            }
                            .onDelete { deductions.remove(atOffsets: $0) }
                        }
                        Button {
                            deductions.append(DeductionEntry())
                        } label: {
                            Label("Düşülen Ekle", systemImage: "minus.circle")
                                .foregroundColor(.hakedisDanger)
                        }
                    } header: {
                        HStack {
                            Text("Düşülecekler")
                            Spacer()
                            if deductTotal > 0 {
                                Text("−\(deductTotal.quantityFormatted)").font(.caption)
                                    .foregroundColor(.hakedisDanger)
                            }
                        }
                    }
                }

                // Özet
                Section("Hesap Özeti") {
                    if calcQty != netQty {
                        LabeledContent("Brüt", value: "\(calcQty.quantityFormatted) \(workItem.unit)")
                        LabeledContent("Düşülen", value: "−\(deductTotal.quantityFormatted) \(workItem.unit)")
                    }
                    LabeledContent("Net Miktar") {
                        Text("\(netQty.quantityFormatted) \(workItem.unit)")
                            .font(.headline)
                            .foregroundColor(isOverContract ? .hakedisDanger : .hakedisOrange)
                    }
                    if isOverContract {
                        Label("Sözleşme miktarı aşılıyor!", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundColor(.hakedisDanger)
                    }
                }

                Section("Onay") {
                    TextField("Kontrol Eden", text: $checkedBy)
                    Toggle("Doğrulandı", isOn: $isVerified)
                }
            }
            .navigationTitle("Metraj Girişi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .bold()
                        .disabled(netQty <= 0)
                }
            }
        }
    }

    private func save() {
        let entry = MeasurementEntry(
            entryNo: nextEntryNo,
            workItemCode: workItem.code,
            location: location,
            measurementType: measurementType,
            previousEntries: workItem.measurementEntries.reduce(0) { $0 + $1.netQuantity }
        )
        entry.date = date
        entry.checkedBy = checkedBy.isEmpty ? nil : checkedBy
        entry.isVerified = isVerified

        let enc = JSONEncoder()
        entry.dimensionsJSON = try? String(data: enc.encode(dimensions), encoding: .utf8)
        entry.deductionsJSON = deductions.isEmpty ? nil : (try? String(data: enc.encode(deductions), encoding: .utf8))
        entry.calculatedQuantity = calcQty
        entry.netQuantity = netQty
        entry.workItem = workItem
        workItem.measurementEntries.append(entry)
        modelContext.insert(entry)
        dismiss()
    }
}

// MARK: - Dimension Input Row

struct DimensionInputRow: View {
    @Binding var dim: DimensionEntry
    let type: MeasurementType

    private var subtotal: Double {
        switch type {
        case .uzunluk, .adet: return dim.length
        case .alan:  return dim.length * (dim.width ?? 1)
        case .hacim: return dim.length * (dim.width ?? 1) * (dim.height ?? 1)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            TextField("Açıklama (opsiyonel)", text: $dim.description)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                DimField(label: "L", value: $dim.length)
                if type.usesWidth {
                    Text("×").foregroundColor(.secondary)
                    DimField(label: "G", value: Binding(
                        get: { dim.width ?? 0 },
                        set: { dim.width = $0 == 0 ? nil : $0 }
                    ))
                }
                if type.usesHeight {
                    Text("×").foregroundColor(.secondary)
                    DimField(label: "Y", value: Binding(
                        get: { dim.height ?? 0 },
                        set: { dim.height = $0 == 0 ? nil : $0 }
                    ))
                }
                Spacer()
                Text("= \(subtotal.quantityFormatted)")
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
                    .frame(width: 72, alignment: .trailing)
            }
        }
    }
}

private struct DimField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4).padding(.vertical, 4)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 60)
        }
    }
}

// MARK: - Measurement Entry Detail

struct MeasurementEntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: MeasurementEntry
    let unit: String

    private var dims: [DimensionEntry] { decodeDimensions(entry.dimensionsJSON) }
    private var deds: [DeductionEntry] { decodeDeductions(entry.deductionsJSON) }

    var body: some View {
        NavigationStack {
            List {
                Section("Genel Bilgi") {
                    LabeledContent("No", value: entry.entryNo)
                    LabeledContent("Tarih", value: entry.date.shortFormatted)
                    LabeledContent("Konum", value: entry.location.isEmpty ? "—" : entry.location)
                    LabeledContent("Ölçüm Türü", value: entry.measurementType.rawValue)
                    LabeledContent("Formül", value: entry.measurementType.formula)
                    if let cb = entry.checkedBy, !cb.isEmpty {
                        LabeledContent("Kontrol Eden", value: cb)
                    }
                    Toggle("Doğrulandı", isOn: $entry.isVerified)
                }

                if !dims.isEmpty {
                    Section("Ölçüm Satırları") {
                        ForEach(dims) { d in
                            HStack {
                                if !d.description.isEmpty {
                                    Text(d.description).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(dimensionText(d)).font(.caption.monospaced())
                            }
                        }
                        LabeledContent("Brüt Toplam") {
                            Text("\(entry.calculatedQuantity.quantityFormatted) \(unit)")
                                .bold()
                        }
                    }
                }

                if !deds.isEmpty {
                    Section("Düşülecekler") {
                        ForEach(deds) { d in
                            HStack {
                                Text(d.description).font(.subheadline)
                                Spacer()
                                Text("−\(d.quantity.quantityFormatted) \(unit)")
                                    .font(.subheadline).foregroundColor(.hakedisDanger)
                            }
                        }
                    }
                }

                Section("Sonuç") {
                    LabeledContent("Net Miktar") {
                        Text("\(entry.netQuantity.quantityFormatted) \(unit)")
                            .font(.headline).foregroundColor(.hakedisOrange)
                    }
                    LabeledContent("Kümülatif Toplam") {
                        Text("\(entry.cumulativeTotal.quantityFormatted) \(unit)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(entry.entryNo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Kapat") { dismiss() } }
            }
        }
    }

    private func dimensionText(_ d: DimensionEntry) -> String {
        var parts = [d.length.quantityFormatted]
        if let w = d.width  { parts.append(w.quantityFormatted) }
        if let h = d.height { parts.append(h.quantityFormatted) }
        return parts.joined(separator: " × ")
    }
}

// MARK: - Measurement Import Sheet (Hakediş oluştururken kullanılır)

struct MeasurementImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let contract: Contract
    let periodStart: Date
    let periodEnd: Date
    let onImport: ([String: Double]) -> Void   // workItemCode → netQuantity

    private var verifiedEntries: [(WorkItem, MeasurementEntry)] {
        contract.workItems.flatMap { wi in
            wi.measurementEntries
                .filter { $0.isVerified && $0.date >= periodStart && $0.date <= periodEnd }
                .map { (wi, $0) }
        }
    }

    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if verifiedEntries.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "ruler").font(.system(size: 48)).foregroundColor(.secondary)
                        Text("Bu dönemde doğrulanmış metraj girişi yok")
                            .font(.headline).foregroundColor(.secondary)
                        Text("Metraj Defteri'nde girişleri doğrulayarak buradan aktarabilirsiniz.")
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            Text("Seçilen metraj girişleri, günlük saha verisi yerine kullanılır.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        ForEach(verifiedEntries, id: \.1.id) { (wi, entry) in
                            HStack {
                                Image(systemName: selected.contains(entry.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selected.contains(entry.id)
                                                     ? .hakedisOrange : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("[\(wi.code)] \(wi.name)").font(.subheadline.bold()).lineLimit(1)
                                    Text("\(entry.entryNo) · \(entry.location)").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(entry.netQuantity.quantityFormatted) \(wi.unit)")
                                    .font(.caption.bold()).foregroundColor(.hakedisOrange)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selected.contains(entry.id) { selected.remove(entry.id) }
                                else { selected.insert(entry.id) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Metrajdan Aktar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aktar (\(selected.count))") {
                        var result: [String: Double] = [:]
                        for (wi, entry) in verifiedEntries where selected.contains(entry.id) {
                            result[wi.code] = (result[wi.code] ?? 0) + entry.netQuantity
                        }
                        onImport(result)
                        dismiss()
                    }
                    .bold()
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}
