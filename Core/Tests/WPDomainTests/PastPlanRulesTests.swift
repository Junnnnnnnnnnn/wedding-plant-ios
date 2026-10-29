import XCTest
import WPDomain
import WPUtils

/// Android 8c1068b `PastPlanRulesTest` 와 같은 표 — 지난 날짜의 **신규** 플랜만 완료로 등록한다(iOS 요청서 07)
final class PastPlanRulesTests: XCTestCase {
    func testOnlyNewDatedPlansBeforeTodayCompleteAutomatically() throws {
        let today = try XCTUnwrap(KstDate(dateString: "2026-10-28"))
        XCTAssertTrue(PlanRules.completeNewPastPlan(date: today.adding(days: -1), isEdit: false, today: today))
        XCTAssertTrue(PlanRules.completeNewPastPlan(date: KstDate(dateString: "2025-12-31"), isEdit: false, today: today))
        XCTAssertFalse(PlanRules.completeNewPastPlan(date: today, isEdit: false, today: today))
        XCTAssertFalse(PlanRules.completeNewPastPlan(date: today.adding(days: 1), isEdit: false, today: today))
        XCTAssertFalse(PlanRules.completeNewPastPlan(date: nil, isEdit: false, today: today))
        XCTAssertFalse(PlanRules.completeNewPastPlan(date: today.adding(days: -1), isEdit: true, today: today))
    }

    /// KST 자정 경계 — 한국 0시 직후의 "오늘" 은 UTC 로는 전날이다. 어제 날짜는 지난 것, 오늘은 아니다.
    func testKstMidnightBoundary() throws {
        // 2026-10-28 00:05 KST = 2026-10-27 15:05 UTC
        let justAfterMidnight = Date(timeIntervalSince1970: 1_793_113_500)
        let today = KstDate.today(now: justAfterMidnight)
        XCTAssertEqual(today.dateString, "2026-10-28")
        XCTAssertTrue(PlanRules.completeNewPastPlan(date: KstDate(dateString: "2026-10-27"), isEdit: false, today: today))
        XCTAssertFalse(PlanRules.completeNewPastPlan(date: KstDate(dateString: "2026-10-28"), isEdit: false, today: today))
    }
}
