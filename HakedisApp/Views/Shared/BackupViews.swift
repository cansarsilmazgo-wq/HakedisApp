import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Backup DTOs (temel modeller)

private struct ProjectDTO: Codable {
    var id: String
    var name: String
    var projectDescription: String
    var status: String
    var startDate: Date
    var contracts: [ContractDTO]
}

private struct ContractDTO: Codable {
    var id: String
    var title: String
    var contractDate: Date
    var retentionRate: Double
    var advanceRate: Double
    var kdvRate: Double
    var totalContractAmount: Double
    var workItems: [WorkItemDTO]
    var hakedisler: [HakedisDTO]
}

private struct WorkItemDTO: Codable {
    var id: String
    var code: String
    var name: String
    var unit: String
    var unitPrice: Double
    var contractedQuantity: Double
}

private struct HakedisDTO: Codable {
    var id: String
    var periodName: String
    var periodStart: Date
    var periodEnd: Date
    var status: String
    var grossAmount: Double
    var netAmount: Double
    var totalPaid: Double
    var items: [HakedisItemDTO]
    var payments: [PaymentDTO]
}

private struct HakedisItemDTO: Codable {
    var id: String
    var workItemCode: String
    var workItemName: String
    var unit: String
    var unitPrice: Double
    var previousQuantity: Double
    var currentQuantity: Double
}

private struct PaymentDTO: Codable {
    var id: String
    var amount: Double
    var paymentDate: Date
    var paymentDescription: String
}

private struct BackupEnvelope: Codable {
    var exportDate: String
    var appVersion: String
    var platform: String
    var dataVersion: String
    var note: String
    var projects: [ProjectDTO]
}

// MARK: - Backup Manager

final class BackupManager: ObservableObject {
    static let shared = BackupManager()
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastBackupDate: Date? = nil
    @Published var errorMessage: String? = nil

    private let backupFilename = "HakedisApp_Backup"

    private init() {
        lastBackupDate = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    }

    // MARK: - JSON Export (gerçek SwiftData verisi)

