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
        if budgetField.isHittable {
            budgetField.tap()
            budgetField.typeText("5000")
            settle(0.5)
        }
        if next.isHittable { next.tap() }
        settle(1.0)
        capture(app, "05-name")

        let nameField = app.textFields["setting.name"]
        if nameField.isHittable {
            nameField.tap()
            nameField.typeText("지수")
            settle(0.5)
            capture(app, "06-name-filled")
        }
        if next.isHittable { next.tap() }

        // 환영 단계는 2.5초 뒤 약관으로 자동 전환된다.
        settle(1.0)
        capture(app, "07-welcome")
        settle(2.5)
        capture(app, "08-terms")

        if app.buttons["setting.agreeAll"].isHittable {
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

        if app.buttons["tab.settings"].isHittable {
            app.buttons["tab.settings"].tap()
            settle(2.5)
            capture(app, "06-user")
        }

        // 피드 탭은 웹과 동일하게 "준비중" 알림만 띄운다.
        if app.buttons["tab.feed"].isHittable {
            app.buttons["tab.feed"].tap()
            settle(1.5)
            capture(app, "07-feed-preparing")
            if app.buttons["닫기"].isHittable {
                app.buttons["닫기"].tap()
                settle(1.0)
            }
        }

        if app.buttons["tab.home"].isHittable {
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
            if app.buttons["높은 가격순"].isHittable {
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
            if app.buttons["detail.delete"].isHittable {
                app.buttons["detail.delete"].tap()
                settle(1.5)
                capture(app, "12-delete-confirm")
                if app.buttons["취소"].isHittable {
                    app.buttons["취소"].tap()
                    settle(1.0)
                }
            }

            if app.buttons["detail.back"].isHittable {
                app.buttons["detail.back"].tap()
                settle(1.5)
            }
        }
    }

    // MARK: - 일정 추가

    /// 웹처럼 입력에 따라 섹션이 하나씩 나타나는지 단계별로 남긴다.
    func test_04_일정_추가() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)

        guard app.buttons["main.add"].waitForExistence(timeout: 10) else { return }
        app.buttons["main.add"].tap()
        settle(2.0)
        capture(app, "13-addplan-empty")

        // 제목을 넣으면 카테고리 섹션이 나타난다.
        let title = app.textFields["addplan.title"]
        if title.waitForExistence(timeout: 5) {
            title.tap()
            title.typeText("드레스 본식 대여")
            settle(1.5)
            capture(app, "14-addplan-category-revealed")
        }

        // 카테고리 선택 모달
        if app.buttons["addplan.category"].isHittable {
            app.buttons["addplan.category"].tap()
            settle(1.5)
            capture(app, "15-category-modal")

            // 시트를 닫는다. 닫힘 애니메이션이 끝나야 아래 화면이 다시 눌린다.
            app.swipeDown()
            settle(2.0)
        }

        // 스크린샷용 테스트는 단언으로 실패시키지 않는다.
        // 눌리지 않는 요소를 tap 하면 XCTest 가 예외를 던지므로 isHittable 로 먼저 확인한다.
        if app.buttons["addplan.back"].isHittable {
            app.buttons["addplan.back"].tap()
            settle(1.0)
        }
    }

    // MARK: - 예산 상세

    /// 메인의 예산 카드 → 예산 상세. 툴팁·탭·카테고리 필터·AI 안내까지 한 번에 돈다.
    func test_05_예산_상세() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)

        guard app.buttons["main.budget"].waitForExistence(timeout: 10) else { return }
        app.buttons["main.budget"].tap()
        settle(3.0)
        capture(app, "16-budget-detail")

        // 잔액 배지 옆 물음표 — 위 카드의 "남은 금액" 과 다른 수치라는 안내가 뜬다.
        let tip = app.buttons["budget.savings.help"]
        if tip.isHittable {
            tip.tap()
            settle(1.0)
            capture(app, "17-budget-savings-tooltip")
            tip.tap()
            settle(0.8)
        }

        // 카테고리 막대를 누르면 아래 목록이 그 카테고리로 좁혀진다.
        let bar = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "웨딩홀")
        ).firstMatch
        if bar.isHittable {
            bar.tap()
            settle(2.5)
            capture(app, "18-budget-category-filtered")
        }

        // 사용 탭 (필터가 걸린 상태라 웨딩홀 항목만 보여야 한다)
        if app.buttons["budget.tab.used"].isHittable {
            app.buttons["budget.tab.used"].tap()
            settle(2.5)
            capture(app, "19-budget-used-tab")
        }

        if app.buttons["budget.clearFilter"].isHittable {
            app.buttons["budget.clearFilter"].tap()
            settle(2.5)
            capture(app, "20-budget-filter-cleared")
        }

        if app.buttons["budget.ai"].isHittable {
            app.buttons["budget.ai"].tap()
            settle(1.5)
            capture(app, "21-budget-ai-modal")
            if app.buttons["budget.ai.close"].isHittable {
                app.buttons["budget.ai.close"].tap()
                settle(1.0)
            }
        }

        if app.buttons["budget.back"].isHittable {
            app.buttons["budget.back"].tap()
            settle(1.5)
        }
    }
}
