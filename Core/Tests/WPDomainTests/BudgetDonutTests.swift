import XCTest
@testable import WPDomain
@testable import WPModels

/// 예산 도넛의 구간 계산.
///
/// **자본을 넘긴 경우가 이 화면에서 제일 깨지기 쉽다.** 원은 100% 를 넘길 수 없어
/// 분모를 `max(자본, 사용+예정)` 으로 두는데, 이 규칙이 어긋나면 124% 도 "꽉 참"
/// 으로만 보인다.
final class BudgetDonutTests: XCTestCase {

    // MARK: - 자본 안

    func test_자본_안에서_쓰면_초과_구간이_없다() {
        let s = BudgetDonutSegments(capital: 1000, used: 300, planned: 200)
        XCTAssertEqual(s.total, 1000, "분모는 자본 그대로다")
        XCTAssertEqual(s.withinCapital, 300)
        XCTAssertEqual(s.overUsed, 0)
        XCTAssertEqual(s.remaining, 500)
        XCTAssertEqual(s.overAmount, 0)
        XCTAssertNil(s.capitalMark, "넘기지 않았으면 눈금이 없다")
        XCTAssertTrue(s.fitsInRing)
    }

    // MARK: - 사용이 자본을 넘김

    func test_사용이_자본을_넘으면_빨간_구간이_생긴다() {
        let s = BudgetDonutSegments(capital: 1000, used: 1240, planned: 0)
        // 분모가 자본이 아니라 사용 합계여야 124% 가 표현된다.
        XCTAssertEqual(s.total, 1240)
        XCTAssertEqual(s.withinCapital, 1000, "분홍은 자본까지만")
        XCTAssertEqual(s.overUsed, 240)
        XCTAssertEqual(s.remaining, -240)
        XCTAssertEqual(s.usedPercent, 124)
        XCTAssertTrue(s.fitsInRing)
    }

    func test_넘긴_만큼_눈금이_안쪽에_찍힌다() {
        let s = BudgetDonutSegments(capital: 1000, used: 1240, planned: 0)
        let mark = try? XCTUnwrap(s.capitalMark)
        // 1000 / 1240 = 80.6%
        XCTAssertEqual(mark ?? 0, 80.645, accuracy: 0.01)
    }

    // MARK: - 예정 때문에만 넘김 (눈금이 유일한 표시)

    func test_예정_때문에만_넘으면_빨간_구간_없이_눈금만_남는다() {
        let s = BudgetDonutSegments(capital: 1000, used: 800, planned: 400)
        XCTAssertEqual(s.overUsed, 0, "사용은 자본을 안 넘었다")
        XCTAssertEqual(s.overAmount, 200)
        XCTAssertNotNil(s.capitalMark, "빨간 구간이 없으니 눈금이 유일한 표시다")
        XCTAssertEqual(s.total, 1200)
        XCTAssertEqual(s.remaining, -200)
        XCTAssertTrue(s.fitsInRing)
    }

    // MARK: - 경계

    func test_아무것도_안_쓰면_남은_금액이_자본과_같다() {
        let s = BudgetDonutSegments(capital: 1000, used: 0, planned: 0)
        XCTAssertEqual(s.remaining, 1000)
        XCTAssertEqual(s.usedPercent, 0)
        XCTAssertEqual(s.ratio(s.withinCapital), 0)
    }

    func test_자본이_0이면_0으로_나누지_않는다() {
        let s = BudgetDonutSegments(capital: 0, used: 0, planned: 0)
        XCTAssertEqual(s.usedPercent, 0)
        XCTAssertEqual(s.ratio(100), 0)
        XCTAssertNil(s.capitalMark)
    }

    func test_자본이_0인데_쓴_게_있으면_전부_초과다() {
        let s = BudgetDonutSegments(capital: 0, used: 500, planned: 0)
        XCTAssertEqual(s.total, 500)
        XCTAssertEqual(s.withinCapital, 0)
        XCTAssertEqual(s.overUsed, 500)
        XCTAssertEqual(s.usedPercent, 0, "자본이 0이면 비율을 말할 수 없다")
    }

    func test_사용과_예정이_정확히_자본이면_눈금이_없다() {
        let s = BudgetDonutSegments(capital: 1000, used: 600, planned: 400)
        XCTAssertEqual(s.overAmount, 0)
        XCTAssertNil(s.capitalMark)
        XCTAssertEqual(s.remaining, 0)
        XCTAssertTrue(s.fitsInRing)
    }

    // MARK: - 세 구간의 합

    func test_어느_경우에도_한_바퀴를_넘지_않는다() {
        let cases = [
            (1000, 300, 200), (1000, 1240, 0), (1000, 800, 400),
            (1000, 0, 0), (0, 500, 0), (1000, 600, 400), (500, 900, 900),
        ]
        for (capital, used, planned) in cases {
            let s = BudgetDonutSegments(capital: capital, used: used, planned: planned)
            XCTAssertTrue(
                s.fitsInRing,
                "자본 \(capital) · 사용 \(used) · 예정 \(planned) 에서 구간이 겹친다"
            )
        }
    }

    // MARK: - 사용률

    func test_사용률은_반올림한다() {
        // 웹 `Math.round` 와 같아야 한다.
        XCTAssertEqual(BudgetDonutSegments(capital: 3, used: 2, planned: 0).usedPercent, 67)
        XCTAssertEqual(BudgetDonutSegments(capital: 5000, used: 2150, planned: 0).usedPercent, 43)
    }

    // MARK: - 사용 후 잔액

    func test_사용_후_잔액은_남은_금액과_다르다() {
        let s = BudgetDonutSegments(capital: 1000, used: 300, planned: 200)
        XCTAssertEqual(s.savings, 700, "사용만 뺀 값")
        XCTAssertEqual(s.remaining, 500, "예정까지 뺀 값")
    }

    // MARK: - 응답에서 바로 만들기

    func test_응답에서_그대로_만든다() {
        let detail = AmountDetail(
            initialCapital: 5000,
            totalPlannedAndUsedAmount: 3000,
            plannedUseAmount: 850,
            usedAmount: 2150
        )
        let s = BudgetDonutSegments(detail)
        XCTAssertEqual(s.capital, 5000)
        XCTAssertEqual(s.used, 2150)
        XCTAssertEqual(s.planned, 850)
        XCTAssertEqual(s.remaining, detail.remaining)
        XCTAssertEqual(s.savings, detail.savings)
        XCTAssertEqual(s.usedPercent, detail.usedPercent)
    }
}
