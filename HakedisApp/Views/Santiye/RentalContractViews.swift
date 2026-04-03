import SwiftUI
import SwiftData

// MARK: - RentalContractListView
struct RentalContractListView: View {
    @Query(sort: \RentalContract.startDate, order: .reverse) private var contracts: [RentalContract]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false

    private var expiringSoon: [RentalContract] { contracts.filter { $0.isExpiringSoon } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if !expiringSoon.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark").foregroundColor(.hakedisWarning)
                        Text("\(expiringSoon.count) sözleşme 7 gün içinde bitiyor")
                            .font(.caption.bold()).foregroundColor(.hakedisWarning)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisWarning.opacity(0.1))
                }

                if contracts.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "Kira sözleşmesi yok",
                        subtitle: "Kiralık ekipman sözleşmelerini kaydedin",
                        actionTitle: "Sözleşme Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(contracts, id: \.id) { contract in
                            NavigationLink(destination: RentalContractDetailView(contract: contract)) {
                                RentalContractRow(contract: contract)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(contracts[i]) }
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
            .accessibilityLabel("Sözleşme ekle")
        }
        .sheet(isPresented: $showingAdd) { AddRentalContractView() }
    }
}

// MARK: - RentalContractRow
private struct RentalContractRow: View {
    let contract: RentalContract
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title3).foregroundColor(.hakedisOrange).frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(contract.rentalCompany).font(.subheadline.bold())
                if let eq = contract.equipment { Text(eq.name).font(.caption).foregroundColor(.secondary) }
                HStack(spacing: 8) {
                    Text(contract.startDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
                    if let end = contract.endDate {
                        Text("→ \(end.shortFormatted)").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(contract.totalCost.currencyFormatted).font(.caption.bold())
                if let rem = contract.daysRemaining {
                    Text("\(rem) gün kaldı")
                        .font(.caption2)
                        .foregroundColor(contract.isExpiringSoon ? .hakedisWarning : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(contract.rentalCompany), \(contract.totalCost.currencyFormatted)")
    }
}

// MARK: - RentalContractDetailView
struct RentalContractDetailView: View {
    let contract: RentalContract
    var body: some View {
        List {
            Section("Sözleşme Bilgileri") {
                LabeledContent("Kiralayan Firma", value: contract.rentalCompany)
                if let no = contract.contractNo { LabeledContent("Sözleşme No", value: no) }
                LabeledContent("Başlangıç", value: contract.startDate.shortFormatted)
                if let end = contract.endDate { LabeledContent("Bitiş", value: end.shortFormatted) }
                if let rem = contract.daysRemaining {
                    LabeledContent("Kalan Gün", value: "\(rem) gün")
                }
                if let eq = contract.equipment { LabeledContent("Ekipman", value: eq.name) }
            }
            Section("Maliyet") {
                LabeledContent("Günlük Ücret", value: contract.dailyRate.currencyFormatted)
                if let monthly = contract.monthlyRate {
                    LabeledContent("Aylık Ücret", value: monthly.currencyFormatted)
                }
                LabeledContent("Toplam Gün", value: "\(contract.totalDays)")
                LabeledContent("Toplam Maliyet", value: contract.totalCost.currencyFormatted)
                if let deposit = contract.depositAmount {
                    LabeledContent("Depozito", value: deposit.currencyFormatted)
                }
                if let penalty = contract.penaltyPerDay {
                    LabeledContent("Geç İade Cezası/Gün", value: penalty.currencyFormatted)
                }
            }
            if let minDays = contract.minimumDays {
                Section { LabeledContent("Minimum Süre", value: "\(minDays) gün") }
            }
            if let notes = contract.notes {
                Section("Notlar") { Text(notes).font(.caption).foregroundColor(.secondary) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Kira Sözleşmesi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AddRentalContractView
struct AddRentalContractView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EquipmentItem.name) private var equipment: [EquipmentItem]

    @State private var rentalCompany = ""
    @State private var contractNo = ""
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var dailyRate = ""
    @State private var monthlyRate = ""
    @State private var minimumDays = ""
    @State private var depositAmount = ""
    @State private var penaltyPerDay = ""
    @State private var selectedEquipment: EquipmentItem? = nil
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Firma & Ekipman") {
                    TextField("Kiralayan Firma *", text: $rentalCompany)
                        .accessibilityLabel("Kiralayan firma")
                    TextField("Sözleşme No", text: $contractNo)
                    Picker("Ekipman", selection: $selectedEquipment) {
                        Text("Seçilmedi").tag(Optional<EquipmentItem>.none)
                        ForEach(equipment, id: \.id) { e in Text(e.name).tag(Optional(e)) }
                    }
                }
                Section("Tarihler") {
                    DatePicker("Başlangıç", selection: $startDate, displayedComponents: .date)
                    Toggle("Bitiş Tarihi", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Bitiş", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                Section("Ücret") {
                    TextField("Günlük Ücret (₺)", text: $dailyRate).keyboardType(.decimalPad)
                        .accessibilityLabel("Günlük kira ücreti")
                    TextField("Aylık Ücret (₺, opsiyonel)", text: $monthlyRate).keyboardType(.decimalPad)
                    TextField("Minimum Süre (gün)", text: $minimumDays).keyboardType(.numberPad)
                    TextField("Depozito (₺)", text: $depositAmount).keyboardType(.decimalPad)
                    TextField("Geç İade Cezası/Gün (₺)", text: $penaltyPerDay).keyboardType(.decimalPad)
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                        .accessibilityLabel("Notlar")
                }
            }
            .navigationTitle("Sözleşme Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        let company = rentalCompany.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !company.isEmpty else { return }
        let rate = Double(dailyRate.replacingOccurrences(of: ",", with: ".")) ?? 0
        let contract = RentalContract(rentalCompany: company, startDate: startDate, dailyRate: rate)
        contract.contractNo = contractNo.isEmpty ? nil : contractNo
        contract.endDate = hasEndDate ? endDate : nil
        contract.monthlyRate = Double(monthlyRate.replacingOccurrences(of: ",", with: "."))
        contract.minimumDays = Int(minimumDays)
        contract.depositAmount = Double(depositAmount.replacingOccurrences(of: ",", with: "."))
        contract.penaltyPerDay = Double(penaltyPerDay.replacingOccurrences(of: ",", with: "."))
        contract.equipment = selectedEquipment
        contract.notes = notes.isEmpty ? nil : notes
        modelContext.insert(contract)
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
