import SwiftUI
import SwiftData

// MARK: - EVMBudgetListView (selects a budget then shows EVMDashboard)

struct EVMBudgetListView: View {
    @Query(sort: \ProjectBudget.createdAt, order: .reverse) private var budgets: [ProjectBudget]

    var body: some View {
        NavigationStack {
            List {
                ForEach(budgets, id: \.id) { budget in
                    NavigationLink(destination: EVMDashboardView(budget: budget)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(budget.projectName).font(.subheadline.bold())
                            Text(budget.totalBudget.currencyFormatted).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("EVM Analizi")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if budgets.isEmpty {
                    EmptyStateView(icon: "chart.xyaxis.line", title: "EVM Verisi Yok",
                                   subtitle: "Bütçe oluşturun ve EVM kaydı ekleyin")
                }
            }
        }
    }
}

// MARK: - FinansTabView

struct FinansTabView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedSegment = 0
    @Query private var hakedisler: [Hakedis]

    private var role: UserRole { authManager.currentRole }

    private var visibleSegments: [(title: String, originalIndex: Int)] {
        var result: [(String, Int)] = []
        if role.canCreateHakedis   { result.append(("Hakediş", 0)) }
        if role.canSeeFinancials    { result.append(("Ödemeler", 1)) }
        if role.canSeeFinancials    { result.append(("Nakit Akış", 2)) }
        if role.canManageContracts  { result.append(("Fiyat Farkı", 3)) }
        if role.canManageContracts  { result.append(("Teminat", 4)) }
        if role.canSeeBudget        { result.append(("Bütçe", 5)) }
        if role.canSeeEVM           { result.append(("EVM", 6)) }
        if role.canSeeProfitability { result.append(("Kârlılık", 7)) }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(visibleSegments.indices, id: \.self) { i in
                            let seg = visibleSegments[i]
                            Button {
                                selectedSegment = i
                            } label: {
                                Text(seg.title)
                                    .font(.subheadline.weight(selectedSegment == i ? .semibold : .regular))
                                    .foregroundColor(selectedSegment == i ? .hakedisOrange : .secondary)
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .overlay(
                                        Rectangle().frame(height: 2)
                                            .foregroundColor(selectedSegment == i ? .hakedisOrange : .clear),
                                        alignment: .bottom
                                    )
                            }
                            .accessibilityLabel(seg.title)
                            .accessibilityAddTraits(selectedSegment == i ? .isSelected : [])
                        }
                    }
                }
                .background(Color.hakedisCard)
                Divider()
                ZStack {
                    if selectedSegment < visibleSegments.count {
                        let originalIdx = visibleSegments[selectedSegment].originalIndex
                        switch originalIdx {
                        case 0: AllHakedisListView()
                        case 1: AllPaymentsView()
                        case 2: CashFlowView(hakedisler: hakedisler)
                        case 3: PriceDifferenceListView()
                        case 4: AllGuaranteeListView()
                        case 5: BudgetView()
                        case 6: EVMBudgetListView()
                        case 7: ProfitAnalysisView()
                        default: EmptyView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Finans")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
