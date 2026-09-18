import XCTest
@testable import WPUtils

final class FormatTests: XCTestCase {

    func test_천_단위로_끊는다() {
        XCTAssertEqual(withThousands(0), "0")
        XCTAssertEqual(withThousands(999), "999")
        XCTAssertEqual(withThousands(1000), "1,000")
        XCTAssertEqual(withThousands(12345), "12,345")
        XCTAssertEqual(withThousands(1234567), "1,234,567")
    }

    func test_음수도_끊는다() {
        // 예산을 넘기면 남은 금액이 음수가 된다.
        XCTAssertEqual(withThousands(-1234), "-1,234")
    }

    func test_소수는_반올림한다() {
        XCTAssertEqual(withThousands(1234.4), "1,234")
        XCTAssertEqual(withThousands(1234.5), "1,235")
    }

    func test_연도_없는_짧은_날짜() {
        let d = KstDate(dateString: "2026-09-12")!
        XCTAssertEqual(d.monthDayWeekText, "9월 12일 (토)")
        XCTAssertEqual(d.monthDayText, "9월 12일")
    }
}
