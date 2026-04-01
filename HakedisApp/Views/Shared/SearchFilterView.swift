import SwiftUI
import SwiftData

// MARK: - Search Category

enum SearchCategory: String, CaseIterable {
    case all         = "Tümü"
    case projects    = "Projeler"
    case contractors = "Taşeronlar"
    case workItems   = "İş Kalemleri"
    case hakedisler  = "Hakedişler"
}

// MARK: - Universal Search

struct UniversalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var projects:     [Project]
    @Query private var contractors:  [Contractor]
    @Query private var workItems:    [WorkItem]
    @Query private var hakedisler:   [Hakedis]

    @State private var query    = ""
    @State private var category: SearchCategory = .all
    @State private var hakedisStatusFilter: HakedisStatus? = nil
    @State private var dateFrom: Date? = nil
    @State private var dateTo: Date?   = nil
    @State private var showDateFilter  = false
    @AppStorage("recentSearches") private var recentSearchesData: Data = Data()

    private var recentSearches: [String] {
        get { (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? [] }
    }

    var results: SearchResults {
        guard query.count >= 2 else { return .empty }
        let q = query.lowercased()

        let filteredProjects: [Project] = (category == .all || category == .projects)
            ? projects.filter {
                $0.name.lowercased().contains(q) || $0.location.lowercased().contains(q)
              }
            : []

        let filteredContractors: [Contractor] = (category == .all || category == .contractors)
            ? contractors.filter {
                $0.name.lowercased().contains(q) || $0.contactPerson.lowercased().contains(q)
              }
            : []

        let filteredWorkItems: [WorkItem] = (category == .all || category == .workItems)
            ? workItems.filter {
                $0.name.lowercased().contains(q) || $0.code.lowercased().contains(q)
              }
            : []

        var filteredHakedisler: [Hakedis] = (category == .all || category == .hakedisler)
            ? hakedisler.filter {
                $0.periodName.lowercased().contains(q)
                || ($0.contract?.title.lowercased().contains(q) ?? false)
                || ($0.contract?.contractor?.name.lowercased().contains(q) ?? false)
              }
            : []

        if let statusFilter = hakedisStatusFilter {
            filteredHakedisler = filteredHakedisler.filter { $0.status == statusFilter }
        }
        if let from = dateFrom {
            filteredHakedisler = filteredHakedisler.filter { $0.periodStart >= from }
        }
        if let to = dateTo {
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: to) ?? to
            filteredHakedisler = filteredHakedisler.filter { $0.periodStart <= endOfDay }
        }

        return SearchResults(
            projects: filteredProjects,
            contractors: filteredContractors,
            workItems: filteredWorkItems,
            hakedisler: filteredHakedisler
        )
    }

    private var totalCount: Int {
        results.projects.count + results.contractors.count
        + results.workItems.count + results.hakedisler.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SearchCategory.allCases, id: \.self) { cat in
                            FilterChip(title: cat.rawValue, isSelected: category == cat) {
                                category = cat
                                if cat != .hakedisler { hakedisStatusFilter = nil }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Hakedis status filter (only when hakedisler or all selected)
                if category == .hakedisler || category == .all {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            FilterChip(title: "Tüm Durum", isSelected: hakedisStatusFilter == nil) {
                                hakedisStatusFilter = nil
                            }
                            ForEach(HakedisStatus.allCases, id: \.self) { status in
                                FilterChip(title: status.rawValue,
                                           isSelected: hakedisStatusFilter == status) {
                                    hakedisStatusFilter = (hakedisStatusFilter == status) ? nil : status
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 4)

                    // Date range filter
                    HStack(spacing: 8) {
                        Button {
                            showDateFilter.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text(dateFrom != nil || dateTo != nil ? "Tarih: \(dateRangeLabel)" : "Tarih Filtresi")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(dateFrom != nil || dateTo != nil
                                        ? Color.hakedisOrange : Color(UIColor.secondarySystemGroupedBackground))
                            .foregroundColor(dateFrom != nil || dateTo != nil ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        if dateFrom != nil || dateTo != nil {
                            Button {
                                dateFrom = nil
                                dateTo = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)

                    if showDateFilter {
                        VStack(spacing: 4) {
                            DatePicker("Başlangıç", selection: Binding(
                                get: { dateFrom ?? Date() },
                                set: { dateFrom = $0 }
                            ), displayedComponents: .date)
                            .padding(.horizontal)
                            DatePicker("Bitiş", selection: Binding(
                                get: { dateTo ?? Date() },
                                set: { dateTo = $0 }
                            ), displayedComponents: .date)
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 4)
                    }
                }

                Divider()

                List {
                    if query.count < 2 {
                        // Recent searches
                        let recent = recentSearches
                        if !recent.isEmpty {
                            Section("Son Aramalar") {
                                ForEach(recent, id: \.self) { term in
                                    Button {
                                        query = term
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(.secondary).font(.subheadline)
                                            Text(term).foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "arrow.up.left")
                                                .foregroundColor(.secondary).font(.caption)
                                        }
                                    }
                                }
                                .onDelete { indices in
                                    var updated = recent
                                    updated.remove(atOffsets: indices)
                                    saveRecent(updated)
                                }
                                Button("Temizle", role: .destructive) { saveRecent([]) }
                            }
                        } else {
                            ContentUnavailableView(
                                "Aramak için yazın",
                                systemImage: "magnifyingglass",
                                description: Text("En az 2 karakter girin")
                            )
                        }
                    } else if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                    } else {
                        // Result count header
                        Section {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.hakedisSuccess)
                                Text("\(totalCount) sonuç bulundu")
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                        .listRowBackground(Color.clear)

                        if !results.projects.isEmpty {
                            Section("Projeler (\(results.projects.count))") {
                                ForEach(results.projects) { p in
                                    NavigationLink(destination: ProjectDetailView(project: p)) {
                                        SearchResultRow(
                                            icon: "building.2",
                                            title: p.name,
                                            subtitle: p.location.isEmpty ? nil : p.location,
                                            badge: p.status.rawValue,
                                            badgeColor: p.status == .active ? .hakedisSuccess : .secondary
                                        )
                                    }
                                }
                            }
                        }

                        if !results.contractors.isEmpty {
                            Section("Taşeronlar (\(results.contractors.count))") {
                                ForEach(results.contractors) { c in
                                    NavigationLink(destination: ContractorDetailView(contractor: c)) {
                                        SearchResultRow(
                                            icon: "person.2",
                                            title: c.name,
                                            subtitle: c.contactPerson.isEmpty ? nil : c.contactPerson,
                                            badge: "\(c.contracts.count) sözleşme",
                                            badgeColor: .hakedisOrange
                                        )
                                    }
                                }
                            }
                        }

                        if !results.workItems.isEmpty {
                            Section("İş Kalemleri (\(results.workItems.count))") {
                                ForEach(results.workItems) { i in
                                    NavigationLink(destination: WorkItemDetailView(workItem: i)) {
                                        SearchResultRow(
                                            icon: "list.bullet.rectangle",
                                            title: i.name,
                                            subtitle: "[\(i.code)] • \(i.contract?.title ?? "—")",
                                            badge: i.completionPercentage.percentFormatted,
                                            badgeColor: i.completionPercentage >= 100 ? .hakedisSuccess : .hakedisOrange
                                        )
                                    }
                                }
                            }
                        }

                        if !results.hakedisler.isEmpty {
                            Section("Hakedişler (\(results.hakedisler.count))") {
                                ForEach(results.hakedisler) { h in
                                    NavigationLink(destination: HakedisDetailView(hakedis: h)) {
                                        SearchResultRow(
                                            icon: "doc.text",
                                            title: h.periodName,
                                            subtitle: h.contract?.title,
                                            badge: h.status.rawValue,
                                            badgeColor: statusColor(h.status)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Ara")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Proje, taşeron, poz, hakediş…"
            )
            .onChange(of: query) { _, newVal in
                if newVal.count >= 2 { saveSearchTerm(newVal) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(_ status: HakedisStatus) -> Color {
        switch status {
        case .draft:            return .secondary
        case .pendingApproval:  return .hakedisWarning
        case .approved:         return .hakedisSuccess
        case .rejected:         return .hakedisDanger
        case .paid:             return .hakedisPaid
        }
    }

    private var dateRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd.MM.yy"
        let from = dateFrom.map { fmt.string(from: $0) } ?? "…"
        let to   = dateTo.map   { fmt.string(from: $0) } ?? "…"
        return "\(from)–\(to)"
    }

    private func saveSearchTerm(_ term: String) {
        var updated = recentSearches.filter { $0 != term }
        updated.insert(term, at: 0)
        if updated.count > 10 { updated = Array(updated.prefix(10)) }
        saveRecent(updated)
    }

    private func saveRecent(_ list: [String]) {
        recentSearchesData = (try? JSONEncoder().encode(list)) ?? Data()
    }
}

// MARK: - Search Result Row

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
                if let subtitle { Text(subtitle).font(.caption).foregroundColor(.secondary) }
            }
            Spacer()
            StatusBadge(text: badge, color: badgeColor)
        }
    }
}

// MARK: - Search Results Model

struct SearchResults {
    let projects:    [Project]
    let contractors: [Contractor]
    let workItems:   [WorkItem]
    let hakedisler:  [Hakedis]

    static let empty = SearchResults(projects: [], contractors: [], workItems: [], hakedisler: [])
    var isEmpty: Bool { projects.isEmpty && contractors.isEmpty && workItems.isEmpty && hakedisler.isEmpty }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isSelected ? Color.hakedisOrange
                            : Color(UIColor.secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
