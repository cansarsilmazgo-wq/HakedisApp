import SwiftUI
import SwiftData

// MARK: - Hakedis List Row
struct HakedisListRow: View {
    let hakedis: Hakedis

    var statusColor: Color {
        switch hakedis.status {
        case .draft: return .secondary
        case .pendingApproval: return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        case .paid: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hakedis.periodName)
                    .font(.subheadline.bold())
                Spacer()
                StatusBadge(text: hakedis.status.rawValue, color: statusColor)
            }
            HStack {
                Text("Net: \(hakedis.netAmount.currencyFormatted)")
                    .font(.caption.bold())
                    .foregroundStyle(.hakedisOrange)
                Spacer()
                if hakedis.remainingAmount > 0 && hakedis.status != .draft {
                    Text("Kalan: \(hakedis.remainingAmount.currencyFormatted)")
                        .font(.caption)
                        .foregroundStyle(.hakedisDanger)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Hakedis
struct AddHakedisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let contract: Contract

    @State private var periodName = ""
    @State private var periodStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var periodEnd = Date()

    var isValid: Bool { !periodName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hakediş Dönemi") {
                    TextField("Dönem Adı (örn: Ocak 2025)", text: $periodName)
                    DatePicker("Dönem Başlangıcı", selection: $periodStart, displayedComponents: .date)
                    DatePicker("Dönem Sonu", selection: $periodEnd, in: periodStart..., displayedComponents: .date)
                }

                Section("Bilgi") {
                    Text("Hakediş oluşturulduğunda, seçilen dönemdeki tüm günlük girişler otomatik olarak hesaplanır.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Sözleşme: \(contract.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Taşeron: \(contract.contractor?.name ?? "—")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Yeni Hakediş")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Auto-fill period name
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "tr_TR")
                formatter.dateFormat = "MMMM yyyy"
                periodName = formatter.string(from: Date())
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") { create() }
                        .disabled(!isValid)
                        .bold()
                }
            }
        }
    }

    private func create() {
        let hakedis = Hakedis(periodName: periodName, periodStart: periodStart, periodEnd: periodEnd)
        hakedis.contract = contract

        // Auto-calculate: find previous hakedis cumulative quantities
        let previousHakedisler = contract.hakedisler.filter { $0.periodEnd < periodStart }

        for workItem in contract.workItems {
            // Previous cumulative quantity from past hakedisler
            let previousQty = previousHakedisler.flatMap { $0.items }
                .filter { $0.workItemCode == workItem.code }
                .map { $0.cumulativeQuantity }
                .max() ?? 0

            // This period quantity from daily entries
            let periodEntries = workItem.dailyEntries.filter {
                $0.date >= periodStart && $0.date <= periodEnd
            }
            let currentQty = periodEntries.reduce(0) { $0 + $1.quantity }

            // Only add if there's work done in this period
            if currentQty > 0 {
                let item = HakedisItem(
                    workItemName: workItem.name,
                    workItemCode: workItem.code,
                    unit: workItem.unit,
                    unitPrice: workItem.unitPrice,
                    previousQuantity: previousQty,
                    currentQuantity: currentQty
                )
                item.hakedis = hakedis
                hakedis.items.append(item)
                modelContext.insert(item)
            }
        }

        contract.hakedisler.append(hakedis)
        modelContext.insert(hakedis)
        dismiss()
    }
}

// MARK: - Hakedis Detail
struct HakedisDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let hakedis: Hakedis
    @State private var showingAddPayment = false

    var statusColor: Color {
        switch hakedis.status {
        case .draft: return .secondary
        case .pendingApproval: return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        case .paid: return .blue
        }
    }

    var body: some View {
        List {
            // Summary
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Brüt Tutar")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(hakedis.grossAmount.currencyFormatted)
                                .font(.title3.bold())
                        }
                        Spacer()
                        StatusBadge(text: hakedis.status.rawValue, color: statusColor)
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Teminat Kesintisi")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(hakedis.retentionAmount.currencyFormatted)
                                .font(.subheadline)
                                .foregroundStyle(.hakedisDanger)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Net Hakediş")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(hakedis.netAmount.currencyFormatted)
                                .font(.subheadline.bold())
                                .foregroundStyle(.hakedisOrange)
                        }
                    }
                    if hakedis.totalPaid > 0 {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ödenen")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(hakedis.totalPaid.currencyFormatted)
                                    .font(.subheadline)
                                    .foregroundStyle(.hakedisSuccess)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Kalan")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(hakedis.remainingAmount.currencyFormatted)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(hakedis.remainingAmount > 0 ? .hakedisDanger : .hakedisSuccess)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            // Status Workflow
            Section("Onay Durumu") {
                HakedisStatusWorkflow(hakedis: hakedis)
            }

            // Items
            Section("İş Kalemleri") {
                if hakedis.items.isEmpty {
                    Text("Bu dönemde yapılan iş bulunmadı")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(hakedis.items) { item in
                        HakedisItemRow(item: item)
                    }
                }
            }

            // Payments
            Section {
                if hakedis.payments.isEmpty {
                    Text("Henüz ödeme yapılmadı")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(hakedis.payments.sorted { $0.paymentDate > $1.paymentDate }) { payment in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(payment.description.isEmpty ? "Ödeme" : payment.description)
                                    .font(.subheadline)
                                Text(payment.paymentDate.shortFormatted)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(payment.amount.currencyFormatted)
                                .font(.subheadline.bold())
                                .foregroundStyle(.hakedisSuccess)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Ödemeler")
                    Spacer()
                    if hakedis.status == .approved || hakedis.status == .paid {
                        Button {
                            showingAddPayment = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.hakedisOrange)
                        }
                    }
                }
            }
        }
        .navigationTitle(hakedis.periodName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddPayment) {
            AddPaymentView(hakedis: hakedis)
        }
    }
}

