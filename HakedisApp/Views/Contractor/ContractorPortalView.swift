import SwiftUI
import SwiftData

struct ContractorPortalView: View {
    @Query private var contractors: [Contractor]
    @State private var selectedContractor: Contractor?
    @State private var isAuthenticated = false
    @State private var pendingContractor: Contractor?
    @State private var showingPasswordEntry = false

    var body: some View {
        NavigationStack {
            if isAuthenticated, let contractor = selectedContractor {
                ContractorDashboardView(contractor: contractor) {
                    isAuthenticated = false
                    selectedContractor = nil
                }
            } else {
                loginView
            }
        }
        .sheet(isPresented: $showingPasswordEntry) {
            if let contractor = pendingContractor {
                PortalLoginSheet(contractor: contractor) {
                    selectedContractor = contractor
                    isAuthenticated = true
                    showingPasswordEntry = false
                }
            }
        }
    }

    private func selectContractor(_ contractor: Contractor) {
        if !contractor.hasPortalPassword {
            selectedContractor = contractor
            isAuthenticated = true
        } else {
            pendingContractor = contractor
            showingPasswordEntry = true
        }
    }

    var loginView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .font(.system(size: 56))
                        .foregroundColor(.hakedisOrange)
                    Text("Taşeron Girişi").font(.title.bold())
                    Text("Hakedişlerinizi görmek için firmanızı seçin")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    ForEach(contractors) { contractor in
                        Button { selectContractor(contractor) } label: {
                            HStack {
                                Circle()
                                    .fill(Color.hakedisOrange.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(String(contractor.name.prefix(2)).uppercased())
                                            .font(.subheadline.bold())
                                            .foregroundColor(.hakedisOrange)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contractor.name).font(.headline).foregroundColor(.primary)
                                    if !contractor.contactPerson.isEmpty {
                                        Text(contractor.contactPerson).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: contractor.hasPortalPassword ? "lock.fill" : "chevron.right")
                                    .foregroundColor(contractor.hasPortalPassword ? .hakedisOrange : .secondary)
                                    .font(.caption)
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if contractors.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: "Taşeron bulunamadı",
                            subtitle: "Taşeronlar sekmesinden önce taşeron ekleyin"
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Taşeron Portali")
    }
}

// MARK: - Portal Login Sheet
struct PortalLoginSheet: View {
    let contractor: Contractor
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var enteredPassword = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.hakedisOrange.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text(String(contractor.name.prefix(2)).uppercased())
                                .font(.title2.bold())
                                .foregroundColor(.hakedisOrange)
                        )
                    Text(contractor.name).font(.title3.bold())
                    Text("Portal şifrenizi girin").font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    SecureField("Şifre", text: $enteredPassword)
                        .textContentType(.password)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    if failed {
                        Text("Hatalı şifre, tekrar deneyin")
                            .font(.caption)
                            .foregroundColor(.hakedisDanger)
                    }

                    Button {
                        if enteredPassword == contractor.keychainPortalPassword {
                            onSuccess()
                        } else {
                            failed = true
                            enteredPassword = ""
                        }
                    } label: {
                        Text("Giriş Yap")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(enteredPassword.isEmpty ? Color.secondary : Color.hakedisOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(enteredPassword.isEmpty)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Giriş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
}

struct ContractorDashboardView: View {
    let contractor: Contractor
    let onLogout: () -> Void

    private var allHakedisler: [Hakedis] {
        contractor.contracts.flatMap { $0.hakedisler }.sorted { $0.createdAt > $1.createdAt }
    }
    private var totalNet: Double { allHakedisler.reduce(0) { $0 + $1.netAmount } }
    private var totalPaid: Double { allHakedisler.reduce(0) { $0 + $1.totalPaid } }
    private var totalPending: Double { totalNet - totalPaid }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.hakedisOrange.opacity(0.15))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Text(String(contractor.name.prefix(2)).uppercased())
                                    .font(.headline.bold())
                                    .foregroundColor(.hakedisOrange)
                            )
                        VStack(alignment: .leading) {
                            Text(contractor.name).font(.title3.bold())
                            if !contractor.contactPerson.isEmpty {
                                Text(contractor.contactPerson).font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                    }
                    Divider()
                    HStack(spacing: 0) {
                        PortalStatItem(label: "Toplam", value: totalNet.currencyFormatted, color: .primary)
                        Divider().frame(height: 40)
                        PortalStatItem(label: "Ödenen", value: totalPaid.currencyFormatted, color: .hakedisSuccess)
                        Divider().frame(height: 40)
                        PortalStatItem(label: "Bekleyen", value: totalPending.currencyFormatted, color: totalPending > 0 ? .hakedisDanger : .hakedisSuccess)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Hakedişlerim") {
                if allHakedisler.isEmpty {
                    Text("Henüz hakediş yok").foregroundColor(.secondary)
                } else {
                    ForEach(allHakedisler) { h in
                        NavigationLink(destination: ContractorHakedisDetailView(hakedis: h)) {
                            ContractorHakedisRow(hakedis: h)
                        }
                    }
                }
            }

            Section("Sözleşmelerim") {
                ForEach(contractor.contracts) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(c.title).font(.subheadline.bold())
                        HStack {
                            Text(c.project?.name ?? "").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(c.totalContractAmount.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Portalım")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Çıkış") { onLogout() }.foregroundColor(.hakedisDanger)
            }
        }
    }
}

struct PortalStatItem: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.caption.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ContractorHakedisRow: View {
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
                Text(hakedis.periodName).font(.subheadline.bold())
                Spacer()
                StatusBadge(text: hakedis.status.rawValue, color: statusColor)
            }
            HStack {
                Text(hakedis.contract?.title ?? "").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(hakedis.netAmount.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ContractorHakedisDetailView: View {
    let hakedis: Hakedis
    @State private var showingObjection = false
    @State private var objectionSubmitted = false
    // FIX-19: PDF paylaşım
    @State private var pdfItem: PDFFileItem?
    @State private var showPDFError = false

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
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Net Hakediş").font(.caption).foregroundColor(.secondary)
                            Text(hakedis.netAmount.currencyFormatted).font(.title2.bold())
                        }
                        Spacer()
                        StatusBadge(text: hakedis.status.rawValue, color: statusColor)
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Brüt").font(.caption).foregroundColor(.secondary)
                            Text(hakedis.grossAmount.currencyFormatted).font(.subheadline)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Teminat").font(.caption).foregroundColor(.secondary)
                            Text(hakedis.retentionAmount.currencyFormatted).font(.subheadline).foregroundColor(.hakedisDanger)
                        }
                    }
                    if hakedis.totalPaid > 0 {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ödenen").font(.caption).foregroundColor(.secondary)
                                Text(hakedis.totalPaid.currencyFormatted).font(.subheadline).foregroundColor(.hakedisSuccess)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Kalan").font(.caption).foregroundColor(.secondary)
                                Text(hakedis.remainingAmount.currencyFormatted)
                                    .font(.subheadline)
                                    .foregroundColor(hakedis.remainingAmount > 0 ? .hakedisDanger : .hakedisSuccess)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("İş Kalemleri") {
                ForEach(hakedis.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("[\(item.workItemCode)]").font(.caption.monospaced()).foregroundColor(.secondary)
                            Text(item.workItemName).font(.subheadline.bold())
                        }
                        HStack {
                            Text("\(item.currentQuantity.quantityFormatted) \(item.unit)").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(item.periodAmount.currencyFormatted).font(.caption.bold())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // FIX-18: Ödeme geçmişi (read-only)
            if !hakedis.payments.isEmpty {
                Section("Ödeme Geçmişi") {
                    ForEach(hakedis.payments.sorted { $0.paymentDate > $1.paymentDate }, id: \.id) { payment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
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
                        .padding(.vertical, 2)
                    }
                }
            }

            // FIX-20: Red gerekçesi ve revizyon geçmişi
            if hakedis.status == .rejected || !hakedis.revisions.isEmpty {
                Section("Red & Revizyon Geçmişi") {
                    if hakedis.status == .rejected && !hakedis.approvalNote.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.hakedisDanger)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Red Gerekçesi").font(.caption).foregroundColor(.secondary)
                                Text(hakedis.approvalNote).font(.subheadline)
                            }
                        }
                    }
                    ForEach(hakedis.revisions.sorted { $0.rejectedAt > $1.rejectedAt }, id: \.id) { rev in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(rev.version).font(.caption.bold().monospaced())
                                    .foregroundColor(.hakedisDanger)
                                Spacer()
                                Text(rev.rejectedAt.shortFormatted).font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(rev.rejectionReason).font(.caption).foregroundColor(.secondary)
                            if !rev.isExpired {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .font(.caption2).foregroundColor(.hakedisWarning)
                                    Text("İtiraz süresi: \(rev.objectionDaysLeft) gün")
                                        .font(.caption2).foregroundColor(.hakedisWarning)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if hakedis.status == .pendingApproval || hakedis.status == .approved {
                Section {
                    if objectionSubmitted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.hakedisSuccess)
                            Text("İtirazınız iletildi").foregroundColor(.hakedisSuccess)
                        }
                    } else {
                        Button { showingObjection = true } label: {
                            Label("İtiraz Bildir", systemImage: "exclamationmark.bubble")
                                .foregroundColor(.hakedisDanger)
                        }
                    }
                }
            }
        }
        .navigationTitle(hakedis.periodName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // FIX-19: PDF indirme butonu
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let data = HakedisPDFGenerator.generate(hakedis: hakedis)
                    let name = HakedisPDFGenerator.safeFileName(hakedis.periodName)
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
                    do {
                        try data.write(to: url)
                        pdfItem = PDFFileItem(url: url)
                    } catch {
                        showPDFError = true
                    }
                } label: {
                    Image(systemName: "arrow.down.doc.fill")
                }
            }
        }
        .sheet(isPresented: $showingObjection) {
            ObjectionView(hakedis: hakedis) {
                objectionSubmitted = true
                showingObjection = false
            }
        }
        .sheet(item: $pdfItem) { item in ShareSheet(items: [item.url]) }
        .alert("PDF Oluşturulamadı", isPresented: $showPDFError) {
            Button("Tamam", role: .cancel) {}
        }
    }
}

