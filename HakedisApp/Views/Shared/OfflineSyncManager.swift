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
    @StateObject private var monitor = NetworkMonitor.shared

    var body: some View {
        Form {
            Section("Bağlantı Durumu") {
                HStack {
                    Image(systemName: monitor.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(monitor.isConnected ? .hakedisSuccess : .hakedisDanger)
                    Text(monitor.isConnected ? "Bağlı" : "Çevrimdışı")
                    Spacer()
                    if monitor.isConnected {
                        Text(monitor.connectionType == .wifi ? "Wi-Fi" : "Mobil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                InfoRow(icon: "arrow.triangle.2.circlepath", color: .blue,
                    title: "iCloud Sync", subtitle: "Yakında eklenecek")
            }
        }
        .navigationTitle("Çevrimdışı & Sync")
        .navigationBarTitleDisplayMode(.inline)
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
