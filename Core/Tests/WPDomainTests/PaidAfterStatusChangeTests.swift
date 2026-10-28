import XCTest
@testable import WPDomain
@testable import WPModels

/// Android `PaymentRulesTest`(7523938) — 서버의 isPaid 는 계산값(완료면 늘 true)이라 상태를 바꾼 뒤에는 응답 값을 쓴다.
final class PaidAfterStatusChangeTests: XCTestCase {
    func testUndoFollowsStatusResponse() {
        // 미결제 일정: 완료 → 예정. 응답은 바뀐 뒤로 다시 계산한 false
        XCTAssertEqual(PlanRules.isPaidAfterStatusChange(responseIsPaid: false, toCompleted: false, before: true), false)
        // 미리 낸 계약금은 예정으로 되돌려도 결제함이 남는다
        XCTAssertEqual(PlanRules.isPaidAfterStatusChange(responseIsPaid: true, toCompleted: false, before: true), true)
    }

    func testNoResponseValueNeverGuessesPaidWhenGoingBack() {
        XCTAssertNil(PlanRules.isPaidAfterStatusChange(responseIsPaid: nil, toCompleted: false, before: true))
        // 완료로 갈 때는 어차피 결제로 읽히므로 들고 있던 값을 둔다
        XCTAssertEqual(PlanRules.isPaidAfterStatusChange(responseIsPaid: nil, toCompleted: true, before: false), false)
    }

    func testEnvelopeParsingToleratesOldServers() {
        XCTAssertEqual(StatusChangeResult.isPaid(fromEnvelope: Data(#"{"result":true,"data":{"isPaid":false}}"#.utf8)), false)
        XCTAssertEqual(StatusChangeResult.isPaid(fromEnvelope: Data(#"{"result":true,"data":{"isPaid":true}}"#.utf8)), true)
        XCTAssertNil(StatusChangeResult.isPaid(fromEnvelope: Data(#"{"result":true}"#.utf8)), "옛 서버 — data 없음")
        XCTAssertNil(StatusChangeResult.isPaid(fromEnvelope: Data()), "빈 본문")
    }
}
