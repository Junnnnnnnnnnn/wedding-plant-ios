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
        // 날짜를 누르면 시트 대신 달력 아래 그날 목록이 바뀐다(안드로이드와 같음).
        let day = days.element(boundBy: min(15, days.count - 1)); reveal(app, day); day.tap()
        let add = app.buttons["calendar.dayAdd"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); reveal(app, add)
        shot(app, "calendar-day"); add.tap()
        XCTAssertTrue(app.textFields["addplan.title"].waitForExistence(timeout: 5))
        shot(app, "calendar-add-date")
    }
    func testFeedWriteForm() {
        let app = launch(); app.buttons["tab.explore"].tap()
        let write = app.buttons["내 후기 올리기"]
        XCTAssertTrue(write.waitForExistence(timeout: 5)); write.tap()
        // 시트 제목은 Android `FeedPostSheet` 와 같은 「견적 후기 올리기」
        XCTAssertTrue(app.staticTexts["견적 후기 올리기"].waitForExistence(timeout: 5))
        shot(app, "feed-post-start")
        let plan = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'feed.post.schedule.'")).firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        reveal(app, plan); plan.tap(); shot(app, "feed-post-selected")
        // The selected schedule and publish action must remain present.
        let publish = app.buttons["feed.post.submit"]; reveal(app, publish)
        shot(app, "feed-post-ready")
    }
}

/// 홈 · 예산 상세를 안드로이드 캡처(`review-native-home-*` · `review-native-budget-*` · `home-*`)와 같은 상태로 찍는다.
final class HomeBudgetParityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ args: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + args
        app.launch()
        XCTAssertTrue(app.buttons["main.profile"].waitForExistence(timeout: 10))
        return app
    }
    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = "parity-" + name; a.lifetime = .keepAlways; add(a)
    }
    private func drag(_ app: XCUIApplication, from: CGFloat, to: CGFloat) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to)))
        Thread.sleep(forTimeInterval: 1.2)
    }
    func testHomeScrollAndBudget() {
        let app = launch()
        XCTAssertTrue(app.buttons["main.budget"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5)
        shot(app, "home-top")
        drag(app, from: 0.7, to: 0.35)
        shot(app, "home-middle")
        // 탭바 위 자랑하기 도크(화면 아래 1/4)를 피해 목록을 잡고 끈다
        drag(app, from: 0.65, to: 0.12)
        shot(app, "home-bottom")
        drag(app, from: 0.2, to: 0.9); drag(app, from: 0.2, to: 0.9)
        app.buttons["main.budget"].tap()
        XCTAssertTrue(app.staticTexts["카테고리별"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        shot(app, "budget-top")
        drag(app, from: 0.8, to: 0.42)
        shot(app, "budget-middle")
        drag(app, from: 0.85, to: 0.15)
        shot(app, "budget-bottom")
        let used = app.buttons["budget.tab.used"]
        XCTAssertTrue(used.waitForExistence(timeout: 5)); used.tap()
        Thread.sleep(forTimeInterval: 1.0)
        shot(app, "budget-used-tab")
        drag(app, from: 0.3, to: 0.9); drag(app, from: 0.3, to: 0.9)
        drag(app, from: 0.8, to: 0.42)
        let hall = app.descendants(matching: .any)["budget.category.웨딩홀"]
        if hall.exists { hall.tap(); Thread.sleep(forTimeInterval: 1.0) }
        shot(app, "budget-filtered")
    }
    func testHomeStates() {
        for (name, args) in [("home-empty", ["-WPHomeEmpty"]), ("home-over", ["-WPOverBudget"]),
                             ("home-garden", ["-WPPassEnabled"]), ("home-garden-mine", ["-WPPassEnabled", "-WPExistingInvitation"])] {
            let app = launch(args)
            XCTAssertTrue(app.buttons["main.budget"].waitForExistence(timeout: 10))
            Thread.sleep(forTimeInterval: 2.0)
            shot(app, name)
            if name == "home-empty" {
                drag(app, from: 0.7, to: 0.35)
                shot(app, name + "-scrolled")
            }
            app.terminate()
        }
    }
}
