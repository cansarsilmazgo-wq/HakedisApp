import SwiftUI
import SwiftData

struct ContractorPortalView: View {
    @Query private var contractors: [Contractor]
    @State private var selectedContractor: Contractor?
    @State private var isAuthenticated = false
    @State private var pendingContractor: Contractor?
    @State private var showingPasswordEntry = false

    var body: some View {
        NavigationStack {
            if isAuthenticated, let contractor = selectedContractor {
                ContractorDashboardView(contractor: contractor) {
                    isAuthenticated = false
                    selectedContractor = nil
                }
            } else {
                loginView
            }
        }
        .sheet(isPresented: $showingPasswordEntry) {
            if let contractor = pendingContractor {
                PortalLoginSheet(contractor: contractor) {
                    selectedContractor = contractor
                    isAuthenticated = true
                    showingPasswordEntry = false
                }
            }
        }
    }

    private func selectContractor(_ contractor: Contractor) {
        if contractor.portalPassword.isEmpty {
            selectedContractor = contractor
            isAuthenticated = true
        } else {
            pendingContractor = contractor
            showingPasswordEntry = true
        }
    }

    var loginView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .font(.system(size: 56))
                        .foregroundColor(.hakedisOrange)
                    Text("Taşeron Girişi").font(.title.bold())
                    Text("Hakedişlerinizi görmek için firmanızı seçin")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    ForEach(contractors) { contractor in
                        Button { selectContractor(contractor) } label: {
                            HStack {
                                Circle()
                                    .fill(Color.hakedisOrange.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(String(contractor.name.prefix(2)).uppercased())
                                            .font(.subheadline.bold())
                                            .foregroundColor(.hakedisOrange)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contractor.name).font(.headline).foregroundColor(.primary)
                                    if !contractor.contactPerson.isEmpty {
                                        Text(contractor.contactPerson).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: contractor.portalPassword.isEmpty ? "chevron.right" : "lock.fill")
                                    .foregroundColor(contractor.portalPassword.isEmpty ? .secondary : .hakedisOrange)
                                    .font(.caption)
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if contractors.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: "Taşeron bulunamadı",
                            subtitle: "Taşeronlar sekmesinden önce taşeron ekleyin"
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Taşeron Portali")
    }
}

// MARK: - Portal Login Sheet
struct PortalLoginSheet: View {
    let contractor: Contractor
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var enteredPassword = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.hakedisOrange.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text(String(contractor.name.prefix(2)).uppercased())
                                .font(.title2.bold())
                                .foregroundColor(.hakedisOrange)
                        )
                    Text(contractor.name).font(.title3.bold())
                    Text("Portal şifrenizi girin").font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    SecureField("Şifre", text: $enteredPassword)
                        .textContentType(.password)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    if failed {
                        Text("Hatalı şifre, tekrar deneyin")
                            .font(.caption)
                            .foregroundColor(.hakedisDanger)
                    }

                    Button {
                        if enteredPassword == contractor.portalPassword {
                            onSuccess()
                        } else {
                            failed = true
                            enteredPassword = ""
                        }
                    } label: {
                        Text("Giriş Yap")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(enteredPassword.isEmpty ? Color.secondary : Color.hakedisOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(enteredPassword.isEmpty)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Giriş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
}

struct ContractorDashboardView: View {
    let contractor: Contractor
    let onLogout: () -> Void

    private var allHakedisler: [Hakedis] {
        contractor.contracts.flatMap { $0.hakedisler }.sorted { $0.createdAt > $1.createdAt }
    }
    private var totalNet: Double { allHakedisler.reduce(0) { $0 + $1.netAmount } }
    private var totalPaid: Double { allHakedisler.reduce(0) { $0 + $1.totalPaid } }
    private var totalPending: Double { totalNet - totalPaid }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.hakedisOrange.opacity(0.15))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Text(String(contractor.name.prefix(2)).uppercased())
                                    .font(.headline.bold())
                                    .foregroundColor(.hakedisOrange)
                            )
                        VStack(alignment: .leading) {
                            Text(contractor.name).font(.title3.bold())
                            if !contractor.contactPerson.isEmpty {
                                Text(contractor.contactPerson).font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                    }
                    Divider()
                    HStack(spacing: 0) {
                        PortalStatItem(label: "Toplam", value: totalNet.currencyFormatted, color: .primary)
                        Divider().frame(height: 40)
                        PortalStatItem(label: "Ödenen", value: totalPaid.currencyFormatted, color: .hakedisSuccess)
                        Divider().frame(height: 40)
                        PortalStatItem(label: "Bekleyen", value: totalPending.currencyFormatted, color: totalPending > 0 ? .hakedisDanger : .hakedisSuccess)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Hakedişlerim") {
                if allHakedisler.isEmpty {
                    Text("Henüz hakediş yok").foregroundColor(.secondary)
                } else {
                    ForEach(allHakedisler) { h in
                        NavigationLink(destination: ContractorHakedisDetailView(hakedis: h)) {
                            ContractorHakedisRow(hakedis: h)
                        }
                    }
                }
            }

            Section("Sözleşmelerim") {
                ForEach(contractor.contracts) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(c.title).font(.subheadline.bold())
                        HStack {
                            Text(c.project?.name ?? "").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(c.totalContractAmount.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Portalım")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Çıkış") { onLogout() }.foregroundColor(.hakedisDanger)
            }
        }
    }
}

struct PortalStatItem: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.caption.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ContractorHakedisRow: View {
    let hakedis: Hakedis
    var statusColor: Color {
        switch hakedis.status {
        case .draft: return .secondary
        case .pendingApproval: return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        case .paid: return .blue
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hakedis.periodName).font(.subheadline.bold())
                Spacer()
                StatusBadge(text: hakedis.status.rawValue, color: statusColor)
            }
            HStack {
                Text(hakedis.contract?.title ?? "").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(hakedis.netAmount.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ContractorHakedisDetailView: View {
    let hakedis: Hakedis
    @State private var showingObjection = false
    @State private var objectionSubmitted = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Net Hakediş").font(.caption).foregroundColor(.secondary)
                            Text(hakedis.netAmount.currencyFormatted).font(.title2.bold())
                        }
                        Spacer()
                        StatusBadge(text: hakedis.status.rawValue, color: .hakedisOrange)
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Brüt").font(.caption).foregroundColor(.secondary)
                            Text(hakedis.grossAmount.currencyFormatted).font(.subheadline)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Teminat").font(.caption).foregroundColor(.secondary)
                            Text(hakedis.retentionAmount.currencyFormatted).font(.subheadline).foregroundColor(.hakedisDanger)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("İş Kalemleri") {
                ForEach(hakedis.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("[\(item.workItemCode)]").font(.caption.monospaced()).foregroundColor(.secondary)
                            Text(item.workItemName).font(.subheadline.bold())
                        }
                        HStack {
                            Text("\(item.currentQuantity.quantityFormatted) \(item.unit)").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(item.periodAmount.currencyFormatted).font(.caption.bold())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if hakedis.status == .pendingApproval || hakedis.status == .approved {
                Section {
                    if objectionSubmitted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.hakedisSuccess)
                            Text("İtirazınız iletildi").foregroundColor(.hakedisSuccess)
                        }
                    } else {
                        Button { showingObjection = true } label: {
                            Label("İtiraz Bildir", systemImage: "exclamationmark.bubble")
                                .foregroundColor(.hakedisDanger)
                        }
                    }
                }
            }
        }
        .navigationTitle(hakedis.periodName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingObjection) {
            ObjectionView(hakedis: hakedis) {
                objectionSubmitted = true
                showingObjection = false
            }
        }
    }
}

