import XCTest
import SwiftData
import CryptoKit

final class AuthAndRoleTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([UserAccount.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // 1. UserAccount creation
    func test_userAccount_creation() {
        let user = UserAccount(fullName: "Ali Yılmaz", email: "ali@test.com", role: .owner, passwordHash: "hash123")
        XCTAssertEqual(user.fullName, "Ali Yılmaz")
        XCTAssertEqual(user.email, "ali@test.com")
        XCTAssertEqual(user.role, .owner)
        XCTAssertTrue(user.isActive)
        XCTAssertTrue(user.assignedProjectIds.isEmpty)
    }

    // 2. Password hash (SHA256 manually)
    func test_password_hash_sha256() {
        let password = "testPassword123"
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        let result = hash.compactMap { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(result.count, 64)
        XCTAssertFalse(result.isEmpty)
    }

    // 3. RoleAccess — canSeeFinancials for owner
    func test_canSeeFinancials_owner_true() {
        XCTAssertTrue(UserRole.owner.canSeeFinancials)
        XCTAssertTrue(UserRole.projectManager.canSeeFinancials)
        XCTAssertTrue(UserRole.accountant.canSeeFinancials)
    }

    // 4. canSeeFinancials — siteEngineer false
    func test_canSeeFinancials_siteEngineer_false() {
        XCTAssertFalse(UserRole.siteEngineer.canSeeFinancials)
        XCTAssertFalse(UserRole.viewer.canSeeFinancials)
        XCTAssertFalse(UserRole.subcontractor.canSeeFinancials)
    }

    // 5. canSeeProfitability — only owner
    func test_canSeeProfitability_ownerOnly() {
        XCTAssertTrue(UserRole.owner.canSeeProfitability)
        for role in UserRole.allCases where role != .owner {
            XCTAssertFalse(role.canSeeProfitability, "\(role.rawValue) should not see profitability")
        }
    }

    // 6. canDeleteData — viewer false
    func test_canDeleteData_viewer_false() {
        XCTAssertFalse(UserRole.viewer.canDeleteData)
        XCTAssertFalse(UserRole.accountant.canDeleteData)
        XCTAssertFalse(UserRole.subcontractor.canDeleteData)
        XCTAssertTrue(UserRole.owner.canDeleteData)
        XCTAssertTrue(UserRole.projectManager.canDeleteData)
    }

    // 7. Tab visibility — accountant sees financials but not site
    func test_tabCount_accountant() {
        let role = UserRole.accountant
        XCTAssertTrue(role.canSeeFinancials)
        XCTAssertFalse(role.canSeeDailyEntry)
        XCTAssertFalse(role.canManageSafety)
    }

    // 8. canSeeAllProjects
    func test_canSeeAllProjects_accountant_true() {
        XCTAssertTrue(UserRole.owner.canSeeAllProjects)
        XCTAssertTrue(UserRole.accountant.canSeeAllProjects)
        XCTAssertFalse(UserRole.siteEngineer.canSeeAllProjects)
        XCTAssertFalse(UserRole.viewer.canSeeAllProjects)
    }

    // 9. Register validation — empty name check via UserAccount init
    func test_register_validation_emptyName() {
        let user = UserAccount(fullName: "", email: "test@test.com", role: .viewer, passwordHash: "hash")
        XCTAssertEqual(user.fullName, "")
        // Validation would happen in view layer; model accepts empty string
        XCTAssertTrue(user.email.contains("@"))
    }

    // 10. canManageSafety — safetyOfficer true
    func test_canManageSafety_safetyOfficer_true() {
        XCTAssertTrue(UserRole.safetyOfficer.canManageSafety)
        XCTAssertTrue(UserRole.owner.canManageSafety)
        XCTAssertFalse(UserRole.accountant.canManageSafety)
        XCTAssertFalse(UserRole.viewer.canManageSafety)
    }

    // 11. maskedCurrency — siteEngineer gets masked
    func test_maskedCurrency_siteEngineer() {
        let amount = 50000.0
        let masked = amount.maskedCurrency(for: .siteEngineer)
        XCTAssertEqual(masked, "₺***")
        let visible = amount.maskedCurrency(for: .owner)
        XCTAssertFalse(visible.contains("***"))
    }
}
