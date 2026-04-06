import SwiftUI
import SwiftData
import PhotosUI

struct RegisterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @State private var step = 0

    // Step 1 — Kişisel
    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var profileItem: PhotosPickerItem? = nil
    @State private var profilePhotoData: Data? = nil

    // Step 2 — Firma
    @State private var companyName = ""
    @State private var logoItem: PhotosPickerItem? = nil
    @State private var logoData: Data? = nil

    // Step 3 — Meslek/Rol
    @State private var selectedProfession: UserProfession = .civilEngineer
    @State private var selectedRole: UserRole = .owner
    @State private var registrationNumber = ""

    // Step 4 — Şifre
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isCreating = false

    private let stepTitles = ["Kişisel Bilgiler", "Firma Bilgileri", "Meslek ve Rol", "Şifre Oluştur"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                stepProgressBar

                ScrollView {
                    VStack(spacing: 24) {
                        switch step {
                        case 0: step1View
                        case 1: step2View
                        case 2: step3View
                        case 3: step4View
                        default: EmptyView()
                        }
                    }
                    .padding()
                }

                // Navigation buttons
                stepButtons
                    .padding()
            }
            .background(Color.hakedisBackground.ignoresSafeArea())
            .navigationTitle(stepTitles[step])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }

    // MARK: Progress Bar
    private var stepProgressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? Color.hakedisOrange : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.hakedisCard)
    }

    // MARK: Step 1 — Kişisel
    private var step1View: some View {
        VStack(spacing: 16) {
            // Profil fotoğrafı
            PhotosPicker(selection: $profileItem, matching: .images) {
                ZStack {
                    if let data = profilePhotoData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.hakedisOrange.opacity(0.15))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "person.fill.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.hakedisOrange)
                            )
                    }
                    Circle()
                        .stroke(Color.hakedisOrange, lineWidth: 2)
                        .frame(width: 90, height: 90)
                }
            }
            .onChange(of: profileItem) { _, item in
                Task {
                    profilePhotoData = try? await item?.loadTransferable(type: Data.self)
                }
            }
            .accessibilityLabel("Profil fotoğrafı seç")

            formField(label: "Ad Soyad *", placeholder: "Ali Yılmaz", text: $fullName)
            formField(label: "E-posta *", placeholder: "ali@email.com", text: $email,
                      keyboard: .emailAddress)
            formField(label: "Telefon", placeholder: "05XX XXX XX XX", text: $phone,
                      keyboard: .phonePad)
        }
    }

    // MARK: Step 2 — Firma
    private var step2View: some View {
        VStack(spacing: 16) {
            // Logo
            PhotosPicker(selection: $logoItem, matching: .images) {
                ZStack {
                    if let data = logoData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(width: 100, height: 60)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.hakedisCard)
                            .frame(width: 100, height: 60)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: "building.2").foregroundColor(.hakedisOrange)
                                    Text("Logo Ekle").font(.caption2).foregroundColor(.secondary)
                                }
                            )
                    }
                }
            }
            .onChange(of: logoItem) { _, item in
                Task { logoData = try? await item?.loadTransferable(type: Data.self) }
            }
            .accessibilityLabel("Firma logosu seç")

            formField(label: "Firma Adı *", placeholder: "ABC İnşaat Ltd. Şti.", text: $companyName)
        }
    }

    // MARK: Step 3 — Meslek/Rol
    private var step3View: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Meslek").font(.caption).foregroundColor(.secondary)
                Picker("Meslek", selection: $selectedProfession) {
                    ForEach(UserProfession.allCases, id: \.rawValue) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .padding(12)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Meslek seç")
            }

            formField(label: "Oda Sicil No (opsiyonel)", placeholder: "54321", text: $registrationNumber)

            VStack(alignment: .leading, spacing: 6) {
                Text("Rol *").font(.caption).foregroundColor(.secondary)
                Picker("Rol", selection: $selectedRole) {
                    ForEach(UserRole.allCases, id: \.rawValue) { r in
                        Label(r.displayName, systemImage: r.icon).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .padding(12)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Rol seç")
            }

            // Rol açıklaması
            roleDescription
        }
    }

    private var roleDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(selectedRole.displayName, systemImage: selectedRole.icon)
                .font(.subheadline.bold())
                .foregroundColor(.hakedisOrange)

            VStack(alignment: .leading, spacing: 4) {
                if selectedRole.canSeeFinancials {
                    permRow("Finansal verileri görüntüleyebilir", true)
                }
                if selectedRole.canSeeProfitability {
                    permRow("Kârlılık analizini görüntüleyebilir", true)
                }
                if selectedRole.canCreateHakedis {
                    permRow("Hakediş oluşturabilir", true)
                }
                if selectedRole.canApproveHakedis {
                    permRow("Hakediş onaylayabilir", true)
                }
                if selectedRole.canManageUsers {
                    permRow("Kullanıcıları yönetebilir", true)
                }
                if !selectedRole.canDeleteData {
                    permRow("Veri silme yetkisi yok", false)
                }
                if selectedRole == .viewer {
                    permRow("Yalnızca görüntüleme — düzenleme yapamaz", false)
                }
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func permRow(_ text: String, _ positive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: positive ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(positive ? .hakedisSuccess : .hakedisDanger)
                .font(.caption)
            Text(text).font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: Step 4 — Şifre
    private var step4View: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Şifre *").font(.caption).foregroundColor(.secondary)
                HStack {
                    Group {
                        if showPassword { TextField("••••••", text: $password) }
                        else { SecureField("••••••", text: $password) }
                    }
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Şifre Tekrar *").font(.caption).foregroundColor(.secondary)
                SecureField("••••••", text: $passwordConfirm)
                    .padding(12)
                    .background(Color.hakedisCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Şifre güvenlik göstergesi
            if !password.isEmpty {
                passwordStrengthView
            }

            if !errorMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.hakedisDanger)
                    Text(errorMessage).font(.subheadline).foregroundColor(.hakedisDanger)
                }
                .padding(10)
                .background(Color.hakedisDanger.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var passwordStrengthView: some View {
        let strength = passwordStrength(password)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Şifre Güvenliği:")
                    .font(.caption).foregroundColor(.secondary)
                Text(strength.label)
                    .font(.caption.bold())
                    .foregroundColor(strength.color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(strength.color)
                        .frame(width: geo.size.width * strength.fraction, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func passwordStrength(_ pw: String) -> (label: String, color: Color, fraction: CGFloat) {
        var score = 0
        if pw.count >= 6 { score += 1 }
        if pw.count >= 10 { score += 1 }
        if pw.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if pw.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }
        switch score {
        case 0, 1: return ("Zayıf", .hakedisDanger, 0.25)
        case 2:    return ("Orta", .hakedisWarning, 0.5)
        case 3:    return ("İyi", Color.hakedisSuccess.opacity(0.8), 0.75)
        default:   return ("Güçlü", .hakedisSuccess, 1.0)
        }
    }

    // MARK: Step Buttons
    private var stepButtons: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button { withAnimation { step -= 1 } } label: {
                    Text("Geri")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.hakedisCard)
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Geri")
            }

            Button {
                if step < 3 {
                    if validateCurrentStep() { withAnimation { step += 1 } }
                } else {
                    doRegister()
                }
            } label: {
                ZStack {
                    Text(step == 3 ? "Hesabı Oluştur" : "Devam")
                        .font(.headline)
                        .foregroundColor(.white)
                        .opacity(isCreating ? 0 : 1)
                    if isCreating { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.hakedisOrange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isCreating)
            .accessibilityLabel(step == 3 ? "Hesabı oluştur" : "Devam et")
        }
    }

    // MARK: Validation
    private func validateCurrentStep() -> Bool {
        errorMessage = ""
        switch step {
        case 0:
            guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Ad soyad zorunludur."; return false
            }
            guard email.contains("@") else {
                errorMessage = "Geçerli bir e-posta girin."; return false
            }
        case 1:
            guard !companyName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Firma adı zorunludur."; return false
            }
        default: break
        }
        return true
    }

    private func doRegister() {
        errorMessage = ""
        guard password.count >= 6 else {
            errorMessage = "Şifre en az 6 karakter olmalıdır."; return
        }
        guard password == passwordConfirm else {
            errorMessage = "Şifreler eşleşmiyor."; return
        }
        isCreating = true
        let hash = authManager.hashPassword(password)
        let user = UserAccount(fullName: fullName, email: email, role: selectedRole, passwordHash: hash)
        user.phone = phone.isEmpty ? nil : phone
        user.companyName = companyName.isEmpty ? nil : companyName
        user.companyLogoData = logoData
        user.profilePhotoData = profilePhotoData
        user.professionRaw = selectedProfession.rawValue
        user.registrationNumber = registrationNumber.isEmpty ? nil : registrationNumber
        authManager.rememberMe = true
        let success = authManager.register(user: user, context: modelContext)
        isCreating = false
        if success {
            dismiss()
        } else {
            errorMessage = "Bu e-posta adresi zaten kayıtlı."
        }
    }

    // MARK: Helper
    private func formField(label: String, placeholder: String, text: Binding<String>,
                           keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocapitalization(keyboard == .emailAddress ? .none : .words)
                .padding(12)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(label)
        }
    }
}
