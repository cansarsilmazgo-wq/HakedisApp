import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - ProjectMapView

struct ProjectMapView: View {
    @Query private var projects: [Project]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597),  // Ankara
        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
    )
    @State private var selectedProject: Project?
    @State private var showDetail = false
    @State private var nearestProject: Project?
    @StateObject private var locationManager = SimpleLocationManager()
    @Environment(\.modelContext) private var modelContext

    private var mappableProjects: [Project] {
        projects.filter { $0.hasCoordinates }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(coordinateRegion: $region, annotationItems: mappableProjects) { project in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(
                        latitude: project.latitude ?? 0,
                        longitude: project.longitude ?? 0
                    )) {
                        projectPin(project)
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                // Alt panel — seçili proje özeti
                if let selected = selectedProject {
                    projectSummaryCard(selected)
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.section)
                        .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle("Proje Haritası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        findNearestProject()
                    } label: {
                        Label("En Yakın", systemImage: "location.fill")
                    }
                    .accessibilityLabel("En Yakın Projeyi Bul")
                }
            }
            .sheet(isPresented: $showDetail) {
                if let project = selectedProject {
                    ProjectDetailSheetView(project: project)
                }
            }
            .onAppear {
                centerMapOnProjects()
            }
        }
    }

    private func projectPin(_ project: Project) -> some View {
        Button {
            selectedProject = project
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(pinColor(project.status))
                        .frame(width: 36, height: 36)
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                Text(project.name)
                    .font(.caption2.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 80)
                    .padding(.horizontal, 4)
                    .background(Color.hakedisCard.opacity(0.9))
                    .cornerRadius(4)
            }
        }
        .accessibilityLabel("Proje: \(project.name)")
    }

    private func pinColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .active:    return .hakedisSuccess
        case .completed: return .blue
        case .paused:    return .hakedisWarning
        }
    }

    private func projectSummaryCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(project.name)
                    .font(.headline)
                Spacer()
                StatusBadge(text: project.status.rawValue, color: pinColor(project.status))
                Button {
                    selectedProject = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Kapat")
            }

            Text(project.location)
                .font(.caption)
                .foregroundColor(.secondary)

            let activeContracts = project.contracts
            let totalBudget = activeContracts.reduce(0.0) { $0 + ($1.workItems.reduce(0.0) { $0 + $1.contractedQuantity * $1.unitPrice }) }

            if totalBudget > 0 {
                HStack {
                    Text("Bütçe:")
                        .font(.caption)
                    Text(totalBudget.compactCurrency)
                        .font(.caption.bold())
                }
            }

            Button {
                showDetail = true
            } label: {
                Text("Detaya Git")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.hakedisOrange)
                    .cornerRadius(8)
            }
            .accessibilityLabel("Proje detayına git: \(project.name)")
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .cornerRadius(16)
        .shadow(radius: 8)
    }

    private func centerMapOnProjects() {
        guard !mappableProjects.isEmpty else { return }
        let lats = mappableProjects.compactMap { $0.latitude }
        let lons = mappableProjects.compactMap { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max(0.5, (maxLat - minLat) * 1.4)
        let spanLon = max(0.5, (maxLon - minLon) * 1.4)

        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }

    private func findNearestProject() {
        locationManager.requestLocation { location in
            guard let location else { return }
            let userLat = location.coordinate.latitude
            let userLon = location.coordinate.longitude

            let nearest = mappableProjects.min { a, b in
                haversine(lat1: userLat, lon1: userLon,
                          lat2: a.latitude ?? 0, lon2: a.longitude ?? 0)
                <
                haversine(lat1: userLat, lon1: userLon,
                          lat2: b.latitude ?? 0, lon2: b.longitude ?? 0)
            }

            DispatchQueue.main.async {
                if let nearest {
                    selectedProject = nearest
                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: nearest.latitude ?? userLat,
                            longitude: nearest.longitude ?? userLon
                        ),
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                }
            }
        }
    }

    // Haversine formülü — km cinsinden mesafe
    private func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

// MARK: - ProjectDetailSheetView

struct ProjectDetailSheetView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Proje Bilgileri") {
                    LabeledContent("Ad", value: project.name)
                    LabeledContent("Durum", value: project.status.rawValue)
                    LabeledContent("Konum", value: project.location)
                    if let lat = project.latitude, let lon = project.longitude {
                        LabeledContent("Koordinat", value: String(format: "%.4f, %.4f", lat, lon))
                    }
                    LabeledContent("Başlangıç", value: project.startDate.formatted(date: .abbreviated, time: .omitted))
                }
                Section("Sözleşmeler") {
                    if project.contracts.isEmpty {
                        Text("Sözleşme yok.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(project.contracts, id: \.id) { contract in
                            VStack(alignment: .leading) {
                                Text(contract.title)
                                    .font(.subheadline)
                                Text(contract.contractor?.name ?? "—")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                if project.hasCoordinates {
                    Section("Mini Harita") {
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: project.latitude ?? 0,
                                longitude: project.longitude ?? 0
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )))
                        .frame(height: 200)
                        .cornerRadius(10)
                        .listRowInsets(EdgeInsets())
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
