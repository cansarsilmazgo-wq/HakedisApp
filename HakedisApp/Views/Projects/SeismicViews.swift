import SwiftUI
import SwiftData

// MARK: - SeismicAssessmentListView

struct SeismicAssessmentListView: View {
    @Query(sort: \SeismicAssessment.assessmentDate, order: .reverse) private var assessments: [SeismicAssessment]
    @Query private var projects: [Project]
    @State private var showAddAssessment = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if assessments.isEmpty {
                    EmptyStateView(
                        icon: "waveform.path.ecg.rectangle.fill",
                        title: "Değerlendirme Yok",
                        subtitle: "Yapı deprem risk değerlendirmesi başlatın.",
                        actionTitle: "Değerlendirme Başlat"
                    ) { showAddAssessment = true }
                } else {
                    List {
                        ForEach(assessments, id: \.id) { assessment in
                            NavigationLink(destination: SeismicAssessmentDetailView(assessment: assessment)) {
                                assessmentRow(assessment)
                            }
                        }
                        .onDelete { indexSet in
                            for i in indexSet { modelContext.delete(assessments[i]) }
                            do { try modelContext.save() } catch { }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Deprem Risk")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddAssessment = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Yeni Değerlendirme")
                }
            }
            .sheet(isPresented: $showAddAssessment) {
                AddSeismicAssessmentView()
            }
        }
    }

    private func assessmentRow(_ assessment: SeismicAssessment) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(assessment.project?.name ?? "Proje Yok")
                    .font(.headline)
                Spacer()
                if let result = assessment.assessmentResult {
                    StatusBadge(text: result.rawValue, color: resultColor(result))
                } else {
                    StatusBadge(text: "Devam Ediyor", color: .hakedisWarning)
                }
            }
            HStack {
                Label(assessment.structuralSystem.rawValue, systemImage: "building.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(assessment.assessmentDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !assessment.checklistItems.isEmpty {
                ProgressBarView(progress: assessment.safetyScore / 100, color: resultColor(assessment.autoResult))
                Text(String(format: "Güvenlik Skoru: %.0f%%", assessment.safetyScore))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func resultColor(_ result: AssessmentResult) -> Color {
        switch result {
        case .safe:           return .hakedisSuccess
        case .limitedSafe:    return .hakedisWarning
        case .unsafeLowRisk:  return .hakedisOrange
        case .unsafeHighRisk: return .hakedisDanger
        case .collapse:       return .hakedisDanger
        }
    }
}

// MARK: - SeismicAssessmentDetailView

struct SeismicAssessmentDetailView: View {
    @Bindable var assessment: SeismicAssessment
    @State private var expandedCategory: SeismicCheckCategory?
    @Environment(\.modelContext) private var modelContext

    private func resultColor(_ result: AssessmentResult) -> Color {
        switch result {
        case .safe: return .hakedisSuccess
        case .limitedSafe: return .hakedisWarning
        case .unsafeLowRisk: return .hakedisOrange
        case .unsafeHighRisk, .collapse: return .hakedisDanger
        }
    }

    var body: some View {
        List {
            // Skor
            Section("Güvenlik Değerlendirmesi") {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Güvenlik Skoru")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.0f%%", assessment.safetyScore))
                            .font(.title2.bold())
                            .foregroundColor(resultColor(assessment.autoResult))
                    }
                    ProgressBarView(progress: assessment.safetyScore / 100,
                                    color: resultColor(assessment.autoResult))
                    HStack {
                        Image(systemName: assessment.autoResult.icon)
                            .foregroundColor(resultColor(assessment.autoResult))
                        Text(assessment.autoResult.rawValue)
                            .font(.subheadline.bold())
                            .foregroundColor(resultColor(assessment.autoResult))
                    }
                }
                Button("Sonucu Güncelle") {
                    assessment.updateResult()
                    do { try modelContext.save() } catch { }
                }
                .foregroundColor(.hakedisOrange)
                .accessibilityLabel("Değerlendirme sonucunu güncelle")
            }

            // Yapı Bilgileri
            Section("Yapı Bilgileri") {
                LabeledContent("Taşıyıcı Sistem", value: assessment.structuralSystem.rawValue)
                LabeledContent("Zemin Sınıfı", value: assessment.soilClass.rawValue)
                LabeledContent("Deprem Bölgesi", value: assessment.seismicZone.rawValue)
                LabeledContent("Kat Sayısı", value: "\(assessment.floorCount)")
                if let age = assessment.buildingAge {
                    LabeledContent("Yapı Yaşı", value: "\(age) yıl")
                }
                LabeledContent("Zemin Etüdü", value: assessment.hasGeotechnicalReport ? "Mevcut" : "Yok")
            }

            // Güçlendirme
            if assessment.retrofitRequired {
                Section("Güçlendirme Önerisi") {
                    if let type = assessment.retrofitType {
                        LabeledContent("Güçlendirme Tipi", value: type)
                    }
                    if let cost = assessment.estimatedRetrofitCost {
                        LabeledContent("Tahmini Maliyet", value: cost.currencyFormatted)
                    }
                }
            }

            // Kontrol listesi
            let categories = SeismicCheckCategory.allCases
            ForEach(categories, id: \.self) { category in
                let items = assessment.checklistItems.filter { $0.category == category }
                let passCount = items.filter { $0.result == .pass }.count
                let failCount = items.filter { $0.result == .fail }.count

                Section {
                    DisclosureGroup(isExpanded: Binding(
                        get: { expandedCategory == category },
                        set: { if $0 { expandedCategory = category } else { expandedCategory = nil } }
                    )) {
                        ForEach(items, id: \.id) { item in
                            checklistItemRow(item)
                        }
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.hakedisOrange)
                                .frame(width: 24)
                            Text(category.rawValue)
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(passCount)/\(items.count)")
                                .font(.caption)
                                .foregroundColor(failCount > 0 ? .hakedisDanger : .hakedisSuccess)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Deprem Risk Değerlendirmesi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func checklistItemRow(_ item: SeismicChecklistItem) -> some View {
        HStack(alignment: .top) {
            Image(systemName: resultIcon(item.result))
                .foregroundColor(resultIconColor(item.result))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.checkDescription)
                    .font(.caption)
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Menu {
                ForEach(SeismicCheckResult.allCases, id: \.self) { result in
                    Button(result.rawValue) {
                        item.result = result
                        do { try modelContext.save() } catch { }
                    }
                }
            } label: {
                Text(item.result.rawValue)
                    .font(.caption2)
                    .foregroundColor(resultIconColor(item.result))
            }
            .accessibilityLabel("Sonuç: \(item.checkDescription)")
        }
        .padding(.vertical, 2)
    }

    private func resultIcon(_ result: SeismicCheckResult) -> String {
        switch result {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .notApplicable: return "minus.circle"
        }
    }

    private func resultIconColor(_ result: SeismicCheckResult) -> Color {
        switch result {
        case .pass: return .hakedisSuccess
        case .fail: return .hakedisDanger
        case .notApplicable: return .secondary
        }
    }
}

