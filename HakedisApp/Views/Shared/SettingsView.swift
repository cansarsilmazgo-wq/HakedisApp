import SwiftUI
import SwiftData

struct SettingsView: View {
    // Şirket bilgileri (PDF başlığında kullanılır)
    @AppStorage("companyName")    private var companyName    = ""
    @AppStorage("companyPhone")   private var companyPhone   = ""
    @AppStorage("companyEmail")   private var companyEmail   = ""
    @AppStorage("companyAddress") private var companyAddress = ""

    // Varsayılan değerler
    @AppStorage("defaultRetentionRate") private var defaultRetentionRate = 10.0
    @AppStorage("defaultAdvanceRate")   private var defaultAdvanceRate   = 0.0
    @AppStorage("defaultKDVRate")       private var defaultKDVRate       = 0.0

    // Para birimi
    @AppStorage("selectedCurrency") private var selectedCurrency = "TRY"

    // Dashboard kartları
    @AppStorage("dashboard_showFinancialSummary") private var showFinancialSummary = true
    @AppStorage("dashboard_showStockAlerts")      private var showStockAlerts = true
    @AppStorage("dashboard_showSafetyCard")       private var showSafetyCard = true
    @AppStorage("dashboard_showRFICard")          private var showRFICard = true
    @AppStorage("dashboard_showWorkOrderCard")    private var showWorkOrderCard = true

    @Environment(\.modelContext) private var modelContext
    @StateObject private var authManager = AuthManager.shared
    @Query private var projects:   [Project]
    @Query private var hakedisler: [Hakedis]

