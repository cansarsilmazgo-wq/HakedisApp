import SwiftUI
import SwiftData
import PhotosUI

// MARK: - AttachmentListView
// İş kalemi bazlı ataşman / yeşil defter listesi

struct AttachmentListView: View {
    let workItem: WorkItem
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var showingPDF = false

    private var sorted: [AttachmentRecord] {
        workItem.attachments.sorted { $0.attachmentNo < $1.attachmentNo }
    }

    private var totalQuantity: Double {
        sorted.reduce(0) { $0 + $1.calculatedQuantity }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if sorted.isEmpty {
                EmptyStateView(
                    icon: "book.pages",
                    title: "Ataşman kaydı yok",
                    subtitle: "Metraj ölçümlerini kaydetmek için + butonuna basın",
                    actionTitle: "Ataşman Ekle",
                    action: { showingAdd = true }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(sorted) { rec in
                            AttachmentRow(record: rec, unit: workItem.unit)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        workItem.attachments.removeAll { $0.id == rec.id }
                                        modelContext.delete(rec)
                                    } label: { Label("Sil", systemImage: "trash") }
                                }
                        }
                    }

                    Section("Alt Toplam") {
                        HStack {
                            Text("Toplam Hesaplanan Miktar")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(totalQuantity.quantityFormatted) \(workItem.unit)")
                                .font(.subheadline.bold())
                                .foregroundColor(.hakedisOrange)
                        }
                        HStack {
                            Text("Sözleşme Miktarı")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(workItem.contractedQuantity.quantityFormatted) \(workItem.unit)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        let diff = totalQuantity - workItem.contractedQuantity
                        if abs(diff) > 0.001 {
                            HStack {
                                Text(diff > 0 ? "Fazla" : "Eksik")
                                    .font(.caption)
                                    .foregroundColor(diff > 0 ? .hakedisWarning : .hakedisInfo)
                                Spacer()
                                Text("\(abs(diff).quantityFormatted) \(workItem.unit)")
                                    .font(.caption.bold())
                                    .foregroundColor(diff > 0 ? .hakedisWarning : .hakedisInfo)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
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
            .accessibilityLabel("Yeni ataşman ekle")
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Ataşman / Yeşil Defter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingPDF = true
                } label: {
                    Image(systemName: "doc.richtext")
                }
                .accessibilityLabel("PDF oluştur")
                .disabled(sorted.isEmpty)

                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Yeni ataşman")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddAttachmentView(workItem: workItem, nextNo: (sorted.last?.attachmentNo ?? 0) + 1)
        }
        .sheet(isPresented: $showingPDF) {
            AttachmentPDFPreviewView(workItem: workItem, records: sorted)
        }
    }
}

// MARK: - AttachmentRow

private struct AttachmentRow: View {
    let record: AttachmentRecord
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("No: \(record.attachmentNo)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.hakedisOrange.opacity(0.15))
                    .foregroundColor(.hakedisOrange)
                    .clipShape(Capsule())

                Text(record.location)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Spacer()

                Text("\(record.calculatedQuantity.quantityFormatted) \(unit)")
                    .font(.subheadline.bold())
                    .foregroundColor(.hakedisOrange)
            }

            if record.length != nil || record.width != nil || record.height != nil {
                Text(record.formulaDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }

            if let notes = record.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if record.sketchPhotoData != nil {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.caption2)
                    Text("Kroki mevcut")
                        .font(.caption2)
                }
                .foregroundColor(.hakedisInfo)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ataşman \(record.attachmentNo), \(record.location), \(record.calculatedQuantity.quantityFormatted) \(unit)")
    }
}

// MARK: - AddAttachmentView

struct AddAttachmentView: View {
    let workItem: WorkItem
    let nextNo: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var attachmentNo: Int
    @State private var location = ""
    @State private var lengthText = ""
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var quantityText = ""
    @State private var notes = ""
    @State private var formulaText = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var sketchData: Data? = nil
    @State private var showValidation = false

    init(workItem: WorkItem, nextNo: Int) {
        self.workItem = workItem
        self.nextNo = nextNo
        _attachmentNo = State(initialValue: nextNo)
    }

    private var calcQty: Double {
        let l = Double(lengthText), w = Double(widthText), h = Double(heightText)
        let q = Double(quantityText)
        if let lv = l, let wv = w, let hv = h { return lv * wv * hv }
        if let lv = l, let wv = w { return lv * wv }
        return q ?? 0
    }

