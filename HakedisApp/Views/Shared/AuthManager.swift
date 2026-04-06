import Foundation
import SwiftUI
import SwiftData
import CryptoKit

// MARK: - LoginResult

enum LoginResult {
    case success
    case invalidCredentials
    case pendingApproval
    case rejected(reason: String?)
    case suspended
}

// MARK: - InviteCodeResult

enum InviteCodeResult {
    case success(Company)
    case invalidFormat
    case invalidChecksum
    case notFound
    case inactive
    case expired
    case locked(until: Date)
}

// MARK: - AuthManager

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: UserAccount?
    @Published var isLoggedIn: Bool = false

    var rememberMe: Bool {
        get { UserDefaults.standard.bool(forKey: "rememberMe") }
        set { UserDefaults.standard.set(newValue, forKey: "rememberMe") }
    }
    var lastUserId: String {
        get { UserDefaults.standard.string(forKey: "lastUserId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lastUserId") }
    }

    // Brute force protection for invite code
    private var inviteCodeAttempts: Int {
        get { UserDefaults.standard.integer(forKey: "inviteCodeAttempts") }
        set { UserDefaults.standard.set(newValue, forKey: "inviteCodeAttempts") }
    }
    private var inviteCodeLockUntil: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: "inviteCodeLockUntil")
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0,
                                      forKey: "inviteCodeLockUntil")
        }
    }

    private init() {}

    var currentRole: UserRole { currentUser?.role ?? .viewer }

    // MARK: - Password

    func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Login

    func login(emailOrPhone: String, password: String, context: ModelContext) -> LoginResult {
        let hash = hashPassword(password)
        let descriptor = FetchDescriptor<UserAccount>()
        guard let users = try? context.fetch(descriptor) else { return .invalidCredentials }
        let normalized = emailOrPhone.lowercased().trimmingCharacters(in: .whitespaces)
        guard let user = users.first(where: {
            ($0.email.lowercased() == normalized || $0.phone == normalized)
            && $0.passwordHash == hash
        }) else { return .invalidCredentials }

        switch user.accountStatus {
        case .pendingApproval:
            return .pendingApproval
        case .rejected:
            let reason = user.company?.joinRequests
                .first(where: { $0.user?.id == user.id && $0.status == .rejected })?
                .rejectionReason
            return .rejected(reason: reason)
        case .suspended:
            return .suspended
        case .active:
            user.lastLoginDate = Date()
            try? context.save()
            DispatchQueue.main.async {
                self.currentUser = user
                self.isLoggedIn = true
                if self.rememberMe { self.lastUserId = user.id.uuidString }
            }
            return .success
        }
    }

    // MARK: - Logout

    func logout() {
        currentUser = nil
        isLoggedIn = false
        if !rememberMe { lastUserId = "" }
    }

    // MARK: - Register

    func register(user: UserAccount, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<UserAccount>()
        guard let existing = try? context.fetch(descriptor) else { return false }
        let emailExists = existing.contains { $0.email.lowercased() == user.email.lowercased() }
        guard !emailExists else { return false }
        context.insert(user)
        do {
            try context.save()
            DispatchQueue.main.async {
                self.currentUser = user
                self.isLoggedIn = true
                self.lastUserId = user.id.uuidString
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Auto Login

    func tryAutoLogin(context: ModelContext) {
        guard !lastUserId.isEmpty, let uid = UUID(uuidString: lastUserId) else { return }
        let descriptor = FetchDescriptor<UserAccount>()
        guard let users = try? context.fetch(descriptor),
              let user = users.first(where: { $0.id == uid && $0.accountStatus == .active }) else { return }
        currentUser = user
        isLoggedIn = true
    }

    // MARK: - Change Password

    func changePassword(user: UserAccount, oldPassword: String, newPassword: String,
                        context: ModelContext) -> Bool {
        guard hashPassword(oldPassword) == user.passwordHash else { return false }
        user.passwordHash = hashPassword(newPassword)
        do { try context.save(); return true } catch { return false }
    }

    // MARK: - Invite Code Validation

    func validateInviteCode(_ code: String, context: ModelContext) -> InviteCodeResult {
        // Check lock
        if let lockUntil = inviteCodeLockUntil {
            if lockUntil > Date() { return .locked(until: lockUntil) }
            // Lock expired — reset
            inviteCodeLockUntil = nil
            inviteCodeAttempts = 0
        }

        let upper = code.uppercased().trimmingCharacters(in: .whitespaces)

        guard Company.validateFormat(upper) else {
            recordFailedInviteAttempt()
            return .invalidFormat
        }
        guard Company.validateChecksum(upper) else {
            recordFailedInviteAttempt()
            return .invalidChecksum
        }

        let descriptor = FetchDescriptor<Company>()
        guard let companies = try? context.fetch(descriptor) else { return .notFound }
        guard let company = companies.first(where: { $0.inviteCode.uppercased() == upper }) else {
            recordFailedInviteAttempt()
            return .notFound
        }

        guard company.isInviteCodeActive else { return .inactive }

        if let expiresAt = company.inviteCodeExpiresAt, expiresAt < Date() {
            return .expired
        }

        // Success
        inviteCodeAttempts = 0
        return .success(company)
    }

    private func recordFailedInviteAttempt() {
        inviteCodeAttempts += 1
        if inviteCodeAttempts >= 5 {
            inviteCodeLockUntil = Date().addingTimeInterval(15 * 60)
            inviteCodeAttempts = 0
        }
    }

    // MARK: - Approve / Reject Join Request

    func approveJoinRequest(_ request: JoinRequest, role: UserRole? = nil, context: ModelContext) {
        guard let reviewer = currentUser else { return }
        request.status = .approved
        request.reviewedBy = reviewer.fullName
        request.reviewDate = Date()
        if let role = role { request.user?.role = role }
        request.user?.accountStatus = .active
        try? context.save()
        if let user = request.user {
            NotificationManager.shared.scheduleApprovalNotification(for: user)
        }
    }

    func rejectJoinRequest(_ request: JoinRequest, reason: String, context: ModelContext) {
        guard let reviewer = currentUser else { return }
        request.status = .rejected
        request.reviewedBy = reviewer.fullName
        request.reviewDate = Date()
        request.rejectionReason = reason.isEmpty ? nil : reason
        request.user?.accountStatus = .rejected
        try? context.save()
        if let user = request.user {
            NotificationManager.shared.scheduleRejectionNotification(for: user)
        }
    }
}
