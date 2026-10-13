import XCTest
import WPDomain
import WPModels
import WPUtils

final class MoneyParityTests: XCTestCase {
    func testServerFractionSurvivesScheduleEditAndExport() throws {
        let json = Data(#"{"id":1,"title":"계약금","amount":"123.456","status":"COMPLETED","isPaid":false}"#.utf8)
        let item = try JSONDecoder().decode(ScheduleItem.self, from: json)
        XCTAssertEqual(item.amount, 123.456)
        XCTAssertEqual(CalendarExport.totals([item]).paid, 123.456)
        let detail = try JSONDecoder().decode(ScheduleDetail.self, from: json)
        XCTAssertEqual(detail.amount, 123.456)
        let request = ScheduleWriteRequest(categoryName: "웨딩홀", title: "계약금 수정", amount: detail.amount!, startDate: "2026-10-13")
        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as! [String: Any]
        XCTAssertEqual(saved["amount"] as? Double, 123.456)
        XCTAssertEqual(withThousands(item.amount!), "123.456")
    }
    func testBudgetFractionAndMissingValues() throws {
        let json = Data(#"{"initialCapital":"1000.5","plannedUseAmount":200.25,"usedAmount":800.5,"totalPlannedAndUsedAmount":1000.75}"#.utf8)
        let detail = try JSONDecoder().decode(AmountDetail.self, from: json)
        XCTAssertEqual(detail.remaining, -0.25)
        XCTAssertEqual(BudgetDonutSegments(detail).overAmount, 0.25)
        let user = try JSONDecoder().decode(PlanUser.self, from: Data(#"{"id":"a","budget":"0.001"}"#.utf8))
        XCTAssertEqual(user.budget, 0.001)
        let invalid = try JSONDecoder().decode(PlanUser.self, from: Data(#"{"id":"a","budget":"Infinity"}"#.utf8))
        XCTAssertNil(invalid.budget)
        let room = try JSONDecoder().decode(Plan.self, from: Data(#"{"roomId":1,"budget":"1000.5","remainingBudget":"-0.25"}"#.utf8))
        XCTAssertEqual(room.budget, 1000.5)
        XCTAssertEqual(room.remainingBudget, -0.25)
    }
    func testAmountEditingDoesNotDropDecimalPoint() {
        XCTAssertEqual(MoneyInput.text(5000), "5000")
        XCTAssertEqual(MoneyInput.accept("1.5", previous: "1"), "1.5")
        XCTAssertEqual(MoneyInput.accept("1,234.567", previous: ""), "1234.567")
        XCTAssertEqual(MoneyInput.accept(".5", previous: ""), "0.5")
        XCTAssertEqual(MoneyInput.accept("1.2.3", previous: "1.2"), "1.2")
        XCTAssertEqual(MoneyInput.accept("9999999999", previous: "10"), "10")
        XCTAssertEqual(MoneyInput.accept("-5", previous: "5"), "5")
    }
}
