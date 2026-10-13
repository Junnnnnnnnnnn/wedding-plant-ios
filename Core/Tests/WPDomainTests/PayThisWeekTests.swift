import XCTest
import WPDomain
import WPModels
import WPUtils

final class PayThisWeekTests: XCTestCase {
    private let today = KstDate(dateString: "2026-12-29")!
    private func item(_ id: Int, days: Int?, amount: Double? = 1.25, paid: Bool? = nil, completed: Bool = false) -> ScheduleItem {
        ScheduleItem(id: id, categoryName: "예물", title: "결제 \(id)", amount: amount,
            startDate: days.map { today.adding(days: $0).dateString },
            status: .init(rawValue: completed ? "COMPLETED" : "PLANNED"), isPaid: paid)
    }
    func testInclusiveSevenDayWindowAcrossYearAndStableOrder() {
        let entries = PayThisWeek.pick([item(1, days: 7), item(2, days: -1), item(3, days: 0), item(4, days: 8), item(5, days: 7), item(6, days: nil)], today: today)
        XCTAssertEqual(entries.map { $0.item.id }, [3, 1, 5])
        XCTAssertEqual(entries.map(\.days), [0, 7, 7])
    }
    func testAlreadyPaidCompletedAndUnknownOrZeroAmountsAreExcluded() {
        let entries = PayThisWeek.pick([item(1, days: 0, paid: true), item(2, days: 0, paid: false, completed: true), item(3, days: 0, amount: nil), item(4, days: 0, amount: 0), item(5, days: 0, amount: -1), item(6, days: 0, paid: false)], today: today)
        XCTAssertEqual(entries.map { $0.item.id }, [6])
        XCTAssertEqual(entries.first?.item.amount, 1.25)
    }
    func testReminderSummaryUsesConfiguredDaysAndKoreanClock() {
        XCTAssertEqual(PayThisWeek.reminderText(.init(leadDays: [])), "알림 시점을 고르지 않았어요")
        XCTAssertEqual(PayThisWeek.reminderText(.init()), "7일 전 · 하루 전 · 당일 오전 9시")
        XCTAssertEqual(PayThisWeek.reminderText(.init(leadDays: [0, 3, 3], hour: 12)), "3일 전 · 당일 오후 12시")
        XCTAssertEqual(PayThisWeek.reminderText(.init(leadDays: [1], hour: 22)), "하루 전 오후 10시")
    }
}
