import SwiftUI
import SwiftData

// MARK: - RootView (Onboarding gate)

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            ContentView()
        } else {
            OnboardingView()
        }
    }
}

struct ContentView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var authManager = BiometricAuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @Query private var projects: [Project]
    @Query private var hakedisler: [Hakedis]
    @Query private var workers: [Worker]
    @Query private var safetyIncidents: [SafetyIncident]
    @Query private var materials: [Material]

    @AppStorage("appLockEnabled") private var appLockEnabled = false

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DashboardView()
                    .tabItem { Label("Ana Ekran", systemImage: "house.fill") }
                    .accessibilityLabel("Ana Ekran")

                ProjectListView()
                    .tabItem { Label("Projeler", systemImage: "folder.fill") }
                    .accessibilityLabel("Projeler")

                SantiyeTabView()
                    .tabItem { Label("Şantiye", systemImage: "hammer.fill") }
                    .accessibilityLabel("Şantiye")

                FinansTabView()
                    .tabItem { Label("Finans", systemImage: "banknote.fill") }
                    .accessibilityLabel("Finans")

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
            case .active:
                authManager.checkTimeout()
            case .background, .inactive:
                authManager.updateActivity()
            @unknown default:
                break
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { appLockEnabled && authManager.isLocked },
            set: { if !$0 { authManager.isLocked = false } }
        )) {
            LockScreenView()
        }
    }
}
