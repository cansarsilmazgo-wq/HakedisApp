import WidgetKit
import SwiftUI

// MARK: - Shared App Group ID
private let appGroupID = "group.com.hakedis.app"

// MARK: - Timeline Entry

struct HakedisWidgetEntry: TimelineEntry {
    let date: Date
    let pendingAmount: Double
    let activeProjects: Int
    let overdueCount: Int
    let lastHakedisName: String
    let lastHakedisStatus: String
    let lastHakedisAmount: Double
}

extension HakedisWidgetEntry {
    static var placeholder: HakedisWidgetEntry {
        HakedisWidgetEntry(
            date: .now,
            pendingAmount: 125_000,
            activeProjects: 3,
            overdueCount: 1,
            lastHakedisName: "Mart 2024 Hakedişi",
            lastHakedisStatus: "Onay Bekliyor",
            lastHakedisAmount: 85_000
        )
    }
    static var empty: HakedisWidgetEntry {
        HakedisWidgetEntry(date: .now, pendingAmount: 0, activeProjects: 0, overdueCount: 0,
                           lastHakedisName: "—", lastHakedisStatus: "—", lastHakedisAmount: 0)
    }
}

// MARK: - Provider

struct HakedisWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HakedisWidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (HakedisWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HakedisWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> HakedisWidgetEntry {
        let d = UserDefaults(suiteName: appGroupID)
        return HakedisWidgetEntry(
            date: .now,
            pendingAmount: d?.double(forKey: "widget_pending") ?? 0,
            activeProjects: d?.integer(forKey: "widget_activeProjects") ?? 0,
            overdueCount: d?.integer(forKey: "widget_overdueCount") ?? 0,
            lastHakedisName: d?.string(forKey: "widget_lastHakedis") ?? "—",
            lastHakedisStatus: d?.string(forKey: "widget_lastStatus") ?? "—",
            lastHakedisAmount: d?.double(forKey: "widget_lastAmount") ?? 0
        )
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: HakedisWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "building.2.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("HAKEDİŞ")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
            Spacer()
            Text(entry.pendingAmount > 0 ? formattedAmount(entry.pendingAmount) : "Tümü Ödendi")
                .font(.title3.bold())
                .foregroundStyle(entry.pendingAmount > 0 ? Color.red : Color.green)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("Bekleyen Ödeme")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "folder.fill").font(.caption2).foregroundStyle(.orange)
                Text("\(entry.activeProjects) aktif proje").font(.caption2).foregroundStyle(.secondary)
            }
            if entry.overdueCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundStyle(.red)
                    Text("\(entry.overdueCount) geciken").font(.caption2).foregroundStyle(.red)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: HakedisWidgetEntry

    var body: some View {
        HStack(spacing: 0) {
            // Sol panel — bekleyen ödeme
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "building.2.fill").font(.caption2).foregroundStyle(.orange)
                    Text("HAKEDİŞ APP").font(.caption2.bold()).foregroundStyle(.orange)
                }
                Spacer()
                Text("Bekleyen Ödeme")
                    .font(.caption2).foregroundStyle(.secondary)
                Text(entry.pendingAmount > 0 ? formattedAmount(entry.pendingAmount) : "Tümü Ödendi")
                    .font(.headline.bold())
                    .foregroundStyle(entry.pendingAmount > 0 ? Color.red : Color.green)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer()
                Label("\(entry.activeProjects) aktif proje", systemImage: "folder.fill")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.vertical, 12)

            // Sağ panel — son hakediş
            VStack(alignment: .leading, spacing: 6) {
                Text("Son Hakediş")
                    .font(.caption2.bold()).foregroundStyle(.secondary)
                Spacer()
                Text(entry.lastHakedisName)
                    .font(.caption.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(entry.lastHakedisStatus)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(statusColor(entry.lastHakedisStatus).opacity(0.15))
                    .foregroundStyle(statusColor(entry.lastHakedisStatus))
                    .clipShape(Capsule())
                Spacer()
                Text(formattedAmount(entry.lastHakedisAmount))
                    .font(.caption.bold()).foregroundStyle(.orange)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helpers

private func formattedAmount(_ v: Double) -> String {
    let n = NumberFormatter()
    n.numberStyle = .currency
    n.currencyCode = "TRY"
    n.currencySymbol = "₺"
    n.maximumFractionDigits = 0
    return n.string(from: NSNumber(value: v)) ?? "\(Int(v)) ₺"
}

private func statusColor(_ status: String) -> Color {
    switch status {
    case "Ödendi":        return .green
    case "Onaylandı":     return .blue
    case "Onay Bekliyor": return .orange
    case "Reddedildi":    return .red
    default:              return .secondary
    }
}

// MARK: - Entry View

struct HakedisWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HakedisWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallWidgetView(entry: entry)
        default:           MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct HakedisWidget: Widget {
    let kind = "HakedisWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HakedisWidgetProvider()) { entry in
            HakedisWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Hakediş")
        .description("Bekleyen ödemeleri ve aktif projeleri takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle Entry Point

@main
struct HakedisWidgetBundle: WidgetBundle {
    var body: some Widget { HakedisWidget() }
}
