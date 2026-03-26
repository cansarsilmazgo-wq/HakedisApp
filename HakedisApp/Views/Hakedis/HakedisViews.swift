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
                if hakedis.isOverdue {
                    StatusBadge(text: "\(hakedis.daysOverdue)g gecikme", color: .hakedisDanger)
                }
                StatusBadge(text: hakedis.status.rawValue, color: statusColor)
            }
            HStack {
                Text(hakedis.kdvAmount > 0
                     ? "Toplam (KDV): \(hakedis.totalWithKDV.currencyFormatted)"
                     : "Net: \(hakedis.netAmount.currencyFormatted)")
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
                Spacer()
                if hakedis.remainingAmount > 0 && hakedis.status != .draft {
                    Text("Kalan: \(hakedis.remainingAmount.currencyFormatted)")
                        .font(.caption)
                        .foregroundColor(.hakedisDanger)
                }
            }
            if let due = hakedis.dueDate, hakedis.status != .paid {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2)
                    Text("Vade: \(due.shortFormatted)")
                        .font(.caption2)
                }
                .foregroundColor(hakedis.isOverdue ? .hakedisDanger : .secondary)
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
    @State private var hasDueDate = true
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!

    var isValid: Bool { !periodName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hakediş Dönemi") {
                    TextField("Dönem Adı (örn: Ocak 2025)", text: $periodName)
                    DatePicker("Dönem Başlangıcı", selection: $periodStart, displayedComponents: .date)
                    DatePicker("Dönem Sonu", selection: $periodEnd, in: periodStart..., displayedComponents: .date)
                }

                Section("Ödeme Vadesi") {
                    Toggle("Vade Tarihi Belirle", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Vade Tarihi", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Bilgi") {
                    Text("Hakediş oluşturulduğunda, seçilen dönemdeki tüm günlük girişler otomatik olarak hesaplanır.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Sözleşme: \(contract.title)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Taşeron: \(contract.contractor?.name ?? "—")")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        let hakedis = Hakedis(
            periodName: periodName,
            periodStart: periodStart,
            periodEnd: periodEnd,
            dueDate: hasDueDate ? dueDate : nil
        )
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
                                .font(.caption).foregroundColor(.secondary)
                            Text(hakedis.grossAmount.currencyFormatted)
                                .font(.title3.bold())
                        }
                        Spacer()
                        StatusBadge(text: hakedis.status.rawValue, color: statusColor)
                    }
                    Divider()
                    // Kesintiler
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Teminat (%\(Int(hakedis.contract?.retentionRate ?? 0)))")
                                .font(.caption).foregroundColor(.secondary)
                            Text("−\(hakedis.retentionAmount.currencyFormatted)")
                                .font(.subheadline).foregroundColor(.hakedisDanger)
                        }
                        if hakedis.advanceDeduction > 0 {
                            Spacer()
                            VStack(alignment: .center, spacing: 4) {
                                Text("Avans (%\(Int(hakedis.contract?.advanceRate ?? 0)))")
                                    .font(.caption).foregroundColor(.secondary)
                                Text("−\(hakedis.advanceDeduction.currencyFormatted)")
                                    .font(.subheadline).foregroundColor(.hakedisWarning)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(hakedis.kdvAmount > 0 ? "Net (KDV Hariç)" : "Net Hakediş")
                                .font(.caption).foregroundColor(.secondary)
                            Text(hakedis.netAmount.currencyFormatted)
                                .font(.subheadline.bold()).foregroundColor(.hakedisOrange)
                        }
                    }
                    // KDV
                    if hakedis.kdvAmount > 0 {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("KDV (%\(Int(hakedis.contract?.kdvRate ?? 0)))")
                                    .font(.caption).foregroundColor(.secondary)
                                Text(hakedis.kdvAmount.currencyFormatted)
                                    .font(.subheadline)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("KDV Dahil Toplam")
                                    .font(.caption).foregroundColor(.secondary)
                                Text(hakedis.totalWithKDV.currencyFormatted)
                                    .font(.subheadline.bold()).foregroundColor(.hakedisOrange)
                            }
                        }
                    }
                    if hakedis.totalPaid > 0 {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ödenen")
                                    .font(.caption).foregroundColor(.secondary)
                                Text(hakedis.totalPaid.currencyFormatted)
                                    .font(.subheadline).foregroundColor(.hakedisSuccess)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Kalan")
                                    .font(.caption).foregroundColor(.secondary)
                                Text(hakedis.remainingAmount.currencyFormatted)
                                    .font(.subheadline.bold())
                                    .foregroundColor(hakedis.remainingAmount > 0 ? .hakedisDanger : .hakedisSuccess)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            // Due Date / Overdue
            if let due = hakedis.dueDate {
                Section("Vade Bilgisi") {
                    HStack {
                        Label("Vade Tarihi", systemImage: "calendar.badge.clock")
                        Spacer()
                        Text(due.shortFormatted)
                            .foregroundColor(hakedis.isOverdue ? .hakedisDanger : .primary)
                    }
                    if hakedis.isOverdue {
                        HStack {
                            Label("Gecikme", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.hakedisDanger)
                            Spacer()
                            Text("\(hakedis.daysOverdue) gün")
                                .foregroundColor(.hakedisDanger)
                                .bold()
                        }
                        HStack {
                            Label("Gecikme Faizi (%9 yıllık)", systemImage: "percent")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(hakedis.overdueInterest.currencyFormatted)
                                .font(.caption.bold())
                                .foregroundColor(.hakedisDanger)
                        }
                        Text("Toplam Alacak: \((hakedis.remainingAmount + hakedis.overdueInterest).currencyFormatted)")
                            .font(.subheadline.bold())
                            .foregroundColor(.hakedisDanger)
                    } else if hakedis.status != .paid {
                        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                        HStack {
                            Label("Kalan Süre", systemImage: "hourglass")
                                .foregroundColor(.hakedisWarning)
                            Spacer()
                            Text(daysLeft <= 0 ? "Bugün" : "\(daysLeft) gün")
                                .foregroundColor(.hakedisWarning)
                        }
                    }
                }
            }

            // Status Workflow
            Section("Onay Durumu") {
                HakedisStatusWorkflow(hakedis: hakedis)
            }

            // Items
            Section("İş Kalemleri") {
                if hakedis.items.isEmpty {
                    Text("Bu dönemde yapılan iş bulunmadı")
                        .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
                } else {
                    ForEach(hakedis.payments.sorted { $0.paymentDate > $1.paymentDate }, id: \.id) { payment in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(payment.paymentDescription.isEmpty ? "Ödeme" : payment.paymentDescription)
                                    .font(.subheadline)
                                Text(payment.paymentDate.shortFormatted)
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(payment.amount.currencyFormatted)
                                .font(.subheadline.bold())
                                .foregroundColor(.hakedisSuccess)
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
                                .foregroundColor(.hakedisOrange)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    NavigationLink(destination: HakedisPDFPreviewView(hakedis: hakedis)) {
                        Image(systemName: "doc.richtext")
                    }
                    WhatsAppShareButton(hakedis: hakedis)
                    HakedisShareButton(hakedis: hakedis)
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
                            .foregroundColor(isActive ? .hakedisOrange : (isPast ? .hakedisSuccess : .secondary))
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
                    .foregroundColor(.secondary)
                Text(item.workItemName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Önceki").font(.caption2).foregroundColor(.secondary)
                    Text("\(item.previousQuantity.quantityFormatted) \(item.unit)")
                        .font(.caption)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bu Dönem").font(.caption2).foregroundColor(.hakedisOrange)
                    Text("\(item.currentQuantity.quantityFormatted) \(item.unit)")
                        .font(.caption.bold())
                        .foregroundColor(.hakedisOrange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kümülatif").font(.caption2).foregroundColor(.secondary)
                    Text("\(item.cumulativeQuantity.quantityFormatted) \(item.unit)")
                        .font(.caption)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tutar").font(.caption2).foregroundColor(.secondary)
                    Text(item.periodAmount.currencyFormatted)
                        .font(.caption.bold())
                        .foregroundColor(.primary)
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
                        Text("₺").foregroundColor(.secondary)
                    }
                    DatePicker("Ödeme Tarihi", selection: $paymentDate, displayedComponents: .date)
                    TextField("Açıklama", text: $description)
                }
                Section("Kalan Tutar") {
                    Text(hakedis.remainingAmount.currencyFormatted)
                        .font(.headline)
                        .foregroundColor(.hakedisDanger)
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
        let payment = Payment(amount: amt, paymentDate: paymentDate, paymentDescription: description)
        payment.hakedis = hakedis
        hakedis.payments.append(payment)
        if hakedis.remainingAmount - amt <= 0 {
            hakedis.status = .paid
        }
        modelContext.insert(payment)
        dismiss()
    }
}
