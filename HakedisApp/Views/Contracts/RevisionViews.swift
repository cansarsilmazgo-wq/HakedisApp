import SwiftUI
import SwiftData

enum RevisionType: String, Codable, CaseIterable {
    case priceRevision = "Fiyat Revizyonu"
    case quantityRevision = "Miktar Revizyonu"
    case extraWork = "Ek İş"
}

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

    var isValid: Bool { !code.isEmpty && !name.isEmpty && Double(unitPrice.replacingOccurrences(of: ",", with: ".")) != nil && Double(quantity.replacingOccurrences(of: ",", with: ".")) != nil && !reason.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section { Picker("İşlem Türü", selection: $isExtraWork) { Text("Ek İş").tag(true); Text("Poz Revizyonu").tag(false) }.pickerStyle(.segmented) }
                Section("Poz Bilgileri") {
                    TextField("Poz No *", text: $code)
                    TextField("İş Kalemi Adı *", text: $name)
                    Picker("Birim", selection: $unit) { ForEach(units, id: \.self) { Text($0) } }
                    HStack {
                        Text("Miktar *"); Spacer()
                        TextField("0", text: $quantity).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text(unit).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Birim Fiyat *"); Spacer()
                        TextField("0", text: $unitPrice).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text("₺").foregroundColor(.secondary)
                    }
                }
                Section("Gerekçe") { TextField("Sebebi *", text: $reason, axis: .vertical).lineLimit(3) }
                if let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")), let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) {
                    Section("Toplam") { Text((price * qty).currencyFormatted).font(.headline).foregroundColor(.hakedisOrange) }
                }
            }
            .navigationTitle(isExtraWork ? "Ek İş Ekle" : "Poz Revize Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.disabled(!isValid).bold() }
            }
        }
    }

    private func save() {
        let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let item = WorkItem(code: isExtraWork ? "EK-\(code)" : code, name: isExtraWork ? "EK: \(name)" : name, unit: unit, unitPrice: price, contractedQuantity: qty)
        item.contract = contract; contract.workItems.append(item); modelContext.insert(item); dismiss()
    }
}

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
        _newQuantity = State(initialValue: String(workItem.contractedQuantity))
    }

    var isValid: Bool { Double(newUnitPrice.replacingOccurrences(of: ",", with: ".")) != nil && Double(newQuantity.replacingOccurrences(of: ",", with: ".")) != nil && !reason.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Revizyon Türü") {
                    Picker("Tür", selection: $revisionType) {
                        ForEach(RevisionType.allCases.filter { $0 != .extraWork }, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Mevcut") {
                    LabeledContent("Birim Fiyat", value: workItem.unitPrice.currencyFormatted)
                    LabeledContent("Miktar", value: "\(workItem.contractedQuantity.quantityFormatted) \(workItem.unit)")
                }
                Section("Yeni Değerler") {
                    HStack {
                        Text("Yeni Birim Fiyat"); Spacer()
                        TextField("0", text: $newUnitPrice).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text("₺").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Yeni Miktar"); Spacer()
                        TextField("0", text: $newQuantity).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text(workItem.unit).foregroundColor(.secondary)
                    }
                }
                if let price = Double(newUnitPrice.replacingOccurrences(of: ",", with: ".")), let qty = Double(newQuantity.replacingOccurrences(of: ",", with: ".")) {
                    Section("Fark") {
                        let diff = (price * qty) - workItem.totalAmount
                        HStack { Text("Yeni Toplam"); Spacer(); Text((price * qty).currencyFormatted).bold().foregroundColor(.hakedisOrange) }
                        HStack { Text("Fark"); Spacer(); Text("\(diff >= 0 ? "+" : "")\(diff.currencyFormatted)").bold().foregroundColor(diff >= 0 ? .hakedisSuccess : .hakedisDanger) }
                    }
                }
                Section("Gerekçe") { TextField("Revizyon sebebi *", text: $reason, axis: .vertical).lineLimit(3) }
            }
            .navigationTitle("Poz Revize Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.disabled(!isValid).bold() }
            }
        }
    }

    private func save() {
        let price = Double(newUnitPrice.replacingOccurrences(of: ",", with: ".")) ?? workItem.unitPrice
        let qty = Double(newQuantity.replacingOccurrences(of: ",", with: ".")) ?? workItem.contractedQuantity
        workItem.unitPrice = price; workItem.contractedQuantity = qty; dismiss()
    }
}
