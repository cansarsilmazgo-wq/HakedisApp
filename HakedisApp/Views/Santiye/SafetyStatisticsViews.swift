import SwiftUI
import SwiftData

// MARK: - SafetyStatisticsView

struct SafetyStatisticsView: View {
    @Query private var incidents: [SafetyIncident]
    @Query private var attendanceRecords: [Attendance]
    @Query private var correctiveActions: [CorrectiveAction]
    @Query private var trainings: [SafetyTraining]
    @Query private var riskAssessments: [RiskAssessment]
    @Query private var emergencyPlans: [EmergencyPlan]
    @Query private var projects: [Project]

    @State private var selectedProjectID: UUID? = nil

    // MARK: - Filtered data

    private var filteredIncidents: [SafetyIncident] {
        incidents.filter { i in selectedProjectID == nil || i.project?.id == selectedProjectID }
    }

    private var filteredAttendance: [Attendance] {
        attendanceRecords.filter { a in selectedProjectID == nil || a.project?.id == selectedProjectID }
    }

    private var filteredActions: [CorrectiveAction] {
        correctiveActions.filter { a in selectedProjectID == nil || a.project?.id == selectedProjectID }
    }

    private var filteredTrainings: [SafetyTraining] {
        trainings.filter { t in selectedProjectID == nil || t.project?.id == selectedProjectID }
    }

    private var filteredRisks: [RiskAssessment] {
        riskAssessments.filter { r in selectedProjectID == nil || r.project?.id == selectedProjectID }
    }

    private var filteredPlans: [EmergencyPlan] {
        emergencyPlans.filter { p in selectedProjectID == nil || p.project?.id == selectedProjectID }
    }

    // MARK: - Computed stats

    private var totalManHours: Double {
        filteredAttendance.reduce(0) { $0 + $1.totalHours }
    }

    private var workAccidents: [SafetyIncident] {
        filteredIncidents.filter { $0.incidentType == .majorInjury || $0.incidentType == .minorInjury }
    }

    private var totalLostDays: Int {
        workAccidents.compactMap { $0.lostWorkDays }.reduce(0, +)
    }

    private var incidentFrequencyRate: Double {
        guard totalManHours > 0 else { return 0 }
        return Double(workAccidents.count) * 1_000_000 / totalManHours
    }

    private var severityRate: Double {
        guard totalManHours > 0 else { return 0 }
        return Double(totalLostDays) * 1_000_000 / totalManHours
    }

    private var nearMissCount: Int {
        filteredIncidents.filter { $0.incidentType == .nearMiss }.count
    }

    private var nearMissFrequency: Double {
        guard totalManHours > 0 else { return 0 }
        return Double(nearMissCount) * 1_000_000 / totalManHours
    }

    private var openCorrectiveActions: Int {
        filteredActions.filter { $0.status == .open || $0.status == .inProgress }.count
    }

    private var overdueCorrectiveActions: Int {
        filteredActions.filter { $0.isOverdue }.count
    }

    private var overdueDrills: Int {
        filteredPlans.filter { $0.isDrillOverdue }.count
    }

    private var highUncontrolledRisks: Int {
        filteredRisks.filter { ($0.riskLevel == .high || $0.riskLevel == .veryHigh) && !$0.isControlled }.count
    }

    private var avgTrainingHoursPerWorker: Double {
        let allAttendees = filteredTrainings.flatMap { $0.attendees }
        guard !allAttendees.isEmpty else { return 0 }
        let uniqueWorkers = Set(allAttendees).count
        let totalHours = filteredTrainings.reduce(0) { $0 + $1.durationHours }
        return uniqueWorkers > 0 ? totalHours / Double(uniqueWorkers) : 0
    }

