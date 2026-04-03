import XCTest
import Foundation

// MARK: - A3 Malzeme Tests

final class SupplierTests: XCTestCase {

    func test_supplier_olusturma_varsayilanDegerler() {
        let supplier = Supplier(companyName: "ABC İnşaat Malzeme")
        XCTAssertEqual(supplier.companyName, "ABC İnşaat Malzeme")
        XCTAssertNil(supplier.contactPerson)
        XCTAssertNil(supplier.rating)
        XCTAssertTrue(supplier.orders.isEmpty)
        XCTAssertTrue(supplier.stockEntries.isEmpty)
    }

    func test_supplier_performansSkoruHesabi_siparisYoksa_ratingDegeri() {
        let supplier = Supplier(companyName: "Test Tedarikçi")
        supplier.rating = 4
        // No completed orders → falls back to rating
        XCTAssertEqual(supplier.averageDeliveryScore, 4.0, accuracy: 0.001)
    }

    func test_supplier_performansSkoruHesabi_zamanindaTeslimat() {
        let supplier = Supplier(companyName: "Test Tedarikçi")
        let order = MaterialOrder(orderNo: "SIP-001", orderDate: Date(), orderedQuantity: 100, unitPrice: 50)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        order.expectedDeliveryDate = tomorrow
        order.actualDeliveryDate = yesterday  // zamanında
        order.status = .completed
        order.supplier = supplier
        supplier.orders.append(order)
        // 1/1 zamanında = 5.0 puan
        XCTAssertEqual(supplier.averageDeliveryScore, 5.0, accuracy: 0.001)
    }
}

final class MaterialOrderTests: XCTestCase {

    func test_materialOrder_olusturma_varsayilanDurum() {
        let order = MaterialOrder(orderNo: "SIP-001", orderDate: Date(), orderedQuantity: 100, unitPrice: 25)
        XCTAssertEqual(order.status, .created)
        XCTAssertEqual(order.totalAmount, 2500.0, accuracy: 0.001)
    }

    func test_materialOrder_durumAkisi_created_to_completed() {
        let order = MaterialOrder(orderNo: "SIP-002")
        order.status = .approved
        XCTAssertEqual(order.status, .approved)
        order.status = .shipped
        XCTAssertEqual(order.status, .shipped)
        order.status = .delivered
        order.status = .completed
        XCTAssertEqual(order.status, .completed)
    }

    func test_materialOrder_gecikmeKontrol_beklenenTarihGecmis() {
        let order = MaterialOrder(orderNo: "SIP-003")
        order.expectedDeliveryDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        order.status = .shipped
        XCTAssertTrue(order.isDelayed)
    }

    func test_materialOrder_gecikmeKontrol_tamamlananSiparis() {
        let order = MaterialOrder(orderNo: "SIP-004")
        order.expectedDeliveryDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        order.status = .completed  // tamamlandı → gecikme yok
        XCTAssertFalse(order.isDelayed)
    }

    func test_materialOrder_teslimatOrani_kismiTeslimat() {
        let order = MaterialOrder(orderNo: "SIP-005", orderedQuantity: 100, unitPrice: 10)
        order.deliveredQuantity = 60
        XCTAssertEqual(order.deliveryRate, 60.0, accuracy: 0.001)
    }
}

final class MaterialRequestTests: XCTestCase {

    func test_materialRequest_olusturma_varsayilanDurum() {
        let req = MaterialRequest(requestedBy: "Ahmet Mühendis", requestedQuantity: 50)
        XCTAssertEqual(req.requestedBy, "Ahmet Mühendis")
        XCTAssertEqual(req.requestedQuantity, 50.0, accuracy: 0.001)
        XCTAssertEqual(req.status, .draft)
        XCTAssertEqual(req.urgency, .normal)
    }

    func test_materialRequest_onayAkisi() {
        let req = MaterialRequest(requestedBy: "Mühendis")
        req.status = .submitted
        XCTAssertEqual(req.status, .submitted)
        req.status = .approved
        req.approvedBy = "Proje Müdürü"
        req.approvalDate = Date()
        XCTAssertEqual(req.status, .approved)
        XCTAssertEqual(req.approvedBy, "Proje Müdürü")
    }

    func test_materialRequest_aciliyetSeviyesi() {
        let req = MaterialRequest(requestedBy: "Test")
        req.urgency = .critical
        XCTAssertEqual(req.urgency, .critical)
        XCTAssertEqual(req.urgency.colorName, "hakedisDanger")
    }
}

final class MaterialWastageTests: XCTestCase {

    func test_material_fireOrani_teorikyaySarf() {
        let material = Material(name: "Demir", unit: "ton")
        material.theoreticalConsumption = 100.0
        let entry = StockEntry(date: Date(), entryType: .outgoing, quantity: 110.0)
        entry.material = material
        material.entries.append(entry)
        // (110 - 100) / 100 * 100 = +10%
        XCTAssertNotNil(material.actualWastage)
        XCTAssertEqual(material.actualWastage!, 10.0, accuracy: 0.001)
    }

    func test_material_fireOrani_teorikSarfNilsa_nil() {
        let material = Material(name: "Beton", unit: "m³")
        XCTAssertNil(material.actualWastage)
    }

    func test_material_stokDegeri_hesaplama() {
        let material = Material(name: "Demir", unit: "ton", minimumStock: 5, unitPrice: 30000)
        material.currentStock = 10.0
        // 10 * 30000 = 300000
        XCTAssertEqual(material.stockValue, 300000.0, accuracy: 0.001)
    }
}

