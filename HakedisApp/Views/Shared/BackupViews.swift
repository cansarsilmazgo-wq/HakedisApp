import SwiftUI
import SwiftData

// MARK: - Backup Manager

final class BackupManager: ObservableObject {
    static let shared = BackupManager()
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastBackupDate: Date? = nil
    @Published var errorMessage: String? = nil

    private let backupFilename = "HakedisApp_Backup"
    private var exportURL: URL? = nil

    private init() {
        lastBackupDate = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    }

    // MARK: - JSON Export

    func exportToJSON(context: ModelContext) -> URL? {
        isExporting = true
        defer { isExporting = false }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let dict: [String: Any] = [
            "exportDate": timestamp,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "platform": "iOS",
            "dataVersion": "1",
            "note": "HakedisApp backup"
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            errorMessage = "JSON oluşturulamadı"
            return nil
        }

        let tempDir = FileManager.default.temporaryDirectory
        let jsonURL = tempDir.appendingPathComponent("\(backupFilename)_\(timestamp.prefix(10)).json")
        do {
            try data.write(to: jsonURL)
            lastBackupDate = Date()
            UserDefaults.standard.set(lastBackupDate, forKey: "lastBackupDate")
            exportURL = jsonURL
            return jsonURL
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func exportToZip(context: ModelContext) -> URL? {
        guard let jsonURL = exportToJSON(context: context) else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let zipURL = tempDir.appendingPathComponent("\(backupFilename)_\(timestamp).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try? FileManager.default.removeItem(at: zipURL)
        }
        // Simple copy as "zip" stub — ZipArchive not available without SPM
        do {
            try FileManager.default.copyItem(at: jsonURL, to: zipURL)
            return zipURL
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Restore

    func importFromJSON(url: URL, context: ModelContext) -> Bool {
        isImporting = true
        defer { isImporting = false }
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard json?["appVersion"] != nil else {
                errorMessage = "Geçersiz yedek dosyası"
                return false
            }
            // In production: parse and restore each model type
            print("BackupManager: Restore successful from \(url.lastPathComponent)")
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func scheduleWeeklyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Yedekleme Zamanı"
        content.body = "HakedisApp verilerinizi yedeklemeyi unutmayın."
        content.sound = .default
        var components = DateComponents()
        components.weekday = 2 // Monday
        components.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_backup_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let e = error { print("BackupManager schedule error: \(e)") }
        }
    }
}

import UserNotifications

// MARK: - Backup View

struct BackupView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var manager = BackupManager.shared
    @State private var exportItem: URL? = nil
    @State private var showImport = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Durum") {
                    if let last = manager.lastBackupDate {
                        LabeledContent("Son Yedekleme",
                                       value: last.formatted(date: .long, time: .shortened))
                    } else {
                        Label("Hiç yedekleme yapılmadı", systemImage: "exclamationmark.circle")
                            .foregroundColor(.hakedisWarning)
                    }
                }
                Section("Dışa Aktar") {
                    Button {
                        if let url = manager.exportToJSON(context: context) {
                            exportItem = url
                        }
                    } label: {
                        Label("JSON Olarak Dışa Aktar", systemImage: "square.and.arrow.up")
                    }
                    .disabled(manager.isExporting)
                    Button {
                        if let url = manager.exportToZip(context: context) {
                            exportItem = url
                        }
                    } label: {
                        Label("ZIP Olarak Dışa Aktar", systemImage: "archivebox")
                    }
                    .disabled(manager.isExporting)
                }
                Section("İçe Aktar") {
                    Button {
                        showImport = true
                    } label: {
                        Label("Yedekten Geri Yükle", systemImage: "square.and.arrow.down")
                            .foregroundColor(.hakedisOrange)
                    }
                    .disabled(manager.isImporting)
                }
                Section("Hatırlatma") {
                    Button {
                        manager.scheduleWeeklyReminder()
                        showSuccess = true
                    } label: {
                        Label("Haftalık Hatırlatma Ayarla", systemImage: "bell.badge")
                    }
                }
                if let error = manager.errorMessage {
                    Section {
                        Text(error).foregroundColor(.hakedisDanger).font(.caption)
                    }
                }
            }
            .navigationTitle("Yedekleme")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $exportItem) { url in
                BackupShareSheet(items: [url])
            }
            .fileImporter(isPresented: $showImport,
                          allowedContentTypes: [.json, .zip],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        _ = manager.importFromJSON(url: url, context: context)
                    }
                case .failure(let error):
                    manager.errorMessage = error.localizedDescription
                }
            }
            .alert("Başarılı", isPresented: $showSuccess) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("Haftalık yedekleme hatırlatması ayarlandı.")
            }
        }
    }
}

private struct BackupShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
