import SwiftUI
import SwiftData

struct AllPaymentsView: View {
    @Query(sort: \Payment.paymentDate, order: .reverse) private var allPayments: [Payment]
    @Query private var projects: [Project]

    @State private var selectedProjectID: UUID? = nil
    @State private var searchText = ""

    private var filtered: [Payment] {
        allPayments.filter { p in
            if let pid = selectedProjectID {
                guard p.hakedis?.contract?.project?.id == pid else { return false }
            }
            if !searchText.isEmpty {
                let projectName = p.hakedis?.contract?.project?.name ?? ""
                let periodName = p.hakedis?.periodName ?? ""
                guard projectName.localizedCaseInsensitiveContains(searchText)
                    || periodName.localizedCaseInsensitiveContains(searchText) else { return false }
            }
            return true
        }
    }

    private var totalFiltered: Double {
        filtered.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Ödeme ara...", text: $searchText)
                        .accessibilityLabel("Ödeme ara")
                }
                .padding(10)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    icon: "creditcard.slash",
                    title: "Ödeme bulunamadı",
                    subtitle: "Henüz ödeme kaydı yok"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        HStack {
                            Text("\(filtered.count) ödeme")
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("Toplam: \(totalFiltered.currencyFormatted)")
                                .font(.caption.bold()).foregroundColor(.hakedisSuccess)
                        }
                    }
                    .listRowBackground(Color.hakedisBackground)

                    ForEach(filtered, id: \.id) { payment in
                        PaymentRow(payment: payment)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color.hakedisBackground)
    }
}

private struct PaymentRow: View {
    let payment: Payment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(payment.amount.currencyFormatted)
                    .font(.subheadline.bold())
                    .foregroundColor(.hakedisSuccess)
                Spacer()
                Text(payment.paymentDate.shortFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let hakedis = payment.hakedis {
                Text(hakedis.periodName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let project = hakedis.contract?.project {
                    Text(project.name)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ödeme \(payment.amount.currencyFormatted), \(payment.paymentDate.shortFormatted)")
    }
}