struct ObjectionView: View {
    let hakedis: Hakedis
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selectedItem: HakedisItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("İtiraz Kalemi") {
                    Picker("Kalem", selection: $selectedItem) {
                        Text("Genel İtiraz").tag(Optional<HakedisItem>.none)
                        ForEach(hakedis.items) { i in
                            Text("[\(i.workItemCode)] \(i.workItemName)").tag(Optional(i))
                        }
                    }
                }
                Section("Açıklama") {
                    TextEditor(text: $text).frame(minHeight: 80)
                }
            }
            .navigationTitle("İtiraz Bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gönder") {
                        saveObjection()
                        onSubmit()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                }
            }
        }
    }

    private func saveObjection() {
        let key = "objection_\(hakedis.id.uuidString)"
        let record: [String: String] = [
            "hakedisId": hakedis.id.uuidString,
            "hakedisName": hakedis.periodName,
            "contractTitle": hakedis.contract?.title ?? "",
            "workItem": selectedItem?.workItemName ?? "Genel",
            "text": text,
            "date": ISO8601DateFormatter().string(from: Date()),
            "status": "pending"
        ]
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Objection Admin View

struct ObjectionAdminView: View {
    @State private var objections: [[String: String]] = []
    @State private var selectedObjection: [String: String]?
    @State private var showingResponse = false

    var pendingObjections: [[String: String]] { objections.filter { $0["status"] == "pending" } }
    var resolvedObjections: [[String: String]] { objections.filter { $0["status"] != "pending" } }

    var body: some View {
        List {
            if objections.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.hakedisSuccess)
                        Text("Bekleyen itiraz yok").foregroundColor(.secondary)
                    }
                }
            }

            if !pendingObjections.isEmpty {
                Section("Bekleyen İtirazlar (\(pendingObjections.count))") {
                    ForEach(pendingObjections, id: \.self["hakedisId"]) { obj in
                        ObjectionRow(objection: obj) {
                            selectedObjection = obj
                            showingResponse = true
                        }
                    }
                }
            }

            if !resolvedObjections.isEmpty {
                Section("Yanıtlananlar") {
                    ForEach(resolvedObjections, id: \.self["hakedisId"]) { obj in
                        ObjectionRow(objection: obj, onRespond: nil)
                    }
                }
            }
        }
        .navigationTitle("İtiraz Yönetimi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { loadObjections() } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .sheet(item: Binding(
            get: { selectedObjection.map { IdentifiableObjection(data: $0) } },
            set: { _ in selectedObjection = nil }
        )) { item in
            ObjectionResponseView(objection: item.data) {
                loadObjections()
                selectedObjection = nil
                showingResponse = false
            }
        }
        .onAppear { loadObjections() }
    }

    private func loadObjections() {
        let defaults = UserDefaults.standard
        objections = defaults.dictionaryRepresentation()
            .compactMap { key, value -> [String: String]? in
                guard key.hasPrefix("objection_"),
                      let data = value as? Data,
                      let record = try? JSONDecoder().decode([String: String].self, from: data)
                else { return nil }
                return record
            }
            .sorted {
                let d0 = $0["date"] ?? ""
                let d1 = $1["date"] ?? ""
                return d0 > d1
            }
    }
}

