import SwiftUI
import SwiftData

struct AllHakedisListView: View {
    @Query(sort: \Hakedis.periodEnd, order: .reverse) private var allHakedisler: [Hakedis]
    @Query private var projects: [Project]

    @State private var selectedProjectID: UUID? = nil
    @State private var selectedStatus: HakedisStatus? = nil
    @State private var searchText = ""

    private var filtered: [Hakedis] {
        allHakedisler.filter { h in
            if let pid = selectedProjectID {
                guard h.contract?.project?.id == pid else { return false }
            }
            if let st = selectedStatus {
                guard h.status == st else { return false }
            }
            if !searchText.isEmpty {
                guard h.periodName.localizedCaseInsensitiveContains(searchText) else { return false }
            }
            return true
        }
    }

    private var totalFiltered: Double {
        filtered.reduce(0) { $0 + $1.netAmount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filters
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Hakediş ara...", text: $searchText)
                        .accessibilityLabel("Hakediş ara")
                }
                .padding(10)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, Spacing.card)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: selectedStatus == nil) {
                            selectedStatus = nil
                        }
                        ForEach(HakedisStatus.allCases, id: \.self) { st in
                            FilterChip(title: st.rawValue, isSelected: selectedStatus == st) {
                                selectedStatus = selectedStatus == st ? nil : st
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card)
                }

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
                    icon: "doc.text.magnifyingglass",
                    title: "Hakediş bulunamadı",
                    subtitle: "Filtrelerinizi değiştirmeyi deneyin"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        HStack {
                            Text("\(filtered.count) hakediş")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Toplam: \(totalFiltered.currencyFormatted)")
                                .font(.caption.bold())
                                .foregroundColor(.hakedisOrange)
                        }
                    }
                    .listRowBackground(Color.hakedisBackground)

                    ForEach(filtered, id: \.id) { hakedis in
                        NavigationLink(destination: LazyView(HakedisDetailView(hakedis: hakedis))) {
                            AllHakedisRow(hakedis: hakedis)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color.hakedisBackground)
    }
}

private struct AllHakedisRow: View {
    let hakedis: Hakedis

    private var statusColor: Color {
        switch hakedis.status {
        case .draft: return .secondary
        case .pendingApproval: return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        case .paid: return .hakedisPaid
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(hakedis.periodName)
                    .font(.subheadline.bold())
                Spacer()
                StatusBadge(text: hakedis.status.rawValue, color: statusColor)
            }
            if let project = hakedis.contract?.project {
                Text(project.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(hakedis.netAmount.currencyFormatted)
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
                Spacer()
                Text(hakedis.periodEnd.shortFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hakedis.periodName), \(hakedis.status.rawValue), \(hakedis.netAmount.currencyFormatted)")
    }
}

