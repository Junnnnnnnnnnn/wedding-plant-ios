import XCTest
@testable import WPDomain
@testable import WPUtils

/// 홈 머리 면의 두 줄 문장과 `이번 달 / 그 다음` 묶음.
/// 웹 main 의 `ddaySentenceLines` · `getTimeBucket` 과 같은 결과인지 고정한다.
final class HomeBucketTests: XCTestCase {

    private func date(_ s: String) -> KstDate { KstDate(dateString: s)! }
    /// 2026-09-18 정오(KST)를 "지금" 으로 고정한다.
    private let now = KstDate(dateString: "2026-09-18")!.startOfDay.addingTimeInterval(12 * 3600)

    // MARK: - 두 줄 문장

    func test_남았으면_결혼식까지() {
        let (a, b) = PlanRules.dDaySentence(weddingDate: date("2026-11-14"), now: now)
        XCTAssertEqual(a, "결혼식까지")
        XCTAssertEqual(b, "57일 남았어요")
    }

    func test_당일이면_오늘이() {
        let (a, b) = PlanRules.dDaySentence(weddingDate: date("2026-09-18"), now: now)
        XCTAssertEqual(a, "오늘이")
        XCTAssertEqual(b, "결혼식이에요")
    }

    func test_지났으면_며칠_지났어요() {
        let (a, b) = PlanRules.dDaySentence(weddingDate: date("2026-09-15"), now: now)
        XCTAssertEqual(a, "결혼식이")
        XCTAssertEqual(b, "3일 지났어요")
    }

    func test_날짜가_없으면_정해_달라고_한다() {
        let (a, b) = PlanRules.dDaySentence(weddingDate: nil, now: now)
        XCTAssertEqual(a, "결혼식 날짜를")
        XCTAssertEqual(b, "정해 주세요")
    }

    // MARK: - 이번 달 / 그 다음

    func test_이번_달_안이면_이번_달이다() {
        XCTAssertTrue(PlanRules.isThisMonthOrPast(startDate: "2026-09-30", today: date("2026-09-18")))
        XCTAssertTrue(PlanRules.isThisMonthOrPast(startDate: "2026-09-18", today: date("2026-09-18")))
    }

    func test_지난_일도_이번_달에_남는다() {
        // 아직 안 끝났으니 여전히 할 일이고 가장 급하다.
        XCTAssertTrue(PlanRules.isThisMonthOrPast(startDate: "2026-08-01", today: date("2026-09-18")))
        XCTAssertTrue(PlanRules.isThisMonthOrPast(startDate: "2025-12-31", today: date("2026-09-18")))
    }

    func test_다음_달부터는_그_다음이다() {
        XCTAssertFalse(PlanRules.isThisMonthOrPast(startDate: "2026-10-01", today: date("2026-09-18")))
    }

    func test_작년_같은_달은_지난_일이다() {
        // 연도를 안 보고 월만 보면 2025-09 가 "이번 달" 로 새어 들어온다.
        XCTAssertTrue(PlanRules.isThisMonthOrPast(startDate: "2025-09-20", today: date("2026-09-18")))
    }

    func test_내년_같은_달은_그_다음이다() {
        XCTAssertFalse(PlanRules.isThisMonthOrPast(startDate: "2027-09-01", today: date("2026-09-18")))
    }

    func test_날짜_미정은_그_다음이다() {
        XCTAssertFalse(PlanRules.isThisMonthOrPast(startDate: nil, today: date("2026-09-18")))
        XCTAssertFalse(PlanRules.isThisMonthOrPast(startDate: "", today: date("2026-09-18")))
    }
}
