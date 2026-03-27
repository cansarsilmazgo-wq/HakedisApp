import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var projects: [Project]
    @Query private var hakedisler: [Hakedis]
    @Query private var dailyEntries: [DailyEntry]

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

    private var todayEntries: [DailyEntry] {
        let calendar = Calendar.current
        return dailyEntries.filter { calendar.isDateInToday($0.date) }
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
            .background(Color.hakedisBackground)
            .navigationTitle("Ana Ekran")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSearch = true } label: { Image(systemName: "magnifyingglass") }
                }
            }
            .sheet(isPresented: $showingSearch) { UniversalSearchView() }
            .onAppear {
                loadPendingObjectionCount()
                triggerBudgetNotificationsIfNeeded()
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
        .padding(14)
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
        .padding(14)
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
        .padding(14)
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
        .padding(14)
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
                StatusBadge(text: project.status.rawValue, color: .hakedisSuccess)
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
        .padding(14)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
