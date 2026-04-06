import SwiftUI
import SwiftData

struct SantiyeTabView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedSegment = 0

    private var role: UserRole { authManager.currentRole }

    private var visibleSegments: [(title: String, originalIndex: Int)] {
        var result: [(String, Int)] = []
        if role.canSeeDailyEntry           { result.append(("Saha", 0)) }
        if role.canSeeSiteDiary            { result.append(("Günlük", 1)) }
        if role.canSeeAttendance           { result.append(("Puantaj", 2)) }
        if role.canManageWorkers           { result.append(("İşçiler", 3)) }
        if role.canManageMaterials         { result.append(("Malzeme", 4)) }
        if role.canManageEquipment         { result.append(("Ekipman", 5)) }
        if role.canManageSafety            { result.append(("İSG", 6)) }
        if role.canSeeSubcontractorDetails { result.append(("Taşeronlar", 7)) }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(visibleSegments.indices, id: \.self) { i in
                            let seg = visibleSegments[i]
                            Button {
                                selectedSegment = i
                            } label: {
                                Text(seg.title)
                                    .font(.subheadline.weight(selectedSegment == i ? .semibold : .regular))
                                    .foregroundColor(selectedSegment == i ? .hakedisOrange : .secondary)
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .overlay(
                                        Rectangle().frame(height: 2)
                                            .foregroundColor(selectedSegment == i ? .hakedisOrange : .clear),
                                        alignment: .bottom
                                    )
                            }
                            .accessibilityLabel(seg.title)
                            .accessibilityAddTraits(selectedSegment == i ? .isSelected : [])
                        }
                    }
                }
                .background(Color.hakedisCard)
                Divider()
                ZStack {
                    if selectedSegment < visibleSegments.count {
                        let originalIdx = visibleSegments[selectedSegment].originalIndex
                        switch originalIdx {
                        case 0: DailyEntryListView()
                        case 1: SiteDiaryListView()
                        case 2: AttendanceListView()
                        case 3: WorkerListView()
                        case 4: MaterialStockSubTabView()
                        case 5: EquipmentSubTabView()
                        case 6: SafetySubTabView()
                        case 7: TaseronSegmentView()
                        default: EmptyView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Şantiye")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - TaseronSegmentView

struct TaseronSegmentView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        List {
            Section("Taşeron Yönetimi") {
                NavigationLink(destination: ContractorListView()) {
                    Label("Taşeron Listesi", systemImage: "person.crop.circle")
                        .accessibilityLabel("Taşeron Listesi")
                }
                NavigationLink(destination: SubcontractorHakedisListView()) {
                    Label("Taşeron Hakedişleri", systemImage: "building.2")
                        .accessibilityLabel("Taşeron Hakedişleri")
                }
                if authManager.currentRole.canSeeProfitability {
                    NavigationLink(destination: ProfitAnalysisView()) {
                        Label("Kâr Analizi", systemImage: "chart.bar.xaxis")
                            .accessibilityLabel("Kâr Analizi")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
