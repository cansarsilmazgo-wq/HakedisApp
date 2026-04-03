import SwiftUI
import SwiftData
import PhotosUI

// MARK: - EquipmentFailureListView
struct EquipmentFailureListView: View {
    @Query(sort: \EquipmentFailure.failureDate, order: .reverse) private var failures: [EquipmentFailure]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var showOpenOnly = true

    private var filtered: [EquipmentFailure] {
        showOpenOnly ? failures.filter { !$0.isResolved } : failures
    }

    private var openCount: Int { failures.filter { !$0.isResolved }.count }
    private var totalDowntime: Double { failures.compactMap { $0.downtimeHours }.reduce(0, +) }
    private var totalRepairCost: Double { failures.filter { $0.isResolved }.compactMap { $0.repairCost }.reduce(0, +) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if openCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.hakedisDanger)
                        Text("\(openCount) açık arıza")
                            .font(.caption.bold()).foregroundColor(.hakedisDanger)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.1))
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    StatCard(title: "Açık Arıza", value: "\(openCount)", color: .hakedisDanger, icon: "exclamationmark.circle")
                    StatCard(title: "Toplam Durma", value: String(format: "%.0f saat", totalDowntime), color: .hakedisWarning, icon: "clock.badge.xmark")
                }
                .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                Toggle("Sadece Açık Arızalar", isOn: $showOpenOnly)
                    .padding(.horizontal, Spacing.card)
                    .accessibilityLabel("Sadece açık arızaları göster")

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "wrench.slash",
                        title: showOpenOnly ? "Açık arıza yok" : "Arıza kaydı yok",
                        subtitle: "Ekipman arızalarını kaydedin",
                        actionTitle: "Arıza Kaydet",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { failure in
                            NavigationLink(destination: EquipmentFailureDetailView(failure: failure)) {
                                EquipmentFailureRow(failure: failure)
                            }
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
            .accessibilityLabel("Arıza kaydet")
        }
        .sheet(isPresented: $showingAdd) { AddEquipmentFailureView() }
    }
}

// MARK: - EquipmentFailureRow
private struct EquipmentFailureRow: View {
    let failure: EquipmentFailure
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: failure.isResolved ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundColor(failure.isResolved ? .hakedisSuccess : .hakedisDanger)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(failure.failureChangeDescription).font(.subheadline.bold()).lineLimit(1)
                if let eq = failure.equipment {
                    Text(eq.name).font(.caption).foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    Text(failure.failureDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
                    if let hours = failure.downtimeHours {
                        Text("\(String(format: "%.0f", hours))s durma").font(.caption2).foregroundColor(.hakedisWarning)
                    }
                }
            }
            Spacer()
            if let cost = failure.repairCost, cost > 0 {
                Text(cost.currencyFormatted).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(failure.failureChangeDescription), \(failure.isResolved ? "çözüldü" : "açık")")
    }
}

// MARK: - EquipmentFailureDetailView
struct EquipmentFailureDetailView: View {
    @Bindable var failure: EquipmentFailure
    @State private var showingResolve = false

    var body: some View {
        List {
            Section("Arıza Bilgileri") {
                LabeledContent("Tarih", value: failure.failureDate.shortFormatted)
                LabeledContent("Açıklama", value: failure.failureChangeDescription)
                if let hours = failure.downtimeHours {
                    LabeledContent("Durma Süresi", value: "\(String(format: "%.1f", hours)) saat")
                }
                if let eq = failure.equipment {
                    LabeledContent("Ekipman", value: eq.name)
                }
            }
            if failure.isResolved {
                Section("Tamir Bilgileri") {
                    if let repairDate = failure.repairDate {
                        LabeledContent("Tamir Tarihi", value: repairDate.shortFormatted)
                    }
                    if let repairDesc = failure.repairChangeDescription {
                        LabeledContent("Tamir Açıklaması", value: repairDesc)
                    }
                    if let cost = failure.repairCost {
                        LabeledContent("Tamir Maliyeti", value: cost.currencyFormatted)
                    }
                    if let parts = failure.spareParts {
                        LabeledContent("Yedek Parça", value: parts)
                    }
                }
            } else {
                Section {
                    Button {
                        showingResolve = true
                    } label: {
                        Label("Tamiri Kaydet", systemImage: "checkmark.circle")
                            .foregroundColor(.hakedisSuccess)
                    }
                    .accessibilityLabel("Tamiri kaydet")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Arıza Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingResolve) { ResolveFailureView(failure: failure) }
    }
}

// MARK: - ResolveFailureView
struct ResolveFailureView: View {
    @Bindable var failure: EquipmentFailure
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var repairDate = Date()
    @State private var repairDesc = ""
    @State private var repairCost = ""
    @State private var spareParts = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tamir Bilgileri") {
                    DatePicker("Tamir Tarihi", selection: $repairDate, displayedComponents: .date)
                    TextField("Tamir Açıklaması", text: $repairDesc)
                        .accessibilityLabel("Tamir açıklaması")
                    TextField("Tamir Maliyeti (₺)", text: $repairCost)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Tamir maliyeti")
                    TextField("Yedek Parça", text: $spareParts)
                        .accessibilityLabel("Kullanılan yedek parça")
                }
            }
            .navigationTitle("Tamiri Kaydet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        failure.repairDate = repairDate
        failure.repairChangeDescription = repairDesc.isEmpty ? nil : repairDesc
        failure.repairCost = Double(repairCost.replacingOccurrences(of: ",", with: "."))
        failure.spareParts = spareParts.isEmpty ? nil : spareParts
        failure.isResolved = true
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}

// MARK: - AddEquipmentFailureView
struct AddEquipmentFailureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EquipmentItem.name) private var equipment: [EquipmentItem]

    @State private var failureDate = Date()
    @State private var failureDesc = ""
    @State private var selectedEquipment: EquipmentItem? = nil
    @State private var downtimeHours = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photoDatas: [Data] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Arıza Bilgileri") {
                    DatePicker("Arıza Tarihi", selection: $failureDate, displayedComponents: .date)
                    TextField("Arıza Açıklaması *", text: $failureDesc)
                        .accessibilityLabel("Arıza açıklaması")
                    Picker("Ekipman", selection: $selectedEquipment) {
                        Text("Seçilmedi").tag(Optional<EquipmentItem>.none)
                        ForEach(equipment, id: \.id) { e in Text(e.name).tag(Optional(e)) }
                    }
                    TextField("Tahmini Durma Süresi (saat)", text: $downtimeHours)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Durma süresi")
                }
                Section("Fotoğraf") {
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 3, matching: .images) {
                        Label("Fotoğraf Seç (\(photoDatas.count)/3)", systemImage: "camera")
                            .foregroundColor(.hakedisOrange)
                    }
                    .onChange(of: photoItems) { _, items in
                        Task {
                            photoDatas = []
                            for item in items {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    photoDatas.append(data)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Arıza Kaydet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        let desc = failureDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else { return }
        let failure = EquipmentFailure(failureDate: failureDate, failureChangeDescription: desc)
        failure.equipment = selectedEquipment
        failure.downtimeHours = Double(downtimeHours.replacingOccurrences(of: ",", with: "."))
        failure.photoData = photoDatas
        modelContext.insert(failure)
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