// MARK: - A4 Ekipman Tests

final class EquipmentFailureTests: XCTestCase {

    func test_equipmentFailure_olusturma_acikAriza() {
        let failure = EquipmentFailure(failureDate: Date(), failureChangeDescription: "Motor arızası")
        XCTAssertFalse(failure.isResolved)
        XCTAssertNil(failure.repairDate)
        XCTAssertNil(failure.repairCost)
        XCTAssertTrue(failure.photoData.isEmpty)
    }

    func test_equipmentFailure_tamir_kapatma() {
        let failure = EquipmentFailure(failureDate: Date(), failureChangeDescription: "Hidrolik arıza")
        failure.repairDate = Date()
        failure.repairCost = 5000.0
        failure.repairChangeDescription = "Piston değiştirildi"
        failure.isResolved = true
        XCTAssertTrue(failure.isResolved)
        XCTAssertEqual(failure.repairCost!, 5000.0, accuracy: 0.001)
    }
}

final class MaintenancePlanTests: XCTestCase {

    func test_maintenancePlan_bakimZamani_geldi() {
        let plan = MaintenancePlan(maintenanceType: .oilChange, intervalHours: 250)
        plan.nextDueHours = 500
        XCTAssertTrue(plan.isDue(currentHours: 500))
        XCTAssertTrue(plan.isDue(currentHours: 600))
    }

    func test_maintenancePlan_bakimZamani_gelmedi() {
        let plan = MaintenancePlan(maintenanceType: .filterChange, intervalHours: 500)
        plan.nextDueHours = 1000
        XCTAssertFalse(plan.isDue(currentHours: 999))
    }

    func test_maintenancePlan_bakimTipi_icon() {
        XCTAssertFalse(MaintenanceType.oilChange.icon.isEmpty)
        XCTAssertFalse(MaintenanceType.generalService.icon.isEmpty)
    }
}

final class RentalContractTests: XCTestCase {

    func test_rentalContract_toplamMaliyet_hesaplama() {
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let endDate = Date()
        let contract = RentalContract(rentalCompany: "Ekipman A.Ş.", startDate: startDate, dailyRate: 1000)
        contract.endDate = endDate
        // ~10 gün × 1000 ₺/gün = ~10000 ₺
        XCTAssertGreaterThan(contract.totalCost, 0)
        XCTAssertGreaterThanOrEqual(contract.totalDays, 9)
    }

    func test_rentalContract_kalanGun_hesaplama() {
        let endDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let contract = RentalContract(rentalCompany: "Test Firma", startDate: Date(), dailyRate: 500)
        contract.endDate = endDate
        XCTAssertNotNil(contract.daysRemaining)
        XCTAssertGreaterThanOrEqual(contract.daysRemaining!, 4)
    }

    func test_rentalContract_yakindaBitiyor_7GunIcinde() {
        let endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let contract = RentalContract(rentalCompany: "Test", startDate: Date(), dailyRate: 500)
        contract.endDate = endDate
        XCTAssertTrue(contract.isExpiringSoon)
    }
}

final class EquipmentComputedTests: XCTestCase {

    func test_equipment_amortisman_hesaplama() {
        let item = EquipmentItem(name: "Ekskavatör")
        item.purchasePrice = 1_000_000.0
        item.depreciationYears = 10
        XCTAssertEqual(item.annualDepreciation, 100_000.0, accuracy: 0.001)
        XCTAssertEqual(item.monthlyDepreciation, 100_000.0 / 12, accuracy: 0.01)
    }

    func test_equipment_costPerHour_hesaplama() {
        let item = EquipmentItem(name: "Vinç")
        item.totalOperatingHours = 100
        let log = EquipmentLog(date: Date(), operatingHours: 10)
        log.fuelCost = 500
        item.logs.append(log)
        let failure = EquipmentFailure(failureDate: Date(), failureChangeDescription: "Test")
        failure.repairCost = 1000
        failure.isResolved = true
        item.failures.append(failure)
        // totalFuelCost = 500, totalRepairCost = 1000, totalOperatingCost = 1500
        // costPerHour = 1500 / 100 = 15
        XCTAssertEqual(item.totalFuelCost, 500.0, accuracy: 0.001)
        XCTAssertEqual(item.totalRepairCost, 1000.0, accuracy: 0.001)
        XCTAssertEqual(item.costPerHour, 15.0, accuracy: 0.001)
    }

    func test_equipment_yakitAsimiUyari_yuzde15Uzeri() {
        let item = EquipmentItem(name: "Buldozer")
        item.hourlyFuelConsumption = 10.0
        item.totalOperatingHours = 100
        let log = EquipmentLog(date: Date(), operatingHours: 100)
        log.fuelLiters = 1200  // 12 lt/saat > 10 × 1.15 = 11.5
        item.logs.append(log)
        XCTAssertTrue(item.isOverConsumption)
    }

    func test_equipment_yakitNormal_uyariYok() {
        let item = EquipmentItem(name: "Forklift")
        item.hourlyFuelConsumption = 10.0
        item.totalOperatingHours = 100
        let log = EquipmentLog(date: Date(), operatingHours: 100)
        log.fuelLiters = 1000  // tam 10 lt/saat = baseline
        item.logs.append(log)
        XCTAssertFalse(item.isOverConsumption)
    }
}
