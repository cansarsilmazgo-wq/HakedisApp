import XCTest
import SwiftData

// MARK: - PDF Generator Tests

final class PDFGeneratorTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            Project.self, Contractor.self, Contract.self,
            WorkItem.self, DailyEntry.self, Hakedis.self, HakedisItem.self,
            Payment.self, RetentionRelease.self,
            SiteDiary.self, Attendance.self,
            Material.self, StockEntry.self,
            EquipmentItem.self, EquipmentLog.self,
            SafetyIncident.self, SafetyChecklist.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - SiteDiaryPDFGenerator

    func test_siteDiaryPDF_gunluk_gecerliPDFOlusturur() throws {
        // Hazırlık: içerik dolu bir günlük
        let diary = SiteDiary(
            date: Date(),
            weatherCondition: .sunny,
            workDescription: "Zemin katı kolon kalıpları kuruldu. Toplam 12 adet kolon tamamlandı."
        )
        diary.temperature = 24.0
        diary.problems = "Beton vibratörü arızalandı, yedek getirildi."
        diary.visitors = "Şantiye Şefi Murat Bey"
        diary.notes = "Yarın beton dökümü planlanıyor."

        // 2 sahte fotoğraf verisi (minimum geçerli JPEG)
        diary.photoData = [makeMinimalJPEG(), makeMinimalJPEG()]
        context.insert(diary)

        // Test: PDF üretilmeli ve içerik boş olmamalı
        let data = SiteDiaryPDFGenerator.generateDaily(diary: diary)

        XCTAssertFalse(data.isEmpty, "PDF verisi boş olmamalı")
        XCTAssertGreaterThan(data.count, 1024, "Geçerli bir PDF en az 1 KB olmalı")
        // PDF magic bytes: %PDF-
        let header = data.prefix(5)
        XCTAssertEqual(String(bytes: header, encoding: .ascii), "%PDF-", "Geçerli PDF başlığı bekleniyor")
    }

    func test_siteDiaryPDF_haftalik_cokluGunluk() throws {
        // Hazırlık: 4 günlük, aynı hafta
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekday = 2 // Pazartesi
        let monday = cal.date(from: comps) ?? Date()

        let topics = ["Temel kazı", "Kolon kalıbı", "Beton dökümü", "Kalıp sökümü"]
        for (i, topic) in topics.enumerated() {
            let d = SiteDiary(
                date: cal.date(byAdding: .day, value: i, to: monday)!,
                weatherCondition: .cloudy,
                workDescription: topic
            )
            context.insert(d)
        }

        let data = SiteDiaryPDFGenerator.generateWeekly(
            diaries: topics.enumerated().map { (i, topic) in
                SiteDiary(
                    date: cal.date(byAdding: .day, value: i, to: monday)!,
                    weatherCondition: .cloudy,
                    workDescription: topic
                )
            },
            weekStart: monday
        )

        XCTAssertFalse(data.isEmpty)
        XCTAssertGreaterThan(data.count, 1024)
        let header = data.prefix(5)
        XCTAssertEqual(String(bytes: header, encoding: .ascii), "%PDF-")
    }

    func test_siteDiaryPDF_haftalik_bosGunluk_gecerliPDF() throws {
        // Boş liste için de geçerli PDF üretilmeli
        let data = SiteDiaryPDFGenerator.generateWeekly(diaries: [], weekStart: Date())
        XCTAssertFalse(data.isEmpty)
        XCTAssertGreaterThan(data.count, 512)
    }

    // MARK: - AttendancePDFGenerator

    func test_attendancePDF_aylikPuantaj_gecerliPDFOlusturur() throws {
        // Hazırlık: Mart 2025 için 3 işçi, çeşitli devam kayıtları
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 3
        comps.day = 1
        let march2025 = cal.date(from: comps)!

        let workers = ["Ali Yılmaz", "Mehmet Demir", "Veli Kaya"]
        var records: [Attendance] = []

        for worker in workers {
            for day in [1, 2, 3, 5, 6, 7, 8, 10, 11, 12, 15, 16, 17, 18, 19, 22, 23, 24, 25, 26] {
                comps.day = day
                let date = cal.date(from: comps)!
                let rec = Attendance(date: date, workerName: worker)
                rec.isPresent = true
                rec.normalHours = 8.0
                rec.overtimeHours = (day % 5 == 0) ? 2.0 : 0.0
                context.insert(rec)
                records.append(rec)
            }
        }

        // Devamsızlık örneği
        comps.day = 4
        let absent = Attendance(date: cal.date(from: comps)!, workerName: "Ali Yılmaz")
        absent.isPresent = false
        context.insert(absent)
        records.append(absent)

        let data = AttendancePDFGenerator.generateMonthly(
            records: records,
            month: march2025,
            projectName: "Test Projesi A"
        )

        XCTAssertFalse(data.isEmpty, "PDF verisi boş olmamalı")
        XCTAssertGreaterThan(data.count, 1024, "Geçerli bir PDF en az 1 KB olmalı")
        let header = data.prefix(5)
        XCTAssertEqual(String(bytes: header, encoding: .ascii), "%PDF-", "Geçerli PDF başlığı bekleniyor")
    }

    func test_attendancePDF_bosKayit_gecerliPDF() throws {
        // Kayıt yokken bile geçerli PDF üretilmeli
        let data = AttendancePDFGenerator.generateMonthly(records: [], month: Date(), projectName: nil)
        XCTAssertFalse(data.isEmpty)
        XCTAssertGreaterThan(data.count, 512)
    }

    func test_attendancePDF_adamGunHesabi_dogrulanir() throws {
        // SGK günü ve adam-gün hesabı doğruluğunu dolaylı test et:
        // 10 gün × 8 saat = 10 adam-gün, 10 SGK günü
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2025; comps.month = 4
        var records: [Attendance] = []
        for day in 1...10 {
            comps.day = day
            let rec = Attendance(date: cal.date(from: comps)!, workerName: "Test İşçi")
            rec.isPresent = true
            rec.normalHours = 8.0
            rec.overtimeHours = 0.0
            records.append(rec)
        }

        let manDays = records.filter { $0.isPresent }.reduce(0.0) { $0 + $1.totalHours / 8.0 }
        let sgkDays = records.filter { $0.isSGKDay }.count
        XCTAssertEqual(manDays, 10.0, accuracy: 0.001)
        XCTAssertEqual(sgkDays, 10)

        comps.day = 1
        let pdfData = AttendancePDFGenerator.generateMonthly(
            records: records,
            month: cal.date(from: comps)!,
            projectName: "Hesap Testi"
        )
        XCTAssertFalse(pdfData.isEmpty)
    }

    // MARK: - Helpers

    /// Minimum geçerli JPEG verisi üretir (1×1 beyaz piksel)
    private func makeMinimalJPEG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.jpegData(withCompressionQuality: 0.5) { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}
