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
        let workers = Set(filtered.map { $0.effectiveName }).count
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
                HStack {
                    NavigationLink(destination: AttendanceGridView()) {
                        Image(systemName: "tablecells")
                    }
                    .accessibilityLabel("Grid görünümü")
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Yeni kayıt ekle")
                }
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
                HStack {
                    if let prof = attendance.worker?.profession {
                        Image(systemName: prof.icon).font(.caption).foregroundColor(.hakedisOrange)
                    }
                    Text(attendance.effectiveName).font(.subheadline.bold())
                }
                HStack(spacing: 8) {
                    if let role = attendance.workerRole ?? attendance.worker?.profession.rawValue {
                        Text(role).font(.caption).foregroundColor(.secondary)
                    }
                    if let contractor = attendance.contractor {
                        Text("· \(contractor.name)").font(.caption).foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    Text(attendance.date.shortFormatted).font(.caption2).foregroundColor(.secondary)
                    if attendance.isPresent {
                        Text("\(String(format: "%.0f", attendance.normalHours))s normal")
                            .font(.caption2).foregroundColor(.secondary)
                        if attendance.overtimeHours > 0 {
                            Text("+ \(String(format: "%.0f", attendance.overtimeHours))s FM")
                                .font(.caption2).foregroundColor(.hakedisWarning)
                        }
                    }
                    // Onay durumu
                    let approval = attendance.approvalStatus
                    if approval != .draft {
                        Text(approval.rawValue).font(.caption2.bold())
                            .foregroundColor(approval == .approved ? .hakedisSuccess : .hakedisWarning)
                    }
                }
            }

            Spacer()

            if attendance.isSGKDay {
                Image(systemName: "shield.checkered").font(.caption)
                    .foregroundColor(.hakedisSuccess).accessibilityLabel("SGK günü")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(attendance.effectiveName), \(attendance.isPresent ? "Mevcut" : "Gelmedi"), \(attendance.date.shortFormatted)")
    }
}

// MARK: - AddAttendanceView
struct AddAttendanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]
    @Query private var contractors: [Contractor]
    @Query(sort: \Worker.fullName) private var workers: [Worker]

    @State private var date = Date()
    @State private var selectedProject: Project? = nil
    @State private var selectedContractor: Contractor? = nil
    @State private var workerEntries: [WorkerEntry] = [WorkerEntry()]
    @State private var allPresent = true
    // FAZ 17.2 — Giriş/çıkış saati
    @State private var checkInTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var checkOutTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var useCheckInOut = false

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
                    // FAZ 17.2 — Giriş/çıkış saati
                    Toggle("Giriş/Çıkış Saati Gir", isOn: $useCheckInOut)
                        .tint(.hakedisOrange)
                    if useCheckInOut {
                        DatePicker("Giriş Saati", selection: $checkInTime, displayedComponents: .hourAndMinute)
                            .accessibilityLabel("Giriş saati")
                        DatePicker("Çıkış Saati", selection: $checkOutTime, displayedComponents: .hourAndMinute)
                            .accessibilityLabel("Çıkış saati")
                    }

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
                    Button("Kaydet") { save() }.accessibilityLabel("Kaydet")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Herkesi Ekle") { addAllActiveWorkers() }
                        .font(.caption).accessibilityLabel("Tüm aktif işçileri ekle")
                }
            }
        }
    }

    private func addAllActiveWorkers() {
        let activeWorkers = workers.filter { $0.isActive }
        for w in activeWorkers {
            if !workerEntries.contains(where: { $0.name == w.fullName }) {
                var entry = WorkerEntry()
                entry.name = w.fullName
                entry.role = w.profession.rawValue
                workerEntries.append(entry)
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
            if useCheckInOut {
                attendance.checkInTime = checkInTime
                attendance.checkOutTime = checkOutTime
            }
            // Worker ilişkisi kur
            if let matchedWorker = workers.first(where: { $0.fullName == entry.name }) {
                attendance.worker = matchedWorker
            }
            modelContext.insert(attendance)
        }
        do { try modelContext.save() } catch { print("Kayıt hatası: \(error)") }
        dismiss()
    }
}

