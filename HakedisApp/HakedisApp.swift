import SwiftUI
import SwiftData

@main
struct HakedisApp: App {
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
