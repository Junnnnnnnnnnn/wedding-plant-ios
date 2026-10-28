import XCTest

/// 새 버전 알림 — Android `AppUpdatePromptTest`(373ec6f). 들어올 때마다 묻고, 새 버전이면 늘 `업데이트 / 나중에`,
/// `나중에` 는 이번만 닫는다. 가짜 스토어(`-WPStoreVersion`)로 본다 — 운영 App Store 에 묻지 않는다.
final class AppUpdatePromptUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    private func launch(store: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPStoreVersion", store, "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        return app
    }

    private func reenter(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
    }

    func testNewerVersionOffersOnEveryEntryAndLaterClosesOnlyThisTime() {
        let app = launch(store: "9.9.9")
        let later = app.buttons["update.later"]
        XCTAssertTrue(later.waitForExistence(timeout: 15), "켤 때 묻는다")
        XCTAssertTrue(app.buttons["update.confirm"].exists)
        XCTAssertTrue(app.staticTexts["새 버전이 나왔어요"].exists)
        sleep(1)
        capture(app, "update-card")
        later.tap()
        XCTAssertFalse(later.waitForExistence(timeout: 2), "나중에 — 이번 안내만 닫는다")

        // 시트를 연 채 나갔다 들어와도 시트 위에 뜬다
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        let write = app.descendants(matching: .any)["feed.write"].firstMatch
        XCTAssertTrue(write.waitForExistence(timeout: 10)); write.tap()
        XCTAssertTrue(app.staticTexts["견적 후기 올리기"].waitForExistence(timeout: 5))
        reenter(app)
        XCTAssertTrue(later.waitForExistence(timeout: 15), "다시 들어오면 또 묻는다")
        XCTAssertTrue(later.isHittable, "열린 시트 위에서 눌린다")
        capture(app, "update-card-over-sheet")
        // 바깥을 누르면 나중에와 같다
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18)).tap()
        XCTAssertFalse(later.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["견적 후기 올리기"].exists, "밑의 시트는 그대로")
    }

    func testSameVersionOffersNothing() {
        let installed = (Bundle(for: Self.self).object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.1"
        let app = launch(store: installed)
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["update.later"].waitForExistence(timeout: 4), "같은 버전이면 묻지 않는다")
    }
}
