import SwiftUI
import SwiftData

// MARK: - HakedisRevision Color Extension

extension HakedisRevision {
    var objectionDeadlineColor: Color {
        if isExpired        { return .hakedisDanger }
        if objectionDaysLeft <= 7  { return .hakedisDanger }
        if objectionDaysLeft <= 15 { return .hakedisWarning }
        return .hakedisSuccess
    }
}

// MARK: - JSON Helper Structs

struct MediationEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var result: String
    var notes: String
}

struct RevisedItemEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var poz: String
    var oldQuantity: Double
    var newOffer: Double
}

private func decodeMediations(_ json: String?) -> [MediationEntry] {
    guard let data = json?.data(using: .utf8),
          let entries = try? JSONDecoder().decode([MediationEntry].self, from: data)
    else { return [] }
    return entries
}

private func encodeMediations(_ entries: [MediationEntry]) -> String? {
    guard let data = try? JSONEncoder().encode(entries) else { return nil }
    return String(data: data, encoding: .utf8)
}

// MARK: - Rejection Capture Sheet (hakediş reddedilince otomatik açılır)

struct RejectionCaptureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let hakedis: Hakedis

    @State private var officialLetterNo = ""
    @State private var objectionText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Red Bilgileri") {
                    LabeledContent("Red Gerekçesi", value: hakedis.approvalNote.isEmpty
                                   ? "—" : hakedis.approvalNote)
                    LabeledContent("Versiyon", value: hakedis.nextRevisionVersion)
                    TextField("Resmi Yazı No (opsiyonel)", text: $officialLetterNo)
                }

                Section("Yüklenici İtiraz Metni") {
                    TextEditor(text: $objectionText)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if objectionText.isEmpty {
                                Text("İtiraz metninizi yazın (opsiyonel)…")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .padding(.top, 8).padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section {
                    HStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(.hakedisDanger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("İtiraz Süresi")
                                .font(.caption).foregroundColor(.secondary)
                            let deadline = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
                            Text("30 gün — \(deadline.shortFormatted)'e kadar")
                                .font(.subheadline.bold())
                                .foregroundColor(.hakedisDanger)
                        }
                    }
                    Text("4735 sayılı Kanun md.8 kapsamında hak düşürücü süre uygulanır.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Red Kaydı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Atla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .bold()
                }
            }
        }
    }

    private func save() {
        let periodDays = hakedis.contract?.objectionPeriodDays
            ?? hakedis.contract?.contractSector.defaultObjectionDays
            ?? 30
        let revision = HakedisRevision(
            version: hakedis.nextRevisionVersion,
            rejectionReason: hakedis.approvalNote.isEmpty ? "—" : hakedis.approvalNote,
            officialLetterNo: officialLetterNo.isEmpty ? nil : officialLetterNo,
            objectionPeriodDays: periodDays
        )
        revision.objectionText = objectionText.isEmpty ? nil : objectionText
        revision.hakedis = hakedis
        hakedis.revisions.append(revision)
        modelContext.insert(revision)
        dismiss()
    }
}

// MARK: - Revision Version Timeline (yatay scroll)

struct RevisionVersionTimeline: View {
    let hakedis: Hakedis
    @State private var selectedRevision: HakedisRevision?

    private var sorted: [HakedisRevision] {
        hakedis.revisions.sorted { $0.rejectedAt < $1.rejectedAt }
    }

    var body: some View {
        if sorted.isEmpty { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Revizyon Geçmişi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, rev in
                            HStack(spacing: 0) {
                                Button {
                                    selectedRevision = rev
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(rev.isExpired
                                                      ? Color.secondary.opacity(0.15)
                                                      : Color.hakedisDanger.opacity(0.12))
                                                .frame(width: 42, height: 42)
                                            Text(rev.version)
                                                .font(.caption.bold())
                                                .foregroundColor(rev.isExpired ? .secondary : .hakedisDanger)
                                        }
                                        Text(rev.rejectedAt.shortFormatted)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if index < sorted.count - 1 {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 30, height: 1)
                                }
                            }
                        }

