import SwiftUI
import SwiftData

@main
struct HakedisApp: App {

    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Project.self, Contractor.self, Contract.self, WorkItem.self,
            DailyEntry.self, Hakedis.self, HakedisItem.self, Payment.self,
            RetentionRelease.self, ChangeOrder.self, Milestone.self, SiteReport.self,
            ApprovalStep.self, HakedisRevision.self, UnitPriceAnalysis.self,
            SiteHandoverRecord.self, SiteDeficiency.self, MeasurementEntry.self
        ])

        // Store URL'sini açıkça belirt — böylece silme işlemi doğru yere gider
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupport.appendingPathComponent("hakedis.store")
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema uyumsuzluğu → SQLite store + WAL dosyalarını sil (-shm/-wal suffix'i)
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("ModelContainer oluşturulamadı: \(error.localizedDescription)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(HakedisApp.sharedModelContainer)
    }
}
