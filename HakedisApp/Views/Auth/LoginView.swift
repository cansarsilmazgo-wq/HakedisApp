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

    var body: some View {
        NavigationStack {
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
                                .autocapitalization(.none)
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

    private func doLogin() {
        isLoading = true
        errorMessage = ""
        authManager.rememberMe = rememberMe
        DispatchQueue.global(qos: .userInitiated).async {
            let success = authManager.login(emailOrPhone: emailOrPhone, password: password, context: modelContext)
            DispatchQueue.main.async {
                isLoading = false
                if !success {
                    errorMessage = "E-posta veya şifre hatalı. Lütfen tekrar deneyin."
                }
            }
        }
    }
}
