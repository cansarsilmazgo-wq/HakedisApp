import SwiftUI
import SwiftData
import PhotosUI

// MARK: - MaterialStockSubTabView
struct MaterialStockSubTabView: View {
    @State private var selectedTab = 0
    private let tabs = ["Stok", "Siparişler", "Talepler", "Tedarikçiler", "Testler"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button {
                            selectedTab = i
                        } label: {
                            Text(tabs[i])
                                .font(.subheadline.weight(selectedTab == i ? .semibold : .regular))
                                .foregroundColor(selectedTab == i ? .hakedisOrange : .secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .overlay(
                                    Rectangle().frame(height: 2)
                                        .foregroundColor(selectedTab == i ? .hakedisOrange : .clear),
                                    alignment: .bottom
                                )
                        }
                        .accessibilityLabel(tabs[i])
                        .accessibilityAddTraits(selectedTab == i ? .isSelected : [])
                    }
                }
            }
            .background(Color.hakedisCard)
            Divider()
            ZStack {
                switch selectedTab {
                case 0: MaterialListView()
                case 1: MaterialOrderListView()
                case 2: MaterialRequestListView()
                case 3: SupplierListView()
                case 4: MaterialTestResultListView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.hakedisBackground)
    }
}

// MARK: - MaterialListView
struct MaterialListView: View {
    @Query(sort: \Material.name) private var materials: [Material]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var showingQRScanner = false
    @State private var searchText = ""

    private var filtered: [Material] {
        materials.filter { m in
            searchText.isEmpty || m.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var lowStockCount: Int { materials.filter { $0.isLowStock }.count }
    private var totalStockValue: Double { materials.reduce(0) { $0 + $1.stockValue } }
    private var pendingOrderCount: Int { materials.reduce(0) { $0 + $1.pendingOrderCount } }
    private var nonConformingCount: Int { materials.filter { $0.hasNonConformingTest }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if lowStockCount > 0 || pendingOrderCount > 0 || nonConformingCount > 0 {
                    HStack(spacing: 12) {
                        if lowStockCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                                Text("\(lowStockCount) kritik").font(.caption.bold()).foregroundColor(.hakedisDanger)
                            }
                        }
                        if pendingOrderCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "shippingbox").foregroundColor(.hakedisWarning)
                                Text("\(pendingOrderCount) sipariş").font(.caption.bold()).foregroundColor(.hakedisWarning)
                            }
                        }
                        if nonConformingCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.seal.fill").foregroundColor(.hakedisDanger)
                                Text("\(nonConformingCount) uygunsuz test").font(.caption.bold()).foregroundColor(.hakedisDanger)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.08))
                }
                HStack {
                    Text("Toplam Stok Değeri:").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(totalStockValue.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
                }
                .padding(.horizontal, Spacing.card).padding(.vertical, 6)

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
        .sheet(isPresented: $showingQRScanner) {
            MaterialQRScannerView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        showingQRScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                    .accessibilityLabel("QR Tarama")
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Yeni malzeme")
                }
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
            HStack(spacing: 8) {
                if let lastEntry = material.entries.max(by: { $0.date < $1.date }) {
                    Text("Son hareket: \(lastEntry.date.shortFormatted)")
                        .font(.caption2).foregroundColor(.secondary)
                }
                if material.pendingOrderCount > 0 {
                    Text("\(material.pendingOrderCount) sipariş")
                        .font(.caption2).foregroundColor(.hakedisWarning)
                }
                if material.hasNonConformingTest {
                    Image(systemName: "xmark.seal.fill").font(.caption2).foregroundColor(.hakedisDanger)
                }
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
    @State private var showingQR = false

    private var sortedEntries: [StockEntry] {
        material.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if material.hasNonConformingTest {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.hakedisDanger)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Uygunsuz Test Sonucu")
                                .font(.subheadline.bold())
                                .foregroundColor(.hakedisDanger)
                            Text("Bu malzemede uygunsuz test sonucu var. Kullanmadan önce kontrol edin.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityLabel("Uyarı: Bu malzemede uygunsuz test sonucu var")
                }
            }
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

            if let wastage = material.actualWastage {
                Section("Fire Analizi") {
                    LabeledContent("Teorik Sarf", value: String(format: "%.2f \(material.unit)", material.theoreticalConsumption ?? 0))
                    let totalOut = material.entries.filter { $0.entryType == .outgoing }.reduce(0.0) { $0 + $1.quantity }
                    LabeledContent("Gerçek Sarf", value: String(format: "%.2f \(material.unit)", totalOut))
                    HStack {
                        Text("Fire Oranı")
                        Spacer()
                        Text(String(format: "%+.1f%%", wastage))
                            .font(.subheadline.bold())
                            .foregroundColor(wastage > 5 ? .hakedisDanger : wastage > 0 ? .hakedisWarning : .hakedisSuccess)
                    }
                }
            }
            Section("Siparişler (\(material.orders.count))") {
                if material.orders.isEmpty {
                    Text("Sipariş yok").font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(material.orders.prefix(5), id: \.id) { order in
                        HStack {
                            Image(systemName: order.status.icon).foregroundColor(.hakedisOrange)
                            Text(order.orderNo).font(.subheadline)
                            Spacer()
                            StatusBadge(text: order.status.rawValue,
                                        color: order.isDelayed ? .hakedisDanger : .hakedisSuccess)
                        }
                    }
                }
            }
            Section("Test Sonuçları (\(material.testResults.count))") {
                if material.testResults.isEmpty {
                    Text("Test sonucu yok").font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(material.testResults.prefix(5), id: \.id) { tr in
                        HStack {
                            Image(systemName: tr.isConforming ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .foregroundColor(tr.isConforming ? .hakedisSuccess : .hakedisDanger)
                            Text(tr.testType.rawValue).font(.subheadline)
                            Spacer()
                            Text(tr.testDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
                        }
                    }
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
                HStack {
                    Button {
                        showingQR = true
                    } label: {
                        Image(systemName: "qrcode")
                    }
                    .accessibilityLabel("QR kodu göster")
                    Button {
                        showingAddEntry = true
                    } label: {
                        Label("Giriş/Çıkış", systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Stok girişi veya çıkışı ekle")
                }
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            StockEntryView(material: material)
        }
        .sheet(isPresented: $showingQR) {
            MaterialQRDisplayView(material: material)
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
    @State private var showNonConformingAlert = false
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
                    if material.hasNonConformingTest {
                        Section {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                                Text("Uygunsuz test sonucu var. Kullanmadan önce kontrol edin.")
                                    .font(.caption).foregroundColor(.hakedisDanger)
                            }
                            .accessibilityLabel("Uyarı: uygunsuz test sonucu")
                        }
                    }
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
                    Button("Kaydet") {
                        if entryType == .outgoing && material.hasNonConformingTest {
                            showNonConformingAlert = true
                        } else {
                            save()
                        }
                    }.accessibilityLabel("Kaydet")
                }
            }
            .confirmationDialog("Uygunsuz Test Sonucu", isPresented: $showNonConformingAlert, titleVisibility: .visible) {
                Button("Yine de Kullan", role: .destructive) { save() }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Bu malzemede uygunsuz test sonucu bulunmaktadır. Kullanmak istediğinizden emin misiniz?")
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
