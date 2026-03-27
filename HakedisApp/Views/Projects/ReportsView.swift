import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct ReportsView: View {
    @Query private var projects: [Project]
    @Query private var contractors: [Contractor]
    @Query(sort: \Hakedis.periodEnd) private var hakedisler: [Hakedis]

    @State private var exportItem: ShareableCSV?
    @State private var selectedChartTab = 0

    private var totalContractValue: Double {
        projects.flatMap { $0.contracts }.reduce(0) { $0 + $1.totalContractAmount }
    }
    private var totalInvoiced: Double { hakedisler.reduce(0) { $0 + $1.netAmount } }
    private var totalKDV: Double { hakedisler.reduce(0) { $0 + $1.kdvAmount } }
    private var totalWithKDV: Double { hakedisler.reduce(0) { $0 + $1.totalWithKDV } }
    private var totalPaid: Double { hakedisler.reduce(0) { $0 + $1.totalPaid } }
    private var totalPending: Double {
        hakedisler.filter { $0.status == .approved }.reduce(0) { $0 + $1.remainingAmount }
    }

    var body: some View {
        NavigationStack {
            List {
                // Özet kartlar
                Section {
                    summaryCards
                }

                // Grafikler
                if !hakedisler.isEmpty {
                    Section("Grafikler") {
                        Picker("Grafik", selection: $selectedChartTab) {
                            Text("Aylık Trend").tag(0)
                            Text("Projeler").tag(1)
                            Text("Ödeme").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)

                        switch selectedChartTab {
                        case 0: MonthlyTrendChart(hakedisler: hakedisler)
                        case 1: ProjectCompletionChart(projects: projects)
                        default: PaymentStatusChart(
                            paid: totalPaid,
                            pending: totalPending,
                            remaining: max(0, totalInvoiced - totalPaid - totalPending)
                        )
                        }
                    }
                }

                // Proje bazlı
                if !projects.isEmpty {
                    Section("Proje Bazlı") {
                        ForEach(projects) { ProjectReportRow(project: $0) }
                    }
                }

                // Taşeron bazlı
                if !contractors.isEmpty {
                    Section("Taşeron Bazlı") {
                        ForEach(contractors) { contractor in
                            NavigationLink(destination: ContractorPerformanceView(contractor: contractor)) {
                                ContractorReportRow(contractor: contractor)
                            }
                        }
                    }
                }

                // Nakit akış tahmini
                if !hakedisler.isEmpty {
                    Section {
                        NavigationLink(destination: CashFlowView(hakedisler: Array(hakedisler))) {
                            Label("Nakit Akış Tahmini", systemImage: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.hakedisOrange)
                        }
                    }
                }

                // Hakediş durumu
                Section("Hakediş Durumu") {
                    ForEach(HakedisStatus.allCases, id: \.self) { status in
                        let count = hakedisler.filter { $0.status == status }.count
                        let total = hakedisler.filter { $0.status == status }.reduce(0) { $0 + $1.netAmount }
                        if count > 0 {
                            HStack {
                                Text(status.rawValue).font(.subheadline)
                                Spacer()
                                Text("\(count) adet").font(.caption).foregroundColor(.secondary)
                                Text(total.currencyFormatted).font(.subheadline.bold()).foregroundColor(.hakedisOrange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Raporlar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportItem = ShareableCSV(
                            content: CSVExporter.exportHakedisler(hakedisler),
                            filename: "hakedis_raporu_\(exportDateString()).csv"
                        )
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(hakedisler.isEmpty)
                }
            }
            .shareSheet(item: $exportItem)
        }
    }

    private var summaryCards: some View {
        VStack(spacing: 14) {
            FinancialRow(label: "Toplam Sözleşme Değeri", value: totalContractValue, color: .primary)
            FinancialRow(label: "Toplam Net Hakediş",     value: totalInvoiced,     color: .hakedisOrange)
            if totalKDV > 0 {
                FinancialRow(label: "Toplam KDV",         value: totalKDV,          color: .secondary)
                FinancialRow(label: "KDV Dahil Toplam",   value: totalWithKDV,      color: .hakedisOrange)
            }
            FinancialRow(label: "Toplam Ödenen",          value: totalPaid,         color: .hakedisSuccess)
            Divider()
            FinancialRow(label: "Bekleyen Ödeme",         value: totalPending,      color: .hakedisDanger)
        }
        .padding(.vertical, 4)
    }

    private func exportDateString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"; return f.string(from: Date())
    }
}

// MARK: - Monthly Trend Chart

struct MonthlyTrendChart: View {
    let hakedisler: [Hakedis]

    struct MonthlyData: Identifiable {
        let id = UUID()
        let label: String
        let date: Date
        let net: Double
        let paid: Double
    }

    private var data: [MonthlyData] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yy"
        fmt.locale = Locale(identifier: "tr_TR")

        let grouped = Dictionary(grouping: hakedisler) { h -> Date in
            let comps = cal.dateComponents([.year, .month], from: h.periodEnd)
            return cal.date(from: comps) ?? h.periodEnd
        }

        return grouped
            .map { date, items in
                MonthlyData(
                    label: fmt.string(from: date),
                    date: date,
                    net: items.reduce(0) { $0 + $1.netAmount },
                    paid: items.reduce(0) { $0 + $1.totalPaid }
                )
            }
            .sorted { $0.date < $1.date }
            .suffix(12)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aylık Hakediş (son 12 ay)")
                .font(.caption).foregroundColor(.secondary)

            Chart(data) { item in
                BarMark(
                    x: .value("Ay", item.label),
                    y: .value("Net", item.net / 1000)
                )
                .foregroundStyle(Color.hakedisOrange.gradient)
                .cornerRadius(4)

                LineMark(
                    x: .value("Ay", item.label),
                    y: .value("Ödenen", item.paid / 1000)
                )
                .foregroundStyle(Color.hakedisSuccess)
                .symbol(Circle().strokeBorder(lineWidth: 2))
                .symbolSize(30)
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks { val in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text("\(Int(v))K ₺").font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { AxisValueLabel().font(.caption2) }
            }

            HStack(spacing: 16) {
                legendItem(color: .hakedisOrange, label: "Hakediş")
                legendItem(color: .hakedisSuccess, label: "Ödenen")
            }
            .font(.caption2)
        }
        .padding(.vertical, 4)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundColor(.secondary)
        }
    }
}

// MARK: - Project Completion Chart

struct ProjectCompletionChart: View {
    let projects: [Project]

    struct ProjectData: Identifiable {
        let id: UUID
        let name: String
        let completion: Double
    }

    private var data: [ProjectData] {
        projects.map { p in
            let total = p.contracts.reduce(0) { $0 + $1.totalContractAmount }
            let invoiced = p.contracts.flatMap { $0.hakedisler }.reduce(0) { $0 + $1.netAmount }
            let pct = total > 0 ? min((invoiced / total) * 100, 100) : 0
            return ProjectData(id: p.id, name: p.name, completion: pct)
        }
        .sorted { $0.completion > $1.completion }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Proje Tamamlanma Oranı")
                .font(.caption).foregroundColor(.secondary)

            Chart(data) { item in
                BarMark(
                    x: .value("Tamamlanma", item.completion),
                    y: .value("Proje", item.name)
                )
                .foregroundStyle(
                    item.completion >= 100 ? Color.hakedisSuccess.gradient :
                    item.completion >= 50  ? Color.hakedisOrange.gradient :
                                             Color.hakedisWarning.gradient
                )
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text(item.completion.percentFormatted)
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .frame(height: max(80, CGFloat(data.count) * 44))
            .chartXScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                    AxisGridLine()
                    AxisValueLabel {
                        Text("%\(Int(val.as(Double.self) ?? 0))").font(.caption2)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Payment Status Chart

struct PaymentStatusChart: View {
    let paid: Double
    let pending: Double
    let remaining: Double

    struct Slice: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }

    private var slices: [Slice] {
        [
            Slice(label: "Ödendi", value: paid, color: .hakedisSuccess),
            Slice(label: "Onaylı Bekleyen", value: pending, color: .hakedisDanger),
            Slice(label: "Diğer", value: remaining, color: .hakedisOrange.opacity(0.5))
        ].filter { $0.value > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ödeme Dağılımı")
                .font(.caption).foregroundColor(.secondary)

            HStack(alignment: .center, spacing: 24) {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Tutar", slice.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(4)
                }
                .frame(width: 130, height: 130)
                .chartLegend(.hidden)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(slices) { slice in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(slice.color)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(slice.label).font(.caption2).foregroundColor(.secondary)
                                Text(slice.value.currencyFormatted).font(.caption.bold())
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

struct FinancialRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value.currencyFormatted).font(.subheadline.bold()).foregroundColor(color)
        }
    }
}

struct ProjectReportRow: View {
    let project: Project

    private var totalContract: Double { project.contracts.reduce(0) { $0 + $1.totalContractAmount } }
    private var totalHakedis: Double { project.contracts.flatMap { $0.hakedisler }.reduce(0) { $0 + $1.netAmount } }
    private var completionRate: Double {
        guard totalContract > 0 else { return 0 }
        return (totalHakedis / totalContract) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.name).font(.subheadline.bold())
                Spacer()
                Text(completionRate.percentFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
            }
            ProgressBarView(progress: completionRate, color: .hakedisOrange)
            HStack {
                Text("Hakediş: \(totalHakedis.currencyFormatted)").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("Sözleşme: \(totalContract.currencyFormatted)").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContractorReportRow: View {
    let contractor: Contractor

    private var totalInvoiced: Double { contractor.contracts.flatMap { $0.hakedisler }.reduce(0) { $0 + $1.netAmount } }
    private var totalPaid: Double { contractor.contracts.flatMap { $0.hakedisler }.reduce(0) { $0 + $1.totalPaid } }
    private var totalPending: Double { totalInvoiced - totalPaid }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(contractor.name).font(.subheadline.bold())
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hakediş").font(.caption2).foregroundColor(.secondary)
                    Text(totalInvoiced.currencyFormatted).font(.caption.bold())
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Ödenen").font(.caption2).foregroundColor(.secondary)
                    Text(totalPaid.currencyFormatted).font(.caption).foregroundColor(.hakedisSuccess)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Kalan").font(.caption2).foregroundColor(.secondary)
                    Text(totalPending.currencyFormatted).font(.caption.bold())
                        .foregroundColor(totalPending > 0 ? .hakedisDanger : .hakedisSuccess)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cash Flow View

struct CashFlowView: View {
    let hakedisler: [Hakedis]

    struct MonthForecast: Identifiable {
        let id = UUID()
        let label: String
        let date: Date
        let expected: Double
        let paid: Double
    }

    private var forecasts: [MonthForecast] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yy"
        fmt.locale = Locale(identifier: "tr_TR")

        var byMonth: [Date: (expected: Double, paid: Double)] = [:]

        for h in hakedisler {
            for p in h.payments {
                let comps = cal.dateComponents([.year, .month], from: p.paymentDate)
                if let d = cal.date(from: comps) {
                    byMonth[d, default: (0, 0)].paid += p.amount
                }
            }
            if h.remainingAmount > 0 {
                let ref = h.dueDate ?? h.periodEnd
                let comps = cal.dateComponents([.year, .month], from: ref)
                if let d = cal.date(from: comps) {
                    byMonth[d, default: (0, 0)].expected += h.remainingAmount
                }
            }
        }

        return byMonth
            .map { date, vals in
                MonthForecast(label: fmt.string(from: date), date: date,
                              expected: vals.expected, paid: vals.paid)
            }
            .sorted { $0.date < $1.date }
            .suffix(18)
            .map { $0 }
    }

    private var totalExpected: Double { forecasts.reduce(0) { $0 + $1.expected } }
    private var totalPaidForecast: Double { forecasts.reduce(0) { $0 + $1.paid } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aylık Nakit Akışı (son 18 ay + tahmin)")
                        .font(.caption).foregroundColor(.secondary)

                    Chart(forecasts) { item in
                        if item.paid > 0 {
                            BarMark(x: .value("Ay", item.label),
                                    y: .value("Ödenen", item.paid / 1000),
                                    width: .ratio(0.45))
                            .foregroundStyle(Color.hakedisSuccess.gradient)
                            .offset(x: -8)
                        }
                        if item.expected > 0 {
                            BarMark(x: .value("Ay", item.label),
                                    y: .value("Beklenen", item.expected / 1000),
                                    width: .ratio(0.45))
                            .foregroundStyle(Color.hakedisOrange.opacity(0.7).gradient)
                            .offset(x: 8)
                        }
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks { val in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = val.as(Double.self) {
                                    Text("\(Int(v))K ₺").font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis { AxisMarks { AxisValueLabel().font(.caption2) } }

                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.hakedisSuccess).frame(width: 8, height: 8)
                            Text("Ödenen").font(.caption2).foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Color.hakedisOrange.opacity(0.7)).frame(width: 8, height: 8)
                            Text("Beklenen").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Özet") {
                HStack {
                    Text("Toplam Ödenen").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    Text(totalPaidForecast.currencyFormatted).font(.subheadline.bold()).foregroundColor(.hakedisSuccess)
                }
                HStack {
                    Text("Bekleyen / Tahmin").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    Text(totalExpected.currencyFormatted).font(.subheadline.bold()).foregroundColor(.hakedisOrange)
                }
            }

            Section("Aylık Detay") {
                ForEach(forecasts) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label).font(.subheadline.bold())
                        HStack {
                            if item.paid > 0 {
                                Label(item.paid.currencyFormatted, systemImage: "checkmark.circle.fill")
                                    .font(.caption).foregroundColor(.hakedisSuccess)
                            }
                            if item.expected > 0 {
                                Label(item.expected.currencyFormatted, systemImage: "clock.fill")
                                    .font(.caption).foregroundColor(.hakedisOrange)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Nakit Akış Tahmini")
        .navigationBarTitleDisplayMode(.inline)
    }
}
