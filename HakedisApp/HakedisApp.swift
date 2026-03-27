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
            RetentionRelease.self, ChangeOrder.self, Milestone.self
        ])
        do {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // iCloud hesabı yoksa veya simulator'da yerel moda geç
            let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [localConfig])
        }
    }()

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(HakedisApp.sharedModelContainer)
    }
}
