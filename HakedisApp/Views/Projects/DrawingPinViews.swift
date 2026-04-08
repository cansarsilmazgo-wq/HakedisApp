import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Drawing Pin List View

struct DrawingPinListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DrawingPin.createdAt, order: .reverse) private var pins: [DrawingPin]
    @State private var showAdd = false
    @State private var showBoard = false
    @State private var filterStatus: PinStatus? = nil
    @State private var filterCategory: PinCategory? = nil

    private var filtered: [DrawingPin] {
        pins.filter { pin in
            (filterStatus == nil || pin.status == filterStatus) &&
            (filterCategory == nil || pin.category == filterCategory)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            FilterChip(title: "Tümü", isSelected: filterStatus == nil) {
                                filterStatus = nil
                            }
                            ForEach(PinStatus.allCases, id: \.self) { s in
                                FilterChip(title: s.rawValue, isSelected: filterStatus == s) {
                                    filterStatus = filterStatus == s ? nil : s
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                ForEach(filtered) { pin in
                    NavigationLink(destination: DrawingPinDetailView(pin: pin)) {
                        DrawingPinRow(pin: pin)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Çizim Pinleri")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showBoard = true } label: {
                        Image(systemName: "map")
                    }
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddDrawingPinView() }
            .sheet(isPresented: $showBoard) { DrawingPinBoardView(pins: pins) }
            .overlay {
                if filtered.isEmpty {
                    EmptyStateView(icon: "mappin.and.ellipse", title: "Pin Yok",
                                   subtitle: "Çizim üzerine pin ekleyin")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(filtered[i]) }
        do { try context.save() } catch { print("DrawingPinListView delete error: \(error)") }
    }
}

private struct DrawingPinRow: View {
    let pin: DrawingPin
    private var priorityColor: Color {
        switch pin.priority {
        case .low: return .hakedisSuccess
        case .medium: return .hakedisWarning
        case .high: return .hakedisOrange
        case .critical: return .hakedisDanger
        }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle().fill(priorityColor.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: pin.category.icon).foregroundColor(priorityColor).font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("#\(pin.pinNumber)").font(.caption).foregroundColor(.secondary)
                    Text(pin.drawingName).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if pin.isOverdue {
                        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.hakedisDanger).font(.caption)
                    }
                    StatusBadge(text: pin.status.rawValue, color: .hakedisOrange)
                }
                Text(pin.title).font(.headline)
                if !pin.assignedTo.isEmpty {
                    Label(pin.assignedTo, systemImage: "person").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Drawing Pin Board View

struct DrawingPinBoardView: View {
    let pins: [DrawingPin]
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selectedPin: DrawingPin? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.hakedisBackground.ignoresSafeArea()
                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: 600, height: 800)
                            .overlay(
                                Text("Çizim Alanı\n(Plan yükleyin)")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.4))
                                    .multilineTextAlignment(.center)
                            )
                        ForEach(pins) { pin in
                            PinMarker(pin: pin)
                                .position(
                                    x: pin.xPosition * 600,
                                    y: pin.yPosition * 800
                                )
                                .onTapGesture { selectedPin = pin }
                        }
                    }
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { v in scale = max(0.5, min(3.0, v)) }
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .navigationTitle("Pin Panosu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(item: $selectedPin) { pin in
                DrawingPinDetailView(pin: pin)
            }
        }
    }
}

