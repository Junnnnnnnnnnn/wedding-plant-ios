import XCTest
@testable import WPModels

/// 신랑·신부 정책. 웹 CLAUDE.md 의 권한 표를 그대로 고정한다.
///
/// |          | 플랜 편집 | 채팅 |
/// | -------- | --------- | ---- |
/// | `OWNER`  | 가능      | 가능 |
/// | `SPOUSE` | 가능      | 가능 |
/// | `WRITE`  | 가능      | 가능 |
/// | `READ`   | **불가**  | 가능 |
final class PermissionTests: XCTestCase {

    func test_읽기_전용만_편집을_못_한다() {
        XCTAssertTrue(PlanPermission.owner.canEdit)
        XCTAssertTrue(PlanPermission.spouse.canEdit)
        XCTAssertTrue(PlanPermission.write.canEdit)
        XCTAssertFalse(PlanPermission.read.canEdit)
    }

    func test_배우자는_자기_플랜을_고칠_수_있다() {
        // 회귀 방지: 예전에는 `owner || write` 로 긍정 열거라 SPOUSE 가 빠졌고,
        // 귀속으로 자기 플랜이 된 방을 배우자가 못 고쳤다.
        XCTAssertTrue(PlanPermission.spouse.canEdit)
    }

    func test_모르는_권한이_생겨도_편집을_막지_않는다() {
        // 백엔드에 권한이 늘어도 "READ 면 거절" 이라 게이트를 고칠 필요가 없다.
        XCTAssertTrue(PlanPermission(rawValue: "MANAGER").canEdit)
    }

    func test_단일_값으로_디코딩된다() throws {
        let decoded = try JSONDecoder().decode([PlanPermission].self, from: Data(#"["OWNER","SPOUSE","READ"]"#.utf8))
        XCTAssertEqual(decoded, [.owner, .spouse, .read])
    }
}
