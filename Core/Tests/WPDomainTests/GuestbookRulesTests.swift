import XCTest
@testable import WPDomain
import WPModels

final class GuestbookRulesTests: XCTestCase {
    private let wishes = [
        InvitationWish(id: "a", name: "하은", message: "결혼 축하해요", createdAt: "2026-11-01T03:00:00.000Z"),
        InvitationWish(id: "b", name: "도윤", message: "행복하세요 하은도 함께", createdAt: "2026-11-08T16:30:00.000Z"),
        InvitationWish(id: "c", name: "Mina", message: "Congrats", createdAt: ""),
    ]

    func testFilterMatchesNameOrMessageCaseInsensitive() {
        XCTAssertEqual(InvitationRules.filterWishes(wishes, query: "하은").map(\.id), ["a", "b"])
        XCTAssertEqual(InvitationRules.filterWishes(wishes, query: " mina ").map(\.id), ["c"])
        XCTAssertEqual(InvitationRules.filterWishes(wishes, query: "   ").count, 3)
        XCTAssertTrue(InvitationRules.filterWishes(wishes, query: "없는말").isEmpty)
    }

    func testNewestFirstKeepsUndatedLast() {
        XCTAssertEqual(InvitationRules.newestFirst(wishes).map(\.id), ["b", "a", "c"])
    }

    func testDateLabelUsesKst() {
        // UTC 11월 8일 16:30 은 KST 11월 9일 01:30
        XCTAssertEqual(InvitationRules.wishDateLabel("2026-11-08T16:30:00.000Z"), "11월 9일")
        XCTAssertEqual(InvitationRules.wishDateLabel(""), "")
    }

    func testValidateTrimsAndLimits() {
        XCTAssertNil(InvitationRules.validateWish(name: "  하은 ", message: " 축하해 "))
        XCTAssertEqual(InvitationRules.validateWish(name: "   ", message: "a"), "이름을 적어 주세요.")
        XCTAssertNil(InvitationRules.validateWish(name: String(repeating: "가", count: 20), message: "a"))
        XCTAssertEqual(InvitationRules.validateWish(name: String(repeating: "가", count: 21), message: "a"), "이름은 20자까지 적을 수 있어요.")
        XCTAssertEqual(InvitationRules.validateWish(name: "a", message: "\n "), "축하 글을 적어 주세요.")
        XCTAssertNil(InvitationRules.validateWish(name: "a", message: String(repeating: "나", count: 120)))
        XCTAssertEqual(InvitationRules.validateWish(name: "a", message: String(repeating: "나", count: 121)), "축하 글은 120자까지 적을 수 있어요.")
    }

    func testRowTitle() {
        XCTAssertEqual(InvitationRules.guestbookRowTitle(total: 3), "축하 글 3개")
        XCTAssertEqual(InvitationRules.guestbookRowTitle(total: nil), "축하 글")
    }

    func testWishDecodesEditable() throws {
        let data = Data(#"{"id":"w1","name":"a","message":"b","avatar":2,"createdAt":"x","editable":true}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(InvitationWish.self, from: data).editable)
        XCTAssertFalse(try JSONDecoder().decode(InvitationWish.self, from: Data(#"{"id":"w1"}"#.utf8)).editable)
    }
}
