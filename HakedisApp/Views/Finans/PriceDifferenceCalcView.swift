import SwiftUI
import SwiftData

// MARK: - PriceDifferenceListView
// Sözleşme bazlı fiyat farkı hesap listesi (4735 Md.8)

struct PriceDifferenceListView: View {
    @Query(sort: \PriceDifferenceCalc.createdAt, order: .reverse) private var calcs: [PriceDifferenceCalc]
    @Query private var contracts: [Contract]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedContractID: UUID? = nil

    private var filtered: [PriceDifferenceCalc] {
        calcs.filter { c in
            guard let cid = selectedContractID else { return true }
            return c.contract?.id == cid
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Sözleşme filtresi
                if !contracts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tümü", isSelected: selectedContractID == nil) {
                                selectedContractID = nil
                            }
                            ForEach(contracts, id: \.id) { c in
                                FilterChip(title: c.title, isSelected: selectedContractID == c.id) {
                                    selectedContractID = selectedContractID == c.id ? nil : c.id
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.card)
                        .padding(.vertical, 6)
                    }
                    .background(Color.hakedisBackground)
                }

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "arrow.up.arrow.down.circle",
                        title: "Fiyat farkı kaydı yok",
                        subtitle: "4735 Md.8 fiyat farkı hesabı ekleyin",
                        actionTitle: "Hesaplama Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { calc in
                            NavigationLink(destination: PriceDifferenceCalcDetail(calc: calc)) {
                                PriceDiffCalcRow(calc: calc)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            do { try modelContext.save() } catch { print(error) }
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
            .accessibilityLabel("Fiyat farkı hesabı ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) {
            PriceDifferenceFormView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Yeni hesap")
            }
        }
    }
}

// MARK: - PriceDifferenceRow

private struct PriceDiffCalcRow: View {
    let calc: PriceDifferenceCalc

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(calc.baseMonth) → \(calc.applicationMonth)")
                        .font(.subheadline.bold())
                    if let name = calc.contract?.title {
                        Text(name).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Pn = \(String(format: "%.4f", calc.pnValue))")
                        .font(.caption.bold())
                        .foregroundColor(calc.pnValue >= 1 ? .hakedisSuccess : .hakedisDanger)
                    Text(calc.priceDifferenceAmount >= 0
                         ? "+\(calc.priceDifferenceAmount.currencyFormatted)"
                         : calc.priceDifferenceAmount.currencyFormatted)
                        .font(.subheadline.bold())
                        .foregroundColor(calc.priceDifferenceAmount >= 0 ? .hakedisSuccess : .hakedisDanger)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fiyat farkı \(calc.baseMonth) - \(calc.applicationMonth), Pn \(String(format: "%.4f", calc.pnValue))")
    }
}

// MARK: - PriceDifferenceFormView
// Yeni hesaplama formu — canlı Pn önizleme

struct PriceDifferenceFormView: View {
    var editingCalc: PriceDifferenceCalc? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contracts: [Contract]

    @State private var selectedContract: Contract? = nil
    @State private var baseMonth = ""
    @State private var appMonth = ""
    @State private var a1 = "0.25"; @State private var a2 = "0.30"
    @State private var a3 = "0.15"; @State private var a4 = "0.28"
    @State private var index1b = ""; @State private var index1c = ""
    @State private var index2b = ""; @State private var index2c = ""
    @State private var index3b = ""; @State private var index3c = ""
    @State private var index4b = ""; @State private var index4c = ""
    @State private var hakedisAmountText = ""
    @State private var showValidation = false

    private let a5: Double = 0.12

    private var pnCalc: Double {
        let da1 = Double(a1) ?? 0, da2 = Double(a2) ?? 0
        let da3 = Double(a3) ?? 0, da4 = Double(a4) ?? 0
        let i1b = Double(index1b) ?? 0, i1c = Double(index1c) ?? 0
        let i2b = Double(index2b) ?? 0, i2c = Double(index2c) ?? 0
        let i3b = Double(index3b) ?? 0, i3c = Double(index3c) ?? 0
        let i4b = Double(index4b) ?? 0, i4c = Double(index4c) ?? 0
        guard i1b > 0, i2b > 0, i3b > 0, i4b > 0 else { return 1.0 }
        return da1*(i1c/i1b) + da2*(i2c/i2b) + da3*(i3c/i3b) + da4*(i4c/i4b) + a5
    }

    private var priceDiff: Double {
        (Double(hakedisAmountText) ?? 0) * (pnCalc - 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                sozlesmeSection
                donemSection
                katsayiSection
                endeksSection
                hakedisSection
                onizlemeSection
            }
            .navigationTitle("Fiyat Farkı Hesabı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
            .onAppear { if let c = editingCalc { populate(from: c) } }
        }
    }

