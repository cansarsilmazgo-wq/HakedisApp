import SwiftUI
import SwiftData

struct MoreTabView: View {
    @Query private var hakedisler: [Hakedis]
    var body: some View {
        NavigationStack {
            List {
                Section("Raporlar") {
                    NavigationLink(destination: ReportListView()) {
                        Label("Rapor Oluşturucu", systemImage: "doc.text.below.ecg")
                            .accessibilityLabel("Rapor Oluşturucu")
                    }
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
                Section("Kabul İşlemleri") {
                    NavigationLink(destination: ProvisionalAcceptanceView()) {
                        Label("Geçici Kabul", systemImage: "checkmark.seal")
                            .accessibilityLabel("Geçici Kabul")
                    }
                    NavigationLink(destination: FinalAcceptanceView()) {
                        Label("Kesin Kabul", systemImage: "checkmark.seal.fill")
                            .accessibilityLabel("Kesin Kabul")
                    }
                    NavigationLink(destination: DeficiencyTrackingView()) {
                        Label("Eksiklik Takibi", systemImage: "list.bullet.clipboard")
                            .accessibilityLabel("Eksiklik Takibi")
                    }
                }

                Section("Saha İletişim") {
                    NavigationLink(destination: WorkOrderListView()) {
                        Label("İş Emirleri", systemImage: "doc.badge.gearshape")
                            .accessibilityLabel("İş Emirleri")
                    }
                    NavigationLink(destination: RFIListView()) {
                        Label("Teknik Sorular (RFI)", systemImage: "questionmark.circle")
                            .accessibilityLabel("Teknik Sorular")
                    }
                    NavigationLink(destination: SiteAnnouncementView()) {
                        Label("Şantiye Duyuruları", systemImage: "megaphone")
                            .accessibilityLabel("Şantiye Duyuruları")
                    }
                }

                Section("Çizim & Pinler") {
                    NavigationLink(destination: DrawingPinListView()) {
                        Label("Çizim Pinleri", systemImage: "mappin.and.ellipse")
                            .accessibilityLabel("Çizim Pinleri")
                    }
                    NavigationLink(destination: PhotoComparisonView()) {
                        Label("Fotoğraf Karşılaştırma", systemImage: "photo.stack")
                            .accessibilityLabel("Fotoğraf Karşılaştırma")
                    }
                    NavigationLink(destination: DrawingAnnotationView()) {
                        Label("Çizim Anotasyonu", systemImage: "pencil.and.ruler.fill")
                            .accessibilityLabel("Çizim Anotasyonu")
                    }
                }

                Section("Maliyet Kontrol") {
                    NavigationLink(destination: BudgetView()) {
                        Label("Bütçe Yönetimi", systemImage: "dollarsign.circle")
                            .accessibilityLabel("Bütçe Yönetimi")
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

                Section("Veri Yönetimi") {
                    NavigationLink(destination: BackupView()) {
                        Label("Yedekleme", systemImage: "externaldrive.badge.checkmark")
                            .accessibilityLabel("Yedekleme")
                    }
                    NavigationLink(destination: SyncStatusView()) {
                        Label("iCloud Senkronizasyonu", systemImage: "icloud.and.arrow.up.fill")
                            .accessibilityLabel("iCloud Senkronizasyonu")
                    }
                }

                Section("Gizlilik & Güvenlik") {
                    NavigationLink(destination: KVKKConsentView()) {
                        Label("KVKK Aydınlatma", systemImage: "person.badge.shield.checkmark")
                            .accessibilityLabel("KVKK Aydınlatma Metni")
                    }
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Gizlilik Politikası", systemImage: "lock.doc")
                            .accessibilityLabel("Gizlilik Politikası")
                    }
                    NavigationLink(destination: DataDeletionView()) {
                        Label("Veri Silme", systemImage: "trash.circle")
                            .accessibilityLabel("Veri Silme")
                    }
                }

                Section("Fiyat & Maliyet") {
                    NavigationLink(destination: PriceTrackerDashboardView()) {
                        Label("Fiyat Takibi", systemImage: "chart.line.uptrend.xyaxis")
                            .accessibilityLabel("Fiyat Takibi")
                    }
                    NavigationLink(destination: PriceAlertView()) {
                        Label("Fiyat Uyarıları", systemImage: "exclamationmark.triangle.fill")
                            .accessibilityLabel("Fiyat Uyarıları")
                    }
                    NavigationLink(destination: MonthlyDeclarationsView()) {
                        Label("Beyannameler", systemImage: "doc.badge.checkmark")
                            .accessibilityLabel("Beyannameler")
                    }
                }

                Section("Özel Modüller") {
                    NavigationLink(destination: UrbanRenewalListView()) {
                        Label("Kentsel Dönüşüm", systemImage: "building.2.fill")
                            .accessibilityLabel("Kentsel Dönüşüm")
                    }
                    NavigationLink(destination: SeismicAssessmentListView()) {
                        Label("Deprem Risk", systemImage: "waveform.path.ecg.rectangle.fill")
                            .accessibilityLabel("Deprem Risk Değerlendirme")
                    }
                    NavigationLink(destination: ProjectMapView()) {
                        Label("Proje Haritası", systemImage: "map.fill")
                            .accessibilityLabel("Proje Haritası")
                    }
                    NavigationLink(destination: WeatherDashboardView()) {
                        Label("Hava Durumu", systemImage: "cloud.sun.fill")
                            .accessibilityLabel("Hava Durumu")
                    }
                    NavigationLink(destination: AttendanceQRListView()) {
                        Label("QR Yoklama", systemImage: "qrcode.viewfinder")
                            .accessibilityLabel("QR Yoklama")
                    }
                    NavigationLink(destination: DisputeManagementView()) {
                        Label("Taşeron İtirazları", systemImage: "exclamationmark.bubble.fill")
                            .accessibilityLabel("Taşeron İtirazları")
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
