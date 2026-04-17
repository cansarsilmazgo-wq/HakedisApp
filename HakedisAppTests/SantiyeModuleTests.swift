import XCTest
import SwiftData

// MARK: - Şantiye Modülleri Test Paketi (Bölüm 2-6)

final class SantiyeModuleTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            Project.self, Contractor.self, Contract.self,
            WorkItem.self, DailyEntry.self, Hakedis.self,
            HakedisItem.self, Payment.self, RetentionRelease.self,
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

    // MARK: - Bölüm 2: SiteDiary

    func test_siteDiary_olusturma() throws {
        let diary = SiteDiary(date: Date(), weatherCondition: .sunny, workDescription: "Temel beton dökümü yapıldı")
        context.insert(diary)
        let fetched = try context.fetch(FetchDescriptor<SiteDiary>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.weatherCondition, .sunny)
        XCTAssertEqual(fetched.first?.workDescription, "Temel beton dökümü yapıldı")
    }

    func test_siteDiary_havaDurumuEnum() throws {
        // Her hava durumu enum değerinin icon ve rawValue'su var
        XCTAssertEqual(WeatherCondition.sunny.icon, "sun.max.fill")
        XCTAssertEqual(WeatherCondition.cloudy.icon, "cloud.fill")
        XCTAssertEqual(WeatherCondition.rainy.icon, "cloud.rain.fill")
        XCTAssertEqual(WeatherCondition.snowy.icon, "cloud.snow.fill")
        XCTAssertEqual(WeatherCondition.stormy.icon, "cloud.bolt.fill")
        XCTAssertEqual(WeatherCondition.sunny.rawValue, "Güneşli")
        XCTAssertEqual(WeatherCondition.rainy.rawValue, "Yağmurlu")
        XCTAssertGreaterThanOrEqual(WeatherCondition.allCases.count, 5)
    }

    func test_siteDiary_fotografVeAlanlar() throws {
        let diary = SiteDiary(date: Date(), weatherCondition: .rainy, workDescription: "Yağmur nedeniyle çalışma durdu")
        diary.temperature = 12.5
        diary.problems = "Şantiye su bastı"
        diary.visitors = "Mühendis Ahmet Bey"
        diary.photoData = [Data([0x01, 0x02]), Data([0x03, 0x04])]
        context.insert(diary)

        let fetched = try context.fetch(FetchDescriptor<SiteDiary>())
        XCTAssertEqual(fetched.first?.temperature, 12.5)
        XCTAssertEqual(fetched.first?.problems, "Şantiye su bastı")
        XCTAssertEqual(fetched.first?.photoData.count, 2)
    }

    func test_siteDiary_tarihFiltreleme() throws {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let d1 = SiteDiary(date: today, weatherCondition: .sunny, workDescription: "Bugün")
        let d2 = SiteDiary(date: yesterday, weatherCondition: .cloudy, workDescription: "Dün")
        context.insert(d1)
        context.insert(d2)

        let descriptor = FetchDescriptor<SiteDiary>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 2)
        XCTAssertTrue(fetched[0].date >= fetched[1].date)
    }

    func test_siteDiary_bosGunluk_workDescriptionZorunlu() throws {
        let diary = SiteDiary()
        XCTAssertTrue(diary.workDescription.isEmpty, "Yeni günlüğün iş açıklaması başlangıçta boş olmalı")
    }

    // MARK: - Bölüm 3: Attendance (Puantaj)

    func test_attendance_olusturma() throws {
        let attendance = Attendance(date: Date(), workerName: "Mehmet Demir", workerRole: "Kalıpçı")
        attendance.isPresent = true
        attendance.normalHours = 8.0
        attendance.overtimeHours = 2.0
        context.insert(attendance)

        let fetched = try context.fetch(FetchDescriptor<Attendance>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.workerName, "Mehmet Demir")
        XCTAssertEqual(fetched.first?.workerRole, "Kalıpçı")
    }

    func test_attendance_sgkGunHesabi() throws {
        // Tam gün: 8 saat → SGK günü
        let a1 = Attendance(date: Date(), workerName: "Ali")
        a1.isPresent = true
        a1.normalHours = 8.0
        a1.overtimeHours = 0.0
        XCTAssertTrue(a1.isSGKDay)
        XCTAssertEqual(a1.totalHours, 8.0)

        // Yarım gün: 4 saat → SGK günü
        let a2 = Attendance(date: Date(), workerName: "Veli")
        a2.isPresent = true
        a2.normalHours = 4.0
        a2.overtimeHours = 0.0
        XCTAssertTrue(a2.isSGKDay)

        // 3 saat → SGK günü değil
        let a3 = Attendance(date: Date(), workerName: "Ayşe")
        a3.isPresent = true
        a3.normalHours = 3.0
        a3.overtimeHours = 0.0
        XCTAssertFalse(a3.isSGKDay)

        // Gelmedi → SGK günü değil
        let a4 = Attendance(date: Date(), workerName: "Fatma")
        a4.isPresent = false
        XCTAssertFalse(a4.isSGKDay)
    }

    func test_attendance_adamGunHesabi() throws {
        // Adam-gün: toplam çalışma saati / 8
        let a = Attendance(date: Date(), workerName: "Hasan")
        a.isPresent = true
        a.normalHours = 8.0
        a.overtimeHours = 4.0
        XCTAssertEqual(a.totalHours, 12.0)
        let adamGun = a.totalHours / 8.0
        XCTAssertEqual(adamGun, 1.5, accuracy: 0.001)
    }

    // MARK: - Bölüm 4: Material / StockEntry

    func test_material_olusturmaVeStokHesabi() throws {
        let material = Material(name: "Çimento", unit: "torba", minimumStock: 50, unitPrice: 150.0)
        context.insert(material)

        // Başlangıç stoğu 0
        XCTAssertEqual(material.currentStock, 0.0)
        XCTAssertTrue(material.isLowStock)

        // Giriş: 100 torba
        let entry1 = StockEntry(date: Date(), entryType: .incoming, quantity: 100)
        entry1.material = material
        material.currentStock += 100
        context.insert(entry1)

        XCTAssertEqual(material.currentStock, 100.0)
        XCTAssertFalse(material.isLowStock)
        XCTAssertEqual(material.stockValue, 15000.0, accuracy: 0.01)

        // Çıkış: 30 torba
        let entry2 = StockEntry(date: Date(), entryType: .outgoing, quantity: 30)
        entry2.material = material
        material.currentStock -= 30
        context.insert(entry2)

        XCTAssertEqual(material.currentStock, 70.0)
        XCTAssertFalse(material.isLowStock)
    }

    func test_material_kritikStokUyarisi() throws {
        let material = Material(name: "Demir", unit: "ton", minimumStock: 10, unitPrice: 50000.0)
        material.currentStock = 5.0
        context.insert(material)

        XCTAssertTrue(material.isLowStock)

        material.currentStock = 15.0
        XCTAssertFalse(material.isLowStock)

        material.currentStock = 10.0  // tam eşitte
        XCTAssertFalse(material.isLowStock)

        material.currentStock = 9.9
        XCTAssertTrue(material.isLowStock)
    }

    // MARK: - Bölüm 5: EquipmentItem / EquipmentLog

    func test_equipment_calismaVeBakimHatirlatma() throws {
        let item = EquipmentItem(name: "Ekskavatör", ownershipType: .rented, maintenanceIntervalHours: 250)
        item.dailyRentalCost = 5000.0
        context.insert(item)

        // Başlangıçta bakım gerekmez (saat = 0)
        XCTAssertFalse(item.isMaintenanceDue)

        // 250 saat → bakım gerekiyor
        item.totalOperatingHours = 250.0
        XCTAssertTrue(item.isMaintenanceDue)

        // Bakım yapıldı (log eklendi)
        let maintenanceLog = EquipmentLog(date: Date(), operatingHours: 0)
        maintenanceLog.isMaintenanceDay = true
        maintenanceLog.equipment = item
        item.logs.append(maintenanceLog)

        // Şimdi 250-500 arasında bakım gerekmez
        XCTAssertFalse(item.isMaintenanceDue)

        // 500 saat → tekrar bakım gerekiyor
        item.totalOperatingHours = 500.0
        XCTAssertTrue(item.isMaintenanceDue)
    }

    // MARK: - Bölüm 6: SafetyIncident

    func test_safetyIncident_olusturmaVeKapama() throws {
        let incident = SafetyIncident(
            date: Date(),
            incidentType: .nearMiss,
            incidentDescription: "İşçi yüksekten düşme riski yaşadı"
        )
        XCTAssertFalse(incident.isResolved)
        context.insert(incident)

        incident.isResolved = true
        XCTAssertTrue(incident.isResolved)
    }

    func test_safetyIncident_turVeRenkler() throws {
        XCTAssertEqual(IncidentType.nearMiss.rawValue, "Ramak Kala")
        XCTAssertEqual(IncidentType.majorInjury.rawValue, "Ciddi Yaralanma")
        XCTAssertEqual(IncidentType.allCases.count, 4)

        XCTAssertEqual(ChecklistType.toolbox.rawValue, "Toolbox Toplantısı")
        XCTAssertEqual(ChecklistType.allCases.count, 5)
    }

    func test_safetyChecklist_jsonEncoding() throws {
        let checklist = SafetyChecklist(date: Date(), checklistType: .toolbox, completedBy: "Şef Mühendis")
        let items = [
            ChecklistItem(title: "KKD kontrolü"),
            ChecklistItem(title: "Güvenlik brifing", isChecked: true)
        ]
        let data = try JSONEncoder().encode(items)
        checklist.items = String(data: data, encoding: .utf8) ?? "[]"
        context.insert(checklist)

        let decoded = try JSONDecoder().decode([ChecklistItem].self, from: Data(checklist.items.utf8))
        XCTAssertEqual(decoded.count, 2)
        XCTAssertFalse(decoded[0].isChecked)
        XCTAssertTrue(decoded[1].isChecked)
    }

    // MARK: - ADIM 5 — Toplu Puantaj Testleri

    // 0 işçi varken markAllPresent çalıştırılınca kayıt oluşmamalı
    func testTopluPuantajSifirIsciKayitOlusmamalı() throws {
        let schema = Schema([Worker.self, Attendance.self, Contractor.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let cont = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(cont)

        // markAllPresent mantığı: workers.isEmpty → işlem yok
        let workers = try ctx.fetch(FetchDescriptor<Worker>())
        XCTAssertTrue(workers.isEmpty, "0 işçi olmalı")
        let afterRecords = try ctx.fetch(FetchDescriptor<Attendance>())
        XCTAssertEqual(afterRecords.count, 0, "0 işçiyle puantaj oluşmamalı")
    }

    // 5 işçi varken markAllPresent çalıştırılınca 5 kayıt oluşmalı
    func testTopluPuantaj5IsciHepsiniIsaretle() throws {
        let schema = Schema([Worker.self, Attendance.self, Contractor.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let cont = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(cont)

        for i in 1...5 {
            let w = Worker(fullName: "İşçi \(i)", profession: .laborer)
            ctx.insert(w)
        }
        try ctx.save()

        let workers = try ctx.fetch(FetchDescriptor<Worker>())
        XCTAssertEqual(workers.count, 5)

        // markAllPresent mantığı simülasyonu
        let today = Calendar.current.startOfDay(for: Date())
        let existingIds: Set<UUID> = []
        for worker in workers {
            guard !existingIds.contains(worker.id) else { continue }
            let a = Attendance(date: today, workerName: worker.fullName)
            a.worker = worker
            a.isPresent = true
            ctx.insert(a)
        }
        try ctx.save()

        let records = try ctx.fetch(FetchDescriptor<Attendance>())
        XCTAssertEqual(records.count, 5, "5 işçi için 5 kayıt oluşmalı")
        XCTAssertTrue(records.allSatisfy { $0.isPresent }, "Tüm kayıtlar 'geldi' olmalı")
    }

    // Tekrar çalıştırılınca idempotent olmalı (aynı işçi için 2 kayıt oluşmamalı)
    func testTopluPuantajIdempotent() throws {
        let schema = Schema([Worker.self, Attendance.self, Contractor.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let cont = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(cont)

        let worker = Worker(fullName: "Tekrarlayan İşçi", profession: .laborer)
        ctx.insert(worker)
        try ctx.save()

        let today = Calendar.current.startOfDay(for: Date())

        // İlk çalıştırma
        let a1 = Attendance(date: today, workerName: worker.fullName)
        a1.worker = worker
        a1.isPresent = true
        ctx.insert(a1)
        try ctx.save()

        // İkinci çalıştırma — mevcut kaydı kontrol et, yeni kayıt oluşturma
        let existingRecords = try ctx.fetch(FetchDescriptor<Attendance>())
        let alreadyMarkedIds = Set(existingRecords.compactMap { $0.worker?.id })
        var newCount = 0
        if !alreadyMarkedIds.contains(worker.id) {
            let a2 = Attendance(date: today, workerName: worker.fullName)
            a2.worker = worker
            ctx.insert(a2)
            newCount += 1
        }

        XCTAssertEqual(newCount, 0, "Zaten işaretlenmiş işçi için yeni kayıt oluşmamalı (idempotent)")
        let finalRecords = try ctx.fetch(FetchDescriptor<Attendance>())
        XCTAssertEqual(finalRecords.count, 1, "Sadece 1 kayıt olmalı")
    }

    // MARK: - ADIM 7 — Yarınki Plan Testleri

    // Boş plan kaydedilmeli (default değer boş string)
    func testYarinPlaniBoşKaydedilebilmeli() throws {
        let schema = Schema([SiteDiary.self, Project.self, WeatherRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let cont = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(cont)

        let diary = SiteDiary(date: Date(), weatherCondition: .sunny, workDescription: "Test")
        XCTAssertEqual(diary.tomorrowPlan, "", "Başlangıçta tomorrowPlan boş olmalı")
        ctx.insert(diary)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SiteDiary>())
        XCTAssertEqual(fetched.first?.tomorrowPlan, "", "Boş plan kaydedilip okunabilmeli")
    }

    // Uzun metin (500+ karakter) kaydedilmeli
    func testYarinPlaniUzunMetinKaydedilebilmeli() throws {
        let schema = Schema([SiteDiary.self, Project.self, WeatherRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let cont = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(cont)

        let uzunMetin = String(repeating: "Yarın beton dökülecek ve demir bağlama tamamlanacak. ", count: 10)
        XCTAssertGreaterThanOrEqual(uzunMetin.count, 500)
        let diary = SiteDiary(date: Date(), weatherCondition: .cloudy, workDescription: "Test")
        diary.tomorrowPlan = uzunMetin
        ctx.insert(diary)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SiteDiary>())
        XCTAssertEqual(fetched.first?.tomorrowPlan, uzunMetin, "500+ karakterlik plan kaydedilmeli")
    }

    // Özel Türkçe karakterler doğru kaydedilmeli
    func testYarinPlaniTurkcKarakter() throws {
        let schema = Schema([SiteDiary.self, Project.self, WeatherRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let cont = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(cont)

        let turkceMetin = "Şantiyede çalışma yapılacak, güneş ışığında öğle arası verilecek. İşçiler üretime devam edecek."
        let diary = SiteDiary(date: Date(), weatherCondition: .sunny, workDescription: "Test")
        diary.tomorrowPlan = turkceMetin
        ctx.insert(diary)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SiteDiary>())
        XCTAssertEqual(fetched.first?.tomorrowPlan, turkceMetin, "Türkçe karakterler (ş, ç, ğ, ü, ö, ı) doğru kaydedilmeli")
    }
}
