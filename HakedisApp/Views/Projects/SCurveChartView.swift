import SwiftUI
import SwiftData
import Charts

// MARK: - SCurveChartView

struct SCurveChartView: View {
    let activities: [ProjectActivity]

    private var dateRange: (start: Date, end: Date) {
        let starts = activities.compactMap { $0.actualStart ?? $0.plannedStart }
        let ends   = activities.compactMap { $0.actualEnd ?? $0.plannedEnd }
        let start = starts.min() ?? Date()
        let end   = ends.max()   ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        return (start, end)
    }

    private var dataPoints: [SCurveDataPoint] {
        let (start, end) = dateRange
        return SCurveDataCalculator.calculateWeeklyData(
            activities: activities,
            startDate: start,
            endDate: end
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                legend
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                if dataPoints.isEmpty {
                    EmptyStateView(
                        icon: "chart.xyaxis.line",
                        title: "Veri Yetersiz",
                        subtitle: "S-Eğrisi için aktivite tarihleri gereklidir"
                    )
                } else {
                    Chart {
                        ForEach(dataPoints) { point in
                            LineMark(
                                x: .value("Tarih", point.date),
                                y: .value("Planlanan %", point.plannedCumulative)
                            )
                            .foregroundStyle(Color.hakedisInfo)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
                            .symbol(.circle)
                        }

                        ForEach(dataPoints) { point in
                            LineMark(
                                x: .value("Tarih", point.date),
                                y: .value("Gerçekleşen %", point.actualCumulative)
                            )
                            .foregroundStyle(Color.hakedisSuccess)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .symbol(.circle)
                        }

                        RuleMark(x: .value("Bugün", Date()))
                            .foregroundStyle(Color.hakedisDanger.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                            .annotation(position: .top) {
                                Text("Bugün")
                                    .font(.caption2)
                                    .foregroundColor(.hakedisDanger)
                            }
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine()
                            AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                    .padding(Spacing.md)
                    .frame(minHeight: 300)
                }

                summaryTable
                    .padding(Spacing.md)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("S-Eğrisi")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var legend: some View {
        HStack(spacing: Spacing.md) {
            HStack(spacing: 6) {
                Rectangle().fill(Color.hakedisInfo).frame(width: 24, height: 2)
                Text("Planlanan").font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 6) {
                Rectangle().fill(Color.hakedisSuccess).frame(width: 24, height: 2)
                Text("Gerçekleşen").font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 6) {
                Rectangle().fill(Color.hakedisDanger.opacity(0.7)).frame(width: 2, height: 14)
                Text("Bugün").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var summaryTable: some View {
        let last = dataPoints.last
        let planned = last?.plannedCumulative ?? 0
        let actual  = last?.actualCumulative  ?? 0
        let variance = actual - planned

        return VStack(spacing: 8) {
            Divider()
            HStack {
                statBox(title: "Planlanan", value: String(format: "%.1f%%", planned), color: .hakedisInfo)
                statBox(title: "Gerçekleşen", value: String(format: "%.1f%%", actual), color: .hakedisSuccess)
                statBox(title: "Sapma", value: String(format: "%+.1f%%", variance), color: variance >= 0 ? .hakedisSuccess : .hakedisDanger)
            }
        }
    }

    @ViewBuilder
    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.subheadline.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.hakedisCard)
        .cornerRadius(8)
    }
}
