import SwiftUI
import SwiftData
import PhotosUI

// MARK: - WeatherCondition Color extension
extension WeatherCondition {
    var uiColor: Color {
        switch self {
        case .sunny: return .hakedisWarning
        case .cloudy: return .secondary
        case .rainy: return .hakedisInfo
        case .snowy: return Color(UIColor.systemCyan)
        case .stormy: return .hakedisDanger
        }
    }
}

// MARK: - SiteDiaryListView
struct SiteDiaryListView: View {
    @Query(sort: \SiteDiary.date, order: .reverse) private var diaries: [SiteDiary]
    @Query private var projects: [Project]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedProjectID: UUID? = nil

    private var filtered: [SiteDiary] {
        diaries.filter { d in
            if let pid = selectedProjectID {
                return d.project?.id == pid
            }
            return true
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if filtered.isEmpty {
                EmptyStateView(
                    icon: "book.closed",
                    title: "Şantiye günlüğü boş",
                    subtitle: "İlk günlüğü eklemek için + butonuna basın",
                    actionTitle: "Günlük Ekle",
                    action: { showingAdd = true }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
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
                            .padding(.vertical, 8)
                        }
                        .background(Color.hakedisBackground)
                    }

                    List {
                        ForEach(filtered, id: \.id) { diary in
                            NavigationLink(destination: SiteDiaryDetailView(diary: diary)) {
                                SiteDiaryRow(diary: diary)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets {
                                modelContext.delete(filtered[i])
                            }
                            do { try modelContext.save() } catch { print("Silme hatası: \(error)") }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button {
                showingAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Yeni günlük ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) {
            AddSiteDiaryView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Yeni günlük ekle")
            }
        }
    }
}

// MARK: - SiteDiaryRow
private struct SiteDiaryRow: View {
    let diary: SiteDiary

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: diary.weatherCondition.icon)
                    .font(.title3)
                    .foregroundColor(diary.weatherCondition.uiColor)
                if let temp = diary.temperature {
                    Text("\(Int(temp))°C")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(diary.date.shortFormatted)
                    .font(.subheadline.bold())
                Text(String(diary.workDescription.prefix(60)) + (diary.workDescription.count > 60 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(diary.weatherCondition.rawValue)
                        .font(.caption2)
                        .foregroundColor(diary.weatherCondition.uiColor)
                    if !diary.photoData.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "photo")
                                .font(.caption2)
                            Text("\(diary.photoData.count)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(diary.date.shortFormatted), \(diary.weatherCondition.rawValue), \(diary.workDescription.prefix(50))")
    }
}

// MARK: - SiteDiaryDetailView
struct SiteDiaryDetailView: View {
    let diary: SiteDiary
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                // Hava kartı
                HStack(spacing: 16) {
                    Image(systemName: diary.weatherCondition.icon)
                        .font(.system(size: 44))
                        .foregroundColor(diary.weatherCondition.uiColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(diary.weatherCondition.rawValue)
                            .font(.title3.bold())
                        if let temp = diary.temperature {
                            Text("\(Int(temp))°C")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text(diary.date.shortFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(Spacing.card)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, Spacing.card)

                // Yapılan işler
                InfoSection(title: "Yapılan İşler", content: diary.workDescription, icon: "checkmark.circle")

                // Sorunlar
                if let problems = diary.problems, !problems.isEmpty {
                    InfoSection(title: "Sorunlar", content: problems, icon: "exclamationmark.triangle", color: .hakedisWarning)
                }

                // Ziyaretçiler
                if let visitors = diary.visitors, !visitors.isEmpty {
                    InfoSection(title: "Ziyaretçiler", content: visitors, icon: "person.2")
                }

                // Notlar
                if let notes = diary.notes, !notes.isEmpty {
                    InfoSection(title: "Notlar", content: notes, icon: "note.text")
                }

                // Fotoğraflar
                if !diary.photoData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Fotoğraflar (\(diary.photoData.count))")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                            ForEach(diary.photoData.indices, id: \.self) { i in
                                if let uiImage = UIImage(data: diary.photoData[i]) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .accessibilityLabel("Fotoğraf \(i + 1)")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card)
                }
            }
            .padding(.vertical, Spacing.card)
        }
        .navigationTitle(diary.date.shortFormatted)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Düzenle") { showingEdit = true }
                    .accessibilityLabel("Günlüğü düzenle")
                Button(role: .destructive) { showingDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Günlüğü sil")
            }
        }
        .confirmationDialog("Günlük silinsin mi?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                modelContext.delete(diary)
                do { try modelContext.save() } catch { print("Silme hatası: \(error)") }
                dismiss()
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddSiteDiaryView(editingDiary: diary)
        }
    }
}

