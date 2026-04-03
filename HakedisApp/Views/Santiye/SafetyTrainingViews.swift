import SwiftUI
import SwiftData

// MARK: - SafetyTrainingListView

struct SafetyTrainingListView: View {
    @Query(sort: \SafetyTraining.trainingDate, order: .reverse) private var trainings: [SafetyTraining]
    @Query private var projects: [Project]
    @Query private var workers: [Worker]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedProjectID: UUID? = nil

    private var filtered: [SafetyTraining] {
        trainings.filter { t in
            selectedProjectID == nil || t.project?.id == selectedProjectID
        }
    }

    private var totalHoursThisYear: Double {
        let year = Calendar.current.component(.year, from: Date())
        return filtered.filter {
            Calendar.current.component(.year, from: $0.trainingDate) == year
        }.reduce(0) { $0 + $1.durationHours }
    }

    private var totalAttendeesThisYear: Int {
        let year = Calendar.current.component(.year, from: Date())
        return filtered.filter {
            Calendar.current.component(.year, from: $0.trainingDate) == year
        }.reduce(0) { $0 + $1.attendees.count }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Yıllık özet
                HStack(spacing: 0) {
                    StatCard(
                        title: "Bu Yıl Eğitim",
                        value: "\(filtered.filter { Calendar.current.component(.year, from: $0.trainingDate) == Calendar.current.component(.year, from: Date()) }.count)",
                        color: .hakedisOrange,
                        icon: "book.fill"
                    )
                    StatCard(
                        title: "Toplam Saat",
                        value: String(format: "%.1f", totalHoursThisYear),
                        color: .hakedisInfo,
                        icon: "clock.fill"
                    )
                    StatCard(
                        title: "Katılımcı",
                        value: "\(totalAttendeesThisYear)",
                        color: .hakedisSuccess,
                        icon: "person.2.fill"
                    )
                }
                .padding(Spacing.card)
                .background(Color.hakedisCard)

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
                    .background(Color.hakedisBackground)
                }

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "book.closed.fill",
                        title: "Eğitim kaydı yok",
                        subtitle: "İSG eğitimleri ve katılımcı takibi",
                        actionTitle: "Eğitim Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { training in
                            NavigationLink(destination: SafetyTrainingDetailView(training: training, allWorkers: workers)) {
                                SafetyTrainingRow(training: training)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(Color.hakedisOrange).clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4).accessibilityLabel("Eğitim ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) { SafetyTrainingForm(allWorkers: workers) }
    }
}

// MARK: - SafetyTrainingRow

private struct SafetyTrainingRow: View {
    let training: SafetyTraining

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(training.trainingType.rawValue).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                Text(String(format: "%.1f saat", training.durationHours))
                    .font(.caption.bold()).foregroundColor(.hakedisOrange)
            }
            HStack {
                Image(systemName: "person.fill").font(.caption2).foregroundColor(.secondary)
                Text(training.trainer).font(.caption).foregroundColor(.secondary)
                Spacer()
                Image(systemName: "person.2.fill").font(.caption2).foregroundColor(.secondary)
                Text("\(training.attendees.count) kişi").font(.caption2).foregroundColor(.secondary)
            }
            Text(training.trainingDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(training.trainingType.rawValue), \(training.attendees.count) katılımcı")
    }
}

// MARK: - SafetyTrainingDetailView

struct SafetyTrainingDetailView: View {
    let training: SafetyTraining
    let allWorkers: [Worker]

    var body: some View {
        List {
            Section("Eğitim Bilgileri") {
                LabeledContent("Tür", value: training.trainingType.rawValue)
                LabeledContent("Tarih", value: training.trainingDate.shortFormatted)
                LabeledContent("Süre", value: String(format: "%.1f saat", training.durationHours))
                LabeledContent("Eğitmen", value: training.trainer)
                if let title = training.trainerTitle { LabeledContent("Unvan", value: title) }
            }

            if !training.topicsCovered.isEmpty {
                Section("İşlenen Konular") { Text(training.topicsCovered) }
            }

            Section("Katılımcılar (\(training.attendees.count) kişi)") {
                if training.attendees.isEmpty {
                    Text("Katılımcı belirtilmemiş").foregroundColor(.secondary).font(.caption)
                } else {
                    ForEach(training.attendees, id: \.self) { name in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.hakedisSuccess).font(.caption)
                            Text(name).font(.body)
                        }
                    }
                }
            }

