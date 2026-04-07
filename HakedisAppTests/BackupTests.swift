import XCTest

// MARK: - Yedekleme Yöneticisi Testleri

final class BackupTests: XCTestCase {

    func test_backupManager_isSingleton() {
        let b1 = BackupManager.shared
        let b2 = BackupManager.shared
        XCTAssertTrue(b1 === b2, "BackupManager singleton olmalı")
    }

    func test_backupManager_initialState() {
        let manager = BackupManager.shared
        XCTAssertFalse(manager.isExporting, "Başlangıçta export işlemi olmaz")
        XCTAssertFalse(manager.isImporting, "Başlangıçta import işlemi olmaz")
    }
}
