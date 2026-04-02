import SwiftUI
import SwiftData

// MARK: - AttendanceListView
struct AttendanceListView: View {
    @Query(sort: \Attendance.date, order: .reverse) private var records: [Attendance]
    @Query private var projects: [Project]
    @Query private var contractors: [Contractor]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedProjectID: UUID? = nil
    @State private var selectedContractorID: UUID? = nil

    private var filtered: [Attendance] {
        records.filter { a in
            if let pid = selectedProjectID, a.project?.id != pid { return false }
            if let cid = selectedContractorID, a.contractor?.id != cid { return false }
            return true
        }
    }

    private var summary: (workers: Int, manDays: Double, sgkDays: Int, overtime: Double) {
        let workers = Set(filtered.map { $0.workerName }).count
        let manDays = filtered.filter { $0.isPresent }.reduce(0.0) { $0 + $1.totalHours / 8.0 }
        let sgkDays = filtered.filter { $0.isSGKDay }.count
        let overtime = filtered.reduce(0.0) { $0 + $1.overtimeHours }
        return (workers, manDays, sgkDays, overtime)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if filtered.isEmpty {
                EmptyStateView(
                    icon: "person.crop.rectangle.stack",
                    title: "Puantaj kaydı yok",
                    subtitle: "İşçi devam kaydı eklemek için + butonuna basın",
                    actionTitle: "Kayıt Ekle",
                    action: { showingAdd = true }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tüm Projeler", isSelected: selectedProjectID == nil) {
                                selectedProjectID = nil
                            }
                            ForEach(projects, id: \.id) { p in
                                FilterChip(title: p.name, isSelected: selectedProjectID == p.id) {
                                    selectedProjectID = selectedProjectID == p.id ? nil : p.id
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.card)
                        .padding(.vertical, 6)
                    }
                    .background(Color.hakedisBackground)

                    // Özet
                    let s = summary
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        StatCard(title: "İşçi Sayısı", value: "\(s.workers)", color: .hakedisOrange, icon: "person.2")
                        StatCard(title: "Adam-Gün", value: String(format: "%.1f", s.manDays), color: .hakedisInfo, icon: "calendar")
                        StatCard(title: "SGK Günü", value: "\(s.sgkDays)", color: .hakedisSuccess, icon: "shield.checkered")
                        StatCard(title: "Fazla Mesai", value: String(format: "%.0fh", s.overtime), color: .hakedisWarning, icon: "clock.badge.plus")
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, 8)

                    List {
                        ForEach(filtered, id: \.id) { attendance in
                            AttendanceRow(attendance: attendance)
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            do { try modelContext.save() } catch { print("Silme hatası: \(error)") }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Yeni puantaj kaydı ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) {
            AddAttendanceView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Yeni kayıt ekle")
            }
        }
    }
}

// MARK: - AttendanceRow
private struct AttendanceRow: View {
    let attendance: Attendance

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attendance.isPresent ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(attendance.isPresent ? .hakedisSuccess : .hakedisDanger)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(attendance.workerName)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    if let role = attendance.workerRole {
                        Text(role).font(.caption).foregroundColor(.secondary)
                    }
                    if let contractor = attendance.contractor {
                        Text("· \(contractor.name)").font(.caption).foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    Text(attendance.date.shortFormatted)
                        .font(.caption2).foregroundColor(.secondary)
                    if attendance.isPresent {
                        Text("\(String(format: "%.0f", attendance.normalHours))s normal")
                            .font(.caption2).foregroundColor(.secondary)
                        if attendance.overtimeHours > 0 {
                            Text("+ \(String(format: "%.0f", attendance.overtimeHours))s fazla")
                                .font(.caption2).foregroundColor(.hakedisWarning)
                        }
                    }
                }
            }

            Spacer()

            if attendance.isSGKDay {
                Image(systemName: "shield.checkered")
                    .font(.caption)
                    .foregroundColor(.hakedisSuccess)
                    .accessibilityLabel("SGK günü")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(attendance.workerName), \(attendance.isPresent ? "Mevcut" : "Gelmedi"), \(attendance.date.shortFormatted)")
    }
}

// MARK: - AddAttendanceView
struct AddAttendanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]
    @Query private var contractors: [Contractor]

    @State private var date = Date()
    @State private var selectedProject: Project? = nil
    @State private var selectedContractor: Contractor? = nil
    @State private var workerEntries: [WorkerEntry] = [WorkerEntry()]
    @State private var allPresent = true

    struct WorkerEntry: Identifiable {
        var id = UUID()
        var name = ""
        var role = ""
        var isPresent = true
        var normalHours = 8.0
        var overtimeHours = 0.0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Genel") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                        .accessibilityLabel("Tarih")

                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                    .accessibilityLabel("Proje")

                    Picker("Taşeron", selection: $selectedContractor) {
                        Text("Seçilmedi").tag(Optional<Contractor>.none)
                        ForEach(contractors, id: \.id) { c in
                            Text(c.name).tag(Optional(c))
                        }
                    }
                    .accessibilityLabel("Taşeron")
                }

                Section {
                    Toggle("Hepsi Geldi", isOn: $allPresent)
                        .onChange(of: allPresent) {
                            for i in workerEntries.indices {
                                workerEntries[i].isPresent = allPresent
                            }
                        }
                        .accessibilityLabel("Tüm işçileri mevcut olarak işaretle")
                } header: {
                    HStack {
                        Text("İşçiler")
                        Spacer()
                        Button {
                            workerEntries.append(WorkerEntry())
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.hakedisOrange)
                        }
                        .accessibilityLabel("İşçi ekle")
                    }
                }

                ForEach($workerEntries) { $entry in
                    Section {
                        TextField("İşçi adı", text: $entry.name)
                            .accessibilityLabel("İşçi adı")
                        TextField("Rol (opsiyonel)", text: $entry.role)
                            .accessibilityLabel("İşçi rolü")
                        Toggle("Geldi", isOn: $entry.isPresent)
                            .accessibilityLabel("İşçi mevcut")
                        if entry.isPresent {
                            Stepper("Normal: \(String(format: "%.0f", entry.normalHours))s",
                                    value: $entry.normalHours, in: 0...16, step: 0.5)
                                .accessibilityLabel("Normal çalışma saati")
                            Stepper("Fazla: \(String(format: "%.0f", entry.overtimeHours))s",
                                    value: $entry.overtimeHours, in: 0...8, step: 0.5)
                                .accessibilityLabel("Fazla mesai saati")
                        }
                    }
                }
            }
            .navigationTitle("Puantaj Girişi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .accessibilityLabel("İptal")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .accessibilityLabel("Kaydet")
                }
            }
        }
    }

    private func save() {
        let validEntries = workerEntries.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !validEntries.isEmpty else { dismiss(); return }

        for entry in validEntries {
            let attendance = Attendance(date: date, workerName: entry.name, workerRole: entry.role.isEmpty ? nil : entry.role)
            attendance.isPresent = entry.isPresent
            attendance.normalHours = entry.normalHours
            attendance.overtimeHours = entry.overtimeHours
            attendance.contractor = selectedContractor
            attendance.project = selectedProject
            modelContext.insert(attendance)
        }
        do { try modelContext.save() } catch { print("Kayıt hatası: \(error)") }
        dismiss()
    }
}
