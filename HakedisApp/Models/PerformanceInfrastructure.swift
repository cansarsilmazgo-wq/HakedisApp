import SwiftUI
import SwiftData
import CryptoKit

// MARK: - Thumbnail Cache

final class AppThumbnailCache: @unchecked Sendable {
    static let shared = AppThumbnailCache()
    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.hakedis.thumbnailcache", attributes: .concurrent)
    private let maxSize = 100

    private init() {}

    func thumbnail(for data: Data, size: CGSize = CGSize(width: 80, height: 80)) -> UIImage? {
        let key = cacheKey(for: data)
        return queue.sync {
            if let cached = cache[key] { return cached }
            return nil
        }
    }

    func setThumbnail(_ image: UIImage, for data: Data) {
        let key = cacheKey(for: data)
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.cache.count >= self.maxSize {
                self.cache.removeAll()
            }
            self.cache[key] = image
        }
    }

    func generateAndCache(from data: Data, size: CGSize = CGSize(width: 80, height: 80)) -> UIImage? {
        let key = cacheKey(for: data)
        if let cached = queue.sync(execute: { cache[key] }) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        let thumbnail = image.resized(to: size)
        setThumbnail(thumbnail, for: data)
        return thumbnail
    }

    func clearCache() {
        queue.async(flags: .barrier) { [weak self] in self?.cache.removeAll() }
    }

    func cacheSize() -> Int {
        queue.sync { cache.count }
    }

    private func cacheKey(for data: Data) -> String {
        let hash = SHA256.hash(data: data.prefix(1024))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Lazy Photo View

struct LazyPhotoView: View {
    let data: Data
    let size: CGSize

    @State private var image: UIImage? = nil

    init(data: Data, size: CGSize = CGSize(width: 80, height: 80)) {
        self.data = data
        self.size = size
    }

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.hakedisCard)
                    .frame(width: size.width, height: size.height)
                    .overlay(Image(systemName: "photo").foregroundColor(.secondary))
            }
        }
        .onAppear {
            if image == nil {
                DispatchQueue.global(qos: .userInitiated).async {
                    let thumb = AppThumbnailCache.shared.generateAndCache(from: data, size: size)
                    DispatchQueue.main.async { image = thumb }
                }
            }
        }
    }
}

// MARK: - Model Performance Monitor

struct ModelPerformanceMonitor {
    static func logQueryTime(_ label: String, block: () -> Void) {
        let start = Date()
        block()
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0.1 {
            print("⚠️ Slow query [\(label)]: \(String(format: "%.3f", elapsed))s")
        }
    }
}
