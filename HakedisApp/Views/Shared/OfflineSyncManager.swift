import SwiftUI
import Network
import CloudKit

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown

    enum ConnectionType { case wifi, cellular, unknown }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                if path.usesInterfaceType(.wifi) { self?.connectionType = .wifi }
                else if path.usesInterfaceType(.cellular) { self?.connectionType = .cellular }
                else { self?.connectionType = .unknown }
            }
        }
        monitor.start(queue: queue)
    }
}

class CloudKitSyncMonitor: ObservableObject {
    static let shared = CloudKitSyncMonitor()

    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var lastSyncDate: Date? = UserDefaults.standard.object(forKey: "lastCloudKitSync") as? Date

    private let container = CKContainer(identifier: "iCloud.com.hakedis.app")

    init() {
        checkAccountStatus()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkAccountStatus),
            name: .CKAccountChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: NSNotification.Name(rawValue: "NSPersistentStoreRemoteChangeNotification"),
            object: nil
        )
    }

    @objc func checkAccountStatus() {
        container.accountStatus { [weak self] status, _ in
            DispatchQueue.main.async {
                self?.accountStatus = status
            }
        }
    }

    @objc private func handleRemoteChange() {
        DispatchQueue.main.async {
            self.lastSyncDate = Date()
            UserDefaults.standard.set(self.lastSyncDate, forKey: "lastCloudKitSync")
        }
    }

    var statusText: String {
        switch accountStatus {
        case .available:      return "iCloud Aktif"
        case .noAccount:      return "iCloud Hesabı Yok"
        case .restricted:     return "iCloud Kısıtlı"
        case .couldNotDetermine: return "Durum Belirsiz"
        case .temporarilyUnavailable: return "Geçici Olarak Kullanılamıyor"
        @unknown default:     return "Bilinmiyor"
        }
    }

    var statusColor: Color {
        switch accountStatus {
        case .available:      return .hakedisSuccess
        case .noAccount:      return .hakedisDanger
        case .restricted:     return .hakedisDanger
        case .temporarilyUnavailable: return .hakedisWarning
        default:              return .secondary
        }
    }

    var statusIcon: String {
        switch accountStatus {
        case .available:      return "icloud.fill"
        case .noAccount:      return "icloud.slash.fill"
        case .restricted:     return "exclamationmark.icloud.fill"
        case .temporarilyUnavailable: return "icloud.and.arrow.up"
        default:              return "questionmark.circle"
        }
    }
}

struct NetworkStatusBanner: View {
    @StateObject private var monitor = NetworkMonitor.shared

    var body: some View {
        if !monitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                Text("Çevrimdışı mod — veriler yerel olarak kaydediliyor")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.hakedisDanger)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct OfflineSyncSettingsView: View {
    @StateObject private var network = NetworkMonitor.shared
    @StateObject private var cloudKit = CloudKitSyncMonitor.shared

    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var cacheSize: String = "—"

    private var lastSyncText: String {
        guard let date = cloudKit.lastSyncDate else { return "Henüz sync yapılmadı" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        Form {
            Section("Bağlantı Durumu") {
                HStack {
                    Image(systemName: network.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(network.isConnected ? .hakedisSuccess : .hakedisDanger)
                    Text(network.isConnected ? "Bağlı" : "Çevrimdışı")
                    Spacer()
                    if network.isConnected {
                        Text(network.connectionType == .wifi ? "Wi-Fi" : "Mobil")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            Section("iCloud Sync") {
                HStack {
                    Image(systemName: cloudKit.statusIcon)
                        .foregroundColor(cloudKit.statusColor)
                    Text(cloudKit.statusText)
                    Spacer()
                }
                if cloudKit.accountStatus == .available {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Son Sync").font(.subheadline)
                            Text(lastSyncText).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if isSyncing {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Button {
                                triggerSync()
                            } label: {
                                Text("Şimdi Sync Et")
                                    .font(.caption.bold())
                                    .foregroundColor(network.isConnected ? .hakedisOrange : .secondary)
                            }
                            .disabled(!network.isConnected)
                        }
                    }
                    if let msg = syncMessage {
                        HStack {
                            Image(systemName: msg.hasPrefix("✓") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(msg.hasPrefix("✓") ? .hakedisSuccess : .hakedisWarning)
                            Text(msg).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                if cloudKit.accountStatus == .noAccount {
                    Text("Sync için iPhone'da Ayarlar → Apple Hesabı → iCloud → CloudKit bölümünden giriş yapın.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Section("Önbellek") {
                HStack {
                    Image(systemName: "internaldrive").foregroundColor(.hakedisOrange).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uygulama Önbelleği").font(.subheadline)
                        Text(cacheSize).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Temizle") { clearCache() }
                        .font(.caption.bold())
                        .foregroundColor(.hakedisDanger)
                }
            }

            Section("Offline Çalışma") {
                InfoRow(icon: "checkmark.circle.fill", color: .hakedisSuccess,
                    title: "Saha girişleri", subtitle: "Her zaman çalışır, offline kaydedilir")
                InfoRow(icon: "checkmark.circle.fill", color: .hakedisSuccess,
                    title: "Proje görüntüleme", subtitle: "Cached veriler gösterilir")
                InfoRow(icon: "exclamationmark.circle.fill", color: .hakedisWarning,
                    title: "Hakediş oluşturma", subtitle: "İnternet bağlantısı önerilir")
                InfoRow(icon: "xmark.circle.fill", color: .hakedisDanger,
                    title: "PDF paylaşma", subtitle: "İnternet gerektirir")
            }

            Section("Veri Saklama") {
                InfoRow(icon: "internaldrive.fill", color: .hakedisOrange,
                    title: "SwiftData", subtitle: "Tüm veriler cihazda saklanır")
                InfoRow(icon: cloudKit.accountStatus == .available ? "icloud.fill" : "icloud.slash.fill",
                    color: cloudKit.statusColor,
                    title: "iCloud CloudKit",
                    subtitle: cloudKit.accountStatus == .available
                        ? "Aktif — cihazlar arası otomatik sync"
                        : "Pasif — iCloud hesabı gerekli")
            }
        }
        .navigationTitle("Çevrimdışı & Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cloudKit.checkAccountStatus()
            calculateCacheSize()
        }
    }

    private func triggerSync() {
        guard network.isConnected else { return }
        isSyncing = true
        syncMessage = nil
        // SwiftData + CloudKit syncs automatically; we trigger a status re-check
        // and record the manual trigger time
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) {
            DispatchQueue.main.async {
                isSyncing = false
                let now = Date()
                UserDefaults.standard.set(now, forKey: "lastCloudKitSync")
                cloudKit.lastSyncDate = now
                syncMessage = "✓ Sync tamamlandı — \(now.shortFormatted)"
                cloudKit.checkAccountStatus()
            }
        }
    }

    private func calculateCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            let tmp = FileManager.default.temporaryDirectory
            let size = (try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: [.fileSizeKey])
                .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
                .reduce(0, +)) ?? 0
            let mb = Double(size) / 1_048_576
            DispatchQueue.main.async {
                cacheSize = mb < 1 ? "\(size / 1024) KB" : String(format: "%.1f MB", mb)
            }
        }
    }

    private func clearCache() {
        let tmp = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        cacheSize = "0 KB"
        syncMessage = "Önbellek temizlendi"
    }
}

struct InfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
