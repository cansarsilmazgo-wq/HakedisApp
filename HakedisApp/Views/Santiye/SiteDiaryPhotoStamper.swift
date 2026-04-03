import UIKit

// MARK: - Fotoğraf Metadata Damgası
// Tarih + saat + proje adı watermark ekler (CoreLocation gerektirmez)

struct SiteDiaryPhotoStamper {

    static func stamp(data: Data, date: Date, projectName: String?) -> Data {
        guard let original = UIImage(data: data) else { return data }
        let size = original.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let stamped = renderer.image { ctx in
            original.draw(at: .zero)

            // Zaman damgası metni
            let df = DateFormatter()
            df.locale = Locale(identifier: "tr_TR")
            df.dateFormat = "dd.MM.yyyy HH:mm"
            var lines = [df.string(from: date)]
            if let pn = projectName, !pn.isEmpty { lines.append(pn) }
            let text = lines.joined(separator: "\n")

            let fontSize: CGFloat = max(size.height * 0.025, 14)
            let font = UIFont.boldSystemFont(ofSize: fontSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -2.0
            ]
            let attrStr = NSAttributedString(string: text, attributes: attrs)
            let textSize = attrStr.size()
            let padding: CGFloat = 8
            let rect = CGRect(
                x: padding,
                y: size.height - textSize.height - padding * 2,
                width: textSize.width + padding * 2,
                height: textSize.height + padding
            )
            // Semi-transparent background
            UIColor.black.withAlphaComponent(0.45).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 4).fill()
            attrStr.draw(at: CGPoint(x: rect.minX + padding, y: rect.minY + padding / 2))
        }
        return stamped.jpegData(compressionQuality: 0.85) ?? data
    }
}
