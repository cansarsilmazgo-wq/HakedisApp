import SwiftUI
import SwiftData

// MARK: - Universal Search
struct UniversalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]
    @Query private var contractors: [Contractor]
    @Query private var workItems: [WorkItem]
    @Query private var hakedisler: [Hakedis]

    @State private var query = ""
    @FocusState private var focused: Bool

    var results: SearchResults {
        guard query.count >= 2 else { return .empty }
        let q = query.lowercased()
        return SearchResults(
            projects: projects.filter { $0.name.lowercased().contains(q) || $0.location.lowercased().contains(q) },
            contractors: contractors.filter { $0.name.lowercased().contains(q) || $0.contactPerson.lowercased().contains(q) },
            workItems: workItems.filter { $0.name.lowercased().contains(q) || $0.code.lowercased().contains(q) },
            hakedisler: hakedisler.filter { $0.periodName.lowercased().contains(q) || ($0.contract?.title.lowercased().contains(q) ?? false) }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if query.count < 2 {
                    ContentUnavailableView("Aramak için yazın", systemImage: "magnifyingglass",
                        description: Text("En az 2 karakter girin"))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    if !results.projects.isEmpty {
                        Section("Projeler (\(results.projects.count))") {
                            ForEach(results.projects) { project in
                                NavigationLink(destination: ProjectDetailView(project: project)) {
                                    SearchResultRow(
                                        icon: "building.2", title: project.name,
                                        subtitle: project.location, badge: project.status.rawValue,
                                        badgeColor: project.status == .active ? .hakedisSuccess : .secondary
                                    )
                                }
                            }
                        }
                    }
                    if !results.contractors.isEmpty {
                        Section("Taşeronlar (\(results.contractors.count))") {
                            ForEach(results.contractors) { contractor in
                                NavigationLink(destination: ContractorDetailView(contractor: contractor)) {
                                    SearchResultRow(
                                        icon: "person.2", title: contractor.name,
                                        subtitle: contractor.contactPerson.isEmpty ? nil : contractor.contactPerson,
                                        badge: "\(contractor.contracts.count) sözleşme", badgeColor: .hakedisOrange
                                    )
                                }
                            }
                        }
                    }
                    if !results.workItems.isEmpty {
                        Section("İş Kalemleri (\(results.workItems.count))") {
                            ForEach(results.workItems) { item in
                                NavigationLink(destination: WorkItemDetailView(workItem: item)) {
                                    SearchResultRow(
                                        icon: "list.bullet.rectangle", title: item.name,
                                        subtitle: "[\(item.code)] • \(item.contract?.title ?? "—")",
                                        badge: item.completionPercentage.percentFormatted, badgeColor: .hakedisOrange
                                    )
                                }
                            }
                        }
                    }
                    if !results.hakedisler.isEmpty {
                        Section("Hakedişler (\(results.hakedisler.count))") {
                            ForEach(results.hakedisler) { hakedis in
                                NavigationLink(destination: HakedisDetailView(hakedis: hakedis)) {
                                    SearchResultRow(
                                        icon: "doc.text", title: hakedis.periodName,
                                        subtitle: hakedis.contract?.title,
                                        badge: hakedis.status.rawValue,
                                        badgeColor: hakedisStatusColor(hakedis.status)
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ara")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Proje, taşeron, poz...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .onAppear { focused = true }
    }

    private func hakedisStatusColor(_ status: HakedisStatus) -> Color {
        switch status {
        case .draft: return .secondary
        case .pendingApproval: return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        case .paid: return .blue
        }
    }
}

struct SearchResultRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let badge: String
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            StatusBadge(text: badge, color: badgeColor)
        }
    }
}

struct SearchResults {
    let projects: [Project]
    let contractors: [Contractor]
    let workItems: [WorkItem]
    let hakedisler: [Hakedis]

    static let empty = SearchResults(projects: [], contractors: [], workItems: [], hakedisler: [])

    var isEmpty: Bool {
        projects.isEmpty && contractors.isEmpty && workItems.isEmpty && hakedisler.isEmpty
    }
}

// MARK: - Hakedis Filter
struct HakedisFilterView: View {
    @Binding var selectedStatus: HakedisStatus?
    @Binding var selectedContractor: Contractor?
    @Query private var contractors: [Contractor]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filtrele").font(.headline).padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("Durum").font(.subheadline.bold()).foregroundColor(.secondary).padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: selectedStatus == nil) {
                            selectedStatus = nil
                        }
                        ForEach(HakedisStatus.allCases, id: \.self) { status in
                            FilterChip(title: status.rawValue, isSelected: selectedStatus == status) {
                                selectedStatus = selectedStatus == status ? nil : status
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Taşeron").font(.subheadline.bold()).foregroundColor(.secondary).padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: selectedContractor == nil) {
                            selectedContractor = nil
                        }
                        ForEach(contractors) { contractor in
                            FilterChip(title: contractor.name, isSelected: selectedContractor?.id == contractor.id) {
                                selectedContractor = selectedContractor?.id == contractor.id ? nil : contractor
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.hakedisOrange : Color(UIColor.secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color(UIColor.separator), lineWidth: 0.5))
        }
    }
}