    @ViewBuilder private var sozlesmeSection: some View {
        Section("Sözleşme") {
            Picker("Sözleşme", selection: $selectedContract) {
                Text("Seçilmedi").tag(Optional<Contract>.none)
                ForEach(contracts, id: \.id) { c in Text(c.title).tag(Optional(c)) }
            }
            .accessibilityLabel("Sözleşme seçin")
        }
    }

    @ViewBuilder private var donemSection: some View {
        Section("Dönem") {
            HStack {
                Text("Baz Ay (İhale)"); Spacer()
                TextField("2025-01", text: $baseMonth).multilineTextAlignment(.trailing).accessibilityLabel("Baz ayı")
            }
            HStack {
                Text("Uygulama Ayı"); Spacer()
                TextField("2026-03", text: $appMonth).multilineTextAlignment(.trailing).accessibilityLabel("Uygulama ayı")
            }
            if showValidation && (baseMonth.isEmpty || appMonth.isEmpty) {
                Text("Ay alanları zorunludur").font(.caption).foregroundColor(.hakedisDanger)
            }
        }
    }

    private var katsayiSum: Double {
        let da1 = Double(a1) ?? 0.0
        let da2 = Double(a2) ?? 0.0
        let da3 = Double(a3) ?? 0.0
        let da4 = Double(a4) ?? 0.0
        return da1 + da2 + da3 + da4 + a5
    }

    @ViewBuilder private var katsayiSection: some View {
        Section("Ağırlık Katsayıları (a1+a2+a3+a4+a5 = 1.00)") {
            katsayiRow("a1 — İşçilik", binding: $a1)
            katsayiRow("a2 — Malzeme", binding: $a2)
            katsayiRow("a3 — Enerji", binding: $a3)
            katsayiRow("a4 — Makine Amortismanı", binding: $a4)
            HStack {
                Text("a5 — Genel Gider + Kâr (Sabit)").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("0.12").font(.caption.bold()).foregroundColor(.secondary)
            }
            HStack {
                Text("Toplam").font(.caption.bold()); Spacer()
                Text(String(format: "%.2f", katsayiSum)).font(.caption.bold())
                    .foregroundColor(abs(katsayiSum - 1.0) < 0.001 ? .hakedisSuccess : .hakedisDanger)
            }
        }
    }

    @ViewBuilder private var endeksSection: some View {
        Section("Endeks Değerleri") {
            endeksRow("İ1 (İşçilik)", base: $index1b, current: $index1c)
            endeksRow("İ2 (Malzeme)", base: $index2b, current: $index2c)
            endeksRow("İ3 (Enerji)", base: $index3b, current: $index3c)
            endeksRow("İ4 (Makine)", base: $index4b, current: $index4c)
        }
    }

    @ViewBuilder private var hakedisSection: some View {
        Section("Hakediş Tutarı") {
            HStack {
                Text("An (TL)"); Spacer()
                TextField("0.00", text: $hakedisAmountText)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .accessibilityLabel("Hakediş tutarı")
            }
        }
    }

    @ViewBuilder private var onizlemeSection: some View {
        Section {
            HStack {
                Text("Pn =").font(.headline); Spacer()
                Text(String(format: "%.6f", pnCalc)).font(.headline).fontDesign(.monospaced)
                    .foregroundColor(pnCalc >= 1 ? .hakedisSuccess : .hakedisDanger)
            }
            HStack {
                Text("Fiyat Farkı F = An × (Pn - 1)").font(.subheadline).foregroundColor(.secondary); Spacer()
                Text((priceDiff >= 0 ? "+" : "") + priceDiff.currencyFormatted).font(.subheadline.bold())
                    .foregroundColor(priceDiff >= 0 ? .hakedisSuccess : .hakedisDanger)
            }
        } header: {
            Text("Hesaplama Önizlemesi")
        } footer: {
            Text("Formül: Pn = a1×(İ1n/İ1₀) + a2×(İ2n/İ2₀) + a3×(İ3n/İ3₀) + a4×(İ4n/İ4₀) + a5").font(.caption2)
        }
    }

