import SwiftUI
import SwiftData

struct WeeklyReportView: View {
    let project: Project
    @State private var weekOffset = 0

    private var weekStart: Date {
        let cal = Calendar.current
        let today = Date()
        let start = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return cal.date(byAdding: .weekOfYear, value: weekOffset, to: start) ?? start
    }
    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }
    private var weekLabel: String {
        "\(weekStart.shortFormatted) – \(weekEnd.shortFormatted)"
    }

    private var weekEntries: [DailyEntry] {
        project.contracts
            .flatMap { $0.workItems }
            .flatMap { $0.dailyEntries }
            .filter { $0.date >= weekStart && $0.date <= weekEnd }
    }
    private var photoCount: Int {
        weekEntries.compactMap { $0.photoData.first }.count
    }

    private struct WorkItemSummary: Identifiable {
        let id: UUID
        let code: String
        let name: String
        let unit: String
        let totalQuantity: Double
    }
    private var workItemSummaries: [WorkItemSummary] {
        let grouped = Dictionary(grouping: weekEntries) { $0.workItem }
        return grouped.compactMap { (item, entries) -> WorkItemSummary? in
            guard let item = item else { return nil }
            return WorkItemSummary(id: item.id, code: item.code, name: item.name,
                                   unit: item.unit,
                                   totalQuantity: entries.reduce(0) { $0 + $1.quantity })
        }.sorted { $0.code < $1.code }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hafta seçici
                    HStack {
                        Button { weekOffset -= 1 } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.hakedisOrange)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            if weekOffset == 0 { Text("Bu Hafta").font(.caption.bold()).foregroundColor(.hakedisOrange) }
                            Text(weekLabel).font(.subheadline.bold())
                        }
                        Spacer()
                        Button { weekOffset += 1 } label: {
                            Image(systemName: "chevron.right")
                                .foregroundColor(weekOffset < 0 ? .hakedisOrange : .secondary)
                        }
                        .disabled(weekOffset >= 0)
                    }
                    .padding()
                    .background(Color.hakedisCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Özet kartlar
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Giriş Sayısı", value: "\(weekEntries.count)",
                                 color: .hakedisOrange, icon: "list.bullet")
                        StatCard(title: "İş Kalemi", value: "\(workItemSummaries.count)",
                                 color: .hakedisSuccess, icon: "square.grid.2x2")
                        StatCard(title: "Fotoğraf", value: "\(photoCount)",
                                 color: .hakedisInfo, icon: "photo")
                        StatCard(title: "Çalışılan Gün",
                                 value: "\(Set(weekEntries.map { Calendar.current.startOfDay(for: $0.date) }).count)",
                                 color: .hakedisWarning, icon: "calendar")
                    }

                    // İş kalemi özeti
                    if workItemSummaries.isEmpty {
                        EmptyStateView(icon: "tray", title: "Giriş Yok",
                                       subtitle: "Bu haftaya ait saha kaydı bulunmuyor.")
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader("İş Kalemi Özeti")
                            ForEach(workItemSummaries) { summary in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(summary.code).font(.caption.bold()).foregroundColor(.hakedisOrange)
                                        Text(summary.name).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(summary.totalQuantity.quantityFormatted) \(summary.unit)")
                                        .font(.subheadline.bold())
                                }
                                .padding(10)
                                .background(Color.hakedisCard)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Haftalık Rapor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    let text = generateReportText()
                    ShareLink(item: text) {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func generateReportText() -> String {
        var text = "HAFTALıK İLERLEME RAPORU\n"
        text += "Proje: \(project.name)\n"
        text += "Dönem: \(weekLabel)\n\n"
        text += "ÖZET\n"
        text += "Toplam Giriş: \(weekEntries.count)\n"
        text += "İş Kalemi Sayısı: \(workItemSummaries.count)\n"
        text += "Fotoğraf Sayısı: \(photoCount)\n\n"
        text += "İŞ KALEMİ DETAYI\n"
        for s in workItemSummaries {
            text += "[\(s.code)] \(s.name): \(s.totalQuantity.quantityFormatted) \(s.unit)\n"
        }
        return text
    }
}
