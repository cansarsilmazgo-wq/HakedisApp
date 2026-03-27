import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

@main
struct HakedisApp: App {

    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Project.self, Contractor.self, Contract.self, WorkItem.self,
            DailyEntry.self, Hakedis.self, HakedisItem.self, Payment.self,
            RetentionRelease.self, ChangeOrder.self, Milestone.self, SiteReport.self
        ])
        #if targetEnvironment(simulator)
        // Simulator: CloudKit gerektirmez, yerel depolama yeterli
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: [localConfig])
        #else
        do {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // iCloud hesabı yoksa veya CloudKit validasyonu başarısız → yerel mod
            let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [localConfig])
        }
        #endif
    }()

    init() {
        #if !targetEnvironment(simulator)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(HakedisApp.sharedModelContainer)
    }
}
