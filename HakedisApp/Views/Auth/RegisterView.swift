import SwiftUI
import SwiftData
import PhotosUI

// MARK: - RegisterPath

private enum RegisterPath {
    case owner
    case employee
}

// MARK: - RegisterView

struct RegisterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @StateObject private var authManager = AuthManager.shared

    @State private var path: RegisterPath? = nil

    var body: some View {
        NavigationStack {
            Group {
                if path == nil {
                    PathSelectionView(path: $path)
                } else if path == .owner {
                    OwnerRegisterView()
                } else {
                    EmployeeRegisterView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(path == nil ? "İptal" : "Geri") {
                        if path == nil { dismiss() } else { withAnimation { path = nil } }
                    }
                }
            }
        }
    }
}

// MARK: - PathSelectionView

private struct PathSelectionView: View {
    @Binding var path: RegisterPath?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.hakedisOrange)
                    Text("Nasıl devam etmek istersiniz?")
                        .font(.title2.bold())
                    Text("Şirket hesabı oluşturun veya\nmevcut bir şirkete katılın.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    pathCard(
                        icon: "crown.fill",
                        iconColor: .hakedisOrange,
                        title: "Şirket Oluştur",
                        subtitle: "Yeni bir şirket hesabı açın ve ekibinizi davet edin",
                        role: "Patron"
                    ) { path = .owner }

                    pathCard(
                        icon: "hammer.fill",
                        iconColor: .hakedisSuccess,
                        title: "Şirkete Katıl",
                        subtitle: "Davet kodu ile mevcut bir şirkete katılın",
                        role: "Çalışan"
                    ) { path = .employee }
                }
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .background(Color.hakedisBackground.ignoresSafeArea())
        .navigationTitle("Hesap Oluştur")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pathCard(icon: String, iconColor: Color, title: String,
                          subtitle: String, role: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.headline)
                        Spacer()
                        Text(role)
                            .font(.caption.bold())
                            .foregroundColor(iconColor)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(iconColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .background(Color.hakedisCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(iconColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - OwnerRegisterView

private struct OwnerRegisterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @StateObject private var authManager = AuthManager.shared

    @State private var step = 0

    // Step 0 — Kişisel
    @State private var fullName       = ""
    @State private var email          = ""
    @State private var phone          = ""
    @State private var selectedProfession: UserProfession = .civilEngineer
    @State private var profileItem: PhotosPickerItem? = nil
    @State private var profilePhotoData: Data? = nil

    // Step 1 — Şirket
    @State private var companyName    = ""
    @State private var taxNumber      = ""
    @State private var address        = ""
    @State private var companyPhone   = ""
    @State private var logoItem: PhotosPickerItem? = nil
    @State private var logoData: Data? = nil

    // Step 2 — Şifre
    @State private var password       = ""
    @State private var passwordConfirm = ""
    @State private var showPassword   = false

    // Step 3 — Tamamlandı
    @State private var createdCompany: Company? = nil

    @State private var errorMessage   = ""
    @State private var isCreating     = false

    private let stepTitles = ["Kişisel Bilgiler", "Şirket Bilgileri", "Şifre Oluştur", "Tamamlandı"]

    var body: some View {
        VStack(spacing: 0) {
            if step < 3 {
                progressBar(steps: 3, current: step)
            }
            ScrollView {
                VStack(spacing: 24) {
                    switch step {
                    case 0: ownerStep0
                    case 1: ownerStep1
                    case 2: ownerStep2
                    case 3: ownerStep3
                    default: EmptyView()
                    }
                }
                .padding()
            }
            if step < 3 {
                navButtons(
                    isLast: step == 2,
                    isCreating: isCreating,
                    onNext: {
                        if step < 2 {
                            if validateOwnerStep() { withAnimation { step += 1 } }
                        } else {
                            doOwnerRegister()
                        }
                    }
                )
                .padding()
            }
        }
        .background(Color.hakedisBackground.ignoresSafeArea())
        .navigationTitle(step < stepTitles.count ? stepTitles[step] : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Step 0
    private var ownerStep0: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $profileItem, matching: .images) {
                profilePhotoCircle(data: profilePhotoData)
            }
            .onChange(of: profileItem) { _, item in
                Task { profilePhotoData = try? await item?.loadTransferable(type: Data.self) }
            }
            .accessibilityLabel("Profil fotoğrafı seç")

            formField("Ad Soyad *", "Ali Yılmaz", $fullName)
            formField("E-posta *", "ali@email.com", $email, keyboard: .emailAddress)
            formField("Telefon", "05XX XXX XX XX", $phone, keyboard: .phonePad)

            professionPicker(selection: $selectedProfession)

            if !errorMessage.isEmpty { errorBanner(errorMessage) }
        }
    }

    // MARK: Step 1
    private var ownerStep1: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $logoItem, matching: .images) {
                logoPicker(data: logoData)
            }
            .onChange(of: logoItem) { _, item in
                Task { logoData = try? await item?.loadTransferable(type: Data.self) }
            }
            .accessibilityLabel("Firma logosu seç")

            formField("Şirket Adı *", "ABC İnşaat Ltd. Şti.", $companyName)
            formField("Vergi No", "1234567890", $taxNumber, keyboard: .numberPad)
            formField("Adres", "İstanbul, Türkiye", $address)
            formField("Telefon", "+90 212 XXX XX XX", $companyPhone, keyboard: .phonePad)

            if !errorMessage.isEmpty { errorBanner(errorMessage) }
        }
    }

    // MARK: Step 2
    private var ownerStep2: some View {
        VStack(spacing: 16) {
            passwordFields(password: $password, confirm: $passwordConfirm,
                           showPassword: $showPassword)
            if !errorMessage.isEmpty { errorBanner(errorMessage) }
        }
    }

    // MARK: Step 3 — Success
    private var ownerStep3: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.hakedisSuccess)
                Text("Şirketiniz oluşturuldu!")
                    .font(.title2.bold())
                Text("Çalışanlarınıza aşağıdaki davet kodunu verin.\nBu kod ile şirketinize katılabilirler.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let company = createdCompany {
                VStack(spacing: 12) {
                    Text(company.inviteCode)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.hakedisOrange)
                        .padding(16)
                        .background(Color.hakedisOrange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Davet kodu: \(company.inviteCode)")

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = company.inviteCode
                        } label: {
                            Label("Kopyala", systemImage: "doc.on.doc")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color.hakedisCard)
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityLabel("Davet kodunu kopyala")

                        ShareLink(item: "HakedişApp davet kodunuz: \(company.inviteCode)") {
                            Label("Paylaş", systemImage: "square.and.arrow.up")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color.hakedisOrange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityLabel("Davet kodunu paylaş")
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Ana Ekrana Git")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.hakedisOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Ana ekrana git")
        }
    }

    // MARK: Validation
    private func validateOwnerStep() -> Bool {
        errorMessage = ""
        switch step {
        case 0:
            guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Ad soyad zorunludur."; return false
            }
            guard isValidEmail(email) else {
                errorMessage = "Geçerli bir e-posta adresi girin."; return false
            }
        case 1:
            guard !companyName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Şirket adı zorunludur."; return false
            }
        default: break
        }
        return true
    }

    // MARK: Register
    private func doOwnerRegister() {
        errorMessage = ""
        guard password.count >= 6 else {
            errorMessage = "Şifre en az 6 karakter olmalıdır."; return
        }
        guard password == passwordConfirm else {
            errorMessage = "Şifreler eşleşmiyor."; return
        }
        isCreating = true
        let hash = authManager.hashPassword(password)

        // Create owner user
        let user = UserAccount(fullName: fullName, email: email, role: .owner, passwordHash: hash)
        user.phone = phone.isEmpty ? nil : phone
        user.profilePhotoData = profilePhotoData
        user.professionRaw = selectedProfession.rawValue

        // Create company
        let company = Company(companyName: companyName)
        company.taxNumber = taxNumber.isEmpty ? nil : taxNumber
        company.address = address.isEmpty ? nil : address
        company.phone = companyPhone.isEmpty ? nil : companyPhone
        company.logoData = logoData

        // Fix 6: Davet kodu uniqueness kontrolü
        let companyDescriptor = FetchDescriptor<Company>()
        if let existingCompanies = try? modelContext.fetch(companyDescriptor) {
            var attempts = 0
            while existingCompanies.contains(where: { $0.inviteCode == company.inviteCode }) && attempts < 10 {
                company.regenerateInviteCode()
                attempts += 1
            }
        }

        company.members.append(user)
        user.company = company
        user.companyName = companyName
        user.companyLogoData = logoData

        modelContext.insert(company)
        authManager.rememberMe = true
        let success = authManager.register(user: user, context: modelContext)
        isCreating = false
        if success {
            createdCompany = company
            withAnimation { step = 3 }
        } else {
            errorMessage = "Bu e-posta adresi zaten kayıtlı."
        }
    }
}

