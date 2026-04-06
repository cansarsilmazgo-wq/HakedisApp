import SwiftUI
import SwiftData

struct UserManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserAccount.createdAt, order: .forward) private var users: [UserAccount]
    @StateObject private var authManager = AuthManager.shared
    @State private var showAddUser = false
    @State private var userToDelete: UserAccount? = nil
    @Query private var projects: [Project]

    var body: some View {
        List {
            if users.isEmpty {
                EmptyStateView(icon: "person.2", title: "Kullanıcı yok",
                               subtitle: "Yeni kullanıcı ekleyerek başlayın",
                               actionTitle: "Kullanıcı Ekle", action: { showAddUser = true })
            } else {
                ForEach(users, id: \.id) { user in
                    NavigationLink(destination: UserDetailEditView(user: user, projects: projects)) {
                        UserRow(user: user)
                    }
                }
                .onDelete { offsets in
                    if let idx = offsets.first { userToDelete = users[idx] }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Kullanıcı Yönetimi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddUser = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Yeni kullanıcı ekle")
            }
        }
        .sheet(isPresented: $showAddUser) { AddUserView() }
        .confirmationDialog(
            userToDelete != nil ? "\(userToDelete!.fullName) silinsin mi?" : "",
            isPresented: Binding(get: { userToDelete != nil }, set: { if !$0 { userToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Kullanıcıyı Sil", role: .destructive) {
                if let u = userToDelete { modelContext.delete(u) }
                userToDelete = nil
            }
            Button("İptal", role: .cancel) { userToDelete = nil }
        }
    }
}

private struct UserRow: View {
    let user: UserAccount
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.hakedisOrange.opacity(0.15)).frame(width: 44, height: 44)
                if let data = user.profilePhotoData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 44, height: 44).clipShape(Circle())
                } else {
                    Image(systemName: user.role.icon).foregroundColor(.hakedisOrange)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(user.fullName).font(.subheadline.bold())
                    if !user.isActive {
                        Text("Pasif").font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Text(user.role.displayName).font(.caption).foregroundColor(.hakedisOrange)
                Text(user.email).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if let last = user.lastLoginDate {
                Text(last.shortFormatted).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.fullName), \(user.role.displayName)")
    }
}

struct UserDetailEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: UserAccount
    let projects: [Project]
    @State private var showToast = false

    var body: some View {
        List {
            Section("Temel Bilgiler") {
                LabeledContent("Ad Soyad", value: user.fullName)
                LabeledContent("E-posta", value: user.email)
            }
            Section("Rol") {
                Picker("Rol", selection: Binding(
                    get: { user.role },
                    set: { user.role = $0 }
                )) {
                    ForEach(UserRole.allCases, id: \.rawValue) { r in
                        Label(r.displayName, systemImage: r.icon).tag(r)
                    }
                }
                .accessibilityLabel("Rol seç")
            }
            Section("Durum") {
                Toggle("Aktif Kullanıcı", isOn: $user.isActive)
                    .accessibilityLabel("Kullanıcı aktif mi")
            }
            Section("Proje Erişimi") {
                if user.role.canSeeAllProjects {
                    Text("Bu rol tüm projeleri görebilir")
                        .font(.subheadline).foregroundColor(.secondary)
                } else {
                    ForEach(projects, id: \.id) { project in
                        Toggle(project.name, isOn: Binding(
                            get: { user.assignedProjectIds.contains(project.id) },
                            set: { assigned in
                                if assigned {
                                    if !user.assignedProjectIds.contains(project.id) {
                                        user.assignedProjectIds.append(project.id)
                                    }
                                } else {
                                    user.assignedProjectIds.removeAll { $0 == project.id }
                                }
                            }
                        ))
                        .accessibilityLabel("\(project.name) erişimi")
                    }
                }
            }
            Section {
                Button("Değişiklikleri Kaydet") { saveChanges() }
                    .foregroundColor(.hakedisOrange)
                    .accessibilityLabel("Değişiklikleri kaydet")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toast(isPresented: $showToast, message: "Kullanıcı güncellendi")
    }

    private func saveChanges() {
        do {
            try modelContext.save()
            withAnimation { showToast = true }
        } catch {
            // silent — toast not shown on failure
        }
    }
}

struct AddUserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @State private var fullName = ""
    @State private var email = ""
    @State private var selectedRole: UserRole = .siteEngineer
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Kişisel Bilgiler") {
                    TextField("Ad Soyad", text: $fullName)
                        .accessibilityLabel("Ad soyad")
                    TextField("E-posta", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .accessibilityLabel("E-posta")
                }
                Section("Rol") {
                    Picker("Rol", selection: $selectedRole) {
                        ForEach(UserRole.allCases, id: \.rawValue) { r in
                            Label(r.displayName, systemImage: r.icon).tag(r)
                        }
                    }
                    .accessibilityLabel("Rol seç")
                }
                Section("Şifre") {
                    SecureField("Geçici şifre (min 6 karakter)", text: $password)
                        .accessibilityLabel("Şifre")
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.hakedisDanger)
                    }
                }
            }
            .navigationTitle("Yeni Kullanıcı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { addUser() }
                        .disabled(fullName.isEmpty || email.isEmpty || password.count < 6)
                }
            }
        }
    }

    private func addUser() {
        let hash = authManager.hashPassword(password)
        let user = UserAccount(fullName: fullName, email: email, role: selectedRole, passwordHash: hash)
        let success = authManager.register(user: user, context: modelContext)
        if success { dismiss() } else { errorMessage = "Bu e-posta zaten kayıtlı." }
    }
}
