import XCTest
@testable import WPDomain
import WPModels

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

    func testSaveResponseKeepsLocalUrlWhenServerSendsNone() {
        let local = [InvitationPhotoDto(key: "new", url: "file:///new.webp"), InvitationPhotoDto(key: "old", url: "file:///old.webp")]
        let remote = [InvitationPhotoDto(key: "new"), InvitationPhotoDto(key: "old", url: "https://r2/old.webp"), InvitationPhotoDto(key: "other")]
        let merged = InvitationRules.mergePhotos(local: local, remote: remote)
        XCTAssertEqual(merged.map(\.key), ["new", "old", "other"], "서버 순서 · 키를 따른다")
        XCTAssertEqual(merged.map(\.url), ["file:///new.webp", "https://r2/old.webp", nil], "서버 주소가 있으면 그것, 없으면 이 기기의 주소")
    }
}
