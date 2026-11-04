import XCTest
@testable import WPDomain

/// 공유 링크 파싱. 앱이 열리자마자 도는 코드라 틀려도 조용히 아무 일도 안 일어난다.
final class ShareLinkTests: XCTestCase {

    private func code(_ raw: String) -> String? {
        guard let url = URL(string: raw) else { return nil }
        return ShareLink.shareCode(from: url)
    }

    func test_웹_주소() {
        XCTAssertEqual(code("https://example.com/share/ABC123"), "ABC123")
    }

    func test_뒤에_슬래시가_있어도_된다() {
        XCTAssertEqual(code("https://example.com/share/ABC123/"), "ABC123")
    }

    func test_커스텀_스킴() {
        XCTAssertEqual(code("weddingplant://share/ABC123"), "ABC123")
        XCTAssertEqual(code("weddingplant:///share/ABC123"), "ABC123")
    }

    func test_쿼리가_붙어도_코드만_읽는다() {
        XCTAssertEqual(code("https://example.com/share/ABC123?from=kakao"), "ABC123")
    }

    func test_경로가_더_깊어도_share_다음_조각을_읽는다() {
        XCTAssertEqual(code("https://example.com/ko/share/ABC123"), "ABC123")
    }

    func test_퍼센트_인코딩을_푼다() {
        XCTAssertEqual(code("https://example.com/share/A%20B"), "A B")
    }

    func test_공유_링크가_아니면_nil() {
        XCTAssertNil(code("https://example.com/main"))
        XCTAssertNil(code("https://example.com/"))
        // share 뒤에 코드가 없다
        XCTAssertNil(code("https://example.com/share"))
        XCTAssertNil(code("https://example.com/share/"))
    }

    func test_대소문자를_가리지_않는다() {
        XCTAssertEqual(code("https://example.com/SHARE/ABC123"), "ABC123")
    }

    // MARK: - 문자열 입력

    func test_코드만_넘어와도_받는다() {
        // 로그인 후 이어서 참여할 때 저장해 둔 값은 코드 자체다.
        XCTAssertEqual(ShareLink.shareCode(from: "ABC123"), "ABC123")
        XCTAssertEqual(ShareLink.shareCode(from: "  ABC123  "), "ABC123")
    }

    func test_문자열로_받은_링크() {
        XCTAssertEqual(ShareLink.shareCode(from: "https://example.com/share/ABC123"), "ABC123")
    }

    func test_빈_문자열은_nil() {
        XCTAssertNil(ShareLink.shareCode(from: ""))
        XCTAssertNil(ShareLink.shareCode(from: "   "))
    }

    func test_공유_링크가_아닌_경로는_코드로_보지_않는다() {
        XCTAssertNil(ShareLink.shareCode(from: "https://example.com/main"))
        XCTAssertNil(ShareLink.shareCode(from: "/plan-list"))
    }

    /// 웹 `isShareCode` 와 같은 판정 — 꼴이 아니면 참여 요청을 보내지 않는다(웹 769a075)
    func test_초대_코드_꼴() {
        XCTAssertTrue(ShareLink.isShareCode("0b7e3c2a-1111-4222-8333-444455556666"))
        XCTAssertTrue(ShareLink.isShareCode("0B7E3C2A-1111-4222-8333-444455556666"))
        XCTAssertFalse(ShareLink.isShareCode("leave"))
        XCTAssertFalse(ShareLink.isShareCode("mine"))
        XCTAssertFalse(ShareLink.isShareCode("../auth/logout/all"))
        XCTAssertFalse(ShareLink.isShareCode("0b7e3c2a-1111-4222-8333-44445555666"))   // 35자
        XCTAssertFalse(ShareLink.isShareCode("0b7e3c2a-1111-4222-8333-4444555566667")) // 37자
        XCTAssertFalse(ShareLink.isShareCode("0b7e3c2a-1111-4222-8333-44445555666g"))
        XCTAssertFalse(ShareLink.isShareCode("０b7e3c2a-1111-4222-8333-444455556666")) // 전각 숫자
        XCTAssertFalse(ShareLink.isShareCode(""))
    }

    /// `%2F` 로 감싼 주소는 풀린 뒤 `/` 를 품는다 — 링크 파싱은 그대로 두고 꼴 검사가 막는다
    func test_인코딩된_경로는_꼴_검사에서_걸린다() {
        let invite = ShareLink.invite(from: URL(string: "weddingplant://share/..%2Fauth%2Flogout%2Fall?as=spouse")!)
        XCTAssertNotNil(invite)
        XCTAssertFalse(ShareLink.isShareCode(invite?.code ?? ""))
    }
}
