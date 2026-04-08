import SwiftUI
import SwiftData

struct MoreTabView: View {
    @Query private var hakedisler: [Hakedis]
    @StateObject private var authManager = AuthManager.shared

    private var role: UserRole { authManager.currentRole }

    var body: some View {
        NavigationStack {
            List {

                // MARK: 1 — Proje Yönetimi
                Section("Proje Yönetimi") {
                    NavigationLink(destination: DocumentListView()) {
                        Label("Proje Dokümanları", systemImage: "doc.fill")
                            .accessibilityLabel("Proje Dokümanları")
                    }
                    NavigationLink(destination: MeetingListView()) {
                        Label("Tüm Toplantılar", systemImage: "person.3.fill")
                            .accessibilityLabel("Toplantı listesi")
                    }
                    NavigationLink(destination: DecisionTrackingView()) {
                        Label("Karar Takibi", systemImage: "checklist")
                            .accessibilityLabel("Toplantı kararları takibi")
                    }
                    NavigationLink(destination: ActivityListView()) {
                        Label("İş Programı", systemImage: "chart.bar.xaxis")
                            .accessibilityLabel("İş Programı")
                    }
                    NavigationLink(destination: ScheduleComparisonView()) {
                        Label("Program Karşılaştırma", systemImage: "arrow.left.arrow.right")
                            .accessibilityLabel("Program Karşılaştırma")
                    }
                    NavigationLink(destination: DrawingPinListView()) {
                        Label("Çizim Pinleri", systemImage: "mappin.and.ellipse")
                            .accessibilityLabel("Çizim Pinleri")
                    }
                    NavigationLink(destination: DrawingAnnotationView()) {
                        Label("Çizim Anotasyonu", systemImage: "pencil.and.ruler.fill")
                            .accessibilityLabel("Çizim Anotasyonu")
                    }
                }

                // MARK: 2 — Saha Yönetimi
                Section("Saha Yönetimi") {
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
                    NavigationLink(destination: PhotoComparisonView()) {
                        Label("Fotoğraf Karşılaştırma", systemImage: "photo.stack")
                            .accessibilityLabel("Fotoğraf Karşılaştırma")
                    }
                    NavigationLink(destination: PhotoMapView()) {
                        Label("Fotoğraf Haritası", systemImage: "photo.on.rectangle.angled")
                            .accessibilityLabel("Fotoğraf GPS Haritası")
                    }
                    NavigationLink(destination: AttendanceQRListView()) {
                        Label("QR Yoklama", systemImage: "qrcode.viewfinder")
                            .accessibilityLabel("QR Yoklama")
                    }
                }

                // MARK: 3 — Finansal Yönetim (rol bazlı)
                if role.canSeeFinancials {
                    Section("Finansal Yönetim") {
                        NavigationLink(destination: BudgetView()) {
                            Label("Bütçe Yönetimi", systemImage: "dollarsign.circle")
                                .accessibilityLabel("Bütçe Yönetimi")
                        }
                        NavigationLink(destination: CashFlowView(hakedisler: hakedisler)) {
                            Label("Nakit Akış Analizi", systemImage: "arrow.left.arrow.right.circle")
                                .accessibilityLabel("Nakit Akış Analizi")
                        }
                        NavigationLink(destination: CashFlowProjectionView()) {
                            Label("Nakit Akış Projeksiyonu", systemImage: "chart.line.uptrend.xyaxis")
                                .accessibilityLabel("Nakit Akış Projeksiyonu")
                        }
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
                        NavigationLink(destination: AllGuaranteeListView()) {
                            Label("Teminat Mektupları", systemImage: "lock.shield")
                                .accessibilityLabel("Teminat Mektupları")
                        }
                    }
                }

                // MARK: 4 — İhale & Keşif
                Section("İhale & Keşif") {
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
                    NavigationLink(destination: PozLibraryView(onSelect: { _, _ in })) {
                        Label("Poz Kütüphanesi", systemImage: "books.vertical")
                            .accessibilityLabel("Poz Kütüphanesi")
                    }
                    NavigationLink(destination: LegalReferenceView()) {
                        Label("Mevzuat Referansı", systemImage: "book.closed")
                            .accessibilityLabel("Mevzuat referansı (4734, 4735, 6331, 4857, 5510, 3194, 6306, 4708, YIGS, TBDY)")
                    }
                }

                // MARK: 5 — Özel Modüller
                Section("Özel Modüller") {
                    NavigationLink(destination: UrbanRenewalListView()) {
                        Label("Kentsel Dönüşüm", systemImage: "building.2.fill")
                            .accessibilityLabel("Kentsel Dönüşüm")
                    }
                    NavigationLink(destination: SeismicAssessmentListView()) {
                        Label("Deprem Risk", systemImage: "waveform.path.ecg.rectangle.fill")
                            .accessibilityLabel("Deprem Risk Değerlendirme")
                    }
                    NavigationLink(destination: WeatherDashboardView()) {
                        Label("Hava Durumu", systemImage: "cloud.sun.fill")
                            .accessibilityLabel("Hava Durumu")
                    }
                    NavigationLink(destination: ProjectMapView()) {
                        Label("Proje Haritası", systemImage: "map.fill")
                            .accessibilityLabel("Proje Haritası")
                    }
                    NavigationLink(destination: ContractorPortalView()) {
                        Label("Taşeron Portal", systemImage: "person.crop.circle.badge.checkmark")
                            .accessibilityLabel("Taşeron Portal")
                    }
                    NavigationLink(destination: DisputeManagementView()) {
                        Label("Taşeron İtirazları", systemImage: "exclamationmark.bubble.fill")
                            .accessibilityLabel("Taşeron İtirazları")
                    }
                }

                // MARK: 6 — Kabul & Raporlar
                Section("Kabul & Raporlar") {
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
                    NavigationLink(destination: ProgressReportListView()) {
                        Label("İlerleme Raporları", systemImage: "camera.viewfinder")
                            .accessibilityLabel("İlerleme Raporları")
                    }
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

                // MARK: 7 — Sistem
                Section("Sistem") {
                    NavigationLink(destination: SettingsView()) {
                        Label("Ayarlar", systemImage: "gear")
                            .accessibilityLabel("Ayarlar")
                    }
                    if role.canManageUsers {
                        NavigationLink(destination: UserManagementView()) {
                            Label("Kullanıcı Yönetimi", systemImage: "person.2.badge.gearshape")
                                .accessibilityLabel("Kullanıcı Yönetimi")
                        }
                    }
                    NavigationLink(destination: BackupView()) {
                        Label("Yedekleme", systemImage: "externaldrive.badge.checkmark")
                            .accessibilityLabel("Yedekleme")
                    }
                    NavigationLink(destination: SyncStatusView()) {
                        Label("iCloud Senkronizasyonu", systemImage: "icloud.and.arrow.up.fill")
                            .accessibilityLabel("iCloud Senkronizasyonu")
                    }
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
                    NavigationLink(destination: AboutView()) {
                        Label("Hakkında", systemImage: "info.circle")
                            .accessibilityLabel("Uygulama Hakkında")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Daha Fazla")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - AboutView

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.hakedisOrange)
                        .accessibilityHidden(true)
                    Text("HakedisApp")
                        .font(.title.bold())
                    Text("v1.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Alphabi Systems")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
            }

            Section("Uygulama") {
                LabeledContent("Sürüm", value: "1.0.0")
                LabeledContent("Platform", value: "iOS 17+")
                LabeledContent("Geliştirici", value: "Alphabi Systems")
            }

            Section("Destek") {
                HStack {
                    Label("Geri Bildirim", systemImage: "envelope")
                    Spacer()
                    Text("destek@alphabisystems.com")
                        .font(.caption)
                        .foregroundColor(.hakedisOrange)
                }
                .accessibilityLabel("Geri bildirim e-postası")

                HStack {
                    Label("Gizlilik Politikası", systemImage: "lock.doc")
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundColor(.secondary)
                }
                .accessibilityLabel("Gizlilik Politikası")
            }

            Section("Lisans") {
                Text("© 2026 Alphabi Systems. Tüm hakları saklıdır.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Hakkında")
        .navigationBarTitleDisplayMode(.large)
    }
}