// MARK: - FAZ 17.2 — Haftalık/Aylık Puantaj Grid

struct AttendanceGridView: View {
    @Query(sort: \Attendance.date, order: .reverse) private var records: [Attendance]
    @State private var viewMode: GridMode = .weekly
    @State private var referenceDate = Date()

    enum GridMode: String, CaseIterable {
        case weekly = "Haftalık"
        case monthly = "Aylık"
    }

    private var workerNames: [String] {
        Array(Set(records.map { $0.effectiveName })).sorted()
    }

    private var daysInRange: [Date] {
        let cal = Calendar.current
        if viewMode == .weekly {
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: referenceDate)?.start else { return [] }
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        } else {
            guard let monthStart = cal.dateInterval(of: .month, for: referenceDate)?.start,
                  let range = cal.range(of: .day, in: .month, for: referenceDate) else { return [] }
            return (0..<range.count).compactMap { cal.date(byAdding: .day, value: $0, to: monthStart) }
        }
    }

    private func isPresent(worker: String, date: Date) -> Bool? {
        let cal = Calendar.current
        guard let record = records.first(where: {
            $0.effectiveName == worker && cal.isDate($0.date, inSameDayAs: date)
        }) else { return nil }
        return record.isPresent
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Görünüm", selection: $viewMode) {
                ForEach(GridMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.card)
            .padding(.vertical, 8)
            .background(Color.hakedisCard)

            HStack {
                Button {
                    referenceDate = Calendar.current.date(byAdding: viewMode == .weekly ? .weekOfYear : .month,
                                                         value: -1, to: referenceDate) ?? referenceDate
                } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(viewMode == .weekly
                     ? "Hafta \(Calendar.current.component(.weekOfYear, from: referenceDate))"
                     : referenceDate.formatted(.dateTime.year().month(.wide)))
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    referenceDate = Calendar.current.date(byAdding: viewMode == .weekly ? .weekOfYear : .month,
                                                         value: 1, to: referenceDate) ?? referenceDate
                } label: { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal, Spacing.card)
            .padding(.vertical, 6)

            if workerNames.isEmpty {
                EmptyStateView(icon: "person.crop.rectangle.stack",
                               title: "Veri Yok",
                               subtitle: "Bu dönemde puantaj kaydı bulunamadı")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack(spacing: 0) {
                            Text("İşçi").frame(width: 100, alignment: .leading)
                                .font(.caption.bold()).padding(4)
                                .background(Color.hakedisCard)
                            ForEach(daysInRange, id: \.self) { day in
                                Text(day.formatted(.dateTime.day()))
                                    .frame(width: 32, alignment: .center)
                                    .font(.caption.bold())
                                    .padding(4)
                                    .background(Calendar.current.isDateInToday(day) ? Color.hakedisOrange.opacity(0.2) : Color.hakedisCard)
                            }
                        }
                        Divider()
                        ForEach(workerNames, id: \.self) { name in
                            HStack(spacing: 0) {
                                Text(name).frame(width: 100, alignment: .leading)
                                    .font(.caption).lineLimit(1).padding(4)
                                    .background(Color.hakedisBackground)
                                ForEach(daysInRange, id: \.self) { day in
                                    let status = isPresent(worker: name, date: day)
                                    ZStack {
                                        Color.hakedisBackground
                                        if let present = status {
                                            Image(systemName: present ? "checkmark" : "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(present ? .hakedisSuccess : .hakedisDanger)
                                        } else {
                                            Text("-").font(.caption2).foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 32, height: 28)
                                }
                            }
                            Divider()
                        }
                    }
                }
            }
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Puantaj Grid")
        .navigationBarTitleDisplayMode(.inline)
    }
}