// MARK: - EmployeeRegisterView

private struct EmployeeRegisterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @StateObject private var authManager = AuthManager.shared

    @State private var step = 0

    // Step 0 — Davet kodu
    @State private var inviteCodeRaw  = ""
    @State private var codeValidated  = false
    @State private var foundCompany: Company? = nil
    @State private var codeError      = ""
    @State private var isValidating   = false

    // Step 1 — Kişisel
    @State private var fullName       = ""
    @State private var email          = ""
    @State private var phone          = ""
    @State private var profileItem: PhotosPickerItem? = nil
    @State private var profilePhotoData: Data? = nil

    // Step 2 — Rol
    @State private var selectedRole: UserRole = .siteEngineer
    @State private var selectedProfession: UserProfession = .civilEngineer
    @State private var noteToOwner    = ""

    // Step 3 — Şifre
    @State private var password       = ""
    @State private var passwordConfirm = ""
    @State private var showPassword   = false

    @State private var errorMessage   = ""
    @State private var isCreating     = false

    private let stepTitles = ["Davet Kodu", "Kişisel Bilgiler", "Rol Seçimi", "Şifre Oluştur", "Beklemede"]

    // Roles employee can select (not owner)
    private let selectableRoles: [UserRole] = [
        .projectManager, .siteEngineer, .safetyOfficer, .siteForeman,
        .accountant, .subcontractor, .viewer
    ]

    var body: some View {
        VStack(spacing: 0) {
            if step < 4 {
                progressBar(steps: 4, current: step)
            }
            ScrollView {
                VStack(spacing: 24) {
                    switch step {
                    case 0: empStep0
                    case 1: empStep1
                    case 2: empStep2
                    case 3: empStep3
                    case 4: empStep4
                    default: EmptyView()
                    }
                }
                .padding()
            }
            if step < 4 {
                navButtons(
                    isLast: step == 3,
                    isCreating: isCreating,
                    onNext: {
                        if step == 0 {
                            if codeValidated { withAnimation { step = 1 } }
                            else { validateCode() }
                        } else if step < 3 {
                            if validateEmpStep() { withAnimation { step += 1 } }
                        } else {
                            doEmployeeRegister()
                        }
                    },
                    nextLabel: step == 0 ? (codeValidated ? "Devam" : "Doğrula") : nil
                )
                .padding()
            }
        }
        .background(Color.hakedisBackground.ignoresSafeArea())
        .navigationTitle(step < stepTitles.count ? stepTitles[step] : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Step 0 — Davet Kodu
    private var empStep0: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.hakedisOrange)
                Text("Şirket davet kodunu girin")
                    .font(.headline)
                Text("Şirket yöneticinizden aldığınız kodu girin.\nFormat: ALP-2026-7X9K-M3")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Davet Kodu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("XXX-YYYY-XXXX-XX", text: $inviteCodeRaw)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.hakedisCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: inviteCodeRaw) { _, newVal in
                        inviteCodeRaw = formatInviteCodeInput(newVal)
                        codeValidated = false
                        foundCompany = nil
                        codeError = ""
                    }
                    .accessibilityLabel("Davet kodu")
            }

            if codeValidated, let company = foundCompany {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.hakedisSuccess)
                    Text(company.companyName)
                        .font(.subheadline.bold())
                        .foregroundColor(.hakedisSuccess)
                }
                .padding(10)
                .background(Color.hakedisSuccess.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if isValidating {
                ProgressView().padding(.top, 4)
            }

            if !codeError.isEmpty { errorBanner(codeError) }
        }
    }

    // MARK: Step 1 — Kişisel
    private var empStep1: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $profileItem, matching: .images) {
                profilePhotoCircle(data: profilePhotoData)
            }
            .onChange(of: profileItem) { _, item in
                Task { profilePhotoData = try? await item?.loadTransferable(type: Data.self) }
            }
            .accessibilityLabel("Profil fotoğrafı seç")

            formField("Ad Soyad *", "Ali Yılmaz", $fullName)
            formField("E-posta *", "ali@email.com", $email, keyboard: .emailAddress)
            formField("Telefon", "05XX XXX XX XX", $phone, keyboard: .phonePad)

            if !errorMessage.isEmpty { errorBanner(errorMessage) }
        }
    }

    // MARK: Step 2 — Rol
    private var empStep2: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Rolünüz *").font(.caption).foregroundColor(.secondary)
                VStack(spacing: 8) {
                    ForEach(selectableRoles, id: \.rawValue) { role in
                        Button {
                            selectedRole = role
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: role.icon)
                                    .foregroundColor(selectedRole == role ? .hakedisOrange : .secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(role.displayName)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                    Text(role.shortDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedRole == role {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.hakedisOrange)
                                }
                            }
                            .padding(12)
                            .background(selectedRole == role
                                ? Color.hakedisOrange.opacity(0.08)
                                : Color.hakedisCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedRole == role
                                        ? Color.hakedisOrange.opacity(0.4)
                                        : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(role.displayName)
                    }
                }
            }

            professionPicker(selection: $selectedProfession)

            VStack(alignment: .leading, spacing: 6) {
                Text("Patrona Not (opsiyonel)").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $noteToOwner)
                    .frame(height: 80)
                    .padding(8)
                    .background(Color.hakedisCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        Group {
                            if noteToOwner.isEmpty {
                                Text("Örn: 3. şantiyede çalışıyorum")
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .font(.subheadline)
                                    .padding(12)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
                    .accessibilityLabel("Patrona not")
            }
        }
    }

    // MARK: Step 3 — Şifre
    private var empStep3: some View {
        VStack(spacing: 16) {
            passwordFields(password: $password, confirm: $passwordConfirm,
                           showPassword: $showPassword)
            if !errorMessage.isEmpty { errorBanner(errorMessage) }
        }
    }

    // MARK: Step 4 — Beklemede
    private var empStep4: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.hakedisWarning)
                Text("Talebiniz gönderildi!")
                    .font(.title2.bold())
                    .accessibilityLabel("Talep gönderildi")
                Text("Şirket yöneticisi talebinizi onayladığında giriş yapabilirsiniz.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                infoRow("building.2", "Şirket", foundCompany?.companyName ?? "—")
                infoRow("person.circle", "Seçilen Rol", selectedRole.displayName)
                infoRow("envelope.circle", "E-posta", email)
            }
            .padding(16)
            .background(Color.hakedisCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Talep durumunuzu kontrol etmek için giriş yapabilirsiniz.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Giriş Ekranına Git")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.hakedisOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Giriş ekranına git")
        }
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(.hakedisOrange).frame(width: 24)
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline.bold())
        }
    }

    // MARK: Code Validation
    private func validateCode() {
        codeError = ""
        isValidating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = authManager.validateInviteCode(inviteCodeRaw, context: modelContext)
            DispatchQueue.main.async {
                isValidating = false
                switch result {
                case .success(let company):
                    codeValidated = true
                    foundCompany = company
                case .invalidFormat:
                    codeError = "Kod formatı geçersiz. Format: XXX-YYYY-XXXX-XX"
                case .invalidChecksum:
                    codeError = "Geçersiz davet kodu. Lütfen doğru kodu girin."
                case .notFound:
                    codeError = "Bu davet kodu bulunamadı."
                case .inactive:
                    codeError = "Bu davet kodu devre dışı bırakılmış. Yöneticinize danışın."
                case .expired:
                    codeError = "Bu davet kodunun süresi dolmuş. Yöneticinize danışın."
                case .locked(let until):
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    codeError = "Çok fazla hatalı deneme. \(formatter.string(from: until)) tarihine kadar bekleyin."
                }
            }
        }
    }

    private func formatInviteCodeInput(_ raw: String) -> String {
        // Strip all dashes, uppercase, limit to 13 chars (3+4+4+2)
        let cleaned = raw.replacingOccurrences(of: "-", with: "")
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        var result = ""
        for (i, char) in cleaned.prefix(13).enumerated() {
            if i == 3 || i == 7 || i == 11 { result += "-" }
            result.append(char)
        }
        return result
    }

    // MARK: Validation
    private func validateEmpStep() -> Bool {
        errorMessage = ""
        switch step {
        case 1:
            guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Ad soyad zorunludur."; return false
            }
            guard isValidEmail(email) else {
                errorMessage = "Geçerli bir e-posta adresi girin."; return false
            }
        default: break
        }
        return true
    }

    // MARK: Register
    private func doEmployeeRegister() {
        errorMessage = ""
        guard password.count >= 6 else {
            errorMessage = "Şifre en az 6 karakter olmalıdır."; return
        }
        guard password == passwordConfirm else {
            errorMessage = "Şifreler eşleşmiyor."; return
        }
        guard let company = foundCompany else { return }

        isCreating = true

        // Fix 1: Email uniqueness kontrolü (authManager.register() atlandığı için burada yapılmalı)
        let userDescriptor = FetchDescriptor<UserAccount>()
        if let existingUsers = try? modelContext.fetch(userDescriptor),
           existingUsers.contains(where: { $0.email.lowercased() == email.lowercased() }) {
            isCreating = false
            errorMessage = "Bu e-posta adresi zaten kayıtlı."
            return
        }

        // Fix 4: Duplicate JoinRequest kontrolü
        let reqDescriptor = FetchDescriptor<JoinRequest>()
        if let existingRequests = try? modelContext.fetch(reqDescriptor) {
            let normalizedEmail = email.lowercased()
            let duplicate = existingRequests.first(where: {
                $0.company?.id == company.id
                && ($0.user?.email.lowercased() == normalizedEmail)
                && ($0.status == .pending || $0.status == .approved)
            })
            if duplicate != nil {
                isCreating = false
                errorMessage = "Bu şirkete zaten bir talebiniz bulunuyor."
                return
            }
            // Reddedilen talep varsa uyar ama devam ettir (confirmationDialog yerine bilgi mesajı)
            let rejected = existingRequests.first(where: {
                $0.company?.id == company.id
                && ($0.user?.email.lowercased() == normalizedEmail)
                && $0.status == .rejected
            })
            if rejected != nil {
                // Önceki red kaydı var — yeni talep oluşturulabilir, mevcut talep geçersiz kalır
            }
        }

        let hash = authManager.hashPassword(password)

        let user = UserAccount(fullName: fullName, email: email, role: selectedRole, passwordHash: hash)
        user.phone = phone.isEmpty ? nil : phone
        user.profilePhotoData = profilePhotoData
        user.professionRaw = selectedProfession.rawValue
        user.accountStatus = .pendingApproval
        user.company = company
        user.companyName = company.companyName

        let joinRequest = JoinRequest(
            user: user,
            company: company,
            requestedRole: selectedRole,
            message: noteToOwner.isEmpty ? nil : noteToOwner
        )

        modelContext.insert(user)
        modelContext.insert(joinRequest)
        do {
            try modelContext.save()
            NotificationManager.shared.scheduleJoinRequestNotification(for: user, company: company)
            isCreating = false
            withAnimation { step = 4 }
        } catch {
            isCreating = false
            errorMessage = "Kayıt sırasında hata oluştu. Tekrar deneyin."
        }
    }
}

