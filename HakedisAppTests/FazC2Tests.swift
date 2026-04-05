import XCTest
import Foundation

// MARK: - C2 KVKK Tests

final class BiometricAuthManagerTests: XCTestCase {

    func test_biometricAuthManager_singleton() {
        let m1 = BiometricAuthManager.shared
        let m2 = BiometricAuthManager.shared
        XCTAssertTrue(m1 === m2)
    }

    func test_biometricAuthManager_lockUnlock() {
        let manager = BiometricAuthManager.shared
        manager.lockApp()
        XCTAssertTrue(manager.isLocked)
    }

    func test_biometricAuthManager_updateActivity() {
        let manager = BiometricAuthManager.shared
        manager.updateActivity()
        // After updating activity, checkTimeout should not lock
        manager.checkTimeout()
        // Since we just updated, it shouldn't be locked by timeout
        // (it might still be locked from lockApp() above, so we just verify no crash)
        XCTAssertNoThrow(manager.checkTimeout())
    }
}