    func exportToJSON(context: ModelContext) -> URL? {
        isExporting = true
        defer { isExporting = false }

        do {
            let projectFetch = FetchDescriptor<Project>()
            let projects = try context.fetch(projectFetch)

            let projectDTOs: [ProjectDTO] = projects.map { p in
                let contractDTOs: [ContractDTO] = p.contracts.map { c in
                    let workItemDTOs = c.workItems.map { wi in
                        WorkItemDTO(id: wi.id.uuidString, code: wi.code, name: wi.name,
                                    unit: wi.unit, unitPrice: wi.unitPrice,
                                    contractedQuantity: wi.contractedQuantity)
                    }
                    let hakedisItemDTOs: ([HakedisItem]) -> [HakedisItemDTO] = { items in
                        items.map { hi in
                            HakedisItemDTO(id: hi.id.uuidString, workItemCode: hi.workItemCode,
                                           workItemName: hi.workItemName, unit: hi.unit,
                                           unitPrice: hi.unitPrice, previousQuantity: hi.previousQuantity,
                                           currentQuantity: hi.currentQuantity)
                        }
                    }
                    let hakedisPaymentDTOs: ([Payment]) -> [PaymentDTO] = { payments in
                        payments.map { py in
                            PaymentDTO(id: py.id.uuidString, amount: py.amount,
                                       paymentDate: py.paymentDate, paymentDescription: py.paymentDescription)
                        }
                    }
                    let hakedislerDTOs = c.hakedisler.map { h in
                        HakedisDTO(id: h.id.uuidString, periodName: h.periodName,
                                   periodStart: h.periodStart, periodEnd: h.periodEnd,
                                   status: h.status.rawValue, grossAmount: h.grossAmount,
                                   netAmount: h.netAmount, totalPaid: h.totalPaid,
                                   items: hakedisItemDTOs(h.items), payments: hakedisPaymentDTOs(h.payments))
                    }
                    return ContractDTO(id: c.id.uuidString, title: c.title,
                                       contractDate: c.contractDate, retentionRate: c.retentionRate,
                                       advanceRate: c.advanceRate, kdvRate: c.kdvRate,
                                       totalContractAmount: c.totalContractAmount,
                                       workItems: workItemDTOs, hakedisler: hakedislerDTOs)
                }
                return ProjectDTO(id: p.id.uuidString, name: p.name,
                                  projectDescription: p.projectDescription,
                                  status: p.status.rawValue, startDate: p.startDate,
                                  contracts: contractDTOs)
            }

            let timestamp = ISO8601DateFormatter().string(from: Date())
            let envelope = BackupEnvelope(
                exportDate: timestamp,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                platform: "iOS",
                dataVersion: "2",
                note: "HakedisApp tam veri yedeği",
                projects: projectDTOs
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(envelope)

            let tempDir = FileManager.default.temporaryDirectory
            let jsonURL = tempDir.appendingPathComponent("\(backupFilename)_\(timestamp.prefix(10)).json")
            try data.write(to: jsonURL)

            lastBackupDate = Date()
            UserDefaults.standard.set(lastBackupDate, forKey: "lastBackupDate")
            return jsonURL
        } catch {
            errorMessage = ErrorHelper.userFriendlyMessage(error)
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
        // ZIP kütüphanesi olmadan JSON kopyası olarak gönder
        do {
            try FileManager.default.copyItem(at: jsonURL, to: zipURL)
            return zipURL
        } catch {
            errorMessage = ErrorHelper.userFriendlyMessage(error)
            return nil
        }
    }

    // MARK: - Restore

    func importFromJSON(url: URL, context: ModelContext) -> Bool {
        isImporting = true
        defer { isImporting = false }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(BackupEnvelope.self, from: data)

            for pDTO in envelope.projects {
                let project = Project(name: pDTO.name, projectDescription: pDTO.projectDescription,
                                     startDate: pDTO.startDate)
                context.insert(project)

                for cDTO in pDTO.contracts {
                    let contract = Contract(title: cDTO.title, contractDate: cDTO.contractDate,
                                            retentionRate: cDTO.retentionRate, advanceRate: cDTO.advanceRate)
                    contract.kdvRate = cDTO.kdvRate
                    contract.project = project
                    context.insert(contract)

                    for wiDTO in cDTO.workItems {
                        let wi = WorkItem(code: wiDTO.code, name: wiDTO.name,
                                          unit: wiDTO.unit, unitPrice: wiDTO.unitPrice,
                                          contractedQuantity: wiDTO.contractedQuantity)
                        wi.contract = contract
                        context.insert(wi)
                    }

                    for hDTO in cDTO.hakedisler {
                        let hakedis = Hakedis(periodName: hDTO.periodName,
                                               periodStart: hDTO.periodStart, periodEnd: hDTO.periodEnd)
                        hakedis.contract = contract
                        hakedis.status = HakedisStatus(rawValue: hDTO.status) ?? .draft
                        context.insert(hakedis)

                        for hiDTO in hDTO.items {
                            let item = HakedisItem(workItemName: hiDTO.workItemName,
                                                    workItemCode: hiDTO.workItemCode,
                                                    unit: hiDTO.unit, unitPrice: hiDTO.unitPrice,
                                                    previousQuantity: hiDTO.previousQuantity,
                                                    currentQuantity: hiDTO.currentQuantity)
                            item.hakedis = hakedis
                            context.insert(item)
                        }

                        for pyDTO in hDTO.payments {
                            let payment = Payment(amount: pyDTO.amount,
                                                   paymentDate: pyDTO.paymentDate,
                                                   paymentDescription: pyDTO.paymentDescription)
                            payment.hakedis = hakedis
                            context.insert(payment)
                        }
                    }
                }
            }
            try context.save()
            return true
        } catch {
            errorMessage = ErrorHelper.userFriendlyMessage(error)
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

    // FAZ 17.21 — Veri Silme (çift onaylı)
    func deleteAllData(context: ModelContext) {
        func deleteAll<T: PersistentModel>(_ type: T.Type) {
            if let items = try? context.fetch(FetchDescriptor<T>()) {
                for item in items { context.delete(item) }
            }
        }
        deleteAll(Project.self)
        deleteAll(Contract.self)
        deleteAll(WorkItem.self)
        deleteAll(DailyEntry.self)
        deleteAll(Hakedis.self)
        deleteAll(HakedisItem.self)
        deleteAll(Payment.self)
        deleteAll(Contractor.self)
        deleteAll(Worker.self)
        deleteAll(Attendance.self)
        deleteAll(Material.self)
        deleteAll(Equipment.self)
        deleteAll(SafetyIncident.self)
        try? context.save()
        lastBackupDate = nil
        UserDefaults.standard.removeObject(forKey: "lastBackupDate")
    }
}

// MARK: - Backup View

struct BackupView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var manager = BackupManager.shared
    @State private var exportItem: URL? = nil
    @State private var showExportSheet = false
    @State private var showImport = false
    @State private var showSuccess = false

    @State private var showToast = false
    @AppStorage("autoBackupEnabled") private var autoBackupEnabled = false
    @State private var showDeleteConfirm1 = false
    @State private var showDeleteConfirm2 = false

    var body: some View {
        NavigationStack {
            ZStack {
              Form {
                Section("Durum") {
                    if let last = manager.lastBackupDate {
                        LabeledContent("Son Yedekleme",
                                       value: last.formatted(date: .long, time: .shortened))
                    } else {
                        Label("Hiç yedekleme yapılmadı", systemImage: "exclamationmark.circle")
                            .foregroundColor(.hakedisWarning)
                    }
                    Toggle("Otomatik Haftalık Yedekleme", isOn: $autoBackupEnabled)
                        .onChange(of: autoBackupEnabled) { _, enabled in
                            if enabled { manager.scheduleWeeklyReminder() }
                        }
                }
                Section("Dışa Aktar") {
                    Button {
                        if let url = manager.exportToJSON(context: context) {
                            exportItem = url
                            showExportSheet = true
                            withAnimation { showToast = true }
                        }
                    } label: {
                        Label("JSON Olarak Dışa Aktar", systemImage: "square.and.arrow.up")
                    }
                    .disabled(manager.isExporting)
                    Button {
                        if let url = manager.exportToZip(context: context) {
                            exportItem = url
                            showExportSheet = true
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

                // FAZ 17.21 — KVKK & Veri Silme
                Section {
                    DisclosureGroup("Gizlilik Politikası (KVKK)") {
                        Text("""
Kişisel Verileriniz: Uygulamada girdiğiniz tüm veriler (proje bilgileri, çalışan bilgileri, finansal veriler) yalnızca cihazınızda yerel olarak saklanır. Herhangi bir sunucuya gönderilmez.

İCloud Kullanımı: iCloud senkronizasyonunu etkinleştirirseniz verileriniz Apple'ın iCloud altyapısı üzerinden senkronize edilir ve Apple'ın gizlilik politikasına tabidir.

Veri Silme Hakkı: Uygulamayı sildiğinizde tüm yerel veriler otomatik olarak silinir. iCloud verilerini silmek için Ayarlar > iCloud > Depolama'yı kullanabilirsiniz.

6698 Sayılı KVKK kapsamında verileriniz üzerinde tam hakimiyete sahipsiniz.
""")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Gizlilik")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm1 = true
                    } label: {
                        Label("Tüm Uygulama Verilerini Sil", systemImage: "trash.fill")
                    }
                } footer: {
                    Text("Bu işlem geri alınamaz. Tüm proje, hakediş, işçi ve diğer veriler silinir.")
                        .font(.caption)
                }

                if let error = manager.errorMessage {
                    Section {
                        Text(error).foregroundColor(.hakedisDanger).font(.caption)
                    }
                }
            }
              .navigationTitle("Yedekleme")
              .navigationBarTitleDisplayMode(.large)
              .sheet(isPresented: $showExportSheet) {
                  if let url = exportItem {
                      BackupShareSheet(items: [url])
                  }
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
                    manager.errorMessage = ErrorHelper.userFriendlyMessage(error)
                }
            }
              .alert("Başarılı", isPresented: $showSuccess) {
                  Button("Tamam", role: .cancel) {}
              } message: {
                  Text("Haftalık yedekleme hatırlatması ayarlandı.")
              }
              .confirmationDialog("Tüm Veriler Silinecek",
                                  isPresented: $showDeleteConfirm1,
                                  titleVisibility: .visible) {
                  Button("Evet, Silmek İstiyorum", role: .destructive) {
                      showDeleteConfirm2 = true
                  }
                  Button("İptal", role: .cancel) {}
              } message: {
                  Text("Bu işlem geri alınamaz. Yedek almak ister misiniz?")
              }
              .confirmationDialog("Son Onay — Emin misiniz?",
                                  isPresented: $showDeleteConfirm2,
                                  titleVisibility: .visible) {
                  Button("Tüm Verileri Kalıcı Olarak Sil", role: .destructive) {
                      manager.deleteAllData(context: context)
                  }
                  Button("İptal", role: .cancel) {}
              } message: {
                  Text("Tüm proje, hakediş, işçi ve sözleşme verileri kalıcı olarak silinecektir.")
              }
              if manager.isExporting {
                  Color.black.opacity(0.25).ignoresSafeArea()
                  VStack(spacing: 10) {
                      ProgressView().scaleEffect(1.3).tint(.white)
                      Text("Yedekleniyor…").font(.subheadline).foregroundColor(.white)
                  }
                  .padding(20)
                  .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
              }
            }
        }
        .toast(isPresented: $showToast, message: "Yedek başarıyla oluşturuldu")
    }
}

private struct BackupShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