struct ObjectionView: View {
    let hakedis: Hakedis
    let onSubmit: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var category: ObjectionCategory = .miktar
    @State private var claimedAmountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("İtiraz Kategorisi") {
                    Picker("Kategori", selection: $category) {
                        ForEach(ObjectionCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        TextField("Talep Edilen Tutar", text: $claimedAmountText)
                            .keyboardType(.decimalPad)
                        Text("₺").foregroundColor(.secondary)
                    }
                }
                Section("İtiraz Nedeni *") {
                    TextEditor(text: $text).frame(minHeight: 80)
                }
                Section {
                    Text("İtiraz süresi hakediş tebligatından itibaren 30 gündür (4735 md.38).")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("İtiraz Bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gönder") {
                        saveObjection()
                        onSubmit()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                }
            }
        }
    }

    private func saveObjection() {
        let allObjections = (try? context.fetch(FetchDescriptor<Objection>())) ?? []
        let number = Objection.generateNumber(existing: allObjections)
        let obj = Objection(
            objectionNumber: number,
            reason: text.trimmingCharacters(in: .whitespaces),
            category: category,
            claimedAmount: Double(claimedAmountText) ?? 0
        )
        obj.relatedHakedis = hakedis
        context.insert(obj)
        try? context.save()
    }
}

