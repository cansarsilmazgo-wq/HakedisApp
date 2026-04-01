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
                    .tabItem { Label("Ana Ekran", systemImage: "square.grid.2x2") }
                    .accessibilityLabel("Ana Ekran")
                ProjectListView()
                    .tabItem { Label("Projeler", systemImage: "building.2") }
                    .accessibilityLabel("Projeler")
                ContractorListView()
                    .tabItem { Label("Taşeronlar", systemImage: "person.2") }
                    .accessibilityLabel("Taşeronlar")
                DailyEntryListView()
                    .tabItem { Label("Saha", systemImage: "pencil.and.list.clipboard") }
                    .accessibilityLabel("Saha Girişi")
                PhotoGalleryView()
                    .tabItem { Label("Galeri", systemImage: "photo.on.rectangle.angled") }
                    .accessibilityLabel("Fotoğraf Galerisi")
                ReportsView()
                    .tabItem { Label("Raporlar", systemImage: "chart.bar") }
                    .accessibilityLabel("Raporlar")
                SettingsView()
                    .tabItem { Label("Ayarlar", systemImage: "gear") }
                    .accessibilityLabel("Ayarlar")
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
