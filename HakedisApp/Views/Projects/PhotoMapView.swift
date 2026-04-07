import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - PhotoMapView

struct PhotoMapView: View {
    @Query(sort: \GeoTaggedPhoto.photoDate, order: .reverse) private var allPhotos: [GeoTaggedPhoto]

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var selectedPhoto: GeoTaggedPhoto?
    @State private var filterModule: String? = nil
    @State private var filterDate: Date? = nil
    @State private var showingFilters = false

    private let moduleOptions = ["SiteDiary", "SafetyIncident", "QualityCheck", "DailyEntry"]
    private let moduleLabelMap: [String: String] = [
        "SiteDiary": "Saha Günlüğü",
        "SafetyIncident": "ISG Olayı",
        "QualityCheck": "Kalite Kontrol",
        "DailyEntry": "Günlük Giriş"
    ]

    private var filteredPhotos: [GeoTaggedPhoto] {
        allPhotos.filter { photo in
            let moduleMatch = filterModule.map { photo.sourceModule == $0 } ?? true
            let dateMatch: Bool
            if let fd = filterDate {
                dateMatch = Calendar.current.isDate(photo.photoDate, inSameDayAs: fd)
            } else {
                dateMatch = true
            }
            return moduleMatch && dateMatch
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if filteredPhotos.isEmpty {
                    EmptyStateView(
                        icon: "map",
                        title: "Coğrafi Fotoğraf Yok",
                        subtitle: "GPS verisi olan fotoğraflar burada görünür"
                    )
                } else {
                    Map(coordinateRegion: $region, annotationItems: filteredPhotos) { photo in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: photo.latitude,
                            longitude: photo.longitude
                        )) {
                            photoPin(photo)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .onAppear { centerOnPhotos() }
                }

                if let selected = selectedPhoto {
                    photoDetailCard(selected)
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.section)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedPhoto?.id)
            .navigationTitle("Fotoğraf Haritası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFilters.toggle()
                    } label: {
                        Label("Filtrele", systemImage: "line.3.horizontal.decrease.circle\(filterModule != nil || filterDate != nil ? ".fill" : "")")
                    }
                    .accessibilityLabel("Harita filtreleri")
                }
            }
            .sheet(isPresented: $showingFilters) {
                PhotoMapFilterView(
                    filterModule: $filterModule,
                    filterDate: $filterDate,
                    moduleOptions: moduleOptions,
                    moduleLabelMap: moduleLabelMap
                )
            }
        }
    }

    @ViewBuilder
    private func photoPin(_ photo: GeoTaggedPhoto) -> some View {
        Button {
            withAnimation { selectedPhoto = (selectedPhoto?.id == photo.id) ? nil : photo }
        } label: {
            ZStack {
                Circle()
                    .fill(pinColor(for: photo.sourceModule))
                    .frame(width: 36, height: 36)
                    .shadow(radius: 3)
                Image(systemName: photo.moduleIcon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel("\(photo.moduleLabel): \(photo.caption.isEmpty ? photo.photoDate.shortFormatted : photo.caption)")
    }

    private func pinColor(for module: String) -> Color {
        switch module {
        case "SiteDiary":      return .hakedisInfo
        case "SafetyIncident": return .hakedisDanger
        case "QualityCheck":   return .hakedisOrange
        case "DailyEntry":     return .hakedisSuccess
        default:               return .secondary
        }
    }

    @ViewBuilder
    private func photoDetailCard(_ photo: GeoTaggedPhoto) -> some View {
        HStack(spacing: Spacing.card) {
            if let thumb = photo.thumbnailData, let img = UIImage(data: thumb) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.hakedisCard)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: photo.moduleIcon)
                            .font(.title2)
                            .foregroundColor(.hakedisOrange)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(pinColor(for: photo.sourceModule))
                        .frame(width: 8, height: 8)
                    Text(photo.moduleLabel)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                if !photo.caption.isEmpty {
                    Text(photo.caption)
                        .font(.subheadline.bold())
                        .lineLimit(2)
                }
                Text(photo.photoDate.shortFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.5f, %.5f", photo.latitude, photo.longitude))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                withAnimation { selectedPhoto = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .accessibilityLabel("Kapat")
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private func centerOnPhotos() {
        guard !filteredPhotos.isEmpty else { return }
        let lats = filteredPhotos.map { $0.latitude }
        let lons = filteredPhotos.map { $0.longitude }
        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLon = (lons.min()! + lons.max()!) / 2
        let spanLat = max(0.01, (lats.max()! - lats.min()!) * 1.3)
        let spanLon = max(0.01, (lons.max()! - lons.min()!) * 1.3)
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }
}

// MARK: - PhotoMapFilterView

struct PhotoMapFilterView: View {
    @Binding var filterModule: String?
    @Binding var filterDate: Date?
    let moduleOptions: [String]
    let moduleLabelMap: [String: String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Modül") {
                    Button("Tümü") { filterModule = nil }
                        .foregroundColor(filterModule == nil ? .hakedisOrange : .primary)
                    ForEach(moduleOptions, id: \.self) { mod in
                        Button(moduleLabelMap[mod] ?? mod) { filterModule = mod }
                            .foregroundColor(filterModule == mod ? .hakedisOrange : .primary)
                    }
                }
                Section("Tarih") {
                    if filterDate != nil {
                        DatePicker("Tarih", selection: Binding(
                            get: { filterDate ?? Date() },
                            set: { filterDate = $0 }
                        ), displayedComponents: .date)
                        .accessibilityLabel("Filtre tarihi")
                        Button("Tarihi Temizle") { filterDate = nil }
                            .foregroundColor(.hakedisDanger)
                    } else {
                        Button("Tarih Filtresi Ekle") { filterDate = Date() }
                            .foregroundColor(.hakedisOrange)
                    }
                }
            }
            .navigationTitle("Filtreler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uygula") { dismiss() }
                }
            }
        }
    }
}
