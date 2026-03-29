import SwiftUI
import SwiftData
import PhotosUI

// MARK: - MaterialInventorySection

struct MaterialInventorySection: View {
    let contract: Contract

    @State private var showAddMaterial = false
    @State private var showFullList = false

    private var totalCount: Int { contract.materialRecords.count }
    private var lowStockCount: Int { contract.materialRecords.filter { $0.isLowStock }.count }
    private var totalStockValue: Double { contract.materialRecords.reduce(0) { $0 + $1.stockValue } }
    private var previewMaterials: [MaterialRecord] {
        contract.materialRecords.sorted { $0.materialName < $1.materialName }.prefix(3).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Malzeme Envanteri") {
                showFullList = true
            }

            // Low stock warning banner
            if lowStockCount > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.hakedisWarning)
                    Text("\(lowStockCount) malzemenin stoku minimum seviyenin altında.")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(12)
                .background(Color.hakedisWarning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Mini stat cards
            HStack(spacing: 12) {
                StatCard(
                    title: "Toplam",
                    value: "\(totalCount)",
                    subtitle: "malzeme çeşidi",
                    color: .hakedisOrange,
                    icon: "shippingbox.fill"
                )
                StatCard(
                    title: "Düşük Stok",
                    value: "\(lowStockCount)",
                    subtitle: "malzeme",
                    color: lowStockCount > 0 ? .hakedisWarning : .hakedisSuccess,
                    icon: "arrow.down.circle.fill"
                )
                StatCard(
                    title: "Stok Değeri",
                    value: totalStockValue.shortFormatted,
                    subtitle: "TL",
                    color: .hakedisSuccess,
                    icon: "turkishlirasign.circle.fill"
                )
            }

            // Preview rows
            if previewMaterials.isEmpty {
                EmptyStateView(
                    icon: "shippingbox",
                    title: "Malzeme Yok",
                    subtitle: "Bu sözleşmeye henüz malzeme eklenmemiş.",
                    actionTitle: "Malzeme Ekle",
                    action: { showAddMaterial = true }
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(previewMaterials) { material in
                        NavigationLink(destination: MaterialTransactionHistoryView(material: material)) {
                            MaterialStockCard(material: material)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    NavigationLink(destination: MaterialInventoryListView(contract: contract)) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("Tümünü Gör")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.hakedisOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.hakedisOrange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button(action: { showAddMaterial = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Malzeme Ekle")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.hakedisOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .sheet(isPresented: $showAddMaterial) {
            AddMaterialRecordView(contract: contract)
        }
        .navigationDestination(isPresented: $showFullList) {
            MaterialInventoryListView(contract: contract)
        }
    }
}

// MARK: - MaterialInventoryListView

struct MaterialInventoryListView: View {
    let contract: Contract

    @Environment(\.modelContext) private var modelContext
    @State private var selectedCategory: MaterialCategory? = nil
    @State private var showAddMaterial = false

    private var filteredMaterials: [MaterialRecord] {
        let source: [MaterialRecord]
        if let cat = selectedCategory {
            source = contract.materialRecords.filter { $0.category == cat }
        } else {
            source = contract.materialRecords
        }
        return source.sorted {
            if $0.category.rawValue == $1.category.rawValue {
                return $0.materialName < $1.materialName
            }
            return $0.category.rawValue < $1.category.rawValue
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryFilterChip(
                            label: "Tümü",
                            icon: "square.grid.2x2.fill",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        ForEach(MaterialCategory.allCases, id: \.self) { cat in
                            CategoryFilterChip(
                                label: cat.rawValue,
                                icon: cat.icon,
                                isSelected: selectedCategory == cat,
                                action: { selectedCategory = cat }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                if filteredMaterials.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "Malzeme Bulunamadı",
                        subtitle: "Seçili kategoride malzeme yok.",
                        actionTitle: "Malzeme Ekle",
                        action: { showAddMaterial = true }
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredMaterials) { material in
                            NavigationLink(destination: MaterialTransactionHistoryView(material: material)) {
                                MaterialStockCard(material: material)
                                    .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteMaterial(material)
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Malzeme Envanteri")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddMaterial = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMaterial) {
            AddMaterialRecordView(contract: contract)
        }
    }

    private func deleteMaterial(_ material: MaterialRecord) {
        modelContext.delete(material)
    }
}

// MARK: - CategoryFilterChip

private struct CategoryFilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2)
                Text(label).font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.hakedisOrange : Color.hakedisCard)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MaterialStockCard

struct MaterialStockCard: View {
    let material: MaterialRecord

    private var stockColor: Color {
        if material.isStockEmpty { return .hakedisDanger }
        if material.isLowStock   { return .hakedisWarning }
        return .hakedisSuccess
    }

    private var stockStatusText: String {
        if material.isStockEmpty { return "Stok Yok" }
        if material.isLowStock   { return "Düşük Stok" }
        return "Yeterli"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.hakedisOrange.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: material.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.hakedisOrange)
            }

            // Name + info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(material.materialName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    StatusBadge(text: stockStatusText, color: stockColor)
                }
                Text("Stok: \(material.stockQty.quantityFormatted) \(material.unit)  •  Değer: \(material.stockValue.currencyFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Mini stats
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill").foregroundColor(.hakedisSuccess).font(.caption2)
                    Text(material.receivedQty.quantityFormatted).font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "hammer.fill").foregroundColor(.hakedisOrange).font(.caption2)
                    Text(material.usedQty.quantityFormatted).font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill").foregroundColor(.hakedisDanger).font(.caption2)
                    Text(material.wastageQty.quantityFormatted).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - AddMaterialRecordView

struct AddMaterialRecordView: View {
    let contract: Contract

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var materialName = ""
    @State private var unit = ""
    @State private var category: MaterialCategory = .diger
    @State private var supplier = ""
    @State private var minimumStockLevel = ""

    private var isValid: Bool { !materialName.trimmingCharacters(in: .whitespaces).isEmpty && !unit.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Malzeme Bilgileri") {
                    TextField("Malzeme Adı *", text: $materialName)
                    TextField("Birim (adet, kg, m³, ...)", text: $unit)
                        .autocapitalization(.none)
                }

                Section("Kategori ve Tedarikçi") {
                    Picker("Kategori", selection: $category) {
                        ForEach(MaterialCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    TextField("Tedarikçi (isteğe bağlı)", text: $supplier)
                }

                Section("Stok Uyarı Seviyesi") {
                    TextField("Minimum Stok Miktarı", text: $minimumStockLevel)
                        .keyboardType(.decimalPad)
                    Text("Bu değerin altına düşünce uyarı gösterilir.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Yeni Malzeme")
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
        let record = MaterialRecord(
            materialName: materialName.trimmingCharacters(in: .whitespaces),
            unit: unit.trimmingCharacters(in: .whitespaces),
            category: category
        )
        record.supplier = supplier.isEmpty ? nil : supplier
        record.minimumStockLevel = Double(minimumStockLevel.replacingOccurrences(of: ",", with: ".")) ?? 0
        record.contract = contract
        modelContext.insert(record)
        dismiss()
    }
}

// MARK: - AddMaterialTransactionView

struct AddMaterialTransactionView: View {
    let material: MaterialRecord
    let contract: Contract?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var type: MaterialTransactionType = .teslimAlindi
    @State private var quantityStr = ""
    @State private var date = Date()
    @State private var unitPriceStr = ""
    @State private var invoiceNo = ""
    @State private var deliveryNoteNo = ""
    @State private var selectedWorkItemCode = ""
    @State private var notes = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    private var quantity: Double { Double(quantityStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var unitPrice: Double? { Double(unitPriceStr.replacingOccurrences(of: ",", with: ".")) }

    private var isValid: Bool { quantity > 0 }

    private var showsStockWarning: Bool {
        type == .kullanildi && quantity > material.stockQty && material.stockQty >= 0
    }

    private var showsNegativeWarning: Bool {
        type == .kullanildi && quantity > material.stockQty
    }

    private var workItems: [WorkItem] {
        contract?.workItems.sorted { $0.code < $1.code } ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hareket Tipi") {
                    Picker("Tip", selection: $type) {
                        ForEach(MaterialTransactionType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Miktar ve Tarih") {
                    HStack {
                        TextField("Miktar *", text: $quantityStr)
                            .keyboardType(.decimalPad)
                        Text(material.unit)
                            .foregroundColor(.secondary)
                    }

                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                }

                // Stock going negative warning
                if showsNegativeWarning {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.hakedisDanger)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stok Yetersiz").font(.subheadline.bold()).foregroundColor(.hakedisDanger)
                                Text("Mevcut stok: \(material.stockQty.quantityFormatted) \(material.unit). Girilen miktar stokun üzerinde.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Conditional: unitPrice for siparis / teslimAlindi
                if type == .siparis || type == .teslimAlindi {
                    Section("Fiyat Bilgisi") {
                        HStack {
                            TextField("Birim Fiyat (isteğe bağlı)", text: $unitPriceStr)
                                .keyboardType(.decimalPad)
                            Text("₺")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Conditional: invoice + delivery note for teslimAlindi
                if type == .teslimAlindi {
                    Section("Belge Numaraları") {
                        TextField("Fatura No", text: $invoiceNo)
                            .autocapitalization(.allCharacters)
                        TextField("İrsaliye No", text: $deliveryNoteNo)
                            .autocapitalization(.allCharacters)
                    }
                }

                // Conditional: workItemCode for kullanildi
                if type == .kullanildi && !workItems.isEmpty {
                    Section("İş Kalemi") {
                        Picker("İş Kalemi", selection: $selectedWorkItemCode) {
                            Text("—").tag("")
                            ForEach(workItems) { item in
                                Text("\(item.code)  \(item.name)").tag(item.code)
                            }
                        }
                    }
                }

                Section("Notlar") {
                    TextField("Açıklama (isteğe bağlı)", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                // Photo picker (for teslimAlindi or siparis documents)
                if type == .teslimAlindi || type == .siparis {
                    Section("Belge Fotoğrafı") {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                    .foregroundColor(.hakedisOrange)
                                Text(photoData == nil ? "Fotoğraf / Belge Ekle" : "Fotoğraf Seçildi ✓")
                                    .foregroundColor(photoData == nil ? .primary : .hakedisSuccess)
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                photoData = try? await newItem?.loadTransferable(type: Data.self)
                            }
                        }

                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .navigationTitle("Hareket Ekle")
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
        let tx = MaterialTransaction(type: type, quantity: quantity, date: date)
        tx.unitPrice = unitPrice
        tx.invoiceNo = invoiceNo.isEmpty ? nil : invoiceNo
        tx.deliveryNoteNo = deliveryNoteNo.isEmpty ? nil : deliveryNoteNo
        tx.workItemCode = selectedWorkItemCode.isEmpty ? nil : selectedWorkItemCode
        tx.notes = notes.isEmpty ? nil : notes
        tx.photoData = photoData
        tx.material = material
        modelContext.insert(tx)
        dismiss()
    }
}

// MARK: - MaterialTransactionHistoryView

struct MaterialTransactionHistoryView: View {
    let material: MaterialRecord

    @State private var showAddTransaction = false

    private var sortedTransactions: [MaterialTransaction] {
        material.transactions.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stock summary header
                MaterialStockSummaryHeader(material: material)
                    .padding(.horizontal)

                // Transaction list
                if sortedTransactions.isEmpty {
                    EmptyStateView(
                        icon: "arrow.left.arrow.right.circle",
                        title: "Hareket Yok",
                        subtitle: "Bu malzeme için henüz hareket kaydı girilmemiş.",
                        actionTitle: "Hareket Ekle",
                        action: { showAddTransaction = true }
                    )
                    .padding(.top, 32)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(sortedTransactions) { tx in
                            MaterialTransactionRow(transaction: tx, unit: material.unit)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.hakedisBackground)
        .navigationTitle(material.materialName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddTransaction = true }) {
                    Label("Hareket Ekle", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTransaction) {
            AddMaterialTransactionView(material: material, contract: material.contract)
        }
    }
}

// MARK: - MaterialStockSummaryHeader

private struct MaterialStockSummaryHeader: View {
    let material: MaterialRecord

    private var stockColor: Color {
        if material.isStockEmpty { return .hakedisDanger }
        if material.isLowStock   { return .hakedisWarning }
        return .hakedisSuccess
    }

    var body: some View {
        VStack(spacing: 14) {
            // Main stock display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mevcut Stok")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(material.stockQty.quantityFormatted)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(stockColor)
                        Text(material.unit)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    if let price = material.lastUnitPrice {
                        Text("Değer: \(material.stockValue.currencyFormatted)  •  Son Fiyat: \(price.currencyFormatted)/\(material.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                ZStack {
                    Circle()
                        .fill(stockColor.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: material.category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(stockColor)
                }
            }

            Divider()

            // Breakdown grid
            HStack(spacing: 0) {
                SummaryMetric(label: "Sipariş", value: material.orderedQty.quantityFormatted, unit: material.unit, color: .secondary)
                Divider().frame(height: 40)
                SummaryMetric(label: "Teslim", value: material.receivedQty.quantityFormatted, unit: material.unit, color: .hakedisSuccess)
                Divider().frame(height: 40)
                SummaryMetric(label: "Kullanılan", value: material.usedQty.quantityFormatted, unit: material.unit, color: .hakedisOrange)
                Divider().frame(height: 40)
                SummaryMetric(label: "Zayi", value: material.wastageQty.quantityFormatted, unit: material.unit, color: .hakedisDanger)
                Divider().frame(height: 40)
                SummaryMetric(label: "İade", value: material.returnedQty.quantityFormatted, unit: material.unit, color: .hakedisWarning)
            }
        }
        .padding(16)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SummaryMetric: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MaterialTransactionRow

private struct MaterialTransactionRow: View {
    let transaction: MaterialTransaction
    let unit: String

    private var typeColor: Color {
        switch transaction.type {
        case .siparis:      return .secondary
        case .teslimAlindi: return .hakedisSuccess
        case .kullanildi:   return .hakedisOrange
        case .iade:         return .hakedisWarning
        case .zayi:         return .hakedisDanger
        }
    }

    private var typeIcon: String {
        switch transaction.type {
        case .siparis:      return "doc.text.fill"
        case .teslimAlindi: return "arrow.down.circle.fill"
        case .kullanildi:   return "hammer.fill"
        case .iade:         return "arrow.uturn.left.circle.fill"
        case .zayi:         return "trash.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: typeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(typeColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    StatusBadge(text: transaction.type.rawValue, color: typeColor)
                    if let code = transaction.workItemCode {
                        Text(code)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    if let inv = transaction.invoiceNo {
                        Label(inv, systemImage: "doc.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let del = transaction.deliveryNoteNo {
                        Label(del, systemImage: "shippingbox.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                if let notes = transaction.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Quantity + date
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.quantity.quantityFormatted) \(unit)")
                    .font(.subheadline.bold())
                    .foregroundColor(typeColor)
                if let cost = transaction.totalCost {
                    Text(cost.currencyFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(transaction.date.shortFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Double extension helper

private extension Double {
    var shortFormatted: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", self / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fB", self / 1_000)
        }
        return String(format: "%.0f", self)
    }
}