// MARK: - AddSeismicAssessmentView

struct AddSeismicAssessmentView: View {
    @Query private var projects: [Project]
    @State private var selectedProject: Project?
    @State private var floorCount = "4"
    @State private var buildingAge = ""
    @State private var structuralSystem = StructuralSystem.reinforcedConcrete
    @State private var soilClass = SoilClass.zc
    @State private var seismicZone = SeismicZone.zone1
    @State private var hasGeotechnicalReport = false
    @State private var useTemplate = true
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Proje") {
                    Picker("Proje (opsiyonel)", selection: $selectedProject) {
                        Text("Seçiniz").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                }
                Section("Yapı Bilgileri") {
                    TextField("Kat Sayısı", text: $floorCount).keyboardType(.numberPad)
                    TextField("Yapı Yaşı (opsiyonel)", text: $buildingAge).keyboardType(.numberPad)
                    Picker("Taşıyıcı Sistem", selection: $structuralSystem) {
                        ForEach(StructuralSystem.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Zemin & Deprem") {
                    Picker("Zemin Sınıfı", selection: $soilClass) {
                        ForEach(SoilClass.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Deprem Bölgesi", selection: $seismicZone) {
                        ForEach(SeismicZone.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Zemin Etüdü Mevcut", isOn: $hasGeotechnicalReport)
                }
                Section("Kontrol Listesi") {
                    Toggle("TBDY 2018 şablonunu kullan", isOn: $useTemplate)
                    Text("Şablon ile \(SeismicChecklistTemplateProvider.allItems().count) kontrol maddesi otomatik oluşturulur.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Yeni Değerlendirme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Başlat") {
                        save()
                        dismiss()
                    }
                    .disabled(floorCount.isEmpty)
                }
            }
        }
    }

    private func save() {
        let floors = Int(floorCount) ?? 4
        let assessment = SeismicAssessment(floorCount: floors, structuralSystem: structuralSystem)
        assessment.buildingAge = Int(buildingAge)
        assessment.soilClass = soilClass
        assessment.seismicZone = seismicZone
        assessment.hasGeotechnicalReport = hasGeotechnicalReport
        assessment.project = selectedProject

        if useTemplate {
            let items = SeismicChecklistTemplateProvider.allItems()
            for item in items {
                item.assessment = assessment
                modelContext.insert(item)
            }
        }

        modelContext.insert(assessment)
        do { try modelContext.save() } catch { }
    }
}
