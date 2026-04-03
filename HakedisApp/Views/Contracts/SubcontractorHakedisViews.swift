import SwiftUI
import SwiftData

// MARK: - SubcontractorHakedisListView

struct SubcontractorHakedisListView: View {
    @Query(sort: \SubcontractorHakedis.periodStart, order: .reverse) private var hakedisler: [SubcontractorHakedis]
    @Query private var contractors: [Contractor]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedContractorID: UUID? = nil

    private var filtered: [SubcontractorHakedis] {
        hakedisler.filter { h in
            guard let cid = selectedContractorID else { return true }
            return h.contractor?.id == cid
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if !contractors.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tüm Taşeronlar", isSelected: selectedContractorID == nil) {
                                selectedContractorID = nil
                            }
                            ForEach(contractors, id: \.id) { c in
                                FilterChip(title: c.name, isSelected: selectedContractorID == c.id) {
                                    selectedContractorID = selectedContractorID == c.id ? nil : c.id
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
                        icon: "building.2",
                        title: "Taşeron hakedişi yok",
                        subtitle: "Taşeron hakediş kayıtlarını buradan yönetin",
                        actionTitle: "Hakediş Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Hakediş Listesi") {
                            ForEach(filtered, id: \.id) { h in
                                SubHakedisRow(hakedis: h)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            modelContext.delete(h)
                                        } label: { Label("Sil", systemImage: "trash") }
                                    }
                            }
                        }

                        // Toplam
                        Section("Özet") {
                            let totalGross = filtered.reduce(0) { $0 + $1.grossAmount }
                            let totalNet   = filtered.reduce(0) { $0 + $1.netAmount }
                            LabeledContent("Toplam Brüt", value: totalGross.currencyFormatted)
                            LabeledContent("Toplam Net", value: totalNet.currencyFormatted)
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
            .accessibilityLabel("Taşeron hakediş ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) {
            AddSubHakedisView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Yeni taşeron hakedişi")
            }
        }
    }
}

// MARK: - SubHakedisRow

private struct SubHakedisRow: View {
    let hakedis: SubcontractorHakedis

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hakedis.periodName).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                StatusBadge(
                    text: hakedis.status.rawValue,
                    color: hakedis.status == .paid ? .hakedisSuccess
                           : hakedis.status == .approved ? .hakedisInfo
                           : hakedis.status == .pendingApproval ? .hakedisWarning : .secondary
                )
            }
            if let name = hakedis.contractor?.name {
                Text(name).font(.caption).foregroundColor(.secondary)
            }
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Brüt").font(.caption2).foregroundColor(.secondary)
                    Text(hakedis.grossAmount.currencyFormatted).font(.caption.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Net").font(.caption2).foregroundColor(.secondary)
                    Text(hakedis.netAmount.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hakedis.periodName), \(hakedis.contractor?.name ?? ""), net \(hakedis.netAmount.currencyFormatted)")
    }
}

// MARK: - AddSubHakedisView

struct AddSubHakedisView: View {
    var editingHakedis: SubcontractorHakedis? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contractors: [Contractor]
    @Query private var contracts: [Contract]

    @State private var periodName = ""
    @State private var periodStart = Date()
    @State private var periodEnd = Date()
    @State private var grossAmountText = ""
    @State private var retentionRateText = "5"
    @State private var selectedContractor: Contractor? = nil
    @State private var selectedContract: Contract? = nil
    @State private var statusRaw = HakedisStatus.draft.rawValue
    @State private var notes = ""
    @State private var showValidation = false

