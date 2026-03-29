import SwiftUI
import SwiftData

// MARK: - PhotoAnnotationSection

struct PhotoAnnotationSection: View {
    @Environment(\.modelContext) private var modelContext
    let dailyEntry: DailyEntry
    let contract: Contract?

    @State private var showLinkSheet = false
    @State private var selectedPhotoIndex: Int = 0
    @State private var selectedAnnotation: PhotoAnnotation? = nil

    private var annotatedIndices: Set<Int> {
        Set(dailyEntry.photoAnnotations.map(\.photoIndex))
    }

    private var unlabeledCount: Int {
        max(0, dailyEntry.photoData.count - annotatedIndices.count)
    }

    /// Annotations grouped by photoIndex, sorted ascending
    private var groupedAnnotations: [(Int, [PhotoAnnotation])] {
        let dict = Dictionary(grouping: dailyEntry.photoAnnotations, by: \.photoIndex)
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        Section {
            if dailyEntry.photoData.isEmpty {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.secondary)
                    Text("Bu kayıtta fotoğraf yok")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                // Unlabeled warning row
                if unlabeledCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.hakedisWarning)
                            .font(.subheadline)
                        Text("\(unlabeledCount) fotoğraf henüz poza bağlanmadı")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                // Existing annotations grouped by photo
                ForEach(groupedAnnotations, id: \.0) { photoIndex, annotations in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            thumbnailImage(for: photoIndex)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fotoğraf \(photoIndex + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Text("\(annotations.count) poz bağlantısı")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)

                        ForEach(annotations) { annotation in
                            Button {
                                selectedAnnotation = annotation
                            } label: {
                                AnnotationRowView(annotation: annotation)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Link button
                Button {
                    selectedPhotoIndex = 0
                    showLinkSheet = true
                } label: {
                    Label("Fotoğrafları Poza Bağla", systemImage: "link.badge.plus")
                        .font(.subheadline.bold())
                        .foregroundColor(.hakedisOrange)
                }
            }
        } header: {
            HStack {
                Text("Fotoğraf–İmalat Bağlantısı")
                if !dailyEntry.photoData.isEmpty {
                    Spacer()
                    Text("\(dailyEntry.photoAnnotations.count)/\(dailyEntry.photoData.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showLinkSheet) {
            PhotoWorkItemLinkSheet(
                dailyEntry: dailyEntry,
                photoIndex: selectedPhotoIndex,
                contract: contract,
                onDismiss: { showLinkSheet = false }
            )
        }
        .sheet(item: $selectedAnnotation) { annotation in
            NavigationStack {
                PhotoAnnotationDetailView(annotation: annotation)
            }
        }
    }

    @ViewBuilder
    private func thumbnailImage(for index: Int) -> some View {
        if index < dailyEntry.photoData.count,
           let uiImage = UIImage(data: dailyEntry.photoData[index]) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.secondary.opacity(0.2)
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - AnnotationRowView (Helper)

private struct AnnotationRowView: View {
    let annotation: PhotoAnnotation

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(annotation.workItemCode)
                        .font(.caption.bold())
                        .foregroundColor(.hakedisOrange)
                    Text(annotation.workItemName)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                if let qty = annotation.measuredQuantity {
                    Text("\(qty.quantityFormatted) \(annotation.unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            StatusBadge(
                text: annotation.isIncludedInHakedis ? "Dahil" : "Hariç",
                color: annotation.isIncludedInHakedis ? .hakedisSuccess : .secondary
            )
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.leading, 52)
    }
}

// MARK: - PhotoWorkItemLinkSheet

struct PhotoWorkItemLinkSheet: View {
    @Environment(\.modelContext) private var modelContext

    let dailyEntry: DailyEntry
    let photoIndex: Int
    let contract: Contract?
    let onDismiss: () -> Void

    // Photo selection
    @State private var currentPhotoIndex: Int
    // Work item selection
    @State private var selectedWorkItem: WorkItem? = nil
    @State private var manualCode: String = ""
    @State private var manualName: String = ""
    @State private var manualUnit: String = ""
    // Fields
    @State private var measuredQuantity: String = ""
    @State private var locationDescription: String = ""
    @State private var annotationText: String = ""
    // Validation
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    init(dailyEntry: DailyEntry, photoIndex: Int, contract: Contract?, onDismiss: @escaping () -> Void) {
        self.dailyEntry = dailyEntry
        self.photoIndex = photoIndex
        self.contract = contract
        self.onDismiss = onDismiss
        _currentPhotoIndex = State(initialValue: photoIndex)
    }

    private var workItems: [WorkItem] {
        contract?.workItems.sorted { $0.code < $1.code } ?? []
    }

    private var hasContract: Bool { contract != nil && !workItems.isEmpty }

    private var resolvedCode: String {
        hasContract ? (selectedWorkItem?.code ?? "") : manualCode
    }
    private var resolvedName: String {
        hasContract ? (selectedWorkItem?.name ?? "") : manualName
    }
    private var resolvedUnit: String {
        hasContract ? (selectedWorkItem?.unit ?? "") : manualUnit
    }

    var body: some View {
        NavigationStack {
            Form {
                // Photo Preview Section
                Section("Fotoğraf") {
                    photoPreviewSection
                }

                // Work Item Section
                Section("İmalat Pozu") {
                    if hasContract {
                        contractWorkItemPicker
                    } else {
                        manualWorkItemFields
                    }
                }

                // Quantity Section
                Section("Ölçüm") {
                    HStack {
                        Text("Ölçülen Miktar")
                        Spacer()
                        TextField("0", text: $measuredQuantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        if !resolvedUnit.isEmpty {
                            Text(resolvedUnit)
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                        }
                    }
                }

                // Location & Notes Section
                Section("Açıklama") {
                    HStack {
                        Text("Konum")
                        Spacer()
                        TextField("Örn: Zemin kat, C/3 aksı", text: $locationDescription)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not")
                            .font(.subheadline)
                        TextEditor(text: $annotationText)
                            .frame(minHeight: 60)
                            .font(.body)
                    }
                }

                // GPS Section
                Section("Konum Bilgisi") {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.hakedisOrange)
                        Text("GPS otomatik kaydedilecek")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Fotoğrafı Poza Bağla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .bold()
                        .foregroundColor(.hakedisOrange)
                }
            }
            .alert("Eksik Bilgi", isPresented: $showValidationAlert) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: Photo Preview

    @ViewBuilder
    private var photoPreviewSection: some View {
        VStack(spacing: 10) {
            // Thumbnail
            if currentPhotoIndex < dailyEntry.photoData.count,
               let uiImage = UIImage(data: dailyEntry.photoData[currentPhotoIndex]) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 120)
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                }
            }

            // Photo selector (if multiple)
            if dailyEntry.photoData.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<dailyEntry.photoData.count, id: \.self) { idx in
                            photoThumb(index: idx)
                                .onTapGesture { currentPhotoIndex = idx }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            Text("Fotoğraf \(currentPhotoIndex + 1) / \(dailyEntry.photoData.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func photoThumb(index: Int) -> some View {
        if index < dailyEntry.photoData.count,
           let uiImage = UIImage(data: dailyEntry.photoData[index]) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(currentPhotoIndex == index ? Color.hakedisOrange : Color.clear, lineWidth: 2)
                )
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 52, height: 52)
        }
    }

    // MARK: Work Item Pickers

    @ViewBuilder
    private var contractWorkItemPicker: some View {
        if selectedWorkItem == nil {
            Text("Poz seçilmedi")
                .foregroundColor(.secondary)
                .font(.subheadline)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedWorkItem!.code)
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
                Text(selectedWorkItem!.name)
                    .font(.subheadline)
                Text("Birim: \(selectedWorkItem!.unit) — Birim Fiyat: \(selectedWorkItem!.unitPrice.currencyFormatted)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }

        Picker("Poz Seç", selection: $selectedWorkItem) {
            Text("Seçiniz...").tag(nil as WorkItem?)
            ForEach(workItems) { item in
                VStack(alignment: .leading) {
                    Text("\(item.code) – \(item.name)")
                }
                .tag(item as WorkItem?)
            }
        }
        .pickerStyle(.menu)
        .accentColor(.hakedisOrange)
    }

    @ViewBuilder
    private var manualWorkItemFields: some View {
        HStack {
            Text("Poz No")
            Spacer()
            TextField("Örn: 01.001", text: $manualCode)
                .multilineTextAlignment(.trailing)
        }
        HStack {
            Text("İmalat Adı")
            Spacer()
            TextField("Poz adı", text: $manualName)
                .multilineTextAlignment(.trailing)
        }
        HStack {
            Text("Birim")
            Spacer()
            TextField("m², m³, adet…", text: $manualUnit)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    // MARK: Save

    private func save() {
        let code = resolvedCode.trimmingCharacters(in: .whitespaces)
        let name = resolvedName.trimmingCharacters(in: .whitespaces)

        guard !code.isEmpty else {
            validationMessage = "Poz numarası giriniz."
            showValidationAlert = true
            return
        }
        guard !name.isEmpty else {
            validationMessage = "İmalat adı giriniz."
            showValidationAlert = true
            return
        }

        let annotation = PhotoAnnotation(
            photoIndex: currentPhotoIndex,
            workItemCode: code,
            workItemName: name,
            unit: resolvedUnit
        )

        let qtyText = measuredQuantity.trimmingCharacters(in: .whitespaces)
        if !qtyText.isEmpty {
            annotation.measuredQuantity = Double(qtyText.replacingOccurrences(of: ",", with: "."))
        }

        let locDesc = locationDescription.trimmingCharacters(in: .whitespaces)
        annotation.locationDescription = locDesc.isEmpty ? nil : locDesc

        let noteText = annotationText.trimmingCharacters(in: .whitespaces)
        annotation.annotationText = noteText.isEmpty ? nil : noteText

        annotation.dailyEntry = dailyEntry
        dailyEntry.photoAnnotations.append(annotation)
        modelContext.insert(annotation)

        onDismiss()
    }
}

// MARK: - PhotoAnnotationDetailView

struct PhotoAnnotationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var annotation: PhotoAnnotation

    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            // Photo
            if let entry = annotation.dailyEntry,
               annotation.photoIndex < entry.photoData.count,
               let uiImage = UIImage(data: entry.photoData[annotation.photoIndex]) {
                Section("Fotoğraf") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }
            }

            // Work Item Info
            Section("İmalat Pozu") {
                LabeledContent("Poz No", value: annotation.workItemCode)
                LabeledContent("İmalat Adı", value: annotation.workItemName)
                if !annotation.unit.isEmpty {
                    LabeledContent("Birim", value: annotation.unit)
                }
            }

            // Measurement
            Section("Ölçüm") {
                if let qty = annotation.measuredQuantity {
                    LabeledContent("Ölçülen Miktar") {
                        Text("\(qty.quantityFormatted) \(annotation.unit)")
                            .bold()
                    }
                } else {
                    HStack {
                        Text("Ölçülen Miktar")
                        Spacer()
                        Text("Girilmedi")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Location & Notes
            Section("Açıklama") {
                if let loc = annotation.locationDescription, !loc.isEmpty {
                    LabeledContent("Konum", value: loc)
                } else {
                    LabeledContent("Konum", value: "—")
                }

                if let note = annotation.annotationText, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(note)
                            .font(.body)
                    }
                    .padding(.vertical, 2)
                }
            }

            // GPS
            Section("Konum Bilgisi") {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.hakedisOrange)
                    Text("GPS: \(annotation.gpsCoordinate ?? "Konum yok")")
                        .font(.subheadline)
                        .foregroundColor(annotation.gpsCoordinate != nil ? .primary : .secondary)
                }
            }

            // Dates
            Section("Tarih Bilgisi") {
                LabeledContent("Çekim Tarihi", value: annotation.capturedAt.shortFormatted)
                LabeledContent("Oluşturulma", value: annotation.createdAt.shortFormatted)
            }

            // Hakedis Toggle
            Section("Hakediş") {
                Toggle("Hakedişe Dahil Et", isOn: $annotation.isIncludedInHakedis)
                    .tint(.hakedisOrange)
                if annotation.isIncludedInHakedis {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.hakedisSuccess)
                        Text("Bu fotoğraf hakedişe dahil edilecek")
                            .font(.caption)
                            .foregroundColor(.hakedisSuccess)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.secondary)
                        Text("Bu fotoğraf hakedişe dahil edilmeyecek")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Delete
            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Bağlantıyı Sil", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Poz Bağlantısı Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Bu fotoğraf–poz bağlantısını silmek istediğinize emin misiniz?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Bağlantıyı Sil", role: .destructive) {
                deleteAnnotation()
            }
            Button("İptal", role: .cancel) {}
        }
    }

