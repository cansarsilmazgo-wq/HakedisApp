import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - MaterialQRCodeManager

class MaterialQRCodeManager {
    static func qrPayload(for material: Material) -> String {
        "MATERIAL:\(material.id.uuidString):\(material.name)"
    }

    static func materialID(from qrString: String) -> UUID? {
        guard qrString.hasPrefix("MATERIAL:") else { return nil }
        let parts = qrString.split(separator: ":", maxSplits: 2)
        guard parts.count >= 2 else { return nil }
        return UUID(uuidString: String(parts[1]))
    }

    static func generateQRCode(for material: Material) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        guard let data = qrPayload(for: material).data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func generateQRLabel(for material: Material) -> UIImage? {
        guard let qr = generateQRCode(for: material) else { return nil }
        let size = CGSize(width: 400, height: 500)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            qr.draw(in: CGRect(x: 100, y: 40, width: 200, height: 200))

            let nameAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            let unitAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.darkGray
            ]
            let stockAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.gray
            ]

            (material.name as NSString).draw(
                in: CGRect(x: 20, y: 260, width: 360, height: 50),
                withAttributes: nameAttr
            )
            ("Birim: \(material.unit)" as NSString).draw(
                at: CGPoint(x: 20, y: 310),
                withAttributes: unitAttr
            )
            (String(format: "Stok: %.2f \(material.unit)", material.currentStock) as NSString).draw(
                at: CGPoint(x: 20, y: 340),
                withAttributes: stockAttr
            )
        }
    }
}
