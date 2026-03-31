import SwiftUI
import SwiftData

// MARK: - SGK Asgari İşçilik

struct SGKLaborSection: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("SGK Asgari İşçilik")

            if contract.sgkLaborRecords.isEmpty {
                EmptyStateView(
                    icon: "person.badge.shield.checkmark.fill",
                    title: "SGK Kaydı Yok",
                    subtitle: "Henüz SGK asgari işçilik kaydı bulunmuyor."
                )
            } else {
                ForEach(contract.sgkLaborRecords.sorted { $0.createdAt > $1.createdAt }) { record in
                    SGKLaborRow(record: record)
                        .contextMenu {
                            Button(role: .destructive) {
                                contract.sgkLaborRecords.removeAll { $0.id == record.id }
                                context.delete(record)
                            } label: { Label("Sil", systemImage: "trash") }
                        }
                }
            }

            Button {
                showAdd = true
            } label: {
                Label("SGK Kaydı Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddSGKLaborView(contract: contract)
        }
    }
}

struct SGKLaborRow: View {
    let record: SGKLaborRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.periodName).font(.subheadline.bold())
                Spacer()
                StatusBadge(
                    text: record.isCompliant ? "Uyumlu" : "Eksik",
                    color: record.isCompliant ? .hakedisSuccess : .hakedisDanger
                )
            }
            HStack(spacing: 0) {
                sgkStat(label: "Asgari İşçilik", value: record.minimumLaborAmount.currencyFormatted, color: .hakedisWarning)
                Divider().frame(height: 36)
                sgkStat(label: "Bildirilen", value: record.declaredLaborAmount.currencyFormatted, color: record.isCompliant ? .hakedisSuccess : .hakedisDanger)
                if !record.isCompliant {
                    Divider().frame(height: 36)
                    sgkStat(label: "Eksik", value: record.deficiency.currencyFormatted, color: .hakedisDanger)
                }
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(record.isCompliant ? Color.clear : Color.hakedisDanger.opacity(0.3), lineWidth: 1)
        )
    }

    private func sgkStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.caption.bold()).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AddSGKLaborView: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var periodName = ""
    @State private var contractAmount = ""
    @State private var laborIntensityRate = "25"
    @State private var declaredLaborAmount = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Dönem") {
                    TextField("Dönem Adı", text: $periodName)
                }
                Section("Sözleşme") {
                    TextField("Sözleşme Tutarı (₺)", text: $contractAmount).keyboardType(.decimalPad)
                    TextField("İşçilik Yoğunluk Oranı (%)", text: $laborIntensityRate).keyboardType(.decimalPad)
                }
                Section("SGK Bildirimi") {
                    TextField("Bildirilen İşçilik (₺)", text: $declaredLaborAmount).keyboardType(.decimalPad)
                }
                if let ca = Double(contractAmount), let ir = Double(laborIntensityRate) {
                    let min = ca * (ir / 100)
                    Section("Hesap") {
                        HStack { Text("Asgari İşçilik"); Spacer(); Text(min.currencyFormatted).foregroundColor(.hakedisWarning) }
                        if let declared = Double(declaredLaborAmount) {
                            let isCompliant = declared >= min
                            HStack { Text("Durum"); Spacer(); Text(isCompliant ? "Uyumlu" : "Eksik").foregroundColor(isCompliant ? .hakedisSuccess : .hakedisDanger) }
                        }
                    }
                }
            }
            .navigationTitle("SGK Asgari İşçilik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(periodName.isEmpty || contractAmount.isEmpty || declaredLaborAmount.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let ca = Double(contractAmount),
              let ir = Double(laborIntensityRate),
              let da = Double(declaredLaborAmount) else { return }
        let record = SGKLaborRecord(periodName: periodName, contractAmount: ca, laborIntensityRate: ir, declaredLaborAmount: da)
        record.contract = contract
        context.insert(record)
        contract.sgkLaborRecords.append(record)
        dismiss()
    }
}
