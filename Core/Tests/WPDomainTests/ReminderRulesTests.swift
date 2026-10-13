import XCTest
import WPDomain
import WPModels
import WPUtils

final class ReminderRulesTests: XCTestCase {
    func testUpcomingAlertUsesKSTHourBoundaryAndSkipsElapsedLeads() {
        let today = KstDate(dateString: "2026-09-26")!, pay = KstDate(dateString: "2026-09-30")!
        XCTAssertEqual(ReminderRules.nextAlertLabel(payDay: pay, setting: .init(), today: today, nowHour: 10), "다음 알림 9월 29일 오전 9시")
        XCTAssertEqual(ReminderRules.nextAlertLabel(payDay: today, setting: .init(), today: today, nowHour: 8), "다음 알림 오늘 오전 9시")
        XCTAssertEqual(ReminderRules.nextAlertLabel(payDay: today, setting: .init(), today: today, nowHour: 9), "남은 알림 없음")
        XCTAssertEqual(ReminderRules.nextAlertLabel(payDay: pay, setting: .init(leadDays: []), today: today, nowHour: 10), "알림 없음")
        XCTAssertEqual(ReminderRules.nextAlertLabel(payDay: today.adding(days: -1), setting: .init(), today: today, nowHour: 8), "날짜가 지났어요 · 결제 여부 확인")
        XCTAssertEqual(ReminderRules.hourLabel(12), "낮 12시")
    }
    func testPaymentsIncludeOverdueButExcludePaidUnknownUndatedAndDeleted() {
        func item(_ id: Int, amount: Double? = 1.25, date: String? = "2026-09-25", status: String = "NORMAL", paid: Bool = false) -> ScheduleItem {
            .init(id: id, categoryName: "예물", title: "결제", amount: amount, startDate: date, status: .init(rawValue: status), isPaid: paid)
        }
        XCTAssertEqual(ReminderRules.payments([item(1), item(2, paid: true), item(3, amount: nil), item(4, date: nil), item(5, status: "DELETE"), item(6, amount: 0)]).map(\.id), [1])
    }
}