    private var previewFormula: String {
        let l = Double(lengthText), w = Double(widthText), h = Double(heightText)
        let q = Double(quantityText)
        if let lv = l, let wv = w, let hv = h {
            return String(format: "%.3g × %.3g × %.3g = %.4g \(workItem.unit)", lv, wv, hv, lv * wv * hv)
        }
        if let lv = l, let wv = w {
            return String(format: "%.3g × %.3g = %.4g \(workItem.unit)", lv, wv, lv * wv)
        }
        if let qv = q { return String(format: "%.4g \(workItem.unit)", qv) }
        return "—"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ataşman Bilgileri") {
                    HStack {
                        Text("Ataşman No")
                        Spacer()
                        TextField("No", value: $attachmentNo, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .accessibilityLabel("Ataşman numarası")
                    }

                    TextField("Mahal (Bodrum Kat, 1. Kat...)", text: $location)
                        .accessibilityLabel("Mahal")
                    if showValidation && location.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Mahal zorunludur").font(.caption).foregroundColor(.hakedisDanger)
                    }
                }

                Section("Ölçüler (m)") {
                    HStack {
                        Text("Uzunluk (L)")
                        Spacer()
                        TextField("—", text: $lengthText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Uzunluk")
                    }
                    HStack {
                        Text("Genişlik (W)")
                        Spacer()
                        TextField("—", text: $widthText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Genişlik")
                    }
                    HStack {
                        Text("Yükseklik (H)")
                        Spacer()
                        TextField("—", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Yükseklik")
                    }
                }

                Section("Alternatif: Direkt Miktar") {
                    HStack {
                        Text("Miktar (\(workItem.unit))")
                        Spacer()
                        TextField("—", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Miktar")
                    }
                    Text("L×W×H varsa kullanılır, yoksa bu değer alınır.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    HStack {
                        Text("Hesaplanan")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(previewFormula)
                            .font(.subheadline.bold())
                            .foregroundColor(.hakedisOrange)
                            .fontDesign(.monospaced)
                    }
                } header: {
                    Text("Önizleme")
                }

                Section("Formül Açıklaması (Opsiyonel)") {
                    TextField("Örn: 3 adet pencere boşluğu", text: $formulaText)
                        .accessibilityLabel("Formül açıklaması")
                }

                Section("Notlar") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .accessibilityLabel("Notlar")
                }

                Section("Kroki / Fotoğraf") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(sketchData == nil ? "Kroki Ekle" : "Kroki Değiştir",
                              systemImage: "photo.badge.plus")
                            .foregroundColor(.hakedisOrange)
                    }
                    .accessibilityLabel("Kroki ekle")
                    if let data = sketchData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .navigationTitle("Yeni Ataşman")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                }
            }
            .onChange(of: selectedPhoto) { loadPhoto() }
        }
    }

    private func loadPhoto() {
        Task {
            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                await MainActor.run { sketchData = data }
            }
        }
    }

    private func save() {
        guard !location.trimmingCharacters(in: .whitespaces).isEmpty else {
            showValidation = true; return
        }
        let rec = AttachmentRecord(attachmentNo: attachmentNo, location: location)
        rec.length = Double(lengthText)
        rec.width = Double(widthText)
        rec.height = Double(heightText)
        rec.quantity = Double(quantityText)
        rec.notes = notes.isEmpty ? nil : notes
        rec.formula = formulaText.isEmpty ? nil : formulaText
        rec.sketchPhotoData = sketchData
        rec.workItem = workItem
        workItem.attachments.append(rec)
        modelContext.insert(rec)
        do { try modelContext.save() } catch { print("Kayıt hatası: \(error)") }
        dismiss()
    }
}

// MARK: - AttachmentPDFPreviewView

struct AttachmentPDFPreviewView: View {
    let workItem: WorkItem
    let records: [AttachmentRecord]

    @Environment(\.dismiss) private var dismiss
    @State private var pdfData: Data?
    @State private var isSharing = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let data = pdfData {
                    PDFKitView(data: data)
                } else {
                    ProgressView("PDF hazırlanıyor…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Ataşman PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let data = pdfData else { return }
                        let url = FileManager.default.temporaryDirectory
                            .appendingPathComponent("atacman_\(workItem.code).pdf")
                        try? data.write(to: url)
                        shareURL = url; isSharing = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(pdfData == nil)
                    .accessibilityLabel("Paylaş")
                }
            }
            .sheet(isPresented: $isSharing) {
                if let url = shareURL { ShareSheet(items: [url]) }
            }
            .onAppear {
                DispatchQueue.global(qos: .userInitiated).async {
                    let data = AttachmentPDFGenerator.generate(workItem: workItem, records: records)
                    DispatchQueue.main.async { pdfData = data }
                }
            }
        }
    }
}
