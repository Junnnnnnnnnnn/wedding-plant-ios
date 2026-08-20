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

    /// 웹과 동일한 6단계 플로우: 축하 → 날짜 → 예산 → 이름 → 환영 → 약관
    func test_01_랜딩과_설정_플로우() {
        let app = makeApp(forceOnboarding: true)
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle()

        capture(app, "01-landing")

        let guestButton = app.buttons["landing.guest"]
        guard guestButton.waitForExistence(timeout: 10) else { return }
        guestButton.tap()

        // 축하 단계는 3초 뒤 자동으로 날짜 단계로 넘어간다.
        settle(1.0)
        capture(app, "02-celebration")
        settle(3.0)
        capture(app, "03-date")

        let next = app.buttons["setting.next"]
        guard next.waitForExistence(timeout: 5) else { return }
        next.tap()
        settle(1.0)
        capture(app, "04-budget")

        let budgetField = app.textFields["setting.budget"]
        if budgetField.exists {
            budgetField.tap()
            budgetField.typeText("5000")
            settle(0.5)
        }
        if next.exists { next.tap() }
        settle(1.0)
        capture(app, "05-name")

        let nameField = app.textFields["setting.name"]
        if nameField.exists {
            nameField.tap()
            nameField.typeText("지수")
            settle(0.5)
            capture(app, "06-name-filled")
        }
        if next.exists { next.tap() }

        // 환영 단계는 2.5초 뒤 약관으로 자동 전환된다.
        settle(1.0)
        capture(app, "07-welcome")
        settle(2.5)
        capture(app, "08-terms")

        if app.buttons["setting.agreeAll"].exists {
            app.buttons["setting.agreeAll"].tap()
            settle(0.8)
            capture(app, "09-terms-agreed")
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

    // MARK: - 정렬 시트 · 일정 상세

    /// 새로 만든 화면들. 여기서 찍지 않으면 CI 아티팩트에 영영 안 나온다.
    func test_03_정렬시트와_일정상세() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)

        // 정렬 시트
        if app.buttons["main.sort"].waitForExistence(timeout: 10) {
            app.buttons["main.sort"].tap()
            settle(1.5)
            capture(app, "09-sort-sheet")

            // 다른 정렬을 골라 목록이 바뀌는지도 남긴다.
            if app.buttons["높은 가격순"].exists {
                app.buttons["높은 가격순"].tap()
                settle(2.5)
                capture(app, "10-sorted-by-price")
            } else {
                app.swipeDown()
                settle(1.0)
            }
        }

        // 일정 상세 — 목록 첫 카드를 누른다.
        let firstPlan = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "드레스")
        ).firstMatch
        if firstPlan.waitForExistence(timeout: 10) {
            firstPlan.tap()
            settle(3.0)
            capture(app, "11-schedule-detail")

            // 삭제 확인 다이얼로그 (취소가 왼쪽인지 눈으로 확인하기 위함)
            if app.buttons["detail.delete"].exists {
                app.buttons["detail.delete"].tap()
                settle(1.5)
                capture(app, "12-delete-confirm")
                if app.buttons["취소"].exists {
                    app.buttons["취소"].tap()
                    settle(1.0)
                }
            }

            if app.buttons["detail.back"].exists {
                app.buttons["detail.back"].tap()
                settle(1.5)
            }
        }
    }
}
