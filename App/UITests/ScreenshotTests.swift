import XCTest

/// 화면을 자동으로 돌면서 스크린샷을 남긴다.
///
/// Windows 개발 환경에서는 시뮬레이터를 띄울 수 없으므로, CI 가 이 테스트를 돌려 만든
/// 스크린샷(과 워크플로가 별도로 녹화하는 동영상)이 화면을 눈으로 확인하는 수단이다.
/// 그래서 **단언(assert)으로 실패시키지 않는다** — 무엇이 나왔든 일단 찍어서 올린다.
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    private func makeApp(forceOnboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode"]
        if forceOnboarding {
            app.launchArguments.append("-WPForceOnboarding")
        }
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settle(_ seconds: TimeInterval = 2.0) {
        Thread.sleep(forTimeInterval: seconds)
    }

    // MARK: - 랜딩 → 설정

    func test_01_랜딩과_초기설정() {
        let app = makeApp(forceOnboarding: true)
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle()

        capture(app, "01-landing")

        let guestButton = app.buttons["landing.guest"]
        if guestButton.waitForExistence(timeout: 10) {
            guestButton.tap()
            settle()
            capture(app, "02-setting")

            let nameField = app.textFields["setting.name"]
            if nameField.waitForExistence(timeout: 5) {
                nameField.tap()
                nameField.typeText("지수")
                settle(1.0)
                capture(app, "03-setting-filled")
            }
        }
    }

    // MARK: - 메인 탭들

    func test_02_메인_탭_전체() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        // 데모 전송 계층에 200ms 지연이 있으므로 데이터가 채워질 시간을 준다.
        settle(3.0)

        capture(app, "04-main")

        // 커스텀 하단 탭바 — 접근성 식별자로 찾는다.
        if app.buttons["tab.rooms"].waitForExistence(timeout: 10) {
            app.buttons["tab.rooms"].tap()
            settle(2.5)
            capture(app, "05-plan-list")
        }

        if app.buttons["tab.settings"].exists {
            app.buttons["tab.settings"].tap()
            settle(2.5)
            capture(app, "06-user")
        }

        // 피드 탭은 웹과 동일하게 "준비중" 알림만 띄운다.
        if app.buttons["tab.feed"].exists {
            app.buttons["tab.feed"].tap()
            settle(1.5)
            capture(app, "07-feed-preparing")
            if app.buttons["닫기"].exists {
                app.buttons["닫기"].tap()
                settle(1.0)
            }
        }

        if app.buttons["tab.home"].exists {
            app.buttons["tab.home"].tap()
            settle(1.5)
            capture(app, "08-main-again")
        }
    }
}
