import XCTest
@testable import WPDomain

/// 청첩장 사진 WebP · 20장 표지 교체 · 새 축하 수 — Android `InvitationRulesTest` · `HomeInvitationRulesTest` ·
/// `InvitationWorkflowAuditTest` 와 같은 경우.
final class InvitationPhotoRulesTests: XCTestCase {
    func testPhotosAreWebpEightyAtSixteenHundred() {
        XCTAssertEqual(InvitationRules.photoContentType, "image/webp")
        XCTAssertEqual(InvitationRules.photoWebpQuality, 80)
        XCTAssertEqual(InvitationRules.photoMaxEdge, 1600)
        XCTAssertEqual(InvitationRules.photoMaxUploadBytes, 8 * 1024 * 1024)
    }

    func testCoverGoesFirstAndReplacesOldCoverOnlyWhenFull() {
        XCTAssertEqual(InvitationRules.withCover(["a", "b"], "n"), ["n", "a", "b"])
        let full = (0..<20).map { "p\($0)" }
        let replaced = InvitationRules.withCover(full, "n")
        XCTAssertEqual(replaced.count, 20)
        XCTAssertEqual(replaced.first, "n")
        XCTAssertEqual(Array(replaced.dropFirst()), Array(full.dropFirst()))
    }

    func testFreshWishesNeedsBothNumbers() {
        XCTAssertEqual(InvitationRules.freshWishes(total: 5, seen: 3), 2)
        XCTAssertEqual(InvitationRules.freshWishes(total: 3, seen: 5), 0)
        XCTAssertEqual(InvitationRules.freshWishes(total: nil, seen: 1), 0)
        XCTAssertEqual(InvitationRules.freshWishes(total: 4, seen: nil), 0)
    }
}
