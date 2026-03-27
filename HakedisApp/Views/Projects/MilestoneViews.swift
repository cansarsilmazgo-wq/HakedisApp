import SwiftUI
import SwiftData

// MARK: - Milestone List

struct MilestoneListView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var showingAdd = false
    @State private var filter: MilestoneFilter = .all

    enum MilestoneFilter: String, CaseIterable {
        case all       = "Tümü"
        case upcoming  = "Bekleyen"
        case overdue   = "Geciken"
        case completed = "Tamamlanan"
    }

    private var sorted: [Milestone] {
        project.milestones.sorted { $0.plannedDate < $1.plannedDate }
    }
    private var filtered: [Milestone] {
        switch filter {
        case .all:       return sorted
        case .upcoming:  return sorted.filter { !$0.isCompleted && !$0.isOverdue }
        case .overdue:   return sorted.filter { $0.isOverdue }
        case .completed: return sorted.filter { $0.isCompleted }
        }
    }
    private var overdueCnt: Int    { sorted.filter { $0.isOverdue }.count }
    private var completedCnt: Int  { sorted.filter { $0.isCompleted }.count }
    private var completionPct: Int {
        guard !sorted.isEmpty else { return 0 }
        return Int(Double(completedCnt) / Double(sorted.count) * 100)
    }

    var body: some View {
        List {
            // Özet
            Section {
                HStack(spacing: 0) {
                    MilestoneStat(value: "\(sorted.count)", label: "Toplam", color: .hakedisOrange)
                    Divider().frame(height: 36)
                    MilestoneStat(value: "\(completedCnt)", label: "Tamamlanan", color: .hakedisSuccess)
                    Divider().frame(height: 36)
                    MilestoneStat(
                        value: "\(overdueCnt)",
                        label: "Geciken",
                        color: overdueCnt > 0 ? .hakedisDanger : .secondary
                    )
                    Divider().frame(height: 36)
                    MilestoneStat(
                        value: sorted.isEmpty ? "—" : "\(completionPct)%",
                        label: "Tamamlanma",
                        color: .hakedisOrange
                    )
                }
                .padding(.vertical, 4)
                if !sorted.isEmpty {
                    ProgressBarView(
                        progress: Double(completionPct),
                        color: completionPct == 100 ? .hakedisSuccess : .hakedisOrange
                    )
                }
            }

            // Filtre
            Section {
                Picker("Filtre", selection: $filter) {
                    ForEach(MilestoneFilter.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            // Liste
            Section {
                if filtered.isEmpty {
                    Text(filter == .all ? "Henüz kilometre taşı eklenmedi" : "Bu kategoride kayıt yok")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(filtered) { milestone in
                        NavigationLink(destination: MilestoneDetailView(milestone: milestone)) {
                            MilestoneRow(milestone: milestone)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { filtered[$0] }.forEach { modelContext.delete($0) }
                    }
                }
            }
        }
        .navigationTitle("İş Programı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddMilestoneView(project: project)
        }
    }
}

// MARK: - Milestone Row

struct MilestoneRow: View {
    let milestone: Milestone

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if milestone.isCritical {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.hakedisDanger)
                            .font(.caption2)
                    }
                    Text(milestone.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.caption2)
                    Text(milestone.plannedDate.shortFormatted)
                    if let actual = milestone.actualDate {
                        Text("→ \(actual.shortFormatted)")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                statusBadgeView
                if milestone.isOverdue {
                    Text("\(milestone.delayDays)g gecikme")
                        .font(.caption2.bold())
                        .foregroundColor(.hakedisDanger)
                } else if !milestone.isCompleted {
                    let days = milestone.daysUntilDue
                    Text("\(days)g kaldı")
                        .font(.caption2)
                        .foregroundColor(days <= 7 ? .hakedisWarning : .secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        if milestone.isCompleted {
            return milestone.completedOnTime ? "checkmark.circle.fill" : "checkmark.circle"
        }
        return milestone.isOverdue ? "exclamationmark.triangle.fill" : "circle"
    }
    private var iconColor: Color {
        if milestone.isCompleted {
            return milestone.completedOnTime ? .hakedisSuccess : .hakedisWarning
        }
        if milestone.isOverdue { return .hakedisDanger }
        return milestone.daysUntilDue <= 7 ? .hakedisWarning : .hakedisOrange
    }
    private var statusBadgeView: some View {
        let label: String
        let color: Color
        if milestone.isCompleted {
            label = milestone.completedOnTime ? "Zamanında" : "Geç"
            color = milestone.completedOnTime ? .hakedisSuccess : .hakedisWarning
        } else if milestone.isOverdue {
            label = "Gecikti"; color = .hakedisDanger
        } else {
            label = "Planlandı"; color = .hakedisOrange
        }
        return StatusBadge(text: label, color: color)
    }
}

// MARK: - Milestone Detail

struct MilestoneDetailView: View {
    let milestone: Milestone
    @State private var showingComplete = false
    @State private var completionDate = Date()

    var body: some View {
        List {
            Section {
                LabeledContent("Başlık", value: milestone.title)
                LabeledContent("Planlanan Tarih", value: milestone.plannedDate.shortFormatted)
                LabeledContent("Kritik Yol") {
                    HStack(spacing: 4) {
                        Image(systemName: milestone.isCritical ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundColor(milestone.isCritical ? .hakedisDanger : .secondary)
                        Text(milestone.isCritical ? "Evet" : "Hayır")
                            .foregroundColor(milestone.isCritical ? .hakedisDanger : .secondary)
                    }
                }
                if let actual = milestone.actualDate {
                    LabeledContent("Tamamlanma Tarihi", value: actual.shortFormatted)
                    if milestone.delayDays > 0 {
                        LabeledContent("Gecikme") {
                            Text("\(milestone.delayDays) gün")
                                .foregroundColor(.hakedisWarning)
                                .bold()
                        }
                    } else {
                        LabeledContent("Sonuç") {
                            Text("Zamanında tamamlandı")
                                .foregroundColor(.hakedisSuccess)
                                .bold()
                        }
                    }
                } else {
                    LabeledContent("Durum") {
                        if milestone.isOverdue {
                            Text("\(milestone.delayDays) gün gecikti")
                                .foregroundColor(.hakedisDanger)
                                .bold()
                        } else {
                            Text("\(milestone.daysUntilDue) gün kaldı")
                                .foregroundColor(milestone.daysUntilDue <= 7 ? .hakedisWarning : .primary)
                        }
                    }
                }
            }

            if !milestone.notes.isEmpty {
                Section("Notlar") {
                    Text(milestone.notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                if !milestone.isCompleted {
                    Button {
                        completionDate = Date()
                        showingComplete = true
                    } label: {
                        Label("Tamamlandı Olarak İşaretle", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.hakedisSuccess)
                    }
                } else {
                    Button(role: .destructive) {
                        milestone.actualDate = nil
                    } label: {
                        Label("Tamamlanmayı Geri Al", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }
        .navigationTitle("Kilometre Taşı")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingComplete) {
            MilestoneCompleteSheet(milestone: milestone, completionDate: $completionDate)
        }
    }
}

// MARK: - Complete Sheet

private struct MilestoneCompleteSheet: View {
    let milestone: Milestone
    @Binding var completionDate: Date
    @Environment(\.dismiss) private var dismiss

    private var delayDays: Int {
        let days = Calendar.current.dateComponents([.day], from: milestone.plannedDate, to: completionDate).day ?? 0
        return max(0, days)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tamamlanma Tarihi") {
                    DatePicker("Tarih", selection: $completionDate, displayedComponents: .date)
                }
                Section {
                    HStack(spacing: 8) {
                        if delayDays > 0 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.hakedisWarning)
                            Text("\(delayDays) gün gecikmeyle tamamlandı")
                                .foregroundColor(.hakedisWarning)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.hakedisSuccess)
                            Text("Zamanında tamamlandı")
                                .foregroundColor(.hakedisSuccess)
                        }
                    }
                }
            }
            .navigationTitle("Tamamlandı İşaretle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        milestone.actualDate = completionDate
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Add Milestone

struct AddMilestoneView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let project: Project

    @State private var title = ""
    @State private var plannedDate = Date()
    @State private var notes = ""
    @State private var isCritical = false

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kilometre Taşı") {
                    TextField("Başlık *", text: $title)
                    DatePicker("Planlanan Tarih", selection: $plannedDate, displayedComponents: .date)
                    Toggle("Kritik Yol", isOn: $isCritical)
                }
                Section("Notlar") {
                    TextField("Açıklama (isteğe bağlı)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Yeni Kilometre Taşı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(!isValid)
                        .bold()
                }
            }
        }
    }

    private func save() {
        let m = Milestone(
            title: title.trimmingCharacters(in: .whitespaces),
            plannedDate: plannedDate,
            notes: notes,
            isCritical: isCritical
        )
        project.milestones.append(m)
        modelContext.insert(m)
        dismiss()
    }
}

// MARK: - Dashboard Milestone Card

struct MilestoneAlertCard: View {
    let milestone: Milestone

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: milestone.isOverdue ? "flag.badge.ellipsis.fill" : "flag.fill")
                .foregroundColor(milestone.isOverdue ? .hakedisDanger : .hakedisWarning)
            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(milestone.project?.name ?? "—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if milestone.isOverdue {
                    Text("\(milestone.delayDays) gün gecikti")
                        .font(.caption.bold())
                        .foregroundColor(.hakedisDanger)
                } else {
                    Text("Vade: \(milestone.plannedDate.shortFormatted) (\(milestone.daysUntilDue) gün)")
                        .font(.caption)
                        .foregroundColor(.hakedisWarning)
                }
            }
            Spacer()
            if milestone.isCritical {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.hakedisDanger)
                    .font(.caption)
            }
        }
        .padding(14)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(milestone.isOverdue ? Color.hakedisDanger.opacity(0.3) : Color.hakedisWarning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Mini Stat

private struct MilestoneStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.caption.bold()).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
