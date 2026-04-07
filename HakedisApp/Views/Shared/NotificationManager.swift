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

    // FIX-21: Geciken ödeme bildirimi her gün 09:00'da tekrarlar
    func schedulePaymentOverdueAlert(hakedis: Hakedis, daysOverdue: Int) {
        guard isAuthorized, overdueAlertsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Geciken Ödeme Uyarısı"
        content.body = "\(hakedis.contract?.contractor?.name ?? "Taşeron") - \(hakedis.periodName): \(daysOverdue) gündür ödeme bekleniyor."
        content.sound = .default
        var components = DateComponents()
        components.hour = 9; components.minute = 0
        // repeats: true — hakediş ödenene kadar her gün 09:00'da hatırlatır
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "overdue_\(hakedis.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    var dailyReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "dailyReminderEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "dailyReminderEnabled") }
    }

    func scheduleDailyEntryReminder() {
        guard isAuthorized, dailyReminderEnabled else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
            return
        }
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

    // FIX-22: Teminat bildirimleri için ayrı toggle
    var guaranteeAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "guaranteeAlertsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "guaranteeAlertsEnabled") }
    }

    func scheduleGuaranteeNotification(guarantee: Guarantee) {
        guard isAuthorized, guaranteeAlertsEnabled else { return }
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

    // MARK: - Sertifika Geçerlilik Bildirimleri

    var certificateAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "certificateAlertsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "certificateAlertsEnabled") }
    }

    /// İşçi sertifikası son kullanım tarihinden 30, 15 ve 7 gün önce sabah 09:00'da bildirim zamanlar.
    func scheduleCertificateExpiryAlerts(worker: Worker) {
        guard isAuthorized, certificateAlertsEnabled else { return }
        let daysBefore = [30, 15, 7]
        for cert in worker.certificates {
            guard let expiryDate = cert.expiryDate else { continue }
            for days in daysBefore {
                guard let triggerDate = Calendar.current.date(byAdding: .day, value: -days, to: expiryDate),
                      triggerDate > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.sound = .default
                switch days {
                case 7:
                    content.title = "Sertifika Süresi Doluyor!"
                    content.body = "\(worker.fullName) — \(cert.certificateType.rawValue): 7 gün içinde süresi doluyor."
                case 15:
                    content.title = "Sertifika Uyarısı"
                    content.body = "\(worker.fullName) — \(cert.certificateType.rawValue): 15 gün içinde süresi doluyor."
                default:
                    content.title = "Sertifika Hatırlatma"
                    content.body = "\(worker.fullName) — \(cert.certificateType.rawValue): 30 gün içinde süresi dolacak."
                }
                var components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
                components.hour = 9; components.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "cert_\(cert.id.uuidString)_d\(days)",
                    content: content, trigger: trigger
                )
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    func cancelCertificateAlerts(certID: UUID) {
        let ids = [30, 15, 7].map { "cert_\(certID.uuidString)_d\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Ekipman Sigorta / Muayene Bildirimleri

    var equipmentAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "equipmentAlertsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "equipmentAlertsEnabled") }
    }

    /// Sigorta veya muayene bitiş tarihinden 30, 15, 7 gün önce bildirim zamanlar.
    func scheduleEquipmentInsuranceAlerts(equipment: EquipmentItem) {
        guard isAuthorized, equipmentAlertsEnabled else { return }
        let daysBefore = [30, 15, 7]
        let checks: [(label: String, date: Date?, prefix: String)] = [
            ("sigorta", equipment.insuranceExpiryDate, "ins"),
            ("muayene", equipment.inspectionExpiryDate, "insp")
        ]
        for check in checks {
            guard let expiryDate = check.date else { continue }
            for days in daysBefore {
                guard let triggerDate = Calendar.current.date(byAdding: .day, value: -days, to: expiryDate),
                      triggerDate > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.sound = .default
                content.title = days == 7 ? "\(equipment.name) \(check.label) bitiyor!" : "\(equipment.name) \(check.label) uyarısı"
                content.body = "\(equipment.name) \(check.label) \(days) gün içinde sona eriyor."
                var components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
                components.hour = 9; components.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(check.prefix)_\(equipment.id.uuidString)_d\(days)",
                    content: content, trigger: trigger
                )
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    /// Ekipman bakım süresi dolduğunda anlık bildirim gönderir.
    func scheduleEquipmentMaintenanceAlert(equipment: EquipmentItem) {
        guard isAuthorized, equipmentAlertsEnabled, equipment.isMaintenanceDue else { return }
        let notifId = "maintenance_\(equipment.id.uuidString)"
        let content = UNMutableNotificationContent()
        content.title = "Ekipman Bakım Zamanı"
        content.body = "\(equipment.name) bakım zamanı geldi (\(Int(equipment.totalOperatingHours)) saat). Bakım yapılmasını planlayın."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: notifId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifId])
        UNUserNotificationCenter.current().add(request)
    }

    func cancelEquipmentAlerts(equipmentID: UUID) {
        let ids = [30, 15, 7].flatMap { d in
            ["ins_\(equipmentID.uuidString)_d\(d)", "insp_\(equipmentID.uuidString)_d\(d)"]
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - İş Kazası SGK Bildirim Uyarıları

    var sgkAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "sgkAlertsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "sgkAlertsEnabled") }
    }

    /// İş kazası için SGK 3 iş günü ve Bakanlık 2 iş günü geri sayım bildirimi zamanlar.
    func scheduleWorkAccidentSGKAlert(incident: SafetyIncident) {
        guard isAuthorized, sgkAlertsEnabled else { return }

        let sgkDeadline = incident.sgkReportDeadline
        let ministryDeadline = incident.ministryReportDeadline

        // SGK bildirimi: 3 iş günü
        if sgkDeadline > Date() {
            let content = UNMutableNotificationContent()
            content.title = "İş Kazası SGK Bildirimi"
            content.body = "\(incident.date.shortFormatted) tarihli iş kazası SGK'ya 3 iş günü içinde bildirilmeli. Son gün: \(sgkDeadline.shortFormatted)"
            content.sound = .default
            var sgkComponents = Calendar.current.dateComponents([.year, .month, .day], from: sgkDeadline)
            sgkComponents.hour = 8; sgkComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: sgkComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: "sgk_\(incident.id.uuidString)",
                content: content, trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }

        // Bakanlık bildirimi: 2 iş günü
        if ministryDeadline > Date() {
            let content2 = UNMutableNotificationContent()
            content2.title = "İş Kazası Bakanlık Bildirimi"
            content2.body = "\(incident.date.shortFormatted) tarihli iş kazası Çalışma Bakanlığı'na 2 iş günü içinde bildirilmeli. Son gün: \(ministryDeadline.shortFormatted)"
            content2.sound = .default
            var minComponents = Calendar.current.dateComponents([.year, .month, .day], from: ministryDeadline)
            minComponents.hour = 8; minComponents.minute = 0
            let trigger2 = UNCalendarNotificationTrigger(dateMatching: minComponents, repeats: false)
            let request2 = UNNotificationRequest(
                identifier: "ministry_\(incident.id.uuidString)",
                content: content2, trigger: trigger2
            )
            UNUserNotificationCenter.current().add(request2)
        }
    }

    func cancelWorkAccidentAlerts(incidentID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "sgk_\(incidentID.uuidString)", "ministry_\(incidentID.uuidString)"
        ])
    }

    // MARK: - Join Request Notifications

    /// Patrona: yeni katılma talebi geldi
    func scheduleJoinRequestNotification(for user: UserAccount, company: Company) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Yeni Katılma Talebi"
        content.body = "\(user.fullName) şirketinize katılmak istiyor."
        content.sound = .default
        content.badge = 1
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "join_request_\(user.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Çalışana: talebi onaylandı
    func scheduleApprovalNotification(for user: UserAccount) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Talebiniz Onaylandı! 🎉"
        content.body = "Artık \(user.companyName ?? "şirkete") giriş yapabilirsiniz."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "approval_\(user.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Çalışana: talebi reddedildi
    func scheduleRejectionNotification(for user: UserAccount) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Talebiniz Reddedildi"
        content.body = "Şirket yöneticisi talebinizi reddetti. Detay için uygulamayı açın."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "rejection_\(user.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Malzeme Sipariş Teslimat Bildirimi

    var materialOrderAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "materialOrderAlertsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "materialOrderAlertsEnabled") }
    }

    func scheduleMaterialOrderDeliveryAlert(order: MaterialOrder) {
        guard isAuthorized, materialOrderAlertsEnabled else { return }
        guard let deliveryDate = order.expectedDeliveryDate else { return }
        let content = UNMutableNotificationContent()
        let materialName = order.material?.name ?? order.orderNo
        content.title = "Malzeme Teslimat Hatırlatıcı"
        content.body = "\(materialName) siparişi (\(order.orderNo)) bugün teslim edilmesi bekleniyor."
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: deliveryDate)
        components.hour = 8; components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "matorder_\(order.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelMaterialOrderAlert(orderID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["matorder_\(orderID.uuidString)"]
        )
    }

    // MARK: - Yazışma Cevap Süresi Bildirimi

    var correspondenceAlertsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "correspondenceAlertsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "correspondenceAlertsEnabled") }
    }

    func scheduleCorrespondenceDeadlineAlert(correspondence: CorrespondenceRecord) {
        guard isAuthorized, correspondenceAlertsEnabled else { return }
        guard let deadline = correspondence.replyDeadline, !correspondence.isReplied else { return }

        let content = UNMutableNotificationContent()
        content.title = "Yazışma Cevap Süresi Yaklaşıyor"
        content.body = "'\(correspondence.subject)' konulu yazışmaya (\(correspondence.recordNo)) cevap vermek için son 2 gün kaldı."
        content.sound = .default

        let alertDate = Calendar.current.date(byAdding: .day, value: -2, to: deadline) ?? deadline
        var components = Calendar.current.dateComponents([.year, .month, .day], from: alertDate)
        components.hour = 9; components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "corrdeadline_\(correspondence.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelCorrespondenceDeadlineAlert(correspondenceID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["corrdeadline_\(correspondenceID.uuidString)"]
        )
    }
}

