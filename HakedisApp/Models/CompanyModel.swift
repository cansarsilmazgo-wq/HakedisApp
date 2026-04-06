import Foundation
import SwiftData

// MARK: - AccountStatus

enum AccountStatus: String, Codable {
    case active          = "Aktif"
    case pendingApproval = "Onay Bekliyor"
    case suspended       = "Askıya Alındı"
    case rejected        = "Reddedildi"
}

// MARK: - JoinRequestStatus

enum JoinRequestStatus: String, Codable {
    case pending  = "Beklemede"
    case approved = "Onaylandı"
    case rejected = "Reddedildi"
}

// MARK: - Company

@Model
final class Company {
    var id: UUID
    var companyName: String
    var taxNumber: String?
    var address: String?
    var phone: String?
    var email: String?
    var logoData: Data?
    var inviteCode: String
    var inviteCodeCreatedAt: Date
    var inviteCodeExpiresAt: Date?
    var isInviteCodeActive: Bool
    @Relationship(deleteRule: .cascade) var members: [UserAccount]
    @Relationship(deleteRule: .cascade) var joinRequests: [JoinRequest]
    var createdAt: Date

    init(companyName: String) {
        self.id = UUID()
        self.companyName = companyName
        self.inviteCode = Company.generateInviteCode(companyName: companyName)
        self.inviteCodeCreatedAt = Date()
        self.isInviteCodeActive = true
        self.members = []
        self.joinRequests = []
        self.createdAt = Date()
    }

    // MARK: Invite Code Generation
    // Format: [3-char prefix]-[year]-[4-char random]-[2-char checksum]
    // Chars: no 0/O, 1/I, L to avoid confusion

    static func generateInviteCode(companyName: String) -> String {
        let filtered = companyName.filter { $0.isLetter }
        var prefix = String(filtered.prefix(3)).uppercased()
        while prefix.count < 3 { prefix += "X" }

        let year = Calendar.current.component(.year, from: Date())
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let charsArray = Array(chars)
        let randomStr = String((0..<4).map { _ in charsArray.randomElement()! })

        let raw = "\(prefix)\(year)\(randomStr)"
        let hashVal = raw.utf8.reduce(0) { ($0 &+ Int($1)) &* 31 }
        let c1 = charsArray[abs(hashVal) % charsArray.count]
        let c2 = charsArray[abs(hashVal / 32) % charsArray.count]

        return "\(prefix)-\(year)-\(randomStr)-\(c1)\(c2)"
    }

    static func validateFormat(_ code: String) -> Bool {
        let parts = code.uppercased().split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        guard parts[0].count == 3 else { return false }
        guard parts[1].count == 4, Int(parts[1]) != nil else { return false }
        guard parts[2].count == 4 else { return false }
        guard parts[3].count == 2 else { return false }
        return true
    }

    static func validateChecksum(_ code: String) -> Bool {
        let parts = code.uppercased().split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        let prefix   = String(parts[0])
        let year     = String(parts[1])
        let random   = String(parts[2])
        let checksum = String(parts[3])
        let raw      = "\(prefix)\(year)\(random)"
        let hashVal  = raw.utf8.reduce(0) { ($0 &+ Int($1)) &* 31 }
        let chars    = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let arr      = Array(chars)
        let c1 = arr[abs(hashVal) % arr.count]
        let c2 = arr[abs(hashVal / 32) % arr.count]
        return checksum == "\(c1)\(c2)"
    }

    func regenerateInviteCode() {
        inviteCode = Company.generateInviteCode(companyName: companyName)
        inviteCodeCreatedAt = Date()
    }
}

// MARK: - JoinRequest

@Model
final class JoinRequest {
    var id: UUID
    var requestDate: Date
    var statusRaw: String
    var requestedRoleRaw: String
    var message: String?
    var reviewedBy: String?
    var reviewDate: Date?
    var rejectionReason: String?
    @Relationship var user: UserAccount?
    @Relationship var company: Company?
    var createdAt: Date

    init(user: UserAccount, company: Company, requestedRole: UserRole, message: String? = nil) {
        self.id = UUID()
        self.requestDate = Date()
        self.statusRaw = JoinRequestStatus.pending.rawValue
        self.requestedRoleRaw = requestedRole.rawValue
        self.message = message
        self.user = user
        self.company = company
        self.createdAt = Date()
    }

    var status: JoinRequestStatus {
        get { JoinRequestStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var requestedRole: UserRole {
        get { UserRole(rawValue: requestedRoleRaw) ?? .viewer }
        set { requestedRoleRaw = newValue.rawValue }
    }
}