private struct InfoSection: View {
    let title: String
    let content: String
    let icon: String
    var color: Color = .hakedisOrange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color).font(.subheadline)
                Text(title).font(.headline)
            }
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Spacing.card)
    }
}

// MARK: - AddSiteDiaryView
struct AddSiteDiaryView: View {
    var editingDiary: SiteDiary? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var date = Date()
    @State private var weatherCondition = WeatherCondition.sunny
    @State private var temperatureText = ""
    @State private var workDescription = ""
    @State private var problems = ""
    @State private var visitors = ""
    @State private var notes = ""
    @State private var selectedProject: Project? = nil
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataList: [Data] = []
    @State private var showValidationError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tarih & Hava") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                        .accessibilityLabel("Günlük tarihi")

                    Picker("Hava Durumu", selection: $weatherCondition) {
                        ForEach(WeatherCondition.allCases, id: \.self) { w in
                            Label(w.rawValue, systemImage: w.icon).tag(w)
                        }
                    }
                    .accessibilityLabel("Hava durumu seçin")

                    HStack {
                        Text("Sıcaklık (°C)")
                        Spacer()
                        TextField("Opsiyonel", text: $temperatureText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Sıcaklık Celsius")
                    }
                }

                Section("Proje") {
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                    .accessibilityLabel("Proje seçin")
                }

                Section("Yapılan İşler *") {
                    TextEditor(text: $workDescription)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Yapılan işleri girin")
                    if showValidationError && workDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Bu alan zorunludur")
                            .font(.caption)
                            .foregroundColor(.hakedisDanger)
                    }
                }

                Section("Sorunlar (Opsiyonel)") {
                    TextEditor(text: $problems)
                        .frame(minHeight: 60)
                        .accessibilityLabel("Sorunları girin")
                }

                Section("Ziyaretçiler (Opsiyonel)") {
                    TextField("Ziyaretçi adları", text: $visitors)
                        .accessibilityLabel("Ziyaretçi adları")
                }

                Section("Notlar (Opsiyonel)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .accessibilityLabel("Notlar")
                }

                Section("Fotoğraflar") {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                        Label("Fotoğraf Ekle", systemImage: "photo.badge.plus")
                            .accessibilityLabel("Fotoğraf ekle")
                    }
                    if !photoDataList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photoDataList.indices, id: \.self) { i in
                                    if let uiImg = UIImage(data: photoDataList[i]) {
                                        Image(uiImage: uiImg)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(editingDiary == nil ? "Yeni Günlük" : "Günlüğü Düzenle")
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
            .onChange(of: selectedPhotos) { loadPhotos() }
            .onAppear { if let d = editingDiary { populate(from: d) } }
        }
    }

    private func populate(from diary: SiteDiary) {
        date = diary.date
        weatherCondition = diary.weatherCondition
        if let t = diary.temperature { temperatureText = String(format: "%.0f", t) }
        workDescription = diary.workDescription
        problems = diary.problems ?? ""
        visitors = diary.visitors ?? ""
        notes = diary.notes ?? ""
        selectedProject = diary.project
        photoDataList = diary.photoData
    }

    private func loadPhotos() {
        Task {
            var loaded: [Data] = []
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(data)
                }
            }
            await MainActor.run { photoDataList = loaded }
        }
    }

    private func save() {
        let desc = workDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else { showValidationError = true; return }

        let diary = editingDiary ?? SiteDiary()
        diary.date = date
        diary.weatherCondition = weatherCondition
        diary.temperature = Double(temperatureText)
        diary.workDescription = desc
        diary.problems = problems.isEmpty ? nil : problems
        diary.visitors = visitors.isEmpty ? nil : visitors
        diary.notes = notes.isEmpty ? nil : notes
        diary.project = selectedProject
        diary.photoData = photoDataList

        if editingDiary == nil {
            modelContext.insert(diary)
        }
        do { try modelContext.save() } catch { print("Kayıt hatası: \(error)") }
        dismiss()
    }
}
