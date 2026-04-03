import SwiftUI
import SwiftData

// MARK: - RiskAssessmentListView

struct RiskAssessmentListView: View {
    @Query(sort: \RiskAssessment.assessmentDate, order: .reverse) private var assessments: [RiskAssessment]
    @Query private var projects: [Project]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedProjectID: UUID? = nil
    @State private var showOnlyUncontrolled = false

    private var filtered: [RiskAssessment] {
        assessments.filter { a in
            let projectMatch = selectedProjectID == nil || a.project?.id == selectedProjectID
            let controlMatch = !showOnlyUncontrolled || !a.isControlled
            return projectMatch && controlMatch
        }
    }

    private var highRiskCount: Int {
        filtered.filter { $0.riskLevel == .high || $0.riskLevel == .veryHigh }.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if highRiskCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.hakedisDanger)
                        Text("\(highRiskCount) yüksek/çok yüksek risk")
                            .font(.caption.bold())
                            .foregroundColor(.hakedisDanger)
                        Spacer()
                        Toggle("", isOn: $showOnlyUncontrolled)
                            .labelsHidden()
                            .tint(.hakedisDanger)
                        Text("Kontrolsüz").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.08))
                }

                if !projects.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tümü", isSelected: selectedProjectID == nil) {
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
                }

                // 5x5 matrix summary
                RiskMatrixSummaryView(assessments: filtered)
                    .padding(Spacing.card)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar.doc.horizontal",
                        title: "Risk değerlendirmesi yok",
                        subtitle: "Tehlike belirleme ve risk skoru hesaplama",
                        actionTitle: "Değerlendirme Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { assessment in
                            NavigationLink(destination: RiskAssessmentDetailView(assessment: assessment)) {
                                RiskAssessmentRow(assessment: assessment)
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
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Risk değerlendirmesi ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) { RiskAssessmentForm() }
    }
}

// MARK: - RiskMatrixSummaryView (5×5 grid)

private struct RiskMatrixSummaryView: View {
    let assessments: [RiskAssessment]

    private func count(likelihood: Int, severity: Int) -> Int {
        assessments.filter { $0.likelihood == likelihood && $0.severity == severity }.count
    }

