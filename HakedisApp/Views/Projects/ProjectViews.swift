import SwiftUI
import SwiftData

// MARK: - Project List
struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var showingAddProject = false
    @State private var searchText = ""

    private var filtered: [Project] {
        if searchText.isEmpty { return projects }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    EmptyStateView(
                        icon: "building.2",
                        title: "Proje bulunamadı",
                        subtitle: "Yeni bir proje ekleyerek başlayın",
                        actionTitle: "Proje Ekle",
                        action: { showingAddProject = true }
                    )
                } else {
                    List {
                        ForEach(filtered) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRow(project: project)
                            }
                        }
                        .onDelete(perform: deleteProjects)
                    }
                    .searchable(text: $searchText, prompt: "Proje ara...")
                }
            }
            .navigationTitle("Projeler")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectView()
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filtered[index])
        }
    }
}

// MARK: - Project Row
struct ProjectRow: View {
    let project: Project

    private var contractCount: Int { project.contracts.count }

    private var totalAmount: Double {
        project.contracts.reduce(0) { $0 + $1.totalContractAmount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.name)
                    .font(.headline)
                Spacer()
                StatusBadge(text: project.status.rawValue,
                           color: project.status == .active ? .hakedisSuccess : .secondary)
            }
            if !project.location.isEmpty {
                Label(project.location, systemImage: "mappin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("\(contractCount) sözleşme")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if totalAmount > 0 {
                    Text(totalAmount.currencyFormatted)
                        .font(.caption.bold())
                        .foregroundColor(.hakedisOrange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Project
struct AddProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var projectDescription = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var status: ProjectStatus = .active

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Proje Bilgileri") {
                    TextField("Proje Adı *", text: $name)
                    TextField("Açıklama", text: $projectDescription, axis: .vertical)
                        .lineLimit(3)
                    TextField("Lokasyon", text: $location)
                }
                Section("Detaylar") {
                    DatePicker("Başlangıç Tarihi", selection: $startDate, displayedComponents: .date)
                    Picker("Durum", selection: $status) {
                        ForEach(ProjectStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }
            }
            .navigationTitle("Yeni Proje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(!isValid)
                        .bold()
                }
            }
        }
    }

    private func save() {
        let project = Project(
            name: name.trimmingCharacters(in: .whitespaces),
            projectDescription: projectDescription,
            location: location,
            startDate: startDate
        )
        project.status = status
        modelContext.insert(project)
        dismiss()
    }
}

