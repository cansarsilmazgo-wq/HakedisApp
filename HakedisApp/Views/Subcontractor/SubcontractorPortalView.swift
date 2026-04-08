import SwiftUI
import SwiftData

// MARK: - SubcontractorPortalView (Ana Portal)

struct SubcontractorPortalView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SubcontractorDashboardView()
                .tabItem { Label("Ana Ekran", systemImage: "house.fill") }
                .tag(0)
                .accessibilityLabel("Taşeron Ana Ekranı")

            SubcontractorHakedisPortalView()
                .tabItem { Label("Hakedişlerim", systemImage: "doc.text.fill") }
                .tag(1)
                .accessibilityLabel("Hakedişlerim")

            SubcontractorWorkOrderView()
                .tabItem { Label("İş Emirlerim", systemImage: "doc.badge.gearshape.fill") }
                .tag(2)
                .accessibilityLabel("İş Emirlerim")

            SubcontractorRequestView()
                .tabItem { Label("Taleplerim", systemImage: "tray.and.arrow.up.fill") }
                .tag(3)
                .accessibilityLabel("Taleplerim")

            // FAZ 16 — #34 Çalıştığım Firmalar
            SubcontractorCompaniesView()
                .tabItem { Label("Firmalar", systemImage: "building.2.fill") }
                .tag(4)
                .accessibilityLabel("Çalıştığım firmalar")
        }
        .tint(.hakedisOrange)
    }
}

// MARK: - SubcontractorDashboardView

struct SubcontractorDashboardView: View {
    @StateObject private var authManager = AuthManager.shared
    @Query private var hakedisler: [Hakedis]
    @Query private var attendances: [Attendance]
    @Query private var disputes: [SubcontractorDispute]
    @Query private var workOrders: [SubcontractorWorkOrder]
    @Query private var materialRequests: [SubcontractorMaterialRequest]
    @Environment(\.modelContext) private var modelContext

    private var currentContractor: Contractor? {
        // Oturum açan kullanıcının contractor'ını bul
        let email = authManager.currentUser?.email ?? ""
        _ = email
        // Contractor modeline email alanı eklenmiş olmalı; yoksa name ile eşleştir
        return nil  // gerçek uygulamada UserAccount.contractor ilişkisi üzerinden çekiliyor
    }

    private var myHakedisler: [Hakedis] {
        // Sadece kendi hakedişleri (contractor eşleşmesi)
        // Not: UserAccount → contractor ilişkisi kurulduğunda filtreleme buraya eklenir
        hakedisler.filter { $0.contract?.contractor?.name != nil }
    }

    private var pendingHakedisler: [Hakedis] {
        myHakedisler.filter { $0.status == .pendingApproval }
    }

    private var pendingHakedisTotal: Double {
        pendingHakedisler.reduce(0) { $0 + $1.netAmount }
    }

    private var activeWorkOrders: [SubcontractorWorkOrder] {
        workOrders.filter { !$0.isCompleted }
    }

    private var pendingMaterialRequests: [SubcontractorMaterialRequest] {
        materialRequests.filter { $0.status == .pending }
    }

    private var openDisputes: [SubcontractorDispute] {
        disputes.filter { $0.isOpen }
    }

    // Bu ayki puantaj özeti
    private var thisMonthAttendances: [Attendance] {
        let calendar = Calendar.current
        let now = Date()
        return attendances.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
    }

    private var totalManDays: Int { thisMonthAttendances.filter { $0.isPresent }.count }
    private var totalAttendanceCost: Double { thisMonthAttendances.reduce(0) { $0 + $1.totalDailyCost } }

