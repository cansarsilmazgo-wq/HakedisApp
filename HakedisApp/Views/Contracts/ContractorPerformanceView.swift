import SwiftUI
import Charts

// MARK: - Contractor Performance View

struct ContractorPerformanceView: View {
    let contractor: Contractor

    // MARK: - Computed Metrics

    private var allHakedisler: [Hakedis] {
        contractor.contracts.flatMap { $0.hakedisler }
    }
    private var approvedOrPaid: [Hakedis] {
        allHakedisler.filter { $0.status == .approved || $0.status == .paid }
    }
    private var rejected: [Hakedis] {
        allHakedisler.filter { $0.status == .rejected }
    }
    private var paid: [Hakedis] {
        allHakedisler.filter { $0.status == .paid }
    }
    private var overdue: [Hakedis] {
        allHakedisler.filter { $0.isOverdue }
    }

    /// Onay oranı: onaylanan / (onaylanan + reddedilen)
    private var approvalRate: Double {
        let decided = approvedOrPaid.count + rejected.count
        guard decided > 0 else { return 100 }
        return Double(approvedOrPaid.count) / Double(decided) * 100
    }

    /// Zamanında ödenen hakedisler (vadesi geçmemişler)
    private var onTimePayments: Int {
        paid.filter { $0.daysOverdue == 0 }.count
    }
    private var onTimeRate: Double {
        guard !paid.isEmpty else { return 100 }
        return Double(onTimePayments) / Double(paid.count) * 100
    }

    /// Ortalama gecikme günü (sadece gecikenlerde)
    private var avgOverdueDays: Double {
        guard !overdue.isEmpty else { return 0 }
        return Double(overdue.reduce(0) { $0 + $1.daysOverdue }) / Double(overdue.count)
    }

    /// Ortalama bütçe kullanım yüzdesi
    private var avgBudgetUtilization: Double {
        let cs = contractor.contracts.filter { $0.totalContractAmount > 0 }
        guard !cs.isEmpty else { return 0 }
        return cs.reduce(0) { $0 + $1.budgetUtilization } / Double(cs.count)
    }

    /// Bütçe aşan sözleşme sayısı
    private var overBudgetCount: Int {
        contractor.contracts.filter { $0.isOverBudget }.count
    }

    /// Toplam bekleyen ödeme
    private var totalPending: Double {
        allHakedisler.filter { $0.status != .paid }.reduce(0) { $0 + $1.remainingAmount }
    }

    /// Genel performans puanı (0–100)
    private var score: Int {
        var s = 100.0

        // Onay oranı etkisi (max −25 puan)
        if approvalRate < 100 {
            s -= (100 - approvalRate) * 0.25
        }

        // Zamanında ödeme etkisi (max −35 puan)
        s -= (100 - onTimeRate) * 0.35

        // Bütçe aşımı etkisi (max −20 puan)
        let over = min(Double(overBudgetCount) * 10, 20)
        s -= over

        // Ortalama gecikme etkisi (max −20 puan)
        let delaySc = min(avgOverdueDays / 5, 20)
        s -= delaySc

        return max(0, min(100, Int(s)))
    }

    private var scoreColor: Color {
        score >= 80 ? .hakedisSuccess : score >= 50 ? .hakedisWarning : .hakedisDanger
    }

    private var scoreLabel: String {
        score >= 80 ? "Yüksek Performans"
            : score >= 60 ? "Orta Performans"
            : score >= 40 ? "Gelişmesi Gerekiyor"
            : "Düşük Performans"
    }

    // MARK: - Body

