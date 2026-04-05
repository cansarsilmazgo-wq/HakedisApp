import SwiftUI
import SwiftData

// MARK: - Survey List View

struct SurveyListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Survey.createdAt, order: .reverse) private var surveys: [Survey]
    @State private var showAdd = false
    @State private var searchText = ""

    private var filtered: [Survey] {
        if searchText.isEmpty { return surveys }
        return surveys.filter {
            $0.surveyName.localizedCaseInsensitiveContains(searchText) ||
            $0.surveyNo.localizedCaseInsensitiveContains(searchText) ||
            $0.projectName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { survey in
                    NavigationLink(destination: SurveyDetailView(survey: survey)) {
                        SurveyRow(survey: survey)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Keşif Çalışmaları")
            .searchable(text: $searchText, prompt: "Keşif ara...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddSurveyView()
            }
            .overlay {
                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "ruler",
                        title: "Keşif Yok",
                        subtitle: "Yeni keşif çalışması ekleyin"
                    )
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(filtered[i]) }
        do { try context.save() } catch { print("SurveyListView delete error: \(error)") }
    }
}

private struct SurveyRow: View {
    let survey: Survey
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(survey.surveyNo).font(.caption).foregroundColor(.secondary)
                Spacer()
                StatusBadge(text: survey.status.rawValue, color: statusColor(survey.status))
            }
            Text(survey.surveyName).font(.headline)
            Text(survey.projectName).font(.subheadline).foregroundColor(.secondary)
            HStack {
                Label("\(survey.totalItems) poz", systemImage: "list.bullet")
                    .font(.caption)
                Spacer()
                Text(survey.totalEstimatedCost.currencyFormatted)
                    .font(.caption).bold().foregroundColor(.hakedisOrange)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ s: SurveyStatus) -> Color {
        switch s {
        case .draft: return .secondary
        case .inProgress: return .hakedisWarning
        case .completed: return .hakedisSuccess
        case .approved: return .hakedisOrange
        }
    }
}

// MARK: - Survey Detail View

