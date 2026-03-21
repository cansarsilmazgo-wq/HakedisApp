import SwiftUI

struct ContentView: View {
    @State private var showingSearch = false

    var body: some View {
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
        }
        .tint(.hakedisOrange)
        .overlay(alignment: .topTrailing) {
            Button { showingSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .padding(12)
            }
        }
        .sheet(isPresented: $showingSearch) { UniversalSearchView() }
    }
}
