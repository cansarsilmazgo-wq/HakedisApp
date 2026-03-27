import SwiftUI
import SwiftData

// MARK: - Change Order List View

struct ChangeOrderListView: View {
    @Environment(\.modelContext) private var modelContext
    let contract: Contract
    @State private var showingAdd = false

    private var sorted: [ChangeOrder] {
        contract.changeOrders.sorted { $0.createdAt > $1.createdAt }
    }

    private var approvedTotal: Double {
        contract.approvedChangeOrderAmount
    }
    private var pendingTotal: Double {
        contract.pendingChangeOrderAmount
    }

    var body: some View {
        List {
            // Özet
            Section("Ek İş Özeti") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Orijinal Sözleşme").font(.caption).foregroundColor(.secondary)
                            Text(contract.totalContractAmount.currencyFormatted)
                                .font(.subheadline.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Efektif Tutar").font(.caption).foregroundColor(.secondary)
                            Text(contract.effectiveContractAmount.currencyFormatted)
                                .font(.subheadline.bold())
                                .foregroundColor(
                                    approvedTotal > 0 ? .hakedisWarning :
                                    approvedTotal < 0 ? .hakedisSuccess : .primary
                                )
                        }
                    }

                    if approvedTotal != 0 || pendingTotal != 0 {
                        Divider()
                        if approvedTotal != 0 {
                            HStack {
                                Label("Onaylı Ek İşler", systemImage: "checkmark.circle.fill")
                                    .font(.caption).foregroundColor(.hakedisSuccess)
                                Spacer()
                                Text(approvedTotal >= 0
                                     ? "+\(approvedTotal.currencyFormatted)"
                                     : approvedTotal.currencyFormatted)
                                    .font(.caption.bold())
                                    .foregroundColor(approvedTotal >= 0 ? .hakedisWarning : .hakedisSuccess)
                            }
                        }
                        if pendingTotal != 0 {
                            HStack {
                                Label("Bekleyen Ek İşler", systemImage: "clock.fill")
                                    .font(.caption).foregroundColor(.hakedisWarning)
                                Spacer()
                                Text(pendingTotal >= 0
                                     ? "+\(pendingTotal.currencyFormatted)"
                                     : pendingTotal.currencyFormatted)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Liste
            Section {
                if sorted.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Henüz ek iş emri yok")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("+ butonuna basarak ilk ek iş emrini oluşturun")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    ForEach(sorted) { co in
                        NavigationLink(destination: ChangeOrderDetailView(changeOrder: co)) {
                            ChangeOrderRow(changeOrder: co)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { sorted[$0] }.forEach { modelContext.delete($0) }
                    }
                }
            } header: {
                HStack {
                    Text("Ek İş Emirleri (\(sorted.count))")
                    Spacer()
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.hakedisOrange)
                    }
                }
            }

            // Durum bazlı özet
            if !sorted.isEmpty {
                Section("Durum Özeti") {
                    ForEach(ChangeOrderStatus.allCases, id: \.self) { status in
                        let items = sorted.filter { $0.status == status }
                        if !items.isEmpty {
                            let total = items.reduce(0) { $0 + $1.amount }
                            HStack {
                                StatusBadge(
                                    text: status.rawValue,
                                    color: status == .approved ? .hakedisSuccess
                                         : status == .pending  ? .hakedisWarning
                                                               : .hakedisDanger
                                )
                                Spacer()
                                Text("\(items.count) adet").font(.caption).foregroundColor(.secondary)
                                Text(total >= 0 ? "+\(total.currencyFormatted)" : total.currencyFormatted)
                                    .font(.caption.bold())
                                    .foregroundColor(status == .approved ? .hakedisWarning : .secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Ek İş Emirleri")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddChangeOrderView(contract: contract)
        }
    }
}

// MARK: - Change Order Row

struct ChangeOrderRow: View {
    let changeOrder: ChangeOrder

    var statusColor: Color {
        switch changeOrder.status {
        case .pending:  return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(changeOrder.title).font(.subheadline.bold())
                Spacer()
                StatusBadge(text: changeOrder.status.rawValue, color: statusColor)
            }
            HStack {
                Text(changeOrder.changeDate.shortFormatted)
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                let sign = changeOrder.amount >= 0 ? "+" : ""
                Text("\(sign)\(changeOrder.amount.currencyFormatted)")
                    .font(.caption.bold())
                    .foregroundColor(changeOrder.amount >= 0 ? .hakedisWarning : .hakedisSuccess)
            }
            if !changeOrder.reason.isEmpty {
                Text(changeOrder.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Change Order Detail View

struct ChangeOrderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let changeOrder: ChangeOrder

    @State private var showingApprove = false
    @State private var showingReject  = false
    @State private var approvalNote   = ""

    var statusColor: Color {
        switch changeOrder.status {
        case .pending:  return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        }
    }

    var body: some View {
        List {
            Section("Ek İş Emri Detayı") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tutar").font(.caption).foregroundColor(.secondary)
                            let sign = changeOrder.amount >= 0 ? "+" : ""
                            Text("\(sign)\(changeOrder.amount.currencyFormatted)")
                                .font(.title2.bold())
                                .foregroundColor(changeOrder.amount >= 0 ? .hakedisWarning : .hakedisSuccess)
                        }
                        Spacer()
                        StatusBadge(text: changeOrder.status.rawValue, color: statusColor)
                    }
                    Divider()
                    LabeledContent("Tarih", value: changeOrder.changeDate.shortFormatted)
                    LabeledContent("Sözleşme", value: changeOrder.contract?.title ?? "—")
                }
                .padding(.vertical, 4)
            }

            if !changeOrder.reason.isEmpty {
                Section("Gerekçe") {
                    Text(changeOrder.reason)
                        .font(.subheadline)
                }
            }

            if !changeOrder.approvalNote.isEmpty {
                Section("Onay / Red Notu") {
                    Text(changeOrder.approvalNote)
                        .font(.subheadline)
                        .foregroundColor(changeOrder.status == .rejected ? .hakedisDanger : .hakedisSuccess)
                }
            }

            // İşlem butonları — sadece beklemedeyse
            if changeOrder.status == .pending {
                Section {
                    Button {
                        showingApprove = true
                    } label: {
                        Label("Onayla", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.hakedisSuccess)
                    }
                    Button {
                        showingReject = true
                    } label: {
                        Label("Reddet", systemImage: "xmark.circle.fill")
                            .foregroundColor(.hakedisDanger)
                    }
                }
            }
        }
        .navigationTitle(changeOrder.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingApprove) {
            ChangeOrderDecisionView(
                changeOrder: changeOrder,
                decision: .approved,
                onDone: { showingApprove = false }
            )
        }
        .sheet(isPresented: $showingReject) {
            ChangeOrderDecisionView(
                changeOrder: changeOrder,
                decision: .rejected,
                onDone: { showingReject = false }
            )
        }
    }
}

// MARK: - Change Order Decision Sheet

struct ChangeOrderDecisionView: View {
    @Environment(\.dismiss) private var dismiss
    let changeOrder: ChangeOrder
    let decision: ChangeOrderStatus
    let onDone: () -> Void

    @State private var note = ""

    var isApproval: Bool { decision == .approved }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ek İş Emri") {
                    LabeledContent("Başlık", value: changeOrder.title)
                    let sign = changeOrder.amount >= 0 ? "+" : ""
                    LabeledContent("Tutar", value: "\(sign)\(changeOrder.amount.currencyFormatted)")
                }
                Section(isApproval ? "Onay Notu (opsiyonel)" : "Red Gerekçesi *") {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(isApproval ? "Onayla" : "Reddet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isApproval ? "Onayla" : "Reddet") {
                        changeOrder.status = decision
                        changeOrder.approvalNote = note
                        onDone()
                        dismiss()
                    }
                    .disabled(!isApproval && note.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                    .foregroundColor(isApproval ? .hakedisSuccess : .hakedisDanger)
                }
            }
        }
    }
}

// MARK: - Add Change Order View

struct AddChangeOrderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let contract: Contract

