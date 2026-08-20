import XCTest
import WPModels
import WPUtils
@testable import WPDomain

/// 웹·안드로이드와 **같은 값**이 나오는지 고정한다.
/// 여기가 어긋나면 세 앱의 화면이 미묘하게 달라지고, 눈으로는 찾기 어렵다.
final class PlanRulesTests: XCTestCase {

    /// KST 2026-08-14 12:00 에 해당하는 시각 (UTC 03:00)
    private var now: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 14
        components.hour = 3
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: components)!
    }

    // MARK: - D-Day 라벨

    func test_dDayLabel_남은_날짜() {
        let date = KstDate(year: 2026, month: 12, day: 14)!
        XCTAssertEqual(PlanRules.dDayLabel(weddingDate: date, now: now), "D-122")
    }

    func test_dDayLabel_당일은_D_Day() {
        let date = KstDate(year: 2026, month: 8, day: 14)!
        XCTAssertEqual(PlanRules.dDayLabel(weddingDate: date, now: now), "D-Day")
    }

    func test_dDayLabel_지난_날짜는_플러스() {
        let date = KstDate(year: 2026, month: 8, day: 11)!
        XCTAssertEqual(PlanRules.dDayLabel(weddingDate: date, now: now), "D+3")
    }

    func test_dDayLabel_날짜가_없으면_안내문구() {
        XCTAssertEqual(PlanRules.dDayLabel(weddingDate: nil, now: now), "날짜 설정")
    }

    // MARK: - 일정 상태

    func test_dateStatus_경계값() {
        // 오늘
        XCTAssertEqual(PlanRules.dateStatus(startDate: "2026-08-14", now: now), .today)
        // 하루 전 → 지남
        XCTAssertEqual(PlanRules.dateStatus(startDate: "2026-08-13", now: now), .past)
        // 5일 뒤까지는 임박
        XCTAssertEqual(PlanRules.dateStatus(startDate: "2026-08-19", now: now), .soon)
        // 6일 뒤부터 예정
        XCTAssertEqual(PlanRules.dateStatus(startDate: "2026-08-20", now: now), .upcoming)
    }

    func test_dateStatus_날짜가_없으면_예정() {
        XCTAssertEqual(PlanRules.dateStatus(startDate: nil, now: now), .upcoming)
        XCTAssertEqual(PlanRules.dateStatus(startDate: "", now: now), .upcoming)
        XCTAssertEqual(PlanRules.dateStatus(startDate: "이상한값", now: now), .upcoming)
    }

    func test_상태_라벨_문구() {
        XCTAssertEqual(PlanRules.DateStatus.upcoming.label, "예정")
        XCTAssertEqual(PlanRules.DateStatus.soon.label, "임박")
        XCTAssertEqual(PlanRules.DateStatus.today.label, "D-day")
        XCTAssertEqual(PlanRules.DateStatus.past.label, "지남")
    }

    // MARK: - 카테고리 색상 (JS 해시 재현)

    func test_같은_이름은_항상_같은_색() {
        XCTAssertEqual(
            PlanRules.categoryColorHex("웨딩홀"),
            PlanRules.categoryColorHex("웨딩홀")
        )
    }

    func test_카테고리_색은_팔레트_안에서만_나온다() {
        for name in ["웨딩홀", "스튜디오", "드레스", "메이크업", "신혼여행", "예물", "", "a", "매우 긴 카테고리 이름입니다"] {
            XCTAssertTrue(
                PlanRules.categoryColors.contains(PlanRules.categoryColorHex(name)),
                "\(name) 이 팔레트 밖의 색을 냈습니다"
            )
        }
    }

    /// JS `hash = (hash << 5) - hash + charCode` 를 손으로 계산한 값과 맞춘다.
    /// "ab" → h=0 → 'a'(97): 0*31+97 = 97 → 'b'(98): 97*31+98 = 3105
    /// 3105 % 6 = 3
    func test_해시_계산이_JS와_일치한다() {
        XCTAssertEqual(PlanRules.categoryColorHex("ab"), PlanRules.categoryColors[3])
    }

    /// 긴 문자열에서 Int32 오버플로가 나도 크래시하지 않아야 한다.
    /// (일반 `<<`/`+` 를 쓰면 여기서 터진다)
    func test_긴_이름에서_오버플로해도_크래시하지_않는다() {
        let long = String(repeating: "카테고리", count: 200)
        XCTAssertTrue(PlanRules.categoryColors.contains(PlanRules.categoryColorHex(long)))
    }

    // MARK: - 예산

    func test_예산_사용률() {
        XCTAssertEqual(PlanRules.budgetUsagePercent(total: 5000, used: 2150), 43)
        XCTAssertEqual(PlanRules.budgetUsagePercent(total: 5000, used: 0), 0)
    }

    func test_총예산이_0이면_0퍼센트() {
        XCTAssertEqual(PlanRules.budgetUsagePercent(total: 0, used: 100), 0)
        XCTAssertEqual(PlanRules.budgetUsagePercent(total: -1, used: 100), 0)
    }

    func test_초과분은_그대로_반환하고_진행바만_클램프() {
        XCTAssertEqual(PlanRules.budgetUsagePercent(total: 100, used: 150), 150)
        XCTAssertEqual(PlanRules.budgetUsagePercentClamped(total: 100, used: 150), 100)
        XCTAssertEqual(PlanRules.budgetUsagePercentClamped(total: 100, used: -50), 0)
    }
}

