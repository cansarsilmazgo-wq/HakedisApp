import SwiftUI
import SwiftData

// MARK: - Contractor List
struct ContractorListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contractor.name) private var contractors: [Contractor]
    @State private var showingAdd = false
    @State private var searchText = ""

    private var filtered: [Contractor] {
        if searchText.isEmpty { return contractors }
        return contractors.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if contractors.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "Taşeron bulunamadı",
                        subtitle: "Taşeronları buradan yönetin",
                        actionTitle: "Taşeron Ekle",
                        action: { showingAdd = true }
                    )
                } else {
                    List {
                        ForEach(filtered) { contractor in
                            NavigationLink(destination: ContractorDetailView(contractor: contractor)) {
                                ContractorRow(contractor: contractor)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { filtered[$0] }.forEach { modelContext.delete($0) }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Taşeron ara...")
                }
            }
            .navigationTitle("Taşeronlar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddContractorView()
            }
        }
    }
}

// MARK: - Contractor Row
struct ContractorRow: View {
    let contractor: Contractor

    private var totalOwed: Double {
        contractor.contracts.flatMap { $0.hakedisler }
            .reduce(0) { $0 + $1.remainingAmount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(contractor.name)
                .font(.headline)
            if !contractor.contactPerson.isEmpty {
                Text(contractor.contactPerson)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("\(contractor.contracts.count) sözleşme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if totalOwed > 0 {
                    Text("Bekleyen: \(totalOwed.currencyFormatted)")
                        .font(.caption.bold())
                        .foregroundStyle(.hakedisDanger)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Contractor
struct AddContractorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var contactPerson = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var taxNumber = ""

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Firma Bilgileri") {
                    TextField("Firma Adı *", text: $name)
                    TextField("Yetkili Kişi", text: $contactPerson)
                    TextField("Vergi No", text: $taxNumber)
                        .keyboardType(.numberPad)
                }
                Section("İletişim") {
                    TextField("Telefon", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("E-posta", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Yeni Taşeron")
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
        let c = Contractor(name: name, contactPerson: contactPerson, phone: phone, email: email, taxNumber: taxNumber)
        modelContext.insert(c)
        dismiss()
    }
}

// MARK: - Contractor Detail
struct ContractorDetailView: View {
    let contractor: Contractor

    private var allHakedisler: [Hakedis] {
        contractor.contracts.flatMap { $0.hakedisler }
    }

    private var totalInvoiced: Double {
        allHakedisler.reduce(0) { $0 + $1.netAmount }
    }

    private var totalPaid: Double {
        allHakedisler.reduce(0) { $0 + $1.totalPaid }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Firma", value: contractor.name)
                if !contractor.contactPerson.isEmpty {
                    LabeledContent("Yetkili", value: contractor.contactPerson)
                }
                if !contractor.phone.isEmpty {
                    LabeledContent("Telefon", value: contractor.phone)
                }
                if !contractor.taxNumber.isEmpty {
                    LabeledContent("Vergi No", value: contractor.taxNumber)
                }
            }

            Section("Finansal Özet") {
                LabeledContent("Toplam Hakediş") {
                    Text(totalInvoiced.currencyFormatted).bold()
                }
                LabeledContent("Ödenen") {
                    Text(totalPaid.currencyFormatted)
                        .foregroundStyle(.hakedisSuccess)
                }
                LabeledContent("Kalan") {
                    Text((totalInvoiced - totalPaid).currencyFormatted)
                        .foregroundStyle(.hakedisDanger)
                        .bold()
                }
            }

            Section("Sözleşmeler") {
                if contractor.contracts.isEmpty {
                    Text("Sözleşme yok").foregroundStyle(.secondary)
                } else {
                    ForEach(contractor.contracts) { contract in
                        NavigationLink(destination: ContractDetailView(contract: contract)) {
                            ContractRow(contract: contract)
                        }
                    }
                }
            }
        }
        .navigationTitle(contractor.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
