import XCTest
import WPModels
import WPUtils
@testable import WPDomain

final class GuestMigrationTests: XCTestCase {

    private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: components)!
    }

    private let weddingDate = KstDate(year: 2026, month: 10, day: 10)!

    func test_동의일이_없으면_KST_오늘로_채운다() {
        let now = utc(2026, 8, 14, 16) // KST 2026-08-15 01:00
        let request = GuestMigration.settingRequest(
            weddingDate: weddingDate,
            budget: 5000,
            name: "지수",
            agreement: nil,
            now: now
        )
        XCTAssertEqual(request.requiredAgreementDate, "2026-08-15")
        XCTAssertNil(request.adAgreementDate)
        XCTAssertEqual(request.weddingDate, "2026-10-10")
        XCTAssertEqual(request.budget, 5000)
    }

    func test_기존_동의일이_있으면_그대로_보낸다() {
        let request = GuestMigration.settingRequest(
            weddingDate: weddingDate,
            budget: nil,
            name: "지수",
            agreement: AgreementData(requiredAgreementDate: "2026-08-01", adAgreementDate: "2026-08-02"),
            now: utc(2026, 8, 14, 1)
        )
        XCTAssertEqual(request.requiredAgreementDate, "2026-08-01")
        XCTAssertEqual(request.adAgreementDate, "2026-08-02")
        XCTAssertEqual(request.budget, 0, "예산 미입력은 0으로 보낸다 (웹과 동일)")
    }

    func test_게스트_일정을_등록요청으로_변환한다() {
        let now = utc(2026, 8, 14, 1) // KST 2026-08-14 10:00
        let items = [
            ScheduleItem(id: -1, categoryName: "웨딩홀", title: "상담", amount: 300, startDate: "2026-09-01"),
            ScheduleItem(id: -2, categoryName: "스튜디오", title: "촬영", startDate: nil),
        ]

        let requests = GuestMigration.scheduleRequests(from: items, roomId: 7, now: now)

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].startDate, "2026-09-01")
        XCTAssertEqual(requests[0].amount, 300)
        XCTAssertEqual(requests[0].roomId, 7)
        XCTAssertEqual(requests[1].startDate, "2026-08-14", "시작일이 없으면 KST 오늘로 채운다")
        XCTAssertEqual(requests[1].amount, 0)
    }

    func test_roomId가_없으면_전송하지_않는다() {
        let requests = GuestMigration.scheduleRequests(
            from: [ScheduleItem(id: -1, categoryName: "드레스", title: "가봉")],
            roomId: nil
        )
        XCTAssertNil(requests[0].roomId)
    }

    func test_빈_목록이면_빈_결과다() {
        XCTAssertTrue(GuestMigration.scheduleRequests(from: []).isEmpty)
    }
}

final class BudgetSummaryTests: XCTestCase {

    func test_TotalAmount에서_요약을_만든다() {
        let summary = BudgetSummary(TotalAmount(totalAmount: 5000, usedAmount: 2000, remainingAmount: 3000))
        XCTAssertEqual(summary.total, 5000)
        XCTAssertEqual(summary.used, 2000)
        XCTAssertEqual(summary.remaining, 3000)
        XCTAssertEqual(summary.usedRatio, 0.4, accuracy: 0.0001)
        XCTAssertFalse(summary.isOverBudget)
    }

    func test_remainingAmount가_없으면_계산해서_채운다() {
        let summary = BudgetSummary(TotalAmount(totalAmount: 5000, usedAmount: 2000, remainingAmount: nil))
        XCTAssertEqual(summary.remaining, 3000)
    }

    func test_총액이_0이면_비율은_0이다() {
        XCTAssertEqual(BudgetSummary(TotalAmount()).usedRatio, 0)
    }

    func test_예산_초과를_감지한다() {
        let summary = BudgetSummary(TotalAmount(totalAmount: 1000, usedAmount: 1500, remainingAmount: -500))
        XCTAssertTrue(summary.isOverBudget)
        XCTAssertEqual(summary.usedRatio, 1.0, "비율은 1을 넘지 않도록 클램프된다")
    }
}
