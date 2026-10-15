import XCTest
@testable import WPDomain
import WPUtils

/// 안드로이드 `PlanRules.timeBucket` · `InvitationRules.homeEmptyText`/`homeMineText` 와 같은 답인지.
final class HomeParityRulesTests: XCTestCase {
    private let today = KstDate(year: 2026, month: 10, day: 14)!

    func testTimeBucketSplitsByMonthStart() {
        XCTAssertEqual(PlanRules.timeBucket(startDate: "2026-10-01", today: today), .thisMonth)
        XCTAssertEqual(PlanRules.timeBucket(startDate: "2026-10-31", today: today), .thisMonth)
        XCTAssertEqual(PlanRules.timeBucket(startDate: "2026-09-30", today: today), .past)
        XCTAssertEqual(PlanRules.timeBucket(startDate: "2025-12-30", today: today), .past)
        XCTAssertEqual(PlanRules.timeBucket(startDate: "2026-11-01", today: today), .later)
        XCTAssertEqual(PlanRules.timeBucket(startDate: nil, today: today), .later)
    }

    func testHomeEmptyText() {
        XCTAssertEqual(InvitationRules.homeEmptyText(planDate: "2027-03-13", planVenue: "그랜드 라온홀").note,
                       "2027. 03. 13 · 그랜드 라온홀 미리 채워 둘게요")
        XCTAssertEqual(InvitationRules.homeEmptyText(planDate: nil, planVenue: " ").note, "사진 · 날짜 · 장소를 담아 하객을 맞아요")
    }

    func testHomeMineText() {
        XCTAssertEqual(InvitationRules.homeMineText(published: false, guestbookOn: true, guests: 3, fresh: 0, latest: nil).action, "공개하기")
        let line = InvitationRules.homeLatestWish([("", "축하\n해요", "2026-10-01"), ("민지", "예", "2026-09-01")])
        XCTAssertEqual(line, .init(name: "하객", message: "축하 해요"))
        XCTAssertEqual(InvitationRules.homeMineText(published: true, guestbookOn: true, guests: 2, fresh: 0, latest: line).title,
                       "청첩장 공개 중 · 하객 2명")
    }
}
