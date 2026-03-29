import SwiftUI
import SwiftData

// MARK: - Handover Warning Banner (ContractDetailView üstüne eklenir)

struct HandoverWarningBanner: View {
    let contract: Contract
    @State private var showingAdd = false

    var body: some View {
        if contract.handoverRecords.isEmpty {
            Button {
                showingAdd = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.hakedisWarning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Yer Teslim Tutanağı Yok")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        Text("Saha girişi öncesinde yer teslim tutanağı oluşturun")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.hakedisOrange)
                }
                .padding(12)
                .background(Color.hakedisWarning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .sheet(isPresented: $showingAdd) {
                AddSiteHandoverView(contract: contract)
            }
        } else if contract.openDeficiencyCount > 0 {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.hakedisDanger)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(contract.openDeficiencyCount) Açık Eksiklik")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("Eksiklikler kapatılmadan proje tamamlanamaz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.hakedisDanger.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }
}

// MARK: - Handover Section (ContractDetailView içinde)

struct SiteHandoverSection: View {
    @Environment(\.modelContext) private var modelContext
    let contract: Contract
    @State private var showingAdd = false
    @State private var selectedRecord: SiteHandoverRecord?

    private var sorted: [SiteHandoverRecord] {
        contract.handoverRecords.sorted { $0.handoverDate > $1.handoverDate }
    }

    var body: some View {
        Section {
            HandoverWarningBanner(contract: contract)

            ForEach(sorted) { record in
                Button {
                    selectedRecord = record
                } label: {
                    HandoverRecordRow(record: record)
                }
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text("Yer Teslim Tutanakları")
                Spacer()
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.hakedisOrange)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddSiteHandoverView(contract: contract)
        }
        .sheet(item: $selectedRecord) { record in
            SiteHandoverDetailView(record: record)
        }
    }
}

// MARK: - Handover Record Row

struct HandoverRecordRow: View {
    let record: SiteHandoverRecord

