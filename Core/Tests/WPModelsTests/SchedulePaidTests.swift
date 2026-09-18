import XCTest
@testable import WPModels

/// 결제 축(`isPaid`)은 일정 완료(`status`)와 **다른 축**이다.
/// 웹 `lib/schedulePaid.ts` · 백엔드 `isSchedulePaid()` 와 같은 규칙인지 고정한다.
final class SchedulePaidTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func item(status: String?, isPaid: Bool?) -> ScheduleItem {
        ScheduleItem(
            id: 1,
            categoryName: "예식장",
            title: "본식",
            status: status.map { ScheduleStatus(rawValue: $0) },
            isPaid: isPaid
        )
    }

    // MARK: - 네 칸

    func test_예정_미결제() {
        let x = item(status: "PLANNED", isPaid: false)
        XCTAssertFalse(x.isPaid)
        XCTAssertFalse(x.isScheduleCompleted)
        XCTAssertNil(x.paymentMismatch, "대부분의 일정이라 아무 표시도 붙이지 않는다")
    }

    func test_예정_결제_미리_낸_계약금() {
        let x = item(status: "PLANNED", isPaid: true)
        XCTAssertTrue(x.isPaid, "통장에서 이미 빠져나간 돈이다")
        XCTAssertFalse(x.isScheduleCompleted)
        XCTAssertEqual(x.paymentMismatch, .paidAhead)
        XCTAssertEqual(x.paymentMismatch?.label, "결제함")
    }

    func test_완료_결제() {
        let x = item(status: "COMPLETED", isPaid: true)
        XCTAssertTrue(x.isPaid)
        XCTAssertTrue(x.isScheduleCompleted)
        XCTAssertNil(x.paymentMismatch, "예전의 완료와 같은 모습이다")
    }

    func test_완료_미결제_정산_전() {
        let x = item(status: "COMPLETED", isPaid: false)
        XCTAssertFalse(x.isPaid, "끝났어도 아직 쓴 돈이 아니다")
        XCTAssertTrue(x.isScheduleCompleted)
        XCTAssertEqual(x.paymentMismatch, .unpaidDone)
        XCTAssertEqual(x.paymentMismatch?.label, "미결제")
    }

    // MARK: - nil 은 false 가 아니다 (가장 중요한 규칙)

    func test_값이_없는_예전_완료_일정은_결제로_읽는다() {
        let x = item(status: "COMPLETED", isPaid: nil)
        XCTAssertTrue(x.isPaid, "이 컬럼이 생기기 전에는 완료가 곧 결제였다")
        XCTAssertNil(x.paymentMismatch)
    }

    func test_값이_없는_예전_예정_일정은_미결제다() {
        let x = item(status: "PLANNED", isPaid: nil)
        XCTAssertFalse(x.isPaid)
        XCTAssertNil(x.paymentMismatch)
    }

    func test_nil을_false로_다루면_지출이_0이_된다() {
        // 회귀 방지: 쌓여 있는 완료 일정에 isPaid 가 없다.
        let 완료들 = (1...5).map { _ in item(status: "COMPLETED", isPaid: nil) }
        XCTAssertEqual(완료들.filter(\.isPaid).count, 5)
    }

    // MARK: - 디코딩

    func test_응답의_isPaid_필드를_읽는다() throws {
        let x = try decode(ScheduleItem.self, """
        { "id": 7, "title": "스드메", "categoryName": "스튜디오", "isPaid": true, "status": "PLANNED" }
        """)
        XCTAssertEqual(x.isPaidRaw, true)
        XCTAssertTrue(x.isPaid)
        XCTAssertEqual(x.paymentMismatch, .paidAhead)
    }

    func test_isPaid_키가_없으면_원값은_nil이다() throws {
        let x = try decode(ScheduleItem.self, #"{ "id": 7, "title": "a", "status": "COMPLETED" }"#)
        XCTAssertNil(x.isPaidRaw)
        XCTAssertTrue(x.isPaid, "없으면 status 로 읽는다")
    }

    func test_상세도_같은_규칙이다() throws {
        let x = try decode(ScheduleDetail.self, #"{ "id": 3, "status": "COMPLETED" }"#)
        XCTAssertNil(x.isPaidRaw)
        XCTAssertTrue(x.isPaid)
    }

    // MARK: - 전송

    func test_요청바디는_보낸_필드만_싣는다() throws {
        let encoder = JSONEncoder()

        let 안보냄 = ScheduleWriteRequest(categoryName: "a", title: "b", startDate: nil)
        let json1 = String(decoding: try encoder.encode(안보냄), as: UTF8.self)
        XCTAssertFalse(json1.contains("isPaid"), "nil 이면 키가 빠져 변경 없음이다")
        XCTAssertFalse(json1.contains("startTime"))

        let 보냄 = ScheduleWriteRequest(
            categoryName: "a", title: "b", startDate: "2026-11-14",
            isPaid: true, startTime: "11:00"
        )
        let json2 = String(decoding: try encoder.encode(보냄), as: UTF8.self)
        XCTAssertTrue(json2.contains("\"isPaid\":true"))
        XCTAssertTrue(json2.contains("11:00"))
    }

    func test_시각을_지우려면_빈_문자열을_보낸다() throws {
        let 지움 = ScheduleWriteRequest(
            categoryName: "a", title: "b", startDate: "2026-11-14", startTime: ""
        )
        let json = String(decoding: try JSONEncoder().encode(지움), as: UTF8.self)
        XCTAssertTrue(json.contains("\"startTime\":\"\""), "키를 빼면 기존 시각이 남는다")
    }
}
