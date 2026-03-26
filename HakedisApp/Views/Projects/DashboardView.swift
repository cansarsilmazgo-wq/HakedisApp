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

    private var todayEntries: [DailyEntry] {
        let calendar = Calendar.current
        return dailyEntries.filter { calendar.isDateInToday($0.date) }
    }

    @State private var showingSearch = false
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

                    // Active Projects
                    if !activeProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Aktif Projeler")
                            ForEach(activeProjects.prefix(3)) { project in
                                ProjectMiniCard(project: project)
                            }
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
