import SwiftUI
import SwiftData

struct AllGuaranteeListView: View {
    @Query(sort: \Guarantee.expiryDate) private var allGuarantees: [Guarantee]
    @Query private var projects: [Project]

    @State private var selectedProjectID: UUID? = nil
    @State private var showOnlyActive = true

    private var filtered: [Guarantee] {
        allGuarantees.filter { g in
            if showOnlyActive, g.isReturned { return false }
            if let pid = selectedProjectID {
                guard g.contract?.project?.id == pid else { return false }
            }
            return true
        }
    }

    private var totalActive: Double {
        filtered.filter { !$0.isReturned }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Toggle("Sadece Aktif", isOn: $showOnlyActive)
                        .font(.caption)
                        .accessibilityLabel("Sadece aktif teminatları göster")
                    Spacer()
                    Text("Toplam: \(totalActive.currencyFormatted)")
                        .font(.caption.bold())
                        .foregroundColor(.hakedisOrange)
                }
                .padding(.horizontal, Spacing.card)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tüm Projeler", isSelected: selectedProjectID == nil) {
                            selectedProjectID = nil
                        }
                        ForEach(projects, id: \.id) { p in
                            FilterChip(title: p.name, isSelected: selectedProjectID == p.id) {
                                selectedProjectID = selectedProjectID == p.id ? nil : p.id
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card)
                }
            }
            .padding(.vertical, 8)
            .background(Color.hakedisBackground)

            if filtered.isEmpty {
                EmptyStateView(
                    icon: "lock.shield",
                    title: "Teminat bulunamadı",
                    subtitle: "Henüz teminat mektubu kaydı yok"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered, id: \.id) { g in
                        GuaranteeRowItem(guarantee: g)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color.hakedisBackground)
    }
}

private struct GuaranteeRowItem: View {
    let guarantee: Guarantee

    private var statusColor: Color {
        if guarantee.isReturned { return .secondary }
        if guarantee.isExpired { return .hakedisDanger }
        if guarantee.isExpiringSoon { return .hakedisWarning }
        return .hakedisSuccess
    }

    private var statusText: String {
        if guarantee.isReturned { return "İade Edildi" }
        if guarantee.isExpired { return "Süresi Doldu" }
        if guarantee.isExpiringSoon { return "\(guarantee.daysUntilExpiry)g kaldı" }
        return "Aktif"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(guarantee.bankName.isEmpty ? "Banka belirtilmedi" : guarantee.bankName)
                    .font(.subheadline.bold())
                Spacer()
                StatusBadge(text: statusText, color: statusColor)
            }
            HStack {
                Text(guarantee.guaranteeType.rawValue)
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(guarantee.amount.currencyFormatted)
                    .font(.caption.bold()).foregroundColor(.hakedisOrange)
            }
            HStack {
                if let project = guarantee.contract?.project {
                    Text(project.name)
                        .font(.caption2).foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
                Text("Son: \(guarantee.expiryDate.shortFormatted)")
                    .font(.caption2).foregroundColor(statusColor)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guarantee.bankName), \(guarantee.amount.currencyFormatted), \(statusText)")
    }
}
