import XCTest
import WPModels
@testable import WPDomain

final class PickerDocumentTests: XCTestCase {
    func testCategoriesAlwaysIncludeFortyDefaultsAndLegacy() {
        let all = WeddingCategories.merge([])
        XCTAssertEqual(all.count, 41); XCTAssertEqual(WeddingCategories.names.count, 40)
        XCTAssertEqual(WeddingCategories.icon("기타"), 39); XCTAssertEqual(WeddingCategories.icon("스드메"), 8)
        XCTAssertEqual(WeddingCategories.group("우리만의 준비"), 5)
    }
    func testLateServerMetadataReplacesDefaultInPlace() {
        let server = PlanCategory(id: 912, name: " 드레스 ", type: "ROOM")
        let all = WeddingCategories.merge([server])
        XCTAssertEqual(all.count, 41); XCTAssertEqual(all[8], server)
        XCTAssertEqual(WeddingCategories.all(all, added: [PlanCategory(name: "드레스", type: "USER")]).count, 41)
    }
    func testUnicodeSpacesAndUnspacedCategorySearch() {
        XCTAssertEqual(WeddingCategories.clean("\u{FEFF}  신혼집\u{00A0}\u{3000}계약  "), "신혼집 계약")
        let filtered = WeddingCategories.filter(WeddingCategories.merge([]), group: 4, query: "신혼여행항공")
        XCTAssertEqual(filtered.map(\.name), ["신혼여행 항공·교통"])
        XCTAssertTrue(WeddingCategories.filter(WeddingCategories.merge([]), group: 0, query: "드레스").isEmpty)
    }
    func testDocumentSizeBoundsAndStorageFormatting() {
        XCTAssertFalse(DocumentRules.validSize(0)); XCTAssertFalse(DocumentRules.validSize(DocumentRules.maxBytes + 1))
        XCTAssertTrue(DocumentRules.validSize(DocumentRules.maxBytes))
        XCTAssertEqual(DocumentRules.formatStorage(nil), "—"); XCTAssertEqual(DocumentRules.formatStorage(0), "0 MB")
        XCTAssertEqual(DocumentRules.formatStorage(1), "1 KB"); XCTAssertEqual(DocumentRules.formatStorage(1024 * 1024 * 1024), "1 GB")
        XCTAssertEqual(DocumentRules.formatStorage(1536 * 1024), "1.5 MB")
    }
}