    var body: some View {
        List {
            // Genel puan
            Section {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 14)
                            .frame(width: 130, height: 130)
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100)
                            .stroke(
                                scoreColor,
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .frame(width: 130, height: 130)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.8), value: score)
                        VStack(spacing: 2) {
                            Text("\(score)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(scoreColor)
                            Text("/ 100").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    VStack(spacing: 4) {
                        Text(scoreLabel)
                            .font(.headline)
                            .foregroundColor(scoreColor)
                        Text(contractor.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // 4 mini metrik
                    HStack(spacing: 0) {
                        MiniMetric(
                            label: "Onay",
                            value: approvalRate.percentFormatted,
                            color: approvalRate >= 90 ? .hakedisSuccess : .hakedisWarning
                        )
                        Divider().frame(height: 36)
                        MiniMetric(
                            label: "Ödeme",
                            value: onTimeRate.percentFormatted,
                            color: onTimeRate >= 90 ? .hakedisSuccess : .hakedisWarning
                        )
                        Divider().frame(height: 36)
                        MiniMetric(
                            label: "Gecikme",
                            value: "\(Int(avgOverdueDays))g",
                            color: avgOverdueDays == 0 ? .hakedisSuccess : avgOverdueDays < 15 ? .hakedisWarning : .hakedisDanger
                        )
                        Divider().frame(height: 36)
                        MiniMetric(
                            label: "Bütçe",
                            value: avgBudgetUtilization.percentFormatted,
                            color: avgBudgetUtilization <= 100 ? .hakedisSuccess : .hakedisDanger
                        )
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Hakediş performansı
            Section("Hakediş Performansı") {
                PerformanceRow(
                    icon: "doc.text.fill",
                    label: "Toplam Hakediş",
                    value: "\(allHakedisler.count) adet",
                    color: .hakedisOrange
                )
                PerformanceRow(
                    icon: "checkmark.circle.fill",
                    label: "Onay Oranı",
                    value: approvalRate.percentFormatted,
                    color: approvalRate >= 90 ? .hakedisSuccess : .hakedisWarning,
                    progress: approvalRate
                )
                PerformanceRow(
                    icon: "xmark.circle.fill",
                    label: "Reddedilen Hakediş",
                    value: "\(rejected.count) adet",
                    color: rejected.isEmpty ? .hakedisSuccess : .hakedisDanger
                )
                if !allHakedisler.isEmpty {
                    let avg = allHakedisler.reduce(0) { $0 + $1.netAmount } / Double(allHakedisler.count)
                    PerformanceRow(
                        icon: "chart.bar.fill",
                        label: "Ortalama Hakediş",
                        value: avg.currencyFormatted,
                        color: .hakedisOrange
                    )
                }
            }

            // Ödeme performansı
            Section("Ödeme Performansı") {
                PerformanceRow(
                    icon: "clock.badge.checkmark.fill",
                    label: "Zamanında Ödeme Oranı",
                    value: onTimeRate.percentFormatted,
                    color: onTimeRate >= 90 ? .hakedisSuccess : .hakedisWarning,
                    progress: onTimeRate
                )
                PerformanceRow(
                    icon: "exclamationmark.triangle.fill",
                    label: "Geciken Ödeme",
                    value: "\(overdue.count) adet",
                    color: overdue.isEmpty ? .hakedisSuccess : .hakedisDanger
                )
                if avgOverdueDays > 0 {
                    PerformanceRow(
                        icon: "calendar.badge.exclamationmark",
                        label: "Ortalama Gecikme",
                        value: "\(Int(avgOverdueDays)) gün",
                        color: avgOverdueDays < 15 ? .hakedisWarning : .hakedisDanger
                    )
                }
                if totalPending > 0 {
                    PerformanceRow(
                        icon: "banknote.fill",
                        label: "Bekleyen Ödeme",
                        value: totalPending.currencyFormatted,
                        color: .hakedisDanger
                    )
                }
            }

            // Sözleşme performansı
            Section("Sözleşme & Bütçe") {
                PerformanceRow(
                    icon: "doc.plaintext.fill",
                    label: "Aktif Sözleşme",
                    value: "\(contractor.contracts.count) adet",
                    color: .hakedisOrange
                )
                PerformanceRow(
                    icon: "chart.pie.fill",
                    label: "Ort. Bütçe Kullanımı",
                    value: avgBudgetUtilization.percentFormatted,
                    color: avgBudgetUtilization <= 100 ? .hakedisSuccess
                         : avgBudgetUtilization <= 110 ? .hakedisWarning : .hakedisDanger,
                    progress: min(avgBudgetUtilization, 100)
                )
                if overBudgetCount > 0 {
                    PerformanceRow(
                        icon: "exclamationmark.triangle.fill",
                        label: "Bütçe Aşan Sözleşme",
                        value: "\(overBudgetCount) adet",
                        color: .hakedisDanger
                    )
                }
            }

            // Hakedis trend grafiği
            if allHakedisler.count > 1 {
                Section("Hakediş Trendi") {
                    HakedisBarChart(hakedisler: allHakedisler)
                        .padding(.vertical, 4)
                }
            }

            // Performans değerlendirme notu
            Section("Değerlendirme") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(evaluationNotes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: note.hasPrefix("✓") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(note.hasPrefix("✓") ? .hakedisSuccess : .hakedisWarning)
                                .font(.caption)
                                .padding(.top, 2)
                            Text(String(note.dropFirst(2)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if contractor.overallPerformanceScore > 0 {
                Section("Manuel Değerlendirme") {
                    LabeledContent("İş Kalitesi") {
                        Text("\(Int(contractor.qualityScore))/10").bold()
                            .foregroundColor(scoreColor(contractor.qualityScore))
                    }
                    LabeledContent("Zamanında Teslim") {
                        Text("\(Int(contractor.onTimeScore))/10").bold()
                            .foregroundColor(scoreColor(contractor.onTimeScore))
                    }
                    LabeledContent("İSG Uyumu") {
                        Text("\(Int(contractor.safetyScore))/10").bold()
                            .foregroundColor(scoreColor(contractor.safetyScore))
                    }
                    LabeledContent("Genel Puan") {
                        Text(String(format: "%.1f/10", contractor.overallPerformanceScore))
                            .font(.headline).bold()
                            .foregroundColor(scoreColor(contractor.overallPerformanceScore))
                    }
                    if !contractor.performanceNotes.isEmpty {
                        Text(contractor.performanceNotes)
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Performans Analizi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scoreColor(_ score: Double) -> Color {
        score >= 8 ? .hakedisSuccess : score >= 5 ? .hakedisWarning : .hakedisDanger
    }

    private var evaluationNotes: [String] {
        var notes: [String] = []
        if approvalRate >= 90 {
            notes.append("✓ Hakedişlerin büyük çoğunluğu onaylandı")
        } else if rejected.count > 0 {
            notes.append("⚠ \(rejected.count) hakediş reddedildi — gerekçeleri inceleyin")
        }
        if onTimeRate >= 90 {
            notes.append("✓ Ödemeler büyük ölçüde zamanında yapıldı")
        } else if overdue.count > 0 {
            notes.append("⚠ \(overdue.count) ödeme gecikiyor — vadesi geçmiş tutarları kontrol edin")
        }
        if overBudgetCount == 0 {
            notes.append("✓ Sözleşmelerin hiçbiri bütçe aşımı yaşamıyor")
        } else {
            notes.append("⚠ \(overBudgetCount) sözleşmede bütçe aşımı tespit edildi")
        }
        if allHakedisler.isEmpty {
            notes.append("⚠ Henüz hakediş kaydı yok — değerlendirme sınırlı")
        }
        return notes.isEmpty ? ["✓ Performans verisi yeterli değil"] : notes
    }
}

// MARK: - Mini Metric (header'daki 4'lü)

private struct MiniMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.caption.bold()).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Performance Row

private struct PerformanceRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(label).font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Text(value).font(.subheadline.bold()).foregroundColor(color)
            }
            if let p = progress {
                ProgressBarView(progress: min(p, 100), color: color)
            }
        }
        .padding(.vertical, progress != nil ? 4 : 2)
    }
}

// MARK: - Bar Chart (Hakediş trend)

private struct HakedisBarChart: View {
    let hakedisler: [Hakedis]

    struct BarData: Identifiable {
        let id: UUID
        let label: String
        let net: Double
        let paid: Double
    }

    private var data: [BarData] {
        hakedisler
            .sorted { $0.periodEnd < $1.periodEnd }
            .suffix(8)
            .map { h in
                BarData(
                    id: h.id,
                    label: shortLabel(h.periodName),
                    net: h.netAmount,
                    paid: h.totalPaid
                )
            }
    }

    private func shortLabel(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(3)) + " " + String(parts[1].suffix(2))
        }
        return String(name.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Son \(data.count) Hakediş")
                .font(.caption).foregroundColor(.secondary)

            Chart(data) { item in
                BarMark(
                    x: .value("Dönem", item.label),
                    y: .value("Net", item.net / 1000)
                )
                .foregroundStyle(Color.hakedisOrange.opacity(0.8).gradient)
                .cornerRadius(4)

                if item.paid > 0 {
                    LineMark(
                        x: .value("Dönem", item.label),
                        y: .value("Ödenen", item.paid / 1000)
                    )
                    .foregroundStyle(Color.hakedisSuccess)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    .symbolSize(25)
                }
            }
            .frame(height: 160)
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
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.hakedisOrange.opacity(0.8))
                        .frame(width: 10, height: 10)
                    Text("Net Hakediş").font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.hakedisSuccess).frame(width: 8, height: 8)
                    Text("Ödenen").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
    }
}
