import SwiftUI
import SwiftData

// MARK: - Activity List View

struct ActivityListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ProjectActivity.activityCode) private var activities: [ProjectActivity]
    @State private var showAdd = false
    @State private var showGantt = false
    @State private var showCriticalPath = false

    var body: some View {
        NavigationStack {
            List {
                if !activities.filter(\.isDelayed).isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.hakedisDanger)
                            Text("\(activities.filter(\.isDelayed).count) gecikmiş aktivite")
                                .foregroundColor(.hakedisDanger)
                                .font(.subheadline)
                        }
                    }
                }
                ForEach(activities) { activity in
                    NavigationLink(destination: ActivityDetailView(activity: activity)) {
                        ActivityRow(activity: activity)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("İş Programı")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showGantt = true } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    Button { showCriticalPath = true } label: {
                        Image(systemName: "arrow.triangle.branch")
                    }
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddActivityView() }
            .sheet(isPresented: $showGantt) { GanttChartView(activities: activities) }
            .sheet(isPresented: $showCriticalPath) { CriticalPathAnalysisView(activities: activities) }
            .overlay {
                if activities.isEmpty {
                    EmptyStateView(icon: "chart.bar.xaxis", title: "Aktivite Yok",
                                   subtitle: "İş programına aktivite ekleyin")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(activities[i]) }
        do { try context.save() } catch { print("ActivityListView delete error: \(error)") }
    }
}

private struct ActivityRow: View {
    let activity: ProjectActivity
    private var statusColor: Color {
        switch activity.status {
        case .notStarted: return .secondary
        case .inProgress: return .hakedisOrange
        case .completed: return .hakedisSuccess
        case .delayed: return .hakedisDanger
        case .onHold: return .hakedisWarning
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if activity.isCritical {
                    Image(systemName: "diamond.fill").foregroundColor(.hakedisDanger).font(.caption)
                }
                Text(activity.activityCode).font(.caption).foregroundColor(.secondary)
                Spacer()
                StatusBadge(text: activity.status.rawValue, color: statusColor)
            }
            Text(activity.activityName).font(.headline)
            HStack {
                Label(activity.plannedStart.formatted(date: .abbreviated, time: .omitted),
                      systemImage: "calendar")
                    .font(.caption)
                Text("→").font(.caption).foregroundColor(.secondary)
                Text(activity.plannedEnd.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                Spacer()
                Text("\(Int(activity.progressPercent))%")
                    .font(.caption).bold()
                    .foregroundColor(activity.isDelayed ? .hakedisDanger : .primary)
            }
            ProgressBarView(progress: activity.progressPercent,
                            color: activity.isDelayed ? .hakedisDanger : .hakedisOrange)
                .frame(height: 4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Gantt Chart View

struct GanttChartView: View {
    let activities: [ProjectActivity]
    @Environment(\.dismiss) private var dismiss

    private var projectStart: Date {
        activities.map(\.plannedStart).min() ?? Date()
    }
    private var projectEnd: Date {
        activities.map(\.plannedEnd).max() ?? Date().addingTimeInterval(30 * 86400)
    }
    private var totalDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: projectStart, to: projectEnd).day ?? 30)
    }

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    GanttHeaderRow(start: projectStart, totalDays: totalDays)
                        .frame(height: 32)
                    Divider()
                    ForEach(activities.sorted(by: { $0.activityCode < $1.activityCode })) { activity in
                        GanttBarRow(activity: activity, projectStart: projectStart, totalDays: totalDays)
                            .frame(height: 40)
                        Divider()
                    }
                }
                .padding(.horizontal, 8)
            }
            .navigationTitle("Gantt Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

private struct GanttHeaderRow: View {
    let start: Date
    let totalDays: Int
    private let dayWidth: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            Text("Aktivite").font(.caption2).bold()
                .frame(width: 120, alignment: .leading)
            Canvas { ctx, size in
                for i in stride(from: 0, through: totalDays, by: 7) {
                    let x = CGFloat(i) * dayWidth
                    let date = Calendar.current.date(byAdding: .day, value: i, to: start) ?? start
                    let label = date.formatted(.dateTime.month(.abbreviated).day())
                    ctx.draw(
                        Text(label).font(.system(size: 8)).foregroundColor(.secondary),
                        at: CGPoint(x: x, y: size.height / 2)
                    )
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    ctx.stroke(path, with: .color(.secondary.opacity(0.3)), lineWidth: 0.5)
                }
            }
            .frame(width: CGFloat(totalDays) * dayWidth)
        }
    }
}

