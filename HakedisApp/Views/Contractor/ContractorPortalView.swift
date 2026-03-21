import SwiftUI
import SwiftData

struct ContractorPortalView: View {
    @Query private var contractors: [Contractor]
    @State private var selectedContractor: Contractor?
    @State private var isAuthenticated = false

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
    }

    var loginView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .font(.system(size: 56))
                        .foregroundColor(.hakedisOrange)
                    Text("Taseron Girisi").font(.title.bold())
                    Text("Hakedislerinizi gormek icin firmay secin")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    ForEach(contractors) { contractor in
                        Button {
                            selectedContractor = contractor
                            isAuthenticated = true
                        } label: {
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
                                Image(systemName: "chevron.right").foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if contractors.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: "Taseron bulunamadi",
                            subtitle: "Taseronlar sekmesinden once taseron ekleyin"
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Taseron Portali")
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
                        PortalStatItem(label: "Odenen", value: totalPaid.currencyFormatted, color: .hakedisSuccess)
                        Divider().frame(height: 40)
                        PortalStatItem(label: "Bekleyen", value: totalPending.currencyFormatted, color: totalPending > 0 ? .hakedisDanger : .hakedisSuccess)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Hakedislerim") {
                if allHakedisler.isEmpty {
                    Text("Henuz hakedis yok").foregroundColor(.secondary)
                } else {
                    ForEach(allHakedisler) { h in
                        NavigationLink(destination: ContractorHakedisDetailView(hakedis: h)) {
                            ContractorHakedisRow(hakedis: h)
                        }
                    }
                }
            }

            Section("Sozlesmelerim") {
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
        .navigationTitle("Portalim")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cikis") { onLogout() }.foregroundColor(.hakedisDanger)
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
                            Text("Net Hakedis").font(.caption).foregroundColor(.secondary)
                            Text(hakedis.netAmount.currencyFormatted).font(.title2.bold())
                        }
                        Spacer()
                        StatusBadge(text: hakedis.status.rawValue, color: .hakedisOrange)
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Brut").font(.caption).foregroundColor(.secondary)
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

            Section("Is Kalemleri") {
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
                            Text("Itiraziniz iletildi").foregroundColor(.hakedisSuccess)
                        }
                    } else {
                        Button { showingObjection = true } label: {
                            Label("Itiraz Bildir", systemImage: "exclamationmark.bubble")
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
                Section("Itiraz Kalemi") {
                    Picker("Kalem", selection: $selectedItem) {
                        Text("Genel Itiraz").tag(Optional<HakedisItem>.none)
                        ForEach(hakedis.items) { i in
                            Text("[\(i.workItemCode)] \(i.workItemName)").tag(Optional(i))
                        }
                    }
                }
                Section("Aciklama") {
                    TextEditor(text: $text).frame(minHeight: 80)
                }
            }
            .navigationTitle("Itiraz Bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Iptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gonder") { onSubmit() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
        }
    }
}
