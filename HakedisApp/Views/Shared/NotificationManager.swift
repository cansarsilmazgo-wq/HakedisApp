import SwiftUI
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var isAuthorized = false

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { self.isAuthorized = granted }
        }
    }

    func scheduleHakedisReminder(hakedis: Hakedis) {
        guard isAuthorized else { requestPermission(); return }
        let content = UNMutableNotificationContent()
        content.title = "Hakediş Onay Bekliyor"
        content.body = "\(hakedis.periodName) hakedişi onayınızı bekliyor."
        content.sound = .default
        content.badge = 1
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: hakedis.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func schedulePaymentOverdueAlert(hakedis: Hakedis, daysOverdue: Int) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Geciken Ödeme Uyarısı"
        content.body = "\(hakedis.contract?.contractor?.name ?? "Taşeron") - \(hakedis.periodName): \(daysOverdue) gündür ödeme bekleniyor."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
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

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

struct NotificationSettingsView: View {
    @StateObject private var manager = NotificationManager.shared
    @State private var dailyReminderEnabled = false
    @State private var overdueAlertsEnabled = false
    @State private var approvalAlertsEnabled = false

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
                Toggle("Hakediş Onay Bildirimleri", isOn: $approvalAlertsEnabled)
                    .tint(.hakedisOrange)
            }

            Section("Bilgi") {
                Text("Günlük hatırlatıcı her gün saat 17:00'de saha girişi yapmanızı hatırlatır.")
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
        }
    }
}
