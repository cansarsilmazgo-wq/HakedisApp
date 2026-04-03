import SwiftUI
import SwiftData
import PhotosUI

// MARK: - MaterialTestResultListView
struct MaterialTestResultListView: View {
    @Query(sort: \MaterialTestResult.testDate, order: .reverse) private var results: [MaterialTestResult]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var conformingFilter: Bool? = nil

    private var filtered: [MaterialTestResult] {
        guard let f = conformingFilter else { return results }
        return results.filter { $0.isConforming == f }
    }

    private var nonConformingCount: Int { results.filter { !$0.isConforming }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if nonConformingCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.seal.fill").foregroundColor(.hakedisDanger)
                        Text("\(nonConformingCount) uygunsuz test sonucu")
                            .font(.caption.bold()).foregroundColor(.hakedisDanger)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.1))
                }
                HStack(spacing: 8) {
                    FilterChip(title: "Tümü", isSelected: conformingFilter == nil) { conformingFilter = nil }
                    FilterChip(title: "Uygun", isSelected: conformingFilter == true) {
                        conformingFilter = conformingFilter == true ? nil : true
                    }
                    FilterChip(title: "Uygunsuz", isSelected: conformingFilter == false) {
                        conformingFilter = conformingFilter == false ? nil : false
                    }
                }
                .padding(.horizontal, Spacing.card).padding(.vertical, 6)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "flask",
                        title: "Test sonucu yok",
                        subtitle: "Malzeme test sonuçlarını kaydedin",
                        actionTitle: "Test Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { r in
                            TestResultRow(result: r)
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            do { try modelContext.save() } catch { print("Silme: \(error)") }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Test sonucu ekle")
        }
        .sheet(isPresented: $showingAdd) { AddMaterialTestResultView() }
    }
}

// MARK: - TestResultRow
private struct TestResultRow: View {
    let result: MaterialTestResult
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.isConforming ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.title3)
                .foregroundColor(result.isConforming ? .hakedisSuccess : .hakedisDanger)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.testType.rawValue).font(.subheadline.bold())
                if let mat = result.material {
                    Text(mat.name).font(.caption).foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    Text(result.testDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
                    if let lab = result.testLaboratory {
                        Text(lab).font(.caption2).foregroundColor(.secondary)
                    }
                }
                if let target = result.targetValue, let actual = result.actualValue {
                    Text("Hedef: \(target) → Gerçek: \(actual)")
                        .font(.caption2)
                        .foregroundColor(result.isConforming ? .hakedisSuccess : .hakedisDanger)
                }
            }
            Spacer()
            StatusBadge(text: result.isConforming ? "Uygun" : "Uygunsuz",
                        color: result.isConforming ? .hakedisSuccess : .hakedisDanger)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.testType.rawValue), \(result.isConforming ? "uygun" : "uygunsuz")")
    }
}

// MARK: - AddMaterialTestResultView
struct AddMaterialTestResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Material.name) private var materials: [Material]
    @Query private var projects: [Project]

    @State private var testType: MaterialTestType = .concreteCube
    @State private var testDate = Date()
    @State private var sampleId = ""
    @State private var testLaboratory = ""
    @State private var result = ""
    @State private var isConforming = true
    @State private var targetValue = ""
    @State private var actualValue = ""
    @State private var selectedMaterial: Material? = nil
    @State private var selectedProject: Project? = nil
    @State private var notes = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Test Bilgileri") {
                    Picker("Test Türü", selection: $testType) {
                        ForEach(MaterialTestType.allCases, id: \.rawValue) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .accessibilityLabel("Test türü")
                    DatePicker("Test Tarihi", selection: $testDate, displayedComponents: .date)
                    TextField("Numune No", text: $sampleId)
                        .accessibilityLabel("Numune numarası")
                    TextField("Laboratuvar", text: $testLaboratory)
                        .accessibilityLabel("Test laboratuvarı")
                }
                Section("Sonuç") {
                    Toggle("Uygun", isOn: $isConforming)
                        .tint(.hakedisSuccess)
                        .accessibilityLabel("Test sonucu uygun mu")
                    TextField("Sonuç Açıklaması", text: $result)
                        .accessibilityLabel("Sonuç açıklaması")
                    TextField("Hedef Değer", text: $targetValue)
                        .accessibilityLabel("Hedef değer")
                    TextField("Gerçek Değer", text: $actualValue)
                        .accessibilityLabel("Gerçek değer")
                }
                Section("İlişkiler") {
                    Picker("Malzeme", selection: $selectedMaterial) {
                        Text("Seçilmedi").tag(Optional<Material>.none)
                        ForEach(materials, id: \.id) { m in Text(m.name).tag(Optional(m)) }
                    }
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                    }
                }
                Section("Fotoğraf & Notlar") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Rapor Fotoğrafı", systemImage: "camera")
                            .foregroundColor(.hakedisOrange)
                    }
                    .onChange(of: photoItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self) {
                                photoData = data
                            }
                        }
                    }
                    if photoData != nil {
                        Text("Fotoğraf seçildi").font(.caption).foregroundColor(.hakedisSuccess)
                    }
                    TextEditor(text: $notes).frame(minHeight: 60)
                        .accessibilityLabel("Notlar")
                }
            }
            .navigationTitle("Test Sonucu Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        let testResult = MaterialTestResult(
            testType: testType, testDate: testDate,
            result: result.isEmpty ? (isConforming ? "Uygun" : "Uygunsuz") : result,
            isConforming: isConforming
        )
        testResult.sampleId = sampleId.isEmpty ? nil : sampleId
        testResult.testLaboratory = testLaboratory.isEmpty ? nil : testLaboratory
        testResult.targetValue = targetValue.isEmpty ? nil : targetValue
        testResult.actualValue = actualValue.isEmpty ? nil : actualValue
        testResult.material = selectedMaterial
        testResult.project = selectedProject
        testResult.notes = notes.isEmpty ? nil : notes
        testResult.photoData = photoData
        modelContext.insert(testResult)
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
