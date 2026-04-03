import SwiftUI
import SwiftData
import PhotosUI

// MARK: - ProgressReportListView

struct ProgressReportListView: View {
    @Query(sort: \ProgressReport.createdAt, order: .reverse) private var reports: [ProgressReport]
    @Query private var projects: [Project]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var selectedProjectID: UUID? = nil

    private var filtered: [ProgressReport] {
        reports.filter { r in
            guard let pid = selectedProjectID else { return true }
            return r.project?.id == pid
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if !projects.isEmpty {
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
                }

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "camera.viewfinder",
                        title: "İlerleme raporu yok",
                        subtitle: "Şantiye ilerleme raporlarını buradan yönetin",
                        actionTitle: "Rapor Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { r in
                            NavigationLink(destination: ProgressReportDetailView(report: r)) {
                                ProgressReportRow(report: r)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(r)
                                } label: { Label("Sil", systemImage: "trash") }
                            }
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
            .accessibilityLabel("İlerleme raporu ekle")
        }
        .background(Color.hakedisBackground)
        .navigationTitle("İlerleme Raporları")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) {
            AddProgressReportView()
        }
    }
}

// MARK: - ProgressReportRow

private struct ProgressReportRow: View {
    let report: ProgressReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(report.reportPeriod).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                Text(String(format: "%%%.0f", report.completionPercentage))
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.hakedisOrange.opacity(0.12))
                    .clipShape(Capsule())
            }
            if let pname = report.project?.name {
                Text(pname).font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 12) {
                Label("\(report.beforePhotoData.count) Önce", systemImage: "photo")
                    .font(.caption2).foregroundColor(.secondary)
                Label("\(report.afterPhotoData.count) Sonra", systemImage: "photo.fill")
                    .font(.caption2).foregroundColor(.hakedisSuccess)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(report.reportPeriod), tamamlanma %\(String(format: "%.0f", report.completionPercentage))")
    }
}

// MARK: - ProgressReportDetailView

struct ProgressReportDetailView: View {
    let report: ProgressReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Özet
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Özet")
                    VStack(spacing: 0) {
                        LabeledContent("Dönem", value: report.reportPeriod)
                            .padding(Spacing.card)
                        Divider()
                        if let pname = report.project?.name {
                            LabeledContent("Proje", value: pname)
                                .padding(Spacing.card)
                            Divider()
                        }
                        HStack {
                            Text("Tamamlanma")
                            Spacer()
                            Text(String(format: "%%.1f%%", report.completionPercentage))
                                .font(.subheadline.bold())
                                .foregroundColor(.hakedisOrange)
                        }
                        .padding(Spacing.card)
                    }
                    .background(Color.hakedisCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, Spacing.card)

                    ProgressBarView(progress: report.completionPercentage, color: .hakedisOrange)
                        .frame(height: 8)
                        .padding(.horizontal, Spacing.card)
                }

                // Açıklama
                if !report.summaryText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Açıklama")
                        Text(report.summaryText)
                            .font(.body)
                            .padding(Spacing.card)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.hakedisCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, Spacing.card)
                    }
                }

                // Fotoğraflar — Önce
                if !report.beforePhotoData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Öncesi Fotoğrafları")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(report.beforePhotoData.indices, id: \.self) { i in
                                    if let img = UIImage(data: report.beforePhotoData[i]) {
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(width: 120, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.card)
                        }
                    }
                }

                // Fotoğraflar — Sonra
                if !report.afterPhotoData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Sonrası Fotoğrafları")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(report.afterPhotoData.indices, id: \.self) { i in
                                    if let img = UIImage(data: report.afterPhotoData[i]) {
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(width: 120, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.card)
                        }
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color.hakedisBackground)
        .navigationTitle(report.reportPeriod)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AddProgressReportView

struct AddProgressReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]

    @State private var reportPeriod = ""
    @State private var completionPct = ""
    @State private var summaryText = ""
    @State private var selectedProject: Project? = nil
    @State private var beforeItems: [PhotosPickerItem] = []
    @State private var afterItems: [PhotosPickerItem] = []
    @State private var beforePhotos: [Data] = []
    @State private var afterPhotos: [Data] = []
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Dönem") {
                    TextField("Dönem (örn: Mart 2026)", text: $reportPeriod)
                    if showValidation && reportPeriod.isEmpty {
                        Text("Dönem adı zorunludur").font(.caption).foregroundColor(.hakedisDanger)
                    }
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                    }
                }
                Section("Tamamlanma") {
                    HStack {
                        Text("Tamamlanma (%)")
                        Spacer()
                        TextField("0", text: $completionPct)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                Section("Açıklama") {
                    TextEditor(text: $summaryText).frame(minHeight: 80)
                }
                Section("Öncesi Fotoğraflar") {
                    PhotosPicker(selection: $beforeItems, maxSelectionCount: 6, matching: .images) {
                        Label("Fotoğraf Seç (\(beforePhotos.count))", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: beforeItems) { _, newItems in
                        Task { beforePhotos = await loadPhotos(newItems) }
                    }
                }
                Section("Sonrası Fotoğraflar") {
                    PhotosPicker(selection: $afterItems, maxSelectionCount: 6, matching: .images) {
                        Label("Fotoğraf Seç (\(afterPhotos.count))", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: afterItems) { _, newItems in
                        Task { afterPhotos = await loadPhotos(newItems) }
                    }
                }
            }
            .navigationTitle("İlerleme Raporu Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async -> [Data] {
        var result: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                result.append(data)
            }
        }
        return result
    }

    private func save() {
        guard !reportPeriod.isEmpty else { showValidation = true; return }
        let r = ProgressReport(
            reportPeriod: reportPeriod,
            completionPercentage: Double(completionPct) ?? 0,
            summaryText: summaryText
        )
        r.project = selectedProject
        r.beforePhotoData = beforePhotos
        r.afterPhotoData = afterPhotos
        modelContext.insert(r)
        do { try modelContext.save() } catch { print(error) }
        dismiss()
    }
}
