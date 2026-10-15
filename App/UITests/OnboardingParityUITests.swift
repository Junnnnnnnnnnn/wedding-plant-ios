import XCTest

/// 온보딩(처음 설정) 단계별 캡처 — 안드로이드 `review-onboarding-*` 와 나란히 비교한다.
/// 데모 모드라 서버에 쓰지 않는다.
final class OnboardingParityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + arguments
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String, settle: TimeInterval = 0.7) {
        // 단계 사이 0.5초 교차 페이드가 끝난 뒤에 찍는다
        if settle > 0 { Thread.sleep(forTimeInterval: settle) }
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testOnboardingStepsMatchAndroid() {
        let app = launch(["-WPForceOnboarding"])

        // 축하 진입 — 3초 뒤 저절로 넘어가므로 뜨자마자 찍는다(종이 가루가 내려오는 중)
        let celebration = app.descendants(matching: .any)["setting.celebration"]
        XCTAssertTrue(celebration.waitForExistence(timeout: 15))
        capture(app, "onb-celebration", settle: 0.4)

        let next = app.buttons["setting.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        capture(app, "onb-date")
        XCTAssertTrue(app.staticTexts["1 / 6"].exists || app.otherElements["setting.progress"].exists)
        next.tap()

        let budget = app.textFields["setting.budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5))
        capture(app, "onb-budget")
        budget.tap()
        budget.typeText("5000")
        // 미리 채운 1000 은 통째로 골라져 새 값으로 바뀐다(안드로이드 selectAllOnFocus)
        XCTAssertEqual(budget.value as? String, "5000")
        // 이 시뮬레이터 캡처에는 키보드가 찍히지 않는다(빈 여백으로 보임) — 내린 뒤 찍는다
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32)).tap()
        capture(app, "onb-budget-typed", settle: 0.5)
        next.tap()

        let name = app.textFields["setting.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        capture(app, "onb-name")
        name.tap()
        name.typeText("지수")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32)).tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        capture(app, "onb-name-filled", settle: 0.5)
        next.tap()

        XCTAssertTrue(app.descendants(matching: .any)["setting.welcome"].waitForExistence(timeout: 5))
        capture(app, "onb-welcome", settle: 0.6)

        let agree = app.buttons["setting.agreeAll"]
        XCTAssertTrue(agree.waitForExistence(timeout: 10))
        capture(app, "onb-terms")
        app.buttons["보기"].firstMatch.tap()
        XCTAssertTrue(app.buttons["setting.terms.close"].waitForExistence(timeout: 3))
        capture(app, "onb-terms-doc", settle: 0.4)
        app.buttons["setting.terms.close"].tap()
        agree.tap()
        capture(app, "onb-terms-agreed", settle: 0.3)
        let submit = app.buttons["setting.submit"]
        for _ in 0..<3 { if submit.isHittable { break }; app.swipeUp() }
        submit.tap()

        let permissionNext = app.buttons["setting.permissions.next"]
        XCTAssertTrue(permissionNext.waitForExistence(timeout: 10))
        capture(app, "onb-permissions")
        let later = app.buttons["setting.permissions.later"]
        if later.exists { later.tap() } else { permissionNext.tap() }

        let inviteLater = app.buttons["setting.inviteLater"]
        XCTAssertTrue(inviteLater.waitForExistence(timeout: 5))
        capture(app, "onb-invite")
        app.buttons["setting.invite.solo"].tap()
        XCTAssertTrue(app.buttons["계획 짜러 가기"].waitForExistence(timeout: 2))
        capture(app, "onb-invite-solo", settle: 0.3)
        inviteLater.tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 10))
    }

    /// 뒤로가기는 예산·이름·약관에만 — 약관의 뒤는 이름(환영은 건너뛴다)
    func testOnboardingBackSkipsWelcome() {
        let app = launch(["-WPForceOnboarding"])
        let next = app.buttons["setting.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["setting.back"].exists)
        next.tap()
        XCTAssertTrue(app.textFields["setting.budget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["setting.back"].waitForExistence(timeout: 2))
        app.buttons["setting.back"].tap()
        XCTAssertTrue(app.buttons["setting.next"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.7)
        XCTAssertFalse(app.buttons["setting.back"].exists)
    }
}
