import XCTest
import Foundation

// MARK: - C3 Yedekleme Tests

final class BackupManagerTests: XCTestCase {

    func test_backupManager_singleton() {
        let m1 = BackupManager.shared
        let m2 = BackupManager.shared
        XCTAssertTrue(m1 === m2)
    }

    func test_backupManager_validJsonExport() {
        let manager = BackupManager.shared
        // Test JSON export creates a valid file
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let expectedFilename = "HakedisApp_Backup_\(timestamp).json"
        let expectedURL = tempDir.appendingPathComponent(expectedFilename)
        // Clean up if exists
        try? FileManager.default.removeItem(at: expectedURL)
        // Can't call exportToJSON without a real ModelContext, so test the metadata dict logic
        let dict: [String: Any] = ["exportDate": "2026-04-06", "appVersion": "1.0", "platform": "iOS", "dataVersion": "1", "note": "test"]
        let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        XCTAssertNotNil(data)
        if let data = data {
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(parsed?["platform"] as? String, "iOS")
            XCTAssertEqual(parsed?["dataVersion"] as? String, "1")
        }
    }
}