private struct GanttBarRow: View {
    let activity: ProjectActivity
    let projectStart: Date
    let totalDays: Int
    private let dayWidth: CGFloat = 14
    private var barColor: Color {
        if activity.isCritical { return .hakedisDanger }
        switch activity.status {
        case .completed: return .hakedisSuccess
        case .delayed: return .hakedisWarning
        default: return .hakedisOrange
        }
    }
    private var startOffset: Int {
        max(0, Calendar.current.dateComponents([.day], from: projectStart, to: activity.plannedStart).day ?? 0)
    }
    private var duration: Int {
        max(1, activity.plannedDurationDays)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(activity.activityName).font(.caption2)
                .frame(width: 120, alignment: .leading)
                .lineLimit(2)
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.clear)
                    .frame(width: CGFloat(totalDays) * dayWidth)
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor.opacity(0.8))
                    .frame(width: CGFloat(duration) * dayWidth, height: 20)
                    .offset(x: CGFloat(startOffset) * dayWidth)
                if activity.progressPercent > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: CGFloat(duration) * dayWidth * activity.progressPercent / 100,
                               height: 20)
                        .offset(x: CGFloat(startOffset) * dayWidth)
                }
            }
        }
    }
}

// MARK: - Critical Path Analysis View

struct CriticalPathAnalysisView: View {
    let activities: [ProjectActivity]
    @Environment(\.dismiss) private var dismiss

    private var criticalActivities: [ProjectActivity] {
        activities.filter(\.isCritical).sorted(by: { $0.plannedStart < $1.plannedStart })
    }
    private var totalCriticalDays: Int {
        criticalActivities.reduce(0) { $0 + $1.plannedDurationDays }
    }
    private var delayedCritical: [ProjectActivity] {
        criticalActivities.filter(\.isDelayed)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Özet") {
                    LabeledContent("Kritik Aktivite", value: "\(criticalActivities.count)")
                    LabeledContent("Toplam Kritik Süre", value: "\(totalCriticalDays) gün")
                    if !delayedCritical.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.hakedisDanger)
                            Text("\(delayedCritical.count) kritik aktivite gecikmiş")
                                .foregroundColor(.hakedisDanger)
                        }
                    }
                }
                Section("Kritik Yol Aktiviteleri") {
                    ForEach(criticalActivities) { activity in
                        CriticalActivityRow(activity: activity)
                    }
                }
                Section("Tüm Aktiviteler (Gecikme Analizi)") {
                    ForEach(activities.sorted(by: { $0.plannedStart < $1.plannedStart })) { activity in
                        ScheduleVarianceRow(activity: activity)
                    }
                }
            }
            .navigationTitle("Kritik Yol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

private struct CriticalActivityRow: View {
    let activity: ProjectActivity
    var body: some View {
        HStack {
            Image(systemName: activity.isDelayed ? "exclamationmark.diamond.fill" : "diamond.fill")
                .foregroundColor(activity.isDelayed ? .hakedisDanger : .hakedisOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.activityName).font(.headline)
                Text("\(activity.plannedDurationDays) gün").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(Int(activity.progressPercent))%").font(.subheadline).bold()
        }
    }
}

private struct ScheduleVarianceRow: View {
    let activity: ProjectActivity
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.activityName).font(.subheadline)
                Text(activity.activityCode).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(activity.progressPercent))% / \(Int(activity.expectedProgress))%")
                    .font(.caption)
                let variance = activity.progressPercent - activity.expectedProgress
                Text(variance >= 0 ? "+\(Int(variance))%" : "\(Int(variance))%")
                    .font(.caption).bold()
                    .foregroundColor(variance >= 0 ? .hakedisSuccess : .hakedisDanger)
            }
        }
    }
}

// MARK: - Schedule Comparison View

