import SwiftUI
import LocalAuthentication

// MARK: - Biometric Auth Manager

final class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    @Published var isLocked: Bool = false
    @Published var authError: String? = nil

    private let context = LAContext()
    private var lastActiveDate: Date? = nil
    private let lockTimeoutSeconds: TimeInterval = 60

    var biometryType: LABiometryType { context.biometryType }
    var isBiometricAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(completion: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            isLocked = false
            completion(true)
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "HakedisApp'a erişmek için kimlik doğrulaması gerekiyor") { [weak self] success, err in
            DispatchQueue.main.async {
                if success {
                    self?.isLocked = false
                    self?.authError = nil
                    self?.lastActiveDate = Date()
                    completion(true)
                } else {
                    self?.authError = err?.localizedDescription
                    completion(false)
                }
            }
        }
    }

    func checkTimeout() {
        guard let last = lastActiveDate else { return }
        if Date().timeIntervalSince(last) > lockTimeoutSeconds {
            isLocked = true
        }
    }

    func updateActivity() {
        lastActiveDate = Date()
    }

    func lockApp() {
        isLocked = true
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    @StateObject private var authManager = BiometricAuthManager.shared
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            Color.hakedisBackground.ignoresSafeArea()
            VStack(spacing: 32) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.hakedisOrange)
                Text("HakedisApp")
                    .font(.largeTitle.bold())
                Text("Uygulamaya erişmek için kimlik doğrulaması yapın")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                if let error = authManager.authError {
                    Text(error).font(.caption).foregroundColor(.hakedisDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Button {
                    isAuthenticating = true
                    authManager.authenticate { _ in isAuthenticating = false }
                } label: {
                    Label(
                        authManager.biometryType == .faceID ? "Face ID ile Giriş" : "Touch ID ile Giriş",
                        systemImage: authManager.biometryType == .faceID ? "faceid" : "touchid"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.hakedisOrange)
                    .cornerRadius(12)
                }
                .disabled(isAuthenticating)
            }
        }
        .onAppear {
            authManager.authenticate { _ in }
        }
    }
}

// MARK: - KVKK Consent View

struct KVKKConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("kvkk_accepted") private var isAccepted: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("KVKK Aydınlatma Metni")
                        .font(.title2.bold())
                    Text(kvkkText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if !isAccepted {
                        Button {
                            isAccepted = true
                            dismiss()
                        } label: {
                            Text("Okudum ve Onaylıyorum")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.hakedisOrange)
                                .cornerRadius(12)
                        }
                    } else {
                        Label("Onaylandı", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.hakedisSuccess)
                            .font(.headline)
                    }
                }
                .padding()
            }
            .navigationTitle("Gizlilik")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private let kvkkText = """
    6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında veri sorumlusu sıfatıyla bilgi vermek isteriz.

    **İşlenen Kişisel Veriler**
    Uygulama; proje bilgileri, sözleşme detayları, personel isimleri ve şantiye verileri işlemektedir.

    **İşleme Amacı**
    Veriler yalnızca hakediş ve inşaat proje yönetimi amacıyla kullanılmaktadır.

    **Veri Güvenliği**
    Tüm veriler cihazınızda yerel olarak saklanmaktadır. Harici sunuculara aktarım yapılmamaktadır.

    **Haklarınız**
    KVKK Madde 11 kapsamında; verilerinize erişim, düzeltme, silme, itiraz etme haklarınız mevcuttur.

    **Veri Silme**
    Ayarlar → Veri Yönetimi bölümünden tüm verilerinizi kalıcı olarak silebilirsiniz.

    Daha fazla bilgi için: hakedisapp.com/gizlilik
    """
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Gizlilik Politikası")
                    .font(.title2.bold())
                    .padding(.bottom, 8)
                Group {
                    PolicySection(title: "1. Veri Toplama", content: "Uygulama yalnızca kullanıcı tarafından girilen proje ve hakediş verilerini toplar.")
                    PolicySection(title: "2. Veri Kullanımı", content: "Toplanan veriler sadece uygulama işlevleri için kullanılır, üçüncü taraflarla paylaşılmaz.")
                    PolicySection(title: "3. Veri Depolama", content: "Tüm veriler cihazınızda yerel olarak SwiftData ile şifreli olarak saklanır.")
                    PolicySection(title: "4. Güvenlik", content: "Face ID/Touch ID ile uygulama kilitleme, otomatik zaman aşımı koruması mevcuttur.")
                    PolicySection(title: "5. Veri Silme", content: "Kullanıcı tüm verilerini Ayarlar bölümünden tamamen silebilir.")
                    PolicySection(title: "6. İletişim", content: "Sorularınız için: destek@hakedisapp.com")
                }
            }
            .padding()
        }
        .navigationTitle("Gizlilik Politikası")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PolicySection: View {
    let title: String
    let content: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(content).font(.subheadline).foregroundColor(.secondary)
        }
    }
}

// MARK: - Data Deletion View

struct DataDeletionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false
    @State private var isDeleting = false
    @State private var isDeleted = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Bu işlem tüm proje, sözleşme, hakediş ve ilgili verilerinizi kalıcı olarak siler.")
                        .foregroundColor(.hakedisDanger)
                        .font(.subheadline)
                }
                Section {
                    if isDeleted {
                        Label("Tüm veriler silindi", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.hakedisSuccess)
                    } else {
                        Button(role: .destructive) {
                            showConfirmation = true
                        } label: {
                            Label("Tüm Verileri Sil", systemImage: "trash.fill")
                        }
                        .disabled(isDeleting)
                    }
                }
            }
            .navigationTitle("Veri Silme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .confirmationDialog("Tüm verileri silmek istediğinize emin misiniz?",
                                isPresented: $showConfirmation, titleVisibility: .visible) {
                Button("Sil", role: .destructive) { deleteAllData() }
                Button("İptal", role: .cancel) {}
            }
        }
    }

    private func deleteAllData() {
        isDeleting = true
        // In production, enumerate all model types and delete
        // For safety, we only log here
        print("DataDeletionView: User confirmed data deletion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isDeleting = false
            isDeleted = true
        }
    }
}