    private var grossAmount: Double { Double(grossAmountText) ?? 0 }
    private var retentionRate: Double { Double(retentionRateText) ?? 5 }
    private var retentionAmount: Double { grossAmount * retentionRate / 100 }
    private var netAmount: Double { grossAmount - retentionAmount }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dönem") {
                    TextField("Dönem Adı (örn: Mart 2026)", text: $periodName)
                        .accessibilityLabel("Dönem adı")
                    if showValidation && periodName.isEmpty {
                        Text("Dönem adı zorunludur").font(.caption).foregroundColor(.hakedisDanger)
                    }
                    DatePicker("Başlangıç", selection: $periodStart, displayedComponents: .date)
                    DatePicker("Bitiş", selection: $periodEnd, in: periodStart..., displayedComponents: .date)
                }
                Section("Taraflar") {
                    Picker("Taşeron", selection: $selectedContractor) {
                        Text("Seçilmedi").tag(Optional<Contractor>.none)
                        ForEach(contractors, id: \.id) { c in Text(c.name).tag(Optional(c)) }
                    }
                    .accessibilityLabel("Taşeron")
                    Picker("Sözleşme", selection: $selectedContract) {
                        Text("Seçilmedi").tag(Optional<Contract>.none)
                        ForEach(contracts, id: \.id) { c in Text(c.title).tag(Optional(c)) }
                    }
                    .accessibilityLabel("Sözleşme")
                }
                Section("Tutarlar") {
                    HStack {
                        Text("Brüt Tutar (TL)")
                        Spacer()
                        TextField("0.00", text: $grossAmountText)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("Brüt tutar")
                    }
                    HStack {
                        Text("Teminat Oranı (%)")
                        Spacer()
                        TextField("5", text: $retentionRateText)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60)
                            .accessibilityLabel("Teminat oranı")
                    }
                    LabeledContent("Teminat Kesintisi", value: retentionAmount.currencyFormatted)
                    HStack {
                        Text("Net Tutar").font(.subheadline.bold())
                        Spacer()
                        Text(netAmount.currencyFormatted).font(.subheadline.bold()).foregroundColor(.hakedisOrange)
                    }
                }
                Section("Durum") {
                    Picker("Durum", selection: $statusRaw) {
                        ForEach(HakedisStatus.allCases, id: \.rawValue) { s in
                            Text(s.rawValue).tag(s.rawValue)
                        }
                    }
                    .accessibilityLabel("Hakediş durumu")
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60).accessibilityLabel("Notlar")
                }
            }
            .navigationTitle(editingHakedis == nil ? "Taşeron Hakedişi" : "Hakedişi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
            .onAppear { if let h = editingHakedis { populate(from: h) } }
        }
    }

    private func populate(from h: SubcontractorHakedis) {
        periodName = h.periodName; periodStart = h.periodStart; periodEnd = h.periodEnd
        grossAmountText = String(h.grossAmount)
        retentionRateText = h.grossAmount > 0 ? String(format: "%.1f", h.retentionAmount / h.grossAmount * 100) : "5"
        selectedContractor = h.contractor; selectedContract = h.contract
        statusRaw = h.statusRaw; notes = h.notes ?? ""
    }

    private func save() {
        guard !periodName.isEmpty else { showValidation = true; return }
        let h = editingHakedis ?? SubcontractorHakedis(periodName: periodName, periodStart: periodStart, periodEnd: periodEnd)
        h.periodName = periodName; h.periodStart = periodStart; h.periodEnd = periodEnd
        h.grossAmount = grossAmount; h.retentionAmount = retentionAmount; h.netAmount = netAmount
        h.statusRaw = statusRaw; h.contractor = selectedContractor; h.contract = selectedContract
        h.notes = notes.isEmpty ? nil : notes
        if editingHakedis == nil { modelContext.insert(h) }
        do { try modelContext.save() } catch { print(error) }
        dismiss()
    }
}

// MARK: - ProfitAnalysisView
// Ana hakediş vs taşeron hakediş kâr/zarar analizi

struct ProfitAnalysisView: View {
    @Query private var mainHakedisler: [Hakedis]
    @Query private var subHakedisler: [SubcontractorHakedis]
    @Query private var contracts: [Contract]

    private struct ContractProfitRow: Identifiable {
        let id: UUID
        let contractTitle: String
        let contractorName: String
        let mainNet: Double
        let subNet: Double
        var profit: Double { mainNet - subNet }
        var margin: Double { mainNet > 0 ? profit / mainNet * 100 : 0 }
    }

    private var rows: [ContractProfitRow] {
        contracts.map { c in
            let mainNet = mainHakedisler.filter { $0.contract?.id == c.id }
                .reduce(0) { $0 + $1.netAmount }
            let subNet = subHakedisler.filter { $0.contract?.id == c.id }
                .reduce(0) { $0 + $1.netAmount }
            return ContractProfitRow(
                id: c.id, contractTitle: c.title,
                contractorName: c.contractor?.name ?? "—",
                mainNet: mainNet, subNet: subNet
            )
        }.filter { $0.mainNet > 0 || $0.subNet > 0 }
    }

    var body: some View {
        if rows.isEmpty {
            EmptyStateView(
                icon: "chart.bar.xaxis",
                title: "Kâr analizi için veri yok",
                subtitle: "Hakediş ve taşeron hakediş kayıtları ekleyin"
            )
        } else {
            List {
                Section("Sözleşme Bazlı Kâr Analizi") {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(row.contractTitle).font(.subheadline.bold()).lineLimit(1)
                            Text(row.contractorName).font(.caption).foregroundColor(.secondary)
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ana Hakediş").font(.caption2).foregroundColor(.secondary)
                                    Text(row.mainNet.currencyFormatted).font(.caption.bold())
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Taşeron").font(.caption2).foregroundColor(.secondary)
                                    Text(row.subNet.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisDanger)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Kâr").font(.caption2).foregroundColor(.secondary)
                                    Text(row.profit.currencyFormatted).font(.caption.bold())
                                        .foregroundColor(row.profit >= 0 ? .hakedisSuccess : .hakedisDanger)
                                    Text(String(format: "%%%.1f", row.margin)).font(.caption2)
                                        .foregroundColor(row.margin >= 0 ? .hakedisSuccess : .hakedisDanger)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(row.contractTitle), kâr \(row.profit.currencyFormatted), marj %\(String(format: "%.1f", row.margin))")
                    }
                }

                // Genel toplam
                if !rows.isEmpty {
                    Section("Genel Toplam") {
                        let totalMain  = rows.reduce(0) { $0 + $1.mainNet }
                        let totalSub   = rows.reduce(0) { $0 + $1.subNet }
                        let totalProfit = totalMain - totalSub
                        LabeledContent("Ana Hakediş", value: totalMain.currencyFormatted)
                        LabeledContent("Taşeron Toplam", value: totalSub.currencyFormatted)
                        HStack {
                            Text("Net Kâr").font(.subheadline.bold())
                            Spacer()
                            Text(totalProfit.currencyFormatted).font(.subheadline.bold())
                                .foregroundColor(totalProfit >= 0 ? .hakedisSuccess : .hakedisDanger)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Kâr Analizi")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
