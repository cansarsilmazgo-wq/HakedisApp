import Foundation
import SwiftData
import CoreLocation
import ImageIO

// MARK: - PhotoLocationService

struct PhotoLocationService {
    static func extractGPSLocation(from imageData: Data) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double
        else { return nil }

        let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
        let finalLat = latRef == "S" ? -lat : lat
        let finalLon = lonRef == "W" ? -lon : lon

        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon))
        else { return nil }
        return CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon)
    }

    static func makeThumbnail(from imageData: Data, size: CGFloat = 120) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: size,
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ]
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, "public.jpeg" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, thumb, nil)
        CGImageDestinationFinalize(dest)
        return mutable as Data
    }
}

// MARK: - GeoTaggedPhoto

@Model
final class GeoTaggedPhoto {
    var id: UUID
    var photoDate: Date
    var latitude: Double
    var longitude: Double
    var caption: String
    var sourceModule: String
    var sourceId: String
    var thumbnailData: Data?
    var project: Project?
    var createdAt: Date

    init(
        photoDate: Date = Date(),
        latitude: Double,
        longitude: Double,
        caption: String = "",
        sourceModule: String,
        sourceId: String,
        thumbnailData: Data? = nil
    ) {
        self.id = UUID()
        self.photoDate = photoDate
        self.latitude = latitude
        self.longitude = longitude
        self.caption = caption
        self.sourceModule = sourceModule
        self.sourceId = sourceId
        self.thumbnailData = thumbnailData
        self.createdAt = Date()
    }

    var coordinate: (lat: Double, lon: Double) { (latitude, longitude) }

    var moduleColor: String {
        switch sourceModule {
        case "SiteDiary":      return "blue"
        case "SafetyIncident": return "red"
        case "QualityCheck":   return "orange"
        case "DailyEntry":     return "green"
        default:               return "gray"
        }
    }

    var moduleIcon: String {
        switch sourceModule {
        case "SiteDiary":      return "book.closed.fill"
        case "SafetyIncident": return "exclamationmark.shield.fill"
        case "QualityCheck":   return "checkmark.seal.fill"
        case "DailyEntry":     return "hammer.fill"
        default:               return "camera.fill"
        }
    }

    var moduleLabel: String {
        switch sourceModule {
        case "SiteDiary":      return "Saha Günlüğü"
        case "SafetyIncident": return "ISG Olayı"
        case "QualityCheck":   return "Kalite Kontrol"
        case "DailyEntry":     return "Günlük Giriş"
        default:               return "Diğer"
        }
    }
}
