import SwiftUI
import SwiftData

struct GuaranteeSection: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @State private var showAdd = false

    private var activeGuarantees: [Guarantee] {
        contract.guarantees.filter { !$0.isReturned }.sorted { $0.expiryDate < $1.expiryDate }
    }
    private var totalActiveAmount: Double {
        activeGuarantees.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Teminat Mektupları")

            if !activeGuarantees.isEmpty {
                StatCard(title: "Aktif Teminat", value: totalActiveAmount.currencyFormatted,
                         color: .hakedisSuccess, icon: "shield.fill")
                    .frame(maxWidth: .infinity)
            }

            if contract.guarantees.isEmpty {
                EmptyStateView(icon: "shield", title: "Teminat Yok",
                               subtitle: "Henüz teminat mektubu kaydedilmedi.",
                               actionTitle: "Teminat Ekle",
                               action: { showAdd = true })
            } else {
                ForEach(contract.guarantees.sorted { $0.expiryDate < $1.expiryDate }, id: \.id) { g in
                    GuaranteeRow(guarantee: g)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                contract.guarantees.removeAll { $0.id == g.id }
                                modelContext.delete(g)
                            } label: { Label("Sil", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            if !g.isReturned {
                                Button {
                                    g.isReturned = true
                                    g.returnedDate = Date()
                                } label: {
                                    Label("İade Edildi", systemImage: "checkmark.shield")
                                }
                                .tint(.hakedisSuccess)
                            }
                        }
                }
            }

            Button { showAdd = true } label: {
                Label("Teminat Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddGuaranteeSheet(contract: contract)
        }
    }
}

struct GuaranteeRow: View {
    let guarantee: Guarantee

    private var rowBackground: Color {
        if guarantee.isReturned { return Color.hakedisCard.opacity(0.5) }
        if guarantee.isExpired { return Color.hakedisDanger.opacity(0.08) }
        if guarantee.isExpiringSoon { return Color.hakedisWarning.opacity(0.08) }
        return Color.hakedisCard
    }
    private var borderColor: Color {
        if guarantee.isExpired { return Color.hakedisDanger.opacity(0.4) }
        if guarantee.isExpiringSoon { return Color.hakedisWarning.opacity(0.4) }
        return Color.clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusBadge(text: guarantee.guaranteeType.rawValue, color: .hakedisOrange)
                Spacer()
                if guarantee.isReturned {
                    StatusBadge(text: "İade Edildi", color: .secondary)
                } else if guarantee.isExpired {
                    StatusBadge(text: "Süresi Doldu", color: .hakedisDanger)
                } else if guarantee.isExpiringSoon {
                    StatusBadge(text: "\(guarantee.daysUntilExpiry) gün", color: .hakedisWarning)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(guarantee.bankName).font(.subheadline.bold())
                    Text("Ref: \(guarantee.referenceNumber)").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(guarantee.amount.currencyFormatted).font(.subheadline.bold())
                    Text("Son: \(guarantee.expiryDate.shortFormatted)").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: 1))
        .opacity(guarantee.isReturned ? 0.6 : 1.0)
    }
}

struct AddGuaranteeSheet: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var guaranteeType: GuaranteeType = .permanent
    @State private var amount = ""
    @State private var bankName = ""
    @State private var referenceNumber = ""
    @State private var issueDate = Date()
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var notes = ""

    private var isValid: Bool {
        !bankName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !referenceNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amount.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Teminat Bilgileri") {
                    Picker("Teminat Tipi", selection: $guaranteeType) {
                        ForEach(GuaranteeType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    HStack {
                        TextField("Tutar (₺)", text: $amount).keyboardType(.decimalPad)
                        if contract.totalContractAmount > 0 {
                            Button("Otomatik") {
                                let pct = guaranteeType == .permanent ? 0.06 :
                                          guaranteeType == .temporary ? 0.03 : contract.retentionRate / 100
                                let calc = contract.totalContractAmount * pct
                                amount = String(format: "%.2f", calc)
                            }
                            .font(.caption)
                            .foregroundColor(.hakedisOrange)
                        }
                    }
                    TextField("Banka Adı", text: $bankName)
                    TextField("Referans No", text: $referenceNumber)
                }
                Section("Tarihler") {
                    DatePicker("Düzenleme Tarihi", selection: $issueDate, displayedComponents: .date)
                    DatePicker("Son Geçerlilik", selection: $expiryDate, displayedComponents: .date)
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(height: 70)
                }
            }
            .navigationTitle("Teminat Ekle")
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
        guard let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) else { return }
        let g = Guarantee(guaranteeType: guaranteeType, amount: amt,
                         bankName: bankName, referenceNumber: referenceNumber,
                         issueDate: issueDate, expiryDate: expiryDate)
        g.notes = notes
        g.contract = contract
        modelContext.insert(g)
        contract.guarantees.append(g)
        NotificationManager.shared.scheduleGuaranteeNotification(guarantee: g)
        dismiss()
    }
}
