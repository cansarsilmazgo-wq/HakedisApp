import SwiftUI
import SwiftData

struct UniversalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]
    @Query private var contractors: [Contractor]
    @Query private var workItems: [WorkItem]
    @Query private var hakedisler: [Hakedis]
    @State private var query = ""

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
                    ContentUnavailableView("Aramak için yazın", systemImage: "magnifyingglass", description: Text("En az 2 karakter girin"))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    if !results.projects.isEmpty {
                        Section("Projeler (\(results.projects.count))") {
                            ForEach(results.projects) { p in
                                NavigationLink(destination: ProjectDetailView(project: p)) {
                                    SearchResultRow(icon: "building.2", title: p.name, subtitle: p.location, badge: p.status.rawValue, badgeColor: p.status == .active ? .hakedisSuccess : .secondary)
                                }
                            }
                        }
                    }
                    if !results.contractors.isEmpty {
                        Section("Taşeronlar (\(results.contractors.count))") {
                            ForEach(results.contractors) { c in
                                NavigationLink(destination: ContractorDetailView(contractor: c)) {
                                    SearchResultRow(icon: "person.2", title: c.name, subtitle: c.contactPerson.isEmpty ? nil : c.contactPerson, badge: "\(c.contracts.count) sözleşme", badgeColor: .hakedisOrange)
                                }
                            }
                        }
                    }
                    if !results.workItems.isEmpty {
                        Section("İş Kalemleri (\(results.workItems.count))") {
                            ForEach(results.workItems) { i in
                                NavigationLink(destination: WorkItemDetailView(workItem: i)) {
                                    SearchResultRow(icon: "list.bullet.rectangle", title: i.name, subtitle: "[\(i.code)] • \(i.contract?.title ?? "—")", badge: i.completionPercentage.percentFormatted, badgeColor: .hakedisOrange)
                                }
                            }
                        }
                    }
                    if !results.hakedisler.isEmpty {
                        Section("Hakedişler (\(results.hakedisler.count))") {
                            ForEach(results.hakedisler) { h in
                                NavigationLink(destination: HakedisDetailView(hakedis: h)) {
                                    SearchResultRow(icon: "doc.text", title: h.periodName, subtitle: h.contract?.title, badge: h.status.rawValue, badgeColor: .hakedisWarning)
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
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
            }
        }
    }
}

struct SearchResultRow: View {
    let icon: String; let title: String; let subtitle: String?; let badge: String; let badgeColor: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.subheadline).foregroundColor(.secondary).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                if let subtitle { Text(subtitle).font(.caption).foregroundColor(.secondary) }
            }
            Spacer()
            StatusBadge(text: badge, color: badgeColor)
        }
    }
}

struct SearchResults {
    let projects: [Project]; let contractors: [Contractor]; let workItems: [WorkItem]; let hakedisler: [Hakedis]
    static let empty = SearchResults(projects: [], contractors: [], workItems: [], hakedisler: [])
    var isEmpty: Bool { projects.isEmpty && contractors.isEmpty && workItems.isEmpty && hakedisler.isEmpty }
}

struct FilterChip: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline).padding(.horizontal, 14).padding(.vertical, 7)
                .background(isSelected ? Color.hakedisOrange : Color(UIColor.secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
