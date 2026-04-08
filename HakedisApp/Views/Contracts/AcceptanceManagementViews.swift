import SwiftUI
import SwiftData

// MARK: - Provisional Acceptance List View

struct ProvisionalAcceptanceView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ProvisionalAcceptance.createdAt, order: .reverse) private var acceptances: [ProvisionalAcceptance]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                if acceptances.contains(where: \.isWarrantyExpiring) {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisWarning)
                            Text("Garanti bitiş tarihi yaklaşıyor").foregroundColor(.hakedisWarning)
                                .font(.subheadline)
                        }
                    }
                }
                ForEach(acceptances) { acc in
                    NavigationLink(destination: ProvisionalAcceptanceDetailView(acceptance: acc)) {
                        ProvisionalAcceptanceRow(acceptance: acc)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Geçici Kabul")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddProvisionalAcceptanceView() }
            .overlay {
                if acceptances.isEmpty {
                    EmptyStateView(icon: "checkmark.seal", title: "Kabul Kaydı Yok",
                                   subtitle: "Geçici kabul kaydı ekleyin")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(acceptances[i]) }
        do { try context.save() } catch { print("ProvisionalAcceptanceView delete error: \(error)") }
    }
}

private struct ProvisionalAcceptanceRow: View {
    let acceptance: ProvisionalAcceptance
    private var statusColor: Color {
        switch acceptance.status {
        case .pending: return .hakedisWarning
        case .inProgress: return .hakedisOrange
        case .acceptedWithDeficiency: return .hakedisWarning
        case .accepted: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(acceptance.acceptanceNo).font(.caption).foregroundColor(.secondary)
                Spacer()
                if acceptance.isWarrantyExpiring {
                    Image(systemName: "clock.badge.exclamationmark").foregroundColor(.hakedisWarning).font(.caption)
                }
                StatusBadge(text: acceptance.status.rawValue, color: statusColor)
            }
            Text(acceptance.contractorName).font(.headline)
            Text(acceptance.contractNo).font(.subheadline).foregroundColor(.secondary)
            HStack {
                Label(acceptance.scheduledDate.formatted(date: .abbreviated, time: .omitted),
                      systemImage: "calendar").font(.caption)
                if acceptance.openDeficiencyCount > 0 {
                    Spacer()
                    Label("\(acceptance.openDeficiencyCount) açık eksiklik", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundColor(.hakedisDanger)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Provisional Acceptance Detail View

struct ProvisionalAcceptanceDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var acceptance: ProvisionalAcceptance
    @State private var showAddDeficiency = false

    var body: some View {
        List {
            Section("Bilgiler") {
                LabeledContent("Kabul No", value: acceptance.acceptanceNo)
                LabeledContent("Sözleşme No", value: acceptance.contractNo)
                LabeledContent("Yüklenici", value: acceptance.contractorName)
                LabeledContent("Planlanan Tarih", value: acceptance.scheduledDate.formatted(date: .long, time: .omitted))
                if let ad = acceptance.acceptanceDate {
                    LabeledContent("Kabul Tarihi", value: ad.formatted(date: .long, time: .omitted))
                }
                LabeledContent("Garanti Süresi", value: "\(acceptance.warrantyPeriodMonths) ay")
                if let end = acceptance.warrantyEndDate {
                    HStack {
                        Text("Garanti Bitiş")
                        Spacer()
                        Text(end.formatted(date: .long, time: .omitted))
                            .foregroundColor(acceptance.isWarrantyExpiring ? .hakedisWarning :
                                               (acceptance.isWarrantyExpired ? .hakedisDanger : .primary))
                    }
                }
            }
            Section("Durum") {
                Picker("Durum", selection: $acceptance.statusRaw) {
                    ForEach(AcceptanceStatus.allCases, id: \.rawValue) {
                        Label($0.rawValue, systemImage: $0.icon).tag($0.rawValue)
                    }
                }
            }
            Section {
                ForEach(acceptance.deficiencies) { def in
                    AcceptanceDeficiencyRow(deficiency: def)
                }
                .onDelete { idx in
                    for i in idx { context.delete(acceptance.deficiencies[i]) }
                    acceptance.deficiencies.remove(atOffsets: idx)
                    do { try context.save() } catch { print("ProvisionalAcceptanceDetailView delete error: \(error)") }
                }
            } header: {
                HStack {
                    Text("Eksiklikler (\(acceptance.openDeficiencyCount) açık)")
                    Spacer()
                    Button { showAddDeficiency = true } label: { Image(systemName: "plus.circle") }
                }
            }
            // FAZ 17.10 — Komisyon üyeleri
            if !acceptance.commissionMembers.isEmpty {
                Section("Komisyon Üyeleri") {
                    ForEach(acceptance.commissionMembers) { member in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name).font(.subheadline)
                                Text("\(member.title) — \(member.affiliation)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if member.isSigned {
                                Image(systemName: "signature")
                                    .foregroundColor(.hakedisSuccess)
                                    .accessibilityLabel("İmzalandı")
                            }
                        }
                    }
                }
            }
            if !acceptance.acceptanceNotes.isEmpty {
                Section("Notlar") { Text(acceptance.acceptanceNotes) }
            }
        }
        .navigationTitle(acceptance.contractorName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: acceptance.statusRaw) { _, _ in
            do { try context.save() } catch { print("ProvisionalAcceptanceDetailView save error: \(error)") }
        }
        .sheet(isPresented: $showAddDeficiency) { AddAcceptanceDeficiencyView(acceptance: acceptance) }
    }
}

private struct AcceptanceDeficiencyRow: View {
    let deficiency: AcceptanceDeficiency
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(deficiency.deficiencyNo): \(deficiency.deficiencyText)").font(.subheadline)
                if !deficiency.location.isEmpty {
                    Text(deficiency.location).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            StatusBadge(text: deficiency.status.rawValue,
                        color: deficiency.status == .resolved ? .hakedisSuccess :
                            (deficiency.isOverdue ? .hakedisDanger : .hakedisWarning))
        }
    }
}

// MARK: - Final Acceptance View

struct FinalAcceptanceView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FinalAcceptance.createdAt, order: .reverse) private var acceptances: [FinalAcceptance]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(acceptances) { acc in
                    NavigationLink(destination: FinalAcceptanceDetailView(acceptance: acc)) {
                        FinalAcceptanceRowView(acceptance: acc)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Kesin Kabul")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddFinalAcceptanceView() }
            .overlay {
                if acceptances.isEmpty {
                    EmptyStateView(icon: "checkmark.seal.fill", title: "Kesin Kabul Yok",
                                   subtitle: "Kesin kabul kaydı ekleyin")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(acceptances[i]) }
        do { try context.save() } catch { print("FinalAcceptanceView delete error: \(error)") }
    }
}

private struct FinalAcceptanceRowView: View {
    let acceptance: FinalAcceptance
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(acceptance.acceptanceNo).font(.caption).foregroundColor(.secondary)
                Spacer()
                StatusBadge(text: acceptance.status.rawValue,
                            color: acceptance.status == .accepted ? .hakedisSuccess : .hakedisOrange)
            }
            Text(acceptance.contractorName).font(.headline)
            Text(acceptance.contractNo).font(.subheadline).foregroundColor(.secondary)
            Label(acceptance.scheduledDate.formatted(date: .abbreviated, time: .omitted),
                  systemImage: "calendar").font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Final Acceptance Detail View

struct FinalAcceptanceDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var acceptance: FinalAcceptance

    var body: some View {
        List {
            Section("Bilgiler") {
                LabeledContent("Kabul No", value: acceptance.acceptanceNo)
                LabeledContent("Sözleşme No", value: acceptance.contractNo)
                LabeledContent("Yüklenici", value: acceptance.contractorName)
                LabeledContent("Planlanan Tarih", value: acceptance.scheduledDate.formatted(date: .long, time: .omitted))
                if let ad = acceptance.acceptanceDate {
                    LabeledContent("Kabul Tarihi", value: ad.formatted(date: .long, time: .omitted))
                }
                if let grd = acceptance.guaranteeReturnDate {
                    LabeledContent("Teminat İade Tarihi", value: grd.formatted(date: .long, time: .omitted))
                }
                if let rrd = acceptance.retentionReleaseDate {
                    LabeledContent("Stopaj İade Tarihi", value: rrd.formatted(date: .long, time: .omitted))
                }
            }
            Section("Durum") {
                Picker("Durum", selection: $acceptance.statusRaw) {
                    ForEach(AcceptanceStatus.allCases, id: \.rawValue) {
                        Label($0.rawValue, systemImage: $0.icon).tag($0.rawValue)
                    }
                }
            }
            if !acceptance.finalAcceptanceNotes.isEmpty {
                Section("Notlar") { Text(acceptance.finalAcceptanceNotes) }
            }
        }
        .navigationTitle(acceptance.contractorName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: acceptance.statusRaw) { _, _ in
            do { try context.save() } catch { print("FinalAcceptanceDetailView save error: \(error)") }
        }
    }
}

// MARK: - Deficiency Tracking View

struct DeficiencyTrackingView: View {
    @Query private var acceptances: [ProvisionalAcceptance]

    private var openDeficiencies: [(AcceptanceDeficiency, String)] {
        acceptances.flatMap { acc in
            acc.deficiencies.filter { $0.status != .resolved }.map { ($0, acc.contractorName) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Açık Eksiklikler (\(openDeficiencies.count))") {
                    ForEach(openDeficiencies, id: \.0.id) { def, contractor in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(contractor).font(.caption).foregroundColor(.secondary)
                                Spacer()
                                StatusBadge(text: def.status.rawValue,
                                            color: def.isOverdue ? .hakedisDanger : .hakedisWarning)
                            }
                            Text("#\(def.deficiencyNo): \(def.deficiencyText)").font(.subheadline)
                            if !def.location.isEmpty {
                                Text(def.location).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Eksiklik Takibi")
        }
    }
}

// MARK: - Add Forms

struct AddProvisionalAcceptanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [ProvisionalAcceptance]

    @State private var contractorName = ""
    @State private var contractNo = ""
    @State private var scheduledDate = Date()
    @State private var warrantyMonths = 12
    @State private var notes = ""
    // FAZ 17.10 — Komisyon üyeleri
    struct MemberEntry: Identifiable {
        var id = UUID()
        var name = ""
        var title = ""
        var affiliation = ""
    }
    @State private var memberEntries: [MemberEntry] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Yüklenici Adı", text: $contractorName)
                    TextField("Sözleşme No", text: $contractNo)
                    DatePicker("Planlanan Tarih", selection: $scheduledDate, displayedComponents: .date)
                    Stepper("Garanti Süresi: \(warrantyMonths) ay", value: $warrantyMonths, in: 1...60)
                }
                // FAZ 17.10 — Komisyon üyeleri
                Section {
                    ForEach($memberEntries) { $m in
                        VStack(spacing: 4) {
                            TextField("Ad Soyad", text: $m.name)
                            TextField("Unvan", text: $m.title)
                            TextField("Kurum", text: $m.affiliation)
                        }
                    }
                    .onDelete { memberEntries.remove(atOffsets: $0) }
                    Button { memberEntries.append(MemberEntry()) } label: {
                        Label("Komisyon Üyesi Ekle", systemImage: "plus.circle")
                            .foregroundColor(.hakedisOrange)
                    }
                } header: {
                    Text("Kabul Komisyonu")
                }
                Section("Notlar") {
                    TextField("Notlar", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Geçici Kabul")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(contractorName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let year = Calendar.current.component(.year, from: Date())
        let no = ProvisionalAcceptance.generateNo(existingCount: existing.count, year: year)
        let acc = ProvisionalAcceptance(acceptanceNo: no, contractNo: contractNo,
                                        contractorName: contractorName, scheduledDate: scheduledDate)
        acc.warrantyPeriodMonths = warrantyMonths
        acc.acceptanceNotes = notes
        acc.warrantyEndDate = Calendar.current.date(byAdding: .month, value: warrantyMonths, to: scheduledDate)
        // FAZ 17.10 — Komisyon üyeleri kaydet
        let members = memberEntries.filter { !$0.name.isEmpty }.map { entry in
            CommissionMember(id: UUID(), name: entry.name, title: entry.title,
                             affiliation: entry.affiliation, isSigned: false)
        }
        acc.commissionMembers = members
        context.insert(acc)
        do { try context.save() } catch { print("AddProvisionalAcceptanceView save error: \(error)") }
        dismiss()
    }
}

struct AddFinalAcceptanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [FinalAcceptance]

    @State private var contractorName = ""
    @State private var contractNo = ""
    @State private var scheduledDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Yüklenici Adı", text: $contractorName)
                    TextField("Sözleşme No", text: $contractNo)
                    DatePicker("Planlanan Tarih", selection: $scheduledDate, displayedComponents: .date)
                }
                Section("Notlar") {
                    TextField("Notlar", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Kesin Kabul")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(contractorName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let year = Calendar.current.component(.year, from: Date())
        let no = FinalAcceptance.generateNo(existingCount: existing.count, year: year)
        let acc = FinalAcceptance(acceptanceNo: no, contractNo: contractNo,
                                   contractorName: contractorName, scheduledDate: scheduledDate)
        acc.finalAcceptanceNotes = notes
        context.insert(acc)
        do { try context.save() } catch { print("AddFinalAcceptanceView save error: \(error)") }
        dismiss()
    }
}

struct AddAcceptanceDeficiencyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var acceptance: ProvisionalAcceptance

    @State private var deficiencyText = ""
    @State private var location = ""
    @State private var responsibleParty = ""
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(14 * 86400)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Eksiklik Açıklaması", text: $deficiencyText, axis: .vertical).lineLimit(2...4)
                    TextField("Konum", text: $location)
                    TextField("Sorumlu Taraf", text: $responsibleParty)
                    Toggle("Tamamlama Tarihi", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Tarih", selection: $deadline, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Eksiklik Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }.disabled(deficiencyText.isEmpty)
                }
            }
        }
    }

    private func save() {
        let no = acceptance.deficiencies.count + 1
        let def = AcceptanceDeficiency(deficiencyNo: no, deficiencyText: deficiencyText, location: location)
        def.responsibleParty = responsibleParty
        if hasDeadline { def.deadline = deadline }
        def.acceptance = acceptance
        context.insert(def)
        acceptance.deficiencies.append(def)
        do { try context.save() } catch { print("AddDeficiencyView save error: \(error)") }
        dismiss()
    }
}