// MARK: - Shared Helpers (file-private)

private func progressBar(steps: Int, current: Int) -> some View {
    HStack(spacing: 4) {
        ForEach(0..<steps, id: \.self) { i in
            RoundedRectangle(cornerRadius: 2)
                .fill(i <= current ? Color.hakedisOrange : Color.secondary.opacity(0.3))
                .frame(height: 4)
        }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(Color.hakedisCard)
}

private func navButtons(isLast: Bool, isCreating: Bool, onNext: @escaping () -> Void,
                        nextLabel: String? = nil) -> some View {
    Button(action: onNext) {
        ZStack {
            Text(nextLabel ?? (isLast ? "Hesabı Oluştur" : "Devam"))
                .font(.headline)
                .foregroundColor(.white)
                .opacity(isCreating ? 0 : 1)
            if isCreating { ProgressView().tint(.white) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.hakedisOrange)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .disabled(isCreating)
    .accessibilityLabel(nextLabel ?? (isLast ? "Hesabı oluştur" : "Devam et"))
}

private func formField(_ label: String, _ placeholder: String, _ text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(label).font(.caption).foregroundColor(.secondary)
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled(keyboard == .emailAddress)
            .padding(12)
            .background(Color.hakedisCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel(label)
    }
}

private func errorBanner(_ message: String) -> some View {
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.hakedisDanger)
        Text(message).font(.subheadline).foregroundColor(.hakedisDanger)
    }
    .padding(10)
    .background(Color.hakedisDanger.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}

private func profilePhotoCircle(data: Data?) -> some View {
    ZStack {
        if let data = data, let img = UIImage(data: data) {
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
        Circle().stroke(Color.hakedisOrange, lineWidth: 2).frame(width: 90, height: 90)
    }
}

private func logoPicker(data: Data?) -> some View {
    ZStack {
        if let data = data, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFit()
                .frame(width: 100, height: 60)
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Color.hakedisCard)
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

private func professionPicker(selection: Binding<UserProfession>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text("Meslek").font(.caption).foregroundColor(.secondary)
        Picker("Meslek", selection: selection) {
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
}

private func passwordFields(password: Binding<String>, confirm: Binding<String>,
                             showPassword: Binding<Bool>) -> some View {
    VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
            Text("Şifre *").font(.caption).foregroundColor(.secondary)
            HStack {
                Group {
                    if showPassword.wrappedValue { TextField("••••••", text: password) }
                    else { SecureField("••••••", text: password) }
                }
                Button { showPassword.wrappedValue.toggle() } label: {
                    Image(systemName: showPassword.wrappedValue ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.hakedisCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("Şifre Tekrar *").font(.caption).foregroundColor(.secondary)
            SecureField("••••••", text: confirm)
                .padding(12)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        if !password.wrappedValue.isEmpty {
            passwordStrengthView(password.wrappedValue)
        }
    }
}

private func passwordStrengthView(_ pw: String) -> some View {
    let strength = passwordStrengthInfo(pw)
    return VStack(alignment: .leading, spacing: 6) {
        HStack {
            Text("Şifre Güvenliği:").font(.caption).foregroundColor(.secondary)
            Text(strength.label).font(.caption.bold()).foregroundColor(strength.color)
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

private func passwordStrengthInfo(_ pw: String) -> (label: String, color: Color, fraction: CGFloat) {
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

// MARK: - Email Validation (Fix 7)

private func isValidEmail(_ email: String) -> Bool {
    let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
    return email.range(of: pattern, options: .regularExpression) != nil
}

// MARK: - UserRole shortDescription

private extension UserRole {
    var shortDescription: String {
        switch self {
        case .owner:          return "Tüm modüller, kullanıcı yönetimi, finans"
        case .projectManager: return "Proje yönetimi, hakediş, sözleşme"
        case .siteEngineer:   return "Saha işleri, puantaj, malzeme, kalite kontrol"
        case .safetyOfficer:  return "İSG yönetimi, risk değerlendirme, eğitim"
        case .siteForeman:    return "Günlük giriş, puantaj, ekipman takibi"
        case .accountant:     return "Finans, ödemeler, nakit akış, bütçe"
        case .subcontractor:  return "Taşeron hakedişleri, kendi verileri"
        case .viewer:         return "Yalnızca görüntüleme — düzenleme yapamaz"
        }
    }
}
