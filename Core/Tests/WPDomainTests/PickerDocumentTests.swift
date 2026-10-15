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
        XCTAssertEqual(WeddingCategories.filter(WeddingCategories.merge([]), group: nil, query: "").count, 41)
        XCTAssertEqual(WeddingCategories.filter(WeddingCategories.merge([]), group: nil, query: "청첩장").map(\.name), ["모바일 청첩장", "종이 청첩장", "청첩장 모임"])
    }
    func testPickerCountsAndRecent() {
        let all = WeddingCategories.merge([]) + [PlanCategory(name: "우리만의 준비", type: "USER")]
        XCTAssertEqual(WeddingCategories.count(all, group: nil), 42)
        XCTAssertEqual(WeddingCategories.count(all, group: 1), 9)
        XCTAssertEqual(WeddingCategories.groupIndices(all), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(WeddingCategories.groupIndices(WeddingCategories.merge([])), [0, 1, 2, 3, 4])
        XCTAssertEqual(WeddingCategories.recent(all, names: ["드레스", "없는 이름", " 웨딩홀 "]).map(\.name), ["드레스", "웨딩홀"])
        XCTAssertEqual(WeddingCategories.pushRecent(["웨딩홀", "드레스", "폐백", "예단"], picked: "드레스"), ["드레스", "웨딩홀", "폐백", "예단"])
        XCTAssertEqual(WeddingCategories.pushRecent(["a", "b", "c", "d"], picked: "e"), ["e", "a", "b", "c"])
    }
    func testDocumentSizeBoundsAndStorageFormatting() {
        XCTAssertFalse(DocumentRules.validSize(0)); XCTAssertFalse(DocumentRules.validSize(DocumentRules.maxBytes + 1))
        XCTAssertTrue(DocumentRules.validSize(DocumentRules.maxBytes))
        XCTAssertEqual(DocumentRules.formatStorage(nil), "—"); XCTAssertEqual(DocumentRules.formatStorage(0), "0 MB")
        XCTAssertEqual(DocumentRules.formatStorage(1), "1 KB"); XCTAssertEqual(DocumentRules.formatStorage(1024 * 1024 * 1024), "1 GB")
        XCTAssertEqual(DocumentRules.formatStorage(1536 * 1024), "1.5 MB")
    }
}
