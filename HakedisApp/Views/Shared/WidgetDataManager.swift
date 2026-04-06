import Foundation
import WidgetKit

struct WidgetDataManager {
    static func update(
        projects: [Project],
        hakedisler: [Hakedis],
        workers: [Worker] = [],
        safetyIncidents: [SafetyIncident] = [],
        materials: [Material] = []
    ) {
        let defaults = UserDefaults.standard

        let activeProjects = projects.filter { $0.status == .active }.count
        let pending = hakedisler
            .filter { $0.status == .approved }
            .reduce(0) { $0 + $1.remainingAmount }
        let overdueCount = hakedisler.filter { $0.isOverdue }.count
        let last = hakedisler.sorted { $0.createdAt > $1.createdAt }.first

        defaults.set(pending, forKey: "widget_pending")
        defaults.set(activeProjects, forKey: "widget_activeProjects")
        defaults.set(overdueCount, forKey: "widget_overdueCount")
        defaults.set(last?.periodName ?? "—", forKey: "widget_lastHakedis")
        defaults.set(last?.status.rawValue ?? "—", forKey: "widget_lastStatus")
        defaults.set(last?.netAmount ?? 0, forKey: "widget_lastAmount")

        defaults.set(workers.filter { $0.isActive }.count, forKey: "widget_workerCount")
        defaults.set(safetyIncidents.filter { !$0.isResolved }.count, forKey: "widget_openIncidents")
        defaults.set(materials.filter { $0.currentStock <= $0.minimumStock }.count, forKey: "widget_lowStockCount")

        WidgetCenter.shared.reloadAllTimelines()
    }
}
