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
        case .partlyCloudy: return .secondary
        case .heavyRain: return .hakedisInfo
        case .foggy: return .secondary
        case .windy: return .hakedisInfo
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

    // Günlük özet için @Query ile aynı tarihteki veriler
    @Query private var allAttendances: [Attendance]
    @Query private var allEntries: [DailyEntry]
    @Query private var allStockEntries: [StockEntry]
    @Query private var allEquipmentLogs: [EquipmentLog]

    private var diaryDateComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: diary.date)
    }

    private func isSameDay(_ d: Date) -> Bool {
        Calendar.current.dateComponents([.year, .month, .day], from: d) == diaryDateComponents
    }

    private var todayAttendances: [Attendance] {
        allAttendances.filter { isSameDay($0.date) && ($0.project?.id == diary.project?.id || diary.project == nil) }
    }
    private var presentWorkerCount: Int { todayAttendances.filter { $0.isPresent }.count }
    private var todayEntries: [DailyEntry] { allEntries.filter { isSameDay($0.date) } }
    private var todayStock: [StockEntry] { allStockEntries.filter { isSameDay($0.date) } }
    private var todayEquipment: [EquipmentLog] { allEquipmentLogs.filter { isSameDay($0.date) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                // Hava + Vardiya kartı
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Image(systemName: diary.weatherCondition.icon)
                            .font(.system(size: 36))
                            .foregroundColor(diary.weatherCondition.uiColor)
                        Image(systemName: diary.shiftType.icon)
                            .font(.caption).foregroundColor(.secondary)
                        Text(diary.shiftType.rawValue).font(.caption2).foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(diary.weatherCondition.rawValue).font(.title3.bold())
                        if let temp = diary.temperature { Text("\(Int(temp))°C").font(.subheadline).foregroundColor(.secondary) }
                        if let wind = diary.windSpeed { Text("Rüzgar: \(wind)").font(.caption).foregroundColor(.secondary) }
                        if let hum = diary.humidity { Text("Nem: %\(Int(hum))").font(.caption).foregroundColor(.secondary) }
                        Text(diary.date.shortFormatted).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(Spacing.card)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, Spacing.card)

                // Günlük Özet (otomatik)
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Günlük Özet")
                    VStack(spacing: 0) {
                        summaryRow(icon: "person.3", label: "Mevcut İşçi", value: "\(presentWorkerCount) kişi")
                        Divider()
                        summaryRow(icon: "gearshape.2", label: "Ekipman Kayıt", value: "\(todayEquipment.count) adet")
                        Divider()
                        summaryRow(icon: "shippingbox", label: "Malzeme Hareketi", value: "\(todayStock.count) giriş/çıkış")
                        Divider()
                        summaryRow(icon: "hammer", label: "İmalat Girişi", value: "\(todayEntries.count) kayıt")
                    }
                    .background(Color.hakedisCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, Spacing.card)
                }

                // Yapılan işler
                InfoSection(title: "Yapılan İşler", content: diary.workDescription, icon: "checkmark.circle")

                // Gecikme section
                if diary.hasDelay, let reason = diary.delayReason, let hours = diary.delayHours {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Gecikme Bilgisi")
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: reason.icon).foregroundColor(.hakedisDanger)
                                Text(reason.rawValue).font(.subheadline.bold())
                                Spacer()
                                Text(String(format: "%.1f saat", hours)).font(.subheadline.bold()).foregroundColor(.hakedisDanger)
                            }
                            .padding(Spacing.card)
                        }
                        .background(Color.hakedisDanger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, Spacing.card)
                    }
                }

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

                // İmza section
                if diary.signedByChief != nil || diary.signedByController != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("İmzalar")
                        VStack(spacing: 0) {
                            if let chief = diary.signedByChief {
                                HStack {
                                    Image(systemName: "signature").foregroundColor(.hakedisOrange)
                                    Text("Şantiye Şefi").font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text(chief).font(.subheadline.bold())
                                }
                                .padding(Spacing.card)
                                Divider()
                            }
                            if let ctrl = diary.signedByController {
                                HStack {
                                    Image(systemName: "signature").foregroundColor(.hakedisInfo)
                                    Text("Kontrol Müh.").font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text(ctrl).font(.subheadline.bold())
                                }
                                .padding(Spacing.card)
                            }
                        }
                        .background(Color.hakedisCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, Spacing.card)
                    }
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
                Button("Düzenle") { showingEdit = true }.accessibilityLabel("Günlüğü düzenle")
                Button(role: .destructive) { showingDeleteConfirm = true } label: { Image(systemName: "trash") }
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
        .sheet(isPresented: $showingEdit) { AddSiteDiaryView(editingDiary: diary) }
    }

    @ViewBuilder
    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.hakedisOrange).frame(width: 20)
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.caption.bold())
        }
        .padding(.horizontal, Spacing.card)
        .padding(.vertical, 6)
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
    @Query(sort: \SiteDiary.date, order: .reverse) private var allDiaries: [SiteDiary]

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
    @State private var shiftType = ShiftType.dayShift
    @State private var hasDelay = false
    @State private var delayReason: DelayReason = .rain
    @State private var delayHoursText = ""
    @State private var windSpeed = "Sakin"
    @State private var humidityValue: Double = 50
    @State private var signedByChief = ""
    @State private var signedByController = ""

    private let windOptions = ["Sakin", "Hafif", "Orta", "Kuvvetli"]

    var body: some View {
        NavigationStack {
            Form {
                temelSection
                vardiayaSection
                havedaSection
                gecikmeSection
                icerikSection
                fotografSection
                imzaSection
            }
            .navigationTitle(editingDiary == nil ? "Yeni Günlük" : "Günlüğü Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Dünü Kopyala") { copyYesterday() }.font(.caption)
                        .accessibilityLabel("Dünün verilerini kopyala")
                }
            }
            .onChange(of: selectedPhotos) { loadPhotos() }
            .onAppear { if let d = editingDiary { populate(from: d) } }
        }
    }

    @ViewBuilder private var temelSection: some View {
        Section("Tarih & Proje") {
            DatePicker("Tarih", selection: $date, displayedComponents: .date).accessibilityLabel("Günlük tarihi")
            Picker("Proje", selection: $selectedProject) {
                Text("Seçilmedi").tag(Optional<Project>.none)
                ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
            }.accessibilityLabel("Proje seçin")
        }
    }

    @ViewBuilder private var vardiayaSection: some View {
        Section("Vardiya") {
            Picker("Vardiya", selection: $shiftType) {
                ForEach(ShiftType.allCases, id: \.self) { s in Label(s.rawValue, systemImage: s.icon).tag(s) }
            }.pickerStyle(.segmented).accessibilityLabel("Vardiya türü")
        }
    }

    @ViewBuilder private var havedaSection: some View {
        Section("Hava Durumu") {
            Picker("Hava", selection: $weatherCondition) {
                ForEach(WeatherCondition.allCases, id: \.self) { w in Label(w.rawValue, systemImage: w.icon).tag(w) }
            }.accessibilityLabel("Hava durumu")
            HStack {
                Text("Sıcaklık (°C)"); Spacer()
                TextField("Opsiyonel", text: $temperatureText).keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing).frame(width: 80)
            }
            Picker("Rüzgar", selection: $windSpeed) {
                ForEach(windOptions, id: \.self) { Text($0).tag($0) }
            }.accessibilityLabel("Rüzgar durumu")
            HStack {
                Text("Nem (%\(Int(humidityValue)))")
                Slider(value: $humidityValue, in: 0...100, step: 5)
            }
        }
    }

    @ViewBuilder private var gecikmeSection: some View {
        Section("Gecikme") {
            Toggle("Gecikme Var", isOn: $hasDelay).accessibilityLabel("Gecikme toggle")
            if hasDelay {
                Picker("Gecikme Nedeni", selection: $delayReason) {
                    ForEach(DelayReason.allCases, id: \.self) { r in Label(r.rawValue, systemImage: r.icon).tag(r) }
                }.accessibilityLabel("Gecikme nedeni")
                HStack {
                    Text("Gecikme Süresi (saat)"); Spacer()
                    TextField("0.0", text: $delayHoursText).keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing).frame(width: 60)
                }
            }
        }
    }

    @ViewBuilder private var icerikSection: some View {
        Section("Yapılan İşler *") {
            TextEditor(text: $workDescription).frame(minHeight: 100).accessibilityLabel("Yapılan işleri girin")
            if showValidationError && workDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Bu alan zorunludur").font(.caption).foregroundColor(.hakedisDanger)
            }
        }
        Section("Sorunlar") { TextEditor(text: $problems).frame(minHeight: 60).accessibilityLabel("Sorunlar") }
        Section("Ziyaretçiler") { TextField("Ziyaretçi adları", text: $visitors).accessibilityLabel("Ziyaretçi adları") }
        Section("Notlar") { TextEditor(text: $notes).frame(minHeight: 60).accessibilityLabel("Notlar") }
    }

    @ViewBuilder private var fotografSection: some View {
        Section("Fotoğraflar") {
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                Label("Fotoğraf Ekle (\(photoDataList.count))", systemImage: "photo.badge.plus")
                    .accessibilityLabel("Fotoğraf ekle")
            }
            if !photoDataList.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photoDataList.indices, id: \.self) { i in
                            if let uiImg = UIImage(data: photoDataList[i]) {
                                Image(uiImage: uiImg).resizable().scaledToFill()
                                    .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var imzaSection: some View {
        Section("İmzalar") {
            TextField("Şantiye Şefi Adı", text: $signedByChief).accessibilityLabel("Şantiye şefi imza adı")
            TextField("Kontrol Mühendisi Adı", text: $signedByController).accessibilityLabel("Kontrol mühendisi")
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
        shiftType = diary.shiftType
        hasDelay = diary.hasDelay
        if let dr = diary.delayReason { delayReason = dr }
        if let dh = diary.delayHours { delayHoursText = String(format: "%.1f", dh) }
        windSpeed = diary.windSpeed ?? "Sakin"
        humidityValue = diary.humidity ?? 50
        signedByChief = diary.signedByChief ?? ""
        signedByController = diary.signedByController ?? ""
    }

    private func copyYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let yc = Calendar.current.dateComponents([.year, .month, .day], from: yesterday)
        guard let prev = allDiaries.first(where: {
            Calendar.current.dateComponents([.year, .month, .day], from: $0.date) == yc
        }) else { return }
        weatherCondition = prev.weatherCondition
        if let t = prev.temperature { temperatureText = String(format: "%.0f", t) }
        workDescription = prev.workDescription
        problems = prev.problems ?? ""
        visitors = prev.visitors ?? ""
        shiftType = prev.shiftType
        windSpeed = prev.windSpeed ?? "Sakin"
        humidityValue = prev.humidity ?? 50
        signedByChief = prev.signedByChief ?? ""
        signedByController = prev.signedByController ?? ""
    }

    private func loadPhotos() {
        Task {
            var loaded: [Data] = []
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(SiteDiaryPhotoStamper.stamp(data: data, date: date, projectName: selectedProject?.name))
                }
            }
            await MainActor.run { photoDataList = loaded }
        }
    }

    private func save() {
        let desc = workDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else { showValidationError = true; return }
        let diary = editingDiary ?? SiteDiary()
        diary.date = date; diary.weatherCondition = weatherCondition
        diary.temperature = Double(temperatureText)
        diary.workDescription = desc
        diary.problems = problems.isEmpty ? nil : problems
        diary.visitors = visitors.isEmpty ? nil : visitors
        diary.notes = notes.isEmpty ? nil : notes
        diary.project = selectedProject
        diary.photoData = photoDataList
        diary.shiftType = shiftType
        diary.windSpeed = windSpeed
        diary.humidity = humidityValue
        diary.delayReason = hasDelay ? delayReason : nil
        diary.delayHours = hasDelay ? Double(delayHoursText) : nil
        diary.signedByChief = signedByChief.isEmpty ? nil : signedByChief
        diary.signedByController = signedByController.isEmpty ? nil : signedByController
        if editingDiary == nil { modelContext.insert(diary) }
        do {
            try modelContext.save()
            extractAndSaveGPSPhotos(for: diary)
        } catch { print("Kayıt hatası: \(error)") }
        dismiss()
    }

    private func extractAndSaveGPSPhotos(for diary: SiteDiary) {
        for photoData in diary.photoData {
            guard let coord = PhotoLocationService.extractGPSLocation(from: photoData) else { continue }
            let thumb = PhotoLocationService.makeThumbnail(from: photoData)
            let geoPhoto = GeoTaggedPhoto(
                photoDate: diary.date,
                latitude: coord.latitude,
                longitude: coord.longitude,
                caption: diary.workDescription.prefix(80).description,
                sourceModule: "SiteDiary",
                sourceId: diary.id.uuidString,
                thumbnailData: thumb
            )
            geoPhoto.project = diary.project
            modelContext.insert(geoPhoto)
        }
        if !diary.photoData.isEmpty {
            do { try modelContext.save() } catch { }
        }
    }
}
