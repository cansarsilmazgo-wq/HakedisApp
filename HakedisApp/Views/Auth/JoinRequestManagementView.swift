import SwiftUI
import SwiftData
import PhotosUI

// MARK: - JoinRequestManagementView

struct JoinRequestManagementView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JoinRequest.requestDate, order: .reverse) private var allRequests: [JoinRequest]

    @State private var showRejectSheet = false
    @State private var selectedRequest: JoinRequest? = nil
    @State private var rejectReason = ""

    private var companyId: UUID? { authManager.currentUser?.company?.id }

    private var pendingRequests: [JoinRequest] {
        allRequests.filter { $0.company?.id == companyId && $0.status == .pending }
    }
    private var reviewedRequests: [JoinRequest] {
        allRequests.filter { $0.company?.id == companyId && $0.status != .pending }
    }

    var body: some View {
        List {
            if pendingRequests.isEmpty && reviewedRequests.isEmpty {
                Section {
                    EmptyStateView(
                        icon: "person.badge.clock",
                        title: "Talep Yok",
                        subtitle: "Henüz katılma talebi bulunmuyor."
                    )
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 24)
                }
            }

            if !pendingRequests.isEmpty {
                Section("Bekleyen Talepler (\(pendingRequests.count))") {
                    ForEach(pendingRequests, id: \.id) { request in
                        RequestRow(request: request, isPending: true,
                                   onApprove: { approveRequest(request) },
                                   onReject: { selectedRequest = request; showRejectSheet = true })
                    }
                }
            }

            if !reviewedRequests.isEmpty {
                Section("İncelenen Talepler") {
                    ForEach(reviewedRequests, id: \.id) { request in
                        RequestRow(request: request, isPending: false,
                                   onApprove: nil, onReject: nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Katılma Talepleri")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRejectSheet) {
            rejectSheet
        }
    }

    // MARK: - Reject Sheet

    private var rejectSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let request = selectedRequest, let user = request.user {
                    HStack(spacing: 12) {
                        userAvatar(user: user, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.fullName).font(.headline)
                            Text(request.requestedRole.displayName)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Red Gerekçesi (opsiyonel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    TextEditor(text: $rejectReason)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.hakedisCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                        .accessibilityLabel("Red gerekçesi")
                }

                Button {
                    if let request = selectedRequest {
                        authManager.rejectJoinRequest(request, reason: rejectReason, context: modelContext)
                    }
                    showRejectSheet = false
                    rejectReason = ""
                    selectedRequest = nil
                } label: {
                    Text("Reddet")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.hakedisDanger)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .accessibilityLabel("Talebi reddet")

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Talebi Reddet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        showRejectSheet = false
                        rejectReason = ""
                        selectedRequest = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func approveRequest(_ request: JoinRequest) {
        authManager.approveJoinRequest(request, context: modelContext)
    }
}

// MARK: - RequestRow

private struct RequestRow: View {
    let request: JoinRequest
    let isPending: Bool
    let onApprove: (() -> Void)?
    let onReject: (() -> Void)?

    @State private var selectedRole: UserRole
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.modelContext) private var modelContext

    init(request: JoinRequest, isPending: Bool,
         onApprove: (() -> Void)?, onReject: (() -> Void)?) {
        self.request = request
        self.isPending = isPending
        self.onApprove = onApprove
        self.onReject = onReject
        self._selectedRole = State(initialValue: request.requestedRole)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let user = request.user {
                HStack(spacing: 12) {
                    userAvatar(user: user, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.fullName).font(.subheadline.bold())
                        if let profession = user.profession {
                            Text(profession.displayName)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    StatusBadge(
                        text: request.status.rawValue,
                        color: statusColor(request.status)
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: request.requestedRole.icon)
                        .foregroundColor(.hakedisOrange)
                        .font(.caption)
                    Text("İstenen Rol:").font(.caption).foregroundColor(.secondary)
                    Text(request.requestedRole.displayName).font(.caption.bold())
                }

                if let message = request.message, !message.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "text.bubble").font(.caption).foregroundColor(.secondary)
                        Text(message).font(.caption).foregroundColor(.secondary).lineLimit(3)
                    }
                }

                Text(request.requestDate.shortFormatted)
                    .font(.caption2).foregroundColor(.secondary)
            }

            if isPending {
                VStack(spacing: 8) {
                    // Rol değiştirme
                    HStack(spacing: 8) {
                        Text("Atanacak Rol:").font(.caption).foregroundColor(.secondary)
                        Picker("Rol", selection: $selectedRole) {
                            ForEach(UserRole.allCases, id: \.rawValue) { role in
                                Text(role.displayName).tag(role)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.caption)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if let request = request as? JoinRequest {
                                authManager.approveJoinRequest(request, role: selectedRole,
                                                                context: modelContext)
                            }
                            onApprove?()
                        } label: {
                            Label("Onayla", systemImage: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.hakedisSuccess)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityLabel("Talebi onayla")

                        Button {
                            onReject?()
                        } label: {
                            Label("Reddet", systemImage: "xmark")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.hakedisDanger)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityLabel("Talebi reddet")
                    }
                }
            } else {
                if let reviewer = request.reviewedBy {
                    HStack(spacing: 6) {
                        Image(systemName: "person.checkmark").font(.caption).foregroundColor(.secondary)
                        Text("İnceleyen: \(reviewer)").font(.caption2).foregroundColor(.secondary)
                    }
                }
                if let reason = request.rejectionReason, !reason.isEmpty {
                    Text("Gerekçe: \(reason)")
                        .font(.caption2).foregroundColor(.hakedisDanger).lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: JoinRequestStatus) -> Color {
        switch status {
        case .pending:  return .hakedisWarning
        case .approved: return .hakedisSuccess
        case .rejected: return .hakedisDanger
        }
    }
}

// MARK: - CompanySettingsView

struct CompanySettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var allUsers: [UserAccount]

    @State private var showRegenerateConfirm = false
    @State private var showExpiryPicker = false
    @State private var expiryDate = Date().addingTimeInterval(30 * 24 * 3600)
    @State private var showRemoveMemberConfirm = false
    @State private var memberToRemove: UserAccount? = nil

    private var company: Company? { authManager.currentUser?.company }

    private var members: [UserAccount] {
        guard let company = company else { return [] }
        return allUsers.filter { $0.company?.id == company.id && $0.role != .owner }
    }

    var body: some View {
        List {
            // MARK: Davet Kodu
            Section {
                if let company = company {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mevcut Davet Kodu")
                            .font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            Text(company.inviteCode)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.hakedisOrange)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = company.inviteCode
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.hakedisOrange)
                            }
                            .accessibilityLabel("Kodu kopyala")
                        }
                        .padding(12)
                        .background(Color.hakedisOrange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Toggle("Kodu Aktif Tut", isOn: Binding(
                            get: { company.isInviteCodeActive },
                            set: { company.isInviteCodeActive = $0; try? modelContext.save() }
                        ))
                        .accessibilityLabel("Davet kodunu aktif tut")

                        if !company.isInviteCodeActive {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.hakedisWarning)
                                    .font(.caption)
                                Text("Kod devre dışı — yeni çalışanlar katılamaz.")
                                    .font(.caption)
                                    .foregroundColor(.hakedisWarning)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    ShareLink(item: "HakedişApp davet kodunuz: \(company.inviteCode)") {
                        Label("Kodu Paylaş", systemImage: "square.and.arrow.up")
                            .accessibilityLabel("Kodu paylaş")
                    }

                    Button {
                        showExpiryPicker.toggle()
                    } label: {
                        HStack {
                            Label("Son Kullanma Tarihi", systemImage: "calendar.badge.clock")
                            Spacer()
                            if let exp = company.inviteCodeExpiresAt {
                                Text(exp.shortFormatted)
                                    .font(.caption).foregroundColor(.secondary)
                            } else {
                                Text("Süresiz").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .accessibilityLabel("Son kullanma tarihi ayarla")

                    if showExpiryPicker {
                        DatePicker("Son Kullanma", selection: $expiryDate, displayedComponents: .date)
                            .onChange(of: expiryDate) { _, d in
                                company.inviteCodeExpiresAt = d
                                try? modelContext.save()
                            }
                        Button("Süresiz Yap") {
                            company.inviteCodeExpiresAt = nil
                            try? modelContext.save()
                            showExpiryPicker = false
                        }
                        .foregroundColor(.hakedisDanger)
                    }

                    Button(role: .destructive) {
                        showRegenerateConfirm = true
                    } label: {
                        Label("Yeni Kod Oluştur", systemImage: "arrow.clockwise.circle")
                    }
                    .accessibilityLabel("Yeni davet kodu oluştur")
                }
            } header: {
                Text("Davet Kodu")
            } footer: {
                Text("Yeni kod oluşturursanız eski kod geçersiz olur.")
            }

            // MARK: Şirket Bilgileri
            if let company = company {
                Section("Şirket Bilgileri") {
                    LabeledContent("Şirket Adı", value: company.companyName)
                    if let tax = company.taxNumber { LabeledContent("Vergi No", value: tax) }
                    if let addr = company.address  { LabeledContent("Adres", value: addr) }
                    LabeledContent("Üye Sayısı",   value: "\(members.count + 1) kişi")
                    LabeledContent("Oluşturulma",  value: company.createdAt.shortFormatted)
                }
            }

            // MARK: Üye Listesi
            if !members.isEmpty {
                Section("Üyeler (\(members.count))") {
                    ForEach(members, id: \.id) { member in
                        MemberRow(member: member, onRoleChange: { role in
                            member.role = role
                            try? modelContext.save()
                        }, onRemove: {
                            memberToRemove = member
                            showRemoveMemberConfirm = true
                        })
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Şirket Ayarları")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Yeni Kod Oluştur", isPresented: $showRegenerateConfirm, titleVisibility: .visible) {
            Button("Evet, Yeni Kod Oluştur", role: .destructive) {
                company?.regenerateInviteCode()
                try? modelContext.save()
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Eski davet kodu geçersiz olacak ve yeni çalışanlar eski kodla katılamayacak.")
        }
        .confirmationDialog("Üyeyi Çıkar", isPresented: $showRemoveMemberConfirm, titleVisibility: .visible) {
            Button("Çıkar", role: .destructive) {
                if let member = memberToRemove {
                    member.company = nil
                    member.isActive = false
                    try? modelContext.save()
                }
                memberToRemove = nil
            }
            Button("İptal", role: .cancel) { memberToRemove = nil }
        } message: {
            Text("\(memberToRemove?.fullName ?? "Bu üye") şirketten çıkarılacak.")
        }
    }
}

// MARK: - MemberRow

private struct MemberRow: View {
    let member: UserAccount
    let onRoleChange: (UserRole) -> Void
    let onRemove: () -> Void

    @State private var selectedRole: UserRole

    init(member: UserAccount, onRoleChange: @escaping (UserRole) -> Void, onRemove: @escaping () -> Void) {
        self.member = member
        self.onRoleChange = onRoleChange
        self.onRemove = onRemove
        self._selectedRole = State(initialValue: member.role)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                userAvatar(user: member, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.fullName).font(.subheadline.bold())
                    Text(member.email).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(
                    text: member.accountStatus.rawValue,
                    color: member.accountStatus == .active ? .hakedisSuccess : .hakedisWarning
                )
            }

            HStack(spacing: 8) {
                Text("Rol:").font(.caption).foregroundColor(.secondary)
                Picker("Rol", selection: $selectedRole) {
                    ForEach(UserRole.allCases.filter { $0 != .owner }, id: \.rawValue) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                .onChange(of: selectedRole) { _, r in onRoleChange(r) }
            }

            if let last = member.lastLoginDate {
                Text("Son giriş: \(last.shortFormatted)")
                    .font(.caption2).foregroundColor(.secondary)
            }

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Üyeyi Çıkar", systemImage: "person.badge.minus")
                    .font(.caption)
            }
            .accessibilityLabel("Üyeyi şirketten çıkar")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shared Helper

func userAvatar(user: UserAccount, size: CGFloat) -> some View {
    Group {
        if let data = user.profilePhotoData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.hakedisOrange.opacity(0.15))
                .frame(width: size, height: size)
                .overlay(
                    Text(String(user.fullName.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(.hakedisOrange)
                )
        }
    }
}
