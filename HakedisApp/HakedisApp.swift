import SwiftUI
import SwiftData

@main
struct HakedisApp: App {
    private let modelContainer: ModelContainer?
    private let dbError: String?

    init() {
        let schema = Schema([
            Project.self, Contractor.self, Contract.self, WorkItem.self,
            DailyEntry.self, Hakedis.self, HakedisItem.self, Payment.self,
            RetentionRelease.self, ChangeOrder.self, Milestone.self, SiteReport.self,
            ApprovalStep.self, HakedisRevision.self, UnitPriceAnalysis.self,
            SiteHandoverRecord.self, SiteDeficiency.self, MeasurementEntry.self,
            PhotoAnnotation.self, LaborRecord.self,
            MaterialRecord.self, MaterialTransaction.self, SpecificationItem.self,
            CorrespondenceRecord.self, PriceDifferenceRecord.self,
            VATWithholdingRecord.self, SGKLaborRecord.self, SiteLogEntry.self,
            Equipment.self, EquipmentUsage.self,
            SoilRecord.self, TestRecord.self,
            AcceptanceRecord.self, WarrantyClaim.self,
            Guarantee.self,
            SiteDiary.self,
            Attendance.self,
            Material.self, StockEntry.self,
            Supplier.self, MaterialOrder.self, MaterialTestResult.self, MaterialRequest.self,
            EquipmentItem.self, EquipmentLog.self,
            EquipmentFailure.self, MaintenancePlan.self, RentalContract.self,
            SafetyIncident.self, SafetyChecklist.self,
            AttachmentRecord.self,
            PriceDifferenceCalc.self,
            SubcontractorHakedis.self,
            QualityChecklist.self,
            TimeExtensionRequest.self,
            WorkChangeOrder.self,
            ProgressReport.self,
            Worker.self,
            WorkerCertificate.self
        ])

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupport.appendingPathComponent("hakedis.store")
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
            self.dbError = nil
        } catch {
            // Schema uyumsuzluğu → SQLite store + WAL dosyalarını sil, yeniden dene
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
            do {
                self.modelContainer = try ModelContainer(for: schema, configurations: [config])
                self.dbError = nil
            } catch {
                self.modelContainer = nil
                self.dbError = error.localizedDescription
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .modelContainer(container)
                    // FIX-23: İlk açılışta bildirim izni iste
                    .onAppear {
                        NotificationManager.shared.requestPermission()
                    }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.orange)
                    Text("Veritabanı Başlatılamadı")
                        .font(.title2.bold())
                    Text(dbError ?? "Bilinmeyen hata")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Text("Uygulamayı kapatıp yeniden açın.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}
