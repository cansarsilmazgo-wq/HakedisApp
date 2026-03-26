import SwiftUI

struct ContentView: View {
    @State private var showingSearch = false
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DashboardView()
                    .tabItem { Label("Ana Ekran", systemImage: "square.grid.2x2") }
                ProjectListView()
                    .tabItem { Label("Projeler", systemImage: "building.2") }
                ContractorListView()
                    .tabItem { Label("Taşeronlar", systemImage: "person.2") }
                DailyEntryListView()
                    .tabItem { Label("Saha", systemImage: "pencil.and.list.clipboard") }
                PhotoGalleryView()
                    .tabItem { Label("Galeri", systemImage: "photo.on.rectangle.angled") }
                ReportsView()
                    .tabItem { Label("Raporlar", systemImage: "chart.bar") }
                SettingsView()
                    .tabItem { Label("Ayarlar", systemImage: "gear") }
            }
            .tint(.hakedisOrange)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showingSearch) { UniversalSearchView() }

            NetworkStatusBanner()
                .animation(.easeInOut, value: networkMonitor.isConnected)
        }
    }
}
