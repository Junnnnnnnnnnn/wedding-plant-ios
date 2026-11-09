import XCTest
final class FeatureReviewUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ paid: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPInboxDemo", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + (paid ? ["-WPPassEnabled"] : [])
        app.launch(); XCTAssertTrue(app.buttons["main.inbox"].waitForExistence(timeout: 20)); sleep(2); return app
    }
    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func testPassAndInbox() {
        let app = launch()
        XCTAssertTrue(app.buttons["main.passEntry"].exists)
        shot(app, "features-home-unpaid")
        app.buttons["main.inbox"].tap()
        XCTAssertTrue(app.buttons["inbox.item.3"].waitForExistence(timeout: 10))
        shot(app, "features-inbox-before")
        app.buttons["inbox.clearUnread"].tap()
        XCTAssertTrue(app.buttons["inbox.item.1"].waitForExistence(timeout: 5)); sleep(1)
        XCTAssertFalse(app.buttons["inbox.item.3"].exists)
        XCTAssertFalse(app.buttons["inbox.clearUnread"].isEnabled)
        shot(app, "features-inbox-after")
        app.buttons["닫기"].tap()
        app.buttons["main.passEntry"].tap(); sleep(3)
        shot(app, "features-pass-intro")
    }
    func testAdRemovalOpensPass() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPAdPreview", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["main.inbox"].waitForExistence(timeout: 20))
        let remove = app.buttons["광고 제거 ›"].firstMatch
        for _ in 0..<10 { if remove.exists && remove.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(remove.isHittable)
        shot(app, "features-ad-remove")
        remove.tap()
        XCTAssertTrue(app.staticTexts["준비 패스"].firstMatch.waitForExistence(timeout: 10))
        shot(app, "features-ad-pass-intro")
    }
    func testPaidHome() {
        let app = launch(true)
        XCTAssertFalse(app.buttons["main.passEntry"].exists)
        shot(app, "features-home-paid")
    }
}