struct NotificationSettingsView: View {
    @StateObject private var manager = NotificationManager.shared
    @AppStorage("overdueAlertsEnabled") private var overdueAlertsEnabled = false
    @AppStorage("approvalAlertsEnabled") private var approvalAlertsEnabled = false
    @AppStorage("budgetAlertsEnabled") private var budgetAlertsEnabled = false
    // FIX-22: Teminat bildirimleri için ayrı AppStorage
    @AppStorage("guaranteeAlertsEnabled") private var guaranteeAlertsEnabled = false
    @AppStorage("certificateAlertsEnabled") private var certificateAlertsEnabled = false
    @AppStorage("materialOrderAlertsEnabled") private var materialOrderAlertsEnabled = false
    @AppStorage("correspondenceAlertsEnabled") private var correspondenceAlertsEnabled = false

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
                Toggle("Günlük Saha Hatırlatıcı (17:00)", isOn: Binding(
                    get: { manager.dailyReminderEnabled },
                    set: { val in
                        manager.dailyReminderEnabled = val
                        manager.scheduleDailyEntryReminder()
                    }
                ))
                .tint(.hakedisOrange)
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
                // FIX-22: Teminat bildirimlerini approvalAlertsEnabled'dan ayır
                Toggle("Teminat Mektubu Uyarıları", isOn: $guaranteeAlertsEnabled)
                    .tint(.hakedisOrange)
                    .onChange(of: guaranteeAlertsEnabled) { _, val in
                        manager.guaranteeAlertsEnabled = val
                        if !val {
                            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                                let ids = requests.filter { $0.identifier.hasPrefix("guarantee_") }.map { $0.identifier }
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                            }
                        }
                    }
                Toggle("Sertifika Geçerlilik Uyarıları", isOn: $certificateAlertsEnabled)
                    .tint(.hakedisOrange)
                    .onChange(of: certificateAlertsEnabled) { _, val in
                        manager.certificateAlertsEnabled = val
                        if !val {
                            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                                let ids = requests.filter { $0.identifier.hasPrefix("cert_") }.map { $0.identifier }
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                            }
                        }
                    }
                Toggle("Malzeme Sipariş Teslimat Uyarıları", isOn: $materialOrderAlertsEnabled)
                    .tint(.hakedisOrange)
                    .onChange(of: materialOrderAlertsEnabled) { _, val in
                        manager.materialOrderAlertsEnabled = val
                        if !val {
                            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                                let ids = requests.filter { $0.identifier.hasPrefix("matorder_") }.map { $0.identifier }
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                            }
                        }
                    }
                Toggle("Yazışma Cevap Süresi Uyarıları", isOn: $correspondenceAlertsEnabled)
                    .tint(.hakedisOrange)
                    .onChange(of: correspondenceAlertsEnabled) { _, val in
                        manager.correspondenceAlertsEnabled = val
                        if !val {
                            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                                let ids = requests.filter { $0.identifier.hasPrefix("corrdeadline_") }.map { $0.identifier }
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                            }
                        }
                    }
            }

            Section("Bilgi") {
                Text("Günlük hatırlatıcı her gün saat 17:00'de saha girişi yapmanızı hatırlatır.")
                    .font(.caption).foregroundColor(.secondary)
                // FIX-21: Tekrarlayan geciken ödeme bildirimi bilgisi güncellendi
                Text("Geciken ödeme uyarıları; ödeme yapılana kadar her gün 09:00'da tekrar eder. Vade bildirimleri 7, 3 gün önce ve vade günü zamanlanır.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Sözleşme bitiş tarihi uyarıları; bitiş tarihinden 30, 14 ve 7 gün önce sabah 08:00'de zamanlanır.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Bütçe aşımı uyarıları, sözleşme bütçesi %80 veya üzeri kullanıldığında tetiklenir.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Teminat uyarıları; son kullanım tarihinden 30, 7 ve 1 gün önce 09:00'da zamanlanır.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Sertifika uyarıları; son kullanım tarihinden 30, 15 ve 7 gün önce 09:00'da zamanlanır.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Malzeme sipariş uyarıları; beklenen teslimat gününde sabah 08:00'de tetiklenir.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Yazışma cevap süresi uyarıları; son yanıt tarihinden 2 gün önce 09:00'da zamanlanır.")
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
                    manager.dailyReminderEnabled = requests.contains { $0.identifier == "daily_reminder" }
                }
            }
        }
    }
}
