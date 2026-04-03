import SwiftUI
import SwiftData

// MARK: - QualityDashboardView

struct QualityDashboardView: View {
    @Query(sort: \QualityChecklist.date, order: .reverse) private var checklists: [QualityChecklist]
    @Query(sort: \NonConformanceReport.detectionDate, order: .reverse) private var allNCRs: [NonConformanceReport]
    @Query private var contracts: [Contract]
    @State private var selectedContractID: UUID? = nil

    private var filtered: [QualityChecklist] {
        checklists.filter { c in selectedContractID == nil || c.contract?.id == selectedContractID }
    }

    private var filteredNCRs: [NonConformanceReport] {
        allNCRs.filter { n in selectedContractID == nil || n.contract?.id == selectedContractID }
    }

    private var thisMonthChecklists: [QualityChecklist] {
        let cal = Calendar.current
        let now = Date()
        return filtered.filter {
            cal.component(.year, from: $0.date) == cal.component(.year, from: now) &&
            cal.component(.month, from: $0.date) == cal.component(.month, from: now)
        }
    }

    private var avgScore: Double {
        guard !filtered.isEmpty else { return 0 }
        return filtered.reduce(0) { $0 + $1.overallScore } / Double(filtered.count)
    }

    private var openNCRs: Int { filteredNCRs.filter { $0.status == .open || $0.status == .correctionProposed || $0.status == .correctionInProgress }.count }
    private var overdueNCRs: Int { filteredNCRs.filter { $0.isOverdue }.count }

    // İş kalemi bazlı ortalama skor
    private var workItemScores: [(name: String, score: Double)] {
        let groups = Dictionary(grouping: filtered) { $0.checklistType.rawValue }
        return groups.map { key, lists in
            let avg = lists.reduce(0) { $0 + $1.overallScore } / Double(lists.count)
            return (name: key, score: avg)
        }.sorted { $0.score < $1.score }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Proje filtresi
                if !contracts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tümü", isSelected: selectedContractID == nil) { selectedContractID = nil }
                            ForEach(contracts, id: \.id) { c in
                                FilterChip(title: c.title, isSelected: selectedContractID == c.id) {
                                    selectedContractID = selectedContractID == c.id ? nil : c.id
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                    }
                }

                // Ana istatistik kartları
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Bu Ay Checklist", value: "\(thisMonthChecklists.count)", color: .hakedisOrange, icon: "checklist")
                    StatCard(title: "Ort. Uygunluk", value: String(format: "%%%.0f", avgScore), color: avgScore >= 80 ? .hakedisSuccess : avgScore >= 60 ? .hakedisWarning : .hakedisDanger, icon: "chart.bar.fill")
                    StatCard(title: "Açık NCR", value: "\(openNCRs)", color: openNCRs > 0 ? .hakedisDanger : .hakedisSuccess, icon: "exclamationmark.circle.fill")
                    StatCard(title: "Gecikmiş NCR", value: "\(overdueNCRs)", color: overdueNCRs > 0 ? .hakedisDanger : .hakedisSuccess, icon: "clock.badge.exclamationmark.fill")
                }
                .padding(.horizontal, Spacing.card)

                // Uyarılar
                if overdueNCRs > 0 || openNCRs > 0 {
                    VStack(spacing: 4) {
                        if overdueNCRs > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.badge.exclamationmark.fill").foregroundColor(.hakedisDanger)
                                Text("\(overdueNCRs) NCR termin tarihi geçmiş").font(.caption.bold()).foregroundColor(.hakedisDanger)
                                Spacer()
                            }
                            .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                            .background(Color.hakedisDanger.opacity(0.08))
                        }
                    }
                }

                // Uygunluk skoru geçmişi (son checklists)
                if !filtered.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Son Kontroller").font(.subheadline.bold()).padding(.horizontal, Spacing.card)
                        ForEach(filtered.prefix(5), id: \.id) { cl in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cl.checklistType.rawValue).font(.caption.bold())
                                    HStack {
                                        Text(cl.checkedBy).font(.caption2).foregroundColor(.secondary)
                                        if let loc = cl.location { Text("· \(loc)").font(.caption2).foregroundColor(.secondary) }
                                        Spacer()
                                        Text(cl.date.shortFormatted).font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                QualityScoreBadge(score: cl.overallScore)
                            }
                            .padding(Spacing.cardSmall)
                            .background(Color.hakedisCard)
                            .cornerRadius(10)
                            .padding(.horizontal, Spacing.card)
                        }
                    }
                }

                // İş kalemi bazlı skor
                if !workItemScores.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tür Bazlı Kalite Skoru").font(.subheadline.bold()).padding(.horizontal, Spacing.card)
                        ForEach(workItemScores, id: \.name) { item in
                            HStack {
                                Text(item.name).font(.caption)
                                Spacer()
                                ProgressBarView(progress: item.score, color: item.score >= 80 ? .hakedisSuccess : item.score >= 60 ? .hakedisWarning : .hakedisDanger)
                                    .frame(width: 100)
                                Text(String(format: "%.0f%%", item.score))
                                    .font(.caption.bold())
                                    .foregroundColor(item.score >= 80 ? .hakedisSuccess : item.score >= 60 ? .hakedisWarning : .hakedisDanger)
                                    .frame(width: 36, alignment: .trailing)
                            }
                            .padding(.horizontal, Spacing.card)
                        }
                    }
                }

                // NCR durumu özeti
                if !filteredNCRs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NCR Durumu").font(.subheadline.bold()).padding(.horizontal, Spacing.card)
                        HStack(spacing: 0) {
                            ForEach(NCRStatus.allCases, id: \.self) { s in
                                let count = filteredNCRs.filter { $0.status == s }.count
                                if count > 0 {
                                    VStack(spacing: 4) {
                                        Text("\(count)").font(.title3.bold())
                                        Text(s.rawValue).font(.caption2).multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .background(Color.hakedisCard)
                        .cornerRadius(10)
                        .padding(.horizontal, Spacing.card)
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.top, Spacing.card)
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Kalite Dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - QualityScoreBadge

struct QualityScoreBadge: View {
    let score: Double

    var body: some View {
        Text(String(format: "%.0f%%", score))
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(scoreColor.opacity(0.15))
            .foregroundColor(scoreColor)
            .cornerRadius(8)
    }

    private var scoreColor: Color {
        score >= 80 ? .hakedisSuccess : score >= 60 ? .hakedisWarning : .hakedisDanger
    }
}
