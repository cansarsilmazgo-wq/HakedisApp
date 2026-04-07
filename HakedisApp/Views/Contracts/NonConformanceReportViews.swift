import SwiftUI
import SwiftData

// MARK: - NonConformanceReportListView

struct NonConformanceReportListView: View {
    @Query(sort: \NonConformanceReport.detectionDate, order: .reverse) private var allNCRs: [NonConformanceReport]
    @Environment(\.modelContext) private var modelContext
    var contract: Contract? = nil

    @State private var showingAdd = false
    @State private var selectedStatus: NCRStatus? = nil

    private var filtered: [NonConformanceReport] {
        allNCRs.filter { ncr in
            let contractMatch = contract.map { ncr.contract?.id == $0.id } ?? true
            let statusMatch = selectedStatus.map { ncr.status == $0 } ?? true
            return contractMatch && statusMatch
        }
    }

    private var openCount: Int { filtered.filter { $0.status == .open || $0.status == .correctionProposed || $0.status == .correctionInProgress }.count }
    private var overdueCount: Int { filtered.filter { $0.isOverdue }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if overdueCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                        Text("\(overdueCount) gecikmiş NCR düzeltme").font(.caption.bold()).foregroundColor(.hakedisDanger)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.08))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: selectedStatus == nil) { selectedStatus = nil }
                        ForEach(NCRStatus.allCases, id: \.self) { s in
                            FilterChip(title: s.rawValue, isSelected: selectedStatus == s) {
                                selectedStatus = selectedStatus == s ? nil : s
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                }
                .background(Color.hakedisBackground)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "exclamationmark.magnifyingglass",
                        title: "NCR kaydı yok",
                        subtitle: "Uygunsuzluk tespit raporu (NCR) oluşturun",
                        actionTitle: "NCR Oluştur",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { ncr in
                            NavigationLink(destination: NonConformanceReportDetailView(ncr: ncr)) {
                                NCRRow(ncr: ncr)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(Color.hakedisOrange).clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4).accessibilityLabel("NCR oluştur")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) { AddNCRView(contract: contract) }
    }
}

// MARK: - NCRRow

private struct NCRRow: View {
    let ncr: NonConformanceReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: ncr.status.icon)
                    .foregroundColor(Color(ncr.status.colorName == "secondary" ? "secondary" : ncr.status.colorName))
                Text(ncr.ncrNo).font(.subheadline.bold()).foregroundColor(.hakedisOrange)
                Spacer()
                StatusBadge(text: ncr.status.rawValue, color: statusColor(ncr.status))
            }
            Text(ncr.nonConformanceDescription).font(.caption).foregroundColor(.secondary).lineLimit(2)
            HStack {
                Text(ncr.location).font(.caption2).foregroundColor(.secondary)
                Text("·").font(.caption2).foregroundColor(.secondary)
                Text(ncr.detectedBy).font(.caption2).foregroundColor(.secondary)
                Spacer()
                if ncr.isOverdue {
                    Image(systemName: "clock.badge.exclamationmark.fill").foregroundColor(.hakedisDanger).font(.caption2)
                }
                Text(ncr.detectionDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ncr.ncrNo), \(ncr.status.rawValue)")
    }

    private func statusColor(_ s: NCRStatus) -> Color {
        switch s {
        case .open: return .hakedisDanger
        case .correctionProposed, .correctionInProgress: return .hakedisWarning
        case .correctionDone: return .hakedisInfo
        case .verified, .closed: return .hakedisSuccess
        }
    }
}

// MARK: - NonConformanceReportDetailView

struct NonConformanceReportDetailView: View {
    let ncr: NonConformanceReport
    @Environment(\.modelContext) private var modelContext
    @State private var showingCreateCA = false
    @State private var correctionDesc = ""
    @State private var verifiedBy = ""

    var body: some View {
        List {
            Section("NCR Bilgileri") {
                LabeledContent("NCR No", value: ncr.ncrNo)
                LabeledContent("Tespit Tarihi", value: ncr.detectionDate.shortFormatted)
                LabeledContent("Mahal", value: ncr.location)
                LabeledContent("Tespit Eden", value: ncr.detectedBy)
                if let wi = ncr.affectedWorkItem { LabeledContent("Etkilenen İş Kalemi", value: wi) }
                HStack {
                    Text("Durum")
                    Spacer()
                    StatusBadge(text: ncr.status.rawValue, color: .hakedisOrange)
                }
                if ncr.isOverdue {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark.fill").foregroundColor(.hakedisDanger)
                        Text("Düzeltme tarihi geçti!").font(.caption).foregroundColor(.hakedisDanger)
                    }
                }
            }

            Section("Uygunsuzluk") {
                Text(ncr.nonConformanceDescription).font(.body)
                if let rootCause = ncr.rootCause, !rootCause.isEmpty {
                    LabeledContent("Kök Neden") { Text(rootCause).multilineTextAlignment(.trailing) }
                }
            }

            // Timeline / Akış
            Section("Düzeltme Süreci") {
                NCRTimelineStep(
                    step: 1, title: "Uygunsuzluk Tespit",
                    date: ncr.detectionDate, isDone: true
                )
                NCRTimelineStep(
                    step: 2, title: "Düzeltme Önerildi",
                    date: nil, isDone: ncr.status.rawValue != NCRStatus.open.rawValue
                )
                if let proposed = ncr.proposedCorrection {
                    Text(proposed).font(.caption).foregroundColor(.secondary).padding(.leading, 32)
                }
                NCRTimelineStep(
                    step: 3, title: "Düzeltme Yapıldı",
                    date: ncr.correctionDate, isDone: ncr.status == .correctionDone || ncr.status == .verified || ncr.status == .closed
                )
                NCRTimelineStep(
                    step: 4, title: "Doğrulandı / Kapatıldı",
                    date: ncr.verificationDate, isDone: ncr.status == .verified || ncr.status == .closed
                )
            }

            // İşlem butonları
            Section("İşlemler") {
                if ncr.status == .open {
                    Button {
                        ncr.status = .correctionProposed
                        try? modelContext.save()
                    } label: { Label("Düzeltme Öner", systemImage: "doc.fill") }
                        .foregroundColor(.hakedisOrange).accessibilityLabel("Düzeltme öner")
                }
                if ncr.status == .correctionProposed || ncr.status == .correctionInProgress {
                    Button {
                        ncr.status = .correctionDone
                        ncr.correctionDate = Date()
                        try? modelContext.save()
                    } label: { Label("Düzeltme Yapıldı", systemImage: "checkmark.circle") }
                        .foregroundColor(.hakedisSuccess).accessibilityLabel("Düzeltme yapıldı")
                }
                if ncr.status == .correctionDone {
                    Button {
                        ncr.status = .verified
                        ncr.verifiedBy = "Kalite Kontrol"
                        ncr.verificationDate = Date()
                        ncr.status = .closed
                        try? modelContext.save()
                    } label: { Label("Doğrula ve Kapat", systemImage: "checkmark.seal.fill") }
                        .foregroundColor(.hakedisSuccess).accessibilityLabel("Doğrula ve kapat")
                }
                Button { showingCreateCA = true } label: {
                    Label("Düzeltici Faaliyet Oluştur", systemImage: "plus.circle")
                }
                .foregroundColor(.hakedisOrange).accessibilityLabel("Düzeltici faaliyet oluştur")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(ncr.ncrNo)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCreateCA) { CorrectiveActionForm() }
    }
}