struct IdentifiableObjection: Identifiable {
    let id = UUID()
    let data: [String: String]
}

struct ObjectionRow: View {
    let objection: [String: String]
    let onRespond: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(objection["hakedisName"] ?? "—").font(.subheadline.bold())
                    Text(objection["contractTitle"] ?? "").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                let status = objection["status"] ?? "pending"
                StatusBadge(
                    text: status == "pending" ? "Bekliyor" : status == "accepted" ? "Kabul" : "Red",
                    color: status == "pending" ? .hakedisWarning : status == "accepted" ? .hakedisSuccess : .hakedisDanger
                )
            }
            Text("Kalem: \(objection["workItem"] ?? "Genel")").font(.caption).foregroundColor(.secondary)
            Text(objection["text"] ?? "").font(.caption).lineLimit(2)
            if let response = objection["response"], !response.isEmpty {
                Text("Yanıt: \(response)").font(.caption.italic()).foregroundColor(.hakedisSuccess)
            }
            if let onRespond {
                Button("Yanıtla", action: onRespond)
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ObjectionResponseView: View {
    let objection: [String: String]
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var responseText = ""
    @State private var decision: String = "accepted"

    var body: some View {
        NavigationStack {
            Form {
                Section("İtiraz Detayı") {
                    LabeledContent("Hakediş", value: objection["hakedisName"] ?? "—")
                    LabeledContent("Kalem", value: objection["workItem"] ?? "Genel")
                    Text(objection["text"] ?? "").font(.subheadline)
                }
                Section("Karar") {
                    Picker("Karar", selection: $decision) {
                        Text("Kabul Et").tag("accepted")
                        Text("Reddet").tag("rejected")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Yanıt Metni") {
                    TextEditor(text: $responseText)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("İtiraz Yanıtla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { saveResponse() }
                        .disabled(responseText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
        }
    }

    private func saveResponse() {
        guard let hakedisId = objection["hakedisId"] else { return }
        let key = "objection_\(hakedisId)"
        var updated = objection
        updated["status"] = decision
        updated["response"] = responseText
        updated["responseDate"] = ISO8601DateFormatter().string(from: Date())
        if let data = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(data, forKey: key)
        }
        onDone()
    }
}
