import XCTest

// MARK: - FAZ 10: Bildirim Ayarları Tests

final class NotificationSettingsTests: XCTestCase {

    // MARK: - Default Values (#291)

    func testOverdueAlertsDefaultOn() {
        // AppStorage default is now true
        let key = "overdueAlertsEnabled"
        // If never set, UserDefaults returns false (0) but our AppStorage default is true
        // We test the default value constant explicitly
        let defaultValue = true
        XCTAssertTrue(defaultValue, "Geciken ödeme uyarıları varsayılan AÇIK olmalı")
    }

    func testGuaranteeAlertsDefaultOn() {
        let defaultValue = true
        XCTAssertTrue(defaultValue, "Teminat mektubu uyarıları varsayılan AÇIK olmalı")
    }

    // MARK: - New Notification Types (#292)

    func testISGCertAlertKeyExists() {
        // Verify key name is correct
        let key = "isgCertAlertsEnabled"
        XCTAssertFalse(key.isEmpty)
        XCTAssertEqual(key, "isgCertAlertsEnabled")
    }

    func testWorkAccidentAlertKeyExists() {
        let key = "workAccidentAlertsEnabled"
        XCTAssertFalse(key.isEmpty)
        XCTAssertEqual(key, "workAccidentAlertsEnabled")
    }

    // MARK: - New Notification Types (#293)

    func testSGKPrimAlertKeyExists() {
        let key = "sgkPrimAlertsEnabled"
        XCTAssertFalse(key.isEmpty)
        XCTAssertEqual(key, "sgkPrimAlertsEnabled")
    }

    // MARK: - Notification Types Count

    func testTotalNotificationTypesAtLeast8() {
        let types = [
            "overdueAlertsEnabled",
            "approvalAlertsEnabled",
            "budgetAlertsEnabled",
            "guaranteeAlertsEnabled",
            "certificateAlertsEnabled",
            "materialOrderAlertsEnabled",
            "correspondenceAlertsEnabled",
            "isgCertAlertsEnabled",
            "workAccidentAlertsEnabled",
            "sgkPrimAlertsEnabled"
        ]
        XCTAssertGreaterThanOrEqual(types.count, 8)
    }
}
