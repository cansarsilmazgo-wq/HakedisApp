import SwiftUI
import SwiftData

// MARK: - MaterialOrderListView
struct MaterialOrderListView: View {
    @Query(sort: \MaterialOrder.orderDate, order: .reverse) private var orders: [MaterialOrder]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var statusFilter: OrderStatus? = nil

    private var filtered: [MaterialOrder] {
        guard let f = statusFilter else { return orders }
        return orders.filter { $0.status == f }
    }

    private var delayedCount: Int { orders.filter { $0.isDelayed }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if delayedCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark").foregroundColor(.hakedisDanger)
                        Text("\(delayedCount) gecikmiş sipariş")
                            .font(.caption.bold()).foregroundColor(.hakedisDanger)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.1))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: statusFilter == nil) { statusFilter = nil }
                        ForEach(OrderStatus.allCases, id: \.rawValue) { s in
                            FilterChip(title: s.rawValue, isSelected: statusFilter == s) {
                                statusFilter = statusFilter == s ? nil : s
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                }
                .background(Color.hakedisBackground)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "Sipariş kaydı yok",
                        subtitle: "Malzeme siparişlerini takip edin",
                        actionTitle: "Sipariş Oluştur",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { order in
                            NavigationLink(destination: MaterialOrderDetailView(order: order)) {
                                MaterialOrderRow(order: order)
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
                    .font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Sipariş oluştur")
        }
        .sheet(isPresented: $showingAdd) { AddMaterialOrderView() }
    }
}

// MARK: - MaterialOrderRow
private struct MaterialOrderRow: View {
    let order: MaterialOrder
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: order.status.icon)
                .font(.title3)
                .foregroundColor(order.isDelayed ? .hakedisDanger : .hakedisOrange)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(order.orderNo).font(.subheadline.bold())
                if let mat = order.material {
                    Text(mat.name).font(.caption).foregroundColor(.secondary)
                }
                if let sup = order.supplier {
                    Text(sup.companyName).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(text: order.status.rawValue,
                            color: order.isDelayed ? .hakedisDanger : order.status == .completed ? .hakedisSuccess : .hakedisWarning)
                Text(order.totalAmount.currencyFormatted).font(.caption2).foregroundColor(.secondary)
                if let exp = order.expectedDeliveryDate {
                    Text(exp.shortFormatted).font(.caption2).foregroundColor(order.isDelayed ? .hakedisDanger : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sipariş \(order.orderNo), \(order.status.rawValue)")
    }
}

// MARK: - MaterialOrderDetailView
struct MaterialOrderDetailView: View {
    @Bindable var order: MaterialOrder

    var body: some View {
        List {
            Section("Sipariş Bilgileri") {
                LabeledContent("Sipariş No", value: order.orderNo)
                LabeledContent("Sipariş Tarihi", value: order.orderDate.shortFormatted)
                if let exp = order.expectedDeliveryDate {
                    LabeledContent("Beklenen Teslim", value: exp.shortFormatted)
                }
                if let actual = order.actualDeliveryDate {
                    LabeledContent("Gerçek Teslim", value: actual.shortFormatted)
                }
                LabeledContent("Miktar", value: String(format: "%.2f", order.orderedQuantity))
                if let del = order.deliveredQuantity {
                    LabeledContent("Teslim Edilen", value: String(format: "%.2f (%%%.0f)", del, order.deliveryRate))
                }
                LabeledContent("Birim Fiyat", value: order.unitPrice.currencyFormatted)
                LabeledContent("Toplam", value: order.totalAmount.currencyFormatted)
            }
            Section("İlişkiler") {
                if let mat = order.material { LabeledContent("Malzeme", value: mat.name) }
                if let sup = order.supplier { LabeledContent("Tedarikçi", value: sup.companyName) }
                if let prj = order.project { LabeledContent("Proje", value: prj.name) }
            }
            Section("Durum") {
                Picker("Durum", selection: $order.statusRaw) {
                    ForEach(OrderStatus.allCases, id: \.rawValue) { s in
                        Text(s.rawValue).tag(s.rawValue)
                    }
                }
                .accessibilityLabel("Sipariş durumu")
                if order.isDelayed {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark").foregroundColor(.hakedisDanger)
                        Text("Sipariş gecikmiş!").font(.caption.bold()).foregroundColor(.hakedisDanger)
                    }
                }
            }
            if let notes = order.notes {
                Section("Notlar") { Text(notes).font(.caption).foregroundColor(.secondary) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sipariş Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AddMaterialOrderView
struct AddMaterialOrderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Material.name) private var materials: [Material]
    @Query(sort: \Supplier.companyName) private var suppliers: [Supplier]
    @Query private var projects: [Project]

    @State private var orderNo = ""
    @State private var orderDate = Date()
    @State private var expectedDeliveryDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var selectedMaterial: Material? = nil
    @State private var selectedSupplier: Supplier? = nil
    @State private var selectedProject: Project? = nil
    @State private var orderedQuantity = ""
    @State private var unitPrice = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Sipariş Bilgileri") {
                    TextField("Sipariş No *", text: $orderNo)
                        .accessibilityLabel("Sipariş numarası")
                    DatePicker("Sipariş Tarihi", selection: $orderDate, displayedComponents: .date)
                    DatePicker("Beklenen Teslim", selection: $expectedDeliveryDate, displayedComponents: .date)
                }
                Section("İlişkiler") {
                    Picker("Malzeme", selection: $selectedMaterial) {
                        Text("Seçilmedi").tag(Optional<Material>.none)
                        ForEach(materials, id: \.id) { m in Text(m.name).tag(Optional(m)) }
                    }
                    Picker("Tedarikçi", selection: $selectedSupplier) {
                        Text("Seçilmedi").tag(Optional<Supplier>.none)
                        ForEach(suppliers, id: \.id) { s in Text(s.companyName).tag(Optional(s)) }
                    }
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                    }
                }
                Section("Miktar & Fiyat") {
                    TextField("Miktar", text: $orderedQuantity).keyboardType(.decimalPad)
                        .accessibilityLabel("Sipariş miktarı")
                    TextField("Birim Fiyat (₺)", text: $unitPrice).keyboardType(.decimalPad)
                        .accessibilityLabel("Birim fiyat")
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                        .accessibilityLabel("Notlar")
                }
            }
            .navigationTitle("Sipariş Oluştur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        let no = orderNo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !no.isEmpty else { return }
        let qty = Double(orderedQuantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let price = Double(unitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        let order = MaterialOrder(orderNo: no, orderDate: orderDate, orderedQuantity: qty, unitPrice: price)
        order.expectedDeliveryDate = expectedDeliveryDate
        order.totalAmount = qty * price
        order.material = selectedMaterial
        order.supplier = selectedSupplier
        order.project = selectedProject
        order.notes = notes.isEmpty ? nil : notes
        modelContext.insert(order)
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
