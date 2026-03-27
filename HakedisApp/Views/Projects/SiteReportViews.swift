import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Site Report List

struct SiteReportListView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var showingAdd = false

    private var sorted: [SiteReport] {
        project.siteReports.sorted { $0.date > $1.date }
    }

    /// Raporları aya göre grupla
    private var grouped: [(key: String, reports: [SiteReport])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        let dict = Dictionary(grouping: sorted) { formatter.string(from: $0.date) }
        return dict.keys.sorted(by: >).map { key in (key: key, reports: dict[key]!) }
    }

    private var totalPersonnel: Int {
        sorted.reduce(0) { $0 + $1.totalPersonnel }
    }
    private var issueCount: Int {
        sorted.filter { $0.hasIssues }.count
    }
    private var todayReportExists: Bool {
        sorted.contains { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        List {
            // Özet
            if !sorted.isEmpty {
                Section {
                    HStack(spacing: 0) {
                        SiteReportStat(value: "\(sorted.count)", label: "Rapor", color: .hakedisOrange)
                        Divider().frame(height: 36)
                        SiteReportStat(value: "\(totalPersonnel / max(sorted.count, 1))", label: "Ort. Personel", color: .hakedisSuccess)
                        Divider().frame(height: 36)
                        SiteReportStat(value: "\(issueCount)", label: "Sorun", color: issueCount > 0 ? .hakedisDanger : .secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Bugün raporu eksik uyarısı
            if !todayReportExists && !sorted.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.hakedisWarning)
                        Text("Bugün için saha raporu girilmedi")
                            .font(.subheadline)
                            .foregroundColor(.hakedisWarning)
                        Spacer()
                        Button("Ekle") { showingAdd = true }
                            .font(.subheadline.bold())
                            .foregroundColor(.hakedisOrange)
                    }
                }
            }

            // Aylara göre gruplu liste
            if sorted.isEmpty {
                Section {
                    Text("Henüz saha raporu girilmedi")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            } else {
                ForEach(grouped, id: \.key) { group in
                    Section(group.key) {
                        ForEach(group.reports) { report in
                            NavigationLink(destination: SiteReportDetailView(report: report)) {
                                SiteReportRow(report: report)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { group.reports[$0] }.forEach { modelContext.delete($0) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Saha Raporları")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddSiteReportView(project: project)
        }
    }
}

// MARK: - Site Report Row

struct SiteReportRow: View {
    let report: SiteReport

    var body: some View {
        HStack(spacing: 12) {
            // Hava durumu ikonu
            ZStack {
                Circle()
                    .fill(weatherColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: report.weather.icon)
                    .foregroundColor(weatherColor)
                    .font(.system(size: 14))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(report.date.shortFormatted)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Label("\(report.totalPersonnel) kişi", systemImage: "person.2")
                    if report.hasIssues {
                        Label("Sorun var", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.hakedisDanger)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                if !report.workSummary.isEmpty {
                    Text(report.workSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(report.weather.rawValue)
                    .font(.caption)
                    .foregroundColor(weatherColor)
                if let temp = report.temperature {
                    Text("\(Int(temp))°C")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var weatherColor: Color {
        switch report.weather {
        case .sunny:  return .hakedisWarning
        case .cloudy: return .secondary
        case .rainy:  return .hakedisOrange
        case .snowy:  return .blue
        case .foggy:  return .gray
        case .windy:  return .hakedisSuccess
        }
    }
}

// MARK: - Site Report Detail

struct SiteReportDetailView: View {
    let report: SiteReport

    var body: some View {
        List {
            // Başlık bilgileri
            Section {
                LabeledContent("Tarih", value: report.date.shortFormatted)
                HStack {
                    Image(systemName: report.weather.icon)
                        .foregroundColor(.hakedisWarning)
                    Text(report.weather.rawValue)
                    if let temp = report.temperature {
                        Spacer()
                        Text("\(Int(temp))°C")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Personel
            Section("Personel") {
                LabeledContent("İşçi Sayısı") {
                    Text("\(report.workerCount) kişi")
                        .bold()
                }
                LabeledContent("Mühendis/Teknik") {
                    Text("\(report.engineerCount) kişi")
                        .bold()
                }
                LabeledContent("Toplam") {
                    Text("\(report.totalPersonnel) kişi")
                        .foregroundColor(.hakedisOrange)
                        .bold()
                }
            }

            // Yapılan İşler
            if !report.workSummary.isEmpty {
                Section("Yapılan İşler") {
                    Text(report.workSummary)
                        .font(.subheadline)
                }
            }

            // Ekipman
            if !report.equipmentNotes.isEmpty {
                Section("Ekipman / Malzeme") {
                    Text(report.equipmentNotes)
                        .font(.subheadline)
                }
            }

            // Sorunlar
            if report.hasIssues {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.hakedisDanger)
                            .padding(.top, 2)
                        Text(report.issues)
                            .font(.subheadline)
                    }
                } header: {
                    Label("Sorunlar / Engeller", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.hakedisDanger)
                }
            }

            // Yarın Planı
            if !report.tomorrowPlan.isEmpty {
                Section("Yarın Planı") {
                    Text(report.tomorrowPlan)
                        .font(.subheadline)
                }
            }

            // Fotoğraflar
            if !report.photoData.isEmpty {
                Section("Fotoğraflar (\(report.photoData.count))") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(report.photoData.indices, id: \.self) { i in
                                if let uiImage = UIImage(data: report.photoData[i]) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
        }
        .navigationTitle("Saha Raporu")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Add Site Report

struct AddSiteReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let project: Project

    @State private var date = Date()
    @State private var weather: SiteWeather = .sunny
    @State private var temperatureText = ""
    @State private var workerCount = 0
    @State private var engineerCount = 0
    @State private var workSummary = ""
    @State private var issues = ""
    @State private var tomorrowPlan = ""
    @State private var equipmentNotes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []

    var isValid: Bool { !workSummary.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                // Temel bilgiler
                Section("Rapor Bilgileri") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    Picker("Hava Durumu", selection: $weather) {
                        ForEach(SiteWeather.allCases, id: \.self) { w in
                            Label(w.rawValue, systemImage: w.icon).tag(w)
                        }
                    }
                    HStack {
                        Text("Sıcaklık (°C)")
                        Spacer()
                        TextField("—", text: $temperatureText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                }

                // Personel
                Section("Personel") {
                    Stepper("İşçi: \(workerCount) kişi", value: $workerCount, in: 0...500)
                    Stepper("Mühendis/Teknik: \(engineerCount) kişi", value: $engineerCount, in: 0...100)
                }

                // İş özeti (zorunlu)
                Section {
                    TextField("Bugün ne yapıldı? *", text: $workSummary, axis: .vertical)
                        .lineLimit(4...8)
                } header: {
                    Text("Yapılan İşler *")
                }

                // Ekipman
                Section("Ekipman / Malzeme") {
                    TextField("Sahada kullanılan ekipman ve malzeme...", text: $equipmentNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Sorunlar
                Section("Sorunlar / Engeller") {
                    TextField("Gecikme, güvenlik olayı, temin sorunu vb.", text: $issues, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Yarın planı
                Section("Yarın Planı") {
                    TextField("Yarın yapılacak işler...", text: $tomorrowPlan, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Fotoğraflar
                Section("Fotoğraflar") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label(
                            photoData.isEmpty ? "Fotoğraf Seç" : "\(photoData.count) fotoğraf seçildi",
                            systemImage: "photo.on.rectangle.angled"
                        )
                        .foregroundColor(.hakedisOrange)
                    }
                    .onChange(of: selectedPhotos) { _, newItems in
                        Task {
                            var loaded: [Data] = []
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    loaded.append(data)
                                }
                            }
                            photoData = loaded
                        }
                    }
                    if !photoData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photoData.indices, id: \.self) { i in
                                    if let uiImage = UIImage(data: photoData[i]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 64)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
            }
            .navigationTitle("Yeni Saha Raporu")
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
        let temp = Double(temperatureText.replacingOccurrences(of: ",", with: "."))
        let report = SiteReport(
            date: date,
            weather: weather,
            temperature: temp,
            workerCount: workerCount,
            engineerCount: engineerCount,
            workSummary: workSummary.trimmingCharacters(in: .whitespaces),
            issues: issues.trimmingCharacters(in: .whitespaces),
            tomorrowPlan: tomorrowPlan.trimmingCharacters(in: .whitespaces),
            equipmentNotes: equipmentNotes.trimmingCharacters(in: .whitespaces)
        )
        report.photoData = photoData
        project.siteReports.append(report)
        modelContext.insert(report)
        dismiss()
    }
}

// MARK: - Dashboard Alert Card

struct SiteReportMissingCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clipboard.fill")
                .foregroundColor(.hakedisWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.subheadline.bold())
                Text("Bugün saha raporu girilmedi")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.hakedisWarning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Mini Stat

private struct SiteReportStat: View {
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
