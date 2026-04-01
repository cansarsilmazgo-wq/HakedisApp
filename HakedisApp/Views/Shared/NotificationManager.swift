import SwiftUI
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var isAuthorized = false

    var overdueAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "overdueAlertsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "overdueAlertsEnabled") }
    }

    var approvalAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "approvalAlertsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "approvalAlertsEnabled") }
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { self.isAuthorized = granted }
        }
    }

    func scheduleHakedisReminder(hakedis: Hakedis) {
        guard isAuthorized, approvalAlertsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Hakediş Onay Bekliyor"
        content.body = "\(hakedis.periodName) hakedişi onayınızı bekliyor."
        content.sound = .default
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date().addingTimeInterval(60))
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "approval_\(hakedis.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
    }

    func schedulePaymentOverdueAlert(hakedis: Hakedis, daysOverdue: Int) {
        guard isAuthorized, overdueAlertsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Geciken Ödeme Uyarısı"
        content.body = "\(hakedis.contract?.contractor?.name ?? "Taşeron") - \(hakedis.periodName): \(daysOverdue) gündür ödeme bekleniyor."
        content.sound = .default
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
        components.hour = 9; components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "overdue_\(hakedis.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleDailyEntryReminder() {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Günlük Saha Girişi"
        content.body = "Bugünkü saha çalışmalarını girdiniz mi?"
        content.sound = .default
        var dateComponents = DateComponents()
        dateComponents.hour = 17
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        UNUserNotificationCenter.current().add(request)
    }

    var budgetAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "budgetAlertsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "budgetAlertsEnabled") }
    }

    func scheduleBudgetOverrunAlert(contract: Contract) {
        guard isAuthorized, budgetAlertsEnabled else { return }
        let notifId = "budget_\(contract.id.uuidString)"
        // Aynı sözleşme için tekrar gönderme
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            guard !requests.contains(where: { $0.identifier == notifId }) else { return }
            let content = UNMutableNotificationContent()
            if contract.isOverBudget {
                content.title = "Bütçe Aşıldı"
                content.body = "\(contract.title): Sözleşme değerinin %\(Int(contract.budgetUtilization - 100)) üzerinde hakediş kesildi."
            } else {
                content.title = "Bütçe Uyarısı"
                content.body = "\(contract.title): Bütçenin %\(Int(contract.budgetUtilization))'i kullanıldı."
            }
            content.sound = .default
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
            components.hour = 9; components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: notifId, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Vade Tarihi Bildirimleri (Takvim Bazlı)

    /// Hakediş vade tarihinden 7 gün önce, 3 gün önce ve vade günü sabah 09:00'da bildirim zamanlar.
    func scheduleHakedisDueDateAlerts(hakedis: Hakedis) {
        guard isAuthorized, overdueAlertsEnabled, let dueDate = hakedis.dueDate else { return }
        let contractorName = hakedis.contract?.contractor?.name ?? "Taşeron"
        let daysBefore = [7, 3, 0]

        for days in daysBefore {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -days, to: dueDate),
                  triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            if days == 0 {
                content.title = "Hakediş Vade Tarihi"
                content.body = "\(contractorName) — \(hakedis.periodName): Ödeme vadesi bugün."
            } else {
                content.title = "Hakediş Vade Yaklaşıyor"
                content.body = "\(contractorName) — \(hakedis.periodName): Ödeme vadesi \(days) gün sonra."
            }
            content.sound = .default

            var components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
            components.hour = 9
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "duedate_\(hakedis.id.uuidString)_d\(days)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Hakediş için zamanlanmış vade bildirimlerini iptal eder (ödendi veya silindi).
    func cancelHakedisDueDateAlerts(hakedisID: UUID) {
        let ids = [7, 3, 0].map { "duedate_\(hakedisID.uuidString)_d\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Sözleşme Bitiş Tarihi Bildirimleri

    /// Sözleşme bitiş tarihinden 30, 14 ve 7 gün önce sabah 08:00'da bildirim zamanlar.
    func scheduleContractDeadlineAlerts(contract: Contract) {
        guard isAuthorized, approvalAlertsEnabled, let deadline = contract.completionDeadline else { return }
        let daysBefore = [30, 14, 7]

        for days in daysBefore {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -days, to: deadline),
                  triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Sözleşme Bitiş Tarihi Yaklaşıyor"
            content.body = "\(contract.title): Bitiş tarihine \(days) gün kaldı."
            content.sound = .default

            var components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
            components.hour = 8
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "deadline_\(contract.id.uuidString)_d\(days)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Sözleşme için zamanlanmış bitiş tarihi bildirimlerini iptal eder.
    func cancelContractDeadlineAlerts(contractID: UUID) {
        let ids = [30, 14, 7].map { "deadline_\(contractID.uuidString)_d\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Teminat Mektubu Bildirimleri

    func scheduleGuaranteeNotification(guarantee: Guarantee) {
        guard isAuthorized, approvalAlertsEnabled else { return }
        let daysBefore = [30, 7, 1]
        for days in daysBefore {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -days, to: guarantee.expiryDate),
                  triggerDate > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.sound = .default
            switch days {
            case 1:
                content.title = "Teminat Mektubu Süresi Doluyor!"
                content.body = "\(guarantee.bankName) teminat mektubu yarın süresi doluyor! (Ref: \(guarantee.referenceNumber))"
            case 7:
                content.title = "Teminat Mektubu Uyarısı"
                content.body = "\(guarantee.bankName) teminat mektubu 7 gün içinde süresi doluyor. (Ref: \(guarantee.referenceNumber))"
            default:
                content.title = "Teminat Mektubu Hatırlatma"
                content.body = "\(guarantee.bankName) teminat mektubu 30 gün içinde süresi dolacak. (Ref: \(guarantee.referenceNumber))"
            }
            var components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
            components.hour = 9
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "guarantee_\(guarantee.id.uuidString)_d\(days)",
                content: content, trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelGuaranteeNotifications(guaranteeID: UUID) {
        let ids = [30, 7, 1].map { "guarantee_\(guaranteeID.uuidString)_d\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

struct NotificationSettingsView: View {
    @StateObject private var manager = NotificationManager.shared
    @State private var dailyReminderEnabled = false
    @AppStorage("overdueAlertsEnabled") private var overdueAlertsEnabled = false
    @AppStorage("approvalAlertsEnabled") private var approvalAlertsEnabled = false
    @AppStorage("budgetAlertsEnabled") private var budgetAlertsEnabled = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: manager.isAuthorized ? "bell.fill" : "bell.slash.fill")
                        .foregroundColor(manager.isAuthorized ? .hakedisSuccess : .hakedisDanger)
                    Text(manager.isAuthorized ? "Bildirimler Aktif" : "Bildirimler Kapalı")
                    Spacer()
                    if !manager.isAuthorized {
                        Button("İzin Ver") { manager.requestPermission() }
                            .foregroundColor(.hakedisOrange)
                    }
                }
            }

            Section("Bildirim Türleri") {
                Toggle("Günlük Saha Hatırlatıcı (17:00)", isOn: $dailyReminderEnabled)
                    .tint(.hakedisOrange)
                    .onChange(of: dailyReminderEnabled) { _, val in
                        if val { manager.scheduleDailyEntryReminder() }
                        else { manager.cancelNotification(id: "daily_reminder") }
                    }
                Toggle("Geciken Ödeme Uyarıları", isOn: $overdueAlertsEnabled)
                    .tint(.hakedisOrange)
                    .onChange(of: overdueAlertsEnabled) { _, val in
                        manager.overdueAlertsEnabled = val
                        if !val {
                            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                                let ids = requests.filter { $0.identifier.hasPrefix("overdue_") }.map { $0.identifier }
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                            }
                        }
                    }
                Toggle("Bütçe Aşımı Uyarıları", isOn: $budgetAlertsEnabled)
                    .tint(.hakedisOrange)
                    .onChange(of: budgetAlertsEnabled) { _, val in
                        manager.budgetAlertsEnabled = val
                        if !val {
                            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                                let ids = requests.filter { $0.identifier.hasPrefix("budget_") }.map { $0.identifier }
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                            }
                        }
                    }
                Toggle("Hakediş Onay Bildirimleri", isOn: $approvalAlertsEnabled)
                    .tint(.hakedisOrange)
                    .onChange(of: approvalAlertsEnabled) { _, val in
                        manager.approvalAlertsEnabled = val
                        if !val {
                            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                                let ids = requests.filter { $0.identifier.hasPrefix("approval_") }.map { $0.identifier }
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                            }
                        }
                    }
            }

            Section("Bilgi") {
                Text("Günlük hatırlatıcı her gün saat 17:00'de saha girişi yapmanızı hatırlatır.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Geciken ödeme uyarıları; hakediş vade tarihinden 7 gün önce (09:00), 3 gün önce (09:00) ve vade günü (09:00) otomatik olarak zamanlanır. Hakediş ödendiğinde iptal edilir.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Sözleşme bitiş tarihi uyarıları; bitiş tarihinden 30, 14 ve 7 gün önce sabah 08:00'de zamanlanır.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Bütçe aşımı uyarıları, sözleşme bütçesi %80 veya üzeri kullanıldığında tetiklenir.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .navigationTitle("Bildirim Ayarları")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    manager.isAuthorized = settings.authorizationStatus == .authorized
                }
            }
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                DispatchQueue.main.async {
                    dailyReminderEnabled = requests.contains { $0.identifier == "daily_reminder" }
                }
            }
        }
    }
}
