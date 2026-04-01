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

    private var plannedData: [(date: Date, value: Double)] {
        guard !milestones.isEmpty else { return [] }
        let total = milestones.count
        return milestones.enumerated().map { (i, m) in
            (date: m.plannedDate, value: Double(i + 1) / Double(total) * 100)
        }
    }

    private var actualData: [(date: Date, value: Double)] {
        let allItems = project.contracts.flatMap { $0.workItems }
        guard !allItems.isEmpty else { return [] }
        let totalContracted = allItems.reduce(0) { $0 + $1.contractedQuantity }
        guard totalContracted > 0 else { return [] }

        let allEntries = allItems.flatMap { $0.dailyEntries }.sorted { $0.date < $1.date }
        guard !allEntries.isEmpty else { return [] }

        var result: [(date: Date, value: Double)] = []
        var cumulative: Double = 0
        let grouped = Dictionary(grouping: allEntries) { entry -> Date in
            Calendar.current.startOfDay(for: entry.date)
        }
        for (date, entries) in grouped.sorted(by: { $0.key < $1.key }) {
            cumulative += entries.reduce(0) { $0 + $1.quantity }
            result.append((date: date, value: min(cumulative / totalContracted * 100, 100)))
        }
        return result
    }

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
                            if !plannedData.isEmpty {
                                ForEach(plannedData, id: \.date) { point in
                                    LineMark(x: .value("Tarih", point.date),
                                             y: .value("Planlanan", point.value))
                                    .foregroundStyle(Color.hakedisInfo)
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                                }
                                .foregroundStyle(by: .value("Seri", "Planlanan"))
                            }

                            if !actualData.isEmpty {
                                ForEach(actualData, id: \.date) { point in
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
