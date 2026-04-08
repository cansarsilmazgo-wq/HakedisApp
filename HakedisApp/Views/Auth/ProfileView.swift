import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authManager = AuthManager.shared
    @State private var showChangePassword = false
    @State private var showLogoutConfirm = false
    @State private var profileItem: PhotosPickerItem? = nil

    var body: some View {
        List {
            if let user = authManager.currentUser {
                // Header
                Section {
                    HStack(spacing: 16) {
                        profilePhoto(user: user)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.fullName).font(.headline)
                            Text(user.email).font(.subheadline).foregroundColor(.secondary)
                            Label(user.role.displayName, systemImage: user.role.icon)
                                .font(.caption)
                                .foregroundColor(.hakedisOrange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Kişisel Bilgiler") {
                    LabeledContent("Ad Soyad", value: user.fullName)
                    if !user.title.isEmpty {
                        LabeledContent("Unvan", value: user.title)
                    }
                    LabeledContent("E-posta", value: user.email)
                    if let phone = user.phone { LabeledContent("Telefon", value: phone) }
                    if let prof = user.profession {
                        LabeledContent("Meslek", value: prof.displayName)
                    }
                    if let reg = user.registrationNumber {
                        LabeledContent("Oda Sicil No", value: reg)
                    }
                }

                if let company = user.companyName {
                    Section("Firma Bilgileri") {
                        LabeledContent("Firma Adı", value: company)
                    }
                }

                Section("Hesap") {
                    LabeledContent("Rol", value: user.role.displayName)
                    if let last = user.lastLoginDate {
                        LabeledContent("Son Giriş", value: last.shortFormatted)
                    }
                    Button("Şifre Değiştir") { showChangePassword = true }
                        .foregroundColor(.hakedisOrange)
                        .accessibilityLabel("Şifre değiştir")
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Çıkış yap")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profilim")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: profileItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    authManager.currentUser?.profilePhotoData = data
                    do { try modelContext.save() } catch { }
                }
            }
        }
        .sheet(isPresented: $showChangePassword) {
            if let user = authManager.currentUser {
                ChangePasswordView(user: user)
            }
        }
        .confirmationDialog("Çıkış yapmak istediğinize emin misiniz?",
                            isPresented: $showLogoutConfirm,
                            titleVisibility: .visible) {
            Button("Çıkış Yap", role: .destructive) { authManager.logout() }
            Button("İptal", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func profilePhoto(user: UserAccount) -> some View {
        if let data = user.profilePhotoData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: 60, height: 60).clipShape(Circle())
        } else {
            Circle()
                .fill(Color.hakedisOrange.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(Image(systemName: "person.fill").foregroundColor(.hakedisOrange))
        }
    }
}

// MARK: - ChangePasswordView

struct ChangePasswordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    let user: UserAccount
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Mevcut Şifre") {
                    SecureField("Mevcut şifreniz", text: $oldPassword)
                        .accessibilityLabel("Mevcut şifre")
                }
                Section("Yeni Şifre") {
                    SecureField("Yeni şifre (min 6 karakter)", text: $newPassword)
                        .accessibilityLabel("Yeni şifre")
                    SecureField("Şifre tekrar", text: $confirmPassword)
                        .accessibilityLabel("Şifre tekrar")
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.hakedisDanger).font(.subheadline)
                    }
                }
            }
            .navigationTitle("Şifre Değiştir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { doChange() }
                        .disabled(oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
            .alert("Başarılı", isPresented: $showSuccess) {
                Button("Tamam") { dismiss() }
            } message: {
                Text("Şifreniz başarıyla değiştirildi.")
            }
        }
    }

    private func doChange() {
        errorMessage = ""
        guard newPassword.count >= 6 else { errorMessage = "Şifre en az 6 karakter olmalıdır."; return }
        guard newPassword == confirmPassword else { errorMessage = "Şifreler eşleşmiyor."; return }
        if authManager.changePassword(user: user, oldPassword: oldPassword, newPassword: newPassword, context: modelContext) {
            showSuccess = true
        } else {
            errorMessage = "Mevcut şifre hatalı."
        }
    }
}
