import XCTest
import UIKit

// MARK: - C1 Performans Tests

final class ThumbnailCacheTests: XCTestCase {

    func test_thumbnailCache_singleton() {
        let c1 = AppThumbnailCache.shared
        let c2 = AppThumbnailCache.shared
        XCTAssertTrue(c1 === c2)
    }

    func test_thumbnailCache_generateAndCache() {
        let cache = AppThumbnailCache.shared
        cache.clearCache()
        // Create a 10x10 red image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let img = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        guard let data = img.pngData() else {
            XCTFail("Could not create image data")
            return
        }
        let thumb = cache.generateAndCache(from: data, size: CGSize(width: 5, height: 5))
        XCTAssertNotNil(thumb)
        XCTAssertEqual(cache.cacheSize(), 1)
        // Second call should return cached
        let thumb2 = cache.generateAndCache(from: data, size: CGSize(width: 5, height: 5))
        XCTAssertNotNil(thumb2)
        XCTAssertEqual(cache.cacheSize(), 1)
        cache.clearCache()
    }

    func test_thumbnailCache_clearCache() {
        let cache = AppThumbnailCache.shared
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let img = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        if let data = img.pngData() {
            _ = cache.generateAndCache(from: data)
        }
        cache.clearCache()
        XCTAssertEqual(cache.cacheSize(), 0)
    }
}
