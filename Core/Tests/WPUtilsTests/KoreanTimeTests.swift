import XCTest
@testable import WPUtils

/// 웹 `formatKoreanTime()` 과 **글자까지** 같은 결과를 내는지 고정한다.
final class KoreanTimeTests: XCTestCase {

    func test_오전과_오후를_가른다() {
        XCTAssertEqual(formatKoreanTime("11:00"), "오전 11:00")
        XCTAssertEqual(formatKoreanTime("13:30"), "오후 1:30")
        XCTAssertEqual(formatKoreanTime("23:59"), "오후 11:59")
    }

    func test_정오와_자정은_12로_적는다() {
        XCTAssertEqual(formatKoreanTime("00:00"), "오전 12:00")
        XCTAssertEqual(formatKoreanTime("12:00"), "오후 12:00")
    }

    func test_한_자리_시각도_받는다() {
        XCTAssertEqual(formatKoreanTime("9:05"), "오전 9:05")
    }

    func test_값이_없으면_빈_문자열이다() {
        XCTAssertEqual(formatKoreanTime(nil), "")
        XCTAssertEqual(formatKoreanTime(""), "")
        XCTAssertEqual(formatKoreanTime("   "), "")
    }

    func test_형식이_아니면_빈_문자열이다() {
        XCTAssertEqual(formatKoreanTime("11"), "")
        XCTAssertEqual(formatKoreanTime("11:0"), "")
        XCTAssertEqual(formatKoreanTime("11:000"), "")
        XCTAssertEqual(formatKoreanTime("24:00"), "", "시는 0~23 만")
        XCTAssertEqual(formatKoreanTime("ab:cd"), "")
        XCTAssertEqual(formatKoreanTime("11:00:00"), "")
    }

    func test_전각_숫자를_받지_않는다() {
        // 웹 정규식 \d 는 ASCII 만 매치한다. 여기도 같아야 한다.
        XCTAssertEqual(formatKoreanTime("１１:００"), "")
    }
}
