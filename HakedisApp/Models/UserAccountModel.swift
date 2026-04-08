import Foundation
import SwiftData
import CryptoKit

// MARK: - UserAccount

@Model
final class UserAccount {
    var id: UUID
    var fullName: String
    @Attribute(.unique) var email: String
    var phone: String?
    var companyName: String?
    var companyLogoData: Data?
    var roleRaw: String
    var professionRaw: String?
    var registrationNumber: String?
    var assignedProjectIds: [UUID]
    var profilePhotoData: Data?
    var isActive: Bool
    var accountStatusRaw: String
    var lastLoginDate: Date?
    var passwordHash: String
    var createdAt: Date
    var title: String = ""   // FAZ 14.3 — Unvan (Genel Müdür, Şantiye Şefi, vb.)
    @Relationship var company: Company?

    init(fullName: String, email: String, role: UserRole, passwordHash: String) {
        self.id = UUID()
        self.fullName = fullName
        self.email = email
        self.roleRaw = role.rawValue
        self.passwordHash = passwordHash
        self.assignedProjectIds = []
        self.isActive = true
        self.accountStatusRaw = AccountStatus.active.rawValue
        self.createdAt = Date()
    }

    var role: UserRole {
        get { UserRole(rawValue: roleRaw) ?? .viewer }
        set { roleRaw = newValue.rawValue }
    }

    var profession: UserProfession? {
        get { professionRaw.flatMap { UserProfession(rawValue: $0) } }
        set { professionRaw = newValue?.rawValue }
    }

    var accountStatus: AccountStatus {
        get { AccountStatus(rawValue: accountStatusRaw) ?? .active }
        set { accountStatusRaw = newValue.rawValue }
    }
}