    private func deleteAnnotation() {
        if let entry = annotation.dailyEntry,
           let idx = entry.photoAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            entry.photoAnnotations.remove(at: idx)
        }
        modelContext.delete(annotation)
        dismiss()
    }
}

// MARK: - HakedisPhotoEvidenceSection

struct HakedisPhotoEvidenceSection: View {
    let hakedis: Hakedis
    let contract: Contract?

    /// Collect all DailyEntries whose date falls within the hakedis period, from all workItems of the contract
    private var periodEntries: [DailyEntry] {
        guard let contract else { return [] }
        return contract.workItems.flatMap { item in
            item.dailyEntries.filter { entry in
                entry.date >= hakedis.periodStart && entry.date <= hakedis.periodEnd
            }
        }
    }

    /// All PhotoAnnotations that are included in hakedis, from the period entries
    private var includedAnnotations: [PhotoAnnotation] {
        periodEntries.flatMap { $0.photoAnnotations }.filter { $0.isIncludedInHakedis }
    }

    /// Group annotations by workItemCode
    private var annotationsByWorkItem: [(String, String, [PhotoAnnotation])] {
        let dict = Dictionary(grouping: includedAnnotations, by: \.workItemCode)
        return dict.map { code, annotations in
            let name = annotations.first?.workItemName ?? ""
            return (code, name, annotations)
        }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        Section {
            if includedAnnotations.isEmpty {
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "Fotoğraflı Kayıt Yok",
                    subtitle: "Bu dönemde fotoğraflı imalat kaydı yok"
                )
                .listRowBackground(Color.clear)
            } else {
                // Summary row
                HStack {
                    Image(systemName: "photo.stack.fill")
                        .foregroundColor(.hakedisOrange)
                    Text("\(includedAnnotations.count) fotoğraf, \(annotationsByWorkItem.count) poz")
                        .font(.subheadline)
                    Spacer()
                    StatusBadge(text: "Hakedişe Dahil", color: .hakedisSuccess)
                }
                .padding(.vertical, 2)

                // Per work item
                ForEach(annotationsByWorkItem, id: \.0) { code, name, annotations in
                    VStack(alignment: .leading, spacing: 8) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(code)
                                        .font(.caption.bold())
                                        .foregroundColor(.hakedisOrange)
                                    Text(name)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                Text("\(annotations.count) fotoğraf")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            // Hakedis item match indicator
                            if let hakedisItem = hakedis.items.first(where: { $0.workItemCode == code }) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(hakedisItem.currentQuantity.quantityFormatted)
                                        .font(.caption.bold())
                                    Text(hakedisItem.unit)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Thumbnail grid (3 per row)
                        PhotoThumbnailGrid(annotations: annotations)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            HStack {
                Text("Fotoğraflı İmalat Kanıtları")
                Spacer()
                if !includedAnnotations.isEmpty {
                    Text("\(includedAnnotations.count) fotoğraf")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - PhotoThumbnailGrid (Helper)

private struct PhotoThumbnailGrid: View {
    let annotations: [PhotoAnnotation]
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(annotations) { annotation in
                photoCell(for: annotation)
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    @ViewBuilder
    private func photoCell(for annotation: PhotoAnnotation) -> some View {
        if let entry = annotation.dailyEntry,
           annotation.photoIndex < entry.photoData.count,
           let uiImage = UIImage(data: entry.photoData[annotation.photoIndex]) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()

                // Qty overlay
                if let qty = annotation.measuredQuantity {
                    Text("\(qty.quantityFormatted) \(annotation.unit)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(3)
                }
            }
        } else {
            ZStack {
                Color.secondary.opacity(0.15)
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
}

// MARK: - UnlabeledPhotosAlertCard

struct UnlabeledPhotosAlertCard: View {
    let projects: [Project]

    private var unlabeledCount: Int {
        projects.flatMap { project in
            project.contracts.flatMap { contract in
                contract.workItems.flatMap { item in
                    item.dailyEntries
                }
            }
        }
        .reduce(0) { total, entry in
            let annotatedIndices = Set(entry.photoAnnotations.map(\.photoIndex))
            let unlabeled = entry.photoData.indices.filter { !annotatedIndices.contains($0) }.count
            return total + unlabeled
        }
    }

    var body: some View {
        if unlabeledCount > 0 {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.hakedisWarning.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "photo.badge.exclamationmark.fill")
                        .font(.title3)
                        .foregroundColor(.hakedisWarning)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(unlabeledCount) fotoğraf henüz poza bağlanmadı")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("Günlük girişlere giderek fotoğrafları imalat pozlarıyla ilişkilendirin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hakedisWarning.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.hakedisWarning.opacity(0.4), lineWidth: 1)
                    )
            )
        }
    }
}