struct ScheduleComparisonView: View {
    @Query(sort: \ProjectActivity.plannedStart) private var activities: [ProjectActivity]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Planlanan vs Gerçekleşen") {
                    ForEach(activities) { activity in
                        ComparisonActivityRow(activity: activity)
                    }
                }
            }
            .navigationTitle("Program Karşılaştırma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

private struct ComparisonActivityRow: View {
    let activity: ProjectActivity
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(activity.activityName).font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan").font(.caption2).foregroundColor(.secondary)
                    Text(activity.plannedStart.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                    Text("→ \(activity.plannedEnd.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                }
                Spacer()
                if let actualStart = activity.actualStart {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Gerçek").font(.caption2).foregroundColor(.secondary)
                        Text(actualStart.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundColor(.hakedisOrange)
                        if let actualEnd = activity.actualEnd {
                            Text("→ \(actualEnd.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundColor(.hakedisSuccess)
                        } else {
                            Text("Devam ediyor").font(.caption).foregroundColor(.hakedisWarning)
                        }
                    }
                } else {
                    Text("Başlamadı").font(.caption).foregroundColor(.secondary)
                }
            }
            if activity.scheduleVarianceDays != 0 {
                let v = activity.scheduleVarianceDays
                Label("\(v > 0 ? "+" : "")\(v) gün gecikme", systemImage: "clock.badge.exclamationmark")
                    .font(.caption).foregroundColor(v > 0 ? .hakedisDanger : .hakedisSuccess)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Activity Detail View

struct ActivityDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var activity: ProjectActivity

    var body: some View {
        List {
            Section("Bilgiler") {
                LabeledContent("Kod", value: activity.activityCode)
                LabeledContent("Sorumlu", value: activity.responsiblePerson.isEmpty ? "-" : activity.responsiblePerson)
                LabeledContent("WBS Seviyesi", value: "\(activity.wbsLevel)")
                Toggle("Kritik Yol", isOn: $activity.isCritical)
            }
            Section("Tarihler") {
                DatePicker("Planlanan Başlangıç", selection: $activity.plannedStart, displayedComponents: .date)
                DatePicker("Planlanan Bitiş", selection: $activity.plannedEnd, displayedComponents: .date)
                if activity.actualStart != nil {
                    DatePicker("Gerçek Başlangıç",
                               selection: Binding(get: { activity.actualStart ?? Date() },
                                                  set: { activity.actualStart = $0 }),
                               displayedComponents: .date)
                }
            }
            Section("İlerleme") {
                LabeledContent("Beklenen", value: "\(Int(activity.expectedProgress))%")
                HStack {
                    Text("Gerçek")
                    Spacer()
                    Text("\(Int(activity.progressPercent))%")
                }
                Slider(value: $activity.progressPercent, in: 0...100, step: 5)
                Picker("Durum", selection: $activity.statusRaw) {
                    ForEach(ActivityStatus.allCases, id: \.rawValue) {
                        Text($0.rawValue).tag($0.rawValue)
                    }
                }
            }
            if !activity.notes.isEmpty {
                Section("Notlar") { Text(activity.notes) }
            }
        }
        .navigationTitle(activity.activityName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: activity.progressPercent) { _, _ in
            do { try context.save() } catch { print("ActivityDetailView save error: \(error)") }
        }
        .onChange(of: activity.statusRaw) { _, _ in
            do { try context.save() } catch { print("ActivityDetailView save error: \(error)") }
        }
        .onChange(of: activity.isCritical) { _, _ in
            do { try context.save() } catch { print("ActivityDetailView save error: \(error)") }
        }
    }
}

// MARK: - Add Activity View

struct AddActivityView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProjectActivity.activityCode) private var existing: [ProjectActivity]

    @State private var activityCode = ""
    @State private var activityName = ""
    @State private var plannedStart = Date()
    @State private var plannedEnd = Date().addingTimeInterval(7 * 86400)
    @State private var isCritical = false
    @State private var responsiblePerson = ""
    @State private var wbsLevel = 1
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Aktivite Bilgileri") {
                    TextField("Aktivite Kodu (örn. A1.1)", text: $activityCode)
                    TextField("Aktivite Adı", text: $activityName)
                    TextField("Sorumlu Kişi", text: $responsiblePerson)
                    Stepper("WBS Seviyesi: \(wbsLevel)", value: $wbsLevel, in: 1...5)
                    Toggle("Kritik Yol", isOn: $isCritical)
                }
                Section("Tarihler") {
                    DatePicker("Başlangıç", selection: $plannedStart, displayedComponents: .date)
                    DatePicker("Bitiş", selection: $plannedEnd, in: plannedStart..., displayedComponents: .date)
                }
                Section("Notlar") {
                    TextField("Notlar", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Yeni Aktivite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }.disabled(activityName.isEmpty || activityCode.isEmpty)
                }
            }
        }
    }

    private func save() {
        let act = ProjectActivity(activityCode: activityCode, activityName: activityName,
                                   plannedStart: plannedStart, plannedEnd: plannedEnd)
        act.isCritical = isCritical
        act.responsiblePerson = responsiblePerson
        act.wbsLevel = wbsLevel
        act.notes = notes
        context.insert(act)
        do { try context.save() } catch { print("AddActivityView save error: \(error)") }
        dismiss()
    }
}
