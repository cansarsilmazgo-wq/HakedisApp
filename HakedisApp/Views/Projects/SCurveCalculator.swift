import Foundation

// MARK: - SCurveDataPoint

struct SCurveDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let plannedCumulative: Double
    let actualCumulative: Double
}

// MARK: - SCurveDataCalculator

struct SCurveDataCalculator {
    /// Haftalık S-Curve veri noktaları üretir.
    static func calculateWeeklyData(
        activities: [ProjectActivity],
        startDate: Date,
        endDate: Date
    ) -> [SCurveDataPoint] {
        guard !activities.isEmpty, startDate < endDate else { return [] }

        let calendar = Calendar.current
        let totalWeight = activities.reduce(0.0) { $0 + max(1, Double($1.plannedDurationDays)) }

        let daySpan = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let weekCount = max(1, Int(ceil(Double(daySpan) / 7.0)))

        var points: [SCurveDataPoint] = []
        var plannedCum: Double = 0
        var actualCum: Double = 0

        for week in 0..<weekCount {
            let weekStart = calendar.date(byAdding: .day, value: week * 7, to: startDate) ?? startDate
            let clampedEnd = min(
                calendar.date(byAdding: .day, value: (week + 1) * 7, to: startDate) ?? endDate,
                endDate
            )

            var plannedIncrement = 0.0
            var actualIncrement  = 0.0

            for act in activities {
                let weight = max(1.0, Double(act.plannedDurationDays))
                let overlap = overlapDays(start1: weekStart, end1: clampedEnd,
                                          start2: act.plannedStart, end2: act.plannedEnd)
                let actDuration = max(1.0, Double(act.plannedDurationDays))
                plannedIncrement += (Double(overlap) / actDuration) * weight

                if (act.actualStart ?? act.plannedStart) <= clampedEnd {
                    let prevEnd = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? startDate
                    let progressAt = progressByDate(act: act, date: clampedEnd)
                    let progressBefore = progressByDate(act: act, date: prevEnd)
                    actualIncrement += (progressAt - progressBefore) / 100.0 * weight
                }
            }

            plannedCum += plannedIncrement
            actualCum  += actualIncrement

            let pNorm = totalWeight > 0 ? min(100, plannedCum / totalWeight * 100) : 0
            let aNorm = totalWeight > 0 ? min(100, actualCum  / totalWeight * 100) : 0

            points.append(SCurveDataPoint(
                date: clampedEnd,
                plannedCumulative: pNorm,
                actualCumulative: aNorm
            ))
        }
        return points
    }

    private static func overlapDays(start1: Date, end1: Date,
                                     start2: Date, end2: Date) -> Int {
        let overlapStart = max(start1, start2)
        let overlapEnd   = min(end1, end2)
        guard overlapEnd > overlapStart else { return 0 }
        return Calendar.current.dateComponents([.day], from: overlapStart, to: overlapEnd).day ?? 0
    }

    private static func progressByDate(act: ProjectActivity, date: Date) -> Double {
        guard let actStart = act.actualStart ?? (act.plannedStart <= date ? act.plannedStart : nil)
        else { return 0 }
        if let actEnd = act.actualEnd, actEnd <= date { return 100 }
        if actStart > date { return 0 }
        let total = max(1.0, Double(act.plannedDurationDays))
        let elapsed = max(0, Double(Calendar.current.dateComponents([.day], from: actStart, to: date).day ?? 0))
        return min(act.progressPercent, elapsed / total * 100)
    }
}