private struct PinMarker: View {
    let pin: DrawingPin
    private var color: Color {
        switch pin.priority {
        case .low: return .hakedisSuccess
        case .medium: return .hakedisWarning
        case .high: return .hakedisOrange
        case .critical: return .hakedisDanger
        }
    }
    var body: some View {
        ZStack {
            Circle().fill(color).frame(width: 24, height: 24)
            Text("\(pin.pinNumber)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Drawing Pin Detail View

struct DrawingPinDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var pin: DrawingPin

    var body: some View {
        List {
            Section("Bilgiler") {
                LabeledContent("Pin No", value: "#\(pin.pinNumber)")
                LabeledContent("Çizim", value: pin.drawingName)
                LabeledContent("Kategori", value: pin.category.rawValue)
                LabeledContent("Öncelik", value: pin.priority.rawValue)
                LabeledContent("Atanan", value: pin.assignedTo.isEmpty ? "-" : pin.assignedTo)
                if let due = pin.dueDate {
                    LabeledContent("Son Tarih",
                                   value: due.formatted(date: .long, time: .omitted))
                        .foregroundColor(pin.isOverdue ? .hakedisDanger : .primary)
                }
            }
            Section("Durum") {
                Picker("Durum", selection: $pin.statusRaw) {
                    ForEach(PinStatus.allCases, id: \.rawValue) {
                        Label($0.rawValue, systemImage: $0.icon).tag($0.rawValue)
                    }
                }
                Picker("Öncelik", selection: $pin.priorityRaw) {
                    ForEach(PinPriority.allCases, id: \.rawValue) {
                        Text($0.rawValue).tag($0.rawValue)
                    }
                }
            }
            if !pin.pinDetails.isEmpty {
                Section("Detay") { Text(pin.pinDetails) }
            }
            // FAZ 17.12 — Fotoğraf gösterimi
            if let data = pin.photoData, let img = UIImage(data: data) {
                Section("Fotoğraf") {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .navigationTitle(pin.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pin.statusRaw) { _, _ in
            do { try context.save() } catch { print("DrawingPinDetailView save error: \(error)") }
        }
        .onChange(of: pin.priorityRaw) { _, _ in
            do { try context.save() } catch { print("DrawingPinDetailView save error: \(error)") }
        }
    }
}

// MARK: - Add Drawing Pin View

struct AddDrawingPinView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existingPins: [DrawingPin]

    @State private var drawingName = ""
    @State private var title = ""
    @State private var pinDetails = ""
    @State private var category = PinCategory.general
    @State private var priority = PinPriority.medium
    @State private var assignedTo = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(7 * 86400)
    @State private var createdBy = ""
    @State private var xStr = "0.5"
    @State private var yStr = "0.5"
    // FAZ 17.12 — Fotoğraf
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Pin Bilgileri") {
                    TextField("Çizim Adı / Pafta No", text: $drawingName)
                    TextField("Başlık", text: $title)
                    Picker("Kategori", selection: $category) {
                        ForEach(PinCategory.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                        }
                    }
                    Picker("Öncelik", selection: $priority) {
                        ForEach(PinPriority.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }
                Section("Atama") {
                    TextField("Atanan Kişi", text: $assignedTo)
                    TextField("Oluşturan", text: $createdBy)
                    Toggle("Son Tarih Ekle", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Son Tarih", selection: $dueDate, displayedComponents: .date)
                    }
                }
                Section("Konum (0.0 - 1.0)") {
                    HStack {
                        Text("X:")
                        TextField("0.5", text: $xStr).keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Y:")
                        TextField("0.5", text: $yStr).keyboardType(.decimalPad)
                    }
                }
                Section("Detay") {
                    TextField("Açıklama", text: $pinDetails, axis: .vertical).lineLimit(3...6)
                }
                // FAZ 17.12 — Fotoğraf
                Section("Fotoğraf") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        if let data = photoData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable().scaledToFit().frame(maxHeight: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Fotoğraf Ekle", systemImage: "photo.badge.plus")
                        }
                    }
                    .onChange(of: photoItem) { _, item in
                        Task {
                            photoData = try? await item?.loadTransferable(type: Data.self)
                        }
                    }
                }
            }
            .navigationTitle("Yeni Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }.disabled(title.isEmpty || drawingName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let x = Double(xStr.replacingOccurrences(of: ",", with: ".")) ?? 0.5
        let y = Double(yStr.replacingOccurrences(of: ",", with: ".")) ?? 0.5
        let pin = DrawingPin(pinNumber: DrawingPin.generateNumber(existingCount: existingPins.count),
                             drawingName: drawingName, title: title,
                             xPosition: min(1, max(0, x)), yPosition: min(1, max(0, y)))
        pin.category = category
        pin.priority = priority
        pin.pinDetails = pinDetails
        pin.assignedTo = assignedTo
        pin.createdBy = createdBy
        if hasDueDate { pin.dueDate = dueDate }
        pin.photoData = photoData
        context.insert(pin)
        do { try context.save() } catch { print("AddDrawingPinView save error: \(error)") }
        dismiss()
    }
}
