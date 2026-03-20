import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query private var projects: [Project]
    @Query private var contractors: [Contractor]
    @Query private var hakedisler: [Hakedis]

    private var totalContractValue: Double {
        projects.flatMap { $0.contracts }.reduce(0) { $0 + $1.totalContractAmount }
    }

    private var totalInvoiced: Double {
        hakedisler.reduce(0) { $0 + $1.netAmount }
    }

    private var totalPaid: Double {
        hakedisler.reduce(0) { $0 + $1.totalPaid }
    }

    private var totalPending: Double {
        hakedisler.filter { $0.status == .approved }.reduce(0) { $0 + $1.remainingAmount }
    }

    var body: some View {
        NavigationStack {
            List {
                // Financial Summary
                Section("Genel Finansal Özet") {
                    VStack(spacing: 14) {
                        FinancialRow(label: "Toplam Sözleşme Değeri", value: totalContractValue, color: .primary)
                        FinancialRow(label: "Toplam Hakediş Kesildi", value: totalInvoiced, color: .hakedisOrange)
                        FinancialRow(label: "Toplam Ödenen", value: totalPaid, color: .hakedisSuccess)
                        Divider()
                        FinancialRow(label: "Bekleyen Ödeme", value: totalPending, color: .hakedisDanger)
                    }
                    .padding(.vertical, 4)
                }

                // Per Project
                Section("Proje Bazlı") {
                    ForEach(projects) { project in
                        ProjectReportRow(project: project)
                    }
                }

                // Per Contractor
                Section("Taşeron Bazlı") {
                    ForEach(contractors) { contractor in
                        ContractorReportRow(contractor: contractor)
                    }
                }

                // Hakedis Status Summary
                Section("Hakediş Durumu") {
                    ForEach(HakedisStatus.allCases, id: \.self) { status in
                        let count = hakedisler.filter { $0.status == status }.count
                        let total = hakedisler.filter { $0.status == status }.reduce(0) { $0 + $1.netAmount }
                        if count > 0 {
                            HStack {
                                Text(status.rawValue)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(count) adet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(total.currencyFormatted)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.hakedisOrange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Raporlar")
        }
    }
}

struct FinancialRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.currencyFormatted)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }
}

struct ProjectReportRow: View {
    let project: Project

    private var totalContract: Double {
        project.contracts.reduce(0) { $0 + $1.totalContractAmount }
    }
    private var totalHakedis: Double {
        project.contracts.flatMap { $0.hakedisler }.reduce(0) { $0 + $1.netAmount }
    }
    private var completionRate: Double {
        guard totalContract > 0 else { return 0 }
        return (totalHakedis / totalContract) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.name)
                    .font(.subheadline.bold())
                Spacer()
                Text(completionRate.percentFormatted)
                    .font(.caption.bold())
                    .foregroundStyle(.hakedisOrange)
            }
            ProgressBarView(progress: completionRate, color: .hakedisOrange)
            HStack {
                Text("Hakediş: \(totalHakedis.currencyFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Sözleşme: \(totalContract.currencyFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContractorReportRow: View {
    let contractor: Contractor

    private var totalInvoiced: Double {
        contractor.contracts.flatMap { $0.hakedisler }.reduce(0) { $0 + $1.netAmount }
    }
    private var totalPaid: Double {
        contractor.contracts.flatMap { $0.hakedisler }.reduce(0) { $0 + $1.totalPaid }
    }
    private var totalPending: Double { totalInvoiced - totalPaid }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(contractor.name)
                .font(.subheadline.bold())
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hakediş").font(.caption2).foregroundStyle(.secondary)
                    Text(totalInvoiced.currencyFormatted).font(.caption.bold())
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Ödenen").font(.caption2).foregroundStyle(.secondary)
                    Text(totalPaid.currencyFormatted).font(.caption).foregroundStyle(.hakedisSuccess)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Kalan").font(.caption2).foregroundStyle(.secondary)
                    Text(totalPending.currencyFormatted).font(.caption.bold())
                        .foregroundStyle(totalPending > 0 ? .hakedisDanger : .hakedisSuccess)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
