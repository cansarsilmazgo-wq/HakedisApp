import SwiftUI
import SwiftData

// MARK: - MaterialRequestListView
struct MaterialRequestListView: View {
    @Query(sort: \MaterialRequest.requestDate, order: .reverse) private var requests: [MaterialRequest]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false
    @State private var statusFilter: RequestStatus? = nil

    private var filtered: [MaterialRequest] {
        guard let f = statusFilter else { return requests }
        return requests.filter { $0.status == f }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: statusFilter == nil) { statusFilter = nil }
                        ForEach(RequestStatus.allCases, id: \.rawValue) { s in
                            FilterChip(title: s.rawValue, isSelected: statusFilter == s) {
                                statusFilter = statusFilter == s ? nil : s
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                }
                .background(Color.hakedisBackground)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "list.clipboard",
                        title: "Talep kaydı yok",
                        subtitle: "Malzeme talebi oluşturun",
                        actionTitle: "Talep Oluştur",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { req in
                            MaterialRequestRow(request: req)
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            do { try modelContext.save() } catch { print("Silme: \(error)") }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Talep oluştur")
        }
        .sheet(isPresented: $showingAdd) { AddMaterialRequestView() }
    }
}

// MARK: - MaterialRequestRow
private struct MaterialRequestRow: View {
    @Bindable var request: MaterialRequest

    var urgencyColor: Color {
        switch request.urgency {
        case .normal:   return .hakedisSuccess
        case .urgent:   return .hakedisWarning
        case .critical: return .hakedisDanger
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(urgencyColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(request.requestedBy).font(.subheadline.bold())
                    Spacer()
                    StatusBadge(text: request.urgency.rawValue, color: urgencyColor)
                }
                if let mat = request.material {
                    Text(mat.name).font(.caption).foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    Text(request.requestDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
                    Text(String(format: "%.1f adet", request.requestedQuantity)).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                StatusBadge(text: request.status.rawValue,
                            color: request.status == .approved ? .hakedisSuccess
                                : request.status == .rejected ? .hakedisDanger : .hakedisWarning)
                if request.status == .submitted {
                    HStack(spacing: 6) {
                        Button("Onayla") {
                            request.status = .approved
                            request.approvalDate = Date()
                        }
                        .font(.caption).foregroundColor(.hakedisSuccess)
                        .accessibilityLabel("Talebi onayla")
                        Button("Reddet") {
                            request.status = .rejected
                            request.approvalDate = Date()
                        }
                        .font(.caption).foregroundColor(.hakedisDanger)
                        .accessibilityLabel("Talebi reddet")
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.requestedBy), \(request.status.rawValue)")
    }
}

// MARK: - AddMaterialRequestView
struct AddMaterialRequestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Material.name) private var materials: [Material]
    @Query private var projects: [Project]

    @State private var requestedBy = ""
    @State private var selectedMaterial: Material? = nil
    @State private var selectedProject: Project? = nil
    @State private var requestedQuantity = ""
    @State private var urgency: RequestUrgency = .normal
    @State private var reason = ""
    @State private var neededByDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var hasNeededByDate = false
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Talep Eden") {
                    TextField("Ad Soyad *", text: $requestedBy)
                        .accessibilityLabel("Talep eden")
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                    }
                }
                Section("Malzeme") {
                    Picker("Malzeme", selection: $selectedMaterial) {
                        Text("Seçilmedi").tag(Optional<Material>.none)
                        ForEach(materials, id: \.id) { m in Text(m.name).tag(Optional(m)) }
                    }
                    TextField("Miktar", text: $requestedQuantity).keyboardType(.decimalPad)
                        .accessibilityLabel("Talep miktarı")
                }
                Section("Aciliyet & Sebep") {
                    Picker("Aciliyet", selection: $urgency) {
                        ForEach(RequestUrgency.allCases, id: \.rawValue) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    .accessibilityLabel("Aciliyet seviyesi")
                    Toggle("Son Tarih", isOn: $hasNeededByDate)
                    if hasNeededByDate {
                        DatePicker("Ne Zamana Kadar", selection: $neededByDate, displayedComponents: .date)
                    }
                    TextField("Gereklilik Sebebi", text: $reason)
                        .accessibilityLabel("Gereklilik sebebi")
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                        .accessibilityLabel("Notlar")
                }
            }
            .navigationTitle("Malzeme Talebi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Gönder") { save() } }
            }
        }
    }

    private func save() {
        let by = requestedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !by.isEmpty else { return }
        let qty = Double(requestedQuantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let req = MaterialRequest(requestedBy: by, requestedQuantity: qty)
        req.status = .submitted
        req.urgency = urgency
        req.material = selectedMaterial
        req.project = selectedProject
        req.reason = reason.isEmpty ? nil : reason
        req.neededByDate = hasNeededByDate ? neededByDate : nil
        req.notes = notes.isEmpty ? nil : notes
        modelContext.insert(req)
        do { try modelContext.save() } catch { print("Kayıt: \(error)") }
        dismiss()
    }
}