    @State private var title = ""
    @State private var changeDate = Date()
    @State private var reason = ""
    @State private var amountText = ""
    @State private var isDeduction = false   // negatif miktar (keşif azaltması)

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && parsedAmount != nil && parsedAmount! > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ek İş Bilgileri") {
                    TextField("Başlık *", text: $title)
                    DatePicker("Tarih", selection: $changeDate, displayedComponents: .date)
                }

                Section {
                    Picker("Tür", selection: $isDeduction) {
                        Text("Ek İş (Artış)").tag(false)
                        Text("Keşif Azaltması").tag(true)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(isDeduction ? "Azaltma Tutarı *" : "Ek İş Tutarı *")
                        Spacer()
                        TextField("0,00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                        Text("₺").foregroundColor(.secondary)
                    }
                } header: {
                    Text("Tutar")
                } footer: {
                    Group {
                        if let amt = parsedAmount, amt > 0 {
                            let effective = contract.totalContractAmount + (isDeduction ? -amt : amt)
                            Text("Efektif sözleşme tutarı: \(effective.currencyFormatted)")
                        }
                    }
                }

                Section("Gerekçe (opsiyonel)") {
                    TextEditor(text: $reason)
                        .frame(minHeight: 60)
                }

                Section("Sözleşme") {
                    LabeledContent("Sözleşme", value: contract.title)
                    LabeledContent("Orijinal Tutar", value: contract.totalContractAmount.currencyFormatted)
                    if contract.approvedChangeOrderAmount != 0 {
                        LabeledContent("Mevcut Ek İşler",
                                       value: "+\(contract.approvedChangeOrderAmount.currencyFormatted)")
                    }
                }
            }
            .navigationTitle("Ek İş Emri Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }
                        .disabled(!isValid)
                        .bold()
                }
            }
        }
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let finalAmount = isDeduction ? -amount : amount
        let co = ChangeOrder(title: title, changeDate: changeDate, reason: reason, amount: finalAmount)
        co.contract = contract
        contract.changeOrders.append(co)
        modelContext.insert(co)
        dismiss()
    }
}
