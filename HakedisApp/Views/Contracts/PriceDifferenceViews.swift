import SwiftUI
import SwiftData

// MARK: - Fiyat Farkı

struct PriceDifferenceSection: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    private var toplamFark: Double {
        contract.priceDifferenceRecords.reduce(0) { $0 + $1.priceDifference }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Fiyat Farkı")

            if !contract.priceDifferenceRecords.isEmpty {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Toplam Fark",
                        value: toplamFark.currencyFormatted,
                        color: toplamFark >= 0 ? .hakedisSuccess : .hakedisDanger,
                        icon: toplamFark >= 0 ? "arrow.up.right" : "arrow.down.right"
                    )
                }

                ForEach(contract.priceDifferenceRecords.sorted { $0.createdAt > $1.createdAt }) { record in
                    PriceDifferenceRow(record: record)
                }
            } else {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Fiyat Farkı Yok",
                    subtitle: "Henüz fiyat farkı kaydı bulunmuyor."
                )
            }

            Button {
                showAdd = true
            } label: {
                Label("Fiyat Farkı Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddPriceDifferenceView(contract: contract)
        }
    }
}

struct PriceDifferenceRow: View {
    let record: PriceDifferenceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.periodName)
                    .font(.subheadline.bold())
                Spacer()
                StatusBadge(
                    text: record.isGain ? "Artış" : "Azalış",
                    color: record.isGain ? .hakedisSuccess : .hakedisDanger
                )
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Baz Endeks").font(.caption2).foregroundColor(.secondary)
                    Text(String(format: "%.2f", record.baseIndex)).font(.caption.bold())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Güncel Endeks").font(.caption2).foregroundColor(.secondary)
                    Text(String(format: "%.2f", record.currentIndex)).font(.caption.bold())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fiyat Farkı").font(.caption2).foregroundColor(.secondary)
                    Text(record.priceDifference.currencyFormatted)
                        .font(.caption.bold())
                        .foregroundColor(record.isGain ? .hakedisSuccess : .hakedisDanger)
                }
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AddPriceDifferenceView: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var periodName = ""
    @State private var baseIndex = ""
    @State private var currentIndex = ""
    @State private var baseAmount = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Dönem") {
                    TextField("Dönem Adı (Ör: Ocak 2026)", text: $periodName)
                }
                Section("Endeks Değerleri") {
                    TextField("Baz Endeks", text: $baseIndex).keyboardType(.decimalPad)
                    TextField("Güncel Endeks", text: $currentIndex).keyboardType(.decimalPad)
                }
                Section("Tutar") {
                    TextField("Hakediş Tutarı (₺)", text: $baseAmount).keyboardType(.decimalPad)
                }
                if let bi = Double(baseIndex), let ci = Double(currentIndex), let ba = Double(baseAmount), bi > 0 {
                    let ratio = ci / bi
                    let diff = ba * (ratio - 1)
                    Section("Hesap Özeti") {
                        HStack {
                            Text("Endeks Oranı")
                            Spacer()
                            Text(String(format: "%.4f", ratio)).foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Fiyat Farkı")
                            Spacer()
                            Text(diff.currencyFormatted)
                                .foregroundColor(diff >= 0 ? .hakedisSuccess : .hakedisDanger)
                        }
                    }
                }
            }
            .navigationTitle("Fiyat Farkı Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(periodName.isEmpty || baseIndex.isEmpty || currentIndex.isEmpty || baseAmount.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let bi = Double(baseIndex), let ci = Double(currentIndex), let ba = Double(baseAmount) else { return }
        let record = PriceDifferenceRecord(periodName: periodName, baseIndex: bi, currentIndex: ci, baseAmount: ba)
        record.contract = contract
        context.insert(record)
        contract.priceDifferenceRecords.append(record)
        dismiss()
    }
}
