import SwiftUI
import SwiftData

struct MoreTabView: View {
    @Query private var hakedisler: [Hakedis]
    var body: some View {
        NavigationStack {
            List {
                Section("Raporlar") {
                    NavigationLink(destination: ReportsView()) {
                        Label("Genel Raporlar", systemImage: "chart.bar.doc.horizontal")
                            .accessibilityLabel("Genel Raporlar")
                    }
                    NavigationLink(destination: CashFlowView(hakedisler: hakedisler)) {
                        Label("Nakit Akış Analizi", systemImage: "arrow.left.arrow.right.circle")
                            .accessibilityLabel("Nakit Akış Analizi")
                    }
                }

                Section("Kütüphane") {
                    NavigationLink(destination: PozLibraryView(onSelect: { _, _ in })) {
                        Label("Poz Kütüphanesi", systemImage: "books.vertical")
                            .accessibilityLabel("Poz Kütüphanesi")
                    }
                }

                Section("Garanti & Teminat") {
                    NavigationLink(destination: AllGuaranteeListView()) {
                        Label("Teminat Mektupları", systemImage: "lock.shield")
                            .accessibilityLabel("Teminat Mektupları")
                    }
                }

                Section("Sistem") {
                    NavigationLink(destination: SettingsView()) {
                        Label("Ayarlar", systemImage: "gear")
                            .accessibilityLabel("Ayarlar")
                    }
                    NavigationLink(destination: ContractorPortalView()) {
                        Label("Taşeron Portal", systemImage: "person.crop.circle.badge.checkmark")
                            .accessibilityLabel("Taşeron Portal")
                    }
                }
            }
            .navigationTitle("Daha Fazla")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
