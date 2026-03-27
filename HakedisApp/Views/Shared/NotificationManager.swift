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
        content.badge = 1
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: hakedis.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func schedulePaymentOverdueAlert(hakedis: Hakedis, daysOverdue: Int) {
        guard isAuthorized, overdueAlertsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Geciken Ödeme Uyarısı"
        content.body = "\(hakedis.contract?.contractor?.name ?? "Taşeron") - \(hakedis.periodName): \(daysOverdue) gündür ödeme bekleniyor."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
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
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: notifId, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
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
                                let ids = requests.filter { req in
                                    !req.identifier.hasPrefix("overdue_") && req.identifier != "daily_reminder"
                                }.map { $0.identifier }
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                            }
                        }
                    }
            }

            Section("Bilgi") {
                Text("Günlük hatırlatıcı her gün saat 17:00'de saha girişi yapmanızı hatırlatır.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Geciken ödeme ve hakediş bildirimleri, ilgili işlem gerçekleştiğinde otomatik gönderilir.")
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