final class KstFormatTests: XCTestCase {

    func test_요일_약자() {
        // 2026-08-14 는 금요일
        XCTAssertEqual(KstDate(year: 2026, month: 8, day: 14)?.weekdayShort, "금")
        XCTAssertEqual(KstDate(year: 2026, month: 8, day: 15)?.weekdayShort, "토")
        XCTAssertEqual(KstDate(year: 2026, month: 8, day: 16)?.weekdayShort, "일")
        XCTAssertEqual(KstDate(year: 2026, month: 8, day: 17)?.weekdayShort, "월")
    }

    func test_결혼식_날짜_문구() {
        XCTAssertEqual(
            KstDate(year: 2026, month: 8, day: 14)?.weddingDateText,
            "2026년 8월 14일 (금)"
        )
    }

    func test_리스트_날짜_문구() {
        XCTAssertEqual(
            KstDate(year: 2026, month: 8, day: 14)?.listDateText,
            "2026년 8월 14일 (금요일)"
        )
    }

    func test_월별_일수() {
        XCTAssertEqual(KstDate.daysInMonth(year: 2026, month: 1), 31)
        XCTAssertEqual(KstDate.daysInMonth(year: 2026, month: 4), 30)
        XCTAssertEqual(KstDate.daysInMonth(year: 2026, month: 2), 28)
        // 윤년
        XCTAssertEqual(KstDate.daysInMonth(year: 2028, month: 2), 29)
        XCTAssertEqual(KstDate.daysInMonth(year: 2000, month: 2), 29)
        XCTAssertEqual(KstDate.daysInMonth(year: 1900, month: 2), 28)
    }

    func test_천단위_구분() {
        XCTAssertEqual(wpThousands(1234), "1,234")
        XCTAssertEqual(wpThousands(0), "0")
        XCTAssertEqual(wpThousands(-2150), "-2,150")
        XCTAssertEqual(wpThousands(1000000), "1,000,000")
    }
    // MARK: - 권한

    private func member(_ id: String, _ permission: String) -> Member {
        Member(planUserId: id, name: id, image: nil, permission: PlanPermission(rawValue: permission))
    }

    func test_읽기_권한이면_읽기전용() {
        let members = [member("me", "READ"), member("other", "OWNER")]
        XCTAssertTrue(PlanRules.isReadOnly(members: members, planUserId: "me"))
    }

    func test_쓰기나_소유자는_읽기전용이_아니다() {
        let members = [member("me", "WRITE"), member("other", "OWNER")]
        XCTAssertFalse(PlanRules.isReadOnly(members: members, planUserId: "me"))
        XCTAssertFalse(PlanRules.isReadOnly(members: [member("me", "OWNER")], planUserId: "me"))
    }

    func test_확실하지_않으면_막지_않는다() {
        let members = [member("other", "OWNER")]
        // 멤버 목록에 내가 없음
        XCTAssertFalse(PlanRules.isReadOnly(members: members, planUserId: "me"))
        // planUserId 를 모름
        XCTAssertFalse(PlanRules.isReadOnly(members: members, planUserId: nil))
        XCTAssertFalse(PlanRules.isReadOnly(members: members, planUserId: "   "))
        // 멤버가 아예 없음
        XCTAssertFalse(PlanRules.isReadOnly(members: [], planUserId: "me"))
    }

    func test_앞뒤_공백은_무시하고_비교한다() {
        XCTAssertTrue(PlanRules.isReadOnly(members: [member(" me ", "READ")], planUserId: "me"))
    }

}
