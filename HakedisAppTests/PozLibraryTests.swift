import XCTest

final class PozLibraryTests: XCTestCase {

    func testMinimum250Poz() {
        XCTAssertGreaterThanOrEqual(PozLibrary.allPozlar.count, 250,
            "Poz sayısı \(PozLibrary.allPozlar.count) — en az 250 olmalı")
    }

    func testMinimum20Categories() {
        let categories = Set(PozLibrary.allPozlar.map { $0.category })
        XCTAssertGreaterThanOrEqual(categories.count, 20,
            "Kategori sayısı \(categories.count) — en az 20 olmalı")
    }

    func testEachCategoryMinimum7Poz() {
        let grouped = Dictionary(grouping: PozLibrary.allPozlar) { $0.category }
        for (category, items) in grouped {
            XCTAssertGreaterThanOrEqual(items.count, 7,
                "\(category) kategorisinde \(items.count) poz var — en az 7 olmalı")
        }
    }

    func testAllPozlarHaveUnitPrice() {
        for poz in PozLibrary.allPozlar {
            XCTAssertGreaterThan(poz.unitPrice, 0, "\(poz.code) \(poz.name) — birim fiyat 0")
        }
    }

    func testNoDuplicatePozCodes() {
        let codes = PozLibrary.allPozlar.map { $0.code }
        XCTAssertEqual(codes.count, Set(codes).count, "Duplicate poz kodu tespit edildi")
    }

    func testBetonC20toC40Exists() {
        let betonPozlar = PozLibrary.allPozlar.filter { $0.category == "Beton İşleri" }
        XCTAssertTrue(betonPozlar.contains { $0.name.contains("C20") }, "C20 beton yok")
        XCTAssertTrue(betonPozlar.contains { $0.name.contains("C25") }, "C25 beton yok")
        XCTAssertTrue(betonPozlar.contains { $0.name.contains("C30") }, "C30 beton yok")
        XCTAssertTrue(betonPozlar.contains { $0.name.contains("C35") }, "C35 beton yok")
        XCTAssertTrue(betonPozlar.contains { $0.name.contains("C40") }, "C40 beton yok")
    }

    func testDemirO8toO32Exists() {
        let demirPozlar = PozLibrary.allPozlar.filter { $0.category == "Demir İşleri" }
        for cap in ["Ø8", "Ø10", "Ø12", "Ø14", "Ø16", "Ø18", "Ø20", "Ø22", "Ø25", "Ø32"] {
            XCTAssertTrue(demirPozlar.contains { $0.name.contains(cap) }, "\(cap) demir pozu yok")
        }
    }

    func testAllCategoriesHaveItems() {
        let categories = PozLibrary.allCategories
        XCTAssertFalse(categories.isEmpty)
        for cat in categories {
            let count = PozLibrary.allPozlar.filter { $0.category == cat }.count
            XCTAssertGreaterThan(count, 0, "\(cat) kategorisinde hiç poz yok")
        }
    }

    func testAllPozlarHaveNonEmptyFields() {
        for poz in PozLibrary.allPozlar {
            XCTAssertFalse(poz.code.isEmpty, "Boş kod: \(poz.name)")
            XCTAssertFalse(poz.name.isEmpty, "Boş isim: \(poz.code)")
            XCTAssertFalse(poz.unit.isEmpty, "Boş birim: \(poz.code)")
            XCTAssertFalse(poz.category.isEmpty, "Boş kategori: \(poz.code)")
        }
    }

    func testItemsAndAllPozlarAreIdentical() {
        XCTAssertEqual(PozLibrary.items.count, PozLibrary.allPozlar.count)
    }
}
