import Foundation
import SwiftUI
import SwiftData
import CryptoKit

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

    private init() {
        // Auto-login if rememberMe and lastUserId set — actual fetch happens in view with context
    }

    var currentRole: UserRole { currentUser?.role ?? .viewer }

    func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func login(emailOrPhone: String, password: String, context: ModelContext) -> Bool {
        let hash = hashPassword(password)
        let descriptor = FetchDescriptor<UserAccount>()
        guard let users = try? context.fetch(descriptor) else { return false }
        let normalized = emailOrPhone.lowercased().trimmingCharacters(in: .whitespaces)
        guard let user = users.first(where: {
            ($0.email.lowercased() == normalized || $0.phone == normalized)
            && $0.passwordHash == hash
            && $0.isActive
        }) else { return false }
        user.lastLoginDate = Date()
        try? context.save()
        DispatchQueue.main.async {
            self.currentUser = user
            self.isLoggedIn = true
            if self.rememberMe { self.lastUserId = user.id.uuidString }
        }
        return true
    }

    func logout() {
        currentUser = nil
        isLoggedIn = false
        if !rememberMe { lastUserId = "" }
    }

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

    func tryAutoLogin(context: ModelContext) {
        guard !lastUserId.isEmpty, let uid = UUID(uuidString: lastUserId) else { return }
        let descriptor = FetchDescriptor<UserAccount>()
        guard let users = try? context.fetch(descriptor),
              let user = users.first(where: { $0.id == uid && $0.isActive }) else { return }
        currentUser = user
        isLoggedIn = true
    }

    func changePassword(user: UserAccount, oldPassword: String, newPassword: String, context: ModelContext) -> Bool {
        guard hashPassword(oldPassword) == user.passwordHash else { return false }
        user.passwordHash = hashPassword(newPassword)
        do { try context.save(); return true } catch { return false }
    }
}