    @State private var showingDeleteConfirm = false
    @State private var showingDeleteFinalConfirm = false
    @State private var exportItem: ExportItem?
    @State private var isExporting = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Şirket Bilgileri
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Şirket / Firma Adı").font(.caption).foregroundColor(.secondary)
                        TextField("PDF başlığında görünür", text: $companyName)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Telefon").font(.caption).foregroundColor(.secondary)
                        TextField("+90 5xx xxx xx xx", text: $companyPhone)
                            .keyboardType(.phonePad)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("E-posta").font(.caption).foregroundColor(.secondary)
                        TextField("firma@ornek.com", text: $companyEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adres").font(.caption).foregroundColor(.secondary)
                        TextField("Şirket adresi", text: $companyAddress, axis: .vertical)
                            .lineLimit(2)
                    }
                } header: {
                    Text("Şirket Bilgileri")
                } footer: {
                    Text("Bu bilgiler PDF hakedişlerin başlığında görünür.")
                }

                // MARK: Varsayılan Değerler
                Section("Varsayılan Değerler") {
                    HStack {
                        Text("Teminat Oranı")
                        Spacer()
                        TextField("10", value: $defaultRetentionRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Avans Oranı")
                        Spacer()
                        TextField("0", value: $defaultAdvanceRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("KDV Oranı")
                        Spacer()
                        Picker("KDV", selection: $defaultKDVRate) {
                            Text("KDV Yok").tag(0.0)
                            Text("%1").tag(1.0)
                            Text("%10").tag(10.0)
                            Text("%20").tag(20.0)
                        }
                        .pickerStyle(.menu)
                    }
                }

                // MARK: Hesabım
                Section("Hesabım") {
                    NavigationLink(destination: ProfileView()) {
                        if let user = authManager.currentUser {
                            Label(user.fullName, systemImage: user.role.icon)
                                .accessibilityLabel("Profilim")
                        } else {
                            Label("Profilim", systemImage: "person.circle")
                        }
                    }
                    if authManager.currentRole == .owner {
                        NavigationLink(destination: CompanySettingsView()) {
                            Label("Şirket Ayarları", systemImage: "building.2")
                                .accessibilityLabel("Şirket ayarları")
                        }
                        NavigationLink(destination: JoinRequestManagementView()) {
                            HStack {
                                Label("Katılma Talepleri", systemImage: "person.badge.clock")
                                Spacer()
                                PendingRequestsBadge()
                            }
                            .accessibilityLabel("Katılma talepleri")
                        }
                    }
                    if authManager.currentRole.canManageUsers {
                        NavigationLink(destination: UserManagementView()) {
                            Label("Kullanıcı Yönetimi", systemImage: "person.2")
                                .accessibilityLabel("Kullanıcı yönetimi")
                        }
                    }
                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        Label("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Çıkış yap")
                }

                // MARK: Para Birimi
                Section("Para Birimi") {
                    Picker("Para Birimi", selection: $selectedCurrency) {
                        ForEach(SupportedCurrency.allCases, id: \.rawValue) { cur in
                            Text("\(cur.symbol) \(cur.rawValue)").tag(cur.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Para birimi seç")
                }

                // MARK: Dashboard Özelleştirme
                Section("Ana Ekran Kartları") {
                    Toggle("Finansal Özet", isOn: $showFinancialSummary)
                    Toggle("Kritik Stok Uyarıları", isOn: $showStockAlerts)
                    Toggle("İSG Kartı", isOn: $showSafetyCard)
                    Toggle("RFI Kartı", isOn: $showRFICard)
                    Toggle("İş Emirleri Kartı", isOn: $showWorkOrderCard)
                }

                // MARK: Uygulama
                Section("Uygulama") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Bildirim Ayarları", systemImage: "bell")
                    }
                    NavigationLink(destination: OfflineSyncSettingsView()) {
                        Label("Çevrimdışı & Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink(destination: ContractorPortalView()) {
                        Label("Taşeron Portalı", systemImage: "person.badge.shield.checkmark")
                    }
                    NavigationLink(destination: ObjectionAdminView()) {
                        Label("İtiraz Yönetimi", systemImage: "exclamationmark.bubble")
                    }
                }

                // MARK: Veri Yönetimi
                Section {
                    Button {
                        exportAllData()
                    } label: {
                        HStack {
                            Label("Tüm Veriyi Dışa Aktar (CSV)",
                                  systemImage: "square.and.arrow.up")
                            if isExporting {
                                Spacer()
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isExporting)

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Tüm Verileri Sil", systemImage: "trash")
                    }
                } header: {
                    Text("Veri Yönetimi")
                } footer: {
                    Text("\(projects.count) proje · \(hakedisler.count) hakediş kayıtlı")
                }

                // MARK: Yardım
                Section("Yardım") {
                    NavigationLink(destination: HelpView()) {
                        Label("Yardım ve Rehber", systemImage: "questionmark.circle")
                    }
                    .accessibilityLabel("Yardım ve Rehber")
                }

                // MARK: Hakkında
                Section("Hakkında") {
                    LabeledContent("Versiyon",   value: "\(appVersion) (\(buildNumber))")
                    LabeledContent("Platform",   value: "iOS 17+")
                    LabeledContent("Teknoloji",  value: "SwiftUI + SwiftData")
                    LabeledContent("Geliştirici",value: "HakedisApp")

                    Link(destination: URL(string: "https://github.com/cansarsilmazgo-wq/HakedisApp")!) {
                        HStack {
                            Label("GitHub Repo", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Image(systemName: "arrow.up.right.square").foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .sheet(item: $exportItem) { item in
                ShareSheet(items: [item.url])
            }
            .confirmationDialog("Tüm Verileri Sil", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Evet, silmek istiyorum", role: .destructive) { showingDeleteFinalConfirm = true }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Bu işlem geri alınamaz. Tüm projeler, sözleşmeler, hakedişler ve günlük girişler silinecek.")
            }
            .confirmationDialog("Emin misiniz?", isPresented: $showingDeleteFinalConfirm, titleVisibility: .visible) {
                Button("Tüm Verileri Kalıcı Olarak Sil", role: .destructive) { deleteAllData() }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("\(projects.count) proje ve \(hakedisler.count) hakediş kalıcı olarak silinecek.")
            }
        }
    }

    // MARK: - Data Helpers

    private func exportAllData() {
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            var lines = ["Tür,İsim,Detay,Net Tutar,Durum,Tarih"]
            for project in self.projects {
                lines.append("Proje,\(q(project.name)),\(q(project.location)),,\(project.status.rawValue),\(project.startDate.shortFormatted)")
                for contract in project.contracts {
                    lines.append("Sözleşme,\(q(contract.title)),\(q(contract.contractor?.name ?? "")),,—,\(contract.contractDate.shortFormatted)")
                    for h in contract.hakedisler {
                        lines.append("Hakediş,\(q(h.periodName)),\(q(contract.title)),\(h.netAmount.currencyFormatted),\(h.status.rawValue),\(h.periodStart.shortFormatted)")
                    }
                }
            }
            let csvString = lines.joined(separator: "\n")
            let dateTag = Date().shortFormatted.replacingOccurrences(of: ".", with: "-")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("HakedisApp_Export_\(dateTag).csv")
            try? csvString.write(to: url, atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                self.isExporting = false
                self.exportItem = ExportItem(url: url)
            }
        }
    }

    private func q(_ s: String) -> String {
        s.contains(",") || s.contains("\"")
            ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
            : s
    }

    private func deleteAllData() {
        for project in projects { modelContext.delete(project) }
    }
}

// MARK: - Export Item Wrapper

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - PendingRequestsBadge

struct PendingRequestsBadge: View {
    @StateObject private var authManager = AuthManager.shared
    @Query private var allRequests: [JoinRequest]

    private var count: Int {
        guard let company = authManager.currentUser?.company else { return 0 }
        return allRequests.filter { $0.company?.id == company.id && $0.status == .pending }.count
    }

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Color.hakedisDanger)
                .clipShape(Capsule())
        }
    }
}