struct SurveyDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var survey: Survey
    @State private var showAddLocation = false

    var body: some View {
        List {
            Section("Bilgiler") {
                LabeledContent("Keşif No", value: survey.surveyNo)
                LabeledContent("Proje", value: survey.projectName)
                LabeledContent("Hazırlayan", value: survey.preparedBy)
                LabeledContent("Durum", value: survey.status.rawValue)
                LabeledContent("Toplam Maliyet", value: survey.totalEstimatedCost.currencyFormatted)
            }
            if !survey.notes.isEmpty {
                Section("Notlar") { Text(survey.notes).font(.subheadline) }
            }
            Section {
                ForEach(survey.locations.sorted(by: { $0.sortOrder < $1.sortOrder })) { loc in
                    NavigationLink(destination: SurveyLocationDetailView(location: loc)) {
                        SurveyLocationRow(location: loc)
                    }
                }
                .onDelete { idx in
                    let sorted = survey.locations.sorted(by: { $0.sortOrder < $1.sortOrder })
                    for i in idx {
                        if let pos = survey.locations.firstIndex(where: { $0.id == sorted[i].id }) {
                            context.delete(survey.locations[pos])
                            survey.locations.remove(at: pos)
                        }
                    }
                    do { try context.save() } catch { print("SurveyDetailView delete error: \(error)") }
                }
            } header: {
                HStack {
                    Text("Mahal / Bölümler")
                    Spacer()
                    Button { showAddLocation = true } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle(survey.surveyName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddLocation) {
            AddSurveyLocationView(survey: survey)
        }
    }
}

private struct SurveyLocationRow: View {
    let location: SurveyLocation
    var body: some View {
        HStack {
            Image(systemName: location.locationType.icon)
                .foregroundColor(.hakedisOrange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(location.locationName).font(.headline)
                Text("\(location.items.count) poz").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(location.subtotal.currencyFormatted)
                .font(.subheadline).bold().foregroundColor(.hakedisOrange)
        }
    }
}

// MARK: - Survey Location Detail View

struct SurveyLocationDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var location: SurveyLocation
    @State private var showAddItem = false

    var body: some View {
        List {
            Section("Özet") {
                LabeledContent("Tür", value: location.locationType.rawValue)
                LabeledContent("Toplam", value: location.subtotal.currencyFormatted)
                LabeledContent("Poz Sayısı", value: "\(location.items.count)")
            }
            Section {
                ForEach(location.items) { item in
                    SurveyItemRow(item: item)
                }
                .onDelete { idx in
                    for i in idx { context.delete(location.items[i]) }
                    location.items.remove(atOffsets: idx)
                    do { try context.save() } catch { print("SurveyLocationDetailView delete error: \(error)") }
                }
            } header: {
                HStack {
                    Text("Pozlar")
                    Spacer()
                    Button { showAddItem = true } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle(location.locationName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddItem) {
            AddSurveyItemView(location: location)
        }
    }
}

private struct SurveyItemRow: View {
    let item: SurveyItem
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.pozCode).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(item.estimatedTotal.currencyFormatted)
                    .font(.subheadline).bold().foregroundColor(.hakedisOrange)
            }
            Text(item.pozName).font(.headline)
            HStack {
                Text("\(item.quantity.quantityFormatted) \(item.unit)")
                    .font(.caption)
                Text("×")
                    .font(.caption).foregroundColor(.secondary)
                Text(item.unitPrice.currencyFormatted)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Survey Views

struct AddSurveyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var surveys: [Survey]

    @State private var surveyName = ""
    @State private var projectName = ""
    @State private var preparedBy = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Keşif Bilgileri") {
                    TextField("Keşif Adı", text: $surveyName)
                    TextField("Proje Adı", text: $projectName)
                    TextField("Hazırlayan", text: $preparedBy)
                }
                Section("Notlar") {
                    TextField("Notlar", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Yeni Keşif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(surveyName.isEmpty || projectName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let no = Survey.generateNo(existingCount: surveys.count, year: year)
        let s = Survey(surveyNo: no, surveyName: surveyName, projectName: projectName, preparedBy: preparedBy)
        s.notes = notes
        context.insert(s)
        do { try context.save() } catch { print("AddSurveyView save error: \(error)") }
        dismiss()
    }
}

struct AddSurveyLocationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var survey: Survey

    @State private var locationName = ""
    @State private var locationType = LocationType.floor

    var body: some View {
        NavigationStack {
            Form {
                Section("Mahal Bilgileri") {
                    TextField("Mahal Adı (örn. 1. Kat)", text: $locationName)
                    Picker("Tür", selection: $locationType) {
                        ForEach(LocationType.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                        }
                    }
                }
            }
            .navigationTitle("Mahal Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }.disabled(locationName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let loc = SurveyLocation(locationName: locationName, type: locationType, sortOrder: survey.locations.count)
        loc.survey = survey
        context.insert(loc)
        survey.locations.append(loc)
        do { try context.save() } catch { print("AddSurveyLocationView save error: \(error)") }
        dismiss()
    }
}

struct AddSurveyItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var location: SurveyLocation

    @State private var pozCode = ""
    @State private var pozName = ""
    @State private var unit = "m²"
    @State private var quantityStr = ""
    @State private var unitPriceStr = ""
    @State private var notes = ""

    private let units = ["m²", "m³", "m", "adet", "kg", "ton", "lt", "takım", "gün"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Poz Bilgileri") {
                    TextField("Poz Kodu", text: $pozCode)
                    TextField("Poz Adı", text: $pozName)
                    Picker("Birim", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Miktar", text: $quantityStr)
                        .keyboardType(.decimalPad)
                    TextField("Birim Fiyat (₺)", text: $unitPriceStr)
                        .keyboardType(.decimalPad)
                }
                if !quantityStr.isEmpty && !unitPriceStr.isEmpty {
                    let q = Double(quantityStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                    let p = Double(unitPriceStr.replacingOccurrences(of: ",", with: ".")) ?? 0
                    Section("Tutar") {
                        LabeledContent("Toplam", value: (q * p).currencyFormatted)
                    }
                }
                Section("Notlar") {
                    TextField("Notlar", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Poz Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }.disabled(pozName.isEmpty || quantityStr.isEmpty)
                }
            }
        }
    }

    private func save() {
        let q = Double(quantityStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let p = Double(unitPriceStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let item = SurveyItem(pozCode: pozCode, pozName: pozName, unit: unit, quantity: q, unitPrice: p)
        item.notes = notes
        item.location = location
        context.insert(item)
        location.items.append(item)
        do { try context.save() } catch { print("AddSurveyItemView save error: \(error)") }
        dismiss()
    }
}