// MARK: - Project Detail
struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var showingAddContract = false

    // MARK: Pursantaj Tahmini hesapları
    private var allWorkItems: [WorkItem] {
        project.contracts.flatMap { $0.workItems }
    }

    private var totalContractValue: Double {
        allWorkItems.reduce(0) { $0 + $1.totalAmount }
    }

    private var totalCompletedValue: Double {
        allWorkItems.reduce(0) { $0 + ($1.completedQuantity * $1.unitPrice) }
    }

    private var overallCompletion: Double {
        guard totalContractValue > 0 else { return 0 }
        return min((totalCompletedValue / totalContractValue) * 100, 100)
    }

    /// Son 30 günün ortalama günlük üretim değeri (₺/gün)
    private var dailyPace: Double {
        let cal = Calendar.current
        let thirtyDaysAgo = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentValue = allWorkItems.reduce(0.0) { total, wi in
            let entries = wi.dailyEntries.filter { $0.date >= thirtyDaysAgo }
            return total + entries.reduce(0.0) { $0 + $1.quantity * wi.unitPrice }
        }
        return recentValue / 30.0
    }

    private var estimatedCompletionDate: Date? {
        guard dailyPace > 0 else { return nil }
        let remaining = totalContractValue - totalCompletedValue
        guard remaining > 0 else { return nil }
        let days = Int((remaining / dailyPace).rounded(.up))
        return Calendar.current.date(byAdding: .day, value: days, to: Date())
    }

    var body: some View {
        List {
            // Summary Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Toplam Sözleşme")
                                .font(.caption).foregroundColor(.secondary)
                            Text(project.contracts.reduce(0) { $0 + $1.totalContractAmount }.currencyFormatted)
                                .font(.title3.bold())
                        }
                        Spacer()
                        StatusBadge(text: project.status.rawValue,
                                   color: project.status == .active ? .hakedisSuccess : .secondary)
                    }
                    if !project.location.isEmpty {
                        Label(project.location, systemImage: "mappin.circle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Label(project.startDate.shortFormatted, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Pursantaj Tahmini
            if totalContractValue > 0 {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Genel Tamamlanma")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(overallCompletion.percentFormatted)
                                .font(.headline)
                                .foregroundColor(overallCompletion >= 100 ? .hakedisSuccess : .hakedisOrange)
                        }
                        ProgressBarView(
                            progress: overallCompletion,
                            color: overallCompletion >= 100 ? .hakedisSuccess : .hakedisOrange
                        )
                        if overallCompletion >= 100 {
                            Label("Tüm işler tamamlandı", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.hakedisSuccess)
                        } else if let est = estimatedCompletionDate {
                            Divider()
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Günlük Tempo (30g ort.)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(dailyPace.currencyFormatted)/gün")
                                        .font(.subheadline.bold())
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Tahmini Bitiş")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(est.shortFormatted)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.hakedisOrange)
                                }
                            }
                        } else {
                            Label("Tempo hesaplamak için günlük giriş yapın", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Pursantaj Tahmini")
                }
            }

            // Saha Raporları
            Section {
                let reports = project.siteReports.sorted { $0.date > $1.date }
                let todayExists = reports.contains { Calendar.current.isDateInToday($0.date) }
                let issueCount = reports.filter { $0.hasIssues }.count
                NavigationLink(destination: SiteReportListView(project: project)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saha Raporları")
                                .font(.subheadline)
                            Text("\(reports.count) rapor\(reports.isEmpty ? "" : " • son: \(reports.first!.date.shortFormatted)")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !todayExists && project.status == .active {
                            StatusBadge(text: "Bugün eksik", color: .hakedisWarning)
                        } else if issueCount > 0 {
                            StatusBadge(text: "\(issueCount) sorun", color: .hakedisDanger)
                        }
                    }
                }
            } header: {
                Text("Saha Raporları")
            }

            // İş Programı
            Section {
                let milestones = project.milestones.sorted { $0.plannedDate < $1.plannedDate }
                let overdueCnt = milestones.filter { $0.isOverdue }.count
                let completedCnt = milestones.filter { $0.isCompleted }.count
                NavigationLink(destination: MilestoneListView(project: project)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("İş Programı")
                                .font(.subheadline)
                            Text("\(milestones.count) kilometre taşı • \(completedCnt) tamamlandı")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if overdueCnt > 0 {
                            StatusBadge(text: "\(overdueCnt) gecikti", color: .hakedisDanger)
                        } else if !milestones.isEmpty {
                            StatusBadge(
                                text: milestones.isEmpty ? "—" : "\(Int(Double(completedCnt) / Double(milestones.count) * 100))%",
                                color: .hakedisSuccess
                            )
                        }
                    }
                }
            } header: {
                Text("İş Programı")
            }

            // Contracts
            Section {
                if project.contracts.isEmpty {
                    Text("Henüz sözleşme eklenmedi")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(project.contracts) { contract in
                        NavigationLink(destination: ContractDetailView(contract: contract)) {
                            ContractRow(contract: contract)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Sözleşmeler")
                    Spacer()
                    Button {
                        showingAddContract = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.hakedisOrange)
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: ProjectPDFReportView(project: project)) {
                    Image(systemName: "doc.richtext")
                }
            }
        }
        .sheet(isPresented: $showingAddContract) {
            AddContractView(project: project)
        }
    }
}
