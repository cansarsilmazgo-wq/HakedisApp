import SwiftUI
import SwiftData

// MARK: - SupplierListView
struct SupplierListView: View {
    @Query(sort: \Supplier.companyName) private var suppliers: [Supplier]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var searchText = ""

    private var filtered: [Supplier] {
        suppliers.filter { s in
            searchText.isEmpty || s.companyName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Tedarikçi ara...", text: $searchText)
                        .accessibilityLabel("Tedarikçi ara")
                }
                .padding(10)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(Spacing.card)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "building.2",
                        title: "Tedarikçi kaydı yok",
                        subtitle: "Malzeme tedarikçilerini ekleyin",
                        actionTitle: "Tedarikçi Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { supplier in
                            NavigationLink(destination: SupplierDetailView(supplier: supplier)) {
                                SupplierRow(supplier: supplier)
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
            .accessibilityLabel("Tedarikçi ekle")
        }
        .sheet(isPresented: $showingAdd) { AddSupplierView() }
    }
}

// MARK: - SupplierRow
private struct SupplierRow: View {
    let supplier: Supplier
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.title3)
                .foregroundColor(.hakedisOrange)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(supplier.companyName).font(.subheadline.bold())
                if let contact = supplier.contactPerson {
                    Text(contact).font(.caption).foregroundColor(.secondary)
                }
                if let phone = supplier.phone {
                    Text(phone).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let rating = supplier.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.hakedisWarning)
                        }
                    }
                }
                let total = supplier.orders.reduce(0.0) { $0 + $1.totalAmount }
                if total > 0 {
                    Text(total.currencyFormatted).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(supplier.companyName), \(supplier.orders.count) sipariş")
    }
}

// MARK: - SupplierDetailView
struct SupplierDetailView: View {
    let supplier: Supplier
    @State private var showingEdit = false

    private var totalOrderAmount: Double { supplier.orders.reduce(0) { $0 + $1.totalAmount } }
    private var completedOrders: [MaterialOrder] { supplier.orders.filter { $0.status == .completed || $0.status == .delivered } }
    private var onTimeOrders: [MaterialOrder] {
        completedOrders.filter { order in
            guard let actual = order.actualDeliveryDate, let expected = order.expectedDeliveryDate else { return true }
            return actual <= expected
        }
    }
    private var onTimeRate: Double {
        guard !completedOrders.isEmpty else { return 0 }
        return Double(onTimeOrders.count) / Double(completedOrders.count) * 100
    }

    var body: some View {
        List {
            Section("İletişim") {
                supplierInfoRows
            }
            Section("Performans") {
                performanceRows
            }
            Section("Sipariş Geçmişi (\(supplier.orders.count))") {
                if supplier.orders.isEmpty {
                    Text("Sipariş kaydı yok").font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(supplier.orders.sorted { $0.orderDate > $1.orderDate }.prefix(10), id: \.id) { order in
                        HStack {
                            Image(systemName: order.status.icon)
                                .foregroundColor(.hakedisOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(order.orderNo).font(.subheadline.bold())
                                Text(order.orderDate.shortFormatted).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                StatusBadge(text: order.status.rawValue, color: order.isDelayed ? .hakedisDanger : .hakedisSuccess)
                                Text(order.totalAmount.currencyFormatted).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(supplier.companyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingEdit = true } label: { Image(systemName: "pencil") }
            }
        }
        .sheet(isPresented: $showingEdit) { AddSupplierView(editing: supplier) }
    }

    @ViewBuilder private var supplierInfoRows: some View {
        if let contact = supplier.contactPerson {
            LabeledContent("Yetkili", value: contact)
        }
        if let phone = supplier.phone {
            LabeledContent("Telefon", value: phone)
        }
        if let email = supplier.email {
            LabeledContent("E-posta", value: email)
        }
        if let address = supplier.address {
            LabeledContent("Adres", value: address)
        }
        if let tax = supplier.taxNumber {
            LabeledContent("Vergi No", value: tax)
        }
        if let iban = supplier.iban {
            LabeledContent("IBAN", value: iban)
        }
        if let notes = supplier.notes {
            LabeledContent("Notlar", value: notes)
        }
    }

    @ViewBuilder private var performanceRows: some View {
        if let rating = supplier.rating {
            HStack {
                Text("Puan")
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.hakedisWarning)
                    }
                }
            }
        }
        LabeledContent("Toplam Sipariş", value: totalOrderAmount.currencyFormatted)
        LabeledContent("Tamamlanan Sipariş", value: "\(completedOrders.count)")
        if !completedOrders.isEmpty {
            LabeledContent("Zamanında Teslimat", value: String(format: "%%%.0f", onTimeRate))
        }
    }
}

// MARK: - AddSupplierView
struct AddSupplierView: View {
    var editing: Supplier? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var companyName = ""
    @State private var contactPerson = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var taxNumber = ""
    @State private var iban = ""
    @State private var rating = 0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Firma Bilgileri") {
                    TextField("Firma Adı *", text: $companyName)
                        .accessibilityLabel("Firma adı")
                    TextField("Yetkili Kişi", text: $contactPerson)
                    TextField("Telefon", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("E-posta", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                Section("Adres & Vergi") {
                    TextField("Adres", text: $address)
                    TextField("Vergi No", text: $taxNumber)
                    TextField("IBAN", text: $iban)
                        .autocapitalization(.allCharacters)
                }
                Section("Değerlendirme") {
                    HStack {
                        Text("Puan")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { i in
                                Button { rating = rating == i ? 0 : i } label: {
                                    Image(systemName: i <= rating ? "star.fill" : "star")
                                        .foregroundColor(.hakedisWarning)
                                }
                                .accessibilityLabel("\(i) yıldız")
                            }
                        }
                    }
                }
                Section("Notlar") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .accessibilityLabel("Notlar")
                }
            }
            .navigationTitle(editing == nil ? "Tedarikçi Ekle" : "Tedarikçiyi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
            .onAppear { loadEditing() }
        }
    }

    private func loadEditing() {
        guard let s = editing else { return }
        companyName = s.companyName
        contactPerson = s.contactPerson ?? ""
        phone = s.phone ?? ""
        email = s.email ?? ""
        address = s.address ?? ""
        taxNumber = s.taxNumber ?? ""
        iban = s.iban ?? ""
        rating = s.rating ?? 0
        notes = s.notes ?? ""
    }

    private func save() {
        let name = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let supplier = editing ?? Supplier(companyName: name)
        supplier.companyName = name
        supplier.contactPerson = contactPerson.isEmpty ? nil : contactPerson
        supplier.phone = phone.isEmpty ? nil : phone
        supplier.email = email.isEmpty ? nil : email
        supplier.address = address.isEmpty ? nil : address
        supplier.taxNumber = taxNumber.isEmpty ? nil : taxNumber
        supplier.iban = iban.isEmpty ? nil : iban
        supplier.rating = rating == 0 ? nil : rating
        supplier.notes = notes.isEmpty ? nil : notes
        if editing == nil { modelContext.insert(supplier) }
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
