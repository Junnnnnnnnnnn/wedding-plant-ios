import XCTest

final class InvitationAdsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPAdPreview", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + extra
        app.launch(); XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 10)); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    private func scroll(_ app: XCUIApplication, to element: XCUIElement, max: Int = 8) {
        for _ in 0..<max { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    func testUnpaidInvitationHasCompactFourRowsAndNoHomeGarden() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["모바일 청첩장"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["하객 자리가 비어 있어요"].exists)
        capture(app, "unpaid-home-invitation-row")
        openExplore(app); app.buttons["explore.invitation"].tap()
        let primary = app.buttons["invitation.primary"]
        scroll(app, to: primary)
        for icon in ["album", "info", "garden", "qr"] {
            XCTAssertTrue(app.descendants(matching: .any)["invitation.feature.\(icon)"].exists)
        }
        XCTAssertFalse(app.staticTexts["분위기 · 가든 / 아이보리 / 로즈"].exists)
        capture(app, "invitation-landing-four-items")
    }
    func testPaidGardenAndSlotsHaveNoAds() {
        let app = launch(["-WPPassEnabled"])
        XCTAssertTrue(app.staticTexts["하객 자리가 비어 있어요"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["ad.home"].exists)
        capture(app, "paid-home-garden")
        openExplore(app); app.buttons["explore.invitation"].tap()
        scroll(app, to: app.buttons["invitation.primary"])
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'invitation.slot.'")).count, 6)
        capture(app, "invitation-paid-six-slots")
        app.buttons["invitation.slot.cover"].tap()
        XCTAssertTrue(app.textFields["invitation.groom"].waitForExistence(timeout: 5))
    }
    func testUnpaidFeedBragAndCalendarAdPlacements() {
        let app = launch()
        openExplore(app)
        scroll(app, to: app.otherElements["ad.feed.2"])
        capture(app, "ads-feed")
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        scrollDown(app, to: app.buttons["explore.brag"])
        app.buttons["explore.brag"].tap()
        scroll(app, to: app.otherElements["ad.brag.1"])
        capture(app, "ads-brag")
        app.buttons["tab.schedule"].tap()
        XCTAssertTrue(app.buttons["calendar.export"].waitForExistence(timeout: 5))
        scroll(app, to: app.descendants(matching: .any)["ad.calendar"].firstMatch)
        capture(app, "ads-calendar")
    }
    func testUnpaidHomeBudgetAndDetailPlacements() {
        let app = launch()
        scroll(app, to: app.otherElements["ad.home"])
        capture(app, "ads-home")
        app.buttons["tab.home"].tap()
        XCTAssertTrue(app.buttons["main.budget"].waitForExistence(timeout: 10))
        let budgetReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: app.buttons["main.budget"])
        XCTAssertEqual(XCTWaiter.wait(for: [budgetReady], timeout: 10), .completed)
        app.buttons["main.budget"].tap()
        XCTAssertTrue(app.buttons["budget.back"].waitForExistence(timeout: 5))
        let budget = app.descendants(matching: .any)["ad.budget"].firstMatch
        scroll(app, to: budget); capture(app, "ads-budget")
        app.buttons["budget.back"].tap()
        let plan = app.staticTexts["드레스 1차 피팅"].firstMatch
        scroll(app, to: plan); plan.tap()
        let detail = app.descendants(matching: .any)["ad.schedule"].firstMatch
        scroll(app, to: detail); capture(app, "ads-schedule")
    }
    private func openExplore(_ app: XCUIApplication) {
        let button = app.buttons["tab.explore"]
        for _ in 0..<3 {
            button.tap()
            if app.buttons["explore.invitation"].waitForExistence(timeout: 3) { return }
        }
        XCTFail("Explore tab did not open")
    }
    private func scrollDown(_ app: XCUIApplication, to element: XCUIElement) {
        for _ in 0..<8 { if element.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(element.isHittable)
    }
    func testGoogleTestNativeAndBannerActuallyLoad() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPRealTestAds", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch(); XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10))
        openExplore(app)
        app.swipeUp(); app.swipeUp()
        let ad = app.otherElements["ad.feed.2"]
        XCTAssertTrue(ad.waitForExistence(timeout: 60))
        scroll(app, to: ad); app.swipeUp(); capture(app, "google-test-native")
        app.buttons["tab.schedule"].tap()
        XCTAssertTrue(app.buttons["calendar.export"].waitForExistence(timeout: 5))
        let banner = app.descendants(matching: .any)["ad.calendar"].firstMatch
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["광고"].firstMatch.waitForExistence(timeout: 45))
        scroll(app, to: banner); app.swipeUp(); capture(app, "google-test-banner")
    }
}
