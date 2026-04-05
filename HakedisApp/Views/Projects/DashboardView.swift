import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var projects: [Project]
    @Query private var hakedisler: [Hakedis]
    @Query private var dailyEntries: [DailyEntry]
    @Query private var attendanceRecords: [Attendance]
    @Query private var materials: [Material]
    @Query private var safetyIncidents: [SafetyIncident]
    @Query(sort: \SiteDiary.date, order: .reverse) private var siteDiaries: [SiteDiary]
    @Query private var priceDiffCalcs: [PriceDifferenceCalc]
    @Query private var stockEntries: [StockEntry]
    @Query private var equipmentLogs: [EquipmentLog]
    @Query private var subHakedisler: [SubcontractorHakedis]
    @Query private var allWorkers: [Worker]
    @Query private var allEquipment: [EquipmentItem]
    @Query private var allMaterialOrders: [MaterialOrder]
    @Query private var allMaterialRequests: [MaterialRequest]
    @Query private var allRiskAssessments: [RiskAssessment]
    @Query private var allCorrectiveActions: [CorrectiveAction]

    private var activeProjects: [Project] {
        projects.filter { $0.status == .active }
    }
    private var pendingHakedisler: [Hakedis] {
        hakedisler.filter { $0.status == .pendingApproval }
    }
    private var overduePayments: [Hakedis] {
        hakedisler.filter { $0.status == .approved && $0.remainingAmount > 0 }
    }
    private var overBudgetContracts: [Contract] {
        projects.flatMap { $0.contracts }.filter { $0.isOverBudget }
    }
    private var nearBudgetContracts: [Contract] {
        projects.flatMap { $0.contracts }.filter { !$0.isOverBudget && $0.budgetUtilization >= 80 }
    }
    private var pendingChangeOrders: [ChangeOrder] {
        projects.flatMap { $0.contracts }.flatMap { $0.changeOrders }.filter { $0.status == .pending }
    }
    private var overdueMilestones: [Milestone] {
        projects.flatMap { $0.milestones }.filter { $0.isOverdue }
    }
    private var upcomingMilestones: [Milestone] {
        projects.flatMap { $0.milestones }
            .filter { !$0.isCompleted && !$0.isOverdue && $0.daysUntilDue <= 7 }
            .sorted { $0.plannedDate < $1.plannedDate }
    }
    /// Bugün rapor girilmemiş aktif projeler
    private var projectsMissingTodayReport: [Project] {
        activeProjects.filter { project in
            !project.siteReports.contains { Calendar.current.isDateInToday($0.date) }
        }
    }

    private var todayEntries: [DailyEntry] {
        let calendar = Calendar.current
        return dailyEntries.filter { calendar.isDateInToday($0.date) }
    }

    private var todayAttendance: [Attendance] {
        attendanceRecords.filter { Calendar.current.isDateInToday($0.date) && $0.isPresent }
    }

    private var lowStockMaterials: [Material] {
        materials.filter { $0.isLowStock }
    }

    private var openSafetyIncidents: [SafetyIncident] {
        safetyIncidents.filter { !$0.isResolved }
    }

    private var latestDiary: SiteDiary? {
        siteDiaries.first
    }

    private var contractsWithDeficiencies: [Contract] {
        projects.flatMap { $0.contracts }.filter { $0.openDeficiencyCount > 0 }
    }
    private var overdueCorrespondence: [(contract: Contract, record: CorrespondenceRecord)] {
        projects.flatMap { $0.contracts }.flatMap { contract in
            contract.correspondenceRecords
                .filter { $0.isSureDoldu }
                .map { (contract: contract, record: $0) }
        }
    }
    private var blockingTests: [(contract: Contract, record: TestRecord)] {
        projects.flatMap { $0.contracts }.flatMap { contract in
            contract.testRecords
                .filter { $0.blocksApproval }
                .map { (contract: contract, record: $0) }
        }
    }
    private var nearExpiryWarranties: [(contract: Contract, record: AcceptanceRecord)] {
        projects.flatMap { $0.contracts }.flatMap { contract in
            contract.acceptanceRecords
                .filter { $0.isNearingWarrantyExpiry }
                .map { (contract: contract, record: $0) }
        }
    }

    // Financial totals across all projects
    private var totalContractValue: Double {
        projects.flatMap { $0.contracts }.reduce(0) { $0 + $1.totalContractAmount }
    }
    private var totalInvoiced: Double {
        hakedisler.filter { $0.status != .draft }.reduce(0) { $0 + $1.netAmount }
    }
    private var totalPaid: Double {
        hakedisler.reduce(0) { $0 + $1.totalPaid }
    }
    private var totalPending: Double {
        hakedisler.filter { $0.status == .approved }.reduce(0) { $0 + $1.remainingAmount }
    }

    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingSearch = false
    @State private var pendingObjectionCount: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Stat Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            title: "Aktif Proje",
                            value: "\(activeProjects.count)",
                            color: .hakedisOrange,
                            icon: "building.2"
                        )
                        StatCard(
                            title: "Onay Bekleyen",
                            value: "\(pendingHakedisler.count)",
                            subtitle: "Hakediş",
                            color: .hakedisWarning,
                            icon: "clock"
                        )
                        StatCard(
                            title: "Geciken Ödeme",
                            value: "\(overduePayments.count)",
                            color: .hakedisDanger,
                            icon: "exclamationmark.circle"
                        )
                        StatCard(
                            title: "Bugün Giriş",
                            value: "\(todayEntries.count)",
                            subtitle: "Saha kaydı",
                            color: .hakedisSuccess,
                            icon: "checkmark.circle"
                        )
                    }

                    // Financial Summary
                    if !projects.isEmpty {
                        DashboardFinancialSummary(
                            totalContractValue: totalContractValue,
                            totalInvoiced: totalInvoiced,
                            totalPaid: totalPaid,
                            totalPending: totalPending
                        )
                    }

                    // Bu Ay Nakit Akış Özeti
                    let buAyNet = GenisletilmisCashFlowEngine.buAyNetAkis(
                        hakedisler: hakedisler,
                        priceDiffCalcs: priceDiffCalcs,
                        stockEntries: stockEntries,
                        attendanceRecords: attendanceRecords,
                        equipmentLogs: equipmentLogs,
                        subHakedisler: subHakedisler
                    )
                    NavigationLink(destination: CashFlowProjectionView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .foregroundColor(buAyNet >= 0 ? .hakedisSuccess : .hakedisDanger)
                                .frame(width: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Bu Ay Net Nakit Akış")
                                    .font(.caption).foregroundColor(.secondary)
                                Text((buAyNet >= 0 ? "+" : "") + buAyNet.currencyFormatted)
                                    .font(.subheadline.bold())
                                    .foregroundColor(buAyNet >= 0 ? .hakedisSuccess : .hakedisDanger)
                                Text("Gelir – Gider tahmini")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(Spacing.card)
                        .background(Color.hakedisCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, Spacing.card)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Nakit akış projeksiyonu, bu ay net \((buAyNet >= 0 ? "+" : "") + buAyNet.currencyFormatted)")

                    // Bugün Şantiye Özeti
                    if !attendanceRecords.isEmpty || latestDiary != nil {
                        let expiringSoonCount = allWorkers.reduce(0) { $0 + $1.expiringSoonCertificates().count }
                        let todayCost = todayAttendance.reduce(0.0) { $0 + $1.totalDailyCost }
                        let professionGroups = Dictionary(grouping: todayAttendance.compactMap { $0.worker?.profession }) { $0 }
                        DashboardSantiyeCard(
                            workerCount: todayAttendance.count,
                            lastDiary: latestDiary,
                            lowStockCount: lowStockMaterials.count,
                            openIncidentCount: openSafetyIncidents.count,
                            expiringSoonCertCount: expiringSoonCount,
                            todayTotalCost: todayCost,
                            professionCounts: professionGroups.mapValues { $0.count }
                        )
                    }

                    // Ekipman Özeti
                    let openFailureCount = allEquipment.filter { $0.hasOpenFailure }.count
                    let maintenanceDueCount = allEquipment.filter { $0.isMaintenanceDue }.count
                    let thisMonthEquipCost = allEquipment.reduce(0.0) { $0 + $1.monthlyCost }
                    if !allEquipment.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader("Ekipman Durumu")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                StatCard(title: "Toplam Ekipman", value: "\(allEquipment.count)", color: .hakedisInfo, icon: "gearshape.2")
                                StatCard(title: "Bakım Bekliyor", value: "\(maintenanceDueCount)", color: maintenanceDueCount > 0 ? .hakedisWarning : .hakedisSuccess, icon: "wrench.and.screwdriver")
                                StatCard(title: "Açık Arıza", value: "\(openFailureCount)", color: openFailureCount > 0 ? .hakedisDanger : .hakedisSuccess, icon: "exclamationmark.circle")
                                StatCard(title: "Bu Ay Maliyet", value: thisMonthEquipCost.currencyFormatted, color: .hakedisOrange, icon: "turkishlirasign.circle")
                            }
                        }
                    }

                    // Malzeme & Sipariş Özeti
                    let delayedOrderCount = allMaterialOrders.filter { $0.isDelayed }.count
                    let pendingRequestCount = allMaterialRequests.filter { $0.status == .submitted }.count
                    let totalStockValue = materials.reduce(0.0) { $0 + $1.stockValue }
                    if delayedOrderCount > 0 || pendingRequestCount > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader("Malzeme & Sipariş")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                if delayedOrderCount > 0 {
                                    StatCard(title: "Gecikmiş Sipariş", value: "\(delayedOrderCount)", color: .hakedisDanger, icon: "clock.badge.exclamationmark")
                                }
                                if pendingRequestCount > 0 {
                                    StatCard(title: "Bekleyen Talep", value: "\(pendingRequestCount)", color: .hakedisWarning, icon: "list.clipboard")
                                }
                                StatCard(title: "Toplam Stok Değeri", value: totalStockValue.currencyFormatted, color: .hakedisSuccess, icon: "shippingbox")
                            }
                        }
                    }

                    // Kritik Stok Uyarısı
                    if !lowStockMaterials.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Kritik Stok Uyarısı")
                            ForEach(lowStockMaterials.prefix(3), id: \.id) { mat in
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.hakedisDanger)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mat.name).font(.subheadline.bold())
                                        Text("Mevcut: \(mat.currentStock.quantityFormatted) \(mat.unit) / Min: \(mat.minimumStock.quantityFormatted)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    StatusBadge(text: "Kritik", color: .hakedisDanger)
                                }
                                .padding(Spacing.cardSmall)
                                .background(Color.hakedisCard)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(mat.name) kritik stok seviyesinde")
                            }
                        }
                    }

                    // Gecikmiş Karar Uyarısı
                    OverdueDecisionsCard()

                    // İSG Dashboard Kartı
                    let highUncontrolledRisks = allRiskAssessments.filter { ($0.riskLevel == .high || $0.riskLevel == .veryHigh) && !$0.isControlled }
                    let overdueActions = allCorrectiveActions.filter { $0.isOverdue }
                    let sgkPendingIncidents = safetyIncidents.filter { $0.incidentType == .majorInjury && !$0.reportedToSGK && $0.isSGKDeadlineApproaching }
                    let sgkOverdueIncidents = safetyIncidents.filter { $0.incidentType == .majorInjury && $0.isSGKDeadlineOverdue }

                    if !openSafetyIncidents.isEmpty || !highUncontrolledRisks.isEmpty || !overdueActions.isEmpty || !sgkPendingIncidents.isEmpty || !sgkOverdueIncidents.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader("İSG Özeti")

                            // SGK Deadline Uyarısı
                            if !sgkOverdueIncidents.isEmpty {
                                ISGDashboardAlertRow(
                                    icon: "exclamationmark.circle.fill",
                                    color: .hakedisDanger,
                                    text: "\(sgkOverdueIncidents.count) iş kazası SGK bildirim süresi geçti!"
                                )
                            }
                            if !sgkPendingIncidents.isEmpty {
                                ISGDashboardAlertRow(
                                    icon: "clock.badge.exclamationmark.fill",
                                    color: .hakedisWarning,
                                    text: "\(sgkPendingIncidents.count) iş kazası SGK bildirimi bekliyor"
                                )
                            }
                            if !highUncontrolledRisks.isEmpty {
                                ISGDashboardAlertRow(
                                    icon: "exclamationmark.triangle.fill",
                                    color: .hakedisWarning,
                                    text: "\(highUncontrolledRisks.count) kontrolsüz yüksek/çok yüksek risk"
                                )
                            }
                            if !overdueActions.isEmpty {
                                ISGDashboardAlertRow(
                                    icon: "clock.fill",
                                    color: .hakedisOrange,
                                    text: "\(overdueActions.count) gecikmiş düzeltici faaliyet"
                                )
                            }

                            // Açık olaylar
                            ForEach(openSafetyIncidents.prefix(3), id: \.id) { incident in
                                HStack(spacing: 10) {
                                    Image(systemName: incident.incidentType.icon)
                                        .foregroundColor(.hakedisDanger)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(incident.incidentType.rawValue).font(.subheadline.bold())
                                        Text(String(incident.incidentDescription.prefix(50)))
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(incident.date.shortFormatted)
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(Spacing.cardSmall)
                                .background(Color.hakedisCard)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("ISG olayı: \(incident.incidentType.rawValue)")
                            }
                        }
                    }

                    // Pending Hakedis
                    if !pendingHakedisler.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Onay Bekleyen Hakedişler")
                            ForEach(pendingHakedisler.prefix(3)) { hakedis in
                                HakedisRowCard(hakedis: hakedis)
                            }
                        }
                    }

                    // Overdue Payments
                    if !overduePayments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Bekleyen Ödemeler")
                            ForEach(overduePayments.prefix(3)) { hakedis in
                                PaymentAlertCard(hakedis: hakedis)
                            }
                        }
                    }

                    // Budget Overrun Alarms
                    if !overBudgetContracts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Bütçe Aşımı")
                            ForEach(overBudgetContracts.prefix(3)) { contract in
                                BudgetAlarmCard(contract: contract)
                            }
                        }
                    }

                    if !nearBudgetContracts.isEmpty && overBudgetContracts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Bütçe Uyarısı")
                            ForEach(nearBudgetContracts.prefix(3)) { contract in
                                BudgetAlarmCard(contract: contract)
                            }
                        }
                    }

                    // Pending Change Orders
                    if !pendingChangeOrders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Onay Bekleyen Ek İş Emirleri")
                            ForEach(pendingChangeOrders.prefix(3)) { co in
                                ChangeOrderAlertCard(changeOrder: co)
                            }
                        }
                    }

                    // Overdue Milestones
                    if !overdueMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Geciken Kilometre Taşları")
                            ForEach(overdueMilestones.prefix(3)) { ms in
                                MilestoneAlertCard(milestone: ms)
                            }
                        }
                    }

                    // Upcoming Milestones (7 gün içinde)
                    if !upcomingMilestones.isEmpty && overdueMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Yaklaşan Kilometre Taşları")
                            ForEach(upcomingMilestones.prefix(3)) { ms in
                                MilestoneAlertCard(milestone: ms)
                            }
                        }
                    }

                    // Unlabeled Photos
                    UnlabeledPhotosAlertCard(projects: projects)

                    // Open Deficiencies
                    if !contractsWithDeficiencies.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Açık Eksiklikler")
                            ForEach(contractsWithDeficiencies.prefix(3)) { contract in
                                DeficiencyAlertCard(contract: contract)
                            }
                        }
                    }

                    // Missing Today's Site Report
                    if !projectsMissingTodayReport.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Bugün Rapor Girilmedi")
                            ForEach(projectsMissingTodayReport.prefix(3)) { project in
                                NavigationLink(destination: SiteReportListView(project: project)) {
                                    SiteReportMissingCard(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Overdue Correspondence
                    if !overdueCorrespondence.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Geciken Yazışmalar")
                            ForEach(overdueCorrespondence.prefix(3), id: \.record.id) { item in
                                CorrespondenceOverdueCard(contract: item.contract, record: item.record)
                            }
                        }
                    }

                    // Blocking Tests
                    if !blockingTests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Başarısız Zorunlu Testler")
                            ForEach(blockingTests.prefix(3), id: \.record.id) { item in
                                BlockingTestCard(contract: item.contract, record: item.record)
                            }
                        }
                    }

                    // Near Expiry Warranties
                    if !nearExpiryWarranties.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Yaklaşan Garanti Bitimleri")
                            ForEach(nearExpiryWarranties.prefix(3), id: \.record.id) { item in
                                WarrantyExpiryCard(contract: item.contract, record: item.record)
                            }
                        }
                    }

                    // Active Projects
                    if !activeProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Aktif Projeler")
                            ForEach(activeProjects.prefix(3)) { project in
                                ProjectMiniCard(project: project)
                            }
                        }
                    }

                    // Pending Objections
                    if pendingObjectionCount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Taşeron İtirazları")
                            NavigationLink(destination: ObjectionAdminView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.bubble.fill")
                                        .foregroundColor(.hakedisDanger)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(pendingObjectionCount) bekleyen itiraz")
                                            .font(.subheadline.bold())
                                        Text("Taşeronların itirazlarını inceleyin")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                .background(Color.hakedisCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.hakedisDanger.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if projects.isEmpty {
                        EmptyStateView(
                            icon: "building.2.crop.circle",
                            title: "Henüz proje yok",
                            subtitle: "İlk projenizi oluşturarak başlayın",
                            actionTitle: "Proje Ekle"
                        )
                    }
                }
                .padding(16)
            }
            .refreshable {
                // SwiftData @Query otomatik güncellenir; widget'ı yenile
                WidgetDataManager.update(projects: projects, hakedisler: hakedisler)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Ana Ekran")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSearch = true } label: { Image(systemName: "magnifyingglass") }
                        .accessibilityLabel("Ara")
                }
            }
            .sheet(isPresented: $showingSearch) { UniversalSearchView() }
            .onAppear {
                loadPendingObjectionCount()
                triggerBudgetNotificationsIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                loadPendingObjectionCount()
            }
        }
    }

    private func loadPendingObjectionCount() {
        let count = UserDefaults.standard.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("objection_") }
            .compactMap { _, value -> [String: String]? in
                guard let data = value as? Data,
                      let record = try? JSONDecoder().decode([String: String].self, from: data)
                else { return nil }
                return record
            }
            .filter { $0["status"] == "pending" }
            .count
        pendingObjectionCount = count
    }

    private func triggerBudgetNotificationsIfNeeded() {
        guard notificationManager.budgetAlertsEnabled else { return }
        let allContracts = projects.flatMap { $0.contracts }
        for contract in allContracts where contract.isOverBudget || contract.budgetUtilization >= 80 {
            notificationManager.scheduleBudgetOverrunAlert(contract: contract)
        }
    }
}