                        // Aktif (şimdiki) versiyon
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 30, height: 1)
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(Color.hakedisOrange.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    Text(hakedis.nextRevisionVersion)
                                        .font(.caption.bold())
                                        .foregroundColor(.hakedisOrange)
                                }
                                Text("Güncel")
                                    .font(.system(size: 9))
                                    .foregroundColor(.hakedisOrange)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 4)
            .sheet(item: $selectedRevision) { rev in
                RevisionDetailSheet(revision: rev, hakedis: hakedis)
            }
        }
    }
}

// MARK: - Objection Deadline Badge

struct ObjectionDeadlineBadge: View {
    let revision: HakedisRevision

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
            if revision.isExpired {
                Text("İtiraz süresi doldu")
            } else {
                Text("\(revision.objectionDaysLeft) gün kaldı")
            }
        }
        .font(.caption.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(revision.objectionDeadlineColor.opacity(0.12))
        .foregroundColor(revision.objectionDeadlineColor)
        .clipShape(Capsule())
    }
}

// MARK: - Revision Detail Sheet

struct RevisionDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var revision: HakedisRevision
    let hakedis: Hakedis

    @State private var showingMediationAdd = false
    @State private var showingPetition = false

    private var mediations: [MediationEntry] { decodeMediations(revision.mediationDatesJSON) }

    var body: some View {
        NavigationStack {
            List {
                Section("Red Bilgileri") {
                    LabeledContent("Versiyon", value: revision.version)
                    LabeledContent("Red Tarihi", value: revision.rejectedAt.shortFormatted)
                    LabeledContent("Red Gerekçesi", value: revision.rejectionReason)
                    if let no = revision.officialLetterNo, !no.isEmpty {
                        LabeledContent("Resmi Yazı No", value: no)
                    }
                }

                Section("İtiraz Durumu") {
                    ObjectionDeadlineBadge(revision: revision)
                        .listRowBackground(Color.clear)
                    if let text = revision.objectionText, !text.isEmpty {
                        Text(text).font(.subheadline)
                    }
                    Picker("Çözüm", selection: $revision.resolution) {
                        Text("Seçiniz").tag(RevisionResolution?.none)
                        ForEach(RevisionResolution.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(Optional(r))
                        }
                    }
                    if revision.resolution != nil {
                        Toggle("İtiraz Kazanıldı", isOn: Binding(
                            get: { revision.itirazKazanildi ?? false },
                            set: { revision.itirazKazanildi = $0 }
                        ))
                        if revision.itirazKazanildi == true {
                            TextField("Ödeme Belgesi No", text: Binding(
                                get: { revision.paymentDocNo ?? "" },
                                set: { revision.paymentDocNo = $0.isEmpty ? nil : $0 }
                            ))
                        }
                    }
                }

                Section {
                    if mediations.isEmpty {
                        Text("Henüz arabuluculuk toplantısı yok")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(mediations) { m in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(m.date.shortFormatted).font(.caption.bold())
                                    Spacer()
                                    StatusBadge(text: m.result.isEmpty ? "—" : m.result,
                                                color: .hakedisWarning)
                                }
                                if !m.notes.isEmpty {
                                    Text(m.notes).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    if mediations.count < 3 {
                        Button {
                            showingMediationAdd = true
                        } label: {
                            Label("Toplantı Ekle", systemImage: "calendar.badge.plus")
                                .foregroundColor(.hakedisOrange)
                        }
                    }
                } header: {
                    Text("Arabuluculuk Toplantıları (maks. 3)")
                }

                Section {
                    Button {
                        showingPetition = true
                    } label: {
                        Label("İtiraz Dilekçesi Oluştur", systemImage: "doc.text.fill")
                            .foregroundColor(.hakedisOrange)
                    }
                }
            }
            .navigationTitle("\(revision.version) Red Kaydı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Kapat") { dismiss() } }
            }
            .sheet(isPresented: $showingMediationAdd) {
                MediationAddSheet { entry in
                    var list = decodeMediations(revision.mediationDatesJSON)
                    list.append(entry)
                    revision.mediationDatesJSON = encodeMediations(list)
                }
            }
            .sheet(isPresented: $showingPetition) {
                ObjectionPetitionView(revision: revision, hakedis: hakedis)
            }
        }
    }
}

