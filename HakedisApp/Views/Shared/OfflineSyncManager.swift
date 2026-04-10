import SwiftUI
import Network

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

    @State private var cacheSize: String = "—"

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

            Section("Veri Saklama") {
                InfoRow(icon: "checkmark.circle.fill", color: .hakedisSuccess,
                    title: "Yerel Depolama",
                    subtitle: "Veriler yerel olarak saklanır. iCloud sync gelecek sürümde eklenecektir.")
                InfoRow(icon: "internaldrive.fill", color: .hakedisOrange,
                    title: "SwiftData", subtitle: "Tüm veriler cihazda saklanır")
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
                InfoRow(icon: "checkmark.circle.fill", color: .hakedisSuccess,
                    title: "Hakediş oluşturma", subtitle: "Offline çalışır, sync sonra yapılır")
                InfoRow(icon: "checkmark.circle.fill", color: .hakedisSuccess,
                    title: "PDF paylaşma", subtitle: "Yerel olarak çalışır")
            }
        }
        .navigationTitle("Çevrimdışı & Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateCacheSize()
        }
    }

    private func calculateCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            // Geçici klasör boyutu
            let tmp = FileManager.default.temporaryDirectory
            let tmpSize = (try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: [.fileSizeKey])
                .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
                .reduce(0, +)) ?? 0

            // SwiftData store dosya boyutu
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
            let storeURL = appSupport.appendingPathComponent("hakedis.store")
            var storeSize = 0
            for suffix in ["", "-shm", "-wal"] {
                let url = URL(fileURLWithPath: storeURL.path + suffix)
                storeSize += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            }

            let total = tmpSize + storeSize
            let mb = Double(total) / 1_048_576
            DispatchQueue.main.async {
                cacheSize = mb < 1 ? "\(max(total / 1024, 1)) KB" : String(format: "%.1f MB", mb)
            }
        }
    }

    private func clearCache() {
        let tmp = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        cacheSize = "0 KB"
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