// MARK: - DashboardSantiyeCard
struct DashboardSantiyeCard: View {
    let workerCount: Int
    let lastDiary: SiteDiary?
    let lowStockCount: Int
    let openIncidentCount: Int
    let expiringSoonCertCount: Int
    let todayTotalCost: Double
    let professionCounts: [WorkerProfession: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Bugün Şantiye")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatCard(
                    title: "Bugün İşçi",
                    value: "\(workerCount)",
                    subtitle: "Sahada",
                    color: .hakedisSuccess,
                    icon: "person.3"
                )
                StatCard(
                    title: "İşçilik Maliyeti",
                    value: todayTotalCost > 0 ? todayTotalCost.currencyFormatted : "—",
                    subtitle: "Bugün",
                    color: .hakedisOrange,
                    icon: "turkishlirasign.circle"
                )
            }
            if !professionCounts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(professionCounts.keys), id: \.rawValue) { prof in
                            HStack(spacing: 4) {
                                Image(systemName: prof.icon).font(.caption2)
                                Text("\(professionCounts[prof] ?? 0) \(prof.rawValue)")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.hakedisCard)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            VStack(spacing: 6) {
                if let diary = lastDiary {
                    HStack(spacing: 8) {
                        Image(systemName: diary.weatherCondition.icon)
                            .font(.subheadline)
                            .foregroundColor(.hakedisWarning)
                        Text(diary.weatherCondition.rawValue).font(.caption.bold())
                        if let temp = diary.temperature {
                            Text("\(Int(temp))°C").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(diary.date.shortFormatted).font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(Spacing.cardSmall)
                    .background(Color.hakedisCard)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Hava: \(diary.weatherCondition.rawValue)")
                }
                HStack(spacing: 12) {
                    if expiringSoonCertCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.hakedisWarning)
                            Text("\(expiringSoonCertCount) sertifika uyarısı")
                                .font(.caption).foregroundColor(.hakedisWarning)
                        }
                    }
                    if lowStockCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox").foregroundColor(.hakedisDanger)
                            Text("\(lowStockCount) kritik stok").font(.caption).foregroundColor(.hakedisDanger)
                        }
                    }
                    if openIncidentCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.shield").foregroundColor(.hakedisWarning)
                            Text("\(openIncidentCount) açık olay").font(.caption).foregroundColor(.hakedisWarning)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Subcomponents
