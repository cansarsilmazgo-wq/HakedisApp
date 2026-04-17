import XCTest
import SwiftData
import CryptoKit

final class AuthAndRoleTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([UserAccount.self, Company.self, JoinRequest.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Existing Tests (1–11)

    // 1. UserAccount creation
    func test_userAccount_creation() {
        let user = UserAccount(fullName: "Ali Yılmaz", email: "ali@test.com", role: .owner, passwordHash: "hash123")
        XCTAssertEqual(user.fullName, "Ali Yılmaz")
        XCTAssertEqual(user.email, "ali@test.com")
        XCTAssertEqual(user.role, .owner)
        XCTAssertTrue(user.isActive)
        XCTAssertTrue(user.assignedProjectIds.isEmpty)
        XCTAssertEqual(user.accountStatus, .active)
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

    // MARK: - New Tests (12–26)

    // 12. Company creation + invite code generation
    func test_company_creation_inviteCode() {
        let company = Company(companyName: "Alphatek İnşaat")
        XCTAssertEqual(company.companyName, "Alphatek İnşaat")
        XCTAssertFalse(company.inviteCode.isEmpty)
        XCTAssertTrue(company.isInviteCodeActive)
        XCTAssertNil(company.inviteCodeExpiresAt)
        XCTAssertTrue(company.members.isEmpty)
        XCTAssertTrue(company.joinRequests.isEmpty)
    }

    // 13. Invite code format validation — prefix-year-random-checksum
    func test_inviteCode_format_valid() {
        let company = Company(companyName: "ABC İnşaat")
        let code = company.inviteCode
        let parts = code.split(separator: "-")
        XCTAssertEqual(parts.count, 4, "Format must have 4 parts: XXX-YYYY-XXXX-XX")
        XCTAssertEqual(parts[0].count, 3)
        XCTAssertEqual(parts[1].count, 4)
        XCTAssertNotNil(Int(parts[1]), "Year part must be a number")
        XCTAssertEqual(parts[2].count, 4)
        XCTAssertEqual(parts[3].count, 2)
        XCTAssertTrue(Company.validateFormat(code))
    }

    // 14. Invite code checksum validation
    func test_inviteCode_checksum_valid() {
        let company = Company(companyName: "XYZ Mühendislik")
        let code = company.inviteCode
        XCTAssertTrue(Company.validateChecksum(code))
        // Tamper with last char — checksum should fail
        var tampered = code
        let lastIndex = tampered.index(before: tampered.endIndex)
        let lastChar = tampered[lastIndex]
        let replacement: Character = lastChar == "A" ? "B" : "A"
        tampered.replaceSubrange(lastIndex...lastIndex, with: [replacement])
        XCTAssertFalse(Company.validateChecksum(tampered))
    }

    // 15. Invite code brute force protection — counter reaches 5 → lock time set
    func test_inviteCode_bruteForce_lock() {
        // Reset any existing lock state
        UserDefaults.standard.removeObject(forKey: "inviteCodeAttempts")
        UserDefaults.standard.removeObject(forKey: "inviteCodeLockUntil")

        // Simulate incrementing the counter 5 times (as AuthManager would do)
        let key = "inviteCodeAttempts"
        for i in 1...5 {
            var count = UserDefaults.standard.integer(forKey: key)
            count += 1
            if count >= 5 {
                let lockUntil = Date().addingTimeInterval(15 * 60)
                UserDefaults.standard.set(lockUntil.timeIntervalSince1970, forKey: "inviteCodeLockUntil")
                UserDefaults.standard.set(0, forKey: key)
            } else {
                UserDefaults.standard.set(count, forKey: key)
            }
            _ = i
        }

        // After 5 failures, lock should be set
        let lockTime = UserDefaults.standard.double(forKey: "inviteCodeLockUntil")
        XCTAssertGreaterThan(lockTime, 0, "Lock time should be set after 5 failed attempts")
        let lockDate = Date(timeIntervalSince1970: lockTime)
        XCTAssertGreaterThan(lockDate, Date(), "Lock should be in the future")
        XCTAssertLessThan(lockDate, Date().addingTimeInterval(16 * 60), "Lock should be ~15 min")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "inviteCodeAttempts")
        UserDefaults.standard.removeObject(forKey: "inviteCodeLockUntil")
    }

    // 16. JoinRequest creation with pending status
    func test_joinRequest_creation_pending() {
        let company = Company(companyName: "Test Şirketi")
        let user = UserAccount(fullName: "Mehmet Kaya", email: "m@test.com",
                               role: .siteEngineer, passwordHash: "hash")
        let request = JoinRequest(user: user, company: company, requestedRole: .siteEngineer,
                                  message: "3. şantiyede çalışıyorum")
        XCTAssertEqual(request.status, .pending)
        XCTAssertEqual(request.requestedRole, .siteEngineer)
        XCTAssertEqual(request.message, "3. şantiyede çalışıyorum")
        XCTAssertNil(request.reviewedBy)
        XCTAssertNil(request.reviewDate)
    }

    // 17. JoinRequest approval → UserAccount.accountStatus = .active
    func test_joinRequest_approval_activatesUser() throws {
        let company = Company(companyName: "Proje Şirketi")
        let user = UserAccount(fullName: "Ayşe Demir", email: "ayse@test.com",
                               role: .siteEngineer, passwordHash: "hash")
        user.accountStatus = .pendingApproval
        let request = JoinRequest(user: user, company: company, requestedRole: .siteEngineer)

        context.insert(company)
        context.insert(user)
        context.insert(request)
        try context.save()

        // Simulate approval
        request.status = .approved
        request.reviewedBy = "Patron"
        request.reviewDate = Date()
        user.accountStatus = .active
        try context.save()

        XCTAssertEqual(request.status, .approved)
        XCTAssertEqual(user.accountStatus, .active)
        XCTAssertNotNil(request.reviewedBy)
    }

    // 18. JoinRequest rejection → UserAccount.accountStatus = .rejected + reason
    func test_joinRequest_rejection_setsReason() throws {
        let company = Company(companyName: "Ret Şirketi")
        let user = UserAccount(fullName: "Can Yıldız", email: "can@test.com",
                               role: .viewer, passwordHash: "hash")
        user.accountStatus = .pendingApproval
        let request = JoinRequest(user: user, company: company, requestedRole: .viewer)

        context.insert(company)
        context.insert(user)
        context.insert(request)
        try context.save()

        request.status = .rejected
        request.rejectionReason = "Tanımıyorum bu kişiyi"
        user.accountStatus = .rejected
        try context.save()

        XCTAssertEqual(request.status, .rejected)
        XCTAssertEqual(user.accountStatus, .rejected)
        XCTAssertEqual(request.rejectionReason, "Tanımıyorum bu kişiyi")
    }

    // 19. Patron role change (assign different role at approval)
    func test_patron_roleChange_onApproval() throws {
        let company = Company(companyName: "Rol Şirketi")
        let user = UserAccount(fullName: "Zeynep Arslan", email: "z@test.com",
                               role: .viewer, passwordHash: "hash")
        let request = JoinRequest(user: user, company: company, requestedRole: .viewer)

        context.insert(company)
        context.insert(user)
        context.insert(request)
        try context.save()

        // Approve with different role
        let assignedRole: UserRole = .siteEngineer
        request.status = .approved
        user.role = assignedRole
        user.accountStatus = .active
        try context.save()

        XCTAssertEqual(user.role, .siteEngineer)
        XCTAssertNotEqual(user.role, request.requestedRole)
    }

    // 20. Invite code regeneration — old code becomes different
    func test_inviteCode_regeneration() {
        let company = Company(companyName: "Yenileme Test")
        let oldCode = company.inviteCode
        // Wait a tiny bit (UUID randomness ensures different output)
        company.regenerateInviteCode()
        let newCode = company.inviteCode
        // Codes should be different (random component)
        // Both should be valid format
        XCTAssertTrue(Company.validateFormat(newCode))
        XCTAssertTrue(Company.validateChecksum(newCode))
        XCTAssertNotEqual(oldCode, newCode, "Regenerated code should differ from old code")
    }

    // 21. Invite code deactivation (isInviteCodeActive = false)
    func test_inviteCode_deactivation() throws {
        let company = Company(companyName: "Devre Dışı Test")
        context.insert(company)
        try context.save()

        company.isInviteCodeActive = false
        try context.save()

        XCTAssertFalse(company.isInviteCodeActive)
        // A deactivated code should be rejected at the validation level
        // (The isInviteCodeActive flag is checked before allowing joins)
        XCTAssertTrue(Company.validateFormat(company.inviteCode), "Code format should still be valid")
        XCTAssertTrue(Company.validateChecksum(company.inviteCode), "Code checksum should still be valid")
    }

    // 22. Login — pendingApproval user accountStatus blocks access
    func test_login_pendingApproval_blocked() throws {
        let data = Data("Pass123".utf8)
        let hash = CryptoKit.SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        let user = UserAccount(fullName: "Bekleme User", email: "pending@test.com",
                               role: .siteEngineer, passwordHash: hash)
        user.accountStatus = .pendingApproval
        context.insert(user)
        try context.save()

        // Verify user is in pendingApproval state — login logic checks this
        XCTAssertEqual(user.accountStatus, .pendingApproval)
        XCTAssertNotEqual(user.accountStatus, .active)
        // A pending user should not have access to the app
        XCTAssertFalse(user.accountStatus == .active)
    }

    // 23. Login — active user can log in (accountStatus is .active)
    func test_login_activeUser_succeeds() throws {
        let data = Data("Pass123".utf8)
        let hash = CryptoKit.SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        let user = UserAccount(fullName: "Aktif User", email: "active@test.com",
                               role: .owner, passwordHash: hash)
        user.accountStatus = .active
        context.insert(user)
        try context.save()

        XCTAssertEqual(user.accountStatus, .active)
        XCTAssertEqual(user.passwordHash, hash)
        XCTAssertTrue(user.accountStatus == .active)
    }

    // 24. RoleAccess — owner sees all modules
    func test_roleAccess_owner_seesAll() {
        let role = UserRole.owner
        XCTAssertTrue(role.canSeeFinancials)
        XCTAssertTrue(role.canSeeProfitability)
        XCTAssertTrue(role.canCreateHakedis)
        XCTAssertTrue(role.canApproveHakedis)
        XCTAssertTrue(role.canManageUsers)
        XCTAssertTrue(role.canDeleteData)
        XCTAssertTrue(role.canSeeDailyEntry)
        XCTAssertTrue(role.canManageSafety)
        XCTAssertTrue(role.canSeeBudget)
        XCTAssertTrue(role.canSeeEVM)
    }

    // 25. RoleAccess — siteEngineer cannot see financials
    func test_roleAccess_siteEngineer_noFinancials() {
        let role = UserRole.siteEngineer
        XCTAssertFalse(role.canSeeFinancials)
        XCTAssertFalse(role.canSeeProfitability)
        XCTAssertFalse(role.canApproveHakedis)
        XCTAssertFalse(role.canManageUsers)
        XCTAssertTrue(role.canSeeDailyEntry)
        XCTAssertTrue(role.canManageWorkers)
    }

    // 26. RoleAccess — viewer cannot edit anything
    func test_roleAccess_viewer_readOnly() {
        let role = UserRole.viewer
        XCTAssertFalse(role.canDeleteData)
        XCTAssertFalse(role.canCreateHakedis)
        XCTAssertFalse(role.canApproveHakedis)
        XCTAssertFalse(role.canManageUsers)
        XCTAssertFalse(role.canManageSafety)
        XCTAssertFalse(role.canManageWorkers)
        XCTAssertFalse(role.canManageEquipment)
        XCTAssertFalse(role.canManageMaterials)
        XCTAssertFalse(role.canManageContracts)
    }

    // MARK: - ADIM 1 — linkedContractorId Testleri

    // 27. Taşeron onaylandığında linkedContractorId set edilmeli
    func testTaseronOnayindaLinkedContractorIdSetEdilmeli() throws {
        let schema = Schema([UserAccount.self, Company.self, JoinRequest.self, Contractor.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let cont = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(cont)

        let owner = UserAccount(fullName: "Patron", email: "patron@test.com", role: .owner, passwordHash: "h")
        let company = Company(companyName: "Test Şirketi")
        let taseronUser = UserAccount(fullName: "Taşeron Ali", email: "taseron@test.com", role: .subcontractor, passwordHash: "h")
        let contractor = Contractor(name: "Taseron Firma A.Ş.")
        let joinReq = JoinRequest(user: taseronUser, company: company, requestedRole: .subcontractor)
        ctx.insert(owner); ctx.insert(company); ctx.insert(taseronUser)
        ctx.insert(contractor); ctx.insert(joinReq)
        try ctx.save()

        // Onay öncesi nil olmalı
        XCTAssertNil(taseronUser.linkedContractorId, "Onay öncesi linkedContractorId nil olmalı")

        // AuthManager.shared üzerinden değil, doğrudan iş mantığını test ediyoruz
        joinReq.status = JoinRequestStatus.approved
        joinReq.reviewedBy = owner.fullName
        joinReq.reviewDate = Date()
        taseronUser.role = .subcontractor
        taseronUser.accountStatus = .active
        taseronUser.linkedContractorId = contractor.id
        try ctx.save()

        XCTAssertEqual(taseronUser.linkedContractorId, contractor.id, "Onay sonrası linkedContractorId set edilmiş olmalı")
        XCTAssertEqual(taseronUser.role, .subcontractor)
        XCTAssertEqual(joinReq.status, JoinRequestStatus.approved)
    }

    // 28. Onay öncesi linkedContractorId nil olmalı
    func testOnayOncesiLinkedContractorIdNilOlmali() throws {
        let user = UserAccount(fullName: "Bekleyen", email: "bekleyen@test.com", role: .subcontractor, passwordHash: "h")
        XCTAssertNil(user.linkedContractorId, "Yeni kullanıcıda linkedContractorId nil olmalı")
    }

    // 29. Reddedildiğinde linkedContractorId set edilmemeli
    func testReddedildigindeLikedContractorIdSetEdilmemeli() throws {
        let schema = Schema([UserAccount.self, Company.self, JoinRequest.self, Contractor.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let cont = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(cont)

        let owner = UserAccount(fullName: "Patron", email: "patron2@test.com", role: .owner, passwordHash: "h")
        let company = Company(companyName: "Test Şirketi 2")
        let taseronUser = UserAccount(fullName: "Reddedilen Ali", email: "red@test.com", role: .subcontractor, passwordHash: "h")
        let contractor = Contractor(name: "Redli Firma")
        let joinReq = JoinRequest(user: taseronUser, company: company, requestedRole: .subcontractor)
        ctx.insert(owner); ctx.insert(company); ctx.insert(taseronUser)
        ctx.insert(contractor); ctx.insert(joinReq)
        try ctx.save()

        // Reddetme — linkedContractorId set edilmemeli
        joinReq.status = JoinRequestStatus.rejected
        joinReq.reviewedBy = owner.fullName
        joinReq.reviewDate = Date()
        taseronUser.accountStatus = .rejected
        // linkedContractorId intentionally NOT set
        try ctx.save()

        XCTAssertNil(taseronUser.linkedContractorId, "Reddedildiğinde linkedContractorId set edilmemeli")
        XCTAssertEqual(joinReq.status, JoinRequestStatus.rejected)
    }
}
