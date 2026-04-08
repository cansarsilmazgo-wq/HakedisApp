import XCTest
import SwiftData

// MARK: - FAZ 11: İtiraz Yönetimi Tests

final class ObjectionTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Project.self, Contract.self, WorkItem.self, DailyEntry.self,
                             Hakedis.self, HakedisItem.self, Payment.self, Objection.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Enum Tests

    func testObjectionCategoryAllCases() {
        XCTAssertEqual(ObjectionCategory.allCases.count, 5)
        XCTAssertEqual(ObjectionCategory.miktar.rawValue, "Miktar İtirazı")
        XCTAssertEqual(ObjectionCategory.fiyat.rawValue, "Fiyat İtirazı")
        XCTAssertEqual(ObjectionCategory.kesinti.rawValue, "Kesinti İtirazı")
    }

    func testObjectionStatusAllCases() {
        XCTAssertEqual(ObjectionStatus.allCases.count, 5)
        XCTAssertEqual(ObjectionStatus.acik.rawValue, "Açık")
        XCTAssertEqual(ObjectionStatus.kabul.rawValue, "Kabul Edildi")
        XCTAssertEqual(ObjectionStatus.red.rawValue, "Reddedildi")
    }

    // MARK: - Model Tests

    func testObjectionCreation() {
        let obj = Objection(objectionNumber: "ITR-2026-001", reason: "Miktar fazla kesildi",
                            category: .miktar, claimedAmount: 15000)
        context.insert(obj)
        try? context.save()

        XCTAssertEqual(obj.objectionNumber, "ITR-2026-001")
        XCTAssertEqual(obj.reason, "Miktar fazla kesildi")
        XCTAssertEqual(obj.category, .miktar)
        XCTAssertEqual(obj.claimedAmount, 15000, accuracy: 0.01)
        XCTAssertEqual(obj.status, .acik)
        XCTAssertEqual(obj.approvedAmount, 0)
    }

    func testObjectionDeadlineDate() {
        let obj = Objection(objectionNumber: "ITR-2026-001", reason: "Test",
                            category: .diger, claimedAmount: 0)
        let expectedDeadline = Calendar.current.date(byAdding: .day, value: 30, to: obj.objectionDate)!
        XCTAssertEqual(obj.deadlineDate.timeIntervalSince1970,
                       expectedDeadline.timeIntervalSince1970, accuracy: 1.0)
    }

    func testObjectionDeadlineApproachingWhenRecent() {
        // Brand new objection has 30 days, not approaching
        let obj = Objection(objectionNumber: "ITR-2026-001", reason: "Test",
                            category: .diger, claimedAmount: 0)
        XCTAssertFalse(obj.isDeadlineApproaching)
    }

    func testObjectionStatusChange() {
        let obj = Objection(objectionNumber: "ITR-2026-001", reason: "Test",
                            category: .miktar, claimedAmount: 5000)
        context.insert(obj)
        obj.status = .incelemede
        try? context.save()
        XCTAssertEqual(obj.status, .incelemede)
    }

    func testObjectionResponseFields() {
        let obj = Objection(objectionNumber: "ITR-2026-001", reason: "Test",
                            category: .miktar, claimedAmount: 5000)
        context.insert(obj)
        obj.status = .kismiKabul
        obj.approvedAmount = 3000
        obj.responseNote = "Kısmi kabul edildi"
        obj.responseDate = Date()
        try? context.save()

        XCTAssertEqual(obj.approvedAmount, 3000, accuracy: 0.01)
        XCTAssertEqual(obj.responseNote, "Kısmi kabul edildi")
        XCTAssertNotNil(obj.responseDate)
    }

    // MARK: - Number Generation Tests

    func testObjectionNumberGeneration() {
        let number = Objection.generateNumber(existing: [])
        let year = Calendar.current.component(.year, from: Date())
        XCTAssertTrue(number.hasPrefix("ITR-\(year)-"))
        XCTAssertEqual(number, "ITR-\(year)-001")
    }

    func testObjectionNumberIncrement() {
        let obj1 = Objection(objectionNumber: "ITR-2026-001", reason: "Test1",
                             category: .miktar, claimedAmount: 0)
        context.insert(obj1)
        let number2 = Objection.generateNumber(existing: [obj1])
        XCTAssertEqual(number2, "ITR-2026-002")
    }

    // MARK: - SwiftData Query Tests

    func testObjectionPersistsInContext() throws {
        let obj = Objection(objectionNumber: "ITR-2026-001", reason: "Test",
                            category: .fiyat, claimedAmount: 8000)
        context.insert(obj)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Objection>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.claimedAmount ?? 0, 8000, accuracy: 0.01)
    }

    func testObjectionLinkedToHakedis() throws {
        let project = Project(name: "Proje")
        let contract = Contract(title: "Sözleşme")
        project.contracts.append(contract)
        context.insert(project)

        let hakedis = Hakedis(periodName: "1. Dönem", periodStart: Date(), periodEnd: Date())
        contract.hakedisler.append(hakedis)

        let obj = Objection(objectionNumber: "ITR-2026-001", reason: "İtiraz",
                            category: .kesinti, claimedAmount: 12000)
        obj.relatedHakedis = hakedis
        context.insert(obj)
        try context.save()

        XCTAssertEqual(obj.relatedHakedis?.periodName, "1. Dönem")
    }
}
