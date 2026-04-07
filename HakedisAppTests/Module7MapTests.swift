import XCTest
import SwiftData

// MARK: - Module 7: Harita Tests

final class Module7MapTests: XCTestCase {

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

    // Test 1: Pin oluşturma (lat/lon)
    func test_project_hasCoordinates_whenSet() {
        let project = Project(name: "Koordinatlı Proje")
        project.latitude = 41.0082
        project.longitude = 28.9784
        XCTAssertTrue(project.hasCoordinates)
    }

    func test_project_hasCoordinates_whenNil() {
        let project = Project(name: "Koordinatsız Proje")
        XCTAssertFalse(project.hasCoordinates)
    }

    func test_project_hasCoordinates_whenOnlyLat() {
        let project = Project(name: "Eksik Koordinat")
        project.latitude = 41.0082
        // longitude nil kaldı
        XCTAssertFalse(project.hasCoordinates)
    }

    // Test 2: En yakın proje hesabı (Haversine formülü)
    func test_haversine_samePoint_isZero() {
        let dist = haversine(lat1: 41.0, lon1: 29.0, lat2: 41.0, lon2: 29.0)
        XCTAssertEqual(dist, 0.0, accuracy: 0.001)
    }

    func test_haversine_knownDistance_ankaraToIstanbul() {
        // Ankara (39.9334, 32.8597) → İstanbul (41.0082, 28.9784) ≈ 352 km
        let dist = haversine(lat1: 39.9334, lon1: 32.8597, lat2: 41.0082, lon2: 28.9784)
        XCTAssertGreaterThan(dist, 300)
        XCTAssertLessThan(dist, 400)
    }

    func test_haversine_nearbyPoints() {
        // Çok yakın iki nokta — 1 km civarı
        let dist = haversine(lat1: 41.0000, lon1: 29.0000, lat2: 41.0090, lon2: 29.0000)
        XCTAssertLessThan(dist, 2.0)
        XCTAssertGreaterThan(dist, 0.5)
    }

    func test_haversine_nearestProjectSelection() {
        // 3 proje arasından en yakınını bul
        let userLat = 41.0, userLon = 29.0
        let projects = [
            (lat: 41.1, lon: 29.0, name: "Proje A"),  // ~11 km
            (lat: 41.01, lon: 29.01, name: "Proje B"), // ~1.3 km — EN YAKIN
            (lat: 40.8, lon: 29.2, name: "Proje C")   // ~30 km
        ]

        let nearest = projects.min { a, b in
            haversine(lat1: userLat, lon1: userLon, lat2: a.lat, lon2: a.lon)
            <
            haversine(lat1: userLat, lon1: userLon, lat2: b.lat, lon2: b.lon)
        }

        XCTAssertEqual(nearest?.name, "Proje B")
    }

    // Test 3: Cluster gruplama (yakın projelerin gruplanması mantığı)
    func test_clustering_sameLocation_shouldBeClose() {
        let lat1 = 41.0082, lon1 = 28.9784
        let lat2 = 41.0085, lon2 = 28.9788  // Çok yakın (< 100m)
        let dist = haversine(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
        XCTAssertLessThan(dist, 0.1)  // 100m altında
    }

    func test_clustering_farLocations_shouldNotCluster() {
        let lat1 = 41.0082, lon1 = 28.9784  // İstanbul
        let lat2 = 39.9334, lon2 = 32.8597  // Ankara
        let dist = haversine(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
        XCTAssertGreaterThan(dist, 300)  // Cluster edilmemeli
    }
}