    private var sigColor: Color {
        switch record.signatureStatus {
        case .taslak:              return .secondary
        case .yukleniciImzaladi:   return .hakedisWarning
        case .idareImzaladi:       return .hakedisWarning
        case .tamamlandi:          return .hakedisSuccess
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(record.handoverType.rawValue, systemImage: "mappin.and.ellipse")
                    .font(.subheadline.bold())
                Spacer()
                StatusBadge(text: record.signatureStatus.rawValue, color: sigColor)
            }
            HStack {
                Text(record.handoverDate.shortFormatted)
                    .font(.caption).foregroundColor(.secondary)
                if !record.location.isEmpty {
                    Text("· \(record.location)")
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if record.hasOpenDeficiencies {
                    Label("\(record.openDeficiencyCount) eksiklik",
                          systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.hakedisDanger)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Handover View

struct AddSiteHandoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let contract: Contract

    @State private var handoverType: HandoverType = .teslimAl
    @State private var handoverDate = Date()
    @State private var contractorRep = ""
    @State private var ownerRep = ""
    @State private var location = ""
    @State private var existingCondition = ""
    @State private var weather = ""
    @State private var notes = ""
    @State private var witnesses = ""

    var isValid: Bool {
        !contractorRep.trimmingCharacters(in: .whitespaces).isEmpty &&
        !ownerRep.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tutanak Bilgileri") {
                    Picker("Tutanak Türü", selection: $handoverType) {
                        ForEach(HandoverType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    DatePicker("Tarih", selection: $handoverDate, displayedComponents: .date)
                }

                Section("Temsilciler") {
                    TextField("Yüklenici Temsilcisi *", text: $contractorRep)
                    TextField("İdare Temsilcisi *", text: $ownerRep)
                    TextField("Şahitler (virgülle ayırın)", text: $witnesses)
                }

                Section("Konum") {
                    TextField("Adres / Açıklama", text: $location)
                    Text("GPS konum bilgisi tutanağa otomatik eklenir")
                        .font(.caption2).foregroundColor(.secondary)
                }

                Section("Mevcut Durum") {
                    TextEditor(text: $existingCondition)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if existingCondition.isEmpty {
                                Text("Sahayı teslim anındaki mevcut durum açıklaması…")
                                    .foregroundColor(.secondary).font(.body)
                                    .padding(.top, 8).padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                    TextField("Hava Durumu", text: $weather)
                }

                Section("Notlar") {
                    TextField("Ek notlar…", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                }
            }
            .navigationTitle("Yer Teslim Tutanağı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") { save() }
                        .bold()
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let record = SiteHandoverRecord(
            handoverType: handoverType,
            handoverDate: handoverDate,
            contractorRepName: contractorRep,
            ownerRepName: ownerRep,
            location: location,
            existingCondition: existingCondition
        )
        record.weatherCondition = weather.isEmpty ? nil : weather
        record.notes = notes.isEmpty ? nil : notes
        if !witnesses.isEmpty {
            let ws = witnesses.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
            record.witnessNamesJSON = (try? String(data: JSONEncoder().encode(ws), encoding: .utf8) ?? nil) ?? nil
        }
        record.contract = contract
        contract.handoverRecords.append(record)
        modelContext.insert(record)
        dismiss()
    }
}

// MARK: - Handover Detail View

struct SiteHandoverDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var record: SiteHandoverRecord

    @State private var showingAddDeficiency = false
    @State private var selectedDeficiency: SiteDeficiency?

    private var witnesses: [String] {
        guard let json = record.witnessNamesJSON,
              let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return arr
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Tutanak Bilgileri") {
                    LabeledContent("Tür", value: record.handoverType.rawValue)
                    LabeledContent("Tarih", value: record.handoverDate.shortFormatted)
                    LabeledContent("Yüklenici Tem.", value: record.contractorRepName)
                    LabeledContent("İdare Tem.", value: record.ownerRepName)
                    if !witnesses.isEmpty {
                        LabeledContent("Şahitler", value: witnesses.joined(separator: ", "))
                    }
                    if let w = record.weatherCondition, !w.isEmpty {
                        LabeledContent("Hava", value: w)
                    }
                    if !record.location.isEmpty {
                        LabeledContent("Konum", value: record.location)
                    }
                }

                Section("İmza Durumu") {
                    Picker("İmza Durumu", selection: $record.signatureStatus) {
                        ForEach(HandoverSignatureStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                if !record.existingCondition.isEmpty {
                    Section("Mevcut Durum") {
                        Text(record.existingCondition)
                            .font(.subheadline)
                    }
                }

                // Eksiklikler
                Section {
                    if record.deficiencies.isEmpty {
                        Text("Eksiklik bulunmuyor")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(record.deficiencies.sorted { !$0.isClosed && $1.isClosed }) { def in
                            DeficiencyRow(deficiency: def)
                        }
                    }
                    Button {
                        showingAddDeficiency = true
                    } label: {
                        Label("Eksiklik Ekle", systemImage: "plus.circle")
                            .foregroundColor(.hakedisOrange)
                    }
                } header: {
                    HStack {
                        Text("Eksiklikler")
                        Spacer()
                        if record.openDeficiencyCount > 0 {
                            StatusBadge(text: "\(record.openDeficiencyCount) açık",
                                        color: .hakedisDanger)
                        }
                    }
                }

                if let n = record.notes, !n.isEmpty {
                    Section("Notlar") { Text(n).font(.subheadline) }
                }
            }
            .navigationTitle(record.handoverType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Kapat") { dismiss() } }
            }
            .sheet(isPresented: $showingAddDeficiency) {
                AddDeficiencyView(record: record)
            }
        }
    }
}

// MARK: - Deficiency Row

struct DeficiencyRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deficiency: SiteDeficiency

    var body: some View {
        HStack(spacing: 10) {
            Button {
                deficiency.isClosed.toggle()
                if deficiency.isClosed { deficiency.closedDate = Date() }
                else { deficiency.closedDate = nil }
            } label: {
                Image(systemName: deficiency.isClosed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(deficiency.isClosed ? .hakedisSuccess :
                                     deficiency.isOverdue ? .hakedisDanger : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(deficiency.title)
                    .font(.subheadline)
                    .strikethrough(deficiency.isClosed)
                    .foregroundColor(deficiency.isClosed ? .secondary : .primary)
                HStack(spacing: 8) {
                    if !deficiency.responsiblePerson.isEmpty {
                        Label(deficiency.responsiblePerson, systemImage: "person.fill")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    if !deficiency.isClosed {
                        Label(deficiency.completionDate.shortFormatted, systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(deficiency.isOverdue ? .hakedisDanger : .secondary)
                    } else if let cd = deficiency.closedDate {
                        Label("Kapandı: \(cd.shortFormatted)", systemImage: "checkmark")
                            .font(.caption2).foregroundColor(.hakedisSuccess)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Deficiency View

struct AddDeficiencyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let record: SiteHandoverRecord

    @State private var title = ""
    @State private var responsible = ""
    @State private var completionDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
    @State private var notes = ""

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Eksiklik") {
                    TextField("Eksiklik Tanımı *", text: $title, axis: .vertical)
                        .lineLimit(2...)
                    TextField("Sorumlu Kişi", text: $responsible)
                    DatePicker("Tamamlanma Tarihi", selection: $completionDate, displayedComponents: .date)
                    TextField("Notlar", text: $notes, axis: .vertical)
                        .lineLimit(2...)
                }
            }
            .navigationTitle("Eksiklik Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }
                        .bold().disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let def = SiteDeficiency(title: title, responsiblePerson: responsible, completionDate: completionDate)
        def.notes = notes.isEmpty ? nil : notes
        def.record = record
        record.deficiencies.append(def)
        modelContext.insert(def)
        dismiss()
    }
}

// MARK: - Dashboard Deficiency Card

struct DeficiencyAlertCard: View {
    let contract: Contract

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.hakedisDanger)
                Text(contract.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text("\(contract.openDeficiencyCount) açık")
                    .font(.caption.bold())
                    .foregroundColor(.hakedisDanger)
            }
            if let p = contract.project {
                Text(p.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