// MARK: - Objection Admin View (FAZ 11 — SwiftData tabanlı)

struct ObjectionAdminView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Objection.createdAt, order: .reverse) private var objections: [Objection]
    @State private var showingAdd = false
    @State private var selectedObjection: Objection?

    private var openObjections: [Objection] { objections.filter { $0.status == .acik || $0.status == .incelemede } }
    private var closedObjections: [Objection] { objections.filter { $0.status != .acik && $0.status != .incelemede } }

    var body: some View {
        List {
            if objections.isEmpty {
                EmptyStateView(icon: "checkmark.circle", title: "İtiraz Yok", subtitle: "Bekleyen itiraz bulunmuyor")
            }
            if !openObjections.isEmpty {
                Section("Açık İtirazlar (\(openObjections.count))") {
                    ForEach(openObjections) { obj in
                        ObjectionRow(objection: obj)
                            .onTapGesture { selectedObjection = obj }
                    }
                }
            }
            if !closedObjections.isEmpty {
                Section("Sonuçlananlar") {
                    ForEach(closedObjections) { obj in
                        ObjectionRow(objection: obj)
                    }
                }
            }
        }
        .navigationTitle("İtiraz Yönetimi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddObjectionView()
        }
        .sheet(item: $selectedObjection) { obj in
            ObjectionResponseView(objection: obj)
        }
    }
}

