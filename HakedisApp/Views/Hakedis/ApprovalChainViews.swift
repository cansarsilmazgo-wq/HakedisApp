import SwiftUI
import SwiftData

// MARK: - Approval Chain Section (HakedisDetailView içinde kullanılır)

struct ApprovalChainSection: View {
    @Environment(\.modelContext) private var modelContext
    let hakedis: Hakedis

    @State private var showingSetup = false
    @State private var showingApprove = false
    @State private var showingReject = false
    @State private var showingDelegate = false
    @State private var showingCancel = false
    @State private var selectedStep: ApprovalStep?

    private var sortedSteps: [ApprovalStep] {
        hakedis.approvalSteps.filter { !$0.isCancelled }.sorted { $0.stepOrder < $1.stepOrder }
    }

    private func isActive(_ step: ApprovalStep) -> Bool {
        guard step.status == .bekliyor else { return false }
        let predecessors = sortedSteps.filter { $0.stepOrder < step.stepOrder }
        return predecessors.allSatisfy { $0.status == .onaylandi || $0.status == .yetkiDevredildi }
    }

    var body: some View {
        if hakedis.approvalSteps.isEmpty {
            Button {
                showingSetup = true
            } label: {
                Label("Onay Zinciri Oluştur", systemImage: "person.3.sequence.fill")
                    .foregroundColor(.hakedisOrange)
            }
            .sheet(isPresented: $showingSetup) {
                SetupApprovalChainSheet { names in
                    createChain(names: names)
                }
            }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(sortedSteps.enumerated()), id: \.element.id) { index, step in
                    ApprovalStepTimelineRow(
                        step: step,
                        isActive: isActive(step),
                        isLast: index == sortedSteps.count - 1,
                        onApprove: { selectedStep = step; showingApprove = true },
                        onReject:  { selectedStep = step; showingReject  = true },
                        onDelegate:{ selectedStep = step; showingDelegate = true },
                        onCancel:  { selectedStep = step; showingCancel  = true }
                    )
                }
            }
            .sheet(isPresented: $showingApprove) {
                if let step = selectedStep {
                    ApprovalCommentSheet(step: step) { comment in
                        approve(step, comment: comment)
                    }
                }
            }
            .sheet(isPresented: $showingReject) {
                if let step = selectedStep {
                    RejectStepSheet(step: step) { reason in
                        reject(step, reason: reason)
                    }
                }
            }
            .sheet(isPresented: $showingDelegate) {
                if let step = selectedStep {
                    DelegateStepSheet(step: step) { name, reason, docNo, docDate, grantedBy in
                        delegate(step, name: name, reason: reason,
                                 docNo: docNo, docDate: docDate, grantedBy: grantedBy)
                    }
                }
            }
            .sheet(isPresented: $showingCancel) {
                if let step = selectedStep {
                    CancelApprovalSheet(step: step) { reason in
                        cancel(step, reason: reason)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func createChain(names: [String]) {
        let roles: [(Int, ApprovalRole)] = [
            (1, .santiyeSef),
            (2, .sefMuhendis),
            (3, .idare)
        ]
        for (index, (order, role)) in roles.enumerated() {
            let name = index < names.count ? names[index] : role.rawValue
            let step = ApprovalStep(stepOrder: order, role: role, approverName: name)
            if role == .idare {
                step.deadline = businessDays(15, from: Date())
            }
            step.hakedis = hakedis
            hakedis.approvalSteps.append(step)
            modelContext.insert(step)
        }
        hakedis.status = .pendingApproval
    }

    private func approve(_ step: ApprovalStep, comment: String) {
        step.status = .onaylandi
        step.approvedAt = Date()
        step.comment = comment.isEmpty ? nil : comment
        appendAudit(step, "Onaylandı\(comment.isEmpty ? "" : ": \(comment)")")

        let all = hakedis.approvalSteps.filter { !$0.isCancelled }
        if all.allSatisfy({ $0.status == .onaylandi || $0.status == .yetkiDevredildi }) {
            hakedis.status = .approved
        }
    }

    private func reject(_ step: ApprovalStep, reason: String) {
        step.status = .reddedildi
        step.approvedAt = Date()
        step.rejectionReason = reason
        appendAudit(step, "Reddedildi: \(reason)")
        hakedis.status = .rejected
    }

    private func delegate(_ step: ApprovalStep, name: String, reason: String,
                           docNo: String?, docDate: Date?, grantedBy: String?) {
        step.delegateName = name
        step.delegateReason = reason
        step.authorityDocNo = docNo
        step.authorityDocDate = docDate
        step.authorityGrantedBy = grantedBy
        step.status = .yetkiDevredildi
        step.approvedAt = Date()
        appendAudit(step, "Yetki devredildi → \(name)")

        let all = hakedis.approvalSteps.filter { !$0.isCancelled }
        if all.allSatisfy({ $0.status == .onaylandi || $0.status == .yetkiDevredildi }) {
            hakedis.status = .approved
        }
    }

    private func cancel(_ step: ApprovalStep, reason: String) {
        step.isCancelled = true
        step.cancellationReason = reason
        appendAudit(step, "İptal edildi: \(reason)")
    }

    private func appendAudit(_ step: ApprovalStep, _ action: String) {
        let entry = "\(ISO8601DateFormatter().string(from: Date())): \(action)"
        step.auditLog = [(step.auditLog ?? ""), entry]
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private func businessDays(_ days: Int, from date: Date) -> Date {
        var count = 0
        var current = date
        while count < days {
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
            let wd = Calendar.current.component(.weekday, from: current)
            if wd != 1 && wd != 7 { count += 1 }
        }
        return current
    }
}

// MARK: - Single Step Row

struct ApprovalStepTimelineRow: View {
    let step: ApprovalStep
    let isActive: Bool
    let isLast: Bool
    let onApprove: () -> Void
    let onReject: () -> Void
    let onDelegate: () -> Void
    let onCancel: () -> Void

    private var rowColor: Color {
        if step.isCancelled      { return .secondary }
        switch step.status {
        case .onaylandi:         return .hakedisSuccess
        case .reddedildi:        return .hakedisDanger
        case .yetkiDevredildi:   return .hakedisSuccess
        case .bekliyor:          return isActive ? .hakedisOrange : .secondary
        }
    }

    private var rowIcon: String {
        if step.isCancelled { return "xmark.circle" }
        switch step.status {
        case .onaylandi:       return "checkmark.circle.fill"
        case .reddedildi:      return "xmark.circle.fill"
        case .yetkiDevredildi: return "arrow.triangle.swap"
        case .bekliyor:        return isActive ? "circle.dotted" : "lock.circle"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(rowColor.opacity(isActive ? 0.15 : 0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: rowIcon)
                        .foregroundColor(rowColor)
                        .font(.title3)
                }
                if !isLast {
                    Rectangle()
                        .fill(step.status == .onaylandi || step.status == .yetkiDevredildi
                              ? Color.hakedisSuccess.opacity(0.4)
                              : Color.secondary.opacity(0.2))
                        .frame(width: 2)
                        .frame(height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    Label(step.role.rawValue, systemImage: step.role.icon)
                        .font(.subheadline.bold())
                        .foregroundColor(rowColor)
                    Spacer()
                    StatusBadge(text: step.isCancelled ? "İptal" : step.status.rawValue,
                                color: rowColor)
                }

                // Approver name
                Text(step.effectiveApproverName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Delegate info
                if let dReason = step.delegateReason {
                    Text("Vekalet: \(dReason)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }

                // Completion date
                if let at = step.approvedAt {
                    Text(at.shortFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Comment
                if let c = step.comment, !c.isEmpty {
                    Text("💬 \(c)").font(.caption2).foregroundColor(.secondary)
                }

                // Rejection reason
                if let r = step.rejectionReason {
                    Label(r, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.hakedisDanger)
                }

                // Cancellation
                if let cr = step.cancellationReason {
                    Label("İptal: \(cr)", systemImage: "minus.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }

                // İdare deadline countdown
                if let daysLeft = step.deadlineDaysLeft {
                    Label(daysLeft <= 0 ? "Süre doldu" : "\(daysLeft) iş günü kaldı",
                          systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(daysLeft <= 3 ? .hakedisDanger : .hakedisWarning)
                }

                // Action buttons for active step
                if isActive {
                    HStack(spacing: 8) {
                        Button("Onayla", action: onApprove)
                            .buttonStyle(.borderedProminent)
                            .tint(.hakedisSuccess)
                            .font(.caption.bold())

                        Button("Reddet", action: onReject)
                            .buttonStyle(.bordered)
                            .tint(.hakedisDanger)
                            .font(.caption)

                        Menu {
                            Button("Yetki Devret", action: onDelegate)
                            Button("İptal Et", role: .destructive, action: onCancel)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }

                // Can cancel last approved step
                if step.status == .onaylandi {
                    let isLast = step.stepOrder == (step.hakedis?.approvalSteps
                        .filter { !$0.isCancelled && $0.status == .onaylandi }
                        .map { $0.stepOrder }.max() ?? -1)
                    if isLast {
                        Button("Onayı İptal Et", action: onCancel)
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                            .font(.caption2)
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : 4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Setup Sheet

struct SetupApprovalChainSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirm: ([String]) -> Void

    @State private var santiyeSef = ""
    @State private var sefMuhendis = ""
    @State private var idare = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("İmzacı İsimleri") {
                    TextField("Şantiye Şefi (opsiyonel)", text: $santiyeSef)
                    TextField("Şef Mühendis (opsiyonel)", text: $sefMuhendis)
                    TextField("İdare (opsiyonel)", text: $idare)
                }
                Section {
                    Text("Boş bırakılan alanlar için rol adı kullanılır. İdare adımına otomatik olarak 15 iş günü son tarih atanır.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Onay Zinciri Kur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") {
                        onConfirm([santiyeSef, sefMuhendis, idare])
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Approve Sheet

struct ApprovalCommentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let step: ApprovalStep
    let onConfirm: (String) -> Void
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("\(step.role.rawValue) — Onay") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if comment.isEmpty {
                                Text("İsteğe bağlı onay notu…")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .padding(.top, 8).padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .navigationTitle("Onay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Onayla") { onConfirm(comment); dismiss() }
                        .bold()
                        .foregroundColor(.hakedisSuccess)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Reject Sheet

struct RejectStepSheet: View {
    @Environment(\.dismiss) private var dismiss
    let step: ApprovalStep
    let onConfirm: (String) -> Void
    @State private var reason = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("\(step.role.rawValue) — Red Gerekçesi *") {
                    TextEditor(text: $reason)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if reason.isEmpty {
                                Text("Red gerekçesini yazın…")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .padding(.top, 8).padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                Section {
                    Text("Hakediş taslağa alınacak ve kırmızı ile işaretlenecektir.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Reddet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reddet") { onConfirm(reason); dismiss() }
                        .bold()
                        .foregroundColor(.hakedisDanger)
                        .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Delegate Sheet

struct DelegateStepSheet: View {
    @Environment(\.dismiss) private var dismiss
    let step: ApprovalStep
    let onConfirm: (String, String, String?, Date?, String?) -> Void

    @State private var delegateName = ""
    @State private var delegateReason = ""
    @State private var showAuthority = false
    @State private var docNo = ""
    @State private var docDate = Date()
    @State private var grantedBy = ""

    private var isValid: Bool {
        !delegateName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !delegateReason.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vekil Bilgileri") {
                    TextField("Vekil Adı Soyadı *", text: $delegateName)
                    TextField("Vekalet Gerekçesi *", text: $delegateReason)
                }
                Section {
                    Toggle("Yetki Belgesi Ekle", isOn: $showAuthority)
                    if showAuthority {
                        TextField("Belge No", text: $docNo)
                        DatePicker("Belge Tarihi", selection: $docDate, displayedComponents: .date)
                        TextField("Yetkiyi Veren Makam", text: $grantedBy)
                    }
                }
            }
            .navigationTitle("Yetki Devret")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Devret") {
                        onConfirm(delegateName, delegateReason,
                                  showAuthority ? docNo : nil,
                                  showAuthority ? docDate : nil,
                                  showAuthority ? grantedBy : nil)
                        dismiss()
                    }
                    .bold()
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Cancel Sheet

struct CancelApprovalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let step: ApprovalStep
    let onConfirm: (String) -> Void
    @State private var reason = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("İptal Gerekçesi *") {
                    TextEditor(text: $reason)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if reason.isEmpty {
                                Text("İptal gerekçesini yazın…")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .padding(.top, 8).padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                Section {
                    Text("Bu kayıt silinmez. İptal edildi olarak işaretlenir ve denetim izinde görünür.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Adımı İptal Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("İptal Et") { onConfirm(reason); dismiss() }
                        .bold()
                        .foregroundColor(.hakedisDanger)
                        .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