            if let notes = training.notes, !notes.isEmpty {
                Section("Notlar") { Text(notes) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Eğitim Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - SafetyTrainingForm

struct SafetyTrainingForm: View {
    let allWorkers: [Worker]
    var editing: SafetyTraining? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var trainingDate = Date()
    @State private var trainingType = SafetyTrainingType.basicOSH
    @State private var durationHours = 2.0
    @State private var trainer = ""
    @State private var trainerTitle = ""
    @State private var topicsCovered = ""
    @State private var notes = ""
    @State private var selectedWorkerNames: Set<String> = []
    @State private var selectedProject: Project? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Eğitim Bilgileri") {
                    DatePicker("Tarih", selection: $trainingDate, displayedComponents: .date).accessibilityLabel("Eğitim tarihi")
                    Picker("Eğitim Türü", selection: $trainingType) {
                        ForEach(SafetyTrainingType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .accessibilityLabel("Eğitim türü")
                    HStack {
                        Text("Süre (saat)")
                        Spacer()
                        Stepper(String(format: "%.1f", durationHours), value: $durationHours, in: 0.5...16, step: 0.5)
                            .accessibilityLabel("Eğitim süresi")
                    }
                    TextField("Eğitmen adı *", text: $trainer).accessibilityLabel("Eğitmen")
                    TextField("Eğitmen unvanı (opsiyonel)", text: $trainerTitle).accessibilityLabel("Eğitmen unvanı")
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                    }
                    .accessibilityLabel("Proje")
                }

                Section("İşlenen Konular") {
                    TextEditor(text: $topicsCovered).frame(minHeight: 60).accessibilityLabel("İşlenen konular")
                }

                if !allWorkers.isEmpty {
                    Section("Katılımcılar (\(selectedWorkerNames.count) seçili)") {
                        ForEach(allWorkers, id: \.id) { worker in
                            Button {
                                if selectedWorkerNames.contains(worker.fullName) {
                                    selectedWorkerNames.remove(worker.fullName)
                                } else {
                                    selectedWorkerNames.insert(worker.fullName)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedWorkerNames.contains(worker.fullName) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedWorkerNames.contains(worker.fullName) ? .hakedisSuccess : .secondary)
                                    Text(worker.fullName).foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .accessibilityLabel("\(worker.fullName), \(selectedWorkerNames.contains(worker.fullName) ? "seçili" : "seçili değil")")
                        }
                    }
                }

                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60).accessibilityLabel("Not")
                }
            }
            .navigationTitle(editing == nil ? "Yeni Eğitim" : "Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.accessibilityLabel("İptal") }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.accessibilityLabel("Kaydet") }
            }
            .onAppear {
                if let e = editing {
                    trainingDate = e.trainingDate; trainingType = e.trainingType
                    durationHours = e.durationHours; trainer = e.trainer
                    trainerTitle = e.trainerTitle ?? ""; topicsCovered = e.topicsCovered
                    notes = e.notes ?? ""; selectedProject = e.project
                    selectedWorkerNames = Set(e.attendees)
                }
            }
        }
    }

    private func save() {
        guard !trainer.isEmpty else { return }
        let t = editing ?? SafetyTraining(trainingType: trainingType, trainingDate: trainingDate, trainer: trainer, durationHours: durationHours)
        t.trainingDate = trainingDate; t.trainingType = trainingType
        t.durationHours = durationHours; t.trainer = trainer
        t.trainerTitle = trainerTitle.isEmpty ? nil : trainerTitle
        t.topicsCovered = topicsCovered
        t.notes = notes.isEmpty ? nil : notes
        t.attendees = Array(selectedWorkerNames)
        t.project = selectedProject
        if editing == nil { modelContext.insert(t) }
        try? modelContext.save()
        dismiss()
    }
}
