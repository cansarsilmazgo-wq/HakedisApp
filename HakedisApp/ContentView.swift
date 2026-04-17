import SwiftUI
import SwiftData

// MARK: - RootView (Auth + Onboarding gate)

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("colorScheme") private var colorSchemeRaw = "auto"
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.modelContext) private var modelContext

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView()
            } else if !authManager.isLoggedIn {
                LoginView()
            } else {
                ContentView()
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            if hasSeenOnboarding && !authManager.isLoggedIn {
                authManager.tryAutoLogin(context: modelContext)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var biometricAuth = BiometricAuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @Query private var hakedisler: [Hakedis]
    @Query private var workers: [Worker]
    @Query private var safetyIncidents: [SafetyIncident]
    @Query private var materials: [Material]

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("hasSeenFirstLoginGuide") private var hasSeenGuide = false

    private var role: UserRole { authManager.currentRole }

    var body: some View {
        // Taşeron rolü → özel portal
        if role == .subcontractor {
            SubcontractorPortalView()
        } else {
            mainTabView
        }
    }

    @ViewBuilder
    private var mainTabView: some View {
        ZStack(alignment: .top) {
            TabView {
                // Tab 1 — Ana Ekran (herkese)
                DashboardView()
                    .tabItem { Label("Ana Ekran", systemImage: "house.fill") }
                    .accessibilityLabel("Ana Ekran")

                // Tab 2 — Projeler (subcontractor hariç)
                if role != .subcontractor {
                    ProjectListView()
                        .tabItem { Label("Projeler", systemImage: "folder.fill") }
                        .accessibilityLabel("Projeler")
                }

                // Tab 3 — Şantiye (accountant ve viewer hariç)
                if role.canSeeDailyEntry || role.canManageSafety {
                    SantiyeTabView()
                        .tabItem { Label("Şantiye", systemImage: "hammer.fill") }
                        .accessibilityLabel("Şantiye")
                }

                // Tab 4 — Finans (canSeeFinancials)
                if role.canSeeFinancials {
                    FinansTabView()
                        .tabItem { Label("Finans", systemImage: "banknote.fill") }
                        .accessibilityLabel("Finans")
                }

                // Tab 5 — Daha Fazla (herkese)
                MoreTabView()
                    .tabItem { Label("Daha Fazla", systemImage: "ellipsis.circle.fill") }
                    .accessibilityLabel("Daha Fazla")
            }
            .tint(.hakedisOrange)

            NetworkStatusBanner()
                .animation(.easeInOut, value: networkMonitor.isConnected)
        }
        .task {
            WidgetDataManager.update(projects: projects, hakedisler: hakedisler,
                workers: workers, safetyIncidents: safetyIncidents, materials: materials)
            NotificationManager.shared.clearBadge()
            // ADIM6: Uygulama açılışında mevcut veri için bildirimleri yeniden zamanla
            NotificationManager.shared.rescheduleAllNotifications(context: modelContext)
        }
        .onChange(of: hakedisler.count) {
            WidgetDataManager.update(projects: projects, hakedisler: hakedisler,
                workers: workers, safetyIncidents: safetyIncidents, materials: materials)
        }
        .onChange(of: projects.count) {
            WidgetDataManager.update(projects: projects, hakedisler: hakedisler,
                workers: workers, safetyIncidents: safetyIncidents, materials: materials)
        }
        .onChange(of: hakedisler.map { $0.totalPaid }.reduce(0, +)) {
            WidgetDataManager.update(projects: projects, hakedisler: hakedisler,
                workers: workers, safetyIncidents: safetyIncidents, materials: materials)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard appLockEnabled else { return }
            switch newPhase {
            case .active: biometricAuth.checkTimeout()
            case .background, .inactive: biometricAuth.updateActivity()
            @unknown default: break
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { appLockEnabled && biometricAuth.isLocked },
            set: { if !$0 { biometricAuth.isLocked = false } }
        )) {
            LockScreenView()
        }
        .sheet(isPresented: Binding(
            get: { !hasSeenGuide },
            set: { if !$0 { hasSeenGuide = true } }
        )) {
            GuidedWalkthroughView()
        }
    }
}

