import SwiftUI
import SwiftData
import PhotosUI

// MARK: - MaterialListView
struct MaterialListView: View {
    @Query(sort: \Material.name) private var materials: [Material]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var searchText = ""

    private var filtered: [Material] {
        materials.filter { m in
            searchText.isEmpty || m.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var lowStockCount: Int {
        materials.filter { $0.isLowStock }.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if lowStockCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.hakedisDanger)
                        Text("\(lowStockCount) malzeme kritik stok seviyesinde")
                            .font(.caption.bold())
                            .foregroundColor(.hakedisDanger)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.1))
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Malzeme ara...", text: $searchText)
                        .accessibilityLabel("Malzeme ara")
                }
                .padding(10)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(Spacing.card)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "Malzeme kaydı yok",
                        subtitle: "Stok takibi için malzeme ekleyin",
                        actionTitle: "Malzeme Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { material in
                            NavigationLink(destination: MaterialDetailView(material: material)) {
                                MaterialRow(material: material)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            do { try modelContext.save() } catch { print("Silme: \(error)") }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Yeni malzeme ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) {
            AddMaterialView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Yeni malzeme")
            }
        }
    }
}

// MARK: - MaterialRow
private struct MaterialRow: View {
    let material: Material

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(material.name)
                    .font(.subheadline.bold())
                Spacer()
                if material.isLowStock {
                    StatusBadge(text: "Kritik Stok", color: .hakedisDanger)
                }
            }
            HStack {
                Text("Stok: \(material.currentStock.quantityFormatted) \(material.unit)")
                    .font(.caption)
                    .foregroundColor(material.isLowStock ? .hakedisDanger : .secondary)
                Spacer()
                Text(material.stockValue.currencyFormatted)
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
            }
            if let lastEntry = material.entries.max(by: { $0.date < $1.date }) {
                Text("Son hareket: \(lastEntry.date.shortFormatted)")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(material.name), stok: \(material.currentStock.quantityFormatted) \(material.unit)\(material.isLowStock ? ", kritik stok" : "")")
    }
}

// MARK: - MaterialDetailView
struct MaterialDetailView: View {
    let material: Material
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddEntry = false

