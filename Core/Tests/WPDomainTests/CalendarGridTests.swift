import XCTest
import WPUtils
@testable import WPDomain

/// 달력 격자. 한 칸만 밀려도 화면 전체가 틀어지므로 경계를 촘촘히 본다.
final class CalendarGridTests: XCTestCase {

    private func date(_ string: String) -> KstDate {
        KstDate(dateString: string)!
    }

    // MARK: - 격자

    func test_항상_42칸이다() {
        // 1일이 무슨 요일이든, 그 달이 며칠이든 42칸
        for month in 1...12 {
            XCTAssertEqual(CalendarGrid.build(year: 2026, month: month).count, 42)
        }
        // 2월이 28일인 해와 29일인 해 모두
        XCTAssertEqual(CalendarGrid.build(year: 2024, month: 2).count, 42)
    }

    func test_첫_칸은_1일이_속한_주의_일요일() {
        // 2026-08-01 은 토요일 → 그 주 일요일은 7월 26일
        let august = CalendarGrid.build(year: 2026, month: 8)
        XCTAssertEqual(august.first, date("2026-07-26"))
        XCTAssertEqual(august[6], date("2026-08-01"))

        // 1일이 일요일이면 패딩 없이 1일부터 시작한다 (2026-11-01 은 일요일)
        let november = CalendarGrid.build(year: 2026, month: 11)
        XCTAssertEqual(november.first, date("2026-11-01"))
    }

    func test_모든_칸이_하루씩_이어진다() {
        let cells = CalendarGrid.build(year: 2026, month: 2)
        for index in 1..<cells.count {
            XCTAssertEqual(cells[index - 1].adding(days: 1), cells[index])
        }
    }

    func test_이번_달_날짜가_모두_들어있다() {
        let cells = Set(CalendarGrid.build(year: 2026, month: 2))
        for day in 1...28 {
            XCTAssertTrue(cells.contains(KstDate(year: 2026, month: 2, day: day)!))
        }
    }

    func test_연도를_넘는_달() {
        // 2026-01-01 은 목요일 → 앞 패딩이 2025년 12월로 넘어간다
        let january = CalendarGrid.build(year: 2026, month: 1)
        XCTAssertEqual(january.first, date("2025-12-28"))

        // 12월은 뒤 패딩이 다음 해 1월로 넘어간다
        let december = CalendarGrid.build(year: 2026, month: 12)
        XCTAssertEqual(december.last?.year, 2027)
    }

    // MARK: - 받아올 달

    func test_앞_현재_뒤_세_달을_받는다() {
        let months = CalendarGrid.monthsToFetch(cursor: date("2026-08-01"))
        XCTAssertEqual(months.count, 3)
        XCTAssertEqual(months[0].year, 2026)
        XCTAssertEqual(months[0].month, 7)
        XCTAssertEqual(months[1].month, 8)
        XCTAssertEqual(months[2].month, 9)
    }

    func test_1월과_12월은_해를_넘어간다() {
        let january = CalendarGrid.monthsToFetch(cursor: date("2026-01-01"))
        XCTAssertEqual(january[0].year, 2025)
        XCTAssertEqual(january[0].month, 12)

        let december = CalendarGrid.monthsToFetch(cursor: date("2026-12-01"))
        XCTAssertEqual(december[2].year, 2027)
        XCTAssertEqual(december[2].month, 1)
    }

    func test_요일_머리글은_일요일부터() {
        XCTAssertEqual(CalendarGrid.weekdayLabels, ["일", "월", "화", "수", "목", "금", "토"])
    }
}

/// 격자가 기대는 `KstDate` 확장.
final class KstMonthTests: XCTestCase {

    private func date(_ string: String) -> KstDate {
        KstDate(dateString: string)!
    }

    func test_요일_인덱스는_일요일이_0() {
        XCTAssertEqual(date("2026-08-02").weekdayIndex, 0) // 일
        XCTAssertEqual(date("2026-08-03").weekdayIndex, 1) // 월
        XCTAssertEqual(date("2026-08-08").weekdayIndex, 6) // 토
    }

    func test_weekdayShort_와_인덱스를_섞어_쓰면_안_된다() {
        // weekdayShort 는 월요일 시작이라 인덱스 기준이 다르다. 회귀 방지용.
        let sunday = date("2026-08-02")
        XCTAssertEqual(sunday.weekdayShort, "일")
        XCTAssertEqual(sunday.weekdayIndex, 0)

        let monday = date("2026-08-03")
        XCTAssertEqual(monday.weekdayShort, "월")
        XCTAssertEqual(monday.weekdayIndex, 1)
    }

    func test_월_단위_이동() {
        XCTAssertEqual(date("2026-08-01").addingMonths(1), date("2026-09-01"))
        XCTAssertEqual(date("2026-08-01").addingMonths(-1), date("2026-07-01"))
        XCTAssertEqual(date("2026-01-01").addingMonths(-1), date("2025-12-01"))
        XCTAssertEqual(date("2026-12-01").addingMonths(1), date("2027-01-01"))
        XCTAssertEqual(date("2026-08-01").addingMonths(0), date("2026-08-01"))
    }

    func test_열두_달_이상_이동() {
        XCTAssertEqual(date("2026-08-01").addingMonths(12), date("2027-08-01"))
        XCTAssertEqual(date("2026-08-01").addingMonths(-12), date("2025-08-01"))
        XCTAssertEqual(date("2026-08-01").addingMonths(-20), date("2024-12-01"))
    }

    func test_대상_달에_없는_날짜는_말일로_자른다() {
        // 웹의 `new Date(y, m+1, d)` 는 3월 3일로 넘어가지만, 여기서는 2월 말일로 자른다
        XCTAssertEqual(date("2026-01-31").addingMonths(1), date("2026-02-28"))
        XCTAssertEqual(date("2024-01-31").addingMonths(1), date("2024-02-29"))
        XCTAssertEqual(date("2026-03-31").addingMonths(-1), date("2026-02-28"))
    }

    func test_그_달의_1일() {
        XCTAssertEqual(date("2026-08-14").firstOfMonth, date("2026-08-01"))
        XCTAssertEqual(date("2026-08-01").firstOfMonth, date("2026-08-01"))
    }
}
