import SwiftUI
import SwiftData

// MARK: - KDV Tevkifatı

struct VATWithholdingSection: View {
    let hakedis: Hakedis

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("KDV Tevkifatı")

            if hakedis.vatWithholdings.isEmpty {
                EmptyStateView(
                    icon: "percent",
                    title: "Tevkifat Yok",
                    subtitle: "Bu hakediş için KDV tevkifatı kaydı bulunmuyor."
                )
            } else {
                ForEach(hakedis.vatWithholdings) { record in
                    VATWithholdingRow(record: record)
                }
            }

            Button {
                showAdd = true
            } label: {
                Label("Tevkifat Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddVATWithholdingView(hakedis: hakedis)
        }
    }
}

struct VATWithholdingRow: View {
    let record: VATWithholdingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("KDV Tevkifatı", systemImage: "percent")
                    .font(.subheadline.bold())
                Spacer()
                StatusBadge(text: record.withholdingRatio.rawValue, color: .hakedisOrange)
            }
            Divider()
            HStack(spacing: 0) {
                vatStat(label: "Toplam KDV", value: record.totalVATAmount.currencyFormatted, color: .primary)
                Divider().frame(height: 36)
                vatStat(label: "Yüklenici Öder", value: record.contractorPays.currencyFormatted, color: .hakedisOrange)
                Divider().frame(height: 36)
                vatStat(label: "İdare Öder", value: record.ownerPays.currencyFormatted, color: .blue)
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func vatStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.caption.bold()).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AddVATWithholdingView: View {
    let hakedis: Hakedis

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var withholdingRatio: VATWithholdingRatio = .ikiUcte
    @State private var totalVAT = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tevkifat Oranı") {
                    Picker("Oran", selection: $withholdingRatio) {
                        ForEach(VATWithholdingRatio.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("KDV Tutarı") {
                    TextField("Toplam KDV (₺)", text: $totalVAT).keyboardType(.decimalPad)
                }
                if let total = Double(totalVAT), total > 0 {
                    let contractor = total * (1 - withholdingRatio.ratio)
                    let owner = total * withholdingRatio.ratio
                    Section("Dağılım") {
                        HStack { Text("Yüklenici"); Spacer(); Text(contractor.currencyFormatted).foregroundColor(.hakedisOrange) }
                        HStack { Text("İdare"); Spacer(); Text(owner.currencyFormatted).foregroundColor(.blue) }
                    }
                }
            }
            .navigationTitle("KDV Tevkifatı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(totalVAT.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let total = Double(totalVAT) else { return }
        let record = VATWithholdingRecord(withholdingRatio: withholdingRatio, totalVATAmount: total)
        record.hakedis = hakedis
        context.insert(record)
        hakedis.vatWithholdings.append(record)
        dismiss()
    }
}