    private var sortedEntries: [StockEntry] {
        material.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section("Özet") {
                HStack {
                    Text("Mevcut Stok")
                    Spacer()
                    Text("\(material.currentStock.quantityFormatted) \(material.unit)")
                        .bold()
                        .foregroundColor(material.isLowStock ? .hakedisDanger : .primary)
                }
                HStack {
                    Text("Min. Stok")
                    Spacer()
                    Text("\(material.minimumStock.quantityFormatted) \(material.unit)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Birim Fiyat")
                    Spacer()
                    Text(material.unitPrice.currencyFormatted)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Stok Değeri")
                    Spacer()
                    Text(material.stockValue.currencyFormatted)
                        .bold().foregroundColor(.hakedisOrange)
                }
            }

            Section("Stok Hareketleri") {
                if sortedEntries.isEmpty {
                    Text("Henüz hareket yok")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(sortedEntries, id: \.id) { entry in
                        StockEntryRow(entry: entry, unit: material.unit)
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { sortedEntries[$0] }
                        for e in toDelete {
                            // Reverse the stock change
                            if e.entryType == .incoming {
                                material.currentStock -= e.quantity
                            } else {
                                material.currentStock += e.quantity
                            }
                            modelContext.delete(e)
                        }
                        do { try modelContext.save() } catch { print("Silme: \(error)") }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(material.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddEntry = true
                } label: {
                    Label("Giriş/Çıkış", systemImage: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Stok girişi veya çıkışı ekle")
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            StockEntryView(material: material)
        }
    }
}

private struct StockEntryRow: View {
    let entry: StockEntry
    let unit: String

    var body: some View {
        HStack {
            Image(systemName: entry.entryType == .incoming ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(entry.entryType == .incoming ? .hakedisSuccess : .hakedisWarning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.entryType.rawValue)
                    .font(.subheadline.bold())
                if let supplier = entry.supplierName {
                    Text(supplier).font(.caption).foregroundColor(.secondary)
                }
                if let note = entry.deliveryNoteNo {
                    Text("İrsaliye: \(note)").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.entryType == .incoming ? "+" : "-")\(entry.quantity.quantityFormatted) \(unit)")
                    .font(.subheadline.bold())
                    .foregroundColor(entry.entryType == .incoming ? .hakedisSuccess : .hakedisWarning)
                Text(entry.date.shortFormatted)
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.entryType.rawValue), \(entry.quantity.quantityFormatted) \(unit), \(entry.date.shortFormatted)")
    }
}

// MARK: - AddMaterialView
struct AddMaterialView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var unit = "adet"
    @State private var minimumStockText = "0"
    @State private var unitPriceText = "0"

    var body: some View {
        NavigationStack {
            Form {
                Section("Malzeme Bilgileri") {
                    TextField("Malzeme adı (Demir, Beton...)", text: $name)
                        .accessibilityLabel("Malzeme adı")
                    TextField("Birim (ton, m³, adet...)", text: $unit)
                        .accessibilityLabel("Ölçü birimi")
                    HStack {
                        Text("Min. Stok")
                        Spacer()
                        TextField("0", text: $minimumStockText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Minimum stok miktarı")
                    }
                    HStack {
                        Text("Birim Fiyat (₺)")
                        Spacer()
                        TextField("0", text: $unitPriceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .accessibilityLabel("Birim fiyat")
                    }
                }
            }
            .navigationTitle("Yeni Malzeme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }.accessibilityLabel("İptal")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.accessibilityLabel("Kaydet")
                }
            }
        }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let material = Material(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            unit: unit.isEmpty ? "adet" : unit,
            minimumStock: Double(minimumStockText) ?? 0,
            unitPrice: Double(unitPriceText) ?? 0
        )
        modelContext.insert(material)
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}

// MARK: - StockEntryView
struct StockEntryView: View {
    let material: Material
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var entryType = StockEntryType.incoming
    @State private var quantityText = ""
    @State private var supplierName = ""
    @State private var deliveryNoteNo = ""
    @State private var usedForWorkItem = ""
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Hareket Bilgileri") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                        .accessibilityLabel("Hareket tarihi")
                    Picker("Tür", selection: $entryType) {
                        ForEach(StockEntryType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Hareket türü")

                    HStack {
                        Text("Miktar (\(material.unit))")
                        Spacer()
                        TextField("0", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Miktar")
                    }
                }

                if entryType == .incoming {
                    Section("Giriş Bilgileri") {
                        TextField("Tedarikçi adı", text: $supplierName)
                            .accessibilityLabel("Tedarikçi")
                        TextField("İrsaliye no.", text: $deliveryNoteNo)
                            .accessibilityLabel("İrsaliye numarası")
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("İrsaliye Fotoğrafı", systemImage: "camera")
                                .accessibilityLabel("İrsaliye fotoğrafı ekle")
                        }
                        .onChange(of: selectedPhoto) {
                            Task {
                                photoData = try? await selectedPhoto?.loadTransferable(type: Data.self)
                            }
                        }
                        if photoData != nil {
                            Text("Fotoğraf eklendi").font(.caption).foregroundColor(.hakedisSuccess)
                        }
                    }
                } else {
                    Section("Çıkış Bilgileri") {
                        TextField("Kullanılan imalat", text: $usedForWorkItem)
                            .accessibilityLabel("Kullanım yeri")
                    }
                }

                Section("Notlar") {
                    TextField("Not (opsiyonel)", text: $notes)
                        .accessibilityLabel("Not")
                }
            }
            .navigationTitle("\(material.name) - \(entryType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }.accessibilityLabel("İptal")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.accessibilityLabel("Kaydet")
                }
            }
        }
    }

    private func save() {
        guard let qty = Double(quantityText), qty > 0 else { return }

        let entry = StockEntry(date: date, entryType: entryType, quantity: qty)
        entry.supplierName = supplierName.isEmpty ? nil : supplierName
        entry.deliveryNoteNo = deliveryNoteNo.isEmpty ? nil : deliveryNoteNo
        entry.usedForWorkItem = usedForWorkItem.isEmpty ? nil : usedForWorkItem
        entry.notes = notes.isEmpty ? nil : notes
        entry.photoData = photoData
        entry.material = material

        if entryType == .incoming {
            material.currentStock += qty
        } else {
            material.currentStock -= qty
        }

        modelContext.insert(entry)
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