private struct NCRTimelineStep: View {
    let step: Int
    let title: String
    let date: Date?
    let isDone: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.hakedisSuccess : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                Text("\(step)").font(.caption.bold()).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).foregroundColor(isDone ? .primary : .secondary)
                if let d = date {
                    Text(d.shortFormatted).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            if isDone {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.hakedisSuccess).font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - AddNCRView

struct AddNCRView: View {
    var contract: Contract? = nil
    var checklist: QualityChecklist? = nil
    var prefillItem: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allNCRs: [NonConformanceReport]
    @Query private var contracts: [Contract]

    @State private var location = ""
    @State private var description = ""
    @State private var affectedWorkItem = ""
    @State private var detectedBy = ""
    @State private var proposedCorrection = ""
    @State private var rootCause = ""
    @State private var correctionDeadline = Date().addingTimeInterval(7 * 86400)
    @State private var hasDeadline = true
    @State private var selectedContract: Contract? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("NCR Bilgileri") {
                    TextField("Mahal (kat, blok, alan) *", text: $location).accessibilityLabel("Mahal")
                    TextEditor(text: $description).frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Uygunsuzluk açıklaması *").foregroundColor(.secondary).font(.body).padding(.leading, 4).padding(.top, 8).allowsHitTesting(false)
                            }
                        }
                    TextField("Etkilenen iş kalemi", text: $affectedWorkItem).accessibilityLabel("Etkilenen iş kalemi")
                    TextField("Tespit eden *", text: $detectedBy).accessibilityLabel("Tespit eden")
                    if contract == nil {
                        Picker("Sözleşme", selection: $selectedContract) {
                            Text("Seçilmedi").tag(Optional<Contract>.none)
                            ForEach(contracts, id: \.id) { c in Text(c.title).tag(Optional(c)) }
                        }
                        .accessibilityLabel("Sözleşme")
                    }
                }
                Section("Kök Neden") {
                    TextEditor(text: $rootCause).frame(minHeight: 60).accessibilityLabel("Kök neden")
                }
                Section("Önerilen Düzeltme") {
                    TextEditor(text: $proposedCorrection).frame(minHeight: 60).accessibilityLabel("Önerilen düzeltme")
                    Toggle("Termin tarihi belirle", isOn: $hasDeadline).tint(.hakedisOrange)
                    if hasDeadline {
                        DatePicker("Termin", selection: $correctionDeadline, displayedComponents: .date)
                            .accessibilityLabel("Düzeltme termin tarihi")
                    }
                }
            }
            .navigationTitle("Yeni NCR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.accessibilityLabel("İptal") }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.accessibilityLabel("Kaydet") }
            }
            .onAppear {
                selectedContract = contract
                if let prefill = prefillItem { affectedWorkItem = prefill }
                if let loc = checklist?.location { location = loc }
            }
        }
    }

    private func save() {
        guard !location.isEmpty, !description.isEmpty, !detectedBy.isEmpty else { return }
        let existingCount = allNCRs.filter { $0.contract?.id == (contract ?? selectedContract)?.id }.count
        let ncrNo = NonConformanceReport.generateNCRNo(existingCount: existingCount)
        let ncr = NonConformanceReport(ncrNo: ncrNo, location: location, nonConformanceDescription: description, detectedBy: detectedBy)
        ncr.affectedWorkItem = affectedWorkItem.isEmpty ? nil : affectedWorkItem
        ncr.rootCause = rootCause.isEmpty ? nil : rootCause
        ncr.proposedCorrection = proposedCorrection.isEmpty ? nil : proposedCorrection
        ncr.correctionDeadline = hasDeadline ? correctionDeadline : nil
        ncr.checklist = checklist
        ncr.contract = contract ?? selectedContract
        if ncr.proposedCorrection != nil { ncr.status = .correctionProposed }
        modelContext.insert(ncr)
        try? modelContext.save()
        dismiss()
    }
}