// MARK: - Mediation Add Sheet

struct MediationAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MediationEntry) -> Void

    @State private var date = Date()
    @State private var result = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Arabuluculuk Toplantısı") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    TextField("Sonuç (örn: Uzlaşma sağlanamadı)", text: $result)
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Toplantı Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        onSave(MediationEntry(date: date, result: result, notes: notes))
                        dismiss()
                    }
                    .bold()
                    .disabled(result.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Objection Petition View

struct ObjectionPetitionView: View {
    @Environment(\.dismiss) private var dismiss
    let revision: HakedisRevision
    let hakedis: Hakedis

    @State private var showingShare = false

    private var petitionText: String {
        let contract = hakedis.contract
        let sn = contract?.title ?? "—"
        let contractor = contract?.contractor?.name ?? "—"
        let date = Date().shortFormatted
        return """
        İTİRAZ DİLEKÇESİ
        Tarih: \(date)

        KONU: \(sn) sözleşmesine ait \(hakedis.periodName) (\(revision.version)) \
        hakedişinin reddine itiraz.

        YÜKLENICI: \(contractor)
        SÖZLEŞME: \(sn)
        RED TARİHİ: \(revision.rejectedAt.shortFormatted)
        RED GEREKÇESİ: \(revision.rejectionReason)
        \(revision.officialLetterNo.map { "RESMİ YAZI NO: \($0)" } ?? "")

        YASAL DAYANAK:
        4735 sayılı Kamu İhale Sözleşmeleri Kanunu madde 8 kapsamında, \
        hakedişin tebliğinden itibaren 30 (otuz) gün içinde itiraz hakkımızı kullanmaktayız.

        İTİRAZ GEREKÇEMİZ:
        \(revision.objectionText ?? "— (İtiraz metni girilmemiş)")

        Gereğini saygılarımızla arz ederiz.
        """
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(petitionText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("İtiraz Dilekçesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: petitionText,
                              subject: Text("İtiraz Dilekçesi"),
                              message: Text("\(hakedis.periodName) \(revision.version)")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Rejection Stats Section (ReportsView içinde kullanılır)

struct RejectionStatsSection: View {
    @Query private var revisions: [HakedisRevision]

    private var total: Int { revisions.count }
    private var won: Int { revisions.filter { $0.itirazKazanildi == true }.count }
    private var pending: Int { revisions.filter { $0.resolution == nil && !$0.isExpired }.count }
    private var wonPercent: Double { total > 0 ? Double(won) / Double(total) * 100 : 0 }

    var body: some View {
        if !revisions.isEmpty {
            Section("İtiraz İstatistikleri") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatCard(title: "Toplam Red", value: "\(total)",
                             subtitle: "Tüm hakediş redleri",
                             color: .hakedisDanger, icon: "xmark.circle.fill")
                    StatCard(title: "Kazanılan İtiraz", value: "\(won)",
                             subtitle: String(format: "%%%0.f", wonPercent),
                             color: .hakedisSuccess, icon: "checkmark.seal.fill")
                    StatCard(title: "Devam Eden", value: "\(pending)",
                             subtitle: "Sonuçlanmamış",
                             color: .hakedisWarning, icon: "hourglass")
                    StatCard(title: "Süresi Dolan", value: "\(revisions.filter { $0.isExpired }.count)",
                             subtitle: "Hak düşmüş",
                             color: .secondary, icon: "timer")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
    }
}
