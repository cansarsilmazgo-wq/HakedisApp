import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Ana Ekran", systemImage: "square.grid.2x2")
                }

            ProjectListView()
                .tabItem {
                    Label("Projeler", systemImage: "building.2")
                }

            ContractorListView()
                .tabItem {
                    Label("Taşeronlar", systemImage: "person.2")
                }

            DailyEntryListView()
                .tabItem {
                    Label("Saha", systemImage: "pencil.and.list.clipboard")
                }

            ReportsView()
                .tabItem {
                    Label("Raporlar", systemImage: "chart.bar")
                }
        }
        .tint(.orange)
    }
}
