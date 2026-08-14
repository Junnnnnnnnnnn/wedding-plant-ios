import XCTest
@testable import WPUtils

final class KstDateTests: XCTestCase {

    /// UTC 기준 시각을 만드는 헬퍼. 테스트가 실행 머신의 타임존에 의존하지 않게 한다.
    private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: components)!
    }

    // MARK: - today

    func test_today_KST자정_직전은_전날이다() {
        // UTC 14:59 = KST 23:59 (같은 날)
        let now = utc(2026, 8, 14, 14, 59)
        XCTAssertEqual(KstDate.today(now: now).dateString, "2026-08-14")
    }

    func test_today_KST자정_직후는_다음날이다() {
        // UTC 15:00 = KST 다음날 00:00 — 웹에서 가장 흔했던 오프바이원 지점
        let now = utc(2026, 8, 14, 15, 0)
        XCTAssertEqual(KstDate.today(now: now).dateString, "2026-08-15")
    }

    func test_today_연말_경계() {
        // UTC 2026-12-31 16:00 = KST 2027-01-01 01:00
        let now = utc(2026, 12, 31, 16, 0)
        let today = KstDate.today(now: now)
        XCTAssertEqual(today.year, 2027)
        XCTAssertEqual(today.month, 1)
        XCTAssertEqual(today.day, 1)
    }

    func test_todayString_은_today의_dateString과_같다() {
        let now = utc(2026, 3, 5, 2, 0)
        XCTAssertEqual(KstDate.todayString(now: now), KstDate.today(now: now).dateString)
    }

    // MARK: - 파싱

    func test_dateString_파싱() {
        let date = KstDate(dateString: "2026-08-14")
        XCTAssertEqual(date?.year, 2026)
        XCTAssertEqual(date?.month, 8)
        XCTAssertEqual(date?.day, 14)
    }

    func test_ISO문자열도_앞_10자만_읽어_파싱된다() {
        // 웹의 parseLocalDate는 ISO 문자열에서 null을 반환했다. createDate 같은 필드를
        // 다루려면 이쪽이 필요하므로 의도적으로 더 관대하게 만들었다.
        let date = KstDate(dateString: "2026-08-14T09:30:00Z")
        XCTAssertEqual(date?.dateString, "2026-08-14")
    }

    func test_존재하지_않는_날짜는_nil이다() {
        // 웹은 2026-02-30을 3월로 굴려버렸다. 여기서는 실패로 취급한다.
        XCTAssertNil(KstDate(dateString: "2026-02-30"))
        XCTAssertNil(KstDate(year: 2026, month: 2, day: 30))
        XCTAssertNil(KstDate(year: 2026, month: 13, day: 1))
        XCTAssertNil(KstDate(year: 2026, month: 0, day: 1))
    }

    func test_윤년_2월29일은_유효하다() {
        XCTAssertNotNil(KstDate(year: 2028, month: 2, day: 29))
        XCTAssertNil(KstDate(year: 2026, month: 2, day: 29))
    }

    func test_형식이_어긋나면_nil이다() {
        XCTAssertNil(KstDate(dateString: ""))
        XCTAssertNil(KstDate(dateString: "2026-08"))
        XCTAssertNil(KstDate(dateString: "20260814"))
        XCTAssertNil(KstDate(dateString: "abcd-ef-gh"))
        XCTAssertNil(KstDate(dateString: "26-08-14"))
    }

    func test_dateString은_0으로_패딩된다() {
        XCTAssertEqual(KstDate(year: 2026, month: 1, day: 5)?.dateString, "2026-01-05")
    }

    // MARK: - 날짜 계산

    func test_days_until() {
        let start = KstDate(year: 2026, month: 8, day: 14)!
        let end = KstDate(year: 2026, month: 9, day: 1)!
        XCTAssertEqual(start.days(until: end), 18)
        XCTAssertEqual(end.days(until: start), -18)
        XCTAssertEqual(start.days(until: start), 0)
    }

    func test_daysFromToday_는_D_day를_돌려준다() {
        let now = utc(2026, 8, 14, 3, 0) // KST 2026-08-14 12:00
        let weddingDay = KstDate(year: 2026, month: 8, day: 24)!
        XCTAssertEqual(weddingDay.daysFromToday(now: now), 10)
    }

    func test_adding_days_는_월_경계를_넘는다() {
        let date = KstDate(year: 2026, month: 8, day: 30)!
        XCTAssertEqual(date.adding(days: 3).dateString, "2026-09-02")
        XCTAssertEqual(date.adding(days: -30).dateString, "2026-07-31")
    }

    func test_비교_가능하다() {
        XCTAssertTrue(KstDate(year: 2026, month: 1, day: 2)! < KstDate(year: 2026, month: 2, day: 1)!)
        XCTAssertTrue(KstDate(year: 2025, month: 12, day: 31)! < KstDate(year: 2026, month: 1, day: 1)!)
    }

    func test_Codable_왕복() throws {
        let original = KstDate(year: 2026, month: 8, day: 14)!
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(KstDate.self, from: data), original)
    }
}