    // Son 3 ödeme
    private var recentPayments: [Payment] {
        myHakedisler
            .flatMap { $0.payments }
            .sorted { $0.paymentDate > $1.paymentDate }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.section) {
                    // Hoş geldin kartı
                    welcomeCard

                    // Bekleyen hakedişler
                    StatCard(
                        title: "Bekleyen Hakedişlerim",
                        value: "\(pendingHakedisler.count) Hakediş",
                        subtitle: pendingHakedisTotal.currencyFormatted,
                        color: pendingHakedisler.isEmpty ? .hakedisSuccess : .hakedisWarning,
                        icon: "doc.text.fill"
                    )

                    // Aktif iş emirleri
                    StatCard(
                        title: "Aktif İş Emirlerim",
                        value: "\(activeWorkOrders.count) İş Emri",
                        subtitle: "Tamamlanmamış",
                        color: activeWorkOrders.isEmpty ? .hakedisSuccess : .hakedisOrange,
                        icon: "doc.badge.gearshape.fill"
                    )

                    // Malzeme talepleri
                    StatCard(
                        title: "Malzeme Taleplerim",
                        value: "\(pendingMaterialRequests.count) Bekliyor",
                        subtitle: "Toplam \(materialRequests.count) talep",
                        color: .hakedisInfo,
                        icon: "shippingbox.fill"
                    )

                    // Bu ay puantaj
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        SectionHeader("Bu Ay Puantaj Özeti")
                        HStack(spacing: Spacing.md) {
                            StatCard(
                                title: "Adam-Gün",
                                value: "\(totalManDays)",
                                subtitle: "Bu ay",
                                color: .hakedisInfo,
                                icon: "person.fill"
                            )
                            StatCard(
                                title: "Maliyet",
                                value: totalAttendanceCost.compactCurrency,
                                subtitle: "Bu ay",
                                color: .hakedisSuccess,
                                icon: "banknote.fill"
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.md)

                    // Son ödemeler
                    if !recentPayments.isEmpty {
                        recentPaymentsSection
                    }

                    // İtirazlar
                    if !openDisputes.isEmpty {
                        openDisputesSection
                    }
                }
                .padding(.vertical, Spacing.md)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Hoş Geldiniz")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.hakedisOrange)
                VStack(alignment: .leading) {
                    Text(authManager.currentUser?.fullName ?? "Taşeron")
                        .font(.headline)
                    Text("Taşeron Portalı")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .cornerRadius(12)
        .padding(.horizontal, Spacing.md)
    }

    private var recentPaymentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader("Son Ödemelerim")
            ForEach(recentPayments, id: \.id) { payment in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.hakedisSuccess)
                    VStack(alignment: .leading) {
                        Text(payment.paymentDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                        Text(payment.paymentDescription.isEmpty ? "Ödeme" : payment.paymentDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(payment.amount.currencyFormatted)
                        .font(.subheadline.bold())
                        .foregroundColor(.hakedisSuccess)
                }
                .padding(Spacing.cardSmall)
                .background(Color.hakedisCard)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private var openDisputesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader("Açık İtirazlarım")
            ForEach(openDisputes, id: \.id) { dispute in
                HStack {
                    Image(systemName: dispute.status.icon)
                        .foregroundColor(.hakedisDanger)
                    Text(dispute.subject)
                        .font(.subheadline)
                    Spacer()
                    StatusBadge(text: dispute.status.rawValue, color: .hakedisDanger)
                }
                .padding(Spacing.cardSmall)
                .background(Color.hakedisCard)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - SubcontractorHakedisPortalView

struct SubcontractorHakedisPortalView: View {
    @Query(sort: \Hakedis.periodStart, order: .reverse) private var hakedisler: [Hakedis]
    @Query private var disputes: [SubcontractorDispute]
    @State private var selectedHakedis: Hakedis?
    @State private var showDisputeSheet = false
    @State private var disputeSubject = ""
    @State private var disputeDetails = ""
    @State private var disputeType = DisputeType.hakedisAmount
    @State private var requestedAmount = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if hakedisler.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "Hakediş Yok",
                        subtitle: "Henüz hakediş kaydınız bulunmuyor."
                    )
                } else {
                    List {
                        ForEach(hakedisler, id: \.id) { hakedis in
                            NavigationLink(destination: SubcontractorHakedisDetailView(hakedis: hakedis)) {
                                hakedisRow(hakedis)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Hakedişlerim")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func hakedisStatusColor(_ s: HakedisStatus) -> Color {
        switch s {
        case .draft: return Color.secondary
        case .pendingApproval: return .hakedisWarning
        case .approved: return .hakedisInfo
        case .rejected: return .hakedisDanger
        case .paid: return .hakedisSuccess
        }
    }

    private func hakedisRow(_ hakedis: Hakedis) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(hakedis.periodName)
                    .font(.headline)
                Spacer()
                StatusBadge(
                    text: hakedis.status.rawValue,
                    color: hakedisStatusColor(hakedis.status)
                )
            }
            HStack {
                Text("Brüt: \(hakedis.grossAmount.currencyFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Net: \(hakedis.netAmount.currencyFormatted)")
                    .font(.caption.bold())
            }
            Text(hakedis.periodStart.formatted(date: .abbreviated, time: .omitted) +
                 " – " + hakedis.periodEnd.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - SubcontractorHakedisDetailView

struct SubcontractorHakedisDetailView: View {
    let hakedis: Hakedis
    @State private var showDisputeSheet = false
    @State private var disputeSubject = ""
    @State private var disputeDetails = ""
    @State private var disputeType = DisputeType.hakedisAmount
    @State private var requestedAmountText = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section("Hakediş Bilgileri") {
                LabeledContent("Dönem", value: hakedis.periodName)
                LabeledContent("Durum", value: hakedis.status.rawValue)
                LabeledContent("Brüt Tutar", value: hakedis.grossAmount.currencyFormatted)
                LabeledContent("Teminat Kesintisi", value: hakedis.retentionAmount.currencyFormatted)
                LabeledContent("Net Tutar", value: hakedis.netAmount.currencyFormatted)
                LabeledContent("Ödenen", value: hakedis.totalPaid.currencyFormatted)
                LabeledContent("Kalan", value: (hakedis.netAmount - hakedis.totalPaid).currencyFormatted)
            }

            if !hakedis.items.isEmpty {
                Section("İş Kalemleri") {
                    ForEach(hakedis.items, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.workItemName)
                                .font(.subheadline)
                            HStack {
                                Text("Miktar: \(item.currentQuantity.quantityFormatted)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(item.periodAmount.currencyFormatted)
                                    .font(.caption.bold())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !hakedis.payments.isEmpty {
                Section("Ödeme Geçmişi") {
                    ForEach(hakedis.payments, id: \.id) { payment in
                        HStack {
                            Text(payment.paymentDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                            Spacer()
                            Text(payment.amount.currencyFormatted)
                                .font(.subheadline.bold())
                                .foregroundColor(.hakedisSuccess)
                        }
                    }
                }
            }

            Section {
                Button {
                    showDisputeSheet = true
                } label: {
                    Label("Hakediş İtiraz Et", systemImage: "exclamationmark.bubble.fill")
                        .foregroundColor(.hakedisDanger)
                }
                .accessibilityLabel("Hakediş İtiraz Et")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(hakedis.periodName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDisputeSheet) {
            disputeSheet
        }
    }

    private var disputeSheet: some View {
        NavigationStack {
            Form {
                Section("İtiraz Türü") {
                    Picker("İtiraz Türü", selection: $disputeType) {
                        ForEach(DisputeType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }
                Section("İtiraz Konusu") {
                    TextField("Konu başlığı", text: $disputeSubject)
                }
                Section("İtiraz Detayı") {
                    TextEditor(text: $disputeDetails)
                        .frame(minHeight: 80)
                }
                Section("Talep Edilen Tutar (Opsiyonel)") {
                    TextField("₺ Tutar", text: $requestedAmountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Hakediş İtirazı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { showDisputeSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gönder") {
                        submitDispute()
                        showDisputeSheet = false
                    }
                    .disabled(disputeSubject.isEmpty || disputeDetails.isEmpty)
                }
            }
        }
    }

    private func submitDispute() {
        let dispute = SubcontractorDispute(
            subject: disputeSubject,
            details: disputeDetails,
            disputeType: disputeType
        )
        dispute.hakedis = hakedis
        dispute.contract = hakedis.contract
        dispute.contractor = hakedis.contract?.contractor
        if let amt = Double(requestedAmountText.replacingOccurrences(of: ",", with: ".")) {
            dispute.requestedAmount = amt
        }
        modelContext.insert(dispute)
        do {
            try modelContext.save()
            NotificationManager.shared.scheduleDisputeNotification(subject: disputeSubject)
        } catch {
            // kayıt hatası
        }
    }
}

// MARK: - SubcontractorWorkOrderView

struct SubcontractorWorkOrderView: View {
    @Query(sort: \SubcontractorWorkOrder.assignedDate, order: .reverse) private var workOrders: [SubcontractorWorkOrder]
    @State private var showCompletionSheet = false
    @State private var selectedOrder: SubcontractorWorkOrder?
    @State private var completionNotes = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if workOrders.isEmpty {
                    EmptyStateView(
                        icon: "doc.badge.gearshape",
                        title: "İş Emri Yok",
                        subtitle: "Size atanmış iş emri bulunmuyor."
                    )
                } else {
                    List {
                        Section("Aktif İş Emirleri") {
                            ForEach(workOrders.filter { !$0.isCompleted }, id: \.id) { order in
                                workOrderRow(order)
                            }
                        }
                        Section("Tamamlananlar") {
                            ForEach(workOrders.filter { $0.isCompleted }, id: \.id) { order in
                                workOrderRow(order)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("İş Emirlerim")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCompletionSheet) {
                if let order = selectedOrder {
                    completionSheet(for: order)
                }
            }
        }
    }

    private func workOrderRow(_ order: SubcontractorWorkOrder) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: order.priority.icon)
                    .foregroundColor(order.isOverdue ? .hakedisDanger : .hakedisOrange)
                Text(order.orderTitle)
                    .font(.headline)
                    .foregroundColor(order.isOverdue ? .hakedisDanger : .primary)
                Spacer()
                StatusBadge(
                    text: order.completionStatus.rawValue,
                    color: order.isCompleted ? .hakedisSuccess : (order.isOverdue ? .hakedisDanger : .hakedisWarning)
                )
            }
            if !order.orderDescription.isEmpty {
                Text(order.orderDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            HStack {
                if let due = order.dueDate {
                    Label(due.formatted(date: .abbreviated, time: .omitted),
                          systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(order.isOverdue ? .hakedisDanger : .secondary)
                }
                Spacer()
                if !order.isCompleted {
                    Button("Tamamlandı") {
                        selectedOrder = order
                        showCompletionSheet = true
                    }
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
                    .accessibilityLabel("İş emrini tamamla: \(order.orderTitle)")
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func completionSheet(for order: SubcontractorWorkOrder) -> some View {
        NavigationStack {
            Form {
                Section("Tamamlama Notu") {
                    TextEditor(text: $completionNotes)
                        .frame(minHeight: 80)
                }
                Section("Tamamlama Kanıtı") {
                    Text("Fotoğraf ekleme özelliği yakında aktif olacak.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("İş Emrini Tamamla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { showCompletionSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tamamlandı Olarak İşaretle") {
                        completeOrder(order)
                        showCompletionSheet = false
                    }
                }
            }
        }
    }

    private func completeOrder(_ order: SubcontractorWorkOrder) {
        order.completionStatus = .completed
        order.completionDate = Date()
        order.completionNotes = completionNotes
        do {
            try modelContext.save()
        } catch {
            // kayıt hatası
        }
        completionNotes = ""
    }
}

// MARK: - SubcontractorRequestView

struct SubcontractorRequestView: View {
    @Query(sort: \SubcontractorMaterialRequest.requestDate, order: .reverse) private var materialRequests: [SubcontractorMaterialRequest]
    @Query(sort: \SubcontractorAdditionalWork.reportDate, order: .reverse) private var additionalWorks: [SubcontractorAdditionalWork]
    @State private var selectedSegment = 0
    @State private var showAddMaterialRequest = false
    @State private var showAddAdditionalWork = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tür", selection: $selectedSegment) {
                    Text("Malzeme").tag(0)
                    Text("Ek İş").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                if selectedSegment == 0 {
                    materialRequestList
                } else {
                    additionalWorkList
                }
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Taleplerim")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if selectedSegment == 0 {
                            showAddMaterialRequest = true
                        } else {
                            showAddAdditionalWork = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Yeni Talep")
                }
            }
            .sheet(isPresented: $showAddMaterialRequest) {
                SubcontractorAddMaterialRequestView()
            }
            .sheet(isPresented: $showAddAdditionalWork) {
                AddAdditionalWorkView()
            }
        }
    }

    private var materialRequestList: some View {
        Group {
            if materialRequests.isEmpty {
                EmptyStateView(
                    icon: "shippingbox",
                    title: "Talep Yok",
                    subtitle: "Malzeme talebi oluşturmak için + butonunu kullanın.",
                    actionTitle: "Talep Oluştur"
                ) { showAddMaterialRequest = true }
            } else {
                List {
                    ForEach(materialRequests, id: \.id) { req in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Text(req.materialName)
                                    .font(.headline)
                                Spacer()
                                StatusBadge(
                                    text: req.status.rawValue,
                                    color: statusColor(req.status)
                                )
                            }
                            HStack {
                                Text("\(req.quantity.quantityFormatted) \(req.unit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let needed = req.neededByDate {
                                    Spacer()
                                    Text("Termin: \(needed.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            if !req.justification.isEmpty {
                                Text(req.justification)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var additionalWorkList: some View {
        Group {
            if additionalWorks.isEmpty {
                EmptyStateView(
                    icon: "plus.circle",
                    title: "Ek İş Bildirimi Yok",
                    subtitle: "Projede olmayan ek iş bildirmek için + butonunu kullanın.",
                    actionTitle: "Bildir"
                ) { showAddAdditionalWork = true }
            } else {
                List {
                    ForEach(additionalWorks, id: \.id) { work in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Text(work.workTitle)
                                    .font(.headline)
                                Spacer()
                                StatusBadge(
                                    text: work.status.rawValue,
                                    color: statusColor(work.status)
                                )
                            }
                            Text(work.workDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            if let amt = work.estimatedAmount {
                                Text("Tahmini: \(amt.currencyFormatted)")
                                    .font(.caption.bold())
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func statusColor(_ status: MaterialRequestStatus) -> Color {
        switch status {
        case .pending:   return .hakedisWarning
        case .approved:  return .hakedisSuccess
        case .rejected:  return .hakedisDanger
        case .delivered: return .hakedisInfo
        }
    }
}

// MARK: - SubcontractorAddMaterialRequestView

struct SubcontractorAddMaterialRequestView: View {
    @State private var materialName = ""
    @State private var quantityText = ""
    @State private var unit = "adet"
    @State private var justification = ""
    @State private var neededByDate = Date()
    @State private var hasNeededDate = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let units = ["adet", "m²", "m³", "ton", "kg", "m", "lt", "çuval"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Malzeme Bilgileri") {
                    TextField("Malzeme adı", text: $materialName)
                    HStack {
                        TextField("Miktar", text: $quantityText)
                            .keyboardType(.decimalPad)
                        Picker("Birim", selection: $unit) {
                            ForEach(units, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("Termin") {
                    Toggle("Termin tarihi belirt", isOn: $hasNeededDate)
                    if hasNeededDate {
                        DatePicker("Ne zaman lazım", selection: $neededByDate, displayedComponents: .date)
                    }
                }
                Section("Gerekçe") {
                    TextEditor(text: $justification)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Malzeme Talebi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        saveRequest()
                        dismiss()
                    }
                    .disabled(materialName.isEmpty || quantityText.isEmpty)
                }
            }
        }
    }

    private func saveRequest() {
        let qty = Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let req = SubcontractorMaterialRequest(materialName: materialName, quantity: qty, unit: unit, justification: justification)
        if hasNeededDate { req.neededByDate = neededByDate }
        modelContext.insert(req)
        do { try modelContext.save() } catch { }
    }
}

// MARK: - AddAdditionalWorkView

struct AddAdditionalWorkView: View {
    @State private var workTitle = ""
    @State private var workDescription = ""
    @State private var estimatedAmountText = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("İş Bilgileri") {
                    TextField("Ek iş başlığı", text: $workTitle)
                    TextEditor(text: $workDescription)
                        .frame(minHeight: 80)
                }
                Section("Tahmini Maliyet (Opsiyonel)") {
                    TextField("₺ Tutar", text: $estimatedAmountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Ek İş Bildirimi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bildir") {
                        saveWork()
                        dismiss()
                    }
                    .disabled(workTitle.isEmpty || workDescription.isEmpty)
                }
            }
        }
    }

    private func saveWork() {
        let work = SubcontractorAdditionalWork(workTitle: workTitle, workDescription: workDescription)
        if let amt = Double(estimatedAmountText.replacingOccurrences(of: ",", with: ".")) {
            work.estimatedAmount = amt
        }
        modelContext.insert(work)
        do { try modelContext.save() } catch { }
    }
}

// MARK: - DisputeManagementView (Patron tarafı)

struct DisputeManagementView: View {
    @Query(sort: \SubcontractorDispute.disputeDate, order: .reverse) private var disputes: [SubcontractorDispute]
    @State private var selectedDispute: SubcontractorDispute?
    @State private var showResponseSheet = false
    @State private var responseText = ""
    @State private var newStatus = DisputeStatus.underReview
    @Environment(\.modelContext) private var modelContext

    var openCount: Int { disputes.filter { $0.isOpen }.count }

    var body: some View {
        NavigationStack {
            Group {
                if disputes.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.bubble",
                        title: "İtiraz Yok",
                        subtitle: "Taşeronlardan gelen itiraz bulunmuyor."
                    )
                } else {
                    List {
                        ForEach(disputes, id: \.id) { dispute in
                            disputeRow(dispute)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Taşeron İtirazları")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showResponseSheet) {
                if let dispute = selectedDispute {
                    disputeResponseSheet(dispute)
                }
            }
        }
    }

    private func disputeRow(_ dispute: SubcontractorDispute) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: dispute.status.icon)
                    .foregroundColor(dispute.isOpen ? .hakedisDanger : .hakedisSuccess)
                Text(dispute.subject)
                    .font(.headline)
                Spacer()
                StatusBadge(text: dispute.status.rawValue,
                            color: dispute.isOpen ? .hakedisDanger : .secondary)
            }
            Text(dispute.disputeType.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            if let amt = dispute.requestedAmount {
                Text("Talep: \(amt.currencyFormatted)")
                    .font(.caption.bold())
            }
            HStack {
                Text(dispute.disputeDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if !dispute.isResolved {
                    Button("Yanıtla") {
                        selectedDispute = dispute
                        newStatus = .underReview
                        responseText = ""
                        showResponseSheet = true
                    }
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
                    .accessibilityLabel("İtirazı yanıtla: \(dispute.subject)")
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func disputeResponseSheet(_ dispute: SubcontractorDispute) -> some View {
        NavigationStack {
            Form {
                Section("Durum Güncelle") {
                    Picker("Yeni Durum", selection: $newStatus) {
                        ForEach([DisputeStatus.underReview, .resolved, .rejected], id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Yanıt") {
                    TextEditor(text: $responseText)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("İtiraz Yanıtı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { showResponseSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        dispute.status = newStatus
                        dispute.resolution = responseText
                        do { try modelContext.save() } catch { }
                        showResponseSheet = false
                    }
                    .disabled(responseText.isEmpty)
                }
            }
        }
    }
}

// MARK: - NotificationManager extension

extension NotificationManager {
    func scheduleDisputeNotification(subject: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Yeni Taşeron İtirazı"
        content.body = "İtiraz konusu: \(subject)"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "dispute_\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleWorkOrderAssignment(orderTitle: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Yeni İş Emri Atandı"
        content.body = orderTitle
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "wo_\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - SubcontractorCompaniesView (FAZ 16 — #34 Çalıştığım Firmalar)

struct SubcontractorCompaniesView: View {
    @StateObject private var authManager = AuthManager.shared
    @Query private var companies: [Company]

    private var myCompanies: [Company] {
        guard let user = authManager.currentUser else { return [] }
        return companies.filter { company in
            company.members.contains(where: { $0.id == user.id })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if myCompanies.isEmpty {
                    Section {
                        EmptyStateView(
                            icon: "building.2",
                            title: "Henüz firma yok",
                            subtitle: "Bir firmaya katılmak için davet kodu kullanın."
                        )
                    }
                } else {
                    ForEach(myCompanies) { company in
                        Section {
                            LabeledContent("Firma Adı", value: company.companyName)
                            if let phone = company.phone { LabeledContent("Telefon", value: phone) }
                            if let email = company.email { LabeledContent("E-posta", value: email) }
                            LabeledContent("Üye Sayısı", value: "\(company.members.count) kişi")
                        } header: {
                            Label(company.companyName, systemImage: "building.2")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Çalıştığım Firmalar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - ContractorPerformanceEditView (FAZ 16 — #119)

struct ContractorPerformanceEditView: View {
    @Bindable var contractor: Contractor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Performans Puanları (0–10)") {
                    LabeledContent("Genel Puan", value: String(format: "%.1f", contractor.overallPerformanceScore))
                    VStack(alignment: .leading) {
                        Text("İş Kalitesi: \(Int(contractor.qualityScore))/10").font(.subheadline)
                        Slider(value: $contractor.qualityScore, in: 0...10, step: 1)
                            .tint(.hakedisOrange)
                    }
                    VStack(alignment: .leading) {
                        Text("Zamanında Teslim: \(Int(contractor.onTimeScore))/10").font(.subheadline)
                        Slider(value: $contractor.onTimeScore, in: 0...10, step: 1)
                            .tint(.hakedisSuccess)
                    }
                    VStack(alignment: .leading) {
                        Text("İSG Uyumu: \(Int(contractor.safetyScore))/10").font(.subheadline)
                        Slider(value: $contractor.safetyScore, in: 0...10, step: 1)
                            .tint(.blue)
                    }
                }
                Section("Değerlendirme Notu") {
                    TextEditor(text: $contractor.performanceNotes)
                        .frame(minHeight: 80)
                }
                Section {
                    LabeledContent("Genel Değerlendirme", value: contractor.performanceRating)
                        .foregroundColor(
                            contractor.overallPerformanceScore >= 8 ? .hakedisSuccess :
                            contractor.overallPerformanceScore >= 6 ? .hakedisWarning : .hakedisDanger
                        )
                }
            }
            .navigationTitle("Performans Değerlendirmesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
