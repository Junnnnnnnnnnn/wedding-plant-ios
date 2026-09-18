import XCTest
@testable import WPDomain

/// 초대 링크 만들기.
///
/// **`?as=spouse` 가 빠지면 배우자로 부르고도 상대가 `READ` 로 들어온다.**
/// 초대 링크가 역할을 지니므로 이 한 글자가 정책 전체를 바꾼다.
final class InviteURLTests: XCTestCase {

    private let base = "https://weddingplant.app"

    func test_배우자_초대에는_역할이_붙는다() {
        XCTAssertEqual(
            ShareLink.inviteURL(webBaseURL: base, code: "ABC123", asSpouse: true),
            "https://weddingplant.app/share/ABC123?as=spouse"
        )
    }

    func test_조언자_초대에는_역할이_없다() {
        // 그냥 들어오면 READ 다 — 남의 플랜을 같이 보며 거드는 자리.
        XCTAssertEqual(
            ShareLink.inviteURL(webBaseURL: base, code: "ABC123", asSpouse: false),
            "https://weddingplant.app/share/ABC123"
        )
    }

    func test_주소_끝의_슬래시를_두_번_넣지_않는다() {
        XCTAssertEqual(
            ShareLink.inviteURL(webBaseURL: "https://weddingplant.app/", code: "X1", asSpouse: false),
            "https://weddingplant.app/share/X1"
        )
    }

    func test_코드_앞뒤_공백을_턴다() {
        XCTAssertEqual(
            ShareLink.inviteURL(webBaseURL: base, code: "  X1  ", asSpouse: true),
            "https://weddingplant.app/share/X1?as=spouse"
        )
    }

    func test_코드가_비면_링크를_만들지_않는다() {
        XCTAssertNil(ShareLink.inviteURL(webBaseURL: base, code: "", asSpouse: true))
        XCTAssertNil(ShareLink.inviteURL(webBaseURL: base, code: "   ", asSpouse: false))
    }

    func test_주소가_비면_링크를_만들지_않는다() {
        XCTAssertNil(ShareLink.inviteURL(webBaseURL: "", code: "X1", asSpouse: false))
    }

    func test_만든_링크를_다시_읽으면_같은_코드다() {
        let url = ShareLink.inviteURL(webBaseURL: base, code: "ABC123", asSpouse: true)!
        // 쿼리가 붙어도 코드만 읽어야 한다.
        XCTAssertEqual(ShareLink.shareCode(from: url), "ABC123")
    }
}
