import SwiftUI
import SwiftData

// MARK: - Taşeron Portal Ana Ekranı
struct ContractorPortalView: View {
    @Query private var contractors: [Contractor]
    @State private var selectedContractor: Contractor?
    @State private var showingPinEntry = false
    @State private var isAuthenticated = false

    var body: some View {
        NavigationStack {
            if isAuthenticated, let contractor = selectedContractor {
                ContractorDashboardView(contractor: contractor) {
                    isAuthenticated = false
                    selectedContractor = nil
                }
            } else {
                contractorLoginView
            }
        }
    }

    var contractorLoginView: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(.system(size: 56))
                    .foregroundColor(.hakedisOrange)
                Text("Taşeron Girişi")
                    .font(.title.bold())
                Text("Hakedişlerinizi görüntülemek için\nfirmayı seçin")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

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
                            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal)

            if contractors.isEmpty {
                EmptyStateView(icon: "person.2", title: "Taşeron bulunamadı",
                    subtitle: "Taşeronlar sekmesinden önce taşeron ekleyin")
            }
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Taşeron Portalı")
    }
}

// MARK: - Taşeron Dashboard
struct ContractorDashboardView: View {
    let contractor: Contractor
    let onLogout: () -> Void

    private var allHakedisler: [Hakedis] {
        contractor.contracts.flatMap { $0.hakedisler }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var totalNet: Double { allHakedisler.reduce(0) { $0 + $1.netAmount } }
    private var totalPaid: Double { allHakedisler.reduce(0) { $0 + $1.totalPaid } }
    private var totalPending: Double { totalNet - totalPaid }
    private var pendingCount: Int { allHakedisler.filter { $0.status == .approved && $0.remainingAmount > 0 }.count }

    var body: some View {
        List {
            // Firma özeti
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
                        PortalStatItem(label: "Toplam Hakediş", value: totalNet.currencyFormatted, color: .primary)
                        Divider().frame(height: 40)
                        PortalStatItem(label: "Ödenen", value: totalPaid.currencyFormatted, color: .hakedisSuccess)
                        Divider().frame(height: 40)
                        PortalStatItem(label: "Bekleyen", value: totalPending.currencyFormatted, color: totalPending > 0 ? .hakedisDanger : .hakedisSuccess)
                    }
                }
                .padding(.vertical, 4)
            }

            // Bekleyen ödemeler uyarısı
            if pendingCount > 0 {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.hakedisWarning)
                        Text("\(pendingCount) hakedişiniz ödeme bekliyor")
                            .font(.subheadline)
                            .foregroundColor(.hakedisWarning)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Hakedişler
            Section("Hakedişlerim") {
                if allHakedisler.isEmpty {
                    Text("Henüz hakediş bulunmuyor").foregroundColor(.secondary)
                } else {
                    ForEach(allHakedisler) { hakedis in
                        NavigationLink(destination: ContractorHakedisDetailView(hakedis: hakedis)) {
                            ContractorHakedisRow(hakedis: hakedis)
                        }
                    }
                }
            }

            // Sözleşmeler
            Section("Sözleşmelerim") {
                ForEach(contractor.contracts) { contract in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(contract.title).font(.subheadline.bold())
                        HStack {
                            Text(contract.project?.name ?? "—").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(contract.totalContractAmount.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Hakediş Portalım")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Çıkış") { onLogout() }
                    .foregroundColor(.hakedisDanger)
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
                Text(hakedis.contract?.title ?? "—").font(.caption).foregroundColor(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(hakedis.netAmount.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
                    if hakedis.remainingAmount > 0 && hakedis.status != .draft {
                        Text("Kalan: \(hakedis.remainingAmount.currencyFormatted)").font(.caption2).foregroundColor(.hakedisDanger)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Taşeron Hakediş Detayı (Salt Okunur + İtiraz)
struct ContractorHakedisDetailView: View {
    let hakedis: Hakedis
    @State private var showingObjection = false
    @State private var objectionText = ""
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
                            Text("Teminat Kesintisi").font(.caption).foregroundColor(.secondary)
                            Text(hakedis.retentionAmount.currencyFormatted).font(.subheadline).foregroundColor(.hakedisDanger)
                        }
                    }
                    if hakedis.totalPaid > 0 {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ödenen").font(.caption).foregroundColor(.secondary)
                                Text(hakedis.totalPaid.currencyFormatted).font(.subheadline).foregroundColor(.hakedisSuccess)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Kalan").font(.caption).foregroundColor(.secondary)
                                Text(hakedis.remainingAmount.currencyFormatted).font(.subheadline.bold())
                                    .foregroundColor(hakedis.remainingAmount > 0 ? .hakedisDanger : .hakedisSuccess)
                            }
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
                        HStack(spacing: 12) {
                            Label("\(item.currentQuantity.quantityFormatted) \(item.unit)", systemImage: "ruler")
                                .font(.caption).foregroundColor(.secondary)
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
                        Button {
                            showingObjection = true
                        } label: {
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
                Section("İtiraz Edilecek Kalem") {
                    Picker("Kalem Seç", selection: $selectedItem) {
                        Text("Genel İtiraz").tag(Optional<HakedisItem>.none)
                        ForEach(hakedis.items) { item in
                            Text("[\(item.workItemCode)] \(item.workItemName)").tag(Optional(item))
                        }
                    }
                }
                Section("İtiraz Açıklaması") {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                }
                Section {
                    Text("İtirazınız yetkili mühendise iletilecektir.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("İtiraz Bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gönder") { onSubmit() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
        }
    }
}
