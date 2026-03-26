import SwiftUI
import SwiftData

// MARK: - Revision Type

enum RevisionType: String, Codable, CaseIterable {
    case priceRevision    = "Fiyat Revizyonu"
    case quantityRevision = "Miktar Revizyonu"
    case extraWork        = "Ek İş"
}

// MARK: - Revision Log Helpers

private struct RevisionRecord {
    let date: Date
    let type: String
    let change: String
    let reason: String

    /// Encode to single pipe-delimited string
    func encoded() -> String {
        let iso = ISO8601DateFormatter()
        return [iso.string(from: date), type, change, reason].joined(separator: "‖")
    }

    static func decode(_ raw: String) -> RevisionRecord? {
        let parts = raw.components(separatedBy: "‖")
        guard parts.count == 4 else { return nil }
        let iso = ISO8601DateFormatter()
        guard let d = iso.date(from: parts[0]) else { return nil }
        return RevisionRecord(date: d, type: parts[1], change: parts[2], reason: parts[3])
    }
}

// MARK: - Add Extra Work

struct AddExtraWorkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let contract: Contract
    @State private var code = ""
    @State private var name = ""
    @State private var unit = "m²"
    @State private var unitPrice = ""
    @State private var quantity = ""
    @State private var reason = ""
    @State private var isExtraWork = true
    let units = ["m²", "m³", "m", "adet", "ton", "kg", "lt", "saat", "gün"]

    var isValid: Bool {
        !code.isEmpty && !name.isEmpty
        && Double(unitPrice.replacingOccurrences(of: ",", with: ".")) != nil
        && Double(quantity.replacingOccurrences(of: ",", with: ".")) != nil
        && !reason.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("İşlem Türü", selection: $isExtraWork) {
                        Text("Ek İş").tag(true)
                        Text("Poz Revizyonu").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Poz Bilgileri") {
                    TextField("Poz No *", text: $code)
                    TextField("İş Kalemi Adı *", text: $name)
                    Picker("Birim", selection: $unit) { ForEach(units, id: \.self) { Text($0) } }
                    HStack {
                        Text("Miktar *"); Spacer()
                        TextField("0", text: $quantity)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text(unit).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Birim Fiyat *"); Spacer()
                        TextField("0", text: $unitPrice)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text("₺").foregroundColor(.secondary)
                    }
                }
                Section("Gerekçe") {
                    TextField("Sebebi *", text: $reason, axis: .vertical).lineLimit(3)
                }
                if let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")),
                   let qty   = Double(quantity.replacingOccurrences(of: ",", with: ".")) {
                    Section("Toplam") {
                        Text((price * qty).currencyFormatted)
                            .font(.headline).foregroundColor(.hakedisOrange)
                    }
                }
            }
            .navigationTitle(isExtraWork ? "Ek İş Ekle" : "Poz Revize Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(!isValid).bold()
                }
            }
        }
    }

    private func save() {
        let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        let qty   = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let finalCode = isExtraWork ? "EK-\(code)" : code
        let finalName = isExtraWork ? "EK: \(name)" : name
        let item = WorkItem(code: finalCode, name: finalName, unit: unit, unitPrice: price, contractedQuantity: qty)
        item.contract = contract

        // Log as extra work
        let rec = RevisionRecord(
            date: Date(),
            type: RevisionType.extraWork.rawValue,
            change: "Yeni: \(qty.quantityFormatted) \(unit) × \(price.currencyFormatted)",
            reason: reason
        )
        item.revisionHistory.append(rec.encoded())

        contract.workItems.append(item)
        modelContext.insert(item)
        dismiss()
    }
}

// MARK: - Revise Work Item

