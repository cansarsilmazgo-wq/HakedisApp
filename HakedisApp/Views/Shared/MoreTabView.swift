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
                    NavigationLink(destination: SGKReportView()) {
                        Label("SGK Hazırlık Raporu", systemImage: "shield.checkered")
                            .accessibilityLabel("SGK Hazırlık Raporu")
                    }
                    NavigationLink(destination: CashFlowView(hakedisler: hakedisler)) {
                        Label("Nakit Akış Analizi", systemImage: "arrow.left.arrow.right.circle")
                            .accessibilityLabel("Nakit Akış Analizi")
                    }
                    NavigationLink(destination: CashFlowProjectionView()) {
                        Label("Nakit Akış Projeksiyonu", systemImage: "chart.line.uptrend.xyaxis")
                            .accessibilityLabel("Nakit Akış Projeksiyonu")
                    }
                    NavigationLink(destination: ProgressReportListView()) {
                        Label("İlerleme Raporları", systemImage: "camera.viewfinder")
                            .accessibilityLabel("İlerleme Raporları")
                    }
                }
                Section("İş Programı") {
                    NavigationLink(destination: ActivityListView()) {
                        Label("İş Programı", systemImage: "chart.bar.xaxis")
                            .accessibilityLabel("İş Programı")
                    }
                    NavigationLink(destination: ScheduleComparisonView()) {
                        Label("Program Karşılaştırma", systemImage: "arrow.left.arrow.right")
                            .accessibilityLabel("Program Karşılaştırma")
                    }
                }

                Section("Keşif & İhale") {
                    NavigationLink(destination: SurveyListView()) {
                        Label("Keşif Çalışmaları", systemImage: "ruler")
                            .accessibilityLabel("Keşif Çalışmaları")
                    }
                    NavigationLink(destination: BidPreparationView()) {
                        Label("İhale Hazırlık", systemImage: "doc.text.magnifyingglass")
                            .accessibilityLabel("İhale Hazırlık")
                    }
                    NavigationLink(destination: ApproximateCostView()) {
                        Label("Yaklaşık Maliyet", systemImage: "dollarsign.circle")
                            .accessibilityLabel("Yaklaşık Maliyet")
                    }
                }

                Section("Mevzuat Referans") {
                    NavigationLink(destination: LegalReferenceView()) {
                        Label("4734 / 4735 Kanun Referansı", systemImage: "book.closed")
                            .accessibilityLabel("Mevzuat referansı")
                    }
                }

                Section("Kütüphane") {
                    NavigationLink(destination: PozLibraryView(onSelect: { _, _ in })) {
                        Label("Poz Kütüphanesi", systemImage: "books.vertical")
                            .accessibilityLabel("Poz Kütüphanesi")
                    }
                }

                Section("Dokümanlar") {
                    NavigationLink(destination: DocumentListView()) {
                        Label("Proje Dokümanları", systemImage: "doc.fill")
                            .accessibilityLabel("Proje doküman yönetimi")
                    }
                }

                Section("Toplantılar") {
                    NavigationLink(destination: MeetingListView()) {
                        Label("Tüm Toplantılar", systemImage: "person.3.fill")
                            .accessibilityLabel("Toplantı listesi")
                    }
                    NavigationLink(destination: DecisionTrackingView()) {
                        Label("Karar Takibi", systemImage: "checklist")
                            .accessibilityLabel("Toplantı kararları takibi")
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
