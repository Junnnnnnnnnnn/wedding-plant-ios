import XCTest

/// 둘러보기에서 실제로 여는 시트들 — 신고·차단 한 장(메뉴 → 사유 → 차단 확인)과 자랑 상세, 후기 상세.
/// 시트 높이는 내용에 맞춰 잡히므로(`presentationDetents(.height)`) 상태 없는 본문 캡처만으로는 확인할 수 없다.
final class ExploreModerationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch(); return app
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testFeedModerationSheetSteps() {
        let app = launch()
        app.buttons["tab.explore"].tap()
        let menu = app.buttons["moderation.menu"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        XCTAssertTrue(app.buttons["moderation.report"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        capture("parity-moderation-menu")
        app.buttons["moderation.report"].tap()
        XCTAssertTrue(app.buttons["moderation.reason.OTHER"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["moderation.submit"].isEnabled)
        Thread.sleep(forTimeInterval: 0.8)
        capture("parity-moderation-reason")
        app.buttons["moderation.reason.OTHER"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        capture("parity-moderation-reason-other")
        app.buttons["moderation.cancel"].tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        menu.tap()
        XCTAssertTrue(app.buttons["moderation.block"].waitForExistence(timeout: 5))
        app.buttons["moderation.block"].tap()
        XCTAssertTrue(app.buttons["moderation.block.confirm"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        capture("parity-moderation-block")
    }

    func testFeedDetailAndBragDetail() {
        let app = launch()
        app.buttons["tab.explore"].tap()
        let card = app.otherElements["feed.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertTrue(app.buttons["feed.detail.back"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        capture("parity-feed-detail-top")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.8)
        capture("parity-feed-detail-bottom")
        app.buttons["feed.detail.back"].tap()
        XCTAssertTrue(app.buttons["explore.brag"].waitForExistence(timeout: 5))
        app.buttons["explore.brag"].tap()
        let brag = app.otherElements["brag.card"].firstMatch
        XCTAssertTrue(brag.waitForExistence(timeout: 10))
        capture("parity-explore-brag-list")
        brag.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(app.buttons["brag.detail.close"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        capture("parity-brag-detail-top")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.8)
        capture("parity-brag-detail-bottom")
        app.buttons["brag.detail.close"].tap()
    }
}