// MARK: - Hakedis Status Workflow
struct HakedisStatusWorkflow: View {
    @Environment(\.modelContext) private var modelContext
    let hakedis: Hakedis

    var body: some View {
        VStack(spacing: 12) {
            // Status steps
            HStack(spacing: 0) {
                ForEach(Array(HakedisStatus.allCases.enumerated()), id: \.element) { index, status in
                    let isActive = hakedis.status == status
                    let isPast = statusIndex(hakedis.status) > statusIndex(status)

                    VStack(spacing: 4) {
                        Circle()
                            .fill(isActive ? Color.hakedisOrange : (isPast ? Color.hakedisSuccess : Color.secondary.opacity(0.3)))
                            .frame(width: 10, height: 10)
                        Text(status.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(isActive ? .hakedisOrange : (isPast ? .hakedisSuccess : .secondary))
                            .multilineTextAlignment(.center)
                            .frame(width: 56)
                    }
                    if index < HakedisStatus.allCases.count - 1 {
                        Rectangle()
                            .fill(isPast ? Color.hakedisSuccess : Color.secondary.opacity(0.3))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .offset(y: -8)
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                switch hakedis.status {
                case .draft:
                    Button("Onaya Gönder") {
                        hakedis.status = .pendingApproval
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.hakedisOrange)
                case .pendingApproval:
                    Button("Reddet") {
                        hakedis.status = .rejected
                    }
                    .buttonStyle(.bordered)
                    .tint(.hakedisDanger)
                    Button("Onayla") {
                        hakedis.status = .approved
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.hakedisSuccess)
                case .approved:
                    if hakedis.remainingAmount <= 0 {
                        Button("Ödendi Olarak İşaretle") {
                            hakedis.status = .paid
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                case .rejected:
                    Button("Taslağa Al") {
                        hakedis.status = .draft
                    }
                    .buttonStyle(.bordered)
                default:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusIndex(_ status: HakedisStatus) -> Int {
        HakedisStatus.allCases.firstIndex(of: status) ?? 0
    }
}

// MARK: - Hakedis Item Row
struct HakedisItemRow: View {
    let item: HakedisItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("[\(item.workItemCode)]")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(item.workItemName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Önceki").font(.caption2).foregroundStyle(.secondary)
                    Text("\(item.previousQuantity.quantityFormatted) \(item.unit)")
                        .font(.caption)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bu Dönem").font(.caption2).foregroundStyle(.hakedisOrange)
                    Text("\(item.currentQuantity.quantityFormatted) \(item.unit)")
                        .font(.caption.bold())
                        .foregroundStyle(.hakedisOrange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kümülatif").font(.caption2).foregroundStyle(.secondary)
                    Text("\(item.cumulativeQuantity.quantityFormatted) \(item.unit)")
                        .font(.caption)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tutar").font(.caption2).foregroundStyle(.secondary)
                    Text(item.periodAmount.currencyFormatted)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Payment
struct AddPaymentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let hakedis: Hakedis

    @State private var amount = ""
    @State private var paymentDate = Date()
    @State private var description = ""

    var isValid: Bool {
        (Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ödeme Bilgileri") {
                    HStack {
                        Text("Tutar *")
                        Spacer()
                        TextField("0,00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("₺").foregroundStyle(.secondary)
                    }
                    DatePicker("Ödeme Tarihi", selection: $paymentDate, displayedComponents: .date)
                    TextField("Açıklama", text: $description)
                }
                Section("Kalan Tutar") {
                    Text(hakedis.remainingAmount.currencyFormatted)
                        .font(.headline)
                        .foregroundStyle(.hakedisDanger)
                }
            }
            .navigationTitle("Ödeme Ekle")
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
        let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        let payment = Payment(amount: amt, paymentDate: paymentDate, description: description)
        payment.hakedis = hakedis
        hakedis.payments.append(payment)
        if hakedis.remainingAmount - amt <= 0 {
            hakedis.status = .paid
        }
        modelContext.insert(payment)
        dismiss()
    }
}
