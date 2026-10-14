import XCTest

/// Action-level review captures; all writes go to the in-memory demo transport.
final class AllScreenReviewUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["main.profile"].waitForExistence(timeout: 10))
        return app
    }
    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = "review-action-" + name; a.lifetime = .keepAlways; add(a)
    }
    private func reveal(_ app: XCUIApplication, _ element: XCUIElement) {
        for _ in 0..<7 { if element.isHittable { break }; app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.18))) }
        XCTAssertTrue(element.isHittable)
    }
    func testProfileSaveAndAccountConfirmations() {
        let app = launch(); app.buttons["main.profile"].tap()
        let name = app.textFields["user.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); shot(app, "profile-before-edit")
        name.tap(); name.typeText("테스트\n")
        shot(app, "profile-edit-keyboard")
        let save = app.buttons["user.save"]; reveal(app, save); shot(app, "profile-ready-save"); save.tap()
        XCTAssertTrue(app.staticTexts["저장되었어요"].waitForExistence(timeout: 5))
        shot(app, "profile-saved")
        let withdraw = app.buttons["user.withdraw"]; reveal(app, withdraw); withdraw.tap()
        XCTAssertTrue(app.buttons["user.withdrawConfirm"].waitForExistence(timeout: 5))
        shot(app, "withdraw-confirm")
        app.buttons["취소"].firstMatch.tap()
        let logout = app.buttons["user.signOut"]; reveal(app, logout); logout.tap()
        XCTAssertTrue(app.buttons["user.signOutConfirm"].waitForExistence(timeout: 5))
        shot(app, "logout-confirm"); app.buttons["user.signOutConfirm"].tap()
        XCTAssertTrue(app.buttons["auth.email"].waitForExistence(timeout: 5))
        shot(app, "logout-done")
    }
    func testCalendarMonthAndDayActions() {
        let app = launch(); app.buttons["tab.schedule"].tap()
        let next = app.buttons["calendar.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5)); shot(app, "calendar-current"); next.tap()
        shot(app, "calendar-next"); app.buttons["calendar.prev"].tap()
        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.day.'"))
        XCTAssertGreaterThan(days.count, 7)
        let day = days.element(boundBy: min(15, days.count - 1)); reveal(app, day); day.tap()
        XCTAssertTrue(app.buttons["calendar.sheet.add"].waitForExistence(timeout: 5))
        shot(app, "calendar-day"); app.buttons["calendar.sheet.add"].tap()
        XCTAssertTrue(app.textFields["addplan.title"].waitForExistence(timeout: 5))
        shot(app, "calendar-add-date")
    }
    func testFeedWriteForm() {
        let app = launch(); app.buttons["tab.explore"].tap()
        let write = app.buttons["내 후기 올리기"]
        XCTAssertTrue(write.waitForExistence(timeout: 5)); write.tap()
        XCTAssertTrue(app.staticTexts["후기 쓰기"].waitForExistence(timeout: 5))
        shot(app, "feed-post-start")
        let plan = app.buttons.containing(NSPredicate(format: "label CONTAINS '청담 드레스룸'")).firstMatch
        reveal(app, plan); plan.tap(); shot(app, "feed-post-selected")
        // The selected schedule and publish action must remain present.
        let publish = app.buttons["feed.post.submit"]; reveal(app, publish)
        shot(app, "feed-post-ready")
    }
}
