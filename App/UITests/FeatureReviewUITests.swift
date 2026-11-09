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
    func testHomeBoardDesignReview() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPAdPreview", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["main.profile"].waitForExistence(timeout: 20))
        shot(app, "review-home-profile")
        let scroll = app.scrollViews["main.scroll"]
        let promo = app.buttons["준비 패스 살펴보기 ›"]
        for _ in 0..<12 { if promo.exists && promo.isHittable { break }; scroll.swipeUp() }
        XCTAssertTrue(promo.isHittable)
        shot(app, "review-home-promo")
        app.buttons["tab.schedule"].tap()
        XCTAssertTrue(app.scrollViews["calendar.scroll"].waitForExistence(timeout: 15))
        let board = app.scrollViews["calendar.scroll"]
        let ad = app.descendants(matching: .any)["ad.board.inline"].firstMatch
        for _ in 0..<10 { if ad.exists && ad.isHittable { break }; board.swipeUp() }
        XCTAssertTrue(ad.isHittable)
        shot(app, "review-board-ad")
    }
    func testCoupleOwnerProfileLabel() { coupleProfile(false) }
    func testCoupleSpouseProfileLabel() { coupleProfile(true) }
    private func coupleProfile(_ spouse: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + (spouse ? ["-WPDemoSpouse"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["main.profile"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["지수"].exists)
        XCTAssertTrue(app.staticTexts["현우"].exists)
        XCTAssertTrue(app.staticTexts["설정"].exists)
        shot(app, spouse ? "review-couple-spouse" : "review-couple-owner")
    }
    func testPaidHome() {
        let app = launch(true)
        XCTAssertFalse(app.buttons["main.passEntry"].exists)
        shot(app, "features-home-paid")
    }
}