struct ObjectionRow: View {
    let objection: Objection

    private var statusColor: Color {
        switch objection.status {
        case .acik:       return .hakedisWarning
        case .incelemede: return .hakedisOrange
        case .kabul, .kismiKabul: return .hakedisSuccess
        case .red:        return .hakedisDanger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(objection.objectionNumber).font(.subheadline.bold())
                    if let h = objection.relatedHakedis {
                        Text(h.periodName).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                StatusBadge(text: objection.status.rawValue, color: statusColor)
            }
            HStack {
                Text(objection.category.rawValue).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(objection.claimedAmount.currencyFormatted).font(.caption.bold())
            }
            Text(objection.reason).font(.caption).lineLimit(2).foregroundColor(.secondary)
            if objection.isDeadlineApproaching {
                Label("\(objection.daysUntilDeadline) gün kaldı — 4735 md.38", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.hakedisDanger)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddObjectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var hakedisler: [Hakedis]

    @State private var selectedHakedis: Hakedis?
    @State private var category: ObjectionCategory = .miktar
    @State private var reason = ""
    @State private var claimedAmountText = ""

    var isValid: Bool { !reason.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("İlgili Hakediş (opsiyonel)") {
                    Picker("Hakediş", selection: $selectedHakedis) {
                        Text("Genel İtiraz").tag(Optional<Hakedis>.none)
                        ForEach(hakedisler) { h in
                            Text(h.periodName).tag(Optional(h))
                        }
                    }
                }
                Section("İtiraz Bilgileri") {
                    Picker("Kategori", selection: $category) {
                        ForEach(ObjectionCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        TextField("Talep Edilen Tutar", text: $claimedAmountText)
                            .keyboardType(.decimalPad)
                        Text("₺").foregroundColor(.secondary)
                    }
                }
                Section("İtiraz Nedeni *") {
                    TextEditor(text: $reason).frame(minHeight: 80)
                }
                Section {
                    Text("İtiraz süresi 30 gündür (4735 sayılı Kanun md.38). Son itiraz tarihi otomatik hesaplanır.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Yeni İtiraz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(!isValid).bold()
                }
            }
        }
    }

    private func save() {
        let allObjections = (try? context.fetch(FetchDescriptor<Objection>())) ?? []
        let number = Objection.generateNumber(existing: allObjections)
        let obj = Objection(
            objectionNumber: number,
            reason: reason.trimmingCharacters(in: .whitespaces),
            category: category,
            claimedAmount: Double(claimedAmountText) ?? 0
        )
        obj.relatedHakedis = selectedHakedis
        context.insert(obj)
        try? context.save()
        dismiss()
    }
}

struct ObjectionResponseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let objection: Objection

    @State private var responseNote = ""
    @State private var newStatus: ObjectionStatus = .incelemede
    @State private var approvedAmountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("İtiraz Detayı") {
                    LabeledContent("Numara", value: objection.objectionNumber)
                    LabeledContent("Kategori", value: objection.category.rawValue)
                    LabeledContent("Talep", value: objection.claimedAmount.currencyFormatted)
                    Text(objection.reason).font(.subheadline)
                }
                Section("Karar") {
                    Picker("Durum", selection: $newStatus) {
                        ForEach(ObjectionStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    if newStatus == .kismiKabul || newStatus == .kabul {
                        HStack {
                            TextField("Onaylanan Tutar", text: $approvedAmountText)
                                .keyboardType(.decimalPad)
                            Text("₺").foregroundColor(.secondary)
                        }
                    }
                }
                Section("Yanıt Notu") {
                    TextEditor(text: $responseNote).frame(minHeight: 80)
                }
            }
            .navigationTitle("İtiraz Yanıtla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { saveResponse() }
                        .disabled(responseNote.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
        }
        .onAppear {
            newStatus = objection.status
            responseNote = objection.responseNote ?? ""
            approvedAmountText = objection.approvedAmount > 0 ? "\(objection.approvedAmount)" : ""
        }
    }

    private func saveResponse() {
        objection.status = newStatus
        objection.responseNote = responseNote
        objection.responseDate = Date()
        objection.approvedAmount = Double(approvedAmountText) ?? 0
        try? context.save()
        dismiss()
    }
}
