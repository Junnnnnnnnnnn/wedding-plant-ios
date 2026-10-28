import XCTest
@testable import WPModels

/// 운영 서버는 좌표를 문자열(`"0.00000000"`)로 준다 — 2026-10-28 iOS QA 에서 일정 상세가 통째로 "응답을 해석하지 못했습니다"
/// 로 막혔다. Android(kotlinx isLenient)처럼 숫자 · 문자열 숫자를 모두 읽는다.
final class ServerNumberDecodingTests: XCTestCase {
    /// 운영 `GET /plan/schedule/{id}` 응답 그대로(QA 계정 일정)
    private let detail = #"{"id":64,"categoryName":"웨딩홀","title":"QA-기본-01","amount":120,"startDate":"2026-10-28","startTime":null,"location":"","locationLat":"0.00000000","locationLng":"0.00000000","memo":"","payType":"CREDIT","status":"NORMAL","isPaid":false}"#

    func testScheduleDetailWithStringCoordinatesDecodes() throws {
        let value = try JSONDecoder().decode(ScheduleDetail.self, from: Data(detail.utf8))
        XCTAssertEqual(value.id, 64)
        XCTAssertEqual(value.amount, 120)
        XCTAssertEqual(value.locationLat, 0)
        XCTAssertEqual(value.isPaidRaw, false)
    }

    func testRealCoordinatesAsStringOrNumberBothWork() throws {
        let quoted = try JSONDecoder().decode(ScheduleDetail.self, from: Data(#"{"id":1,"locationLat":"37.5245","locationLng":"127.0411"}"#.utf8))
        XCTAssertEqual(quoted.locationLat ?? 0, 37.5245, accuracy: 1e-9)
        let number = try JSONDecoder().decode(ScheduleDetail.self, from: Data(#"{"id":1,"locationLat":37.5245,"locationLng":127.0411}"#.utf8))
        XCTAssertEqual(number.locationLng ?? 0, 127.0411, accuracy: 1e-9)
        let item = try JSONDecoder().decode(ScheduleItem.self, from: Data(#"{"id":1,"title":"t","locationLat":"37.1","locationLng":"127.2"}"#.utf8))
        XCTAssertEqual(item.locationLat ?? 0, 37.1, accuracy: 1e-9)
    }
}
