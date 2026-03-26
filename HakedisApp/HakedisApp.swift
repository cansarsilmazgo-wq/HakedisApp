import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

@main
struct HakedisApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Project.self,
            Contractor.self,
            Contract.self,
            WorkItem.self,
            DailyEntry.self,
            Hakedis.self,
            HakedisItem.self,
            Payment.self
        ])
    }
}