struct ReviseWorkItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workItem: WorkItem
    @State private var newUnitPrice: String
    @State private var newQuantity: String
    @State private var reason = ""
    @State private var revisionType: RevisionType = .priceRevision

    init(workItem: WorkItem) {
        self.workItem = workItem
        _newUnitPrice = State(initialValue: String(workItem.unitPrice))
        _newQuantity  = State(initialValue: String(workItem.contractedQuantity))
    }

    var isValid: Bool {
        Double(newUnitPrice.replacingOccurrences(of: ",", with: ".")) != nil
        && Double(newQuantity.replacingOccurrences(of: ",", with: ".")) != nil
        && !reason.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Revizyon Türü") {
                    Picker("Tür", selection: $revisionType) {
                        ForEach(RevisionType.allCases.filter { $0 != .extraWork }, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }
                Section("Mevcut") {
                    LabeledContent("Birim Fiyat", value: workItem.unitPrice.currencyFormatted)
                    LabeledContent("Miktar", value: "\(workItem.contractedQuantity.quantityFormatted) \(workItem.unit)")
                }
                Section("Yeni Değerler") {
                    HStack {
                        Text("Yeni Birim Fiyat"); Spacer()
                        TextField("0", text: $newUnitPrice)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text("₺").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Yeni Miktar"); Spacer()
                        TextField("0", text: $newQuantity)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text(workItem.unit).foregroundColor(.secondary)
                    }
                }
                if let price = Double(newUnitPrice.replacingOccurrences(of: ",", with: ".")),
                   let qty   = Double(newQuantity.replacingOccurrences(of: ",", with: ".")) {
                    Section("Fark") {
                        let diff = (price * qty) - workItem.totalAmount
                        HStack {
                            Text("Yeni Toplam"); Spacer()
                            Text((price * qty).currencyFormatted).bold().foregroundColor(.hakedisOrange)
                        }
                        HStack {
                            Text("Fark"); Spacer()
                            Text("\(diff >= 0 ? "+" : "")\(diff.currencyFormatted)")
                                .bold().foregroundColor(diff >= 0 ? .hakedisSuccess : .hakedisDanger)
                        }
                    }
                }
                Section("Gerekçe") {
                    TextField("Revizyon sebebi *", text: $reason, axis: .vertical).lineLimit(3)
                }

                if !workItem.revisionHistory.isEmpty {
                    Section("Geçmiş Revizyonlar (\(workItem.revisionHistory.count))") {
                        NavigationLink("Geçmişi Görüntüle") {
                            RevisionHistoryView(workItem: workItem)
                        }
                    }
                }
            }
            .navigationTitle("Poz Revize Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(!isValid).bold()
                }
            }
        }
    }

    private func save() {
        let price = Double(newUnitPrice.replacingOccurrences(of: ",", with: ".")) ?? workItem.unitPrice
        let qty   = Double(newQuantity.replacingOccurrences(of: ",", with: ".")) ?? workItem.contractedQuantity

        // Build change summary
        var changes: [String] = []
        if price != workItem.unitPrice {
            changes.append("Fiyat: \(workItem.unitPrice.currencyFormatted) → \(price.currencyFormatted)")
        }
        if qty != workItem.contractedQuantity {
            changes.append("Miktar: \(workItem.contractedQuantity.quantityFormatted) → \(qty.quantityFormatted) \(workItem.unit)")
        }
        let changeText = changes.isEmpty ? "Değişiklik yok" : changes.joined(separator: ", ")

        let rec = RevisionRecord(
            date: Date(),
            type: revisionType.rawValue,
            change: changeText,
            reason: reason
        )
        workItem.revisionHistory.append(rec.encoded())
        workItem.unitPrice = price
        workItem.contractedQuantity = qty
        dismiss()
    }
}

// MARK: - Revision History View (per WorkItem)

struct RevisionHistoryView: View {
    let workItem: WorkItem

    private var records: [RevisionRecord] {
        workItem.revisionHistory
            .compactMap { RevisionRecord.decode($0) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(
                    "Revizyon yok",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Bu poz için henüz revizyon yapılmamış")
                )
            } else {
                Section("\(workItem.code) — \(workItem.name)") {
                    LabeledContent("Güncel Fiyat",  value: workItem.unitPrice.currencyFormatted)
                    LabeledContent("Güncel Miktar", value: "\(workItem.contractedQuantity.quantityFormatted) \(workItem.unit)")
                    LabeledContent("Güncel Toplam", value: workItem.totalAmount.currencyFormatted)
                }

                Section("Revizyon Geçmişi (\(records.count))") {
                    ForEach(Array(records.enumerated()), id: \.offset) { idx, rec in
                        RevisionRecordRow(record: rec, index: records.count - idx)
                    }
                }
            }
        }
        .navigationTitle("Revizyon Geçmişi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RevisionRecordRow: View {
    let record: RevisionRecord
    let index: Int

    private var typeColor: Color {
        switch record.type {
        case RevisionType.priceRevision.rawValue:    return .hakedisOrange
        case RevisionType.quantityRevision.rawValue: return .blue
        case RevisionType.extraWork.rawValue:        return .hakedisSuccess
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StatusBadge(text: record.type, color: typeColor)
                Spacer()
                Text(record.date.shortFormatted)
                    .font(.caption).foregroundColor(.secondary)
            }
            Text(record.change)
                .font(.subheadline.bold())
            if !record.reason.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "text.quote")
                        .font(.caption2).foregroundColor(.secondary)
                    Text(record.reason)
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Contract Revision History (tüm sözleşme)

struct ContractRevisionHistoryView: View {
    let contract: Contract

    private struct FlatRecord: Identifiable {
        let id = UUID()
        let workItem: WorkItem
        let record: RevisionRecord
    }

    private var allRecords: [FlatRecord] {
        contract.workItems.flatMap { item in
            item.revisionHistory
                .compactMap { RevisionRecord.decode($0) }
                .map { FlatRecord(workItem: item, record: $0) }
        }
        .sorted { $0.record.date > $1.record.date }
    }

    var body: some View {
        List {
            if allRecords.isEmpty {
                ContentUnavailableView(
                    "Revizyon yok",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Bu sözleşmede henüz revizyon yapılmamış")
                )
            } else {
                Section {
                    LabeledContent("Toplam Revizyon", value: "\(allRecords.count)")
                    LabeledContent("Etkilenen Poz",
                                   value: "\(Set(allRecords.map { $0.workItem.id }).count)")
                }

                let grouped = Dictionary(grouping: allRecords) {
                    Calendar.current.startOfDay(for: $0.record.date)
                }
                let sortedDays = grouped.keys.sorted(by: >)

                ForEach(sortedDays, id: \.self) { day in
                    Section(day.shortFormatted) {
                        ForEach(grouped[day] ?? []) { flat in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("[\(flat.workItem.code)] \(flat.workItem.name)")
                                        .font(.subheadline.bold()).lineLimit(1)
                                    Spacer()
                                    StatusBadge(text: flat.record.type, color: .hakedisOrange)
                                }
                                Text(flat.record.change)
                                    .font(.caption).foregroundColor(.primary)
                                if !flat.record.reason.isEmpty {
                                    Text(flat.record.reason)
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Revizyon Geçmişi")
        .navigationBarTitleDisplayMode(.inline)
    }
}
