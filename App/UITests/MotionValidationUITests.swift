import XCTest

/// 화면마다 굴림 버벅임(hitch time ratio)을 잰다(2026-11-09 사용자 "스크롤 드드득").
/// 시뮬레이터 숫자는 참고용이다 — 실기기 Instruments 가 정답이고, 여기서는 고치기 전후 **방향**만 본다.
/// 오래 걸려 기본 실행에서는 건너뛴다. 켜려면 `TEST_RUNNER_WP_SCROLL_PERF=1 xcodebuild test …`.
final class MotionValidationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 15))
        sleep(2)
        return app
    }

    private func measureScroll(_ target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        sleep(2)
        target.swipeUp(velocity: .slow)
        target.swipeDown(velocity: .slow)
        target.swipeUp(velocity: .fast)
        target.swipeDown(velocity: .fast)
        sleep(2)
    }

    func testHome() { let app = launch(); measureScroll(app.scrollViews["main.scroll"]) }

    func testCalendar() {
        let app = launch(); app.buttons["tab.schedule"].tap()
        measureScroll(app.scrollViews["calendar.scroll"])
    }

    func testBudget() {
        let app = launch(); XCTAssertTrue(app.buttons["main.budget"].waitForExistence(timeout: 10)); app.buttons["main.budget"].tap()
        measureScroll(app.scrollViews["budget.scroll"])
    }

    func testScheduleDetail() {
        let app = launch()
        let plan = app.staticTexts["드레스 1차 피팅"].firstMatch
        for _ in 0..<8 { if plan.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(plan.isHittable); plan.tap()
        measureScroll(app.scrollViews["detail.scroll"])
    }

    func testFeed() {
        let app = launch(); app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.buttons["feed.post.open"].waitForExistence(timeout: 10))
        measureScroll(app.scrollViews.firstMatch)
    }

    func testBrag() {
        let app = launch(); app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.buttons["explore.brag"].waitForExistence(timeout: 10)); app.buttons["explore.brag"].tap()
        sleep(2)
        measureScroll(app.scrollViews.firstMatch)
    }

    func testInvitationStudio() {
        let app = launch(["-WPPassEnabled"]); app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.buttons["explore.invitation"].waitForExistence(timeout: 10)); app.buttons["explore.invitation"].tap()
        sleep(2)
        measureScroll(app.scrollViews.firstMatch)
    }

    /// 예시 청첩장(하객 화면) — 표지 문 열림 · 반짝임이 있는 화면
    func testInvitationPreview() {
        let app = launch(); app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.buttons["explore.invitation"].waitForExistence(timeout: 10)); app.buttons["explore.invitation"].tap()
        let example = app.buttons["예시 청첩장 구경하기"]
        XCTAssertTrue(example.waitForExistence(timeout: 10))
        for _ in 0..<6 { if example.isHittable { break }; app.swipeUp() }
        example.tap()
        sleep(4)
        measureScroll(app.scrollViews.firstMatch)
    }

    func testProfile() {
        let app = launch(); XCTAssertTrue(app.buttons["main.profile"].waitForExistence(timeout: 10)); app.buttons["main.profile"].tap()
        XCTAssertTrue(app.buttons["user.pass"].waitForExistence(timeout: 10))
        measureScroll(app.scrollViews.firstMatch)
    }

    func testChatKeyboard() {
        let app = launch(); app.buttons["tab.rooms"].tap()
        let input = app.descendants(matching: .any)["chat.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        for _ in 0..<3 {
            input.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            sleep(2)
            let latest = app.staticTexts["좋아요! 그때 봐요 :)"].firstMatch
            XCTAssertTrue(latest.exists, "마지막 메시지가 있어야 한다")
            XCTAssertGreaterThan(latest.frame.minY, app.tables["chat.scroll"].frame.minY)
            XCTAssertLessThanOrEqual(latest.frame.maxY, input.frame.minY, "마지막 메시지가 입력창에 가려지면 안 된다")
            XCTAssertLessThan(input.frame.minY - latest.frame.maxY, 70, "마지막 메시지는 입력창 바로 위에 붙어야 한다")
            XCTAssertLessThanOrEqual(input.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
            // 목록 스크롤과 키보드 전환을 분리해서 본다. 바깥 탭으로 키보드만 닫는다.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
            let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
            XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed, "키보드가 완전히 접혀야 한다")
            sleep(2)
            XCTAssertLessThanOrEqual(latest.frame.maxY, input.frame.minY, "접힌 뒤에도 마지막 메시지가 가려지면 안 된다")
            XCTAssertLessThan(input.frame.minY - latest.frame.maxY, 70, "접힌 뒤에도 마지막 메시지가 입력창을 따라가야 한다")
        }
    }

    func testChatMultilineAndDragDismiss() {
        let app = launch(); app.buttons["tab.rooms"].tap()
        let input = app.descendants(matching: .any)["chat.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText("First line\nSecond line\nThird line")
        sleep(2)
        XCTAssertTrue((input.value as? String ?? "").contains("Third line"))
        let latest = app.staticTexts["좋아요! 그때 봐요 :)"].firstMatch
        XCTAssertLessThanOrEqual(latest.frame.maxY, input.frame.minY)
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
        from.press(forDuration: 0.1, thenDragTo: to)
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)
        XCTAssertTrue((input.value as? String ?? "").contains("Third line"))
        app.tables["chat.scroll"].swipeDown()
        app.tables["chat.scroll"].swipeUp()
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        sleep(2)
        XCTAssertLessThanOrEqual(latest.frame.maxY, input.frame.minY)
    }

    func testChat() {
        let app = launch(); app.buttons["tab.rooms"].tap()
        measureScroll(app.tables["chat.scroll"])
    }

    func testAddPlan() {
        let app = launch(); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10)); title.tap(); title.typeText("드레스 투어\n")
        sleep(2)
        XCTAssertTrue(app.buttons["addplan.category"].waitForExistence(timeout: 10))
        measureScroll(app.scrollViews.firstMatch)
    }
    func testCategoryPicker() {
        let app = launch(); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10)); title.tap(); title.typeText("드레스 투어\n")
        sleep(2)
        let button = app.buttons["addplan.category"]
        XCTAssertTrue(button.waitForExistence(timeout: 10)); button.tap()
        XCTAssertTrue(app.textFields["category.search"].waitForExistence(timeout: 10))
        measureScroll(app.scrollViews.firstMatch)
    }
    func testPassIntro() {
        let app = launch(); app.buttons["main.profile"].tap()
        let pass = app.buttons["user.pass"]
        XCTAssertTrue(pass.waitForExistence(timeout: 10)); pass.tap()
        let skip = app.webViews.buttons["건너뛰기"]
        if skip.waitForExistence(timeout: 10) { skip.tap() }
        sleep(3)
        measureScroll(app.webViews.firstMatch)
    }
    func testInvitationEditor() {
        let app = launch(["-WPPassEnabled", "-WPInvitationPublished"])
        app.buttons["tab.explore"].tap(); app.buttons["explore.invitation"].tap()
        let edit = app.buttons["청첩장 고치기"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        for _ in 0..<5 { if edit.isHittable { break }; app.swipeUp() }
        edit.tap()
        measureScroll(app.scrollViews["invitation.editPreview"])
    }
}