import XCTest

// MARK: - Biyometrik Kimlik Doğrulama Testleri

final class BiometricTests: XCTestCase {

    func test_biometricManager_isSingleton() {
        let b1 = BiometricAuthManager.shared
        let b2 = BiometricAuthManager.shared
        XCTAssertTrue(b1 === b2, "BiometricAuthManager singleton olmalı")
    }

    func test_biometricManager_lockApp() {
        let manager = BiometricAuthManager.shared
        let originalState = manager.isLocked
        manager.lockApp()
        XCTAssertTrue(manager.isLocked, "lockApp() çağrısı uygulamayı kilitlemeli")
        // restore
        manager.isLocked = originalState
    }
}
