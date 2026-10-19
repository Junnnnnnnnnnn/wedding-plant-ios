import XCTest
@testable import WPDomain

/// Android `DocumentStageTest` 와 같은 기대값
final class DocumentStageTests: XCTestCase {
    func test_새로_고른_것만_더하고_같은_것은_한_번() {
        let (kept, dropped) = DocumentRules.stage(["a", "b"], picked: ["b", "c", "c", "d"])
        XCTAssertEqual(kept, ["a", "b", "c", "d"])
        XCTAssertEqual(dropped, 0)
    }

    func test_한도는_전체_개수다() {
        let current = (1...8).map(String.init)
        let (kept, dropped) = DocumentRules.stage(current, picked: ["x", "y", "z"])
        XCTAssertEqual(kept.count, DocumentRules.maxStaged)
        XCTAssertEqual(kept.suffix(2), ["x", "y"])
        XCTAssertEqual(dropped, 1)
    }

    func test_다_찼으면_모두_뺀다() {
        let full = (1...10).map(String.init)
        let (kept, dropped) = DocumentRules.stage(full, picked: ["x"])
        XCTAssertEqual(kept, full)
        XCTAssertEqual(dropped, 1)
    }

    func test_멈춘_까닭이_있으면_그_문장() {
        XCTAssertEqual(DocumentRules.pendingNotice(failed: 2, stopMessage: nil), "서류 2개를 못 올렸어요. 수정하기에서 다시 붙여 주세요.")
        XCTAssertEqual(DocumentRules.pendingNotice(failed: 2, stopMessage: "준비 패스가 있어야 서류를 올릴 수 있어요."), "준비 패스가 있어야 서류를 올릴 수 있어요.")
    }
}