    @ViewBuilder
    private func katsayiRow(_ label: String, binding: Binding<String>) -> some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            TextField("0.00", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .accessibilityLabel(label)
        }
    }

    @ViewBuilder
    private func endeksRow(_ label: String, base: Binding<String>, current: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack {
                    Text("Baz").font(.caption2).foregroundColor(.secondary)
                    TextField("100", text: base)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .accessibilityLabel("\(label) baz endeksi")
                }
                HStack {
                    Text("Güncel").font(.caption2).foregroundColor(.secondary)
                    TextField("100", text: current)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .accessibilityLabel("\(label) güncel endeksi")
                }
            }
        }
    }

    private func populate(from c: PriceDifferenceCalc) {
        selectedContract = c.contract
        baseMonth = c.baseMonth; appMonth = c.applicationMonth
        a1 = String(c.a1); a2 = String(c.a2)
        a3 = String(c.a3); a4 = String(c.a4)
        index1b = String(c.index1Base);  index1c = String(c.index1Current)
        index2b = String(c.index2Base);  index2c = String(c.index2Current)
        index3b = String(c.index3Base);  index3c = String(c.index3Current)
        index4b = String(c.index4Base);  index4c = String(c.index4Current)
        hakedisAmountText = String(c.hakedisAmount)
    }

    private func save() {
        guard !baseMonth.isEmpty, !appMonth.isEmpty else { showValidation = true; return }
        let calc = editingCalc ?? PriceDifferenceCalc(baseMonth: baseMonth, applicationMonth: appMonth)
        calc.baseMonth = baseMonth; calc.applicationMonth = appMonth
        calc.a1 = Double(a1) ?? 0.25; calc.a2 = Double(a2) ?? 0.30
        calc.a3 = Double(a3) ?? 0.15; calc.a4 = Double(a4) ?? 0.28
        calc.index1Base = Double(index1b) ?? 100; calc.index1Current = Double(index1c) ?? 100
        calc.index2Base = Double(index2b) ?? 100; calc.index2Current = Double(index2c) ?? 100
        calc.index3Base = Double(index3b) ?? 100; calc.index3Current = Double(index3c) ?? 100
        calc.index4Base = Double(index4b) ?? 100; calc.index4Current = Double(index4c) ?? 100
        calc.hakedisAmount = Double(hakedisAmountText) ?? 0
        calc.contract = selectedContract
        if editingCalc == nil { modelContext.insert(calc) }
        do { try modelContext.save() } catch { print(error) }
        dismiss()
    }
}

// MARK: - PriceDifferenceCalcDetail

struct PriceDifferenceCalcDetail: View {
    let calc: PriceDifferenceCalc
    @State private var showingEdit = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Dönem") {
                LabeledContent("Baz Ay (İhale)", value: calc.baseMonth)
                LabeledContent("Uygulama Ayı", value: calc.applicationMonth)
                if let c = calc.contract { LabeledContent("Sözleşme", value: c.title) }
            }
            Section("Katsayılar") {
                LabeledContent("a1 (İşçilik)", value: String(format: "%.4f", calc.a1))
                LabeledContent("a2 (Malzeme)", value: String(format: "%.4f", calc.a2))
                LabeledContent("a3 (Enerji)",  value: String(format: "%.4f", calc.a3))
                LabeledContent("a4 (Makine)",  value: String(format: "%.4f", calc.a4))
                LabeledContent("a5 (Sabit)",   value: String(format: "%.4f", calc.a5))
            }
            Section("Endeksler") {
                endeksRow("İ1 (İşçilik)", base: calc.index1Base, current: calc.index1Current)
                endeksRow("İ2 (Malzeme)", base: calc.index2Base, current: calc.index2Current)
                endeksRow("İ3 (Enerji)",  base: calc.index3Base, current: calc.index3Current)
                endeksRow("İ4 (Makine)",  base: calc.index4Base, current: calc.index4Current)
            }
            Section("Hesaplama Sonucu") {
                HStack {
                    Text("Pn değeri")
                    Spacer()
                    Text(String(format: "%.6f", calc.pnValue))
                        .font(.subheadline.bold()).fontDesign(.monospaced)
                        .foregroundColor(calc.pnValue >= 1 ? .hakedisSuccess : .hakedisDanger)
                }
                LabeledContent("Hakediş Tutarı (An)", value: calc.hakedisAmount.currencyFormatted)
                HStack {
                    Text("Fiyat Farkı (F = An × (Pn−1))")
                    Spacer()
                    Text((calc.priceDifferenceAmount >= 0 ? "+" : "") + calc.priceDifferenceAmount.currencyFormatted)
                        .font(.subheadline.bold())
                        .foregroundColor(calc.priceDifferenceAmount >= 0 ? .hakedisSuccess : .hakedisDanger)
                }
                Text("Formül: Pn = a1×(İ1n/İ1₀) + a2×(İ2n/İ2₀) + a3×(İ3n/İ3₀) + a4×(İ4n/İ4₀) + a5")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(calc.baseMonth) → \(calc.applicationMonth)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Düzenle") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            PriceDifferenceFormView(editingCalc: calc)
        }
    }

    @ViewBuilder
    private func endeksRow(_ label: String, base: Double, current: Double) -> some View {
        let ratio = base > 0 ? current / base : 1.0
        HStack {
            Text(label).font(.caption)
            Spacer()
            Text("\(String(format: "%.2f", base)) → \(String(format: "%.2f", current))")
                .font(.caption).foregroundColor(.secondary)
            Text("(\(String(format: "%.4f", ratio)))")
                .font(.caption.bold())
                .foregroundColor(ratio >= 1 ? .hakedisWarning : .hakedisInfo)
        }
    }
}