    private var unreportedSGK: Int {
        filteredIncidents.filter { $0.incidentType == .majorInjury && !$0.reportedToSGK }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Project filter
                if !projects.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tümü", isSelected: selectedProjectID == nil) { selectedProjectID = nil }
                            ForEach(projects, id: \.id) { p in
                                FilterChip(title: p.name, isSelected: selectedProjectID == p.id) {
                                    selectedProjectID = selectedProjectID == p.id ? nil : p.id
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                    }
                }

                // Uyarılar
                if unreportedSGK > 0 || overdueCorrectiveActions > 0 || overdueDrills > 0 || highUncontrolledRisks > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Uyarılar").font(.subheadline.bold()).padding(.horizontal, Spacing.card)
                        VStack(spacing: 4) {
                            if unreportedSGK > 0 {
                                AlertRow(icon: "clock.badge.exclamationmark.fill", color: .hakedisDanger,
                                         text: "\(unreportedSGK) iş kazası SGK'ya bildirilmedi")
                            }
                            if overdueCorrectiveActions > 0 {
                                AlertRow(icon: "exclamationmark.circle.fill", color: .hakedisDanger,
                                         text: "\(overdueCorrectiveActions) gecikmiş düzeltici faaliyet")
                            }
                            if highUncontrolledRisks > 0 {
                                AlertRow(icon: "exclamationmark.triangle.fill", color: .hakedisWarning,
                                         text: "\(highUncontrolledRisks) kontrolsüz yüksek risk")
                            }
                            if overdueDrills > 0 {
                                AlertRow(icon: "flame.fill", color: .hakedisWarning,
                                         text: "\(overdueDrills) gecikmiş tatbikat")
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }

                // Kaza İstatistikleri
                ISGStatSection(title: "Kaza Göstergeleri") {
                    ISGStatRow(label: "Kayıp İş Günleri", value: "\(totalLostDays) gün", accent: totalLostDays > 0)
                    ISGStatRow(label: "İş Kazası Sıklık Hızı", value: String(format: "%.2f", incidentFrequencyRate), sublabel: "kaza × 10⁶ / adam-saat", accent: incidentFrequencyRate > 5)
                    ISGStatRow(label: "Ağırlık Hızı", value: String(format: "%.2f", severityRate), sublabel: "kayıp gün × 10⁶ / adam-saat", accent: severityRate > 100)
                    ISGStatRow(label: "Ramak Kala Sıklık Hızı", value: String(format: "%.2f", nearMissFrequency), sublabel: "× 10⁶ adam-saat")
                    ISGStatRow(label: "Toplam Adam-Saat", value: String(format: "%.0f", totalManHours))
                }

                // Olaylar
                ISGStatSection(title: "Olay Dağılımı") {
                    ForEach(IncidentType.allCases, id: \.self) { type in
                        let count = filteredIncidents.filter { $0.incidentType == type }.count
                        if count > 0 {
                            HStack {
                                Image(systemName: type.icon).foregroundColor(type.uiColor).frame(width: 24)
                                Text(type.rawValue).font(.body)
                                Spacer()
                                Text("\(count)").font(.body.bold())
                            }
                        }
                    }
                    if filteredIncidents.isEmpty {
                        Text("Olay kaydı yok").foregroundColor(.secondary).font(.caption)
                    }
                }

                // Düzeltici Faaliyetler
                ISGStatSection(title: "Düzeltici Faaliyetler") {
                    ISGStatRow(label: "Açık / Devam Eden", value: "\(openCorrectiveActions)", accent: openCorrectiveActions > 0)
                    ISGStatRow(label: "Gecikmiş", value: "\(overdueCorrectiveActions)", accent: overdueCorrectiveActions > 0)
                    ISGStatRow(label: "Doğrulandı", value: "\(filteredActions.filter { $0.status == .verified }.count)")
                    ISGStatRow(label: "Toplam", value: "\(filteredActions.count)")
                }

                // Risk Matrisi Dağılımı
                ISGStatSection(title: "Risk Dağılımı") {
                    ForEach(RiskLevel.allCases, id: \.self) { level in
                        let count = filteredRisks.filter { $0.riskLevel == level }.count
                        if count > 0 {
                            HStack {
                                RiskLevelBadge(level: level, score: 0)
                                    .opacity(0.8)
                                Spacer()
                                Text("\(count) risk").font(.body.bold())
                            }
                        }
                    }
                    if filteredRisks.isEmpty {
                        Text("Risk değerlendirmesi yok").foregroundColor(.secondary).font(.caption)
                    }
                }

                // Eğitim
                ISGStatSection(title: "Eğitim İstatistikleri") {
                    ISGStatRow(label: "Bu Yıl Eğitim Sayısı",
                               value: "\(filteredTrainings.filter { Calendar.current.component(.year, from: $0.trainingDate) == Calendar.current.component(.year, from: Date()) }.count)")
                    ISGStatRow(label: "Toplam Eğitim Saati",
                               value: String(format: "%.1f saat", filteredTrainings.reduce(0) { $0 + $1.durationHours }))
                    ISGStatRow(label: "Kişi Başı Ort. Eğitim Saati",
                               value: String(format: "%.1f saat", avgTrainingHoursPerWorker))
                }

                Spacer(minLength: 80)
            }
            .padding(.top, Spacing.card)
        }
        .background(Color.hakedisBackground)
    }
}

// MARK: - Helper Views

private struct AlertRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(text).font(.caption.bold()).foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal, Spacing.card).padding(.vertical, 6)
        .background(color.opacity(0.08))
    }
}

private struct ISGStatSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.subheadline.bold()).foregroundColor(.secondary)
                .padding(.horizontal, Spacing.card).padding(.bottom, 4)
            VStack(spacing: 0) {
                content
            }
            .background(Color.hakedisCard)
            .cornerRadius(12)
            .padding(.horizontal, Spacing.card)
        }
    }
}

private struct ISGStatRow: View {
    let label: String
    let value: String
    var sublabel: String? = nil
    var accent: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.body)
                if let sub = sublabel {
                    Text(sub).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(value).font(.body.bold()).foregroundColor(accent ? .hakedisDanger : .primary)
        }
        .padding(.horizontal, Spacing.card).padding(.vertical, 10)
        Divider().padding(.leading, Spacing.card)
    }
}
