import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authManager = AuthManager.shared
    @State private var emailOrPhone = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showRegister = false

    // Account status states
    @State private var pendingUser: UserAccount? = nil
    @State private var rejectedReason: String? = nil
    @State private var showPendingScreen = false
    @State private var showRejectedScreen = false

    var body: some View {
        NavigationStack {
            Group {
                if showPendingScreen {
                    PendingApprovalScreen(user: pendingUser) {
                        resetToLogin()
                    }
                } else if showRejectedScreen {
                    RejectedScreen(reason: rejectedReason) {
                        showRejectedScreen = false
                    }
                } else {
                    loginForm
                }
            }
            .background(Color.hakedisBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showRegister) {
                RegisterView()
            }
            .onAppear {
                rememberMe = authManager.rememberMe
            }
        }
    }

    // MARK: - Login Form
    private var loginForm: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Logo + başlık
                VStack(spacing: 12) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.hakedisOrange)
                        .accessibilityHidden(true)
                    Text("HakedişApp")
                        .font(.largeTitle.bold())
                    Text("İnşaat Proje Yönetimi")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                // Giriş formu
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("E-posta veya Telefon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("ornek@email.com", text: $emailOrPhone)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(12)
                            .background(Color.hakedisCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("E-posta veya telefon")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Şifre")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("••••••", text: $password)
                                } else {
                                    SecureField("••••••", text: $password)
                                }
                            }
                            .textContentType(.password)
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityLabel(showPassword ? "Şifreyi gizle" : "Şifreyi göster")
                        }
                        .padding(12)
                        .background(Color.hakedisCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Toggle("Beni Hatırla", isOn: $rememberMe)
                        .font(.subheadline)
                        .accessibilityLabel("Beni hatırla")

                    if !errorMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.hakedisDanger)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.hakedisDanger)
                        }
                        .padding(10)
                        .background(Color.hakedisDanger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)

                // Butonlar
                VStack(spacing: 12) {
                    Button {
                        doLogin()
                    } label: {
                        ZStack {
                            Text("Giriş Yap")
                                .font(.headline)
                                .foregroundColor(.white)
                                .opacity(isLoading ? 0 : 1)
                            if isLoading {
                                ProgressView().tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.hakedisOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || emailOrPhone.isEmpty || password.isEmpty)
                    .accessibilityLabel("Giriş yap")
                    .padding(.horizontal)

                    Button {
                        showRegister = true
                    } label: {
                        Text("Hesabın yok mu? **Hesap Oluştur**")
                            .font(.subheadline)
                            .foregroundColor(.hakedisOrange)
                    }
                    .accessibilityLabel("Hesap oluştur")
                }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Login Action

    private func doLogin() {
        isLoading = true
        errorMessage = ""
        authManager.rememberMe = rememberMe
        DispatchQueue.global(qos: .userInitiated).async {
            let result = authManager.login(
                emailOrPhone: emailOrPhone,
                password: password,
                context: modelContext
            )
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    break // RootView handles navigation
                case .invalidCredentials:
                    errorMessage = "E-posta veya şifre hatalı. Lütfen tekrar deneyin."
                case .pendingApproval:
                    // Fetch user to show name
                    let descriptor = FetchDescriptor<UserAccount>()
                    let users = (try? modelContext.fetch(descriptor)) ?? []
                    let normalized = emailOrPhone.lowercased().trimmingCharacters(in: .whitespaces)
                    pendingUser = users.first(where: {
                        $0.email.lowercased() == normalized || $0.phone == normalized
                    })
                    showPendingScreen = true
                case .rejected(let reason):
                    rejectedReason = reason
                    showRejectedScreen = true
                case .suspended:
                    errorMessage = "Hesabınız askıya alınmıştır. Şirket yöneticinize başvurun."
                }
            }
        }
    }

    private func resetToLogin() {
        showPendingScreen = false
        showRejectedScreen = false
        pendingUser = nil
        rejectedReason = nil
        emailOrPhone = ""
        password = ""
    }
}

// MARK: - PendingApprovalScreen

private struct PendingApprovalScreen: View {
    let user: UserAccount?
    let onLogout: () -> Void

    private var waitingDuration: String {
        guard let date = user?.createdAt else { return "" }
        let hours = Int(Date().timeIntervalSince(date) / 3600)
        if hours < 1 { return "Az önce gönderildi" }
        if hours < 24 { return "\(hours) saattir bekliyor" }
        let days = hours / 24
        return "\(days) gündür bekliyor"
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "clock.badge.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.hakedisWarning)
                    .accessibilityHidden(true)

                if let user = user {
                    Text("Merhaba, \(user.fullName.components(separatedBy: " ").first ?? user.fullName)!")
                        .font(.title2.bold())
                }

                Text("Hesabınız Onay Bekliyor")
                    .font(.headline)
                    .foregroundColor(.hakedisWarning)

                Text("Şirket yöneticisi talebinizi henüz onaylamamış. Onaylandıktan sonra giriş yapabilirsiniz.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if !waitingDuration.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "timer").foregroundColor(.secondary)
                        Text(waitingDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let company = user?.company {
                HStack(spacing: 10) {
                    Image(systemName: "building.2").foregroundColor(.hakedisOrange)
                    Text(company.companyName).font(.subheadline.bold())
                }
                .padding(12)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()

            Button(action: onLogout) {
                Label("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.headline)
                    .foregroundColor(.hakedisDanger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.hakedisDanger.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .accessibilityLabel("Çıkış yap")
        }
    }
}

// MARK: - RejectedScreen

private struct RejectedScreen: View {
    let reason: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.hakedisDanger)
                    .accessibilityHidden(true)

                Text("Talebiniz Reddedildi")
                    .font(.title2.bold())

                if let reason = reason, !reason.isEmpty {
                    VStack(spacing: 6) {
                        Text("Red Gerekçesi:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(reason)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(12)
                    .background(Color.hakedisDanger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("Şirket yöneticisi talebinizi reddetti.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            Button(action: onRetry) {
                Label("Tekrar Dene", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.hakedisOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .accessibilityLabel("Tekrar giriş dene")
        }
    }
}