struct HakedisRowCard: View {
    let hakedis: Hakedis

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(hakedis.contract?.title ?? "—")
                    .font(.subheadline.bold())
                Text(hakedis.periodName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(hakedis.netAmount.currencyFormatted)
                    .font(.subheadline.bold())
                StatusBadge(text: hakedis.status.rawValue, color: .hakedisWarning)
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PaymentAlertCard: View {
    let hakedis: Hakedis

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hakedis.isOverdue ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(.hakedisDanger)
            VStack(alignment: .leading, spacing: 3) {
                Text(hakedis.contract?.title ?? "—")
                    .font(.subheadline.bold())
                Text(hakedis.periodName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if hakedis.isOverdue {
                    Text("\(hakedis.daysOverdue) gün gecikme")
                        .font(.caption.bold())
                        .foregroundColor(.hakedisDanger)
                } else if let due = hakedis.dueDate {
                    let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                    Text("Vade: \(due.shortFormatted)\(daysLeft > 0 ? " (\(daysLeft) gün)" : " — bugün")")
                        .font(.caption)
                        .foregroundColor(.hakedisWarning)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(hakedis.remainingAmount.currencyFormatted)
                    .font(.subheadline.bold())
                    .foregroundColor(.hakedisDanger)
                if hakedis.overdueInterest > 0 {
                    Text("+\(hakedis.overdueInterest.currencyFormatted) faiz")
                        .font(.caption2)
                        .foregroundColor(.hakedisDanger.opacity(0.7))
                }
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hakedis.isOverdue ? Color.hakedisDanger.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

struct BudgetAlarmCard: View {
    let contract: Contract

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: contract.isOverBudget ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(contract.isOverBudget ? .hakedisDanger : .hakedisWarning)
            VStack(alignment: .leading, spacing: 3) {
                Text(contract.title).font(.subheadline.bold())
                Text(contract.project?.name ?? "—").font(.caption).foregroundColor(.secondary)
                ProgressBarView(
                    progress: min(contract.budgetUtilization, 100),
                    color: contract.isOverBudget ? .hakedisDanger : .hakedisWarning
                )
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(contract.budgetUtilization.percentFormatted)
                    .font(.subheadline.bold())
                    .foregroundColor(contract.isOverBudget ? .hakedisDanger : .hakedisWarning)
                Text("kullanım").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(contract.isOverBudget ? Color.hakedisDanger.opacity(0.3) : Color.hakedisWarning.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ChangeOrderAlertCard: View {
    let changeOrder: ChangeOrder

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.badge.clock.fill")
                .foregroundColor(.hakedisWarning)
            VStack(alignment: .leading, spacing: 3) {
                Text(changeOrder.title).font(.subheadline.bold())
                Text(changeOrder.contract?.title ?? "—")
                    .font(.caption).foregroundColor(.secondary)
                Text(changeOrder.changeDate.shortFormatted)
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                let sign = changeOrder.amount >= 0 ? "+" : ""
                Text("\(sign)\(changeOrder.amount.currencyFormatted)")
                    .font(.caption.bold())
                    .foregroundColor(changeOrder.amount >= 0 ? .hakedisWarning : .hakedisSuccess)
                Text("Onay bekliyor").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.hakedisWarning.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ProjectMiniCard: View {
    let project: Project

    private var totalCompletion: Double {
        let items = project.contracts.flatMap { $0.workItems }
        guard !items.isEmpty else { return 0 }
        return items.reduce(0) { $0 + $1.completionPercentage } / Double(items.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(project.name)
                    .font(.subheadline.bold())
                Spacer()
                StatusBadge(text: project.status.rawValue,
                            color: project.status == .active ? .hakedisSuccess : project.status == .completed ? .hakedisInfo : .hakedisWarning)
            }
            if !project.location.isEmpty {
                Text(project.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                ProgressBarView(progress: totalCompletion, color: .hakedisOrange)
                Text(totalCompletion.percentFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CorrespondenceOverdueCard: View {
    let contract: Contract
    let record: CorrespondenceRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.badge.fill")
                .foregroundColor(.hakedisDanger)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.subject).font(.subheadline.bold()).lineLimit(1)
                Text(contract.title).font(.caption).foregroundColor(.secondary)
                Text("Cevap süresi doldu").font(.caption2).foregroundColor(.hakedisDanger)
            }
            Spacer()
            StatusBadge(text: record.direction.rawValue, color: .hakedisDanger)
        }
        .padding(Spacing.cardSmall)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hakedisDanger.opacity(0.3), lineWidth: 1))
    }
}

struct BlockingTestCard: View {
    let contract: Contract
    let record: TestRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.seal.fill")
                .foregroundColor(.hakedisDanger)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.testName).font(.subheadline.bold()).lineLimit(1)
                Text(contract.title).font(.caption).foregroundColor(.secondary)
                Text("Hakediş onayını engelliyor").font(.caption2).foregroundColor(.hakedisDanger)
            }
            Spacer()
            StatusBadge(text: record.status.rawValue, color: .hakedisDanger)
        }
        .padding(Spacing.cardSmall)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hakedisDanger.opacity(0.3), lineWidth: 1))
    }
}

struct WarrantyExpiryCard: View {
    let contract: Contract
    let record: AcceptanceRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .foregroundColor(.hakedisWarning)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.acceptanceType.rawValue).font(.subheadline.bold())
                Text(contract.title).font(.caption).foregroundColor(.secondary)
                Text("\(record.warrantyDaysLeft) gün kaldı").font(.caption2).foregroundColor(.hakedisWarning)
            }
            Spacer()
            if let end = record.effectiveWarrantyEnd {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(end, style: .date).font(.caption2)
                    Text("bitiş").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(Spacing.cardSmall)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hakedisWarning.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Dashboard Financial Summary
struct DashboardFinancialSummary: View {
    let totalContractValue: Double
    let totalInvoiced: Double
    let totalPaid: Double
    let totalPending: Double

    private var invoicedRatio: Double {
        guard totalContractValue > 0 else { return 0 }
        return min(totalInvoiced / totalContractValue, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Finansal Özet")

            VStack(alignment: .leading, spacing: 14) {
                // Contract value + progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Toplam Sözleşme")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(totalContractValue.currencyFormatted)
                            .font(.subheadline.bold())
                    }
                    ProgressBarView(progress: invoicedRatio, color: .hakedisOrange)
                    HStack {
                        Text("Hakedişe Alınan")
                            .font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text((invoicedRatio * 100).percentFormatted)
                            .font(.caption2).foregroundColor(.hakedisOrange)
                    }
                }

                Divider()

                // 3-column money breakdown
                HStack(spacing: 0) {
                    financialCell(
                        label: "Hakediş",
                        amount: totalInvoiced,
                        color: .hakedisOrange,
                        icon: "doc.text.fill"
                    )
                    Divider().frame(height: 40)
                    financialCell(
                        label: "Ödenen",
                        amount: totalPaid,
                        color: .hakedisSuccess,
                        icon: "checkmark.seal.fill"
                    )
                    Divider().frame(height: 40)
                    financialCell(
                        label: "Bekleyen",
                        amount: totalPending,
                        color: totalPending > 0 ? .hakedisDanger : .secondary,
                        icon: "clock.fill"
                    )
                }
            }
            .padding(14)
            .background(Color.hakedisCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func financialCell(label: String, amount: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption).foregroundColor(color)
            Text(amount.compactCurrency)
                .font(.subheadline.bold())
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ISGDashboardAlertRow

private struct ISGDashboardAlertRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(text).font(.caption.bold()).foregroundColor(color)
            Spacer()
        }
        .padding(Spacing.cardSmall)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - OverdueDecisionsCard

private struct OverdueDecisionsCard: View {
    @Query private var allDecisions: [MeetingDecision]

    private var overdueDecisions: [MeetingDecision] {
        allDecisions.filter { $0.isOverdue && $0.status != .completed }
    }

    var body: some View {
        if !overdueDecisions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Toplantı Kararları")
                NavigationLink(destination: DecisionTrackingView()) {
                    StatCard(title: "Gecikmiş Karar",
                             value: "\(overdueDecisions.count)",
                             color: .hakedisDanger,
                             icon: "exclamationmark.triangle.fill")
                }
            }
        }
    }
}
