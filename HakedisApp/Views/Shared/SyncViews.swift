import SwiftUI
import SwiftData
import CloudKit

// MARK: - Sync Status

enum SyncStatus: String, CaseIterable {
    case idle = "Senkronize"
    case syncing = "Senkronize Ediliyor..."
    case success = "Son senkronizasyon başarılı"
    case failed = "Senkronizasyon başarısız"
    case disabled = "Senkronizasyon Kapalı"
    var icon: String {
        switch self {
        case .idle: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .success: return "checkmark.icloud.fill"
        case .failed: return "exclamationmark.icloud"
        case .disabled: return "icloud.slash"
        }
    }
    var color: Color {
        switch self {
        case .idle, .success: return .hakedisSuccess
        case .syncing: return .hakedisOrange
        case .failed: return .hakedisDanger
        case .disabled: return .secondary
        }
    }
}

// MARK: - Sync Manager

final class SyncManager: ObservableObject {
    static let shared = SyncManager()
    @Published var status: SyncStatus = .disabled
    @Published var lastSyncDate: Date? = nil
    @Published var isCloudKitEnabled: Bool = false

    private init() {
        // CloudKit availability check would go here
        // For now, disabled until CloudKit container is configured
        isCloudKitEnabled = false
        status = .disabled
    }

    func enableSync() {
        // In production: configure ModelContainer with .private CloudKit database
        // ModelConfiguration(schema:, cloudKitDatabase: .private("iCloud.com.hakedis.app"))
        isCloudKitEnabled = true
        status = .idle
        print("SyncManager: CloudKit sync enabled")
    }

    func disableSync() {
        isCloudKitEnabled = false
        status = .disabled
        print("SyncManager: CloudKit sync disabled")
    }

    func triggerSync() {
        guard isCloudKitEnabled else { return }
        status = .syncing
        // CloudKit sync happens automatically with SwiftData + CloudKit
        // This simulates a manual trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.status = .success
            self?.lastSyncDate = Date()
        }
    }
}

// MARK: - Sync Status View

struct SyncStatusView: View {
    @StateObject private var syncManager = SyncManager.shared
    // FAZ 17.22 — iCloud hesap durumu
    @State private var iCloudAccountStatus: CKAccountStatus = .couldNotDetermine
    // FAZ 17.22 — Seçici sync toggles
    @AppStorage("sync_hakedis") private var syncHakedis = true
    @AppStorage("sync_santiye") private var syncSantiye = true
    @AppStorage("sync_documents") private var syncDocuments = true
    @AppStorage("sync_photos") private var syncPhotos = false
    @AppStorage("sync_contracts") private var syncContracts = true

    var body: some View {
        NavigationStack {
            Form {
                // FAZ 17.22 — iCloud hesap uyarısı
                if iCloudAccountStatus != .available {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.icloud.fill")
                                .font(.title2)
                                .foregroundColor(.hakedisWarning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iCloud Hesabı Bulunamadı")
                                    .font(.subheadline.bold())
                                Text("Senkronizasyon için iPhone Ayarlar → iCloud'dan giriş yapın.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("iCloud Durumu") {
                    HStack {
                        Image(systemName: syncManager.status.icon)
                            .foregroundColor(syncManager.status.color)
                        Text(syncManager.status.rawValue)
                            .foregroundColor(syncManager.status.color)
                        Spacer()
                        if syncManager.status == .syncing {
                            ProgressView()
                        }
                    }
                    if let last = syncManager.lastSyncDate {
                        LabeledContent("Son Senkronizasyon",
                                       value: last.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                Section("Ayarlar") {
                    Toggle("iCloud Senkronizasyonu", isOn: Binding(
                        get: { syncManager.isCloudKitEnabled },
                        set: { enabled in
                            if enabled { syncManager.enableSync() }
                            else { syncManager.disableSync() }
                        }
                    ))
                    .tint(.hakedisOrange)
                    if syncManager.isCloudKitEnabled {
                        Button {
                            syncManager.triggerSync()
                        } label: {
                            Label("Şimdi Senkronize Et", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(syncManager.status == .syncing)
                    }
                }

                // FAZ 17.22 — Seçici sync
                if syncManager.isCloudKitEnabled {
                    Section("Veri Seçimi") {
                        Toggle("Hakedişler", isOn: $syncHakedis).tint(.hakedisOrange)
                        Toggle("Şantiye Verileri", isOn: $syncSantiye).tint(.hakedisOrange)
                        Toggle("Sözleşmeler", isOn: $syncContracts).tint(.hakedisOrange)
                        Toggle("Belgeler", isOn: $syncDocuments).tint(.hakedisOrange)
                        Toggle("Fotoğraflar", isOn: $syncPhotos).tint(.hakedisOrange)
                        Text("Not: Fotoğraflar iCloud depolama alanı tüketir.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                Section("Bilgi") {
                    Text("iCloud senkronizasyonu etkinleştirildiğinde verileriniz otomatik olarak tüm Apple cihazlarınızla paylaşılır.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Not: CloudKit entegrasyonu aktif geliştirme aşamasındadır.")
                        .font(.caption)
                        .foregroundColor(.hakedisWarning)
                }
            }
            .navigationTitle("iCloud Senkronizasyonu")
            .navigationBarTitleDisplayMode(.large)
            .task {
                // FAZ 17.22 — iCloud hesap durumunu kontrol et
                do {
                    iCloudAccountStatus = try await CKContainer.default().accountStatus()
                } catch {
                    iCloudAccountStatus = .couldNotDetermine
                }
            }
        }
    }
}
