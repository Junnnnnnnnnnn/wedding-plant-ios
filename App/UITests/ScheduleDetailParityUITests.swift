import XCTest

/// 일정 상세를 안드로이드 `DetailActionsShotTest`(detail-actions-planned · detail-actions-ready)와 같은
/// 상태로 찍는다 — 머리 면(예정·완료)과 아래 보내기 · 공유 카드 + `삭제 · 수정하기` 한 줄.
final class ScheduleDetailParityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + arguments
        app.launch(); return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testDetailTopAndActionsPlannedThenCompleted() {
        let app = launch(["-WPDetailFeedReady"])
        let plan = app.staticTexts["드레스 1차 피팅"].firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        for _ in 0..<6 { if plan.isHittable { break }; app.swipeUp() }
        plan.tap()

        let title = app.descendants(matching: .any)["detail.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let pill = app.descendants(matching: .any)["detail.statusPill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        sleep(1)
        capture(app, "detail-top-planned")

        let scroll = app.scrollViews["detail.scroll"]
        for _ in 0..<5 { scroll.swipeUp() }
        let toggle = app.buttons["detail.status"]
        XCTAssertTrue(toggle.isHittable)
        XCTAssertTrue(app.buttons["detail.shareChat"].exists)
        // 예정이면 피드 줄은 잠겨 자리를 지킨다
        XCTAssertTrue(app.buttons["detail.shareFeed"].exists)
        XCTAssertFalse(app.buttons["detail.shareFeed"].isEnabled)
        XCTAssertTrue(app.buttons["detail.delete"].isHittable)
        XCTAssertTrue(app.buttons["detail.edit"].isHittable)
        capture(app, "detail-actions-planned")

        toggle.tap()
        XCTAssertTrue(app.staticTexts["예정으로 되돌리기"].waitForExistence(timeout: 5))
        let feed = app.buttons["detail.shareFeed"]
        let ready = NSPredicate(format: "isEnabled == true")
        expectation(for: ready, evaluatedWith: feed)
        waitForExpectations(timeout: 5)
        for _ in 0..<3 { scroll.swipeUp() }
        sleep(1)
        capture(app, "detail-actions-ready")

        for _ in 0..<6 { scroll.swipeDown() }
        sleep(1)
        capture(app, "detail-top-completed")
    }
}