    private func cellColor(_ score: Int) -> Color {
        switch RiskLevel.from(score: score) {
        case .veryLow:  return .hakedisSuccess.opacity(0.7)
        case .low:      return Color.green.opacity(0.5)
        case .medium:   return .hakedisWarning.opacity(0.7)
        case .high:     return .hakedisOrange.opacity(0.8)
        case .veryHigh: return .hakedisDanger.opacity(0.85)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("5×5 Risk Matrisi").font(.caption.bold()).foregroundColor(.secondary)
            HStack(spacing: 2) {
                // Y-axis label
                VStack(spacing: 2) {
                    Text("Olasılık ↑").font(.system(size: 8)).foregroundColor(.secondary).rotationEffect(.degrees(-90)).frame(width: 16, height: 60)
                    Spacer()
                }
                VStack(spacing: 2) {
                    ForEach((1...5).reversed(), id: \.self) { likelihood in
                        HStack(spacing: 2) {
                            Text("\(likelihood)").font(.system(size: 9)).foregroundColor(.secondary).frame(width: 12)
                            ForEach(1...5, id: \.self) { severity in
                                let score = likelihood * severity
                                let n = count(likelihood: likelihood, severity: severity)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(cellColor(score))
                                    if n > 0 {
                                        Text("\(n)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(height: 28)
                            }
                        }
                    }
                    HStack(spacing: 2) {
                        Text("").frame(width: 12)
                        ForEach(1...5, id: \.self) { s in
                            Text("\(s)").font(.system(size: 9)).foregroundColor(.secondary).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            Text("Şiddet →").font(.system(size: 8)).foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.hakedisCard)
        .cornerRadius(10)
    }
}

// MARK: - RiskAssessmentRow

private struct RiskAssessmentRow: View {
    let assessment: RiskAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(assessment.hazard)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                RiskLevelBadge(level: assessment.riskLevel, score: assessment.riskScore)
                if assessment.isControlled {
                    Image(systemName: "checkmark.shield.fill").foregroundColor(.hakedisSuccess).font(.caption)
                }
            }
            Text(assessment.activity).font(.caption).foregroundColor(.secondary).lineLimit(1)
            HStack {
                Text(assessment.location).font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text(assessment.assessmentDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assessment.hazard), risk skoru \(assessment.riskScore)")
    }
}

// MARK: - RiskLevelBadge

struct RiskLevelBadge: View {
    let level: RiskLevel
    let score: Int

    var body: some View {
        Text("\(score) · \(level.rawValue)")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(levelColor.opacity(0.15))
            .foregroundColor(levelColor)
            .cornerRadius(6)
    }

    private var levelColor: Color {
        switch level {
        case .veryLow:  return .hakedisSuccess
        case .low:      return .green
        case .medium:   return .hakedisWarning
        case .high:     return .hakedisOrange
        case .veryHigh: return .hakedisDanger
        }
    }
}

// MARK: - RiskAssessmentDetailView

struct RiskAssessmentDetailView: View {
    let assessment: RiskAssessment
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false

    var body: some View {
        List {
            Section("Risk Bilgileri") {
                LabeledContent("Konum", value: assessment.location)
                LabeledContent("Faaliyet", value: assessment.activity)
                LabeledContent("Tehlike", value: assessment.hazard)
                LabeledContent("Tarih", value: assessment.assessmentDate.shortFormatted)
            }

            Section("Risk Skoru") {
                HStack {
                    VStack(spacing: 4) {
                        Text("Olasılık").font(.caption).foregroundColor(.secondary)
                        Text("\(assessment.likelihood)").font(.title2.bold())
                    }
                    Spacer()
                    Text("×").font(.title2).foregroundColor(.secondary)
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Şiddet").font(.caption).foregroundColor(.secondary)
                        Text("\(assessment.severity)").font(.title2.bold())
                    }
                    Spacer()
                    Text("=").font(.title2).foregroundColor(.secondary)
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Skor").font(.caption).foregroundColor(.secondary)
                        RiskLevelBadge(level: assessment.riskLevel, score: assessment.riskScore)
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    Text("Kontrol Durumu")
                    Spacer()
                    StatusBadge(
                        text: assessment.isControlled ? "Kontrol Altında" : "Kontrolsüz",
                        color: assessment.isControlled ? .hakedisSuccess : .hakedisDanger
                    )
                }
            }

            if let controls = assessment.existingControls, !controls.isEmpty {
                Section("Mevcut Kontroller") { Text(controls) }
            }
            if let additional = assessment.additionalControls, !additional.isEmpty {
                Section("Ek Kontrol Önlemleri") { Text(additional) }
            }
            if let person = assessment.responsiblePerson {
                Section("Sorumlu Kişi") {
                    LabeledContent("Ad", value: person)
                    if let target = assessment.targetDate {
                        LabeledContent("Hedef Tarih", value: target.shortFormatted)
                    }
                }
            }
            if let reassess = assessment.reassessmentDate {
                Section("Yeniden Değerlendirme") {
                    LabeledContent("Tarih", value: reassess.shortFormatted)
                    if reassess < Date() && !assessment.isControlled {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.hakedisWarning)
                            Text("Yeniden değerlendirme tarihi geçti").font(.caption).foregroundColor(.hakedisWarning)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Risk Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button("Düzenle") { showingEdit = true }.accessibilityLabel("Düzenle")
                    if !assessment.isControlled {
                        Button("Kontrol Al") {
                            assessment.isControlled = true
                            try? modelContext.save()
                        }
                        .foregroundColor(.hakedisSuccess)
                        .accessibilityLabel("Kontrol altına al")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) { RiskAssessmentForm(editing: assessment) }
    }
}

// MARK: - RiskAssessmentForm

struct RiskAssessmentForm: View {
    var editing: RiskAssessment? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var location = ""
    @State private var activity = ""
    @State private var hazard = ""
    @State private var likelihood = 3
    @State private var severity = 3
    @State private var existingControls = ""
    @State private var additionalControls = ""
    @State private var responsiblePerson = ""
    @State private var targetDate: Date = Date().addingTimeInterval(7 * 86400)
    @State private var hasTargetDate = false
    @State private var isControlled = false
    @State private var reassessmentDate: Date = Date().addingTimeInterval(90 * 86400)
    @State private var hasReassessment = false
    @State private var selectedProject: Project? = nil

    private var score: Int { likelihood * severity }
    private var level: RiskLevel { RiskLevel.from(score: score) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Konum ve Faaliyet") {
                    TextField("Konum *", text: $location).accessibilityLabel("Konum")
                    TextField("Faaliyet *", text: $activity).accessibilityLabel("Faaliyet")
                    TextField("Tehlike/Tehlikeli Durum *", text: $hazard).accessibilityLabel("Tehlike")
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                    }
                    .accessibilityLabel("Proje")
                }

                Section("Risk Değerlendirme") {
                    HStack {
                        Text("Olasılık (1-5)")
                        Spacer()
                        Stepper("\(likelihood)", value: $likelihood, in: 1...5)
                            .accessibilityLabel("Olasılık değeri")
                    }
                    HStack {
                        Text("Şiddet (1-5)")
                        Spacer()
                        Stepper("\(severity)", value: $severity, in: 1...5)
                            .accessibilityLabel("Şiddet değeri")
                    }
                    HStack {
                        Text("Risk Skoru")
                        Spacer()
                        RiskLevelBadge(level: level, score: score)
                    }
                }

                Section("Kontrol Önlemleri") {
                    TextEditor(text: $existingControls).frame(minHeight: 60)
                        .overlay(alignment: .topLeading) {
                            if existingControls.isEmpty {
                                Text("Mevcut kontroller").foregroundColor(.secondary).font(.body).padding(.leading, 4).padding(.top, 8).allowsHitTesting(false)
                            }
                        }
                    TextEditor(text: $additionalControls).frame(minHeight: 60)
                        .overlay(alignment: .topLeading) {
                            if additionalControls.isEmpty {
                                Text("Ek önlemler").foregroundColor(.secondary).font(.body).padding(.leading, 4).padding(.top, 8).allowsHitTesting(false)
                            }
                        }
                    Toggle("Kontrol Altında", isOn: $isControlled).tint(.hakedisSuccess)
                        .accessibilityLabel("Kontrol altında mı")
                }

                Section("Sorumlu ve Tarih") {
                    TextField("Sorumlu kişi", text: $responsiblePerson).accessibilityLabel("Sorumlu kişi")
                    Toggle("Hedef tarih belirle", isOn: $hasTargetDate).tint(.hakedisOrange)
                    if hasTargetDate {
                        DatePicker("Hedef Tarih", selection: $targetDate, displayedComponents: .date)
                            .accessibilityLabel("Hedef tarih")
                    }
                    Toggle("Yeniden değerlendirme tarihi", isOn: $hasReassessment).tint(.hakedisOrange)
                    if hasReassessment {
                        DatePicker("Tarih", selection: $reassessmentDate, displayedComponents: .date)
                            .accessibilityLabel("Yeniden değerlendirme tarihi")
                    }
                }
            }
            .navigationTitle(editing == nil ? "Risk Değerlendirme" : "Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.accessibilityLabel("İptal") }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.accessibilityLabel("Kaydet") }
            }
            .onAppear { loadEditing() }
        }
    }

    private func loadEditing() {
        guard let e = editing else { return }
        location = e.location; activity = e.activity; hazard = e.hazard
        likelihood = e.likelihood; severity = e.severity
        existingControls = e.existingControls ?? ""; additionalControls = e.additionalControls ?? ""
        responsiblePerson = e.responsiblePerson ?? ""; isControlled = e.isControlled
        selectedProject = e.project
        if let td = e.targetDate { hasTargetDate = true; targetDate = td }
        if let rd = e.reassessmentDate { hasReassessment = true; reassessmentDate = rd }
    }

    private func save() {
        guard !location.isEmpty, !activity.isEmpty, !hazard.isEmpty else { return }
        let a = editing ?? RiskAssessment(location: location, activity: activity, hazard: hazard)
        a.location = location; a.activity = activity; a.hazard = hazard
        a.likelihood = likelihood; a.severity = severity
        a.existingControls = existingControls.isEmpty ? nil : existingControls
        a.additionalControls = additionalControls.isEmpty ? nil : additionalControls
        a.responsiblePerson = responsiblePerson.isEmpty ? nil : responsiblePerson
        a.targetDate = hasTargetDate ? targetDate : nil
        a.isControlled = isControlled
        a.reassessmentDate = hasReassessment ? reassessmentDate : nil
        a.project = selectedProject
        if editing == nil { modelContext.insert(a) }
        try? modelContext.save()
        dismiss()
    }
}
