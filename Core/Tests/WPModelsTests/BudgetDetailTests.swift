import XCTest
@testable import WPModels

/// 예산 상세 화면이 쓰는 파생 수치.
///
/// "남은 금액"과 "사용 후 잔액"은 **같은 화면에 둘 다** 나오는데 계산식이 다르다.
/// 웹·안드로이드에서도 반복해서 헷갈렸던 부분이라 여기서 못 박아 둔다.
final class BudgetDetailTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - AmountDetail

    private let sample = AmountDetail(
        initialCapital: 5000,
        totalPlannedAndUsedAmount: 3400,
        plannedUseAmount: 1250,
        usedAmount: 2150
    )

    func test_남은금액은_예정과_사용을_모두_뺀다() {
        XCTAssertEqual(sample.remaining, 5000 - (1250 + 2150))
        XCTAssertEqual(sample.remaining, 1600)
    }

    func test_사용후잔액은_사용만_뺀다() {
        XCTAssertEqual(sample.savings, 5000 - 2150)
        XCTAssertEqual(sample.savings, 2850)
    }

    func test_남은금액과_사용후잔액은_다른_수치다() {
        XCTAssertNotEqual(sample.remaining, sample.savings)
    }

    func test_예정과_사용이_초기자본을_넘으면_남은금액은_음수() {
        let over = AmountDetail(
            initialCapital: 1000,
            totalPlannedAndUsedAmount: 1500,
            plannedUseAmount: 900,
            usedAmount: 600
        )
        XCTAssertEqual(over.remaining, -500)
        // 사용만 뺀 값은 아직 양수일 수 있다.
        XCTAssertEqual(over.savings, 400)
    }

    func test_사용률은_초기자본이_0이면_0() {
        let zero = AmountDetail(
            initialCapital: 0,
            totalPlannedAndUsedAmount: 300,
            plannedUseAmount: 100,
            usedAmount: 200
        )
        XCTAssertEqual(zero.usedPercent, 0)
    }

    func test_사용률은_내림한다() {
        // 2150 / 5000 = 43%
        XCTAssertEqual(sample.usedPercent, 43)

        let odd = AmountDetail(
            initialCapital: 3,
            totalPlannedAndUsedAmount: 2,
            plannedUseAmount: 0,
            usedAmount: 2
        )
        // 66.66... → 66
        XCTAssertEqual(odd.usedPercent, 66)
    }

    // MARK: - CategoryChartItem

    func test_카테고리_비율() {
        XCTAssertEqual(
            CategoryChartItem(categoryName: "웨딩홀", totalAmount: 1400, usedAmount: 700).ratio,
            0.5,
            accuracy: 0.0001
        )
    }

    func test_계획이_없는데_쓴_돈이_있으면_100퍼센트() {
        let item = CategoryChartItem(categoryName: "본식스냅", totalAmount: 0, usedAmount: 500)
        XCTAssertEqual(item.ratio, 1)
    }

    func test_둘_다_없으면_0퍼센트() {
        XCTAssertEqual(CategoryChartItem(categoryName: "예물").ratio, 0)
    }

    func test_계획보다_많이_썼어도_1을_넘지_않는다() {
        let item = CategoryChartItem(categoryName: "드레스", totalAmount: 100, usedAmount: 400)
        XCTAssertEqual(item.ratio, 1)
    }

    func test_차트응답_디코딩() throws {
        let page = try decode(CategoryChartPage.self, """
        {"list":[
          {"categoryName":"웨딩홀","totalAmount":"1400","usedAmount":1200.0},
          {"categoryName":"예물","totalAmount":null,"usedAmount":null}
        ]}
        """)
        XCTAssertEqual(page.list.count, 2)
        // 문자열·소수로 와도 관대하게 받는다 (@LooseInt)
        XCTAssertEqual(page.list[0].total, 1400)
        XCTAssertEqual(page.list[0].used, 1200)
        XCTAssertEqual(page.list[1].total, 0)
        XCTAssertEqual(page.list[1].used, 0)
    }

    func test_list가_없어도_빈_배열로_디코딩된다() throws {
        let page = try decode(CategoryChartPage.self, #"{"total":0}"#)
        XCTAssertTrue(page.list.isEmpty)
    }
}
