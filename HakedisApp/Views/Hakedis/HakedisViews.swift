import SwiftUI
import SwiftData
import MessageUI

// MARK: - Hakedis List Row
struct HakedisListRow: View {
    let hakedis: Hakedis

    var statusColor: Color {
        switch hakedis.status {
        case .draft: return .secondary
        case .pendingApproval: return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        case .paid: return .hakedisPaid
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hakedis.periodName), \(hakedis.status.rawValue), \(hakedis.netAmount.currencyFormatted)\(hakedis.isOverdue ? ", \(hakedis.daysOverdue) gün gecikme" : "")")
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
    @State private var showingMeasurementImport = false
    @State private var measurementOverrides: [String: Double] = [:]
    @State private var lumpSumCompletionPct: Double = 0.0

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

                if contract.contractType == .lumpSum {
                    Section("Götürü Bedel Tamamlanması") {
                        Stepper(
                            "Tamamlanma: %\(Int(lumpSumCompletionPct))",
                            value: $lumpSumCompletionPct,
                            in: 0...100,
                            step: 1
                        )
                        HStack {
                            Text("Efektif Brüt Tutar")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text((contract.totalContractAmount * lumpSumCompletionPct / 100).currencyFormatted)
                                .bold()
                                .foregroundColor(.hakedisOrange)
                        }
                        Text("Götürü bedelde brüt tutar = sözleşme bedeli × tamamlanma %'si.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Metraj Defteri") {
                    Button {
                        showingMeasurementImport = true
                    } label: {
                        HStack {
                            Label("Metraj Kayıtlarından İçe Aktar", systemImage: "ruler.fill")
                                .foregroundColor(.hakedisOrange)
                            Spacer()
                            if !measurementOverrides.isEmpty {
                                Text("\(measurementOverrides.count) kalem")
                                    .font(.caption.bold())
                                    .foregroundColor(.hakedisSuccess)
                            }
                        }
                    }
                    if measurementOverrides.isEmpty {
                        Text("Onaylanmış metraj kayıtlarını seçerek bu hakedişe dahil edebilirsiniz.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Label("\(measurementOverrides.count) iş kalemi metrajdan aktarılacak — günlük saha girişleri yerine kullanılır.",
                              systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.hakedisSuccess)
                        Button("Seçimi Temizle") {
                            measurementOverrides = [:]
                        }
                        .font(.caption)
                        .foregroundColor(.hakedisDanger)
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
            .sheet(isPresented: $showingMeasurementImport) {
                MeasurementImportSheet(contract: contract, periodStart: periodStart, periodEnd: periodEnd) { overrides in
                    measurementOverrides = overrides
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
        hakedis.lumpSumCompletionPercentage = lumpSumCompletionPct

        // Auto-calculate: find previous hakedis cumulative quantities
        let previousHakedisler = contract.hakedisler.filter { $0.periodEnd < periodStart }

        for workItem in contract.workItems {
            // Previous cumulative quantity from past hakedisler
            let previousQty = previousHakedisler.flatMap { $0.items }
                .filter { $0.workItemCode == workItem.code }
                .map { $0.cumulativeQuantity }
                .max() ?? 0

            // This period: prefer measurement override over daily entries
            let currentQty: Double
            if let overrideQty = measurementOverrides[workItem.code] {
                currentQty = overrideQty
            } else {
                let periodEntries = workItem.dailyEntries.filter {
                    $0.date >= periodStart && $0.date <= periodEnd
                }
                currentQty = periodEntries.reduce(0) { $0 + $1.quantity }
            }

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
        AuditLogHelper.log(context: modelContext, hakedis: hakedis, action: .created, details: "Hakediş oluşturuldu: \(periodName)")

        if hasDueDate {
            NotificationManager.shared.scheduleHakedisDueDateAlerts(hakedis: hakedis)
        }

        dismiss()
    }
}

// MARK: - Hakedis Detail
struct HakedisDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let hakedis: Hakedis
    @State private var showingAddPayment = false
    @State private var showingRejectionCapture = false
    @State private var editingItem: HakedisItem?
    @State private var showingKopyala = false
    @State private var showingPetition = false
    @State private var paymentToDelete: Payment?
    @State private var showPaymentToast = false
    @State private var showingMailCompose = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @StateObject private var authManager = AuthManager.shared

    var statusColor: Color {
        switch hakedis.status {
        case .draft: return .secondary
        case .pendingApproval: return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        case .paid: return .hakedisPaid
        }
    }

    var body: some View {
        List {
            // Summary
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(hakedis.contract?.contractType == .lumpSum ? "Efektif Brüt (Götürü %\(Int(hakedis.lumpSumCompletionPercentage)))" : "Brüt Tutar")
                                .font(.caption).foregroundColor(.secondary)
                            Text((hakedis.contract?.contractType == .lumpSum
                                  ? hakedis.effectiveGrossAmount
                                  : hakedis.grossAmount).currencyFormatted)
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
                    // Stopaj ve Damga Vergisi
                    HakedisVergiSection(hakedis: hakedis)
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

            // Götürü Bedel Tamamlanma Yüzdesi (sadece lump-sum sözleşmelerde)
            if hakedis.contract?.contractType == .lumpSum {
                Section("Götürü Bedel Tamamlanması") {
                    Stepper(
                        "Tamamlanma: %\(Int(hakedis.lumpSumCompletionPercentage))",
                        value: Binding(
                            get: { hakedis.lumpSumCompletionPercentage },
                            set: { hakedis.lumpSumCompletionPercentage = $0 }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    HStack {
                        Text("Efektif Brüt Tutar").foregroundColor(.secondary)
                        Spacer()
                        Text(hakedis.effectiveGrossAmount.currencyFormatted)
                            .bold().foregroundColor(.hakedisOrange)
                    }
                    if let total = hakedis.contract?.totalContractAmount, total > 0 {
                        HStack {
                            Text("Sözleşme Bedeli").foregroundColor(.secondary).font(.caption)
                            Spacer()
                            Text(total.currencyFormatted).font(.caption)
                        }
                    }
                }
            }

            // Versiyon Timeline (redler varsa)
            if !hakedis.revisions.isEmpty {
                Section {
                    RevisionVersionTimeline(hakedis: hakedis)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
            }

            // Status Workflow
            Section("Onay Durumu") {
                HakedisStatusWorkflow(hakedis: hakedis)
            }

            // İmza Zinciri
            Section("Onay Zinciri") {
                ApprovalChainSection(hakedis: hakedis)
            }

            // Items
            Section("İş Kalemleri") {
                if hakedis.items.isEmpty {
                    Text("Bu dönemde yapılan iş bulunmadı")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(hakedis.items) { item in
                        HakedisItemCumulativeRow(item: item, contract: hakedis.contract)
                            .swipeActions(edge: .trailing) {
                                if hakedis.status == .draft {
                                    Button {
                                        editingItem = item
                                    } label: {
                                        Label("Düzenle", systemImage: "pencil")
                                    }
                                    .tint(.hakedisOrange)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if hakedis.status == .draft {
                                    Button(role: .destructive) {
                                        hakedis.items.removeAll { $0.id == item.id }
                                        modelContext.delete(item)
                                    } label: {
                                        Label("Sil", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }

            // KDV Tevkifatı
            Section {
                VATWithholdingSection(hakedis: hakedis)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            // Fotoğraflı Kanıt
            HakedisPhotoEvidenceSection(hakedis: hakedis, contract: hakedis.contract)

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
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                paymentToDelete = payment
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
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
                    if hakedis.status == .approved || hakedis.status == .paid {
                        Button {
                            showingKopyala = true
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    if hakedis.status == .rejected {
                        Button {
                            showingPetition = true
                        } label: {
                            Image(systemName: "doc.text")
                        }
                    }
                    NavigationLink(destination: HakedisApprovalAnalysisView(hakedis: hakedis)) {
                        Image(systemName: "chart.bar.doc.horizontal")
                    }
                    NavigationLink(destination: HakedisPDFPreviewView(hakedis: hakedis)) {
                        Image(systemName: "doc.richtext")
                    }
                    if authManager.currentRole.canExportData && MFMailComposeViewController.canSendMail() {
                        Button {
                            showingMailCompose = true
                        } label: {
                            Image(systemName: "envelope")
                        }
                        .accessibilityLabel("E-posta ile gönder")
                    }
                    WhatsAppShareButton(hakedis: hakedis)
                    HakedisShareButton(hakedis: hakedis)
                }
            }
        }
        .sheet(isPresented: $showingMailCompose) {
            HakedisMailComposeView(hakedis: hakedis, result: $mailResult)
        }
        .navigationTitle(hakedis.periodName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingKopyala) {
            HakedisKopyalaView(hakedis: hakedis)
        }
        .sheet(isPresented: $showingPetition) {
            PetitionGeneratorView(hakedis: hakedis)
        }
        .sheet(isPresented: $showingAddPayment) {
            AddPaymentView(hakedis: hakedis)
        }
        .sheet(isPresented: $showingRejectionCapture) {
            RejectionCaptureSheet(hakedis: hakedis)
        }
        .sheet(item: $editingItem) { item in
            EditHakedisItemView(item: item)
        }
        .onChange(of: hakedis.payments.count) { old, new in
            if new > old { withAnimation { showPaymentToast = true } }
        }
        .toast(isPresented: $showPaymentToast, message: "Ödeme kaydedildi")
        .onChange(of: hakedis.status) { _, newStatus in
            if newStatus == .rejected {
                showingRejectionCapture = true
            }
        }
        .onChange(of: hakedis.dueDate) { _, newDueDate in
            NotificationManager.shared.cancelHakedisDueDateAlerts(hakedisID: hakedis.id)
            if newDueDate != nil {
                NotificationManager.shared.scheduleHakedisDueDateAlerts(hakedis: hakedis)
            }
        }
        .onChange(of: hakedis.modelContext == nil) { _, isDeleted in
            if isDeleted { dismiss() }
        }
        .confirmationDialog(
            paymentToDelete.map { "\($0.amount.currencyFormatted) tutarındaki ödeme silinsin mi?" } ?? "",
            isPresented: Binding(get: { paymentToDelete != nil }, set: { if !$0 { paymentToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Ödemeyi Sil", role: .destructive) {
                if let p = paymentToDelete {
                    hakedis.payments.removeAll { $0.id == p.id }
                    modelContext.delete(p)
                    if hakedis.status == .paid && hakedis.remainingAmount > 0 {
                        hakedis.status = .approved
                    }
                }
                paymentToDelete = nil
            }
            Button("İptal", role: .cancel) { paymentToDelete = nil }
        }
    }
}

// MARK: - Hakedis Status Workflow
struct HakedisStatusWorkflow: View {
    @Environment(\.modelContext) private var modelContext
    let hakedis: Hakedis
    @State private var noteText = ""
    @State private var pendingStatus: HakedisStatus? = nil
    @State private var showingNoteSheet = false
    @State private var showBlockedAlert = false

    private var hasBlockingTests: Bool {
        hakedis.contract?.testRecords.contains { $0.blocksApproval } ?? false
    }

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
                            .frame(height: 1).frame(maxWidth: .infinity).offset(y: -8)
                    }
                }
            }

            // Approval note display
            if !hakedis.approvalNote.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: hakedis.status == .rejected ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(hakedis.status == .rejected ? .hakedisDanger : .hakedisSuccess)
                        .font(.caption)
                    Text(hakedis.approvalNote)
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Action Buttons
            HStack(spacing: 12) {
                switch hakedis.status {
                case .draft:
                    Button("Onaya Gönder") {
                        if hasBlockingTests {
                            showBlockedAlert = true
                        } else {
                            hakedis.status = .pendingApproval
                            AuditLogHelper.log(context: modelContext, hakedis: hakedis, action: .submitted)
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(.hakedisOrange)
                case .pendingApproval:
                    Button("Reddet") {
                        noteText = hakedis.approvalNote
                        pendingStatus = .rejected
                        showingNoteSheet = true
                    }
                    .buttonStyle(.bordered).tint(.hakedisDanger)
                    Button("Onayla") {
                        if hasBlockingTests {
                            showBlockedAlert = true
                        } else {
                            noteText = hakedis.approvalNote
                            pendingStatus = .approved
                            showingNoteSheet = true
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(.hakedisSuccess)
                case .approved:
                    // FIX-3: grossAmount > 0 kontrolü — sıfır hakedişi yanlışlıkla .paid yapılmasın
                    if hakedis.remainingAmount <= 0 && hakedis.grossAmount > 0 {
                        Button("Ödendi Olarak İşaretle") {
                            hakedis.status = .paid
                            AuditLogHelper.log(context: modelContext, hakedis: hakedis, action: .paid)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.hakedisPaid)
                    }
                case .rejected:
                    // FIX-5: Taslağa dönüşte onay zincirini temizle — yeni zincir kurulabilsin
                    Button("Taslağa Al") {
                        for step in hakedis.approvalSteps {
                            modelContext.delete(step)
                        }
                        hakedis.approvalSteps.removeAll()
                        hakedis.status = .draft
                    }
                    .buttonStyle(.bordered)
                default:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
        .alert("Onay Engelliyor", isPresented: $showBlockedAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Başarısız test kaydı var, onay verilemez.")
        }
        .sheet(isPresented: $showingNoteSheet) {
            ApprovalNoteSheet(
                title: pendingStatus == .rejected ? "Red Gerekçesi" : "Onay Notu",
                placeholder: pendingStatus == .rejected
                    ? "Reddetme gerekçenizi yazın…"
                    : "İsteğe bağlı onay notu…",
                note: $noteText,
                actionLabel: pendingStatus == .rejected ? "Reddet" : "Onayla",
                actionColor: pendingStatus == .rejected ? .hakedisDanger : .hakedisSuccess
            ) {
                if let s = pendingStatus {
                    hakedis.status = s
                    hakedis.approvalNote = noteText.trimmingCharacters(in: .whitespaces)
                    let action: AuditAction = s == .approved ? .approved : .rejected
                    let note = noteText.trimmingCharacters(in: .whitespaces)
                    AuditLogHelper.log(context: modelContext, hakedis: hakedis, action: action, details: note.isEmpty ? nil : note)
                }
            }
        }
    }

    private func statusIndex(_ status: HakedisStatus) -> Int {
        HakedisStatus.allCases.firstIndex(of: status) ?? 0
    }
}

// MARK: - Approval Note Sheet
struct ApprovalNoteSheet: View {
    let title: String
    let placeholder: String
    @Binding var note: String
    let actionLabel: String
    let actionColor: Color
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if note.isEmpty {
                                Text(placeholder)
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .padding(.top, 8).padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionLabel) { onConfirm(); dismiss() }
                        .bold().foregroundColor(actionColor)
                }
            }
        }
        .presentationDetents([.medium])
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
    // FIX-4: Fazla ödeme onay dialogu
    @State private var showOverpaymentConfirm = false

    private var enteredAmount: Double {
        Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var isOverpayment: Bool {
        enteredAmount > hakedis.remainingAmount && hakedis.remainingAmount > 0
    }

    // FIX-4: amount <= 0 ise kaydetme
    var isValid: Bool { enteredAmount > 0 }

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
                    if isOverpayment {
                        Label("Girilen tutar kalan miktarı (\(hakedis.remainingAmount.currencyFormatted)) aşıyor.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.hakedisWarning)
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
                    // FIX-4: Fazla ödeme ise onay iste, değilse direkt kaydet
                    Button("Kaydet") {
                        if isOverpayment {
                            showOverpaymentConfirm = true
                        } else {
                            save()
                        }
                    }
                    .disabled(!isValid)
                    .bold()
                }
            }
            // FIX-4: Fazla ödeme onay dialogu
            .confirmationDialog(
                "Fazla Ödeme",
                isPresented: $showOverpaymentConfirm,
                titleVisibility: .visible
            ) {
                Button("Yine de Kaydet", role: .destructive) { save() }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Girilen tutar (\(enteredAmount.currencyFormatted)) kalan bakiyeyi (\(hakedis.remainingAmount.currencyFormatted)) aşıyor. Fazla ödeme giriyorsunuz, emin misiniz?")
            }
        }
    }

    private func save() {
        let payment = Payment(amount: enteredAmount, paymentDate: paymentDate, paymentDescription: description)
        payment.hakedis = hakedis
        hakedis.payments.append(payment)
        if hakedis.remainingAmount - enteredAmount <= 0 {
            hakedis.status = .paid
            NotificationManager.shared.cancelHakedisDueDateAlerts(hakedisID: hakedis.id)
        }
        modelContext.insert(payment)
        dismiss()
    }
}

// MARK: - Hakediş Kalemi Düzenle (Draft)
struct EditHakedisItemView: View {
    let item: HakedisItem

    @Environment(\.dismiss) private var dismiss

    @State private var currentQtyText: String

    init(item: HakedisItem) {
        self.item = item
        _currentQtyText = State(initialValue: item.currentQuantity.quantityFormatted)
    }

    private var enteredQty: Double? { Double(currentQtyText.replacingOccurrences(of: ",", with: ".")) }
    private var isValid: Bool { enteredQty != nil && (enteredQty ?? -1) >= 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kalem Bilgisi") {
                    HStack {
                        Text("Kod").foregroundColor(.secondary)
                        Spacer()
                        Text(item.workItemCode).font(.subheadline.bold())
                    }
                    HStack {
                        Text("Ad").foregroundColor(.secondary)
                        Spacer()
                        Text(item.workItemName)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Birim").foregroundColor(.secondary)
                        Spacer()
                        Text(item.unit).font(.subheadline)
                    }
                    HStack {
                        Text("Birim Fiyat").foregroundColor(.secondary)
                        Spacer()
                        Text(item.unitPrice.currencyFormatted).font(.subheadline)
                    }
                }

                Section("Miktarlar") {
                    HStack {
                        Text("Önceki Miktar").foregroundColor(.secondary)
                        Spacer()
                        Text("\(item.previousQuantity.quantityFormatted) \(item.unit)")
                            .font(.subheadline)
                    }
                    HStack {
                        Text("Bu Dönem Miktar")
                        Spacer()
                        TextField("0.00", text: $currentQtyText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .foregroundColor(.hakedisOrange)
                            .bold()
                    }
                    if let qty = enteredQty {
                        HStack {
                            Text("Kümülatif").foregroundColor(.secondary)
                            Spacer()
                            Text("\((item.previousQuantity + qty).quantityFormatted) \(item.unit)")
                                .font(.subheadline)
                        }
                        HStack {
                            Text("Dönem Tutar").foregroundColor(.secondary)
                            Spacer()
                            Text((qty * item.unitPrice).currencyFormatted)
                                .font(.subheadline.bold())
                                .foregroundColor(.hakedisSuccess)
                        }
                    }
                }
            }
            .navigationTitle("Kalemi Düzenle")
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
        guard let qty = enteredQty else { return }
        item.currentQuantity = qty
        dismiss()
    }
}

// MARK: - Hakediş Vergi & Ceza Özet Bölümü
struct HakedisVergiSection: View {
    let hakedis: Hakedis

    var body: some View {
        VStack(spacing: 6) {
            Divider()
            if hakedis.withholdingTaxAmount > 0 {
                HStack {
                    Text("Stopaj (%\(String(format: "%.1f", hakedis.withholdingTaxRate)))")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("−\(hakedis.withholdingTaxAmount.currencyFormatted)")
                        .font(.subheadline).foregroundColor(.hakedisDanger)
                }
            }
            HStack {
                Text("Damga Vergisi (%\(String(format: "%.3f", hakedis.stampTaxRate)))")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("−\(hakedis.stampTaxAmount.currencyFormatted)")
                    .font(.subheadline).foregroundColor(.hakedisDanger)
            }
            HStack {
                Text("Net Ödenecek")
                    .font(.subheadline.bold())
                Spacer()
                Text(hakedis.netAmountAfterTax.currencyFormatted)
                    .font(.subheadline.bold())
                    .foregroundColor(.hakedisOrange)
            }
            if hakedis.penaltyAmount > 0 {
                HStack {
                    Label("\(hakedis.penaltyDays) gün gecikme cezası", systemImage: "calendar.badge.exclamationmark")
                        .font(.caption).foregroundColor(.hakedisDanger)
                    Spacer()
                    Text("−\(hakedis.penaltyAmount.currencyFormatted)")
                        .font(.subheadline.bold()).foregroundColor(.hakedisDanger)
                }
                .padding(8)
                .background(Color.hakedisDanger.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Mail Compose View

struct HakedisMailComposeView: UIViewControllerRepresentable {
    let hakedis: Hakedis
    @Binding var result: Result<MFMailComposeResult, Error>?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator

        let contractorName = hakedis.contract?.contractor?.name ?? "Taşeron"
        let projectName = hakedis.contract?.project?.name ?? "Proje"
        vc.setSubject("Hakediş: \(hakedis.periodName) — \(contractorName)")
        vc.setMessageBody(
            """
            Sayın \(contractorName),

            \(projectName) projesi için \(hakedis.periodName) dönemi hakediş belgesi ekte iletilmektedir.

            Net Hakediş Tutarı: \(hakedis.netAmount.currencyFormatted)
            Durum: \(hakedis.status.rawValue)

            İyi çalışmalar.
            """,
            isHTML: false
        )

        let pdfData = HakedisPDFGenerator.generate(hakedis: hakedis)
        let fileName = HakedisPDFGenerator.safeFileName(hakedis.periodName)
        vc.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: "\(fileName).pdf")

        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: HakedisMailComposeView
        init(_ parent: HakedisMailComposeView) { self.parent = parent }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            if let error {
                parent.result = .failure(error)
            } else {
                parent.result = .success(result)
            }
            parent.dismiss()
        }
    }
}
