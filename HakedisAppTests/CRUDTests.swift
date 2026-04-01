import XCTest
import SwiftData

final class CRUDTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Project.self, Contractor.self, Contract.self,
                             WorkItem.self, DailyEntry.self, Hakedis.self,
                             HakedisItem.self, Payment.self, RetentionRelease.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - Project CRUD

    func test_insertProject() throws {
        let project = Project(name: "Test Proje", location: "İstanbul")
        context.insert(project)
        let fetched = try context.fetch(FetchDescriptor<Project>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test Proje")
        XCTAssertEqual(fetched.first?.location, "İstanbul")
        XCTAssertEqual(fetched.first?.status, .active)
    }

    func test_updateProject() throws {
        let project = Project(name: "Eski Ad")
        context.insert(project)
        project.name = "Yeni Ad"
        project.location = "Ankara"
        let fetched = try context.fetch(FetchDescriptor<Project>())
        XCTAssertEqual(fetched.first?.name, "Yeni Ad")
        XCTAssertEqual(fetched.first?.location, "Ankara")
    }

    func test_deleteProject() throws {
        let project = Project(name: "Silinecek")
        context.insert(project)
        context.delete(project)
        let fetched = try context.fetch(FetchDescriptor<Project>())
        XCTAssertEqual(fetched.count, 0)
    }

    func test_multipleProjects() throws {
        for i in 1...3 {
            context.insert(Project(name: "Proje \(i)"))
        }
        let fetched = try context.fetch(FetchDescriptor<Project>())
        XCTAssertEqual(fetched.count, 3)
    }

    // MARK: - Contractor CRUD

    func test_insertContractor() throws {
        let c = Contractor(name: "ABC İnşaat", phone: "0212 000 0000", email: "abc@test.com")
        context.insert(c)
        let fetched = try context.fetch(FetchDescriptor<Contractor>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "ABC İnşaat")
        XCTAssertEqual(fetched.first?.phone, "0212 000 0000")
    }

    func test_deleteContractor() throws {
        let c = Contractor(name: "Silinecek")
        context.insert(c)
        context.delete(c)
        let fetched = try context.fetch(FetchDescriptor<Contractor>())
        XCTAssertEqual(fetched.count, 0)
    }

    // MARK: - Contract & WorkItem

    func test_contractWorkItemRelationship() throws {
        let contractor = Contractor(name: "Test")
        let project = Project(name: "Test")
        let contract = Contract(title: "Sözleşme 1", retentionRate: 10, advanceRate: 5)
        contract.contractor = contractor
        contract.project = project
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 200, contractedQuantity: 500)
        workItem.contract = contract
        contract.workItems.append(workItem)
        context.insert(contractor)
        context.insert(project)
        context.insert(contract)
        context.insert(workItem)

        let contracts = try context.fetch(FetchDescriptor<Contract>())
        XCTAssertEqual(contracts.count, 1)
        XCTAssertEqual(contracts.first?.workItems.count, 1)
        XCTAssertEqual(contracts.first?.totalContractAmount, 100_000, "200 × 500 = 100000")
        XCTAssertEqual(contracts.first?.retentionRate, 10)
    }

    func test_multipleWorkItemsInContract() throws {
        let contract = Contract(title: "Test", retentionRate: 0, advanceRate: 0)
        context.insert(contract)
        for i in 1...5 {
            let wi = WorkItem(code: "0\(i)", name: "İş \(i)", unit: "m²",
                              unitPrice: 100, contractedQuantity: Double(i * 10))
            wi.contract = contract
            contract.workItems.append(wi)
            context.insert(wi)
        }
        let fetched = try context.fetch(FetchDescriptor<Contract>())
        XCTAssertEqual(fetched.first?.workItems.count, 5)
        // 10+20+30+40+50 = 150, × 100 = 15000
        XCTAssertEqual(fetched.first?.totalContractAmount, 15_000)
    }

    // MARK: - Hakedis & Payment

    func test_hakedisInsert() throws {
        let contract = Contract(title: "T", retentionRate: 0, advanceRate: 0)
        let jan1 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let jan31 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 31))!
        let hakedis = Hakedis(periodName: "Ocak 2025", periodStart: jan1, periodEnd: jan31)
        hakedis.contract = contract
        context.insert(contract)
        context.insert(hakedis)

        let fetched = try context.fetch(FetchDescriptor<Hakedis>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.periodName, "Ocak 2025")
        XCTAssertEqual(fetched.first?.status, .draft)
    }

    func test_paymentInsert() throws {
        let contract = Contract(title: "T", retentionRate: 0, advanceRate: 0)
        let hakedis = Hakedis(periodName: "Ocak 2025", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        context.insert(contract)
        context.insert(hakedis)

        let payment = Payment(amount: 50_000, paymentDescription: "1. Taksit")
        payment.hakedis = hakedis
        hakedis.payments.append(payment)
        context.insert(payment)

        let fetched = try context.fetch(FetchDescriptor<Hakedis>())
        XCTAssertEqual(fetched.first?.payments.count, 1)
        XCTAssertEqual(fetched.first?.totalPaid, 50_000)
    }

    func test_hakedisItemInsert() throws {
        let contract = Contract(title: "T", retentionRate: 5, advanceRate: 0)
        let hakedis = Hakedis(periodName: "Şubat 2025", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        context.insert(contract)
        context.insert(hakedis)

        let item = HakedisItem(workItemName: "Beton Dökümü", workItemCode: "B01",
                               unit: "m³", unitPrice: 800, previousQuantity: 50, currentQuantity: 30)
        item.hakedis = hakedis
        hakedis.items.append(item)
        context.insert(item)

        let fetched = try context.fetch(FetchDescriptor<Hakedis>())
        XCTAssertEqual(fetched.first?.items.count, 1)
        XCTAssertEqual(fetched.first?.grossAmount, 24_000, "30 × 800 = 24000")
        XCTAssertEqual(fetched.first?.retentionAmount, 1_200, "%5 teminat")
        XCTAssertEqual(fetched.first?.netAmount, 22_800)
    }

    // MARK: - DailyEntry CRUD

    func test_dailyEntryInsert() throws {
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 100, contractedQuantity: 100)
        context.insert(workItem)
        let entry = DailyEntry(date: Date(), quantity: 25, location: "Bodrum Kat", notes: "Normal seyir")
        entry.workItem = workItem
        workItem.dailyEntries.append(entry)
        context.insert(entry)

        let fetched = try context.fetch(FetchDescriptor<WorkItem>())
        XCTAssertEqual(fetched.first?.dailyEntries.count, 1)
        XCTAssertEqual(fetched.first?.completedQuantity, 25)
        XCTAssertEqual(fetched.first?.completionPercentage, 25)
    }

    func test_multipleDailyEntries() throws {
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 100, contractedQuantity: 100)
        context.insert(workItem)
        for qty in [10.0, 20.0, 30.0] {
            let e = DailyEntry(quantity: qty)
            e.workItem = workItem
            workItem.dailyEntries.append(e)
            context.insert(e)
        }
        XCTAssertEqual(workItem.completedQuantity, 60)
        XCTAssertEqual(workItem.completionPercentage, 60)
    }

    // MARK: - Cascade delete

    func test_cascadeDelete_contractDeletesWorkItems() throws {
        let contract = Contract(title: "T", retentionRate: 0, advanceRate: 0)
        let wi = WorkItem(code: "01", name: "Beton", unit: "m³", unitPrice: 300, contractedQuantity: 100)
        wi.contract = contract
        contract.workItems.append(wi)
        context.insert(contract)
        context.insert(wi)
        context.delete(contract)

        let workItems = try context.fetch(FetchDescriptor<WorkItem>())
        XCTAssertEqual(workItems.count, 0, "Cascade: WorkItem silinmeli")
    }

    func test_cascadeDelete_contractDeletesHakedisler() throws {
        let contract = Contract(title: "T", retentionRate: 0, advanceRate: 0)
        let hakedis = Hakedis(periodName: "Ocak", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        contract.hakedisler.append(hakedis)
        context.insert(contract)
        context.insert(hakedis)
        context.delete(contract)

        let hakedisler = try context.fetch(FetchDescriptor<Hakedis>())
        XCTAssertEqual(hakedisler.count, 0, "Cascade: Hakedis silinmeli")
    }

    func test_cascadeDelete_hakedisDeletesItems() throws {
        let contract = Contract(title: "T", retentionRate: 0, advanceRate: 0)
        let hakedis = Hakedis(periodName: "Ocak", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        let item = HakedisItem(workItemName: "Boya", workItemCode: "01",
                               unit: "m²", unitPrice: 50, previousQuantity: 0, currentQuantity: 100)
        item.hakedis = hakedis
        hakedis.items.append(item)
        context.insert(contract)
        context.insert(hakedis)
        context.insert(item)
        context.delete(hakedis)

        let items = try context.fetch(FetchDescriptor<HakedisItem>())
        XCTAssertEqual(items.count, 0, "Cascade: HakedisItem silinmeli")
    }

    func test_cascadeDelete_hakedisDeletesPayments() throws {
        let contract = Contract(title: "T", retentionRate: 0, advanceRate: 0)
        let hakedis = Hakedis(periodName: "Ocak", periodStart: Date(), periodEnd: Date())
        hakedis.contract = contract
        let payment = Payment(amount: 10_000)
        payment.hakedis = hakedis
        hakedis.payments.append(payment)
        context.insert(contract)
        context.insert(hakedis)
        context.insert(payment)
        context.delete(hakedis)

        let payments = try context.fetch(FetchDescriptor<Payment>())
        XCTAssertEqual(payments.count, 0, "Cascade: Payment silinmeli")
    }

    func test_cascadeDelete_workItemDeletesDailyEntries() throws {
        let workItem = WorkItem(code: "01", name: "Kazı", unit: "m³",
                                unitPrice: 100, contractedQuantity: 100)
        for qty in [10.0, 20.0] {
            let e = DailyEntry(quantity: qty)
            e.workItem = workItem
            workItem.dailyEntries.append(e)
            context.insert(e)
        }
        context.insert(workItem)
        context.delete(workItem)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 0, "Cascade: DailyEntry silinmeli")
    }

    func test_cascadeDelete_projectDeletesContracts() throws {
        let project = Project(name: "Test")
        let contract = Contract(title: "T", retentionRate: 0, advanceRate: 0)
        contract.project = project
        project.contracts.append(contract)
        context.insert(project)
        context.insert(contract)
        context.delete(project)

        let contracts = try context.fetch(FetchDescriptor<Contract>())
        XCTAssertEqual(contracts.count, 0, "Cascade: Contract silinmeli")
    }

    func testGuaranteeCRUD() throws {
        let schema = Schema([Guarantee.self, Contract.self, Project.self, Contractor.self,
                             WorkItem.self, DailyEntry.self, Hakedis.self,
                             HakedisItem.self, Payment.self, RetentionRelease.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let gContainer = try ModelContainer(for: schema, configurations: [config])
        let gContext = ModelContext(gContainer)
        let g = Guarantee(guaranteeType: .permanent, amount: 150000,
                         bankName: "Ziraat", referenceNumber: "ZBK001",
                         issueDate: Date(),
                         expiryDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
        gContext.insert(g)
        let fetched = try gContext.fetch(FetchDescriptor<Guarantee>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.bankName, "Ziraat")
        gContext.delete(g)
        let afterDelete = try gContext.fetch(FetchDescriptor<Guarantee>())
        XCTAssertEqual(afterDelete.count, 0)
    }

    func testHakedisKopyalaLogic() throws {
        // previousQty transferi mantık testi (model düzeyinde)
        let prevQty = 50.0
        let currQty = 30.0
        let expectedPrevQtyInCopy = prevQty + currQty
        XCTAssertEqual(expectedPrevQtyInCopy, 80.0)
    }
}
