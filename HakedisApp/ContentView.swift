import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Query private var projects: [Project]
    @Query private var hakedisler: [Hakedis]

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DashboardView()
                    .tabItem { Label("Ana Ekran", systemImage: "house.fill") }
                    .accessibilityLabel("Ana Ekran")

                ProjectListView()
                    .tabItem { Label("Projeler", systemImage: "folder.fill") }
                    .accessibilityLabel("Projeler")

                SantiyeTabView()
                    .tabItem { Label("Şantiye", systemImage: "hammer.fill") }
                    .accessibilityLabel("Şantiye")

                FinansTabView()
                    .tabItem { Label("Finans", systemImage: "banknote.fill") }
                    .accessibilityLabel("Finans")

                MoreTabView()
                    .tabItem { Label("Daha Fazla", systemImage: "ellipsis.circle.fill") }
                    .accessibilityLabel("Daha Fazla")
            }
            .tint(.hakedisOrange)

            NetworkStatusBanner()
                .animation(.easeInOut, value: networkMonitor.isConnected)
        }
        .task {
            WidgetDataManager.update(projects: projects, hakedisler: hakedisler)
            NotificationManager.shared.clearBadge()
        }
        .onChange(of: hakedisler.count) {
            WidgetDataManager.update(projects: projects, hakedisler: hakedisler)
        }
        .onChange(of: projects.count) {
            WidgetDataManager.update(projects: projects, hakedisler: hakedisler)
        }
        .onChange(of: hakedisler.map { $0.totalPaid }.reduce(0, +)) {
            WidgetDataManager.update(projects: projects, hakedisler: hakedisler)
        }
    }
}
