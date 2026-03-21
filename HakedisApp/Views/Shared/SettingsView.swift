import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Uygulama") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Bildirim Ayarları", systemImage: "bell")
                    }
                    NavigationLink(destination: OfflineSyncSettingsView()) {
                        Label("Çevrimdışı & Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink(destination: ContractorPortalView()) {
                        Label("Taşeron Portalı", systemImage: "person.badge.shield.checkmark")
                    }
                }
                Section("Hakkında") {
                    LabeledContent("Versiyon", value: "1.0.0")
                    LabeledContent("Platform", value: "iOS 17+")
                    LabeledContent("Teknoloji", value: "SwiftUI + SwiftData")
                }
            }
            .navigationTitle("Ayarlar")
        }
    }
}
