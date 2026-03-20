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
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("\(contractCount) sözleşme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if totalAmount > 0 {
                    Text(totalAmount.currencyFormatted)
                        .font(.caption.bold())
                        .foregroundStyle(.hakedisOrange)
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

    var body: some View {
        List {
            // Summary Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Toplam Sözleşme")
                                .font(.caption).foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }
                    Label(project.startDate.shortFormatted, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Contracts
            Section {
                if project.contracts.isEmpty {
                    Text("Henüz sözleşme eklenmedi")
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.hakedisOrange)
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddContract) {
            AddContractView(project: project)
        }
    }
}
