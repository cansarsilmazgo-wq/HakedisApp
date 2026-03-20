import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Daily Entry List
struct DailyEntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyEntry.date, order: .reverse) private var entries: [DailyEntry]
    @State private var showingAdd = false
    @State private var selectedDate = Date()

    private var entriesForSelectedDate: [DailyEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date Picker Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(-6...0, id: \.self) { offset in
                            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                            DateChip(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)) {
                                selectedDate = date
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.hakedisCard)

                // Entries
                if entriesForSelectedDate.isEmpty {
                    VStack {
                        Spacer()
                        EmptyStateView(
                            icon: "pencil.and.list.clipboard",
                            title: "Bu gün için kayıt yok",
                            subtitle: "Saha çalışmalarını buradan girin",
                            actionTitle: "Giriş Ekle",
                            action: { showingAdd = true }
                        )
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(entriesForSelectedDate) { entry in
                            DailyEntryRow(entry: entry)
                        }
                        .onDelete { offsets in
                            offsets.map { entriesForSelectedDate[$0] }.forEach { modelContext.delete($0) }
                        }
                    }
                }
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Saha Girişi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddDailyEntryView(date: selectedDate)
            }
        }
    }
}

// MARK: - Date Chip
struct DateChip: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayAbbr)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(dayNumber)
                    .font(.subheadline.bold())
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(width: 44, height: 52)
            .background(isSelected ? Color.hakedisOrange : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var dayAbbr: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - Daily Entry Row
struct DailyEntryRow: View {
    let entry: DailyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.workItem?.name ?? "İş kalemi silinmiş")
                        .font(.subheadline.bold())
                    if let workItem = entry.workItem {
                        Text(workItem.contract?.contractor?.name ?? "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.quantity.quantityFormatted) \(entry.workItem?.unit ?? "")")
                        .font(.subheadline.bold())
                        .foregroundStyle(.hakedisOrange)
                    if !entry.location.isEmpty {
                        Text(entry.location)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !entry.photoData.isEmpty {
                Label("\(entry.photoData.count) fotoğraf", systemImage: "photo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Daily Entry (Critical Screen)
struct AddDailyEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contracts: [Contract]

    let date: Date

    @State private var selectedContract: Contract?
    @State private var selectedWorkItem: WorkItem?
    @State private var quantity = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var entryDate: Date

    init(date: Date) {
        self.date = date
        _entryDate = State(initialValue: date)
    }

    private var workItems: [WorkItem] {
        selectedContract?.workItems ?? []
    }

    var isValid: Bool {
        selectedWorkItem != nil &&
        (Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private var parsedQuantity: Double {
        Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date
                Section {
                    DatePicker("Tarih", selection: $entryDate, displayedComponents: .date)
                }

                // Contract + Work Item (cascade selection)
                Section("İş Kalemi Seç") {
                    if contracts.isEmpty {
                        Text("Önce sözleşme ve iş kalemi tanımlayın")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        Picker("Sözleşme", selection: $selectedContract) {
                            Text("Seçiniz").tag(Optional<Contract>.none)
                            ForEach(contracts) { c in
                                Text("\(c.title) — \(c.contractor?.name ?? "")").tag(Optional(c))
                            }
                        }
                        .onChange(of: selectedContract) { _, _ in
                            selectedWorkItem = nil
                        }

                        if let contract = selectedContract {
                            Picker("İş Kalemi", selection: $selectedWorkItem) {
                                Text("Seçiniz").tag(Optional<WorkItem>.none)
                                ForEach(contract.workItems) { item in
                                    Text("[\(item.code)] \(item.name)").tag(Optional(item))
                                }
                            }
                        }
                    }
                }

                // Quantity + Location
                Section("Miktar") {
                    HStack {
                        TextField("Yapılan miktar *", text: $quantity)
                            .keyboardType(.decimalPad)
                        if let item = selectedWorkItem {
                            Text(item.unit)
                                .foregroundStyle(.secondary)
                        }
                    }
                    TextField("Mahal / Kat / Blok", text: $location)
                }

                // Work Item info (helper)
                if let item = selectedWorkItem {
                    Section("Poz Durumu") {
                        HStack {
                            Label("Sözleşme miktarı", systemImage: "doc")
                            Spacer()
                            Text("\(item.contractedQuantity.quantityFormatted) \(item.unit)")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Bugüne kadar yapılan", systemImage: "checkmark.circle")
                            Spacer()
                            Text("\(item.completedQuantity.quantityFormatted) \(item.unit)")
                                .foregroundStyle(.hakedisSuccess)
                        }
                        HStack {
                            Label("Kalan", systemImage: "clock")
                            Spacer()
                            let remaining = item.remainingQuantity - parsedQuantity
                            Text("\(remaining.quantityFormatted) \(item.unit)")
                                .foregroundStyle(remaining < 0 ? .hakedisDanger : .primary)
                        }
                    }
                }

                // Notes
                Section("Not") {
                    TextField("Opsiyonel not...", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                // Photos
                Section("Fotoğraflar") {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5,
                                matching: .images) {
                        Label("Fotoğraf Ekle", systemImage: "camera")
                            .foregroundStyle(.hakedisOrange)
                    }
                    .onChange(of: selectedPhotos) { _, newItems in
                        loadPhotos(newItems)
                    }

                    if !photoData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(photoData.indices, id: \.self) { i in
                                    if let ui = UIImage(data: photoData[i]) {
                                        Image(uiImage: ui)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saha Girişi")
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

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        photoData = []
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data {
                    DispatchQueue.main.async { photoData.append(data) }
                }
            }
        }
    }

    private func save() {
        guard let workItem = selectedWorkItem,
              let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) else { return }

        let entry = DailyEntry(date: entryDate, quantity: qty, location: location, notes: notes)
        entry.photoData = photoData
        entry.workItem = workItem
        workItem.dailyEntries.append(entry)
        modelContext.insert(entry)
        dismiss()
    }
}
