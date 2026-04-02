import SwiftUI
import Charts

struct SCurveView: View {
    let project: Project
    @State private var selectedInterval: ChartInterval = .monthly

    enum ChartInterval: String, CaseIterable {
        case weekly = "Haftalık"
        case monthly = "Aylık"
    }

    private var milestones: [Milestone] {
        project.milestones.sorted { $0.plannedDate < $1.plannedDate }
    }

    // FIX-14: Planlanan veri — tutar ağırlıklı kümülatif S eğrisi
    private var plannedData: [(date: Date, value: Double)] {
        guard !milestones.isEmpty else { return [] }
        let totalPlanned = milestones.reduce(0) { $0 + $1.plannedAmount }
        if totalPlanned > 0 {
            // Milestone'lara plannedAmount girilmişse ağırlıklı hesap
            var cumulative: Double = 0
            return milestones.sorted { $0.plannedDate < $1.plannedDate }.map { m in
                cumulative += m.plannedAmount
                return (date: m.plannedDate, value: min(cumulative / totalPlanned * 100, 100))
            }
        } else {
            // plannedAmount girilmemişse eşit dağılım (fallback)
            let total = milestones.count
            return milestones.enumerated().map { (i, m) in
                (date: m.plannedDate, value: Double(i + 1) / Double(total) * 100)
            }
        }
    }

    // FIX-15: Gerçekleşen veri — tutar bazlı (miktar × birim fiyat), birim karışımı olmaz
    private var actualData: [(date: Date, value: Double)] {
        let allItems = project.contracts.flatMap { $0.workItems }
        guard !allItems.isEmpty else { return [] }
        let totalContractAmount = allItems.reduce(0) { $0 + $1.totalAmount }
        guard totalContractAmount > 0 else { return [] }

        // Her iş kalemi için günlük tutar: entry.quantity × workItem.unitPrice
        var amountByDay: [Date: Double] = [:]
        for item in allItems {
            for entry in item.dailyEntries {
                let day = Calendar.current.startOfDay(for: entry.date)
                amountByDay[day, default: 0] += entry.quantity * item.unitPrice
            }
        }
        guard !amountByDay.isEmpty else { return [] }

        var result: [(date: Date, value: Double)] = []
        var cumulative: Double = 0
        for (date, amount) in amountByDay.sorted(by: { $0.key < $1.key }) {
            cumulative += amount
            result.append((date: date, value: min(cumulative / totalContractAmount * 100, 100)))
        }
        return result
    }

    // FIX-16: Seçilen aralığa göre verileri grupla
    private func groupByInterval(_ data: [(date: Date, value: Double)]) -> [(date: Date, value: Double)] {
        guard !data.isEmpty else { return data }
        var grouped: [Date: Double] = [:]
        for point in data {
            let key: Date
            switch selectedInterval {
            case .weekly:
                key = Calendar.current.dateInterval(of: .weekOfYear, for: point.date)?.start ?? point.date
            case .monthly:
                let comps = Calendar.current.dateComponents([.year, .month], from: point.date)
                key = Calendar.current.date(from: comps) ?? point.date
            }
            // Kümülatif seri: her periyotta son (en yüksek) değeri al
            grouped[key] = max(grouped[key] ?? 0, point.value)
        }
        return grouped.sorted(by: { $0.key < $1.key }).map { (date: $0.key, value: $0.value) }
    }

    private var groupedPlanned: [(date: Date, value: Double)] { groupByInterval(plannedData) }
    private var groupedActual:  [(date: Date, value: Double)] { groupByInterval(actualData) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if milestones.isEmpty && actualData.isEmpty {
                        EmptyStateView(icon: "chart.xyaxis.line",
                                       title: "Veri Yok",
                                       subtitle: "Kilometre taşı ekleyerek S eğrisi oluşturun.")
                    } else {
                        Picker("Aralık", selection: $selectedInterval) {
                            ForEach(ChartInterval.allCases, id: \.self) { i in
                                Text(i.rawValue).tag(i)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        Chart {
                            if !groupedPlanned.isEmpty {
                                ForEach(groupedPlanned, id: \.date) { point in
                                    LineMark(x: .value("Tarih", point.date),
                                             y: .value("Planlanan", point.value))
                                    .foregroundStyle(Color.hakedisInfo)
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                                }
                                .foregroundStyle(by: .value("Seri", "Planlanan"))
                            }

                            if !groupedActual.isEmpty {
                                ForEach(groupedActual, id: \.date) { point in
                                    LineMark(x: .value("Tarih", point.date),
                                             y: .value("Gerçekleşen", point.value))
                                    .foregroundStyle(Color.hakedisOrange)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                                .foregroundStyle(by: .value("Seri", "Gerçekleşen"))
                            }

                            RuleMark(x: .value("Bugün", Date()))
                                .foregroundStyle(Color.hakedisDanger)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .annotation(position: .top) {
                                    Text("Bugün").font(.caption2).foregroundColor(.hakedisDanger)
                                }
                        }
                        .chartYAxis {
                            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                                AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                                AxisGridLine()
                            }
                        }
                        .frame(height: 280)
                        .padding()
                        .background(Color.hakedisCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)

                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Rectangle().fill(Color.hakedisInfo).frame(width: 20, height: 2)
                                Text("Planlanan").font(.caption).foregroundColor(.secondary)
                            }
                            HStack(spacing: 6) {
                                Rectangle().fill(Color.hakedisOrange).frame(width: 20, height: 2)
                                Text("Gerçekleşen").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        // Interval bilgi notu
                        Text(selectedInterval == .weekly ? "Haftalık gruplandırma" : "Aylık gruplandırma")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("S Eğrisi")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
